# 任务规划文档（S1 技能与插件控制台）

> 基于 `spec.md` 与 `design.md` 生成。实施原则：**复用优先**、**确定性优先**、**二次开发底座优先**、**大工程拆分边界明确**。
> 仓颉代码编写须使用 cangjie-coder 技能；**严禁运行 cjpm build**（编译与回传由人工在独立环境完成）。
> 前端使用 web-coder；PC 端使用 app-coder。

## 文档信息
- 关联需求：`specs/ConsoleClosure/ConsoleClosure--skill-console/spec.md`
- 关联设计：`specs/ConsoleClosure/ConsoleClosure--skill-console/design.md`
- 主工程账本：`specs/ConsoleClosure/SPECS_INDEX.md`
- 生成日期：2026-10-30 ｜ 版本：1.0 ｜ 状态：草稿（待 gate-task 闸口确认）

## 开发规范（全任务强制遵守）
- **语言与工具绑定**：仓颉 → cangjie-coder；Web 前端（Vue/TS）→ web-coder；PC 端（Electron）→ app-coder。
- **二次开发底座优先（迭代 runtime/uctoo 时强制）**：
  1. 规范源：先加载 `uctoo-dev-manual`（`skills/uctoo-dev-manual/`），按要做的事读对应 `docs/uctoo-v4/*.md`。
  2. 脚手架优先确定性工具：`loaddbinfo`（灌表结构）→ `plugingen`/`crudgen`（仅宿主 `src/app/` 公共基础设施）/`crudweb`（管理界面）；命令 `cjpm run --skip-build --name <包名> --run-args "<参数>"`。
  3. 工具链坑位：`loaddbinfo` 命令行有未修问题，退到 Web 端「数据库管理 → 加载数据库信息」；crudgen 编译报 `@DAO` 错看 `docs/uctoo-v4/crud-generator-v2.md`。
  4. **生成后必补**：新增表/列的 DDL 放 `sql/incremental/`（新增须先论证复用不成立，铁律 9）；新增宿主路由必做 `permissions` + `role_has_permission` 登记，否则 403。
  5. 只在生成物上做最小适配，不另起炉灶。
- **大工程拆分态（铁律 15）**：
  1. 本子系统 ID=S1，`feature_name=ConsoleClosure--skill-console`，无上游依赖，最高业务优先级，标签 web+app。
  2. **每条任务标注「本子系统负责」与「不碰（移交/调用上游契约接口）」**；跨子系统一律落成"调用上游契约接口"或"等下游消费"，不许顺手改别处。
  3. 契约先行：本子系统消费 C-001~C-006 既有 v1 契约，不新增 runtime 路由（spec §1.4）；如需服务端改动仅限 M5 埋点与 A10 双语读取（均不产生新路由）。
  4. 验收带跨边界冒烟：≥3 主干 + 1 异常（见验收清单）。
- **编译约束**：AI 不运行 `cjpm build`；编译/类型检查/lint 由人工执行并回传结果。
- **复用原则**：优先复用 `src/store/models/uctoo/*`（97 个 Model），禁止在遗留 `src/api/*` thin 层另起封装。
- **命名/注释/错误处理**：遵循 `uctoo-dev-manual` 与 legacy `design-principles.md`。

---

## 任务总览

