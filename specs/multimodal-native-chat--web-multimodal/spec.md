# 子系统需求规格：前端多模态交互（`web-multimodal`）

> 主工程：`multimodal-native-chat` ｜ 子系统 `feature_name`：`multimodal-native-chat--web-multimodal`
> 版本：v1 ｜ 日期：2026-10-15 ｜ 阶段：spec
> 上游：主工程 `spec.md` v2 §5.1/§5.4、`host-attach-core` v1（wire 契约 IF-05 / IF-06）、`research-opentiny-official.md`
> 契约：本目录 `contract.md`（v1，草案）
> 语言标签：web（Vue3 + TypeScript）

---

## 1. 组件定位

### 1.1 核心职责

本子系统负责前端（tiny-remoter 聊天组件）的附件上传交互：能力门控、附件转 content 块、WebMCP 边界形状归一化、以及丢弃/降级的可见化呈现。

### 1.2 核心输入

1. 用户选择的文件（图片 / 文档）。
2. 选中模型的 `MultimodalCapability`（`supportImages` / `maxFileSize` / `supportedMimeTypes`）。
3. 宿主返回的响应与 `<attachment_notices>` 留痕文本。

### 1.3 核心输出

1. 组装好的多模态 `content` 块数组（AI-SDK 形状，供 SDK 内部使用）。
2. 归一化后的 WebMCP 请求 `messages[]`（OpenAI 兼容形状）。
3. 上传入口显隐、可传类型、以及留痕提示 UI。

### 1.4 职责边界

本子系统**不负责**：

1. 文档内容解析（宿主调度 + 插件解析，前端只传不解析）。
2. 宿主侧的限流判定（前端做**预估**拦截，最终裁定在宿主）。
3. 附件持久化（归 `attachment-persistence`）。
4. 把 `MultimodalCapability` 的能力数据源改造为后端可判定（见主工程 §7 已知偏差）。

---

## 2. 领域术语

**AI-SDK 形状**
: 前端 SDK 内部使用的图片块 `{ type:'image', image:dataURL, filename }`。
: 备注：与 AI-SDK 直连路径保持一致，不在源头改成 OpenAI 形状。

**形状归一化**
: 在 WebMCP 边界把 AI-SDK 形状转为 OpenAI 官方 `image_url` 块的唯一转换点。
: 备注：只在边界做，避免破坏 AI-SDK 直连路径（RISK-9）。

**file-pending 块**
: 前端产出的非图片附件块 `{ type:'file-pending', filename, mimeType, data }`，由边界归一化为 `file` 块。

**能力门控**
: 依模型 `MultimodalCapability` 决定上传入口显隐与可接受类型。

---

## 3. 角色与边界

### 3.1 核心角色

- **终端用户**：上传附件、看到留痕提示。
- **前端集成开发者**：为模型配置能力声明。

### 3.2 外部系统

- **`host-attach-core`**（下游/上游双向调用方）：前端发 WebMCP 请求，宿主回响应与留痕。
- **tiny-remoter / next-sdk**（vendored SDK）：承载发送与形状归一化落点。

### 3.3 交互上下文

```plantuml
@startuml
skinparam rectangle { BackgroundColor #F5F5F5 BorderColor #333333 }
skinparam shadowing false
rectangle "终端用户" as User
rectangle "前端多模态交互\n(本子系统)" as Fe
rectangle "host-attach-core" as Host
rectangle "ChatModel" as LLM

User --> Fe : 选文件 + 输入提问
Fe --> Fe : 门控判定 / 附件转块 / 边界归一化
Fe --> Host : WebMCP messages[]
Host --> LLM : content 块
Host --> Fe : 回复 + attachment_notices
Fe --> User : 展示回复与留痕提示
@enduml
```

---

## 4. DFX 约束

### 4.1 性能
1. 选择文件到可发送状态的本地处理（转 base64 + 预览）应在 **2 秒**内完成（单文件 ≤10MB）。
2. 前端预估拦截超 `maxFileSize` 的文件，不进入网络传输。

### 4.2 可靠性
1. 附件存在但无文本时也必须可发送。
2. 宿主返回错误或留痕时，前端必须呈现，不得吞掉。
3. 纯文本消息路径行为不变。

### 4.3 安全性
1. 附件以内联 base64 传输，不引入独立上传接口。
2. 前端不做解析，不执行附件内容。

### 4.4 可维护性
1. 形状归一化只在一处（`normalizeContentForWebMCP`），不得在多处重复转换。

### 4.5 兼容性
1. AI-SDK 直连路径行为不变（源头不改形状）。
2. `image_url` 块形状与 OpenTiny 官方契约一致（AC6）。

---

## 5. 核心能力

### 5.1 上传入口与能力门控

#### 5.1.1 业务规则

