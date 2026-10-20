# 任务规划文档：ASR 自进化系统（RSI）

> 阶段：task
> 工程：`specs/RSI`
> 上游：`research.md`(confirm) + `spec.md`(confirm) + `design.md`(confirm)
> 模板：`skills/sdd/templates/tasks-template.md`
> 落库：`long_running_task_artifact`(usage=deliverable, stage=task)
> 日期：2026-10-17 · 版本 v0.1 · 状态：草稿（待闸口 confirm）

---

## 文档信息
- 关联需求：`spec.md`
- 关联设计：`design.md`
- 生成日期 / 版本 / 状态：2026-10-17 / v0.1 / 草稿

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：技能/文档（Markdown/YAML）→ 主 agent 直接编写；仓颉宿主代码（若护栏需宿主侧实现）→ 加载 `cangjie-coder`；前端 → `web-coder`。
- **编译约束（铁律）**：**AI 严禁运行 `cjpm build`**；编译/类型检查由人工在独立 cmd 环境执行并回传结果。本任务清单中所有"生成/编写"动作产出文档与源码后，由人工编译验证。
- **二次开发底座优先（铁律 14）**：RSI 是**编排层 + 新技能**，不重复实现既有能力（loaddbinfo/crudgen/crudweb/plugingen/pluginuninstall/sdd/long-running-task/parallel 全部复用）。仅当确需宿主侧新代码（如 RSI-0 护栏校验器）时，优先 `plugingen`（做成插件，默认 L3 process 轨）；生成物上做最小适配。
- **确定性优先（Iron Law RSI-0）**：框架级确定性优先由确定性工具链保障；LLM 仍在需要的流程与位置生成代码（胶水逻辑、非标准实现、保护区手写等），只是概率性输出不单独承担框架级结构正确性（以确定性基础设施消解 LLM 不确定性，而非去 LLM）。
- **复用优先（铁律 9）**：不新增白名单表；运行态落 `long_running_task_artifact`/`sdd_projects`/规范文档。
- **人在回路（铁律 12/16）**：破坏性变更须 SDD 闸口 confirm；编译绿 + 测试过才 git 入库，提交绑定 `feature_name=RSI` 与 `stage`。

---

## 任务总览

| 编号 | 任务 | 关联 spec | 关联 design | 语言/产物 | 状态 |
|---|---|---|---|---|---|
| T-01 | 编写 `skills/RSI/SKILL.md` 技能本体（方法论 SOP + 三腿规划器 + 工具编排） | C1,C3,C9 | §2.3 | Markdown | 待开始 |
| T-02 | 实现 RSI-0 护栏（拦截"把框架级结构正确性交给 LLM 概率性输出单独承担"的越界动作） | C2 | §7,§8.1 | 校验器(宿主/插件) | 待开始 |
| T-03 | 串接 LRT：RSI 注册为原生 scheme（`rsi://<goal>`）+ 周期/事件触发 | C6 | §2.1,§8.4 | 配置/SOP | 待开始 |
| T-04 | 复用多技能并行：声明 RSI 为可并行技能 + 子任务拆分 SOP | C5 | §8.3 | Markdown/SOP | 待开始 |
| T-05 | 验证强制链：build watcher 绿条 + SDD 测试步 接入 RSI 接受判据 | C7 | §6,§8.5 | 编排/SOP | 待开始 |
| T-06 | 防回退锚点规范：锚点格式定义 + 回流 uctoo-v4 流程 | C8 | §7,§8.5 | 规范/Markdown | 待开始 |
| T-07 | UMI-ORM DB 腿补全（P1）：schema→ORM/CRUD/Web 确定性生成 | C4 | §1,§8.2 | 仓颉(UMI-ORM) | 待开始 |
| T-08 | 开放标准 `self-evolution` 能力声明 + 探测接口（P2） | C10 | §8.6 | YAML/文档 | 待开始 |
| T-09 | 编写 RSI 技能 README + 演示（五阶段循环 + 三腿闭环示例） | C1–C10 | 全 | Markdown | 待开始 |
| T-10 | 登记 RSI 为 agentskills 标准能力（更新 SPECS_INDEX / 规范索引） | 全局 | §1 | 文档 | 待开始 |
| T-11 | System-1 承接 PoC（Laya 判断引擎驱动确定性代码开发，降低 System-2 依赖，非去 LLM） | C11 | §2.4,§8.7 | 仓颉(Laya 集成) | 待开始 |

---

## 任务依赖关系图

