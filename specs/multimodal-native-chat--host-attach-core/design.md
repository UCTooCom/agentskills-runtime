# 设计文档：宿主附件消费内核（`host-attach-core`）

> 主工程：`multimodal-native-chat` ｜ 子系统 `feature_name`：`multimodal-native-chat--host-attach-core`
> 版本：v1 ｜ 日期：2026-10-16 ｜ 阶段：design（**实现先行、按代码反推**）
> 关联：`spec.md` v1 ｜ `contract.md` v1（2026-10-16 冻结）｜ `tasks.md`（T-HAC-01~07/09/11 已落地）
> 语言标签：cangjie

---

## 0. 本文档定位（重要）

本工程实际是「**实现先于 design**」：代码在 2026-10-15 已 `cjpm build` 通过（cjc 1.1.3），
design 步在其后补写。因此本文档**不另起一套设计**，只做两件事：

1. **实现即现状**：把已落地的代码结构如实记录下来；
2. **差距**：对照 `spec.md` / `tasks.md` 标注尚未完成、已偏离的项。

所有结论均来自对 `src/` 真实文件的核对，不是凭 spec 想象。

---

## 1. 架构总览（实现即现状）

宿主内"附件接收 → 归一化 → 调度解析 → 随聊天提交 → 留痕"主线，代码分布如下：

| 职责 | 实现文件 | 备注 |
|---|---|---|
| 入口归一化 + 限流 + notice | `src/app/services/webmcp/multimodal_content_parser.cj` | 解析 content 块数组、纯文本兼容、只取最后一条 user 消息 |
| 调度器（命中→下发→超时→次优→兜底） | `src/plugin/multimodal/parse_dispatcher.cj` | 永不抛异常 |
| 注册表（注册/命中/健康/统计） | `src/plugin/multimodal/parser_registry.cj` | 含 `stats()`（IF-04f） |
| SPI 与值对象 | `src/plugin/multimodal/document_parser.cj` | `DocumentParser` / `ParserDescriptor` / `ParseRequest` / `ParseResult` / `FilePart` / `ParserFormats` / `ParseLimits` |
| 降级兜底块生成 | `src/plugin/multimodal/parse_fallback.cj` | 五类 notice |
| 附件解析摘要（随请求透传） | `src/core/agent/attachment_summary.cj` | `AttachmentSummary`，刻意不依赖 plugin 包（避免 core→plugin 反向依赖成环） |
| 留痕回灌 + 摘要构建 + 事件发布 | `src/app/services/webmcp/WebMCPProtocol.cj` | `<attachment_notices>` 同步/流式双分支；构建 `AttachmentSummary`；发布 `AttachmentParsed` |
| 参考解析器（L2 内建） | `src/plugin/multimodal/builtin/*.cj` | 见 `doc-parser-plugins` 子系统 design |

开关：`MULTIMODAL_ATTACH_ENABLED`（spec §1 交付面定义）。

调用链：
```
WebMCPProtocol
  └─ MultimodalContentParser.parse(content)  → {text, images, files, notices}
       └─ ParseDispatcher.dispatchWithMeta(attachment)
            ├─ ParserRegistry.resolve(name, mime)         // 优先级降序、失败率升序
            ├─ runWithTimeout(parser, 10s)                 // spawn + 轮询，超时转次优
            ├─ truncateParts(100k 字符，按 Rune 截断)
            └─ 全失败 → ParseFallback.fallbackParseFailed
  └─ 拼装 <uploaded_files> + <attachment_notices>
  └─ 构建 AttachmentSummary → 挂到 AgentRequest
  └─ 发布 AttachmentParsed 事件（IF-07a，当前无订阅者，见 §3 偏差）
```

---

## 2. 关键设计决策（已落地）

- **调度器不解析**：`ParseDispatcher` 只调度，格式解析全部经 `ParserRegistry` 委托给 `DocumentParser` 实现（spec §1.4.1 / 铁律 15）。
- **超时机制**：不依赖 `Future.cancel`（仓颉无可靠取消），改用 `spawn` 工作协程 + `AtomicBool` 标志 + 50ms 轮询；超时后**忽略**工作协程结果并转次优（解析器是黑盒，无法注入取消）。`parse_dispatcher.cj:123-147`。
- **阈值常量**（`parse_dispatcher.cj:46-48`）：单附件字节上限 `10MB`、单附件解析总耗时 `10s`、累计文本 `10万字符` 截断，均与 spec §4.1 对齐。
- **截断按 Rune**：字节切片会切断多字节字符导致抛异常，故 `truncate` 走 `toRuneArray()`（spec §4.1.4）。
- **注册表命中排序**：`resolve` 按「优先级降序、失败率升序」选择排序；同优先级冲突按 `parserId` 字典序稳定裁决；无候选返回空数组不抛（spec §5.2.1.1 / IF-04c）。
- **可观测**：`ParserRegistry.stats()` 已按「失败率降序 → 失败数降序」返回 `ParserStat[]`（IF-04f / T-HAC-12 的代码部分已完成）。
- **零静默丢弃**：所有丢弃/降级均产出告知性文本块并回灌 `<attachment_notices>`（spec §4.2.3）。

