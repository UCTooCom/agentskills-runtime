# 研究文档：ASR 自进化系统（RSI）研究步

> 阶段：research（可选步，本次显式执行以支撑"超越业界最佳实践"的论证）
> 工程：`specs/RSI`
> 上游：无（首步）
> 模板：`skills/sdd/templates/research-template.md`
> 落库：`long_running_task_artifact`(usage=deliverable, stage=research)
> 日期：2026-10-17 · 版本 v0.1 · 状态：草稿（待闸口 confirm）

---

## 1. 研究目标与问题边界

本研究为 ASR（agentskills-runtime，即 uctoo v4）的 **RSI（Recursive Self-Improvement，递归自进化）** 能力专题落地提供理论与工程依据。核心问题：

1. **RSI 在 ASR 里的确切含义是什么？** —— 不是"模型改写技能文本"这一单点能力，而是
   **代码 + 技能 + 数据库三大数字基础设施的闭环自进化**（用户原话："ASR 是不仅限于 skill 知识的进化，而是一整套数字基础设施的闭环自进化"）。
2. **为什么"直接让大模型生成框架源码"此路不通？** —— 需要一个经实证的方法论结论，而非直觉。
3. **ASR 相比 deepseek-harness / openclaw / hermes-agent 等业界 harness 的差异化根基在哪？** —— 需要可辩护的对比，而非工程量碾压。
4. **RSI 的落地形态是什么？** —— 一个综合调度既有基础设施的 `skills/RSI` 技能，从理论到实践落地《人工智能软件工程方法论》。

---

## 2. 证据来源（已核验）

| 证据 | 路径 / 出处 | 用途 |
|---|---|---|
| uctoo 框架 README（AI 驱动开发框架理念） | `D:\UCT\products\uctoo\README.zh-CN.md` | 前身理念、UMI 同构、Human-Code Preservation、生态集成 |
| 仓颉开发者大会 PPT（代码+skill 闭环） | `D:\UCT\products\opencangjie\cangjie Developers day 深圳\OpenCangjie-AgentSkills-runtime仓颉智能体.pptx` | 2026-04 演讲：代码+技能闭环开发框架自主进化 |
| WAIC PPT（代码+skill+数据库闭环） | `D:\UCT\products\opencangjie\WAIC\zhipeng-waic2026-agentskills-runtime.pptx` | 2026-07 演讲：代码+技能+数据库闭环开发框架自主进化 |
| 《人工智能软件工程方法论》 | https://mp.weixin.qq.com/s/woq7c8cxvr8TYv1NkNH17A （2025-11-29 发布） | 思想方法论根基：三支柱、确定性/不确定性二分、确定性代码生成优于概率代码生成 |
| uctoo-v4 规范集 | `docs/uctoo-v4/*.md`（api / database-design / module-development / orm / middleware / architecture / permission） | RSI 落地必须对齐的规范源 |
| 确定性代码生成工具 | `src/app/tools/{loaddbinfo,crudgen,crudweb}`、`src/plugin/tools/{plugingen,pluginuninstall}` | "框架之手"——保证产出确定性可用的代码 |
| 多技能并行子系统 | `src/skill/parallel/*`（declaration_parser / auto_injector / task_matcher / budget_manager / conflict_filter / profile_skill_resolver …） | RSI 的并发执行基底 |
| LRT 长程任务子系统 | `src/app/services/lrt/`、`src/skill/lrt_composition_runner.cj`、`src/app/tools/long_running_task_tool.cj` | RSI 的异步多轮调度心跳 |
| AI 可驱动技能 SOP | `skills/{sdd,uctoo-dev-manual,long-running-task}` | RSI 调用的"既有 SOP 库" |
| 四项目插件机制对比报告 | `docs/ref/plugin-mechanism-comparison.html`（D12 原生智能/自进化维度） | 同业 RSI 能力基线 |
| Laya System-1 决策引擎集成研究 | `.codeartsdoer/specs/laya-system1-integration/{research,spec,appendix}.md` | System-1 判断型模型（Jev 开源替代）：choice/score/noul 原语、校准置信度、不生成文字、本地/离线、MCP 接入；是 RSI「以 System-1 承接可结构化决策」设想的底座 |
| AI 驱动架构原则（架构师观点 + AI 分析） | `docs/ref/AIDrivenArchitecture.md` | **「确定性优先，AI 增强」分层协作原则**；双驱动框架（有 AI 是 AI 驱动，无 AI 仍是完备框架）；AI 本职含"代码生成"；核心措辞来源："以系统工程的确定性消解 LLM 的不确定性"，而非去 LLM |

