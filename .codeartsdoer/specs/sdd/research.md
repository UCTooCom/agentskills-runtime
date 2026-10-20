# 用户原始需求

在 `apps/agentskills-runtime/.codeartsdoer/specs` 目录下，我们已经通过 `goai2026`（AI 驱动开发框架多 agent 协作基础设施）、`plugin-system`（技能融合插件工程，三轨架构 + cordis-cj L3 集成）、`long-running-task`（长程任务技能，真实落地了 goai2026 中的很多基础设施）等多个子工程，沉淀了相当完整的多 agent 协作与插件融合底座。

现在要开发一个 **SDD（Specification-Driven Development，规范驱动开发）技能融合插件**，把我们在 `.codeartsdoer/specs` 中一直使用的「规范驱动开发流程」用技能插件的方式真实落地。

触发条件：当大模型分析用户提出的任务是一个**软件开发类型的任务**时，即可调用本 SDD 技能融合插件推进开发。

SDD 流程包含以下步骤：

1. **（可选）研究步骤**：主 agent 调用需求撰写子 agent，输出类似 `long-running-task/research.md` 的研究文档；研究是开放自由的工作流，暂无标准模板，必要时可参考业界最佳实践总结一个研究模板。
2. **（必选）需求规格说明书**：主 agent 调用设计撰写子 agent，输出类似 `long-running-task/spec.md` 的需求文档，可参考 `managing-sdd-spec-markdown` 模板。
3. **（必选）设计说明书**：主 agent 调用设计撰写子 agent，输出类似 `long-running-task/design.md` 的设计文档，可参考 `managing-sdd-design-markdown` 模板。
4. **（必选）任务规划**：主 agent 调用任务规划子 agent，输出类似 `long-running-task/tasks.md` 的任务规划文档；暂无标准模板，必要时可总结一个任务规划模板。
5. **（必选）编码实现**：主 agent 调用专用编程语言能力（如 `cangjie-coder` 编写仓颉、`web-coder` 编写 HTML/CSS/TypeScript、`app-coder` 编写鸿蒙/安卓/苹果原生）。
   > **v3 形态修正（见 §十二）**：原文表述的"编程语言**子 agent**"已在第五次研究中改为"**编程 / 领域技能**"——不派生编码子 agent。此处保留原始需求表述以存史。
6. **（必选）测试验收**：主 agent 调用测试验收子 agent，产出测试与验收报告（含产出物与 SDD 文档的一致性、完成度、缺陷、完善意见）；暂无标准模板，必要时可总结。
7. **（贯穿全程）人在回路**：每个步骤完成后，均可接收用户对上一步产物的审核与反馈，迭代上一回合产物或进入下一步。
8. 在 `specs` 目录创建规范驱动开发技能插件的 `sdd` 目录，**先从研究步骤开始生成工程文档**；尽量复用 agentskills-runtime 已有基础设施，遵循已有开发规范，可参考 `uctoo-dev-manual` 与 `uctoo-doc` 技能。

---

# 研究结果

## 一、SDD 融合插件的定位与现状

### 1.1 与既有 `sdd-skills` 工程的关系（先认清历史）

`.codeartsdoer/specs/sdd-skills/`（2026-07-26）是 SDD 的早期探索，产出 `spec.md / design.md / tasks.md` 三份文档，定义了 `REQ-SDD-001~006`（SpecAgent / DesignAgent / TaskAgent / CodeAgent / TestAgent / sdd-flow 编排），并把流程映射到 `AgentTeams` 的 Manager→TeamLeader→Worker 分层。

该工程存在两个局限，正是本次需要升级的：

- **只停留在"技能桩 + 编排声明"**：`skills/sdd-spec|sdd-design|sdd-task|sdd-test|sdd-flow` 五个技能目前仍是无实现细节的 `SKILL.md` 桩（各自仅 ~2KB，模板直接内联在 SKILL.md 里），`sdd-flow/COMPOSITION.yaml` 也是一份未接宿主组合引擎的"理想编排"，没有真正跑起来。
- **没有融合进多 agent 基础设施**：当时 `long-running-task` 尚未落地，`goai2026` 的多 agent 协作底座、`plugin-system` 的三轨插件机制都还没成形，所以早期 `sdd-skills` 只是把 SDD 流程画成了 AgentTeams 的分层示意图，没有复用 L3 进程隔离、组合执行引擎、数据契约、人在回路决策点等后来才成熟的设施。

> **结论**：本次 `sdd` 工程不是另起炉灶，而是把早期 `sdd-skills` 的"意图"用 `long-running-task` 已经验证过的"融合插件"形态真实落地——即一个 **L3 进程隔离轨插件**，内部用 `COMPOSITION.yaml` 编排研究→需求→设计→任务→编码→测试六步，并在每步之间挂人在回路决策点。早期 `sdd-skills` 的五份文档可作为需求基线保留参考，但工程实现以本 `sdd` 目录为准。

### 1.2 SDD 与 long-running-task 的本质区别（决定不能简单复用其代码）

| 维度 | long-running-task | SDD 融合插件 |
|------|-------------------|--------------|
| 目标 | 接收高层目标，AI **自主**规划执行到天级，人只评审交付 | 软件开发任务，每一步都需**人审核/反馈**才能进入下一步 |
| 人在回路节奏 | 终点评审（`review` 决策点）+ 中途干预（pause/resume/cancel） | **每步一闸**，研究/需求/设计/任务/编码/测试后都可有审核-迭代闭环 |
| 产物形态 | 任意目标产物（报告/文件/数据） | 强约束的文档链：`research.md→spec.md→design.md→tasks.md→code→test-report` |
| 子 agent 角色 | 通用规划/执行/扩展/验核 | 领域固定的 spec/design/task/code/test 撰写 agent |
| 触发 | 长程任务触发词 / `/lrt` 前缀 | 识别到"软件开发类任务"时启用 |

两者**共享同一套宿主底座**（插件系统、组合引擎、调度、AgentTeams、host.db 服务代理、决策点框架），但 SDD 的编排语义更强调"文档契约链 + 步步闸口"，这是 `long-running-task` 没有的。因此工程上应**复用底座与模式、不复用业务代码**，SDD 插件写成独立的 L3 进程插件。

## 二、已有可复用基础设施盘点

> 路径前缀统一为 `apps/agentskills-runtime/`。仅列出与 SDD 融合插件强相关的部分。

### 2.1 插件系统（三轨架构 + cordis-cj L3 集成）—— SDD 插件的宿主形态直接套用

- `skills/long-running-task/plugin.yaml`：L3 进程隔离轨插件的**自完备声明样板**（`mode: process`、`command` 相对 cwd 的路径约定、不写 `protocol` 字段、config 段、env、tableWhitelist、routes）。SDD 插件可直接照抄其骨架，仅改 `name`/`command`/`routes`/`tableWhitelist`。
- `src/plugin/cordis_host_manager.cj` / `cordis_host_services.cj`：L3 宿主管理器与宿主侧服务代理（`host.db` / `host.log` / `host.cache`），SDD 插件用它读写数据库、落日志、取缓存，无需自带 DB 连接。
- `src/plugin/external_plugin_route_gateway.cj`、`plugin_route_scanner.cj`、`plugin_config.cj`、`plugin_sync_bridge.cj`：插件路由网关、扫描、配置、状态库同步。
- `src/plugin/tools/plugingen` / `pluginuninstall`：表驱动 / 空白骨架 / `--mode process` 三种方式生成 L3 插件。SDD 插件可先用 `plugingen --name sdd --blank --mode process` 生成骨架，再填业务逻辑。
- `.codeartsdoer/skills/` 与 `skills/` 的"一切皆技能"去中心化发现机制（`PluginDiscoveryService` + `plugin.yaml` 自完备）已就位。

### 2.2 组合执行引擎（COMPOSITION.yaml + 运行器）—— SDD 六步编排的载体

