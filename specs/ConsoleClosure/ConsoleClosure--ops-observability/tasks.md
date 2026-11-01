# 任务规划文档 — S5 系统运维与可观测

> 基于 `spec.md` 与 `design.md` 生成。
> 子系统 ID：**S5** ｜ feature_name：`ConsoleClosure--ops-observability`
> 主工程：`ConsoleClosure` ｜ 契约：C-019 / C-020 / C-021 / C-022 / C-024 ｜ 语言标签：cangjie + web
> 仓颉代码编写须用 cangjie-coder 技能，**严禁运行 cjpm build**（编译与回传由人工在独立 cmd 完成）。
> 前端用 web-coder。本子系统 **0 新建表、0 新建列**（铁律 9），故**无 DDL 任务**，仅有 permissions/role_has_permission 登记 DML（落 `sql/incremental/`，否则 403，风险 R6）。

## 文档信息
- 关联需求：`specs/ConsoleClosure/ConsoleClosure--ops-observability/spec.md`
- 关联设计：`specs/ConsoleClosure/ConsoleClosure--ops-observability/design.md`
- 生成日期：2026-10-30 ｜ 版本：v1.0 ｜ 状态：草稿（待 gate-task 闸口确认）

## 开发规范（全任务强制遵守）
- **语言与工具绑定**：仓颉 → cangjie-coder；前端（Vue/TS）→ web-coder。
- **二次开发底座优先（迭代 runtime / uctoo 时强制）**：
  1. 规范源：先加载 `uctoo-dev-manual`（`skills/uctoo-dev-manual/`），按事项读 `docs/uctoo-v4/*.md`。
  2. 脚手架优先确定性代码生成工具；本子系统无新表/新列，故**不跑 `loaddbinfo`/`crudgen`/`crudweb` 生成新结构**，仅在既有 `AutoRouteConfig.cj` 注册表上加 `RouteEntry`、复用既有 ORM 模型与 `.vue` 页。
  3. 生成后必补：`permissions` + `role_has_permission` 登记（否则 403，R6）。
- **大工程拆分态（铁律 15）**：每条任务标注「本子系统负责」与「不碰（移交/调用上游契约）」；跨子系统一律落成「调用上游契约接口」或「等下游消费」。
- **编译约束**：**AI 不运行 `cjpm build`**；编译/类型检查/lint 由人工执行并回传。
- **复用原则**：优先复用 `design.md §4` 所列既有表、既有 `.vue` 页、既有 ORM 模型，不重新实现。
- **命名约束（严禁违背）**：`skills/sdd`、`/api/v1/uctoo/sdd/` 运行时接口、`sdd_projects` 库表、`sdd-*` 子 agent 名（sdd-researcher 等）、「SDD 编排台」（S2 名）、「SDD 工程」一词保持原样；交叉引用用 `specs/ConsoleClosure/`。

## 任务总览