---

## 3. 核心结论一：RSI 的语义边界（ASR 定义）

ASR 的 RSI 不是"技能知识进化"的子集，而是 **三层数字基础设施的闭环自进化**：

```
        ┌──────────── 感知/规划（LLM 为脑）────────────┐
        │  skills/RSI 技能 = 调度中枢 + 方法论 SOP      │
        └───────────────────┬──────────────────────────┘
                ┌──────────┼──────────┐
         ① 代码层        ② 技能层        ③ 数据库层
   确定性代码生成      SKILL.md/SOP     UMI / UMI-ORM
   crudgen/crudweb    sdd 流水线        schema→ORM→CRUD→web
   plugingen          uctoo-dev-manual  多端一致数据传递
   pluginuninstall                    （UMI-ORM 待补全）
                └──────────┴──────────┘
        每一层都"可被测/可被确定性工具改写/可被模型感知"
```

- **代码层自进化**：通过 `loaddbinfo → plugingen/crudgen → crudweb` 确定性工具链改写框架源码，**不靠 LLM 手写**。
- **技能层自进化**：通过 `sdd` 流水线改写 `spec/design/tasks`（知识层），并通过"一切皆技能"机制让模型即时感知新能力。
- **数据库层自进化**：通过 UMI 架构（`docs/uctoo-v4/uctoo-database-design-*.md`）+ UMI-ORM（atomgit 开源，待补全）实现 schema 驱动的确定性多端一致演进。

三者形成闭环：数据库结构变化 → 确定性重生成 ORM/CRUD/Web → 新能力以技能形式被模型感知 → 模型基于新能力规划下一轮演进。

---

## 4. 核心结论二：框架级变更不能仅靠 LLM 概率性生成——需以确定性基础设施消解其不确定性（实证）

《人工智能软件工程方法论》（2025-11）的逻辑链（已逐字核验原文）：

1. 软件本质分**确定性 / 不确定性 / 不可判定性**三类。传统软件追求**确定性**（同输入同输出，这是调试、验证、可靠性的基石）。
2. 集成大模型后输出具**概率性与不可解释性**，突破传统确定性；图灵停机问题的**不可判定性**划定了"AI 无法全面自我解释与验证"的根本边界。
3. 因此：**用含概率的 AI 去生成"全部框架代码"是错配**——框架代码属确定性软件，本应由确定性工具产出。
4. 作者一线实证："即使是数据库表加了一个字段，直接用大模型生成代码去进行框架中的变更，也无法一次性修改正确，**必定经历编译失败和修复的过程**，这个是无法达到框架代码进化要求的。"
5. 结论：**AI 生产力 = AI IDE + 大模型 + AI 驱动开发框架（三位一体）**。开发框架负责固化最佳实践与预制构件并向 AI 提供**确定性代码生成工具**；AI 负责**规划调用哪些工具 + 拼装胶水代码**。这是"人机协同、框架为基、AI 为脑"的最优解。

> ⚠️ 措辞澄清（用户 2026-10-17 修正）：本节易被误读为"LLM 不得生成框架源码"。**正确理解是——LLM 仍然在需要的流程与位置生成代码**（如胶水逻辑、非标准模块、Novel 实现、需求理解与方案构思），这正是 `docs/ref/AIDrivenArchitecture.md` 所列 AI 本职活动之一（"代码生成"）。我们构建大量确定性基础设施，**目的不是"去 LLM"，而是「以系统工程的确定性消解 LLM 的不确定性」**：把"框架级结构正确性"这一确定性诉求，交由确定性代码生成工具（loaddbinfo/crudgen/crudweb/plugingen）保障，从而让 LLM 从"必须一次写对全部框架代码"的高风险负担中解放出来，专注于其擅长的不确定性任务。

