---
name: RSI
description: >
  ASR 自进化系统（Recursive Self-Improvement）技能——把《人工智能软件工程方法论》从理论到实践落地的
  方法论执行中枢。它**综合编排** ASR 既有基础设施（确定性代码生成工具 loaddbinfo/crudgen/crudweb/plugingen/
  pluginuninstall、SDD 规范驱动开发流水线、多技能并行 src/skill/parallel、LRT 长程任务、一切皆技能插件机制、
  UMI 数据架构），驱动"代码 + 技能 + 数据库"三大数字基础设施的闭环自进化。
  核心铁律 RSI-0：框架级确定性优先由确定性代码生成工具保障，以系统工程的确定性消解 LLM 在框架级变更中的不确定性；LLM 仍在需要的流程与位置生成代码（胶水逻辑、非标准实现等），只是不再让其概率性输出单独承担框架级结构正确性。
  触发词："自进化"、"RSI"、"递归自改进"、"框架自我演进"、"让框架自己进化"、"代码+技能+数据库闭环"、
  "AI 驱动开发框架自主进化"、"按方法论做一次演进"。
license: MIT
version: "0.1.0"  # 2026-10-17 初版，与 specs/RSI SDD 同源
compatibility: >
  需要宿主侧能力：L3 进程隔离轨插件宿主（CordisHostManager + host.db 服务代理）、
  SDD 编排（skills/sdd）、多技能并行（src/skill/parallel）、LRT 长程任务（src/app/services/lrt/）、
  确定性代码生成工具链（src/app/tools + src/plugin/tools）、UMI 数据架构（docs/uctoo-v4）。
  自身建议以 L3 process 轨插件形态落地（对齐 plugingen 默认轨）。
metadata:
  author: UCToo Team
  category: recursive-self-improvement
  tags: ["rsi", "self-improvement", "spec-driven", "deterministic-codegen", "ai-driven-dev-framework", "闭环自进化"]
allowed-tools: filesystem, cli, skill
---

# ASR 自进化系统（RSI）

## 1. 概述

RSI 是 ASR（agentskills-runtime，即 uctoo v4）的**方法论执行中枢**，把《人工智能软件工程方法论》（2025-11）
落地为可执行的闭环。它不是新服务，而是对既有基础设施的**编排层 + 一条强制约束**。

**一句话定位**：让开发框架在运行中持续进化（代码 + 技能 + 数据库三大基础设施闭环），
且**架构不腐坏、对二次开发友好、每次变异可回放验证**。

### 核心铁律 RSI-0（不可违背）

> **RSI 框架级确定性优先由确定性代码生成工具保障，以系统工程的确定性消解 LLM 的不确定性；LLM 仍在需要的流程与位置生成代码，只是不再让其概率性输出单独承担框架级结构正确性（不是"去 LLM"，而是让合适的子系统特性由合适的组件提供）。**

依据《人工智能软件工程方法论》的实证结论：框架代码属确定性软件，用含概率的 AI 直接生成全部框架代码是错配；
一线实测"即使是数据库表加一个字段，直接让大模型改框架代码也无法一次改对，必经历编译失败—修复循环，
达不到框架级进化要求"。确定性工具（loaddbinfo/crudgen/crudweb/plugingen/pluginuninstall）产出确定性可用代码，
才是支撑框架自主迭代、保证架构不腐坏的正解。所有同业 harness（deepseek-harness / openclaw / hermes-agent）
都把自进化停在"技能文本层"且缺确定性代码生成工具——这正是 ASR 超越 harness 的根基。

---

## 2. AI 生产力三支柱（方法论根基）

```
AI 生产力 = AI IDE + 大模型 + AI 驱动开发框架（三位一体，缺一不可）
                │
                ├─ AI IDE：人机协同界面
                ├─ 大模型：规划"调用哪些工具"、拼装"胶水代码"（为脑）
                └─ AI 驱动开发框架（ASR）：固化最佳实践与预制构件，
                                         向 AI 提供确定性代码生成工具（为手）
```

ASR 的角色是"手"：固化最佳实践、预制构件，并把确定性代码生成工具暴露给 LLM 调用。
LLM 的角色是"脑"：规划与编排，而非代写框架源码。

---

## 3. RSI 五阶段自进化循环（心跳）

