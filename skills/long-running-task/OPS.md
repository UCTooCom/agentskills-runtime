# 长程任务系统 · 运维手册

> 适用范围：`long-running-task` 插件（L3 进程隔离轨，`skills/long-running-task/`）+ 宿主 `agentskills-runtime`。
> 本手册基于磁盘代码事实编写（非设想），所有断言均可对照源码/配置定位。
> 配套文档：`README.md`（接口面）、`COMPOSITION.yaml`、`DATA_CONTRACT.yaml`、`SKILL.md`。
> **最近更新：2026-09-15**（补齐 §2.5 监控/水位环境变量、§4.5 告警排查、§5.6 告警三路出口、§5.7 磁盘水位告警；§7 原「待补」三项已落地）。

---

## 1. 系统概览

- 宿主（`agentskills-runtime`，cjpm 工程名 `magic`）通过 **cordis 插件管理器**加载 `mode: process` 插件。
- 本插件以独立进程运行：宿主经 **stdio** 与插件通信（JSON-RPC over stdio），插件进程的标准输出/错误由 cordis 采集并转发到宿主日志。
- 插件不直接访问数据库，所有表读写经宿主注入的 `host.db` 服务，**受 `plugin.yaml` 的 `tableWhitelist` 约束**（白名单外的表会被拒绝）。
- 长程任务轨迹写入数据库 `crontab_log` 表（经 `LrtTraceLog`），可经 `/trace` 接口聚合查看；宿主进程自身的文本日志走文件。

---

## 2. 部署配置

### 2.1 两处独立构建

| 构件 | 工程位置 | 构建命令 | 产物 |
|------|----------|----------|------|
| 宿主 runtime | 仓库根（`cjpm.toml` 名 `magic`） | `cjpm build` | 宿主可执行体 |
| 本插件 | `skills/long-running-task/`（`cjpm.toml` 名 `skill_long_running_task`，`output-type=executable`，`target-dir=target`） | `cd skills/long-running-task && cjpm build` | `skills/long-running-task/target/release/bin/skill_long_running_task.exe` |

> `plugin.yaml` 的 `command: ./skills/long-running-task/target/release/bin/skill_long_running_task.exe` 是**相对宿主工作目录**的路径。宿主 `resolvePluginCommand` 的语义是 `${cwd}/${command}`（去掉前导 `./`）后直接交给 `launch()`，**没有** `skills/{name}/` 自动补全的历史版本——那时写成相对插件目录的短路径会指向不存在的 `/target/release/bin/...`，且 `launch()` 不给可读错误，只表现为「插件起不来」。
> 当前宿主已加兜底：若 `${cwd}/${command}` 不存在，会再探一次 `${cwd}/skills/{name}/${command}` 并打 `plugin_command_relative_fallback` 警告。因此两种写法都能工作，但**推荐写带 `skills/{name}/` 前缀的完整形式**（发布包 cwd=bin 时 exe 正落在 `bin/skills/{name}/` 下）。**若插件未构建，该二进制不存在 → 进程拉起失败**（见 §4.1）。

### 2.2 plugin.yaml 关键字段

```
name: long-running-task
version: 1.0.0
mode: process            # 固定 process 轨；不要写 protocol 字段（解析逻辑不存在，会被静默忽略）
command: ./skills/long-running-task/target/release/bin/skill_long_running_task.exe   # 相对宿主 cwd，勿写成相对插件目录的短路径
enabled: true            # false → 宿主跳过加载（见 §4.1）
order: 7                 # 加载顺序
autoRestart: true        # 进程异常退出自动拉起
config:                  # 宿主读取（maxRounds 等统一来源，默认见下）
  maxRounds: 30
  maxRoundDurationMs: 1800000
  maxTaskDurationMs: 86400000
  maxConcurrentTasks: 100
  checkpointStrategy: "per-round"
  # 降级后端可选值：cli_execute / sql_only / builtin_tool / llm / template
  #   sql_only = 同一个脚本追加 `--sql-only` 再跑一次（数据库连不上时产出可人工导入的 SQL，spec 5.9.1 规则 5）
  degradationChain: [cli_execute, builtin_tool, llm, template]
  qualityGate: true
  # 是否允许同一任务重叠触发（默认 false）。false 时同一任务的两次触发串行，
  # 用 payload.executing 作进程内咨询锁；锁龄超过 maxTaskDurationMs 视为崩溃遗留并自动接管
  # （放这里而不是 crontab 列：给运维一个可改的开关，且改完只需重启宿主）。
  concurrentable: false
  # ── §11.3 监控告警阈值（单一事实来源；环境变量 LRT_MONITOR_* 可覆盖，见 2.3）──
  monitorEnabled: true
  monitorWindowSize: 50            # 滑动窗口样本数（近 N 次任务完成）
  monitorFailureRate: 0.3          # 非 completed 占比，0.0~1.0
  monitorRoundTimeoutRate: 0.2     # round_timeout 占比，0.0~1.0
  monitorCheckpointLatencyMs: 30000
  monitorProgressLatencyMs: 1000
env:                     # 仅作为插件进程环境变量与脚本运行提示
  LRT_SKILL_ROOT: ""     # 见 2.3
  LRT_SCRIPTS_DIR: ""
  LRT_PYTHON: ""
tableWhitelist:          # host.db 白名单；未列出的表调用会被拒绝（12 张，逐个 - 列出，见 §2.4）
  - agent_tasks
  - agent_contexts
  - crontab
  - crontab_log
  - agent_loop_metrics
  - agent_loop_tuning_configs
  - long_running_task_artifact
  - long_running_task_evolution
  - agent_approvals
  - aip_interaction_session
  - aip_interaction_task
  - agent_skills
```

