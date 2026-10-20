# 任务规划：`doc-parser-plugins`（文档解析插件轨）

> 关联需求：本目录 `spec.md` v1 ｜ 关联契约：本目录 `contract.md` v1（草案）
> 主工程账本：`specs/multimodal-native-chat/SPECS_INDEX.md`（开工前必读 §2/§3/§4）
> 调研依据：`specs/multimodal-native-chat/research-doc-parser-ecosystem.md`
> 阶段：task ｜ 日期：2026-10-15 ｜ 状态：草稿

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：仓颉 → `cangjie-coder`；插件内脚本（Python/JS）按各自语言规范。
- **大工程拆分态（铁律 15）**：
  1. 已读主工程 `SPECS_INDEX.md`：本子系统 ID = `doc-parser-plugins`，上游 = `host-attach-core` v1，验收档位 L1+L2+L3。
  2. **上游 `host-attach-core` 契约未冻结前不得进 code 步**。
  3. 与上游的接口改动成对成条（T-HAC-02/03/04 ↔ 本侧 T-DPP-02/03）。
  4. 禁止 import 宿主私有模块、禁止直连 DB。
  5. 验收含 ≥3 条跨边界主干 + 1 条异常（contract §6）。
- **二次开发底座优先**：插件脚手架走 `plugingen`（默认 L3 process 轨；需内嵌 sync 轨显式 `--mode sync`）；下线用 `pluginuninstall`，禁止手删 `skills/{name}/`。
- **复用优先**：生态既有实现能复用就复用，不自研重复能力（主工程 D3）。
- **编译约束**：AI 不运行 `cjpm build`，由人工在独立 cmd 执行并回传。

## 任务总览

| 编号 | 任务 | 关联需求(spec §) | 负责范围 | 状态 | 预计产出 |
|---|---|---|---|---|---|
| T-DPP-01 | 契约交叉评审并冻结（与 `host-attach-core`） | §6 全章 | 本子系统 + 上游 | [ ] | contract.md 转「已冻结」 |
| T-DPP-02 | 用 `plugingen` 生成 L2 解析器插件骨架 | §5.1 | 本子系统 | [ ] | `skills/doc-parser-office/` 骨架 |
| T-DPP-03 | 搬迁存量抽取器为 L2 插件（PDF/DOCX/PPTX/文本族） | §5.1.1 | 本子系统（**与 T-HAC-07 同轮**） | [ ] | 插件实现 + 注册 |
| T-DPP-04 | 组织 fixtures 集并做搬迁前后等价校验 | §5.1.1 / §4.5.2 | 本子系统 + 主工程 | [ ] | fixtures + 等价报告 |
| T-DPP-05 | L3 轨承载生态解析器（Python 实现）可行性验证 | §5.2.1 | 本子系统 | [ ] | Spike 结论（含 Windows 编译） |
| T-DPP-06 | 接入生态解析器（MarkItDown 或同类）为 L3 插件 | §5.2.1 / §5.2.1.2 | 本子系统 | [ ] | L3 插件 + 注册 |
| T-DPP-07 | 实现 `SkillAdapter`（标准技能 → `DocumentParser`） | §5.3.1 | 本子系统 | [ ] | 适配层 |
| T-DPP-08 | 第三方技能接入流程：源码评审 + 沙箱试跑 + 登记 | §5.3.1.3 / §4.3.4 | 本子系统 | [ ] | 评审清单 + 试跑记录 |
| T-DPP-09 | 插件 `capabilities` 声明与安装期人工确认 | §4.3.2 | 本子系统 + 上游 | [ ] | 声明与阻断逻辑 |
| T-DPP-10 | 多解析器优先级与故障回落实测 | §5.4.1.1 | 本子系统 + 上游 | [ ] | 实测记录 |
| T-DPP-11 | 环境不适用检测（无 Python/Node 时标记跳过） | §5.2.2.1 | 本子系统 | [ ] | 环境探测逻辑 |
| T-DPP-12 | L1 自测（L2 + L3 + 适配器三条路径） | §5 全章 | 本子系统 | [ ] | 单测/冒烟 |
| T-DPP-13 | L2 集成冒烟（contract §6 SC-11~SC-15） | contract §6 | 本子系统 + 上游 | [ ] | L2 报告 |

## 任务依赖关系图

