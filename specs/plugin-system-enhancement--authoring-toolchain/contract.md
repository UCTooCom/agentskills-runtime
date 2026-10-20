# 子系统集成契约（authoring-toolchain）

> 模板：`templates/subsystem-contract-template.md`
> 产出阶段：`spec` / `design` 步（子系统的文档步产出，属该子系统工程内部）
> 被谁消费：主工程 `SPECS_INDEX.md` §3 集成契约汇总 + 下游子系统的 tasks.md / 编码步
> 铁律依据：**铁律 15**（大工程拆分：集成契约先定、先改契约再改实现）

> 契约是**承诺**，不是设计说明。本文件在子系统实现开工前冻结；
> **禁止**在实现里单边改动契约——要改就走 §5 的演进档位，双侧同轮完成。

## 文档信息

- 所属主工程：`plugin-system-enhancement`
- 子系统 ID：`authoring-toolchain`（稳定标识，跨轮次不变，改名等同于新建子系统）
- 子系统 `feature_name`：`plugin-system-enhancement--authoring-toolchain`（双连字符；与 `sdd_projects` 唯一键对齐）
- 契约版本：`v1`
- 冻结日期 / 冻结状态：**2026-10-19 / 草案**（主工程 SPECS_INDEX §3 中 IF-12 状态为「草案」，本子系统同步；转「已冻结」须由主工程闸口在同一次更新里完成）
- 上游依赖（已依赖的上游子系统 + 各自契约版本）：
  - `capability-governance` **v1** —— 取 IF-05（能力枚举与缺省策略）、IF-06（能力门禁判定）、IF-07（跨进程能力禁列表）
  - `version-guard` **v1** —— 取 IF-02（清单版本字段解析）
- 下游消费方（计划中的全部）：
  1. 主工程 L2 跨子系统集成验收（`SPECS_INDEX.md` §5 冒烟第 3 条）
  2. 主工程 L3 端到端验收（`SPECS_INDEX.md` §5.1 用例 1、用例 5 存量体检）
  3. CI / 准入门禁（离线调用，不依赖宿主运行态）
  4. 插件作者（人类，本地改完清单后自检）
  5. `lifecycle-observability` —— 仅消费本子系统输出的**存量清单体检报告数据**，不调用本子系统接口（防回退锚点 R-04）

---

## 1. 本子系统提供什么（能力清单）

