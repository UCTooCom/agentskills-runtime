# 技术设计文档（S1 技能与插件控制台）

## 文档信息
- **项目名称**: ConsoleClosure（三端能力补全）
- **子系统**: S1 技能与插件控制台
- **feature_name**: `ConsoleClosure--skill-console`
- **版本**: 1.0
- **创建日期**: 2026-10-30
- **作者**: SDD 设计步（sdd-design-writer 派生）
- **状态**: 草稿（待 gate-design 闸口确认）
- **关联需求**: `specs/ConsoleClosure/ConsoleClosure--skill-console/spec.md`
- **关联主工程账本**: `specs/ConsoleClosure/SPECS_INDEX.md`（契约 C-001~C-006、风险 R2/R4/R6/R9/R10、缺口 W1/W2/M5）

---

## 1. 设计概述

### 1.1 设计目标
把 AgentSkills-runtime 服务端**已存在但无界面承接**的技能与插件能力，按交付面补齐到 Web 管理端（web-admin）与 PC 端数据层（pc-client），使三端能力对齐。本子系统是主工程 6 个子系统里**业务优先级最高、无上游依赖**的一个，承载需求 A1-A10（含用户走查缺口 W1/A9 智能体详情页、W2/A10 技能双语建模与界面）。

设计目标可量化为：
- Web 端补齐 6 类业务界面（技能目录/详情内容/合规校验/用量统计/插件运行时/智能体详情），**全部经 C-024 动态菜单可见、经 R6 权限可达**。
- PC 端把 `skills:*` / 智能体列表的硬编码空数组与 `Not implemented` 替换为 runtime 真实数据（数据层打通，页面壳交 S6 按混合模式集成）。
- 修掉服务端真实缺陷 M5（用量埋点），否则 A5 界面永远空。
- 补上 `agent_skills` 双语建模缺口（R9），先定口径再排期，不按"内容缺口"瞎填。

### 1.2 设计原则
1. **复用优先（铁律 9）**：优先复用既有表/列与既有 JSON 字段（`config`/`extra_metadata` 等）收纳扩展信息；新增表/列必须在本文件 §4 写明"复用不成立"理由。本子系统**不新建表**，双语只在 `agent_skills` 上论证单列 JSON（见 §4.3）。
2. **二次开发底座优先（铁律 14）**：迭代 runtime/uctoo 时，规范以 `uctoo-dev-manual` + `docs/uctoo-v4/*.md` 为准；脚手架优先跑确定性工具（`loaddbinfo` → `crudgen`/`plugingen` → `crudweb`），生成物当骨架做最小适配；生成后必补 `sql/incremental/` DDL 与 `permissions`/`role_has_permission` 登记。
3. **不改服务端路由（spec §1.4）**：本子系统**不新增/修改 runtime 仓颉路由**；所有能力经既有 C-001~C-006 的 v1 契约消费。允许的两类跨界服务端改动都**不产生新路由**：① M5 在既有执行路径内补一个既有 Service 调用；② A10 在既有表加一列 + 既有查询方法加回退逻辑。
4. **菜单/权限双层登记硬约束（R2/R6）**：每新增一个 Web 业务界面必须同时写入 `permissions` + `role_has_permission` + 菜单树（C-024）并执行 `loaddbinfo`，否则表现为"功能做了但找不到入口"或 API 层 403。
5. **PC 端只补数据层（铁律 15 / 混合模式）**：桌面端业务页以 iframe 集成为主（归 S6），本子系统在 PC 端只改 `electron/main/index.ts` 的 IPC 实现，页面壳与导航不碰。
6. **跨界不手写（铁律 15）**：不直接连其他子系统私有表/私有目录；对上游 runtime 一律走契约接口，对下游 S6 只交付数据层产物。

