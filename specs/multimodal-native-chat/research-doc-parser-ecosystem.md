# 研究：文档解析生态与智能体技能市场复用（决定「解析外置」可行性的依据）

> 工程目录：`specs/multimodal-native-chat`
> 研究日期：2026-10-15
> 研究动机：v1 把文档解析做在 `agentskills-runtime` 宿主体内（`src/app/services/multimodal/`），但同族格式（doc / docx）的解析栈完全不同，新增格式成本不收敛。本次调研回答一个问题：**能不能不自研，直接复用生态已有的文档解析能力？**
> 结论用途：为本工程 v2 架构调整（解析能力外置到 L2/L3 插件轨）提供事实依据。

---

## 0. 结论速览（TL;DR）

1. **不必自研**：文档解析是被生态解决了多年的问题。Microsoft `MarkItDown`（开源 Python，PDF/DOCX/PPTX/XLSX/HTML/CSV/JSON/XML/EPUB/图片 OCR/音频/ZIP/Outlook 全覆盖，输出 Markdown，自带插件体系与 MCP server）一个库就覆盖了本工程 v1 自研千余行代码才做到的三种格式。
2. **有标准可依**：Agent Skills 是**开放标准**（Anthropic 发起并开源，核心就是一个含 `SKILL.md` 的文件夹，可选带 `scripts/` / `references/` / `assets/`），已被大量 agent 产品采用。本工程的 agentskills 技能体系与之同构 ⇒ **生态里的解析技能可以被直接装配**。
3. **技能市场供给充足**：公开技能市场已有成规模的文档解析类目（LobeHub「PDF & Documents」分类、SkillHub、skillmd.ai 等），涵盖 `document-extraction`（LandingAI ADE）、`mineru`（MinerU，支持 PDF/Office/EPUB/HTML/CSV 等并给出 page/block 级定位）、`paddleocr-doc-parsing`、`document-qa`、`document-processor`（自带 `scripts/extract_pdf.py` / `extract_docx.py`）等。
4. **复用前提是"进程外"**：这些生态实现的运行时是 **Python / Node**，不是仓颉。要复用它们，**宿主必须能把解析请求发到宿主外的进程**——这正是本项目已有的 **L3 进程隔离轨（cordis-cj，mode: process）**。
5. **因此架构调整为**：宿主只做接收/调度/提交，**格式解析全部外置**；优先复用生态实现，v1 自研抽取器降级为「无外部依赖场景下的兜底参考实现」，而不是唯一实现。
6. **门控必须按模型实例能力，而非 provider 名**：经复核，DeepSeek 现已发布原生多模态视觉模型 **`deepseek-flash`**（原 `deepseek-v4-flash-vision-exp`；V4.1-Flash 亦具备原生多模态视觉理解），支持 JPEG/PNG/GIF/WebP、OpenAI 兼容 content 块、Files API、单请求最多 600 张图（见 <https://api-docs.deepseek.com/zh-cn/guides/vision>）。因此「deepseek = 纯文本」的旧判断已不成立，上传 UI 门控必须读取目标模型实例的 `MultimodalCapability` 判定，不能按 provider 名假设（详见 `problem-analysis.md` §4 更正说明）。

---

## 1. 调研范围与方法

- 沿三条线调研：① 通用文档解析库（是否能一站式覆盖多格式）；② 智能体技能标准与技能市场（是否有可复用的现成技能）；③ 本项目宿主能否承载非仓颉运行时（L2/L3 轨可行性）。
- 证据口径：以官方文档/仓库与市场页面为准；对无法当场验证的条目，进 §7「待核实清单」，**不在本文档中断言**。

---

## 2. 通用文档解析库：MarkItDown

| 维度 | 事实 |
|---|---|
| 定位 | Microsoft 开源的轻量 Python 库，把各种文件转成**面向 LLM 的 Markdown** |
| 覆盖格式 | PDF、Word(.docx)、PowerPoint(.pptx)、Excel(.xlsx)、HTML、CSV、JSON、XML、EPUB、ZIP（递归处理）、Outlook(.msg)、RSS、Wikipedia、图片（OCR / LLM 描述）、音频（转写）、YouTube（字幕） |
| 输出 | 保留标题层级、列表、表格、链接的 Markdown —— 对 LLM/RAG 友好，且 token 效率优于 HTML |
| 扩展点 | 插件体系（`markitdown-ocr` 为 PDF/DOCX/PPTX/XLSX 提供 OCR）；可接 Azure Document Intelligence 处理复杂版面与扫描件 |
| 集成形态 | Python API（`MarkItDown().convert(path).text_content`）、CLI、Docker、**内置 MCP server** |
| 社区量级 | GitHub 星标 11 万+ 量级（公开资料口径 110K~125K，随时间增长） |

**对本工程的意义**：本工程 v1 为覆盖 PDF/DOCX/PPTX 自研了 `pdf_text.cj` / `office_text.cj` / `zip_lite.cj` / `xml_text.cj` 四个文件、千余行字节级代码，且 CID 编码中文 PDF 仍读不准；而 MarkItDown 一个依赖就覆盖了同样范围且质量更好。**这直接证明了"自研"不是必需项**。

