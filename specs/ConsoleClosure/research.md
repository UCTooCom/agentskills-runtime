# 三端能力盘点与缺口分析（research）

> SDD 主工程：`ConsoleClosure`（三端能力补全）
> 落点：`specs/ConsoleClosure/research.md`
> 阶段：`research`（步一）
> 状态：待闸口确认（gate-research）
> 铁律依据：铁律 1（用户显式指定输出目录优先）、铁律 12（落盘优先于说清楚）、铁律 15（大工程拆分）

---

## 1. 研究背景与目标

### 1.1 起因

用户需要一篇面向最终用户的完整产品文章，并要求截图 Web 端与 PC 端全部界面。执行过程中发现：**服务端大量能力没有任何用户界面承接**。

### 1.2 研究目标

1. 盘点 `apps/agentskills-runtime` 服务端对外暴露的全部功能，形成能力基线；
2. 盘点 `apps/web-admin` 与 `apps/pc-client` 已实现界面，形成覆盖基线；
3. 交叉比对，产出「服务端有能力、前端无界面」的缺口矩阵，作为后续开发路标。

### 1.3 盘点方法

| 手段 | 说明 |
|---|---|
| 源码路径 + 行号取证 | 每个结论必须能指到具体文件的具体行，**禁止凭印象** |
| 三端交叉验证 | 服务端 → Web → PC 逐项比对，单端结论不采信 |
| 二次抽样复核 | 对 Agent 初判结论抽样 `grep` / `sed` 复核后才落本文档 |

**重要判读口径**：`src/views/database/uctoo/<实体>/index.vue` 这类页面是 `crudweb` 批量生成的**表记录增删改查**，
不是业务界面。它们会让"页面数"看起来很大，却掩盖业务能力真空。**盘点时必须把"表 CRUD 页"与"业务界面"分开计。**

---

## 2. 服务端能力基线

**版本**：CHANGELOG.md 最新 `0.0.25`（2026-07-23）

### 2.1 路由注册机制（这是读懂服务端的关键）

`src/app/routes/uctoo/` 下并非"只有一个 pkg.cj"，实为 **90 个 `XxxRoute.cj`**。真正的集中注册链路：

| 环节 | 证据 |
|---|---|
| 启动入口 | `src/app/main.cj:580-581` → `AutoRouteRegistry(router).registerAllRoutes()` |
| 注册器 | `src/app/registry/AutoRouteRegistry.cj:74-87` |
| **配置表（真正的注册点）** | `src/app/registry/AutoRouteConfig.cj:286-1529`，共 **87 条 `RouteEntry`**（`entity` 条目被注释，实际生效 **86** 条） |
| 条目结构 | `src/app/registry/RouteEntry.cj:13-42` |
| 排序注册 | `src/app/registry/RouteRegistry.cj:52-62`，按 priority 升序 |
| 非 CRUD 路由 | `main.cj:591`(Skill) `618`(Tool) `625`(WebMCP) `635`(AI) `644`(Sync) `651`(McpOpen) `656`(Aip) |
| WebSocket | `main.cj:630-631` |
| 插件动态路由 | `main.cj:913` `PluginRouteScanner.scanAndRegister`；扫描器 `src/plugin/plugin_route_scanner.cj:30` |

每表标准 CRUD 壳 = 9 个端点：`add / edit / del / export / empty-recycle-bin / :id / :limit / :page / :limit/:page/:skip`。

### 2.2 八域功能清单（节选带证据代表项，完整量见 §2.3）