- `skills/long-running-task/COMPOSITION.yaml`：文件态组合格式（**非** DB 存储态 schema），由 `src/skill/lrt_composition_runner.cj`（`LrtCompositionRunner`）解析。SDD 插件应直接复用这一文件态格式与运行器，把它当成"融合插件内部的步骤编排 DSL"。
- 该格式已支持的要素，恰好覆盖 SDD 所需：`step_type: script|plugin|output`、`depends_on`、`input` 变量插值、`condition`、`acceptance_criteria`、`degradation_chain`、`uses_tables`。
- `DAG` 能力：`src/.../dag_scheduler.cj`（DagPlanStatus / DagStepStatus / 验证器 / 重试 / 上下文传递 / 增量推送）、`dag_team_orchestrator.cj`、`dag_config.cj` / `yaml_dag_config_parser.cj`、条件评估 `condition_evaluator.cj`、结果聚合 `result_aggregator.cj`。可作为 SDD 插件内部"一步内多子任务并行/串行"的底层引擎。

### 2.3 Agent 执行与团队（多 agent 协作底座）—— SDD 子 agent 的运行环境

- `agent_executor_manager.cj` 及多种执行器（`plan_react` / `react` / `tool_loop` / `naive` / `dsl`）。
- `team_manager.cj` / `team_config.cj` / `team_messenger.cj` / `team_message.cj`，多种团队模式（auto_discuss_group / leader_group / linear_group / manager_group 等）。
- SDD 的 spec/design/task/code/test 子 agent 天然对应"Manager→TeamLeader→Worker"分层：**spec（Manager 级，定义 WHAT）→ design/task（TeamLeader 级，定义 HOW 与拆解）→ code/test（Worker 级，执行）**。早期 `sdd-skills/design.md` 画的 PlantUML 分层仍然成立，只是现在有了真实的执行器与团队运行时去承载它。

### 2.4 人在回路决策点框架 —— SDD"步步闸口"的直接来源

- `long-running-task/SKILL.md` 的 `decision-points` frontmatter + `web_request_approval` 调用契约（`skillName` + `decisionPointId` + options/default/recommended）。SDD 的"每步审核-反馈-迭代"可以**原样复用**这一机制，为 research/spec/design/task/code/test 每一步定义一个 `review` 类决策点：用户可选"确认通过 / 要求修改 / 放弃"，要求修改时回退到上一步重做（类似 long-running-task 的 `review→improve→replan`）。
- `agent_approvals` 表（已在 long-running-task `tableWhitelist` 中）记录每一次审核决策，天然提供审计留痕。

### 2.5 现有 SDD 子技能与模板 —— SDD 插件要编排的领域技能

- `skills/sdd-spec` / `sdd-design` / `sdd-task` / `sdd-test`：四个角色桩，各自内联了 Markdown 模板（EARS 格式 spec、design 模板、tasks 模板）。这些模板内容与 `.codeartsdoer/skills/managing-sdd-spec-markdown`（`spec_template.md` + `ears-format.md`）、`managing-sdd-design-markdown`（`design_template.md` + `design-principles.md`）一致。**SDD 插件不必重新发明模板，直接复用这两个 `managing-*` 目录的模板作为子 agent 的写入规范即可。**
- `skills/sdd-flow`：组合编排桩（仅 SKILL.md + COMPOSITION.yaml 理想稿）。本次 `sdd` 工程会把它从"理想稿"升级为"真实融合插件编排"。

### 2.6 编码与质量闸门子技能 —— SDD 编码步的执行者

- `skills/cangjie-coder`：仓颉代码编写四步工作流（查阅 CangjieSkills → 检索代码片段 → 编辑适配 → 写入文件），是编码步"仓颉"分支的执行者。
- `skills/code-gen-verifier`：代码生成质量闸门（long-running-task 的 `extend-capability` 步骤已要求"任何代码生成类缺口必须挂 code-gen-verifier"）。SDD 编码步产出必须经此闸门。
- **缺口**：`web-coder`（HTML/CSS/TypeScript 前端栈）、`app-coder`（鸿蒙/安卓/苹果原生）目前**不存在**。现有近似能力是 `fullstack-codegen`（全栈代码生成）、`frontend-dev`（前端开发，位于用户级 `~/.workbuddy/skills`）、`opentiny-next-app-integration`。需要在 SDD 插件落地的"编码实现"步补齐这两个专用子 agent（或把 web/app 编码路由到 `fullstack-codegen` / `frontend-dev` 并补一套 SKILL.md 化的调用契约）。

### 2.7 数据契约与产物落库模式 —— SDD 文档链在跨步传递的规范

- `long-running-task/DATA_CONTRACT.yaml`：跨步数据契约样板（把每步输入/输出结构化、参数化，摊平给后续脚本/插件步骤）。SDD 的 `research.md→spec.md→design.md→tasks.md→code→report` 链路本质是**强契约的文档传递**，照搬 DATA_CONTRACT 思路即可，只是契约内容从"任务树 JSON"变成"各阶段 Markdown 路径 + 结构化元信息（版本/状态/编号/验收清单）"。
- 产物落库：`long_running_task_artifact` 表（usage=deliverable 标记交付物）、`agent_tasks`（任务树/步骤状态）、`agent_contexts`（检查点）、`agent_approvals`（审核）。**优先复用这四张表**，避免为 SDD 新建数据库表——符合 long-running-task 研究阶段定下的原则："如果可以利用当前已有基础设施只需要增加配置数据或配置文件就可以实现的功能，优先复用当前基础设施"。

### 2.8 进度/可观测模式 —— SDD 长流程的用户可见性

- `long-running-task/SKILL.md` 的进度落盘（`output/checkpoint/progress.md`）、`notify-progress` 脚本、`LrtEventEmitter` → SSE/WS 事件通道（`lrt_step_start/progress_update/step_complete/goal_achieved`）。SDD 是多步长流程，同样需要"每步完成即推进度 + 落盘"，可直接复用 SSE/WS 通道与 event 命名约定，只把 `session_id`/trace 语义对齐到 SDD 的阶段。

## 三、能力缺口分析（已有 vs 待建）

| 缺口 | 现状 | 待建（本 sdd 工程范围） | 复用/新建 |
|------|------|------------------------|-----------|
| SDD 融合插件骨架 | 仅有 `sdd-flow` 理想稿 | L3 进程插件 `skills/sdd/`（plugin.yaml + COMPOSITION.yaml + src + prompts + scripts） | 新建（套用 long-running-task 骨架） |
| 研究文档模板 | 无标准模板 | 总结 `research-template.md`（本目录已产出） | 新建（模板） |
| 任务规划模板 | 无标准模板 | 后续 spec/design 阶段总结 `tasks-template.md` | 待建 |
| 测试验收模板 | 无标准模板 | 后续阶段总结 `test-report-template.md` | 待建 |
| web-coder / app-coder 子 agent | 不存在 | 编码步补齐两个专用语言子 agent | 新建（或路由到 fullstack-codegen/frontend-dev） |
| 六步组合编排 + 步步闸口 | 仅有理想稿 | 真实 COMPOSITION.yaml（research→spec→design→task→code→test，每步挂 review 决策点） | 新建（复用组合引擎） |
| 文档链数据契约 | DATA_CONTRACT 是长程任务版 | SDD 版 DATA_CONTRACT（阶段文档路径 + 元信息） | 新建（复用模式） |
| 子 agent 真实实现 | 四个 sdd-* 是桩 | 把 sdd-spec/sdd-design/sdd-task/sdd-test 从桩升级为可编排的领域 agent（写入规范来自 managing-* 模板） | 升级 |
| 人在回路审核闭环 | long-running-task 有终点评审 | 每步 review 决策点 + "确认/修改/放弃" + 修改回退上一步 | 复用机制 + 配置 |

## 四、推荐工程方案

### 4.1 总体形态

**SDD 融合插件 = 一个独立的 L3 进程隔离轨插件 `skills/sdd/`**，与 `long-running-task` 平级，复用同一套宿主底座（插件系统、组合引擎、DAG、AgentTeams、host.db 服务代理、决策点框架、SSE/WS 进度通道），但内部业务编排是 SDD 专属的"文档契约链 + 步步闸口"。

### 4.2 六步组合编排（COMPOSITION.yaml 草图，供后续 design 细化）

```
研究(可选,research) → 需求(spec) → 设计(design) → 任务(task) → 编码(code) → 测试(test)
        │                                                                         │
        └──────────────── 每步完成后挂 review 决策点（确认/修改/放弃）──────────────┘
                             修改 → 回退到上一步重做；放弃 → 终止；确认 → 进入下一步
```

