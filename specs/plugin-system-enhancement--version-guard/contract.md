# 子系统集成契约（version-guard）

> 模板：`skills/sdd/templates/subsystem-contract-template.md`
> 产出阶段：`spec` / `design` 步（子系统的文档步产出，属该子系统工程内部）
> 被谁消费：主工程 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 集成契约汇总 + 下游子系统的 tasks.md / 编码步
> 铁律依据：**铁律 15**（大工程拆分：集成契约先定、先改契约再改实现）

> 契约是**承诺**，不是设计说明。本文件在子系统实现开工前冻结；
> **禁止**在实现里单边改动契约——要改就走 §5 的演进档位，双侧同轮完成。

## 文档信息

- 所属主工程：`plugin-system-enhancement`
- 子系统 ID：`version-guard`（稳定标识，跨轮次不变，改名等同于新建子系统）
- 子系统 `feature_name`：`plugin-system-enhancement--version-guard`（双连字符；与 `sdd_projects` 唯一键对齐）
- 契约版本：`v1`
- 冻结日期 / 冻结状态：`2026-10-19` / **草案**（随本子系统 spec/design/tasks 同步定稿后转「已冻结」）
- 上游依赖：**无**（本子系统是主工程 DAG 的拓扑序 1 号节点，见 SPECS_INDEX §4）
- 下游消费方（计划中的全部）：
  1. `capability-governance` v1 —— 消费 **IF-01**（取 `PluginHostApi.CURRENT` 做能力清单版本基线）、**IF-02**（读 `entry.pluginApi` 决定能力缺省策略）
  2. `capability-handshake` v1 —— 消费 **IF-04**（在 `InitializeParams` 上追加 IF-08 `declaredCapabilities`，**串行**，见 §3.2 共享文件约定）
  3. `authoring-toolchain` v1 —— 消费 **IF-02**（`plugin validate` 静态校验 `pluginApi` / `hostVersionRange` 合法性）
  4. 宿主 `magic.plugin.PluginHostManager` / `CordisHostManager` —— 消费 **IF-03**（加载前拦截）
  5. 全量子系统 —— 消费 **IF-01**（版本常量）

---

## 1. 本子系统提供什么（能力清单）

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| IF-01 | 进程内调用 | `plugin_spi.PluginHostApi`（经 `magic.plugin.spi_reexport` 转发） | 静态常量读取：`PluginHostApi.CURRENT` / `PROTOCOL_VERSION` / `HOST_VERSION` / `MIN_COMPAT` | 无（编译期常量） | `String` / `Int32` / `String` / `String` | 不适用（常量） | 天然幂等 | 唯一真源。任何子系统**禁止**自建第二份宿主版本常量；新增常量属 minor，改值语义属 major |
| IF-02 | 进程内调用 | `magic.plugin.PluginManifestEntry` 三字段：`version` / `pluginApi` / `hostVersionRange` | 字段读取（由 `fromJsonValue` / `fromPluginYaml` 解析 `plugin.yaml`） | YAML/JSON 清单 | `String` / `Option<String>` / `Option<String>` | 解析失败 → 该字段回落缺省值并 `LogUtils.warn`，**不**抛异常、**不**拒绝清单条目（防回退 R-04） | 解析幂等 | `version` 复用既有"写了不读"的死字段落点（`plugin_config.cj` 现无此字段；生成器 `PluginGenerator.cj:339`、`CrudPluginGenerator.cj:156/:371`、模板 `plugin.yaml.tpl:4` 已写 `version: 1.0.0`） |
| IF-03 | 进程内调用 | `magic.plugin.VersionGuard` | `check(entry: PluginManifestEntry)` | 单个清单条目 | `Result<Unit, PluginError>`：`Ok(Unit)` 放行 / `Err(VersionMismatch \| UnsupportedHost)` 拒绝 | 统一走 `plugin_spi.PluginError` 新增三构造器，**不自造错误码**；文案含「插件名 + 期望 + 实际」三要素 | 幂等（纯函数，无副作用、不写注册表、不读写 DB） | 覆盖 **Sync 轨 + Process 轨**；dylib 轨见下行预留接口 |
| IF-03R（预留） | 进程内调用 | `magic.plugin.VersionGuard.checkDylib(entry)` | `checkDylib(entry: PluginManifestEntry)` | 单个清单条目 | `Result<Unit, PluginError>` | 同 IF-03 | 幂等 | **本工程不接线**（R-01：`PluginDylibLoader` 全仓零调用、`PluginHostManager.loadAll` 对 Dylib 走 Sync 同款 `loadSingle`，`plugin_host_manager.cj:135`）。仅预留签名 + 单测，待 dylib 轨复活后由该工程接线 |
| IF-04 | L3 插件跨轨（握手载荷字段）+ 进程内校验 | `ystyle::cordis_core.InitializeParams.protocolVersion` / `InitializeResult.protocolVersion` / `InitializeResult.hostApiVersion`；宿主侧校验入口 `VersionGuard.checkHandshake(pluginId, reported)` | `(String, ?Int32) -> ?String`（构造注入到 `PluginHost.setProtocolGate`） | 握手载荷字段 + 插件 id | `None` 通过 / `Some(拒绝原因)` 拒绝 | 拒绝 → `InitializeResult(ok=false)` + 实例置 `InstanceStatus.Failed`（**不**置 Pending，避免插件周期重发导致握手风暴） | 幂等（同一握手版本重复校验结果一致） | **本子系统先冻结 `protocolVersion`，`capability-handshake` 再追加 IF-08**，串行，见 §3.2 |

