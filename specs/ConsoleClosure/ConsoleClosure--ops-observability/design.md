# 技术设计文档 — S5 系统运维与可观测

> 子系统 ID：**S5** ｜ feature_name：`ConsoleClosure--ops-observability`
> 主工程：`ConsoleClosure`（三端能力补全）
> 关联 spec：`specs/ConsoleClosure/ConsoleClosure--ops-observability/spec.md`
> 关联主账本：`specs/ConsoleClosure/SPECS_INDEX.md`
> 契约：C-019 / C-020 / C-021 / C-022 / C-024 ｜ 语言标签：cangjie + web
> 验收档位：L1 + L2 + L3 ｜ 设计版本：v1.0

---

## 文档信息

- **项目名称**: ConsoleClosure（三端能力补全）— S5 系统运维与可观测
- **版本**: v1.0
- **创建日期**: 2026-10-30
- **作者**: sdd-design-writer（SDD 设计步派生）
- **状态**: 草稿（待 gate-design 闸口确认）

---

## 1. 设计概述

### 1.1 设计目标

1. **把 S5 定位成「地基 + 运维台」双角色**：
   - **地基（R3 横切 P0）**：把 `MemoryController` / `ModelController` / `StorageController` / `RetrieverController` / `ExecutorController` 五个**已实现但无路由绑定**的控制器，绑成 HTTP 端点（契约 C-022），使下游 S2（SDD 编排台）、S4（协议网关运维）能够开工。这是全工程优先级最高的前置，必须最先完成。
   - **运维台**：为 runtime 已实现但无界面的运维/可观测能力补齐 Web 控制台——运行日志、健康检查、定时任务、文件↔库同步、事件处理器、执行器切换、行级授权、国际化管理。
2. **诚实暴露，不谎报可用**：`StorageController.kvGet/kvSet/vectorSearch` 与 `RetrieverController.search` 当前是**占位桩**（源码返回「待…集成」的 `message`，不产生真实读写）。本设计**只暴露、不实现真实存储/检索**，并在前端以「未接入」徽标如实渲染（spec §5.3.1-3，R3 风险缓解）。
3. **低成本高收益收口既有资产**：把已实现但未挂载的 `user/role/permission/menu` 四页 + `setup.vue`（R8，37 条路由未 import）挂上路由并登记菜单权限；修正 `data_flow.vue`「宣称展示同步流却未调用任何 sync 端点」的既有缺陷（M3-附带）。

### 1.2 设计原则

| 原则 | 落地口径 |
|---|---|
| **铁律 9 复用优先** | 本期 **0 新建表、0 新建列**（spec §6.4）。记忆/检索/通道/执行器均复用既有表（`agent_memories` / `retrievers` / `llm_channel` / `agent_executors`），KV 值若后续需持久化优先复用既有 JSON 列。新增表/列须论证复用不成立——本期无此情形。 |
| **铁律 14 二次开发底座优先** | runtime 路由绑定走既有 `AutoRouteConfig.cj` 的 `RouteEntry` 注册表；前端管理页复用 web-admin 既有 `src/views/**` 与 `src/store/models/uctoo/` 已有 97 个 ORM 模型，不重写。 |
| **铁律 15 大工程拆分边界** | 每条任务标注「本子系统负责」与「不碰（移交/调用上游契约）」。S5 只做能力暴露 + 运维台 + 权限挂载；控制器内部业务逻辑、SyncService 内部逻辑、data_flow 已有可视化、PC 原生页均不碰。 |
| **三态如实标注** | 每个新暴露端点与每个运维面板必须标注三态之一（`可用` / `占位桩` / `待集成`），禁止把占位桩渲染为成功数据（spec §4.4-2）。 |
| **路径穿越防护硬红线** | `ops/logs` 的 `file` 参数仅接受服务端下发的枚举值（`startup` / `startup-trace`），前端**绝不**构造、拼接、透传任何路径片段（spec §4.3-1）。 |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 服务端语言 | 仓颉（cangjie） | `apps/agentskills-runtime`，路由经 `AutoRouteConfig.cj` 的 `RouteEntry` 注册；由 `cangjie-coder` 技能辅助编写，**AI 不运行 `cjpm build`**，编译回传由人工完成。 |
| 前端语言 | Vue 3 + TypeScript | `apps/web-admin`，管理后台路由由后端菜单树 `C-024` 动态注入；由 `web-coder` 技能辅助编写。 |
| 接口契约 | `/api/v1/uctoo/*` | 沿用既有前缀与响应体形状 `{success,data,reason}` 或 `{ok,...}`，不引入第三套（spec §4.5-2）。 |
| 注册机制 | `AutoRouteConfig.cj` `RouteEntry` 表 | 新增 5 条 `RouteEntry`，priority 300-340（现有最大 290）。 |
| 权限底座 | `RequirePermissionMiddleware` + `permissions` / `role_has_permission` | 双层把关（R6），缺登记即 403。 |
| 数据底座 | 既有 PostgreSQL 表（cangjie ORM） | 复用 `agent_memories` / `retrievers` / `llm_channel` / `agent_executors` / `crontab` / `sync_log` / `event_handlers` / `permissions` / `role_has_permission` 等，0 新建。 |

