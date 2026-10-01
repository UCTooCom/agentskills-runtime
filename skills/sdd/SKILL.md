---
name: sdd
description: >
  规范驱动开发（Spec-Driven Development）—— 把一次功能开发固化为 research（可选）→ spec → design → tasks → code → test
  六步流水线，每步产出文档化中间产物并落库可回放，每步之后设人在回路闸口。
  各文档步由 SDD 专属子 agent 真实派生执行（非主 agent 自扮演），回传结果经契约校验后才被采信。
  触发词："规范驱动开发"、"SDD"、"按 SDD 流程"、"六步开发"、"先写 spec 再写代码"。
license: MIT
version: "1.0.0"
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

## 路由

| 方法 | 路径 | 用途 |
|---|---|---|
| POST | `/api/v1/uctoo/sdd/gen-{research,spec,design,task,code,test}` | 六步执行入口 |
| POST | `/api/v1/uctoo/sdd/spawn-subagent` | 按名派生 `agents/` 下的子 agent |
| POST | `/api/v1/uctoo/sdd/review` | 闸口决策回执（confirm/revise/abandon） |
| GET | `/api/v1/uctoo/sdd/projects/:feature_name` | 查询工程实例（`sdd_projects`） |

## 复用底座声明（不重复实现）

- 表：`agent_tasks`（权威态）/ `agent_contexts`（检查点）/ `long_running_task_artifact`（文档正文）/ `agent_approvals`（闸口留痕）/ `agents`（只读，查子 agent 定义）/ `sdd_projects` / `sub_agent_invocations`
- 引擎：COMPOSITION 编排引擎、决策框架、`code-gen-verifier`、宿主 SSE/WS 进度通道
- 数据访问：插件侧经 `host.db` 服务代理读写；两张新表的宿主侧五层模块由 `crudgen` 生成（见 `logs/crud.md`）

## 铁律

1. **阶段文档落 runtime 自有 `specs/{feature_name}/`**，禁止落 `.codeartsdoer/specs/`（该目录归属 CodeArts Agent）。
2. **研究步 `condition` 只挂入口信号 `${input.enable_research}`**，绝不挂"文件是否已存在"——否则首轮恒跳过。
3. **文档步必须真派生子 agent**，禁止主 agent 自扮演；子 agent 定义缺失时立即失败并提示，禁止静默降级。
4. **回传结果必须先过契约校验**（REQ-SDD-012-A）再写入 `sub_agent_invocations.output_json`；校验不通过重派 1 次，仍失败转人工闸口，**禁止无限重试**。
5. **每次派单必须落库**（REQ-SDD-012-B）：`duration_ms` + `prompt_tokens` / `completion_tokens` / `total_tokens`；取不到记 0 并在 `error_message` 标 `token_missing`，**禁止估算冒充实测**。
6. **上下文按次隔离**：一律 `SubAgentMode.Isolated` + 显式上下文包；`agent_contexts` 必带 `task_id`；超窗口降级为路径引用时**必须**在 `mode` 字段标 `path_ref`，不得无声切换。
7. **状态不倒退**：`revise` 递增 `round`，`current_stage` 不回到更早阶段。
8. **编码前必须取得确定依据**（工程内既有 import 先例 / 同类实现 / 官方文档技能），查不到须标注缺口请人工确认，**禁止凭印象猜 API**；产物未过 `code-gen-verifier` 不得标记完成。
9. **禁止新建库表或列**：只能使用白名单七张表；新增表≤2、既有表新增列≤2 的额度已用满（`spec.md §6.7`）。
10. **插件自完备**：六个子 agent 声明 + 六份 prompt + 七份模板全部随插件打包，禁止依赖插件目录之外的路径。
11. **L3 进程 stdout 是 stdio RPC 独占通道**，诊断日志一律走 stderr；推入宿主 SSE 的多行正文必须做单行转义（换行转 `\n`）。
