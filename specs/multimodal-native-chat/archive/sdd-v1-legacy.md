> **【归档说明】** 本文件是 v1 的合并版设计（2026-10-14），已被 v2 架构调整版取代：需求规格见 `../spec.md`、总体设计与拆分决策见 `../design.md`、子系统目录见 `../SPECS_INDEX.md`。v1 与 v2 的核心差异是**文档解析能力从宿主内自研改为宿主外 L2/L3 插件轨**。本文件保留备查，不再维护。（注：文中「deepseek 为纯文本模型」「deepseek 不支持文件块」等判断已过时——DeepSeek 现已发布 `deepseek-flash` 原生多模态视觉模型，门控须按模型实例能力判定，详见 v2 的 `problem-analysis.md` §4。）

# SDD：Agent 聊天原生多模态支持（图片 / PPT / PDF）

> 工程目录：`specs/multimodal-native-chat`
> 配套文档：`problem-analysis.md`（现状与断点证据）、`research-opentiny-official.md`（OpenTiny 官方做法研究）、`tasks.md`（任务拆分）
> 范围：让 web 端 tiny-remoter 聊天组件原生支持用户在聊天中上传**图片、PPT、PDF 等文件**，并由大模型对这些多模态内容进行处理与回复。覆盖 `web-admin` 前端 + `agentskills-runtime` 运行时两端。

---

## 1. 目标（Goal）

- G1 用户在 tiny-remoter 聊天框可选中图片并随消息发送，agent 能「看到」图片并基于图片内容回复。
- G2 用户可上传 PPT / PDF / DOC 等文档，agent 能读取其内容（文本 + 必要时的页面图像）并基于内容回复。
- G3 多模态消息与现有文本聊天、技能注入（`SkillAutoInjector`）、`<profile_context>` 等机制**并行共存、互不干扰**。
- G4 上传 UI 的出现受「模型能力」门控：仅当选中支持 vision 的模型时显示图片上传；仅当支持文档理解时显示文件上传（deepseek 等纯文本模型不显示/不接受文件块）。

## 2. 非目标（Non-Goal）

- 不做独立的「文件管理 / 知识库」系统（仅处理随聊天即时上传、随会话生命周期存在的临时附件）。
- 不改造 L3 进程插件的文件读取能力（那是 plugin 自身职责）。
- 不在本工程内训练/微调多模态模型；只做「通道 + 协议 + ingestion」打通。
- 不强制所有 provider 支持原文件块（deepseek 不支持文件块，走文本抽取降级）。
- **不重构 / 不替换** tiny-remoter 聊天组件为 GenUI SDK 的 `GenuiChat`（后者是本次 OpenTiny 直播主题，本工程仅**对齐其多模态 wire 契约**，不迁移组件）。

---

## 3. 总体数据流（端到端）

```
[用户] 在 tiny-remoter 选中 图片/PDF/PPT
   │  (TrUploadButton → onFilesSelected → convertAttachmentsToContent)
   ▼
[前端] 生成 content 数组（内部 AI-SDK 形状）
   │  image → {type:"image", image: dataURL, filename}
   │  doc   → {type:"file-pending", filename, mimeType, data:dataURL}
   ▼
[前端 SDK] _chatViaWebMCP 组包前，normalizeContentForWebMCP() 归一化为官方 OpenAI 形状
   │  image → {type:"image_url", filename, image_url:{url: dataURL}}
   │  doc   → {type:"file", file:{filename, mimeType, data:dataURL}}
   ▼
[前端 SDK] _chatViaWebMCP 原样透传 messages[]  →  WebMCP 协议
   ▼
[后端 WebMCPProtocol] 解析 content 数组：
   - text 块 → 用户文本
   - image_url 块 → images: Array<String>
   - file 块 → files: Array<Attachment>  → 文档 ingestion 服务抽取文本/图像
   ▼
[后端 AgentRequest] 携带 text + images + 抽取后的文件文本块
   ▼
[后端 执行器] Message.user(...) 组装多 content part
   ▼
[后端 ChatModel.messageList2Json]
   - 多 image_url 块
   - 文档抽取文本作为 text 块 / 可选 image_url 块（vision OCR）
   ▼
[LLM] 处理多模态内容并返回
```