> 全局账本口径：主工程 `SPECS_INDEX.md` §3 只登记 **IF-12「清单静态校验」** 一条外部接口；
> 本节 §1 的 IF-12.1~IF-12.4 是 IF-12 的**内部分解编号**（与 `SPECS_INDEX.md` §2「v1 / 4 接口 / 0 新表」对齐），
> 仅 IF-12.1 与 IF-12.4 对外可见，IF-12.2 是文件产物、IF-12.3 是本子系统内部与 `plugingen` 之间同进程协作用的进程内接口。
> 编号前缀一律走 IF-12，本子系统**不占用新的全局接口号**。

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| IF-12.1 | CLI（进程外命令行，随 release 二进制分发） | 可执行目标 `magic.plugin.tools.pluginvalidate`（`cjpm.toml` 新增段，镜像 `cjpm.toml:146-147`）；源码 `src/plugin/tools/pluginvalidate/pluginvalidate.cj`（对齐 `src/plugin/tools/plugingen/plugingen.cj`） | `main(args: Array<String>)` | `validate --path <插件目录> [--format text\|json] [--min-level error\|warn\|info] [--strict] [--skip <规则号前缀>]` | 校验报告（text 或 json）+ 进程退出码 `0` / `1` / `2` | 不新造错误码空间；以**规则编号**（`AT-<域>-<序号>`）+ 严重级 + 位置（文件:行）三元组表达诊断；`2` 表示输入不可用而非清单有错 | **只读幂等**：不写任何文件、不联网、不连 DB、不起宿主；对同一目录内容重复执行结果一致 | 对外主接口，CI 与作者均走此口 |
| IF-12.2 | 脚手架产物（文件落盘） | `skills/{name}/TESTING.md`；process 轨 `skills/{name}/src/test/smoke_test.cj` + `skills/{name}/cjpm.toml` 内 `[package.package-configuration."skill_{name}.test"] output-type = "executable"`；sync 轨 `skills/{name}/src/test/{name}_smoke_test.cj` + 宿主 `cjpm.toml` 内 `[package.package-configuration."magic.plugins.{name}.test"]` | `writeTestScaffold(...)` / `writeTestingDoc(...)`，由 `CrudPluginGenerator`（process 轨）与 `PluginGenerator`（sync 轨）内部调用 | 生成器入参（`--name` / `--mode` / 表清单） | 文件落盘 + 生成日志（`已生成: <路径>`，沿用 `CrudPluginGenerator.cj:198` 风格） | 与既有生成器一致：`println` 失败原因 + 返回 `false`；不抛异常、不半途留残文件 | **重生成幂等**：测试文件整体在 AutoCreateCode 保护区内，二次开发区保留（复用 `TemplateEngine.updateFileWithMarkers`，与 `CrudPluginGenerator.cj:194-197` 同构） | 产物是**离线纯函数级**最小测试，不依赖 DB/网络/宿主 |
| IF-12.3 | 进程内调用（构造注入） | `magic.plugin.validator.PluginManifestValidator` | `validate(dir: String, opts: ValidateOptions): ValidationReport`；规则以 `Array<ValidationRule>` 构造注入 | 插件目录路径 + 选项对象 | `ValidationReport` | 单条规则抛异常时降级为该规则 `skip`，不中断整体校验 | 幂等（纯函数，无副作用） | `plugingen` 生成末尾自校验与 IF-12.1 CLI **共用同一实现**，不各写一套 |
| IF-12.4 | 进程内调用 / CLI 输出 | `magic.plugin.validator.ValidationReport`（含 `Diagnostic{ruleId, level, location, message, hint}` 与 `Summary{errors, warns, infos, skipped}`） | `toText(): String` / `toJson(): String` | 报告对象 | text（人类可读，`规则号 [级] 位置: 消息 → 建议`）或 json（`{plugin, passed, summary, diagnostics[]}`） | json 结构变更属 **minor**，须同步本表 | 幂等 | 供 CI 机器消费；json schema 首版不含 schema 版本号，后续追加 `schemaVersion` 属 minor |

- **类型口径说明**：本子系统是**离线工具链**，不提供 HTTP 接口、不直连库表、不走 L3 跨轨 RPC，故四种类型均不属于模板列出的 HTTP/库表/L3/进程内四类之一；其中 IF-12.3 / IF-12.4 属「进程内调用」，求值方式为**构造注入**（规则数组注入 `PluginManifestValidator` 构造器），便于下游测试替身（注入空规则数组即可测框架本身）。
- **错误约定**：
  - 本子系统的诊断编号 `AT-<域>-<序号>`（如 `AT-RT-01`）是**工具链私有诊断编号**，不进入宿主 HTTP API 错误码空间，也不与 `PluginError`（`plugin_config.cj` / `plugin_loader.cj`）混用。
  - domain 取值：`IO`（输入输出）/ `CORE`（清单结构与必填）/ `MODE`（加载轨匹配）/ `EXE`（可执行文件存在性）/ `RT`（HTTP 路由）/ `CAP`（能力声明）/ `VER`（版本声明）/ `DOC`（文档与脚手架）。
  - 退出码语义：`0` = 无 error 级诊断；`1` = 存在 ≥1 条 error 级诊断；`2` = 输入不可用（目录不存在 / `plugin.yaml` 缺失 / YAML 不可解析 / 参数非法）。`2` 优先于 `1`。