```
T-01 (技能本体) ──┬──► T-02 (RSI-0 护栏) ──► T-05 (验证强制链)
                  ├──► T-03 (LRT 心跳)
                  ├──► T-04 (多技能并行)
                  └──► T-06 (防回退锚点)
T-07 (UMI-ORM DB腿) ──► (C4 由部分能力升级为全能力，独立 P1 排期)
T-08 (开放标准) ──► T-10 (标准登记)
T-09 (README/演示) ──► 末步
T-11 (System-1 PoC) ──► (P2，依赖 T-01 + 既有确定性代码生成工具；可独立排期)
```

可并行：T-02/T-03/T-04/T-06 均依赖 T-01，彼此可并行；T-07 独立 P1；T-08 可与 T-01 并行；T-11 属 P2，可与 T-08 并行（依赖 T-01 与已实现的 loaddbinfo/crudgen/crudweb）。

---

## 任务详细说明

### T-01 [编写 skills/RSI/SKILL.md 技能本体]
- **目标**：交付 RSI 的可执行载体，固化《人工智能软件工程方法论》三支柱 + RSI-0 约束 + 三腿规划器。
- **输入**：`research.md`/`spec.md`/`design.md`。
- **步骤**：
  1. 编写 frontmatter（name=RSI, description 含触发词"自进化/RSI/递归自改进", license=MIT, version, compatibility 声明依赖 L3 宿主 + sdd + parallel + lrt）。
  2. 写"方法论 SOP"章：AI 生产力三支柱、确定性死路论证、RSI-0 铁律（框架级确定性由确定性工具保障，以确定性基础设施消解 LLM 不确定性，LLM 仍在需要的流程与位置生成代码）。
  3. 写"三腿规划器"章：解析目标 → 判定代码腿/技能腿/DB 腿 → 选工具链。
  4. 写"工具编排"章：串接 loaddbinfo→plugingen/crudgen→crudweb、sdd 六步、long-running-task。
  5. 写"护栏"章：RSI-0 越界拦截（拦截把框架级结构正确性交给 LLM 概率性输出单独承担的越界动作）、防回退锚点强制、验证闸口强制。
  6. 写"并行声明"+"LRT scheme 注册"+"System-1 可选承接声明"章（指向 T-03/T-04/T-11）。
- **产出物**：`skills/RSI/SKILL.md`。
- **验收**：技能可被 `sdd`/`parallel` 识别；含上述六章；显式声明 RSI-0 与 System-1 可选承接。
- **风险**：勿把"框架级结构正确性"写成 LLM 职责（必须写为确定性工具的职责，LLM 不确定性由确定性基础设施消解，而非要求 LLM 一次写对全部框架源码，也非禁止 LLM 在需要的流程与位置生成代码）。

### T-02 [实现 RSI-0 护栏]
- **目标**：把"RSI 自动变更受 Human-Code Preservation 护栏约束、框架级确定性由确定性工具保障（LLM 不确定性被消解，而非去 LLM）"从注释变为可执行校验。
- **输入**：design §7、§8.1。
- **步骤**：
  1. 设计检测规则：识别"把框架级结构正确性交给 LLM 概率性输出单独承担"的越界动作——典型表现包括（a）生成区外 emit 完整框架源码、（b）覆盖 Human-Code Preservation 保护区中的人工代码、（c）由 LLM 概率性输出单独产出框架级结构而非确定性工具产出。结合 Human-Code Preservation 区 + 生成器标记（生成区标识）做判定。LLM 在需要的流程与位置生成的胶水逻辑、非标准实现、保护区内手写不在此列。
  2. 实现为 `code-gen-verifier` 的 RSI 扩展 或 独立校验器（优先 `plugingen` 生成插件）。
  3. 越界即返回明确拒绝原因，阻断入库。
- **产出物**：校验器（插件或宿主工具）+ 使用 SOP。
- **验收**：故意提交一段"把框架级结构正确性交给 LLM 概率性输出单独承担"的越界动作（如生成区外直接 emit 完整框架源码，或尝试覆盖保护区）→ 被拒并告警；正常确定性工具链产物（含保护区内合规手写）→ 通过。
- **风险**：误伤 Human-Code Preservation 区手写 → 白名单豁免保护区；误伤 LLM 合规生成的胶水逻辑 → 仅拦截"框架级结构正确性单独由 LLM 概率性输出承担"的越界，不泛化到一切 LLM 产出。

