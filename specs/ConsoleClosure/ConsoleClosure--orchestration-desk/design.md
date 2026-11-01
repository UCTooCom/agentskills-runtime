# S2 长期任务与 SDD 编排台 技术设计文档

## 文档信息
- **项目名称**: ConsoleClosure（三端能力补全）
- **子系统**: S2 长期任务与 SDD 编排台
- **feature_name**: `ConsoleClosure--orchestration-desk`
- **版本**: v1.0
- **创建日期**: 2026-10-30
- **作者**: SDD design 步（sdd-design-writer 派生）
- **状态**: 待 gate-design 确认
- **关联需求**: `specs/ConsoleClosure/ConsoleClosure--orchestration-desk/spec.md`
- **关联主工程账本**: `specs/ConsoleClosure/SPECS_INDEX.md`

---

## 1. 设计概述

### 1.1 设计目标

S2 是 **人机回路门面**：把 AgentSkills-runtime 已实现、但前端零界面的两类能力——**长期任务（LRT）** 与 **SDD 流水线**——以统一的业务控制台呈现给用户，并强制关键推进/自演进动作必须由人确认、可追溯、可停止。

设计目标（对齐 `spec.md §1.1`）：

1. **LRT 态势一张图**：任务树、进度、检查点、执行轨迹放在同一业务界面，不把附属表 CRUD 包装成业务闭环。
2. **LRT 质量闭环**：干预、核验、交付、评审、演进由人显式触发，任何写动作按钮在回执前防重复提交。
3. **SDD 流水线可视化**：六步（research 可选 → spec → design → tasks → code → test）与轮次、闸口等待态清晰呈现。
4. **五个闸口决策门面**：`confirm` / `revise` / `abandon` 三选一，决策前先展示后果，决策后强制留痕。
5. **可审计**：LRT 干预与 SDD 闸口决策全部落到既有 `agent_approvals`，界面不把本地成功提示当落库成功。
6. **可导航、可授权**：通过动态菜单（C-024）暴露入口，双层 RBAC（菜单可见 + API 鉴权）一致，缺登记即 403 或无入口。

### 1.2 设计原则

- **前端只读编排，不实现算法**：遵守 `spec.md §1.4` 职责边界——不实现 LRT/SDD 服务端编排、不新增或猜测 API、不替人自动决策。
- **复用优先（铁律 9）**：6 张数据对象全部复用既有表，本子系统 **不新增任何表或列**；菜单/权限只往既有 `permissions` / `role_has_permission` / `menu` 插入数据。
- **二次开发底座优先（铁律 14）**：web-admin 属既有工程，前端页面走既有 Vue 技术栈与 `src/store/models/uctoo/*` 取数范式，不另起炉灶。
- **契约先行（铁律 15）**：所有后端交互以 C-007~C-012 冻结契约为准；未冻结字段不臆造映射。
- **确定性优先**：请求/响应形态以 `specs/ConsoleClosure/SPECS_INDEX.md §3` 契约表为准，前端不猜测 `action`、`payload` 等字段取值。

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 编程语言 | TypeScript / Vue SFC | 与 web-admin 既有栈一致，标签 `web` |
| 前端框架 | Vue 3（web-admin 既有）+ OpenTiny / TinyVue 组件库 | 既有管理后台已用，沿用其组件与布局 |
| 状态管理 / 取数 | Pinia + `src/store/models/uctoo/*` ORM 模型层 | 真正的接口全集在该模型层（97 个 Model），非 `src/api/*` 模板薄层 |
| 路由 | web-admin 动态菜单注入路由（`src/router/guard/menu.ts`） | 入口靠 C-024 菜单树，组件解析 `views/${menu.component}.vue` |
| 后端依赖 | AgentSkills runtime（已部署，不归 S2 改） | LRT 九动作 + SDD 五语义端点由 runtime 提供 |
| 权限 | 既有 `RequirePermissionMiddleware` + 动态菜单树 | 双层把关，缺登记即 403 或无入口（R6） |
| 数据库 | 宿主 PostgreSQL（复用，不在 S2 建表） | 直接复用 `long_running_task` 等 6 张表 |