- **类型口径说明**：IF-01 / IF-02 / IF-03 / IF-03R 为**进程内调用**，求值方式 = **静态常量 / 静态函数直接调用**（无 DI 容器、无反射注入），便于下游在单测中直接构造 `PluginManifestEntry` 做替身；IF-04 的宿主侧校验入口求值方式 = **构造注入**（`CordisHostManager` 构造 `PluginHost` 后调 `setProtocolGate` 注入 `VersionGuard.checkHandshake`），下游可注入恒真 gate 做测试替身。
- **错误约定**：全部沿用 `plugin_spi.PluginError`（`libs/plugin-spi/src/plugin_types.cj:56-63`），本子系统追加三个构造器 `VersionMismatch(String)` / `IncompatibleApi(String)` / `UnsupportedHost(String)`，并在同文件 `message()`（`:66-83`）补对应分支。**跨子系统不得自造错误码**；错误码冲突时以主工程 SPECS_INDEX §3 汇总表裁决。
- **幂等性**：本子系统**无写类接口**、无 DB 写入、无跨进程副作用，全部接口天然幂等，下游重试无副作用。

### 1.1 接口签名（冻结态，仓颉）

```cangjie
// libs/plugin-spi/src/plugin_host_api.cj（新增，package plugin_spi）—— IF-01
public class PluginHostApi {
    public static let CURRENT: String = "1.0.0"          // 插件 API 语义化版本
    public static let MIN_COMPAT: String = "1.0.0"       // 宿主仍向下兼容的最低插件 API
    public static let PROTOCOL_VERSION: Int32 = 1        // L3 握手协议版本
    public static let HOST_VERSION: String = "0.0.29"    // 宿主运行时版本（与 cjpm.toml:18 人工同步）
}

// libs/plugin-spi/src/api_version.cj（新增，package plugin_spi）—— IF-02/IF-03 解析内核
public class ApiVersion {
    public static func parse(s: String): ?ApiVersion                 // 支持 X.Y.Z / X.Y / X
    public static func compare(that: ApiVersion): Int32              // -1 / 0 / 1
    public func toString(): String
    public static func satisfies(version: String, constraints: String): Result<Unit, String>
    // 约束语法（最小集）：">=X.Y.Z" "<X.Y.Z" "<=X.Y.Z" ">X.Y.Z" "==X.Y.Z" "!=X.Y.Z"，空格分隔 = AND
    // 不支持 ^ / ~ / || / 通配符；含不支持语法 → Err(含原文的描述)
}

// src/plugin/version_guard.cj（新增，package magic.plugin）—— IF-03 / IF-03R / IF-04
public class VersionGuard {
    public static func check(entry: PluginManifestEntry): Result<Unit, PluginError>
    public static func checkDylib(entry: PluginManifestEntry): Result<Unit, PluginError>  // 预留，不接线
    public static func checkHandshake(pluginId: String, reported: ?Int32): ?String
}
```

### 1.2 兼容性判定规则（冻结态）

| 声明 | 缺省值（未声明时） | 判定规则 | 不匹配的 `PluginError` |
|---|---|---|---|
| `pluginApi` | `None` → **放行** + `LogUtils.warn` | `ApiVersion.satisfies(PluginHostApi.CURRENT, entry.pluginApi)` | `VersionMismatch` |
| `hostVersionRange` | `None` → 不约束 | `ApiVersion.satisfies(PluginHostApi.HOST_VERSION, entry.hostVersionRange)` | `UnsupportedHost` |
| `version`（插件自身版本） | `""` → 仅作元数据 | **不参与**兼容性判定，仅进日志 / 错误信息 / inspect 输出 | 不适用 |
| `protocolVersion`（握手） | `None` → **放行** + `LogUtils.warn` | `reported == PluginHostApi.PROTOCOL_VERSION` | `IncompatibleApi`（经 gate 转为 `InitializeResult(ok=false)`） |