| 编号 | 任务 | 关联 spec § | 关联 design § | 负责子 agent | 状态 | 预计产出 |
|---|---|---|---|---|---|---|
| T-01 | 绑定五控制器路由（C-022 地基，R3） | §5.3.1-1/2/5 | §3.3 | cangjie-coder | 待开始 | `AutoRouteConfig.cj` +5 RouteEntry |
| T-02 | 占位桩三态如实暴露核实 | §5.3.1-3 | §3.3.3 | cangjie-coder | 待开始 | 端点响应核对记录 |
| T-03 | 死代码处置（5 文件，待用户决策） | §5.4.1-5 | §3.4.5 | cangjie-coder | 阻塞 | 删除或补注册+授权 |
| T-04 | 路由注册无冲突验证 | §5.3.1-2, §4.2-3 | §3.3.2 | cangjie-coder | 待开始 | 启动不报错证明 |
| T-05 | 路径穿越防护白名单核实（C-019） | §4.3-1, §5.1.1-2 | §6.3-1 | cangjie-coder | 待开始 | 核实 `resolvePath` 枚举 |
| T-06 | env 密钥剔除核实（C-020） | §4.3-3, §5.1.1-3 | §6.3-2 | cangjie-coder | 待开始 | 核实 env 仅返回 name/available |
| T-07 | 破坏性动作操作日志补齐 | §4.3-4 | §6.3-3 | cangjie-coder | 待开始 | crontab/del、sync/to-fs、event/unregister 写日志 |
| T-08 | 健康与运行日志运维台页（E1/E2/E3） | §5.1 | §3.1 | web-coder | 待开始 | `views/ops/health-log/index.vue` |
| T-09 | 定时任务运维台（E4） | §5.2.1-1/2, §5.2.3 | §3.2.1 | web-coder | 待开始 | `views/ops/crontab/index.vue` |
| T-10 | 同步运维台（E5 全新建设） | §5.2.1-3, §5.2.3 | §3.2.2 | web-coder | 待开始 | `views/ops/sync/index.vue` |
| T-11 | data_flow.vue 缺陷修正（M3-附带 P2） | §5.2.1-4, §9 M3 | §3.2.2 | web-coder | 待开始 | `views/ai/data_flow/index.vue` 改 |
| T-12 | 能力暴露状态页（R3/C-022） | §5.3.1-1/3 | §3.3 | web-coder | 待开始 | `views/ops/capability-exposure/index.vue` |
| T-13 | 事件处理器管理页（E6） | §5.4.1-1 | §3.4.1 | web-coder | 待开始 | `views/ops/event-handlers/index.vue` |
| T-14 | 执行器切换页（E7） | §5.4.1-1 | §3.4.1 | web-coder | 待开始 | `views/ops/executor/index.vue` |
| T-15 | 行级授权页（E8） | §5.4.1-2, §5.4.3 | §3.4.2 | web-coder | 待开始 | `views/ops/data-access-auth/index.vue` |
| T-16 | 国际化管理页挂载（E9） | §5.4.1-3 | §3.4.3 | web-coder | 待开始 | 挂载 `views/locale/index.vue` |
| T-17 | 既有权限页挂载（R8/G4） | §5.4.1-3, R8 | §3.4.3 | web-coder | 待开始 | `constant.ts` import 4 页 |
| T-18 | setup.vue 挂载（R8/G5） | §5.4.1-3, R8 | §3.4.3 | web-coder | 待开始 | `constant.ts` import setup.vue |
| T-19 | 菜单与权限登记 SQL（R2/R6/C-024） | §5.4.1-4, R6 | §3.4.4, §4.1 | web-coder + cangjie-coder | 待开始 | `sql/incremental/*_s5_permissions.sql` + 执行 loaddbinfo |
| T-20 | 破坏性动作二次确认统一组件（DFX §4.3-4） | §4.3-4, §5.2.1-2 | §6.3-3 | web-coder | 待开始 | 确认弹窗组件复用 |
| T-21 | 三态渲染规范组件（DFX §4.4-2） | §4.4-2, §5.3.1-3 | §3.3.3 | web-coder | 待开始 | 徽标组件(可用/占位桩/待集成) |
| T-22 | 兼容性核对（DFX §4.5） | §4.5 | §3.3.2, §5.3 | cangjie-coder + web-coder | 待开始 | 路径不改/v1 前缀/响应体形状核对 |
| T-23 | 文档口径回写（research 订正，spec 待确认项 5） | §待确认项 5 | §9.2-5 | 主 agent | 待开始 | research.md §5.2-E4 订正 |

## 任务依赖关系图

```
地基链（必须最先，阻塞下游 S2/S4）：
T-01(绑路由) → T-02(桩核实) → T-04(无冲突验证)
T-01 ────────→ T-12(能力暴露状态页, 依赖端点存在)

runtime 核实类（可与 T-01 并行）：
T-03(死代码, 待用户决策)   T-05(路径防护)   T-06(env剔除)   T-07(操作日志)

前端页（消费既有/新增端点）：
T-08(E1-E3健康日志)  T-09(E4定时)  T-10(E5同步)  T-11(data_flow修正)
T-13(E6事件)  T-14(E7执行器)  T-15(E8行级)  T-16(E9国际化)
T-17(R8权限页)  T-18(R8 setup)
   │ （均依赖 C-024 菜单可见，即 T-19 完成）
   └───────────────────────────────┐
T-20(二次确认组件) → 被 T-09/T-10/T-13 引用
T-21(三态组件)   → 被 T-12 引用
T-19(权限登记SQL) → 所有前端页可见前提（R6 403 红线）
T-22(兼容性核对) → 终验前
T-23(research订正) → 与 T-01/T-22 并行收尾
```