---

## 3. 智能体技能标准与技能市场

### 3.1 Agent Skills 开放标准

- 一个技能 = 一个文件夹，核心是 `SKILL.md`（至少含 `name` / `description` + 操作指引），可选带 `scripts/`（可执行代码）、`references/`（参考资料）、`assets/`（模板资源）。
- 加载机制是**渐进披露**：启动时只加载 name + description → 任务命中时加载完整 `SKILL.md` → 执行时按需跑脚本 / 读参考文件。上下文占用小，可挂载大量技能。
- 该格式由 Anthropic 发起并作为开放标准发布，已被众多 agent 产品与客户端支持。

**对本工程的意义**：本工程的 agentskills 技能体系与这一形态同构 ⇒ 生态里的解析技能在**结构上**可被本工程装配，只需要一个适配层（`SkillAdapter`）把「技能脚本」包成宿主的 `DocumentParser` 契约。

### 3.2 技能市场中的文档解析供给（公开市场样例）

| 市场 | 典型解析类技能 | 说明 |
|---|---|---|
| LobeHub Skills Marketplace（「PDF & Documents」分类，全站技能量 30 万+ 量级） | `document-extraction`（LandingAI ADE，结构化 Markdown + 版面理解 + 视觉定位，支持大文档异步）、`document-workflows`、`paddleocr-doc-parsing`、`document-qa`、`contract-review`、`nutrient-document-processing` | 覆盖 PDF/Office/图片，从「解析」到「抽取 schema」到「批量流水线」各有专精 |
| SkillHub | `mineru`（MinerU） | 命令行文档阅读器，支持 PDF（含扫描件）、图片、Word、PPT、Excel、RTF、ODF、EPUB、OFD、HTML、MHTML、CSV；输出可续读的 page/block 定位（`doc:{id}/tier:{t}/page:{n}/block:{n}`），适合长文档 |
| skillmd.ai | `document-processor` | 自带 `scripts/extract_pdf.py` / `extract_docx.py` / `requirements.txt`，典型「SKILL.md + 脚本」形态 |

**结论**：文档解析不是稀缺能力，市场里**按格式、按模型（OCR / ADE / PaddleOCR / MinerU）、按场景（合同审查 / 表格抽取 / 批量流水线）**已有细分供给。本工程应当做**装配者**，而不是重新实现者。

### 3.3 技能适配与安装时轨决策（实施约束）

- **略作适配是可预期的**：市场既有技能（如 `document-processor` 自带 `extract_pdf.py`）直接运行时，往往与本项目约定（输入三要素 `filename/mimeType/bytes`、输出 `ParseResult`、错误码映射、超时/截断遵守 `limits`）不完全一致，需要一层薄适配。适配**不改写技能实现本体**，只在外层包装（见下条 `SkillAdapter`）。
- **轨形态由安装时决定**：某技能最终以「纯文档技能（直接调脚本）/ L2 动态库轨 / L3 进程隔离轨」接入，**不在架构层预先固定**，而是在该技能被安装进 agentskills-runtime 时，按其实现语言、隔离需求与运行环境具体决策。例如：Python 生态的 MinerU 走 L3；仓颉自研的轻量解析器走 L2；仅含脚本、无独立进程需求的技能可走「纯文档技能」轻封装。
- **决策是数据驱动、可逆的**：适配形态与优先级随技能注册信息登记，可由管理员在插件管理界面调整/卸载，不触发宿主重编。这与「门控按模型实例能力」「解析器按优先级替换」共同构成「稳定消费 + 不稳定实现」的分离主线。

---

## 4. 宿主能否承载非仓颉运行时：三轨机制

本项目已有插件三轨（见 `docs/ref/cangjie-plugin-system-feasibility.md` 附 7.14.4）：

| 轨道 | 加载机制 | 插件形态 | 对解析场景的适配性 |
|---|---|---|---|
| 内嵌轨（mode: sync） | 编译进宿主 | 宿主内子包 | ✗ 与「解析外置」目标冲突，不用 |
| **L2 动态库轨（mode: dylib）** | `PackageInfo.load` 热加载 | 预编译动态库 | ✓ 适合仓颉实现的轻量解析器（如存量抽取器搬迁），零 IPC |
| **L3 进程隔离轨（mode: process）** | cordis-cj 拉起子进程 + stdio/jsonrpc | 独立可执行文件 | ✓✓ **可承载 Python/Node 生态解析器**；崩溃隔离、资源可回收 |

**关键推论**：L3 轨的进程边界使「解析器的实现语言」与「宿主语言」解耦 ⇒ 复用 MarkItDown / MinerU / PaddleOCR 这类 Python 实现在工程上是可行的，且天然获得故障隔离（解析崩溃不拖垮宿主）。

**既有约束（必须遵守）**：
- L3 插件进程的 **stdout 是 stdio RPC 独占通道**，诊断日志一律走 stderr；
- 插件不直连 DB，需宿主能力时经 `host.db` / `host.log` 等服务代理反向调用；
- 插件登记走 `plugins.yaml` 与 `agent_skills` 状态回写（PluginSyncBridge），安装/卸载不重编宿主。