- `research`：复用 `sdd-research` 子 agent（或直接由主 agent 产出 `research.md`），`condition` 为"用户选择启用研究步骤"，可选跳过。
- `spec / design / task`：`step_type: plugin`（路由到 SDD 插件内部 agent 执行入口），分别调用 sdd-spec / sdd-design / sdd-task 子 agent，落盘 `spec.md / design.md / tasks.md`。
- `code`：`step_type: plugin`，依据 `tasks.md` 的语言标签（`cangjie` / `web` / `app`）分派到 `cangjie-coder` / `web-coder` / `app-coder`，产出代码后经 `code-gen-verifier` 闸门。
- `test`：`step_type: plugin`，调用 test-agent，产出测试验收报告（一致性/完成度/缺陷/完善意见）。
- 每步之间：`review` 决策点（复用 long-running-task 的 `web_request_approval` 契约）。

### 4.3 复用决策（严守"优先复用"原则）

- **复用长程任务已建 DB 表**：`agent_tasks`（SDD 阶段状态树）、`long_running_task_artifact`（各阶段文档作为 deliverable 入库）、`agent_contexts`（检查点）、`agent_approvals`（审核留痕）。**优先复用既有表**，仅在 `tableWhitelist` 中声明复用（注：早期表述为"不新建数据库表"；2026-10-14 修订细化为「复用优先、确有必要时允许新建表/列」，见 spec §6.7 / 铁律 9）。
- **复用组合引擎与 DAG**：SDD 插件内部的六步编排直接走 `COMPOSITION.yaml` + `LrtCompositionRunner` 同款文件态格式；一步内多文件/多子任务并行走 `dag_scheduler`。
- **复用模板**：四个子 agent 的写入规范直接引用 `.codeartsdoer/skills/managing-sdd-spec-markdown` 与 `managing-sdd-design-markdown` 的模板，不重写。
- **复用人在回路框架**：`decision-points` + `web_request_approval` 契约原样套用。
- **复用进度通道**：SSE/WS `lrt_*` 事件命名约定对齐到 SDD 阶段（或新增 `sdd_step_start/step_complete`）。

### 4.4 需新建的最小集合

1. `skills/sdd/`（L3 进程插件骨架：plugin.yaml 仿 long-running-task、COMPOSITION.yaml、src 入口、prompts、scripts）。
2. `skills/sdd-research`（或并入 sdd 主插件的研究步）的产出规范 + 本目录 `research-template.md`。
3. `skills/web-coder`、`skills/app-coder`（编码步两个缺失的语言子 agent），或明确路由到 `fullstack-codegen` / `frontend-dev` 的调用契约。
4. 把 `sdd-spec/sdd-design/sdd-task/sdd-test` 从桩升级为可编排领域 agent（写入规范绑定 managing-* 模板）。
5. `tasks-template.md`、`test-report-template.md`（后续阶段补充）。

## 五、关键设计决策与风险

1. **独立 L3 插件 vs 复用 long-running-task 代码**：决策为**独立插件、复用底座**。原因见 1.2——SDD 的"文档契约链 + 步步闸口"语义与长程任务的"自主执行"语义不同，硬塞进 long-running-task 会污染其状态机；独立插件又能完整复用宿主底座，性价比最高。
2. **研究步可跳过**：SDD 流程中研究是可选步，COMPOSITION 中用 `condition` 控制（参考 long-running-task `extend-capability` 的 condition 下沉到脚本内部的教训，避免"恒跳过"——研究步的 condition 应挂在"用户在入口明确选择"这一可判定信号上，而非挂在"研究文档是否存在"上）。
3. **复用优先，确有必要时允许新建表/列（2026-10-14 修订）**：默认严守 long-running-task 研究定下的"优先复用"原则，SDD 全程优先复用既有四张表、仅通过 `tableWhitelist` 声明；当且仅当复用明显不成立时才新建表/列，并在 design 写明复用不成立的理由（详见 spec §6.7 / 铁律 9），DB 结构变更后一律走 `loaddbinfo` → `crudgen`/`plugingen` → `crudweb` 确定性生成。
4. **人在回路是 SDD 的核心而非附加**：与 long-running-task（终点评审）不同，SDD 每步都要闸口，需在 COMPOSITION 与决策点配置上把"修改→回退上一步"做成一等能力，否则会退化成"一次性自动生成四份文档"而失去 SDD 价值。
5. **AI 编译约束**：本工程只做代码分析与文档产出，不运行 `cjpm build`；仓颉相关代码如需验证，交由人工在独立 cmd 环境编译并回传结果（与项目既有约定一致）。

## 六、后续步骤指引（交接给 spec / design / tasks）

- **下一步（需求规格 `spec.md`）**：基于本研究的"推荐工程方案 + 能力缺口表 + 复用决策"，撰写 SDD 融合插件的正式需求规格，重点固化 REQ：插件形态、六步编排契约、步步闸口决策点、四张复用表、子 agent 角色与模板绑定、web/app-coder 新建决策。
- **再下一步（设计 `design.md`）**：细化 `skills/sdd/` 的目录结构、`COMPOSITION.yaml` 终稿、`DATA_CONTRACT` 的 SDD 版字段、子 agent 与宿主服务代理的调用关系、进度/审核落库路径。
- **任务规划（`tasks.md`）**：拆解为"骨架生成 → 四子 agent 升级 → web/app-coder 新建 → COMPOSITION 六步编排 → 决策点配置 → 模板补齐（tasks/test-report）→ 联调验证"的可执行任务清单。

---

## 七、二次研究（2026-09-26）：CodeArts Agent SDD 方法论溯源与模板反演

### 7.1 动机
上一轮（§1–§6）把 `apps/.../.codeartsdoer/skills/managing-sdd-*` 当成 SDD 模板来源，但用户指出它们更像是**另一款 AI 开发工具 CodeArts Agent 早期遗留下来的明文技能旧版本**，且 long-running-task 的 spec/design/tasks 实为 CodeArts Agent 生成、并被认可"这套 SDD 文档不错"。本轮回三个目录溯源，目标是定位**最新版明文方法论**直接复用，缺口部分再从本仓库既有生成物反演。

