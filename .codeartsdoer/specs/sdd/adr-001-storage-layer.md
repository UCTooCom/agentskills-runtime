# ADR-001：SDD 两张新表的存储层形态

- **状态**：**v2（取代 v1 决策）** —— 2026-09-27 修订
- **日期**：2026-09-27（v1） / 2026-09-27（v2 修订）
- **决策者**：项目维护者（人工，最终拍板） + AI 分析建议
- **影响范围**：`sub_agent_invocations`、`sdd_projects` 两张新表及其宿主侧 / 前端访问代码
- **关联文档**：`spec.md` §6.7（数据约束）、`design.md` §2.3.3-ter / §2.7.3 / §2.10、`research.md` §九 / §十一、`tasks.md` T-13 / T-14 / T-19 / T-22 / T-23 / **T-25**
- **执行记录**：`apps/agentskills-runtime/logs/crud.md`（人工实际执行的命令与产物清单，是 v2 的事实依据）
- **落盘位置说明**：本文件是**开发期决策记录**，与本工程的 `spec.md` / `design.md` / `tasks.md` 同级，放 `.codeartsdoer/specs/sdd/`。
  它**不是** SDD 运行时产出的阶段文档——运行时产出的 research/spec/design/tasks/test-report 一律落 runtime 自有 `specs/{feature_name}/`（见 `spec.md` §1.3、§5.1.1）。

---

## 0. 修订说明（v1 → v2）

### 0.1 v1 决策与它的实际结局

v1 的结论是「**宿主侧手写仓储，不生成标准 CRUD**」。该结论在 2026-09-27 上午被人工操作**部分推翻**：维护者实际执行了 `crudgen` + `crudweb`，为两张新表生成了完整的宿主五层模块与前端页面，宿主 `cjpm build` 全部通过。

**决策翻转点**在于「怎么保证这两张表不被人工增删改」这个问题上：

| | v1 主张 | v2 实际做法 |
|---|---|---|
| 手段 | 不生成写接口（结构性禁止） | 先生成，再关闭前端写入口（约定性禁止） |
| 前提假设 | 手写成本可接受 | 手写成本高于「生成后收敛」，且与项目其它表范式不一致 |

v2 采纳人工方案。理由见 §3.3。

### 0.2 v1 中被**完全证实**的部分（一字不改地保留）

v1 §4.2 判定「`plugingen` 表驱动会覆盖 `plugin.yaml`」——2026-09-27 07:51 的人工执行把它变成了事故：

```
plugingen --name sdd --mode process
  → 已生成: ./skills/sdd/SKILL.md        ← 覆盖了已完成的 T-03 定制资产
  → 已生成: ./skills/sdd/plugin.yaml     ← 覆盖了已完成的 T-02 定制资产
```

事后核验：`plugin.yaml` 退回成 `tableWhitelist: []` + `routes=add/edit/del/list`，`SKILL.md` 退回成 `{{tableName}}` 占位模板；且 `skills/sdd/` 未被 git 跟踪（`git status` 显示 `??`），**无法用版本库找回**。所幸 `COMPOSITION.yaml` / `DATA_CONTRACT.yaml` / `agents/` / `prompts/` / `templates/` 未被波及（plugingen 只写它自己那 6 个文件）。两个丢失文件已按原始设计重写恢复（见 §8 债 5）。

**这条禁令从"理论风险"升级为"已付出代价的事实"，保留并强化**（§9）。

### 0.3 本轮顺带修掉的问题

- 恢复了 `plugin.yaml` / `SKILL.md`；
- 修正了 `skills/sdd/src/main.cj` 一个会**破坏 L3 stdio RPC 协议**的真 bug（骨架用 `console.log` 打 stdout，同轨 `long-running-task` 用 `eprintln`）；
- 删除了 CRUD 残留 `src/handlers.cj`，并按 T-01 收尾；
- 填平了 v1 §8 债 1（`COMPOSITION.yaml` 未声明两张新表、`sdd_projects` 无写入方）；
- 填平了 v1 §8 债 2（`plugin.yaml` 路由与 `design.md` §2.2.1 不一致）。