- **幂等性**：写类接口在标准意义上不适用（本子系统**无任何写接口**）；IF-12.1 的重试依据是「只读 + 同输入同输出」，IF-12.2 的重生成依据是「保护区内外划分 + 幂等键 = `skills/{name}` 路径」。

## 2. 数据契约

> **铁律 9 复用优先结论：本子系统 0 新表、0 新列、0 新宿主路由。**

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| （无）**不读写任何数据库表** | 不读不写 | 不暴露 | — | 不适用（无任何数据行读写） | 不适用 |

补充约束：

1. **输入面是文件系统，不是数据库**：本子系统只读 `skills/{name}/` 下的 `plugin.yaml`、`cjpm.toml`、`src/**`；不读 `db_info`、不读 `agent_skills`、不读 `config/plugins.yaml` 的 `plugins:` 数组（`config/plugins.yaml` 的清单条目校验由 `plugin_config_parser.cj:47` 在宿主侧承担，本子系统**不改**它）。
2. **写面**：仅 `plugingen` 既有的 `skills/**` 落点，新增文件只有 `TESTING.md` 与测试源码，不扩散到 `src/plugins/`、不碰 `config/plugins.yaml`。
3. **对外屏蔽**：不向任何下游暴露插件作者的 `config:` 段内容（`env`、`secret` 相关字段），报告里对敏感键值一律脱敏为 `<redacted>`。
4. **复用不成立论证（为何不新建表）**：校验报告是一次性输出，生命周期等于一次进程执行，落表反而引入存储与清理成本；历史报告的保留需求（若有）由 CI 自身承担，不进本子系统。
5. **`version: 1.0.0` 字段**：生成器侧继续写出（现状 `CrudPluginGenerator.cj:156` / `PluginGenerator.cj:339`），**宿主侧的读取与消费缺口归 `version-guard`**，本子系统只做静态格式校验（R-VER-01），不做兼容性判定。

## 3. 依赖方向

- **我依赖的上游（有限名单，只允许这几条，禁止反向）**：
  1. `capability-governance v1` —— 取 IF-05（`PluginCapability` 枚举 + `CapabilityPolicy` 缺省策略）、IF-06（`CapabilityGate.check(pluginId, cap)` 判定）、IF-07（`HostUnsupportedCapabilities` 跨进程禁列表常量表）。契约版本对齐到 v1。
  2. `version-guard v1` —— 取 IF-02（`PluginManifestEntry.pluginApi` / `hostVersionRange` 字段解析）。契约版本对齐到 v1。
- **我不依赖谁**：
  - 不依赖 `capability-governance` 的 **handler 内部实现**（如 `CordisHostServices` 各 handler 的具体处理），只依赖其 §1 的 IF-05 枚举常量、IF-06 判定函数签名、IF-07 常量表；不 import 其私有包。
  - 不依赖 `version-guard` 的 **IF-03 加载前拒绝**（`VersionGuard.check(entry)`）：本子系统只解析并报告版本字段的**存在性与格式**，**不做拒绝决策**，也**不调用** `VersionGuard.check`。理由：拒绝是加载期行为，静态工具给出「会被拒」的判定会与宿主产生第二处事实来源。
  - 不依赖 `capability-handshake` 的 IF-09（宣告比对）：那是运行期行为。
  - 不依赖 `dependency-graph` / `lifecycle-observability` 的任何实现（二者与本子系统无接口边）。
  - 不修改宿主清单解析实现（`plugin_config.cj:122-208`）与加载器（`plugin_loader.cj`）：二者分别属 `version-guard` 与宿主，本子系统**只读式复用**其解析函数作为交叉校验 oracle（见 §1 IF-12.3 与 design §3.2），不改动其一行代码。