> **缺省放行是防回退硬约束（R-04）**：存量 51 个 skill 插件 + 4 个 sync 插件（`src/plugins/generated_anchors.cj`）的 `plugin.yaml` 均无 `pluginApi` 字段，若缺省即拒绝将造成全量回归。故 v1 一律缺省放行并告警；v2 是否收紧为「缺省即拒绝」属 **major** 档位，须双侧同轮（见 §5）。

---

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| **（无）** | 本子系统**不读写任何数据库表**：全部状态承载于 `plugin.yaml` 清单条目（进程内对象）与 L3 JSON-RPC 握手载荷 | 无 | 无 | 不适用 | 不适用 |

- **新建表/列：0 张 / 0 列**（铁律 9 复用优先）。主工程 `SPECS_INDEX.md` §2 已登记本子系统「0 新表」，本契约确认不变。
- **复用论证**：
  - 插件清单已有载体 `plugin.yaml` → `PluginManifestEntry`（`plugin_config.cj:72-112`），版本字段直接在其上增列，**不**新建清单文件、不新建 `plugin_version` 表。
  - 握手已有载体 `InitializeParams` / `InitializeResult`（`libs/cordis-cj/cordis_core/src/message.cj:10-97`），协议版本直接在其上增字段，**不**新增 `Methods` 常量、**不**新增 `hello`/`negotiate` 方法（避免与 capability-handshake 的 IF-08 抢改协议骨架）。
  - 观测与状态回写已有通道 `PluginSyncBridge` → `agent_skills.runtime_status` / `last_error`（R-06），本子系统**只读复用其日志通道，不写这两列**（列写入与语义归 `lifecycle-observability`）。
- **行级权限 / 软删**：本子系统不触达数据面，无 `creator` / `owner_user_id` 判定、无 `deleted_at` 语义，下游不得假借本子系统绕过 `user-permission-system.md` / `row-level-permission-system.md`。

---

## 3. 依赖方向

### 3.1 我依赖的上游（有限名单）

1. **无**。本子系统是主工程 DAG 的拓扑序 1 号节点（`SPECS_INDEX.md` §4），无上游子系统依赖。

### 3.2 我不依赖谁（明确保留位）

- **不依赖 `capability-governance` 的任何实现细节**。本子系统只做「版本协商」，不读、不判定、不消费能力清单（`PluginCapability` enum / `CapabilityPolicy`）。将来若需按能力做版本分档，必须回本文改依赖方向并过闸口，而不是在实现里偷偷 import。
- **不依赖 `authoring-toolchain` 的 `plugin validate`**。本子系统只提供清单字段与校验函数；`plugin validate` CLI 是否调用 IF-02/IF-03 由 `authoring-toolchain` 单方决定，本子系统不反向调用它。
- **不依赖 `lifecycle-observability` 的事件通道**。版本拒绝只走 `LogUtils` + `PluginError` + 既有 `plugin.error` 生命周期事件（`plugin_host_manager.cj:499-506`），不订阅 `plugin.crashed` / `plugin.restarted`。
- **不依赖 `cordis-cj` 的内部状态机**。本子系统仅在 `PluginHost` 上以**构造注入回调**方式挂载 gate，不读 `HostState`、不改 `Reconciler` 拓扑逻辑。
- **禁止成环**：本子系统与任一若出现双向依赖，合并回去重新切边界（SKILL.md 颗粒度红线）。当前 DAG 无回边。

### 3.3 共享文件冲突约定（R-05，强制执行）

- `version-guard` 与 `capability-handshake` 都会改 `libs/cordis-cj/cordis_core/src/message.cj` 的 `InitializeParams`。
- **约定**：本子系统**先**冻结 IF-04 —— 以**尾部命名默认参数**形式追加 `protocolVersion!: ?Int32 = None`（`InitializeParams`）与 `protocolVersion!: ?Int32 = None` / `hostApiVersion!: ?String = None`（`InitializeResult`）；
  `capability-handshake` 在其**之后**再以同样的「尾部命名默认参数」形式追加 IF-08 `declaredCapabilities`。
- 双方**串行**改动同一结构体，禁止并行；任一侧改为「必填位置参数」或改动既有字段语义即判 **major**，须双侧同轮。
- 序列化顺序不影响 JSON-RPC 语义（对象键无序），故追加顺序无兼容风险。