### 7.2 关键发现：最新明文方法论就在已安装的 CodeArts Agent 产品内
在 `D:\Program Files\CodeArts Agent\resources\app\extensions\vscode-codebot\skills\` 下找到完整 SDD 方法论（用户级缓存副本在 `C:\Users\patrick\.codeartsdoer\cache\system\skills\`）：

| 技能（明文） | 文件 | 作用 |
|---|---|---|
| `creating-sdd-directory` | SKILL.md | SDD 引导：建 `.codeartsdoer/specs/{feature_name}/`，feature_name ≤10 字符、小写+数字+下划线 |
| `managing-spec-document` | SKILL.md + `spec_template.md` + `ears-format.md` | spec.md 写入规范（"做什么"），6 节组件定位模板 + EARS 验收语法 |
| `managing-design-document` | SKILL.md + `design_template.md` | design.md 写入规范（"怎么做"），**仅 3 节骨架**（实现模型/接口设计/数据模型） |
| `managing-tasks-document` | SKILL.md | tasks.md 写入流程（须 spec+design 存在后生成），**无模板** |
| `prd` | SKILL.md | 独立 PRD 生成器（10 节：背景/目标价值/术语/范围/非目标/功能需求/关键流程/风险依赖/验收/待决），输出到 `output/prd-*.md` |

**结论：方法论明文可直接复用，不必纯手工反演。** 但产品自带模板有三类缺口：design 仅 3 节骨架偏薄、tasks 无模板、research/test 完全没有。

### 7.3 版本溯源（旧明文 vs 产品最新）
- `apps/.../.codeartsdoer/skills/managing-sdd-*` 是**早期明文技能旧版**，已被产品重命名为 `managing-spec/design-document`：
  - **spec 模板内容两者完全一致**（均为 6 节组件定位，含 DFX、领域术语、核心能力、数据约束 + EARS）。
  - **design 模板反而 legacy 更完整**：legacy `managing-sdd-design-markdown/design_template.md` 是 10 节通用设计模板（概述/架构/详细设计/数据/API/接口/安全/性能/部署/附录），而产品当前的 `managing-design-document/design_template.md` 只剩 3 节骨架——**design 应优先采用 legacy 10 节版**。
- 仓库实际生成的 spec.md 还有第二种更常见的风格（见 7.4），说明 CodeArts Agent 历史上"特征/需求型"默认模板与组件型 6 节并存。

### 7.4 反向工程：从 52 份 spec / 47 份 design / 48 份 tasks 统计出的 house style
（grep 全部 `specs/*/{spec,design,tasks}.md` 的 H1/H2 词频）

- **spec.md 两种主流风格并存**
  - Style A 组件定位 6 节（约 13 份，= 产品 `spec_template.md`；long-running-task 采用且被用户认可）：`组件定位→领域术语→角色与边界→DFX约束→核心能力→数据约束`。
  - Style B 特征/需求型（约 23 份，更常见）：`项目背景→核心问题→功能需求→验收标准`（常附 非功能需求/依赖/数据模型/文档信息）。
- **design.md 主导结构**
  - long-running-task 两段式最成体系：`一、需求与存量功能关系分析（已实现/需扩展对比表）→ 二、增量设计方案`；模板式（实现模型/接口设计/数据模型）次之。
- **tasks.md 主导结构**
  - `开发规范`（27）→ `任务总览`（17）→ `任务依赖关系图`（8）→ `需求覆盖追踪/矩阵`（4）→ `验收检查清单`（2），常带多轮修订记录段。

### 7.5 SDD 插件模板基线决策（各步采用什么、来源哪）
| SDD 步骤 | 采用模板 | 来源 | 说明 |
|---|---|---|---|
| 研究（可选） | `research-template.md`（本目录） | 自研（long-running-task/research.md + PRD 10 节可选） | 产品无 research 模板 |
| 需求规格（必选） | 6 节组件定位模板 | 产品 `managing-spec-document/spec_template.md`（= legacy managing-sdd-spec-markdown） | Style B 作为特征型项目可选 |
| 设计 | 10 节通用设计模板 + 两段式首章 | legacy `managing-sdd-design-markdown/design_template.md` + long-running-task 范式 | 弃用产品 3 节骨架（过薄） |
| 任务规划 | 反演 house style | 新建 `tasks-template.md`（缺口） | 开发规范/总览/依赖图/需求覆盖/验收清单 |
| 编码 | 领域子 agent | cangjie-coder / 路由 fullstack-codegen·frontend-dev；web-coder·app-coder 待建 | — |
| 测试验收 | 反演 house style | 新建 `test-report-template.md`（缺口） | 一致性/完成度/缺陷/完善意见 |

### 7.6 对下一步的影响
- `managing-sdd-*` 旧明文**仍可作为 SDD 插件的写入规范来源**（spec 直接用、design 用 legacy 10 节），但应明确标注它们是 CodeArts Agent 演进链条上的"旧明文快照"；新插件以产品最新 6 节 spec 为准、design 取 legacy 10 节。
- 缺口模板（tasks / test-report / 强化版 design）将在后续 `design.md` 之后随 `tasks.md` 一并补齐，落地到 `skills/sdd-*` 的 prompts 与 `specs/sdd/` 模板库（见 `sdd-methodology-baseline.md`）。

---

## 八、三次研究（2026-09-26）：sdd-skills 子工程复核

### 8.1 背景与结论

用户指出 `specs/sdd-skills/` 是 `goai2026` 早期（2026-07-26）分解出的子工程，大概率未落地。本轮通读其 `spec.md / design.md / tasks.md` 三文档，目的是挖出可参考点、并明确与当前 `specs/sdd/` 工程的差异与取舍。

**结论：sdd-skills 是"意图原型"，当前 `specs/sdd/` 工程是其严格超集；仅少量可借鉴，多数须以当前 sdd 为准覆盖。**

### 8.2 sdd-skills 三文档要点

- **spec.md（71 行，Style B）**：采用「项目背景 → 核心问题 → 功能需求 → 验收标准」四段式（= 研究 §7.4 的 Style B，约 23 份文档使用的更常见风格）。定义 `REQ-SDD-001~006` = SpecAgent(Manager) / DesignAgent(TeamLeader) / TaskAgent(TeamLeader) / CodeAgent(Worker，**复用 cangjie-coder**) / TestAgent(Worker) / sdd-flow 编排。**无研究步、无人在回路闸口**。
- **design.md（111 行，两段式）**：首章「需求与存量功能关系分析」（已实现 / 需扩展对比表）与 `long-running-task` 同源范式；§2.2 给出一份 COMPOSITION.yaml **理想稿**（`composition:` 根 + `skill:` / `agent_type:` / `output:` + `${step.output.field}` 插值）；§2.3 明确"**本工程不涉及数据库表变更**"。
- **tasks.md（112 行）**：「开发规范」置顶 + `SDD-T001~T006` 任务表（`T001~T005` ✅已完成 = 四个 `sdd-*` 桩 + `sdd-flow` 理想稿；`T006` AgentTeams 集成 ⏳未完成 = 印证未落地）；逐任务含子任务 + 验收标准。

### 8.3 可借鉴点（建议纳入当前 sdd）

1. **Style B spec 是合法替代模板**：sdd-skills/spec.md 正是四段式 Style B 的 concrete 样本，印证研究 §7.5 的判断——特征 / 需求型项目可用 Style B 替代 6 节组件定位。当前 `sdd/spec.md` 用 Style A，二者并存合法。
2. **AgentTeams 角色映射**：Spec=Manager（定义 WHAT）、Design/Task=TeamLeader（定义 HOW 与拆解）、Code/Test=Worker（执行）——清晰可复用，已在研究 §2.3 引用，本轮确认其出处。
3. **"不新建库表"早期共识（已修订）**：sdd-skills design §2.3 曾声明不涉及表变更，作为早期"优先复用"原则的历史佐证；2026-10-14 已修订为「复用优先、确有必要时允许新建表/列」（spec §6.7 / 铁律 9），本共识仅作历史留痕。
4. **任务清单格式**：开发规范置顶 + 任务表 + 逐任务子任务 / 验收标准，印证当前 `tasks-template.md` 的 house style（开发规范词频 27 居首）。

### 8.4 须以当前 sdd 为准覆盖 / 纠偏的点

1. **COMPOSITION schema 是理想稿，不可照搬**：sdd-skills design §2.2 的 `composition:` 根 + `skill:` / `agent_type:` / `output:` + `${step.output.field}` 与真实运行器（long-running-task 的 `step_type` / `uses_tables` / `acceptance_criteria` / `condition` / `degradation_chain` + `${file:...}` / `${var}`）**不是同一套**。当前 sdd 必须复用 long-running-task 的真实 schema，禁止抄 sdd-skills 理想稿。
2. **sdd-skills design 的 PlantUML 实现模型图有歧义**：图把 `User→Flow` 扇出到 5 个 agent 并列箭头，视觉像并行，但 `depends_on` 是顺序链。当前 sdd 画编排图须严格表达顺序依赖，不照搬该扇出图。
3. **架构布局分歧**：sdd-skills 设想 `skills/sdd-spec|sdd-design|sdd-task|sdd-test` + 独立 `skills/sdd-flow` 组合；当前 sdd 设计为**单一 L3 融合插件 `skills/sdd/`** 内含全部子能力。当前方案更贴合"融合插件"定位，sdd-skills 的分散布局不被采用。
4. **能力缺口（当前 sdd 必须补齐，sdd-skills 没有）**：① 可选研究步；② 每步人在回路闸口（`decision-points` + `web_request_approval`，confirm/revise/abandon）；③ 数据契约 + 交付物落库（`long_running_task_artifact`）；④ `web-coder` / `app-coder`（仅 cangjie-coder 被复用）；⑤ 进度 / 可观测（SSE/WS）；⑥ 真实可跑的组合引擎接入。

### 8.5 小结

sdd-skills 贡献了"SDD→AgentTeams 分层"的原始意图与 Style B spec 样本，但因其未落地、schema 是理想稿、缺研究步与人在回路，不能作为实现基线。当前 `specs/sdd/` 工程（research→spec→design→tasks 已产出，code/test 待补）是其严格超集，继续以 sdd 目录为准推进 `design.md` / `tasks.md`。

---

# 九、plugingen 工具适配性研究（2026-09-26 追加）

## 9.1 工具定位

`src/plugin/tools/plugingen/plugingen.cj` 是仓库内置的**确定性插件代码生成器**（与 `crudgen` 同构），三种产出模式：

| 模式 | 命令 | 产出 | 对 SDD 的适用性 |
|------|------|------|----------------|
| 表驱动 CRUD | `--name X --db D --table T` | 五层 CRUD Web 插件（PO/DAO/Service/Controller/Route + fountain ORM 依赖 + permissions/i18 节点） | ❌ 不适用（SDD 不是 DB CRUD 服务，且不建表） |
| 进程 CRUD | `--mode process --db D --table T` | 进程内 CRUD 插件（CrudPluginGenerator，codelabs 风格） | ❌ 不适用 |
| **空白进程骨架** | `--mode process --blank` | **空白 L3 进程隔离插件骨架** | ✅ **适用：作为 SDD 插件打包外壳** |

SDD 是 `mode: process` 的 L3 融合插件，因此唯一相关的是 `--mode process --blank`，入口 `PluginGenerator.generateProcessPlugin(name)`。

## 9.2 空白进程骨架实际产出（`generateProcessPlugin`）

| 文件 | 内容 | SDD 处置 |
|------|------|----------|
| `cjpm.toml` | `cjc-version = "1.1.3"`、`output-type = "executable"`、依赖 `ystyle::cordis_plugin`/`cordis_core`/`jsonvalue`/`jsonrpc`（正确的 `../../libs/...` 相对路径） | ✅ **直接保留**——正是 cjc 1.0.5→1.1.3 迁移中最易写错、最需版本/路径一致的部分 |
| `plugin.yaml` | `mode: process`、`command: ./skills/sdd/target/release/bin/skill_sdd.exe`（cwd 相对路径，宿主 `CordisHostManager.resolvePluginCommand` 契约）、`tableWhitelist: []`、`routes: add/edit/del/list` | ✏️ **编辑**：tableWhitelist 改为四张复用表；routes 改为 `gen-sdd`/`review`；description 更新 |
| `src/main.cj` | 显式 `PluginRuntime.run(...)` 入口（禁用 `@Plugin` 宏，规避跨模块宏 bug）+ onInit 注册 handlers/effects | ✏️ **改写**：保留入口范式，把 CRUD handler 注册换成 SDD 编排 bootstrap |
| `src/handlers.cj` | V4 CRUD RPC 框架（add/edit/del/get/list） | ❌ **删除**：SDD 是编排器而非 CRUD 服务（见 9.3） |
| `src/effects.cj` | 可逆效果占位框架 | ✏️ **适配**：保留 effect 范式，注册 SDD 清理效果 |
| `src/README.md` | 通用 L3 插件手册 | ✏️ **覆盖**：写 SDD 专属文档 |
| `SKILL.md`（来自 `SKILL.md.tpl`） | 100% CRUD 定向（table/db/route） | ❌ **覆盖**：替换为 SDD 技能定义 |

## 9.3 关键架构事实（决定 CRUD 框架不可用）

- **宿主侧**已有通用编排引擎：`src/skill/composition_executor.cj`、`composition_yaml_parser.cj`、`lrt_composition_runner.cj`、`composition_validator.cj`。
- **`skills/long-running-task/src/` 自带 500KB+ 进程内编排引擎**：`lrt_composition_runner.cj`（70KB）、`lrt_handlers.cj`（54KB）、`lrt_executor.cj` 等。这说明 L3 插件是"**进程内自带编排器**"，不是 CRUD 端点。

→ SDD 若采用同形态 L3 融合插件，也需要**进程内编排骨架**（编排 runner + 路由 handler + 子 agent 调用 + 事件中继），而非 plugingen 默认生成的 CRUD handler 框架。SDD 的真正复用点是"**宿主底座编排引擎 + 四张复用表 + 决策框架**"（design.md §1.1 已实现度 100% 项），不是 CRUD 模板。

## 9.4 决策结论

**采用 `plugingen --name sdd --mode process --blank` 确定性生成 SDD 插件的"打包外壳"，然后深度定制。** 理由：

1. `cjpm.toml` 与 `plugin.yaml` 的 `mode/command/tableWhitelist` 契约是 cjc 1.1.3 迁移 + 进程插件加载的易错点，工具产出与 `long-running-task` 同源、与仓库约定一致 → 确定性 + 一致性收益大。
2. CRUD 专属产物（`SKILL.md.tpl`、`handlers.cj`、`routes=add/edit/del/list`）与 SDD 编排范式冲突，必须删除/覆盖，删除成本低。
3. plugingen 在此场景是**打包工具而非行为工具**：它解决"正确编译配置 + 正确插件清单"，不解决"SDD 编排逻辑"；后者由 `design.md §2` 的 COMPOSITION.yaml + prompts/ + src/ 编排 handler 承担。

**执行归属（铁律）**：AI 严禁运行 `cjpm build`；plugingen 本身也需宿主编译/运行。故"运行 plugingen 生成骨架"及"后续 `cd skills/sdd && cjpm build`"均为**人工步骤**，AI 仅给出命令、并负责全部编辑与新增文件。

---

# 十、四次研究（2026-09-27）：主 Agent 派生子 Agent 的机制与上下文交接

> 研究动机：SDD 六步全部依赖"主 agent 调用子 agent"。必须先把 runtime 里"子 agent 到底怎么被派生、上下文怎么交接"摸清楚，否则 `design.md` 的编排设计是空中楼阁。

## 10.1 业界基线：Anthropic `agents/` 子目录机制

`skills/skill-creator/`（Anthropic 官方发布，目录内带 `LICENSE.txt`）是 Agent Skills 开放标准的样板，其结构为：

```
skills/skill-creator/
├── SKILL.md
└── agents/{analyzer,comparator,grader}.md
```

子 agent 定义 = **Markdown 正文（系统提示词）+ YAML frontmatter（元数据）**。以 `agents/grader.md` 为例，frontmatter 键为：

```
name / agent_type / description / version / author / tools / model / maxTurns / memory / background / parent_id / permissions
```

本项目 `skills/cangjie-coder/` 明确仿此机制：`SKILL.md` frontmatter 声明 `agents: [doc-consultant, code-searcher, code-editor, code-verifier]`，`agents/` 目录放四个 `.md`（每个都带 `agent_type: sub`、`parent_id: MainAgent`、`language`/`language_context` 等自定义键）。

## 10.2 关键结论：声明侧已对齐业界，运行侧**从未接通**

逐层核验结果（每条都附源码位置，可复核）：

| 层 | 实现位置 | 真实状态 |
|---|---|---|
| **① 声明**（SKILL.md `agents:` 键） | `skills/cangjie-coder/SKILL.md:10-13` | ❌ **无任何代码解析**。`src/skill/skill_parser.cj`、`skill_loader.cj` 中 grep `"agents"` 无命中；全仓 `src` 除 `AutoRouteConfig.cj:1244` 路由表字符串外无解析逻辑 → 该键目前**纯文档，运行时被忽略** |
| **② 解析**（frontmatter → 对象） | `src/core/agent/agent_loader.cj:117-190` | ✅ 已实现。`YamlUtils.extractYamlFrontmatter` + `buildAgentFromYaml`，必填 `name`/**`agent_type`**/`description`，正文作 `systemPrompt` |
| **③ 同步**（文件 ↔ DB） | `src/app/services/sync/handler/AgentSyncHandler.cj` + `detector/ChangeDetector.cj:140-170` | ⚠️ **只扫一半**。`collectMdFiles` 只收 `<base>/AGENTS.md` 与 `<base>/agents/**/*.md`；`base` 来自 `main.cj:264` 的 `SYNC_AGENT_BASE_PATH`（默认 `./`）→ **不扫 `skills/*/agents/*.md`** |
| **④ 拉起**（主 agent 派生） | `src/tool/sub_agent_tool.cj:141-190`（`executeSubAgent`） | ❌ **桩实现**。只拼 transcript 字符串，同步分支直接 `return "Sub-agent task completed: ${question}"`；background 分支返回拼出来的 `subagent_<ts>` 字符串。**不创建、不运行任何 Agent**（工具本身已在 `builtin_tools_registry.cj:120` 注册，名为 `sub_agent_execute`） |
| **⑤ 团队派生**（备选路径） | `src/agent_group/team_manager.cj:163-169`（`createAgent`） | ❌ **空壳**。`BaseAgent(model: unsafe { zeroValue<ChatModel>() }, description: "Agent role: ${agentType}")` → 零值模型、无 system_prompt、不读 `agents` 表 |