---

## 4. 前后端统一内容块契约（content block contract）

约定：聊天消息的 `content` 既可是 `string`（纯文本，兼容旧链路），也可是 **OpenAI 兼容的 content 块数组**。后端以此数组为唯一解析入口。

| type | 形状 | 说明 |
|------|------|------|
| `text` | `{ type:"text", text: String }` | 文本段 |
| `image_url` | `{ type:"image_url", filename:String, image_url:{ url: String } }` | `url` 为 `data:image/png;base64,...` 内联 dataURL（无需独立上传接口）；`filename` 为原始文件名 |
| `file` | `{ type:"file", file:{ filename:String, mimeType:String, data:String } }` | `data` 为 `data:<mime>;base64,...` 内联；后端做 ingestion 抽取 |

> **官方对齐（2026-10-14 补）**：`image_url` 块形状与 **OpenTiny 官方 GenuiChat 图片上传契约完全一致**——官方原文「数据结构符合 OpenAI 兼容格式」，块形如 `{ "type":"image_url", "filename":"circle.png", "image_url":{ "url":"data:image/png;base64,..." } }`。出处见 `research-opentiny-official.md` §2 与官方文档 `genui-sdk/examples/chat/image-upload.html`。`file` 块为**官方能力之外的增值扩展**（官方组件仅支持图片上传），无官方契约，由本工程自研。
>
> 约束：**图片走 `image_url`（OpenAI 形状）而非 AI SDK 的 `{type:"image",image}`**。注意前端 SDK 内部存在**双路径**（AI-SDK 直连 `streamText` 吃 AI-SDK part，WebMCP 透传给 runtime 需 OpenAI 形状），故 AI-SDK↔OpenAI 形状的**归一化放在 WebMCP 边界**（见 §6.2b），不在 `convertAttachmentsToContent` 内强行改造（避免破坏 AI-SDK 路径）。文件统一走 `file` 块，由后端抽取，避免各 provider 文件块格式不一致的兼容地狱。

---

## 5. 文档 Ingestion 策略（PPT/PDF/DOC 的核心难点）

deepseek 等多数 OpenAI 兼容网关**不接受文件块**，且 PPT/PDF 不能直接当图像。因此采用：

- **默认策略 B（provider 无关、必做）**：后端 ingestion 服务对 `file` 块做**内容抽取**，产出 `text` content 块喂给 LLM：
  - **PDF** → 提取每页文本；可选抽取页面图像（供 vision 模型 OCR / 图表理解）。
  - **PPT/PPTX** → 解包 `pptx`，提取每页 slide 的文本（`<a:t>`）；可选渲染 slide 为图像（需 office/render 依赖，P2）。
  - **DOC/DOCX** → 提取正文文本。
  - 输出：`ArrayList<ContentPart>`，每块标注来源（如 `[PDF p.3]` / `[PPT slide 5]`），合并进用户消息文本。
- **可选策略 A（fast-path，仅当模型声明支持）**：若解析后的 `ChatModel` 声明 `supportsFileContent=true`，则直接把 `file` 块透传为 LLM 的 `file` 内容类型（如部分网关支持）。否则一律走 B。
- **超大文件**：P2 做大小上限（前端 `maxFileSize` 已有 10MB 默认，见 `useMultimodal.ts:85`）+ 分片/截断 + 错误 UX。

> 备注：此节是本工程相对 **OpenTiny 官方能力的增值部分**（官方只支持图片）。文档抽取契约自研，后续若官方推出文档协议（关注公开课第六期）应回填校正（见 `research-opentiny-official.md` §4、RISK-6/7）。

---

## 6. 分层改动设计

> 说明：§6.1 前端改动落在**本地 vendored** 的 `@opentiny/{next-remoter,next-sdk}` 源码（`package.json` 为 `file:` 依赖）。须最小化改动、记录 diff、并向上游提 PR（RISK-8）。

### 6.1 `web-admin` 前端（消费侧）