---

## 1. 背景

`sql/incremental/sdd_subagent_20260927.sql` 为本工程新增两张表：

| 表 | 性质 | 建表位置 |
|---|---|---|
| `sub_agent_invocations` | 子 agent 派单留痕（含 REQ-SDD-012 的 4 个契约校验列 + 3 个成本列） | 脚本第 47-73 行 |
| `sdd_projects` | SDD 工程实例可查询投影（`feature_name` 唯一，`current_stage` / `round`） | 脚本第 111-126 行 |

**实际执行记录**（`logs/crud.md`，全部由人工在 cmd 执行）：

| 序 | 命令 | 结果 |
|---|---|---|
| 1 | `plugingen --name sdd --mode process` | 生成 L3 骨架；**覆盖了 SKILL.md / plugin.yaml**（见 §0.2） |
| 2 | `loaddbinfo --db uctoo` | 刷新 `db_info`，2920 条列信息 —— 顺带消掉 v1 §4.1 记的"新表未登记 db_info"前置坑 |
| 3 | `crudgen --db uctoo --table sdd_projects` | 五层模块 + AutoRouteConfig 注册 + 权限节点 + i18n |
| 4 | `crudgen --db uctoo --table sub_agent_invocations` | 同上 |
| 5-6 | `crudweb --db uctoo --table {两张表}` | 前端 `index.vue` / `add-*.vue` / `*-table.vue` / `edit-form.vue` / store model |
| 7 | `cjpm build` | **success** |

核验结果：两张表的 PO 已完整包含 REQ-SDD-012 的七个新列（`contract_type` / `verify_passed` / `verify_errors` / `attempt` / `prompt_tokens` / `completion_tokens` / `total_tokens`），说明第 2 步 `loaddbinfo` 跑在建表之后，元数据是最新的。

## 2. 决策（v2）

**两张表采用「crudgen 确定性生成宿主五层模块 + 写入口收敛」的混合形态：**

1. **保留生成产物**：Model / DAO / Service / Controller / Route 五层照 crudgen 产出，作为项目统一范式的一部分，不再手写仓储；
2. **写入方收敛为一个**：业务写入只能经 `SddProjectsService` / `SubAgentInvocationsService`，且只允许 **语义化动作**（见 §6），禁止业务代码调用通用 `update` / `delete`；
3. **人工操作通道按层关闭**（T-25，分三步，按严格度递增）：
   - 前端：`add-*.vue` / `edit-form.vue` 的写入口不挂载，列表页降级为只读；
   - 菜单：`permissions` 中已生成的两个节点不授予任何非超管角色，**否则菜单项仍在，前端改了也白改**；
   - 后端：`Route.cj` 中 `add` / `edit` / `del` / `empty-recycle-bin` 四条路由注册注释掉（真正的关闭点在后端，不只是前端）；
4. **禁止 `sub_agent_invocations` 的物理删除**：只能用软删（`deleted_at`），`force=true` 的硬删路径对本表必须关闭。

> **一句话**：表的主权仍在宿主运行时，"防人工误改"由**生成后收敛**保证，而不是由**不生成**保证。

## 3. 判据

### 3.1 三问判据（v1 提出，v2 继续有效）

| 判据 | `sub_agent_invocations` | `sdd_projects` |
|---|---|---|
| **① 写入方是谁** | 宿主进程：`src/tool/sub_agent_tool.cj:141-190`（`design.md:540`）、`src/sdd_subagent_dispatch.cj`（`tasks.md:179`） | 宿主进程：随 `agent_tasks` 状态机推进写入 |
| **② 语义是什么** | 追加型审计账本 | 投影表，权威态在 `agent_tasks` |
| **③ 读写发生在哪个进程** | 宿主进程 | 宿主进程 |

**三问的答案没变**，所以 v1 的核心主张之一——**绝不能把主权交给插件 CRUD**——继续成立（见 §4.2、§4.3）。

### 3.2 v1 的推断哪里不准

