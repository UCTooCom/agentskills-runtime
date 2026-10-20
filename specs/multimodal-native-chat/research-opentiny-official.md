# 研究：按 OpenTiny 官方推荐方式扩展聊天组件与原生多模态

> 工程：`specs/multimodal-native-chat`
> 目的：为 `sdd.md` 提供 OpenTiny 官方推荐做法的**依据**，使上一轮 SDD 更完善、准确
> 日期：2026-10-14
> 一手资料：OpenTiny 官方 GenUI SDK 文档 + `web-admin/docs/` 既有文档 + 本地 vendored SDK 源码

---

## 0. 结论速览（TL;DR）

1. **官方多模态消息体就是 OpenAI 兼容的 content 块数组**，图片块形如
   `{ type:'image_url', filename, image_url:{ url:'data:image/png;base64,...' } }`。
   → 本工程 SDD §4 的方向**正确**，需按官方**补 `filename` 字段**。
2. **官方组件（GenuiChat）原生只支持"图片上传"**（`features.supportImage`），**不含 PDF/PPT/DOC 等文档**。
   → 文档 ingestion 是本工程相对官方的**增值扩展**，无官方契约可抄，须自研（SDD §5 保持）。
3. **官方扩展点**：模型能力（`features` / `multimodal`）+ 消息底部工具栏（`roles.<role>.slots.trailer`）+
   `customActions` / `rendererSlots` / `thinkComponent` / `customFetch` / slots。
   → 加"上传入口"这类交互入口，官方推荐走**能力配置 + 插槽/工具栏**，而非硬改发送逻辑。
4. **前端 SDK 是本地 vendored 的 `@opentiny/next-remoter` / `@opentiny/next-sdk`**（`package.json` 里为 `file:` 依赖）。
   → 改动属于"改上游 SDK 源码"，须最小化 + 向上游贡献 + 应用层装配，升级时要能 merge。
5. 前端 SDK 有**双路径**：AI-SDK `streamText`（AI-SDK content part `{type:'image',image}`）与
   **WebMCP（把 content 数组原样 POST 给 runtime）**。→ 多模态 shape 必须在 **WebMCP 边界归一化为 OpenAI 形状**。

---

## 1. 官方组件族与本工程映射

OpenTiny NEXT 下有多个聊天相关包，容易混淆：

| 包 | 组件 | 角色 | 本工程现状 |
|---|---|---|---|
| `@opentiny/genui-sdk-vue` | `GenuiChat` / `GenuiRenderer` / `GenuiConfigProvider` | **GenUI SDK**（本次直播主题、官方图片上传文档所在） | 未直接使用 |
| `@opentiny/next-remoter` | `TinyRemoter` / `TinyRobotChat` | **TinyRobot 智能组件**（悬浮/嵌入式聊天，含 MCP 插件市场） | **本工程实际使用**（本地 vendor，v0.4.11） |
| `@opentiny/next-sdk` | `AgentModelProvider` 等 | Agent/LLM 适配、WebMCP 通道 | **本工程实际使用**（本地 vendor） |
| `@opentiny/tiny-robot`(`-kit`,`-svgs`) | `Tr*` 组件 + `useMessage`/`useConversation` | 底层 UI 组件与消息引擎（npm 0.5.1） | 使用（npm 依赖） |

> **关键点**：直播 / 官方图片上传文档讲的是 **GenuiChat**；本工程用的是**同门的 `TinyRemoter/TinyRobotChat`**。
> 两者**多模态 wire 契约一致（OpenAI 兼容）**，但**配置入口与扩展 API 名不同**（见 §2、§3）。SDD 需按"本工程组件"落点，同时对齐官方 wire 契约。

---

## 2. 官方多模态契约（GenuiChat 上传图片）

来源：`https://docs.opentiny.design/genui-sdk/examples/chat/image-upload.html`（官方）

**能力配置**（`features`，类型 `ModelCapability`）：

