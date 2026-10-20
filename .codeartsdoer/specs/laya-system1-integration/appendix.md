# 附录：落地工件参考

> 本附录给出可直接落地的工件模板与接口清单，供实现团队在 Phase 1 起步。所有仓颉侧代码/配置需据 runtime 现有 MCP 集成代码与插件规范（`plugin-system` REQ-PS-007）最终确认，此处只定语义与形态。

---

## A.1 `skills/system1-decision/SKILL.md` 模板（提案形态）

```markdown
---
name: system1-decision
description: System-1 快思考决策技能（纯技能形态，不派生子 agent）。当 Agent 循环需要做一个结构化、带校准置信度的快速判断（技能选择、工具风险门控、意图分类、停滞检测、上下文相关性、引用核验、注入筛查）时，必须使用此技能，调用 Laya 的 MCP 工具（laya_predict / laya_decide / laya_preset / laya_shortlist）返回 choice/score/noul 决策与置信度，再由主 Agent 按阈值执行 auto/review/escalate 三态。
version: 0.1.0
author: OpenCangjie Team
dependencies:
  - laya-mcp-server   # 外部 MCP 服务，由 runtime MCP host 注册
scripts: []
---

# System-1 决策技能

## 适用场景
- 技能选择：从 ≤32 个候选技能中判定最匹配项（超过用 laya_shortlist 两阶段）
- 工具风险门控：判定待执行工具调用是否不可逆 / 偏离任务（noul，p≥0.95 自动放行）
- 意图分类 / 工单分诊：直接复用 laya_preset triage / router
- 循环停滞检测：每步判定 CONTINUE / WARN / REPLAN / HALT
- 上下文压缩：对 tool call 打相关性分，丢弃陈旧项
- RAG 重排 / 引用核验：对检索片段打分 / 判定支持·反驳·无关
- 提示注入筛查：对片段判定注入概率

## 调用约定
- 状态（state）可是文本 / JSON / 对象；问题（questions）用 choice/score/noul 描述。
- 单次 ≤32 属性、≤32 选项、≤10 打分档；超量先 laya_shortlist。
- 返回含 `confidence`；落地阈值：≥0.95 自动执行，0.7–0.95 复核，<0.7 升级 LLM/人工。
- Laya 不生成文字，仅做结构化判断；开放问答/生成一律交 System-2（LLM）。

## 三态执行映射（对接 ApprovalConfig.autoApproveLowRisk）
- auto：高置信低风险 → 直接执行
- review：中置信 → 写入待复核（SideEffectTracker / ExecutionEvidenceRecorder）
- escalate：低置信/高影响 → HITL 审批或强模型重判
```

> 配套 `plugin.yaml` 按 `plugin-system` REQ-PS-009 三维一体（`SKILL.md` + `plugin.yaml` + `scripts/cj/`）声明，由 `PluginDiscoveryService` 自动发现并注册到 SkillRegistry。

---

## A.2 MCP 注册语义（概念配置）

Laya 作为 runtime MCP host 的**外部 MCP 服务**接入，等价于在 runtime 现有 MCP 服务清单中新增一条 stdio 服务条目，命令指向 `laya-mcp-server`（或 `python -m laya.mcp.server`），由宿主拉起子进程、按 MCP stdio 协议发现并挂载以下工具。具体字段名以 runtime 现有 MCP 集成代码为准。

环境变量（Laya 侧，`laya/mcp/server.py` 契约）：
- `LAYA_DEVICE`：torch 设备（cuda/cpu/mps）
- `LAYA_PRELOAD`：`"0"` 懒加载；默认预载 `english,multilingual`
- `LAYA_MODELS`：逗号分隔预载 checkpoint（MCP 默认不预载 typed-decisions）
- `LAYA_THREADS`：CPU 推理线程上限（≤物理核数）
- `LAYA_AUTO_TASK`：`"1"` 允许按问题 schema 自动路由到 typed-decisions

---

## A.3 Laya MCP 工具清单（runtime 可消费）

| 工具 | 用途 | 对应决策点（见 spec.md §2） |
|---|---|---|
| `laya_status` | 报告设备/已载 checkpoint/版本 | 运维可观测 |
| `laya_route` | 仅路由判定（不跑前向） | 调试/解释 |
| `laya_predict` | choice/score/noul 单次决策 | #1 #2 #3 #6 #7 #8 #9 |
| `laya_predict_batch` | 批量决策、共享前向 | 大规模分类/重排 |
| `laya_route_batch` | 批量路由判定 | 工作负载探查 |
| `laya_shortlist` | 多选项预筛后再决策 | #1 大技能目录 |
| `laya_preset` | 内置 triage/email/guard/moderation/router | #9 意图/分诊/护栏 |
| `laya_decide` | JSON-Schema/pydantic 驱动、投影出值 | 通用结构化决策 |

---

## A.4 Laya vs Jev 基准（来自 `laya/BENCHMARKS.md`）

| 指标 | Laya | Jev（公开，第三方） |
|---|---|---|
| typed-decisions（2000） | **0.766** | 0.727 |
| AG News（4 类） | **0.953** | 0.910 |
| DAIR Emotion（6 类） | **0.600** | 0.480 |
| 温度拟合后 ECE（↓） | **0.081** | 0.246 |
| p50 延迟 单问题（T4） | **32.8ms** | 236–276ms |
| 许可 / 部署 | **Apache-2.0 / 本地离线** | 闭源 / 托管 API |
| 多语言 | **100+（multilingual）** | 英文为主 |

---

## A.5 决策点 → runtime 模块 速查表

| 决策点 | runtime 模块 | 接入形态 |
|---|---|---|
| 技能选择 | `magic.skill` SkillRegistry / skill-composition-engine | choice + shortlist |
| 工具风险门控 | `approval-rollback` ApprovalManager / RequirePermissionMiddleware | noul + 阈值 |
| 模型路由 | `magic.model` | score |
| 循环停滞 | `agent-loop` / `agent-error-recovery` / `sdd` | score（4 档） |
| 完成核验 | `agent-error-recovery` / `execution-audit` | noul |
| 上下文压缩 | `context-optimization` | score |
| RAG 重排/引用 | 检索 / 交叉编码器重排 | score + choice |
| 注入筛查 | 安全层 | noul |
| 意图/分诊 | workflow 意图分类器 | preset triage/router |
| 密钥防护 | 安全层 | noul（脱敏串） |
