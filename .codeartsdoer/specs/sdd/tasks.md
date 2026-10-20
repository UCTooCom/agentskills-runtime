# SDD 规范驱动开发融合插件 - 任务规划（tasks.md）

> 基于 `spec.md`（REQ-SDD-001~012）与 `design.md`（§1 存量复用 + §2 增量方案）生成。
> 实施原则：**复用优先**、**确定性优先**、**数据驱动**、**L3 进程隔离**（`mode: process`）。
> 仓颉代码编写须使用 cangjie-coder 技能；**严禁运行 cjpm build**（编译与回传由人工在独立 cmd 完成）。
> 本插件骨架经 `plugingen --mode process --blank` 确定性生成（见 `research.md` §九），其 CRUD 专属产物（SKILL.md.tpl / handlers.cj / routes=add/edit/del/list）必须删除或覆盖，仅保留打包外壳（cjpm.toml / plugin.yaml / main.cj 入口范式 / README）。

## 文档信息
- 关联需求：`specs/sdd/spec.md`（v4，12 条 REQ-SDD-001~012）
- 关联设计：`specs/sdd/design.md`（v4，§1 已实现/需扩展/需新增 + §1.2.6 子 agent 现状 + §2.7 派生设计 + §2.8 数据库增量 + §2.9 自动探测 + §2.10 契约校验与成本账本）
- 关联研究：`specs/sdd/research.md` §九（plugingen）、§十（子 agent 机制）、§十一（数据库）、§十二（coder 形态与自动探测）
- 关联决策记录：**`specs/sdd/adr-001-storage-layer.md`（v1，已接受）** —— 两张新表（`sdd_projects` / `sub_agent_invocations`）的存储层形态为**宿主侧手写仓储，不生成标准 CRUD**；禁止对 `skills/sdd` 跑 `plugingen --table`，禁止对这两张表跑 `crudgen`。落地口径见 ADR §6，悬空债见 ADR §8。
- 初稿日期：2026-09-26 / 修订：2026-09-27 / 版本 **v4** / 状态：草稿（待人工编译骨架后推进）

## 开发规范（全任务强制遵守）
- **骨架来源**：`skills/sdd/` 由 `plugingen --name sdd --mode process --blank` 生成（人工执行），AI 不运行该工具、不运行 `cjpm build`。
- **语言与工具绑定**：仓颉 → cangjie-coder；前端（HTML/CSS/TS）→ web-coder / 过渡路由 fullstack-codegen / frontend-dev；原生 App（鸿蒙/安卓/iOS）→ app-coder（新建）。
- **复用原则**：优先复用 `design.md §1.1` 已实现度 100% 的底座（L3 宿主、COMPOSITION 引擎、决策框架、复用表、cangjie-coder、code-gen-verifier、模板），不重新实现。
- **命名/注释/错误处理**：遵循 `uctoo-dev-manual` 与 legacy `design-principles.md`。仓颉 `!` 参数、跨包 import（防 cyclic dependency）、L3 进程日志只走 stderr 等红线见 `design.md §2.6` 与项目 memory。
- **建表红线（复用优先，确有必要时可建）**：`tableWhitelist` 为 `agent_tasks` / `agent_contexts` / `long_running_task_artifact` / `agent_approvals` / `agents`(只读) / `sdd_projects` / `sub_agent_invocations` 七张；复用优先，若确需新表/新列须先在 design 写明复用不成立的理由（铁律 9）。任何表结构变更先过"能否收纳进 payload/config JSON"一问（铁律 9 复用优先）。落地有二选一：走 `loaddbinfo` → `crudgen`/`plugingen` → `crudweb` 确定性生成，或手动补但须参照生成逻辑补全所有位置（见 `spec.md §6.7`）。早期"新增表≤2、新增列≤2"硬额度封顶已作废。
- **研究步 condition 红线**：`research` 步的 `condition` 必须为 `${input.enable_research}`，**绝不**挂"文件是否已存在"类条件（避免首轮即跳步）。
- **文档落盘路径红线**：阶段文档落 **runtime 自有 `specs/{feature_name}/`**，**禁止**落到 `.codeartsdoer/specs/`（该目录归属 CodeArts Agent）。
- **子 agent 真派生红线（v2 新增）**：禁止沿用 `SubAgentTool.executeSubAgent` 的桩行为（返回字符串冒充执行）。子 agent 定义缺失时**立即失败并提示**，禁止静默降级为"主 agent 自己写"；过渡模式必须在日志显式标注。
- **存储层形态红线（ADR-001 v2）**：两张新表已由 `crudgen` 生成宿主五层模块（宿主侧**不再手写仓储**），业务写入一律经 `SddProjectsService` / `SubAgentInvocationsService` 的**语义化方法**（`beginInvocation` / `finishInvocation` / `failInvocation` / `retryInvocation`；`upsertProject` / `advanceStage`），**禁止**业务代码直调通用 `update` / `delete` / `emptyRecycleBin`；`sub_agent_invocations` 禁硬删（只软删）。"防人工误改"由 **T-25 三层关闭**落地，**仅关前端入口不算完成**。禁止对 `skills/sdd` 再跑 `plugingen`（2026-09-27 已因此丢失定制 `SKILL.md` / `plugin.yaml` 各一次）。
- **生成器执行顺序红线**：一律「**先跑生成器出骨架 → 再覆盖定制内容**」。若必须先有内容，生成前要把 `SKILL.md` / `plugin.yaml` 拷到目录外备份，生成后 diff 回填（`skills/sdd/` 未被 git 跟踪，`git checkout` 救不回来）。
- **上下文隔离红线（v2 新增）**：六步一律 `SubAgentMode.Isolated` + 显式上下文包；`agent_contexts` 按 `task_id` 隔离，禁止同一子 agent 多次调用共用一份上下文。
- **插件自完备红线**：五个子 agent 声明文件 + 七份模板 + EARS/设计原则**必须**随插件打包进 `skills/sdd/`，不得依赖插件目录之外的路径。

## 任务总览

| 编号 | 任务 | 关联 spec | 关联 design | 负责子 agent / 角色 | 状态 | 预计产出 |
|------|------|-----------|-------------|----------------------|------|----------|
| T-01 | 生成 L3 进程骨架并初始化基线 | REQ-SDD-001 | §2.1 | 人工(plugingen) + AI(编辑) | 已完成 | `skills/sdd/` 基线就位（cjpm.toml/plugin.yaml/main.cj/effects.cj），handlers.cj 已删除；**注：plugingen 覆盖了 SKILL.md/plugin.yaml，已由 AI 按原始设计重写恢复** |
| T-02 | 修订 plugin.yaml（清单契约） | REQ-SDD-001/008/010 | §2.2.1 | AI | 已完成 | 七张 tableWhitelist + routes=gen-*/review/spawn-subagent |
| T-03 | 编写 SDD SKILL.md（覆盖 CRUD tpl） | REQ-SDD-001~010 | §2.2/§2.5/§2.7 | AI(主 agent) | 已完成 | `skills/sdd/SKILL.md`（六步 + `agents:` 声明 + 决策点 + 路由说明） |
| T-04 | 编写 COMPOSITION.yaml 六步编排 | REQ-SDD-002~007 | §2.2.2 | AI | 已完成 | `skills/sdd/COMPOSITION.yaml`（真实 schema + 研究步 condition 红线 + gate-*） |
| T-05 | 编写 DATA_CONTRACT.yaml（SDD 视角） | REQ-SDD-009/010 | §2.3 | AI | 已完成 | `skills/sdd/DATA_CONTRACT.yaml`（含 agents 只读段与两张新表） |
| T-06 | 新建五个子 agent **声明文件** | REQ-SDD-010 | §2.7.1/§2.7.2 | AI(主 agent) | 已完成 | `skills/sdd/agents/*.md`（5 份，frontmatter 含 skill_name/input_types/output_types/capabilities） |
| T-07 | 编写六份执行提示词（含 `code.md`；code 步由主 agent 直执行，不派生子 agent） | REQ-SDD-002~007 | §2.1/§2.7.1 | AI(主 agent) | 已完成 | `skills/sdd/prompts/{research,spec,design,task,code,test}.md` |
| T-08 | 打包 templates/（随插件，自完备） | REQ-SDD-002~007 | §2.1 | AI | 已完成 | `skills/sdd/templates/*`（6 模板 + ears-format + design-principles，实体复制） |
| T-09 | **宿主侧编排引擎**（架构重定位）+ 插件退化为资产包+薄路由 | REQ-SDD-008/010 | §2.4/§2.5/§2.7.3 | cangjie-coder + 宿主侧 | 已完成（编排服务 + 入口 + crontab 异步化 + 产物落盘 + sdd_* 事件 + 五闸口） | 宿主 `SddOrchestrationService`（六步直接调 T-15 `SubAgentDispatchServiceImpl.dispatch` 真派生）+ `SddOrchestrationController/Route`（start/run-stage/status 三语义入口，已注册 `sdd_orchestration` 路由 + RBAC）；插件 `sdd` 仅保留资产(SKILL/COMPOSITION/agents/prompts/templates)；原插件内 `sdd_subagent_dispatch.cj` 移入宿主 |
| T-10 | 编码语言分派：web-coder/app-coder **编程技能**新建或过渡路由 | REQ-SDD-006 | §2.2.3 | AI + cangjie-coder | 已完成（skills/web-coder 与 skills/app-coder 技能骨架；code.md 路由表同步） | `prompts/code.md` 路由契约 + `skills/web-coder` / `skills/app-coder` 技能骨架（**无 `agents/` 目录**；或过渡路由） |
| T-11 | 决策点 gate-* 配置（confirm/revise/abandon） | REQ-SDD-008 | §2.5 | AI | 已完成 | `SKILL.md` decision-points 五闸口 + web_request_approval 契约 |
| T-12 | 进度可观测 sdd_* 事件 + SSE 单行转义加固 | REQ-SDD-001(DFX) | §2.4 | cangjie-coder | 已完成（宿主侧 SddEventBridge 六类 sdd_* 事件 + SSE 单行转义 + 无 session 早退） | 事件中继 + 宿主 SSE 早退/单行转义 |
| **T-13** | **执行数据库增量脚本（2 表 + 2 列）** | REQ-SDD-010 | §2.8 | 人工(psql) | 已完成 | `sdd_subagent_20260927.sql` 已执行；随后 `loaddbinfo` 刷新 `db_info`（2920 列），PO 已含 REQ-SDD-012 七个新列 |
| **T-14** | **扩展同步扫描范围到 `skills/*/agents/`** | REQ-SDD-010 | §2.7.5-1/2 | cangjie-coder | 已完成 | 扫描扩围在基线已存在（`collectMdFiles` 已走 `agents/`）；本轮补 `AgentsPO.skillName`(@ORMField) + `AgentSyncHandler.deriveSkillName` 按路径绑定 `skill_name`（子agent必填/主agent留空），落库即挂载所属技能 |
| **T-15** | **补全 SubAgentTool 真实派生** | REQ-SDD-010 | §2.7.5-3/§2.7.3 | cangjie-coder | 已完成(宿主侧链路；端到端见T-23) | `src/tool/sub_agent_tool.cj` 由桩改为经 DI 真派生：magic.tool 定义接口+槽，magic.app.services.bridge.SubAgentDispatchServiceImpl 查表→造 Agent→AgentAsTool(Isolated)→chat→写 sub_agent_invocations |
| **T-16** | **AgentDefinition 扩展字段 + 解析 `agents:` 键** | REQ-SDD-010 | §2.7.5-4/6 | cangjie-coder | 已完成(字段+loader；agents:键解析并入T-19) | `capabilities/defaultInputTypes/defaultOutputTypes` 三字段**已存在**；新增 `skillName` 字段已落（agent_definition.cj + agent_loader.cj 解析 `skill_name` 键 + agent_runtime_bridge.cj/DataMapper.cj 双向 map）；`agents:` 键解析并入 T-19 真加载入口（skill_parser.cj 当前是桩，真入口为 SkillManagementService） |
| **T-17** | **修订 Agent 声明规范文档（含"技能内 `agents/` 约定"章）** | REQ-SDD-010/011 | §2.7.5-5 | AI | 已完成（agent-declaration-spec 修订 + §9 技能内 agents 目录约定章） | `docs/agents/agent-declaration-spec.md` 修订 |
| **T-18** | **cangjie-coder 去子 agent 化（删 `agents/` + 清 DB）**【v3 变更】 | REQ-SDD-006 | §1.2.7② | AI + 人工 | 已完成（skills/cangjie-coder/agents 已删；职责并入 SKILL.md 四步工作流；清理 SQL 随 T-13 执行） | `skills/cangjie-coder/agents/` 删除；4 条手工数据清理；职责并入 SKILL.md 四步工作流 |
| **T-19** | **技能加载管线挂载 `bundledAgents`（自动探测）**【v3 新增，关键】 | REQ-SDD-011 | §2.9.3 | cangjie-coder | 已完成(代码落地；端到端见T-23) | 新增 `src/skill/infrastructure/loaders/bundled_agent_scanner.cj`（`BundledAgentScanner.scan`，扫描口径对齐 `ChangeDetector.collectMdFiles`）；`SkillManifest` 加 `bundledAgents: Array<String>`(默认空)+`hasBundledAgent()`；两个构造点填充：真解析点 `skill_md_loader.cj`（`SkillManagementService.loadSkillFromPath` 经 `SkillLoadingService` 到此）与 `skill_loading_service.cj` |
| **T-20** | **SubAgentTool 解析顺序：bundledAgents 优先**【v3 新增】 | REQ-SDD-011 | §2.9.4 | cangjie-coder | 已完成(代码落地；端到端见T-23) | `SubAgentDispatchServiceImpl` 新增 `pickBundledFirst()`：同名多条时 ① 归属当前技能(`skill_name`命中) → ② 全局子 agent(`skill_name`为空) → ③ 首条；按 name 分支改用它，pageSize 10→50。**说明**：bundledAgents 作用域在派单侧以 `skill_name` 过滤表达（同步落库已按路径写入 skill_name），未把内存 manifest 跨层传到派发器 |
| **T-21** | **派单结果契约校验器（ContractVerifier）**【v4 新增，建议 A】 | REQ-SDD-012-A | §2.10.2 | cangjie-coder | 已完成（SubAgentContractVerifier + 派单挂点 + 重派 1 次 + 五份声明契约校正） | `src/tool/sub_agent_contract_verifier.cj` + 规则取 `capabilities.output_contract` + 失败自动重派 1 次 |
| **T-22** | **派生成本账本（token/duration 入表 + 聚合视图）**【v4 新增，建议 B】 | REQ-SDD-012-B | §2.10.3/§2.8 | 人工(psql) + cangjie-coder | 已完成（recordCost 语义方法 + 视图与成本列随 T-13 脚本落地；token 取不到记 0+token_missing） | `sub_agent_invocations` 成本字段 + `v_sub_agent_stage_cost` 视图 + 取数口径落地 |
| **T-23** | **联调验证（人工编译 + 宿主加载 + 走通六步）** | 全部 | §2.6/§2.7/§2.9/§2.10 | 人工 + AI | 待人工执行（AI 侧验证清单已备，见 §T-23） | 编译通过 + 六步跑通 + 子 agent 真派生 + 自动探测生效 + 契约校验生效 + 落库验证 |
| **T-25** | **关闭两张新表的人工写入口（前端+菜单+后端路由）**【ADR-001 v2 新增】 | REQ-SDD-010 | ADR-001 v2 §2.3 | AI + web-coder + cangjie-coder | 已完成（后端写路由注释 + 前端写入口摘除 + 菜单节点无任何角色授权） | 后端路由已注释（`AutoRouteConfig` 两表 RouteEntry + import 注释，括号平衡校验通过）；前端写入口摘除 + permissions 不授非超管 待收尾；三层缺一不算完成 |
| **T-24** | **文档与 OPS.md** | 全部 | 全部 | AI | 已完成（skills/sdd/OPS.md 新建 + README 覆盖为 SDD 专属） | `skills/sdd/OPS.md` + README 覆盖 |
| **T-26** | **crudgen/crudweb 全文件字段补齐（agents.skill_name + agent_contexts.task_id）** | REQ-SDD-010 | §2.8/§2.7.5 | AI(主 agent) + web-coder | 已完成 | 后端 PO/DAO/Service/Controller 八文件 + 前端 store model 二 + vue 六，手工逐枚举点补齐；DAO 为硬编码列清单须逐文件改 insert/update/select |