### 1.3 技术选型
| 组件 | 技术选型 | 说明 |
|------|---------|------|
| Web 前端 | Vue 3 + TypeScript（web-admin 既有栈） | 业务界面落 `src/views/ai/skill_console/**`，经 `src/router/guard/menu.ts:79` 动态注入 |
| 状态/接口层 | `src/store/models/uctoo/*`（97 个 Model） | **强制复用**，禁止在遗留 `src/api/*` thin 层另起封装 |
| PC 前端 | Vue 3（pc-client 渲染进程） | 智能体/技能页复用既有 `AgentsView.vue`/`SkillsView.vue` 壳，只换数据源 |
| PC 主进程 | Electron `electron/main/index.ts` | 集中 64 个 IPC 通道，本子系统改 `skills:*` / 智能体取数实现 |
| 服务端 | 仓颉（AgentSkills-runtime） | 仅做 M5 埋点 + A10 双语读取 Service 两类最小改动；**AI 不运行 `cjpm build`** |
| 数据库 | PostgreSQL（uctoo 库） | 仅 A10 可能新增单列 + 存量回填，走 `sql/incremental/` |
| 国际化 | 既有 `i18` 词条表 + 前端 locale 兜底 | A10 界面文案全走词条；词条录入界面归 S5(E9)，本子系统只消费/补 key |

---

## 2. 系统架构

### 2.1 架构图
```
                         [ 系统管理员 / 普通使用者 / 桌面端用户 ]
                                        │
            ┌─────────────── Web 端(web-admin) ───────────────┐  ┌──── PC 端(pc-client, Electron) ────┐
            │ views/ai/skill_console/**                       │  │ SkillsView.vue / AgentsView.vue     │
            │ views/ai/agent_detail/**  (A9 补 id 入参)        │  │ electron/main/index.ts IPC 数据层   │
            │ views/ai/agent_skills.vue   (A10 i18n 修复)      │  │ (skills:list/getDetail/install,      │
            └───────────────────────┬──────────────────────────┘  │  agents 取数, 替换假实现)            │
                                     │  HTTP + Bearer token         └──────────────┬─────────────────────┘
                                     │                                            │ IPC(地址/token 经 C-023 桥, 归 S6)
            ┌────────────────────────▼──────────────────────────┐  ┌──────────────▼─────────────────────┐
            │ store/models/uctoo/*（97 Model，强制复用）          │  │ electron/modules/ipc.ts 统一封装     │
            │ （不另起 src/api/* thin 层）                        │  │ → HTTP 调用 runtime                 │
            └────────────────────────┬──────────────────────────┘  └──────────────┬─────────────────────┘
                                     │  C-001~C-006（v1 契约，单向消费）              │
                                     ▼                                            ▼
                          ┌──────────────────────────────────────────────────────────────┐
                          │  runtime (AgentSkills-runtime)                                │
                          │  SkillRoutes / ToolRoutes / SkillUsageStats / Validation      │
                          │  读写的库表:                                                  │
                          │   agent_skills / skill_usage_stats / skill_compositions /     │
                          │   agents / permissions / role_has_permission                  │
                          └──────────────────────────────────────────────────────────────┘
                                     ▲
                                     │ C-024 动态菜单树（菜单入口可见性）
                              web-admin 路由守卫 menu.ts:79
```

### 2.2 模块划分
| 模块 | 边界 | 标签 | 负责方 |
|---|---|---|---|
| **M1 Web 技能控制台前端** | 目录/检索/安装卸载/详情内容/合规校验/用量统计/插件运行时 6 类界面 | web | 本子系统（web-coder） |
| **M2 Web 智能体详情补全** | `agent_detail/index.vue` 增加 `id` 入参健壮性 + 四段数据真实渲染；上游列表入口 | web | 本子系统（web-coder） |
| **M3 Web 技能页双语** | `agent_skills.vue` 的 i18n 修复 + 操作真正生效 | web | 本子系统（web-coder） |
| **M4 PC 端数据层** | `electron/main/index.ts` 的 `skills:*` / 智能体 IPC 替换为真实取数 | app | 本子系统（app-coder） |
| **M5 Runtime 最小修补** | M5 用量埋点 + A10 双语读取 Service + 必要 DDL | cangjie/web | 本子系统（cangjie-coder，人工编译） |
| **M6 权限与菜单登记** | 全部新界面的 `permissions`/`role_has_permission`/菜单树/`loaddbinfo` | web+db | 本子系统（web-coder + DML） |

