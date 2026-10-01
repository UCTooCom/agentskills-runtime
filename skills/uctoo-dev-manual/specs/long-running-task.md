# 长程任务开发指南

> 本文整合自 `.codeartsdoer/specs/long-running-task`（spec.md v15 / design.md），聚焦 **v0.0.27 之后落地**的长程任务系统。
> 长程任务本质是「一切皆技能」理念下的 **L3 进程隔离轨插件 + 技能内 SKILL.md + COMPOSITION.yaml 编排**，由 AI 自主驱动从分钟级到天级任务的执行闭环。

## 1. 组件定位与职责边界

- **核心职责**：接收用户高层目标，由 AI 自主规划并驱动执行，实现「人设目标、AI 自主规划与执行、人评审交付」的闭环。
- **复用而非重建**（职责边界）：调度引擎（crontab + f_ticktock）、检查点（CheckpointManager + agent_contexts）、DAG 编排、Agent 执行器、AIP 协议、进度通知（WebSocket/SSE）、技能系统、三轨插件架构、评估调优（agent_loop_metrics）。

## 2. D-P-H-E 四层分层架构

长程任务的工程落地形态，各层职责清晰：

| 层 | 形态 | 职责 |
|----|------|------|
| **D 层（动态脚本）** | Python 脚本 | 承载业务逻辑，经 `cli_execute` 调用，通过 HTTP API 调 H 层宿主服务 |
| **P 层（L3 插件）** | 仓颉进程隔离轨插件 | 提供进程隔离的 CRUD + 自定义 handler + 幂等落库，`plugin.yaml` 声明 `mode:process` |
| **H 层（宿主服务）** | 仓颉宿主 | 提供 MCP 开放服务 + `host.db` + 行级权限 + 审计日志，凭证仅存宿主 `.env` |
| **E 层（技能定义）** | `SKILL.md` + `COMPOSITION.yaml` | 声明 SOP 与步骤编排（依赖关系、输入、YAML 步骤） |

**约束**：D 层脚本/插件不得直连数据库（经宿主 MCP/HTTP 调用）；凭证仅存宿主 `.env`；SSL 校验不可禁用；`tableWhitelist` 必须配置。

## 3. 6 步 SOP 全流程模式

长程任务统一遵循 **6 步 SOP**（三技能已跑通验证了共性）：

```
目标解析 → 任务规划 → 调度执行 → 进度通知 → 能力扩展 → 验核交付
```

- 每步都有明确的脚本/技能、输入、输出、验收条件。
- 步骤间通过文件系统传递中间产物，目录约定 `output/{阶段}/{标识}`（如 `output/raw → output/clean → output/factors → output/brief → output/sql`）。
- **禁止提前终止**：必须依次执行全部步骤，不得在任何中间步骤后直接跳到 answer 总结。

### COMPOSITION.yaml 编排声明

```yaml
name: long-running-task
version: 1.0.0
steps:
  - name: parse_goal
    step_type: script
    script: scripts/parse_goal.py
    depends_on: []
  - name: plan
    step_type: plugin
    plugin_route: /api/v1/uctoo/lrt/plan
    depends_on: [parse_goal]
  - name: aggregate
    step_type: output        # 产出聚合节点（第 7 个 step）
    depends_on: [plan]
```

- `step_type`：`script` / `plugin` / `output`。
- `depends_on`：声明 DAG 依赖（具传递性，禁止循环依赖）；空数组 = 可并行。
- `step.input`：支持 `${input.xxx}` / `${step-name.output}` / `${env.YYYYMMDD}`；**引用未就绪产出必须报错，禁止静默替换为空串**。
- 新增字段：`uses_tables`（按步注入数据契约）、`degradation_chain`（降级链）、`cwd`（必须真实生效）。
- **术语统一**：6 步 SOP + 1 个 `output` 聚合节点（共 7 个 step）。

## 4. 降级策略链（遇挫不停）

每个步骤声明工具优先级链，确保流程不中断：

```
cli_execute（已验证脚本）→ 内置工具（web_fetch / http_request）→ 大模型 → 模板降级
```

规则：

1. **遇挫不停**：任何步骤失败**先重试一次**（同一命令再跑确认是否偶发），重试仍失败才换方案，严禁遇挫即停、直接 answer。
2. **替代方案链**：重试失败 → 替代方案（脚本失败→降级 web_fetch→手工整理）；替代方案也失败 → answer 中明确报告「尝试了 X 次重试和 Y 种替代方案均失败」。
3. **部分失败隔离**：批量执行单条失败不中断批次，记录错误字段继续其他条目。

## 5. 产物校验与防回退

- **每步产物校验**：每步执行后必须 `file_read` 或 `cli_execute` 校验产出文件存在且非空，缺失则补执行。
- **answer 前终检**：返回 answer 前确认全部关键产出物均已存在，缺失则继续补执行。
- **任务完成判定**：不能因目录有旧文件就误判完成——必须检查**日期匹配 + 实际执行 SOP + 内容校验**（旧日期文件不算完成）。
- **防回退显式约束注入**：每轮修复必须增加防御性设计和错误行为示例（严禁复现），通过显式约束注入 SKILL.md，防止已修复问题复现。

## 6. 数据契约（让大模型准确操作数据库）

现状：`BuiltinToolsRegistry` 注册的 20 个内置工具中**没有任何数据库工具**，大模型只能靠 HTTP CRUD 路由或 Python 脚本间接落库，且看不到表结构与示例数据。