**唯一真实可用的子 agent 执行器**是 `src/tool/agent_as_tool.cj` 的 `AgentAsTool`：

- `enum SubAgentMode { Isolated | WithContext }`（L46-56）——**这就是现有的上下文交接语义**：
  - `Isolated`：子 agent 不继承主 agent 任何状态，全部上下文必须塞进唯一的 `question` 字符串（L34-41 的 `PARAM_DESCRIPTION` 明确要求"core question + necessary context or constraints + expected output format"）；
  - `WithContext`：继承主 agent 完整上下文，`question` 只需简短提问（L30-32 `SIMPLE_PARAM_DESCRIPTION`）。
- `invoke`（L102-123）：`agent.chat(AgentRequest(question))`，非 JSON 响应被包成 `{"result": ...,"is_raw_response": true}`。

**缺口定位**：`AgentAsTool` 是"给定 Agent 实例 → 包成工具"的**后半段**；缺的是**前半段**——"给定 `agents` 表一行 / `skills/*/agents/*.md` → 造出 Agent 实例"。`SubAgentTool` 本该补这一环，但它是桩。

## 10.3 上下文交接现状与三个硬缺口

现有交接链路只有三样东西：

1. **入参**：单个 `question: String`（`AgentAsTool`）或 `SubAgentTool` 的 9 个字符串参数（`skill_path`/`question`/`input_files`/`output_dir`/`language_context`/`subagent_type`/`model_override`/`background`/`task_id`，L38-48），全部不落地。
2. **落库载体**：`agent_tasks.parent_task_id`（**存在**，天然可建任务树）+ `agent_contexts`（**只有 `agent_id`，没有 `task_id`**）+ `agent_messages`（`from_agent_id`/`to_agent_id`/`task_id`，可做交接留痕）+ `long_running_task_artifact`（阶段文档）。
3. **回传**：字符串 / JSON 文本，无结构化校验。