---

## 3. 与 spec / contract 的偏差（已登记）

| 偏差 | 现状 | 影响 |
|---|---|---|
| **内建参考解析器仍留在宿主源码树** | `src/plugin/multimodal/builtin/` 内的 `builtin.text/pdf/docx/pptx` 是宿主内 L2 实现，非可独立装卸的外部插件 | 与 v2「解析全部外置」终态仍有差距；属有意偏差（零依赖首个参考实现），详见 `doc-parser-plugins` design 与 SPECS_INDEX §7 |
| **IF-07a 事件无订阅者** | `attachment_parsed_event.cj` + `WebMCPProtocol` 发布点已落地，但 `attachment-persistence` 实际走 `AttachmentSummary` 直传落库，事件通道闲置 | 冗余通道；建议保留直传、事件留给前端留痕（见 SPECS_INDEX §7） |
| **后端能力门控兜底（T-HAC-10）** | 未做宿主侧按模型能力位的显式拦截；能力真相在 DB `llm_channel.capabilities`，前端上传入口已改为恒显（见 `web-multimodal` design §3） | 门控语义从「前端按 advisory 能力位拦截」改为「后端按通道能力决定投递方式」；T-HAC-10 需重新定义验收 |

---

## 4. 数据约束（实现即现状）

- `ParseRequest`：宿主剥离 dataURL 前缀后下发 `bytes`；携带 `ParseLimits(maxChars=100000, timeoutMs=10000)`。
- `ParseResult`：`status` ∈ `ok/empty/error`；`parts` 为 `FilePart[]`；`parserId`/`parserVersion` 必填（溯源）。
- `FilePart`：`source` 标注 + `text`；PDF 用 `[p.N]`、PPTX 用 `[slide N]` 分段标注（见 `builtin_parsers.cj`）。
- **绝不回显密钥 / 绝不落大 base64**：本子系统只持有附件字节与会话上下文，不接触 DB 凭据（spec §4.3）。

---

## 5. 差距清单（对照 `tasks.md`）

| 任务 | 状态 | 说明 |
|---|---|---|
| T-HAC-01~07, 09, 11 | ✅ 已落地 | 契约冻结、SPI/注册表/调度器/兜底/入口限流/留痕/事件发布 |
| T-HAC-10 后端能力门控兜底 | ⬜ 未做 | 需结合 `web-multimodal` 的新门控语义重新定义 |
| T-HAC-12 HTTP 管理端点 | 🟡 半成品 | `stats()` 代码已就绪，但缺暴露给运维的 HTTP 路由（contract IF-04 的查询侧） |
| T-HAC-13 L1 自测 | ⬜ 未做 | SC-01~05 无实测（仅编译通过） |
| T-HAC-14 L2 集成冒烟 | ⬜ 未做 | 需 runtime 实际运行 + 下游 `doc-parser-plugins` 配合 |

---

## 6. 验证状态与下一步

- **已验证**：runtime `cjpm build` 通过（cjc 1.1.3，2026-10-15）；`src/app/services/multimodal/` 已清空（无宿主内格式解析实现）。
- **未验证**：调度四条路径（命中/超时/次优/兜底）均无运行时实测；双分支（同步/流式）一致性未跑。
- **下一步建议**（不依赖本子系统改代码）：① 补 `stats()` 的 HTTP 暴露（T-HAC-12）；② 准备 L1 mock 解析器自测 + L2 冒烟 fixtures（T-HAC-13/14），待 runtime 运行后执行。

---

**修订记录**

| 日期 | 版本 | 触发 | 改动摘要 |
|---|---|---|---|
| 2026-10-16 | v1 | 主工程 T-MAIN-03 收口 | 按已落地代码反推撰写 design：实现即现状 + 偏差 + 差距 |
