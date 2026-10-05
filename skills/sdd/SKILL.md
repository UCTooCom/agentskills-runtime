---
name: sdd
description: >
  规范驱动开发（Spec-Driven Development）—— 把一次功能开发固化为 research（可选）→ spec → design → tasks → code → test
  六步流水线，每步产出文档化中间产物并落库可回放，每步之后设人在回路闸口。
  各文档步由 SDD 专属子 agent 真实派生执行（非主 agent 自扮演），回传结果经契约校验后才被采信。
  触发词："规范驱动开发"、"SDD"、"按 SDD 流程"、"六步开发"、"先写 spec 再写代码"、
  "继续 SDD"、"接着 SDD 走"、"直接开始编码阶段"、"从任务分解继续"、"SDD 先跳过研究步"、
  "拆分成多个子系统"、"多子系统 SDD"、"子系统目录"、"SPECS_INDEX"、"大工程拆分"。
license: MIT
version: "1.2.0"  # 2026-10-03：新增铁律 15「大工程拆分」（多子系统 SDD 工程 / 集成契约 / 主工程目录）
compatibility: >
  需要 runtime 宿主侧能力：L3 进程隔离轨插件宿主（CordisHostManager + host.db 服务代理）、
  子 agent 派生链路（ChangeDetector 同步 skills/*/agents/ + SkillManagementService bundledAgents + SubAgentTool 真派生）、
  宿主 PostgreSQL（七张白名单表）。L3 进程隔离轨插件（mode=process）。
metadata:
  author: UCToo Team
  category: spec-driven-development
  tags: ["sdd", "spec-driven", "multi-agent", "human-in-the-loop", "规范驱动开发"]
allowed-tools: filesystem, cli, skill
agents:
  - name: sdd-researcher
    role: 研究步执行者
    file: agents/sdd-researcher.md
    stage: research
  - name: sdd-spec-writer
    role: 需求规格撰写
    file: agents/sdd-spec-writer.md
    stage: spec
  - name: sdd-design-writer
    role: 设计方案撰写
    file: agents/sdd-design-writer.md
    stage: design
  - name: sdd-task-planner
    role: 任务分解与覆盖矩阵
    file: agents/sdd-task-planner.md
    stage: task
  # code 步**没有子 agent**（2026-09-27 拍板）：由主 agent 加载编程技能 + SOP 执行，
  # 声明文件已删除（约定即注册，删文件即下线），见正文章节。
  - name: sdd-tester
    role: 测试验收与一致性核查
    file: agents/sdd-tester.md
    stage: test
decision-points:
  - id: gate-research
    when: 研究步产出 research.md 后
    question: 研究结果是否确认？
    options:
      - id: confirm
        label: 确认
        description: 接受 research.md，进入 spec 步
        tradeoff: 后续步骤以本研究为依据
      - id: revise
        label: 打回重做
        description: 附加修改意见后重跑 research 步，round 递增
        tradeoff: 上下文按新 task_id 重开，已确认产物不丢
      - id: abandon
        label: 终止
        description: 终止整个 SDD 工程
        tradeoff: 已产出文档保留，工程不再推进
    default: confirm
    recommended: confirm
    timeout_seconds: 600
  - id: gate-spec
    when: 需求步产出 spec.md 后
    question: 需求规格是否确认？
    options:
      - id: confirm
        label: 确认
        description: 接受 spec.md，进入 design 步
        tradeoff: 后续设计与任务分解以此为准
      - id: revise
        label: 打回重做
        description: 附加修改意见后重跑 spec 步，round 递增
        tradeoff: 上下文按新 task_id 重开
      - id: abandon
        label: 终止
        description: 终止整个 SDD 工程
        tradeoff: 已产出文档保留
    default: confirm
    recommended: confirm
    timeout_seconds: 600
  - id: gate-design
    when: 设计步产出 design.md 后
    question: 设计方案是否确认？
    options:
      - id: confirm
        label: 确认
        description: 接受 design.md，进入 tasks 步
        tradeoff: 按此设计分解任务
      - id: revise
        label: 打回重做
        description: 附加修改意见后重跑 design 步，round 递增
        tradeoff: 上下文按新 task_id 重开
      - id: abandon
        label: 终止
        description: 终止整个 SDD 工程
        tradeoff: 已产出文档保留
    default: confirm
    recommended: confirm
    timeout_seconds: 600
  - id: gate-task
    when: 任务步产出 tasks.md 后
    question: 任务分解是否确认？
    options:
      - id: confirm
        label: 确认
        description: 接受 tasks.md，进入 code 步
        tradeoff: 按此任务清单编码
      - id: revise
        label: 打回重做
        description: 附加修改意见后重跑 task 步，round 递增
        tradeoff: 上下文按新 task_id 重开
      - id: abandon
        label: 终止
        description: 终止整个 SDD 工程
        tradeoff: 已产出文档保留
    default: confirm
    recommended: confirm
    timeout_seconds: 600
  - id: gate-code
    when: 编码步完成且 code-gen-verifier 通过后
    question: 代码产物是否确认？
    options:
      - id: confirm
        label: 确认
        description: 接受代码产物，进入 test 步
        tradeoff: 进入测试验收
      - id: revise
        label: 打回重做
        description: 附加修改意见后重跑 code 步，round 递增
        tradeoff: 上下文按新 task_id 重开
      - id: abandon
        label: 终止
        description: 终止整个 SDD 工程
        tradeoff: 已产出文档与代码保留
    default: confirm
    recommended: confirm
    timeout_seconds: 600
---

# 规范驱动开发（SDD）

## 概述

本技能把"提需求 → 做设计 → 拆任务 → 写代码 → 跑测试"这件通常一次成型的事，拆成**六步可回放流水线**：

```
research（可选，由 enable_research 决定）
   → spec → design → tasks → code → test
```

每一步都有三个硬约束：

1. **产出必须落盘并入库**：阶段文档正文进 `long_running_task_artifact`（`usage=deliverable`），工程进度进 `sdd_projects`，派单留痕进 `sub_agent_invocations`；
2. **文档步必须由子 agent 真派生执行**：主 agent 不得自己扮演写手，缺定义即报错，不许静默降级；
3. **每步之后有人在回路闸口**（`decision-points`）：`confirm` / `revise` / `abandon` 三选一；测试步为末步不挂闸口，其报告本身就是验收依据。

> **工程很大的时候不硬跑一条流水线**：按铁律 15 拆成多个**独立子系统 SDD 工程**，
> 各自走六步、各自验收、再由主工程 `SPECS_INDEX.md` 做目录与组合集成。详见「大工程拆分（多子系统 SDD 工程）」。

## 委派触发规则

本技能由 **MainAgent 显式委派**触发，不是自动运行。当用户需求具备"要写完整的功能或模块"、"要求先出方案再动手"、"点名 SDD 或规范驱动开发"任一特征时，走以下路径：

- **路径 A — 显式委派**：直接调用 `sdd` 技能，传 `task_description` + `feature_name` + `enable_research`；
- **路径 B — 编排投递**：宿主侧 `LongTaskApiService.submitTask`（`scheme` 指向本插件）后，由编排器按 `COMPOSITION.yaml` 推进。

## 六步与子 agent 绑定

| 步 | 说明 | 模板 | 子 agent | 是否派生 |
|---|---|---|---|---|
| research | 现状调研与可行性分析（**可选**） | `templates/research-template.md` | `sdd-researcher` | 是（`enable_research=true` 时） |
| spec | 需求规格（6 节组件定位 + EARS 验收） | `templates/spec_template.md` | `sdd-spec-writer` | 是 |
| design | 设计方案（存量对比表 + 实现模型） | `templates/design_template.md` | `sdd-design-writer` | 是 |
| task | 任务分解（含需求覆盖追踪矩阵） | `templates/tasks-template.md` | `sdd-task-planner` | 是 |
| code | 编码实现（主 agent 加载编程技能 + SOP） | — | — | **否**（主 agent 直执行，见下） |
| test | 测试验收（一致性 + 缺陷分级 P0-P2） | `templates/test-report-template.md` | `sdd-tester` | 是 |

**编码步不派生子 agent（2026-09-27 拍板，原 v3 决策已升级为硬约束）**：`code` 步由**主 agent**按语言标签加载**编程技能**后按 SOP 自行执行——仓颉加载 `cangjie-coder`、前端加载 `web-coder`（过渡期路由 `fullstack-codegen`）、原生 App 加载 `app-coder`。

理由："换脑子的才派生，换说明书的用技能"——编码不需要换脑子，需要的是确定的 API 依据与工程内既有范式；语言专用子 agent 的边际收益已被"主 agent + 语言技能"覆盖，派生只会带来上下文重建成本。

落地口径（宿主侧 `SddOrchestrationService`）：

- `agents/` 下**没有** code 的声明文件（原 `sdd-code-dispatcher.md` 已删，约定即注册、删文件即下线），`subAgentForStage("code")` 返回空串；
- code 步走 `runHostDirectStage`：加载**主 agent**（`agent_id`，必填）→ 按 `codingSkillChain` 校验编程技能已挂载（全不命中即显式失败，禁止无依据编码）→ `agent.chat` 一轮，SOP 约束全部写进 prompt；
- **不写 `sub_agent_invocations`**（该表只记真派生步）。

## 人在回路闸口

五个 `gate-*`（research / spec / design / task / code），每点三选项：

- **confirm** —— 接受本步产出，推进下一步；
- **revise** —— 附带修改意见回退本步重做。`round` 递增、`current_stage` **不倒退**；上下文按**新的 `task_id`** 重开，已确认的其它步产物不丢；
- **abandon** —— 终止整个工程，已产出文档保留备查。

决策留痕进 `agent_approvals`（`skill_name=sdd`）。

## 路由（**宿主侧实际注册**，不是 `plugin.yaml` 里声明的那批 `gen-*`）

| 方法 | 路径 | 用途 |
|---|---|---|
| POST | `/api/v1/uctoo/sdd/start` | 幂等取/建工程（`sdd_projects.current_stage=init`） |
| POST | `/api/v1/uctoo/sdd/run` | **异步**编排；可选 `stage` 指定从哪一步开始 |
| POST | `/api/v1/uctoo/sdd/run-stage` | **同步**跑单个指定阶段（阻塞到子 agent 返回，探针/联调用） |
| POST | `/api/v1/uctoo/sdd/review` | 闸口决策回执（confirm/revise/abandon） |
| GET | `/api/v1/uctoo/sdd/status[/:featureName]` | 查询工程实例（`sdd_projects`） |

> `plugin.yaml` 的 `routes` 段里 `gen-{research,spec,design,task,code,test}` / `spawn-subagent` /
> `projects/:feature_name` 仍是**早期设计稿的声明**，宿主侧并未注册（全仓搜不到实现），会 404。
> 真实入口就是上表五个，别照着那份声明去调。

## 指定阶段执行（跳步续跑）

六步是 `depends_on` 串起来的流水线，但**不是必须从头跑**——前几步产物已落盘并确认后，
用户可以直接点名某一步开始。典型场景：research / spec / design / tasks 都已完成，用户要求
"直接开始编码阶段"。

两种用法（任选其一，参数一致）：

```bash
# 异步（推荐）：建行 → 立即触发一次 → 跑完 code 这一步停在 gate-code 闸口等人决策
POST /api/v1/uctoo/sdd/run
{
  "feature_name": "AgenticSoftwareFactoryHackathon",
  "stage": "code",
  "question": "按 tasks.md 逐个任务完成编码",
  "output_dir": "/abs/.codeartsdoer/specs/AgenticSoftwareFactoryHackathon",
  "agent_id": "<主 agent 定义 id>",          # code 步必填
  "language": "cangjie",
  "auto": false
}

# 同步（跑单步探针）：会阻塞到主 agent 返回，HTTP 直接拿结果
POST /api/v1/uctoo/sdd/run-stage
{ "feature_name": "...", "stage": "code", "output_dir": "...", "agent_id": "...", "language": "cangjie" }
```

三条硬规则：

1. **`stage` 非空 = 只跑这一步就停表**，跑完置 `awaiting_review`，回 `gate-${stage}` 等人决策，
   不会再自动往下推——想继续得显式再调一次（异步路径）或点闸口确认。
2. **跳步前查上游产物**（`SddOrchestrationService.checkUpstream`）：把 `stage` 的**全部**上游
   阶段文档（不是只查紧邻上一步）在 `output_dir` 下找一遍，缺件直接 400 拦下，
   提示里写明该把 `output_dir` 指到哪。确知要跳步缺件的，显式传 `allow_missing_upstream=true`。
   > `output_dir` 必须**传对**：阶段文档不落在 `specs/{feature_name}/` 时就靠它指路，
   > 不传会按 runtime 工作目录去找，然后报"找不到 tasks.md"。
3. **`question` 可空**：不传则由 `buildStageQuestion` 自动拼装（读上游产物 + 产物目录引导），
   与异步路径同口径，不需要调用方手工粘上下文。

`enable_research=false` 时，上游校验会跳过 research（COMPOSITION condition 同款信号）。

## 复用底座声明（不重复实现）

- 表：`agent_tasks`（权威态）/ `agent_contexts`（检查点）/ `long_running_task_artifact`（文档正文）/ `agent_approvals`（闸口留痕）/ `agents`（只读，查子 agent 定义）/ `sdd_projects` / `sub_agent_invocations`
- 引擎：COMPOSITION 编排引擎、决策框架、`code-gen-verifier`、宿主 SSE/WS 进度通道
- 数据访问：插件侧经 `host.db` 服务代理读写；两张新表的宿主侧五层模块由 `crudgen` 生成（见 `logs/crud.md`）

## 二次开发底座优先（uctoo 规范 + 确定性代码生成工具）

**适用判据**：只要迭代落点仍在 agentskills-runtime / uctoo 之内（新模块、新表 CRUD、管理界面、
新插件），就按"**先对齐规范 → 再跑工具生成骨架 → 最后最小适配**"走，不要一上来手写。

SDD 不重复叙述规范条款，只负责把执行者引到规范源：

| 阶段 | 规范源 / 工具 | 位置 |
|---|---|---|
| 规范 | `uctoo-dev-manual`（渐进式六层文档） | `skills/uctoo-dev-manual/` |
| 接口 | `uctoo-v4-api-specification.md` | `docs/uctoo-v4/` |
| 表 / 字段 | `uctoo-database-design-specification.md` | `docs/uctoo-v4/` |
| 五层 CRUD（PO/DAO/Service/Controller/Route） | `uctoo-v4-module-development.md`、`uctoo-v4-orm-specification.md` | `docs/uctoo-v4/` |
| 中间件 / 路由 / 架构 | `uctoo-v4-middleware-guide.md`、`uctoo-v4-architecture.md` | `docs/uctoo-v4/` |
| 权限与行级可见范围 | `user-permission-system.md`、`row-level-permission-system.md` | `docs/uctoo-v4/` |

工具链（`cjpm run --skip-build --name <包名> --run-args "<参数>"`，都是宿主工程内可运行包）：

```
loaddbinfo  →  plugingen（优先，插件）
             →  crudgen（仅宿主 src/app/ 公共基础设施）
             →  crudweb（Web 管理界面）
下线：pluginuninstall（对称，别手删 skills/{name} 留 DB 痕迹）
```

三条选工具判据：**能做成插件就做插件**（宿主 `src/app/` 是存量冻结、只减不增，别往里加东西）；
**crudgen 只补宿主公共基础设施**；**生成物是骨架，在它上面改，不推倒重写**。

落地文档见 `prompts/code.md「二次开发底座优先」`、`prompts/task.md` 硬约束、
`templates/tasks-template.md「开发规范（全任务强制遵守）」` 三处，编码步与任务步都以它们为准。

## 大工程拆分（多子系统 SDD 工程）

工程量评估下来单跑一条六步流水线会失控时（一次跑不完、验收分不开、交付面互阻塞），
**拆成多个独立子系统 SDD 工程**，各自走完整六步、各自有人回路闸口、各自可独立验收，
再由主工程做组合集成。目的不是"把活分小"，而是**让每个可交付单元自己站得住**。

### 一、什么时候拆（触发判据）

命中任一即进拆分评估；**同时建议保留主工程工程**（跑总装/端到端，不重复实现子系统内部细节）：

| 判据 | 阈值 |
|---|---|
| 任务规模 | 单工程 `tasks.md` 预计 > 40 条任务 |
| 语言/技术栈 | 覆盖 ≥ 3 条语言标签（cangjie / web / app） |
| 交付面 | ≥ 3 个可独立上线、独立开关、独立回滚的边界 |
| 上下文预算 | 按铁律 13 口径，单工程 code 步两轮内跑不完 |
| 人回路 | ≥ 2 个独立把关人，需要各自闸口 |

**不拆的反例（别为拆而拆）**：只加字段、加一个接口、一张表 CRUD、一个既有模块的小改——
这些直接单工程跑。判据兜底："不确定就先不拆"，中途发现顶到阈值再**补做**拆分评估
（补的是 SPECS_INDEX + 契约，不是推倒重来）。

### 二、按什么切（拆分维度优先级）

从上往下，先到先切；**禁止按文件目录切、禁止按实体个数平均分**——那切出来的是耦合块，不是子系统：

1. **交付面 / 可上线边界**（最优先）——能独立部署+独立开关+独立回滚的一大块；
2. **数据 / 领域边界** —— 表归属明确、跨边界只走接口；
3. **技术栈 / 语言边界** —— 不同语言标签的自然切分点；
4. **人 / 回路边界** —— 不同人把关的不同块。

### 三、颗粒度红线（每个子系统的"合适大小"）

| 维度 | 红线 |
|---|---|
| 下限 | 能独立产出六步文档，且有 **≥ 3 条可独立验收**的任务；比这更小就并进相邻子系统 |
| 上限 | 单子系统 `tasks.md` **≤ 40 条**任务；code 步一轮内可收敛；test 步 P0 ≤ 1 轮闭环 |
| 数量 | 一次拆分**≤ 6 个一级子系统**；超了按上面四条边界再归一层，别摊成十几个半拉子 |
| 耦合 | 拆完两个子系统之间出现 **≥ 5 个双向接口**，判定拆得不对 → 合并回去，重找边界 |

> "能验收"是硬指标：一个子系统若无法独立跑通自己的 L1 + 与上游的 L2，它就是拆碎了，不是拆对了。

### 四、集成契约先定（可组合集成的关键）

**顺序不能反：先出契约，再动实现**（对齐铁律 14「先对齐规范再动手」的同一手法）。

- 每个子系统在 `spec` / `design` 步必须产出一份集成契约，模板 `templates/subsystem-contract-template.md`；
- 契约四要素：① 对外接口清单（类型/路径/方法/请求响应形态/错误约定/幂等）② 数据契约（读哪些表、暴露哪些字段、行级权限口径）③ **依赖方向（单向、无环）** ④ 明确**不提供什么**；
- 契约在开工前**冻结**；任何调整走「先改契约 → 再改实现」，破坏性变更必须**双侧同轮**完成，单边先改 = P0 缺陷；
- 契约是唯一权威，实现与契约不符一律以契约为准回改，不许说"实现就这样了"。

### 五、可验收（三档，L2 是硬档位）

| 档位 | 谁执行 | 在什么合并态上跑 |
|---|---|---|
| **L1** 单子系统自测 | 子系统自身 test 步 | 本子系统 |
| **L2** 跨子系统集成 | 下游子系统 test 步 | 与**已 done 的上游**合并后的运行态 |
| **L3** 主工程端到端 | 主工程 test 步 / 总装验收 | 全量已 done 子系统在宿主上跑起来 |

- **子系统只跑 L1 就报 done，主工程闸口不予确认**。
- 每个子系统的 test-report 必须带一组跨边界冒烟用例（≥ 3 条主干 + 1 条异常）。

### 六、主工程维护子系统目录（SPECS_INDEX）

- 落点：`specs/{主 feature_name}/SPECS_INDEX.md`，模板 `templates/specs-index-template.md`；
- 内容八节：工程总览 / 子系统登记表 / 集成契约汇总（全局接口表）/ 依赖 DAG / 组合集成验收基线 /
  变更影响面 / 风险与已知偏差 / 修订记录（append-only）；
- **每个子系统是独立 SDD 工程**，不是主工程某一步的子步骤：
  各自独立 `feature_name`、`sdd_projects` 行、独立六步、独立闸口；
  - 命名：`feature_name = {主}--{子系统ID}`（双连字符），保证 `getByFeatureName` 唯一、目录可排序不撞名；
  - 产物目录：`specs/{主}--{子系统ID}/`（由 `resolveOutputDir` 自然派生，**不传 `output_dir`**——
    传了会让库里 `relativeArtifactPath` 记 `feature_name` 下的逻辑路径、与盘上实际路径不一致）；
- **状态同步**：任一子系统闸门回执后，主工程必须回到 SPECS_INDEX 更新该行（≤ 1 个闸口周期）；
- **并行策略**：无依赖的可并行，有依赖按拓扑序串行；上游进 `code` 前必须已达 `test`。

### 七、防回退

| 风险 | 约束 |
|---|---|
| 拆得碎 / 拆得粗 | 走 §三红线；≥5 个双向接口即判错，合并重切 |
| 契约漂移 | 先改契约再改实现；单边改 = P0；变更必须进 SPECS_INDEX §6 |
| 依赖成环 | §4 DAG 无回边；新依赖要改契约的依赖方向字段，不许实现里偷偷 import |
| 子系统互相直连私有表/私有目录 | 一律禁止，对外只准走 §1 契约接口 |
| 闸口被代决策 | 子系统闸口由子系统的闸口决策人确认，主工程不得代签 |
| 额度超支 | 铁律 9 表/列白名单额度按子系统独立计，超了升级人工闸口，禁止绕 |
| 主工程重复实现 | 主工程只做组合与端到端，不重复子系统内部设计细节 |

---

## 铁律

1. **阶段文档默认落 runtime 自有 `specs/{feature_name}/`**，禁止落 `.codeartsdoer/specs/`（该目录归属 CodeArts Agent）。
   > **冲突消解（2026-10-02 补充）**：**用户显式指定的输出目录优先于本条铁律。**
   > 当用户在请求里点名了输出路径（例："写到 `.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/`"），
   > 一律以用户指定为准，不要再纠结"这是不是合规目录"，也不要因为目录已存在而改回默认目录。
   > 本条约束的是**无人指定时的默认行为**，不是用来覆盖用户指令的。
2. **研究步 `condition` 只挂入口信号 `${input.enable_research}`**，绝不挂"文件是否已存在"——否则首轮恒跳过。
3. **文档步必须真派生子 agent**，禁止主 agent 自扮演；子 agent 定义缺失时立即失败并提示，禁止静默降级。
4. **回传结果必须先过契约校验**（REQ-SDD-012-A）再写入 `sub_agent_invocations.output_json`；校验不通过重派 1 次，仍失败转人工闸口，**禁止无限重试**。
5. **每次派单必须落库**（REQ-SDD-012-B）：`duration_ms` + `prompt_tokens` / `completion_tokens` / `total_tokens`；取不到记 0 并在 `error_message` 标 `token_missing`，**禁止估算冒充实测**。
6. **上下文按次隔离**：一律 `SubAgentMode.Isolated` + 显式上下文包；`agent_contexts` 必带 `task_id`；超窗口降级为路径引用时**必须**在 `mode` 字段标 `path_ref`，不得无声切换。
7. **状态不倒退**：`revise` 递增 `round`，`current_stage` 不回到更早阶段。
8. **编码前必须取得确定依据**（工程内既有 import 先例 / 同类实现 / 官方文档技能），查不到须标注缺口请人工确认，**禁止凭印象猜 API**；产物未过 `code-gen-verifier` 不得标记完成。
9. **禁止新建库表或列**：只能使用白名单七张表；新增表≤2、既有表新增列≤2 的额度已用满（`spec.md §6.7`）。
10. **插件自完备**：五个子 agent 声明（code 步无子 agent）+ 六份 prompt + **九份模板**（原有七份 +
    2026-10-03 新增 `specs-index-template.md` / `subsystem-contract-template.md`）全部随插件打包，
    禁止依赖插件目录之外的路径。
11. **L3 进程 stdout 是 stdio RPC 独占通道**，诊断日志一律走 stderr；推入宿主 SSE 的多行正文必须做单行转义（换行转 `\n`）。
12. **落盘优先于"说清楚"**（2026-10-02 补充，针对主对话直跑 SDD 的路径）：任何阶段产物（research / spec / design / tasks）必须在**本步之内**用 file_write 落盘，**禁止把正文只写进回复**——回复里的 markdown 不是交付物。
13. **跳步必须查上游（2026-10-02 补充）**：显式指定 `stage` 时一律先过 `checkUpstream`，
    缺件即拦（除非 `allow_missing_upstream=true`）。允许"指定阶段执行"不等于允许"没有任务清单就编码"——
    前者是用户主动选的入口，后者是上下文断档后子 agent 自己编前提。
    - 步数预算不足时：先落一份"初稿/未完成"再回复，并在回复里写明还差什么；
    - 工具返回空内容或乱码（中文被替换成 `?`）：**立即上报工具异常**并换路子（如 `withLineNumber=false`、分段读），
      禁止靠自造脚本反复绕路、把预算烧在探查上（2026-10-02 实测：5 次读取全乱码 → 1/3 预算归零 → 触顶未落盘）；
    - 明显超出单次预算的工程改用 `long_running_task` 提交，不要在主对话里硬跑到底。
14. **二次开发底座优先（2026-10-03 补充）**：迭代 runtime / uctoo 时
    **① 规范以 `uctoo-dev-manual` + `docs/uctoo-v4/*.md` 为准**（不在本技能内复述条款）；
    **② 脚手架优先跑内置确定性工具** `loaddbinfo` → `plugingen`（优先做成插件，默认 L3 进程隔离轨 process，
    需退回宿主内嵌 sync 轨显式加 `--mode sync`）／`crudgen`（仅宿主公共基础设施）／`crudweb`（管理界面），
    **禁止手撸五层骨架**；下线走对称的 `pluginuninstall`，禁止手删 `skills/{name}/` 目录（会留库痕迹）；
    **③ 生成物当骨架做最小适配**，不推倒重写；
    **    ④ 生成后必补** `sql/incremental/` 增量 DDL（涨幅受铁律 9 白名单额度约束）+ 新增宿主路由的
    `permissions` / `role_has_permission` 登记（否则 403）。
    规矩落点：`prompts/code.md` 新章、`prompts/task.md` 硬约束、`templates/tasks-template.md` 开发规范段。
15. **大工程拆分为多子系统 SDD 工程（2026-10-03 补充）**：工程量巨大时按"**交付面 → 数据/领域 → 技术栈 → 人回路**"
    优先级切分（禁按文件目录切、禁按实体个数平均分），每个子系统**独立 SDD 工程**、`feature_name = {主}--{子系统ID}`、
    独立六步与闸口、颗粒度守住「≥3 条可验收任务 且 tasks.md ≤40 条 且 一级子系统 ≤6 个 且 双向接口 <5」；
    **集成契约先定后动**（模板 `templates/subsystem-contract-template.md`，四要素：接口清单 / 数据契约 /
    单向依赖 / 明确不提供），先改契约再改实现，破坏性变更双侧同轮；拆出的每个子系统必须能独立验收
    （L1 自测 + L2 与已 done 上游的集成，L2 为硬档位，只跑 L1 不许报 done）；
    **主工程维护子系统目录** `specs/{主}/SPECS_INDEX.md`（模板 `templates/specs-index-template.md`）：
    子系统登记表 + 全局接口表 + 依赖 DAG + 组合集成验收基线 + 变更影响面，闸门回执后 ≤1 个闸口周期同步。
    规矩落点：`SKILL.md「大工程拆分（多子系统 SDD 工程）」`、`prompts/task.md` 硬约束、
    `prompts/code.md` 硬约束、`templates/tasks-template.md` 开发规范段。