### 2.3 组件交互
- Web 端所有请求经 `store/models/uctoo/*` Model 发出，统一带 `Authorization: Bearer <token>`（对齐 `src/store/models/uctoo/agent_skills.ts:80`）。
- 菜单入口由 C-024 后端菜单树注入，组件路径须与 `views/${menu.component}.vue` 可解析（R2）。
- PC 端经 IPC 调用 `electron/modules/ipc.ts` → 内部 HTTP 请求 runtime；地址与 token 由 S6 的 C-023 桥提供（L1 测试用手动配置代替）。
- 本子系统与 S6 单向依赖（S1 → S6）：S1 交付 PC 数据层产物，S6 负责把页面 iframe 集成进桌面端壳。

---

## 3. 详细设计

### 3.1 M1 Web 技能控制台前端
#### 3.1.1 关键类/组件
| 组件 | 落点（建议） | 职责 |
|---|---|---|
| 技能目录页 | `src/views/ai/skill_console/SkillList.vue` | C-001 列表 + 关键词检索(C-001 search) + 分页 |
| 技能详情页 | `.../SkillDetail.vue` | C-001 `:id` 详情 + C-003 `:name/content` 内容只读 |
| 合规校验页 | `.../SkillValidation.vue` | C-004 `validate`/`validate-security`/`validate-all` |
| 用量统计页 | `.../SkillUsage.vue` | C-005 `top-used` + 成功率计算 |
| 插件运行时页 | `.../PluginRuntime.vue` | C-006 `plugin_inspect/activate/deactivate/refresh` |

> 落点目录 `skill_console/**` 仅为建议，最终以 `menu.component` 登记值为准（组件路径必须可解析，否则白屏）。

#### 3.1.2 接口设计（前端 Model 封装，非新增 HTTP 路由）
复用既有 Model：`src/store/models/uctoo/agent_skills.ts` 等。新增的"接口"仅指前端对 C-001~C-006 的调用封装，例如：
- `fetchSkills(query)` → `GET /api/v1/uctoo/skills`
- `searchSkills(body)` → `POST /api/v1/uctoo/skills/search`
- `installSkill(body)` → `POST /api/v1/uctoo/skills/add`
- `fetchSkillContent(name)` → `GET /api/v1/uctoo/skills/:name/content`

#### 3.1.3 数据流（以安装为例）
```
用户填来源 → 前端校验(来源/来源形态必填, 重名校验) → POST /skills/add (C-002)
→ runtime 返回 {success, skillId} → Model 层写回列表 → 列表新增卡片
异常: 来源不可达 → 展示服务端原因并保留已填内容; 403 → 隐藏入口并提示联系管理员
```

### 3.2 M2 Web 智能体详情补全（A9 / W1）
- **问题**：`agent_detail/index.vue` 取数逻辑已写，但 `agentId = route.params.id`，不带 id 直接访问即为空串 → 渲染「Agent 未找到」。菜单 `menu.ai.agentDetail` 是独立项，无上游列表带 id 跳入。
- **修复**：
  1. 上游补一个可点击的智能体列表入口（复用 `GET /api/v1/uctoo/agents/:limit/:page`，见 `AutoRouteConfig.cj:1386`），点击行携带 `id` 跳 `/ai/agent_detail/:id`。
  2. `agent_detail/index.vue` 增加 `route.params.id` 为空/不存在时的回落逻辑（跳列表或展示明确引导，禁止裸「Agent 未找到」）。
  3. 四段数据（`agent_tasks`/`agent_contexts`/`agent_memories` + 详情）真实渲染并分页，禁止写死或空数组。
- **产出**：`agents` 现 9 条、可全部可达；`agent_tasks` 615 / `agent_memories` 371 量级真实展示。

### 3.3 M3 Web 技能页双语（A10 / W2 / R9）
- **数据层缺口**：`agent_skills` 52 列无任何多语言列，109 条记录全单语 → 属建模缺口。
- **界面层缺口**：`agent_skills.vue:20-25` 前 3 项走 `t('agentSkills.options.*')` 但运行时取不到译文（显示裸 key `agentSkills.options.all`），后 2 项硬编码中文。
- **修复**：界面文案全量走词条（补 `agentSkills.options.all/services/functions` + 「服务端」「浏览器端」的 i18n key）；存量裸 key 与硬编码中文一并清除；页面各操作按钮真实绑定到 C-001/C-002，禁止静默无响应。

