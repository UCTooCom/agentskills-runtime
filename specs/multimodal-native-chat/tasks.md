# 任务规划文档（主工程 · 总装与组合集成）

> 基于 `spec.md` v2 与 `design.md` v2 生成。
> **本文件只承载主工程级任务**：契约冻结、子系统协同、组合集成、端到端验收。
> **子系统内部的编码任务一律下沉到** `specs/multimodal-native-chat--{子系统ID}/tasks.md`，此处不重复。

## 文档信息

- 关联需求：`specs/multimodal-native-chat/spec.md`（v2 架构调整版）
- 关联设计：`specs/multimodal-native-chat/design.md`（v2）
- 子系统目录：`specs/multimodal-native-chat/SPECS_INDEX.md`
- 生成日期：2026-10-15 ｜ 版本：v2 ｜ **最后盘点：2026-10-16**
- 状态：**进行中** —— 契约已冻结（T-MAIN-01 ✅），四个子系统代码均已落地并接线（runtime `cjpm build` 于 2026-10-15 在 cjc 1.1.3 下通过）；**缺口集中在验证侧**：无 fixtures 等价校验、无运行时冒烟（L2）、无端到端验收（L3）

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：仓颉 → `cangjie-coder`；前端（TS/Vue）→ `web-coder` / `fullstack-codegen`。
- **二次开发底座优先（迭代 runtime / uctoo 时强制）**：
  1. 规范源先加载 `uctoo-dev-manual`，按事读 `docs/uctoo-v4/*.md`（接口 → `uctoo-v4-api-specification`；表/字段 → `uctoo-database-design-specification`；CRUD → `uctoo-v4-module-development` + `uctoo-v4-orm-specification`；权限 → `user-permission-system` / `row-level-permission-system`）。
  2. 脚手架优先确定性工具：`loaddbinfo` → `plugingen`（**功能拓展优先做成插件**，默认 L3 process 轨）／`crudgen`（**仅**补宿主 `src/app/` 公共基础设施）／`crudweb`（管理界面）；下线用对称的 `pluginuninstall`，禁止手删 `skills/{name}/`。
  3. 生成后必补：`sql/incremental/` 增量 DDL（新增须先论证复用不成立，铁律 9）+ 新宿主路由的 `permissions` / `role_has_permission` 登记（否则 403）。
  4. 只在生成物上做最小适配，不推倒重写。
- **大工程拆分态（铁律 15，本工程为多子系统主工程）**：
  1. 开工前先读 `SPECS_INDEX.md`：确认子系统 ID / `feature_name = {主}--{子系统ID}` / 契约摘要 / 上游依赖 / 本次跑到哪档验收。
  2. 每条任务标注「本子系统负责」与「不碰（移交/调用上游）」；跨子系统动作写成"调用上游契约接口"或"等下游消费"，不许写成"顺手也改一下 X"。
  3. 跨子系统接口改动**成对成条**：提供方侧 + 消费方侧各一条，同轮完成。
  4. 契约先行：minor/major 写明契约条目编号；major 必须双侧同轮。
  5. 验收必须带跨边界冒烟（≥3 条主干 + 1 条异常）。
  6. 禁止跨界手写：不许直连其他子系统私有表/私有目录。
- **编译约束**：AI 不运行 `cjpm build`；编译、类型检查、lint 由人工在独立 cmd 执行并回传结果。
- **架构硬约束（本工程特有）**：宿主 `src/app/` 内**不得新增任何文档格式解析代码**；新增格式支持 = 新增/安装解析插件。

---

## 任务总览

