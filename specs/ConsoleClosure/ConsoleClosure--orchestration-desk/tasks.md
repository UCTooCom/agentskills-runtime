# S2 长期任务与 SDD 编排台 任务规划文档

## 文档信息
- 关联需求：`specs/ConsoleClosure/ConsoleClosure--orchestration-desk/spec.md`
- 关联设计：`specs/ConsoleClosure/ConsoleClosure--orchestration-desk/design.md`
- 生成日期：2026-10-30
- 版本：v1.0
- 状态：草稿（待 gate-task 确认）
- 主工程账本：`specs/ConsoleClosure/SPECS_INDEX.md`

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：S2 标签为 `web`，前端（Vue/TS）任务一律由 **web-coder** 执行；本子系统**不含仓颉代码**（C-022 属 S5，不在本边界内），故无需 `cangjie-coder`。
- **编译约束**：本子系统无仓颉编译链路；web-admin 前端构建/类型检查/lint 由人工执行并回传结果，AI 不运行构建命令。仓颉相关（若误入本边界）严禁运行 `cjpm build`。
- **二次开发底座优先（铁律 14）**：前端页面沿用 web-admin 既有栈（Vue3 + `src/store/models/uctoo/*` 取数 + 动态菜单注入），不另起炉灶；新增页面靠 C-024 菜单节点 + 路由注入，不写静态路由（除非既有范式要求）。
- **大工程拆分态（铁律 15）**：
  1. 本子系统 ID=S2，`feature_name=ConsoleClosure--orchestration-desk`，上游依赖 S5（C-022 硬前置）。
  2. 每条任务标注「本子系统负责」与「不碰（移交/调用上游契约接口，尤其 S5 的 C-022）」。
  3. 跨子系统接口成对：本子系统只做消费侧（调用 C-007~C-012、C-022），提供侧（runtime/S5 实现）不归本子系统。
  4. 验收带跨边界冒烟（见验收清单 L2 段）。
- **复用优先（铁律 9）**：6 张表全部复用，本子系统**不新增任何表或列**；菜单/权限只往既有 `permissions`/`role_has_permission`/`menu` 插入数据（种子 SQL），不新建表结构 DDL。
- **权限登记（R6）**：所有新增编排台入口与路由，必做 `permissions` + `role_has_permission` 登记，否则 403；登记 SQL 落到 `sql/incremental/`，完成后执行 `loaddbinfo`。
- **契约先行**：所有后端交互以 C-007~C-012 冻结契约为准；字段取值（如 `intervene.action`、`payload`）以 `LongRunningTaskController`/`SddOrchestrationController` 实读为准，前端不猜测。
- **进度与日志**：遵循既有日志/进度通道；多轮修订留痕。

---

## 任务总览

> 编号从 T-01 起；「边界」列标注本子系统负责 / 不碰（移交/调用上游）。
> 「SQL」列：种子数据（菜单/权限）→ `sql/incremental/`；本子系统无新表 DDL（全复用）。
> 「agent」列：前端任务统一 web-coder。