- **技能声明数据契约**：技能目录下提供 `DATA_CONTRACT.yaml`，声明本技能用到的表、字段（名/类型/必填/枚举/外键）、**幂等键**、写入规则、示例行。
- **runtime 提供结构查询工具**：`db_schema_lookup(table)` 返回 L1 结构契约，受 `tableWhitelist` + 行级权限同一套机制保护。
- **按步注入，控制 token**：仅注入当前步骤 `uses_tables` 声明的表（1-2 张），单回合结构信息 ≤ 2000 token。
- **幂等键必须声明**：写入规则写明「先查后写」（命中 UPDATE / 未命中 INSERT）。
- **禁止开放任意 SQL**：数据操作限定 `query` / `count` / `execute` 三类受控操作。

## 7. 执行内核健壮性（长程任务的承载底线）

> 编排层写得再完整，只要底层 ReAct 循环在第 N 步提前返回，任务照样跑不完。

1. **畸形输出必须重试，不得终止**：LLM 输出无已知标签（纯散文/半截标签），必须抛可修复异常 → 追加修复提示 → 重试；**严禁静默判为最终答案而结束循环**。
2. **最终答案必须有显式开标签**：判定为 answer 前必须确认输出流中存在 `<answer>` 开标签，不得仅凭「内容不像工具调用」推断。
3. **步数上限可配置**：`AgentExecutionExecutor.maxRounds`（同步）/ `Config.maxReactNumber`（异步）统一由 `plugin.yaml config.maxRounds` 驱动，默认建议 30。
4. **完成判定结构化**：废弃基于魔法字符串（如「## 完成总结」）的完成判定，改由 `LrtArtifactVerifier` 按产物清单结构化判定。
5. **两条链路同等要求**：长程任务链路（crontab → AgentExecutionExecutor）与用户实时提交链路（WebMCP → asyncChat → asyncRun）都必须满足上述 1-4。

## 8. 人在回路决策（AI 提供可选方案）

声明在技能，能力在 runtime：技能作者在 `SKILL.md` frontmatter 增加 `decision-points` 段，runtime 提供「怎么问、怎么等、怎么回灌」。

- 每个决策点须声明 `id` / 触发时机 / 问题 / 选项（`id`/`label`/`description`/`tradeoff`）/`default`/`recommended`/`timeout`。
- **必须有 default**：人类超时未选或通道不可用时自动采用默认项，记 `decision_timeout_default_applied` 日志，不挂死。
- 选项至少 2 项（仅确认/取消二值语义用普通审批）。
- 选择结果（id+label）写入回合上下文与 `agent_approvals.selected_option`，供后续步骤与追溯使用。

## 9. 可观测与可回溯

- **日志不被覆盖**：runtime 每次启动生成独立日志文件 `<basename>-<yyyyMMdd>-<HHmmss>.log`（追加模式）；保留期默认 14 天，只删符合命名模板的文件。
- **固定入口**：`logs/current-log.txt`（指针文件，内容为活跃日志相对路径），外部采集器先读它再定位活跃日志。
- **按任务可回溯**：每次长程任务生成 `trace_id`，贯穿全部回合/步骤/工具调用；支持按 `trace_id` 或 `task_id` 检索完整执行轨迹。
- **关键决策留痕**：规划/重规划/降级链/人在回路选择各写一条结构化（JSON 行）日志。
- **复用既有 trace 事件**：`trace_start` / `trace_step` / `trace_token_usage` / `trace_end`，不重复建模。

## 10. 关键数据约束

### agent_tasks（复用）状态机
`status`：0-待处理 / 1-进行中 / 2-完成 / 3-失败 / 4-已取消 / 5-暂停 / **6-等待下回合**。
- **禁止状态倒退**：进行中(1) 与 等待下回合(6) 可双向流转，但二者均不得回退到待处理(0)（置 0 会让任务被当新任务重派发，丢失回合上下文）。

### crontab（复用）调度配置
- `task`：`agent_execution://<agentId>`。
- `cron`：6 位格式（秒 分 时 日 月 周），须 f_ticktock 可编译。
- `status`：**必须显式写 1**（`CrontabPO.status` 默认 0，而 `SchedulerEngine` 只认 `status==1`，默认 0 时任务永不触发且无报错）。
- `timeout`：建议长程任务 1800（30 分钟）；`concurrentable` 建议 false；`once` 建议 false。

### plugin.yaml（L3 长程任务插件，真实被解析字段）
`name`(=long-running-task) / `mode`(=process) / `command` / `args` / `env` / `enabled` / `order` / `autoRestart` / `config`(含 `maxRounds`、检查点策略、质量闸门、降级链) / `tableWhitelist`(必须) / `routes`。
> `protocol` 字段**无解析代码，会被静默忽略**，不要写。

## 11. AI 驱动自进化闭环

长程任务系统的演进遵循五环节闭环，每轮优化基于**实测日志证据**而非猜测：

```
实测驱动 → 根因分析 → 增量优化 → 防回退 → 显式约束注入
```

- 根因分析：从日志定位底层代码/配置缺陷，而非只看表面现象。
- 增量优化：沿用原有架构复用现有基础设施，不重建已有能力。
- 问题分级：P0 阻断 / P1 严重 / P2 中等 / P3 低，按优先级修复。
- 前后端协同：前端产物需重新构建部署，代码修复正确但产物未重建会导致修复未生效。

> 扩展阅读：审计/传输口径（复用 `operate_log` 表，模块 `plugin`/`tool`；宿主直连 ORM 不走 `host.db` 避免递归）；幂等落库 `creator=userId` + 行级权限 + 批量隔离。详见 long-running-task design.md 附录 A 与 `audit-module-evaluation-20260915.md`。