### 2.3 生产必设环境变量

`plugin.yaml` 注释明确要求：**生产部署建议显式设置 `LRT_SKILL_ROOT`**。

原因：插件为 `mode: process`，宿主经 stdio 拉起，**进程 cwd 不保证是技能根目录**。若 `LRT_SKILL_ROOT` 为空，`LrtScriptRunner` 会回退到「进程 cwd 下的 `scripts/`」，导致 `output/parsed` 等相对产物落到非预期位置。

- `LRT_SKILL_ROOT`：技能根绝对路径（推荐）。`LrtScriptRunner` 据此取 `<root>/scripts` 为脚本目录，并把 `<root>` 作为子进程 cwd，使 `COMPOSITION.yaml` 的 `output/xxx` 相对路径正确落盘。
- `LRT_SCRIPTS_DIR`：直接指定脚本目录（优先级最高，覆盖 `LRT_SKILL_ROOT`）。
- `LRT_PYTHON`：Python 解释器；为空时按 `python3 → python` 顺序探测。

### 2.4 数据库 DDL

本插件新增/依赖的表（详见 `DATA_CONTRACT.yaml`）：
- 新增表：`long_running_task_artifact`、`long_running_task_evolution`
- 共同依赖：`agent_approvals`（§13.4 审批落库）、`crontab_log`（轨迹）、`agent_tasks`、`agent_contexts`、`crontab`、`agent_loop_metrics`、`agent_loop_tuning_configs`、`aip_interaction_session`、`aip_interaction_task`、`agent_skills`

> **部署前置**：上述 12 张表必须已在目标库建好，且全部列入 `tableWhitelist`。DDL 未执行或漏表 → `host.db` 调用被白名单拒绝（见 §4.2）。
> **审计留痕复用既有表**：平台级审计不另建表，统一写入 `operate_log`（宿主直写，插件不碰、也不需要列入 `tableWhitelist`）—— 见 §2.4.2。

#### 2.4.1 调度目录表预置数据（`crontab_task_registry`）

长程任务的 crontab 走 **`lrt://<agentId>`** scheme，由宿主的 `LrtPluginExecutor` 承接
（**不再用 `agent_execution://`**：宿主 `AgentExecutionExecutor` 会在循环退出时无条件把任务置为
`status=2`，与「未确认不得交付」的两段式冲突）。

`crontab_task_registry` 是调度执行器的**类型目录**（管理端 CRUD 直读），每种 scheme 一行。
**缺 `lrt://` 行不会导致任务不跑**（`SchedulerEngine` 按 scheme 从 `ExecutorRegistry` 取执行器，
不查这张表），但管理端的执行器下拉/类型列表会看不到该类型。建库时执行一次：

```sql
-- 幂等增量脚本（补 lrt:// 行 + 迁移存量 lrt-* 命名行 + 补列注释 + 自检查询）
sql/incremental/lrt_scheme_registry_20260915.sql
```

> **排障特征**：如果发现长程任务被 `AgentExecutionExecutor` 驱动（日志出现 `agent_execution://`），
> 说明该任务的 `crontab.task` 是旧值 —— 用上面的脚本迁移，或对存量任务手工
> `UPDATE crontab SET task = 'lrt://<agentId>' WHERE task = 'agent_execution://<agentId>'`。

#### 2.4.2 审计留痕（复用 `operate_log`，宿主直写，不进白名单）

spec 5.12.1 规则 5（数据写入审计）与 5.13.1 规则 3（MCP 调用审计）**复用既有 `operate_log` 表**
（用 `module` 区分事件类别），**不需要执行任何 DDL** —— 该表、五层模块、中间件、回收站、
CSV 导出与 Web 管理页均已在位。

