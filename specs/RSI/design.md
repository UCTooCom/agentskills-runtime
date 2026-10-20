# 设计方案：ASR 自进化系统（RSI）

> 阶段：design
> 工程：`specs/RSI`
> 上游：`research.md`(confirm) + `spec.md`(confirm)
> 模板：`skills/sdd/templates/design_template.md`
> 落库：`long_running_task_artifact`(usage=deliverable, stage=design)
> 日期：2026-10-17 · 版本 v0.1 · 状态：草稿（待闸口 confirm）

---

## 1. 需求与存量功能关系分析（已实现 / 需扩展 / 需新增 对比表）

| 能力（对应 spec §5） | 存量基础设施 | 状态 | 本设计动作 |
|---|---|---|---|
| C2 代码层确定性改写 | `src/app/tools/{loaddbinfo,crudgen,crudweb}`、`src/plugin/tools/{plugingen,pluginuninstall}` | 已实现 | 复用，作为 RSI 的"框架之手"；新增**护栏**：拦截把框架级结构正确性交给 LLM 概率性输出单独承担的越界动作 |
| C3 技能层自进化 | `skills/{sdd,uctoo-dev-manual}`、SDD 六步 + 闸口 + git SOP | 已实现 | 复用 SDD 为 RSI 变更治理通道 |
| C5 多技能并行 | `src/skill/parallel/*`（auto_injector/task_matcher/budget_manager/conflict_filter/profile_skill_resolver） | 已实现 | 复用为 RSI 并发执行基底 |
| C6 LRT 心跳 | `src/app/services/lrt/`、`src/skill/lrt_composition_runner.cj`、`long_running_task_tool.cj` | 已实现 | 复用，RSI 注册为原生 scheme |
| C9 原生智能感知 | `src/plugin/`、`SkillToToolAdapter`、一切皆技能机制 | 已实现 | 复用，RSI 产出经此即时暴露 |
| C1 自进化目标规划 | —（分散在各技能 SOP） | **需新增** | `skills/RSI` 技能本体：方法论 SOP + 三腿规划器 |
| C4 数据库层自进化 | UMI 架构（`docs/uctoo-v4/uctoo-database-design-*.md`）；UMI-ORM（atomgit 开源骨架，**未完整实现**） | **部分/需扩展** | 补齐 UMI-ORM 这条 DB 腿（见 §6）；在就绪前 C4 降级为"UMI 多端一致 + 显式标注部分能力" |
| C7 验证即闸口 | 自动化编译 watcher（昨日落地）；SDD 测试步 | 已实现（组件） | **需扩展**：把 watcher 绿条 + 测试步串成 RSI 的"接受判据"强制链 |
| C8 防回退与约束注入 | SDD 修订记录、契约优先；无专门锚点机制 | **需扩展** | 新增"防回退锚点"规范：每次采纳方案必写测试/契约锚点并回流规范 |
| C10 开放标准声明 | agentskills 开放标准（现有 plugin 能力项） | **需新增** | 在标准中加入 `self-evolution` 能力声明 + 探测接口 |

> 结论：RSI **不重新实现任何已有能力**，纯编排 + 三处补强（RSI 技能本体 / UMI-ORM DB 腿 / 防回退锚点 + 验证强制链 / 开放标准声明）。符合 SDD 铁律 9、14。

---

## 2. 实现模型（RSI 闭环架构）

### 2.1 五阶段循环（RSI 心跳）

```
        ┌─────────────────────────────────────────────┐
        │            RSI 五阶段自进化循环              │
        │                                             │
  ① 实测 ──► ② 根因 ──► ③ 优化方案 ──► ④ 防回退 ──► ⑤ 约束注入
   │                                                    │
   └──────────────── 反馈（下一轮触发）◄───────────────┘
        │
   触发源：周期(LRT) / 事件(构建失败·新需求·缺陷复盘)
```

- **① 实测**：采集指标（编译结果、测试覆盖率、契约漂移、复用率、二次开发冲突率）。来源 = build watcher 日志 + `long_running_task_artifact` + SDD 缺陷分级。
- **② 根因**：LLM 分析实证数据，定位"为何未达预期"，输出根因假设（此阶段只定位根因，不产出源码）。
- **③ 优化方案**：LLM 规划"调用哪些确定性工具 + 拼装哪些胶水代码"，产出方案文档 + 胶水代码片段（确定性工具覆盖不到处，由 LLM 在需要的流程与位置生成）；框架级结构由 `loaddbinfo/crudgen/crudweb/plugingen` 确定性生成。例如：新增一张表 → `loaddbinfo` 灌结构 → `crudgen`+`crudweb` 生成 → 写 `SKILL.md` 暴露能力。
- **④ 防回退**：将方案转 SDD 任务，**必须**附带防回退锚点（测试/契约/规范条目），否则任务被打回。
- **⑤ 约束注入**：方案采纳后，把新约束回流 `uctoo-v4` 规范 / `uctoo-dev-manual`，使同类问题不再复发。