- **禁止成环**：本子系统 → 上游为单向；上游不得反向 import 本子系统。若 `capability-governance` 需要本子系统能力，必须回本文改依赖方向并过闸口。

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| 加载前版本协商与拒绝加载（按 `pluginApi` / `hostVersionRange` 判定） | `version-guard`（IF-03） | 本子系统只报字段缺失/格式非法（warn 级），明确提示「兼容性由 version-guard 在加载前判定」 |
| 运行时能力门禁（请求期 allow/deny） | `capability-governance`（IF-06） | 本子系统只在静态期按 IF-05/IF-07 检查声明合法性 |
| L3 启动能力宣告握手与拒绝挂载 | `capability-handshake`（IF-08/IF-09） | 运行期行为，静态工具不得越位 |
| 依赖拓扑排序替代 `order` | `dependency-graph`（IF-10） | 无关 |
| 崩溃退避 / 计数 / 风暴熔断 | `lifecycle-observability`（IF-11） | 无关 |
| `dylib` 轨接通 | 需单独立项（`SPECS_INDEX.md` §7 R-01） | 本子系统对 `mode: dylib` 只报 `AT-MODE-02` 提示「该轨当前无落点」，不复活该轨 |
| 插件安装 / 卸载 / 目录删除 | 既有 `pluginuninstall`（`src/plugin/tools/pluginuninstall/pluginuninstall.cj`） | 本子系统不改它；其「未在 `cjpm.toml` 注册 executable」与「`--mode` 行级字符串匹配（`pluginuninstall.cj:295-317`）仅 warn」两处缺口，建议由主工程在 §7 登记为 **R-09**，不在本子系统修 |
| **RSI 常驻自进化循环：每 N 轮后台自评触发器**、LRT 五环节编排 | 既有工程 `specs/RSI` | **明确不纳入**。报告 §9 第 8 条整条移交 `specs/RSI`；本子系统**不提供每 N 轮后台自评触发器与 LRT 五环节编排**，也不提供任何定时/常驻进程 |
| 插件的**运行时/端到端**测试执行（起宿主、连 DB、跑 HTTP） | 不归属任何已登记子系统 | 脚手架只提供离线纯函数级最小测试；需要 DB 的测试由作者自选手段 |
| 对外 HTTP 接口 / 管理界面 | 不归属任何已登记子系统 | 本子系统是 CLI + 库，无 HTTP 面 |
| 数据库表 / 列 | — | **0 新表 0 新列**（铁律 9） |
| 修改宿主清单解析 / 加载器 / 握手实现 | `version-guard` / `capability-handshake` / 宿主 | 本子系统只做生成器侧与离线静态校验侧 |
| `plugingen --validate` 选项 | 本子系统（主动不做） | 校验能力落在独立 `plugin validate` 命令（IF-12.1），`plugingen` 侧只做**生成末尾进程内自校验**（默认开，`--no-selfcheck` 关）；不新增 `--validate` 选项，避免一个能力两个入口 |

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动；在子系统 tasks.md 修订记录留痕即可 |
| 向后兼容（minor） | 只增接口/只增可选字段，不改既有语义 | 改本文 + 主工程 §3 汇总；下游不必同步改。例：新增 `AT-RT-04` 规则、json 报告加 `schemaVersion` 字段 |
| 破坏性（major） | 改路径/改字段语义/删接口/改权限口径 | **必须双侧同轮**：提供方与全量消费方在同一轮 code 里改完；主工程 SPECS_INDEX §6 登记；单侧先改 = P0 缺陷。例：退出码语义变更、撤销 `AT-*` 规则号、把 `validate` 子命令改名 |

- 演进一律「**先改契约 → 再改实现**」，顺序反了按铁律 15 打回。
- 契约冻结后到实现完成之间的任何偏差，在子系统 `test-report.md` 里必须归因到具体契约条目，禁止笼统写"实现与文档略有差异"。
- **上游未就位的降级策略**（写死在契约里，避免实现期各写一套）：若 `capability-governance` 未达 `code`（IF-05 枚举不可引用），则 `AT-CAP-*` 规则置为 **skipped** 并在报告 summary 中显式列出 `skipped` 计数，**不得**以「通过」蒙混；`plugin validate` 退出码仍按其余规则计算。

