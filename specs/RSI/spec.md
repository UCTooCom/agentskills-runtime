# 需求规格：ASR 自进化系统（RSI）

> 阶段：spec
> 工程：`specs/RSI`
> 上游：`research.md`（已 confirm）
> 模板：`skills/sdd/templates/spec_template.md`
> 落库：`long_running_task_artifact`(usage=deliverable, stage=spec)
> 日期：2026-10-17 · 版本 v0.1 · 状态：草稿（待闸口 confirm）

---

## 1. 组件定位（Component Positioning）

RSI（Recursive Self-Improvement，递归自进化）是 ASR 的**一级能力子系统**，定位为"AI 驱动开发框架"的方法论执行中枢。它不是一个独立服务，而是**对既有基础设施的编排层 + 一条强制约束（确定性优先）**：

- **编排对象**：确定性代码生成工具（loaddbinfo/crudgen/crudweb/plugingen/pluginuninstall）、SDD 流水线、多技能并行子系统、LRT 长程任务子系统、一切皆技能插件机制、UMI 数据架构。
- **强制约束（Iron Law RSI-0）**：框架级确定性优先由确定性代码生成工具保障，以系统工程的确定性消解 LLM 在框架级变更中的不确定性；LLM 仍在需要的流程与位置生成代码（胶水逻辑、非标准实现等），只是不再让其概率性输出单独承担框架级结构正确性。这是 ASR 相对所有同业 harness 的根本分水岭——不是"去 LLM"，而是让合适的子系统特性由合适的组件提供（详见 `research.md` §4）。
- **交付形态**：一个可复用技能 `skills/RSI`，把《人工智能软件工程方法论》从理论到实践完整落地。

RSI 服务于"让开发框架在运行中持续进化（代码+技能+数据库三大基础设施闭环），且架构不腐坏、对二次开发友好"这一产品级目标。

---

## 2. 领域术语（Domain Glossary）

| 术语 | 定义 |
|---|---|
| RSI | Recursive Self-Improvement，递归自进化；此处特指 ASR 三大基础设施（代码/技能/数据库）的闭环自进化能力 |
| 确定性代码生成工具 | `loaddbinfo`/`crudgen`/`crudweb`/`plugingen`/`pluginuninstall`，产出确定性可用的框架代码，是 RSI 的"框架之手" |
| 一切皆技能 | ASR 插件机制：每个能力以 `SKILL.md` + `plugin.yaml` 声明，被 `SkillToToolAdapter` 映射为 LLM 可见 Tool，实现原生智能 |
| UMI | 全栈模型同构（Unified Model Isomorphism），以数据库结构为单一事实源驱动多端一致代码生成 |
| UMI-ORM | UMI 的 ORM 实现（atomgit 开源骨架），数据库自进化腿，尚待完整实现 |
| Human-Code Preservation | 代码保护区：自定义代码写在 `//#region Human-Code Preservation` 内，生成器不覆盖，对二次开发友好 |
| 多技能并行 | `src/skill/parallel/*`，多个技能可被同时注入/执行并受预算与冲突管控 |
| LRT | Long Running Task，长程任务子系统，提供异步多轮执行与调度，是 RSI 的心跳 |
| SDD | 规范驱动开发（六步流水线 + 人在回路闸口 + git SOP），RSI 的变更治理通道 |
| 五阶段循环 | RSI 心跳循环：实测 → 根因 → 优化方案 → 防回退 → 约束注入 |

---

## 3. 角色与边界（Actors & Boundaries）

**角色**
- **RSI 编排者（LLM 为脑）**：基于 `skills/RSI` 规划自进化目标、选择工具、拼装胶水代码。
- **确定性工具（框架之手）**：实际产出/改写代码，保证编译可用。
- **人在回路审核者**：在 SDD 闸口与 git SOP 处确认/打回每一次自进化。
- **调度器（LRT）**：周期/事件触发 RSI 循环。

**边界（明确不提供什么）**
- RSI **不接管框架级结构的手写**：框架级确定性由确定性工具保障，LLM 仍在需要的流程与位置生成胶水逻辑与非标准实现（Iron Law RSI-0 落地）。把框架级结构正确性交给 LLM 概率性输出单独承担的越界动作被护栏拦截。
- RSI **不取代人工架构决策**：破坏性变更必须走 SDD 闸口 + 人工 confirm。
- RSI **不覆盖 Human-Code Preservation 保护区内的用户代码**；保护区外由确定性工具生成的代码可重生成。RSI 默认只增不改既有逻辑，破坏性改写须经 SDD 显式确认。
- RSI **不改动生产数据**：数据库自进化只涉及 schema/结构层，数据迁移走既有迁移工具。
- RSI **不越权改其他子系统私有表/私有目录**（遵循 SDD 铁律 15 契约边界）。

---

## 4. DFX 约束（质量属性）