> 并行说明：T-01 是 P0 地基，优先开工；T-08~T-18 前端页在既有端点（C-019/020/021/sync/event/exec/data_auth）已存在前提下可与 T-01 并行开发，但 **C-022 相关页（T-12）须等 T-01 路由生效**；全部页须等 **T-19 权限登记**完成才能正常访问（否则 403）。

## 任务详细说明（按编号展开）

### T-01 绑定五控制器路由（C-022 地基，R3）
- **目标**：spec §5.3.1-1/2/5；design §3.3。把 Memory/Model/Storage/Retriever/Executor 五控制器共 16 个方法绑成 HTTP 端点。
- **本子系统负责**：在 `AutoRouteConfig.cj` 新增 5 条 `RouteEntry`（`tableName, routePath, priority, enabled, registerFunc`），priority 300-340。
- **不碰（移交/调用上游）**：严禁改写五个控制器**内部逻辑**（spec §5.3.1-5）；占位桩保持原样透传。
- **步骤**：① 读 `AutoRouteConfig.cj` 现有 `RouteEntry` 结构；② 新增 memory/model/storage/retriever/executor 5 条，路径见 design §5.2；③ `ExecutorController.list` 与既有 `/executor/list`（AutoRouteConfig.cj:1508）**合并复用**，仅补 `getByName`/`listSchemes`；④ 确保 16 方法全绑定、无 404。
- **产出**：`AutoRouteConfig.cj` 改动；5 个 routePath 注册。
- **验收**：逐请求 16 端点均返回 2xx/4xx（非 404）；启动不报错；既有 86 条路由不受影响。
- **风险**：路径冲突（T-04 验证）；AI 不跑 `cjpm build`，编译回传人工。

### T-02 占位桩三态如实暴露核实
- **目标**：spec §5.3.1-3；design §3.3.3。确认 `StorageController.kvGet/kvSet/vectorSearch` 与 `RetrieverController.search` 返回含 `message` 字段，前端据其渲染「未接入」。
- **本子系统负责**：核实响应体 `message` 存在且非空；路由不改写控制器逻辑。
- **不碰**：不实现真实存储/检索（本期仅暴露）。
- **步骤**：① 调 4 个桩端点确认 `message` 透传；② 记录响应样例供 T-12/T-21 使用；③ 若缺 `message` 字段，上报人工（不擅自改控制器）。
- **产出**：端点响应核对记录。
- **验收**：4 个桩端点响应均含 `message`；缺字段时按「未接入」处理（前端侧 T-12/T-21）。

### T-03 死代码处置（5 文件，待用户决策）
- **目标**：spec §5.4.1-5；design §3.4.5。处置 `MockRoute.cj`/`AiDevDemoRoute.cj`/`LanguageOrchestrationRoute.cj`/`PublicCompaniesRoute.cj`/`PublicTasksRoute.cj`。
- **本子系统负责**：按用户决策执行「物理删除」或「补注册 + 权限登记」。
- **不碰**：若选择补注册，仅补 `RouteEntry` + 权限，不改业务。
- **步骤**：① 等用户确认删除或补注册（**当前阻塞**）；② 删除：直接从工程移除 5 文件；补注册：加 `RouteEntry` + T-19 权限登记。
- **产出**：5 文件已删除 或 已注册+已授权。
- **验收**：5 文件处于「已删除」或「已注册+已授权」二者之一，禁止半绑定。
- **风险**：⚠ 当前阻塞于用户决策（spec 待确认项 4）。

### T-04 路由注册无冲突验证
- **目标**：spec §5.3.1-2、§4.2-3；design §3.3.2。新增 5 条 priority 300+ 不影响既有 86 条生效路由。
- **本子系统负责**：验证启动后既有 86 条路由全部生效、新 5 条注册成功。
- **步骤**：① 启动 runtime（人工）；② 核对既有端点与新增端点均可达；③ 确认无重复注册告警。
- **产出**：启动不报错证明。
- **验收**：86 条既有 + 5 条新增均生效，无冲突。

