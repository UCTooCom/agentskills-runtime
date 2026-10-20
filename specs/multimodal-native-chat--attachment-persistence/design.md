# 设计文档：附件持久化与审计（`attachment-persistence`）

> 主工程：`multimodal-native-chat` ｜ 子系统 `feature_name`：`multimodal-native-chat--attachment-persistence`
> 版本：v1 ｜ 日期：2026-10-16 ｜ 阶段：design（**实现先行、按代码反推**）
> 关联：`spec.md` v1 ｜ `contract.md` v1（IF-07a 草案）｜ `tasks.md`
> 语言标签：cangjie + web ｜ 优先级：P2

---

## 0. 本文档定位（重要）

「实现先于 design」。本文档记录附件元数据持久化的真实落库路径，并澄清一个**极易混淆的点**：
本子系统 ≠ `attachments` 通用上传表。

> ⚠️ **易混淆澄清**：仓库里另有一个 `attachments` 表，配套 `AttachmentsController` / `AttachmentsService`
> / `AttachmentsDAO` / `AttachmentsPO`，其 `AttachmentsService.uploadToCos` 是**腾讯云 COS 通用文件上传设施**
> （存 `path/url/mimeType/fileExt/filesize/filename/driver/scene`），属既有通用资源存储能力，
> **不是**本多模态子系统的附件元数据持久化。本子系统的落库目标只有 `agent_messages.attachments`
> 与 `messages.attachments` 两个 **JSON 列**（见 §1）。请勿把两者混为一谈。

---

## 1. 架构总览（实现即现状）

### 1.1 实际落库路径（直传，非事件订阅）

```
WebMCPProtocol 完成调度
  └─ 构建 AttachmentSummary（core/agent/attachment_summary.cj）
       { messageId, sessionId, attachmentCount, parseSummary, attachmentsJson }
       ※ attachmentsJson = 附件元数据数组的 JSON 字符串（不含原文 base64）
  └─ 挂到 AgentRequest 透传
       ↓
AgentPersistenceEventHandler.onAgentStart（src/app/services/bridge/agent_persistence_event_handler.cj:124-127）
  └─ 保存 user message 后：
       messagesService.updateAttachments(userMsg.id, summary.attachmentsJson)
       → 写入 agent_messages.attachments（同步写 messages.attachments）
```

**关键点**：持久化走 `AttachmentSummary` 随 `AgentRequest` 透传 → handler 直写 JSON 列，
**不是** spec §5.1.1.1 描述的「订阅 `AttachmentParsed` 事件后写入」。

### 1.2 DDL（已存在）

`sql/incremental/20261015_attachment_metadata_columns.sql`：
```sql
ALTER TABLE "public"."agent_messages" ADD COLUMN IF NOT EXISTS "attachments" json DEFAULT '[]'::json;
ALTER TABLE "public"."messages"      ADD COLUMN IF NOT EXISTS "attachments" json DEFAULT '[]'::json;
```
- 幂等（`IF NOT EXISTS`）、禁 DROP、不改既有列；默认 `'[]'`。
- 列注释明确：只存元数据（filename/mimeType/sizeBytes/parserId/status/partCount/notice），**不含原文 base64**。

### 1.3 附件摘要载体

`src/core/agent/attachment_summary.cj` 的 `AttachmentSummary`：刻意只持「可序列化字段 + 已序列化 JSON」，
**不引用 `magic.plugin.multimodal` 任何类型**，以避免 `core → plugin` 反向依赖成环（与 `host-attach-core` design §1 呼应）。

### 1.4 IF-07a 事件（冗余通道）

`src/plugin/multimodal/attachment_parsed_event.cj` + `WebMCPProtocol` 发布点已落地，
但**无订阅者**——持久化实际走 §1.1 直传。属已知偏差（SPECS_INDEX §7）。

---

## 2. 关键设计决策（已落地）

- **加列而非新建表（铁律 9 复用论证）**：附件元数据是「每消息一条结构化 JSON」，既有 `agent_messages` / `messages`
  表无合适 payload 容器承载，且纯文本消息该列可空、不影响历史记录。故加列优于新建表，论证见 `contract.md` §2 与 DDL 注释。
