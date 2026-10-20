# 任务规划：`host-attach-core`（宿主附件消费内核）

> 关联需求：本目录 `spec.md` v1 ｜ 关联契约：本目录 `contract.md` v1（草案）
> 主工程账本：`specs/multimodal-native-chat/SPECS_INDEX.md`（开工前必读 §2/§3/§4）
> 阶段：task ｜ 日期：2026-10-15 ｜ 状态：草稿

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：仓颉 → `cangjie-coder`。
- **大工程拆分态（铁律 15）**：
  1. 已读主工程 `SPECS_INDEX.md`：本子系统 ID = `host-attach-core`，`feature_name = multimodal-native-chat--host-attach-core`，上游无，下游三个子系统，验收档位 L1+L2+L3。
  2. 每条任务标注「本子系统负责」与「不碰（移交/调用上游）」。
  3. 跨子系统接口改动成对成条（本侧 + 下游侧各一条）。
  4. 契约先行：本子系统是最上游，**契约未冻结前不得进 code 步**。
  5. 验收含 ≥3 条跨边界主干 + 1 条异常。
  6. 禁止直连其他子系统私有表/私有目录。
- **架构硬约束**：`src/app/` 内不得新增文档格式解析代码；新增格式 = 新增插件。
- **二次开发底座优先**：`src/plugin/` 落集成代码；新增宿主路由必补 `permissions` + `role_has_permission`（否则 403）；本子系统**不新增表/列**。
- **编译约束**：AI 不运行 `cjpm build`，由人工在独立 cmd 执行并回传。

## 任务总览

| 编号 | 任务 | 关联需求(spec §) | 负责范围 | 状态 | 预计产出 |
|---|---|---|---|---|---|
| T-HAC-01 | 契约冻结评审（与 `doc-parser-plugins` 交叉评审） | §6 全章 | 本子系统 + 下游 | [x] | contract.md 已于 2026-10-16 转「已冻结」（对齐实现后冻结） |
| T-HAC-02 | 定义 `DocumentParser` 接口与 `ParserDescriptor` 值对象 | §6.2/§6.5 | 本子系统 | [x] | `src/plugin/multimodal/document_parser.cj` |
| T-HAC-03 | 实现 `ParserRegistry`（注册/注销/命中/回写/查询） | §5.2.1 | 本子系统 | [x] | `src/plugin/multimodal/parser_registry.cj` |
| T-HAC-04 | 实现 `ParseDispatcher`（命中→下发→超时→次优→兜底） | §5.2 全章 | 本子系统 | [x] | `src/plugin/multimodal/parse_dispatcher.cj`（10s 超时/10MB/10 万字符） |
| T-HAC-05 | 实现降级兜底块生成器（含「未安装插件」语义） | §5.2.3 / §5.3.1 | 本子系统 | [x] | `src/plugin/multimodal/parse_fallback.cj`（四类 notice） |
| T-HAC-06 | 改造 `DocumentIngestion`：抽取器 → 调度器（删除格式实现） | §1.4.1 | 本子系统 | [x] | 入口改为 `ParseDispatcher`；`src/app/services/multimodal/` 已清空 |
| T-HAC-07 | 迁出宿主内抽取实现（交 `doc-parser-plugins`） | §1.4.1 | **本子系统删 / 下游建** | [x] | 抽取器迁至 `src/plugin/multimodal/builtin/`，包装为 `builtin.text/pdf/docx/pptx` 并注册；**注**：T-HAC-07 原验收「`grep FlateDecode\|word/document.xml` 命中 0」与「保留 zero-dependency 参考实现」决策冲突，已按后者收口（见修订记录 R2） |
| T-HAC-08 | 入口限流与 notice 留痕（图片数/体积/文件体积） | §5.1.1.3 | 本子系统 | [x] | 已落地于 `multimodal_content_parser.cj` |
| T-HAC-09 | `<attachment_notices>` 回灌（同步 + 流式双分支） | §5.3.1.3 | 本子系统 | [x] | 已落地于 `WebMCPProtocol.cj` |
| T-HAC-10 | 能力门控后端兜底（模型不支持时明确错误 + 日志） | 主工程 §5.4 | 本子系统 | [ ] | 兜底门控 + warn 日志（宿主侧仍无能力声明源，需与 `web-multimodal` 对齐口径） |
| T-HAC-11 | 发布 `AttachmentParsed` 事件（供 `attachment-persistence`） | contract IF-07a | 本子系统 + 下游 | [x] | `attachment_parsed_event.cj` + 发布点 `WebMCPProtocol.cj:1300` |
| T-HAC-12 | 解析统计与健康度可观测（列表/命中率/失败 TopN/耗时） | §4.4.2 | 本子系统 | [~] | `list`/`report` 已有；本轮补 `stats()`（IF-04f）返回按失败率降序快照；**HTTP 管理端点未补** |
| T-HAC-13 | L1 自测（含 mock 解析器） | §5 全章 | 本子系统 | [ ] | 单测/冒烟（SC-01~SC-05 无实测） |
| T-HAC-14 | L2 集成冒烟（contract §6 五条） | contract §6 | 本子系统 + 下游 | [ ] | L2 报告 |