### T-05 路径穿越防护白名单核实（C-019）
- **目标**：spec §4.3-1、§5.1.1-2；design §6.3-1。核实 `RuntimeLogService.resolvePath` 仅枚举 `startup`/`startup-trace`，其余回落主日志。
- **本子系统负责**：服务端白名单核实；前端（T-08）禁传路径。
- **不碰**：不改 `runtime_log_service.cj` 内部逻辑。
- **步骤**：① 核实 `resolvePath` 白名单；② 构造 `../../etc/passwd` 验证回落主日志不暴露外部文件。
- **产出**：核实记录。
- **验收**：非法 `file` 不暴露 `logs/` 之外文件（spec §5.1.1-2a）。

### T-06 env 密钥剔除核实（C-020）
- **目标**：spec §4.3-3、§5.1.1-3；design §6.3-2。
- **本子系统负责**：核实 `ops/env` 仅返回 `{name, available}`，剔除 API Key/口令。
- **步骤**：① 调 `ops/env` 核对无密钥类字段；② 采集器抛异常时返回 500 + `ok=false`（spec §5.1.1-3a）。
- **产出**：核实记录。
- **验收**：响应仅 `name/available`；异常时前端显示「采集失败」非空白。

### T-07 破坏性动作操作日志补齐
- **目标**：spec §4.3-4；design §6.3-3。
- **本子系统负责**：确保 `/crontab/del`、`/sync/to-fs`、`/event-handlers/unregister` 写操作日志（若既有未覆盖则补）。
- **步骤**：① 核查三端点现有是否写操作日志；② 缺失则补写日志调用。
- **产出**：操作日志写入点。
- **验收**：破坏性动作可在操作日志查到记录。

### T-08 健康与运行日志运维台页（E1/E2/E3）
- **目标**：spec §5.1；design §3.1。
- **本子系统负责**：新建运维台外壳页，消费 `/api/v1/health`、`/api/v1/info`、`ops/logs`（C-019）、`ops/env`（C-020）。
- **不碰**：不重写 `runtime_log_service.cj` / `RuntimeCapabilityCollector`。
- **步骤**：① 健康卡片展示 `chatModel.available` + `scheduler` 4 项 + info；② 日志查看器 `file` 仅下拉枚举（T-05 防护）、`lines` 默认 500 封顶 5000、`truncated` 提示；③ env 表格两列；④ 卡片隔离（单 5xx 不整页白屏，spec §4.2-2）。
- **产出**：`views/ops/health-log/index.vue`。
- **验收**：spec §5.1.1 全部验收条件（含 degraded 降级、lines=99999 封顶、日志缺失不返空列表）。

### T-09 定时任务运维台（E4）
- **目标**：spec §5.2.1-1/2、§5.2.3；design §3.2.1。
- **本子系统负责**：crontab 列表 + 8 端点操作，二次确认（T-20）。
- **不碰**：不改 `CrontabRoute.cj` 路径（保持 `scheduler/status` 点号）。
- **步骤**：① 拉状态/running/executors/builtin-tasks；② trigger/pause/resume/reload 动作 + 二次确认；③ 任务不存在标记失效（§5.2.3-1）；调度未初始化常驻告警（§5.2.3-2）。
- **产出**：`views/ops/crontab/index.vue`。
- **验收**：点击触发发 `POST /crontab/trigger/:id` 并展示结果（§5.2.1-1a）。

### T-10 同步运维台（E5 全新建设）
- **目标**：spec §5.2.1-3、§5.2.3；design §3.2.2。
- **本子系统负责**：新建同步运维台，覆盖 sync 七端点。
- **不碰**：不重建 `data_flow.vue`（T-11 仅修缺陷）；不碰 `SyncService` 内部。
- **步骤**：① summary/status/logs/health 展示；② from-fs（文件→库）与 to-fs（库→文件，需 entityType+entityId）分离按钮；③ all 全量同步后轮询 logs；④ 同步不可用时禁用按钮（§5.2.3-3）。
- **产出**：`views/ops/sync/index.vue`。
- **验收**：全量同步调 `POST /sync/all` 并轮询 `/sync/logs`（§5.2.1-3a）；to-fs 传两路径参数（§5.2.1-3b）。

