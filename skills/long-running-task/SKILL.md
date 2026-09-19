---
name: long-running-task
description: AI 自主驱动长程任务系统 —— 接收高层目标，AI 自主规划并驱动分钟级到天级长程任务，实现"人设目标、AI 自主规划与执行、人评审交付"闭环。触发词："长程任务"、"自主任务"、"跑一个长期任务"、"AI 自主执行"、"定时自主任务"、"Long Running Task"、"Autonomous Task"。
license: MIT
version: "1.1.0"
compatibility: 需要 runtime 内置工具支持（cli_execute/file_read/file_write/http_request/skill），脚本执行需 Python 3.8+，宿主 PostgreSQL + crontab 调度引擎。L3 进程隔离轨插件（mode=process）。
metadata:
  author: UCToo Team
  version: "1.1.0"
  category: autonomous-agent
  tags: ["long-running-task", "autonomous", "planning", "self-evolution", "长程任务", "自主规划"]
allowed-tools: network, filesystem, cli
decision-points:
  - id: pause
    when: 用户请求暂停任务
    question: 是否暂停当前长程任务？
    options:
      - id: "yes"
        label: 暂停
        description: 等待当前回合完成后暂停，crontab.status=2，agent_tasks.status=5
        tradeoff: 任务暂停但不丢失上下文，可从检查点恢复
      - id: "no"
        label: 继续
        description: 不暂停，继续执行
        tradeoff: 任务继续运行
    default: "yes"
    recommended: "yes"
    timeout_seconds: 30
  - id: resume
    when: 用户请求恢复已暂停任务
    question: 是否从检查点恢复执行？
    options:
      - id: "yes"
        label: 恢复
        description: 从检查点继续执行，crontab.status=1
        tradeoff: 从断点续跑，不重头开始
      - id: "no"
        label: 保持暂停
        description: 保持暂停状态不变
        tradeoff: 任务继续暂停
    default: "yes"
    recommended: "yes"
    timeout_seconds: 30
  - id: cancel
    when: 用户请求取消任务
    question: 是否取消当前任务？
    options:
      - id: force
        label: 强制取消
        description: 立即终止，status=4
        tradeoff: 保留 result 但中断当前步骤
      - id: graceful
        label: 优雅取消
        description: 当前步完成后终止，status=4
        tradeoff: 等当前步跑完再取消
      - id: "no"
        label: 不取消
        description: 继续执行
        tradeoff: 任务继续运行
    default: graceful
    recommended: graceful
    timeout_seconds: 30
  - id: replan
    when: 子任务失败/环境变更/用户调整目标
    question: 是否基于反馈调整规划？
    options:
      - id: "yes"
        label: 重规划
        description: 保留已完成子任务，增量调整未执行部分
        tradeoff: 已完成不重跑，只调未执行部分
      - id: "no"
        label: 不调整
        description: 沿用原规划继续
        tradeoff: 可能再次失败
    default: "yes"
    recommended: "yes"
    timeout_seconds: 60
  - id: human_confirm
    when: 代码合并/生产部署/数据删除/质量闸门未通过
    question: 是否确认执行此关键操作？
    options:
      - id: confirm
        label: 确认
        description: 经 agent_approvals 确认后执行
        tradeoff: 用户确认后才合并/部署/删除
      - id: reject
        label: 拒绝
        description: 不执行此操作
        tradeoff: 操作被阻止
      - id: defer
        label: 稍后
        description: 暂不决定，保持当前状态
        tradeoff: 等用户后续确认
    default: defer
    recommended: defer
    timeout_seconds: 300
  - id: review
    when: 验核报告生成后推送用户评审
    question: 是否确认交付？
    options:
      - id: confirm
        label: 确认交付
        description: 置 status=2，产物落地
        tradeoff: 任务完成
      - id: improve
        label: 要求改进
        description: 触发 LrtPlanner.replan 调整规划
        tradeoff: 基于反馈继续迭代
      - id: abandon
        label: 放弃
        description: 置 status=4
        tradeoff: 任务取消
    default: improve
    recommended: improve
    timeout_seconds: 600
---

# AI 自主驱动长程任务系统（Long Running Task）

## 概述

本技能实现"人设目标、AI 自主规划与执行、人评审交付"的闭环：
**目标解析 → 任务规划 → 调度执行 → 进度通知 → 能力扩展 → 验核交付**。