---

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| **`dylib` 轨复活 / `PluginDylibLoader` 接线** | 需单独立项（建议 `specs/plugin-dylib-track`） | **本子系统不复活 dylib 轨、不接线 `PluginDylibLoader`**（`src/plugin/plugin_dylib_loader.cj`，全仓零调用；`PluginHostManager.loadAll` 对 Dylib 走与 Sync 相同的 `loadSingle`，`plugin_host_manager.cj:135`；`unloadDylib` 是空实现，`plugin_dylib_loader.cj:146-151`）。见主工程 §7 **R-01**。本子系统仅提供 §1 的 IF-03R 预留接口 `VersionGuard.checkDylib`，**标注未接线**，待 dylib 轨复活后由该工程在 `PluginDylibLoader.loadFromDylib` 入口调用 |
| 能力枚举 `PluginCapability` + 缺省策略 `CapabilityPolicy` | `capability-governance`（IF-05） | 版本协商与能力治理正交：本子系统不解释"能力"语义 |
| 运行时能力门禁判定 | `capability-governance`（IF-06） | 本子系统只判"版本能不能进"，不判"进来后能干啥" |
| 跨进程能力禁列表 `HostUnsupportedCapabilities` | `capability-governance`（IF-07） | 同上 |
| L3 能力宣告载荷 `declaredCapabilities` 与宣告比对 | `capability-handshake`（IF-08 / IF-09） | 本文 §3.3 只冻结 `protocolVersion`，宣告字段由其追加 |
| 依赖拓扑排序 / `order` 替代 | `dependency-graph`（IF-10） | 版本校验发生在依赖解析之前，两者不交叉 |
| 崩溃退避 / 重启计数 / 风暴熔断 | `lifecycle-observability`（IF-11） | 本子系统的握手拒绝置 `Failed` 态是为**避免**握手风暴，**不是**自愈策略；自愈语义归 `lifecycle-observability` |
| `plugin validate` CLI / 存量清单体检 | `authoring-toolchain`（IF-12） | 本子系统只暴露可被调用的 `VersionGuard.check`，不提供命令行入口 |
| 宿主环境变量白名单 / `host.secret` per-plugin 授权 | `capability-governance`（R-03 修复） | 安全缺陷 R-03 的修复不在本子系统范围 |
| `plugin.yaml` 未知字段/类型严格 schema 校验 | `authoring-toolchain`（IF-12） | 本子系统对 `pluginApi` / `hostVersionRange` **类型不符**仅回落缺省 + warn，**不做**整份清单的 schema 严格校验（`plugin_config.cj:161-165` 静默跳过的既有行为不在本工程改动范围） |
| 未知 `mode` 值报错（现静默降级 Sync，`plugin_config.cj:275`） | `authoring-toolchain`（IF-12） | 属清单体检范畴；本子系统只在降级为 Sync 后照常执行 Sync 轨版本校验 |
| 数据库表 / 列的任何新增 | 全部子系统（默认 0 新表） | 铁律 9 复用优先；本子系统确认 0 新表 0 新列 |