## 任务依赖关系图

```
T-01(生成骨架) ──→ T-02(修订 plugin.yaml) ──→ T-03(SKILL.md) ──┐
                                                    │          │
T-04(COMPOSITION) ──┐                                │          │
T-05(DATA_CONTRACT)─┤                                ▼          ▼
T-06(子agent声明) ──┤──→ T-09(src 编排+派生+事件) ──→ T-11(gate 决策点) ──→ T-23(联调)
T-07(prompts) ──────┤                                │
T-08(templates) ────┤                                └──→ T-12(进度事件) ──→ T-23
T-10(web/app 技能)──┘                                        │
                                                             │
T-13(DB 增量脚本) ──→ T-14(同步扫描扩展) ──┬──→ T-15(SubAgentTool) ──┐
                          │               │                          │
                          │               └──→ T-16(定义字段+agents键)┤
                          │                                           │
                          └──→ T-19(加载管线 bundledAgents) ──→ T-20(解析顺序) ──┤
                                                                       │
T-17(文档:含 agents/ 约定章) ───────────────────────────────────────────┤
T-18(cangjie-coder 去子agent化) ────────────────────────────────────────┤
                                                                       ▼
                                    T-15 ──→ T-21(契约校验器) ──→ T-22(成本账本) ──┤
                                                                       │          │
                                                                       ▼          ▼
                                                            T-23 ──→ T-24(OPS/README)
```

- **顺序链**：T-01 → T-02 → T-03 是骨架与清单前置；T-09 依赖 T-04/T-05/T-06/T-07/T-08 就位。
- **宿主侧链（关键前置）**：**T-13 → T-14 → T-15/T-16 → T-19 → T-20 → T-23**。没有这条链，SDD 的"调子 agent"就是假的（research.md §十、§十二）。
- **自动探测链**：T-14（同步层）+ T-16（定义字段）→ T-19（加载层 bundledAgents）→ T-20（派生层解析顺序）。三者缺一，"加载即就绪"就不成立。
- **增强链（v4）**：**T-15 → T-21（契约校验器）→ T-22（成本账本）**。校验器必须挂在真实派生之后（否则校验的是桩返回值）；成本账本与校验共用同一行派单记录。
- **可并行**：T-04 / T-05 / T-06 / T-07 / T-08 / T-10 之间无强依赖，可在 T-03 后并行展开；T-17 / T-18 与插件侧任务可并行。
- **阻塞点**：T-23 联调阻塞于全部 T-02~T-22；T-24 阻塞于 T-23。

## 任务详细说明

### T-01 生成 L3 进程骨架并初始化基线
- **目标**：以确定性方式落地 `skills/sdd/` 打包外壳（REQ-SDD-001 插件形态）。
- **输入**：仓库已就位的 `plugingen` 工具（`src/plugin/tools/plugingen/plugingen.cj`）。
- **步骤**：
  1. 【人工】在宿主工程编译/运行 `plugingen`，命令：`plugingen --name sdd --mode process --blank`。
  2. 【AI】`cjpm.toml` 原样保留（cjc 1.1.3 + cordis 依赖 + executable，与 long-running-task 同源）。
  3. 【AI】删除 `src/handlers.cj`（CRUD 框架，SDD 不需要）。
  4. 【AI】`src/effects.cj` 暂留待 T-09 适配；`README.md` 暂留待 T-20 覆盖；`SKILL.md` 暂留待 T-03 覆盖。
- **产出物**：`skills/sdd/{cjpm.toml, plugin.yaml, src/main.cj, src/effects.cj, README.md, SKILL.md(占位)}`。
- **验收**：`skills/sdd/` 存在且 `cjpm.toml` 中 `cjc-version="1.1.3"`、`output-type="executable"`；`handlers.cj` 已删除。
- **风险**：plugingen 生成的 CRUD `routes=add/edit/del/list` 与 `tableWhitelist:[]` 是占位，T-02 必须改，否则宿主加载后 host.db 调用被拒。

### T-02 修订 plugin.yaml（清单契约）
- **目标**：固化 `mode: process` 插件清单的表白名单与 SDD 路由（REQ-SDD-001/008/010，design §2.2.1）。
- **步骤**：
  1. `tableWhitelist` 改为七张：`agent_tasks`、`agent_contexts`、`long_running_task_artifact`、`agent_approvals`、`agents`(只读)、`sdd_projects`、`sub_agent_invocations`。
  2. `routes` 改为六条 `gen-*`（gen-research/gen-spec/gen-design/gen-task/gen-code/gen-test）+ `review` + `spawn-subagent` + `GET projects/:feature_name`。
  3. `description` 改为"规范驱动开发（SDD）L3 融合插件"；`command` 保持 cwd 相对路径 `./skills/sdd/target/release/bin/skill_sdd.exe`。
- **产出物**：`skills/sdd/plugin.yaml`。
- **验收**：`tableWhitelist` 恰好七张、与 `spec.md §6.7` 一致；`mode: process`；`command` 带 `skills/sdd/` 前缀。
- **风险**：`sdd_projects` / `sub_agent_invocations` 若未在 T-13 建表，宿主启动会校验失败——**T-02 与 T-13 需配套推进**。

### T-03 编写 SDD SKILL.md（覆盖 CRUD tpl）
- **目标**：定义 SDD 技能语义：六步流程、子 agent 角色与声明、决策点契约、路由（REQ-SDD-001~010）。
- **步骤**：
  1. 覆盖 `plugingen` 生成的 CRUD 占位 SKILL.md。
  2. frontmatter 除 `name: sdd` 外，**必须显式声明 `agents:` 五个子 agent 名单**（待 T-16 让宿主真正解析该键；未解析前它是文档，已解析后它就是声明）。
  3. 正文含：能力说明、六步概览（research→spec→design→task→code→test）、各步绑定的子 agent、人在回路闸口语义（confirm/revise/abandon）、复用底座声明、约束（表红线/语言分派/子 agent 真派生/上下文隔离/文档落盘路径）。
- **产出物**：`skills/sdd/SKILL.md`。
- **验收**：与 `spec.md` 十条需求、`design.md §2.1` 目录结构、`§2.7` 派生设计一致；无 CRUD 残留表述。

### T-04 编写 COMPOSITION.yaml 六步编排
- **目标**：以 long-running-task 真实 schema 定义六步文件态编排（REQ-SDD-002~007，design §2.2.2）。
- **步骤**：
  1. 六步 step：`research`（step_type: output，condition `${input.enable_research}`，**红线不挂文件存在条件**）→ `spec` → `design` → `task` → `code` → `test`。
  2. 每步 `uses_tables` 声明本步触及的表子集（含 `sub_agent_invocations`）；`acceptance_criteria` 写"子 agent 派单成功 + 产出物落库且校验通过"。
  3. 五个 `gate-*` 决策点（spec/design/task/code/test 后各一个）以 `step_type: output` + decision-points 形式挂接。
  4. `degradation_chain` 写降级（code 步失败回退 revise 而非 abandon；**子 agent 定义缺失不得降级**）。
- **产出物**：`skills/sdd/COMPOSITION.yaml`。
- **验收**：schema 与 `long-running-task/COMPOSITION.yaml` 同款；research 步 condition 为 `${input.enable_research}`；每步标注所派生的子 agent 名。
- **风险**：**严禁**抄 `sdd-skills` 理想稿的 `composition:` 根 + `skill:`/`agent_type:`/`output:` schema（与真实 runner 不兼容）。

### T-05 编写 DATA_CONTRACT.yaml（SDD 视角）
- **目标**：固化 SDD 对各表的访问契约与写入纪律（REQ-SDD-009/010，design §2.3）。
- **步骤**：
  1. 复用 long-running-task DATA_CONTRACT schema（`tables[]` + `idempotent_key` + `columns[]` + `write_rule` + `sample_rows`）。
  2. 四张复用表 + `agents`（access: read）+ `sdd_projects` / `sub_agent_invocations`（access: write）。
  3. `write_rule` 固化：状态不倒退、表/列扩张受 §6.7 限量、artifact.stage 维度、`file_path` 指向 runtime 自有 `specs/`、`agent_approvals.skill_name=sdd`、`agent_contexts` 必带 `task_id`、`sub_agent_invocations` 成功必填 `output_json` 与 `duration_ms`。
- **产出物**：`skills/sdd/DATA_CONTRACT.yaml`。
- **验收**：表数量与 `plugin.yaml` 一致；`write_rule` 含"状态不倒退""artifact.stage""上下文按 task_id 隔离"三条。