| 编号 | 任务 | 关联需求(spec §) | 关联设计(design §) | 归属 | 状态 | 预计产出 |
|---|---|---|---|---|---|---|
| **T-MAIN-01** | 冻结 `DocumentParser` / `ParseRequest` / `ParseResult` / `ParserDescriptor` / `FilePart` 契约 | §6.5-6.8 | §4.1 | 主工程 | [x] | 2026-10-16 已冻结：`host-attach-core/contract.md` v1（对齐实现）+ SPECS_INDEX §3 IF-01~04/06/07 转「已冻结」 |
| **T-MAIN-02** | 冻结 WebMCP content 块 wire 契约（IF-05）与留痕契约（IF-06） | §6.1-6.4 | §3.2 | 主工程 | [x] | 已落地（P0），回写契约表 |
| **T-MAIN-03** | 建立 4 个子系统 SDD 工程目录并产出 `spec.md` / `design.md` / `contract.md` / `tasks.md` | §5 全章 | §5.3 | 主工程 | [x] | 4 个目录已建，spec + contract + tasks + **design 均已产出**（design 于 2026-10-16 按「实现即现状 + 差距」反推补齐） |
| **T-MAIN-04** | 主工程 SPECS_INDEX 建账（§2 登记表 / §3 接口表 / §4 DAG / §6 变更影响面） | — | §5.4 | 主工程 | [x] | `SPECS_INDEX.md` v1.1 |
| **T-MAIN-05** | 协调 S0→S1：宿主内核开工前契约已冻结，且下游三个子系统已读契约 | §5.3.1 | §6 S0/S1 | 主工程 | [x] | 契约已于 2026-10-16 冻结。**流程偏差登记**：实现先于冻结落地（代码 10-15 已编译通过），已按实现反推冻结，见 SPECS_INDEX §8 |
| **T-MAIN-06** | 协调 S2：存量抽取器搬迁为 L2 插件，组织 fixtures 等价校验 | §4.5.5 | §2.1 | 主工程 + `doc-parser-plugins` | [~] | **搬迁已完成**（`src/app/services/multimodal/` 已空，抽取器迁至 `src/plugin/multimodal/builtin/` 并包装注册）；**fixtures 等价校验未做**（无 fixtures 集与等价报告） |
| **T-MAIN-07** | 协调 S3/S5 并行推进，处理二者对 `host-attach-core` 的契约依赖 | §5.2/§5.4 | §6 S3/S5 | 主工程 | [~] | 二者均按契约推进、无私有目录直连；**偏差**：`attachment-persistence` 实际走 `AttachmentSummary` 直传落库，IF-07a 事件已发布但无订阅者（见 SPECS_INDEX §7） |
| **T-MAIN-08** | 组织 L2 跨子系统集成冒烟（3 主干 + 1 异常） | §5 全章 | §5 §5 | 主工程 | [ ] | L2 冒烟报告（**当前仅编译通过，无任何运行时实测**） |
| **T-MAIN-09** | 组织 L3 主工程端到端验收（AC1~AC8） | §5 全章 | §8 | 主工程 | [ ] | 主工程 `test-report.md` |
| **T-MAIN-10** | 子系统闸门回执后 ≤1 闸口周期同步 SPECS_INDEX（每子系统一次） | — | SKILL 铁律 15 | 主工程 | [~] | 2026-10-16 已同步一次（§2/§3/§7/§8）；后续每子系统闸门回执继续触发 |
| **T-MAIN-11** | 归档 v1 文档、清理 `src/app/services/multimodal/` 待迁出标记 | 附录 A | §2.1 | 主工程 | [x] | `archive/sdd-v1-legacy.md`；`src/app/services/multimodal/` **已清空**（空目录 git 不跟踪，可 `rmdir`） |
| **T-MAIN-12** | 主工程终验：三份文档与实现一致性复核（无漂移） | — | — | 主工程 | [ ] | 一致性复核表 |

---

## 任务依赖关系图

```
T-MAIN-02 ✅ ──┐
               ├─→ T-MAIN-01 ✅ ─→ T-MAIN-03 [~] ─→ T-MAIN-05 ✅ ─→ T-MAIN-06 [~] ─┐
T-MAIN-04 ✅ ──┘                                                                    ├─→ T-MAIN-08 ─→ T-MAIN-09 ─→ T-MAIN-12
T-MAIN-11 ✅                                                      T-MAIN-07 [~] ───┘
                                                                       ↓
                                                              T-MAIN-10 [~]（贯穿，每子系统闸门后触发）
```