- 规划方式：AI 根据目标、环境状态与已安装技能（cangjie-coder/crud-generator/sdd-flow/skill-creator 等）自主分解任务树并编排技能，非硬编码流程
- 执行底座：agentskills-runtime（仓颉 L3 进程隔离轨插件 `long-running-task` + 宿主 SchedulerEngine/CheckpointManager/DagScheduler/WebSocket/SkillBridge）
- 持久化：agent_tasks（任务树）/ agent_contexts（检查点）/ long_running_task_artifact（产物）/ long_running_task_evolution（自进化）
- 人在回路：暂停/恢复/取消/调整目标/追加约束，关键操作（合并/部署/删除）需用户确认

## 全流程 SOP

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ 1.解析   │ → │ 2.规划   │ → │ 3.执行   │ → │ 4.通知   │ → │ 5.扩展   │ → │ 6.验核   │
│ parse    │   │ plan     │   │ execute  │   │ notify   │   │ extend   │   │ verify   │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

### Step 1：目标解析（Parse Goal）
解析用户自然语言目标为结构化目标描述，含成功标准与约束。
- **输入**：用户目标文本
- **输出**：`output/parsed/goal.json`
- **验收**：含 goal / success_criteria / constraints

### Step 2：任务规划（Plan Tasks）
AI 自主分解任务树（parent_task_id 层级），选择并编排技能序列，持久化到 agent_tasks。
- **输入**：`output/parsed/goal.json`
- **输出**：`output/planned/plan.json`（任务树 + 技能编排序列）
- **验收**：任务树非空；每个子任务含 skill_sequence 与 acceptance_criteria
- **能力缺口**：所需技能不存在 → 编排 skill-creator / cangjie-coder 子任务（经质量闸门 code-gen-verifier）

### Step 3：调度执行（Execute Rounds）
回合内：加载检查点 → AI 自主规划 → DAG 步骤执行（script/plugin/output 分发）→ 产物校验 → 保存检查点 → 进度通知。
- **输入**：`output/planned/plan.json`
- **输出**：`output/executed/`（各步产物）
- **验收**：每步产出文件存在且非空；超时保存检查点 status=6（等待下回合，不得置 0）
- **降级链**：cli_execute → builtin_tool → llm → template（遇挫不停：先重试 1 次，再换方案）

### Step 4：进度通知（Notify Progress）
经 WebSocket/SSE 推送 step_start/step_complete/checkpoint_saved/progress_update/subtask_dispatched/goal_achieved。
- **输入**：task_id
- **输出**：实时进度事件

### Step 5：能力扩展（Extend Capability）
检测能力缺口，自主创建技能 / 编写代码，经质量闸门后注册到 agent_skills。
- **输入**：`output/planned/plan.json`
- **输出**：新增/更新技能

### Step 6：验核交付（Verify & Deliver）
AI 自主比对产物与目标，生成结构化验核报告（目标达成度/产物清单/测试结果/已知问题），推送用户评审。
- **输入**：task_id + 产物清单
- **输出**：验核报告 + 交付状态
- **验收**：用户确认交付 → 产物落地 + sync 同步；要求改进 → 触发重规划（LrtPlanner.replan）

## 显式约束（防回退，严禁复现）