v1 认为 crudgen 的通用 CRUD 面（含 edit/del/回收站）与本表语义冲突，因此建议不生成。这个推断对，但**解法选错了优先级**：crudgen 是项目里所有表的统一生成范式，绕开它意味着这两张表要在既有的 Model/DAO 体系之外另起一套手写仓储——后续任何人看代码都要先理解"为什么这两张表特殊"。而"防人工误改"完全可以在生成之后用三层关闭实现（§2.3）。

### 3.3 v2 采纳人工方案的理由

1. 生成产物**已通过编译**，与 `long-running-task`、其它业务表同构，维护心智成本低；
2. `loaddbinfo` 已刷新，PO 字段与 DDL 严格一致，手写反而容易漂移；
3. Service 层已经提供了 `createWithPermission` / `getFilteredList` 等能力，语义化写入口可以**追加在它之上**，不必另起仓储。

## 4. 备选项与淘汰理由

### 4.1 选项 A：`crudgen` 生成宿主模块 —— **v2 采纳（带 §2.3 的收敛条件）**

v1 列出的产物面仍然全部属实，只是从"淘汰理由"变成了"必须在 T-25 关掉的东西"：

| 生成产物 | 位置 | 处置 |
|---|---|---|
| `/add` `/edit` `/del` 路由注册 | `src/app/routes/uctoo/{sub_agent_invocations,sdd_projects}/*Route.cj`（如 `SubAgentInvocationsRoute.cj:27/28/29/41`） | T-25 注释掉（后端真关闭点） |
| `add` / `edit` / `delete` / `emptyRecycleBin` 控制器方法 | `src/app/controllers/uctoo/.../*Controller.cj` | 保留但不被路由触达 |
| 路由注册入口 | `src/app/registry/AutoRouteConfig.cj:612-636` | 注释具体路由行，而不是删注册块（避免影响 Route 类构造） |
| `database.uctoo.{table}` 权限节点 + i18n | `permissions` / `config_i18n` 表 | **不授予非超管角色**（菜单才真的消失） |
| 前端页面 | `apps/web-admin/web/src/views/database/uctoo/{sdd_projects,sub_agent_invocations}/`（`index.vue` + `components/add-*.vue` + `components/edit-form.vue`） | 写入口不挂载，列表降级只读 |
| store model | `apps/web-admin/web/src/store/models/uctoo/{sdd_projects,sub_agent_invocations}.ts` | 保留（只读列表仍要用） |

**注意一处 crudgen 没做的事**：日志第 58 行「`.env` 文件中未找到行级权限配置区域标记，跳过配置」——行级权限**没有生成**。若 `sdd_projects` 需要按 owner 隔离，必须手工把表名加进 `PermissionUtils.hasOwnerUserColumn`（`src/app/utils/PermissionUtils.cj:57`），否则会出现"产出但查不到"的静默失败。**当前未启用，属待决策项**（§8 债 6）。

### 4.2 选项 B：`plugingen` 表驱动生成插件 CRUD —— 淘汰（**已被事故证实**）

`--mode process` 骨架生成会覆盖 `${pluginDir}/plugin.yaml` 与 `SKILL.md`（本次实测，`CrudPluginGenerator.cj:106` 无存在性保护；本次虽未带 `--table`，走的空白骨架分支，但同样覆写了这两个文件）。此外：

- `--table` 只支持单表（`CrudPluginGenerator.cj:92`），两表要跑两次；
- 与 `research.md:286-292` 既定的"打包外壳 + 深度定制、删除 CRUD handler"策略冲突；
- process 轨只能经 `host.db` 代理写（`cordis_host_services.cj:186/350`），把账本主权切进插件进程会造成写方分裂。

### 4.3 选项 C：另起数据型插件（如 `sdd-ledger`）承载 CRUD —— 淘汰

账本类数据**只有一个写入方**才谈得上可审计；宿主 `SubAgentTool` 已确定是唯一写方，再开一路等于自毁可回放性。

### 4.4 选项 D：宿主侧手写仓储 —— **降级为备选**

v1 的首选，v2 因 §3.3 三条理由让位于选项 A。保留为"若将来 T-25 关闭不彻底、出现误改事故"时的回退方案。

## 5. 依据清单（file:line）