### T-06 新建五个子 agent 声明文件【v2 新增，关键】
- **目标**：让 SDD 的五个子 agent 从"文字分工"变成**可被派生的实体**（REQ-SDD-010，design §2.7.1/§2.7.2）。
- **步骤**：
  1. 新建 `skills/sdd/agents/` 目录与五份声明文件：`sdd-researcher.md`、`sdd-spec-writer.md`、`sdd-design-writer.md`、`sdd-task-planner.md`、`sdd-tester.md`。（`code` 步不派生子 agent——编码由主 agent 加载编程技能 + SOP 执行，原 `sdd-code-dispatcher.md` 已删除）
  2. 每份 frontmatter 必含：`name` / `agent_type: sub` / `description` / `version` / `author` / `skill_name: sdd` / `parent_id: MainAgent` / `tools` / `model` / `maxTurns` / `memory` / `background` / `identity_status` / `discoverable: true` / `input_types` / `output_types` / `capabilities` / `permissions`。
  3. 正文按 `docs/agents/agent-declaration-spec.md` 的五段结构写：角色 / 输入 / 处理流程 / 输出 / 指南。
  4. **注意 frontmatter 键是 `agent_type` 不是 `type`**（实现读 `agent_type`，规范文档已过时，T-17 修订）。
- **产出物**：`skills/sdd/agents/*.md`（5 份）。
- **验收**：T-14 完成后重启同步 → `SELECT ... FROM agents WHERE skill_name='sdd'` 返回 5 行，`discoverable=true`，`default_input_types`/`default_output_types`/`capabilities` 均非 NULL。
- **风险**：未做 T-14 时这 5 个文件不会被同步进表，子 agent 不可用——**必须与宿主侧改造配套验收**。

### T-07 编写六份执行提示词（含 `code.md`；code 步由主 agent 直执行，不派生子 agent）
- **目标**：定义六步"这一步怎么做"的工作流指令（REQ-SDD-002~007，design §2.7.1）。
- **步骤**：
  1. `prompts/research.md` ← `templates/research-template.md`（八节）。
  2. `prompts/spec.md` ← 6 节组件定位模板 + EARS。
  3. `prompts/design.md` ← legacy 10 节设计模板 + 两段式首章。
  4. `prompts/task.md` ← `templates/tasks-template.md`（开发规范/总览/依赖图/覆盖矩阵/验收清单）。
  5. `prompts/code.md` ← 编码语言分派路由契约（cangjie/web/app），含过渡路由说明（T-10）。
  6. `prompts/test.md` ← `templates/test-report-template.md`（一致性/完成度/缺陷分级/完善意见）。
  7. 每份 prompt 须写明**输入上下文包结构**（对齐 design §2.7.4）与**期望输出格式**。
- **产出物**：`skills/sdd/prompts/{research,spec,design,task,code,test}.md`。
- **验收**：每个 prompt 显式绑定其模板路径（指向 `skills/sdd/templates/`）；code.md 写明 web/app 路由契约；六份均含输入/输出格式约定。

### T-08 打包 templates/（实体复制，插件自完备）
- **目标**：使插件离线可用、信息自完备（design §2.1 + spec §4.4）。
- **步骤**：**必须**把 `research-template.md` / `spec_template.md` / `design_template.md` / `tasks-template.md` / `test-report-template.md` 及 `ears-format.md` / `design-principles.md` **实体复制**进 `skills/sdd/templates/`。
- **产出物**：`skills/sdd/templates/*`（7 份实体文件，非引用）。
- **验收**：仅部署 `skills/sdd/` 一个目录、不挂载 `.codeartsdoer/skills/` 时，六步仍能产出合规文档。
- **风险**：早期版本写过"或写明引用路径"——该表述已与 spec §4.4 冲突，**本版取消该选项**（维护成本低于自完备性的收益）。

### T-09 宿主侧编排引擎（架构重定位）+ 插件退化为资产包 + 薄路由
- **目标**：以进程内编排替换被删的 CRUD handlers，并实现子 agent 派单（REQ-SDD-008/010，design §2.4/§2.5/§2.7.3）。
- **⚠️ 架构重定位（v8，2026-09-27 拍板）**：原设计「插件内 `sdd_subagent_dispatch.cj` 调 `SubAgentTool`」**不可实现**——宿主向插件只暴露 `host.db`/`host.mcp`/`host.event`/`host.db_schema_lookup`/`host.cache`/`host.log`（`cordis_host_services.cj:70-76`），无 `host.agent.invoke` RPC；`SubAgentTool` 是宿主内建工具，Agent 运行时不向插件开放。故**六步真派生落在宿主侧**（类 `lrt_composition_runner`），插件 `sdd` 退化为资产包（SKILL/COMPOSITION/agents/prompts/templates）+ 启动/查询薄路由。
- **实现进展（2026-09-27，宿主侧）**：
  1. 新建 `src/app/services/bridge/sdd_orchestration_service.cj`（`magic.app.services.bridge`）：
     - `SddStageResult` 结构（stage / agentName / success / output / error / durationMs）；
     - `SddOrchestrationService.runStage(...)` —— 六步→子 agent 映射 → 构造 `SubAgentDispatchRequest` → 调 T-15 的 `SubAgentDispatchServiceImpl.dispatch`（真派生 + `sub_agent_invocations` 落库）→ 成功则推进 `sdd_projects` 阶段；失败**立即返回不降级**；
     - `subAgentForStage` 映射（research→`sdd-researcher`、spec→`sdd-spec-writer`、design→`sdd-design-writer`、task→`sdd-task-planner`、test→`sdd-tester`；code 步为宿主直执行 `HOST_DIRECT_STAGES=["code"]`，不在此映射内、不派生），名称取自 `skills/sdd/agents/*.md` 的 `name:`（约定即注册）；
     - `withHostDispatcher()` 便捷构造（组合根同 T-15：`SubAgentDispatchServiceImpl(bridge: AgentRuntimeBridge.instance)`）。
  2. `src/app/services/uctoo/SddProjectsService.cj` 定制区新增 ADR-001 语义化方法：`upsertProject`（按 feature_name 幂等取/建）、`advanceStage`（只改 stage/status，**不触碰 round**）、`bumpRound`（revise 时 +1）、私有 `findByFeatureName`。
     - 刻意让 `advanceStage` 不动 round：阶段推进在同一轮次内，带 round 参数会把 revise 递增的轮次打回 0。
  3. **查环**：跑 `.workbuddy/pkggraph.py` → `SCC size > 1 = NONE`（新增文件只走 bridge→tool / bridge→uctoo 既有边）。
  4. **编排入口接线（2026-09-27）**——`runStage` 此前无调用方，现补宿主侧薄路由：
     - 新建 `src/app/controllers/uctoo/sdd/SddOrchestrationController.cj`：
       `start`（→ `upsertProject` 幂等取/建）/ `runStage`（→ `SddOrchestrationService.runStage` 真派生）/ `status`（只读查询）；
     - 新建 `src/app/routes/uctoo/sdd/SddOrchestrationRoute.cj`：`POST /api/v1/uctoo/sdd/start`、`POST /api/v1/uctoo/sdd/run-stage`、`GET /api/v1/uctoo/sdd/status/:featureName`、`GET /api/v1/uctoo/sdd/status`；
     - `src/app/registry/AutoRouteConfig.cj` 新增 `sdd_orchestration` 路由条目（sdd_projects 通用 CRUD 仍按 ADR-001 保持注释）；
     - `SddProjectsService` 新增只读访问器 `getByFeatureName`（ADR-001 只禁写，读显式开放）；
     - 新增 `sql/incremental/20260927_sdd_orchestration_permissions.sql`：4 条 API 权限（type=3）+ 授予超管（`RequirePermissionMiddleware` 全局生效，未登记一律 403）。
     - 阶段白名单只认 `SddOrchestrationService.STAGES` 一处定义，控制器不复制一份（避免"一侧放行、一侧拒绝"）。
  5. **查环**：`pkggraph.py` → `SCC size > 1 = NONE`（controllers.uctoo.sdd → services.bridge 为新增边，bridge 不反向依赖 controllers）。
  6. **六步异步化（2026-09-27，用户拍板参考 `LrtPluginExecutor` 路子）**：
     - 新增 `src/app/services/crontab/executor/SddOrchestrationExecutor.cj`（scheme = `sdd`，URI `sdd://<feature_name>`）：**每 tick 推进一步**，跑完/失败**自己停表**（引擎摘除 + 库里置 status=2，两步缺一不可）；失败标 `status=failed` 并停表，**不静默降级**。
     - 新增 `src/app/services/bridge/sdd_schedule_bridge.cj`：调度注册/摘除函数槽（依赖倒置）。**原因**：`crontab.executor` 不能反向 import `crontab`（`crontab → crontab.executor → bridge → crontab` 会成环），与 `LrtScheduleBridge` 同一套解法；由组合根 `main.cj` 在 `SchedulerEngine.initialize` 之后注入。
     - `ExecutorRegistry.parseScheme/parsePath` 增 `sdd://` 分支；`SchedulerEngine` 注册 `executorRegistry.register("sdd", ...)`。
     - `SddOrchestrationService.startPipeline(...)`：建 `crontab` 行（`concurrentable=false`、`once=false`、cron 六段无 `?`、每分钟一跳）+ `SddScheduleBridge.reloadCrontab`。
     - 新增 `POST /api/v1/uctoo/sdd/run`（异步整条流水线，HTTP 立即返回 `crontab_id`，并 `spawn` 立即触发首 tick 以免等到下一个分钟边界）；`POST /run-stage` **保留为同步单步**（探针/联调用）。
- **未完（下一跳）**：① 产物落盘与 `long_running_task_artifact` 写入；② `sdd_*` 事件（T-12，走宿主侧事件出口而非插件）；③ 五闸口 gate 决策（confirm/revise/abandon）与 revise 新 task_id 上下文隔离；④ 六步连跑的异步驱动（当前 `run-stage` 为单步同步，长耗时需评估是否改 crontab executor 异步化）。
- **步骤**：
  1. 保留 `main.cj` 的 `PluginRuntime.run(...)` 显式入口（禁用 @Plugin 宏）。
  2. onInit 注册 `SddHandlers.register(ctx)`、`SddEventRelay.register(ctx)`、`SddSubAgentDispatch.register(ctx)`。
  3. 新建 `src/sdd_handlers.cj`：`sdd/gen-*`（六步入口）、`sdd/review`（闸口决策）、`sdd/spawn-subagent`（派生）。
  4. 新建 `src/sdd_subagent_dispatch.cj`：实现 design §2.7.3 的八步派单时序（查 `agents` 表 → 组装上下文包 → 写 `sub_agent_invocations` → 建子任务 → 调 `SubAgentTool` → 回写结果 → 落 artifact）。
  5. 新建 `src/sdd_event_relay.cj`：经 `host.event` 上报 `sdd_*` 进度事件。
  6. `src/effects.cj` 适配：注册 SDD 卸载清理效果。
- **产出物**：`skills/sdd/src/{main.cj, sdd_handlers.cj, sdd_subagent_dispatch.cj, sdd_event_relay.cj, effects.cj}`。
- **验收**：`main.cj` 无 CRUD 注册残留；派单链路写满 `sub_agent_invocations` 字段；子 agent 定义缺失时**抛错提示**而非静默自写。
- **风险**：上下文包超限时走 `path_ref` 降级（design §2.7.4），须在 `mode` 字段标注，不可无声切换。

### T-10 编码语言分派（web-coder / app-coder 编程技能）
- **目标**：落实 REQ-SDD-006 的编码步语言路由。
- **形态约束（v3 变更）**：`web-coder` / `app-coder` 一律为**编程技能**（`skills/<name>/SKILL.md`），**不建 `agents/` 子目录、不派生编码子 agent**（design §1.2.7①）。
- **步骤**：
  1. `prompts/code.md` 写明：仓颉→加载 cangjie-coder；web→加载 web-coder（待建）；app→加载 app-coder（待建）；主 agent 加载后按 SOP 自执行。
  2. 过渡期：web/app 显式路由到 fullstack-codegen / frontend-dev，并在 `code.md` 写清调用契约（不得静默 fallback）。
  3. 【新建】`web-coder`/`app-coder` **技能骨架**（属本插件交付范围），各自**必须包含或引用本技术栈的官方文档技能**，并与 `cangjie-coder` 同构地遵循**确定性优先**哲学（先在目标工程查到确定依据再写代码，禁止凭印象生代码）。
- **产出物**：`prompts/code.md` 路由契约 + `skills/web-coder` / `skills/app-coder` 技能骨架（或过渡路由说明）。
- **验收**：编码步能按语言标签加载技能；过渡路由契约显式可查；web/app-coder 含官方文档技能引用；`ls skills/{web,app}-coder/agents` 不存在。

### T-11 决策点 gate-* 配置（confirm/revise/abandon）
- **目标**：固化步步闸口的人在回路闭环（REQ-SDD-008，design §2.5）。
- **步骤**：
  1. 在 `SKILL.md` decision-points 定义五个 `gate-*`（spec/design/task/code/test 后）。
  2. 每点选项：confirm（进下一步）/ revise（回退上一步重做，不丢已确认产物，上下文按新 `task_id` 重开）/ abandon（终止）。
  3. 对接 `web_request_approval` 契约（对齐 long-running-task SKILL.md）。