```
  ① 实测 ──► ② 根因 ──► ③ 优化方案 ──► ④ 防回退 ──► ⑤ 约束注入
   │                                                  │
   └──────────────── 反馈（下一轮触发）◄───────────────┘
   触发源：周期(LRT) / 事件(构建失败·新需求·缺陷复盘)
```

1. **实测**：采集编译结果、测试覆盖率、契约漂移、复用率、二次开发冲突率（来源 = build watcher 日志 + `long_running_task_artifact` + SDD 缺陷分级）。
2. **根因**：LLM 分析实证数据，定位"为何未达预期"，输出根因假设（**不写代码**）。
3. **优化方案**：LLM 规划"调用哪些确定性工具 + 拼装哪些胶水代码"，产出**方案文档**（非源码）。
4. **防回退**：方案转 SDD 任务，**必须**附带防回退锚点（测试/契约/规范条目），否则打回。
5. **约束注入**：方案采纳后，把新约束回流 `uctoo-v4` 规范 / `uctoo-dev-manual`，同类问题不再复发。

> 任一阶段如需改写代码，一律回到第 3 步走确定性工具链，绝不裸写源码（RSI-0）。

---

## 4. 三腿闭环（代码 / 技能 / 数据库）

```
   数据库结构(schema)
        │ ① UMI / UMI-ORM 确定性生成
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

- **代码腿**：`loaddbinfo → plugingen|crudgen → crudweb` 确定性工具链。
- **技能腿**：`sdd` 六步流水线改写 `spec/design/tasks` 与 `SKILL.md`，经闸口后即时暴露。
- **数据库腿**：UMI 架构（已具备多端一致） + UMI-ORM（atomgit 开源骨架，待补全）实现 schema 驱动的确定性联动。

---

## 5. 工具编排（综合使用 ASR 既有基础设施）

| 基础设施 | RSI 中的角色 | 调用方式 |
|---|---|---|
| `loaddbinfo` | 把 DB 结构灌入 `db_info`（确定性工具单一事实源） | `cjpm run --skip-build --name loaddbinfo --run-args "..."` |
| `plugingen` | 生成 L3 进程隔离插件（默认 process 轨，产物可单独 `cjpm build`） | `cjpm run --skip-build --name plugingen --run-args "..."` |
| `crudgen` | 仅补宿主 `src/app/` 公共基础设施五层 | 同上，包名 crudgen |
| `crudweb` | 生成 Web 管理界面 | 同上，包名 crudweb |
| `pluginuninstall` | 对称下线插件（禁手删 `skills/{name}`） | 同上，包名 pluginuninstall |
| `sdd` 技能 | 变更治理通道（六步 + 人在回路闸口 + git SOP） | 见 `skills/sdd` |
| `src/skill/parallel` | 多技能并行基底（分析/起草/生成并发） | 声明本技能为可并行技能 |
| `src/app/services/lrt` + `long_running_task_tool` | 心跳调度（周期/事件触发五阶段循环） | 注册 `rsi://<goal>` scheme |
| 一切皆技能 / `SkillToToolAdapter` | 原生智能：新能力即时进 LLM 可见 Tool 列表 | 自动，无需手注册 |
| `docs/uctoo-v4/*` + `uctoo-dev-manual` | 规范单一事实源 + 护栏依据 | 只读引用 |

> 工具链坑位见 `skills/uctoo-dev-manual`（loaddbinfo 命令行模式有未修问题 → 退 Web 端"加载数据库信息"；
> crudgen 编译报 `@DAO` 错 → 看 `docs/uctoo-v4/crud-generator-v2.md`）。

---

## 6. 护栏（强制约束，越界即拒）

1. **RSI-0 源码护栏**：检测"生成区外 / Human-Code Preservation 保护区外"的新增/修改框架源码，硬拒并告警。
2. **防回退锚点强制**：任一优化方案转 SDD 任务时，`tasks.md` 必含"防回退锚点"字段，否则打回。
3. **验证即闸口**：变异必须经 build watcher 绿条 + SDD 测试步通过，方可 git 入库（绑定 `feature_name=RSI`/`stage`）。
4. **破坏性变更人工确认**：改契约、删表、改生成器模板须 SDD `gate-*` confirm，RSI 不自动采纳。
5. **不碰二次开发手写代码**：Human-Code Preservation 区外的既有逻辑默认不改，除非经 SDD 显式确认。