由此得出三个硬缺口：

- **G1 上下文串味**：`agent_contexts` 按 `agent_id` 而非 `task_id` 隔离。SDD 六步会**多次调用同一个子 agent**（如 revise 回退重做 spec），上下文必然互相污染。
- **G2 契约靠自然语言**：子 agent 的"输入什么、输出什么"只写在 system_prompt 正文里，没有结构化字段，主 agent 只能靠 prompt 约定，无法校验。
- **G3 无调用留痕**：子 agent 每次被派单的入参/出参/耗时没有专门落点，散落在 `agent_tasks.payload` / `agent_skill_executions`。

## 10.4 数据驱动哲学下的"超越业界"方案

runtime 已确立**数据驱动**设计哲学（文件 ↔ DB 双向同步为事实标准：`AGENTS.md` ↔ `agents` 表已真实运行）。据此，把"子 agent"从 Anthropic 的**文本约定**升级为**数据库一等公民**：

| 环节 | Anthropic 基线 | 本项目可做的超越 |
|---|---|---|
| 定义 | `agents/*.md` 文本，宿主自行发现 | `agents/*.md` ↔ `agents` 表**双向同步**，`source_path` 作唯一键（已是），扩展同步扫描到 `skills/*/agents/**/*.md` |
| 归属 | 无（靠目录位置隐式） | 增 `skill_name` 列 → 可索引查询"某技能拥有哪些子 agent" |
| 契约 | 正文自然语言描述 | `capabilities` / `default_input_types` / `default_output_types`（**三个 jsonb 列已存在、当前全 NULL**）填 GB/Z 185.4 ACS 结构 → 输入输出契约结构化、可校验 |
| 派单 | 主 agent 口述分派 | 主 agent 写 `agent_tasks(parent_task_id, agent_id, payload)` → **派单即数据** |
| 上下文 | 模型自行决定 | `agent_contexts` 增 `task_id` → **按次隔离**，可复现、可回放 |
| 拉起 | 宿主内建 | 补全 `SubAgentTool.executeSubAgent`：「查 `agents` 表 → `AgentLoader` 造 `AgentDefinition` → 造 Agent 实例 → `AgentAsTool` 包装 → `chat`」，一次实现即同时获得 `Isolated` / `WithContext` 两种成熟语义 |
| 发现 | 无 | `discoverable` + `capabilities` → 能力可被检索（对齐 GB/Z 185.4 / AIP 发现） |

## 10.5 附带发现（须一并修正）

1. **文档与实现不一致**：`docs/agents/agent-declaration-spec.md` §3.1 写 frontmatter 键为 `type:`，而 `agent_loader.cj:177` 实际读 **`agent_type:`**。且该文档未覆盖已实装键：`parent_id`、`model_capabilities`、`capabilities_skill`、`identity_status`、`discoverable`、`aic`。
2. **`parent_id` 语义**：frontmatter 里写的是字符串 `MainAgent`（名字），`agents` 表里存的是 uuid。二者需映射（`AgentSyncHandler` 需按 name 解析 uuid），目前 DB 中的 4 条是人工填好的。
3. **`cangjie-coder` 不是定稿**：本次确认其子 agent 机制从未由 runtime 运行（①不解析 ②不扫描 ③桩执行）。因此 **SDD 编码步不能假定 `cangjie-coder` 的 subagent 可用**；SDD 工程须把"打通子 agent 执行链路"与"迭代 cangjie-coder"作为共同前置（见 §10.6）。
4. **`docs/agents/agent-declaration-spec.md` §7.1 的加载目录**（`built-in/agents`、`user/agents`、`project/agents`、`policy/agents`）**与 `AgentLoadManager.loadFromDirs`（`agent_loader.cj:325`）的实际用法无关**，属早期设计残留。

## 10.6 对 SDD 工程的直接影响

1. SDD 六步的"主 agent 调用子 agent"**不能**直接寄托于 `SubAgentTool` 现状，必须在 SDD 工程内（或作为前置任务）**补全执行链路**。
2. SDD 自身的五个子 agent 定义文件放 `skills/sdd/agents/*.md`，frontmatter 必须写全：`name` / `agent_type: sub` / `description` / `parent_id: MainAgent` / `tools` / `model` / `maxTurns` / `memory` / `permissions` / **`skill_name: sdd`** / **`input_types`** / **`output_types`**。
3. SDD 六步的上下文交接采用 **`Isolated` 模式 + 显式上下文包**（把上一步产物路径、模板路径、用户反馈一并写进 `question`），因为 SDD 每步产物是大文档，"继承全部上下文"会撑爆窗口且不利于复现；产物交接走 `long_running_task_artifact`（`stage` 维度）+ `agent_tasks.result`。
4. cangjie-coder 的迭代（`skills/cangjie-coder` 定稿）纳入 SDD 工程依赖，但不阻塞 SDD 骨架开发——过渡期编码步可退化为"主 agent 直接按 cangjie-coder 的 SKILL.md 四步工作流执行"。

---

# 十一、四次研究（2026-09-27）：数据库现状盘点与 SDD 所需补充

> 依据：`apps/agentskills-runtime/sql/public20260927.sql`（Navicat 全量导出，93MB，导出时间 2026-09-27 00:34）。

## 11.1 `agents` 表结构与现状数据

DDL 共 34 列（`sql/public20260927.sql:19755`），关键列：

`id / name / agent_type / description / status / config(json) / system_prompt / tools(json) / model / parent_id / user_id / color / background / memory_scope / isolation_mode / max_turns / initial_prompt / creator / version / author / permissions(json) / source_path / sync_status / last_sync_at / aic / identity_status / aip_registered_at / capabilities(jsonb) / default_input_types(jsonb) / default_output_types(jsonb) / discoverable`

**现状 5 行**（与用户描述一致）：

| name | agent_type | source_path | parent_id | 来源 |
|---|---|---|---|---|
| `MainAgent` | `MAIN` | `AGENTS.md` | — | ✅ 自动生成（`last_sync_at=2026-09-26 10:30` 证明同步机制在跑） |
| `code-editor` | `sub` | `skills/cangjie-coder/agents/code-editor.md` | MainAgent | ❌ 手工（`sql/insert_subagents.sql`） |
| `code-searcher` | `sub` | 同上目录 | MainAgent | ❌ 手工 |
| `code-verifier` | `sub` | 同上目录 | MainAgent | ❌ 手工 |
| `doc-consultant` | `sub` | 同上目录 | MainAgent | ❌ 手工 |

4 条子 agent 共性缺陷（可直接粘 psql 复核）：`discoverable = false`、`identity_status = 'none'`、`aic / capabilities / default_input_types / default_output_types` **全为 NULL**、`created_at` 集中在 `2026-09-24 13:23:28`（一次性手工灌入）。