- `T-MAIN-01`（契约冻结）是全局前置：**已于 2026-10-16 完成** ✅，下游闸口放行。
  - ⚠️ 流程偏差：本工程实际是「实现先行（10-15 编译通过）→ 契约后冻结（10-16）」，与「先冻结后 code」的正序相反。已在 SPECS_INDEX §8 留痕；本文档按现状据实记录。
- `T-MAIN-06` / `T-MAIN-07` 可并行（分别对应不同子系统）。
- `T-MAIN-10` 是贯穿性维护动作，每有一次子系统闸门回执就触发一次。
- **当前真正的瓶颈不在编码，而在验证**：T-MAIN-06 的 fixtures 等价校验、T-MAIN-08 的 L2 冒烟、T-MAIN-09 的 L3 验收**均未执行**，代码只经过编译，未经运行。

---

## 任务详细说明（按编号展开）

### T-MAIN-01 冻结解析契约（最高优先级）

- **目标**：spec §6.5-6.8 的 `ParseRequest` / `ParseResult` / `ParserDescriptor` / `FilePart` 落到可实现的契约文本。
- **输入**：`spec.md` §6、`design.md` §4.1、`research-doc-parser-ecosystem.md` §6 决策。
- **步骤**：
  1. 在 `host-attach-core` 子系统 `contract.md` 写出 SPI 的方法签名、错误约定、幂等性、超时约定。
  2. 在 `doc-parser-plugins` 子系统 `contract.md` 写出插件侧实现义务（无状态、不直连 DB、stdout 独占等）。
  3. 两侧交叉评审：确认「宿主不依赖插件实现」「插件不依赖宿主私有模块」双向成立。
  4. 主工程闸口 confirm 后标记「已冻结」，回写 `SPECS_INDEX.md` §3（IF-01~IF-03）。
- **产出物**：两个子系统的 `contract.md`（v1）+ SPECS_INDEX §3 状态改为「已冻结」。
- **验收**：任何一方按契约独立开发，联调时无需改契约。
- **风险**：契约未冻结就开工 = RISK-A1 漂移，按 P0 计。

### T-MAIN-02 冻结 WebMCP wire 契约与留痕契约

- **状态**：已完成（P0 已落地），本轮只需回写契约表。
- **产出物**：`SPECS_INDEX.md` §3 的 IF-05（已冻结）、IF-06（草案→已冻结）。
- **验收**：`image_url` 块形状与 OpenTiny 官方契约一致（AC6）。

### T-MAIN-03 建立 4 个子系统 SDD 工程

- **目标**：把主工程需求拆到 4 个可独立验收的子系统工程。
- **步骤**：
  1. 建目录 `specs/multimodal-native-chat--{ID}/`，ID 取 `host-attach-core` / `doc-parser-plugins` / `web-multimodal` / `attachment-persistence`。
  2. 各写 `spec.md`（6 节模板 + EARS）、`design.md`（内部架构，不重复主工程）、`contract.md`（集成契约）、`tasks.md`（≤40 条）。
  3. 各子系统独立 `feature_name`、独立六步、独立闸口。
- **产出物**：4 个目录 × 4 份文档。
- **验收**：每子系统 ≥3 条可独立验收任务；双向接口数 = 0。
- **风险**：子系统之间出现 ≥5 个双向接口 ⇒ 判定切错边界，合并重切。

### T-MAIN-04 主工程 SPECS_INDEX 建账

- **状态**：已完成（v1.0），后续按 T-MAIN-10 持续同步。

### T-MAIN-05 协调 S0→S1