> 这构成 ASR 的**第一性原理约束（Iron Law RSI-0）**：框架级确定性的部分**优先经由确定性代码生成工具保障**，以系统工程的确定性**消解 LLM 在框架级变更中的不确定性**；LLM **仍在需要的流程与位置生成代码**，只是不再让其概率性输出单独承担框架级的结构正确性。这是与所有同业 harness 的根本分水岭——**不是"去 LLM"，而是"让合适的子系统特性由合适的组件提供"**（确定性工具做确定的事，System-1 做结构化判断，System-2/LLM 做推理与创造）。

---

## 5. 核心结论三：同业 RSI 能力基线（来自对比报告 D12）

依据 `docs/ref/plugin-mechanism-comparison.html` D12 维度（三层评估法）的已核验结论：

| 项目 | 第一层（能力自动进 prompt） | 第二层（模型能否自扩充） | 第三层（模型自省） |
|---|---|---|---|
| deepseek-harness | ✅ `ctx.systemPrompt.tools()` 一行打通 | ❌ `self-improvement/reflection` 全仓零命中；ralph 明确拒改自身循环 | 只读 `cordis_inspect_*` |
| openclaw | ✅ 插件工具按字母序自动追加 | ✅ 最强：`skill_workshop` 八动作 + 默认后台自动评审 + `reloadAndResume` | 四组工具最全 |
| hermes-agent | ✅ `get_tool_definitions()` 收编 | ⚠️ 每轮 `background_review` 自评写 memory，但**契约明文禁止改框架代码** | 无统一自省工具 |
| **ASR** | ✅ `SkillToToolAdapter` 把 SKILL.md frontmatter 映射成 Tool | ⚠️ LRT 闭环只出 optimization_plan **不改源码** | `plugin_inspect/activate/refresh` + `llm_channel_*` |

**关键行业发现**：四家**不约而同把自进化限制在"技能文本层"，不让模型动插件/框架代码**。当前 RSI 共识边界 = *让模型改写知识/流程，但不让它改写代码*。

ASR 的差异化在于：这条边界**被写成正式注释与可执行流程**（而非靠权限缺省），且 ASR **额外拥有确定性代码生成工具**——这是同业完全没有的"框架之手"。因此 ASR 有条件把边界从"技能文本层"**推进到"确定性工具驱动的源码层"**，而不退化为"概率代码生成"。

---

## 6. 核心结论四：ASR 已具备的 RSI 前置基础设施（存量盘点）

| 基础设施 | 现状 | RSI 角色 |
|---|---|---|
| 一切皆技能的插件机制（`src/plugin/`、`SkillToToolAdapter`） | ✅ 已实现 | 原生智能基底：让 LLM 感知框架能力，是无限拓展能力的前置设施 |
| 多技能并行（`src/skill/parallel/*`） | ✅ 已实现 | RSI 并发执行基底：多 RSI 子agent（分析/起草/生成）可并行受预算与冲突管控 |
| LRT 长程任务（`src/app/services/lrt/`） | ✅ 已实现 | RSI 心跳/调度：异步多轮执行，支持事件/周期触发自进化循环 |
| 确定性代码生成工具（loaddbinfo/crudgen/crudweb/plugingen/pluginuninstall） | ✅ 已实现 | "框架之手"：保证 RSI 改写源码确定性可用、架构不腐坏 |
| 规范集（`docs/uctoo-v4/*`）+ `uctoo-dev-manual` 技能 | ✅ 已实现 | RSI 改动的"单一事实源"与护栏 |
| SDD 流水线（`skills/sdd`，六步 + 人在回路闸口 + git SOP） | ✅ 已实现 | RSI 的"变更治理"通道：每一次自进化都过 spec→design→tasks→code→test |
| 开发阶段自动化编译（build watcher，昨日落地） | ✅ 已落地 | RSI 的"验证闸口"：编译通过才允许纳入版本管理 |
| UMI-ORM（数据库自进化腿） | ⚠️ 仅开源骨架（atomgit），未完整实现 | **RSI 最大短板**：DB 层自进化目前仅 UMI 架构多端一致传递，缺 schema→代码的确定性闭环 |