| 编号 | 任务 | 关联 spec § | 关联 design § | 负责子 agent | 状态 | 预计产出 |
|---|---|---|---|---|---|---|
| T-01 | 新界面权限与菜单登记（R2/R6 基座，覆盖全部 6+ 界面） | §1.3,§4.3,§5.1.1,§5.6.1 | §2.3 M6, §3.6 | web-coder | [ ] 待开始 | `permissions`/`role_has_permission`/菜单行 + `loaddbinfo` |
| T-02 | 技能目录列表页（Web，C-001） | §5.1.1 | §3.1 | web-coder | [ ] 待开始 | `SkillList.vue` + Model 封装 |
| T-03 | 技能关键词检索（Web，C-001 search） | §5.1.1 | §3.1 | web-coder | [ ] 待开始 | 检索替换列表逻辑 |
| T-04 | 技能安装/更新页（Web，C-002） | §5.2.1 | §3.1, §5.2.2 | web-coder | [ ] 待开始 | 安装/更新表单 + 来源/重名校验 |
| T-05 | 技能卸载（含引用阻断，C-002 del） | §5.2.1 | §3.1, §5.2.2 | web-coder | [ ] 待开始 | 卸载确认弹窗 + `agents.skill_name` 引用数 |
| T-06 | 技能详情与内容页（Web，C-001/:id + C-003） | §5.3.1 | §3.1 | web-coder | [ ] 待开始 | `SkillDetail.vue` + 内容只读渲染 |
| T-07 | 合规校验页（Web，C-004） | §5.3.1 | §3.1 | web-coder | [ ] 待开始 | `SkillValidation.vue`（单技能/安全/全库） |
| T-08 | M5 用量埋点修复（cangjie，runtime） | §5.4.1, SPECS_INDEX §9 | §2.3 M5, §3.5, §5.2.1 | cangjie-coder | [ ] 待开始 | `incrementUsage()` 调用点接入（人工编译） |
| T-09 | 用量统计可视化页（Web，C-005） | §5.4.1 | §3.1, §5.2.1 | web-coder | [ ] 待开始 | `SkillUsage.vue` + 成功率计算 |
| T-10 | 插件运行时管理页（Web，C-006） | §5.5.1 | §3.1 | web-coder | [ ] 待开始 | `PluginRuntime.vue`（inspect/activate/deactivate/refresh） |
| T-11 | PC 端技能页数据层（app，A7） | §5.5.1, research §6 A7 | §2.3 M4, §3.4 | app-coder | [ ] 待开始 | `electron/main/index.ts` `skills:*` 真实取数 |
| T-12 | PC 端智能体页数据层（app，A8） | §5.5.1, research §6 A8 | §2.3 M4, §3.4 | app-coder | [ ] 待开始 | `AgentsView.vue` + 智能体取数 IPC |
| T-13 | 智能体列表上游入口（Web，A9/W1） | §5.6.1 | §3.2 | web-coder | [ ] 待开始 | 可点击列表带 id 跳转 `/ai/agent_detail/:id` |
| T-14 | 智能体详情页补全（Web，A9/W1） | §5.6.1 | §3.2 | web-coder | [ ] 待开始 | `agent_detail/index.vue` id 健壮性 + 四段真实数据 |
| T-15 | 双语数据建模（DDL + 存量迁移，A10/R9） | §5.7.1, §6.6, R9 | §4.3 | cangjie-coder/sql | [ ] 待开始 | `sql/incremental/` 单列 JSON（条件）+ 回填脚本 |
| T-16 | 双语读取 Service 层（cangjie，A10/R9） | §5.7.1, §6.6 | §3.5, §4.3 | cangjie-coder | [ ] 待开始 | 按 locale 取+回退逻辑（人工编译） |
| T-17 | 技能页 i18n 修复与操作生效（Web，A10/W2） | §5.7.1, §6.6, R9 | §3.3 | web-coder | [ ] 待开始 | `agent_skills.vue` 全走词条 + 操作绑定 |
| T-18 | L1 自测 + L2 跨边界冒烟（验收） | 全文 | §8, §9.2 | web-coder | [ ] 待开始 | 自测报告 + 冒烟用例结果 |

---

## 任务依赖关系图
```
T-01(权限菜单基座) ──┬──> T-02 ──> T-03
                     ├──> T-04 ──> T-05
                     ├──> T-06
                     ├──> T-07
                     ├──> T-09 ──> T-08(M5 埋点, cangjie, 上游 runtime)
                     ├──> T-10
                     ├──> T-14 ──> T-13(上游入口)
                     └──> T-17 ──> T-15 ──> T-16 (A10 双语链, cangjie)

T-11(PC 技能数据) ── 依赖 S6 C-023 提供 address/token（L1 用手动配置测）
T-12(PC 智能体数据) ─ 同上依赖 C-023；A8 归属待主工程闸口确认，可能移交 S6

T-18(验收) ── 依赖 T-01~T-17 全部 done
```
- **可并行**：T-02~T-07、T-09、T-10、T-13、T-14、T-17（Web 前端，互不阻塞，仅共享 T-01 基座）。
- **须顺序**：T-15 → T-16（DDL 先于 Service）；T-08 → T-09（埋点先于可视化有数据）；T-13 → T-14（入口先于详情补全验证）。
- **跨界阻塞**：T-11/T-12 依赖 S6 的 C-023（address/token 桥）；S1 自身 L1 可用手动配置绕过，不阻塞本子系统 done。