### T-11 data_flow.vue 缺陷修正（M3-附带 P2）
- **目标**：spec §5.2.1-4、research §9 M3-附带；design §3.2.2。
- **本子系统负责**：修正 `views/ai/data_flow/index.vue`「宣称展示同步流却未调用任何 sync 端点」。
- **不碰**：不重写该页，仅修缺陷（接入 `sync/summary` 或 `sync/status` 真实数据，或更正其文案）。
- **步骤**：① 读现有 data_flow.vue；② 接入至少一处 sync 真实数据或更正「展示同步流」文案；③ 保留既有可视化。
- **产出**：`views/ai/data_flow/index.vue` 改动。
- **验收**：页面数据与 sync 端点一致或文案不再误导。

### T-12 能力暴露状态页（R3/C-022）
- **目标**：spec §5.3.1-1/3；design §3.3。
- **本子系统负责**：列出 5 控制器 16 端点，逐个探测（2xx/4xx 非 404），按 `message` 渲染「未接入」徽标（T-21 组件）。
- **不碰**：不实现桩的真实能力。
- **步骤**：① 探测 16 端点；② 标注三态 + 路由路径；③ 缺 `message` 按未接入（§5.3.1-3b）。
- **产出**：`views/ops/capability-exposure/index.vue`。
- **验收**：16 端点全部可达非 404；桩端点显「未接入」徽标。

### T-13 事件处理器管理页（E6）
- **目标**：spec §5.4.1-1；design §3.4.1。
- **本子系统负责**：消费 event-handlers 五端点。
- **步骤**：① active/history 列表；② register/unregister/toggle 操作（unregister 走 T-20 二次确认 + T-07 日志）。
- **产出**：`views/ops/event-handlers/index.vue`。
- **验收**：五端点均可调通并渲染。

### T-14 执行器切换页（E7）
- **目标**：spec §5.4.1-1；design §3.4.1。
- **本子系统负责**：消费 executor switch/list/agent-executor 三端点（其中 list 与 C-022 合并）。
- **步骤**：① list 展示内置 5 种；② switch 切换策略 UI；③ agent-executor 展示。
- **产出**：`views/ops/executor/index.vue`。
- **验收**：三端点可调通；切换生效。

### T-15 行级授权页（E8）
- **目标**：spec §5.4.1-2、§5.4.3；design §3.4.2。
- **本子系统负责**：消费 data_access_authorization 三端点。
- **步骤**：① authorize/revoke 提交；② `:entityType/:entityId/authorizations` 列表；③ 目标不存在提示（§5.4.3-2）。
- **产出**：`views/ops/data-access-auth/index.vue`。
- **验收**：三端点可调通；授权列表正确。

### T-16 国际化管理页挂载（E9）
- **目标**：spec §5.4.1-3；design §3.4.3。
- **本子系统负责**：挂载 `views/locale/index.vue`（36 行 + 子组件已存在）。
- **不碰**：不重写，仅挂路由 + 菜单。
- **步骤**：① 在 `constant.ts`/菜单登记挂 locale；② 登记权限（T-19）。
- **产出**：locale 页可达。
- **验收**：超管菜单可见 locale 入口。

### T-17 既有权限页挂载（R8/G4）
- **目标**：spec §5.4.1-3、R8；design §3.4.3。
- **本子系统负责**：把 `userManager/role/permission/menu` 四页 import 进 `src/router/constant.ts` 路由模块 + 菜单登记。
- **不碰**：页面代码已实现，仅挂载（低成本高收益）。
- **步骤**：① 在 `constant.ts` 补 import；② T-19 补权限登记。
- **产出**：4 页可达。
- **验收**：原「37 条未挂载」中这 4 页可达（spec §5.4.1-3a）。

### T-18 setup.vue 挂载（R8/G5）
- **目标**：spec §5.4.1-3、R8；design §3.4.3。
- **本子系统负责**：挂载 `src/views/setup.vue`（235 行）。
- **步骤**：① `constant.ts` import setup.vue；② T-19 权限登记。
- **产出**：setup.vue 可达。
- **验收**：setup 入口可见。