```ts
interface ImageFeatures {
  enabled: boolean;             // 是否启用图片上传
  maxImageSize: number;         // 单张图片最大大小（MB）
  maxFilesPerRequest: number;   // 每次请求最多上传的图片数量
  supportedFileTypes: string[]; // 支持的图片格式
}
// 用法
const modelFeatures = {
  supportImage: { enabled: true, maxImageSize: 10, maxFilesPerRequest: 3,
    supportedFileTypes: ['jpg','jpeg','png','gif','webp','bmp','heic','tiff'] },
  supportFunctionCalling: true,
}
```

**LLM 接受数据格式**（官方原文："数据结构符合 OpenAI 兼容格式"）：

```json
{
  "role": "user",
  "content": [
    { "type": "image_url", "filename": "circle.png",
      "image_url": { "url": "data:image/png;base64,XXXXXXXXXXX" } },
    { "type": "text", "text": "分析一下这张图片" }
  ]
}
```

**UI 侧 messageItem**（含 `messages[].attachments`）：

```json
{ "role":"user", "content":[ ... ],
  "messages":[ { "type":"templateData",
    "templateData":[ {"id":"...","type":"template","content":"circle.png"},
                     {"id":"...","type":"text","content":"Please analyze this image for me"} ],
    "attachments":[ { "name":"circle.png", "type":"image/png", "size":50,
                      "lastModified":1768449231945, "base64":"data:image/svg+xml," } ] } ] }
```

**要点（对 SDD 的直接影响）**：
- 内容块用 **`image_url`**（非 AI-SDK 的 `image`），并带 **`filename`**。
- 图片以**内联 base64 data URL** 传输（无独立上传接口）——与本工程 SDD §4 一致。
- 文本块 `{type:'text',text}` 与图片块**同一 content 数组**混排——与 SDD §4 一致。

---

## 3. 官方扩展点清单（"怎么扩展聊天组件"）

### 3.1 GenuiChat（GenUI SDK，直播主题）
- `features`（`ModelCapability`）：`supportImage`、`supportFunctionCalling` —— **能力门控**入口。
- **消息底部工具栏**：通过 `roles` 属性为不同角色配置，`slots.trailer` 指定底部组件：
  ```ts
  const roles = {
    assistant: { slots: { trailer: AssistantFooter } },
    user:      { slots: { trailer: UserFooter } },
  }
  interface IBubbleSlotsProps { index:number; bubbleProps:BubbleProps;
                                isFinished:boolean; messageManager:UseMessageReturn }
  ```
- `thinkComponent`（自定义思考过程组件）、`rendererSlots`（header/footer）、
  `customActions`（AI 可调用的自定义动作，`{name,description,parameters,execute}`）、
  `customFetch`（完全自定义 HTTP 请求）、slots：`empty`、方法 `getConversation()`（历史会话管理）。

### 3.2 TinyRemoter / TinyRobotChat（本工程实际组件）
- **插槽**（`docs/tiny-remoter.md`）：`#welcome`、`#suggestions`、`#operations`（头部操作区）、`#header-actions`。
  → 官方未提供"输入框底部工具栏"插槽；上传按钮位于 `tr-sender` 内部 `#footer`（见源码）。
- **模型能力**（`next-sdk.md` / `AI-Extension.md`）：`UnifiedModelConfig.multimodal`
  ```ts
  interface MultimodalCapability { supportImages?:boolean; maxFileSize?:number; supportedMimeTypes?:string[] }
  ```
  → **官方没有 `supportFiles` 字段**；文档类应通过 `supportedMimeTypes` 表达。
- **SDK 自带多模态模块**：`packages/next-remoter/src/multimodal/{useMultimodal,utils,index}.ts`
  - `useMultimodal` / `useMultimodalWithModel`（model-aware，切模型自动清不兼容附件）；
  - `convertAttachmentsToContent()` —— **当前产出 AI-SDK 形状** `{type:'image',image:dataURL}`，**仅处理图片**。
  - `BubbleImageRenderer.vue` —— 气泡内图片渲染（含预览/无障碍）。

