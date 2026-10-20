# 子系统集成契约（`attachment-persistence`）

> 模板：`templates/subsystem-contract-template.md`
> 产出阶段：spec / design 步 ｜ 铁律依据：**铁律 15**

## 文档信息

- 所属主工程：`multimodal-native-chat`
- 子系统 ID：`attachment-persistence`
- 子系统 `feature_name`：`multimodal-native-chat--attachment-persistence`
- 契约版本：`v1`
- 冻结状态：**草案**
- 冻结日期：2026-10-15
- 上游依赖：`host-attach-core` v1（事件契约 IF-07a）
- 下游消费方：无（管理与回放为终点）

---

## 1. 本子系统提供什么（能力清单）

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| P-01 | HTTP | `/api/v1/uctoo/attachment_records` | GET | 分页 + 筛选（会话/时间/格式/状态/解析器） | 列表（键名 `attachment_recordss`? 按 `uctoo-v4-api-specification`：列表键名 = 表名 + `s`） | 统一错误结构 | 是（读） | 权限内过滤 |
| P-02 | HTTP | `/api/v1/uctoo/attachment_records/{id}` | GET | 路径参数 | 单条详情 | 统一错误结构；不存在 404 | 是（读） | |
| P-03 | 进程内调用 | `AttachmentRecordService.listByMessage(messageId)` | — | `(messageId)` | `Array<AttachmentRecord>` | 不抛，异常返回空 | 是 | 供回放 |
| P-04 | 进程内事件消费 | `AttachmentParsed` 订阅 | — | `{sessionId, messageId, attachmentMeta[], parseSummary}` | — | 落库失败记 error，不回抛 | 幂等键 `messageId` + 附件序号 | 消费自 `host-attach-core` |
| P-05 | 库表 | `agent_messages.attachments` / `messages.attachments`（JSON 列） | — | — | — | — | — | **加列而非新建表**，见 §2 复用论证 |

- **错误约定**：复用 uctoo 既有统一错误响应结构，不自造错误码。
- **幂等性**：写以 `messageId` + 附件序号为幂等键；读天然幂等。

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| `agent_messages` | 写（新增 `attachments` JSON 列） | `attachments`（元数据数组） | 表内其它既有字段不变 | 沿用既有会话归属过滤 | 查询须带既有软删语义 |
| `messages` | 写（新增 `attachments` JSON 列） | `attachments`（元数据数组） | 同上 | 同上 | 同上 |

- **复用不成立的论证（铁律 9，必须写）**：
  1. 两表既有列均为标量文本/时间字段，无法承载「多附件 + 每附件的解析摘要」这一**一对多结构化**数据；
  2. 本项目两表**不存在** `payload` / `config` 类通用 JSON 收纳列，无可复用容器；
  3. 因此选择**在既有两张表上各加一个 `attachments` JSON 列**（加列而非新建表），已是最省的复用方案。
- 行级权限口径沿用 `user-permission-system.md` / `row-level-permission-system.md`；`creator` / 归属判定归既有会话逻辑，**下游不得自行解释**。
- DB 结构变更须走 `loaddbinfo` → `crudgen`（宿主公共基础设施）→ `crudweb`（界面），并补 `sql/incremental/` 增量 DDL。

## 3. 依赖方向

- **我依赖的上游**：
  1. `host-attach-core` v1 —— 消费 `AttachmentParsed` 事件（IF-07a）。
- **我不依赖谁**：
  - 不依赖 `doc-parser-plugins` 的实现（只消费上游事件里的 `parserId` 字符串）；
  - 不依赖 `web-multimodal` 的任何内部状态。
- **禁止成环**：本子系统只订阅上游事件，不向上游回写任何控制指令。

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| 附件内容解析 | `doc-parser-plugins` | 数据面只存结果摘要 |
| 附件接收与调度 | `host-attach-core` | 上游职责 |
| 附件原始字节存储 | — | **全工程禁止**（§6.1.10 红线） |
| 前端上传交互 | `web-multimodal` | 前端交付面 |

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动 |
| 向后兼容（minor） | `attachments` JSON 内新增可选字段 | 改本文 + 主工程 §3；消费方按可选处理 |
| 破坏性（major） | 改事件结构 / 改列语义 / 改权限口径 | **双侧同轮**：与 `host-attach-core` 同轮；主工程 SPECS_INDEX §6 登记 |

## 6. 集成验收（本子系统对下游的交付承诺）

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| SC-31 | 一轮含附件对话后，元数据落库且管理界面可见 | 与 `host-attach-core` 合并态实跑 | `host-attach-core` done | 列表出现该记录，字段齐全，无 base64 |
| SC-32 | 重复投递同一 `messageId` 事件 → 记录唯一 | 连发两次事件 | `host-attach-core` done | 记录数不增 |
| SC-33 | 历史会话回放可取回附件元数据与解析摘要 | 打开历史会话 | `host-attach-core` done | 回放展示元数据与摘要 |
| SC-34 | **异常**：DB 不可用时聊天链路不受影响 | 模拟 DB 故障发一条含附件消息 | `host-attach-core` done | 聊天正常返回，error 日志有记录 |
| SC-35 | **异常**：权限外用户查询不到他人会话附件 | 换普通用户查询 | `host-attach-core` done | 返回空或非 403 的空列表，不泄漏 |

- §6 用例由本子系统 test 步执行（L1 + L2）。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|---|---|---|---|
| 2026-10-15 | v1 | 主工程 v2 架构调整 | 首次落契约；明确加列而非新建表并给出复用不成立论证 | 无直接下游；宿主侧需发布 IF-07a 事件（T-HAC-11） |