### 3.4 M4 PC 端数据层（A7 / A8）
- 现状：`electron/main/index.ts:583-585` 硬编码 `return {success:true, data:[]}`；`skills:getDetail`/`skills:install` 直接 `return {success:false, error:'Not implemented'}`；`AgentsView.vue:4` 写死 `const agents = ref<any[]>([])`.
- 修复：在 `electron/main/index.ts` 实现 `skills:list`/`skills:getDetail`/`skills:install` 与智能体取数，内部经 `ipc.ts` HTTP 调用 runtime（C-001/C-002/C-001 agents 端点）。
- **边界**：页面壳与导航归 S6（混合模式 iframe）；地址与 token 经 C-023 桥（S6 归口），L1 测试用手动配置代替。
- **A8 归属备注**：spec §5.5.1 标注 A8 同时出现在 S1 与 S6，归属待主工程闸口确认；本子系统仅承担数据层打通，若闸口将 A8 整体划 S6，则本数据层任务移交 S6，S1 仅保留 C-001 契约消费。

### 3.5 M5 Runtime 最小修补（M5 / A10 读取）
- **M5 埋点**：`SkillUsageStatsService.incrementUsage()` 全仓无调用点 → 用量字段永不累加。修复方式：在技能执行既有路径内补一个对 `incrementUsage()` 的调用（如 `POST /skills/execute` 或服务端执行入口），**不产生新路由、不改对外契约**，属 spec §1.4 边界豁免项（M5 由 SPECS_INDEX §9 显式指派 S1）。
- **A10 读取 Service**：在既有 `agent_skills` 查询方法内增加"按 locale 取双语字段、缺语种回退"的逻辑（见 §4.3）。
- **编译约束**：仓颉改动由人工 `cjpm build` 并回传结果，AI 不运行编译。

### 3.6 M6 权限与菜单登记（R2 / R6）
- 每个新界面在 `permissions` 表登记一条路由权限，在 `role_has_permission` 授权（至少一个角色），在菜单树登记 `component`（须与 `views/...vue` 可解析），最后执行 `loaddbinfo` 刷新元数据。
- 顺序：先权限+菜单 → 再 `loaddbinfo`，否则不生效。
- 超管持通配权 `*` 走全量分支，改 `role_has_permission` 对超管无效；普通角色必须显式授权。

---

## 4. 数据设计

### 4.1 数据模型（5 表，全部复用，0 新建表）
| 表 | 来源 | 本子系统用途 | 复用/新增 |
|---|---|---|---|
| `agent_skills` | runtime 既有 | 技能主记录（C-001/C-002/C-003/C-004 读写）；A10 双语字段 | **复用**（仅 A10 可能新增单列 JSON，见 §4.3 论证） |
| `skill_usage_stats` | runtime 既有 | 用量统计（C-005 读）；M5 累加 | 复用（只读写既有字段） |
| `skill_compositions` | runtime 既有 | 技能组合（spec §6.3，**只读展示**，不提供在线编辑） | 复用（只读） |
| `agents` | runtime 既有 | 智能体列表/详情（A8/A9）；`skill_name` 用作卸载引用判定 | 复用（只读） |
| `permissions` / `role_has_permission` | runtime 既有 | R6 双层登记；C-024 菜单树 | 复用（只增登记行，不新建表） |

> 铁律 9 / spec §4.5（R4）：本子系统**不新建表**。`plugin_state`（C-006 标注"新增，需论证"）暂缓建表，插件状态直接取 `plugin_inspect` 返回的运行时态，复用论证待 S5 能力暴露前置完成后再议。

### 4.2 数据关系
```
agents.skill_name  ──(引用, 可为空)──>  agent_skills.name
skill_usage_stats.skill_name  ──(统计主键, 同名一条)──>  agent_skills.name
skill_compositions  ──(只读展示)──  agent_skills（无强 FK）
permissions  ──(1:N)──> role_has_permission  ──(N:1)──> 角色
菜单树(component)  ──(解析)──>  views/${component}.vue
```
- `agents.skill_name` 非空时，该技能必须存在于 `agent_skills`（卸载前引用判定依据，A2 弹窗展示引用数）。
- `skill_usage_stats.skill_name` 同名只保留一条在用记录；`use_count = success_count + failure_count`。

