# 应用建议方案：将 Laya（System-1 决策引擎）集成进 agentskills-runtime

> 配套研究报告见同目录 `research.md`。本方案聚焦"能不能接、接在哪、怎么接、分几步走、风险与差异化"。
> 设计原则：**System-1 只做判断、System-2（LLM）做生成**；Laya 以"技能 + MCP 工具"形态接入，不侵入 runtime 宿主编译图（遵循插件系统"存量冻结 / 不硬编码业务功能"红线）；优先低风险决策点做 PoC。

---

## 1. 集成可行性结论

**可行，且成本低、收益高。** 依据：

- **接口对齐**：Laya 提供 MCP stdio 服务 `laya-mcp-server`，暴露 `laya_predict / laya_decide / laya_preset / laya_route / laya_shortlist / laya_status` 等工具；runtime 已有 MCP 集成能力（"从技能清单动态发现工具""与 MCP 协议的语义搜索集成"），并对外暴露 `host.mcp`。**Laya 作为外部 MCP 服务注册即可成为 runtime 工具，无需改动 Laya 的 Python 代码。**
- **范式对齐**：runtime 是"系统二" deliberative Agent 循环；Laya 补"系统一"快思考，构成 dual-drive。
- **合规对齐**：Laya Apache-2.0、本地/离线、不引入托管后端，契合"全链路自主可控 / 在任何地方运行"。

> 注：runtime 源码级 MCP host 配置字段需实现团队据现有 MCP 集成代码确认；本方案只定义集成语义，不臆造配置项。

---

## 2. 决策点映射（核心：Laya 用例 → runtime 现有能力）

| # | Laya / Jev 用例 | runtime 对应模块 | 接入方式 |
|---|---|---|---|
| 1 | **技能选择**（从技能目录选 ≤1 个） | `magic.skill` SkillRegistry + `skill-composition-engine` | 把技能目录建模为 choice 问题（≤32 选项/次，超量用 `laya_shortlist` 两阶段）；高置信自动分派，低置信升级 LLM |
| 2 | **工具调用风险门控** | `approval-rollback`：`ApprovalManager.checkApprovalNeeded` + `ApprovalConfig.autoApproveLowRisk` + `RequirePermissionMiddleware` | 用 `laya noul/score` 判定"是否不可逆 / 偏离任务"；p≥0.95 自动放行，否则走 HITL 审批 |
| 3 | **模型路由** | `magic.model` 双驱 | `laya score` 评估请求难度 → 快模型 / 强模型 |
| 4 | **循环停滞检测** | `agent-loop` + `agent-error-recovery` + `sdd` 编排 | 每步用 `laya` 判定 CONTINUE/WARN/REPLAN/HALT，替代昂贵的 LLM 自省 |
| 5 | **"完成"声明核验** | `agent-error-recovery` / `execution-audit` | `laya noul` 判定 transcript 是否含完成证据，防幻觉式 "done" |
| 6 | **上下文压缩** | `context-optimization`（README：令牌高效输出的上下文压缩） | `laya score` 给 tool call 打相关性分，丢弃陈旧项，替代 LLM 摘要 |
| 7 | **RAG 重排 / 引用核验** | README：交叉编码器重排 + 检索 | `laya` 对检索片段打分 / 判定引用支持·反驳·无关，低成本 top-k |
| 8 | **提示注入筛查** | 安全层（能力访问控制 / 沙箱） | `laya noul` 判定片段注入概率，过滤后再喂 LLM |
| 9 | **意图分类 / 工单分诊** | workflow 意图分类器 | 直接复用 `laya_preset triage / router` |
| 10 | **密钥泄露防护** | 安全层 | `laya noul` 对脱敏串判定泄露概率 |

> 用例 2、4、5、6 是**最高优先级**：它们直接对应 runtime 已有的审批/回滚、循环/错误恢复、上下文优化模块，集成阻力最小、收益（省 LLM 调用 + 提速 + 可量化置信度）最直接。

---

## 3. 集成架构（三层接入）

```
┌─────────────────────────────────────────────────────────────┐
│  agentskills-runtime (仓颉, "System-2" deliberative loop)     │
│   AgentLoop / SDD 编排 / ApprovalManager / SkillRegistry ...  │
└───────────────┬───────────────────────────────┬─────────────┘
                │ 调用                          │ 注册/发现
                ▼                              ▼
        ┌──────────────────┐        ┌──────────────────────────┐
        │ runtime MCP host  │◀─stdio─│  laya-mcp-server (Python) │
        │ (host.mcp)        │        │  laya_predict/decide/...  │
        └──────────────────┘        └──────────────────────────┘
                │                              │
                ▼                              ▼
   system1-decision SKILL.md          本地 checkpoint（英文/multilingual/
   (插件形态，自动注册到              typed-decisions），ONNX 可量化
    SkillRegistry，一切皆技能)          ~200ms/问(CPU) / 33ms(T4)
```