> **为什么复用而非新建**：`operate_log` 的表注释就是「操作记录」，既有 `api` / `tool` / `cli` 三类；
> 该模块在 `backend`(TS)、`agentskills-runtime`(仓颉)、`web-admin`(Web) 三端同构，
> 另建表要在三端各建一套，也与「所有用户操作行为统一保存到该表」的方向冲突。
> 完整评估见 `.codeartsdoer/specs/long-running-task/audit-module-evaluation-20260915.md`。

打点位置**全部在宿主侧唯一出口**，插件与脚本都不必自己实现：

| `module` | 打点位置 | 记录内容 |
|---|---|---|
| `plugin` | `CordisHostServices.executeExecute`（L3 插件写库的唯一通道，成功与失败各一处） | `operate`=insert\|update\|delete、`route`=表名、`creator`=操作人、`params` 含内容摘要与 `affected` |
| `tool` | `McpOpenService.call`（REST `/open/call`、插件 `host.mcp`、CLI 三入口的汇聚点） | `operate`=工具名、`creator`=操作人、`params` 含入参摘要 / `durationMs` / `success` / `source`（三入口可辨） |

`params` 为 JSON，结构与既有 `module='tool'` 记录对齐：

```json
{"args":{…},"result":{"success":true,"affected":3,"durationMs":42},
 "error":"…","pluginId":"…","mcpAlias":"…","source":"host.db","actorType":"plugin","traceId":"…"}
```

- **不进 `tableWhitelist`**：写审计的是宿主进程（`OperateLogService` → `ORM.executor()`），不经过 `host.db`；
  走 `host.db` 写反而会形成「写审计触发审计」的递归。
- **失败不阻断业务**：审计写库异常只记 warn，主链路照常。
- **脱敏**：入参摘要里 `token` / `password` / `secret` / `api_key` / `apikey` / `accesskey` /
  `authorization` / `credential` 等值替换为 `***`，再截断到 2000 字节（错误信息 1000 字节）。
- **`creator` 无用户上下文时写 NULL**：插件链路常常没有用户身份；`recordLog` 直连 DAO 落库
  （绕开会把 `None` 覆盖成 `Some("")` 的 `create()`），因为空串写 `uuid` 列会报错且被静默吞掉。
- **与 `due_diligence_mcp_call_log` 并存**：后者是 due_diligence 插件（黑客松参赛作品，非核心功能）
  的领域业务表（含 `task_id`），由插件自写；`operate_log` 是平台级合规兜底，两者层级不同。

查最近的留痕（近 1 小时）：

```sql
SELECT module, operate, creator, route, params, created_at
FROM operate_log WHERE created_at > now() - interval '1 hour'
ORDER BY created_at DESC LIMIT 50;
```

### 2.5 监控 / 日志相关环境变量（全部可选）

| 环境变量 | 作用 | 缺省 |
|---|---|---|
| `LRT_MONITOR_ENABLED` | 监控告警总开关 | `true` |
| `LRT_MONITOR_WINDOW_SIZE` | 滑动窗口样本数（近 N 次任务完成） | `50` |
| `LRT_MONITOR_FAILURE_RATE` | 任务失败率阈值（0.0~1.0） | `0.3` |
| `LRT_MONITOR_ROUND_TIMEOUT_RATE` | 回合超时率阈值（0.0~1.0） | `0.2` |
| `LRT_MONITOR_CHECKPOINT_LATENCY_MS` | 检查点保存平均延迟阈值（ms） | `30000` |
| `LRT_MONITOR_PROGRESS_LATENCY_MS` | 单轮平均耗时阈值（ms，进度延迟代理） | `1000` |
| `LRT_LOG_WATERMARK_BYTES` | 日志目录水位告警阈值（字节）；`<=0` 关闭 | `1073741824`（1 GiB） |
| `PROMPTS_DIR` | **宿主进程**提示词配置目录（见下） | `./prompts` |

> **阈值优先级**：环境变量 > `plugin.yaml` 的 `config` 段 > 内置默认值（三者同一套解析，见 `LrtConfig`）。
> `LRT_MONITOR_*` 是**插件进程**的环境变量（插件在宿主经 stdio 拉起时继承宿主环境）；`LRT_LOG_WATERMARK_BYTES` / `PROMPTS_DIR` 是**宿主进程**的环境变量。

#### 2.5.1 提示词可视化配置（`PROMPTS_DIR`）

压缩/总结类提示词不再硬编码，由宿主在启动时从 `PROMPTS_DIR`（默认 `./prompts`）加载，**文件存在即覆盖内置默认**：