> **关键约束（Iron Law RSI-0 落地）**：③ 的"胶水代码"来自确定性工具输出 + Human-Code Preservation 区内的手写；**任何 RSI 自动变更不得覆盖 Human-Code Preservation 保护区中的人工代码，框架级结构正确性由确定性工具保障（LLM 不确定性被消解，而非禁用 LLM 写码）**。

### 2.2 三腿闭环（代码 / 技能 / 数据库）

```
   数据库结构(schema)
        │ ① UMI/UMI-ORM 确定性生成
        ▼
   ORM + 五层 CRUD（crudgen/crudweb）
        │ ② 管理界面（crudweb）
        ▼
   Web/App 多端一致代码
        │ ③ 能力声明（SKILL.md + plugin.yaml）
        ▼
   LLM 可见 Tool（一切皆技能 / SkillToToolAdapter）
        │ ④ 模型基于新能力规划下一轮演进
        ▼
   回到 ①（闭环）
```

三腿任一层变化都触发另外两层的确定性联动——这是 ASR 相对"技能单腿进化"同业的本质差异。

### 2.3 `skills/RSI` 技能本体（交付物形态）

`skills/RSI/SKILL.md` 是 RSI 的可执行载体，内部编排：
1. **方法论 SOP**（固化《人工智能软件工程方法论》三支柱与 RSI-0 约束）；
2. **三腿规划器**（解析目标 → 判定走代码腿/技能腿/DB 腿 → 选工具链）；
3. **工具调用编排**（串接 loaddbinfo/plugingen/crudgen/crudweb/pluginuninstall/sdd/long-running-task）；
4. **护栏**（拦截把框架级结构正确性交给 LLM 概率性输出单独承担的越界动作、强制防回退锚点、强制验证闸口）；
5. **多技能并行声明**（自身声明为可被 `src/skill/parallel` 并行调度的技能）；
6. **LRT scheme 注册说明**（如何以 `rsi://` scheme 周期/事件触发）；
7. **System-1 可选承接声明**（对应 §2.4）：在"选工具/填参数/验结果"等结构化决策点，可由 Laya 判断引擎驱动，降低对推理 LLM 的依赖，而非移除 LLM。

### 2.4 代码腿的 System-1 承接（Laya 集成，可选加速）

> 本节对应 `research.md` §7。目的：把此前"去 LLM / 去 System-2"的错误表述纠正为 **"由合适组件做合适的事"**——并非移除 LLM，而是把"结构化决策"交给 System-1，降低对 System-2 的依赖，三者分层协作（详见 `docs/ref/AIDrivenArchitecture.md` 的"确定性优先，AI 增强"原则）。

ASR 的确定性代码生成工具早已把"写框架代码"这一不确定任务，转化为"调用哪工具 + 传什么结构化参数 + 什么顺序"的**结构化决策序列**。而"结构化决策"正是 System-1 判断引擎（Laya 的 `choice/score/noul` 原语，带校准置信度、不生成文字、可本地/离线、MCP 接入）的定义域。于是：

- 选操作 / 模块 / 模板 = Laya `choice`；
- 字段 / 参数取值 = Laya `noul` / `score`；
- 正确性核验 / 防回退 = Laya `noul`；
- 三态门控 = Laya 校准置信度（高 → 自动执行；中 → 提示人工；低 → 升级 System-2 / 人工）。

**范围与边界**（避免过度承诺）：覆盖内（加表 / 字段 / 标准 CRUD / Web / 插件脚手架 / 卸载）可由 System-1 闭合；覆盖外（新架构 / 复杂重构 / 歧义需求 / UMI-ORM 深水区）仍须 System-2 或人工。**System-2 仍保留于需求理解与低置信升级——LLM 仍在需要的流程与位置生成代码，只是不再由其概率性输出单独承担框架级结构正确性。**

这与 Iron Law RSI-0 一致而非冲突：System-1 不 emit 源码、只 emit"调工具的决策"，确定性工具负责代码正确性，三者分层协作。工程底座见 `.codeartsdoer/specs/laya-system1-integration/`。

