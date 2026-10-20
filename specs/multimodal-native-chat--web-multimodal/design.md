# 设计文档：前端多模态交互（`web-multimodal`）

> 主工程：`multimodal-native-chat` ｜ 子系统 `feature_name`：`multimodal-native-chat--web-multimodal`
> 版本：v1 ｜ 日期：2026-10-16 ｜ 阶段：design（**实现先行、按代码反推**）
> 关联：`spec.md` v1 ｜ `contract.md` v1（IF-05 已冻结）｜ `tasks.md`
> 语言标签：web（Vue3 + TypeScript）

---

## 0. 本文档定位（重要）

「实现先于 design」。本文档记录前端多模态交互的已落地结构，并指出与 spec 的关键偏差。
所有结论来自对 `web-admin/src/lib/webmcp-sdk/` 真实文件的核对。

---

## 1. 架构总览（实现即现状）

前端多模态能力集中在 vendored SDK `src/lib/webmcp-sdk/packages/next-remoter/` 内：

| 职责 | 实现文件 | 备注 |
|---|---|---|
| 附件→内容块转换（AI-SDK 形状） | `src/multimodal/useMultimodal.ts` | `convertAttachmentsToContent`：图片→`{type:'image',image,filename}`，非图片→`{type:'file-pending',filename,mimeType,data}` |
| 多模态 Composable | `src/multimodal/useMultimodal.ts` | `useMultimodal` / `useMultimodalWithModel` |
| 发送消息 | `src/composable/useTinyRobotChat.ts` | `handleSendMessage` → `engine.send({role:'user', content: 块数组})` |
| 形状归一化（唯一转换点） | `src/next-sdk/agent/AgentModelProvider.ts` | `normalizeContentForWebMCP`：image→`image_url`、file-pending→`file` |
| 上传入口 | `src/components/TrUploadButton`（或等价组件） | `accept` 已覆盖 ppt/pptx/md/csv/json 等 |
| 聊天组件 | `src/components/TinyRobotChat.vue` / `ChatRemoter.vue` | 组装上述能力 |

调用链：
```
用户选文件
  → useMultimodal.handleFilesSelected（类型/体积校验，图片与文档分别限额）
  → convertAttachmentsToContent（产出 AI-SDK 形状块数组）
  → useTinyRobotChat.handleSendMessage → engine.send({role:'user', content: 块数组})
  → AgentModelProvider.normalizeContentForWebMCP（WebMCP 边界唯一转换点）
       image      → {type:'image_url', filename, image_url:{url}}
       file-pending → {type:'file', file:{filename, mimeType, data}}
```

---

## 2. 关键设计决策（已落地）

- **形状归一化只在 WebMCP 边界一处**（`normalizeContentForWebMCP`）：源头保持 AI-SDK 形状，避免破坏 AI-SDK 直连路径（spec §4.4.1 / RISK-9）。
- **非图片不静默丢弃**：改为产出 `file-pending` 块，由边界归一化为 `file` 块交后端 ingestion（spec §5.2.1.2 / 修复 problem-analysis B2）。
- **只图不打字可发送**：发送按钮 disabled 改为「无文本且无附件」（spec §5.2.1.4）。
- **accept 覆盖**：上传入口 `accept` 含 image/* 与 pdf/doc/docx/ppt/pptx/txt/md/csv/json（spec §5.1.1.3）。
- **DEFAULT_SUPPORTED_TYPES** = `['image/','text/','application/']`：因文档 MIME 各家网关写法不一，用前缀包含而非精确枚举（避免"选得到 PDF 却被判不支持"的自相矛盾）。

---

## 3. 与 spec / contract 的核心偏差（必须记录）

### ⚠️ 上传入口门控语义反转（2026-10-16 用户架构裁决）

- **spec §5.1.1.1/1.2 写明**：模型未声明 `supportImages` / `supportedMimeTypes` 不含文档 MIME 时，**隐藏**图片/文档上传入口。
- **代码现状**（`useMultimodal.ts:228`）：`hasMultimodalSupport = computed(() => true)` —— **上传入口恒显**，不再按模型能力位隐藏。
- **裁决理由（代码注释原意）**：
  1. 模型能力位是通道 seed 给的 advisory 值（本库几乎清一色 `["chat","stream","tools","embedding","image"]` 粗粒度），既不真实也不完整；
  2. 更关键的是它废掉了框架核心价值——即便所选模型无原生视觉能力，runtime 也能通过**技能/插件系统**装第三方图片理解插件，把"能不能看图"从"厂商出厂配置"变成"可无限扩展的能力"。按模型原生能力关掉上传口 = 把可扩展性砍回出厂配置。
- **新职责划分**：
  - 前端：上传入口恒显，用户永远可以把图/文档交给智能体；
  - 后端：按通道能力位决定**怎么投递**（原生视觉→`image_url` 直传；无原生视觉→转交插件 ingestion 链由智能体选技能）。
- **对文档的影响**：spec §5.1.1.1/1.2 与 `tasks.md` 的 T-WEB-04（"扩展为图片或文档能力，不新增 supportFiles"）描述已与实现不符，需在主工程闸口确认是否回改 spec；当前以代码裁决为准。

---

## 4. 数据约束（实现即现状）

- 前端附件对象：`rawFile` / `filename` / `mimeType` / `data`(base64 dataURL)。
- 归一化 content 块：`text` / `image_url{url,filename}` / `file{filename,mimeType,data}`（spec §6.2）。
- 内联 base64 传输，不引入独立上传接口（spec §4.3.1）；前端不做解析。

---

## 5. 差距清单（对照 `tasks.md`）

| 任务 | 状态 | 说明 |
|---|---|---|
| T-WEB-01 契约确认（IF-05） | ⬜ 待书面确认 | 沿用已落地形态，需与宿主对齐演进约定 |
| T-WEB-02~07 | ✅ 已落地（回归项） | 转块/发送/门控/accept/按钮/归一化 |
| T-WEB-08 切模型清理不兼容附件 | 🟡 代码已实现（`watch`）/ 待回归 | |
| T-WEB-09 留痕呈现（`<attachment_notices>` UI） | ⬜ 未做 | AC7 不静默丢弃的前端呈现缺失 |
| T-WEB-10 前端预估拦截 `maxFileSize` | ⬜ 未做 | 当前仅类型/体积（按 4/3 base64 膨胀估算）校验，未显式按 `maxFileSize` 预估 |
| T-WEB-11 与技能注入 / profile_context 并行共存回归 | ⬜ 未做 | AC2 |
| T-WEB-12 L1 自测 | ⬜ 未做 | |
| T-WEB-13 L2 集成冒烟 | ⬜ 未做 | |

---

## 6. 验证状态与下一步

- **已验证**：`npm run build` / eslint 需人工回传（未在本轮执行）；P0 六项能力代码已落地。
- **未验证**：留痕 UI 呈现、切模型清理回归、并行共存回归、L1/L2 冒烟。
- **下一步建议**：① 先补 T-WEB-09 留痕呈现（AC7 硬验收项，当前缺口最明显）；② 在闸口确认 §3 的门控语义反转是否回写 spec；③ 跑 T-WEB-08/10/11 回归 + T-WEB-12/13。

---

**修订记录**

| 日期 | 版本 | 触发 | 改动摘要 |
|---|---|---|---|
| 2026-10-16 | v1 | 主工程 T-MAIN-03 收口 | 按代码反推；记录「上传入口恒显」与 spec §5.1.1 的门控语义偏差 |