- **目标**：`host-attach-core` 进 code 步前，契约已冻结且三个下游已读契约。
- **验收**：三个下游子系统 `tasks.md` 的「开发规范」段均写明已读 `SPECS_INDEX.md` 与上游契约版本。

### T-MAIN-06 协调存量抽取器搬迁（S2）

- **目标**：`src/app/services/multimodal/{pdf_text,office_text,zip_lite,xml_text}.cj` 迁出宿主为 L2 轨插件，解析结果等价。
- **步骤**：
  1. 组织 fixtures 集（PDF 文本型 / DOCX / PPTX / 文本族 / 损坏文件 / 加密文件 各 ≥1）。
  2. 搬迁**前**用宿主内实现跑一遍，留存基线文本块划分与 `source` 标注。
  3. 搬迁**后**用插件跑同一 fixtures，逐项比对。
- **验收**：全部 fixtures 结果等价（差异需逐条说明并经主工程确认）。
- **风险**：RISK-A4 搬迁回归。

### T-MAIN-07 协调 S3/S5 并行

- **目标**：`web-multimodal` 与 `attachment-persistence` 并行推进不互相阻塞。
- **验收**：二者对 `host-attach-core` 的依赖均只走 IF-04 / IF-07 契约，无私有目录直连。

### T-MAIN-08 组织 L2 集成冒烟

- **目标**：按 `SPECS_INDEX.md` §5 的 3 主干 + 1 异常清单执行。
- **验收**：全绿；任一条失败 → 归因到具体契约条目，禁止笼统写"实现与文档略有差异"。

### T-MAIN-09 组织 L3 端到端验收（AC1~AC8）

- **目标**：全量子系统在宿主上跑起，AC1~AC8 全绿。
- **验收**：主工程 `test-report.md`；AC4（新增格式不改宿主）与 AC5（生态复用）必须有实际演示证据，不接受"设计上支持"。

### T-MAIN-10 SPECS_INDEX 同步（贯穿）

- **触发**：任一子系统闸门回执。
- **动作**：更新 §2 status / §3 契约状态 / §6 变更影响面 / §8 修订记录。
- **验收**：≤1 个闸口周期内完成。

### T-MAIN-11 归档 v1 文档

- **状态**：已完成 —— `sdd.md` → `archive/sdd-v1-legacy.md`（带归档说明头）；`spec.md` / `design.md` 升 v2。
- **遗留**：`src/app/services/multimodal/` 目录标记「待迁出」，由 `doc-parser-plugins` 的 S2 阶段清空。

### T-MAIN-12 主工程终验一致性复核

- **目标**：spec / design / tasks 三份文档与最终实现一致，无漂移。
- **验收**：逐条比对主工程 §5 各验收条件与 `test-report.md` 结论。

---

## 需求覆盖追踪矩阵

| spec 条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §5.1 图片上传与理解 | T-MAIN-02 + `web-multimodal` + `host-attach-core` | 全覆盖 | 已部分落地，收口在子系统 |
| §5.2 文档接收与消费 | `host-attach-core` 全部任务 | 全覆盖 | 主工程只做契约与协调 |
| §5.3 解析能力外置与装配 | T-MAIN-01 + `doc-parser-plugins` | 全覆盖 | v2 新增核心 |
| §5.4 模型能力门控 | `web-multimodal` + `host-attach-core` | 全覆盖 | |
| §5.5 向后兼容与并行共存 | T-MAIN-06（等价校验）+ 各子系统回归 | 全覆盖 | |
| §4.1 性能 | `host-attach-core` + `doc-parser-plugins` | 全覆盖 | 10s 超时由宿主强制 |
| §4.2 可靠性 | `host-attach-core`（降级链） | 全覆盖 | |
| §4.3 安全性 | `host-attach-core`（最小权限）+ `doc-parser-plugins`（能力声明） | 全覆盖 | |
| §4.4 可维护性 | `host-attach-core`（可观测）+ T-MAIN-06 | 全覆盖 | |
| §4.5 兼容性 | T-MAIN-06 + T-MAIN-09 | 全覆盖 | 迁移等价是硬指标 |
| §6 数据约束 | T-MAIN-01 | 全覆盖 | 契约即数据约束 |
| AC1~AC8 | T-MAIN-09 | 未开始 | 终验执行 |