`agent_skills` 表 50 行，已含 `cangjie-coder`、`long-running-task`、`sdd-spec`、`sdd-design`、`sdd-flow`（SDD 插件完成后需在此表落一行 `sdd`）。

## 11.2 结论：需要补充，且既补数据也补结构

**A. 必须补的数据（~~6 行~~ 5 行）** —— SDD 的子 agent：

`skills/sdd/agents/{sdd-researcher, sdd-spec-writer, sdd-design-writer, sdd-task-planner, sdd-tester}.md`，落库时 `parent_id` = MainAgent 的 uuid、`source_path` = `skills/sdd/agents/<name>.md`、`agent_type = 'sub'`、`discoverable = true`。

> **v13 更正（2026-09-27 拍板）**：`code` 步**不派生**写代码子 agent —— 编码由主 agent 加载编程技能（`cangjie-coder` / `web-coder` / `app-coder`）+ SOP 执行，故 `sdd-code-dispatcher.md` 已从 `agents/` 删除，此处由 6 行减为 5 行。

> 与既有 4 条手工数据不同，这 5 条**不应手工灌**，而应由扩展后的同步机制自动写入（见 11.3 第 1 项）——否则 SDD 就无法证明"子 agent 机制真的跑起来了"。

**B. 必须补的结构（4 项 DDL）**：

```sql
-- 1) 子 agent 归属技能：替代 source_path 字符串解析，可索引
ALTER TABLE "public"."agents" ADD COLUMN IF NOT EXISTS "skill_name" varchar(128);
COMMENT ON COLUMN "public"."agents"."skill_name" IS '所属技能名（skills/<skill_name>/agents/*.md），子agent必填，主agent为空';
CREATE INDEX IF NOT EXISTS "idx_agents_skill_name" ON "public"."agents" ("skill_name")
  WHERE "deleted_at" IS NULL;

-- 2) 上下文按"次"隔离：子 agent 被同一 SDD 工程多次调用不串味
ALTER TABLE "public"."agent_contexts" ADD COLUMN IF NOT EXISTS "task_id" uuid;
COMMENT ON COLUMN "public"."agent_contexts"."task_id" IS '所属任务/调用次，子agent按次隔离上下文';
CREATE INDEX IF NOT EXISTS "idx_agent_contexts_task_id" ON "public"."agent_contexts" ("task_id")
  WHERE "deleted_at" IS NULL;

-- 3) 子 agent 调用留痕：入参/出参/耗时/模式，可做回放与验收
CREATE TABLE IF NOT EXISTS "public"."sub_agent_invocations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "parent_task_id" uuid,
  "task_id" uuid,
  "agent_id" uuid NOT NULL,
  "skill_name" varchar(128),
  "stage" varchar(64),
  "mode" varchar(20) NOT NULL DEFAULT 'isolated',
  "input_json" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "output_json" jsonb,
  "status" varchar(20) NOT NULL DEFAULT 'running',
  "duration_ms" int8,
  "error_message" text,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
);
COMMENT ON TABLE "public"."sub_agent_invocations" IS '子agent派单留痕：主agent每次派生子agent的入参/出参/耗时';

-- 4) SDD 工程实例头表：六步+闸口+多轮修订需要一个可查询的工程态
CREATE TABLE IF NOT EXISTS "public"."sdd_projects" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "feature_name" varchar(64) NOT NULL,
  "title" varchar(256),
  "task_id" uuid,
  "current_stage" varchar(32) NOT NULL DEFAULT 'init',
  "status" varchar(20) NOT NULL DEFAULT 'running',
  "enable_research" bool NOT NULL DEFAULT false,
  "round" int4 NOT NULL DEFAULT 1,
  "payload" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "creator" uuid,
  "owner_user_id" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
);
COMMENT ON TABLE "public"."sdd_projects" IS 'SDD规范驱动开发工程实例：feature_name唯一，current_stage取值 init/research/spec/design/task/code/test/done';
CREATE UNIQUE INDEX IF NOT EXISTS "uq_sdd_projects_feature" ON "public"."sdd_projects" ("feature_name")
  WHERE "deleted_at" IS NULL;
```

> **取舍说明**：此前 `spec.md §6` 定过"不新建表"。本轮用户明确"允许拓展数据库结构"，故放宽；**2026-10-14 进一步修订为「复用优先、确有必要时允许新建表/列」，不再设"最多 2 张/2 列"硬额度封顶**（spec §6.7 / 铁律 9）。`sub_agent_invocations`、`sdd_projects` 作为复用不成立时允许的新增表，二者都是"工程态/留痕"性质，**阶段文档正文仍落 `long_running_task_artifact`**，不重复存储。

**C. 不需要 DDL、只需填值（3 列）**：`capabilities` / `default_input_types` / `default_output_types` —— 直接按 GB/Z 185.4 ACS 结构填充五个 SDD 子 agent 的输入输出契约。

**D. 行级权限白名单同步**：`PermissionUtils.hasOwnerUserColumn` 目前只认 `agent_tasks / crontab / long_running_task_artifact / long_running_task_evolution`。新表 `sdd_projects` 若需 owner 隔离，必须同步加入该白名单（否则"产出但查不到"静默失败）。

## 11.3 与子 agent 机制的配套改造（DB 侧闭环）

1. `ChangeDetector.collectMdFiles`（`src/app/services/sync/detector/ChangeDetector.cj:140-170`）扩展：除 `<base>/agents/**/*.md` 外，增加遍历 `<base>/skills/*/agents/**/*.md`，使 `skills/sdd/agents/*.md` 能被 `AgentSyncHandler` 自动同步进 `agents` 表。
2. `AgentSyncHandler` 映射 frontmatter 新增键：`skill_name`（由 source_path 推导，形如 `skills/<name>/agents/...`）、`input_types`/`output_types` → `default_input_types`/`default_output_types`、`capabilities`。
3. `parent_id` 解析：frontmatter 写名字（`MainAgent`），同步时按 name 查 uuid；查不到记 `sync_status='dependency_missing'` 而非静默丢 NULL。

---

# 十二、五次研究（2026-09-27）：coder 技能形态决策与 `agents/` 自动探测

> 触发：用户补充意见——`skills/cangjie-coder/agents/` 的四个子 agent 疑似早期 AI 工具未理解意图而随意创建；语言专用子 agent 架构已随模型能力提升而落伍，应简化为"主 agent + 编程语言 skills"；SDD 插件仍保留 `agents/` 并作为多 agent 协作落地示例；希望实现"加载带 `agents/` 的技能即自动探测并加载子 agent"。

## 12.1 `skills/cangjie-coder/agents/` 现状盘点

四个文件（`code-searcher` / `code-editor` / `code-verifier` / `doc-consultant`），frontmatter 均为 `agent_type: sub`、`language: cangjie`、`language_context: cangjie-language-guide,cangjie-full-docs`，`tools` 各不相同（`file_search` / `file_write,file_edit` / `cli_execute` / `file_search`），`maxTurns` 50~100。

**判定为"早期 AI 工具自行创建的遗留物"，三条证据**：

1. `SKILL.md` 的 `agents:` 键**无人解析**（§10.2），即这四个文件从未被 runtime 加载；
2. 对应 4 条 DB 记录来自 `sql/insert_subagents.sql` **手工灌入**（§11.1），`discoverable=false`、契约三列 NULL；
3. 四个角色（查阅文档 → 检索片段 → 编辑适配 → 验证）**恰好等于 `SKILL.md` 已有的四步工作流步骤**——切成四个子 agent 只是把顺序执行的步骤换成四个需要上下文重建的独立会话，没有新增能力，只新增开销。

## 12.2 架构演进判断：语言专用子 agent → 主 agent + 语言技能

用户提出的演进路径成立，且与本仓库观察一致：

| 维度 | 多语言专用子 agent（2025-12 架构） | 主 agent + 语言技能（当前，采纳） |
|---|---|---|
| 前提 | 模型通用编码能力不足，需角色切分补偿 | 模型能力足够，缺的是**确定性依据**而非角色 |
| 成本 | 每次派生都要重建上下文 + 回传结果 | 加载 SKILL.md，上下文连续 |
| 复杂度 | 需编排角色顺序与结果传递 | SOP 顺序执行，零编排 |
| 关键收益来源 | 角色隔离 | **官方文档技能检索 + 工程内既有先例**（确定性优先） |