| 文件 | 作用 |
|---|---|
| `tool-summarize.system.md` | 工具结果压缩的 system 提示词 |
| `tool-summarize.user.md` | 工具结果压缩的全局 user 提示词（含 `{tool_call}` / `{tool_result}` 占位符） |
| `tool-summarize.user.<profile>.md` | 按 **profile**（= `agent.name`）定向覆盖，缺省则回落全局那份 |
| `conversation-summary.system.md` | 会话压缩 system 提示词 |

> **长程任务为什么单独一份**：默认提示词只要求"总结工具输出"，对跨越数十回合的任务会把
> 「已完成/待办/卡在哪」丢掉。仓库内提供 `tool-summarize.user.long-running-task.md`
> 作为长程任务 profile 的示例（强调 Progress / Blockers / Next）。
> **目录不存在或文件读不到一律软着陆**（回落内置默认），不会让任务跑不起来。
> 监控告警的行为与排查见 §4.5 / §5.6。

---

### 2.6 HTTPS / WSS 部署口径（开发、测试、线上统一）

本框架的开发/测试/线上环境**统一是带真实证书的 HTTPS**（`.env`: `PORT=443` +
`CERT_FILE_NAME`/`KEY_FILE_NAME` 指向真实证书，配合 Windows hosts 把域名映射到 127.0.0.1）。

| 关注点 | 结论 | 依据 |
|---|---|---|
| REST 是否 HTTPS | 由 `BACKEND_URL` 前缀决定：`https://` → 走 `Application(port, host, certPath, keyPath, …)`；否则明文 | `src/app/main.cj` |
| WS 要不要单独配 WSS | **不需要**。WS 路由注册在**同一个** HTTP(S) server 实例上（`server.registerWebSocketRoute("/api/v1/uctoo/webmcp/mcp", …)`），HTTPS 生效时自动就是 WSS，**同端口、同证书、无第二个开关** | `src/app/main.cj` |
| 前端 WS 地址 | 不硬编码：`baseURL` 由业务侧传入，按 `wss://` / `ws://` / `/webmcp/mcp` 判定 WS 模式 | `next-remoter/src/composable/CustomAgentModelProvider.ts` |
| 证书校验 | **全仓不得关闭**（spec 5.13.1 规则 8 禁止项）。`tests/lrt` 用例 `17.4-https-loop-01` 会扫描 `src/**/*.cj` + `skills/**`，出现 `verify=False` / `rejectUnauthorized: false` / `InsecureSkipVerify` / `CertificateVerifyMode.TrustAll` 即 FAIL | — |
| D 层脚本基址 | 解析顺序：`HOST_BASE_URL` 环境变量 > 仓库 `.env` 的 `BACKEND_URL` > `https://javatoarktsapi.uctoo.com`。**不提供明文 localhost 默认值** | `skills/due_diligence_agent/scripts/run_batch_dd.py::resolve_base_url` |

> **排障提示**：D 层脚本报「连不上」时，先确认基址是不是被显式写成了 `http://…` 或非 443 端口
> —— 在 HTTPS 环境里这类错值表现是"连接失败"，而不是"证书错误"，很容易被当成服务没起。

## 3. 插件加载验证

宿主启动时自动发现并加载 `plugin.yaml`（`loadProcessPlugins`）。验证是否加载成功**只看日志关键字**：

### 3.1 成功标志

```
[CordisHostManager] process plugin started: long-running-task
```

出现即表示：插件进程拉起成功，并与宿主完成握手（`awaitActive` 10s 内返回 `Ok`）。

### 3.2 失败/跳过标志

| 日志 | 含义 | 处置 |
|------|------|------|
| `process plugin '<name>'(disabled)` 进入 skipped | `enabled: false` | 改 `enabled: true` 后重启宿主 |
| `process plugin '<name>' missing required 'command'` | `command` 字段缺失 | 补齐 `command` |
| `process plugin '<name>' empty 'command'` | `command` 为空 | 填写正确路径 |
| `process plugin '<id>' failed to activate: <reason>` | 拉起/握手失败（含 10s 超时） | 见 §4.1，先查插件自身 stdout（已并入宿主日志） |

### 3.3 加载超时

`awaitActive` 超时固定 **10 秒**（`cordis_host_manager.cj`）。若插件进程冷启动慢、或握手协议未对齐，会落入 `failed to activate`。此时插件进程的 `eprintln` 已由 cordis 转发到宿主日志，直接搜插件名查 stderr。

### 3.4 加载后自检清单