## 6. 集成验收（本子系统对下游的交付承诺）

> **上游就位前提**：依赖 `capability-governance` 处于 **done**、且不晚于本文冻结日；依赖 `version-guard` 至少达 `test`。
> 若上游未就位，S-02 / S-03 按 §5 降级策略报 `skipped`，S-01 / S-04 / S-05 / S-06 不受影响。

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| S-01 | **跨子系统主干**：`plugingen --name demo --db uctoo --table entity`（process 轨）生成完毕 → 立即 `plugin validate --path skills/demo` | 命令行 + 退出码断言 | —（本子系统自闭环） | 退出码 `0`，报告中 `errors=0`；`skills/demo/TESTING.md` 与 `skills/demo/src/test/smoke_test.cj` 存在 |
| S-02 | **跨 `capability-governance`**：在 S-01 生成的 `plugin.yaml` 里手工把 `capabilities` 改成一项非枚举值 → 再跑 `plugin validate` | 命令行 + JSON 报告断言 | capability-governance（IF-05/IF-07） | 报出 `AT-CAP-01`（枚举非法）或 `AT-CAP-02`（跨进程禁列表命中），退出码 `1`，且**不**报成加载期错误码 |
| S-03 | **跨 `version-guard`**：删掉 `pluginApi` 字段 → 跑 `plugin validate`；再写成 `pluginApi: "abc"` → 再跑 | 命令行 + JSON 报告断言 | version-guard（IF-02） | 前者报 `AT-VER-01` 的 **warn**（缺失提示，退出码 `0`）；后者报 **error**（格式非法，退出码 `1`）；两次报告均**不出现**「拒绝加载」类措辞 |
| S-04 | **异常 / 边界**：`plugin validate --path skills/not-exist`；以及对一个 `command` 指向不存在文件的 process 插件清单 | 命令行 + 进程行为观察 | — | 前者退出码 `2` + `AT-IO-01`，不抛栈、不创建任何文件；后者报 `AT-EXE-01`（error，退出码 `1`）。**两种情况下进程均正常退出，无残留、无挂起** |
| S-05 | **存量防回退（R-04）**：对 `skills/` 下既有 51 个 skill 插件批量跑 `--format json` | 批量脚本 + JSON 汇总 | — | 输出一份全量 json 报告；**过程中不修改、不删除任何被扫描文件**（read-only 契约）；报告可直接作为主工程 §5.1 用例 5 的输入 |
| S-06 | **脚手架可跑**：对 S-01 生成的插件执行测试目标（`cjpm run --skip-build --name skill_demo.test`） | 命令行 + 退出码断言 | — | 退出码 `0`，且输出中含 ≥3 项断言通过标记；不连 DB、不起宿主也能跑通 |

- 归属档位：S-01~S-06 由**本子系统 test 步**产出与执行（L1 + L2）；主工程端到端（L3，§5.1 用例 1 / 用例 5）在主工程 test 步执行，不在这里重复。
- S-02 / S-03 是跨子系统主干，S-04 是异常/边界，满足模板「≥1 条跨子系统主干 + ≥1 条异常」。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|:---:|---|---|---|
| 2026-10-19 | v1 | 主工程 `SPECS_INDEX.md` v1.0（IF-12 草案）+ 报告 §9 第 7 条 | 首次落契约：IF-12 分解为 4 条内部分解接口；0 新表；上游 IF-02/IF-05/IF-06/IF-07；§4 明确 RSI 自评循环与 LRT 编排移交 `specs/RSI` | 主工程（§3 新增 R-09 建议）、capability-governance、version-guard |

> 主工程账本同步：本节每次改动，**必须**同步到 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 / §6 / §7。
