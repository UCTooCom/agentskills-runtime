# 编码实现步执行提示词（step: code）

> 执行者：**主 agent 自己** —— 加载编程技能（`cangjie-coder` / `web-coder` / `app-coder`）后按本 SOP 执行，**不派生编码子 agent**
>
> 宿主侧口径：`SddOrchestrationService.HOST_DIRECT_STAGES` 只含 `code`；该步走 `runHostDirectStage`——
> 需 `agent_id`（主 agent 定义 id，必填）+ `language`（选技能），**不写 `sub_agent_invocations`**；
> 编程技能未挂载即显式失败（禁止无依据编码）。

## 这一步做什么

按 `tasks.md` 的语言标签**加载对应编程技能**，由主 agent 按技能 SOP 执行编码。

## 语言分派路由契约

| 语言标签 | 编程技能 | 状态 | 过渡路由 |
|---|---|---|---|
| `cangjie` | `cangjie-coder` | 已存在 | — |
| `web` | `web-coder` | 已建（`skills/web-coder/SKILL.md`） | `fullstack-codegen` / `frontend-dev` |
| `app` | `app-coder` | 已建（`skills/app-coder/SKILL.md`） | `frontend-dev`（近似，原生部分待补） |

三个编程技能均为**纯技能形态**（无 `agents/` 目录、不派生编码子 agent），
与 `cangjie-coder` 同构遵循"确定性优先"四步工作流。

使用过渡路由时**必须**在回传结果中写明，**禁止**静默 fallback。

## 铁律：确定性优先（三个 coder 统一哲学）

1. **先查依据再写代码** —— 目标工程内既有 import 先例 / 同类实现 / 调用范式 + 技术栈官方文档技能确认 API 契约。判据是"文档 + 工程既有先例"。
2. **复制粘贴 + 二次编辑** —— 产出路径是"定位既有正确代码 → 复制 → 最小适配"，等价人类开发行为；**禁止**从零凭空生成、禁止凭跨语言经验臆造 API。
3. **官方文档技能** —— cangjie → `CangjieSkills`；web → 前端技术栈；app → 鸿蒙/安卓/苹果原生。三者必须包含或引用。
4. **依据留痕与降级** —— 查不到必须显式标注缺口并请人工确认，**禁止**静默猜写。

## 二次开发底座优先（uctoo 规范 + 确定性代码生成工具）

判定口径：当本次迭代落点仍在 **agentskills-runtime / uctoo 宿主**内（新增模块、新表 CRUD、
管理界面、新插件），**先对齐既有规范，再决定是否手写**——顺序不能反。

### 第 0 步：先加载开发手册技能

**必须**加载 `uctoo-dev-manual`（`skills/uctoo-dev-manual/SKILL.md`，渐进式六层文档）。
它才是 runtime 二次开发的规范源，SDD 不重复叙述规范内容，只负责把人引到正确位置。

### 规范基线（`docs/uctoo-v4/`，动手前先读对应那篇）

| 你要做的事 | 必读规范 |
|---|---|
| 新增/改动接口 | `uctoo-v4-api-specification.md`（列表键名 = 表名 + s，分页/筛选/排序） |
| 新建表、改字段 | `uctoo-database-design-specification.md`（UUID 主键 / timestamptz / `creator` 行级权限 / `deleted_at` 软删） |
| 写五层 CRUD（PO/DAO/Service/Controller/Route） | `uctoo-v4-module-development.md`、`uctoo-v4-orm-specification.md` |
| 挂中间件、调路由 | `uctoo-v4-architecture.md`、`uctoo-v4-middleware-guide.md` |
| 碰权限与数据可见范围 | `user-permission-system.md`、`row-level-permission-system.md` |
| 用 crudgen 生成过模块后编译炸 | `crud-generator-v2.md`（已知坑：生成 `db_connection` 之类会让 `@DAO` 全报错） |

### 脚手架：优先跑内置确定性代码生成工具，别手撸

工具链入口都是宿主工程内的 cjpm 可运行包，一律 `cjpm run --skip-build --name <包名> --run-args "<参>"`：

```bash
# 1) 先把表结构灌进 db_info（工具链第一步，后面三个都从它读）
cjpm run --skip-build --name magic.app.tools.loaddbinfo   --run-args "--db uctoo"

# 2a) 功能拓展优先做成插件（默认 L3 进程隔离轨 process；需退回内嵌 sync 轨显式加 --mode sync）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db uctoo --table <表> [--mode sync]"

# 2b) 只有需要往宿主 src/app/ 补公共基础设施时才用 crudgen
cjpm run --skip-build --name magic.app.tools.crudgen     --run-args "--db uctoo --table <表>"

# 2c) 要管理界面用 crudweb
cjpm run --skip-build --name magic.app.tools.crudweb     --run-args "--db uctoo --table <表>"

# 下线插件用对称的 uninstall，别手动删 skills/{name} 目录（会留 DB 痕迹）
cjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name <插件名>"
```