- **产出物**：`skills/sdd/SKILL.md` decision-points 段 + COMPOSITION 中 gate 挂接。
- **验收**：revise 回退不覆盖已 confirm 产物；abandon 留痕于 `agent_approvals`；revise 重做时子 agent 上下文为**新 task_id**（不串味）。

### T-12 进度可观测 sdd_* 事件 + SSE 单行转义加固
- **目标**：六步进度可观测（REQ-SDD-001 DFX，design §2.4）。
- **步骤**：
  1. 新增 `sdd_step_start` / `sdd_progress` / `sdd_step_complete` / `sdd_goal_achieved` 事件，并增加 `sdd_subagent_spawn` / `sdd_subagent_done`（子 agent 派生可观测）。
  2. 推送前做 SSE 单行转义（`\r`→`\\r`、`\n`→`\\n`），无 session 早退。
- **产出物**：`sdd_event_relay.cj` + 宿主 SSE 接收端适配说明。
- **验收**：多行正文经转义后单帧可解析；无 session 早退不打日志误判。

### T-13 执行数据库增量脚本【v2 新增】
- **目标**：落地 SDD 工程态与派单留痕的存储（REQ-SDD-010，design §2.8）。
- **步骤**：
  1. 【AI】产出 `sql/incremental/sdd_subagent_20260927.sql`（内容即 design §2.8 的四段 DDL，可直接粘 psql 执行）。
  2. 【人工】执行脚本。
  3. 【人工】若 `sdd_projects` 启用 owner 隔离，把表名加入 `PermissionUtils.hasOwnerUserColumn` 白名单并重新编译宿主。
- **产出物**：2 张新表 + 2 个新列。
- **验收**：`\d public.sdd_projects`、`\d public.sub_agent_invocations` 成功；`agents.skill_name`、`agent_contexts.task_id` 列存在。
- **风险**：白名单未同步会导致"产出但查不到"的静默失败（项目已知坑）。

### T-14 扩展同步扫描范围到 `skills/*/agents/`【v2 新增，关键】
- **目标**：让子 agent 声明文件自动入库，而非手工灌 SQL（REQ-SDD-010，design §2.7.5-1/2）。
- **步骤**：
  1. `src/app/services/sync/detector/ChangeDetector.cj:140-170` 的 `collectMdFiles`：在现有 `<base>/AGENTS.md` + `<base>/agents/**/*.md` 之外，增加遍历 `<base>/skills/*/agents/**/*.md`。
  2. `AgentSyncHandler` 映射新增键：`skill_name`（由 source_path `skills/<name>/agents/...` 推导）、`input_types`→`default_input_types`、`output_types`→`default_output_types`、`capabilities`。
  3. `parent_id` 按名字解析 uuid；解析不到记 `sync_status='dependency_missing'`（不得静默 NULL）。
- **产出物**：宿主侧同步能力升级。
- **验收**：新建 `skills/sdd/agents/probe.md` → 无需手工 SQL 即可在 `agents` 表查到该行，且 `skill_name='sdd'`。
- **风险**：扫描范围扩大可能把非 agent 的 `.md` 收进来——**必须限定路径形态为 `skills/*/agents/*.md`**，不得泛扫 `skills/**`。

### T-15 补全 SubAgentTool 真实派生【v2 新增，关键】
- **目标**：把 `SubAgentTool` 从桩改为真实执行（REQ-SDD-010，design §2.7.5-3）。
- **架构决策（2026-09-27 拍板）**：因 `magic.app.services.bridge` 已反向依赖 `magic.tool`，真派生**不落在 `magic.tool` 包**，采用「宿主侧服务 + DI（函数槽 + 组合根注入）」，与项目既有 `LrtScheduleBridge` 同款解。
- **实现（已完成 2026-09-27）**：
  1. `src/tool/sub_agent_tool.cj`：新增 `SubAgentDispatcher` 接口 + `SubAgentDispatchRequest`/`SubAgentDispatchResult` 结构 + `private static var dispatcher` 槽与 `static setDispatcher`；`execute` 不再走桩，改为构造请求并调用注入的 dispatcher；新增 `agent_id`/`user_id`/`parent_task_id` 三个工具入参；`skill_path` 末段推导 `skill_name`。
  2. 新建 `src/app/services/bridge/sub_agent_dispatch_service.cj`（`magic.app.services.bridge`）：实现 `SubAgentDispatcher`——按 `agent_id`（优先）或 `skill_name`+`name` 解析 → `AgentRuntimeBridge.instance.loadFromDatabase` 造 `BaseAgent` → `AgentAsTool(agent, Isolated).invoke(question)` → 经 `SubAgentInvocationsService.beginInvocation`/`finishInvocation` 写 `sub_agent_invocations`。子 agent 缺失立即失败提示（红线：禁静默降级）。
  3. `src/app/services/uctoo/SubAgentInvocationsService.cj`：定制区新增语义化方法 `beginInvocation`/`finishInvocation`（ADR-001 红线：业务禁直调通用 `update`）。
  4. `src/app/services/bridge/agent_runtime_bridge.cj`：`init()` 组合根注入 `SubAgentTool.setDispatcher(SubAgentDispatchServiceImpl(bridge: this))`。
- **跨包查环**：改后跑 `.workbuddy/pkggraph.py` → `SCC size > 1 = NONE`，无循环依赖。
- **产出物**：可用的子 agent 真派生通道（宿主侧）。
- **验收**：T-23 端到端——派单一子 agent 令其写探针文件 → 文件真实落盘 + `sub_agent_invocations` 有记录 + `duration_ms > 0`；派生不存在的名字 → 明确失败提示而非静默自写。
- **保留项**：`WithContext` 能力在 `AgentAsTool` 已支持，当前默认 `Isolated`（`mode` 入参已留扩展位）；T-20 解析顺序（bundledAgents 优先）依赖 T-19，未在本任务内做。

### T-16 AgentDefinition 扩展字段 + 解析 `agents:` 键【v2 新增】
- **目标**：让声明文件的扩展键与 SKILL.md 的 `agents:` 键真正生效（REQ-SDD-010，design §2.7.5-4/6）。
- **步骤**：
  1. `src/core/agent/agent_definition.cj`：增加 `skillName` / `inputTypes` / `outputTypes` / `capabilities` 字段，并同步 `toJsonValue` 与 builder。
  2. `src/core/agent/agent_loader.cj`：`buildAgentFromYaml` 解析这四个键（注意 `YamlUtils.parseYamlContent` 返回 `HashMap<String,String>`，数组/嵌套结构需确认其表达形式，必要时改写为 JsonValue Map）。
  3. `src/skill/skill_parser.cj`：解析 SKILL.md frontmatter 的 `agents:` 键并挂到技能定义上。
- **产出物**：Agent 定义模型与解析能力升级。
- **验收**：`AgentLoader` 加载 `skills/sdd/agents/sdd-spec-writer.md` 后，`skillName == "sdd"` 且 `inputTypes` 非空。
- **风险**：`parseYamlContent` 的返回结构限制（当前为 `HashMap<String,String>`）可能无法表达嵌套的 `input_types`；若确认不支持，改为在 frontmatter 中以 JSON 字符串内联，由 loader 二次解析，并在 T-17 的规范文档中写明。

### T-17 修订 Agent 声明规范文档【v2 新增，v3 调整】
- **目标**：消除文档与实现的不一致，并把"技能内 `agents/` 目录"确立为规范（REQ-SDD-010/011，design §2.7.5-5）。
- **步骤**：
  1. 修订 `docs/agents/agent-declaration-spec.md`：§3.1 的 `type:` → **`agent_type:`**；补齐 `parent_id` / `skill_name` / `capabilities` / `model_capabilities` / `capabilities_skill` / `identity_status` / `discoverable`；修正 §7.1 已失效的加载目录（built-in/user/project/policy）。
  2. **新增"技能内 `agents/` 目录约定"章节**：目录形态 `<skill-root>/agents/*.md`、必需键、自动探测与双向同步、删除即下线、判别准则（流程编排类建、编程/领域类不建）。
- **产出物**：规范文档 v1.1。
- **验收**：文档中的键名与 `agent_loader.cj` 完全一致；含 `agents/` 目录约定章。
- **注**：v3 已取消"回填 4 条 cangjie-coder 手工数据"，改为 T-18 清理下线。

### T-18 cangjie-coder 去子 agent 化【v3 变更，替代原"迭代至定稿"】
- **目标**：删除早期 AI 工具遗留的语言角色子 agent，统一 coder 类技能形态（REQ-SDD-006，design §1.2.7②）。
- **步骤**：
  1. 删除 `skills/cangjie-coder/agents/` 四个文件（`code-searcher` / `code-editor` / `code-verifier` / `doc-consultant`）。
  2. 把四个角色的职责并入 `skills/cangjie-coder/SKILL.md` 的**四步工作流**（查阅 CangjieSkills → 检索代码片段 → 编辑适配 → 写入文件）——该工作流本就与四角色一一对应，无需新增内容，只需核对无遗漏。
  3. 【人工】执行清理 SQL（design §2.8 第 3 条的 DELETE 语句），下线 `agents` 表中 4 条手工数据。
  4. 核对 `SKILL.md` frontmatter 中 `agents:` 声明键一并删除。
- **产出物**：`skills/cangjie-coder` 纯技能形态（SOP + `references/` + `scripts/` + 官方文档技能引用）。
- **验收**：`ls skills/cangjie-coder/agents` 不存在；`SELECT count(*) FROM agents WHERE skill_name='cangjie-coder'` = 0；给一个 `.cj` 编码任务 → 主 agent 按四步工作流执行并产出代码。
- **风险**：若 T-19/T-20 未完成，删除后 cangjie-coder 完全靠 SOP 运行——这正是目标形态，不构成回归。

### T-19 技能加载管线挂载 `bundledAgents`（自动探测）【v3 新增，关键】
- **目标**：实现"主 agent 加载带 `agents/` 的技能时自动探测并注册其中子 agent"（REQ-SDD-011，design §2.9.3）。
- **前置**：T-13（DB 列）、T-14（同步层）、T-16（定义字段）。
- **步骤**：
  1. **先确认真加载入口**：`SkillManagementService.loadSkillsFromDirectory`（依据 `src/plugin/skill_bridge.cj:18` 注释：frontmatter → manifest 校验 → Skill 实例完整管线）。**禁止**改 `src/skill/skill_loader.cj:55`——它返回 `placeholder-skill`，是桩。
  2. 在真入口处，技能解析完成后追加：探测 `<skill-root>/agents/` → 逐个解析 frontmatter（复用 `src/core/agent/agent_loader.cj:117-190`，读 `agent_type`）→ 必需键缺失则跳过并报错 → 组装后挂到 Skill 实例的 `bundledAgents` 字段。
  3. 与同步层做一致性校验（文件数 N vs DB 条数 M，N≠M 以 DB 为准并打 WARN）。
- **产出物**：技能加载能力升级 + `bundledAgents` 字段。
- **验收**：加载 `sdd` 技能 → `bundledAgents` 长度 6；加载 `cangjie-coder` → 长度 0；放入缺 `agent_type` 的文件 → 报错指出文件与缺失键、不入库。

### T-20 SubAgentTool 解析顺序：bundledAgents 优先【v3 新增】
- **目标**：让"加载即就绪"闭环（REQ-SDD-011，design §2.9.4）。
- **前置**：T-15（真实派生）、T-19（bundledAgents）。
- **步骤**：
  1. `src/tool/sub_agent_tool.cj` 的 agent 解析改为三步：① 当前技能 `bundledAgents` 按 name 查 → ② 全局 `agents` 表查（`discoverable=true`）→ ③ 均未命中则**立即失败并报出缺失 source_path**，禁止静默降级。
  2. 命中后沿用 T-15 的真实派生链路（写 `sub_agent_invocations` → `AgentAsTool` Isolated）。
- **产出物**：可用的"按名派生"通道。
- **验收**：主 agent 加载 `sdd` 后直接派生 `sdd-spec-writer` → 真实执行 + `sub_agent_invocations` 有记录；派生一个不存在的名字 → 明确失败提示而非静默自写。