1. **图片入口门控**：模型未声明 `supportImages` 时隐藏图片入口
   a. 验收条件：While 选中模型 supportImages 为 false, the 前端多模态交互 shall 隐藏图片上传入口
2. **文档入口门控**：`supportedMimeTypes` 不含文档 MIME 时隐藏文档入口
   a. 验收条件：While 选中模型 supportedMimeTypes 不含文档 MIME, the 前端多模态交互 shall 隐藏文档上传入口
3. **accept 覆盖**：上传入口 `accept` 必须覆盖图片与常见文档类型
   a. 验收条件：When 渲染上传入口, the 前端多模态交互 shall 使 accept 覆盖 image/* 与 pdf/doc/docx/ppt/pptx/txt/md/csv/json 等
4. **切模型清理**：切换模型后清理与新能力不兼容的已选附件
   a. 验收条件：When 用户切换模型, the 前端多模态交互 shall 清理与新模型能力不兼容的已选附件

#### 5.1.2 异常场景

1. **文件类型不在 accept 内**
   a. 触发条件：用户选中不在 accept 内的文件
   b. 系统行为：系统选择框层面已过滤；绕过时前端拦截并提示
   c. 用户感知：提示不支持的文件类型

### 5.2 附件转块与发送

#### 5.2.1 业务规则

1. **图片转块**：图片产出 AI-SDK 形状块并携带 `filename`
   a. 验收条件：When 用户选中图片, the 前端多模态交互 shall 产出 `{type:'image', image:dataURL, filename}` 块
2. **非图片转块**：非图片产出 `file-pending` 块，不得静默丢弃
   a. 验收条件：When 用户选中非图片文件, the 前端多模态交互 shall 产出 `{type:'file-pending', filename, mimeType, data}` 块
3. **随消息发送**：附件必须与文本组装为同一条消息提交
   a. 验收条件：When 用户发送消息, the 前端多模态交互 shall 用 engine.send 提交含 content 块数组的 user 消息
4. **只图不打字可发送**：附件存在但输入为空时发送按钮不得禁用
   a. 验收条件：If 输入为空但有附件, the 前端多模态交互 shall 使发送按钮可用
5. **禁止项**：禁止在发送时把附件降级为纯文本
   a. 验收条件：If 存在附件, the 前端多模态交互 shall 不得丢弃附件仅发送纯文本

#### 5.2.2 异常场景

1. **文件读取失败**
   a. 触发条件：`FileReader` 读取失败
   b. 系统行为：该附件不进入消息并提示用户
   c. 用户感知：提示「文件 X 读取失败」

### 5.3 边界形状归一化

#### 5.3.1 业务规则

1. **唯一转换点**：AI-SDK 形状 → OpenAI 形状只在 WebMCP 组包前完成
   a. 验收条件：When 走 WebMCP 通道, the 前端多模态交互 shall 在组包前把 image 块转为 `{type:'image_url', filename, image_url:{url}}`
2. **file-pending → file 块**
   a. 验收条件：When 归一化时遇到 file-pending 块, the 前端多模态交互 shall 转为 `{type:'file', file:{filename, mimeType, data}}`
3. **纯文本不受影响**
   a. 验收条件：When 消息 content 为纯字符串, the 前端多模态交互 shall 原样透传不做转换

### 5.4 留痕呈现

#### 5.4.1 业务规则

1. **留痕可见**：宿主回传 `<attachment_notices>` 时前端必须呈现
   a. 验收条件：When 响应含 attachment_notices, the 前端多模态交互 shall 向用户呈现被丢弃/未解析的附件说明
2. **不重复提示**：留痕文本由宿主产出，前端只呈现不做二次加工
   a. 验收条件：When 呈现留痕, the 前端多模态交互 shall 直接使用宿主文本, 不自行拼接重复提示

---

## 6. 数据约束

### 6.1 前端附件对象
1. **rawFile**：原始 `File`，必填。
2. **filename**：文件名，必填。
3. **mimeType**：MIME，必填。
4. **data**：base64 dataURL，必填。

### 6.2 归一化后的 content 块
1. **text 块**：`{type:'text', text}`，原样透传。
2. **image_url 块**：`{type:'image_url', filename, image_url:{url}}`。
3. **file 块**：`{type:'file', file:{filename, mimeType, data}}`。

### 6.3 MultimodalCapability
1. **supportImages**：布尔，缺失按 false。
2. **maxFileSize**：单附件上限（MB），缺失用默认。
3. **supportedMimeTypes**：MIME 列表，用于推导文档能力。

---

**文档状态**: spec **v1**（2026-10-15，子系统 spec 步产出）
**下一步**: `contract.md`（冻结）→ `design.md` → `tasks.md` → code → test（L1 + L2）