---

## 3. 接口设计（RSI 对外契约）

RSI 作为编排层，**不新增 HTTP 路由**，复用既有入口：

| 能力 | 复用入口 | 说明 |
|---|---|---|
| 触发自进化 | `POST /api/v1/uctoo/sdd/start` + `run`（scheme=`rsi://<goal>`） | 将自进化目标作为 SDD 工程提交，由 LRT 调度 |
| 提交长程循环 | `LongRunningTaskTool.submitTask`（goal=RSI 目标） | 异步多轮，见 `long_running_task_tool.cj` |
| 能力即时暴露 | `SkillToToolAdapter` + `pluginInspect/activate/refresh` | 新生成技能/插件经此进 LLM 可见列表 |
| 验证闸口 | build watcher + `gate-code`/`gate-test` | 编译绿 + 测试过才接受变异 |
| 人在回路 | SDD `review` 接口 + `agent_approvals` | confirm/revise/abandon |

> RSI 仅通过**既有接口的组合**工作，不引入新攻击面；符合 SDD 铁律 14、铁律 9。

---

## 4. 数据模型

- **不新增白名单表**（铁律 9 复用优先）。
- RSI 运行态（五阶段进度、防回退锚点索引）落入：
  - `long_running_task_artifact`（usage=trace，记录每阶段产物与指标）；
  - `sdd_projects`（每个自进化目标 = 一个 SDD 工程，含 `current_stage`/`round`）；
  - 防回退锚点以**引用**形式写入对应 `specs/RSI/*.md` 与 `docs/uctoo-v4/*` 规范，不另建存储。
- DB 腿演进的 DDL 一律入 `sql/incremental/`，走既有迁移，保证多环境可复现。

---

## 5. 进度可观测

- 五阶段每阶段产出结构化日志（实测指标/根因/方案/锚点），经 stderr/SSE 上报；L3 进程 stdout 专用于 stdio RPC（铁律 11）。
- RSI 工程进度在 `sdd_projects` 可见，可经 `GET /sdd/status` 查询。
- 每次循环形成一份 `test-report.md` 风格复盘（一致性 + 缺陷 P0–P2 + 防回退锚点清单）。

---

## 6. 人在回路（Human-in-the-Loop）

- 每个自进化目标 = 一个 SDD 工程，必经 `gate-spec / gate-design / gate-task / gate-code` 五选一三态（confirm/revise/abandon）。
- **破坏性变更**（改契约、删表、改生成器模板）必须人工 confirm，RSI 不得自动采纳。
- 验证闸口：编译未绿 / 测试未过 → 变异丢弃或回滚，不入库（git SOP 禁区）。
- 二次开发友好：Human-Code Preservation 区外的既有手写代码，RSI 默认不碰。

---

## 7. 防回退约束

| 风险 | 约束 |
|---|---|
| LLM 越界手写框架源码 | Iron Law RSI-0 + 护栏：检测生成区外的源码 emit，硬拒并告警 |
| 变异未验证即入库 | 强制链：build watcher 绿条 + SDD 测试步 = 接受判据；否则不 commit |
| 同类问题复发 | 每次采纳方案必写防回退锚点（测试/契约）+ 回流 uctoo-v4 规范 |
| 架构漂移 | 所有生成物遵循 UMI 同构 + uctoo-v4 五层；SDD 复用优先，禁重复实现 |
| DB 腿半成品被误用为全能力 | C4 在 UMI-ORM 就绪前显式标注"部分能力"，不夸大 |
| 多技能并行失控 | 经 `src/skill/parallel` 的 budget/conflict 管控，不裸跑并发 agent |

---

## 8. 超越业界最佳实践的方案（重点交付项）

以下为本次 SDD 相对 deepseek-harness / openclaw / hermes-agent 的**增量设计**，均建立在已核验存量上：

### 8.1 确定性优先的 RSI（核心差异化，同业无）
同业把自进化限制在"技能文本层"（openclaw 的 skill_workshop、hermes 的 background_review 均只写 memory/skill，DSH 连这都无）。ASR 独有确定性代码生成工具，故可把边界**推进到"确定性工具驱动的源码层"**：
- 把 RSI-0（框架级确定性优先由确定性工具保障，以系统工程的确定性消解 LLM 不确定性）从注释提升为**可执行护栏**（静态检测 + 运行期拒绝"把框架级结构正确性交给 LLM 概率性输出单独承担"的越界动作）。
- 收益：消除"编译失败—修复"循环对框架演进的阻塞（你一线实证结论），保证**架构不腐坏**；同时 LLM 仍在需要的流程与位置生成胶水/非标准实现，并非"去 LLM"。