### T-21 派单结果契约校验器（ContractVerifier）【v4 新增，建议 A】
- **目标**：把"子 agent 交回什么就信什么"升级为按契约自动校验，残次品在自动层被拦截（REQ-SDD-012-A，design §2.10.2）。
- **步骤**：
  1. 【cangjie-coder】新建 `src/tool/sub_agent_contract_verifier.cj`：纯字符串 / JSON 处理，**不得**发起网络或模型调用（spec §4.1-3 ≤1s）。
  2. 规则来源 `agents.capabilities.output_contract`（`kind` / `required_sections` / `forbidden_placeholders` / `min_chars`；json 类用 `schema`）；`default_output_types` 为空时降级为"仅非空校验"并标 `contract_absent`。
  3. 挂点：`SubAgentTool` 在回写 `output_json` **之前**调用；通过才采信，失败且 `attempt=1` 时携结构化错误自动重派一次，`attempt=2` 仍失败转人工闸口。
  4. 校验结果写 `sub_agent_invocations` 的 `contract_type` / `verify_passed` / `verify_errors` / `attempt`。
- **产出物**：`src/tool/sub_agent_contract_verifier.cj` + 五个子 agent 声明文件的 `output_contract` 规则段。
- **验收**：回传一篇缺章节 spec → 预期 `verify_passed=false` + `attempt` 递增 + 恰好两次派单后转闸口；改 `required_sections` → 规则即时生效无需改代码。

### T-22 派生成本账本（token/duration 入表 + 聚合视图）【v4 新增，建议 B】
- **目标**：让"这一步派生划算吗"可测量（REQ-SDD-012-B，design §2.10.3）。
- **步骤**：
  1. 【人工】执行增量脚本（随 T-13 一并交付）：`sub_agent_invocations` 增加 `contract_type` / `verify_passed` / `verify_errors` / `attempt` / `prompt_tokens` / `completion_tokens` / `total_tokens` 七列（**新表加列，不触碰既有表，§6.7 限量不变**）+ 建 `v_sub_agent_stage_cost` 视图。
  2. 【cangjie-coder】派单收尾处读取模型 `usage` 写四段成本；取不到记 `0` 并在 `error_message` 追加 `token_missing`，**禁止**用字符数折算。
  3. 按 `stage` 聚合导出四张指标：派单次数 / 平均 tokens / 重派率 / 平均耗时。
- **产出物**：增量 SQL + 取数口径 + 首个工程的成本基线数据。
- **验收**：一次派单后四条成本字段非 NULL；`SELECT * FROM v_sub_agent_stage_cost` 能按 stage 给出四项指标。

### T-23 联调验证（人工编译 + 宿主加载 + 走通六步）
- **目标**：端到端验证（全部需求）。
- **步骤**：
  1. 【人工】`cd skills/sdd && cjpm build`（产出 `target/release/bin/skill_sdd.exe`）。
  2. 【人工】宿主 `config/plugins.yaml` 追加 sdd 条目，启动宿主加载。
  3. 【人工+AI】发起一个真实软件任务，走通 research（开/关）→ spec→design→task→code→test 六步，每步触发 gate 闸口决策。
  4. 校验落库：`agent_tasks`（状态机）、`sdd_projects`（current_stage/round）、`long_running_task_artifact`（stage 维度 + `file_path` 在 runtime 自有 `specs/`）、`agent_approvals`（留痕）、`sub_agent_invocations`（六条以上派单记录）、`agent_contexts`（`task_id` 非空）。
  5. 校验 revise 回退（上下文为新 task_id，不串味）与 abandon 终止语义。
  6. 校验子 agent 真派生：临时删除某子 agent 记录 → 预期立即失败并提示，不得静默自写。
  7. **校验自动探测**：新建 `skills/sdd/agents/probe.md` → 无需手工 SQL 即可查出；删除该文件 → DB 对应行消失（约定即注册 + 删除即下线）。
  8. **校验契约校验与成本账本**：故意回传缺章节文档 → 预期两次派单后转人工；查 `v_sub_agent_stage_cost` → 预期各 stage 四项指标齐全。
- **产出物**：验证报告（可纳入 test-report-template 产物）。
- **验收**：六步可跑通、闸口可用、子 agent 真派生、自动探测生效、契约校验生效、成本可聚合、落库符合 DATA_CONTRACT、表/列扩张不超 §6.7 限量。

### T-25 关闭两张新表的人工写入口（前端 + 菜单 + 后端路由）【ADR-001 v2 新增】

- **目标**：让 `sdd_projects` / `sub_agent_invocations` 事实上不可被人工增删改，补齐 ADR-001 v2 相比 v1 付出的安全性代价。
- **背景**：这两张表已 `crudgen` 生成五层模块 + `crudweb` 生成前端页面（见 `logs/crud.md`），写接口当前**全部开放**。仅注释前端入口**不够**——后端路由仍在注册、菜单项由 `permissions` 节点决定。
- **步骤（三步，缺一不算完成）**：
  1. **后端（真正的关闭点）**：注释掉两张表 Route 中的写路由注册——
     `src/app/routes/uctoo/sdd_projects/SddProjectsRoute.cj` 与 `src/app/routes/uctoo/sub_agent_invocations/SubAgentInvocationsRoute.cj`
     里的 `add` / `edit` / `del` / `empty-recycle-bin` 四行；`src/app/registry/AutoRouteConfig.cj:612-636` 保持注册块不动，只注释 Route 内部的路由行。
     保留 `getSingle` / `getManyWithPathParams` / `getManyWithSkip` / `export`（只读）。
  2. **菜单**：`permissions` 中已生成的 `database.uctoo.sdd_projects` / `database.uctoo.sub_agent_invocations` 两个节点**不授予任何非超管角色**（默认角色一律不授），否则前端改了菜单项照样在。
  3. **前端**：`apps/web-admin/web/src/views/database/uctoo/{sdd_projects,sub_agent_invocations}/` 下 `index.vue` 不挂载 `components/add-*.vue` 与 `components/edit-form.vue`，表格的操作列去掉编辑/删除按钮；`*-table.vue` 降级为只读列表。
- **产出物**：上述三个位置的实际改动 + 一张"当前仍开放的写路径"清单。
- **验收**：① 直接 `curl POST /api/v1/uctoo/{两张表}/add` 返回 404/路由不存在（不是仅仅页面上看不见）；② 普通角色登录后菜单不出现这两项；③ 列表页无新增/编辑/删除入口，且数据仍可读。
- **风险**：若后续确实需要后台查看"派生 ROI"，走 §6.3 的只读列表路由 + `v_sub_agent_stage_cost` 视图，不要图省事把写路由加回来。

### T-24 文档与 OPS.md
- **目标**：交付运维手册（对齐 long-running-task OPS.md）。
- **步骤**：
  1. 覆盖 `plugingen` 生成的通用 README 为 SDD 专属。
  2. 新建 `OPS.md`：部署、插件登记、编译命令、子 agent 注册与派生排查（声明文件未同步 / SubAgentTool 未改造 / 上下文串味）、常见排查（command 路径 / SSE 早退 / tableWhitelist 被拒）。
- **产出物**：`skills/sdd/OPS.md` + `README.md`。
- **验收**：OPS 与 design §2.6 十条防回退约束一一对应。

### T-26 crudgen/crudweb 全文件字段补齐（agents.skill_name + agent_contexts.task_id）【v5 后续，手工补齐】
- **目标**：把 `sdd_subagent_20260927.sql` 后来追加的两列（`agents.skill_name`、`agent_contexts.task_id`）补进 crudgen/crudweb 已确定性生成、但事后未重跑生成器的全部 CRUD 产物（REQ-SDD-010，design §2.8/§2.7.5）。
- **根因**：两张表的"全套 CRUD"此前已由 `src/app/tools/crudgen`（后端五层）+ `src/app/tools/crudweb`（前端）确定性生成；DDL 是后来单独补的，没重跑生成器，导致新列在所有 CRUD 产物里缺失。重跑生成器会覆盖既有定制（`SKILL.md`/`plugin.yaml` 已因 plugingen 丢过一次），故选择**手工逐文件补齐**而非重跑。
- **关键事实**：crudgen 的 DAO 是**硬编码列清单**（非 `@QueryMappersGenerator` 宏生成），加列必须改 `insert` 列 / `insert values` / `update set` / 所有 `select` 列清单（多处写死），不能靠宏自动展开。
- **后端补齐（8 文件，仓颉）**：
  - `agents`：`AgentsPO`（`@ORMField` 声明 + 构造函数参数/体 + `toJsonValue`）、`AgentsDAO`（insert 列+values、update set、6 处 select 列清单，`replace_all` 统一在 `description` 后插 `skill_name`）、`AgentsService.update`（`skillName.isSome()` 合并段）、`AgentsController.mapToEntity`（从 `map.get("skill_name")` 映射 `Some<String>(s)`）。
  - `agent_contexts`：`AgentContextsPO`（`task_id` 在 `deleted_at` 后、`Option<String>`）、`AgentContextsDAO`（insert/update/7 处 select 统一末位加 `task_id`）、`AgentContextsService.update`（`taskId.isSome()` 合并段）、`AgentContextsController.mapToEntity`（`task_id` 映射）。
  - 未改：`*Route.cj`（路由不含字段枚举）。
- **前端补齐（`apps/web-admin/web/src`，web-coder）**：
  - store model：`store/models/uctoo/agents.ts`（`@Str('') declare skill_name`）、`agent_contexts.ts`（`@Uid() declare task_id`）。
  - vue 表单/表格（字段枚举点逐处补齐）：`agents/components/{add-agents,agents-table,edit-form}.vue`、`agent_contexts/components/{add-agent-contexts,agent-contexts-table,edit-form}.vue`。
  - 枚举点：formModel 初始化 / registerPageTool 解构 / formModel 赋值 / `<TinyFormItem>` 模板（add）；availableFields / getData 提取 / searchParams / 行映射 / onEditClosed 回写 / query+create 解构 + if 过滤块 + add 负载 / `<TinyGridColumn>`（table）；formData 初始化 / watch Object.assign / 模板（edit-form）。
  - 未改：`index.vue`（仅组合组件、无字段枚举）。
- **产出物**：上述 16 个文件（8 后端 + 2 store model + 6 vue）的实际改动。
- **验收**：grep `skill_name` / `task_id` 确认 6 个目标 vue 与后端五层均含新字段；DAO 多 select 处无遗漏；前端 `npm` 编译 + 后端 `cjpm build` 由人工验证（AI 不跑构建）。
- **关联与改进建议**：与 T-13（DDL 执行）、T-14（同步层 `skillName` 绑定）互补——T-13/T-14 解决"列与同步"，本任务解决"已生成 CRUD 产物补齐"。建议固化红线："DDL 列变更须触发 crudgen/crudweb 重跑 review"，或把 DAO 改造为宏生成，避免下次再手工补。

## 需求覆盖追踪矩阵

| spec 需求 | 覆盖任务 | 覆盖状态 | 备注 |
|-----------|----------|----------|------|
| REQ-SDD-001 任务识别与工程初始化 | T-01/T-02/T-03/T-12 | 全覆盖 | 插件形态=L3 进程，复用底座 |
| REQ-SDD-002 可选研究 | T-04/T-06/T-07/T-08 | 全覆盖 | research 步 condition 红线 |
| REQ-SDD-003 需求 | T-04/T-06/T-07 | 全覆盖 | 绑定 6 节模板 + EARS |
| REQ-SDD-004 设计 | T-04/T-06/T-07 | 全覆盖 | 绑定 legacy 10 节 + 两段式 |
| REQ-SDD-005 任务 | T-04/T-06/T-07 | 全覆盖 | 绑定 tasks-template |
| REQ-SDD-006 编码 | T-07/T-10/T-18 | 全覆盖 | web/app-coder 以**技能**形态待建；cangjie-coder 去子 agent 化后按 SOP 运行 |
| REQ-SDD-007 测试 | T-04/T-06/T-07 | 全覆盖 | 绑定 test-report-template |
| REQ-SDD-008 步步闸口 | T-04/T-09/T-11 | 全覆盖 | gate-* 五闸口 |
| REQ-SDD-009 决策闭环 | T-05/T-11/T-23 | 全覆盖 | 落库 + revise/abandon 留痕 |
| **REQ-SDD-010 子 agent 派生与上下文交接** | **T-06/T-09/T-13/T-14/T-15/T-16/T-17** | **全覆盖** | 声明文件 + 同步 + 真实派生 + 派单留痕 + 上下文隔离 |
| **REQ-SDD-011 技能内 `agents/` 自动探测与加载** | **T-14/T-16/T-17/T-19/T-20/T-23** | **全覆盖** | 同步层扩扫 + 加载层 bundledAgents + 派生层优先解析 |
| **REQ-SDD-012 派单结果契约校验 + 派生成本账本** | **T-15/T-21/T-22/T-23** | **全覆盖** | 校验器挂真实派生之后（T-15 前置）；成本字段属新表，不占既有表列额度 |