### 4.3 A10 双语建模方案（铁律 9 复用优先论证）
**现状（已核实）**：`public.agent_skills` 52 列均为标量业务字段（`name`/`description`/`source`/`source_type`/...），**无任何多语言列**；全库仅 `permissions.locale` 与多语言相关；109 条记录全单语。

**首选方案（零新增列）**：核查 `agent_skills` 是否已有 JSON 类型容器列（如 `config`/`extra_metadata`/`meta`）。若存在，直接在既有 JSON 列内嵌子树，零 DDL：
```json
{ "name": {"zh":"中文名","en":"English Name"},
  "description": {"zh":"中文描述","en":"English description"} }
```
读取层按 locale 取 `json->field->locale`，缺失回退另一语种，再缺失回退标量 `name`/`description`。

**兜底方案（复用不成立时，新增单列 JSON）**：若核查确认**无**任何 JSON 容器列可承载双语子树，则新增单列 `agent_skills.i18n`（JSONB/JSON）。**复用不成立的论证**：
1. **复用语义不符**：既有 `i18` 词条表是"界面文案 label"机制，key 标识 UI 文案（如 `agentSkills.options.all`），无法表达"某条技能记录自身的双语业务数据（中英文名）"这一 per-record 维度，强行套用会把业务数据塞进 UI 词条，语义错位。
2. **复用列不成立**：52 列全是标量业务字段，无结构化容器列；双语是 `{zh,en}` 键值子树，无法用若干既有标量列组合表达（否则要为每个语种、每个字段各加一列，反而更脏）。
3. **维度绑定记录**：双语随每条技能记录存在，必须跟随该记录存储，不能外挂独立表造成跨表 JOIN 与一致性负担。

**读取/回退规则（Service 层，强制）**：`getSkill(name, locale)` 优先取 `i18n[field][locale]` → 缺失回退另一语种 → 再缺失回退标量 `name`/`description`；**禁止返回空值或 i18n key 原文**。

**存量迁移（109 条）**：用幂等 SQL 将现有标量 `name`/`description` 回填为 `zh` 语种（英文缺失自然回退到中文，界面始终有可读文案）。迁移脚本落 `sql/incremental/`，可复跑。

**界面文案（非数据）**：技能页可见文案（分类/筛选项/操作按钮）走 `i18` 词条表；缺失 key（`agentSkills.options.all` 等 + 「服务端」「浏览器端」）补录中英双语。词条录入界面属 S5(E9)，本子系统只消费并补 key。

---

## 5. API 设计

### 5.1 契约接口清单（本子系统全部消费既有 v1 契约，不新增 runtime 路由）
| 编号 | 方法 | 路径 | 提供方→消费方 | 描述 | 数据契约 |
|---|---|---|---|---|---|
| C-001 | GET | `/api/v1/uctoo/skills` | runtime → S1/S6 | 技能列表（A1/A7） | `agent_skills.*` |
| C-001 | POST | `/api/v1/uctoo/skills/search` | runtime → S1 | 关键词检索（A1） | `agent_skills.*` |
| C-001 | GET | `/api/v1/uctoo/skills/:id` | runtime → S1 | 技能详情（A3） | `agent_skills.*` |
| C-002 | POST | `/api/v1/uctoo/skills/{add,edit,del}` | runtime → S1/S6 | 安装/更新/卸载（A2/A7） | `agent_skills.id/name/status` |
| C-003 | GET | `/api/v1/uctoo/skills/:name/content` | runtime → S1 | 内容读取（A3） | `agent_skills.content` |
| C-004 | POST | `/api/v1/uctoo/skill/validate` | runtime → S1 | 单技能合规校验（A4） | 无落表 |
| C-004 | POST | `/api/v1/uctoo/skill/validate-security` | runtime → S1 | 安全校验（A4） | 无落表 |
| C-004 | GET | `/api/v1/uctoo/skill/validate-all` | runtime → S1 | 全库校验（A4） | 无落表 |
| C-005 | GET | `/api/v1/uctoo/skill_usage_stats/top-used` | runtime → S1 | 用量排行（A5） | `skill_usage_stats.*` |
| C-005 | POST | `/api/v1/uctoo/skill_usage_stats/increment-usage` | runtime → S1 | 执行计数（A5/M5） | `skill_usage_stats.*` |
| C-006 | POST | `/api/v1/tools/plugin_inspect` | runtime → S1 | 插件检视（A6） | 运行时态（暂不落表） |
| C-006 | POST | `/api/v1/tools/plugin_activate` | runtime → S1 | 插件激活（A6） | 运行时态 |
| C-006 | POST | `/api/v1/tools/plugin_deactivate` | runtime → S1 | 插件停用（A6） | 运行时态 |
| C-006 | POST | `/api/v1/tools/plugin_refresh` | runtime → S1 | 增量发现刷新（A6） | 运行时态 |
| — | GET | `/api/v1/uctoo/agents/:limit/:page` | runtime → S1 | 智能体列表（A8/A9 上游） | `agents.*` |
| C-024 | POST | `/api/v1/uctoo/permissions/user/menu` | runtime → 全部 Web | 动态菜单树（R2） | `permissions.*` |