- **绝不落大 base64**：只写元数据 JSON，原文文本进入消息 `content` 的 `<uploaded_files>` 块（受 `host-attach-core` 10 万字符上限约束）。与 spec §4.3.1 红线一致。
- **非阻塞**：写入在 `onAgentStart` 的 `spawn` 协程内，失败仅 `LogUtils.error`，不阻塞主聊天链路（spec §5.1.2.1）。
- **幂等**：以 `messageId` 为幂等键，`updateAttachments` 对同一条 user message 重复调用只覆盖同列，不产生重复记录（spec §4.2.1 / §5.1.1.2）。

---

## 3. 与 spec / contract 的偏差

| 偏差 | spec 期望 | 现状 | 影响 |
|---|---|---|---|
| **落库触发方式** | 订阅 `AttachmentParsed` 事件后写入 | 走 `AttachmentSummary` 直传落库，事件无订阅者 | 功能等价；事件通道闲置（已知偏差，建议保留直传、事件给前端留痕） |
| **管理界面（T-AP-09）** | crudweb 生成列表/详情，按会话/时间/格式/状态/解析器筛选 | 未做；目前 JSON 列无独立查询 UI | 审计/排查入口缺失 |
| **会话回放取回（T-AP-10）** | 打开历史会话时取回附件元数据与解析摘要 | 未做；列已可存，但无回放取用逻辑 | AC3 未闭环 |

---

## 4. 数据约束（实现即现状）

- 落库内容 = `attachments` JSON 列，结构（与 spec §6.1 对齐）：
  `filename` / `mimeType` / `sizeBytes` / `parserId` / `parserVersion` / `status`(ok/empty/error/fallback) / `partCount` / `charCount` / `costMs` / `errorText` / `notice`。
- **禁止字段**：`rawContent`（大 base64）绝不在列内（spec §6.1.10）。
- 权限：沿用 `agent_messages` / `messages` 既有 RBAC 与行级可见范围（会话归属用户可见）。

---

## 5. 差距清单（对照 `tasks.md`）

| 任务 | 状态 | 说明 |
|---|---|---|
| T-AP-01 契约确认（IF-07a） | ⬜ 待确认 | 实际走直传，事件语义需与主工程对齐 |
| T-AP-02 复用不成立论证 + 加列方案 | ✅ 已落 DDL + 论证 | 见 §2 / contract §2 |
| T-AP-03 增量 DDL | ✅ 已存在（`20261015_attachment_metadata_columns.sql`） | |
| T-AP-04 执行 DDL + loaddbinfo | 🟡 待人工确认 ORM 刷新 | |
| T-AP-05 五层代码 | 🟡 部分 | PO/DAO/Service 层读 `attachments` 列的能力需确认是否由 crudgen 生成；落库走 handler 直写 |
| T-AP-06 权限登记 | ⬜ 待确认 | 复用既有消息表权限，无新增路由故大概率无需新节点 |
| T-AP-07 事件订阅落库 | 🟡 被直传替代 | 功能已覆盖，事件订阅可降级为可选 |
| T-AP-08 落库失败不阻塞 | ✅ 已实现 | spawn + error 日志 |
| T-AP-09 管理界面 | ⬜ 未做 | 最大缺口 |
| T-AP-10 会话回放取回 | ⬜ 未做 | |
| T-AP-11 禁 base64 防护 + 自检 | 🟡 设计保证（只存 metadata JSON） | 缺独立自检脚本 |
| T-AP-12/13 L1 / L2 冒烟 | ⬜ 未做 | |

---

## 6. 验证状态与下一步

- **已验证**：DDL 存在且幂等；`AttachmentSummary` 直传落库链路在代码中闭合（handler:124-127）。
- **未验证**：列内确无 base64 的自检、管理界面、回放取回、L1/L2 冒烟。
- **下一步建议**（按优先级）：
  1. **先补 T-AP-09 管理界面**（crudweb 在 `agent_messages` 上生成附件元数据查看/筛选），这是审计闭环最明显的缺口；
  2. 补 T-AP-10 会话回放取回；
  3. 在闸口确认「直传替代事件订阅」是否回写 spec/contract（建议保留直传、事件降级）；
  4. 跑 T-AP-11 自检 + T-AP-12/13。

---

**修订记录**

| 日期 | 版本 | 触发 | 改动摘要 |
|---|---|---|---|
| 2026-10-16 | v1 | 主工程 T-MAIN-03 收口 | 按代码反推；澄清「落库=AttachmentSummary 直传写 JSON 列」而非事件订阅；澄清与通用 attachments/COS 上传表无关 |
