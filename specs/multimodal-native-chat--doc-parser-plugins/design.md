# 设计文档：文档解析插件轨（`doc-parser-plugins`）

> 主工程：`multimodal-native-chat` ｜ 子系统 `feature_name`：`multimodal-native-chat--doc-parser-plugins`
> 版本：v1 ｜ 日期：2026-10-16 ｜ 阶段：design（**实现先行、按代码反推**）
> 关联：`spec.md` v1 ｜ `contract.md` v1（2026-10-16 冻结）｜ `tasks.md`
> 语言标签：cangjie（L2 轨）/ 脚本·Python·Node（L3 轨，未落地）

---

## 0. 本文档定位（重要）

与 `host-attach-core` 同理，本子系统也是「**实现先于 design**」。本文档如实记录现状并指出差距。

**一句话现状**：宿主内已落地 4 个**零依赖 L2 参考解析器**（`builtin.text/pdf/docx/pptx`），
经 `ParserRegistry` 注册即可被调度内核调用；但 spec / tasks 期望的「可独立装卸的外部 L2/L3 插件轨、
生态解析器接入、SkillAdapter、安装期轨决策、fixtures 等价校验」**均尚未实现**。

> 注意：`tasks.md` 当前 13 项全部标记为 `[ ]`，与代码现状不符——这是「实现先于文档」导致的漂移。
> 本文档以代码为准：T-DPP-03（存量抽取器搬迁为 L2 参考实现）的代码部分**已完成**，
> 但其「外部化 / 可装卸 / 生态接入」的目标态**未完成**。

---

## 1. 架构总览（实现即现状）

### 1.1 已落地的内建参考解析器（L2 轨，宿主源码树内）

| 文件 | 内容 |
|---|---|
| `src/plugin/multimodal/builtin/builtin_parsers.cj` | 4 个解析器类 + `registerAllBuiltinParsers(registry)` 注册入口 |
| `src/plugin/multimodal/builtin/pdf_text.cj` | PDF 文本抽取（`PdfTextExtractor.extractPages` → 按页 `[p.N]` 分段） |
| `src/plugin/multimodal/builtin/office_text.cj` | DOCX/PPTX 文本抽取（`OfficeTextExtractor.extractDocx` / `extractPptxSlides` → `[slide N]`） |
| `src/plugin/multimodal/builtin/xml_text.cj` | XML 文本抽取 |
| `src/plugin/multimodal/builtin/zip_lite.cj` | 轻量 zip 处理 |

### 1.2 注册形态（来自 `builtin_parsers.cj`）

- `BuiltinTextParser`：`parserId=builtin.text`，`formats` 覆盖 `text/*` + 常见文档扩展名（txt/md/json/csv/代码族/xml/html…），`priority=100`，`track=L2`，`version=1.0.0`。
- `BuiltinPdfParser` / `BuiltinDocxParser` / `BuiltinPptxParser`：分别对应 `application/pdf`、OOXML word/presentation，`priority=100`，`track=L2`。
- 注册时机：宿主初始化期由 `WebMCPProtocol.init` 调 `registerAllBuiltinParsers(ParserRegistry.shared())` 完成（幂等，重复调用按 `parserId` 覆盖）。

### 1.3 解析器契约（已实现，与 `host-attach-core` 冻结版对齐）

每个解析器实现 `DocumentParser`：
- `descriptor(): ParserDescriptor`
- `parse(request: ParseRequest): ParseResult` —— 空字节/空内容返 `Empty`，二进制返 `Empty`，异常自我捕获返 `Error`，**不崩溃到不可响应**（spec §4.2.2）。
- 文本截断遵守 `request.limits.maxChars`（按 Rune）。

---

## 2. 关键设计决策（已落地）

- **零外部依赖**：`builtin.*` 全部用仓颉标准库 / `stdx` 实现，不依赖 Python/Node，保证最小化部署场景仍可解析（spec §5.1.1.2）。
- **分段标注**：PDF 按页、PPTX 按幻灯片标注 `[p.N]` / `[slide N]`，与 spec §6 的 `source` 标注约定一致，便于模型定位引用。
- **与调度内核解耦**：`builtin.*` 只是 `DocumentParser` 的一种实现，将来可无缝被外部 L2/L3 插件替换，无需改 `host-attach-core` 调度逻辑（spec §1.4 / 铁律 15）。