---

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动；在子系统 `tasks.md` 修订记录留痕即可 |
| 向后兼容（minor） | 只增接口/只增可选字段，不改既有语义 | 改本文 + 主工程 `SPECS_INDEX.md` §3；下游不必同步改 |
| 破坏性（major） | 改路径/改字段语义/删接口/改权限口径/**改 `PluginHostApi` 常量值语义**/**把缺省放行改为缺省拒绝**/**把 `protocolVersion` 改为必填** | **必须双侧同轮**：提供方与全量消费方（`capability-governance` / `capability-handshake` / `authoring-toolchain` / 宿主 `PluginHostManager` / `CordisHostManager`）在同一轮 code 里改完；主工程 `SPECS_INDEX.md` §6 登记；单侧先改 = P0 缺陷 |

- 演进一律「**先改契约 → 再改实现**」，顺序反了按铁律 15 打回。
- 契约冻结后到实现完成之间的任何偏差，在子系统 `test-report.md` 里必须归因到具体契约条目，禁止笼统写"实现与文档略有差异"。
- **已知 v2 候选（不在 v1 范围）**：① 缺省拒绝未声明 `pluginApi` 的插件（major，需先由 `authoring-toolchain` 为全量存量清单补全字段）；② `pluginApi` 约束语法扩展 `^` / `~`（minor）；③ `PluginHostApi` 常量改为从构建期注入而非硬编码（minor）。

---

## 6. 集成验收（本子系统对下游的交付承诺）

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| S-VG-01 | **主干**：process 插件 `plugin.yaml` 声明 `pluginApi: ">=1.0.0 <2.0.0"` → 加载前 IF-03 通过 → L3 进程被拉起 → 握手携带 `protocolVersion: 1` → IF-04 通过 → 实例 `Active` | 集成脚本（宿主进程内调用 `PluginHostManager.loadAll` + `CordisHostManager.loadProcessPlugins`），见 `src/plugin/integration/` | 无（本子系统自闭环） | `LoadResult.loaded` 含该插件；日志出现 `[VersionGuard] check passed`；`awaitActive` 返回 `Ok` |
| S-VG-02 | **异常 / 跨子系统主干（version-guard → capability-handshake）**：process 插件声明 `pluginApi: ">=2.0.0"`（不兼容）→ 加载前被拒 | 同上，观察 `LoadResult.failed` 与进程列表 | 无 | ① `LoadResult.failed` 含 `"{name}(version mismatch: ...)"`；② `PluginError.message()` 含插件名 + 期望 + 实际三要素；③ **L3 进程未被拉起**（`ps` 无对应进程）；④ 宿主无崩溃、其余插件照常加载（对应主工程 §5 L2 冒烟清单第 1 条） |
| S-VG-03 | **异常**：`pluginApi: ">>1.0"`（约束语法非法）→ 拒绝加载 | 单测 `ApiVersion.satisfies` + 集成用例 | 无 | 返回 `Err(PluginError.VersionMismatch("...unparsable constraint..."))`，**不**静默放行 |
| S-VG-04 | **异常 / 跨子系统（version-guard → capability-handshake）**：握手上报 `protocolVersion: 99` → 宿主拒绝挂载 | 集成脚本，观察 initialize 响应与实例状态 | IF-04 字段已冻结（本子系统） | ① 返回 `InitializeResult(ok=false)`；② 实例状态置 `InstanceStatus.Failed`（`libs/cordis-cj/cordis_core/src/status.cj:14`）而**非** `Pending`，插件周期重发不会形成握手风暴；③ 宿主日志含 `[VersionGuard] handshake rejected` |
| S-VG-05 | **边界 / 防回退（R-04）**：全量存量插件（51 个 skill + 4 个 sync 锚点）清单**无** `pluginApi` 字段 → 全部放行 | 存量清单体检脚本（只读解析 + 调 `VersionGuard.check`） | 无 | `VersionGuard.check` 对 100% 存量条目返回 `Ok`，且每条产生一条 `warn` 日志；主工程 §5.1 用例 5「行为零回归」不被破坏 |
| S-VG-06 | **边界 / 下游消费（→ capability-governance）**：`capability-governance` 侧读取 `entry.pluginApi` 得到与 `PluginHostApi.CURRENT` 一致的值 | 下游 test 步调用 IF-01 + IF-02 | `version-guard` 处于 done（L1 通过）且不晚于其 test 步开始日 | 下游能读到非空 `pluginApi` 缺省语义说明；IF-01 常量与 IF-02 解析结果无二义 |
| S-VG-07 | **边界**：`VersionGuard.check` 对 `mode: dylib` 条目返回 `Ok`（因 dylib 轨不接线，不产生任何拒绝），且 `checkDylib` 预留接口可被单测直接调用 | 单测 | 无 | `check` 不因 dylib 分支抛异常；`checkDylib` 单测覆盖通过/拒绝两条路径（仅单测覆盖，**运行时零调用**） |

- **上游就位前提**：本子系统无上游子系统依赖，§6 全部用例可在 `version-guard` 自身 test 步（L1）与下游 test 步（L2）独立执行，无需等待他人。
- **归属档位**：本文 §6 用例由**本子系统 test 步**产出与执行（L1 + L2）；主工程端到端（L3，含 §5.1 用例 1/2/5）在主工程 test 步执行，不在这里重复。
- **不跑编译**：AI 不执行 `cjpm build`；编译、类型检查、lint 由人工在独立 cmd 环境完成并回传结果。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|:---:|---|---|---|
| 2026-10-19 | v1.0 | 主工程 `SPECS_INDEX.md` §3 接口账本 + 基线侦察（P0 GAP：`pluginApi`/`apiVersion`/`hostVersion`/`handshake` 全仓 `src/` 0 命中） | 首次落契约：IF-01~IF-04 冻结为草案；新增 IF-03R 作为 dylib 预留接口并显式标注未接线；§3.3 写入 R-05 串行约定 | `capability-governance`（消费 IF-01/IF-02）、`capability-handshake`（在 IF-04 之后追加 IF-08）、`authoring-toolchain`（消费 IF-02）、宿主 `PluginHostManager` / `CordisHostManager`（消费 IF-03） |

> 主工程账本同步：本节每次改动，**必须**同步到 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 / §6。
