# 子系统集成契约（`web-multimodal`）

> 模板：`templates/subsystem-contract-template.md`
> 产出阶段：spec / design 步 ｜ 铁律依据：**铁律 15**

## 文档信息

- 所属主工程：`multimodal-native-chat`
- 子系统 ID：`web-multimodal`
- 子系统 `feature_name`：`multimodal-native-chat--web-multimodal`
- 契约版本：`v1`
- 冻结状态：IF-05 **已冻结**（P0 已落地）；其余**草案**
- 冻结日期：2026-10-15
- 上游依赖：`host-attach-core` v1（wire 契约 IF-05 / 留痕契约 IF-06）
- 下游消费方：无（本子系统是链路终点）

---

## 1. 本子系统提供什么（能力清单）

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| IF-05 | HTTP（WebMCP） | `completion/complete` | POST | `{ method, params:{ model, messages[], stream }, jsonrpc, id }` | SSE / 完整响应 | 复用宿主统一错误结构 | 否（聊天请求天然非幂等） | **已冻结**：`messages[].content` 支持字符串或 `text`/`image_url`/`file` 块数组 |
| IF-09 | 前端呈现 | `<attachment_notices>` 渲染 | — | 宿主返回的留痕文本块 | UI 提示 | — | — | 前端只呈现，不二次加工 |
| IF-10 | 前端门控 | `MultimodalCapability` 消费 | — | `{supportImages, maxFileSize, supportedMimeTypes}` | 上传入口显隐 + accept | 缺失字段按默认处理 | — | 能力数据来源为模型配置 |

- **错误约定**：复用 uctoo 既有统一错误响应结构，不自造错误码。
- **类型口径**：对外/对上走 HTTP（WebMCP 通道由 SDK 封装）。

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| 无 | 本子系统**不新增表、不加列**，不直连 DB | — | — | — | — |

- 铁律 9 自检：零表 ✓。

## 3. 依赖方向

- **我依赖的上游**：
  1. `host-attach-core` v1 —— 取 IF-05（content 块 wire 契约）与 IF-06（留痕文本）。
- **我不依赖谁**：
  - 不依赖 `doc-parser-plugins` 的任何实现（前端不感知具体解析器）；
  - 不依赖 `attachment-persistence` 的表结构（历史附件回放由宿主侧编排）。
- **禁止成环**：本子系统是链路终点，不得被其它子系统反向依赖其内部状态。

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| 文档内容解析 | `doc-parser-plugins`（经 `host-attach-core` 调度） | 前端只传不解析 |
| 附件的最终限流裁定 | `host-attach-core` | 前端只做预估拦截 |
| 附件元数据落库 | `attachment-persistence` | 数据面分离 |
| 模型能力声明的权威来源 | 主工程 + 模型配置 | 见主工程 §7 已知偏差 |

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动 |
| 向后兼容（minor） | 新增可选 content 块类型 | 改本文 + 主工程 §3；宿主按未知类型忽略 |
| 破坏性（major） | 改 `image_url` / `file` 块形状、改 WebMCP 方法名 | **双侧同轮**：前端与 `host-attach-core` 同轮改完；主工程 SPECS_INDEX §6 登记 |

- 演进一律「先改契约 → 再改实现」。

## 6. 集成验收（本子系统对下游的交付承诺）

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| SC-21 | 图片随文本发送 → 宿主收到 `image_url` 块 → 模型基于图片回复 | 与 `host-attach-core` 合并态实跑 | `host-attach-core` done | agent 回复内容体现图片信息（AC1） |
| SC-22 | 上传超限图片 → 前端预估拦截或宿主留痕 → 提示可见 | 造一个超限文件 | `host-attach-core` done | 用户看到明确提示（AC7） |
| SC-23 | 上传 DOCX → 宿主调度插件解析 → 回复引用文档内容 | 与 `host-attach-core` + `doc-parser-plugins` 合并态实跑 | 两者 done | 回复引用文档具体内容（AC3） |
| SC-24 | **异常**：纯文本模型收到图片 → 前端入口已隐藏 / 宿主返回明确错误 | 切到无 vision 模型 | `host-attach-core` done | 入口隐藏或明确错误，不崩溃 |

- §6 用例由本子系统 test 步执行（L1 + L2）。
- 上游就位前提：`host-attach-core` done；SC-23 还需 `doc-parser-plugins` done。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|---|---|---|---|
| 2026-10-15 | v1 | 主工程 v2 架构调整 | 首次落契约；IF-05 沿用已落地形态并标记已冻结；新增 IF-09/IF-10 | 无直接下游 |
