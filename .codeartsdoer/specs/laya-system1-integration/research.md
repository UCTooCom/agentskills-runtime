# 研究报告：System-1 决策模型（Jev / Laya）与 agentskills-runtime 的集成可行性

> 研究范围：以 `apps/laya`（Jev 类开源替代）为研究对象，结合业界对 Jev 的评测、案例与开源社区应用方案，评估其与 `apps/agentskills-runtime`（仓颉实现的 AI Agent 运行时）的集成与应用点。
> 研究日期：2026-09-29
> 结论先行：**Laya 是 Jev 的开源、本地化、可离线替代；其"System-1 快思考决策引擎"正好补上 agentskills-runtime 当前缺失的"快思考层"，二者在架构上高度互补，且契合本项目"全链路自主可控 / 在任何地方运行"的主线叙事。**

---

## 1. 背景：什么是 System-1 决策模型（Jev）

2026 年 9 月 15 日，TypeSafe AI（由前 OpenAI 研究员、RLHF/InstructGPT 共同发明人 Diogo Almeida 等人创办，2024 年成立，2026 年获 DCVC 领投 4000 万美元种子轮）发布 **Jev**——业界首个被定义为 **"System One" 决策模型** 的 AI 模型。

其命名来自卡尼曼《思考，快与慢》中的"系统一"（快速、直觉式判断）。与传统大语言模型（"系统二"：自回归逐 token 生成文字）不同，Jev **完全不生成文字**，只面向软件自动化场景，输入一段"状态"（文本 / JSON / 数组），并预先定义若干问题，一次性并行返回**结构化、带校准置信度的决策**。

**三类原生问题原语（与本项目集成最关键的接口）：**
- **Choice**：从最多 255 个选项中选一，返回每个选项概率 + 置信度（Jev）；Laya 的 schema 模式上限为 32 选项/次，超量用 shortlist 预筛。
- **Score**：按有序量表打分（如 0–2 / 1–5），返回概率分布 + 置信度。
- **Noul**：返回该陈述为真的概率 P(true) ∈ [0,1]（名称取自 Bernoulli 分布）。

**官方宣称指标（vendor-reported，属最佳情形）：**
- 端到端延迟 70–500ms；输入 $0.042 / 百万 token，输出免费。
- 在自有 4 个工作流评测上，相对前沿 LLM 最高 ~194× 速度、~445× 成本优势；社区独立测试实测约 5–25× 加速。
- 训练方法 **RLCD（Reinforcement Learning for Calibrated Decisions，面向校准决策的强化学习）**：让模型输出概率与实际正确率对齐——"说 80% 确定，长期就该约 80% 真确"，从而置信度可直接用于阈值门控（高置信自动执行、低置信转人工/调强模型）。
- **闭源、托管 API**，模型运行在 TypeSafe 服务器，上下文 64k（jev-1.13.0）。

**本质归纳**：Jev 把"成千上万个嵌在 Agent 循环里的小判断"（调哪个模型、哪步工具安全、哪段检索相关、Agent 是否真做完了）从"昂贵的 LLM + JSON 解析 + 防幻觉"中剥离出来，变成一次 33ms 级、schema 受限、零幻觉的结构化决策。这正是"让 LLM 别再当昂贵的 if/else"这一工程痛点的解法。

---

## 2. Laya：`apps/laya` 项目技术剖析（Jev 的开源替代）

`apps/laya` 是 NandhaKishorM / convaiinnovations 维护的 **System-1 决策引擎开源实现**，定位为 Jev 的开源替代，核心差异是 **本地化、多语言、可离线、Apache-2.0**。

### 2.1 模型与路由架构
内置三个 checkpoint，`Router` 按脚本/语言检测自动派发：

| checkpoint | 底座 | 参数量 | 上下文 | 适用 |
|---|---|---|---|---|
| `laya` | ModernBERT-large | 421M | 512 | 英文 |
| `laya-multilingual` | mmBERT-base | 322M | 1024（最长 8192） | 100+ 语言，快约 2× |
| `laya-typed-decisions` | ModernBERT-large | 421M | 1024 | 自有决策工作流微调 |

- **单次前向传播即出结果**：T4 上单问题 33ms、批量 7.2ms/问题；CPU 约 200ms/问题（`README`/`BENCHMARKS`）。
- 同样用 **RLCD**、针对严格正确评分规则（strictly proper scoring rules）训练；支持微调，自有 typed-decisions 微调 checkpoint 在 2000 条决策上准确率 0.766（基座英文 checkpoint 仅 0.362）。
- 与 Jev 一样**不生成文字、无解析、无幻觉**。