## 验收检查清单（终验）
- [ ] 全部 **12** 条 REQ-SDD 有对应实现并通过其 EARS 验收条件
- [ ] DFX 约束（性能/可靠/安全/可维护/兼容）已验证或标注豁免
- [ ] 复用项未被重新实现（COMPOSITION 引擎/决策框架/复用表/模板均复用）
- [ ] 编译 / 类型检查 / lint 通过（人工确认，AI 不运行 cjpm build）
- [ ] spec/design/tasks 三份文档与最终实现一致（无漂移）
- [ ] 表/列扩张严格符合 `spec.md §6.7`：新增表 ≤2、新增列 ≤2
- [ ] plugingen 生成的 CRUD 残留（handlers.cj / SKILL.md.tpl 表述 / routes=add/edit/del/list）已清除
- [ ] 六步走通 + 五个 gate 可用 + revise/abandon 语义正确
- [ ] **五个子 agent 声明文件已由同步机制自动入 `agents` 表**（`skill_name='sdd'`，discoverable=true，契约三列非 NULL）
- [ ] **`SubAgentTool` 已非桩**：派单可产生真实副作用（探针文件落盘）
- [ ] **上下文按 `task_id` 隔离**：revise 重做时子 agent 不读到上一轮 messages
- [ ] **子 agent 缺失时立即失败提示**，无静默自写
- [ ] 阶段文档落在 runtime 自有 `specs/{feature_name}/`，`.codeartsdoer/specs/` 下无新增产出
- [ ] `skills/sdd/templates/` 实体齐全，仅部署插件目录即可产出合规文档
- [ ] **coder 类技能无 `agents/`**：`skills/{cangjie,web,app}-coder/` 三处均无该目录；`agents` 表中 `skill_name='cangjie-coder'` 为 0 行
- [ ] **自动探测生效**：加载 `sdd` 技能即得到 5 个 `bundledAgents`；新建/删除 `agents/*.md` 能双向同步（无手工 SQL）
- [ ] **未误改假入口**：`src/skill/skill_loader.cj:55` 未被当作加载入口改造
- [ ] **契约校验生效**：缺章节回传被拦截（`verify_passed=false` + `attempt` 递增），自动重派恰好 1 次后转人工闸口，无无限重试
- [ ] **成本账本可聚合**：`v_sub_agent_stage_cost` 按 stage 给出派单次数 / 平均 tokens / 重派率 / 平均耗时；token 取不到记 0 + `token_missing`，无估算冒充实测

## 修订记录 / 多轮迭代
- 2026-09-26 v1 初稿：基于 spec/design 生成 13 个任务；明确采用 plugingen 生成打包外壳、删除 CRUD 框架的处置策略（research.md §九）。
- 2026-09-27 v2 修订（四次研究成果并入，research.md §十/§十一）：
  1. 新增 **REQ-SDD-010 子 agent 派生与上下文交接**，配套新增 T-06（声明文件）、T-13（DB 增量）、T-14（同步扫描扩展）、T-15（SubAgentTool 补全）、T-16（定义字段 + `agents:` 键解析）、T-17（规范文档修订 + 数据回填）、T-18（cangjie-coder 定稿）共 7 个任务，任务总数 13 → 20。
  2. 原「T-06 子 agent 声明与提示词」拆为 **T-06（声明文件）+ T-07（执行提示词）**，理由：声明定义"是谁"（入表、可发现），提示词定义"这一步怎么做"（随步骤加载），分离后子 agent 可被非 SDD 场景复用。
  3. 原 T-07（templates）**取消"或写明引用路径"选项**，改为必须实体复制（与 spec §4.4 插件自完备对齐）。
  4. 建表红线由"禁建表"放宽为"新增表 ≤2、新增列 ≤2"（用户授权），但仍严格限量。
  5. 新增文档落盘路径红线（runtime 自有 `specs/`）、子 agent 真派生红线、上下文隔离红线。
  6. 依赖图补宿主侧关键前置链 T-13 → T-14 → T-15/T-16 → T-19。
- 2026-09-27 **v3 修订（五次研究成果并入，research.md §十二）**：
  1. **架构决策变更**：采纳用户意见，编程语言专用子 agent 架构作废——`cangjie-coder` / `web-coder` / `app-coder` 一律为**纯技能形态**（SOP + 官方文档技能 + references/scripts），**不建 `agents/` 子目录、不派生编码子 agent**。理由：模型能力提升后角色切分的边际收益已被覆盖，派生成本（上下文重建、编排复杂度）不再划算。
  2. **T-18 目标反转**：原"迭代 cangjie-coder 至定稿（子 agent 真跑通）"→ 改为"**cangjie-coder 去子 agent 化**"（删 `skills/cangjie-coder/agents/` 4 文件 + 清理 DB 4 条手工数据 + 职责并入 SKILL.md 四步工作流）。
  3. **T-17 去掉数据回填**：原"回填 4 条 cangjie-coder 手工数据"取消，改为规范文档新增"技能内 `agents/` 目录约定"章。
  4. **T-10 形态修正**：web-coder/app-coder 由"子 agent 骨架"改为"**技能骨架**"，并加验收项"无 `agents/` 目录"。
  5. **新增 REQ-SDD-011 技能内 `agents/` 自动探测与自动加载**，配套新增 **T-19（加载管线挂 bundledAgents）**、**T-20（SubAgentTool 解析顺序）** 两个任务，任务总数 20 → 22；原 T-19/T-20 顺延为 T-21/T-22（联调验证 / 文档）。
  6. **新增红线**：coder 技能禁止 `agents/`；子 agent 只靠约定注册（禁手工 SQL / 禁硬编码）；禁改假加载入口（`skill_loader.cj:55` 是桩，真入口为 `SkillManagementService`）。design §2.6 防回退约束 10 条 → 13 条。
- 2026-09-27 **v4 修订（用户采纳建议 A + B）**：
  1. **新增 REQ-SDD-012**：① **派单结果契约校验**（按 `agents.default_output_types` + `capabilities.output_contract` 自动校验回传产物，不过则不采信；携结构化错误自动重派 **1 次**，仍失败转人工闸口）；② **派生成本账本**（每次派单记 `duration_ms` + token 三项，按 `stage` 聚合出单位产出成本）。
  2. 配套新增 **T-21（契约校验器）**、**T-22（成本账本字段 + `v_sub_agent_stage_cost` 视图）** 两个任务，任务总数 22 → 24；原 T-21/T-22 顺延为 T-23/T-24（联调验证 / 文档）。
  3. **依赖定位**：T-21 挂在 **T-15 之后**——必须先有真实派生，否则校验的是桩返回的假字符串。
  4. **不突破 §6.7 限量**：校验规则塞进 `agents.capabilities`（jsonb），成本字段属**新表** `sub_agent_invocations` 的固有列，既有表新增列仍锁定为 2 个。
  5. design 新增 §2.10（校验器流程 / 规则结构 / 成本口径 / 4 条防回退），§2.8 DDL 补齐七列与聚合视图；spec §4.1 新增"契约校验 ≤1s 且无网络/模型调用"。
  6. 验收清单补 2 项（契约校验生效 / 成本可聚合），终验 REQ 条数 11 → 12。
- 2026-09-27 **v5 修订（人工落地执行结果并入，见 `logs/crud.md`）**：
  1. **T-01 已完成**：人工执行 `plugingen --name sdd --mode process` 生成 L3 骨架；`cjpm build` 通过。**但 plugingen 覆盖了已完成的定制 `SKILL.md` / `plugin.yaml`**（`skills/sdd/` 未被 git 跟踪，无法版本找回），已由 AI 按原始设计重写恢复，并按 T-01 删除 CRUD 残留 `src/handlers.cj`。
  2. **T-13 已完成**：增量 SQL 已执行；随后 `loaddbinfo --db uctoo` 刷新 `db_info`（2920 列），两张表的 PO 已完整包含 REQ-SDD-012 七个新列。
  3. **存储层形态改口径（ADR-001 v1 → v2）**：两张新表改由 **`crudgen` 生成宿主五层模块**（宿主侧不再手写仓储），并新增 **T-25（关闭人工写入口：前端 + 菜单 + 后端路由三层）**；红线同步改写，新增"生成器执行顺序红线"（先生成后定制）。原 v1「手写仓储」降级为备选方案。
  4. **新增 T-25**，任务总数 24 → 25。
  5. **顺带修掉**：`COMPOSITION.yaml` 六步 `uses_tables` 补齐两张新表并明确写入责任方（`sdd_projects` 每步推进、仅文档步写 `sub_agent_invocations`、code 步不写）；`plugin.yaml` 路由与 `design.md` §2.2.1 对齐（补 `GET /projects/:feature_name`，去 `:id` / `:limit/:page`）；`skills/sdd/src/main.cj` 的 `console.log` 改 `eprintln`（L3 stdout 是 stdio RPC 通道）。
  6. **已知待决策**：`sdd_projects` 是否启用 owner 隔离（crudgen 跳过了行级权限配置，日志第 58 行）；启用则须把表名加入 `PermissionUtils.hasOwnerUserColumn` 并重编宿主。
- 2026-09-27 **v6 修订（crudgen/crudweb 全文件字段补齐，T-26）**：
  1. **新增 T-26（已完成）**：`sdd_subagent_20260927.sql` 后来补的两列（`agents.skill_name`、`agent_contexts.task_id`）未触发生成器重跑，须手工补齐全部 CRUD 产物。后端 PO/DAO/Service/Controller 8 文件 + 前端 store model 2 + vue 6 已逐枚举点补齐（DAO 为硬编码列清单，insert/update/select 多处改）。
  2. 关键事实入档：crudgen 的 DAO 非宏生成、列写死；重跑生成器会覆盖既有定制，故走手工补齐路径。
  3. 改进建议入档：固化"DDL 列变更须触发 crudgen/crudweb 重跑 review"红线，或 DAO 改宏生成，避免下次再手工补。

- 2026-09-27 **v7 修订（T-15 宿主侧真派生链路完成）**：
  1. **T-15 已完成（宿主侧）**：`SubAgentTool` 由桩改为经 DI 真派生——`magic.tool` 定义 `SubAgentDispatcher` 接口 + `SubAgentDispatchRequest`/`SubAgentDispatchResult` + `setDispatcher` 函数槽；`magic.app.services.bridge.SubAgentDispatchServiceImpl` 实现（查 agents 表 → `AgentRuntimeBridge.loadFromDatabase` 造 Agent → `AgentAsTool(Isolated).invoke` → 写 `sub_agent_invocations` 的 `beginInvocation`/`finishInvocation`）；`AgentRuntimeBridge.init()` 组合根注入。子 agent 缺失立即失败提示（红线：禁静默降级）。
  2. **架构决策入档**：因 `bridge` 已反向依赖 `magic.tool` 成环，真派生不落 `magic.tool`，沿用项目既有「函数槽 + 组合根注入」解（同 `LrtScheduleBridge`）。
  3. **ADR-001 落地**：`SubAgentInvocationsService` 定制区新增 `beginInvocation`/`finishInvocation` 语义化方法，业务派单经语义化方法而非通用 `update`。
  4. **查环**：改后跑 `pkggraph.py` → 无循环依赖（SCC NONE）。
  5. **状态行更新**：T-15 标「已完成(宿主侧链路；端到端见 T-23)」；T-16 已并入 T-15 关联。端到端走通（探针落盘 + 落库 + duration_ms）留 T-23。

- 2026-09-27 **v8 修订（T-09 架构重定位：宿主侧编排引擎）**：
  1. **T-09 架构阻断（实测核查）**：宿主向插件仅暴露 `host.db`/`host.mcp`/`host.event`/`host.db_schema_lookup`/`host.cache`/`host.log` 六类 RPC（`src/plugin/cordis_host_services.cj:70-76`），**无 `host.agent.invoke`/chat RPC**；`SubAgentTool` 是宿主内建工具（`builtin_tools_registry.cj:120`），Agent 运行时全在宿主进程内、不向插件开放；参考插件 `long-running-task` 也**从不在插件进程内跑 LLM 子 agent**（其 `spawn` 全是子进程 stdio 管道读脚本输出，由宿主 `LrtPluginExecutor` 经 `lrt-execute` 路由驱动）。故 T-09 原设计「插件内 `sdd_subagent_dispatch.cj` 调 `SubAgentTool`」**在插件进程内不可实现**，落笔即"凭印象臆造不存在的 API"，违反项目「确定性优先」红线。
  2. **决策（用户拍板，推荐项）**：六步编排引擎**落在宿主侧**（类 `lrt_composition_runner`），每步直接调 T-15 已就绪的 `SubAgentDispatchServiceImpl.dispatch`（复用真派生 + `sub_agent_invocations` 落库 + 事件）；插件 `sdd` **退化为资产包**（SKILL/COMPOSITION/agents/prompts/templates）+ 启动/查询薄路由。原插件内 `sdd_subagent_dispatch.cj` 移入宿主（作为编排引擎一部分）。
  3. **状态行更新**：T-09 由「待开始」改为「进行中（架构决策已定，宿主侧落地中）」；预计产出改为「宿主 `SddOrchestrationService` + 插件资产包 + 薄路由」。
  4. **连锁影响**：T-23 联调路径随编排落点变更（真派生在宿主，无需 `host.agent.invoke` RPC）；T-12 的 sdd_* 事件中继随之改在宿主侧（类 `LrtEventRelay`）而非插件 `sdd_event_relay.cj`；插件 `sdd/src/` 仅保留 `main.cj`+`effects.cj` 薄壳 + 启动/查询路由壳。