1. 宿主日志出现 `process plugin started: long-running-task`。
2. 插件进程的日志（含 `LrtTraceLog` 的 `[lrt-trace]` 等）已并入宿主日志文件（见 §5）。
3. DB 中 `crontab_log` 等表可写入（白名单生效）。
4. 调一次 `lrt-plan` / `lrt-execute` RPC，返回非「表白名单拒绝」类错误。

---

## 4. 故障排查

### 4.1 插件完全不加载 / 启动即退出

- **`enabled: false`** → 跳过，改 `true` 重启。
- **二进制不存在**（未 `cjpm build` 或产物路径与 `command` 不符）→ 进程拉起失败，日志见 `failed to activate`。
- **`command` 路径解析错**：宿主会自动把相对插件目录的 `command` 转成 `./skills/<name>/<command>`；若插件目录名与 `name` 不一致会错位，核对 `plugin.yaml` 的 `name` 与实际目录。
- **握手 10s 超时**：查宿主日志中该插件进程的 stderr（通常能看到插件侧 panic/初始化报错）。

### 4.2 调用插件 RPC 报「表白名单拒绝」

- 错误源自 `host.db`：请求的表不在 `tableWhitelist`。
- 处置：① 确认目标库已建该表（DDL 落地）；② 把表名加入 `tableWhitelist`；③ 重启宿主重新加载插件。

### 4.3 长程任务跑飞 / 异常终止

- **校验失败**：`LrtArtifactVerifier` 判定不通过 → 由 `LrtExecutor` 标记重产出（补执行）→ 仍失败触发 `LrtDegradation.run` 降级链（`cli_execute → builtin_tool → llm → template`）。降级详情写入 `payload.last_degradation`。
- **`LRT_SKILL_ROOT` 未设**：脚本产物（`output/parsed` 等）落到非预期目录，导致后续步骤读不到中间结果。设好环境变量（§2.3）后重跑。
- **限额触顶**：`maxRounds=30` / `maxTaskDurationMs=86400000` / `maxConcurrentTasks=100`。超限会终止或排队，按需在 `plugin.yaml` 的 `config` 调整。

### 4.4 评审闭环不生效（前端不弹卡片）

- 后端 `review_required` 事件链路：`LrtExecutor` 发射 → `LrtEventRelay`（`case "review_required"`）→ `LrtEventBridge.pushReviewRequired` → SSE `lrt_event`。
- 前端经 `/events` SSE 订阅，收到 `event: lrt_event` 后由 `onLrtEvent` 回调渲染 `ReviewCard`。
- **常见断点**：**`session_id` 对齐**——事件用任务 `session_id` 投递 SSE，浏览器订阅的是 `webmcp-default`。若聊天创建的任务其 `session_id` 非 `webmcp-default`，前端收不到。验证：确认 `goal_achieved` 等其它 `lrt_event` 能到前端（同通道），能到则本事件也能到。
- 排查顺序：① 宿主日志是否有 `pushReviewRequired`；② 前端控制台是否收到 `lrt_event`；③ `TinyRobotChat.vue` 的 `contentRendererMatches` 是否含 `review_required` 匹配。

### 4.5 监控告警不触发 / 反复误报

**先理解它是什么**：`LrtMonitorService` 是**进程内滑动窗口**（best-effort，**不持久化**）。样本来自每次任务终态时 `LrtExecutor` 调的 `recordTaskOutcome`。四类指标：`task_failure_rate` / `round_timeout_rate` / `checkpoint_latency` / `progress_latency`。

**不触发**，按序排查：
1. `monitorEnabled` 是否为 `true`（`plugin.yaml` 或 `LRT_MONITOR_ENABLED`）。
2. **插件进程是否重启过**——窗口在内存里，重启即清空；样本需重新累积。
3. **样本数是否 < 2**——窗口内样本不足 2 条时**不评估**（刻意避免单样本误报）。`monitorWindowSize` 决定窗口上限。
4. 指标是否真的超阈值：`monitorFailureRate=0.3` 表示窗口内非 `completed` 占比 > 30% 才告警。
5. 是否处于**冷却期**：同一指标 **5 分钟内只告警一次**（`COOLDOWN_MS = 300000`）。冷却窗内重复超标**不会**再发。

**反复误报**（阈值偏紧）：
- `checkpoint_latency`：检查点保存是 `host.db` 写库，DB 抖动会拉高均值 → 调大 `monitorCheckpointLatencyMs`。
- `progress_latency`：**这是「单轮平均耗时」作为进度通知延迟的代理指标**（不是真实的通知链路延迟）。长步骤天然耗时高，`1000ms` 这个默认值对真实 LLM 回合几乎必然超标 → 生产建议按实际单轮耗时量级调整（例如 60000），或直接关掉该指标（无单独开关，可把阈值调得足够大）。
- 窗口过小（如 `monitorWindowSize: 5`）会让单次异常主导比率 → 调大窗口。