1. **任务完成判定**：禁止仅凭字符串匹配（如"完成总结"）判定完成；必须 `LrtArtifactVerifier` 结构化验核（产物存在且非空 + 目标达成度）通过才算完成。
2. **遇挫不停重试**：任何步骤失败必须先重试 1 次，重试仍失败才换降级方案，禁止直接返回停止。
3. **SOP 全步完成强制约束**：6 步必须全部执行完，answer 前必须终检全部关键产出物存在，缺失则补执行对应步骤，禁止提前终止。
4. **产出文件校验**：每步执行后必须校验产出文件存在且非空（file_read / cli_execute），日期匹配当前执行日，内容含本次执行数据。
5. **状态不得倒退**：执行回合超时置 status=6（等待下回合），禁止置 0（会让任务被当新任务重新派发并丢失回合上下文，spec §6.1）。
6. **确定性优先**：CRUD/权限/调度/检查点用既有基础设施；推理/判断/创造由 AI 驱动。
7. **降级策略链**：每步声明 degradation_chain，全部失败时在 answer 中报告尝试次数与失败原因。
8. **输出必须以标签开头**：禁止在首个标签前写散文（spec 5.14 执行内核基线）。所有结构化输出（计划 / 进度 / 验核 / 决策）必须以 `##` 标题、`-` 列表或 `[TAG]` 等标签起始，便于 `tag_stream_parser.cj` 解析；首标签前的自然语言会被内核截断或抛异常，导致整轮输出解析失败。
9. **步数预算与收束协议**（2026-09-15 实测教训）：宿主主循环的 ReAct 步数**已分层独立配置**（`Config.normalReactSteps` 普通任务默认 30、`Config.longRunningTaskSteps` 长程任务内循环默认 100、`Config.agentExecutionSteps` 子 agent 默认 30；均可用环境变量 `AGENT_NORMAL_STEPS` / `LRT_REACT_STEPS` / `AGENT_EXEC_STEPS` 覆盖）。耗尽时日志打印 `Exceed the max react loop` 并强制结束。Step 2 规划时必须给任务树每个子任务分配步数预算（建议：解析 2 / 规划 3 / 每个子任务 ≤ 6 / 验核 3 / 交付 2），并在**剩余步数 ≤ 5** 时进入收束模式：停止开启新策略，改为「落盘 checkpoint + 产出阻塞报告 + 请求续跑或人工决策」。**禁止把预算耗在同一策略的反复重试上**——本次事故中 30 步有 20+ 步耗在"换一组 urllib 参数重抓同一个图片页"。
10. **同策略失败上限（"遇挫不停"的边界）**：同一子任务、同一策略**连续失败 ≤ 2 次**，第 3 次必须换**策略**而不是换参数重试。同一子任务累计尝试 **≤ 4 次**仍无进展 → 判定 `blocked`：写 `output/blocked/<subtask_id>.json`（含已尝试策略清单、逐次失败原因、建议的人工介入方式），向用户上报并请求决策，**禁止继续消耗步数**。
11. **非文本载体：先判模型视觉能力，再决定 OCR 还是直传**（2026-09-15/16 实测教训）：命中以下任一特征即判定为**图片 / PDF / 扫描件承载**——① HTML 文本化后体量远小于原始（实测 156 KB HTML → 8 KB 文本）；② 关键术语（题号、学科词）零命中；③ 页面存在 `img` / `iframe` / `embed` / `.pdf` 直链。**先查模型能力**：若当前模型具备视觉/多模态能力（运行时 `Config.modelCapabilities` 含 `vision`，如 `deepseek-flash` / `deepseek-vl` 等原生多模态模型），**直接将图片作为输入交给模型理解**，无需 OCR；若**不具备视觉能力**，再按序降级：提取图片 / PDF 直链 → 调用视觉模型或 OCR 还原文本 → 改换**文本版来源**（教辅站文字版 / 百科 / 题库 API / 可访问性文本）。**关键认知**：`deepseek-flash` 等新版模型已是原生多模态，把图片丢给它即可，强制 OCR 是冗余且会丢信息的反模式；本 runtime 不会再因「模型信息缺失」而误判。
12. **步数耗尽 ≠ 任务完成**：`Exceed the max react loop` 属**异常终止**，此时输出的 answer 是「中断报告」而非「交付物」。运行时现已分离状态：**`status=5`（步数耗尽未闭环）与 `status=2`（正常完成）是两个不同终态**，中断任务不会再被记为 completed。必须在 answer 首行标注 `状态：未闭环（blocked）`，列出已完成 / 未完成子任务与恢复步骤；**禁止**在此状态下声明任务成功、禁止走 `review` 决策点请求确认交付。
13. **进度必须落盘而非只写在 answer 里**：每完成一个子任务（以及进入收束模式时）把「目标 / 已完成 / 待办 / 失败项 / 下一步 / 关键产物路径」写入 `output/checkpoint/progress.md`。answer 会随会话结束而丢失，只有落盘进度才能在中断后从检查点续跑。

### 运行时登记的防回退条目（自动区，勿手工编辑）

`LrtAntiRegressionRegistry` 在自进化环节 4/5 会把 P0/P1 问题的「错误行为示例 + 正确行为示例」
写进下面这对标记之间，**每次整块替换**。标记缺失时注入会直接报错并跳过，而不是猜位置插入。

<!-- BEGIN: AUTO-CONSTRAINTS -->
<!-- 暂无已登记的防回退约束 -->
<!-- END: AUTO-CONSTRAINTS -->

## 决策点（decision-points，第 13 章人在回路）