- 2026-09-27 **v9 修订（T-19 / T-20 落地：约定即注册 + bundledAgents 优先解析）**：
  1. **T-19（REQ-SDD-011）已落地**：新增 `src/skill/infrastructure/loaders/bundled_agent_scanner.cj`（`BundledAgentScanner.scan(skillDir)`），扫描 `<skill-root>/agents/` 下 `.md`，取文件名（去后缀）为子 agent 名；**扫描口径对齐 `ChangeDetector.collectMdFiles`**（同一目录、同样只认 `.md`），保证「加载期探测」与「同步期落库」看到同一批声明文件。`SkillManifest` 新增 `bundledAgents: Array<String>`（默认空数组，既有 3 个构造点不受影响）+ `hasBundledAgent(name)`。两个构造点填充：`skill_md_loader.cj`（**真解析点**，链路 `SkillManagementService.loadSkillFromPath` → `SkillLoadingService.loadSkillFromPath` → `SkillMdLoader`）与 `skill_loading_service.cj`（`createSkillManifestFromContent`，有外部调用点 `file_based_skill_repository.cj:72`）。
  2. **T-20（REQ-SDD-011）已落地**：`SubAgentDispatchServiceImpl` 新增 `pickBundledFirst(list, skillName)`，同名多条时按 ① 归属当前技能（`skill_name` 命中）→ ② 全局子 agent（`skill_name` 为空）→ ③ 首条 的顺序挑；按 name 解析分支改用它，`pageSize` 由 10 放宽到 50。**实现口径说明**：bundledAgents 作用域在派单侧以 `skill_name` 过滤表达（T-14 同步已按路径写 `skill_name`），未把内存 manifest 跨层传到派发器——语义等价、改动最小、无新增跨包依赖。
  3. **校验**：`pkggraph.py` 查环 → `SCC size > 1 = NONE`；5 个改动文件块注释深度 0、花括号/圆括号平衡。
  4. **仍待 T-23 端到端确认**：真实加载时 `bundledAgents` 是否如日志所示探测到 5 个（`sdd-researcher` / `sdd-spec-writer` / `sdd-design-writer` / `sdd-task-planner` / `sdd-tester`；`code` 步不派生，已无 `sdd-code-dispatcher`），以及同名多技能场景下的优先挑选是否生效。

- 2026-09-27 **v10 修订（T-09 编排入口接线：宿主侧薄路由 + RBAC 注册）**：
  1. **接线背景**：v8 落地 `SddOrchestrationService.runStage` 后**长期无调用方**，六步编排跑不起来；本轮补上宿主侧入口。
  2. **落地内容**：新增 `SddOrchestrationController`（`magic.app.controllers.uctoo.sdd`）与 `SddOrchestrationRoute`（`magic.app.routes.uctoo.sdd`），在 `AutoRouteConfig.cj` 注册 `sdd_orchestration` 条目（`sdd_projects` 通用 CRUD 仍按 ADR-001 保持注释）；`SddProjectsService` 增 `getByFeatureName` 只读访问器；新增 `sql/incremental/20260927_sdd_orchestration_permissions.sql`（4 条 type=3 API 权限 + 授予超管）。
  3. **两个刻意的设计口径**：① 阶段白名单只在 `SddOrchestrationService.STAGES` 一处定义，控制器不复制（避免一侧放行一侧拒绝）；② RBAC 必须显式注册——`RequirePermissionMiddleware` 挂在全局（`main.cj:496`），未登记路径对非通配角色一律 403（errno 40301），LRT 系列路由同样是靠 permissions 表登记才通。
  4. **import 归属修正（实测）**：`SddProjectsPO` 声明在 `magic.app.models.uctoo`，**不是** `magic.app.services.uctoo`；初版写成从 services 包导入，按 models 包既有先例（`AgentsController.cj:13`）改正。
  5. **校验**：`pkggraph.py` → `SCC size > 1 = NONE`；4 个改动文件块注释深度 0、花括号/圆括号平衡。
  6. **遗留**：`run-stage` 目前是**单步同步**（子 agent chat 可能耗时数分钟，HTTP 长连接风险），六步连跑的异步驱动（是否改走 crontab executor 异步化）未定，留 T-23 前评估。

- 2026-09-27 **v11 修订（六步异步化：改走 crontab executor）**：
  1. **变更动机（用户拍板）**：v10 遗留的「单步同步、HTTP 长连接」问题本轮解决——六步编排参考 `LrtPluginExecutor` 的路子改由 crontab executor 驱动，HTTP 只建行+注册+立即触发，随即返回。
  2. **运行形态**：一条 `sdd://<feature_name>` 调度行，`concurrentable=false`（重叠 tick 由引擎内存态 `runningTasks` 跳过）、`once=false`（由执行器自己停表）；每 tick 读 `sdd_projects.current_stage` 决定下一步，`enable_research=false` 时跳过 research；末步跑完置 `done/completed` 并停表；任一步失败置 `failed` 并停表。
  3. **包循环依赖处理**：`crontab.executor → bridge`（调编排服务）是新增边，而停表/注册要够到 `crontab`，故新增 `SddScheduleBridge` 函数槽由组合根注入——**不能直接 import，否则 `crontab → crontab.executor → bridge → crontab` 成环**。`pkggraph.py` → `SCC size > 1 = NONE`。
  4. **两个刻意取舍**：① `run-stage` **保留同步**（T-23 单步探针要用，异步拿不到即时结果），`run` 才是异步整条流水线；② 建行后 `spawn` 立即触发首 tick，否则要等到下一个分钟边界（cron 为每分钟一跳）。
  5. **已知限制（诚实记录）**：自动推进时后续阶段的 `question` 是在 base question 上追加阶段提示拼出来的，**尚未接入产物落盘**（`long_running_task_artifact`），子 agent 间的上下文交接目前依赖"各自读写 output_dir"，不是框架显式传递。产物落盘完成后应改为从 artifact 或上一步 `sub_agent_invocations.output_json` 取。
  6. **嵌套类型改为顶层 struct**：`SddParams` 初版写在类内，全工程 grep **无类内嵌套类型先例**，不赌编译器支持，改为顶层 `public struct`。

- 2026-09-27 **v12 修订（产物落盘 + 上下文显式交接）**：
  1. **v11 第 5 条限制已解除**：每步跑完由 `SddOrchestrationService.persistArtifact` 落盘 + 登记 `long_running_task_artifact`（append-only）；下一步 question 由框架经 `readStageArtifact` **显式读出上游产物**拼入，不再让子 agent 各自猜 output_dir 里的前序文件名。
  2. **落盘口径**：目录 `specs/{feature_name}/`（runtime 自有，禁落 `.codeartsdoer/specs/`）；显式给了 `output_dir` 用它，否则回落 runtime 工作目录下 specs 子目录。文件名按 COMPOSITION 各步验收标准：`research.md` / `spec.md` / `design.md` / `tasks.md` / `code-summary.md` / `test-report.md`。
  3. **入库字段口径（关键决策）**：实测 `long_running_task_artifact` **仅 11 列、无 usage / stage 列**（psql 查 information_schema 确认）。对齐 LRT `DATA_CONTRACT.yaml`：`usage=deliverable` 是**逻辑概念不入表**（LRT 自身 write_rule 与入库字段列表同样无 usage）；`artifact_type` 取 LRT 枚举 `[code, config, doc, test, report, data, artifact]`；**stage 维度记入 `verification_result` jsonb**（键 stage / feature_name / usage / source），可用 jsonb 取值查询——**不动公共表结构**。
  4. **失败语义**：产物落盘或入库失败**不翻转本步成功**（编排主链路是子 agent 执行，产物登记属留痕），仅告警并让 `artifactPath` 留空，下游据此识别"无上游产物"。
  5. **⚠️ 发现一处实现与规范不符（待裁决，未擅自改）**：`COMPOSITION.yaml` code 步验收明确要求「主 agent 按 SOP 执行，**不派生编码子 agent**」「**本步不写 sub_agent_invocations**」，但当前 `subAgentForStage("code")` 仍派生 `sdd-code-dispatcher`。改动会改变六步语义，故只记录不修改，待用户裁决（另：T-18「cangjie-coder 去子 agent 化」与此同源）。
  6. **当场改掉的自造 bug**：初版用 `content[0..maxChars]` 截断上游产物——仓颉 String 是 UTF-8，**字节切片会截断中文**（同包 `char_delta_splitter.cj:9-17` 有复核结论）。改为 `toRuneArray()` 按 Rune 切 + `String(runeSlice)` 的 `truncateChars`。
  7. **校验**：`pkggraph.py` → `SCC size > 1 = NONE`；全量 `src/` 1107 个 .cj 块注释未闭合 0；剥离注释/字符串后两文件括号差 0。

- 2026-09-27 **v13 修订（code 步改主 agent 直执行：v12 第 5 条裁决落地）**：
  1. **用户拍板**：**不派生写代码子 agent** —— 编码由**主 agent + 各编程语言的 skills + SOP** 完成。理由是"换脑子的才派生，换说明书的用技能"：编码不需要换脑子，需要的是确定的 API 依据与工程内既有范式。此前 v12 记录的规范冲突就此关闭。
  2. **宿主侧落点（`SddOrchestrationService`）**：新增 `HOST_DIRECT_STAGES = ["code"]`；`subAgentForStage("code")` 改为返回**空串**（不再有 `sdd-code-dispatcher`）；`runStage` 按 `isHostDirectStage` 分流到新的 `runHostDirectStage`。
  3. **`runHostDirectStage` 三步**：① `AgentRuntimeBridge.loadFromDatabase(agentId)` 造**主 agent**（`agent_id` 必填，缺失即显式失败，不兜底造 agent）；② 按 `codingSkillChain(language)` 在主 agent 的 `SkillManager` 里找第一个**已挂载**的编程技能（`cangjie`→`cangjie-coder`；`web`→`web-coder`/`fullstack-codegen`/`frontend-dev`；`app`→`app-coder`/`frontend-dev`），全不命中即失败（铁律：不得无依据编码）；③ `agent.chat(AgentRequest(prompt))` 跑一轮，SOP 铁律（先查依据 / 复制+最小适配 / 缺口须标注 / 不编译 / 只改目标工程）与回传契约全部写进 `buildHostDirectPrompt`。
  4. **不写 `sub_agent_invocations`**（该表只记真派生步，与 COMPOSITION 一致）；产物落盘 + 阶段推进与派生路径同口径。
  5. **声明文件下线**：`skills/sdd/agents/sdd-code-dispatcher.md` **已删除**（约定即注册、删文件即下线）；`SKILL.md` 子 agent 表与正文、`prompts/code.md` 抬头、`COMPOSITION.yaml` code 步 input/acceptance 同步更新。psql 实测 `agents` 表 `name LIKE 'sdd-%'` **0 行**，故**无需**写清理 SQL（同步链路只增不删，日后若已落库再补 DELETE）。
  6. **参数链打通**：HTTP `run` / `run-stage` 新增 `agent_id`、`language` → `startPipeline` 写入 crontab `parameters` → `SddParams`（新增两字段）→ `runStage(agentId:, language:)`。executor 顶部 parameters 契约同步注明 code 步必需 `agent_id`。
  7. **校验**：`pkggraph.py` → `SCC size > 1 = NONE`（新增 `bridge → magic.skill` 边不成环）；3 个改动文件块注释深度 0（脚本 `.workbuddy/check_comments.py`）。**未编译**，待人工 `cjpm build`。
  8. **遗留（不本轮解决）**：agents 表尚无 sdd 子 agent 记录（0 行，T-19 同步未生效），五个**派生步**目前会按"未注册"失败——code 步不受此影响（它不查表）。