---

## 4. 官方 6 期课程（多模态知识的官方出处）

| 期 | 时间 | 主题 | 简介 |
|---|---|---|---|
| 1 | 09/01 | GenUI 快速上手 | 从零搭建 AI 对话界面 |
| 2 | 09/15 | GenuiChat 核心配置深度解析 | 对话流程控制与模型行为调优 |
| 3 | 09/22 | GenUI 能力扩展机制详解 | 自定义组件、片段与动作编排 |
| 4 | 10/13 | 对话界面自定义渲染 | GenuiRenderer 全能力解析 |
| 5 | 10/27 | GenUI 高级交互设计 | 思考链可视化、角色系统与工具栏定制 |
| 6 | **11/10** | **多模态交互与通信协议解析** | **图片上传协议与 Schema 规范设计** |

> **第六期（11/10）"图片上传协议"是官方多模态协议的权威出处**，但尚未开播。
> 本期（第四讲）文章已发布，其排期海报即本工程 `web-admin/docs/opentiny-genui-chat-advanced.md`。
> 待第六期开播后应回填其协议细节，进一步校正本工程契约。

---

## 5. 对本工程 SDD 的具体修订建议

| # | 修订点 | 依据 |
|---|---|---|
| R-1 | §4 契约的 `image_url` 块**增加 `filename` 字段**，与官方一致 | §2 官方原文 |
| R-2 | **不要新增 `supportFiles`**；文档能力用既有 `MultimodalCapability.supportedMimeTypes` + `maxFileSize` 表达（F3/R7 调整） | §3.2 官方类型 |
| R-3 | 明确**前端双路径**：`convertAttachmentsToContent` 仍产 AI-SDK 形状供 AI-SDK 路径；**在 WebMCP 边界（`_chatViaWebMCP` 或发送前）归一到 OpenAI `image_url`**，避免破坏 AI-SDK 路径 | §0-5、源码 `AgentModelProvider` |
| R-4 | 明确**改动落在 vendored SDK** 的事实与策略：最小化 + 上游贡献 + 应用层装配，升级可 merge | §0-4、`package.json` `file:` |
| R-5 | 文档（PDF/PPT）标注为**官方能力之外的增值扩展**，契约自研；图片部分**对齐官方** | §0-2、§4 第六期 |
| R-6 | 作为"官方推荐扩展方式"记录：**优先用能力配置 + 插槽/工具栏/customActions**，而非硬改发送逻辑；TinyRemoter 可用 `#operations`/`#header-actions` 等官方插槽承载入口 | §3 |
| R-7 | SDD 引用官方文档链接（image-upload / components/chat / footer-toolbar / server-usage）作为契约出处 | §6 |

---

## 6. 参考链接

- 官方图片上传：https://docs.opentiny.design/genui-sdk/examples/chat/image-upload.html
- 官方 GenuiChat 组件：https://docs.opentiny.design/genui-sdk/components/chat
- 官方自定义底部工具栏：https://docs.opentiny.design/genui-sdk/examples/chat/footer-toolbar.html
- 官方自定义 Actions：https://docs.opentiny.design/genui-sdk/examples/chat/custom-actions.html
- 官方 Server（OpenAI 兼容）：https://docs.opentiny.design/genui-sdk/guide/server-usage
- 直播预告文章（本仓库）：`web-admin/docs/opentiny-genui-chat-advanced.md`
- 既有文档：`web-admin/docs/{genui-sdk-v1.3.0-release,next-sdk,tiny-remoter,tiny-robot,tiny-robot-kit-article,AI-Extension}.md`
- 本地 SDK 源码：`web-admin/src/lib/webmcp-sdk/packages/{next-remoter,next-sdk}`