**F1 `multimodal/useMultimodal.ts` `convertAttachmentsToContent`（L35-64）**
- 保持 **AI-SDK 形状**产出（`{ type:'image', image: base64DataURL, filename }`）——该函数是 SDK 既有实现，供 AI-SDK 直连路径使用，**改动最小化**。
- 不再静默丢弃非图片（删除 L48 的 `isImageFile` 唯一分支）：图片产 `{type:'image', image, filename}`；非图片（pdf/ppt/doc）产 `{ type:'file-pending', filename, mimeType, data }`，留待 §6.2b 边界归一化转成官方 `file` 块。

**F2 `composable/useTinyRobotChat.ts` `handleSendMessage`（L418-471）**
- 删除 L449-456 的「退化为纯文本」逻辑。改为：当 `attachmentsContent` 非空时，把纯文本 + `attachmentsContent`（content 数组）组装成一条多模态 user 消息，通过 engine 推送并发送（参考 L449 TODO 指明的 `engine.messages.value.push + engine.send()`）。
- 注意：需在实施期核实 0.5.1 SDK 的 `engine` API（push 的单条消息是否接受 `content` 数组），这是前端唯一待确认的外部依赖点（RISK-1）。

**F3 `components/TinyRobotChat.vue`（L75-76）**
- `hasMultimodalSupport` 扩展语义：模型具备图片能力（`multimodal.supportImages`）**或**文档能力（`multimodal.supportedMimeTypes` 含文档 MIME）时即为 true（**沿用官方 `MultimodalCapability` 字段，不新增 `supportFiles`**）。
- `TrUploadButton` 的 `accept` 增加 ppt/pptx 与文档类型；`accept` 与门控均建议由模型 `supportedMimeTypes` 驱动，与官方 model-aware 机制对齐（`useMultimodalWithModel` 已在切模型时自动清不兼容附件，L162-188）。

### 6.2 webmcp SDK（新增一处边界归一化）

- `next-sdk/agent/AgentModelProvider.ts` `_chatViaWebMCP` 已把 `messages` **原样** POST 给 runtime（L1158-1166、L1202-1207），官方契约由此直达后端。
- 在 SDK 中固化「content 数组即多模态」约定，供前端 F1/F2 对齐（避免再次出现形状不对齐）。

### 6.2b WebMCP 边界内容归一化（新增，官方契约落点）

> 背景：SDK 有**双路径**——AI-SDK 直连 `streamText`（吃 AI-SDK part `{type:'image',image}`）与 WebMCP（原样透传给 runtime，需 OpenAI 形状）。若直接在 `convertAttachmentsToContent` 改形状会破坏 AI-SDK 路径。

- 新增 `normalizeContentForWebMCP(content: any[]): any[]`，在 `_chatViaWebMCP` 组包前对 `messages[].content` 逐块转换：
  - `{type:'image', image, filename}` → `{type:'image_url', filename, image_url:{url:image}}`（官方形状）；
  - `{type:'file-pending', filename, mimeType, data}` → `{type:'file', file:{filename,mimeType,data}}`；
  - `{type:'text', text}` → 原样。
- 归一化是**唯一**把 AI-SDK 形状翻成官方 OpenAI 形状的地点，AI-SDK 直连路径不受影响。

### 6.3 `agentskills-runtime` 运行时（生产侧）

**R1 `core/message/message.cj` —— Message 结构扩展**
- 保留 `content: String` 与 `image: Option<String>`（兼容旧代码与 `OpenAIChatModel` 现有读取）。
- 新增 `images: ArrayList<String>`（多图，dataURL 或 http URL）与 `fileParts: ArrayList<FilePart>`（文档抽取结果，`FilePart = { source:String, text:String, images:ArrayList<String> }`）。
- 新增 builder：`Message.user(content, images!: ..., files!: ...)`；`toJsonValue`/`fromJsonValue` 同步序列化 `images`/`fileParts`。

**R2 `core/agent/agent_request.cj` —— AgentRequest 扩展**
- 由单 `image: Option<String>` 扩展为 `images: ArrayList<String>` + `files: ArrayList<Attachment>`（`Attachment = { filename, mimeType, data }`）。保留 `image` 作为 `images[0]` 兼容别名或移除（需同步改 R3 消费方）。
- 解析、构造、持久化字段随之更新。