### 2.2 对外接口（开发者面）
- **Python SDK**：`from laya import Router; router.predict(state, questions)`，`questions` 用 `choice/score/noul` 字典描述；`router.decide(state, schema=...)` 支持 JSON-Schema / pydantic 驱动、直接投影出值。
- **CLI**：`laya "..." --preset triage` 等，内置 preset：triage / email / guard / moderation / router。
- **预测钩子（hooks）**：如脱敏 redaction hook，每个 state 进模型前改写，可在路由层统一做敏感信息遮蔽。

### 2.3 集成扩展面（本项目最关心的部分）
可选 extras 直接给出多种接入形态：

| extra | 能力 | 对本项目的意义 |
|---|---|---|
| `laya[mcp]` | **MCP stdio 服务** `laya-mcp-server`，暴露 `laya_predict` / `laya_decide` / `laya_preset` / `laya_route` / `laya_shortlist` / `laya_predict_batch` / `laya_route_batch` / `laya_status` | 与 runtime 的 **MCP host** 直接对接，零改 Laya 代码即可成为 runtime 的工具 |
| `laya[serve]` | FastAPI HTTP 服务（`/predict`、`/predict/batch`） | 可作为独立 HTTP 决策服务被 runtime 调用，便于容器化/远程部署 |
| `laya[onnx]` | ONNX Runtime 导出 + INT8 量化（CPU） | **边缘/离线原生**部署，契合"全链路自主可控" |
| `laya[langchain]` / `laya[langgraph]` / `laya[llamaindex]` / `laya[crewai]` | 主流 Agent 框架选择器 | 社区已验证的 Agent 集成范式可借鉴 |
| `laya-ts` | TypeScript / Node / 浏览器版 | 与 runtime 的 JS/TS SDK、web-admin 前端栈同语言，可做前端侧快思考 |

### 2.4 关键约束（集成时必须正视）
- 单次决策 **≤32 个属性（MAX_PROPERTIES）、≤32 个选项（MAX_OPTIONS）、≤10 个打分档（MAX_SCORE_LEVELS）**；超过需 `laya_shortlist` 两阶段预筛。
- 仅做结构化决策：**不**做开放问答 / 摘要 / 改写 / 代码 / 多跳推理。
- 是 Python 项目，runtime 是仓颉项目——跨语言必须经 MCP/HTTP 子进程或 ONNX 原生加载。
- 首次需从 HuggingFace 下载 checkpoint（可离线缓存）；`AGENTS.md` 明确禁止引入托管后端依赖，与本项目"自主可控"哲学一致。

---

## 3. 业界评测与案例（Jev）

### 3.1 评测数据（第三方为主，样本/提示不同，作指示性参考）
TypeSafe 自有 4 工作流评测共识键由 GPT-6 Astra / Claude Fable 5.1 预测均值构造（非人工真值），故其 193.6×/444.6× 为最佳情形；独立测试（JourdanLabs ASSAY-001 预注册校准研究、AY Automate、Beri.net 等）实测约 5–25× 加速仍显著优于传统 LLM。

生产侧遥测（社区/厂商披露）：在某多 Agent 管线中作调度 governance，端到端执行时间下降 94%、API 账单下降 85% 以上；浏览器智能体 Google Flights 搜索全程 7.1s，每步决策中位 146ms；桌面/移动端 computer-use 每步约 $0.0002；Doom demo 约 10 查询/秒。

### 3.2 典型案例（"20 个 Agentic 用例"）
- **路由与编排**：模型路由（按难度分派快/强模型，LangChain `ModelRouterMiddleware`）、技能选择（从 182 技能目录选 ≤1 个，2 次请求）、类型化函数调用、工单分诊（部门+情绪+紧急度一调用返回）。
- **安全与护栏**：工具调用风险门控（pi-warden：判断是否不可逆/偏离任务）、只读自动放行（jev-auto-approve，p≥0.95 才自动批准）、密钥泄露防护（jev-secret-guard，脱敏串判定）、提示注入筛查（RAG 植入注入片段 cosine 0.584 排第一，Jev 打 0.99 并丢弃）、LLM 输入/输出护栏（按危险概率阈值 pass/review/block/route）。
- **检索与溯源**：重排（CLERC 法律查询 top-1 5%→18%、top-10 38%→62%）、引用核验（单 Choice 判定片段支持/反驳/无关）。
- **浏览器/实时控制**：Browser Use 的 Jev Ultrafast、桌面/移动 computer-use、实时游戏 Agent。
- **Agent 质量与记忆**：循环停滞检测（ProgressGate：CONTINUE/WARN/REPLAN/HALT）、"完成"声明核验（jev-belay：先查 transcript 证据再信 done）、上下文压缩（fast-jev-compaction：对 tool call 打分、丢弃陈旧项而非摘要）。