> 合计本子系统涉及的契约接口 14 个（与 SPECS_INDEX"S1: 14 接口"一致：C-001 计 3 子路径 + C-002 计 3 + C-003 计 1 + C-004 计 3 + C-005 计 2 + C-006 计 4 = 16 方法，按契约条目归并为 6 条契约 C-001~C-006，外加 agents 列表端点与 C-024）。

### 5.2 API 详细设计（节选关键）
#### 5.2.1 C-005 用量统计（A5 + M5）
- **请求**: `GET /api/v1/uctoo/skill_usage_stats/top-used?limit=N`
- **响应**: `{ items: [{ skillName, count, successCount, failureCount }] }`
- **成功率**: 前端由 `successCount/(successCount+failureCount)` 计算，禁止本地累加。
- **M5 修复点**: `POST .../increment-usage` 的底层 `SkillUsageStatsService.incrementUsage()` 必须在技能执行路径被调用，否则 `count` 恒为 0，界面永远空（spec §5.4.1 规则 2、SPECS_INDEX §9 M5）。

#### 5.2.2 C-002 安装/卸载（A2）
- **请求**: `POST /api/v1/uctoo/skills/add` `{ source, sourceType, ... }`
- **前置校验**: `source`/`sourceType` 必填成对；重名（`agent_skills.name` 唯一）阻断并提示改更新。
- **卸载引用阻断**: 发 `POST .../skills/del` 前，查 `agents.skill_name` 引用数，>0 时弹窗展示数量并要求显式确认。

#### 5.2.3 安全设计关联（见 §7）
所有 C-001~C-006 请求须带 `Authorization: Bearer <token>`；`source_path`/`install_path`/`env_vars` 仅对系统管理员可见；未授权角色调用安装接口须返回 403 且界面不展示入口。

---

## 6. 接口设计（内部/外部）
- **内部接口**：Web 端 `store/models/uctoo/*` 的 Model 方法封装；PC 端 `electron/modules/ipc.ts` 的 IPC 通道（`skills:list`/`skills:getDetail`/`skills:install`、智能体取数）— 均为本子系统边界内实现。
- **外部接口**：全部为消费 runtime 的 C-001~C-006（单向，无环）；对下游 S6 仅交付 PC 数据层产物，经 C-023 桥传 token，不直连 S6 私有目录。

---

## 7. 安全设计

### 7.1 认证机制
- 全部 HTTP 请求携带 `Authorization: Bearer <token>`（对齐 `agent_skills.ts:80`）。
- PC 端 token 经 C-023 `auth:token` 桥由 S6 提供；L1 测试期可用手动配置代替。

### 7.2 权限控制（R6 双层硬约束）
- **API 层**：未授权角色直接调用技能 API（如安装）→ 返回 403，界面隐藏入口。
- **菜单层**：新界面未登记 `permissions`/`role_has_permission` → 表现为"无入口"而非 403；须按缺权限排查，不可当前端 bug。
- **登记动作**：每条新路由写 `permissions` + `role_has_permission` 授权 + 执行 `loaddbinfo`。