| 域 | 代表能力 | 关键证据 |
|---|---|---|
| **LLM 通道** | 通道 CRUD、list、catalog、health、audit、models、import/export、reload、toggle、default、test、sync-models、probe；路由规则 list/shadow-stats/evaluate；用量日志；模型定价；Token 统计 summary/by-agent/by-model；计费日报/月报/CSV；OpenAI 兼容 `/api/v1/ai/*` | `AutoRouteConfig.cj:1315`；`SkillRoutes` 同级 `LlmChannelRoute.cj:54-74`；`AutoRouteConfig.cj:1464-1480` |
| **技能 / 插件** | 技能 list/detail/content/add/edit/del/execute/search；合规校验 validate / validate-security / execute-secure / validate-all；用量 increment-usage / top-used；技能组合；Agent-技能绑定；插件 inspect/activate/deactivate/refresh；插件动态路由扫描；运行时增量发现（60s reconcile） | `SkillRoutes.cj:68-103`；`AutoRouteConfig.cj:1519-1522`；`main.cj:602-606, 913, 929-974` |
| **Agent 与任务** | Agent  CRUD/main/关联技能；上下文 / 消息 / 任务 / 记忆；群组 / 成员；执行器 + 切换策略；人工审批；循环指标 evaluate/dashboard/tuning-configs；子 Agent 调用记录；编排计划 / 步骤；看板 by-state/update-state/assign；**长程任务 LRT 九动作**；**SDD 六步编排**；任务 / 公司 / 站内消息；积分结算配额；监控仪表板 | `LongRunningTaskRoute.cj:43-80`；`SddOrchestrationRoute.cj:26-36`；`AgentDashboardController.cj:16` |
| **MCP / AIP 协议** | MCP Streamable HTTP；MCP 开放调用；WebMCP HTTP/SSE/WS + 运维端点；AIP 身份（本地/互联注册、启停、锁定、吊销、登录）；能力描述注册/发布/更新；发现与缓存；会话与消息；配置与模式切换；健康检查 | `routes/aip/AipRoute.cj:29-66`；`routes/webmcp/WebMCPRoutes.cj:40-98`；`routes/mcpopen/McpOpenRoutes.cj:16-17` |
| **数据 CRUD 基础设施** | 86 张表 × 9 端点；`loaddbinfo` / `crudgen` / `crudweb` / `plugingen` 四个确定性代码生成器；数据源连接 db_connection | `AutoRouteConfig.cj:286-1529`；`DbInfoRoute.cj:51-64` |
| **系统运维** | health / info / ops:logs / ops:env；crontab CRUD + trigger/pause/resume/reload/scheduler-status/running/executors/builtin-tasks；文件↔库双向同步 summary/status/from-fs/to-fs/all/logs/health；配置管理 metadata/export-config/batch/import/key；操作日志 / 登录日志 / 短信日志；事件处理器管理；国际化 | `main.cj:661-745`；`CrontabRoute.cj:56-60`；`SyncRoute.cj:31-61`；`AutoRouteConfig.cj:1492-1496` |
| **权限认证** | 登录 / 注册 / 登出 / me / 改密 / 验票；用户 / 会话 / 角色 / 组 RBAC；权限项与授权；**路由自发现**（反射导出全部路由供授权绑定）；数据访问授权（行级）；应用与令牌 | `UctooUserAuthRoute.cj:42-68`；`PermissionsRoute.cj:59-76`；`DataAccessAuthorizationRoute.cj:50-52` |
| **多模态与文件** | 附件 CRUD + upload；多模态解析分发；图像理解工具；COS 存储 | `AttachmentsRoute.cj:54`；`src/plugin/multimodal/parse_dispatcher.cj:45` |

### 2.3 服务端规模

| 口径 | 数量 |
|---|---|
| 已注册 HTTP 端点（去重 method+path） | **793** |
| ├ CRUD 自动生成壳 | 632 |
| └ 业务 / 运维扩展端点 | 161 |
| `AutoRouteConfig.cj` 内联注册 | 24 |
| `main.cj` 内联注册 | 4 |
| **静态 HTTP 小计** | **821** |
| WebSocket | 2 |
| 插件运行时动态路由 | ≈153 |
| **合计** | **≈976** |