| # | 结论 | 依据 |
|---|---|---|
| 1 | 写入方在宿主进程 | `design.md:540`（`src/tool/sub_agent_tool.cj:141-190`）、`tasks.md:179` |
| 2 | 插件经 `host.db` 代理，按表白名单拦截 | `src/plugin/cordis_host_services.cj:186`、`:350`；解析 `src/plugin/plugin_config.cj:192-193` |
| 3 | `crudgen` 产出面（add/edit/del + 权限节点 + i18n） | `logs/crud.md:48-61`、`:75-88`；模板 `templates/Route.cj.tpl:27-36`、`Controller.cj.tpl:29/71/191/438` |
| 4 | 两张表已在 AutoRouteConfig 注册 | `src/app/registry/AutoRouteConfig.cj:170-173`、`:250-251`、`:612-636` |
| 5 | PO 已含 REQ-SDD-012 七个新列 | `src/app/models/uctoo/SubAgentInvocationsPO.cj:61-79` |
| 6 | `plugingen` 会覆盖已存在的 `plugin.yaml` / `SKILL.md` | `src/plugin/tools/plugingen/CrudPluginGenerator.cj:106`；**实证** `logs/crud.md:5-7` |
| 7 | 骨架 `main.cj` 用 `console.log` 打 stdout（L3 RPC 污染） | 修正前 `skills/sdd/src/main.cj:13`；正确写法依据 `skills/long-running-task/src/main.cj:14` |
| 8 | owner 隔离白名单现状 | `src/app/utils/PermissionUtils.cj:57` |

## 6. 落地口径（v2）

### 6.1 `sub_agent_invocations`

在已生成的 `SubAgentInvocationsService`（`src/app/services/uctoo/SubAgentInvocationsService.cj`）**之上**追加语义方法，**不改动 crudgen 生成的现有方法**：

| 新增语义方法 | 时机 | 落到哪些字段 |
|---|---|---|
| `beginInvocation(...)` | 派单前（八步时序第 ③ 步） | `parent_task_id` / `agent_id` / `skill_name` / `stage` / `mode` / `input_json` / `status='running'` / `attempt` |
| `finishInvocation(...)` | 契约校验通过后（第 ⑦ 步） | `output_json` / `status` / `duration_ms` / `contract_type` / `verify_passed` / `verify_errors` / `prompt_tokens` / `completion_tokens` / `total_tokens` |
| `failInvocation(...)` | 重派仍失败 → 转人工闸口 | `status` / `error_message`（token 取不到时追加 `token_missing`，成本列记 0 **不估算**） |
| `retryInvocation(...)` | 契约校验失败自动重派 | `attempt` 递增（上限 2），**同 `task_id` 新上下文，不新插行** |

约束：**下游实现不得直接调用** `Service.update` / `delete` / `emptyRecycleBin`；下线只走软删。

### 6.2 `sdd_projects`

在 `SddProjectsService` 之上追加：`upsertProject(feature_name, task_id, ...)`（受 `uq_sdd_projects_feature` 约束）与 `advanceStage(feature_name, stage, round, status)`（`revise` 递增 `round`，`current_stage` **不倒退**）。

### 6.3 成本账本读取

`v_sub_agent_stage_cost` 是**视图**，不在插件 `tableWhitelist` 内，宿主 agent 不会被拦截（宿主直连 ORM），可以直接查。前端若要做"派生 ROI"看板，建议**复用 crudweb 已生成的列表页改造**（现成的 `index.vue` + store model），而不是新建页面。

## 7. 后果

**正面**
- 与项目其它表同构，`long-running-task` 之后不用再多背一套例外；
- PO 与 DDL 严格一致（`loaddbinfo` 保证），不会手写漂移；
- 编译已通过，链路不再有"能不能编过"的不确定性。

**负面**
- **只关前端入口是不够的**：四条写路由仍在 `AutoRouteConfig` 里注册并可被直接调用；`permissions` 节点也已生成，菜单项不会因为前端改了就消失。这是 v2 相比 v1 付出的真实代价，必须由 T-25 三步走**全部做完**才算落地（§2.3）；
- 通用 Service 方法（`update` / `delete` / `emptyRecycleBin`）在编译期内始终可见，防不住"后来者在业务代码里顺手调一下"，只能靠 §6 的约定 + 代码评审。