---

## 5. 候选方案评估

| 方案 | 覆盖面 | 质量 | 维护成本 | 依赖风险 | 隔离性 | 采纳 |
|---|---|---|---|---|---|---|
| A. 宿主内自研（v1 现状） | 逐格式扩张 | 中（CID 中文 PDF 读不准） | **高**（每格式千行级 + 重编宿主） | 无外部依赖 | ✗ 同进程 | ✗ 不作为主路径 |
| B. L2 轨自研解析器（存量搬迁） | 已覆盖 PDF/DOCX/PPTX/文本族 | 中 | 中 | 无 | 同进程（需宿主做异常边界） | ✓ **首个参考实现**，保证零外部依赖场景可用 |
| C. L3 轨复用生态实现（MarkItDown / MinerU / PaddleOCR …） | **广**（含扫描件 OCR、表格、版面） | 高 | 低（升级 = 升级插件） | 需 Python/Node 运行时 | ✓ 进程隔离 | ✓ **优先路径** |
| D. `SkillAdapter` 装配技能市场既有技能 | 取决于市场供给 | 取决于具体技能 | 低 | 技能质量参差（需评审） | 随其承载轨 | ✓ **生态接入通道** |

**采纳顺序**：先 B（保证可用、零依赖），再 C（提升覆盖面与质量），同时提供 D（生态接入通道）。三者共用同一套 `DocumentParser` 契约，对宿主完全透明。

---

## 6. 决策与对架构的影响

| 决策 | 内容 |
|---|---|
| D1 | 文档格式解析**全部外置**到宿主外插件（L2/L3 轨），宿主只保留接收、归一化、调度、提交、留痕、兜底 |
| D2 | 图片链路**保留在宿主内**——它是通道能力（dataURL → `image_url` 块），不涉及格式解析，因此不受 D1 影响 |
| D3 | 优先复用生态实现；v1 自研抽取器搬迁为 L2 轨首个插件，定位为「零外部依赖场景的兜底实现」而非唯一实现 |
| D4 | 提供 `SkillAdapter`，使标准技能形态（`SKILL.md` + `scripts/`）的既有解析技能可被直接装配 |
| D5 | 宿主侧新增 `DocumentParser` SPI + `ParserRegistry`，作为唯一契约与装配点；宿主不 import 任何插件代码 |

---

## 7. 待核实清单（实施前必须逐条落实，不得凭本文档断言）

1. **运行环境**：目标部署环境是否具备 Python 3.10+ / Node 运行时？若不具备，C 方案退化为「仅在服务端可用」。
2. **许可与合规**：拟复用的生态实现（MarkItDown / MinerU / PaddleOCR / 市场技能）各自的 License 与分发要求，需与本项目 MIT 协议兼容并登记。
3. **市场技能安全**：技能市场页面明确提示「技能为第三方公开仓库代码，市场只做已知恶意模式扫描、不保证安全」⇒ 接入前必须做**源码评审 + 沙箱试跑**，并在插件安装环节提示风险。
4. **体积与耗时**：大文档（>100 页 / >20MB）经 L3 轨 IPC + Python 解析的端到端耗时，需实测确认是否落在 10s 预算内；超出则需分页/异步化。
5. **L3 轨 Windows 可编译性**：`docs/ref/cangjie-plugin-system-feasibility.md` 记录的 Spike-1/Spike-2（工具链与 Windows stdio 编译）结论需复核，未通过则 L3 轨暂不可用、先走 L2。
6. **MCP vs 自定 SPI**：MarkItDown 自带 MCP server，是「直接以 MCP 工具接入」还是「包成 `DocumentParser` 契约」更优，需在 `doc-parser-plugins` 子系统 design 步论证（当前倾向后者：契约统一，宿主调度逻辑不用分叉）。
7. **DeepSeek 模型视觉能力矩阵**：`deepseek-flash` 已确认支持原生视觉（JPEG/PNG/GIF/WebP、OpenAI 兼容 content 块、Files API、单请求最多 600 张图）；需核实本项目 `channel_registry` / `builtin_seed` 是否已登记 `deepseek-flash` 的 `supportImages=true`，以及 `deepseek-chat` / `deepseek-reasoner` 等是否仍无视觉能力——上传 UI 门控依赖这份能力矩阵正确（见 `problem-analysis.md` §4 更正）。

---

## 8. 参考链接

- Agent Skills 开放标准总览（SKILL.md 格式、渐进披露、客户端生态）：https://skill.md
- LobeHub Skills Marketplace（PDF & Documents 分类）：https://lobehub.com/skills?category=pdf-documents
- SkillHub（mineru / MinerU 技能页）：https://skills.palebluedot.live/en/skill/opendatalab/MinerU/mineru
- skillmd.ai（document-processor 技能结构）：https://skillmd.ai/how-to-build/document-processor-2/
- Microsoft MarkItDown（仓库与文档）：https://github.com/microsoft/markitdown
- 本项目三轨机制可行性：`docs/ref/cangjie-plugin-system-feasibility.md`（附 7.14.4 / 附 7.14.5）