- **何时暂停**：用户 pause → 等待当前回合完成 → crontab.status=2 → agent_tasks.status=5
- **何时恢复**：用户 resume → crontab.status=1 → 从检查点继续
- **何时取消**：用户 cancel → 当前步完成后 status=4；force_cancel → 立即终止 status=4
- **何时重规划**：子任务失败/环境变更/用户 adjust_goal → 保留已完成子任务，增量调整未执行部分
- **何时请求人工确认**：代码合并 / 生产部署 / 数据删除 / 质量闸门未通过 → 调用 `web_request_approval` 请求确认
- **审批调用的必填契约**（决策点闭环，必做）：到达 frontmatter `decision-points` 声明的任一决策点时，调用 `web_request_approval` 必须同时带上 `skillName`（固定 `long-running-task`）与 `decisionPointId`（该决策点的 `id`），并按该决策点 frontmatter 的同名字段传 `options` / `default` / `recommended`。宿主据此校验该决策点是否仍生效；**失效或被禁用时工具会自动降级为普通「批准/拒绝」审批**，此时不得自行伪造选项卡片，按用户实际答复继续。

## 提示词配置（PromptConfig：可视化配置，而非硬编码）

框架主张「尽量可视化配置而不硬编码」。长程任务的**工具结果摘要提示词**走
`magic.compactor.PromptConfig`，改提示词不需要动代码、不需要重新编译。

- **机制**：宿主启动时的组合根读 `PROMPTS_DIR`（默认 `./prompts`）并调用
  `PromptConfig.loadFromDir`；优先级为 **profile 文件 > 全局文件 > 内置默认**。
- **本技能的 profile 名**：`long-running-task`，对应文件
  `tool-summarize.user.long-running-task.md`。
- **命中条件**：`AgentTask` 构造 `SimpleToolCompactor` 时传入的 profile 是**候选链**
  `<已注册技能名…>,<agent 名>`（见 `SkillAwareAgent.promptProfileCandidates`）。
  因此只要 `long-running-task` 技能挂在该 agent 上，它的工具结果摘要就会命中本 profile。
- **为什么必须配**：内置默认措辞只有一句 `Summarize the tool execution result.`，
  不要求保留「目标 / 产物路径 / 进度 / 失败项 / 下一步」。长程任务跨回合压缩时
  会静默丢掉这些，上下文越跑越薄。**2026-09-15 实测**：profile 未命中，
  日志中「命中 profile 摘要提示词」出现 **0 次**。
- **占位符（硬约束）**：user 提示词必须保留 `{tool_call}` 与 `{tool_result}` 两个占位，
  缺失会让 `Template.format` 取不到值。
- **输出结构（推荐）**：`Status / Artifacts / Progress / Blockers / Key Data / Next` 六段，
  与本技能「进度必须落盘」（约束 13）天然对齐。
- **随技能分发**：技能目录下 `prompts/` 与宿主 `./prompts` 保持同名结构；
  发布脚本会把 `skills/<name>/` 整体打进发布包，便于技能自带提示词。

## 中断与续跑（2026-09-15 事故沉淀）

一次 run 可能因任一原因被动结束，必须能被人接手：

| 中断信号 | 日志标志 | 应当落盘 | 禁止 |
|---|---|---|---|
| ReAct 步数耗尽 | `Exceed the max react loop` | `output/checkpoint/progress.md` + `output/blocked/<subtask>.json` | 声明成功 / 置 `status=2` / 走 `review` |
| 单回合超时 | 宿主置 `status=6` | checkpoint（**不得置 0**，会让任务被当新任务重派） | 置 0 |
| L3 进程插件未激活 | `process plugin '<name>' failed to activate` | 退化为「通用工具手搓 SOP」时**必须**在 answer 中声明状态机未生效 | 假装状态机在跑 |

**恢复步骤**：读 `output/checkpoint/progress.md` → 确认未完成的子任务与其步数预算 →
优先换策略（而非重试原策略）→ 仍受阻则按 `output/blocked/*.json` 的建议请求人工介入。

## 自进化（LrtSelfEvolutionLoop，第 7 章）

每轮优化基于实测日志证据：实测驱动 → 根因分析 → 增量优化 → 防回退（错误行为示例严禁复现）→ 显式约束注入 SKILL.md。
问题按 P0 阻断 / P1 严重 / P2 中等 / P3 低 分级依次修复。

> 上面的自动区由 `LrtAntiRegressionRegistry` 维护；手工约束请写在"显式约束（防回退，严禁复现）"编号清单里。
> 两边合起来才是完整的防回退约束：编号清单是设计期确定的框架约束，自动区是运行期用真实教训补出来的。