---

## 任务详细说明（按编号展开）

### T-01 新界面权限与菜单登记（R2/R6 基座）【本子系统负责】
- **目标**：满足 R2（菜单登记可追溯）/R6（权限 RBAC 双层）硬约束，确保 6+ 新界面"做了且看得到、调得到"。
- **输入**：各页面任务（T-02~T-14/T-17）落定的 `component` 路径与路由标识。
- **步骤**：
  1. 为每个新界面在 `permissions` 表登记路由权限行；
  2. 在 `role_has_permission` 为至少一个角色（超管/系统管理员）授权；
  3. 在菜单树登记 `component`（须与 `views/${component}.vue` 可解析，避免白屏）；
  4. 执行 `loaddbinfo` 刷新元数据（顺序：先权限+菜单，后 loaddbinfo）；
  5. 逐项核对：超管可见入口、低权限角色无入口且直接调 API 返回 403。
  - 覆盖界面清单：技能目录、技能详情/内容、合规校验、用量统计、插件运行时、智能体详情（A9）、技能页（A10）。
- **产出物**：`permissions`/`role_has_permission`/菜单行 DML + `loaddbinfo` 执行记录。
- **验收**：L3 用例 1/4 显式校验入口可见（SPECS_INDEX §5.2）；缺权限排查而非前端 bug 排查。
- **风险**：R6 — 漏登记表现为"无入口"而非 403，易误判为前端 bug。
- **边界**：**本子系统负责**全部登记动作；**不碰** runtime 路由定义本身（C-024 已冻结）。

### T-02 技能目录列表页（Web，A1/C-001）【本子系统负责】
- **目标**：实现 spec §5.1.1 目录默认展示，调用 `GET /api/v1/uctoo/skills`（C-001）。
- **输入**：T-01 基座（菜单入口已登记）。
- **步骤**：
  1. 复用 `src/store/models/uctoo/agent_skills.ts` 封装 `fetchSkills(query)`；
  2. 渲染技能卡片列表（name/version/validation_status 同源一致）；
  3. 实现 `page`/`limit` 翻页，两页条目无重复；
  4. 首屏 ≤2s，50 条数据量。
- **产出物**：`src/views/ai/skill_console/SkillList.vue` + Model 封装。
- **验收**：打开首页 2s 内出现卡片；翻页无重复；禁止以 `agent_skills` 表 CRUD 页替代交付（spec §5.1.1 禁止项）。
- **风险**：R4 复用 — 禁止在 `src/api/*` thin 层另起封装。
- **边界**：**不碰** runtime 路由；**调用** C-001 契约。

### T-03 技能关键词检索（Web，A1/C-001 search）【本子系统负责】
- **目标**：spec §5.1.1 关键词检索，调用 `POST /api/v1/uctoo/skills/search`。
- **步骤**：提交关键词 → 以下发结果替换列表；无命中 → 展示「无匹配技能」且不残留上次结果。
- **产出物**：检索逻辑（可并入 SkillList.vue）。
- **验收**：提交关键词列表仅留命中项；空结果不残留。
- **边界**：调用 C-001 search 契约。

### T-04 技能安装/更新页（Web，A2/C-002）【本子系统负责】
- **目标**：spec §5.2.1 安装提交与更新提交。
- **步骤**：
  1. `POST /api/v1/uctoo/skills/add`（C-002）传 source/sourceType；
  2. 提交前校验：source/sourceType 必填成对；重名（`agent_skills.name` 唯一）阻断并提示改更新；
  3. `POST /api/v1/uctoo/skills/edit`（C-002）刷新条目版本号。
- **产出物**：安装/更新表单组件。
- **验收**：合法来源 → 列表新增卡片；更新 → 版本号变新值；重名不新增并提示。
- **边界**：调用 C-002；**不碰** runtime 路由。

### T-05 技能卸载（含引用阻断，A2/C-002 del）【本子系统负责】
- **目标**：spec §5.2.1 卸载确认与引用阻断。
- **步骤**：
  1. 发 `POST /api/v1/uctoo/skills/del` 前弹确认；
  2. 查 `agents.skill_name` 引用数，>0 时弹窗展示数量并要求显式确认；
  3. 成功后列表立即移除该条目（不依赖下次全量刷新）。