**R3 执行器消费方**
- `conversation_agent.cj:82`、`agent_execution_info.cj:199/235`、`vision_tools.cj:188`：从 `request.image` 改为读取 `request.images`/`request.files`，组装多 content part 的 `Message.user(...)`。

**R4 `app/services/webmcp/WebMCPProtocol.cj` —— 入口解析（核心 B3 修复）**
- `handleCompletionComplete`（L1285-1319，含流式分支 L1542-1559 / L1633）：当 `content` 为数组时遍历块：
  - `text` → 累积用户文本；
  - `image_url` → 收集到 `images`（块形如 `{type:'image_url',filename,image_url:{url}}`，`url` 为内联 dataURL）；
  - `file` → 收集到 `files` 并调用 ingestion 服务抽取。
- 兼容：除 OpenAI 官方形状外，可**顺带**接受 AI-SDK `{type:'image',image}`（旧链路/直连），但以官方形状为主。
- 构造 `AgentRequest` 时填入 `images`/`files`（取代现在 L1373 不传 image 的写法）。
- 向后兼容：content 为纯字符串时行为不变。

**R5 新建 `service/multimodal/DocumentIngestion` 服务**
- `ingest(attachment: Attachment): ArrayList<ContentPart>`：按 mimeType 分发到 PDF / PPTX / DOCX / 通用文本抽取器。
- P0 可只做「文本抽取」（PDF 用轻量解析、PPTX 解包 XML、DOCX 解包 XML）；图像渲染（slide→图）与 OCR 留 P2。
- 失败兜底：抽取异常时回退为「告知模型『用户上传了文件 X，但内容无法解析』」的文本提示，不崩溃。

**R6 `model/**/chat.cj` 序列化**
- `OpenAIChatModel.messageList2Json`（L327-369）扩展：除首个 `image` 外，遍历 `images` 输出多个 `image_url` 块；`fileParts` 的文本作为 `text` 块、`fileParts.images` 作为 `image_url` 块。
- `ollama/chat.cj:190`、`tokendance/chat.cj:319`、`stepfun/chat.cj:318` 同步支持多图（保持各 provider 一致性）。

**R7 模型能力门控（对齐官方 `MultimodalCapability`）**
- **不新增 `supportFiles`**（官方 `MultimodalCapability` 只有 `supportImages?` / `maxFileSize?` / `supportedMimeTypes?`）。文档能力由既有 `multimodal.supportedMimeTypes`（含文档 MIME）+ `maxFileSize` 表达；`useMultimodal.ts` 的 `hasMultimodalSupport` 据此放开（见 F3）。
- 运行时 `resolveRequestChatModel`（WebMCPProtocol.cj:1324 附近）在收到图片/文件时，若解析出的模型不支持多模态，返回明确错误而非塞给不支持的模型。

### 6.4 持久化（P2）
- `AgentMessagesPO` / `MessagesPO`：增加 `attachments` JSON 列（存 images URL 列表 + files 元数据，不含大 base64），支持多轮对话回带附件上下文。
- 迁移 SQL + `loaddbinfo` + `crudgen`/`crudweb`（按 SDD 铁律走确定性工具链）。

---

## 7. 分阶段实施

- **P0（MVP，图片优先，最快打通用户观测到的断点）**：F1(图片分支) + F2 + F3(图片门控) + §6.2b(图片归一化) + R1(images 列表) + R2(images) + R3 + R4(解析 image_url) + R6(多 image_url)。复用现有 `OpenAIChatModel` 单图序列化扩展为多图。P0 完成后即复现「上传图片→agent 看图回复」。
- **P1（文档）**：F1(file 分支) + F3(文件门控) + §6.2b(file 归一化) + R1(fileParts) + R2(files) + R4(file 块) + R5(ingestion 文本抽取) + R6(filePart 文本块)。打通 PPT/PDF/DOC。
- **P2（稳健）**：R5 图像渲染+OCR、R7 能力门控精细化、§6.4 持久化、超大文件/错误 UX、流式分支一致性校验、测试与文档。

---

## 8. 验收标准