> **S2 不新增后端 HTTP 接口**：遵守 `spec.md §1.4.2`，S2 仅消费 runtime 已注册端点与 S5 后续冻结的 C-022。所谓"本子系统要新增的接口"实为 **web-admin 前端路由组件 + 菜单/权限数据登记**，非后端 API。

---

## 2. 系统架构

### 2.1 架构图

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          浏览器 (web-admin SPA)                            │
│                                                                            │
│  ┌──────────────────────── S2 编排台 (Vue 模块) ────────────────────────┐ │
│  │                                                                        │ │
│  │  ① 入口与菜单集成层           (C-024 动态菜单 / 路由注入)              │ │
│  │       └─ 编排台主页 (长期任务 ｜ SDD 工程 两个一级入口)                │ │
│  │                                                                        │ │
│  │  ┌─────────────── LRT 能力线 ───────────────┐  ┌──── SDD 能力线 ───┐  │ │
│  │  │ B1 任务树视图 (C-007)                    │  │ B6 六步流水线视图 │  │ │
│  │  │ B2 进度/检查点 (C-008)                   │  │    (start/run/    │  │ │
│  │  │ B3 人工干预面板 (C-009)                  │  │     run-stage/    │  │ │
│  │  │ B4 核验/交付/评审 (verify/deliver/review)│  │     C-011 status) │  │ │
│  │  │ B5 演进与追踪 (C-010)                    │  │ B7 五闸口决策     │  │ │
│  │  │                                        │  │    (C-012 review) │  │ │
│  │  └────────────────────────────────────────┘  │ B8 阶段产物查看   │  │ │
│  │                                              │    (artifact)     │  │ │
│  │  ┌──── 横切：权限 RBAC 闭环 (R6) ────┐        └───────────────────┘  │ │
│  │  │ 菜单可见 + API 鉴权双层一致        │                              │ │
│  │  │ 审计留痕 (agent_approvals 复用)    │                              │ │
│  │  └───────────────────────────────────┘                              │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│         │ 取数/动作请求                  │ 菜单/鉴权                      │
│         ▼                                ▼                               │
└─────────┼────────────────────────────────┼────────────────────────────────┘
          │                                │
          ▼                                ▼
