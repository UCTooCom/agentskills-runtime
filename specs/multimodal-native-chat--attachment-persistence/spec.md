# 子系统需求规格：附件持久化与审计（`attachment-persistence`）

> 主工程：`multimodal-native-chat` ｜ 子系统 `feature_name`：`multimodal-native-chat--attachment-persistence`
> 版本：v1 ｜ 日期：2026-10-15 ｜ 阶段：spec（P2 优先级）
> 上游：主工程 `spec.md` v2 §4.3.4、`host-attach-core` v1（事件契约 IF-07）
> 契约：本目录 `contract.md`（v1，草案）
> 语言标签：cangjie + web

---

## 1. 组件定位

### 1.1 核心职责

本子系统负责把随聊天上传的附件**元数据与解析摘要**持久化，并提供管理界面与审计回放能力；**不落大体积 base64**。

### 1.2 核心输入

1. `host-attach-core` 发布的 `AttachmentParsed` 事件（含 `sessionId` / `messageId` / `attachmentMeta[]` / `parseSummary`）。
2. 管理员在管理界面的查询条件。

### 1.3 核心输出

1. 落库的附件元数据记录（文件名、MIME、体积、解析器、状态、摘要）。
2. 管理界面列表与详情。
3. 会话回放时可取回的附件上下文（不含原始字节）。

### 1.4 职责边界

本子系统**不负责**：

1. 附件内容解析（归 `doc-parser-plugins`）。
2. 附件接收与调度（归 `host-attach-core`）。
3. 前端上传交互（归 `web-multimodal`）。
4. **不存大 base64**：原始字节不落库（安全与体积红线）。

---

## 2. 领域术语

**附件元数据（attachment metadata）**
: 附件的描述性信息（文件名 / MIME / 体积 / 解析状态 / 解析器标识 / 摘要），不含内容本体。

**解析摘要（parse summary）**
: 一次解析的结果概要：状态（ok/empty/error/fallback）、命中解析器、耗时、产出块数、字符数。

**回放（replay）**
: 在历史会话中重新展示当时附件的元数据与解析摘要，用于审计与排查。

---

## 3. 角色与边界

### 3.1 核心角色

- **终端用户**：在历史会话中看到当时上传过什么附件。
- **运维/管理员**：按会话/时间/解析器/状态查询附件记录，排查解析失败。

### 3.2 外部系统

- **`host-attach-core`**（上游事件源）：发布 `AttachmentParsed`。
- **管理界面（crudweb 生成）**：查询与展示。

### 3.3 交互上下文

```plantuml
@startuml
skinparam rectangle { BackgroundColor #F5F5F5 BorderColor #333333 }
skinparam shadowing false
rectangle "host-attach-core" as Host
rectangle "附件持久化与审计\n(本子系统)" as AP
rectangle "PostgreSQL" as DB
rectangle "管理界面" as UI
rectangle "运维/管理员" as Ops

Host --> AP : AttachmentParsed 事件(messageId 幂等)
AP --> DB : 写附件元数据
Ops --> UI : 查询条件
UI --> AP : 列表/详情查询
AP --> DB : 读
AP --> UI : 记录
@enduml
```

---

## 4. DFX 约束

### 4.1 性能
1. 单条附件元数据写入应在 **50ms** 内完成（P95）。
2. 列表查询分页默认 20 条，须带索引支撑的时间/会话筛选。

### 4.2 可靠性
1. 事件重复投递时必须幂等（以 `messageId` + 附件序号为幂等键）。
2. 落库失败不得影响主聊天链路（异步化或失败记日志，禁止阻塞回复）。

### 4.3 安全性
1. **禁止**把附件原始 base64 写入数据库。
2. 记录访问须遵循既有 RBAC 与行级可见范围（会话归属用户可见）。
3. 审计字段（`creator` / 创建时间）沿用既有约定。

### 4.4 可维护性
1. 解析摘要须可定位到具体 `parserId` / `parserVersion`，便于归因。
2. 失败记录须保留原因分类，支持按失败原因统计。

### 4.5 兼容性
1. 新增列不得影响既有纯文本消息记录（可为空）。
2. 管理界面须按既有 `crudweb` 规范生成，不手写一套。

---

## 5. 核心能力

### 5.1 附件元数据落库

#### 5.1.1 业务规则

1. **事件驱动写入**：收到 `AttachmentParsed` 后写入附件元数据
   a. 验收条件：When 收到 AttachmentParsed 事件, the 附件持久化与审计 shall 写入该消息的全部附件元数据
2. **幂等**：同一 `messageId` 重复事件不得产生重复记录
   a. 验收条件：If 同一 messageId 的事件重复投递, the 附件持久化与审计 shall 保持记录唯一
3. **禁止落大 base64**
   a. 验收条件：When 写入记录, the 附件持久化与审计 shall 不写入附件原始 base64 内容
4. **解析摘要保留**：状态、命中解析器、耗时、块数、字符数、失败原因须落库
   a. 验收条件：When 写入记录, the 附件持久化与审计 shall 保留解析状态与命中解析器标识

#### 5.1.2 异常场景

1. **落库失败**
   a. 触发条件：DB 不可用或写入异常
   b. 系统行为：记 error 日志，**不阻塞主聊天链路**
   c. 用户感知：无（聊天正常）

### 5.2 查询与管理界面

#### 5.2.1 业务规则

1. **列表查询**：支持按会话、时间、格式、解析状态、解析器筛选
   a. 验收条件：When 管理员输入筛选条件, the 附件持久化与审计 shall 返回符合条件且权限内的记录
2. **权限过滤**：只能看到自己可见范围内的记录
   a. 验收条件：When 查询记录, the 附件持久化与审计 shall 按既有行级可见范围过滤
3. **界面走 crudweb 生成**
   a. 验收条件：When 提供管理界面, the 附件持久化与审计 shall 基于 crudweb 生成物做最小适配

### 5.3 会话回放

#### 5.3.1 业务规则

1. **历史附件可见**：打开历史会话时可看到当时附件的元数据与解析摘要
   a. 验收条件：When 打开含附件的历史会话, the 附件持久化与审计 shall 提供该会话的附件元数据与解析摘要

---

## 6. 数据约束

### 6.1 附件元数据记录
1. **messageId**：所属消息标识，必填，与附件序号组成幂等键。
2. **filename**：原始文件名，必填。
3. **mimeType**：MIME，必填。
4. **sizeBytes**：原始字节数，必填。
5. **parseStatus**：`ok` / `empty` / `error` / `fallback`，必填。
6. **parserId** / **parserVersion**：可为空（未命中解析器时）。
7. **costMs**：解析耗时，可为空。
8. **partCount** / **charCount**：产出块数/字符数，可为空。
9. **errorText**：失败原因，`parseStatus=error` 时应填。
10. **rawContent**：**禁止存储**（大 base64 红线）。

### 6.2 AttachmentParsed 事件（消费自上游）
1. **sessionId**：会话标识，必填。
2. **messageId**：消息标识，必填（幂等键）。
3. **attachmentMeta[]**：附件元数据数组，必填。
4. **parseSummary**：解析摘要，必填。

---

**文档状态**: spec **v1**（2026-10-15，子系统 spec 步产出）
**下一步**: `contract.md`（冻结）→ `design.md`（含**复用不成立论证**）→ `tasks.md` → code → test