**结论**：RSI 的代码腿、技能腿、调度腿、治理腿、感知腿均已完成；唯独**数据库腿（UMI-ORM）是缺口**，且 RSI 尚未被"专题化"为独立能力。这正对应你所说"现在应该是到了专题落地 RSI 的时候"。

---

## 7. 核心结论五：Laya System-1 决策引擎可承接「确定性代码开发」中的结构化决策，降低对 System-2 推理 LLM 的依赖

> 本节回应一个直觉性假设：**"我们已经有很多前置基础设施，那么通过集成 Laya 这样的判断型大模型，也许能够降低对推理型大模型的依赖，以系统工程的确定性 + System-1 的结构化判断来驱动 ASR 进行确定性代码开发。"** 下文把它从直觉提升为可论证、可验证的设计命题。注意：这不是"去 LLM"，而是"让合适的子系统特性由合适的组件提供"，LLM 仍在需要的流程与位置生成代码。

### 7.1 底座：laya-system1-integration 工程已具备的研究基础

`.codeartsdoer/specs/laya-system1-integration/` 工程（2026-09-29）已对 **Laya（Jev 的开源/本地/离线 System-1 决策引擎，Apache-2.0）** 做完整论证。关键事实（已核验，详见该工程 research.md）：

- **System-1 只做结构化判断，不生成文字**：输入一段 state（文本/JSON/数组）+ 预定义问题，一次性并行返回 choice（≤32 选项选一，带概率+置信度）/ score（有序量表打分）/ noul（陈述为真的概率 P∈[0,1]）三类决策；零幻觉、无 JSON 解析负担。
- **置信度经 RLCD 校准**："说 80% 确定，长期就该约 80% 真确"，置信度可直接用于阈值门控（高置信自动执行、低置信升级）。
- **本地/离线、可 ONNX 量化**：T4 单问题 ~33ms、CPU ~200ms；契合"全链路自主可控"。
- **MCP 接入零改 Laya 代码**：`laya-mcp-server` 暴露 `laya_predict/decide/preset/shortlist/...`，可注册为 runtime 外部 MCP 工具。
- **该工程原有的定位**：把 System-1 当作 Agent 循环里的"快思考层"——路由、护栏、循环停滞检测（CONTINUE/WARN/REPLAN/HALT）、"完成"声明核验、上下文压缩。即"判断从生成中剥离"。

### 7.2 新论点：把 System-1 从"循环内判断"推到"代码开发本身"

原工程止步于"循环内判断"。本节推进一层——**ASR 已建好的确定性代码生成工具（loaddbinfo / crudgen / crudweb / plugingen / pluginuninstall），本质上已把"写框架代码"这个不确定任务，转化成了"调用哪个工具 + 传什么结构化参数 + 按什么顺序"的结构化决策序列。**

而"结构化决策"正是 System-1（Laya 的 choice/score/noul）最擅长、且带校准置信度的能力。于是得到命题：

> **AI 驱动 ASR 做确定性代码开发，可由 System-1 承接"调用哪工具 / 填什么参数 / 验什么结果"这类结构化决策，从而降低对 System-2 推理 LLM 的依赖；System-2 仍保留在需求理解、Novel 实现与低置信度升级等位置——不是"去 LLM"，而是让合适的子系统特性由合适的组件提供。**

推理链：
1. RSI-0（§4）已证：让 System-2 **单独以概率性输出承担框架级结构正确性**必走编译失败—修复循环。确定性基础设施的意义正在于**消解**这份不确定性，而非禁用 LLM 写码。
2. 但若 System-2 不直接承担结构正确性，而是**把"要做什么变更"拆成确定性工具调用序列**，则每一步都变成"选工具 / 选模板 / 填参数 / 验结果"的**有限分类与打分**——这正是 System-1 的定义域。
3. 因此 RSI 自进化循环里"可结构化的决策"可由 System-1 承接，**降低**对 System-2 的依赖；System-2 从重复的确定性决策中解放，专注其擅长的不确定性任务，仅作为**低置信度升级通道**保留。

### 7.3 可行性映射：ASR 确定性代码开发工作流 → Laya 原语