选工具的三条判据：

1. **能做成插件就做插件** —— 插件是 runtime 的一等公民（三轨：sync / dylib / process），
   宿主 `src/app/` 是"存量冻结、只减不增"，往里加东西要慎重；
2. **crudgen 只用于宿主侧公共基础设施**，业务表优先 plugingen / crudweb；
3. **生成完再二次编辑** —— 拿生成物当骨架做最小适配，这是"定位既有正确代码 → 复制 → 最小适配"
   的具体落法，不是让模型从零写一遍五层架构。

已知坑：`loaddbinfo` 命令行模式有未修问题（见 `skills/uctoo-dev-manual/tools/loaddbinfo.md` 顶部 TODO，报找不到数据库连接），
遇到就退到 Web 端「数据库管理 → 加载数据库信息」走同一件事；crudgen 生成后编译报一片 `@DAO` 错，先看
`docs/uctoo-v4/crud-generator-v2.md`。

### 生成之后必须补的两件事（漏了就是半成品）

- **新表/新列走增量 SQL**：放 `sql/incremental/`，单行 `SELECT ... WHERE NOT EXISTS` 写法；
  既有表加列受 SDD 铁律 9 白名单额度约束，用完即升级人工闸口，不许绕过。
- **新增宿主路由必挂 RBAC**：`permissions` 登记 + `role_has_permission` 授权，
  否则 `RequirePermissionMiddleware` 全局中间件一律 403（不是代码 bug，是权限没登记）。

## 跨子系统边界（大工程拆分态，铁律 15）

只在**本子系统 `feature_name = {主}--{子系统ID}` 的边界内**动手，跨出去一律先回主工程 `SPECS_INDEX.md` 登记：

| 情形 | 怎么办 |
|---|---|
| 改的是契约 §1 里已登记的接口 | 先改契约（`templates/subsystem-contract-template.md`）→ 再改实现；破坏性变更**双侧同轮**，单边先改按 P0 打回 |
| 需要调用上游子系统能力 | 走契约登记的「我依赖的上游」清单，只读其公开接口；**禁止**直连上游私有表/私有目录/临时文件 |
| 需要下游提前给我加能力 | 写进本轮待办并在 SPECS_INDEX §6 登记，不要自己先实现一半再等下游 |
| 顺手改到别的子系统文件 | **不许**。把这条记进回传 `out_of_scope`，交主工程闸口裁决 |
| 契约与实现不一致 | 以契约为准回改实现，禁止"实现就这样了"；偏差在 test-report 里归因到契约条目编号 |

回传必须带 `subsystem_id`；多文件跨界时 `changed_files` 里同时标 `in_scope` / `out_of_scope`。

## 执行步骤

0. **先过二次开发底座（见上一节，不跳）**：落点仍在 runtime / uctoo 宿主内的，先加载
   `uctoo-dev-manual` → 读对应的 `docs/uctoo-v4/*.md` → 能生成骨架的先跑
   `loaddbinfo` / `plugingen` / `crudgen` / `crudweb` → 再在生成物上做最小适配。
   只有"改一段既有逻辑、不新增模块/表/界面"的活儿才直接手写。
1. 读取 `tasks.md`，按语言标签分组。
2. 加载对应编程技能（或过渡路由技能），逐个任务执行编码。
3. 产物经 `code-gen-verifier` 闸门；未通过**禁止**标记完成。
4. 至少一份 `usage=deliverable` 代码产物入 `long_running_task_artifact`（`stage=code`）。
5. 触发 `gate-code` 闸口：confirm → 进测试；revise → 回退重做（**新 task_id，上下文不串味**）；abandon → 终止。

## 硬约束

- **不派生编码子 agent**（语言专用子 agent 架构已作废，见 `research.md` §十二）。
- **不手写脚手架**：新增模块/表 CRUD/管理界面/插件先走 `plugingen` / `crudgen` / `crudweb` + `loaddbinfo` 工具链生成，再二次编辑；违规产物 `code-gen-verifier` 打回。
- **规范源以 `uctoo-dev-manual` 为准**（`skills/uctoo-dev-manual/` + `docs/uctoo-v4/`），SDD 不在本技能里复述规范条款。
- **不编译**：`cjpm build` 与日志回传由人工在独立 cmd 完成。
- **连续质量闸门失败**挂人工闸口，不得无限重试。
- 改动只落在 `target_project_root` 内；**拆分态下只落本子系统边界内**，跨界改动先登记后动手（铁律 15）。

## 回传

`{"changed_files": [...], "verify_passed": true|false, "language": "cangjie|web|app"}`；失败时附失败项清单。
拆分态追加：`{"subsystem_id": "...", "contract_version": "v1|v1+", "out_of_scope": [...]}`。

## 回传

`{"changed_files": [...], "verify_passed": true|false, "language": "cangjie|web|app"}`；失败时附失败项清单。