### T-03 [串接 LRT 心跳]
- **目标**：RSI 可经 `rsi://<goal>` 周期/事件触发。
- **输入**：`src/app/services/lrt/`、`lrt_composition_runner.cj`、`long_running_task_tool.cj`。
- **步骤**：
  1. 参照 `sdd://` scheme 注册方式，新增 `rsi://` scheme 指向 RSI 编排。
  2. 编写触发 SOP：周期（每 N 轮）与事件（构建失败/新需求/缺陷复盘）两种。
  3. 在 `skills/RSI` 中给出调用示例。
- **产出物**：scheme 注册配置 + RSI SOP 章节。
- **验收**：提交 RSI 目标 → LRT 调度五阶段循环 → 进度可查。
- **风险**：与 sdd scheme 冲突 → 复用同一调度器，仅新增 scheme 名。

### T-04 [复用多技能并行]
- **目标**：单次 RSI 循环的可并行子任务并发执行。
- **输入**：`src/skill/parallel/*`（auto_injector/task_matcher/budget_manager/conflict_filter）。
- **步骤**：
  1. 在 `skills/RSI` 声明自身为可并行技能（parallel declaration）。
  2. 编写子任务拆分 SOP：分析/起草/生成/测试 四角色并行，受 budget/conflict 管控。
- **产出物**：并行声明 + SOP。
- **验收**：单次循环产生 ≥2 并发子任务且受预算管控，无双重注入。
- **风险**：裸并发失控 → 强制走 `src/skill/parallel` 管控。

### T-05 [验证强制链]
- **目标**：RSI 变异必须经"编译绿 + 测试过"才接受。
- **输入**：build watcher（昨日落地）、SDD 测试步。
- **步骤**：
  1. 在 RSI 接受判据中串联：确定性生成 → watcher 绿条 → SDD `gate-test` 通过。
  2. 未通过 → 变异丢弃/回滚，禁止 git 入库（git SOP 禁区）。
- **产出物**：RSI 接受判据 SOP。
- **验收**：注入一次"编译失败"变异 → 被拒不入库；一次"全绿"变异 → 可 commit。
- **风险**：watcher 超时误判 → 明确超时即非绿，阻断入库。

### T-06 [防回退锚点规范]
- **目标**：每次采纳方案必写锚点并回流规范。
- **输入**：design §7。
- **步骤**：
  1. 定义锚点格式（测试/契约/规范条目三类）。
  2. 写"回流 uctoo-v4"流程：锚点 → 对应规范文档更新 → SPECS_INDEX 登记。
- **产出物**：锚点规范 Markdown + 回流 SOP。
- **验收**：模拟一次采纳 → 产出含 ≥1 锚点且规范已更新。
- **风险**：锚点流于形式 → SDD 任务模板强制"防回退锚点"字段。

### T-07 [UMI-ORM DB 腿补全]（P1，独立排期）
- **目标**：schema 确定性联动 ORM/CRUD/Web，C4 升级为全能力。
- **输入**：atomgit UMI-ORM 骨架、`docs/uctoo-v4/uctoo-database-design-*.md`、`uctoo-v4-orm-specification.md`。
- **步骤**：
  1. 复刻 UMI-ORM 仓颉工程，补齐 schema→ORM→CRUD→Web 生成器。
  2. 接入 loaddbinfo 的 db_info 作为单一事实源。
- **产出物**：UMI-ORM 生成器（独立仓颉工程，可单独 `cjpm build`）。
- **验收**：改一张表结构 → 三端代码确定性重生成且编译绿。
- **风险**：资源约束 → P0 阶段 C4 以 UMI 多端一致兜底并显式标注部分能力。

### T-08 [开放标准声明]（P2）
- **目标**：agentskills 标准新增 `self-evolution` 能力项。
- **输入**：agentskills 开放标准 plugin 能力声明。
- **步骤**：在标准中加入能力项 + 探测接口（对标 `plugin_inspect`）。
- **产出物**：标准补丁 + 探测实现。
- **验收**：外部运行时可探测 ASR 的 self-evolution 能力。

### T-09 [README + 演示]
- **目标**：可对外讲清 RSI（对标两场大会 PPT 的通俗表达）。
- **步骤**：写 `skills/RSI/README.md`，含五阶段循环图 + 三腿闭环图 + 一个端到端演示（新增表→生成→技能暴露→模型规划下一轮），并补一节"双驱动框架"说明（有 AI 是 AI 驱动开发框架，无 AI 仍是完备框架）。
- **验收**：文档自洽、图可渲染、示例可复现。

### T-10 [标准登记]
- **目标**：RSI 进入工程规范索引。
- **步骤**：更新 `specs/RSI` 主目录（如需 SPECS_INDEX）与 uctoo-dev-manual 索引。
- **验收**：索引可查 RSI 能力。