| 编号 | 任务 | 关联 spec § | 关联 design § | 负责子 agent | 边界 | SQL/权限登记 | 状态 | 预计产出 |
|------|------|-----------|--------------|-------------|------|--------------|------|----------|
| T-01 | 读主工程契约与上游前置判定（S5 C-022 状态、blocked 判定） | §1.2.7、§5.5.1 | §2.1、§2.3 | 主 agent | 本子系统负责边界确认；**不碰** S5 的 C-022 实现 | 无 | 待开始 | 边界确认纪要 + 开工闸门结论 |
| T-02 | 搭建编排台前端骨架 + 动态菜单节点登记（C-024） | §1.2.5、§5.5.1 | §3.1、§3.7 | web-coder | 本子系统负责页面骨架/路由注入；**不碰** 菜单服务实现 | 菜单种子 + permission + role_has_permission | 待开始 | `views/orchestration/index.vue` + 种子 SQL |
| T-03 | LRT 任务树可视化（B1，C-007） | §5.1、§6.1 | §3.2 | web-coder | 本子系统负责；**不碰** runtime 的 tree 实现 | 无 | 待开始 | `LrtTaskTree.vue` + API client `getTree` |
| T-04 | LRT 进度与检查点（B2，C-008） | §5.1、§6.2 | §3.2 | web-coder | 本子系统负责；**不碰** runtime 实现 | 无 | 待开始 | `LrtProgressCheckpoint.vue` + `getProgress`/`getCheckpoints` |
| T-05 | LRT 人工干预面板（B3，C-009） | §5.2、§6.3 | §3.3 | web-coder | 本子系统负责；**不碰** 干预业务逻辑 | 无 | 待开始 | `LrtIntervenePanel.vue` + `intervene` |
| T-06 | LRT 核验/交付/评审（B4，verify/deliver/review） | §5.2、§6.3 | §3.3 | web-coder | 本子系统负责；**不碰** 三个端点实现 | 无 | 待开始 | `LrtVerifyDeliverReview.vue` + 三个 client 方法 |
| T-07 | LRT 演进与追踪（B5，C-010） | §5.1、§5.2、§6.4 | §3.2、§3.3 | web-coder | 本子系统负责；**不碰** 演进逻辑 | 无 | 待开始 | `LrtEvolveTrace.vue` + `evolve`/`getTrace` |
| T-08 | SDD 六步流水线可视化（B6，start/run/run-stage/C-011） | §5.3、§6.5 | §3.4 | web-coder | 本子系统负责；**不碰** SDD 编排引擎 | 无 | 待开始 | `SddPipeline.vue`/`SddRunControls.vue`/`SddStatusPoll.vue` |
| T-09 | SDD 五闸口决策界面（B7，C-012） | §5.4、§6.6 | §3.5、§7.4 | web-coder | 本子系统负责；**不碰** 闸口状态机 | 无 | 待开始 | `SddGateDecision.vue` + `sddReview` |
| T-10 | SDD 阶段产物查看（B8，`long_running_task_artifact`） | §5.3、§6.7 | §3.6 | web-coder | 本子系统负责；**不碰** 产物落库逻辑 | 无 | 待开始 | `SddArtifactView.vue` |
| T-11 | 权限 RBAC 双层登记（permissions + role_has_permission + menu 种子） | §5.5、R6 | §3.7、§7.2 | web-coder | 本子系统负责登记；**不碰** 中间件实现 | 菜单+权限+角色授权种子 SQL | 待开始 | `sql/incremental/` 种子 + `loaddbinfo` |
| T-12 | 审计留痕集成（agent_approvals 确认，C-009/C-012 回执后重查） | §1.3.5、§5.4 | §3.8、§7.3 | web-coder | 本子系统负责前端重查；**不碰** `agent_approvals` 表结构（复用） | 无 | 待开始 | 留痕重查逻辑（无新表） |
| T-13 | 前端通用规范：错误标识/空态/防重复提交/轮询串行 | §4.2、§4.4 | §6.1、§8.2 | web-coder | 本子系统负责 | 无 | 待开始 | API client 公共能力 |
| T-14 | 验收用例与 L2 跨边界冒烟（L1 自测 + L2 S2↔S5/S2↔runtime） | §4.4、§5.5 | §9、§7 | 主 agent + web-coder | 本子系统负责验收；**不碰** 上游实现 | 无 | 待开始 | 验收用例集 + L2 冒烟报告 |

---

## 任务依赖关系图