**告警出口在哪里看** → 见 §5.6。

---

## 5. 日志查看方法（带时间戳文件名 + current 入口）

### 5.1 文件日志命名规则

日志由宿主 `LogUtils` 落盘（`src/log/log_utils_impl.cj`）：

- 基路径由 `Config.logFile` 决定，默认 `stderr`；可由环境变量 **`LOG_FILE`** 指定（默认 `./logs/agentskills-runtime.log`）。
- 当 `Config.logFileTimestamped = true`（**默认 true**）时，实际写入文件为：
  ```
  <basename>-<yyyyMMdd>-<HHmmss>.log
  例：logs/agentskills-runtime-20260915-082800.log
  ```
  同秒内重启会追加 `-1` / `-2` 后缀，**不会覆盖历史日志**（便于回溯长程任务完整轨迹）。

### 5.2 current 入口（指针文件）

每次运行会在日志目录维护一个指针文件：

```
logs/current-log.txt
```

内容为**本次运行活跃日志文件的绝对路径**（一行）。查看"当前这次运行"的日志，先读它：

```bash
cat logs/current-log.txt        # 得到例如 logs/agentskills-runtime-20260915-082800.log
tail -f "$(cat logs/current-log.txt)"   # 实时跟踪当前运行
```

> 设计说明：Windows 普通用户常无软链权限，故统一降级为「指针文件」（写路径文本）而非符号链接。

### 5.3 保留期清理

- `Config.logRetentionDays` 默认 **14 天**。启动时扫描日志目录，删除文件名时间戳超期**且符合模板** `<basename>-<yyyyMMdd>-<HHmmss>[-n].log` 的文件。
- 安全约束：只删符合模板的文件，**不会误删 `current-log.txt` 或用户放在同目录的其它文件**。
- 设为 `0` 或负数表示不清理。
- 另有**按容量**的日志水位告警（`LRT_LOG_WATERMARK_BYTES`），见 §5.7。

### 5.4 插件日志去哪了

插件进程的 stdout/stderr 经 cordis 采集并**转发到宿主 LogUtils**，因此：

- 插件自身的 `eprintln`（含 `[lrt-trace] crontab_log 写入失败` 等）**直接出现在宿主日志文件里**，无需另开插件进程日志。
- 一个 `current-log.txt` 指向的日志文件，同时包含宿主与插件输出，按时间戳顺序混排。

### 5.5 结构化轨迹（不在文件，在 DB）

长程任务的每轮/每步结构化轨迹（trace_id / task_id / round / step / status / duration_ms / message）写入 `crontab_log` 表，经 `/trace` 接口聚合为一条时间线：

```
GET /api/v1/uctoo/long_running_task/trace?taskId=<>&agentId=<>&traceId=<>&page=&pageSize=
```

文件日志适合看「当时的原始输出」，DB `/trace` 适合做「结构化检索与跨轮归并」。两者互补。

### 5.6 监控告警的输出去哪看（三路并发）

`LrtAlertService.fire` 一次告警**同时**走三个出口（各自 try/catch，任一失败不影响其余）：

| 出口 | 落地位置 | 怎么查 |
|---|---|---|
| **stderr**（兜底，最直接） | 插件进程 stderr → 由 cordis 转发到宿主日志 | 搜 `[lrt-alert]`，形如 `[lrt-alert][warning] task_failure_rate: value=0.42 threshold=0.3 window=50 :: ...` |
| **结构化日志** | 插件经 `host.db` 写 `crontab_log`，`type=monitor_alert` | `GET /api/v1/uctoo/long_running_task/trace?...` 或用 SQL 查 `crontab_log where type='monitor_alert'` |
| **事件（前端可见）** | `LrtEventEmitter.emitMonitorAlert` → `host.event` → `LrtEventRelay`（`case "monitor_alert"`）→ `LrtEventBridge.pushMonitorAlert` → SSE/WS `lrt_event` | 与 `review_required` **同一通道**；前端 `/events` 订阅后可在控制台看到 `event: lrt_event`，`type=monitor_alert` |

> **链路完整性**（任一处缺失都会让事件被静默丢弃）：`emitter` → `relay` 的 `case "monitor_alert"` → `bridge` 的 `MonitorAlert` 变体 + `wireName` + `pushMonitorAlert`。排查时按这个顺序逐段确认。

### 5.7 日志磁盘水位告警