┌──────────────────────────┐   ┌────────────────────────────────────────────┐
│  AgentSkills Runtime      │   │  权限与菜单服务 (IAM)                       │
│  (已部署, 非 S2 改)       │   │  C-024: POST /api/v1/uctoo/permissions/     │
│  ├ LRT API (C-007~C-010)  │   │          user/menu                         │
│  │  /long_running_task/*  │   │  RequirePermissionMiddleware               │
│  ├ SDD API (C-011/C-012)  │   └────────────────────────────────────────────┘
│  │  /api/v1/uctoo/sdd/*   │
│  └ S5 能力暴露 C-022      │   ← S2 硬前置：S5 必须达 test 且冻结 C-022
│     (上游, S2 不实现)     │      S2 仅调用，不实现其路由
└──────────────────────────┘
```

> **两条能力线的关系**：LRT 能力线管"正在跑的长期任务"（任务树/进度/干预/演进），SDD 能力线管"SDD 工程本身的六步开发与闸口"。两者在 S2 内共用同一套入口框架、权限层与留痕表（`agent_approvals`），但**数据源与契约完全独立**：LRT 走 `C-007~C-010`（`/long_running_task/*`），SDD 走 `C-011/C-012` 及 `start/run/run-stage`（`/api/v1/uctoo/sdd/*`）。SDD 工程的阶段产物又回写 `long_running_task_artifact`，与 LRT 共享该产物表（B8）。

### 2.2 模块划分

| 模块 | 编号 | 职责 | 对应需求 |
|------|------|------|---------|
| M1 入口与菜单集成 | menu | 编排台主页 + 动态菜单节点登记 + 路由注入 | C-024、§5.5 |
| M2 LRT 态势 | lrt-situation | 任务树 / 进度 / 检查点 / 轨迹 只读视图 | B1、B2、B5 |
| M3 LRT 人工控制与质量闭环 | lrt-control | 干预 / 核验 / 交付 / 评审 / 演进 写动作面板 | B3、B4 |
| M4 SDD 流水线可视化 | sdd-pipeline | 六步流水线 + start/run/run-stage + 状态轮询 | B6 |
| M5 SDD 闸口决策 | sdd-gate | 五闸口 confirm/revise/abandon 决策门面 | B7 |
| M6 SDD 阶段产物 | sdd-artifact | 关联 `long_running_task_artifact` 展示阶段产物 | B8 |
| M7 权限 RBAC 闭环 | rbac | 菜单登记 + permissions + role_has_permission 一致 | §5.5、R6 |
| M8 审计留痕 | audit | 干预/闸口决策落 `agent_approvals`，回执后强制重查 | §1.3.5、§5.4 |

### 2.3 组件交互

- **单向依赖**：S2 → runtime（消费 C-007~C-012 等已注册端点）；S2 → IAM（消费 C-024 菜单与鉴权）。**S2 不反向依赖其它 Web 子系统**，符合铁律 15「依赖方向单向无环」。
- **与 S5 的边界**：S2 仅把 S5 的 C-022 作为开工硬前置并做 L2 集成验收；**不实现** C-022 的控制器路由暴露（归 S5）。若 C-022 未达 `test`/未冻结，S2 状态置 `blocked`（§5.5.1 业务规则 1）。
- **页面间数据共享**：各视图通过独立接口取数，不依赖前端缓存推断阶段推进（§4.2.2）；恢复可见后 10 秒内重新拉取权威状态。

---

## 3. 详细设计

### 3.1 M1 入口与菜单集成模块

#### 3.1.1 类/组件设计

- `views/orchestration/index.vue`：编排台主页，左侧两个一级入口（长期任务 / SDD 工程），右侧为对应子视图容器。
- `router` 注册：本模块**不写静态路由**（`src/router/constant.ts` 不挂载），改由 C-024 动态菜单注入 `views/${menu.component}.vue`。

#### 3.1.2 接口设计

- 入口数据来源：`POST /api/v1/uctoo/permissions/user/menu`（C-024，runtime 提供）→ 返回菜单树，含 `component` 字段指向 `orchestration/index`。
- S2 自身**不新增后端接口**，仅新增一条菜单节点数据（见 §4 / M7）。

#### 3.1.3 数据流

用户登录 → IAM 返回菜单树 → 菜单含「长期任务与 SDD 编排台」节点 → 点击 → `router.addRoute('root', ...)` 注入 → 渲染 `orchestration/index.vue`。无权限角色不在菜单树中出现该节点。

### 3.2 M2 LRT 态势模块（B1/B2/B5）

#### 3.2.1 类/组件设计

- `LrtTaskTree.vue`：调用 C-007 渲染任务树（根 + 子层级），空 `children` 表示叶节点，不据空集合推断完成。
- `LrtProgressCheckpoint.vue`：选中节点后调用 C-008（progress + checkpoints），区分总体进度与检查点列表。
- `LrtTrace.vue`：调用 C-010 的 `GET /trace` 展示执行轨迹，缺失属性显空态不推断。
- `LrtEvolveTrace.vue`：演进完成后刷新 C-010 相关视图，呈现 `evolutionId` 与轨迹（B5）。

#### 3.2.2 接口设计（消费）

| 契约 | 方法 | 路径 | 用途 |
|------|------|------|------|
| C-007 | GET | `/api/v1/uctoo/long_running_task/tree/:rootId` | 任务树 |
| C-008 | GET | `/api/v1/uctoo/long_running_task/progress/:taskId` | 总体进度 |
| C-008 | GET | `/api/v1/uctoo/long_running_task/checkpoints/:taskId` | 检查点列表 |
| C-010 | GET | `/api/v1/uctoo/long_running_task/trace` | 执行轨迹（查询参数待核对控制器） |

#### 3.2.3 数据流

打开 `rootId` → C-007 返回根与子层级 → 选节点 → C-008 取进度/检查点 → 开轨迹 → C-010 trace。根不存在则停止后续查询；局部失败保留已成功区域并允许单独重试。

### 3.3 M3 LRT 人工控制与质量闭环模块（B3/B4）

#### 3.3.1 类/组件设计

- `LrtIntervenePanel.vue`：提交前显式展示目标任务/动作/影响摘要，再调 C-009（B3）。
- `LrtVerifyDeliverReview.vue`：核验 `POST .../verify/:taskId`、交付 `POST .../deliver/:taskId`、评审 `POST .../review/:taskId`（B4）。
- `LrtEvolvePanel.vue`：演进 `POST .../evolve/:agentId`，调用前必须二次确认，禁止页面加载自动触发（B5）。

> 说明：`verify` / `deliver` / `review`（LRT 评审）是 LRT 九动作中的三个端点，在 SPECS_INDEX 未单列契约编号，但属 S2 消费范围（spec §5.2）。其请求字段以 `LongRunningTaskController` 实读为准，前端不猜测。

#### 3.3.2 接口设计（消费）

| 契约/端点 | 方法 | 路径 | 用途 |
|------|------|------|------|
| C-009 | POST | `/api/v1/uctoo/long_running_task/intervene` | 人工干预 |
| — | POST | `/api/v1/uctoo/long_running_task/verify/:taskId` | 核验 |
| — | POST | `/api/v1/uctoo/long_running_task/deliver/:taskId` | 交付 |
| — | POST | `/api/v1/uctoo/long_running_task/review/:taskId` | 评审 |
| C-010 | POST | `/api/v1/uctoo/long_running_task/evolve/:agentId` | 演进 |

#### 3.3.3 关键交互约束（来自 spec §5.2）

- 所有写动作：按钮在收到回执前禁用（防重复提交）；`intervene`/`verify`/`evolve`/`deliver`/`review` 及 SDD `review` **自动重试次数必须为 0**（§4.2.1）。
- 取消即不发送任何请求；状态冲突时刷新权威状态不自动重试；权限不足显示无权限提示，不展示成功假象。

### 3.4 M4 SDD 流水线可视化模块（B6）

#### 3.4.1 类/组件设计

- `SddPipeline.vue`：按 research（可选）→ spec → design → tasks → code → test 六步渲染，区分五个 gate 与六个阶段（不把 gate 当阶段）。
- `SddRunControls.vue`：启动 `POST /api/v1/uctoo/sdd/start`；完整编排 `POST /api/v1/uctoo/sdd/run`（异步立即返回）；单阶段 `POST /api/v1/uctoo/sdd/run-stage`（同步等待结果），界面说明两种等待语义。
- `SddStatusPoll.vue`：轮询 `GET /api/v1/uctoo/sdd/status/:featureName`（C-011），按 `stage`/`round`/`gate`/`waiting` 更新。

#### 3.4.2 接口设计（消费，路径保持 `/api/v1/uctoo/sdd/` 原样）

| 契约 | 方法 | 路径 | 用途 |
|------|------|------|------|
| — | POST | `/api/v1/uctoo/sdd/start` | 启动工程（幂等取/建） |
| — | POST | `/api/v1/uctoo/sdd/run` | 异步完整编排 |
| — | POST | `/api/v1/uctoo/sdd/run-stage` | 同步单阶段探针 |
| C-011 | GET | `/api/v1/uctoo/sdd/status/:featureName` | 流水线状态 |

> ⚠️ **路径铁律**：`/api/v1/uctoo/sdd/` 是 runtime 真实注册路径（见 `skills/sdd/SKILL.md:200-212`），**不得改为 ConsoleClosure 或任何其它前缀**。

### 3.5 M5 SDD 闸口决策模块（B7）

#### 3.5.1 类/组件设计

- `SddGateDecision.vue`：等待任一既定 gate（gate-research/gate-spec/gate-design/gate-task/gate-code）时高亮对应阶段并展示决策区；`test` 为末步不新增 gate-test。
- 决策三选项：`confirm`（推进）/ `revise`（重做并增轮次）/ `abandon`（终止并保留产物）。提交前展示后果。
- 提交至 `POST /api/v1/uctoo/sdd/review`（C-012），输入 `featureName`/`stage`/`decision`，展示 `nextStage`；回执后强制重查 C-011 状态，若未变化提示核对审批留痕。

#### 3.5.2 接口设计（消费）

| 契约 | 方法 | 路径 | 用途 |
|------|------|------|------|
| C-012 | POST | `/api/v1/uctoo/sdd/review` | 闸口决策回执 |

#### 3.5.3 留痕约束

五类闸口决策必须落 `agent_approvals`（与 LRT 干预共享表，按业务语义区分）。`revise` 增加轮次且保留已确认产物，前端不隐藏历史轮次（SKILL.md:190-198）。

### 3.6 M6 SDD 阶段产物查看模块（B8）

#### 3.6.1 类/组件设计

- `SddArtifactView.vue`：从既有 `long_running_task_artifact` 关联展示阶段产物；选中已有产物的阶段展示对应产物，无产物显明确空态。关联字段与读取 API 待核对源码确认。
- 不伪造补件；上游产物缺失时展示拒绝原因（spec §5.3.3）。

### 3.7 M7 权限 RBAC 闭环模块（R6 / §5.5）

#### 3.7.1 设计

- 新增菜单节点「长期任务与 SDD 编排台」→ `permissions` 表登记对应 `permission_name` → `role_has_permission` 授权给有权角色。
- 三层一致：菜单可见角色 = API 授权角色。完成后执行 `loaddbinfo`（R6）。
- 越权直达：API 层 `RequirePermissionMiddleware` 拒绝（403），前端不降级绕过。

#### 3.7.2 数据登记（种子 SQL，落到 `sql/incremental/`）

- `menu` 插入一条组件节点（`component='orchestration/index'`，`type=1`、`menu_type` 非空、`deleted_at` 为 NULL，遵循 SPECS_INDEX §8 机制备忘）。
- `permissions` 插入编排台访问权限项。
- `role_has_permission` 授权给目标角色（注意：超管持通配 `*` 走全量分支，改 `role_has_permission` 对超管无效）。

### 3.8 M8 审计留痕模块

- 所有 `intervene`（C-009）与 SDD `review`（C-012）回执成功后，前端**必须重新查询权威状态**确认落库；不把本地成功提示当留痕成功。
- 复用 `agent_approvals.*`，不新增列（铁律 9）。

---

## 4. 数据设计

### 4.1 数据模型与复用结论

S2 **不新增任何表或列**（spec §1.4.7、R4）。沿用既有 6 类数据对象，覆盖任务、上下文、审批、演进、工程、产物。字段映射以 C-007~C-012 冻结契约为准；本设计不臆造列名（spec 多处标注"待核对 PO/Controller 后确认"）。

### 4.2 数据表设计（全部复用）

| 表名 | 复用/新增 | S2 用途 | 关联契约 | 字段口径 |
|------|---------|--------|---------|---------|
| `long_running_task` | **复用** | 任务树根与子层级（`id`/`title`/`state`/`children`） | C-007 | 属性与实体列是否同名待核对 PO 后确认 |
| `agent_contexts` | **复用** | 进度与检查点（`percent`/`currentStage`/`checkpoints`） | C-008 | 不声明未经源码确认的具体存储列 |
| `agent_approvals` | **复用** | 干预审批 + SDD 闸口决策留痕 | C-009、C-012 | `skill_name=sdd`/决策/阶段/工程标识，具体列待核对 |
| `long_running_task_evolution` | **复用** | 演进记录与轨迹（`evolutionId`/`trace`） | C-010 | 不新增 S2 专属演进表 |
| `sdd_projects` | **复用** | SDD 工程状态（`stage`/`round`/`gate`/`waiting`） | C-011 | `sdd_projects` 是真实库表，名不改 |
| `long_running_task_artifact` | **复用** | 阶段产物正文（B8） | B8 | 产物与工程/阶段/轮次关联字段待核对 |

> 注：`long_running_task_artifact` / `long_running_task_evolution` / `lrt_verify_job` 三张附属表已有 CRUD 页，但 S2 **不**把它们包装成业务闭环（spec §1.4.4）；仅按需以权威接口读取展示。

### 4.3 数据关系

```
long_running_task (rootId → children 层级)
        │  progress/checkpoints 归属
        ▼
agent_contexts (taskId → percent/currentStage/checkpoints)

long_running_task_evolution (agentId → evolutionId/trace)   ── C-010
agent_approvals (taskId/featureName → decision/approver)     ── C-009 / C-012 留痕
sdd_projects (featureName → stage/round/gate/waiting)        ── C-011
long_running_task_artifact (sdd_projects.featureName + stage + round → 产物)  ── B8
```

全部为既有表间既有关联，S2 仅在视图层按契约字段关联展示，不改动表结构或外键。

---

## 5. API 设计

### 5.1 API 列表（S2 消费的全部契约/端点）

> S2 是 web 前端子系统，**不新增后端 HTTP 接口**。下表为 S2 消费的 runtime 已注册端点（路径保持原样）。

| 契约 | 方法 | 路径 | 描述 | 复用/新增 |
|------|------|------|------|----------|
| C-007 | GET | `/api/v1/uctoo/long_running_task/tree/:rootId` | LRT 任务树 | runtime 提供 |
| C-008 | GET | `/api/v1/uctoo/long_running_task/progress/:taskId` | LRT 进度 | runtime 提供 |
| C-008 | GET | `/api/v1/uctoo/long_running_task/checkpoints/:taskId` | LRT 检查点 | runtime 提供 |
| C-009 | POST | `/api/v1/uctoo/long_running_task/intervene` | LRT 人工干预 | runtime 提供 |
| — (LRT) | POST | `/api/v1/uctoo/long_running_task/verify/:taskId` | LRT 核验 | runtime 提供 |
| — (LRT) | POST | `/api/v1/uctoo/long_running_task/deliver/:taskId` | LRT 交付 | runtime 提供 |
| — (LRT) | POST | `/api/v1/uctoo/long_running_task/review/:taskId` | LRT 评审 | runtime 提供 |
| C-010 | POST | `/api/v1/uctoo/long_running_task/evolve/:agentId` | LRT 演进 | runtime 提供 |
| C-010 | GET | `/api/v1/uctoo/long_running_task/trace` | LRT 轨迹 | runtime 提供 |
| — (SDD) | POST | `/api/v1/uctoo/sdd/start` | SDD 启动工程 | runtime 提供 |
| — (SDD) | POST | `/api/v1/uctoo/sdd/run` | SDD 异步编排 | runtime 提供 |
| — (SDD) | POST | `/api/v1/uctoo/sdd/run-stage` | SDD 同步单阶段 | runtime 提供 |
| C-011 | GET | `/api/v1/uctoo/sdd/status/:featureName` | SDD 状态 | runtime 提供 |
| C-012 | POST | `/api/v1/uctoo/sdd/review` | SDD 闸口回执 | runtime 提供 |
| C-024 | POST | `/api/v1/uctoo/permissions/user/menu` | 动态菜单（IAM） | runtime 提供 |

> **数量口径说明（对齐 spec §1.2.8）**：S2 消费 6 条正式契约（C-007~C-012），对应 runtime 已注册端点 **14 个**（LRT 九动作 + SDD 五语义）。SPECS_INDEX 摘要记为「13 接口」，差额为计数口径差异（C-008、C-010 各含 2 端点但按契约各计 1；另 LRT 的 verify/deliver/review 三端点在索引未单列契约编号）。**此差额待 C-007~C-012 冻结时由主工程统一对账**，本设计不臆造解决。

### 5.2 API 详细设计（重点契约）

#### 5.2.1 C-011 SDD 流水线状态
- **请求方法**: GET
- **请求路径**: `/api/v1/uctoo/sdd/status/:featureName`  ← **`/sdd/` 路径不可改**
- **请求参数**: `featureName`（路径参数，工程标识）
- **响应格式**: `{ stage, round, gate, waiting }`
- **错误码**: 未授权 403；工程不存在由 runtime 统一响应

#### 5.2.2 C-012 SDD 闸口回执
- **请求方法**: POST
- **请求路径**: `/api/v1/uctoo/sdd/review`  ← **`/sdd/` 路径不可改**
- **请求参数**: `{ featureName, stage, decision }`，`decision ∈ {confirm, revise, abandon}`
- **响应格式**: `{ nextStage }`
- **错误码**: 403（无决策权限）；非 waiting 态提交由 runtime 拒绝；并发冲突以后端权威回执为准

#### 5.2.3 C-009 LRT 人工干预
- **请求方法**: POST
- **请求路径**: `/api/v1/uctoo/long_running_task/intervene`
- **请求参数**: `{ taskId, action, payload }`（`action` 候选值、`payload` 格式待核对 `LongRunningTaskController` 后确认，前端不猜测）
- **响应格式**: `{ accepted, reason }`（按原样展示）
- **错误码**: 403；状态冲突由 runtime 拒绝，前端刷新权威状态

#### 5.2.4 C-007 / C-008 / C-010
- 路径前缀均为 `/api/v1/uctoo/long_running_task/`，响应字段以 §4.2 表为准，缺失属性显空态不推断。

---

## 6. 接口设计（内部 / 外部）

### 6.1 内部接口（S2 前端模块间）
- 各视图组件经统一 API client 调用 runtime；client 封装：`getTree`/`getProgress`/`getCheckpoints`/`intervene`/`verify`/`deliver`/`review`/`evolve`/`getTrace`/`sddStart`/`sddRun`/`sddRunStage`/`sddStatus`/`sddReview`。
- client 统一处理：鉴权头透传、查询类失败重试 ≤2 次、写动作重试 0 次、单一在途请求控制。

### 6.2 外部接口（S2 依赖的上游，非 S2 实现）
- **C-022（S5 提供）**：S2 的硬开工前置，S2 不实现其路由，仅调用并做 L2 集成验收。确切新增路径由 S5 契约冻结。
- **C-024（IAM 提供）**：动态菜单，S2 消费并据其登记自身入口。
- **C-007~C-012（runtime 提供）**：见 §5。

---

## 7. 安全设计

### 7.1 认证机制
- 沿用 web-admin 既有登录态（token 经 `persisted-uctoo-user` + 注入头透传）；S2 不重新实现认证。
- PC 端登录态由 iframe 内 web-admin 完成，token 经 `postMessage` → `safeStorage`（C-023，归 S6），S2 不触碰。

### 7.2 权限控制（RBAC 双层，R6）
- **菜单层**：C-024 动态菜单树决定入口可见性；未登记即"看不到入口"。
- **API 层**：`RequirePermissionMiddleware` 对所有 C-007~C-012 及业务端点 100% 鉴权；未授权返回 403，前端不降级绕过。
- **登记覆盖**：新增编排台页面/路由，必做 `permissions` + `role_has_permission` 登记，完成后 `loaddbinfo`（§3.7、R6）。
- **超管特例**：超管持通配 `*` 走全量分支，对超管的 `role_has_permission` 改动无效（SPECS_INDEX §8 备忘）。

### 7.3 数据安全
- **审计留痕率 100%**：`intervene`（C-009）与 SDD `review`（C-012）决策必须落 `agent_approvals`；回执成功后强制重查权威状态，未变化提示核对留痕。
- **不替人决策**：`confirm`/`revise`/`abandon` 绝不自动确认、不以超时默认确认（spec §1.4.3、§5.4）。
- **敏感脱敏**：展示敏感内容的脱敏规则待安全评审确认，不在本设计臆造。
- **错误可定位**：所有接口错误展示保留 1 个可定位请求标识（标识名与日志格式待既有前端错误规范确认）。

### 7.4 闸口决策流（confirm / revise / abandon）

```
决策人选中等待中的 gate
   │
   ▼
SddGateDecision 展示：产物 + 三项决策 + 后果说明
   │  confirm → 推进到 nextStage
   │  revise  → 增轮次、保留已确认产物、重做当前阶段
   │  abandon → 终止工程、保留已有产物
   ▼
提交 POST /api/v1/uctoo/sdd/review {featureName, stage, decision}
   │
   ▼
runtime 回执 {nextStage}  →  落 agent_approvals
   │
   ▼
前端强制重查 C-011 状态；若未变化 → 提示核对审批留痕（不展示推进成功假象）
```

---

## 8. 性能设计

### 8.1 性能目标（来自 spec §4.1）
1. 任务树 ≤1000 节点、同屏展开 ≤200 节点时，树视图从收到成功响应到可交互 p95 ≤ 2 秒。
2. 运行中任务默认刷新间隔 5 秒；同一页面同一时刻最多 1 个未完成状态请求。
3. 人工动作提交后 1 秒内进入"提交中"状态；服务端完成时间上限待联调基线确认。

### 8.2 优化策略
- 树视图虚拟化（仅渲染可视节点）应对大任务树。
- 状态轮询串行化：同一 `featureName`/`rootId` 的轮询请求互斥，避免并发放大（§4.1.2）。
- 查询类失败自动重试 ≤2 次（指数退避）；写动作重试 0 次（§4.2.1）。
- 页面恢复可见（visibilitychange）后 10 秒内重新拉取权威状态，不靠前端缓存宣称推进（§4.2.2）。

---

## 9. 部署设计

### 9.1 部署架构
- S2 作为 web-admin 前端模块随 web-admin 构建物部署；**无独立后端服务、无新进程**。
- 入口由 runtime 的 C-024 动态菜单在运行时注入，无需前端静态路由预注册。
- 后端依赖（runtime 的 LRT/SDD 端点、S5 的 C-022）由宿主统一部署，S2 不携带。

### 9.2 环境配置
- 依赖宿主 runtime 已起（SPECS_INDEX §5.3 前置）。
- 依赖 S5 达 `test` 且 C-022 冻结（硬前置）。
- 种子 SQL（`sql/incremental/` 内的菜单/权限/角色授权）需在部署后执行并 `loaddbinfo`。
- 浏览器内核与最低版本待 design 冻结至少 2 个（spec §4.5.3 兼容性要求），联调时定稿。

---

## 10. 附录

### 10.1 参考文档
- `specs/ConsoleClosure/ConsoleClosure--orchestration-desk/spec.md`（需求权威来源）
- `specs/ConsoleClosure/SPECS_INDEX.md`（契约/风险/集成/验收总账）
- `specs/ConsoleClosure/research.md`（三端能力盘点与缺口分析，B1-B8 证据）
- `skills/sdd/SKILL.md`（SDD 方法论、铁律 9/14/15、闸口定义）
- `skills/sdd/templates/design_template.md`（本模板）
- 源码证据：`src/app/routes/uctoo/long_running_task/LongRunningTaskRoute.cj:43-80`、`src/app/routes/uctoo/sdd/SddOrchestrationRoute.cj:26-36`、`src/router/guard/menu.ts:79`

### 10.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-10-30 | sdd-design-writer | 初始设计：覆盖 B1-B8 双能力线、6 表全复用、C-007~C-012 契约、闸口决策流、RBAC 闭环、性能/部署 |