- **产出物**：卸载确认弹窗组件。
- **验收**：被 2 个 Agent 引用 → 弹窗显示「被 2 个智能体引用」；取消 → 技能仍在列表。
- **边界**：只读 `agents` 表（引用判定），不碰 agents 业务态管理。

### T-06 技能详情与内容页（Web，A3/C-001/:id + C-003）【本子系统负责】
- **目标**：spec §5.3.1 详情展示 + 内容读取。
- **步骤**：
  1. `GET /api/v1/uctoo/skills/:id`（C-001）展示名称/描述/版本/来源/校验状态；
  2. `GET /api/v1/uctoo/skills/:name/content`（C-003）只读渲染 SKILL.md 全文（≤200KB，≤3s）；
  3. 内容为空 → 展示「该技能暂无内容」。
- **产出物**：`SkillDetail.vue`。
- **验收**：详情与列表卡片字段一致；内容 3s 内展示；空内容不阻断页面。
- **边界**：调用 C-001/C-003。

### T-07 合规校验页（Web，A4/C-004）【本子系统负责】
- **目标**：spec §5.3.1 合规校验与留痕。
- **步骤**：
  1. `POST /api/v1/uctoo/skill/validate`（单技能）→ 结论 + 问题清单；
  2. `POST /api/v1/uctoo/skill/validate-security`（安全）→ 安全问题分栏；
  3. `GET /api/v1/uctoo/skill/validate-all`（全库）→ 受检总数 + 不通过数；
  4. 完成时以 `validation_status` + `last_validated_at` 留痕。
- **产出物**：`SkillValidation.vue`。
- **验收**：单技能/安全/全库三种结论正确分区；刷新详情状态与时间已更新。
- **边界**：调用 C-004（AutoRouteConfig.cj:1519-1522）；不碰校验服务端逻辑（只消费）。

### T-08 M5 用量埋点修复（cangjie，runtime）【本子系统负责·边界豁免】
- **目标**：修 SPECS_INDEX §9 M5 — `SkillUsageStatsService.incrementUsage()` 全仓无调用点 → 用量字段永不累加。
- **输入**：无（基于既有 runtime 执行路径）。
- **步骤**：
  1. 定位技能执行既有路径（如 `POST /skills/execute` 或服务端执行入口）；
  2. 在该路径内补一个对既有 `incrementUsage()` 的调用（**不产生新路由、不改对外契约**）；
  3. 确保 `POST /api/v1/uctoo/skill_usage_stats/increment-usage`（C-005）底层真正调用 `incrementUsage()`。
- **产出物**：runtime 仓颉改动（1 处调用点接入）。
- **验收**：执行一次技能 → 该技能 `use_count` +1；T-09 界面随之更新。
- **风险**：**AI 不运行 `cjpm build`**，由人工编译回传；改动须过 `code-gen-verifier` 思路的自检。
- **边界（重要）**：属 spec §1.4「不改 runtime 路由」的豁免项（M5 由主工程 §9 显式指派 S1）；**严禁借此新增/修改其他路由**；如需其他服务端改动须回 SPECS_INDEX §6 登记。

### T-09 用量统计可视化页（Web，A5/C-005）【本子系统负责】
- **目标**：spec §5.4.1 排行展示 + 成功率。
- **步骤**：
  1. `GET /api/v1/uctoo/skill_usage_stats/top-used?limit=N`（C-005）渲染 `use_count` 降序；
  2. 由 `success_count`/`failure_count` 计算成功率（前端算，禁止本地累加）；
  3. 依赖 T-08 埋点使数据非空。
- **产出物**：`SkillUsage.vue`。
- **验收**：打开 2s 内展示排行；成功 8 失败 2 → 80%；断开服务端后不出现本地假计数。
- **边界**：调用 C-005；**不碰** runtime 统计端点。

### T-10 插件运行时管理页（Web，A6/C-006）【本子系统负责】
- **目标**：spec §5.5.1 插件检视/启停/增量发现。
- **步骤**：
  1. `POST /api/v1/tools/plugin_inspect` 展示运行时态；
  2. `plugin_activate`/`plugin_deactivate` 刷新状态；
  3. `plugin_refresh` 在新增目录后刷新列表（无需重启 runtime）。