```
T-01（边界/前置判定）
  │  若 S5 C-022 未达 test → S2 标记 blocked，T-02..T-14 顺延
  ▼
T-02（骨架 + 菜单登记）──┬──► T-03 ──► T-04 ──► T-05 ──► T-06 ──► T-07   (LRT 线，可局部并行)
                         │
                         └──► T-08 ──► T-09 ──► T-10                    (SDD 线，可局部并行)
T-11（权限登记）──────────┤ 与 T-02..T-10 并行，但须在验收前完成
T-12（审计留痕）──────────┤ 依赖 T-05、T-09 的写动作完成
T-13（前端通用规范）───────┤ 建议在 T-02 后即做，被 T-03..T-10 复用
                         ▼
                    T-14（L1 + L2 验收，硬闸）
```

- **可并行**：LRT 线 T-03~T-07 与 SDD 线 T-08~T-10 之间无数据耦合，可并行；T-11/T-12/T-13 与业务视图并行推进。
- **须顺序**：T-01 → T-02（先定边界与骨架）；T-14 必须在所有业务任务与权限登记完成后。
- **互相阻塞**：S5 C-022 未达 `test` → 整条 S2 链 blocked（铁律 15 + spec §5.5.1）。

---

## 任务详细说明（按编号展开）

### T-01 读主工程契约与上游前置判定
- **目标**：确认 S2 边界、依赖 S5 的 C-022 状态，给出开工/blocked 结论（spec §1.2.7、§5.5.1）。
- **输入**：`SPECS_INDEX.md`、本子系统 `spec.md`/`design.md`。
- **步骤**：
  1. 复读 SPECS_INDEX §2/§3/§4，确认 S2 上游=S5、契约 C-007~C-012、硬前置 C-022。
  2. 核查 S5 是否达 `test` 且 C-022 冻结；未达成则 S2 状态置 `blocked` 并写明依赖。
  3. 输出边界纪要：明确「本子系统负责」与「移交/调用上游」清单。
- **产出物**：边界确认纪要（落 design 或本任务记录）。
- **验收**：S2 开工前边界清晰；若 C-022 未冻结，系统/台账标记 blocked 而非裸挂。
- **风险**：R3（C-022 实为占位桩未实现完）——S2 不得谎称能力可用，仅做集成验收。

### T-02 搭建编排台前端骨架 + 动态菜单节点登记
- **目标**：建 `views/orchestration/index.vue` 主页（长期任务 / SDD 工程 双入口），并经 C-024 注入路由（design §3.1）。
- **输入**：T-01 边界结论；web-admin 既有菜单注入范式（`src/router/guard/menu.ts:79`）。
- **步骤**：
  1. 建 `orchestration/index.vue` 布局骨架，注册两个一级子视图容器。
  2. **不写静态路由**；改由 T-11 的菜单种子经 C-024 动态注入 `views/orchestration/index.vue`。
  3. 与 T-11 协同确保菜单节点 `component='orchestration/index'`。
- **产出物**：`views/orchestration/index.vue`；与 T-11 种子 SQL 配套。
- **验收**：有权用户登录后菜单出现「长期任务与 SDD 编排台」入口；越权用户无入口（spec §5.5.1 验收条件 2/3）。
- **风险**：R2（菜单漏登记→看不到入口）；R6（权限双层）。

### T-03 LRT 任务树可视化（B1，C-007）
- **目标**：`LrtTaskTree.vue` 调用 C-007 渲染根+子层级（design §3.2）。
- **输入**：T-02 骨架；C-007 路径 `/api/v1/uctoo/long_running_task/tree/:rootId`。
- **步骤**：
  1. API client 加 `getTree(rootId)`（查询失败重试 ≤2 次）。
  2. 组件渲染 `root.{id,title,state,children[]}`；空 `children` 示为叶节点，不推断完成。
  3. 根不存在 → 停止后续查询，提示「任务根不存在或不可见」。
- **产出物**：`LrtTaskTree.vue` + client 方法。
- **验收**：打开有效 `rootId` 展示 C-007 返回根与子层级（spec §5.1.1 验收 1）。
- **边界**：**不碰** runtime 的 tree 端点实现；**不**从附属表 CRUD 自行拼树（spec §5.1.1 业务规则 1）。