### T-11 [System-1 承接 PoC]（P2）
- **目标**：以最小场景验证"结构化决策交由 System-1（Laya choice/score/noul）+ 确定性工具，推理 LLM（System-2）低参与"下完成确定性代码变更，体现双驱动框架（有/无 AI 皆完备）。非去 LLM，而是把合适子系统的特性交给合适组件。
- **输入**：`.codeartsdoer/specs/laya-system1-integration/{README,research,spec}.md`、`research.md` §7、`docs/ref/AIDrivenArchitecture.md`。
- **步骤**：
  1. 选最小场景：数据库加一个字段（DDL → `loaddbinfo` → `crudgen` → `crudweb`）。
  2. 把"选操作模块 / 填参数字段 / 验结果正确性"映射为 Laya `choice` / `noul` / `score` + 三态门控（高→自动执行；中→提示人工；低→升级 System-2 / 人工）。
  3. 校验 System-1 只 emit"调工具的决策"，不 emit 源码；框架级结构正确性由确定性工具保障（与 RSI-0 一致）。
  4. 覆盖外（新架构 / 复杂重构 / 歧义需求 / UMI-ORM 深水区）阈值校准：强制升级 System-2 或人工。
  5. 跑通 → 编译绿条 → 记录为 System-1 承接示范（"双驱动框架"下低 AI 参与即可推进演进）。
- **产出物**：PoC 集成代码 + 演示记录。
- **验收**：System-2 低参与下完成加字段变更且编译绿；覆盖外场景被正确升级而非误自决。
- **风险**：Laya 置信度误判 → 灰度标定阈值，禁止 System-1 越界 emit 源码；LLM 仍在需要的流程与位置生成代码。

---

## 需求覆盖追踪矩阵

| spec 需求 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| C1 目标规划 | T-01,T-09 | 全覆盖 | 三腿规划器 |
| C2 代码层确定性改写 | T-01,T-02 | 全覆盖 | RSI-0 护栏 |
| C3 技能层自进化 | T-01 | 全覆盖 | 复用 sdd |
| C4 数据库层自进化 | T-07（P1） | 部分(当前)/全(达标后) | UMI-ORM 补全前标注部分能力 |
| C5 多技能并行 | T-04 | 全覆盖 | 复用 parallel |
| C6 LRT 心跳 | T-03 | 全覆盖 | rsi:// scheme |
| C7 验证即闸口 | T-05 | 全覆盖 | watcher+SDD |
| C8 防回退锚点 | T-06 | 全覆盖 | 回流规范 |
| C9 原生智能感知 | T-01 | 全覆盖 | 一切皆技能 |
| C10 开放标准 | T-08（P2） | 全覆盖(达标后) | 标准补丁 |
| C11 System-1 可选驱动 | T-11（P2） | 全覆盖(达标后) | Laya 集成 PoC |

---

## 验收检查清单（终验）

- [ ] 全部 spec 功能需求有对应实现并通过其验收条件
- [ ] DFX 约束已验证或标注豁免（DB 腿 P0 标注部分能力）
- [ ] 复用项未被重新实现（design §1 对比表）
- [ ] 编译/类型检查/lint 通过（人工确认，AI 不跑 build）
- [ ] spec/design/tasks 三份文档与最终实现一致（无漂移）
- [ ] RSI-0 护栏实测有效（把框架级结构正确性单独交给 LLM 概率性输出的越界动作被拒，LLM 合规生成不误伤）
- [ ] System-1 承接 PoC 在 System-2 低参与下跑通（覆盖外正确升级，不越界 emit 源码）
- [ ] 至少一次端到端演示跑通三腿闭环

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件 | 验证结果 |
|---|---|---|---|---|
| 2026-10-17 | r1 | 用户需求（RSI 专题落地） | research.md/spec.md/design.md/tasks.md（新建） | 待 gate 闸口 confirm |
| 2026-10-17 | r2 | 最新研究信息修订（与 spec C11 / design §2.4·§8.7·§9 对齐） | tasks.md | 校准 T-02 过强措辞（"拦截越界手写框架源码"→"拦截把框架级结构正确性交给 LLM 概率性输出单独承担的越界动作"）；新增 T-11 System-1 承接 PoC（C11 覆盖）；同步更新任务总览/依赖图/覆盖矩阵/验收清单 |

---

> 配套模板：`test-report-template.md`（测试验收报告）、`research-template.md`（研究文档）均见 `skills/sdd/templates/`。