- **产出物**：`PluginRuntime.vue`。
- **验收**：检视展示状态不依赖本地缓存；激活/停用状态正确；刷新后出现新技能。
- **边界**：调用 C-006（ToolRoutes.cj:39 + main.cj:602-606）；`plugin_state` 暂不落表（design §4.1）。

### T-11 PC 端技能页数据层（app，A7）【本子系统负责·PC 数据层】
- **目标**：research §6 A7 — `electron/main/index.ts:583-585` 硬编码空数组、`skills:getDetail`/`skills:install` 返回 `Not implemented`。
- **步骤**：
  1. 在 `electron/main/index.ts` 实现 `skills:list`/`skills:getDetail`/`skills:install` IPC；
  2. 经 `electron/modules/ipc.ts` HTTP 调用 runtime（C-001/C-002）；
  3. 地址与 token 经 C-023 桥（S6 归口），L1 用手动配置代替。
- **产出物**：`electron/main/index.ts` + `ipc.ts` 改动。
- **验收**：打开 PC 技能页展示与 Web 同账号技能；安装返回成功或明确失败。
- **边界**：**不碰** PC 页面壳/导航（归 S6 混合模式 iframe）；**依赖** S6 C-023 提供 address/token（L1 用手动配置测，不阻塞 S1 done）。

### T-12 PC 端智能体页数据层（app，A8）【本子系统负责·数据层；归属待确认】
- **目标**：research §6 A8 — `AgentsView.vue:4` 写死 `agents=[]`。
- **步骤**：
  1. `AgentsView.vue` 接入真实取数；
  2. IPC 经 `GET /api/v1/uctoo/agents/:limit/:page`（AutoRouteConfig.cj:1386）拉取渲染。
- **产出物**：`AgentsView.vue` + 对应 IPC。
- **验收**：打开智能体页展示库中名称与描述；空库展示空态。
- **边界备注**：spec §5.5.1 标注 A8 同时出现在 S1 与 S6，归属待主工程闸口确认；**若闸口将 A8 整体划 S6，则本任务移交 S6，S1 仅保留 C-001 契约消费**。

### T-13 智能体列表上游入口（Web，A9/W1）【本子系统负责】
- **目标**：spec §5.6.1 上游入口 — 提供可点击智能体列表带 id 跳详情。
- **步骤**：
  1. 在 AI 中心补（或复用）智能体列表页，调用 `GET /api/v1/uctoo/agents/:limit/:page`；
  2. 点击行携带 `id` 跳 `/ai/agent_detail/:id`；
  3. 库内 `agents` 现 9 条均可达。
- **产出物**：智能体列表入口（可并入现有 AI 中心页）。
- **验收**：点击任意一行 → URL 带 id 且详情页展示对应数据。
- **边界**：**不碰** Agent 业务态管理（上下文/消息/任务/记忆/审批不属本范围）。

### T-14 智能体详情页补全（Web，A9/W1）【本子系统负责】
- **目标**：spec §5.6.1 — `agent_detail/index.vue` 已完成取数但 `route.params.id` 为空即渲染「Agent 未找到」。
- **步骤**：
  1. 增加 `route.params.id` 为空/不存在的回落逻辑（跳列表或明确引导，禁止裸「Agent 未找到」）；
  2. 四段数据（task/context/memory/详情）真实渲染并分页（615/371 量级）；
  3. 任一 fetch 失败 → 该标签页内错误+重试，整页不白屏。
- **产出物**：`agent_detail/index.vue` 改动（复用既有取数逻辑）。
- **验收**：从列表点入 → 展示名称/类型/状态 + 四分页；直接访问无 id → 回落列表；库内 9 条可达。
- **边界**：配合 T-01 完成 `menu.ai.agentDetail` 权限/菜单登记（R6）。

### T-15 双语数据建模（DDL + 存量迁移，A10/R9）【本子系统负责·需新 DDL】
- **目标**：design §4.3 — 补 `agent_skills` 双语建模缺口（R9）。
- **步骤**：
  1. **先核查** `agent_skills` 是否已有 JSON 容器列（`config`/`extra_metadata`/`meta`）；
  2. **若有** → 直接复用该列内嵌 `{name:{zh,en},description:{zh,en}}` 子树，**零新增列**；
  3. **若无** → 新增单列 `agent_skills.i18n`（JSONB/JSON），铁律 9「复用不成立」论证见 design §4.3（语义不符 i18 词条表 / 52 列无容器列 / per-record 维度）；
  4. 写 `sql/incremental/` 幂等 DDL + 存量回填脚本（109 条标量 name/description 回填为 `zh`，英文缺失自然回退中文）；
  5. 执行 `loaddbinfo` 刷新 `db_info`。