### T-04 LRT 进度与检查点（B2，C-008）
- **目标**：`LrtProgressCheckpoint.vue` 调 C-008 区分总体进度与检查点（design §3.2）。
- **输入**：T-03 选中节点 `taskId`。
- **步骤**：
  1. client 加 `getProgress(taskId)`、`getCheckpoints(taskId)`。
  2. 分别展示 `percent`/`currentStage` 与 `checkpoints[]`，明确区分两类数据。
  3. 局部失败（树成功但进度/检查点失败）保留已成功区并允许单独重试。
- **产出物**：组件 + 两个 client 方法。
- **验收**：选中树节点展示该 `taskId` 进度与检查点（spec §5.1.1 验收 2）。
- **边界**：**不**自行枚举未证实阶段（`currentStage` 取自服务端）。

### T-05 LRT 人工干预面板（B3，C-009）
- **目标**：`LrtIntervenePanel.vue` 显式确认后调 C-009（design §3.3）。
- **输入**：T-03/T-04 选中任务；C-009 路径 `/api/v1/uctoo/long_running_task/intervene`。
- **步骤**：
  1. client 加 `intervene({taskId, action, payload})`（写动作重试 0 次）。
  2. 提交前展示目标任务/动作/影响摘要；确认后只提交一次，展示 `accepted`/`reason`。
  3. 按钮在回执前禁用（防重复提交）。
- **产出物**：组件 + client 方法。
- **验收**：确认干预只发一次 C-009 并展示回执（spec §5.2.1 验收 1）。
- **边界**：`action`/`payload` 取值以控制器实读为准，**不猜测**；**不碰** 干预逻辑。

### T-06 LRT 核验/交付/评审（B4）
- **目标**：`LrtVerifyDeliverReview.vue` 承接核验/交付/评审三动作（design §3.3）。
- **输入**：选中任务 `taskId`；三个 runtime 端点 verify/deliver/review（LRT 九动作内，索引未单列契约）。
- **步骤**：
  1. client 加 `verify(taskId)`、`deliver(taskId)`、`review(taskId, feedback)`（重试 0 次）。
  2. 核验/交付必须由人确认后才调用；评审提交反馈后展示是否进入改进流程回执。
  3. 取消即不发送请求；权限不足显无权限提示，不显成功假象。
- **产出物**：组件 + 三个 client 方法。
- **验收**：有权操作者发起核验/交付/评审均展示服务端回执（spec §5.2.1 验收 2/4/5）。
- **边界**：**不**以读取 `lrt_verify_job` CRUD 页代替核验（spec §5.2.1 业务规则 2）；**不碰** 三个端点实现。

### T-07 LRT 演进与追踪（B5，C-010）
- **目标**：`LrtEvolveTrace.vue` 演进（二次确认）+ 轨迹查看（design §3.2/§3.3）。
- **输入**：`agentId`；C-010 `POST .../evolve/:agentId`、`GET .../trace`。
- **步骤**：
  1. client 加 `evolve(agentId)`、`getTrace(params)`（trace 查询参数待核对控制器）。
  2. 演进调用前必须二次确认，禁止页面加载自动触发；取消则不发请求。
  3. 演进回执后刷新 C-010 相关视图，呈现 `evolutionId` 与轨迹；缺失不生成临时标识冒充。
- **产出物**：组件 + 两个 client 方法。
- **验收**：演进被接受时展示回执并刷新演进/追踪区（spec §5.1.1 验收 4）；取消则不发请求（§5.2.1 验收 3）。
- **边界**：**不碰** 演进逻辑；轨迹缺失显空态不推断。

