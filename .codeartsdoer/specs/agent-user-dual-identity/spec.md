# 需求规格：Agent / 用户双账号身份、委派路由与 creator 归属

## 文档信息
- **规格名称**: agent-user-dual-identity
- **版本**: 1.0.0
- **创建日期**: 2026-09-20
- **作者**: AI-Driven Development Framework
- **状态**: 草稿（决策已拍板，待实现）
- **关联问题**: 两次长程任务失败排查（2026-09-19 日志 + public20260920.sql）引出的身份/路由根因

---

## 1. 概述

### 1.1 项目背景

`agentskills-runtime` 采用「agent 与人类行为对齐」设计哲学：agent 是 `uctoo_user` 表的一等公民，拥有独立
帐号与 id。长程任务（LRT）子系统已具备完整路由（`WebMCPProtocol` 前缀触发 → `LongTaskApiService.submitTask`
→ `LrtPluginClient` 插件执行），但当前存在三类不一致：

1. **委派路由表达偏差**：复杂任务不会自动走 LRT，需显式前缀；而此前在 AGENTS.md 写入的「调用 long-running-task
   工具」规则指向的是一条**空实现的死路**（`SkillToToolAdapter`→`BaseSkill.execute`），导致模型与人类都不知道
   如何正确地把复杂任务委派给 LRT。
2. **creator 归属失真**：LRT 全流程把人类用户的 `userId` 当作 `creator` 写入，**agent 从不作为执行者出现**，
   违反「agent 操作如实记 agent 帐号」的对齐哲学，也削弱责任追溯与权限隔离。
3. **agent 身份未接入运行时**：agent 自动登录仅存在于 AIP 互联端点，本地 WebMCP 路径未触发；agent 的 token
   是孤立的、未被注入 `TokenManager`，出站调用无法以 agent 身份进行。

### 1.2 项目范围

**包含**：
- LRT 委派触发规则在 AGENTS.md / SKILL.md 的准确表达（前缀路由，非技能工具）
- `long_running_task` / `agent_tasks` 增加 `owner_user_id` 字段，并改写 `submitTask` 的 creator/owner 语义
- agent 本地自动登录接入 WebMCP 会话（config 密钥，与用户同钥）
- 审计日志 `resolveAuditActorType` 按 `uctoo_user.userType` 区分 agent/user/system
- `AutoRouteRegistry.cj:110` 硬编码密钥统一为 config 密钥

**不包含**：
- AIP 互联模式（`/aip/*`）的 `aip-agent-secret-key` 体系改造（保持 AIP 专用，本规格不涉及）
- 死路 `SkillToToolAdapter`→`BaseSkill.execute` / `LrtCompositionRunner` 的清理（列为可选 T8，不阻塞主链路）
- 权限模型细粒度重构（`data_access_authorization` 对 agent 帐号的授权策略，见 design.md 风险项）

### 1.3 术语定义

| 术语 | 定义 |
|------|------|
| MainAgent | 主 Agent，前端 WebMCP 会话绑定的对话 Agent |
| LRT | Long Running Task，长程任务子系统（规划→调度→插件执行→多回合） |
| creator | 实际执行写操作的主体 id（本规格：agent 自主执行 = agent 的 uctoo_user.id） |
| owner_user_id | 任务归属的真人用户 id（始终 = 委派/拥有任务的人类） |
| WebMCP | Web Model Context Protocol，前端注册为工具供 Agent 调用的协议，也是前端聊天通道 |
| 本地模式 | agentskills-runtime 内部 Agent 协作，复用 uctoo_user + RBAC，不启用 AIP 互联特性 |
| AIP 互联模式 | GB/Z 185 智能体互联，使用 `aip-agent-secret-key`，仅 `/aip/*` 端点 |

---

## 2. 功能需求

### FR-1：复杂任务委派规则准确化

- **FR-1.1** AGENTS.md 的委派规则须指引：复杂/多步/需持久化/AI 自主编排的任务，使用
  **`长程任务：<目标>` 或 `/lrt <目标>` 前缀**提交（对应 `WebMCPProtocol` 已实现的 `LRT_TRIGGER_PREFIXES`）。
- **FR-1.2** 移除/改写此前误指的「调用 `long-running-task` 工具」表述（该工具走 `BaseSkill.execute` 空实现死路）。
- **FR-1.3** `skills/long-running-task/SKILL.md` 同步说明：本技能由 **WebMCP 前缀路由**触发，非 Agent 工具调用。

### FR-2：creator / owner 双字段归属

- **FR-2.1** `long_running_task` 表新增 `owner_user_id`（人类所有者），`agent_tasks` 表同新增。
- **FR-2.2** `LongTaskApiService.submitTask` 改写：`creator = agent 的 uctoo_user.id`（执行者），
  `owner_user_id = WebMCPProtocol 透传的人类 userId`（所有者）。
- **FR-2.3** `LrtPluginClient.plan/execute` 透传 `creator` 与 `owner_user_id`，插件侧按此落库。
- **FR-2.4** 历史数据 `owner_user_id` 允许为 NULL（回溯前无此概念），新写入强制双字段。

### FR-3：agent 本地自动登录接入运行时

- **FR-3.1** `AgentAuthService.agentAutoLogin` 增加 `mode` 参数：本地模式用 **config JWT 密钥**（与用户同钥），
  互联模式用 `aip-agent-secret-key`（保持 AIP 专用）。
- **FR-3.2** WebMCP 会话建立（携带 userId）时，触发 agent 本地自动登录，将 agent token 存入 `TokenManager`
  （独立 agent sessionId），供 LRT 取用。
- **FR-3.3** agent 的 token 可被 `DeserializeUserMiddleware` 用 config 密钥验过（无需并入 AIP 密钥）。

### FR-4：审计 actorType 区分

- **FR-4.1** `OperateLogService.resolveAuditActorType` 依据 `uctoo_user.userType` 判定 `agent`/`user`/`system`，
  而非仅凭 userId 非空即记 `user`。

### FR-5：密钥一致性

- **FR-5.1** `AutoRouteRegistry.cj:110` 硬编码 `uctoo-v4-secret-key` 改为引用 config `jwtSecret`，
  消除与 `main.cj:480` 不同源的静默 401 风险（影响 long_running_task 系列路由）。

---

## 3. 非功能需求

- **NFR-1 兼容**：`aip-agent-secret-key` 行为不变，AIP 互联端点继续可用。
- **NFR-2 最小侵入**：以 WebMCP 前缀路由为活路，不做执行链路大改；死路 `SkillToToolAdapter` 清理列为可选。
- **NFR-3 可审计**：所有 agent 自主写操作可追溯到具体 agent 帐号与人类 owner。
- **NFR-4 安全**：agent 用自身 token 出站时，受 `data_access_authorization` 行级权限约束（详见 design.md 风险）。

---

## 4. 验收标准

- 用户用「长程任务：查找去年高考物理题并解题」提交，任务进入 `long_running_task` 表，`creator` = agent id，
  `owner_user_id` = 人类用户 id，且任务能跑完（结合已修复的 P0 静默死亡 bug）。
- AGENTS.md / SKILL.md 委派规则与 `WebMCPProtocol.LRT_TRIGGER_PREFIXES` 一致。
- agent 本地自动登录在 WebMCP 会话建立时触发，token 进入 `TokenManager`，出站调用可携带。
- 审计日志区分 agent/user 行为。
- `AutoRouteRegistry` 与 `main.cj` 使用同一把 config 密钥。