| 代码开发步骤 | 决策类型 | Laya 原语 | 备注 |
|---|---|---|---|
| 选择变更操作（加表/加字段/标准 CRUD/标准 Web 页/生成插件/卸载插件） | 分类 | choice | ≤6 类，远在 32 上限内 |
| 选择目标模块（从 `src/app/*`、`src/plugin/*` 目录） | 分类 | choice + `laya_shortlist` | 模块目录大时用两阶段预筛 |
| 选择模板/脚手架（crudgen 模板 / plugingen `mode=sync\|dylib\|process`） | 分类 | choice | plugingen 默认 process（L3） |
| 字段/参数取值判定（某字段是否必填、类型、约束对齐规范） | 打分/判定 | score / noul | 对照 `docs/uctoo-v4/*` 规范 |
| 生成结果正确性核验（编译通过？保护区未破坏？规范对齐？） | 判定 | noul / score | 接 build watcher 绿条信号 |
| 防回退判定（是否引入回归 / 破坏既有接口） | 判定 | noul | 接 ExecutionEvidenceRecorder |
| 是否自动执行 / 复核 / 升级 | 阈值门控 | confidence | auto(≥0.95) / review / escalate(<0.7) |

**关键观察**：上表中真正需要 System-2 的"推理残留"只剩两处——① 把用户自然语言需求翻译成"要做什么变更"（需求理解）；② 置信度 <0.7 时升级人工/强模型。其余均可由 System-1 闭环。**这正是"以确定性 + System-1 消解 LLM 不确定性"的落地形态：LLM 不被去除，而是与确定性工具、System-1 分层协作。**

### 7.4 与 RSI-0（确定性死路）的一致性

System-1 **不生成代码**，只生成"调用确定性工具的决策"。这与 Iron Law RSI-0（框架级确定性优先由确定性工具保障、LLM 不确定性被消解）**完美契合、且加固**：
- System-2 单独以概率性输出承担结构正确性 → 失败（§4 实证）。
- System-1 驱动确定性工具 → 产出确定性可用代码（工具链保证）。
二者不冲突，反而构成"双层去风险"：System-1 负责结构化决策、确定性工具负责代码正确性，System-2 在需要推理/创造的环节与升级通道出现。**三者分层协作，而非相互替代。**

### 7.5 System-1 承接的范围与边界（避免过度承诺）

System-1 可大规模承接 **仅在"变更类型落在确定性工具覆盖范围内"成立**：

- **覆盖内（可由 System-1 + 确定性工具闭合）**：加表/加字段、标准 CRUD、标准 Web 页、标准插件脚手架（默认 L3 process）、插件卸载、规范对齐的增量。
- **覆盖外（仍需 System-2 或人工）**：全新非标准架构、跨模块复杂重构、需求歧义、低置信度（<0.7）升级、UMI-ORM 尚未实现的 schema 演进深水区（见 §6 短板）。

三态执行（auto/review/escalate）天然映射：高置信 → 自动执行确定性工具；中置信 → 走 SDD 流水线 + 人在回路闸口；低置信 → 升级 System-2/人工。

### 7.6 对 RSI 架构的影响：代码腿可由 System-1 与确定性工具承接，降低对 System-2 的依赖

此前 RSI design.md 的代码腿默认 LRT 五环节（实测→根因→优化方案→防回退→约束注入）由 System-2 驱动（根因分析、优化方案生成）。若 7.2 命题成立：
- LRT 的"根因分析→优化方案"中**可结构化的部分可下沉为 System-1 判定序列**（哪类故障？哪条确定性工具可修？参数如何填？），System-2 退居升级通道，专注真正需要推理的环节。
- 这进一步拉开与同业差距：OC/HM/DSH 的 RSI 第二层（模型自扩充）**全部依赖推理型 LLM**；ASR 可把自进化循环中**可结构化的决策交由 System-1**，使 System-2 不再被重复的确定性决策消耗——这不是"去 LLM"，而是**把合适的子系统特性交给合适的组件**，让 LLM 专注其不可替代的不确定性智能。

### 7.7 与 laya-system1-integration 工程的衔接（新增需求）