日志改为「不覆盖、滚动新增」（§5.1）后会持续累积，因此除 14 天保留期（§5.3）外，另有**水位告警**：

- 检查时机：宿主 `LogUtils.buildLogger` 内，紧接 `purgeExpiredLogs` 之后执行一次 `checkDiskWatermark`。
- 统计口径：日志目录下**符合文件模板** `<basename>-<yyyyMMdd>-<HHmmss>[-n].log` 的文件 `size` 累加（不含 `current-log.txt` 等其它文件）。
- 阈值：`LRT_LOG_WATERMARK_BYTES`（字节），缺省 1 GiB，`<=0` 关闭。
- 触发后：`LogUtils.warn` 写一条警告（进日志文件 + stderr），并调用宿主注入的回调 → `LrtEventBridge.pushMonitorAlert`，即**以 `metric=log_disk_watermark` 复用同一条 `monitor_alert` 事件通道**（`taskId`/`sessionId`/`agentId` 为空串，属系统级告警）。
- 与保留期的关系：保留期是「按时间兜底清理」，水位告警是「按容量提前预警」，两者互补，不互相替代。

> 排查「水位告警没出现」：① 确认宿主进程环境变量已设且值合理（默认 1 GiB 可能始终不触发）；② 确认日志文件确实写在**同一目录**且文件名符合模板（手动重命名过的文件不计入）；③ 该检查在每次 `buildLogger` 时执行，启动后不会周期性重查。

---

## 6. 运维速查

| 想确认的事 | 怎么做 |
|------------|--------|
| 插件是否加载成功 | 搜宿主日志 `process plugin started: long-running-task` |
| 看当前运行日志 | `tail -f "$(cat logs/current-log.txt)"` |
| 找历史某次运行日志 | `ls -t logs/agentskills-runtime-*.log` 按时间取最新 |
| 调用被白名单拒 | 检查 `tableWhitelist` + 目标库表是否已建 |
| 任务执行轨迹 | `GET /trace?taskId=...` |
| 任务跑飞 | 查 `payload.last_degradation`（降级链）+ 宿主日志插件 stderr |
| 评审不弹卡片 | 查 `session_id` 是否对齐 `webmcp-default`（§4.4） |
| 看告警（最直接） | 搜宿主日志 `[lrt-alert]`（§5.6） |
| 查告警历史 | `crontab_log where type='monitor_alert'` 或 `/trace`（§5.6） |
| 告警不触发 | 查 `monitorEnabled` + 样本是否 ≥2 + 是否在 5 分钟冷却内 + 是否重启过（§4.5） |
| 调告警阈值 | 环境变量 `LRT_MONITOR_*`（优先级最高）> `plugin.yaml config` > 默认（§2.5） |
| 日志目录快满了 | `LRT_LOG_WATERMARK_BYTES` 水位告警；`logRetentionDays` 按天清理（§5.3 / §5.7） |
| 长程任务被谁驱动 | `select task,status from crontab where name like 'lrt-%'` —— `task` 必须是 `lrt://<agentId>`；若是 `agent_execution://`，宿主会自行置 `status=2` 旁路两段式（§2.4.1） |
| 改了提示词不生效 | 确认 `PROMPTS_DIR` 指向正确目录（宿主进程环境变量）+ 文件名/profile 拼写（§2.5.1）；启动时只加载一次，改完要重启宿主 |
| 同一任务被跳过不跑 | 查 `payload.executing` 是否为真（并发开关 `concurrentable=false`）；若为崩溃遗留，锁龄超 `maxTaskDurationMs` 会自动接管（§2.2） |
| 数据库连不上但任务没停 | 该步应在 `degradation_chain` 里声明 `sql_only` —— 会用同一脚本加 `--sql-only` 产出可导入 SQL（§2.2） |
| 谁写了某张表 / 谁调了某个 MCP 工具 | 查 `operate_log`（`module` 区分 `plugin` / `tool`，`params.source` 区分入口），见 §2.4.2 |
| 审计表里没有记录 | 确认 DDL 已执行 + 宿主已重启（打点在编译后的宿主进程里）；失败只记 `[AuditLog] audit_write_failed` warn，不抛错 |
| D 层脚本连不上宿主 | 先看基址是否被写成明文/错端口 —— 解析顺序为 `HOST_BASE_URL` > `.env BACKEND_URL` > https 默认值（§2.6） |

---

## 7. 已完成能力（原「已知待补」清单，2026-09-15 收尾）

以下三项曾列为待补，现已落地，本节保留作能力索引：