### T-08 SDD 六步流水线可视化（B6）
- **目标**：六步流水线视图 + start/run/run-stage + 状态轮询（design §3.4）。
- **输入**：T-02 骨架；SDD 端点 `start`/`run`/`run-stage`、C-011 `status`（**路径 `/api/v1/uctoo/sdd/` 不可改**）。
- **步骤**：
  1. client 加 `sddStart`/`sddRun`/`sddRunStage`/`sddStatus(featureName)`。
  2. `SddPipeline.vue` 渲染 research(可选)→spec→design→tasks→code→test 六步，区分五个 gate 与六个阶段。
  3. `SddRunControls.vue` 说明 run（异步立即返回）与 run-stage（同步等待）两种语义。
  4. `SddStatusPoll.vue` 按 C-011 的 `stage`/`round`/`gate`/`waiting` 轮询（5s、单一在途）。
- **产出物**：三个组件 + 四个 client 方法。
- **验收**：打开工程展示六步及 research 可选（验收 1）；启动后查状态（验收 2）；选运行模式调对应端点（验收 3）；状态按 C-011 更新（验收 4）。
- **边界**：启动走语义端点，**不**直接编辑 `sdd_projects` CRUD（spec §5.3.1 业务规则 2）；**不碰** SDD 编排引擎。

### T-09 SDD 五闸口决策界面（B7，C-012）
- **目标**：`SddGateDecision.vue` 五闸口 confirm/revise/abandon 决策门面（design §3.5/§7.4）。
- **输入**：T-08 状态；C-012 `POST /api/v1/uctoo/sdd/review`（**`/sdd/` 路径不可改**）。
- **步骤**：
  1. client 加 `sddReview({featureName, stage, decision})`（写动作重试 0 次）。
  2. 等待既定 gate 时高亮阶段并展示决策区；决策前展示后果：confirm 推进 / revise 增轮次重做 / abandon 终止保留产物。
  3. 提交后强制重查 C-011；若状态未变化提示核对审批留痕（不显推进成功假象）。
  4. revise 后显示新轮次并允许回看先前产物（不隐藏历史）。
- **产出物**：组件 + client 方法。
- **验收**：等待 gate 高亮+决策区（验收 1）；无人选则保持 waiting（验收 2）；选任一项先展后果（验收 3）；提交展 nextStage（验收 4）；回执后重查（验收 5）；revise 显新轮次（验收 6）。
- **边界**：**禁止** 自动确认/超时默认确认/主工程代签（spec §1.4.3、§5.4）；**不碰** 闸口状态机。

### T-10 SDD 阶段产物查看（B8）
- **目标**：`SddArtifactView.vue` 关联 `long_running_task_artifact` 展示阶段产物（design §3.6）。
- **输入**：T-08 选中阶段；产物关联字段/读取 API 待核对源码。
- **步骤**：
  1. 组件按工程+阶段+轮次关联展示产物；有则展示，无则显明确空态。
  2. 上游产物缺失（前置校验失败）时不伪造补件，展示拒绝原因。
- **产出物**：组件。
- **验收**：选已有产物阶段展示对应产物，无产物显空态（spec §5.3.1 验收 5）。
- **边界**：仅读取展示，**不**改产物落库逻辑；关联字段以源码为准。

### T-11 权限 RBAC 双层登记
- **目标**：登记菜单节点 + `permissions` + `role_has_permission`，双层一致（design §3.7、R6）。
- **输入**：T-02 的 `component='orchestration/index'`。
- **步骤**：
  1. 写 `sql/incremental/20261030_s2_orchestration_menu_perm.sql`：插 `menu` 节点（`type=1`、`menu_type` 非空、`deleted_at` NULL）、插 `permissions` 编排台权限项、插 `role_has_permission` 授权目标角色。
  2. 执行种子 SQL 后运行 `loaddbinfo`（R6 要求）。
  3. 与 T-02 对齐 `component` 字段解析。
- **产出物**：`sql/incremental/` 种子 SQL（**非新表 DDL，仅既有表插入**）。
- **验收**：有权用户见入口；越权用户无入口且直达 API 被 403（spec §5.5.1 验收 3）；执行 `loaddbinfo` 后权限生效。
- **风险**：R6（漏登记即 403/无入口）；超管走通配分支，对其 `role_has_permission` 改动无效（SPECS_INDEX §8 备忘）。

