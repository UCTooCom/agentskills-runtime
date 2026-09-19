# long-running-task 接口文档

> AI 自主驱动长程任务系统插件（`mode=process` L3 进程隔离轨）。
> 本文档以磁盘代码为准，列出**用户 API**（HTTP 端点）与**插件 RPC**（JSON-RPC over stdio / host 透传）的真实接口面。

---

## 1. 用户 API（HTTP 端点）

路由前缀：`/api/v1/uctoo/long_running_task`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/add` | 创建长程任务（高层目标 → 解析 → 规划 → 建 crontab → 立即首回合） |
| POST | `/intervene/:taskId` | 人工干预：暂停 / 恢复 / 取消 / 调整目标（body `action` + 参数） |
| GET  | `/tree/:rootId` | 取任务树（含子任务层级与状态） |
| GET  | `/progress/:taskId` | 取实时进度（步状态 / 检查点 / 最近事件） |
| GET  | `/checkpoints/:taskId` | 取检查点列表 |
| POST | `/verify/:taskId` | 触发验核（产物结构校验 + 验核报告） |
| POST | `/evolve/:agentId` | 触发自进化闭环（实测驱动 → 根因 → 优化 → 防回退 → 约束注入） |
| POST | `/deliver/:taskId` | 交付决策：`confirm` / `abandon`（确认交付 → status=2；放弃 → status=4） |
| POST | `/review/:taskId` | 评审决策：`improve` / `abandon`（改进 → 触发 replan；放弃 → status=4） |
| GET  | `/trace` | 全量链路追踪（跨任务 trace 查询） |

> 注：spec §9.1 规划"7 个用户 API"，实际落地为 10 个端点（多出 `intervene` / `checkpoints` / `trace` 三个，能力更完整）。

### 1.1 通用请求/响应

- 鉴权：请求经 `requireUser` 提取用户身份（缺省按匿名处理，具体取决于宿主中间件）。
- 响应统一结构（成功）：
  ```json
  { "errno": 0, "errmsg": "ok", "data": { ... } }
  ```
- 响应统一结构（失败）：`errno != 0` + `errmsg` 描述；部分端点额外返回 `trace_id`。
- `deliver` / `review` 的 body 字段：
  - `deliver`：`{ "action": "confirm" | "abandon" }`
  - `review`：`{ "action": "improve" | "abandon", "feedback": "..." }`（`improve` 时 feedback 可为空，空则本地拦下不转发）
- 异常映射：参数缺失/非法 → `errno=400xx`；任务不存在 → `errno=404xx`；运行时错误 → `errno=500xx` 并附 `errmsg`。

---

## 2. 插件 RPC（JSON-RPC）

插件经 JSON-RPC over stdio 暴露以下方法（宿主 `CordisHostManager` 透传）。路径前缀 `/api/v1/uctoo/long_running_task`，方法名即路径末段：

| 方法 | 路径 | 说明 |
|------|------|------|
| `lrt-plan` | `/lrt-plan` | 目标解析 + 任务树规划，写 `agent_tasks` |
| `lrt-execute` | `/lrt-execute` | 执行回合循环（DAG 步骤分发 + 产物校验 + 检查点） |
| `lrt-intervene` | `/lrt-intervene` | 暂停 / 恢复 / 取消（与用户 API `intervene` 同源） |
| `lrt-verify` | `/lrt-verify` | 验核：产物校验 + 验核报告生成 |
| `lrt-evolve` | `/lrt-evolve` | 自进化闭环（见 §3） |
| `lrt-deliver` | `/lrt-deliver` | 交付决策收敛 |
| `lrt-review` | `/lrt-review` | 评审决策收敛（improve → replan） |

> 注：spec §9.1 规划"6 个插件 RPC"，实际落地为 7 个（多出 `lrt-intervene`）。

### 2.1 宿主侧消费的服务（host.*）

插件不直接连数据库，统一经宿主 host 服务：

| host 服务 | 用途 |
|-----------|------|
| `host.db` | 受控 CRUD：`query` / `count` / `execute`，受 `tableWhitelist` + 行级权限约束 |
| `host.db_schema_lookup` | 取表结构 + 幂等键 + 示例行（数据契约注入用） |
| `host.mcp` | 调用宿主统一 MCP 开放服务 |
| `host.event` | 推送结构化事件（评审 / 漂移 / 进度） |
| `host.cache` | 共享缓存 |
| `host.log` | 结构化日志 |

---

## 3. 事件（SSE / WebSocket 广播）

插件经 `LrtEventRelay` → `LrtEventBridge` 推送到前端的 `lrt_event` 事件（前端在 `eventStream.ts` 经 `onLrtEvent` 回调消费，**不翻译为气泡、不视为终态**）：

| 事件 type | payload 关键字段 | 前端动作 |
|-----------|------------------|----------|
| `step_start` / `step_complete` / `step_failed` | taskId, step, status | 进度展示 |
| `checkpoint_saved` | taskId, checkpointId | 进度展示 |
| `progress_update` | taskId, message | 进度展示 |
| `subtask_dispatched` / `subtask_completed` | taskId, subtaskId | 进度展示 |
| `goal_achieved` | taskId, goalAchievement, artifactCount, summary | 进度展示 |
| `review_required` | taskId, goal, summary, goalAchievement | 弹出 `ReviewCard`（确认交付 / 要求改进 / 放弃） |
| `contract_drift` | findings[] | 告警提示 |

---

## 4. 人在回路决策点（decision-points）

`SKILL.md` frontmatter `decision-points` 声明 6 个结构化决策点，每个含 `id` / `when` / `question` / `options[]`(id+label+description+tradeoff) / `default` / `recommended` / `timeout_seconds`：

`pause` / `resume` / `cancel` / `replan` / `human_confirm` / `review`

宿主在 `web_request_approval` 调用时按 `skillName=long-running-task` + `decisionPointId` 校验决策点是否仍生效；失效则工具自动降级为普通"批准/拒绝"审批。

---

## 5. 数据契约

插件写入的表通过 `DATA_CONTRACT.yaml` 声明（含 `idempotent_key` / `write_rules` / `sample_rows`），运行时经 `host.db_schema_lookup` 按步注入到 ReAct system prompt（单回合 ≤ 2000 token）。相关表：`agent_tasks` / `agent_contexts` / `long_running_task_artifact` / `long_running_task_evolution` / `agent_approvals` 等。

---

## 6. 端到端流程

```
用户消息 "长程任务: <目标>"
  → WebMCPProtocol 前缀命中 → handleLongRunningTaskRoute
  → lrt-plan（规划）→ lrt-execute（回合循环：步骤分发→产物校验→检查点→进度推送）
  → lrt-verify（验核报告）
  → 推送 review_required 事件 → 前端 ReviewCard
  → 用户选择 → lrt-deliver(confirm)→status=2 / lrt-review(improve)→replan
  → （可选）lrt-evolve 自进化闭环 → 防回退约束注入 SKILL.md
```

> 文档更新请以 `src/app/routes/uctoo/long_running_task/LongRunningTaskRoute.cj` 与 `skills/long-running-task/plugin.yaml` 的代码为准。