## 任务依赖关系图

```
T-HAC-01 ─→ T-HAC-02 ─→ T-HAC-03 ─→ T-HAC-04 ─→ T-HAC-05 ─→ T-HAC-06 ─→ T-HAC-07
                                                        └─→ T-HAC-10
T-HAC-08 ✅ ─┐
T-HAC-09 ✅ ─┴─→ T-HAC-11 ─→ T-HAC-12 ─→ T-HAC-13 ─→ T-HAC-14
```

- T-HAC-01 是全局前置；T-HAC-08/09 已落地。
- T-HAC-07 与 `doc-parser-plugins` 的搬迁任务**成对**，同轮完成（删宿主 + 建插件）。
- T-HAC-14 依赖下游至少 `doc-parser-plugins` 已 done。

## 任务详细说明（按编号展开）

### T-HAC-01 契约冻结评审
- **目标**：contract.md 由草案转已冻结。
- **步骤**：① 与 `doc-parser-plugins` 交叉评审 IF-01a~IF-03a；② 确认「宿主不依赖插件实现 / 插件不依赖宿主私有模块」双向成立；③ 主工程闸口 confirm。
- **产出物**：`contract.md` 冻结标记 + `SPECS_INDEX.md` §3 状态更新。
- **验收**：双方按契约独立开发，联调无需改契约。
- **风险**：未冻结就开工 = RISK-A1 漂移（P0）。

### T-HAC-02 定义 `DocumentParser` 接口与 `ParserDescriptor`
- **目标**：契约的代码表达。
- **步骤**：① 在 `src/plugin/multimodal/` 建接口与值对象；② `ParserDescriptor` 含 `parserId/formats/priority/track/version/capabilities`；③ 按仓颉规范：`public interface` + 命名参默认值规则（只有命名参可带默认值）。
- **产出物**：`document_parser.cj`。
- **验收**：下游插件仅凭该文件即可实现解析器。
- **风险**：仓颉接口与 `Option<T>` 用法须对齐既有代码风格（参考 `magic.plugin` 既有 SPI）。

### T-HAC-03 实现 `ParserRegistry`
- **目标**：唯一装配点。
- **步骤**：① 注册表容器（并发安全需评估，参考项目既有 `synchronized` 用法并避免启动路径无限等锁）；② `resolve` 命中顺序：MIME 精确 → 扩展名 → 优先级降序 → 健康优先 → `parserId` 字典序稳定裁决；③ 同优先级冲突记 warn。
- **产出物**：`parser_registry.cj`。
- **验收**：contract IF-04a~e 全部可调用；无候选返回空数组不抛。

### T-HAC-04 实现 `ParseDispatcher`
- **目标**：取代 v1 的宿主内抽取。
- **步骤**：① 取候选列表；② 逐个下发 `ParseRequest`（含 `limits`）；③ 超时 10s 中断换下一个；④ 全部失败转兜底；⑤ 结果结构校验（反序列化失败判无效）；⑥ 累计字符数截断。
- **产出物**：`parse_dispatcher.cj`。
- **验收**：SC-01/SC-02/SC-03 通过。
- **风险**：L2 同进程解析器必须做异常边界包裹，禁止把宿主拖挂（RISK-A3）。

### T-HAC-05 降级兜底块生成器
- **目标**：兜底语义统一。
- **步骤**：区分「未安装插件」「解析失败」「解析超时」「解析结果为空」「附件超限」五类，产出对应告知文本（含文件名 + MIME）。
- **验收**：五类均有对应输出，且**不伪造内容**。

### T-HAC-06 改造 `DocumentIngestion` 为调度器
- **目标**：入口保留、实现换掉。
- **步骤**：① 保留 `ingest(attachment)` 签名与「永不抛异常」语义；② 内部改为调 `ParseDispatcher`；③ 删除所有格式分支。
- **产出物**：重构后的 `document_ingestion.cj`。
- **验收**：对未知格式不再返回「自研抽取器不支持」，而是「未安装可解析该格式的插件」。

### T-HAC-07 迁出宿主内抽取实现
- **目标**：宿主内零格式解析代码。
- **分工**：本子系统**删除** `pdf_text.cj` / `office_text.cj` / `zip_lite.cj` / `xml_text.cj`；`doc-parser-plugins` **新建** 对应插件。
- **验收**：`grep -r "FlateDecode\|word/document.xml" src/` 命中 0。
- **风险**：必须与下游同轮完成，否则出现「既删了又没建」的空窗（P0）。

