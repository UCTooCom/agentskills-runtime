# 问题分析报告：Agent 聊天原生多模态支持（图片 / 文档上传与处理）

> 工程目录：`specs/multimodal-native-chat`
> 关联仓库：
> - 前端 `web-admin`：`D:\UCT\projects\uctoo\apps\web-admin`
> - 运行时 `agentskills-runtime`：`D:\UCT\projects\uctoo\apps\agentskills-runtime`
> 触发背景：对接 deepseek 模型通道时发现，web 端 tiny-remoter 聊天组件没有图片上传通道，且 runtime 不接收随聊天内容上传的图片/文档。
> **版本**：v2（2026-10-15）—— 在 v1 调研（B1/B2/B3 三个链路断点）基础上，新增 **B4 架构断点**：文档解析能力内聚在宿主体内，不可持续。

本文件记录对「端到端聊天多模态断点」的调研结果，全部结论均附**已核实的代码文件:行号**，供 `spec.md` / `design.md` 直接引用。

---

## 1. 调研方法

沿「用户上传 → 前端组件 → webmcp SDK → 后端 WebMCP 协议 → Agent 执行器 → ChatModel → LLM HTTP 请求」逐层 grep + 读源码，定位每一处「有通道但被丢弃 / 只支持单图 / 不解析数组」的断点。

关键发现有两轮：

- **第一轮（v1）**：后端到 LLM 的「单图 → image_url 块」链路其实已经通了（`OpenAIChatModel` 已支持），真正断在「前端把附件丢进纯文本」和「WebMCP 入口不解析多模态 content 数组」两处。
- **第二轮（v2，本次）**：打通之后暴露出**架构层面**的问题——文档解析是格式强相关的无限膨胀面，把它放在宿主体内会持续污染宿主、且无法复用外部生态。这是本次架构调整的直接动因。

---

## 2. 现状逐层盘点（附证据）

> 状态图例：`✅已修`（本工程已落地）/ `⚠️遗留` / `🔴架构问题`

### 2.1 前端 UI —— 上传按钮已存在，但被门控 + 发送时丢弃
- `web-admin/src/lib/webmcp-sdk/packages/next-remoter/src/components/TinyRobotChat.vue`
  - L75-76：`TrUploadButton` 已存在，`accept="image/*,application/pdf,.doc,.docx,.txt"`、`:multiple="true"`、`@select="onFilesSelected"`。
  - L58-62：附件预览 `TrAttachments v-model:items="attachments"` 已存在。
  - 按钮可见性由 `hasMultimodalSupport` 门控（L75 `v-if="hasMultimodalSupport"`）。
- `hasMultimodalSupport` 来源（`useMultimodal.ts` `useMultimodalWithModel`）：原实现 `= selectedModel.value?.multimodal?.supportImages`（仅图片门控）。选中的模型没有 `supportImages` 时，连图片按钮都不显示。
- **状态**：`✅已修` —— 门控已扩展为「图片能力 或 supportedMimeTypes 含文档 MIME」；`accept` 已补齐 `.ppt/.pptx/.md/.csv/.json`；`SendStopButton` 的 disabled 由 `!inputMessage.trim()` 改为 `!inputMessage.trim() && attachments.length === 0`（原「只传图不打字」发不出去）。

### 2.2 前端附件 → content 拼接 —— 只认图片，且格式与后端不对接
- `web-admin/src/lib/webmcp-sdk/packages/next-remoter/src/multimodal/useMultimodal.ts`
  - 原 L35-64 `convertAttachmentsToContent`：遍历附件，**仅 `isImageFile` 才 push**（L48），PDF/PPT/DOC 被静默丢弃。
  - 产出的形状是 **AI SDK 格式** `{ type: 'image', image: base64Data }`（L49-52），**不是** OpenAI 的 `{ type: 'image_url', image_url: { url } }`，后端不认这个形状。
- **状态**：`✅已修` —— 保留 AI-SDK 形状并补 `filename`（避免破坏 AI-SDK 直连路径），新增非图片 `{type:'file-pending', filename, mimeType, data}` 分支；形状归一化统一放到 WebMCP 边界 `AgentModelProvider.normalizeContentForWebMCP`。

### 2.3 前端发送 —— 核心断点：附件被强制降级为纯文本
- `web-admin/src/lib/webmcp-sdk/packages/next-remoter/src/composable/useTinyRobotChat.ts`
  - L418-471 `handleSendMessage(_inputValue, attachmentsContent?)`：当 `attachmentsContent` 非空时（L445），**只调用 `sendMessage(_inputValue)` 发纯文本**，附件被完全忽略（L452-453）。
  - L449-451 有 TODO 自陈：「0.5.1 的 sendMessage 仅接受纯文本，多模态需通过 `engine.messages.value.push + engine.send()` 实现，暂时退化为纯文本发送」。
  - 这就是用户感知到「无法上传图片」的真正根因：**不是没 UI，是发送通道没接线**。