- **产出物**：`sql/incremental/20261030_agent_skills_i18n.sql`（条件性）+ 回填脚本。
- **验收**：切换英文 → 展示英文；切回中文 → 中文；缺语种 → 回退另一语种而非空/key。
- **风险**：R4 — 若新增列必须附 design §4.3 论证；**不新建表**。
- **边界**：**本子系统负责** DDL（R9 显式指派 S1）；**不碰** runtime 路由。

### T-16 双语读取 Service 层（cangjie，A10/R9）【本子系统负责】
- **目标**：design §4.3 读取/回退逻辑。
- **输入**：T-15 DDL 完成。
- **步骤**：在既有 `agent_skills` 查询方法内增加按 locale 取 `i18n[field][locale]` → 回退另一语种 → 回退标量的逻辑（**不产生新路由**）。
- **产出物**：runtime 仓颉改动（查询方法增强）。
- **验收**：缺语种返回可读文案，绝不返回空或 key。
- **边界**：**AI 不运行 `cjpm build`**；人工编译回传。

### T-17 技能页 i18n 修复与操作生效（Web，A10/W2）【本子系统负责】
- **目标**：spec §5.7.1 — 界面层 i18n 半途而废 + 操作须真实生效。
- **步骤**：
  1. `agent_skills.vue:20-25` 的 `serviceOptions` 全量走 `t()`，清除裸 key（`agentSkills.options.all` 等）+ 硬编码中文（「服务端」「浏览器端」）；
  2. 补 `agentSkills.options.all/services/functions` + 「服务端」「浏览器端」的 i18n key 到 `i18` 词条表（幂等 `INSERT ... WHERE NOT EXISTS(key+lang_id)`，SPECS_INDEX §10.2 机制）；
  3. 确认页面操作（安装/卸载/更新/刷新/搜索/分页）真实绑定到 C-001/C-002，禁止静默无响应；未实现项显式标注不可用。
- **产出物**：`agent_skills.vue` 改动 + `i18` 词条补录 SQL。
- **验收**：切英文无中文残留、无裸 key；每项操作有明确反馈。
- **边界**：**词条录入界面属 S5(E9)**，本子系统只消费并补 key，不重复建设。

### T-18 L1 自测 + L2 跨边界冒烟（验收）【本子系统负责】
- **目标**：spec/design 全部需求验收 + SPECS_INDEX §5.2 L2 冒烟。
- **步骤**：
  1. L1：逐条 spec 验收条件（A1-A10）通过；P0 缺陷清零；
  2. L2（与已 done 上游 runtime 合并态）：≥3 主干 + 1 异常（见验收清单）。
- **产出物**：自测记录 + 冒烟结果（不新建 test-report.md，结果汇入主工程验收）。
- **验收**：下游 S6 集成时本子系统已 done（SPECS_INDEX §5 依赖序）。
- **边界**：L3 主工程端到端由主工程 test 步执行。

---

## 需求覆盖追踪矩阵

