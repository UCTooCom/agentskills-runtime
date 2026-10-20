# 子系统集成契约（`doc-parser-plugins`）

> 模板：`templates/subsystem-contract-template.md`
> 产出阶段：spec / design 步 ｜ 铁律依据：**铁律 15**
> 契约是**承诺**，不是设计说明；禁止在实现里单边改动。

## 文档信息

- 所属主工程：`multimodal-native-chat`
- 子系统 ID：`doc-parser-plugins`（稳定标识，跨轮次不变）
- 子系统 `feature_name`：`multimodal-native-chat--doc-parser-plugins`
- 契约版本：`v1`
- 冻结状态：**草案**（待主工程闸口 confirm）
- 冻结日期：2026-10-15（草案）
- 上游依赖：`host-attach-core` v1（`DocumentParser` SPI / `ParserRegistry` / `ParseRequest` / `ParseResult` / `FilePart`）
- 下游消费方：无直接下游（本子系统经 `host-attach-core` 的注册表被间接消费）

---

## 1. 本子系统提供什么（能力清单）

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| IF-01 | L3 插件跨轨 / 进程内调用 | `parser.descriptor` | `descriptor()` | `()` | `ParserDescriptor` | 不适用 | 是 | 与 `host-attach-core` IF-01a 同契约 |
| IF-02 | L3 插件跨轨 / 进程内调用 | `parser.supports` | `supports()` | `(filename, mimeType)` | `Bool` | 不适用 | 是 | 宿主以 descriptor 为主，本方法为二次确认 |
| IF-03 | L3 插件跨轨 / 进程内调用 | `parser.parse` | `parse()` | `ParseRequest`（JSON: `{filename, mimeType, bytes(base64), limits}`） | `ParseResult`（JSON: `{status, parts[], error, parserId, parserVersion}`） | 内部异常一律转 `status=error` + `error` 文本，**不向宿主抛** | 是（无状态，同输入同输出） | 核心接口 |
| IF-08 | 库表（无） | — | — | — | — | — | — | 本子系统**零表**，不落库 |

- **错误约定**：复用 uctoo 既有统一错误响应结构；跨子系统不自造错误码。
- **幂等性**：解析器无状态，`parse` 对同一输入可重复调用。
- **类型口径**：
  - L2 轨 = 进程内调用（宿主直接持有函数引用）；
  - L3 轨 = L3 插件跨轨（经 `host.parser.*` 服务代理 / stdio jsonrpc），**不走裸文件**。

> **技能适配与安装时轨决策（与 `spec.md` §5.4 对齐）**：从其它技能市场获取的解析技能通常需略作适配方能在 agentskills-runtime 良好运行；其最终以「纯文档技能 / L2 动态库轨 / L3 进程隔离轨」哪一种形态接入，**不在架构层预先固定**，而是在该技能安装到本运行时时结合实现语言、隔离需求与运行环境具体决策（安装时 Checklist 见 `spec.md` §5.4.1）。本子系统负责该适配与决策落地，但**不改写技能实现本体**。

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| 无 | 本子系统**不新增表、不加列、不直连 DB** | — | — | — | — |

- 插件不直连 PostgreSQL；需要宿主能力时经 `host.db` / `host.log` 服务代理反向调用（复用宿主 ORM 与权限过滤）。
- 铁律 9 自检：本子系统零表 ✓。

## 3. 依赖方向

- **我依赖的上游**（有限名单，只允许这几条，禁止反向）：
  1. `host-attach-core` v1 —— 取 `DocumentParser` 契约、`ParseRequest` / `ParseResult` / `FilePart` 数据结构、注册通道（`ParserRegistry.register`）。
  2. `plugin-system`（既有基础设施，非本工程子系统）—— 三轨加载、生命周期、`host.*` 服务代理。
- **我不依赖谁**：
  - 不依赖 `web-multimodal` 的任何东西；
  - 不依赖 `attachment-persistence` 的表结构；
  - **不依赖宿主私有模块**（禁止 import `magic.app.*` 私有实现），只依赖 §1 契约接口。
  > 真要依赖必须回本文改依赖方向并过闸口；实现里偷偷 import = 依赖漂移，按 P0 计。
- **禁止成环**：本子系统与 `host-attach-core` 的依赖关系必须是「插件实现宿主定义的接口」这一单向形态。

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| 附件接收、限流、调度、提交、留痕 | `host-attach-core` | 宿主职责 |
| 插件加载/卸载机制本身 | `plugin-system`（既有） | 复用三轨，不新造 |
| 前端上传与门控 | `web-multimodal` | 前端交付面 |
| 附件元数据落库与审计界面 | `attachment-persistence` | 数据面分离 |
| 模型能力判定 | `host-attach-core` + 主工程 | 与解析无关 |

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动，在 `tasks.md` 修订记录留痕 |
| 向后兼容（minor） | 只增可选字段（如 `FilePart` 新增可选字段） | 改本文 + 主工程 §3；宿主按可选处理，插件不必同步改 |
| 破坏性（major） | 改 `ParseRequest` / `ParseResult` 字段语义、改 `parse` 方法语义 | **必须双侧同轮**：`host-attach-core` 与全部已注册插件同轮改完；主工程 SPECS_INDEX §6 登记；单侧先改 = P0 |

- 演进一律「先改契约 → 再改实现」。
- 契约冻结后到实现完成之间的任何偏差，在 `test-report.md` 必须归因到具体契约条目。

## 6. 集成验收（本子系统对下游的交付承诺）

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| SC-11 | L2 仓颉插件注册后被宿主命中并完成 DOCX 解析 | 与 `host-attach-core` 合并态实跑 | `host-attach-core` done | 用户消息出现带 `source` 的解析文本 |
| SC-12 | L3 非仓颉插件（Python 生态）被宿主命中并完成 PDF 解析 | 与 `host-attach-core` 合并态实跑 | `host-attach-core` done | CID 中文 PDF 产出可读中文（或明确记录仍是乱码并归因） |
| SC-13 | 同一格式两个插件按优先级命中；首选失败回落到次优 | mock 首选失败 | `host-attach-core` done | 最终由次优产出结果 |
| SC-14 | **异常**：L3 插件进程被 kill | 手工 kill 子进程后发请求 | `host-attach-core` done | 宿主不崩、标记插件不可用、转次优或兜底 |
| SC-15 | 标准技能经 `SkillAdapter` 装配为解析器并可被调用 | 用一个自带脚本的最小技能验证 | `host-attach-core` done | 技能脚本输出被转成 `FilePart` |

- §6 用例由本子系统 test 步执行（L1 + L2）；L3 端到端在主工程执行。
- 上游就位前提：`host-attach-core` 处于 done 且不晚于本文冻结日。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|---|---|---|---|
| 2026-10-15 | v1 | 主工程 v2 架构调整（解析外置） | 首次落契约：IF-01/02/03，零表，单向依赖 `host-attach-core` v1 | 无直接下游；宿主侧需同轮实现注册与调用（T-HAC-02/03/04） |