### T-19 菜单与权限登记 SQL（R2/R6/C-024）
- **目标**：spec §5.4.1-4、R6；design §3.4.4、§4.1。
- **本子系统负责**：为 T-08~T-18 全部新增/挂载页面写 `permissions` + `role_has_permission` 登记 + 菜单树（`type=1 AND menu_type IS NOT NULL`，参考 SPECS_INDEX §8 隐藏菜单机制）。
- **不碰**：0 新建表（铁律 9）；仅 DML 入既有表。
- **步骤**：① 列出全部需登记页面；② 写 `sql/incremental/*_s5_permissions.sql`（permissions 行 + role_has_permission 行，幂等可复跑）；③ 执行 `loaddbinfo`。
- **产出**：`sql/incremental/20261030_s5_permissions.sql` + 执行回执。
- **验收**：超管登录后菜单树返回全部 S5 页面；漏登记 = P0 缺陷（spec §5.4.1-4a）。
- **风险**：⚠ 否则新界面 403（R6），最高频缺陷点。

### T-20 破坏性动作二次确认统一组件（DFX §4.3-4）
- **目标**：spec §4.3-4、§5.2.1-2；design §6.3-3。
- **本子系统负责**：封装确认弹窗组件，供 T-09/T-10/T-13 复用。
- **步骤**：① 通用确认组件（展示任务名/动作说明）；② 未确认不发请求（§5.2.1-2a）。
- **产出**：确认组件。
- **验收**：未确认不请求；破坏性动作均带确认。

### T-21 三态渲染规范组件（DFX §4.4-2）
- **目标**：spec §4.4-2、§5.3.1-3；design §3.3.3。
- **本子系统负责**：徽标组件（可用/占位桩/待集成），各面板标注数据来源端点路径。
- **步骤**：① 三态徽标组件；② 缺 `message` 按未接入；③ 面板显示端点路径。
- **产出**：三态徽标组件。
- **验收**：桩端点显「未接入」；面板标数据来源。

### T-22 兼容性核对（DFX §4.5）
- **目标**：spec §4.5；design §3.3.2、§5.3。
- **本子系统负责**：核对既有端点路径不改（尤其 `crontab/scheduler/status` 点号）、v1 前缀、响应体形状沿用 `{success,data,reason}`/`{ok,...}`。
- **步骤**：① 比对新增/改动端点与源码路径一致；② 确认无第三套响应形状。
- **产出**：核对记录。
- **验收**：路径/前缀/响应形状无漂移。

### T-23 文档口径回写（research 订正，spec 待确认项 5）
- **目标**：spec §待确认项 5；design §9.2-5。
- **本子系统负责**：回写 `research.md §5.2-E4` 把 `scheduler-status` 订正为源码真实的 `scheduler/status`。
- **不碰**：不改代码，仅订正文档。
- **步骤**：① 在 research.md 对应处加订正说明；② 同步 spec 待确认项闭环。
- **产出**：research.md 订正行。
- **验收**：research 与源码路径一致。

## 需求覆盖追踪矩阵