- AC1（P0）在选中 vision 模型时，聊天框出现图片上传按钮；上传一张图并提问，agent 回复明确基于图片内容（可观测「看到了图」）。
- AC2（P0）同一会话中，多模态消息与技能注入、`<profile_context>` 正常并行，不互相覆盖。
- AC3（P1）上传 PDF/PPT，agent 能引用文档中具体页/幻灯片内容作答（deepseek 纯文本模型走抽取降级，不报错）。
- AC4 非 vision 模型（如 deepseek-chat）选中时，前端不出现图片/文件上传，且后端收到意外多模态块时返回明确错误而非崩溃。
- AC5（P2）多轮对话中附件上下文可被重建（持久化生效）。
- AC6（对齐）前端发出的图片块形状与 OpenTiny 官方契约一致（`image_url` + `filename` + 内联 dataURL），可被标准 OpenAI 兼容服务直接接受。

---

## 9. 风险与待确认

- **RISK-1（前端 SDK API）**：0.5.1 `engine` 是否支持 `messages.value.push(contentArrayMsg) + send()` 发送多模态消息，需实施期在 SDK 源码/`AgentModelProvider.ts` 核实（见 F2）。若 SDK 当前不支持，需升级 SDK 或绕过 `sendMessage` 直接走 `_chatViaWebMCP` 透传。
- **RISK-2（deepseek 不支持图片）**：图片功能仅对 vision 模型有效；须确保门控正确，避免向 deepseek 发 image_url 导致 4xx。
- **RISK-3（PPT 图像渲染依赖）**：PPTX→slide 图像需要 office/render 库，体积与跨平台成本高，故 P0/P1 仅做文本抽取，图像渲染后置。
- **RISK-4（大文件 base64 体积）**：内联 dataURL 会显著增大 WebSocket 消息；P2 应加大小上限与进度，必要时改为独立上传接口 + URL 引用（超出本 SDD 最小范围，列为 P2）。
- **RISK-5（provider file 块差异）**：各网关 `file` 内容类型字段不一，故默认走策略 B（文本抽取）规避，A 仅作可选 fast-path。
- **RISK-6（官方仅覆盖图片）**：OpenTiny 官方组件（GenuiChat）只支持图片上传；PDF/PPT 文档无官方契约，本工程文档 ingestion 为**自研增值项**，需自担兼容性（见 §5、`research-opentiny-official.md`）。
- **RISK-7（官方协议待补）**：官方「图片上传协议」的权威解读在 GenUI SDK 公开课**第六期（2026-11-10，多模态交互与通信协议解析）**，尚未开播；届时须回填并校正本契约。
- **RISK-8（vendored SDK 漂移）**：前端改动落在本地 vendor 的 `@opentiny/{next-remoter,next-sdk}` 源码（`file:` 依赖）。须最小化改动、记录 diff、并向 OpenTiny 上游提 PR，以降低升级 merge 成本。
- **RISK-9（双路径形状）**：AI-SDK 直连路径吃 AI-SDK part、WebMCP 路径吃 OpenAI 形状；归一化须严格限定在 WebMCP 边界（§6.2b），否则会破坏直连路径。

---

## 10. 参考

- **官方多模态契约**：https://docs.opentiny.design/genui-sdk/examples/chat/image-upload.html
- **官方 GenuiChat 组件**：https://docs.opentiny.design/genui-sdk/components/chat
- **官方自定义底部工具栏**：https://docs.opentiny.design/genui-sdk/examples/chat/footer-toolbar.html
- **官方自定义 Actions**：https://docs.opentiny.design/genui-sdk/examples/chat/custom-actions.html
- **本工程研究笔记**：`research-opentiny-official.md`（OpenTiny 官方做法与映射）
- **现状分析**：`problem-analysis.md`｜**任务拆分**：`tasks.md`
- **既有文档**：`web-admin/docs/{genui-sdk-v1.3.0-release,next-sdk,tiny-remoter,tiny-robot,tiny-robot-kit-article,AI-Extension,opentiny-genui-chat-advanced}.md`
- **本地 SDK 源码**：`web-admin/src/lib/webmcp-sdk/packages/{next-remoter,next-sdk}`