**关键设计选择：**
- **Laya 以"技能 + 插件"形态接入**：新建 `skills/system1-decision/`（含 `SKILL.md` + `plugin.yaml`），其 `SKILL.md` 指导主 Agent 调用 Laya 的 MCP 工具做决策。这符合"一切皆技能 / 插件 = Service + Skill"的架构哲学（`plugin-system` REQ-PS-007），且**不向 `src/app` 与 `AutoRouteConfig.cj` 追加代码**（存量冻结红线）。
- **跨语言边界走 MCP/HTTP**：runtime（仓颉）↔ Laya（Python）经 `laya-mcp-server` 子进程或 `laya[serve]` HTTP 服务通信，符合 L3 插件"独立进程、宿主只暴露 host.db/host.mcp/host.event…"的隔离模型。
- **置信度驱动三态执行**：所有决策点统一引入阈值（auto / review / escalate），与 `ApprovalConfig` 的 `autoApproveLowRisk` 语义一致。

---

## 4. 分阶段实施计划

### Phase 0 — 评估 / PoC（建议 1 周）
- 独立环境 `pip install laya[mcp]` + `laya-mcp-server`，用 runtime 现有技能机制调用 Laya 做 **1–2 个低风险决策点**（如工单分诊 preset、工具风险 noul）。
- 验证：中文场景准确率（项目面向中文用户，重点测中文意图/工单）、延迟（CPU vs T4）、校准（置信度是否跟踪正确率）。
- 产出：`eval_report.md`（域内校准与延迟基线，作为后续门控阈值依据）。

### Phase 1 — MCP 接入与技能封装（低风险）
- 将 `laya-mcp-server` 注册为 runtime MCP host 的外部 MCP 服务（据现有 MCP 集成代码配置）。
- 编写 `skills/system1-decision/SKILL.md` + `plugin.yaml`（模板见 `appendix.md`），自动注册到 SkillRegistry。
- 在 `approval-rollback` 的 `checkApprovalNeeded` 接入 `laya noul` 置信度：高置信只读/低危操作自动放行，降低 HITL 触发率。
- 复用 `laya_preset triage/router` 做 workflow 意图分类。

### Phase 2 — Agent 循环深度集成（中风险）
- 在 `agent-loop` / `sdd` 编排中注入：技能选择分类（#1）、循环停滞检测（#4）、完成核验（#5）、上下文压缩评分（#6）、RAG 重排（#7）、提示注入筛查（#8）。
- 通过现有中间件链（如 `RequirePermissionMiddleware`）与 SDD 六步编排挂载，决策结果写入 SideEffectTracker / ExecutionEvidenceRecorder，形成审计闭环。
- 引入统一的"置信度阈值配置"（auto / review / escalate），可由 `ApprovalConfig` 扩展承载。

### Phase 3 — 边缘原生（差异化，高风险高收益）
- 导出 Laya ONNX（`scripts/export_onnx.py --quantize` INT8），在 runtime 边缘 / WASM 沙箱层加载，实现**零网络 System-1 决策**。
- 这将 agentskills-runtime 与 Jev（闭源托管）彻底区分：**完全离线、自主可控、无数据出域**，是"全链路自主可控"路线的可演示证据。

---

## 5. 风险与缓解

| 风险 | 说明 | 缓解 |
|---|---|---|
| 校准漂移 | Laya 置信度需域内重新拟合温度（README/研究提到 temperature clamp） | Phase 0 做域内校准评估，按工作流设阈值 |
| 选项上限 | choice ≤32 选项/次、≤32 属性、≤10 档 | 大技能目录（如 182 技能）用 `laya_shortlist` 两阶段预筛 |
| 中文覆盖 | 英文 checkpoint 对非英语弱，多语言走 multilingual checkpoint | 重点测中文意图/工单；必要时微调 `laya-typed-decisions`（Kaggle 免费 2×T4 可跑） |
| 能力边界 | Laya 不生成文字，仅结构化决策 | 明确路由：System-1 只判断，System-2 做生成；避免越界 |
| 跨语言运维 | Laya 是 Python，需管理环境 + HF 模型下载 | 容器化或 `laya[serve]` HTTP；Phase 3 走 ONNX 固化 |
| 性能 | CPU ~200ms/问 | 评估是否可接受；上 GPU/ONNX 提速；批量 `predict_batch` 摊薄 |

---

## 6. 与 Jev 的差异化定位（赛事叙事要点）

| 维度 | Jev（TypeSafe） | Laya（本项目拟集成） |
|---|---|---|
| 许可 | 闭源 | **Apache-2.0 开源** |
| 部署 | 托管 API（数据出域） | **本地 / 离线 / ONNX 边缘** |
| 多语言 | 英文为主 | **100+ 语言（含中文重点验证）** |
| 与 runtime 关系 | 外部依赖、潜在锁定 | **可内化为 runtime 的"快思考层"** |

**一句话叙事**：agentskills-runtime 以仓颉实现全链路自主可控的 Agent 运行时，集成同为开源、可离线的 Laya System-1 决策引擎，构建"系统二慢思考 + 系统一快思考"的双驱 Agent 架构——既获得 Jev 类模型 30–190× 的决策提速与可量化置信度，又避免闭源托管带来的数据出域与供应商锁定，真正"在任何地方运行"。

---

## 7. 交付物清单（本目录）
- `research.md` — Jev/Laya 技术、业界评测与开源社区方案研究
- `spec.md` — 本应用建议方案（本文）
- `appendix.md` — 落地工件：`system1-decision` SKILL.md 模板、MCP 注册语义、Laya MCP 工具清单、对比表