该工程 10 个决策点映射（spec.md §2）中，#4 循环停滞检测、#5 完成核验直接对应 RSI 的 LRT 验证环；#2 工具风险门控对应 RSI 护栏。但**该工程未覆盖"代码生成决策点"**——这正是 RSI 的新增需求：
- 在 `skills/system1-decision`（该工程 appendix A.1 模板）基础上派生 **`skills/RSI-system1`** 决策技能，新增"选择工具 / 模板 / 参数 / 正确性核验"四类决策面。
- RSI 的 LRT 五环节验证环直接复用 Laya 的 `laya noul` 做"完成核验"与"防回退判定"（对应原工程决策点 #5/#4）。

### 7.8 风险与 PoC 建议（呼应 laya spec §5）

| 风险 | 缓解 |
|---|---|
| 校准漂移 | 域内重新拟合温度（Phase 0 `eval_report.md` 做中文/代码场景校准基线） |
| 选项上限（≤32/次） | 大模块目录用 `laya_shortlist` 两阶段预筛 |
| 中文覆盖 | multilingual checkpoint 重点验证中文意图/工单；必要时微调 `laya-typed-decisions` |
| 能力边界 | System-1 不生成文字，开放生成一律交 System-2 升级通道 |
| 跨语言运维 | Laya(Python) 经 MCP 子进程 / `laya[serve]` HTTP 接入，或 Phase 3 走 ONNX 固化 |

**最小 PoC 提议**：选 §4 已实证的"数据库加一个字段"场景（最易暴露 LLM 概率性生成风险的极小变更），用 Laya 决策驱动 `loaddbinfo → crudgen → crudweb`，验证 **在 System-2 仅作升级通道、不主导变更决策的条件下**能否完成确定性代码变更且通过自动化编译绿条。若通过，则 7.2 命题获首个实证支点。

---

## 8. 超越业界最佳实践的方案（建议摘要，详细见 design.md §超越业界最佳实践）

1. **确定性优先的 RSI（核心差异化）**：把"框架级确定性优先由确定性代码生成工具保障、LLM 不确定性被消解"从注释提升为**设计原则**——RSI 自动变更受 Human-Code Preservation 护栏约束（不得覆盖保护区中的人工代码），框架级结构正确性由确定性工具保障，LLM 在需要的流程与位置仍生成代码（胶水逻辑、非标准实现等）。同业停在"技能文本层"，ASR 可推进到"确定性工具驱动的源码层"。
2. **代码+技能+数据库三腿闭环**：补全 UMI-ORM 这条 DB 腿，使 schema 变更能确定性地联动 ORM/CRUD/Web，形成完整闭环（同业只有技能腿或代码腿）。
3. **多技能并行作为 RSI 基底**：将 RSI 实现为 `src/skill/parallel` 的并行技能组合（分析失败构建 / 起草 spec / 生成代码 并发），受 budget/conflict 管控。
4. **LRT 心跳调度**：RSI 注册为原生 LRT scheme（类 `sdd://`），支持周期/事件触发五阶段循环（实测→根因→优化方案→防回退→约束注入），并扩展到 DB 腿。
5. **验证即闸口**：RSI 每次变异必过 SDD 流水线 + 自动化编译（watcher）绿条 + 测试，才被接受——把 RSI 从"建议改动"升级为"提出已验证的 PR"。
6. **开放标准领导力**：把"自进化"作为 agentskills 开放标准的能力声明，把 ASR 差异化变成行业标准。

---

## 9. 研究步验收（acceptance_criteria）

- [x] 产出 `specs/RSI/research.md` 且九节齐全（目标/证据/结论1-5/建议/验收）
- [x] 结论均有可核验证据（路径或出处），无编造
- [x] 明确给出 RSI 语义边界、确定性死路论证、同业基线、存量盘点、超最佳实践建议
- [x] 新增核心结论五：Laya System-1 承接确定性代码开发中的结构化决策、降低对 System-2 依赖的设想（含可行性映射、范围边界、架构影响、PoC 提议；措辞已按"消解 LLM 不确定性而非去 LLM"校准）
- [x] 指出最大短板（UMI-ORM 未完整实现）与专题化时机已到
- [ ] 待 `gate-research` 闸口 confirm
