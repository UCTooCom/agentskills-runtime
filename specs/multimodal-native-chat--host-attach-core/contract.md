# 子系统集成契约（`host-attach-core`）

> 模板：`templates/subsystem-contract-template.md`
> 产出阶段：spec / design 步 ｜ 铁律依据：**铁律 15**
> 契约是**承诺**，不是设计说明；禁止在实现里单边改动。

## 文档信息

- 所属主工程：`multimodal-native-chat`
- 子系统 ID：`host-attach-core`（稳定标识，跨轮次不变）
- 子系统 `feature_name`：`multimodal-native-chat--host-attach-core`
- 契约版本：`v1`
- 冻结状态：**已冻结**
- 冻结日期：2026-10-16（对齐已实现代码后冻结）
- 上游依赖：无（本子系统是最上游）
- 下游消费方：`doc-parser-plugins` v1、`web-multimodal` v1、`attachment-persistence` v1

---

## 1. 本子系统提供什么（能力清单）

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| IF-01a | 进程内调用 | `magic.plugin.multimodal.DocumentParser.descriptor` | — | `()` | `ParserDescriptor` | 不适用（由插件实现） | 是 | 契约声明在宿主，实现在插件 |
| IF-02a | 进程内调用 | `ParserRegistry.resolve`（内部经 `formatMatches`） | — | `(descriptor.formats, filename, mimeType)` | `Bool`（命中判定） | 不抛 | 是 | **声明式命中**：格式能力由 `ParserDescriptor.formats` 表达；`DocumentParser` **不提供** `supports()`。MIME 支持 `type/*` 通配，扩展名按后缀匹配（大小写不敏感） |
| IF-03a | 进程内调用 | `magic.plugin.multimodal.DocumentParser.parse` | — | `(ParseRequest)` | `ParseResult` | **实现不得抛出未捕获异常**；失败以 `status=Error` + `error` 表达 | 否（读取字节有副作用） | 超时由宿主 `ParseDispatcher` 强制（10s），超时后转次优，不等待解析器自行退出 |
| IF-04a | 进程内调用 | `ParserRegistry.register` | — | `(parser: DocumentParser)` | `Unit` | 描述符由 `parser.descriptor()` 取得；重复 `parserId` 按版本覆盖，不报错 | 是（同 ID 重复注册幂等） | 供插件注册；**入参是解析器实例本身**，不是 `ParserDescriptor` |
| IF-04b | 进程内调用 | `ParserRegistry.unregister` | — | `(parserId: String)` | `Bool` | 未注册返回 `false` | 是 | 供卸载 |
| IF-04c | 进程内调用 | `ParserRegistry.resolve` | — | `(filename: String, mimeType: String)` | `ArrayList<DocumentParser>`（按「优先级降序、失败率升序」有序） | 无候选返回空数组，**不抛** | 是 | 供调度器与查询 |
| IF-04d | 进程内调用 | `ParserRegistry.report` | — | `(parserId: String, ok: Bool, costMs: Int64)` | `Unit` | 未知 ID 记 warn 不抛 | 是 | 回写健康度 |
| IF-04e | 进程内调用 / `host.parser.list` | `ParserRegistry.list` | — | `()` | `ArrayList<ParserDescriptor>` | 不抛 | 是 | 供管理界面与运维 |
| IF-04f | 进程内调用 | `ParserRegistry.stats` | — | `()` | `ArrayList<ParserStat>`（按失败率降序、失败数降序） | 不抛 | 是 | 可观测：命中率/失败 TopN/平均耗时（T-HAC-12） |
| IF-04g | 进程内调用 | `ParserRegistry.size` | — | `()` | `Int64` | 不抛 | 是 | 已注册数量 |
| IF-06a | 进程内事件 | 用户消息文本中的 `<attachment_notices>` 块 | — | 文本块 | — | — | — | 供 `web-multimodal` 呈现、供模型告知 |
| IF-07a | 进程内事件 | `AttachmentParsed` 事件（经 `AttachmentParsedEventBus.publish`） | — | `{sessionId: String, messageId: String, attachmentCount: Int64, parseSummary: String, attachments: ArrayList<AttachmentMeta>}` | — | 订阅者异常被吞，不影响发布方 | 幂等键 `messageId` | 供 `attachment-persistence` / `web-multimodal` 消费 |

- **契约以 `src/plugin/multimodal/` 已实现代码为准**（2026-10-16 冻结）：`document_parser.cj`（IF-01a/IF-02a 值对象/IF-03a）、`parser_registry.cj`（IF-04a~g）、`parse_dispatcher.cj`、`parse_fallback.cj`、`attachment_parsed_event.cj`（IF-07a）。
- **IF-02 口径变更（原草案有偏差）**：草案曾约定 `DocumentParser.supports(filename, mimeType) -> Bool`，实现未采纳；改为「描述符声明格式 + 注册表统一匹配」。理由是命中可在不加载/实例化解析器的前提下完成，且便于 `list()` 直接对运维可见。**此变更在冻结时一并确认，非事后漂移。**
- **兜底语义**（`parse_fallback.cj`，供下游对齐 notice 文案）：`no_plugin`（未安装可解析该格式的插件）/ `too_large`（超 10MB）/ `unsupported`（base64 解不出字节）/ `parse_failed`（全部候选失败，含逐条原因）。兜底块**绝不伪造内容**。