controller 文件 112 个；route 文件 95 个；`RouteEntry` 87 条（86 生效）；内置工具 23 个 + 宿主注入工具 8 个。

---

## 3. web-admin 覆盖基线

### 3.1 路由架构（关键）

`src/router/constant.ts` 仅挂载 **6 条静态路由 + aibuilder + website 两个模块**。
**其余管理后台页面（ai/*、database/*、chat、user、role、permission、menu、system）没有静态路由**，
由 `src/router/guard/menu.ts` 的 `toRoutes()` 在运行时根据后端返回菜单树动态 `router.addRoute('root', ...)` 注入。

- 菜单数据源：`POST /api/v1/uctoo/permissions/user/menu`（`src/store/models/uctoo/user_menu.ts`）
- 组件解析：`views/${menu.component}.vue`（`src/router/guard/menu.ts:79`）

### 3.2 已实现业务界面（真正手写的人机界面）

| 分组 | 页面 | 源码 |
|---|---|---|
| 登录 | 登录页（含注册/找回/后端地址配置） | `src/views/login/index.vue` |
| AI 中心 | 模型通道管理（732 行，能力最全） | `src/views/ai/model_channel/index.vue` |
| | 路由规则 + 影子对比 | `src/views/ai/model_channel/route-rule.vue`、`shadow-compare.vue` |
| | Agent 监控仪表板 / Agent 详情 / Agent 技能 | `src/views/ai/agent_monitor/`、`agent_detail/`、`agent_skills.vue` |
| | Token 统计仪表板 / 计费报表 | `src/views/ai/token_dashboard/`、`billing_report/` |
| | 数据流可视化 / 全链路可观测时间线 | `src/views/ai/data_flow/`、`observability_timeline/` |
| 聊天 | AI 助手聊天 | `src/views/chat/index.vue` |
| AI Builder | 14 个页面：任务广场/详情/创建/我的任务/组织/成长/创建/个人中心/消息中心/我的关注 | `src/views/aibuilder/**`（静态路由 `/vue-pro/aibuilder/**`） |
| 官网 | 10 个静态展示页 | `src/views/website/**` |
| 权限管理 | 用户/角色/权限/菜单/系统配置（**已实现但路由模块未挂载**） | `src/views/{userManager,role,permission,menu,system}/**` |

### 3.3 规模与"水分"

| 项 | 数量 |
|---|---|
| 实际挂载静态路由记录 | **31** |
| 已定义但未挂载的路由记录 | 37（15 个 `src/router/routes/modules/*.ts` 中仅 2 个被 import） |
| 页面级 .vue 文件 | 179 |
| 全部 .vue（含子组件） | 517 |
| **其中 database/uctoo 表 CRUD 页** | **82**（非业务界面） |
| `src/store/models/uctoo/` ORM 模型数（**真正接口全集**） | **97** |

> 注意：`src/api/*`（15 个文件）是模板遗留 thin 层，**真正的接口全集在 `src/store/models/uctoo/*.ts` 的 97 个 Model**。
> 判断"有接口无界面"缺口时应以这 97 个模型为准。

---

## 4. pc-client 覆盖基线

### 4.1 架构（与常规 electron-vite 不同）

| 部位 | 路径 |
|---|---|
| 渲染进程根 | `src/` |
| 主进程 | `electron/main/index.ts`（单入口 1138 行） |
| 主进程模块 | `electron/modules/*.ts`（26 个） |
| preload | `electron/preload/index.ts` |
| IPC 注册 | **全部 64 个通道集中在 `electron/main/index.ts`**，经 `electron/modules/ipc.ts:20` 统一封装 |

### 4.2 渲染进程 8 条路由（`src/router/index.ts:4-52`）

| 页面 | 源码 | 实质 |
|---|---|---|
| 首页（内嵌 Web 管理端） | `src/views/HomeView.vue`(288) | **iframe** 承载 web-admin 静态站，含 5 次重试 |
| 首次运行向导 | `src/views/setup/SetupView.vue` | 4 步：欢迎→AI 模型→数据库模式→建号 |
| 技能管理 | `src/views/skills/SkillsView.vue`(51) | ⚠️ **假实现**（见 §6-A7） |
| 智能体管理 | `src/views/agents/AgentsView.vue`(23) | ⚠️ **死页面**（`agents` 恒为 `[]`） |
| Runtime 监控 | `src/views/runtime/RuntimeStatus.vue`(85) | 状态/PID/端口/版本，5s 轮询 |
| PostgreSQL 管理 | `src/views/pgsql/PgsqlView.vue`(329) | 三 Tab：状态/备份恢复/连接测试 |
| 系统设置 | `src/views/settings/SettingsView.vue`(651) | 6 组配置 |
| 关于 | `src/views/AboutView.vue`(159) | 版本/更新/外链 |

### 4.3 主进程原生能力（PC 端真正的核心差异）

**64 个 IPC invoke 通道**：系统配置 15 / 初始化建号 5 / Runtime 进程管理 11 / PostgreSQL 实例管理 8 / WebAdmin 静态站与环境同步 8 / 认证+依赖+更新+自启+技能 14。
另有 **9 个推送事件**：`runtime:stateChanged`、`pgsql:stateChanged`、`webadmin:stateChanged`、`auth:loginStateChanged`、`bootstrap:progress`、`runtime:integrateProgress`、`service:startFailed`、`service:postgresqlReuse` 等。

preload 暴露 13 个方法组；**窗口仅 1 个 BrowserWindow + 1 Tray**，3 个入口 HTML（loading/setup/home）在同一窗口切换。

### 4.4 关键结论：PC 端没有原生登录页

登录完全在 iframe 内的 web-admin 完成，token 经 `postMessage` → `HomeView.vue:47-51` → `auth:saveToken` → 主进程 `safeStorage` 加密保存（`electron/modules/auth-bridge.ts:87`）。

**PC 端定位（用户 2026-10-29 拍板）：核心运维原生 + 业务 iframe（混合模式）。**

---

## 5. 三端缺口矩阵

判定口径：**服务端有 HTTP 能力 / 有控制器实现，但 Web 端无业务界面（仅有表 CRUD 页不算）、PC 端无原生或非 iframe 集成页面**，计为缺口。

### 5.1 P0 —— 核心能力，服务端完整实现，前端零界面

| 编号 | 缺口 | 服务端证据 | 前端现状 |
|---|---|---|---|
| **A1** | 技能市场 / 目录浏览 | `/api/v1/uctoo/skills`、`/skills/search`（`SkillRoutes.cj:68,103`） | 无。仅有 `agent_skills` **绑定关系表** CRUD |
| **A2** | 技能安装 / 卸载 / 更新 | `/skills/add`、`/edit`、`/del`（`SkillRoutes.cj:83,88,93`） | 无 |
| **A3** | 技能详情与内容查看 | `/skills/:id`、`/skills/:name/content`（`SkillRoutes.cj:73,78`） | 无 |
| **A4** | 技能合规校验结果展示 | `/skill/validate`、`/validate-security`、`/validate-all`（`AutoRouteConfig.cj:1519-1522`） | 无 |
| **A5** | 技能用量统计可视化 | `/skill_usage_stats/increment-usage`、`/top-used`（`SkillUsageStatsRoute.cj:53,54`） | 仅有 `skill_usage_stats` 表 CRUD |
| **A6** | 插件运行时管理 | `plugin_inspect/activate/deactivate/refresh`（`main.cj:602-606`，`src/plugin/plugin_agent_tools.cj`） | 无（这些是经 `/api/v1/tools/:toolName` 暴露的工具） |
| **A7** | PC 端技能页打通 | — | ⚠️ `electron/main/index.ts:583-585` 硬编码 `return {success:true, data:[]}`；`skills:getDetail`/`skills:install` 直接 `return {success:false, error:'Not implemented'}`（已复核属实） |
| **A8** | PC 端智能体页打通 | — | ⚠️ `AgentsView.vue:4` 写死 `const agents = ref<any[]>([])`，无任何 IPC 调用（已复核属实） |
| **B1** | LRT 任务树可视化 | `/long_running_task/tree/:rootId`（`LongRunningTaskRoute.cj:43-80`） | 无。仅有 `long_running_task_artifact` / `_evolution` / `lrt_verify_job` 三张附属表 CRUD |
| **B2** | LRT 进度与检查点 | `/progress/:taskId`、`/checkpoints/:taskId` | 无 |
| **B3** | LRT 人工干预 | `/intervene` | 无（人机回路能力的门面） |
| **B4** | LRT 核验 / 交付 / 评审 | `/verify`、`/deliver`、`/review` | 无 |
| **B5** | LRT 演进与追踪 | `/evolve/:agentId`、`/trace` | 无 |
| **B6** | SDD 流水线可视化（六步） | `/api/v1/uctoo/sdd/*`（`SddOrchestrationRoute.cj:26-36`） | 仅有 `sdd_projects` 表 CRUD |
| **B7** | SDD 闸口决策界面（5 个 gate） | SKILL.md `decision-points` 5 个点 + `/sdd/review` | 无 |
| **B8** | SDD 阶段产物查看 | 产物落 `long_running_task_artifact` | 无 |

### 5.2 P1 —— 协议、运维与治理

| 编号 | 缺口 | 服务端证据 |
|---|---|---|
| **D1** | MCP Server 管理（Streamable HTTP 运维） | `src/app/routes/uctoo/mcp/McpRoute.cj:25,27`；注册于 `AutoRouteRegistry.cj:148-159` |
| **D2** | MCP 开放工具目录与调用 | `McpOpenRoutes.cj:16,17` |
| **D3** | AIP 身份管理（本地/互联注册、启停、锁定、吊销） | `AipRoute.cj:29-39` |
| **D4** | AIP 能力描述发布 / 更新 | `AipRoute.cj:41-45` |
| **D5** | AIP 发现与缓存运维 | `AipRoute.cj:47-51` |
| **D6** | AIP 会话与消息查看 | `AipRoute.cj:53-59` |
| **D7** | AIP 模式查询与切换、健康检查 | `AipRoute.cj:61-66` |
| **D8** | 工具网关管理（列表/详情/权限/审计） | `ToolRoutes.cj:39,44,49` |
| **E1** | 运行日志在线查看 | `main.cj:720-735`（`ops/logs`） |
| **E2** | 环境能力采集与冒烟 | `main.cj:738-745`（`ops/env`） |
| **E3** | 健康检查 / 应用信息面板 | `main.cj:661-705`（`/api/v1/health`、`/api/v1/info`） |
| **E4** | crontab 运维操作（trigger/pause/resume/reload/scheduler-status/running/executors/builtin-tasks） | `CrontabRoute.cj:56-60` |
| **E5** | 文件↔库同步运维操作 | `SyncRoute.cj:31-61`（Web 的 `data_flow.vue` 覆盖部分） |
| **E6** | 事件处理器管理 | `AutoRouteConfig.cj:1492-1496` |
| **E7** | 执行器切换 | `AutoRouteConfig.cj:1508-1510` |
| **E8** | 数据访问授权（行级权限） | `DataAccessAuthorizationRoute.cj:50-52` |
| **E9** | 国际化管理 | 组件存在但无路由：`src/views/locale/index.vue`(36) |
| **C1** | 模型定价维护 | 仅 `model_pricing` 表 CRUD |
| **C2** | 用量配额治理 | 仅 `usage_quotas` 表 CRUD |
| **C3** | 用量明细查询 | 仅 `llm_usage_logs` 表 CRUD |
| **C4** | 通道健康历史可视化 | 仅 `llm_channel_health` 表 CRUD |
| **C5** | 通道审计日志可视化 | 仅 `llm_channel_audit` 表 CRUD |

### 5.3 P2 —— 增量体验

| 编号 | 缺口 | 说明 |
|---|---|---|
| **G1** | 审批工作流界面 | `agent_approvals` 有表 CRUD，无"待我审批/批准/拒绝"工作流 UI |
| **G2** | 看板任务拖拽与状态流转 | `/agent_kanban_tasks/by-state`、`/update-state`、`/assign` 无 UI |
| **G3** | 技能组合编排与执行 UI | `skill_compositions` / `composition_executions` 仅表 CRUD |
| **G4** | 权限管理路由挂载 | user/role/permission/menu 页面已实现但 `constant.ts` 未 import（37 条未挂载） |
| **G5** | `setup.vue` 初始化页挂载 | `src/views/setup.vue`(235 行) 未挂载 |
| **G6** | PC 端多通道管理 | 当前仅 Settings 里单条 AI 配置，无多通道列表与切换 |

### 5.4 横切 P0 —— 服务端实现了，但**连 HTTP 都没暴露**

这条不属于任何单一交付面，是多个子系统（尤其 C、E）的共同前置：

| 控制器 | 位置 | 后果 |
|---|---|---|
| `MemoryController` | 存在，无路由绑定 | 记忆管理能力无法访问 |
| `ModelController` | 存在，无路由绑定 | 模型管理无 API |
| `StorageController` | 存在，无路由绑定 | 存储管理无 API |
| `RetrieverController` | 存在，无路由绑定 | **矢量库 / RAG 检索无 API** |
| `ExecutorController` | 存在，无路由绑定 | 执行器管理无 API |

另有 4 个文件是**完全未注册的死代码**：`MockRoute.cj`、`AiDevDemoRoute.cj`、`LanguageOrchestrationRoute.cj`、`PublicCompaniesRoute.cj`/`PublicTasksRoute.cj`（仅被 import）。

---

## 6. 结论与拆分建议

### 6.1 核心判断

不是"某个页面忘了做"，而是**结构性失衡**：服务端把能力做得很深（≈976 端点），承接它们的界面建设严重滞后。

最刺眼的一点：**技能是这套系统的核心卖点**（ASR 自进化、RSI 五阶段闭环都构建在技能之上），
却既没有 Web 管理界面，PC 端还是 `Not implemented` 的假实现。这一条应列为最高优先级。

### 6.2 拆分必要性（铁律 15 判据）

| 判据 | 阈值 | 实测 | 命中 |
|---|---|---|---|
| 任务规模 | 单工程 tasks.md > 40 条 | P0+P1 共 33 项缺口，每项平均 4-6 条任务，预计 **150+ 条** | ✅ |
| 语言/技术栈 | ≥ 3 条标签 | cangjie（服务端补路由）+ web（Vue）+ app（Electron） | ✅ |
| 交付面 | ≥ 3 个独立上线边界 | 技能控制台 / 任务编排台 / 协议网关 / 运维台 / 桌面端 = 5 个 | ✅ |
| 上下文预算 | 单工程 code 步两轮内跑不完 | 远超 | ✅ |

**命中 4 条判据，按铁律 15 必须拆分。**

### 6.3 拆分方案（按交付面优先）

用户 2026-10-29 拍板：**拆 6 个子系统 + PC 端混合模式**（核心运维原生 + 业务 iframe）。

| ID | 中文名 | 承载缺口 |
|---|---|---|
| `S1` | 技能与插件控制台 | A1-A8 |
| `S2` | 长期任务与 SDD 编排台 | B1-B8 |
| `S3` | LLM 通道与成本治理 | C1-C6 |
| `S4` | 协议网关运维 | D1-D8 |
| `S5` | 系统运维与可观测 | E1-E9 + 横切能力暴露前置 |
| `S6` | 桌面端纵深 | A7、A8、F3、G6（混合模式落地） |

详细登记表、契约汇总与依赖 DAG 见 `SPECS_INDEX.md`。

---

## 7. 待办 / 风险

| 项 | 说明 |
|---|---|
| 版本口径 | CHANGELOG 最新为 `0.0.25`，但 people/上下文提到 v0.0.30。**写文章前需确认真实版本** |
| 动态菜单 | web-admin 管理页路由由后端 `permissions/user/menu` 返回，仓库内无固定清单；**新增业务界面必须同步登记菜单，否则用户看不到入口** |
| 截图前置 | 写文章需 runtime + web-admin + pc-client 全起来；用户选择先写 SDD，截图后置 |

---

## 8. 实读修正日志

> 撰写 6 份子系统 spec 时，各撰写者回到源码逐条复核，**以下发现修正了本文档前序章节的口径，以本节为准**。
> 这几条正是"拍脑袋盘点"与"真读源码"的分水岭，后续 design / tasks 步必须以本节为准。

| # | 原口径 | 实读修正后的真相 | 影响 |
|---|---|---|---|
| **M1** | E4 端点含 `crontab/scheduler-status` | 实际路径为 **`/crontab/scheduler/status`**（点号分隔，非连字符） | 契约 C-021 路径需订正 |
| **M2** | §5.4 横切 P0 描述为"控制器存在但未绑路由"，读起来像"能力已实现、只是忘了开接口" | **`RetrieverController.search` 与 `StorageController` 的 kv / vector 方法实为占位桩**，并非完整实现。不是"忘开路由"，而是"**尚未实现完**" | **性质变更，影响最大**：S5 的能力暴露前置从"补个路由"升级为"先实现、再补路由"，工作量显著增大；且必须对外标注"已暴露但未真正接入"，**不得向前端谎称可用** |
| **M3** | E5 注明"Web 的 `data_flow.vue` 覆盖部分" | **`src/views/ai/data_flow/index.vue` 实际未调用任何 sync 端点** | E5 从"补齐"更正为**全新建设**。另：该页面宣称展示文件↔库同步流却无数据支撑，属既有缺陷，单列 P2 记录 |
| **M4** | C1-C5 五张表"仅有表 CRUD"（推测） | 已复核**属实**：五张表均只有 crudgen 生成的 CRUD 壳，无自定义路由 | 维持 P1 判定 |
| **M5** | （原未发现） | **`SkillUsageStatsService.incrementUsage()` 全仓无调用点** → `skill_usage_stats` 的用量字段**不会自动累加** | **新增 P1 缺陷**：用量统计数据实际不增长。S1 的 A5 技能用量可视化会以空数据开局，须先修埋点 |
| **M6** | （原未发现） | **用量聚合端点硬扫描 10000 条记录且忽略入参 limit** | **新增 P2 性能缺陷**：随数据量增长将劣化，S3 需在 design 步处理 |
| **M7** | A8（PC 端智能体页）归属未明确 | S1 与 S6 均涉及，需主工程闸口裁定 | **建议归 S6**（桌面端纵深）：它是 PC 原生页面；S1 只负责提供 API 契约 |

### 修正后的优先级变化

- **M2 使 S5 的前置工作量显著上升**，且它是 S2 / S4 的开工前提 —— 主工程排期时应把 S5 的「能力真正实现」而非「路由绑定」作为里程碑口径。
- **M5 / M6 是写 SDD 时才浮现的真实缺陷**：它们不在原始缺口矩阵里，因为它们不是"缺界面"，而是"服务端逻辑本身没跑通"。这类缺陷只有写到子系统 spec 层面才会被看见 —— 这正是坚持先写 SDD 再动手编码的价值。

---

**研究步产出完毕（含 8 处实读修正），等待 gate-research 闸口确认（confirm / revise / abandon）。**