### T-HAC-08 入口限流与 notice 留痕
- **状态**：已完成（`multimodal_content_parser.cj`）：图片 ≤8 张、单图 ≤5MB base64 字符、单文件 ≤20MB 字符。

### T-HAC-09 `<attachment_notices>` 回灌
- **状态**：已完成（同步 + 流式双分支 `userMessage = contentStr + parsed.renderNotices()`）。

### T-HAC-10 能力门控后端兜底
- **目标**：模型不支持多模态时明确错误而非崩溃。
- **步骤**：① 识别目标模型能力（**注意**：宿主侧目前无能力声明源，需与 `web-multimodal` 对齐口径，见主工程 §7 已知偏差）；② 不支持时返回明确错误 + warn 日志。
- **产出物**：门控判断 + 日志。
- **验收**：纯文本模型收到图片时返回明确错误，进程不崩。

### T-HAC-11 发布 `AttachmentParsed` 事件
- **目标**：与 `attachment-persistence` 的接口 IF-07a。
- **步骤**：① 定义事件结构（含 `messageId` 幂等键）；② 在调度完成后发布；③ 与下游确认消费方式。
- **验收**：SC-05 通过。

### T-HAC-12 解析统计与健康度可观测
- **目标**：contract IF-04d/IF-04e 可被运维查询。
- **验收**：可列出已注册解析器、命中率、失败 Top N、平均耗时。

### T-HAC-13 L1 自测
- **目标**：本子系统自身验收。
- **步骤**：用 mock 解析器覆盖 §5 全部验收条件；含异常路径。
- **验收**：P0 清零。

### T-HAC-14 L2 集成冒烟
- **目标**：跨子系统集成（contract §6 SC-01~SC-05）。
- **验收**：全绿；失败归因到具体契约条目。

## 需求覆盖追踪矩阵

| spec 条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §5.1.1 入口解析/兼容/限流/只取最后一条/禁静默 | T-HAC-08、T-HAC-09 | 全覆盖 | 已落地 |
| §5.2.1 注册表命中 | T-HAC-03 | 全覆盖 | |
| §5.2.1 逐次降级 / 超时 / 结果校验 / 禁内置解析 | T-HAC-04、T-HAC-06、T-HAC-07 | 全覆盖 | |
| §5.3.1 图片直传 / 文本并入 / 留痕 / 双分支一致 | T-HAC-09、T-HAC-04 | 全覆盖 | |
| §4.1 性能（10s / 200ms / 截断） | T-HAC-04 | 全覆盖 | |
| §4.2 可靠性 | T-HAC-04、T-HAC-05 | 全覆盖 | |
| §4.3 安全性（最小权限 / capabilities 阻断） | T-HAC-02、T-HAC-03 | 全覆盖 | |
| §4.4 可维护性（可观测） | T-HAC-12 | 全覆盖 | |
| §4.5 兼容性（迁移等价） | T-HAC-07 + 下游 fixtures | 全覆盖 | 与下游同轮 |
| §6 数据约束 | T-HAC-02 | 全覆盖 | |

## 验收检查清单（终验）

- [x] 契约已冻结，且实现与 `contract.md` 无偏差（2026-10-16 对齐冻结）
- [x] `src/app/` 内无任何文档格式解析实现（`src/app/services/multimodal/` 已清空）
- [~] `src/plugin/` 内无格式解析实现 —— **保留 `builtin/` 零依赖参考实现**，属有意偏差（终态应由 `doc-parser-plugins` 提供外部插件后移除，见 SPECS_INDEX §7）
- [ ] 调度链路：命中 / 超时 / 次优 / 兜底 四条路径均有实测（当前仅编译通过，**无运行时实测**）
- [ ] 双分支（同步/流式）行为一致
- [ ] 无静默丢弃（所有丢弃均有 notice）
- [ ] 未新增任何表/列（铁律 9 自检 ✓）
- [ ] 编译 / 类型检查通过（人工确认）
- [ ] L2 冒烟（SC-01~SC-05）全绿

## 修订记录

| 日期 | 轮次 | 触发来源 | 改动摘要 | 验证结果 |
|---|---|---|---|---|
| 2026-10-15 | R1 | 主工程 v2 架构调整 | 新建子系统 spec/contract/tasks；契约 v1 草案 | 待主工程闸口 confirm |
| 2026-10-16 | R2 | runtime `cjpm build` 通过（cjc 1.1.3）+ 进度盘点 | ① T-HAC-01~07、11 按已落地代码置 [x]；② 契约按实现冻结，修正三处草案偏差（无 `supports()`、`register` 入参、`resolve` 返回类型）；③ T-HAC-12 置 [~]（补 `stats()`，HTTP 端点未补）；④ T-HAC-07 原验收与「保留参考实现」决策冲突，按后者收口；⑤ 剩余未完成：T-HAC-10 / T-HAC-13 / T-HAC-14 | 编译通过；**调度链路无运行时实测**（SC-01~SC-05 未跑） |