### 7.3 数据安全
- `env_vars` / `source_path` / `install_path` 仅系统管理员可见，展示脱敏。
- `name`/`version`/`validation_status` 列表与详情必须同源一致，禁止前端本地改写。
- 双语字段回退逻辑严禁返回空或 key（§4.3）。
- PC 端后端地址未配置 / token 失效 → 展示连接失败并引导到设置页（不抛未捕获异常）。

---

## 8. 性能设计

### 8.1 性能目标（来自 spec §4.1）
| 场景 | 指标 |
|---|---|
| 技能列表首屏（50 条，局域网） | 发起 C-001 到卡片渲染 ≤ 2s |
| 内容读取 / 单技能校验（≤200KB） | ≤ 3s |
| 用量排行 top-used 请求 / 渲染 | ≤ 2s / ≤ 1s |
| PC 端 `skills:list` IPC 到卡片渲染 | ≤ 2s |

### 8.2 优化策略
- 列表分页（`page`/`limit`）避免全量拉取；两页条目无重复。
- 双语回退在服务端/Model 层一次算好，前端不二次遍历。
- 任一 C-001~C-006 返回非 2xx → 展示错误文案 + 重试入口，禁止静默空列表；runtime 恢复后手动刷新即恢复（MTTR ≤ 1 次刷新）。

---

## 9. 部署设计

### 9.1 部署架构
- **web-admin**：Vue SPA，管理路由由 C-024 后端菜单树动态注入（`menu.ts:79`）；构建产物静态托管，PC 端首页以 iframe 内嵌（混合模式，归 S6）。
- **pc-client**：Electron 应用，`electron/main/index.ts` 集中 IPC；本子系统改动随 PC 端构建发布。
- **runtime**：AgentSkills-runtime（仓颉），M5 与 A10 读取 Service 改动随 runtime 编译发布（人工 `cjpm build`）。

### 9.2 环境配置
- **DB 迁移**：A10 若需新增 `i18n` 列 + 存量回填，DDL 落 `sql/incremental/`，可复跑；执行后 `loaddbinfo`（或 Web 端「数据库管理 → 加载数据库信息」）刷新 `db_info`。
- **权限/菜单登记**：新增界面的 `permissions`/`role_has_permission`/菜单行登记（DML），执行 `loaddbinfo`。
- **前置依赖**：宿主 runtime 已起、DB 迁移已执行、权限已授权、菜单已登记（SPECS_INDEX §5.3）— 任一缺失会导致"看不到入口"或 403，须作为发布 checklist。

---

## 10. 附录

### 10.1 参考文档
- `specs/ConsoleClosure/ConsoleClosure--skill-console/spec.md`（需求权威来源）
- `specs/ConsoleClosure/SPECS_INDEX.md`（契约 C-001~C-006、风险 R2/R4/R6/R9/R10、缺口 W1/W2/M5）
- `specs/ConsoleClosure/research.md`（三端能力盘点与缺口矩阵，M1-M7 实读修正）
- `skills/sdd/SKILL.md`（铁律 9 复用优先 / 铁律 14 二次开发底座优先 / 铁律 15 大工程拆分）
- `skills/sdd/templates/design_template.md`（本模板）
- runtime 源码证据：`SkillRoutes.cj:67-105`、`ToolRoutes.cj:39`、`SkillUsageStatsRoute.cj:53-54`、`AutoRouteConfig.cj:618,1386,1519-1522`、`main.cj:602-606,913`、`src/store/models/uctoo/agent_skills.ts:80`、`src/router/guard/menu.ts:79`、`electron/main/index.ts:583-585`、`AgentsView.vue:4`

### 10.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-10-30 | sdd-design-writer | 初始设计：覆盖 S1(A1-A10) 架构/模块/数据(A10 双语建模铁律9论证)/API(C-001~C-006)/安全/性能/部署；标注 M5 埋点与 PC 数据层边界 |

> 本文件为 S1 子系统 `design` 步产出，等待 `gate-design` 闸口确认（confirm / revise / abandon）。