---

## 验收检查清单（主工程终验）

- [x] 契约已冻结（T-MAIN-01），SPECS_INDEX §3 IF-01/02/03/04/06/07 均为「已冻结」
- [x] 编译通过（人工确认）：runtime `cjpm build success`（cjc 1.1.3，2026-10-15，1 warning）
- [x] `src/app/services/multimodal/` 已清空（宿主 `src/app/` 内无格式解析实现）
- [x] 各子系统 `design.md` 补齐（4 份，2026-10-16 已写「实现即现状 + 差距」）
- [ ] `SPECS_INDEX.md` §2 四个子系统全部 `status=done`（当前均为 `code`）
- [ ] 四个子系统闸口均 `confirm`，无 `abandon`（当前均「待 confirm」）
- [ ] L2 跨子系统冒烟（3 主干 + 1 异常）全绿 —— **未执行**
- [ ] L3 端到端 AC1~AC8 全绿，AC4/AC5 有实际演示证据 —— **未执行**
- [ ] T-MAIN-06 fixtures 等价校验（搬迁回归）—— **未执行**
- [ ] §6 变更影响面无未闭环的破坏性契约变更
- [~] `src/plugin/multimodal/builtin/` 零依赖参考实现仍在宿主源码树内（有意偏差，终态应移除；见 SPECS_INDEX §7）
- [ ] spec / design / tasks / SPECS_INDEX 四份文档与最终实现一致（无漂移）

---

## 修订记录

| 日期 | 轮次 | 触发来源 | 改动摘要 | 验证结果 |
|---|---|---|---|---|
| 2026-10-14 | R1 | 初始需求 | v1 任务拆分（P0 图片 / P1 文档 / P2 稳健与持久化，T-MC-001~021） | P0 全链路落地待联调；P1 除 PDF/DOCX/PPTX 真抽取外落地 |
| 2026-10-15 | R2 | 解除解析阻塞 | 自研 `zip_lite` + 复用 compress4cj，补齐 PDF/DOCX/PPTX 抽取；补入口限流与丢弃留痕 | 未联调（待人工编译） |
| 2026-10-15 | R3 | **用户架构调整指令** | 文档解析全部外置到 L2/L3 插件轨；宿主只做接收/消费/提交；图片链路保持宿主内；拆为 4 个子系统 SDD 工程；`spec.md`/`design.md` 升 v2，`sdd.md` 归档，新增 `SPECS_INDEX.md` 与 `research-doc-parser-ecosystem.md` | 文档层完成；代码层（`src/app/services/multimodal/`）仍为 v1 形态，标记「待迁出」 |
| 2026-10-16 | R4 | runtime `cjpm build` 通过（cjc 1.1.3）+ 用户要求盘点进度 | **按代码真实状态回写全表状态**：① T-MAIN-01 ✅ 契约冻结（`host-attach-core/contract.md` 对齐实现后冻结，修正「无 `supports()`」等三处草案偏差）；② T-MAIN-05 ✅；③ T-MAIN-03/06/07/10 置 [~]（design.md 未产出 / fixtures 等价校验未做 / IF-07a 无订阅者）；④ T-MAIN-11 ✅（旧目录已清空）；⑤ 同步 `SPECS_INDEX.md` 至 v1.1（§2 status→code、§3 契约→已冻结、§7 三条偏差、§8 留痕）；⑥ 同步 `host-attach-core/tasks.md`（T-HAC-01~07/11 置 [x]，T-HAC-12 置 [~]） | 编译通过；**验证侧全空**：无运行时冒烟、无等价校验、无 L3 验收 |