### T-12 审计留痕集成
- **目标**：C-009/C-012 回执后强制重查权威状态，确认落 `agent_approvals`（design §3.8）。
- **输入**：T-05（intervene）、T-09（review）的写动作回执。
- **步骤**：
  1. 在 `intervene`、`sddReview` 回执成功路径追加「重查权威状态」调用。
  2. 状态未变化时提示核对审批留痕；不把本地成功当落库成功。
- **产出物**：前端重查逻辑（无新表/列）。
- **验收**：干预/闸口决策 100% 留痕；回执后状态与留痕一致（spec §4.3.3、§5.4.1 验收 5）。
- **边界**：**复用** `agent_approvals.*`，不新增列（铁律 9）；**不碰** 表结构。

### T-13 前端通用规范
- **目标**：API client 公共能力——错误标识、空态、防重复提交、轮询串行（design §6.1/§8.2）。
- **输入**：T-03~T-10 共用。
- **步骤**：
  1. 统一 client：鉴权头透传；查询失败重试 ≤2；写动作重试 0；单一在途请求控制。
  2. 错误展示保留 1 个可定位请求标识（标识名待前端错误规范确认）。
  3. 空态组件（缺属性/无产物不推断）。
  4. 防重复提交：写按钮回执前禁用。
- **产出物**：`src/store/models/uctoo/*` 或 API client 公共模块（沿用既有范式）。
- **验收**：写动作无重复提交；查询局部失败可单独重试；错误可定位（spec §4.2、§4.4）。
- **边界**：仅前端层；不引入后端变更。

### T-14 验收用例与 L2 跨边界冒烟
- **目标**：L1 自测全 B1-B8 + L2 跨 S5/S2 与 S2/runtime 冒烟（design §9）。
- **输入**：T-02~T-13 全部产出；S5 达 `test` 且 C-022 冻结。
- **步骤**：
  1. 编写 B1-B8 各 ≥1 条自动化验收用例（spec §4.4.1 需求覆盖率 100%）。
  2. 编写 C-007~C-012 各 ≥1 主干 + 1 异常契约测试（§4.4.2）。
  3. L2 冒烟 ≥3 主干 + 1 异常（见验收清单）。
- **产出物**：验收用例集 + L2 冒烟报告（落 test-report，本任务不创建 test-report.md 之外的额外文档）。
- **验收**：L1 全过；L2 跨边界冒烟全绿；权限/数据不存在/上游超时异常各覆盖。
- **边界**：**不碰** 上游实现；仅消费与集成验收。

---

## 需求覆盖追踪矩阵

> 目标：spec 每条功能需求（B1-B8）+ 关键 DFX 约束都有任务承接。