> **规模口径说明（与 SPECS_INDEX 对齐）**：子系统登记表写「12 接口 / 4 表」。design 落地口径如下，避免与 spec §6.4「0 新建表」冲突：
> - **「4 表」** = S5 运维台主要读写/展示的 **4 张既有表**：`crontab`、`sync_log`、`event_handlers`、`retrievers`（记忆类复用 `agent_memories`、通道复用 `llm_channel`、执行器复用 `agent_executors`，均为既有表）。**本期 0 新建表、0 新建列**。
> - **「12 接口」** = S5 须显式注册/暴露的接口规模估算；权威清单见 §6：C-022 五控制器 **16 个方法**为新增绑定，其余（crontab 8 / sync 7 / event-handlers 5 / executor 3 / data_access_authorization 3 / ops 4）为**既有已注册端点**，S5 仅消费与补全界面 + 权限，不重复实现。

---

## 2. 系统架构

### 2.1 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                         web-admin（前端宿主）                      │
│  ┌─────────────┐ ┌──────────┐ ┌────────┐ ┌────────────────────┐  │
│  │ 运维台外壳   │ │ 同步运维台│ │ 权限页  │ │ 国际化/locale + 设置 │  │
│  │ (E1/E2/E3)  │ │ (E5)     │ │(G4/G5) │ │ (E9)               │  │
│  └──────┬──────┘ └────┬─────┘ └───┬────┘ └─────────┬──────────┘  │
│         │             │           │               │              │
│  ┌──────┴─────────────┴───────────┴───────────────┴──────────┐   │
│  │ src/router/guard/menu.ts 运行时动态注入（C-024 菜单树）    │   │
│  └──────────────────────────┬────────────────────────────────┘   │
└─────────────────────────────┼────────────────────────────────────┘
                               │  HTTP  /api/v1/uctoo/*
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                  AgentSkills-runtime（cangjie）                    │
│  RequirePermissionMiddleware（鉴权，R6） → 全部新增端点必经       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ AutoRouteConfig.cj  RouteEntry 注册表（按 priority 升序）   │  │
│  │  +5 条新 RouteEntry（priority 300-340，承载 C-022）        │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────────────┐  │
│  │C-019/020 │ │C-021     │ │C-022 五  │ │E6/E7/E8 既有路由    │  │
│  │ops logs/ │ │crontab + │ │控制器绑定│ │event/exec/          │  │
│  │env/health│ │sync 七端 │ │(R3 地基) │ │data_access_auth     │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────────┬──────────┘  │
│       │            │            │                  │             │
│  ┌────┴────────────┴────────────┴──────────────────┴──────────┐  │
│  │ 既有控制器实现（内部逻辑【不改】，仅暴露）                  │  │
│  │ Memory / Model / Storage / Retriever / Executor Controller   │  │
│  │ ⚠ Storage.kvGet/kvSet/vectorSearch、Retriever.search       │  │
│  │   = 占位桩，返回含「待…集成」的 message，不产真实读写       │  │
│  └───────────────────────────────────────────────────────────┘  │
│  RuntimeLogService.resolvePath（白名单，路径穿越防护，§4.3-1）     │
│  RuntimeCapabilityCollector.buildOpsResponse（env，剔除密钥）      │
└──────────────────────────────────────────────────────────────────┘
        │                                    │
        ▼                                    ▼
   logs/ 运行日志                     PostgreSQL（既有表，0 新建）
   (startup / startup-trace /               crontab / sync_log /
    主运行日志)                             event_handlers / retrievers /
                                           agent_memories / llm_channel /
                                           agent_executors / permissions /
                                           role_has_permission
```

### 2.2 模块划分

| 模块 | 职责 | 边界（铁律 15） |
|---|---|---|
| **M1 运行观测** | 健康/信息/运行日志/环境能力四类页面与接口消费（E1/E2/E3） | 不碰 `runtime_log_service.cj` 内部逻辑，仅消费 `ops/logs` / `ops/env` |
| **M2 任务与同步运维** | crontab 八端点 + sync 七端点操作台（E4/E5）；新建同步运维台，修正 data_flow 缺陷（M3-附带） | 不重建 `data_flow.vue`；不碰 `SyncService` / `SyncLogService` 内部逻辑 |
| **M3 横切能力暴露（R3 地基）** | 五控制器 16 方法绑路由（C-022），占位桩三态如实暴露 | **禁止**改写五个控制器内部逻辑；仅加 `RouteEntry` |
| **M4 治理与挂载** | 事件处理器/执行器/行级授权/国际化/既有权限页挂载/死代码处置/菜单权限登记（E6-E9, G4, G5, R8, R2, R6, C-024） | 不碰 PC 原生页（归 S6）；不碰 `data_access_authorization` 内部逻辑 |

### 2.3 组件交互（关键链路）

- **地基链路（最关键）**：S5 在 `AutoRouteConfig.cj` 注册 5 条 `RouteEntry` → runtime 启动 `registerAllRoutes()` 把五控制器方法绑到 `/api/v1/uctoo/{memory,model,storage,retriever,executor}/*` → S2/S4 经 C-022 调用 → S5 达 `test` 后下游开工。
- **运维链路**：运维人员操作 web-admin → 动态菜单（C-024）注入路由 → 调用既有运维端点（C-019/020/021 + sync/event/exec/data_auth）→ 渲染面板。
- **死代码链路**：5 个未注册路由文件（MockRoute 等）→ 按用户决策物理删除或补注册 + 权限登记。

---

## 3. 详细设计

### 3.1 M1 运行观测（E1/E2/E3）

#### 3.1.1 类/组件设计
- 前端页 `views/ops/health-log/index.vue`（新建运维台外壳，承载健康卡片 + 日志查看器 + env 能力清单三块）。
- 卡片隔离容器：单卡片 5xx 时仅该卡片降级，不整页白屏（spec §4.2-2）。

#### 3.1.2 接口设计（消费既有契约，不新增）
| 端点 | 用途 | 来源 |
|---|---|---|
| `GET /api/v1/health` | 健康快照（chatModel.available / scheduler 4 项 / info） | `main.cj:661-701` |
| `GET /api/v1/info` | 应用信息 name/version/language | `main.cj:703-705` |
| `GET /api/v1/uctoo/ops/logs?file=&lines=` | 运行日志（C-019） | `main.cj:720-735` |
| `GET /api/v1/uctoo/ops/env` | 环境能力采集（C-020） | `main.cj:738-745` |

#### 3.1.3 数据流
健康卡片读 `/api/v1/health` → 展示 `chatModel.available`（缺省通道 `degraded` 时 `available=false` + `error`）；日志查看器读 `ops/logs`，`file` 仅从服务端枚举下拉选（绝不由前端拼路径），`lines` 默认 500、封顶 5000，`truncated=true` 必须提示；env 卡片读 `ops/env`，表格仅两列 `name / available`，剔除密钥。

### 3.2 M2 任务与同步运维（E4/E5 + M3-附带）

#### 3.2.1 接口设计（消费既有契约）
- **crontab（C-021）**：`POST /crontab/trigger/:id`、`/pause/:id`、`/resume/:id`、`/reload`；`GET /crontab/scheduler/status`、`/running`、`/executors`、`/builtin-tasks`（`CrontabRoute.cj:53-60`）。注意路径是点号 `scheduler/status`，**非** research 误记的 `scheduler-status`（待回写 research 订正，spec §待确认项 5）。
- **sync 七端点（E5 全新建设）**：`GET /sync/summary`、`GET /sync/status/:entityType`、`POST /sync/from-fs`、`POST /sync/to-fs/:entityType/:entityId`、`POST /sync/all`、`GET /sync/logs`、`GET /sync/health`（`SyncRoute.cj:31-63`）。

#### 3.2.2 数据流
- 定时任务卡片：拉 `scheduler/status` → 展示调度器状态；触发/暂停/恢复/重载均带二次确认弹窗（`reload` 无 id，提示「将重载全部任务」）。
- 同步运维台（新建页 `views/ops/sync/index.vue`）：`from-fs`（文件→库）与 `to-fs`（库→文件，需 `entityType` + `entityId` 两个路径参数）为两个方向按钮；`all` 全量同步后轮询 `/sync/logs` 展示结果。
- **M3-附带修正**：`views/ai/data_flow/index.vue` 既有缺陷（宣称展示文件↔库同步流却未调用任何 sync 端点）→ 接入 `sync/summary` 或 `sync/status` 真实数据，或更正其「展示同步流」文案；**不重写该页**（spec §1.4-1）。

### 3.3 M3 横切能力暴露（R3 地基，C-022）

#### 3.3.1 路由绑定清单（5 控制器，按枚举 16 个方法）
> spec §5.3.1-1 记为「15 个方法」，按实枚举 Memory(4)+Model(2)+Storage(4)+Retriever(3)+Executor(3)=**16** 存在差异；本设计以源码实读为最终口径，全部绑定，不漏绑。

| 控制器 | 绑定路径前缀 | 方法（16） | 三态 |
|---|---|---|---|
| MemoryController | `/api/v1/uctoo/memory` | `update` / `search` / `list` / `delete` | 可用（复用 `agent_memories`） |
| ModelController | `/api/v1/uctoo/model` | `list` / `test` | 可用（复用 `llm_channel` 注册表） |
| StorageController | `/api/v1/uctoo/storage` | `listTypes` / `kvGet` / `kvSet` / `vectorSearch` | **kvGet/kvSet/vectorSearch = 占位桩（未接入）** |
| RetrieverController | `/api/v1/uctoo/retriever` | `list` / `getById` / `search` | `search` = **占位桩（未接入）**；`list/getById` 可用（复用 `retrievers`） |
| ExecutorController | `/api/v1/uctoo/executor` | `list` / `getByName` / `listSchemes` | 可用（复用内置 5 种 + `agent_executors`） |

#### 3.3.2 注册方式与冲突处理
- 在 `AutoRouteConfig.cj` 新增 5 条 `RouteEntry`（`tableName, routePath, priority, enabled, registerFunc`），priority **300-340**（现有最大 290），与既有 86 条生效路由无冲突（spec §5.3.1-2）。
- **路径冲突预防（DFX §4.5-1）**：`/api/v1/uctoo/executor/list` 与既有 `AutoRouteConfig.cj:1508` 的 `GET /executor/list`（E7）为同一端点——**合并复用，不重复注册**；C-022 的 `ExecutorController.list` 即指向既有 `/executor/list`，仅补 `getByName` / `listSchemes` 两条新绑定。`/model/*` 与既有 `/api/v1/ai/*` 模型路由前缀不同，无冲突。
- **禁止项（spec §5.3.1-5）**：绑定路由时**严禁**改写五个控制器内部逻辑；占位桩保持返回 `message` 原样透传。

#### 3.3.3 三态响应契约
- 可用端点：返回 `{success, data}`。
- 占位桩端点：`StorageController.kvGet/kvSet/vectorSearch` 与 `RetrieverController.search` 返回含 `message`（如「待…集成」）的响应。**前端缺 `message` 字段时一律按「未接入」处理**（spec §5.3.1-3b），禁止渲染为成功数据。

### 3.4 M4 治理与挂载（E6-E9, G4, G5, R8, R2, R6, C-024）

#### 3.4.1 事件处理器与执行器（E6/E7，消费既有）
- event-handlers 五端点：`GET /event-handlers/active`、`/history`、`POST /event-handlers/register`、`/unregister`、`/toggle`（`AutoRouteConfig.cj:1492-1496`）。
- executor 三端点：`POST /executor/switch`、`GET /executor/list`、`GET /executor/agent-executor`（`AutoRouteConfig.cj:1508-1510`）。

#### 3.4.2 行级授权（E8，消费既有）
- `POST /data_access_authorization/authorize`、`/revoke`、`GET /data_access_authorization/:entityType/:entityId/authorizations`（`DataAccessAuthorizationRoute.cj:50-52`）。

#### 3.4.3 国际化与既有页挂载（E9/G4/G5/R8）
- `src/views/locale/index.vue`（36 行 + 子组件已存在）挂路由 + 菜单（E9）。
- `src/views/{userManager,role,permission,menu}/**` 与 `src/views/setup.vue`（235 行）经 `src/router/constant.ts` import 挂载（R8/G4/G5）——**挂载即可，无需重写**。

#### 3.4.4 菜单与权限登记（R2/R6/C-024）
- 全部新增/挂载页面经 `POST /api/v1/uctoo/permissions/user/menu`（C-024）登记菜单树，并写入 `permissions` + `role_has_permission` 后执行 `loaddbinfo`（spec §5.4.1-4）。漏登记 = 看不到入口或 403（P0 缺陷）。

#### 3.4.5 死代码处置（spec §5.4.1-5）
- `MockRoute.cj` / `AiDevDemoRoute.cj` / `LanguageOrchestrationRoute.cj` / `PublicCompaniesRoute.cj` / `PublicTasksRoute.cj` 五文件仅被 import、从未注册。本设计建议**物理删除**（research §5.4 口径），经用户确认后执行；若用户选择补注册，则须同步登记权限。处置结果须为「已删除」或「已注册+已授权」二者之一，禁止半绑定。

---

## 4. 数据设计

### 4.1 复用论证（铁律 9，0 新建）

| 对象 | 复用表 | 字段/口径 | 复用成立理由 |
|---|---|---|---|
| 记忆条目 | `agent_memories` | `agent_id`/`content`/`scope`/`weight`/`tags`/`metadata`；`scope` 缺省 `episodic` | 表已存在且语义直接匹配，无需新表 |
| 检索器 | `retrievers`（`RetrieversPO`） | 既有字段 | 检索器即配置记录，表已承载 |
| 模型通道 | `llm_channel`（ChannelRegistry） | 注册表为空回落内置名单 | 通道注册表已存在 |
| 执行器 | 内置 5 种（`naive`/`react`/`plan-react`/`tool-loop`/`dsl-executor`）+ `agent_executors` | 既有模型 | 执行器名单与模型均已有 |
| 定时任务 / 同步 / 事件 | `crontab` / `sync_log` / `event_handlers` | 既有 | 运维对象已落表 |
| 权限 / 角色 | `permissions` / `role_has_permission` | 既有 | RBAC 底座已存在，仅补数据行 |
| KV 值（未来） | 优先复用 `agent_memories.metadata` 或 `retrievers` 既有 JSON 列 | — | 复用不成立时才另案论证 |

**结论**：本期 **0 新建表、0 新建列**。因此**无 DDL 任务**；仅有 DML 任务（向 `permissions` / `role_has_permission` 补登记行，落 `sql/incremental/`）。

### 4.2 数据表关系（既有，仅标注）

```
permissions (菜单/权限项, type=1 且 menu_type NOT NULL 即菜单节点)
   └─< role_has_permission (角色↔权限多对多, RBAC 双层把关 R6)

crontab ─< crontab_log
sync_log (同步记录)
event_handlers (事件处理器注册)
retrievers ─< (被 RetrieverController 读)
agent_memories (记忆, 被 MemoryController 读)
llm_channel (通道, 被 ModelController 读)
agent_executors (执行器, 被 ExecutorController 读)
```

> 隐藏菜单机制备忘（来自 SPECS_INDEX §8）：菜单取数 SQL 为 `type=1 AND menu_type IS NOT NULL AND deleted_at IS NULL`；`hidden` 字段**不参与过滤**（现存 172 节点均为 `hidden=1`）；超管持通配权 `*` 走全量分支，**改 `role_has_permission` 对超管无效**。隐藏菜单只有两条路：软删 `deleted_at`（推荐，可回滚）或 `menu_type` 置 NULL。

### 4.3 落表范围声明
全部领域对象落在 §4.1/§4.2 既有表上，**本期 0 新建表、0 新建列**；占位桩端点不落数据，`kvSet` 在 `JsonKVStorage` 集成前为空操作（spec §6.4）。

---

## 5. API 设计

### 5.1 本子系统涉及的契约接口（消费 / 暴露）

| 编号 | 方法 | 路径 | 角色 | 说明 |
|---|---|---|---|---|
| C-019 | GET | `/api/v1/uctoo/ops/logs` | 消费（既有） | 运行日志，S5 运维台 + S6 桌面端消费 |
| C-020 | GET | `/api/v1/uctoo/ops/env` | 消费（既有） | 环境能力采集 |
| C-021 | POST | `/api/v1/uctoo/crontab/{trigger,pause,resume,reload}` + GET 状态类 | 消费（既有） | 定时任务运维 |
| **C-022** | GET/POST | `/api/v1/uctoo/{memory,model,storage,retriever,executor}/*` | **S5 新增绑定（地基）** | 五控制器 16 方法，见 §3.3.1 |
| C-024 | POST | `/api/v1/uctoo/permissions/user/menu` | 消费（已冻结） | 动态菜单登记，C-024 是硬约束 |

### 5.2 本子系统新增绑定的接口（C-022，5 控制器 16 方法）

> 以下为**新增路由绑定**（非新业务逻辑）；全部须过 `RequirePermissionMiddleware` 并登记 `permissions`（否则 403，R6）。

| 控制器 | 方法 | 路径 | 三态 | 参数要点 |
|---|---|---|---|---|
| Memory | update | `POST /api/v1/uctoo/memory/update` | 可用 | `agentId`(必填) |
| Memory | search | `POST /api/v1/uctoo/memory/search` | 可用 | `agentId`(必填) |
| Memory | list | `GET /api/v1/uctoo/memory/list` | 可用 | `agentId`(必填) |
| Memory | delete | `DELETE /api/v1/uctoo/memory/delete` | 可用 | `memoryId`(必填) |
| Model | list | `GET /api/v1/uctoo/model/list` | 可用 | — |
| Model | test | `POST /api/v1/uctoo/model/test` | 可用 | `model`(必填) |
| Storage | listTypes | `GET /api/v1/uctoo/storage/listTypes` | 可用 | — |
| Storage | kvGet | `GET /api/v1/uctoo/storage/kvGet` | **占位桩** | `key`(必填) |
| Storage | kvSet | `POST /api/v1/uctoo/storage/kvSet` | **占位桩** | `key`/`value` |
| Storage | vectorSearch | `POST /api/v1/uctoo/storage/vectorSearch` | **占位桩** | `query` |
| Retriever | list | `GET /api/v1/uctoo/retriever/list` | 可用 | — |
| Retriever | getById | `GET /api/v1/uctoo/retriever/getById` | 可用 | `id`(必填) |
| Retriever | search | `POST /api/v1/uctoo/retriever/search` | **占位桩** | `id`(必填) + `query`(必填) |
| Executor | list | `GET /api/v1/uctoo/executor/list` | 可用 | 与既有 `/executor/list` 合并 |
| Executor | getByName | `GET /api/v1/uctoo/executor/getByName` | 可用 | `name`(必填) |
| Executor | listSchemes | `GET /api/v1/uctoo/executor/listSchemes` | 可用 | — |

### 5.3 既有运维端点（S5 消费，不重复实现）
crontab 8 / sync 7 / event-handlers 5 / executor 3（E7，其中 `list` 与 C-022 合并）/ data_access_authorization 3 / ops 4（health/info/logs/env）/ locale 1。完整路径见 §3.1.2、§3.2.1、§3.4.1-3，均沿用源码实读路径，**禁止改名**（DFX §4.5-1）。

---

## 6. 安全设计

### 6.1 认证机制
- 全部新增端点经 API 层 `RequirePermissionMiddleware` 鉴权（spec §4.3-2）；未登录/无票 → 401/403。
- 前端管理路由由 `C-024` 菜单树动态注入，无菜单节点即无入口（R2）。

### 6.2 权限控制（R6 双层）
- **API 层**：`RequirePermissionMiddleware` 按 `permission_name` 校验。
- **菜单层**：`getUserMenuTree` 按角色返回可见菜单。
- **登记硬要求**：C-022 五控制器 + 全部新增/挂载页面，必须写入 `permissions` + `role_has_permission` 并执行 `loaddbinfo`，否则 403（spec §4.3-2，R6）。**这是本子系统最高频缺陷点，必须落任务**。

### 6.3 数据安全
1. **路径穿越防护（硬红线，spec §4.3-1）**：服务端 `RuntimeLogService.resolvePath` 白名单 + 固定路径，`file` 仅接受 `startup` / `startup-trace`，其余回落主运行日志；**前端禁止构造/拼接/透传任何路径片段**，只从服务端枚举下拉选。
2. **env 密钥剔除（spec §4.3-3）**：`ops/env` 仅返回 `{name, available}`，剔除 API Key / 数据库口令。
3. **破坏性动作二次确认 + 操作日志（spec §4.3-4）**：`/crontab/del`、`/sync/to-fs`、`/event-handlers/unregister` 等须前端二次确认，服务端写操作日志。
4. **占位桩不谎报（R3）**：`message` 字段缺失即按「未接入」渲染，禁止把桩当成功数据。

---

## 7. 性能设计

### 7.1 性能目标（spec §4.1）
1. `/api/v1/health` 与 `/api/v1/uctoo/sync/health` P95 ≤ 300ms。
2. `ops/logs` 单次返回行数上限 5000、默认 500；前端默认请求 ≤ 500。
3. 运维台首屏（健康 + 任务列表 + 同步概览）3 个并发接口渲染完成 ≤ 2s。

### 7.2 优化策略
- 首屏三块并发请求（非串行）；单卡片失败隔离降级（spec §4.2-2），不阻塞其余。
- `ops/logs` 前端默认 `lines=500`，用户可调但封顶 5000（前端 + 服务端双封顶）。
- 日志轮询：默认 10s（spec §待确认项 6），结合日志量可由用户确认调短；首屏不自动轮询，手动刷新或可选自动。

---

## 8. 部署设计

### 8.1 部署架构
- 服务端：随 `apps/agentskills-runtime` 一起 `cjpm build` 部署；新增 5 条 `RouteEntry` 在 `AutoRouteConfig.cj`，随启动 `registerAllRoutes()` 生效，不影响既有 86 条路由（spec §4.2-3）。
- 前端：随 `apps/web-admin` 构建；新增/挂载页面经 `C-024` 菜单树动态注入，无需改 `constant.ts` 之外的静态路由（G4/G5 页需补 import）。
- **AI 不运行 `cjpm build`**：仓颉编译、类型检查、lint 由人工在独立环境执行并回传（铁律 15 / tasks 模板硬约束）。

### 8.2 环境配置与前置（来自 SPECS_INDEX §5.3）
| 前置 | 状态 | 处置 |
|---|---|---|
| 宿主 runtime 已起 | ✗ | 用户启动（AI 不跑 build） |
| DB 迁移 `sql/incremental/` 已执行 | 本期无 DDL | 仅 DML（permissions/role_has_permission 登记） |
| 新增路由 permissions 授权 | ✗ | 必做，否则 403（R6） |
| 动态菜单登记 | ✗ | 依赖 C-024，本子系统 authoritative 登记 |

### 8.3 验收档位
- **L1**：S5 自身 test 步，spec 每条 EARS 验收条件通过，P0 缺陷清零（含 R3 占位桩如实暴露、R6 权限登记齐备）。
- **L2**：下游 S2/S4 test 步，在 S5 `done` 后与 S5 合并运行态，冒烟 C-022 能力端点全绿（SPECS_INDEX §5.2 用例 3）。
- **L3**：主工程端到端，排障场景（制造 runtime 故障 → 运维台看健康告警 + 拉日志定位 → 桌面端托盘变红，跨 S5→S6，SPECS_INDEX §5.1 用例 5）。

---

## 9. 附录

### 9.1 参考文档
- `specs/ConsoleClosure/ConsoleClosure--ops-observability/spec.md`（需求权威来源）
- `specs/ConsoleClosure/SPECS_INDEX.md`（契约/风险/集成/验收主账本）
- `specs/ConsoleClosure/research.md`（缺口分析，§5.2-E4 / §5.4 / §8 M1-M3 实读修正）
- `skills/sdd/SKILL.md`（铁律 9 复用优先 / 14 二次开发底座优先 / 15 大工程拆分）
- 源码实读：`main.cj:661-745`、`CrontabRoute.cj:53-60`、`SyncRoute.cj:31-63`、`AutoRouteConfig.cj:1492-1510`、`DataAccessAuthorizationRoute.cj:50-52`、`runtime_log_service.cj`、`RuntimeCapabilityCollector`（ops 响应）

### 9.2 待确认/决策点（来自 spec §待确认项，本设计已部分决策）
1. **路由注册 priority**：本设计定为 300-340（现有最大 290），新增 5 条 `RouteEntry`。✅ 已决策。
2. **ops/env 完整字段**：沿用 research `{capabilities:[{name,available}]}`；前端表格两列，扩展字段待 `RuntimeCapabilityCollector.buildOpsResponse` 实读后追加。⏳ 待实读。
3. **占位桩真集成时机**：本期仅暴露 + 标注未接入，不实现真实存储/检索。✅ 已决策（与 spec 一致）。
4. **死代码处置方式**：本设计建议物理删除，⏳ 待用户确认删除或补注册。
5. **`crontab/scheduler/status` 文档偏差**：本设计沿用源码点号路径，⏳ 待回写 research.md 订正（见任务 T-25）。
6. **ops/logs 前端轮询周期**：默认 10s，⏳ 待 design 步结合日志量确认（本设计 §7.2 取 10s 可选）。

### 9.3 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-30 | sdd-design-writer | 初始设计：地基 R3 能力暴露 + 运维台四模块 + 0 新建表论证 + 安全/性能/部署/验收档位 |
