# SDD 插件运维手册（OPS）

面向**部署与排障**，不含方法论（方法论在 `SKILL.md` / `COMPOSITION.yaml`）。
每一节都对应 design.md §2.6 的防回退约束，编号见文末对照表。

---

## 1. 形态：插件是资产包，编排在宿主

这是最容易误判的一点——**六步编排引擎不在插件进程里**。

| 位置 | 承担什么 |
|---|---|
| `skills/sdd/`（插件） | 资产包：`SKILL.md` / `COMPOSITION.yaml` / `DATA_CONTRACT.yaml` / `agents/` / `prompts/` / `templates/` + 薄壳路由 |
| 宿主 `src/app/services/bridge/sdd_orchestration_service.cj` | 六步编排、真派生、产物落盘、闸口、事件 |

原因：宿主向 L3 插件只暴露 `host.db` / `host.mcp` / `host.event` / `host.db_schema_lookup` /
`host.cache` / `host.log` 六类 RPC（`src/plugin/cordis_host_services.cj:70-76`），
**没有 `host.agent.invoke`**，而 `SubAgentTool` 是宿主内建工具。插件进程里跑不了子 agent。
（design §2.6-7 确定性优先：能复用宿主能力的不要重造。）

---

## 2. 编译与部署

### 2.1 插件（独立工程，与 runtime 分开构建）

```bash
cd apps/agentskills-runtime/skills/sdd
cjpm build
```

产物：`target/release/bin/skill_sdd.exe`（`plugin.yaml` 的 `command` 就是它）。

> `command` 是**相对宿主工作目录**的路径，不是相对插件目录。
> `CordisHostManager.resolvePluginCommand` 直接把 `${cwd}/${command}` 交给 `launch()`，
> 不做存在性校验、也没有 `skills/{name}/` 兜底补全——路径写错的表现是"插件静默不加载"。

### 2.2 宿主

宿主侧任何改动（编排服务、同步链路、路由）都要重编译 runtime：

```bash
cd apps/agentskills-runtime
cjpm build
```

### 2.3 数据库增量脚本（按顺序执行）

| 顺序 | 脚本 | 内容 |
|---|---|---|
| 1 | `sql/incremental/sdd_subagent_20260927.sql` | 2 张新表 + 2 个新列 + 7 个 REQ-SDD-012 列 + `v_sub_agent_stage_cost` 视图 + cangjie-coder 手工数据下线 |
| 2 | `sql/incremental/20260927_sdd_orchestration_permissions.sql` | 编排 5 条 API 路由的 RBAC 注册与超管授权 |
| 3 | `sql/incremental/20260928_sdd_gate_review_permission.sql` | `POST /sdd/review` 闸口路由的 RBAC 注册 |

**漏第 2、3 步的典型症状**：接口全部 403（`RequirePermissionMiddleware` 挂在全局，
未登记路径对非通配角色一律拒绝）。不是代码 bug，是权限没登记。

---

## 3. 六步怎么跑

| 接口 | 用途 |
|---|---|
| `POST /api/v1/uctoo/sdd/start` | 按 `feature_name` 幂等取/建工程 |
| `POST /api/v1/uctoo/sdd/run` | **异步**跑整条流水线（建 `sdd://<feature_name>` 调度行，每 tick 推进一步） |
| `POST /api/v1/uctoo/sdd/run-stage` | **同步**跑单步（联调/探针用，会阻塞到子 agent 返回） |
| `GET /api/v1/uctoo/sdd/status/:featureName` | 只读查 `current_stage` / `status` / `round` |
| `POST /api/v1/uctoo/sdd/review` | 闸口决策：`confirm` / `revise` / `abandon` |

关键参数：
- `agent_id`：**code 步必需**（主 agent 直执行，不派生编码子 agent，缺它显式失败）。
- `language`：`cangjie` / `web` / `app`，决定加载哪个编程技能。
- `auto=false`：每步跑完**停在闸口**（`awaiting_review`）等人决策；`auto=true` 自动推进。

---

## 4. 排障清单（按症状查）

### 4.1 `agents` 表里没有子 agent（最常见）

症状：五个派生步全部报 "sub-agent not found"。

排查顺序：
1. 声明文件在不在：看各技能根目录下 `agents` 子目录里的 `.md`。
2. 有没有走同步链路：文件→DB 的唯一入口是 `SyncManager.syncAll`
   （启动时跑一次，或 `POST /api/v1/uctoo/sync/all` 手动触发；该路由需权限，403 就重启宿主）。
   链路：`AgentSyncHandler.detectChanges` → `ChangeDetector.detectAgentChanges(basePath, bundledSkillRoots!)`。
3. **只看加载期探测是不够的**：`BundledAgentScanner.scan` 只把名字挂进内存
   `SkillManifest.bundledAgents`，**不写库**。派单查的是库。
4. 自检 SQL：

```sql
SELECT name, agent_type, skill_name, source_path
FROM public.agents WHERE deleted_at IS NULL ORDER BY skill_name, name;
```

### 4.2 派单一直失败、每次都重派一遍

大概率是**契约校验误判**，不是子 agent 写不出来。