**结论**：编码能力以**技能**形态提供——`SKILL.md`（SOP）+ 官方文档技能引用 + `references/` + `scripts/`，主 agent 加载后自执行，不派生编码子 agent。

## 12.3 判别准则：什么才值得派生子 agent

提出一条可操作的判据，供后续所有技能套用：

> **"需要换脑子的才派生，只需要换说明书的用技能。"**

- **换脑子**（派生子 agent）：产物是**文档 / 流程**，需要独立的角色立场、独立的上下文边界、可被其他场景复用的身份 → **流程编排类技能**（SDD 六步）。
- **换说明书**（用技能）：产物是**代码 / 配置**，主 agent 具备通用能力，只需拿到该语言 / 领域的 SOP 与官方 API 契约 → **编程 / 领域类技能**（cangjie-coder / web-coder / app-coder）。

## 12.4 自动探测的三个挂点（本轮新发现）

| 层 | 现状 | 改造 |
|---|---|---|
| **同步层** | `ChangeDetector.collectMdFiles`（L140-174）只收 `<base>/AGENTS.md` + `<base>/agents/**/*.md`；`collectSkillDirs`（L175-193）用 `Directory.walk` 找含 `SKILL.md` 的目录 | 复用 `collectSkillDirs` 的 walk 模式枚举 `<base>/skills/*`，再收其 `agents/**/*.md`；`skill_name` 由路径反推；既有"文件删除→DB 删除"逻辑（L60-64）自动生效 |
| **加载层** | ⚠️ **`src/skill/skill_loader.cj:55` 的 `loadSkillFromDirectory` 是桩**——直接返回 `BaseSkill(name: "placeholder-skill", instructions: "# Placeholder Skill")` | **禁止**挂在这里。真入口是 **`SkillManagementService.loadSkillsFromDirectory`**（`src/plugin/skill_bridge.cj:18` 注释：含 SKILL.md frontmatter 解析 → manifest 校验 → Skill 实例创建完整管线） |
| **派生层** | `SubAgentTool.executeSubAgent` 是桩（§10.2） | 解析顺序：① 当前技能 `bundledAgents` → ② 全局 `agents` 表（`discoverable=true`）→ ③ 未命中立即失败 |

> **本轮最有价值的一条"防坑"发现**：`skill_loader.cj` 是桩。若照目录名直觉把它当加载入口改造，会得到"功能看起来跑通但实际是假的"的结果——这是本次研究中比"机制缺失"更隐蔽的风险。

## 12.5 与 Anthropic 基线的差异（本项目超出业界的部分）

Anthropic `skill-creator` 的 `agents/*.md` 是**纯文本约定**：SKILL.md 写 "read `agents/grader.md`"，由模型自行 spawn 并读文件；runtime 不解析、不入库、不登记、不可发现、删除无感知。

本项目将同一目录约定升级为**运行时机制**（**约定即注册**）：

| 能力 | Anthropic 基线 | 本项目（设计后） |
|---|---|---|
| 存在性 | 仅文件 | 文件 + DB 行（可查询） |
| 发现 | 靠模型读文件 | `agents` 表按 `skill_name` 查询 |
| 能力契约 | 无 | `capabilities` / `default_input_types` / `default_output_types`（对齐 GB/Z 185.4 ACS） |
| 下线 | 无（删文件后模型仍可能引用） | 删文件 → DB 行同步删除 |
| 加载 | 无 | 技能加载即挂载 `bundledAgents`，按名直接派生 |

这是"数据驱动"哲学在子 agent 机制上的直接体现，也构成相对业界基线（含智能体互联国标的 frontmatter 描述方案）的实质增强。

## 12.6 对 SDD 工程的直接影响

1. **spec.md**：新增 §5.10 REQ-SDD-011（自动探测与自动加载，6 条规则）；§3.1 编码执行者改为"编程技能"；§5.6 规则 2/4 改技能形态；§5.9 规则 8 改为"coder 技能去子 agent 化"；§2 补两个术语。
2. **design.md**：新增 §1.2.7（形态决策 + 处置 + 三挂点 + 与业界差异）、§2.9（自动探测设计）；§2.1.2 加"哪些技能该带 `agents/`"判别准则；§2.2.4 路由契约表改为技能并加官方文档技能列；§2.6 防回退 10 条 → 13 条；§2.8 由"回填 4 条数据"改为"清理下线"。
3. **tasks.md**：T-10 改技能形态；T-17 去掉数据回填、加 `agents/` 约定章；**T-18 目标反转**（去子 agent 化）；新增 **T-19（bundledAgents）**、**T-20（解析顺序）**；原 T-19/T-20 顺延 T-21/T-22；总数 20 → 22。

---

# 附录 A：本研究直接复用的关键文件索引

| 用途 | 文件 | 备注 |
|------|------|------|
| L3 插件样板 | `skills/long-running-task/plugin.yaml` | 直接仿写 |
| 组合编排格式 | `skills/long-running-task/COMPOSITION.yaml` + `src/skill/lrt_composition_runner.cj` | 文件态 DSL，SDD 复用 |
| 人在回路契约 | `skills/long-running-task/SKILL.md`（decision-points + web_request_approval） | 原样套用 |
| 数据契约样板 | `skills/long-running-task/DATA_CONTRACT.yaml` | SDD 版改造 |
| 运维手册 | `skills/long-running-task/OPS.md` | 部署/排查参考 |
| 需求模板 | `.codeartsdoer/skills/managing-sdd-spec-markdown/{spec_template.md,ears-format.md}` | spec 子 agent 写入规范 |
| 设计模板 | `.codeartsdoer/skills/managing-sdd-design-markdown/{design_template.md,design-principles.md}` | design 子 agent 写入规范 |
| 早期需求基线 | `.codeartsdoer/specs/sdd-skills/{spec.md,design.md,tasks.md}` | 保留参考，实现以本 sdd 目录为准 |
| 开发手册 | `skills/uctoo-dev-manual/SKILL.md` | 工具链/规范总入口 |
| 文档查询 | `skills/uctoo-doc/SKILL.md` | 检索 runtime 文档与 DB |
| **业界子 agent 基线** | `skills/skill-creator/{SKILL.md, agents/*.md}` | Anthropic 官方，frontmatter 机制样板 |
| **子 agent 仿制样本** | `skills/cangjie-coder/{SKILL.md, agents/*.md}` | 未定稿，运行侧未接通 |
| **frontmatter 解析** | `src/core/agent/agent_loader.cj:117-190` | 读 `agent_type`（非 `type`） |
| **Agent 定义模型** | `src/core/agent/agent_definition.cj:114-160` | 字段全集 |
| **文件↔DB 同步** | `src/app/services/sync/handler/AgentSyncHandler.cj`、`detector/ChangeDetector.cj:140-170` | 只扫 `AGENTS.md` + `<base>/agents/` |
| **子 agent 拉起（桩）** | `src/tool/sub_agent_tool.cj:141-190` | `executeSubAgent` 未实现 |
| **子 agent 执行器（可用）** | `src/tool/agent_as_tool.cj:46-123` | `SubAgentMode.Isolated/WithContext` |
| **团队派生（空壳）** | `src/agent_group/team_manager.cj:163-169` | 零值模型 |
| **Agent 声明规范（过时）** | `docs/agents/agent-declaration-spec.md` | `type:` 与实现 `agent_type:` 冲突 |
| **全量数据基线** | `sql/public20260927.sql` | `agents` 表 DDL 在 19755 行 |
| **子 agent 手工数据** | `sql/insert_subagents.sql` | 演示数据，非运行产物（v3 决策：清理下线） |
| **cangjie-coder 遗留子 agent** | `skills/cangjie-coder/agents/{code-searcher,code-editor,code-verifier,doc-consultant}.md` | §12.1 判定为遗留物，须删除 |
| **技能加载真入口** | `SkillManagementService.loadSkillsFromDirectory`（据 `src/plugin/skill_bridge.cj:18` 注释） | 自动探测挂点（§12.4） |
| **技能加载桩（勿改）** | `src/skill/skill_loader.cj:55` | 返回 `placeholder-skill`，改它等于造假 |
| **Anthropic 子 agent 基线** | `skills/skill-creator/agents/{grader,analyzer,comparator}.md` | 纯文本约定，runtime 不解析（§12.5） |