- **错误约定**：复用 uctoo 既有统一错误响应结构，跨子系统**不自造错误码**；冲突时以主工程 `SPECS_INDEX.md` §3 裁决。
- **幂等性**：写类接口以 `messageId` / `parserId` 为幂等键。

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| 无 | 本子系统**不新增表、不加列** | — | — | — | — |

- 本子系统在数据面上是**零表**子系统：附件只在会话生命周期内以内存对象存在，落库全部归 `attachment-persistence`。
- 铁律 9 自检：本子系统不需要任何新表/新列，复用既有内存值对象即可 ✓。

## 3. 依赖方向

- **我依赖的上游**：无（本子系统定义契约，是最上游）。
- **我不依赖谁**：
  - 不依赖 `doc-parser-plugins` 的**任何具体实现**，只依赖本文 §1 的 IF-01a/IF-02a/IF-03a 接口；
  - 不依赖 `web-multimodal` 的任何内部状态；
  - 不依赖 `attachment-persistence` 的表结构。
  > 将来若要依赖，必须回本文改依赖方向并过闸口，禁止在实现里偷偷 import（依赖漂移按 P0 计）。
- **禁止成环**：本子系统作为最上游，与任一子系统出现双向依赖即判定切错边界。

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| 任何文档格式的字节级解析 | `doc-parser-plugins` | 解析外置是本轮架构调整的核心 |
| 解析插件的打包/发布/生命周期 | `plugin-system`（既有）+ `doc-parser-plugins` | 复用既有三轨机制 |
| 附件元数据的持久存储 | `attachment-persistence` | 数据面分离 |
| 上传 UI / 能力门控 / 留痕呈现 | `web-multimodal` | 前端交付面 |
| 模型的视觉能力判定数据来源 | 主工程 + `web-multimodal` | 宿主侧目前没有能力声明源，见主工程 §7 已知偏差 |

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动，在 `tasks.md` 修订记录留痕 |
| 向后兼容（minor） | 只增接口/只增可选字段 | 改本文 + 主工程 §3 汇总；下游不必同步改 |
| 破坏性（major） | 改方法签名/改字段语义/改权限口径 | **必须双侧同轮**：本子系统与全量消费方同轮改完；主工程 SPECS_INDEX §6 登记；单侧先改 = P0 |

- 演进一律「先改契约 → 再改实现」。

## 6. 集成验收（本子系统对下游的交付承诺）

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| SC-01 | 插件注册 → 宿主 `resolve` 命中 → 下发 `parse` → 收到 `FilePart` | 用一个 mock 解析器（固定返回已知 FilePart）跑通全链路 | 无 | 用户消息中出现带 `source` 的解析文本 |
| SC-02 | 首选解析器超时 → 自动切次优 → 成功 | mock 首选 sleep 超时、次优正常 | 无 | 最终产出次优的 FilePart，无降级块 |
| SC-03 | 全部解析器失败 → 兜底块 + notice 回灌 | mock 全部抛异常 | 无 | 响应含「未读取到内容」语义，请求不失败 |
| SC-04 | **异常**：卸载全部解析器后上传 PDF | 清空注册表后发请求 | 无 | 宿主不崩溃、产出「未安装可解析该格式的插件」、日志含原因 |
| SC-05 | 跨 `host-attach-core` → `attachment-persistence`：IF-07a 事件可被消费 | 与 `attachment-persistence` 合并态下跑 | 该子系统 done | 事件被接收且元数据格式符合约定 |

- §6 用例由本子系统 test 步执行（L1 + L2）；主工程端到端（L3）不在本文重复。
- 上游就位前提：本子系统无上游依赖；下游冒烟需本子系统处于 done。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|---|---|---|---|
| 2026-10-15 | v1 | 主工程 v2 架构调整（解析外置） | 首次落契约：IF-01a/IF-04a~e/IF-06a/IF-07a | `doc-parser-plugins`、`web-multimodal`、`attachment-persistence` 全部按本契约开发 |
| 2026-10-16 | v1 | 与已实现代码对齐后冻结（T-MAIN-01 / T-HAC-01） | ① 补 IF-02a（声明式命中）与 IF-03a（`parse`），§1 表格补全；② **修正草案偏差**：`DocumentParser` 无 `supports()`，命中由 `ParserRegistry` 依 `descriptor.formats` 完成；③ `register` 入参由 `(ParserDescriptor, ParserHandle)` 修正为 `(parser: DocumentParser)`；④ `resolve` 返回 `ArrayList<DocumentParser>`；⑤ 新增 IF-04f `stats`、IF-04g `size`；⑥ IF-07a 事件字段按实现写精确（`attachmentCount` 等）；⑦ 补兜底语义四类 notice | 下游按冻结版开发；`doc-parser-plugins` 实现 `DocumentParser` 时无需实现 `supports()` |