```
T-DPP-01 ─→ T-DPP-02 ─→ T-DPP-03 ─→ T-DPP-04 ─→ T-DPP-10 ─→ T-DPP-12 ─→ T-DPP-13
                                   │
                                   └─→ T-DPP-05 ─→ T-DPP-06 ─┘
                                                    └─→ T-DPP-11
            T-DPP-07 ─→ T-DPP-08 ────────────────────────────┘
            T-DPP-09
```

- T-DPP-01 全局前置；T-DPP-03 与上游 T-HAC-07 **同轮**（删宿主 + 建插件）。
- T-DPP-05（L3 可行性 Spike）是 T-DPP-06 的前置；失败则 T-DPP-06 降级为「仅 L2」。
- T-DPP-07/08/09 可与主链路并行。

## 任务详细说明（按编号展开）

### T-DPP-01 契约交叉评审并冻结
- **目标**：contract.md 转已冻结。
- **步骤**：与 `host-attach-core` 逐条对齐 `ParseRequest` / `ParseResult` / `FilePart` / `ParserDescriptor`；确认双向无反向依赖。
- **验收**：双方按契约独立开发，联调无需改契约。
- **风险**：未冻结就开工 = RISK-A1（P0）。

### T-DPP-02 用 `plugingen` 生成 L2 插件骨架
- **目标**：脚手架走确定性工具，不手写。
- **步骤**：`cjpm run --skip-build --name <包名> --run-args "plugingen ..."`（L3 默认；本任务要 L2/sync 形态需显式 `--mode sync` 或按工具支持的 dylib 形态）；生成后在产物上最小适配。
- **产出物**：`skills/doc-parser-office/` 骨架（plugin.yaml + 源码入口）。
- **验收**：骨架可编译、可注册。
- **风险**：`plugingen` 的 `--mode` 语义（sync / process）需先查工具文档确认，禁止凭印象（铁律 8）。

### T-DPP-03 搬迁存量抽取器为 L2 插件
- **目标**：v1 宿主内实现 → L2 插件，宿主侧清空。
- **步骤**：① 搬迁 `pdf_text.cj` / `office_text.cj` / `zip_lite.cj` / `xml_text.cj`；② 实现 `descriptor` / `supports` / `parse`；③ 注册到 `ParserRegistry`；④ 与 T-HAC-07 同轮提交。
- **验收**：fixtures 结果等价（T-DPP-04）；`grep -r "FlateDecode\|word/document.xml" src/` 命中 0。
- **风险**：RISK-A4 搬迁回归；空窗期（既删又没建）按 P0。

### T-DPP-04 fixtures 与等价校验
- **目标**：搬迁前后结果等价。
- **步骤**：① 建 fixtures（文本型 PDF / CID 中文 PDF / DOCX / PPTX / 文本族 / 损坏文件 / 加密文件 各 ≥1）；② **搬迁前**用宿主实现跑基线并留存；③ 搬迁后比对文本块划分与 `source` 标注。
- **验收**：全部等价或差异逐条说明并经主工程确认。

### T-DPP-05 L3 轨承载非仓颉解析器可行性验证（Spike）
- **目标**：确认 L3 轨能在目标环境承载 Python 解析器。
- **步骤**：① 复核 `docs/ref/cangjie-plugin-system-feasibility.md` 的 Spike-1（工具链）与 Spike-2（Windows stdio 编译）结论；② 跑一个 hello-world L3 插件；③ 跑一个最小 Python 解析脚本经 IPC 往返。
- **验收**：L3 进程插件可被拉起、调用、终止；往返时延记录。
- **风险**：Spike 不通过 → T-DPP-06 降级为「仅 L2 仓颉实现」，需回主工程 SPECS_INDEX §7 登记偏差。

### T-DPP-06 接入生态解析器为 L3 插件
- **目标**：复用成熟实现提升覆盖面与质量。
- **步骤**：① 选定生态实现（优先 Markdown 输出类，如 MarkItDown；或 MinerU 之类带 page/block 定位者）；② 包成 L3 插件并声明 `formats` / `priority`；③ 校验 License 与分发要求（`research` §7.2）。
- **验收**：CID 中文 PDF / 扫描件 / 复杂表格至少一类相对 L2 实现有可观测改善。
- **风险**：环境依赖（Python 3.10+）；耗时是否落在 10s 预算内需实测。