### 8.2 代码+技能+数据库三腿闭环（同业只有单/双腿）
- openclaw/hermes/DSH 的自进化基本停在技能层；ASR 补齐 **DB 腿（UMI-ORM）**，使 schema 变更确定性联动 ORM/CRUD/Web。
- 建议排期：先以 UMI 架构多端一致兜底（当前已具备），再分阶段补全 UMI-ORM 生成器，最终形成完整三腿闭环。

### 8.3 多技能并行作为 RSI 基底
将一次 RSI 循环拆为可并行子任务（分析失败构建 / 起草 spec / 生成代码 / 写测试），经 `src/skill/parallel` 并发调度，受 `budget_manager` + `conflict_filter` 管控。同业（如 openclaw 的 background_review 分叉）多为单线后台，ASR 可做到**受控并发自进化**。

### 8.4 LRT 心跳调度（周期/事件触发）
RSI 注册为原生 LRT scheme（`rsi://<goal>`），支持：
- 周期触发（如每 N 轮后台自评，对标 openclaw `autonomous.mode: auto` / hermes `background_review`）；
- 事件触发（构建失败、新需求、缺陷复盘）。
把"自进化"从"人工点一下"升级为"框架自主心跳"。

### 8.5 验证即闸口（把 RSI 从"建议"升级为"已验证 PR"）
串接：确定性工具生成 → build watcher 绿条 → SDD 测试步 → git 纳入版本管理（绑定 `feature_name`/`stage`）。每一次自进化都是**可回放的已验证变更**，而非飘在对话里的建议。

### 8.6 开放标准领导力
在 agentskills 开放标准中新增 `self-evolution` 能力声明 + 探测接口，使"AI 驱动开发框架"的差异化成为**行业标准**，反向牵引生态。

### 8.7 System-1 承接与双驱动框架（在同业之上的额外差异化）
- **System-1 承接**（对应 §2.4）：把确定性代码开发的"结构化决策"（选工具 / 填参数 / 验结果）交由 Laya 等判断型引擎驱动，降低对推理 LLM（System-2）的依赖——**降低依赖而非移除 LLM**。这是比同业"第二层全依赖推理 LLM"更精细的分层协作：确定性工具做确定的事、System-1 做结构化判断、System-2 做推理与创造，各司其职。
- **双驱动框架**：ASR 有 AI 是 AI 驱动开发框架，无 AI 仍是完备框架（CRUD / 权限 / 同步 / 调度照常）；同业 harness 无 AI 即瘫。这是 ASR 被称为"AI 驱动开发框架超越 harness"的底层原因，也是 RSI 能在"推理 LLM 低参与"时仍可借 System-1 + 确定性工具推进演进的根基（详见 `docs/ref/AIDrivenArchitecture.md`）。

---

## 9. 实施分期（落地节奏建议）

- **P0（本周可落地）**：`skills/RSI` 技能本体 + RSI-0 护栏 + 复用 SDD/LRT/parallel 串起代码腿与技能腿闭环。
- **P1（补齐 DB 腿）**：UMI-ORM 生成器补全（schema→ORM/CRUD/Web 确定性联动），C4 由"部分能力"升级为"全能力"。
- **P2（专题完善）**：防回退锚点规范固化、验证强制链、开放标准 `self-evolution` 声明、周期/事件触发心跳；**System-1 承接 PoC**（见 §2.4）：以"数据库加一个字段"最小场景，用 Laya 决策驱动 `loaddbinfo → crudgen → crudweb`，验证在 System-2 低参与下完成确定性变更并通过编译绿条。

---

## 10. 风险与已知偏差

- **UMI-ORM 资源约束**：DB 腿完整实现需额外人力，P0 阶段 C4 以 UMI 多端一致兜底并显式标注部分能力（不夸大）。
- **确定性工具覆盖盲区**：若某变更确定性工具无法生成（如复杂算法逻辑），须走 Human-Code Preservation 区手写 + SDD 人工 confirm，不得强行由 LLM 生成。
- **并行失控**：严格依赖 `src/skill/parallel` 的预算/冲突管控，禁止裸并发。
- **System-1 置信度误判**：Laya `noul`/低置信升级阈值需灰度标定；覆盖外（新架构/复杂重构/歧义）必须升级 System-2 或人工，禁止 System-1 越界 emit 源码。LLM 仍在需要的流程与位置生成代码，确定性工具负责框架级结构正确性。