`output_contract.required_sections` 里的串是**子串包含**判断，必须与模板标题**逐字一致**。
例如契约写"决策风险"、模板是"关键设计决策与风险" → 永远匹配不上 → 每次派单都判失败
→ 自动重派 → 仍失败 → 卡在闸口。

排查：
```sql
SELECT stage, attempt, verify_passed, verify_errors
FROM public.sub_agent_invocations ORDER BY created_at DESC LIMIT 20;
```
`contract_type = contract_absent` 表示这个子 agent **没配契约**（降级为仅非空校验）。

### 4.3 进度事件收不到

- 聊天区（SSE）收不到：多半是没带 `session_id`，或 SSE 管理器未注入。
  注入点在 `WebMCPController` 里 `LrtEventBridge.attachSSEManager` 的同一处
  （新增了 `SddEventBridge.attachSSEManager`）。
- **纯 cron 任务本来就没有 session**，事件只走 WebSocket 广播——这是设计如此，不是故障，
  代码里是早退且不打日志。
- 多行内容会被转义成单行（`\n` → `\\n`）：SSE 是行协议，裸换行会切断帧。

### 4.4 `host.db` 报"表不在白名单"

`plugin.yaml` 的 `tableWhitelist` 只列了 7 张表。要访问别的表必须**改白名单并重编译宿主**，
不要绕。（design §2.6-2）

### 4.5 产物没落盘 / 查不到

- 目录：runtime 自有 `specs/{feature_name}/`，**禁落 `.codeartsdoer/specs/`**。
- 入库表 `long_running_task_artifact` 只有 11 列、**没有 usage / stage 列**：
  `stage` 维度记在 `verification_result` jsonb 里。别去加列。
- revise 重做时上一版会归档成 `*.prev`，不会被静默覆盖。

### 4.6 手工执行 SQL 报 `操作符不存在: uuid = text`

`FROM (VALUES ...) AS v(...)` 会把裸字符串固化成 text，与 uuid 列比较就炸。
写法：`VALUES` 首列 `::uuid`、次列 `::text`。单行 `SELECT ... WHERE NOT EXISTS` 则无需强转。

（Windows 版 psql 在 Git Bash 下会忽略 `-c` / `-f`，要走 stdin 管道：
`psql -w "<url>" < file.sql`）

---

## 5. 防回退约束对照（design §2.6 共 13 条）

| # | 约束 | 本手册落点 / 代码落点 |
|---|---|---|
| 1 | 禁止跳过闸口 | §3：`auto=false` 时每步停 `awaiting_review`；`POST /sdd/review` 三选一 |
| 2 | 禁止新建库表 | §2.3：表扩张严格限量（新表 ≤2、既有表新列 ≤2） |
| 3 | 研究步 condition 红线 | `SddOrchestrationExecutor.nextStage` 读 `enable_research`，不挂"文件是否存在" |
| 4 | 编码质量闸门 | `code` 步主 agent 直执行；过渡路由必须写进 `skill_used` |
| 5 | L3 日志只走 stderr | `src/main.cj` 一律 `eprintln`（stdout 被 stdio RPC 独占） |
| 6 | 状态不倒退 | `advanceStage` 只推进；revise 靠 `bumpRound` + 新 `task_id`，不改 `status` 语义 |
| 7 | 确定性优先 | 落库走 `host.db` / 宿主 Service 语义方法；只有撰写/推理交给模型 |
| 8 | COMPOSITION 真实 schema | `COMPOSITION.yaml` 用 long-running-task 同款要素 |
| 9 | 子 agent 必须真派生 | `SubAgentDispatchServiceImpl.dispatch`；缺失**立即失败**，无静默降级 |
| 10 | 上下文隔离 | 一律 `SubAgentMode.Isolated` + 显式 question；`agent_contexts` 按 `task_id` 隔离 |
| 11 | coder 技能无 `agents/` | `skills/{cangjie,web,app}-coder/` 三处均无该目录（cangjie-coder 的已删并并入四步工作流） |
| 12 | 子 agent 只靠约定注册 | 唯一来源是各技能 `agents` 子目录；已于 2026-09-28 补齐"删除即下线"（软删） |
| 13 | 禁改假加载入口 | 真入口是 `SkillManagementService.loadSkillsFromDirectory`；`src/skill/skill_loader.cj:55` 是桩 |

---

## 6. 变更时的连带检查

| 改了什么 | 必须同步改什么 |
|---|---|
| 新增宿主路由 | ① `AutoRouteConfig` 注册 ② `permissions` 表登记 + 授权（否则 403） |
| 新增 `sdd://` 参数 | `SddParams` + `parseParameters` + `startPipeline` 的 `parameters` 三处 |
| 改动阶段集合 | `SddOrchestrationService.STAGES` 唯一定义，别在控制器复制一份 |
| 新增产物类型 | `artifactFileForStage` / `artifactTypeForStage`；`artifact_type` 只能取既有枚举 |
| 删子 agent 声明文件 | 重启或触发同步即下线（软删）；确认 `SELECT ... FROM agents WHERE source_path LIKE ...` |