| 维度 | 约束 |
|---|---|
| 可靠性 | 任意一次 RSI 变异在纳入版本管理前**必须**通过：确定性工具生成（无手改源码）+ 自动化编译绿条 + （用户确认）测试通过；失败变异可一键回滚 |
| 安全性 | RSI 动作受 SDD 闸口 + 权限矩阵约束；越界手写源码被护栏硬拒；敏感配置走 SecretCrypto |
| 可维护性 | 所有 RSI 变异留痕（SDD 六步文档 + `sub_agent_invocations` + git 提交绑定 `feature_name`/`stage`），可逐闸口回放 |
| 性能 | RSI 循环默认异步（LRT），不阻塞在线请求；多技能并行受 `budget_manager` 管控，防上下文爆炸 |
| 兼容性 | 严守 UMI 同构与 uctoo-v4 规范；生成物与既有五层结构一致；跨端（web/app/服务端）一致 |
| 可观测 | 每次循环产出结构化日志（实测指标/根因/方案/防回退锚点），经 stderr/SSE 上报，不污染 L3 stdout |

---

## 5. 核心能力（Core Capabilities，EARS 验收）

> EARS 语法：*When <触发>, the system shall <响应>.* / *The system shall <响应>.* / *If <条件>, then the system shall <响应>.*

- **C1 自进化目标规划**
  - When RSI 收到自进化目标（自然语言），the system shall 解析为"代码/技能/数据库"三腿中至少一项的可执行计划，并标注拟调用的确定性工具链。
- **C2 代码层确定性改写**
  - When RSI 需变更框架源码（新增表/列/接口/插件），the system shall 调用 `loaddbinfo → plugingen|crudgen → crudweb` 工具链生成确定性部分，且 shall not 让概率性输出单独承担框架级结构正确性（框架级确定性由确定性工具保障，LLM 不确定性被消解；Iron Law RSI-0）。
- **C3 技能层自进化**
  - When RSI 需新增/修订能力描述，the system shall 经 `sdd` 流水线产出/修订 `spec/design/tasks` 与 `SKILL.md`，并经闸口确认后由"一切皆技能"机制即时暴露给 LLM。
- **C4 数据库层自进化（目标态）**
  - If UMI-ORM 已就绪，then when RSI 需演进数据模型，the system shall 以 schema 为单一事实源确定性地联动 ORM/CRUD/Web 三端；If UMI-ORM 未就绪，then the system shall 至少经 UMI 架构保证多端一致，并显式标注 DB 腿为"部分能力"。
- **C5 多技能并行执行**
  - When 单次循环含多个可并行子任务（分析/起草/生成），the system shall 经 `src/skill/parallel` 并行调度并受预算与冲突管控。
- **C6 LRT 心跳调度**
  - The system shall 支持将 RSI 注册为 LRT scheme，按周期或事件（如"构建失败""新需求到来"）触发五阶段循环。
- **C7 验证即闸口**
  - When RSI 完成一次变异，the system shall 先经自动化编译（build watcher）绿条 + SDD 测试步，方可被 git 纳入版本管理；编译失败或测试未过则变异被丢弃/回滚。
- **C8 防回退与约束注入**
  - When RSI 采纳一个优化方案，the system shall 写入防回退锚点（测试/契约）并将新约束注入规范（uctoo-v4 / uctoo-dev-manual），防止同类问题复发。
- **C9 原生智能感知**
  - The system shall 保证每次自进化后新增能力经"一切皆技能"机制自动进入 LLM 可见 Tool 列表，无需人工重新注册。
- **C10 开放标准声明（展望）**
  - The system shall 在 `plugin.yaml`/agentskills 开放标准中声明 `self-evolution` 能力项，使 ASR 的 RSI 可被外部运行时探测。
- **C11 System-1 可选驱动（弱化 System-2 依赖，非去 LLM）**
  - When 一次自进化的决策可被结构化（选工具 / 填参数 / 验结果），the system may 由 System-1 判断引擎（Laya choice/score/noul）承接该结构化决策，以降低对推理 LLM（System-2）的依赖；If 置信度低于阈值或涉及歧义/新架构，then the system shall 升级至 System-2 或人工。LLM 仍在需要的流程与位置生成代码（胶水/非标准实现），只是不再由其概率性输出单独承担框架级结构正确性（对应 `research.md` §7）。

---

## 6. 数据约束（Data Constraints）

- RSI 复用既有七张白名单表（`agent_tasks` / `long_running_task_artifact` / `sdd_projects` / `sub_agent_invocations` / `agent_approvals` / `agent_contexts` 等），**不新增白名单表**（遵循铁律 9 复用优先；RSI 是编排层，非新存储域）。
- 若确需持久化 RSI 专属元数据（如五阶段循环的运行态、防回退锚点索引），优先落入既有 `config`/`payload` JSON 字段或 `long_running_task_artifact`（usage=trace），仅在复用明显不成立时论证新建（见铁律 9）。
- 数据库自进化只改结构层（DDL 入 `sql/incremental/`），不动业务数据；迁移走既有迁移工具，保证 dev/staging/prod 可复现。
- 所有 RSI 变异的文档产物落 `specs/RSI/`（铁律 1），不落 `.codeartsdoer/specs/`。

---

## 7. 需求验收对照（spec → research 溯源）

| spec 条目 | 研究依据 |
|---|---|
| §1 组件定位 / RSI-0 | research §3（三层闭环）、§4（确定性死路实证） |
| §2 术语 | research §2 证据清单 |
| §3 边界 | research §5（同业边界共识）、§4（确定性优先、以系统工程的确定性消解 LLM 不确定性） |
| §4 DFX | research §6（存量盘点）、§7（验证即闸口） |
| §5 C1–C10 | research §3/§7 全部建议 |
| §6 数据约束 | research §6（复用优先、UMI-ORM 缺口） |