- **§11.3 监控告警**（tasks.md 1003）：`LrtMonitorService` + `LrtAlertService` 已落地——四指标（失败率/超时率/检查点延迟/进度延迟）+ 进程内滑动窗口 + 5 分钟冷却 + 三路出口。运维面见 §4.5 / §5.6 / §2.5。
- **§11.3 磁盘水位告警**（tasks.md 1005）：`LogUtils.checkDiskWatermark` + `LRT_LOG_WATERMARK_BYTES` 已落地，以 `metric=log_disk_watermark` 复用 `monitor_alert` 事件通道。见 §5.7。
- **§14.1 契约生成工具**（tasks.md 1146）：已并入 `plugingen`——`plugingen --name <名> --db <库> --tables <表...> --contract-only` 从 `db_info` 生成 `DATA_CONTRACT.yaml` 骨架（只填表/列/类型/可空/注释，`access`/`role`/`idempotent_key`/`write_rule`/`sample_rows` 留 `TODO` 供人工补齐）。

### 2026-09-15 第三十轮新增（收尾）

- **调度 scheme 改为 `lrt://`**：宿主 `LrtPluginExecutor` 只触发插件、不写 `agent_tasks.status`，两段式交付不再被宿主 CRON 链路旁路。部署需跑一次 `sql/incremental/lrt_scheme_registry_20260915.sql`。运维面见 §2.4.1。
- **`concurrentable` 可配**：`plugin.yaml config.concurrentable`（默认 false）+ 陈旧并发锁自愈。见 §2.2。
- **提示词可视化配置**：`PROMPTS_DIR` + `prompts/*.md`，按 profile 定向。见 §2.5.1。
- **`sql_only` 降级后端**：数据库连不上时同脚本加 `--sql-only` 产出可导入 SQL（spec 5.9.1 规则 5）。
- **人在回路超时兜底具名事件**：`decision_timeout_default_applied`（可 grep 统计，覆盖后端兜底与前端代兜底两条路径）。
- **干预路由**：`POST /intervene`（taskId 在 body）与 `POST /intervene/:taskId` 同时可用。
- **产物日期校验在主路径生效**：从目标原文抽取 `YYYY-MM-DD`，路径或内容命中即算匹配（防"旧文件误判完成"）。

### 2026-09-15 第三十一轮新增（审计留痕 + HTTPS 闭环）

- **审计留痕落地**（spec 5.12.1 规则 5 / 5.13.1 规则 3）：**复用既有 `operate_log` 表** + 宿主两个唯一出口打点。
  **无需执行任何 DDL**（该表已存在）。运维面见 §2.4.2。
- **HTTPS / WSS 口径澄清**：WS 与 REST 同 server 承载，HTTPS 生效时自动 WSS，无独立开关；
  D 层脚本基址改为 `HOST_BASE_URL` > `.env BACKEND_URL` > https 默认值（原默认是明文 `localhost:8080`，在 443+HTTPS 环境里必然连不上）。见 §2.6。
- **证书校验禁止项可机械核查**：新增用例 `17.4-https-loop-01` 扫全仓源码，出现任何关闭校验的写法即 FAIL。

**仍待人工/运行时验收（非阻塞）**：

| 项 | 说明 |
|---|---|
| `cjpm build` | 第三十轮 12 个宿主文件 / 8 个插件文件 + **第三十一轮 3 个宿主文件**（`OperateLogService.cj`、`cordis_host_services.cj`、`McpOpenService.cj`；`run_batch_dd.py` 为 Python 无需编译）尚未编译（AI 不代跑编译） |
| 执行增量 SQL | `lrt_scheme_registry_20260915.sql` 已人工执行 ✅；**审计复用 `operate_log`，无需任何 DDL** |
| 审计打点真机验证 | 跑一次 LRT 任务 + 一次 MCP 调用后，`select module, operate, count(*) from operate_log where created_at > now() - interval '1 hour' group by 1,2` 应出现 `plugin` / `tool` 两类 |
| 监控告警真机验收 | 造「失败率超阈值」场景确认三路输出；`LRT_LOG_WATERMARK_BYTES=1000` 验水位告警 |
| `DATA_CONTRACT.yaml` 人工补齐 | 生成器只出骨架，`write_rule` / `sample_rows` / 幂等键仍需人工按业务填 |
| §11.3 四类决策 JSONL 行日志（tasks.md 1000） | `plan`/`replan`/`degradation`/`decision` 目前落 payload/表字段，非可被采集器按行抓取的 JSONL |
| §11.4 SKILL.md 错误行为示例（tasks.md 1020） | 需自进化闭环实跑出真实样本后才能补，现为占位 |
| §11.2 存量 Agent 配置补齐（tasks.md 992） | 按 Agent 区分的 `config` 覆盖机制未做 |