| spec 需求 / 条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| A1 技能目录浏览与检索 | T-01, T-02, T-03 | 全覆盖 | C-001 列表+检索+菜单(R2)+权限(R6) |
| A2 安装/更新/卸载 | T-01, T-04, T-05 | 全覆盖 | C-002；含 `agents.skill_name` 引用阻断 |
| A3 技能详情与内容 | T-01, T-06 | 全覆盖 | C-001/:id + C-003 |
| A4 合规校验 | T-01, T-07 | 全覆盖 | C-004 三条 |
| A5 用量统计可视化 | T-01, T-08, T-09 | 全覆盖 | M5 埋点(T-08) + top-used(T-09) |
| A6 插件运行时管理 | T-01, T-10 | 全覆盖 | C-006 inspect/activate/deactivate/refresh |
| A7 PC 端技能页打通 | T-11 | 全覆盖 | 数据层；页面壳归 S6 |
| A8 PC 端智能体页打通 | T-12 | 全覆盖（归属待确认） | 数据层；若划 S6 则移交 |
| A9 智能体详情页补全（W1） | T-01, T-13, T-14 | 全覆盖 | 上游入口 + id 健壮性 + 四段数据 |
| A10 技能双语建模与界面（W2/R9） | T-01, T-15, T-16, T-17 | 全覆盖 | DDL(T-15)+Service(T-16)+i18n(T-17) |
| M5 用量埋点缺陷 | T-08 | 全覆盖 | SPECS_INDEX §9 显式指派 S1 |
| R9 双语数据模型缺位 | T-15, T-16, T-17 | 全覆盖 | design §4.3 论证 |
| R10 登录态半成品 | （移交 S6 C-023） | 不覆盖（配合） | spec §1.3：本子系统只在 A10 界面配合，持久化归口 S6 |
| R2 动态菜单未登记 | T-01 | 全覆盖 | 每界面登记 |
| R4 复用论证缺失 | T-15（design §4.3） | 全覆盖 | 铁律 9 论证 |
| R6 权限 RBAC 双层 | T-01 | 全覆盖 | permissions+role_has_permission+loaddbinfo |
| C-001~C-006 契约消费 | T-02~T-10, T-11, T-12 | 全覆盖 | 单向消费，不新增路由 |
| DFX 性能（§4.1） | T-02, T-06, T-09, T-11 | 全覆盖 | 首屏≤2s/内容≤3s/用量≤2s/PC≤2s |
| DFX 可靠性（§4.2） | T-02~T-10 | 全覆盖 | 错误重试/同源一致/卸载即时移除 |
| DFX 安全（§4.3） | T-01, T-04, T-05 | 全覆盖 | R6 + 敏感字段脱敏 |
| DFX 可维护（§4.4） | T-01, T-02~T-17 | 全覆盖 | 复用 Model 层、菜单可追溯 |
| DFX 兼容（§4.5） | T-15 | 全覆盖 | 只消费 v1、不迁移存量字段回填 |

---

## 验收检查清单（终验）

- [ ] **A1-A10 全部实现并通过 spec 验收条件**（逐条）
- [ ] **M5 已修**：执行技能后 `use_count` 累加，A5 界面非空
- [ ] **R9 双语建模落地**：`agent_skills` 有双语存储（复用 JSON 列或新增 `i18n` 列，附铁律 9 论证）、回退逻辑生效
- [ ] **R2/R6 全过**：6+ 新界面均登记 `permissions`+`role_has_permission`+菜单+`loaddbinfo`；低权限角色无入口且直接调 API 返回 403
- [ ] **A9 智能体详情可达**：从列表带 id 进入；无 id 回落列表；9 条 agents 全可达；四段数据真实
- [ ] **A10 界面 i18n 干净**：无裸 key、无硬编码中文；操作真实生效
- [ ] **A7/A8 PC 数据层**：`skills:*`/智能体 IPC 返回真实数据（非 `Not implemented`/空数组）
- [ ] **跨边界冒烟（L2，≥3 主干 + 1 异常）**：
  - [ ] 主干1：Web 安装技能 → 同一账号 PC 原生技能页见到该技能（跨 S1→S6）
  - [ ] 主干2：技能执行 → A5 用量 +1（M5 生效）
  - [ ] 主干3：插件 inspect/activate 状态刷新正确（C-006）
  - [ ] 异常：低权限用户打开仅超管可见的安装页 → 403 且无入口
- [ ] **复用项未被重新实现**：复用 `src/store/models/uctoo/*`，未在 `src/api/*` 另起封装；未新建表
- [ ] **DDL/权限登记齐备**：A10 条件 DDL 落 `sql/incremental/`；新界面权限登记已执行 `loaddbinfo`
- [ ] **编译/类型检查/lint 通过**（人工确认：cangjie 改动由人工 `cjpm build` 回传）
- [ ] **三份文档与最终实现一致**（spec/design/tasks 无漂移）

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果 |
|---|---|---|---|---|
| 2026-10-30 | v1.0 | 用户要求生成 design+tasks（S1） | design.md / tasks.md（新建） | 待 gate-task 确认 |

> 配套：本目录不创建 `contract.md` / `test-report.md`（用户仅要求 design + tasks）。跨子系统契约见主工程 `SPECS_INDEX.md` §3。