**中性**
- 行级权限未配置（crudgen 跳过），`sdd_projects` 的 owner 隔离尚未启用，需明确决策（§8 债 6）。

## 8. 悬空债

| # | 问题 | 状态 | 处置 |
|---|---|---|---|
| 1 | `COMPOSITION.yaml` 未声明两张新表，`sdd_projects` 无写入方 | **已修**（本轮） | 六步 `uses_tables` 已补 `sdd_projects`；五个文档步补 `sub_agent_invocations`（code 步不派生故不写）；每步验收加 stage 推进条款 |
| 2 | `plugin.yaml` 路由与 `design.md` §2.2.1 不一致 | **已修**（本轮） | 恢复时按 design 校正：补 `GET /projects/:feature_name`，去掉多余的 `:id` / `:limit/:page` |
| 3 | 视图不在插件白名单 | 保持 | 宿主侧直连 ORM 可查，不需进白名单 |
| 4 | owner 白名单未同步 | **待决策** | 若要 owner 隔离，把 `sdd_projects` 加进 `PermissionUtils.hasOwnerUserColumn` 并重编宿主 |
| 5 | `plugingen` 覆盖了 `SKILL.md` / `plugin.yaml` | **已修**（本轮） | 按原始设计重写恢复；已写入 §9 防回退条款 1 |
| 6 | 前端 + 后端写入口未关闭（新的） | 待办 | **T-25**，按 §2.3 三步走，缺一步都不算"禁止人工操作" |
| 7 | 骨架 `main.cj` 的 stdout 污染 | **已修**（本轮） | 改 `eprintln` + 去掉 `SddHandlers` 注册 + 删除 `handlers.cj` |

## 9. 防回退条款

1. **禁止**对 `skills/sdd` 再执行任何 `plugingen` 命令（本次已因此丢失 `SKILL.md` / `plugin.yaml`）。确需重出骨架时：**先把定制文件拷到目录外备份，生成后再 diff 回填**。
2. **先跑生成器、后写定制内容**。本工程的执行顺序反了（先写清单后跑生成器），才有了这次事故。新 SkIll 一律按「生成 → 再覆盖定制」的顺序。
3. **业务写入只走 §6 的语义方法**，禁止在业务代码里调用这两张表的通用 `update` / `delete` / `emptyRecycleBin`。
4. `sub_agent_invocations` **禁止硬删**（`force=true` 路径对本表关闭）。
5. 契约校验与成本字段（REQ-SDD-012）**不得落地为"以后再补"**：PO 已含七列，缺写入就是 bug，不是 TODO。
6. L3 进程**诊断日志只走 stderr**；`main.cj` 的 `console.log` 是协议污染，不允许再出现。
7. 依据均为 file:line 级事实；相关文件重构后须回来复核行号。

## 10. 反选判据：什么时候用哪个生成器

| 场景 | 该用的工具 |
|---|---|
| 表是后台可人工增删改的业务实体（`entity`、`crontab`） | `crudgen` + `crudweb`（全量） |
| 表是运行态账本/投影，**不希望人工改** | `crudgen` 生成 + **写入口收敛三层关闭**（本例，ADR-001 v2） |
| 表主权属于某个**数据型**插件进程（`codelabs` 那类） | `plugingen` 表驱动 |
| 只需要打包外壳的**编排型**插件 | `plugingen --mode process` + **先备份再生成** |

---

## 变更记录

| 日期 | 版本 | 说明 |
|---|---|---|
| 2026-09-27 | v1 | 初稿：三问判据 + 四选项对比 + 手写仓储落地口径 + 4 条悬空债 |
| 2026-09-27 | v2 | 决策改为「`crudgen` 生成 + 写入口收敛」；记录 `plugingen` 覆盖事故并强化禁令；新增 T-25 三层关闭清单；修掉债 1/2/5/7，新增债 6；全部事实依据取自 `logs/crud.md` 的人工执行记录 |