- 2026-09-28 **v14 修订（T-19 真落库：技能内 bundled 子 agent 未进 agents 表的根因与修复）**：
  1. **现象（用户实测）**：全量重编译 + 重启 runtime + web 验证后，`agents` 表**仍只有 MainAgent 一行**（psql 实测：`MainAgent | MAIN | (空 skill_name) | AGENTS.md`），各技能 `agents/` 子目录下的声明文件一个都没同步进来。
  2. **真因（源码核对，非猜测）**：文件→DB 同步的唯一入口是 `SyncManager.syncAll` → `AgentSyncHandler.detectChanges` → `ChangeDetector.detectAgentChanges` → `collectMdFiles(basePath)`，而 `collectMdFiles` **只收两处**：`<basePath>/AGENTS.md` 与 `<basePath>/agents/` 下的 md。`main.cj:265` 的 `agentBasePath` 默认 `./`（runtime 工作目录），**`skills/<skill>/agents/*.md` 从来不在扫描范围内**。T-19 此前只做到"加载期把名字挂进内存 `SkillManifest.bundledAgents`"（`BundledAgentScanner.scan`），**没有任何落库代码**——design §2.9.6「经本节机制注册后可按名派生」属于未兑现的表述。
  3. **修法（三处，语义统一不改契约）**：① `ChangeDetector.detectAgentChanges` 增加命名参数 `bundledSkillRoots!: Array<String> = []`（老调用点不受影响），文件收集改走新的 `collectAgentDeclarationFiles`；② 新增 `collectBundledAgentMdFiles(skillRoot)`——`Directory.walk` 技能根目录，收 `.md` 且**路径含 `/agents/` 段**者（判定口径与 `AgentSyncHandler.deriveSkillName` 一致，保证 `skill_name` 能由路径反推）；③ `AgentSyncHandler` 构造加 `skillBasePath!: String = ""`，`SyncManager.setupHandlers` 里 `AgentSyncHandler(agentBasePath, skillBasePath)` 把技能目录递下去。
  4. **预期效果**：重启后 `agents` 表新增 **15 行** —— sdd 5（researcher/spec-writer/design-writer/task-planner/tester）+ cangjie-coder 4 + skill-creator 3 + test-generator 3，`skill_name` 分别取各技能名，`agent_type=SUB`，`source_path=skills/<skill>/agents/<name>.md`；此后五个派生步才可能查到子 agent。
  5. **又踩同一颗雷**：注释里写 `skills/*/agents/` 的目录通配形式 —— 块注释内斜杠紧跟星号被词法器识别为**嵌套块注释起始**，`check_comments.py` 立刻报 `UNTERMINATED`（与 v10 同一颗雷）。已改写为文字描述 + 显式提醒。
  6. **校验**：`pkggraph.py` → `SCC size > 1 = NONE`；3 个改动文件块注释深度 0。**未编译**，待人工 `cjpm build`。
  7. **遗留（待裁决，未擅自改）**：① **删除下线未闭环**——`SyncManager.syncAll` 对 `ChangeType.Deleted` 只 `continue` 跳过，删声明文件后库里记录仍会残留（当前库里无残留，因从未同步过）；② `skills/cangjie-coder/agents/` 下 4 个声明（code-editor/code-searcher/code-verifier/doc-consultant）与 v13"不派生写代码子 agent"口径的关系待定（其中 verifier/searcher 偏辅助而非编码，暂不动）；③ DB→文件方向（`syncToFileSystem` / `SyncInterceptor`）既有，本轮未改。

- 2026-09-28 **v15 修订（未完成任务一次性收尾：T-10/T-12/T-17/T-18/T-21/T-22/T-24/T-25 + T-09 闸口 + 删除下线）**：
  1. **T-21 契约校验器（REQ-SDD-012-A）**：新建 `src/tool/sub_agent_contract_verifier.cj`（纯字符串/JSON，无网络无模型调用，≤1s）。规则取 `agents.capabilities` 的 `output_contract`（支持 JSON 对象与 YAML 文本两种落库形态：先 `JsonValue.fromStr`，失败则按 `output_contract` 子串定位 + 一级花括号配平提取）；取不到规则降级"仅非空 + 最小长度"并标 `contract_absent`（可观测，非静默通过）。挂点在 `SubAgentDispatchServiceImpl.dispatch`：**回写 output 之前**校验，不过则携结构化错误**重派 1 次**（`attempt=2`），仍不过转人工闸口并 `success=false`。结论经 `SubAgentInvocationsService.recordVerification` 写 `contract_type`/`verify_passed`/`verify_errors`/`attempt`（新增语义方法，ADR-001）。
  2. **⚠️ 当场修掉一个会让六步全卡死的坑**：五个声明文件的 `output_contract.required_sections` 与模板真实标题**逐字不一致**（如契约"决策风险" vs 模板"关键设计决策与风险"、契约"执行结果" vs 模板"测试执行与结果"、契约"4. DFX 约束" vs 模板"4. DFX约束"）。校验是子串包含判断，不一致会导致**每次派单都判失败 → 自动重派 → 仍失败 → 卡在闸口**。已按模板逐字校正（researcher 3 处、spec 1 处、tester 1 处）。**新增规则时同样必须逐字核对模板标题。**
  3. **T-22 成本账本（REQ-SDD-012-B）**：DDL 侧（7 个成本/校验列 + `v_sub_agent_stage_cost` 视图）**已随 T-13 脚本落地**（本次核对确认，无需新脚本）；代码侧新增 `SubAgentInvocationsService.recordCost` 语义方法，派单收尾调用。现状：`AgentAsTool.invoke` 的 `ToolResponse` 不暴露 `ChatUsage`，取不到 usage → **一律记 0 并在 `error_message` 追加 `token_missing`，禁止字符数折算**（代码注释写明，待 ToolResponse 暴露 usage 后替换即可）。
  4. **T-12 进度可观测**：新增 `src/app/services/bridge/sdd_event_bridge.cj`（`sdd_step_start`/`sdd_step_complete`/`sdd_step_failed`/`sdd_progress`/`sdd_subagent_spawn`/`sdd_subagent_done`/`sdd_goal_achieved`/`sdd_review_required`），复用 WS 广播 + SSE 双通道；**SSE 单行转义**（`\r`/`\n` 转义）+ **无 session 早退且不打日志**（cron 场景常态，打日志会被误判为故障）。注入点与 `LrtEventBridge.attachSSEManager` 同一处（`WebMCPController`）。`session_id`/`notify_agent_id` 沿 HTTP → crontab parameters → `SddParams` → `runStage` 全链透传。
  5. **T-09 收尾：五闸口落地**：`SddOrchestrationService.applyGateDecision`（confirm/revise/abandon）+ `gateForStage`；新增 `POST /api/v1/uctoo/sdd/review`（`SddOrchestrationController.review` + Route 注册 + `20260928_sdd_gate_review_permission.sql` RBAC 登记，漏登记会全 403）。语义：`auto=false` 时每步跑完置 `awaiting_review` + 推 `sdd_review_required` + 停表；confirm → 恢复调度（库置 1 + 重新注册引擎 + 立即触发，三步缺一不可）；revise → `current_stage` 退回上一步使 `nextStage` 重算本步 + `bumpRound` + **新 task_id**（不串味），产物**不覆盖**（盘上归档 `.prev`、库里 append-only）；abandon → 置 `abandoned` + 写 `agent_approvals` 留痕。
  6. **T-25 三层闭环**：后端两表 Route 的 add/edit/del/empty-recycle-bin 四行注释（`AutoRouteConfig` 本就未注册，此处双保险）；前端 `index.vue` 摘除 `add-*` 挂载、表格写按钮的 `v-permission` 改为不存在的权限码（只读"查看"保留）；菜单侧实测 `database.uctoo.sdd_projects` / `sub_agent_invocations` 两个节点**无任何角色授权**（`role_id` 为 NULL），普通角色菜单不出现。
  7. **T-10**：新建 `skills/web-coder/` 与 `skills/app-coder/`（纯技能形态，**无 `agents/` 目录**），与 cangjie-coder 同构的"确定性优先"四步工作流 + 官方文档技能引用 + 回传契约；`prompts/code.md` 路由表状态由"待建"改"已建"。
  8. **T-18**：删除 `skills/cangjie-coder/agents/`（4 个声明文件）；`SKILL.md` frontmatter 去掉 `agents:` 键、description 改纯技能形态（version 3.0.0 → 4.0.0），正文"编排器模式"改"四步工作流（纯技能形态）"并保留原四角色职责对照表；DB 清理 SQL 早已在 `sdd_subagent_20260927.sql` 第 5 段（软删）。
  9. **T-17**：`docs/agents/agent-declaration-spec.md` 修订——§3.1 `type` → **`agent_type`** 并加键名红线；§3.2 补 `parent_id`/`skill_name`/`capabilities`/`model_capabilities`/`capabilities_skill`/`identity_status`/`discoverable`；**§7.1 重写**（原 built-in/user/project/policy 四级目录在代码里不存在，是早期设计残留）；**新增 §9「技能内 agents 目录约定」**（形态/必需键/自动探测与删除下线/输出契约配法与逐字一致警告/建不建 agents 的判别准则）。
  10. **删除下线闭环（v14 遗留①）**：`AgentSyncHandler.offlineBySourcePath`（按 `source_path` 精确定位 + **软删**置 `deleted_at`，不做物理删除）；`SyncManager.syncAll` 的 `Deleted` 分支改调它（用 `as` 安全向下转型取 `AgentSyncHandler`，不给接口加方法）。仅 agent 生效，其他实体维持跳过。
  11. **T-24**：新建 `skills/sdd/OPS.md`（部署/编译/登记/六步运行/六类症状排障表 + **design §2.6 十三条防回退约束逐条对照** + 变更连带检查表）；`README.md` 由 plugingen 通用模板覆盖为 SDD 专属。
  12. **校验**：`pkggraph.py` → `SCC size > 1 = NONE`；14 个改动 .cj 文件块注释深度 0（`check_comments.py`）。**未编译**，待人工 `cjpm build`（宿主 + `skills/sdd` 两个工程）。
  13. **T-23 转为人工执行**，验证清单见下。

---

### T-23 联调验证清单（人工执行，按顺序打勾）

前置：`cjpm build`（宿主）→ 重启 runtime → `psql` 执行三条增量 SQL（若未执行）。

| # | 步骤 | 预期 |
|---|---|---|
| 1 | `SELECT name, agent_type, skill_name, source_path FROM agents WHERE deleted_at IS NULL ORDER BY skill_name, name;` | sdd 5 行 + 其他技能 bundled 子 agent；`skill_name` 非空 |
| 2 | 新建 `skills/sdd/agents/probe.md`（含 `agent_type: sub`）→ 重启或 `POST /api/v1/uctoo/sync/all` → 再查 ① | 多出 probe 行，`skill_name='sdd'` |
| 3 | 删除 probe.md → 重启/同步 → 再查 ① | probe 行 `deleted_at` 非空（软删下线） |
| 4 | `POST /api/v1/uctoo/sdd/start` → `/run`（带 `agent_id`、`auto:false`） | 返回 `crontab_id`，阶段文档落 `specs/{feature_name}/` |
| 5 | `GET /status/:featureName` | `status=awaiting_review`，前端收到 `sdd_review_required` 事件 |
| 6 | `POST /review` `{decision:"confirm", crontab_id}` | 恢复调度并推进下一步 |
| 7 | `POST /review` `{decision:"revise", task_id:"<新uuid>"}` | `round+1`、`current_stage` 退回上一阶段、上一版产物出现 `*.prev` |
| 8 | 查 `sub_agent_invocations` | `contract_type`/`verify_passed`/`attempt` 非 NULL；`prompt_tokens` 等为 0 且 `error_message` 含 `token_missing`（待 ToolResponse 暴露 usage 后应有真实值） |
| 9 | 故意让子 agent 回传缺章节文档 | `verify_passed=false`、`attempt=2`、**恰好两次派单**（无第三次）后转闸口 |
| 10 | `SELECT * FROM v_sub_agent_stage_cost;` | 按 `skill_name`+`stage` 给出 invocations/retries/avg_tokens/avg_duration_ms/verify_fail_rate_pct |
| 11 | `POST /review` `{decision:"abandon"}` | `sdd_projects.status='abandoned'` + `agent_approvals` 有 `sdd-gate-abandon` 留痕 |
| 12 | 临时删除某子 agent 声明文件并同步下线 → 再跑该步 | **立即失败并提示**，不得静默由主 agent 自写 |

---

> 配套：本目录另提供 `research.md`（§九 plugingen / §十 子 agent 机制 / §十一 数据库）、`spec.md`（v4）、`design.md`（v4）、**`adr-001-storage-layer.md`（v2，两张新表存储层形态决策）**、`research-template.md`、`sdd-methodology-baseline.md`、`tasks-template.md`、`test-report-template.md`。
> 人工执行记录：`apps/agentskills-runtime/logs/crud.md`（plugingen / loaddbinfo / crudgen / crudweb / cjpm build）。