- **状态**：`✅已修` —— 改为 `engine.send({ role:'user', content:[text块, ...附件块] })`。RISK-1 已核实：tiny-robot-kit 0.5.1 d.ts 明确 `sendMessage:(content:string)=>Promise<void>`、`send:(...msgs:ChatMessage[])=>Promise<void>`，且 `ChatMessage = ChatCompletionMessageParam`（content 支持块数组）。

### 2.4 SDK 通道 —— 已能透传 content 数组（无缺口）
- `web-admin/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts`
  - `_chatViaWebMCP`（L1104 起）构造请求体：`{ method:'completion/complete', params:{ model, messages, stream:true }, jsonrpc:'2.0', id }`（L1202-1207）。
  - `messages` 数组**原样透传**（L1158-1166）。
  - 结论：**只要前端把多模态 content 数组塞进来，后端就能收到，SDK 层无需改**。
- **状态**：`✅无缺口`（通道能力，未改动）。

### 2.5 后端 WebMCP 入口 —— 核心断点：把 content 拍平、不解析多模态
- `agentskills-runtime/src/app/services/webmcp/WebMCPProtocol.cj`
  - `handleCompletionComplete`（非流式主路径）原 L1285-1319：无论 content 是字符串还是数组，**都被拍平成字符串**（L1298-1302：`contentVal.toString().replace("\"","")`）；**不抽取 `image` / `image_url` / 文件块**。
  - 随后 `AgentRequest(userMessage, conversation:)`（L1373）——**没传 `image:` 参数**，`request.image` 永远 `None`。
  - 流式分支（L1542-1559 解析、L1633 `AgentRequest`）同样不解析多模态。
- **状态**：`✅已修` —— 新增 `MultimodalContentParser`，同步 + 流式**两条分支**均接入；纯字符串时行为不变；附件只取最后一条 user 消息（防多轮重复注入）；新增 `<attachment_notices>` 留痕回灌。

### 2.6 后端 AgentRequest / Message —— 单图结构，无多附件
- `src/core/agent/agent_request.cj`：原仅 `image: Option<String>`（L27/L56/L115）。
- `src/core/message/message.cj`：`Message` 原仅 `content: String` + 单个 `image: Option<String>`（L14-35），无多附件概念。
- **状态**：`✅已修` —— `Message` 加 `images` / `fileParts` + `allImages()`（合并旧 `image`，老调用方零改动受益）；`AgentRequest` 加 `images` / `files`；新增 `FilePart`（`core/message/file_part.cj`）与 `Attachment`（`core/agent/attachment.cj`）。

### 2.7 后端 Agent 执行器 —— 已消费 image（链路半通）
- `src/agent/conversation_agent.cj:82`、`src/agent_executor/common/agent_execution_info.cj:199,235`、`src/tool/vision_tools.cj:188`。
- **状态**：`✅已修` —— 消费方改为 `images: request.allImages()`。

### 2.8 后端 ChatModel 序列化 —— 单图→image_url 块已支持（关键利好）
- `src/model/openai/chat.cj` `messageList2Json`（原 L327-369）：`msg.image` 有值时 content 输出数组 `[{type:"text",...},{type:"image_url",image_url:{url}}]`。
- 同类：`ollama/chat.cj:190`（独立 `images` 数组）、`tokendance/chat.cj:319`、`stepfun/chat.cj:318`。
- **状态**：`✅已修` —— 支持多 `image_url` 块 + fileParts 文本块。

### 2.9 🔴 文档解析内聚在宿主体内 —— 架构断点 B4（本次新增）

在补齐 PDF/DOCX/PPTX 真抽取的过程中，暴露出四个不可持续的信号：

| 信号 | 证据 |
|---|---|
| **同族不同实现** | `.doc` 是 OLE 复合文档、`.docx` 是 ZIP + OOXML + deflate，两者解析**毫无共享代码**；`.ppt` / `.pptx` 同理。所谓「一族格式」只是用户视角，工程上是完全不同的格式栈 |
| **成本不收敛** | 为覆盖 3 类格式新增 `pdf_text.cj` / `office_text.cj` / `zip_lite.cj` / `xml_text.cj` 四个文件、千余行**字节级**代码；每加一种格式（XLSX / EPUB / ODT / CAD …）都要再来一遍 |
| **质量天花板低** | 自研 PDF 抽取只覆盖 FlateDecode，CID 自定义编码的中文 PDF 无 ToUnicode 时必然乱码；而生态里的 `pdfplumber` / `python-docx` / `python-pptx` / `markitdown` 已解决多年 |
| **与工程红线冲突** | 项目红线：`src/app/` 存量冻结、只减不增，功能拓展优先做成插件；把格式解析塞进 `src/app/services/multimodal/` 与红线相悖。且解析是**重依赖、易崩溃**的能力，放同进程会把宿主拖下水 |

**根因表述**：v1 把「**稳定的消费契约**」与「**不稳定的格式实现**」混在了同一个进程、同一个模块里。变化频率差一个数量级的两类代码耦合在一起，必然随格式增长而失控。

**结论（B4）**：必须把文档格式解析**整体外置**到宿主外的插件轨（L2 动态库轨 / L3 进程隔离轨），宿主只保留接收、归一化、调度、提交、留痕与兜底。

---

## 3. 根因总结（4 个断点）