---

## 3. 与 spec / contract 的偏差（核心）

| 偏差 | spec 期望 | 现状 | 影响 |
|---|---|---|---|
| **解析外置程度** | 解析全部外置为可独立装卸的 L2/L3 插件，新增格式 = 装插件而非改宿主 | 仅落地了**宿主内** `builtin.*` 参考实现；无独立可装卸插件机制、无 `plugingen` 脚手架 | 与 v2 终态差距最大，属有意偏差（首个参考实现），见 SPECS_INDEX §7 |
| **L3 生态解析器** | 用 MarkItDown/MinerU 等 Python 实现承载 CID 中文 PDF / 扫描件 / 复杂表格 | 未做（T-DPP-05/06 未启动） | AC4/AC5 缺实际演示证据 |
| **SkillAdapter** | 标准技能（`SKILL.md` + `scripts/`）包装为 `DocumentParser` | 未做（T-DPP-07/08） | 生态复用未打通 |
| **安装期轨决策** | 安装时按实现语言/隔离需求/运行环境选定 L2/L3/纯文档技能形态 | 未做（T-DPP-09/11） | 无 capabilities 声明与人工确认、无环境不适用检测 |
| **fixtures 等价校验** | 搬迁前后对同一 fixtures 结果等价 | 未做（T-DPP-04） | 迁移等价无实测证据 |

---

## 4. 数据约束（实现即现状）

- 解析器消费 `ParseRequest`（`filename` / `mimeType` / `bytes` / `limits`），产出 `ParseResult`（`status` / `parts` / `error` / `parserId` / `parserVersion`）。
- `FilePart.source` 当前为 `filename` 或 `filename [p.N]` / `[slide N]`，满足 spec §6.3 的必填标注要求。
- 不接触 DB、不索取会话令牌（spec §4.3.1）。

---

## 5. 差距清单（对照 `tasks.md`）

| 任务 | 状态 | 说明 |
|---|---|---|
| T-DPP-01 契约冻结 | ✅ 已冻结 | 与 `host-attach-core` 对齐，2026-10-16 |
| T-DPP-02 `plugingen` 生成 L2 骨架 | ⬜ 未做 | 当前是手写内建，非工具生成 |
| T-DPP-03 存量抽取器搬迁为 L2 参考实现 | 🟡 代码完成 / 外置未完成 | 抽取器已迁至 `builtin/`，但非独立可装卸插件 |
| T-DPP-04 fixtures 等价校验 | ⬜ 未做 | 无 fixtures 集、无等价报告 |
| T-DPP-05 L3 可行性 Spike | ⬜ 未做 | |
| T-DPP-06 生态解析器接入 | ⬜ 未做 | |
| T-DPP-07/08 SkillAdapter + 第三方接入流程 | ⬜ 未做 | |
| T-DPP-09/11 capabilities 声明 + 环境不适用检测 | ⬜ 未做 | |
| T-DPP-10 多解析器优先级/故障回落实测 | ⬜ 未做 | 注册表逻辑已支持，未跑实测 |
| T-DPP-12/13 L1 / L2 冒烟 | ⬜ 未做 | |

---

## 6. 验证状态与下一步

- **已验证**：`cjpm build` 通过；4 个内建解析器可注册、可被 `ParseDispatcher` 调起（编译期 + 调用契约正确）。
- **未验证**：实际解析质量（中文 PDF 等）、等价性、崩溃隔离（L3 缺失故无 L3 隔离实测）。
- **下一步建议**（按优先级）：
  1. **先收口可装卸插件骨架**（T-DPP-02 + 把 `builtin.*` 移到真正独立可装卸形态），这是 v2 终态的硬门槛，也是 AC4 的前置。
  2. 再上 L3 生态解析器（T-DPP-05/06）以拿到 AC5 的实际证据。
  3. fixtures 等价校验（T-DPP-04）应尽早补，作为一切迁移的安全网。

---

**修订记录**

| 日期 | 版本 | 触发 | 改动摘要 |
|---|---|---|---|
| 2026-10-16 | v1 | 主工程 T-MAIN-03 收口 | 按代码反推：现状=4 个内建 L2 参考解析器；差距=外置/L3/SkillAdapter/fixtures 全未做 |