### 3.3 商业落地
发布一周内被 **Vercel、Cloudflare、LangChain** 集成；极光 **GPTBots.ai** 以"两层架构（一层思考、一层判断）"把模型路由、RAG 动态 Top-K、FlowAgent/Workflow 意图分类统一到 Jev 决策引擎，引入可配置置信度阈值（高置信自动执行 / 复核 / 升级人工），强调"适配犯错的成本，而非只追求做对的速度"。

---

## 4. 开源社区应用方案（重点）

### 4.1 Jev 生态（社区克隆与适配器，发布 48h 内即出现 6 个社区克隆）
- 框架层：LangChain（`Building an Agent Harness with Jev` + LangGraph 状态机）、Vercel AI Gateway、Cloudflare Workers AI。
- 编排/钩子：jev-router（Claude Code / Codex 逐轮路由）、jev-auto-approve、jev-secret-guard、pi-warden、ProgressGate、jev-belay、fast-jev-compaction。
- 检索/护栏：reranking、citation check、guardrails cookbook。
- 端侧控制：Browser Use（Jev Ultrafast）、typesafe-computer-use、Mobile Jev。

### 4.2 Laya 生态（项目本身即交付这些，可直接复用）
- **MCP 服务**（见 2.3）：与任何 MCP 客户端（Claude Desktop / Cursor / OpenClaw 等）即插即用。
- **HTTP 服务**：`examples/server.py` 自带双栏 playground + JSON API。
- **主流框架选择器**：LangChain / LangGraph / LlamaIndex / CrewAI 集成 extras。
- **ONNX + INT8**：CPU 量化导出，边缘离线。
- **laya-ts**：浏览器/Node 同语言版本，含 Colab 与 HuggingFace Space 在线 demo。

> 社区方案的共性：**把"判断"从"生成"中剥离，用 System-1 决策做 Agent 循环里的路由/护栏/停滞检测/压缩，用置信度阈值驱动"自动 / 复核 / 升级"三态执行**。这正是本项目可直接借鉴的成熟范式。

---

## 5. Laya vs Jev 基准对比（来自 `laya/BENCHMARKS.md`，Jev 数字为第三方公开、未在本机测量）

| 指标 | Laya | Jev（公开） |
|---|---|---|
| typed-decisions（2000 决策） | **0.766** | 0.727 |
| AG News（4 类） | **0.953** | 0.910 |
| DAIR Emotion（6 类） | **0.600** | 0.480 |
| 温度拟合后 ECE（越低越好） | **0.081** | 0.246 |
| p50 延迟，单问题（T4） | **32.8ms** | 236–276ms |
| 许可 / 部署 | **Apache-2.0，本地/离线** | 闭源，TypeSafe 托管 API |
| 多语言 | **100+ 语言（multilingual checkpoint）** | 英文为主 |

> 注：Jev 数字为第三方公开、样本/提示不同，作指示性参考；Laya 数字为本仓库复现。Laya 在准确率、校准（ECE）、延迟三项均占优，且**开放、可离线、多语言**——对"国产自主可控 / 全链路自主可控"路线是更优底座。

---

## 6. 小结：对本项目的含义

1. **范式契合**：agentskills-runtime 当前是"系统二"（LLM 驱动的 deliberative Agent 循环）；Laya 提供"系统一"（本地、快速、带校准置信度的结构化决策）。二者构成 **System-1 + System-2 双驱**，正好呼应本项目已有的"dual-drive"主张。
2. **架构契合**：runtime 已有 MCP host、插件/SKILL.md 体系、审批与回滚、技能注册表、上下文优化、RAG 重排等能力，Laya 的 8 个 MCP 工具可**零改 Laya 代码**作为 runtime 工具接入。
3. **路线契合**：Laya 本地/离线/Apache-2.0，与 Jev 的闭源托管形成鲜明对比，强化了"全链路自主可控、在任何地方运行"的赛事叙事。
4. **风险可控**：约束清晰（32 选项/次、不生成文字、Python 跨语言），可在 Phase 1 以 1–2 个低风险决策点做 PoC 验证。

详见同目录 `spec.md`（应用建议方案）与 `appendix.md`（落地工件模板）。