| # | 断点 | 位置 | 现状 |
|---|------|------|------|
| B1 | 前端发送丢弃附件 | `useTinyRobotChat.ts:445-456` | ✅ 已修（`engine.send` 带 content 块数组） |
| B2 | 前端仅拼图片 + 格式不对 | `useMultimodal.ts:48-53` | ✅ 已修（补 file-pending 分支；归一化移入 WebMCP 边界） |
| B3 | 后端入口不解析多模态 | `WebMCPProtocol.cj:1298-1302,1373` | ✅ 已修（双分支接入 `MultimodalContentParser`） |
| **B4** | **文档解析内聚宿主** | `src/app/services/multimodal/{document_ingestion,pdf_text,office_text,zip_lite,xml_text}.cj` | **🔴 架构问题 —— 本次调整对象**（v2 要求全部外置到 L2/L3 插件轨） |

> B1~B3 是**链路断点**（通道没接线），已修；B4 是**架构断点**（能力放错了位置），是 v2 的核心议题。

---

## 4. 关键约束（设计必须遵守）

> **信息更正（2026-10-15 复核）**：本节 v1 表述「deepseek 等纯文本模型」已**过时**。经调研 DeepSeek 官方（<https://www.deepseek.com/> 与 <https://api-docs.deepseek.com/zh-cn/guides/vision>）：DeepSeek 现已发布原生多模态视觉模型 **`deepseek-flash`**（原 `deepseek-v4-flash-vision-exp`；V4.1-Flash 亦具备原生多模态视觉理解），支持 JPEG/PNG/GIF/WebP、OpenAI 兼容 content 块、Files API、单请求最多 600 张图。**因此不能按 provider 名假设能力，门控必须按「模型实例的能力声明」判定。**

1. **模型能力门控必须按实例能力判定，不能按 provider 名硬编码**：门控读取的是目标模型实例的 `MultimodalCapability`（`supportImages` / `supportedMimeTypes`），而非「某个 provider 是否支持」。例如同属 DeepSeek，旧 `deepseek-chat` 可能无视觉能力，而 `deepseek-flash` 已支持原生视觉——门控逻辑必须对两者区别对待，不得把整个 provider 一律判为纯文本。
2. **文档必须经解析转文本/图像块后再提交**：无论目标模型是否支持 vision，文档（PDF/PPTX/DOCX…）都**不**以原始文件块直发，而是由宿主外的解析插件转成带来源标注的文本块（可选图像块）后随聊天提交。这一约束是架构决定的（解析外置），与「模型是否纯文本」无关。
3. **前端 0.5.1 SDK 的 `sendMessage` 只收纯文本**：多模态需走 `engine.send()`（已核实 d.ts，RISK-1 已消除）。
4. **🔴 宿主内不得新增格式解析代码**（v2 新增硬约束）：新增一种格式的支持 = 新增/安装一个解析插件，不是改宿主源码。
5. **🔴 解析插件必须能被替换**（v2 新增）：同一格式允许多个解析器共存并按优先级命中，允许管理员卸载；不得出现「宿主硬编码某个解析器」。
6. **绝不静默丢弃**：历史 bug 的根因形态就是「附件被接收后无声消失」。任何丢弃/失败都必须留痕并回灌到用户消息。

---

## 5. 结论

### 5.1 已完成（v1 最小改动集，P0/P1 已落地待联调）

1. 前端 B1：`handleSendMessage` 构造多模态 content 数组并 `engine.send()`。
2. 前端 B2：`convertAttachmentsToContent` 支持非图片；形状归一化收敛到 WebMCP 边界。
3. 前端门控：`hasMultimodalSupport` 扩展为「图片或文档能力」，`accept` 覆盖 ppt/pptx。
4. 后端 B3：`WebMCPProtocol` 双分支解析 content 块数组。
5. 后端结构：`Message` 多图 + fileParts；`AgentRequest` 加 `images`/`files`。
6. 后端序列化：各 `ChatModel.messageList2Json` 输出多 `image_url` 块 + 文档文本块。

### 5.2 本次架构调整要做的事（v2，针对 B4）

7. **定义 `DocumentParser` SPI 与 `ParserRegistry`**，作为宿主与解析插件之间的唯一契约与装配点。
8. **宿主侧去掉格式解析实现**：`document_ingestion.cj` 由「抽取器」重构为「调度器」；`pdf_text/office_text/zip_lite/xml_text` 迁出宿主。
9. **存量抽取器搬迁为首个解析插件**（L2 轨先行），并要求搬迁前后解析结果等价（fixtures 校验）。
10. **支持生态复用**：`SkillAdapter` 把 agentskills 标准技能包装成解析器；L3 进程隔离轨承载非仓颉生态（Python/Node 解析库）。
11. **拆分为 4 个子系统 SDD 工程**（见 `SPECS_INDEX.md`），各自独立六步与闸口。
12. **持久化（P2）**：`AgentMessagesPO`/`MessagesPO` 增加 `attachments` 列（须论证复用不成立），支持多轮对话回带附件元数据。

详见 `spec.md`（需求规格 v2）与 `design.md`（总体架构与拆分决策）。