| spec 需求条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §5.1.1-1 健康检查真实化（E1/E2/E3） | T-08 | 全覆盖 | 健康/info/scheduler/chatModel |
| §5.1.1-2 日志来源与口径 | T-08, T-05 | 全覆盖 | file 枚举 + lines 封顶 + 路径防护 |
| §5.1.1-3 环境能力采集 | T-08, T-06 | 全覆盖 | env 仅 name/available |
| §5.1.1-4 禁止项（路径/5xx） | T-08, T-05 | 全覆盖 | 卡片隔离 + 禁拼路径 |
| §5.1.3 异常场景 | T-08 | 全覆盖 | 模型不可用/日志缺失/端点不可达 |
| §5.2.1-1 crontab 端点对齐（E4） | T-09 | 全覆盖 | 8 端点 |
| §5.2.1-2 破坏性二次确认 | T-09, T-20 | 全覆盖 | 统一确认组件 |
| §5.2.1-3 sync 七端点（E5） | T-10 | 全覆盖 | 全新建设 |
| §5.2.1-4 不重建 data_flow | T-11 | 全覆盖 | 仅修缺陷 |
| §5.2.3 异常场景 | T-09, T-10 | 全覆盖 | 任务不存在/调度未初始化/同步不可用 |
| §5.3.1-1 五控制器绑定（R3 地基） | T-01 | 全覆盖 | 16 方法，spec 记 15 以枚举为准 |
| §5.3.1-2 注册方式统一 | T-01, T-04 | 全覆盖 | RouteEntry priority 300+ |
| §5.3.1-3 占位桩如实标注 | T-02, T-12, T-21 | 全覆盖 | 未接入徽标 |
| §5.3.1-4 铁律9 论证 | design §4 + T-19(0 DDL) | 全覆盖 | 0 新建表/列 |
| §5.3.1-5 禁止改内部逻辑 | T-01(边界) | 全覆盖 | 仅加 RouteEntry |
| §5.3.3 异常场景 | T-12 | 全覆盖 | 参数缺失/检索器不存在/桩误判 |
| §5.4.1-1 事件处理器/执行器（E6/E7） | T-13, T-14 | 全覆盖 | 8 端点 |
| §5.4.1-2 行级授权（E8） | T-15 | 全覆盖 | 3 端点 |
| §5.4.1-3 国际化/既有页挂载（E9/G4/G5） | T-16, T-17, T-18 | 全覆盖 | 挂载即可 |
| §5.4.1-4 菜单权限登记（R2/R6/C-024） | T-19 | 全覆盖 | 否则 403 |
| §5.4.1-5 死代码处置 | T-03 | 全覆盖 | 待用户决策删除/补注册 |
| §4.1 性能 | T-08, design §7 | 全覆盖 | 首屏并发 ≤2s |
| §4.2 可靠性 | T-08(隔离), T-01(不影响86), T-04 | 全覆盖 | 单卡片降级 |
| §4.3 安全性 | T-05, T-06, T-07, T-19, T-20, T-09 | 全覆盖 | 路径/密钥/日志/权限/确认 |
| §4.4 可维护性 | T-01, T-21/T-12 | 全覆盖 | RouteEntry + 三态标注 |
| §4.5 兼容性 | T-01, T-22 | 全覆盖 | 路径不改/v1 前缀 |
| **R3 横切 P0** | T-01, T-02 | 全覆盖 | 地基，S2/S4 前置 |
| **R8 既有页挂载** | T-17, T-18 | 全覆盖 | user/role/permission/menu + setup |
| **M3-附带 data_flow 缺陷** | T-11, T-10 | 全覆盖 | E5 全新 + data_flow 修正 |
| E1-E9 / G4 / G5 全量 | 上述任务 | 全覆盖 | 无遗漏 |

## 验收检查清单（终验）

- [ ] **L1（S5 自测）**：spec 每条 EARS 验收条件通过；R3 占位桩如实暴露（T-02/T-12）、R6 权限登记齐备（T-19）、R8 四页+setup 可达（T-17/T-18）；P0 缺陷清零。
- [ ] **L2（跨子系统集成）**：下游 S2/S4 test 步在 S5 `done` 后合并运行态，冒烟 C-022 能力端点全绿（SPECS_INDEX §5.2 用例 3）。
- [ ] **L3（主工程端到端）**：排障场景——制造 runtime 故障 → 运维台看健康告警 + 拉日志定位 → 桌面端托盘变红（跨 S5→S6，SPECS_INDEX §5.1 用例 5）。
- [ ] **DFX**：性能（首屏 ≤2s、health P95≤300ms）、可靠性（卡片隔离、不影响 86 路由）、安全（路径防护 T-05、env 剔除 T-06、权限 T-19、二次确认 T-20）、可维护（RouteEntry T-01、三态 T-21）、兼容（T-22）均验证或标注豁免。
- [ ] **复用项未被重新实现**：0 新建表/列（铁律 9），既有 `.vue` 页仅挂载不重写，既有 ORM 模型复用（design §4）。
- [ ] **编译/类型检查/lint 通过**（人工确认，AI 不跑 `cjpm build`）。
- [ ] **spec / design / tasks / 实现 四者一致**（无漂移）。
- [ ] **T-03 死代码处置闭环**（删除或补注册+授权，禁止半绑定）。
- [ ] **T-23 research 文档订正**完成（scheduler/status 口径）。

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果 |
|---|---|---|---|---|
| 2026-10-30 | v1.0 | 用户委托生成 design + tasks | `design.md` / `tasks.md`（新建） | 待 gate-design / gate-task 闸口确认 |

> 配套：本目录不创建 `contract.md` / `test-report.md`（用户仅要求 design + tasks）；集成契约以 SPECS_INDEX §3 为准。