### T-DPP-07 实现 `SkillAdapter`
- **目标**：标准技能 → `DocumentParser`。
- **步骤**：① 解析 `SKILL.md` 元数据与 `scripts/` 入口；② 把附件字节以约定方式传给技能脚本（临时文件或 stdin，须声明 `capabilities`）；③ 把脚本输出转成 `FilePart`。
- **验收**：SC-15 通过。
- **风险**：需要落盘 → 触发 `needs_fs` 声明与人工确认（§4.3.2）。

### T-DPP-08 第三方技能接入流程
- **目标**：安全前置。
- **步骤**：① 源码评审清单；② 沙箱试跑；③ 登记结论与责任人。
- **验收**：每个接入的第三方技能都有评审记录与试跑记录。
- **风险**：技能市场明确声明「只做已知恶意模式扫描、不保证安全」⇒ 评审不可跳过。

### T-DPP-09 `capabilities` 声明与安装期确认
- **目标**：最小权限。
- **步骤**：① `ParserDescriptor.capabilities` 支持 `needs_fs` / `needs_net`；② 安装/启用环节对非空声明阻断并提示。
- **验收**：声明 `needs_fs` 的插件在未确认前不可用。

### T-DPP-10 多解析器优先级与故障回落实测
- **目标**：SC-13。
- **验收**：首选失败自动回落次优；同优先级冲突按 `parserId` 稳定裁决并记 warn。

### T-DPP-11 环境不适用检测
- **目标**：SC-12 的异常分支。
- **验收**：无 Python/Node 时插件注册标记「环境不适用」，宿主跳过且不报错。

### T-DPP-12 L1 自测
- **验收**：三条路径（L2 / L3 / SkillAdapter）各有覆盖；P0 清零。

### T-DPP-13 L2 集成冒烟
- **验收**：SC-11~SC-15 全绿；失败归因到具体契约条目。

## 需求覆盖追踪矩阵

| spec 条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §5.1.1 搬迁等价 / 零外部依赖 / 宿主清空 | T-DPP-03、T-DPP-04 | 全覆盖 | 与 T-HAC-07 同轮 |
| §5.2.1 多语言承载 / 覆盖面扩展 / 故障隔离 | T-DPP-05、T-DPP-06 | 全覆盖 | 依赖 Spike |
| §5.3.1 标准技能装配 / 不改写 / 安全前置 | T-DPP-07、T-DPP-08 | 全覆盖 | |
| §5.4.1 优先级共存 / 禁反向依赖 | T-DPP-10、T-DPP-01 | 全覆盖 | |
| §4.1 性能（遵守 limits） | T-DPP-03、T-DPP-06 | 全覆盖 | |
| §4.2 可靠性（无状态 / 自捕获 / 崩溃隔离） | T-DPP-03、T-DPP-06、T-DPP-11 | 全覆盖 | |
| §4.3 安全性（最小权限 / capabilities / stdout / 评审） | T-DPP-07、T-DPP-08、T-DPP-09 | 全覆盖 | |
| §4.4 可维护性（parserId/version / plugingen / 热插拔） | T-DPP-02、T-DPP-03 | 全覆盖 | |
| §4.5 兼容性（迁移等价 / 环境可用） | T-DPP-04、T-DPP-11 | 全覆盖 | |
| §6 数据约束 | T-DPP-01 | 全覆盖 | 契约即约束 |

## 验收检查清单（终验）

- [ ] 契约已冻结，插件实现与 `contract.md` 无偏差
- [ ] 宿主内格式解析代码已清零（与 T-HAC-07 联合确认）
- [ ] fixtures 等价校验通过
- [ ] L2 插件（仓颉，零外部依赖）可用
- [ ] L3 插件（生态实现）可用，或已登记 Spike 失败偏差
- [ ] `SkillAdapter` 至少装配 1 个真实技能
- [ ] 第三方技能均有评审 + 试跑记录
- [ ] 崩溃隔离实测通过（kill 子进程不拖垮宿主）
- [ ] 未新增任何表/列（铁律 9 自检 ✓）
- [ ] 编译 / 类型检查通过（人工确认）
- [ ] L2 冒烟（SC-11~SC-15）全绿

## 修订记录

| 日期 | 轮次 | 触发来源 | 改动摘要 | 验证结果 |
|---|---|---|---|---|
| 2026-10-15 | R1 | 主工程 v2 架构调整 | 新建子系统 spec/contract/tasks；契约 v1 草案；明确存量抽取器搬迁与生态接入两条线 | 待主工程闸口 confirm |