| spec 需求 / 条目 | 覆盖任务 | 覆盖状态 | 备注 |
|-----------------|---------|---------|------|
| B1 LRT 任务树可视化（§5.1、§6.1） | T-03 | 全覆盖 | C-007 |
| B2 LRT 进度与检查点（§5.1、§6.2） | T-04 | 全覆盖 | C-008 |
| B3 LRT 人工干预（§5.2、§6.3） | T-05 | 全覆盖 | C-009 |
| B4 LRT 核验/交付/评审（§5.2） | T-06 | 全覆盖 | verify/deliver/review 端点 |
| B5 LRT 演进与追踪（§5.1/§5.2、§6.4） | T-07 | 全覆盖 | C-010 |
| B6 SDD 六步流水线可视化（§5.3、§6.5） | T-08 | 全覆盖 | start/run/run-stage + C-011 |
| B7 SDD 五闸口决策（§5.4、§6.6） | T-09 | 全覆盖 | C-012 |
| B8 SDD 阶段产物查看（§5.3、§6.7） | T-10 | 全覆盖 | long_running_task_artifact |
| §1.2.5 / §5.5 动态菜单入口（C-024） | T-02、T-11 | 全覆盖 | 菜单+权限登记 |
| §1.4.7 / R4 不新增表或列（全复用） | T-11、T-12 | 全覆盖 | 6 表全复用，仅种子插入 |
| §4.1 性能（树 p95/5s 轮询/单一在途） | T-08、T-13 | 全覆盖 | 轮询串行+虚拟化 |
| §4.2 可靠性（重试/防重复/重查） | T-05、T-06、T-09、T-12、T-13 | 全覆盖 | 写动作重试 0、防重复提交 |
| §4.3 安全性（鉴权 100%/权限登记/RBAC/留痕） | T-11、T-12 | 全覆盖 | R6 + agent_approvals |
| §4.4 可维护性（需求/契约覆盖） | T-14 | 全覆盖 | B1-B8 各 ≥1 用例 |
| §4.5 兼容性（不删存量 CRUD 页/浏览器矩阵） | T-14 | 全覆盖 | 存量页回归 100% |
| §5.5.1 C-022 硬开工门槛（S5 依赖） | T-01 | 全覆盖 | blocked 判定 |
| §1.4.2 不新增/猜测 API | 全部（T-02~T-10） | 全覆盖 | 仅消费已注册端点 |

---

## 验收检查清单（终验）

- [ ] **L1 单子系统自测**：B1-B8 每条需求有对应实现并通过 spec 验收条件（T-03~T-10、T-14）。
- [ ] **契约测试**：C-007~C-012 各 ≥1 主干 + 1 异常（T-14）。
- [ ] **L2 跨边界冒烟（≥3 主干 + 1 异常）**：
  - [ ] 主干1（跨 S5→S2）：S5 的 C-022 达 test 后，启动 SDD 工程 → C-011 返回 `spec` 阶段 → 编排台正确渲染进度。
  - [ ] 主干2（跨 S2→runtime）：提交长程任务 → 编排台任务树展开、进度推进 → 触发人工干预（C-009）→ 闸口决策（C-012）生效 → 任务继续。
  - [ ] 主干3（跨 S2→runtime）：SDD 工程推进到某 gate → 编排台五闸口高亮 → 决策 confirm/revise/abandon 后 C-011 状态按预期变化。
  - [ ] 异常：低权限用户打开编排台 → 菜单无入口且直达 API 返回 403（R6）。
- [ ] **权限登记（R6）**：菜单节点 + `permissions` + `role_has_permission` 已登记并执行 `loaddbinfo`；越权 403 已验证。
- [ ] **复用项未被重新实现**：6 张表全复用，无新表/列 DDL（仅有 `sql/incremental/` 种子插入）；`agent_approvals` 等仅读展示。
- [ ] **C-011/C-012 路径为 `/api/v1/uctoo/sdd/`**：未改成 ConsoleClosure 或其它前缀（铁律命名规则）。
- [ ] **S5 前置**：若 C-022 未达 test，S2 标记为 blocked 且不绕过依赖（T-01）。
- [ ] **存量页兼容**：未删除/改写现有四张 CRUD 页，回归通过率 100%（§4.5.2）。
- [ ] **编译/类型/lint**：web-admin 前端构建与 lint 由人工确认通过（无仓颉，不涉及 cjpm build）。
- [ ] **三文档一致**：spec/design/tasks 与最终实现无漂移（铁律 12 落盘优先）。

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果 |
|------|------|---------|-------------|---------|
| 2026-10-30 | v1.0 初稿 | S2 design/task 步派生 | `design.md`（新建）、`tasks.md`（新建） | 待 gate-task 确认 |

> 多轮 revise 时在此追加行：每轮记录触发来源（如 spec 冻结字段变更、C-007~C-012 契约对账结果）、改动文件、验证结果；P0/P1/P2 问题表与防回归锚点随轮次补充。