---

## 7. 并行与调度声明

- **多技能并行**：本技能声明为可被 `src/skill/parallel` 并行调度的技能；单次循环拆为
  「分析失败构建 / 起草 spec / 生成代码 / 写测试」四角色并发，受 `budget_manager` + `conflict_filter` 管控。
- **LRT 心跳**：RSI 注册为原生 LRT scheme `rsi://<goal>`，支持
  - 周期触发（每 N 轮后台自评，对标 openclaw `autonomous.mode: auto` / hermes `background_review`）；
  - 事件触发（构建失败、新需求、缺陷复盘）。
  注册方式参照 `sdd://` scheme（见 `src/skill/lrt_composition_runner.cj` 与 `SddOrchestrationService`）。

---

## 8. 使用流程（端到端示例）

**目标**：为系统新增"低代码表单引擎"能力，并让模型即时可用。

```
Step 1  规划（脑）：RSI 解析目标 → 判定走"代码腿 + 技能腿"，选工具链
        loaddbinfo → plugingen(生成 form-engine 插件, L3 process 轨)
        → crudgen(宿主公共脚手架) → crudweb(管理界面)
Step 2  生成（手）：依次调用上述确定性工具，产出编译可用的插件 + 界面骨架
Step 3  治理（闸口）：将变更转 SDD 工程，经 gate-spec/design/task/code/test，
        附防回退锚点（表单引擎契约测试）
Step 4  验证：build watcher 绿条 + SDD 测试步通过 → git 入库（绑定 feature_name=RSI）
Step 5  暴露（原生智能）：form-engine 插件的 SKILL.md 经"一切皆技能"自动进 LLM 可见 Tool 列表
Step 6  循环：模型基于新能力规划下一轮演进（如"给表单加权限字段"）→ 回到 Step 1
```

整个过程 LLM 只在 Step 1/3/6 做规划与决策，源码由确定性工具在 Step 2 产出——**零裸写框架源码**。

---

## 9. 与同业差异（为何 ASR 超越 harness）

| 维度 | deepseek-harness | openclaw | hermes-agent | **ASR（RSI）** |
|---|---|---|---|---|
| 自进化边界 | 仅装插件，无自改进 | 技能文本层（skill_workshop） | 技能文本层（background_review，禁改框架） | **确定性工具驱动的源码层 + 技能层 + DB 层** |
| 确定性代码生成 | ❌ | ❌ | ❌ | ✅（loaddbinfo/crudgen/crudweb/plugingen） |
| 架构不腐坏保障 | 无 | 无 | 无 | ✅（RSI-0 + Human-Code Preservation） |
| 多端一致数据自进化 | ❌ | ❌ | ❌ | ✅（UMI / UMI-ORM） |
| 原生智能感知 | cordis_inspect | 工具集最全 | 无统一自省 | 一切皆技能自动暴露 |

> 同业共识边界 = "让模型改写知识/流程，但不让它改写代码"。ASR 把边界推进到"确定性工具驱动的源码层"，
> 且不退化为概率代码生成——这是 RSI 的差异化内核。

---

## 10. 参考文档（同源 SDD）

- `specs/RSI/research.md` —— 研究步（同业基线 + 确定性死路实证 + 超最佳实践建议）
- `specs/RSI/spec.md` —— 需求规格（六节 + EARS 验收）
- `specs/RSI/design.md` —— 设计方案（存量对比 + 闭环架构 + 超最佳实践 §8）
- `specs/RSI/tasks.md` —— 任务分解（T-01~T-10，含 UMI-ORM DB 腿 P1 排期）
- `docs/ref/plugin-mechanism-comparison.html` —— 四项目插件机制对比（D12 原生智能/自进化维度）
- `docs/uctoo-v4/*` —— 规范单一事实源
- `skills/{sdd,uctoo-dev-manual,long-running-task}` —— 复用的既有 SOP 库

---

## 11. 实施分期

- **P0（当前）**：本技能 + RSI-0 护栏 + 复用 SDD/LRT/parallel 跑通代码腿与技能腿闭环。
- **P1**：补全 UMI-ORM DB 腿，C4 由"部分能力"升级为"全能力"。
- **P2**：防回退锚点规范固化、验证强制链、开放标准 `self-evolution` 声明、周期/事件心跳。
