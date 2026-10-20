# 技术设计文档（version-guard · 版本协商守卫）

## 文档信息

- **项目名称**：`plugin-system-enhancement--version-guard`（主工程 `plugin-system-enhancement` 子系统 1 号节点）
- **版本**：v1.0
- **创建日期**：2026-10-19
- **作者**：SDD 文档步执行者
- **状态**：草稿（随本子系统 code 步开工转「已批准」）
- **关联需求**：`specs/plugin-system-enhancement--version-guard/spec.md`
- **关联契约**：`specs/plugin-system-enhancement--version-guard/contract.md`（接口编号 IF-01~IF-04 以其为准）
- **权威边界账本**：`specs/plugin-system-enhancement/SPECS_INDEX.md`

---

## 1. 设计概述

### 1.1 设计目标

1. **G1 补 P0 缺口**：当前全仓 `src/`（含 `libs/plugin-spi/`、`libs/cordis-cj/`）grep `pluginApi` / `apiVersion` / `hostVersion` / `handshake` → **0 命中**（已验证基线），插件系统完全没有版本协商。本设计把这条缺口补上。
2. **G2 兑现既有需求 REQ-PS-010**：`.codeartsdoer/specs/plugin-system/spec.md:179` 要求「版本不兼容时明确报错并回滚注册表」，当前未实现。本设计用「校验前置 + 快照/回滚」把它真正落地。
3. **G3 盘活死字段**：生成器已写 `version: 1.0.0`（`CrudPluginGenerator.cj:156/:371`、`PluginGenerator.cj:339`、模板 `plugin.yaml.tpl:4`），宿主从不读（`plugin_config.cj:122-208`）→ 变成活字段。
4. **G4 零回归**：51 个 skill 插件 + 4 个 sync 锚点（`generated_anchors.cj:10-17`）清单无版本声明，必须 100% 放行（R-04）。
5. **G5 可组合**：只冻结协议版本字段，把 `declaredCapabilities` 的追加权留给 `capability-handshake`，串行不抢改（R-05）。

### 1.2 设计原则

| 原则 | 落地口径 |
|---|---|
| **铁律 9 复用优先** | 0 新建表 / 0 新建列；状态全部承载于既有 `plugin.yaml` 条目对象与既有握手载荷 |
| **铁律 14 底座优先** | 常量落 `plugin-spi`（底座包），宿主与插件共用同一真源；不改生成器骨架、不改构建流程 |
| **铁律 15 契约先行** | 严格按 `contract.md` §1.1 冻结签名实现；偏差须走 §5 演进档位，禁止单边改 |
| **纯函数优先** | `VersionGuard.check` 无副作用、幂等，便于单测与下游替身 |
| **依赖单向无环** | `cordis_core` 不反向依赖 `plugin_spi`；语义判定留在宿主侧，以构造注入回调挂载 |
| **缺省放行** | v1 未声明 = 放行 + warn；收紧为「缺省拒绝」属 major，须双侧同轮 |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 编程语言 | 仓颉（Cangjie） | 与宿主 `agentskills-runtime` 一致；编写须用 `cangjie-coder` 技能 |
| 常量承载包 | `libs/plugin-spi`（package `plugin_spi`） | 底座包，插件将来独立包化后直接 import |
| 校验内核 | `libs/plugin-spi/src/api_version.cj` | `ApiVersion.parse` / `compare` / `satisfies` |
| 准入闸门 | `src/plugin/version_guard.cj`（package `magic.plugin`） | `VersionGuard.check` / `checkDylib` / `checkHandshake` |
| 握手协议 | `libs/cordis-cj/cordis_core/src/message.cj` | 仅增哑字段，语义在宿主侧 |
| 序列化 | 既有 `JsonSerializable` / `JsonDeserializable` | 沿用 `InitializeParams` 既有模式，不引入新依赖 |
| 数据库 | **无** | 0 新表 0 新列 |
| 编译 | **AI 不跑 `cjpm build`** | 编译、类型检查、lint 由人工在独立 cmd 环境完成并回传 |

---

## 2. 系统架构

### 2.1 架构图

```
                       ┌──────────────────────────────────────┐
                       │    libs/plugin-spi  (package plugin_spi)   │
                       │  ┌────────────────────────────────┐  │
                       │  │ PluginHostApi   (IF-01)        │  │
                       │  │  CURRENT / MIN_COMPAT          │  │
                       │  │  PROTOCOL_VERSION / HOST_VERSION│  │
                       │  └────────────────────────────────┘  │
                       │  ┌────────────────────────────────┐  │
                       │  │ ApiVersion      (IF-02/03 内核) │  │
                       │  │  parse / compare / satisfies    │  │
                       │  └────────────────────────────────┘  │
                       │  ┌────────────────────────────────┐  │
                       │  │ PluginError +3 构造器           │  │
                       │  │  VersionMismatch / IncompatibleApi│
                       │  │  / UnsupportedHost              │  │
                       │  └────────────────────────────────┘  │
                       └───────────────┬──────────────────────┘
                                       │ public import（spi_reexport.cj:16-30 追加）
                                       ▼
   plugin.yaml ──► PluginManifestEntry (+version/pluginApi/hostVersionRange)  ── IF-02
                                       │
                       ┌───────────────▼──────────────────────┐
                       │  src/plugin/version_guard.cj         │
                       │   VersionGuard.check        (IF-03)   │
                       │   VersionGuard.checkDylib   (IF-03R)  │
                       │   VersionGuard.checkHandshake(IF-04)  │
                       └───┬───────────────┬──────────────┬───┘
                           │               │              │
              ┌────────────▼──┐  ┌─────────▼──────┐  ┌────▼──────────────┐
              │ PluginHostManager│ │ CordisHostManager│ │ cordis-cj PluginHost│
              │ loadSingle      │ │ loadProcessPlugins│ │ setProtocolGate     │
              │ (Sync/Dylib)    │ │ (Process)         │ │ initialize handler  │
              └─────────────────┘ └──────────────────┘ └─────────────────────┘
                           │               │
              PluginRegistry.snapshot()/restore()  ← 兑现 REQ-PS-010 回滚
```

### 2.2 模块划分

| 模块 | 落点 | 职责 | 契约接口 |
|---|---|---|---|
| M1 版本真源 | `libs/plugin-spi/src/plugin_host_api.cj`（新增） | 暴露 4 个静态常量，唯一真源 | IF-01 |
| M2 版本内核 | `libs/plugin-spi/src/api_version.cj`（新增） | 解析 / 比较 / 约束求值 | IF-02 / IF-03 |
| M3 错误码扩展 | `libs/plugin-spi/src/plugin_types.cj:56-83`（改） | 追加 3 个构造器 + `message()` 分支 | 横切 |
| M4 SPI 转发 | `src/plugin/spi_reexport.cj:16-30`（改） | 追加 `PluginHostApi` / `ApiVersion` 转发 | 横切 |
| M5 清单字段 | `src/plugin/plugin_config.cj:72-208`（改） | 增列三字段并解析（含降级 + warn） | IF-02 |
| M6 准入闸门 | `src/plugin/version_guard.cj`（新增） | `check` / `checkDylib` / `checkHandshake` | IF-03 / IF-03R / IF-04 |
| M7 Sync/Dylib 接线 | `src/plugin/plugin_host_manager.cj:302`（改） | 前置校验 + 快照回滚 | IF-03 |
| M8 Process 接线 | `src/plugin/cordis_host_manager.cj:137`（改） | 前置校验，不拉起进程 | IF-03 |
| M9 握手协议字段 | `libs/cordis-cj/cordis_core/src/message.cj:10-97`（改） | 追加 `protocolVersion` / `hostApiVersion` 哑字段 | IF-04 |
| M10 门禁注入 | `libs/cordis-cj/cordis_host/src/plugin_host.cj:104-138`（改） | 新增 `setProtocolGate`，拒绝置 `Failed` | IF-04 |

### 2.3 组件交互

1. `PluginDiscoveryService` 解析 `plugin.yaml` → `PluginList`（含本次新增三字段）。
2. `PluginHostManager.loadAll`（`:114`）遍历：Sync/Dylib → `loadSingle`（`:302`）→ **先 `VersionGuard.check`**；Process → 累积 `hasProcess` → `CordisHostManager.loadProcessPlugins`（`cordis_host_manager.cj:137`）→ **先 `VersionGuard.check`**。
3. 通过 → 走既有加载/拉起路径；拒绝 → `result.failed` 记录 + `plugin.error` 事件 + 注册表快照回滚，**不产生实例化/进程副作用**。
4. Process 轨子进程启动后发 `initialize` → `PluginHost` handler 读 `params.protocolVersion` → 调注入的 gate → 拒绝则 `InitializeResult(ok=false)` + `InstanceStatus.Failed`。

---

## 3. 详细设计

### 3.1 M1 `PluginHostApi`（IF-01）

#### 3.1.1 类设计

新增 `libs/plugin-spi/src/plugin_host_api.cj`，package `plugin_spi`，仅含静态常量，无状态、无依赖。

#### 3.1.2 接口设计

```cangjie
// libs/plugin-spi/src/plugin_host_api.cj（新增）
public class PluginHostApi {
    public static let CURRENT: String = "1.0.0"          // 插件 API 语义化版本
    public static let MIN_COMPAT: String = "1.0.0"       // 宿主仍向下兼容的最低插件 API（v1 不参与判定）
    public static let PROTOCOL_VERSION: Int32 = 1        // L3 握手协议版本
    public static let HOST_VERSION: String = "0.0.29"    // 宿主运行时版本（与 cjpm.toml:18 人工同步）
}
```

#### 3.1.3 数据流

`PluginHostApi` →（编译期常量内联）→ `VersionGuard` / `ApiVersion` / 下游子系统。无运行时数据流。

#### 3.1.4 关键约定

- 新增常量 = **minor**；改值语义 = **major**（contract §5）。
- `HOST_VERSION` 与 `cjpm.toml:18` 人工同步，v1 不引入构建期注入（已知 v2 候选③）。

### 3.2 M2 `ApiVersion`（IF-02 / IF-03 内核）

#### 3.2.1 类设计

新增 `libs/plugin-spi/src/api_version.cj`，package `plugin_spi`。不可变值对象（major/minor/patch 三段）。

#### 3.2.2 接口设计

```cangjie
// libs/plugin-spi/src/api_version.cj（新增）
public class ApiVersion <: ToString {
    public let major: Int32
    public let minor: Int32
    public let patch: Int32

    public init(major: Int32, minor: Int32, patch: Int32)

    /// 支持 "X" / "X.Y" / "X.Y.Z"；缺段补 0；非法返回 None
    public static func parse(s: String): ?ApiVersion

    /// -1 / 0 / 1
    public func compare(that: ApiVersion): Int32

    public func toString(): String

    /// 约束语法最小集：">=X.Y.Z" "<X.Y.Z" "<=X.Y.Z" ">X.Y.Z" "==X.Y.Z" "!=X.Y.Z"
    /// 空格分隔 = AND；不支持 ^ ~ || 通配符；不支持语法 → Err(含原文描述)
    public static func satisfies(version: String, constraints: String): Result<Unit, String>
}
```

#### 3.2.3 判定流程

```
satisfies(version, constraints):
  v = parse(version)          ; v == None   -> Err("invalid version '...'")
  for each token in constraints.split(" ").filter(!isEmpty):
      (op, operand) = splitToken(token)     ; 无法识别运算符 -> Err("unparsable constraint '<token>'")
      t = parse(operand)                    ; t == None      -> Err("unparsable constraint '<token>'")
      c = v.compare(t)
      if !evalOp(op, c): return Err("version '${version}' does not satisfy '${constraints}'")
  return Ok(Unit)
```

- `splitToken` 仅识别六个前缀运算符（先匹配双字符 `>=` `<=` `==` `!=`，再匹配单字符 `>` `<`）。
- `evalOp`：`>=` → c >= 0；`<=` → c <= 0；`>` → c > 0；`<` → c < 0；`==` → c == 0；`!=` → c != 0。

#### 3.2.4 边界

| 输入 | 结果 |
|---|---|
| `"1"` / `"1.2"` / `"1.2.3"` | `Ok` 解析为 1.0.0 / 1.2.0 / 1.2.3 |
| `""` / `"abc"` / `"1.2.3-beta"` / `"-1"` | `parse` → `None` |
| `">=1.0.0 <2.0.0"`（宿主 1.0.0） | `Ok` |
| `"^1.0.0"` / `"~1"` / `"1.x"` | `Err("unparsable constraint ...")` |
| `">>1.0"` | `Err("unparsable constraint '>>1.0'")` |

### 3.3 M3 `PluginError` 扩展

在 `libs/plugin-spi/src/plugin_types.cj:56-63` 的枚举体**尾部**追加三个构造器，并在 `message()`（`:66-83`）的 `match` 中追加对应分支：

| 构造器 | 触发场景 | `message()` 文案模板 |
|---|---|---|
| `VersionMismatch(String)` | `pluginApi` 不满足（含约束串语法非法） | `"plugin api version mismatch: ${desc}"` |
| `IncompatibleApi(String)` | 握手 `protocolVersion` 与宿主不一致 | `"incompatible plugin api protocol: ${desc}"` |
| `UnsupportedHost(String)` | `hostVersionRange` 不满足 | `"unsupported host version: ${desc}"` |

- `desc` 由 `VersionGuard` 拼装，固定含**插件名 + 期望（约束串）+ 实际（常量值）**三要素。
- 既有 7 个构造器与文案一字不改（兼容性约束 4）。

### 3.4 M4 SPI 转发层

在 `src/plugin/spi_reexport.cj:16-30` 的 `public import plugin_spi.{...}` 花括号内追加 `PluginHostApi` 与 `ApiVersion`，保持存量 `import magic.plugin.{Plugin, ...}` 使用方零改动。

### 3.5 M5 清单字段与解析（IF-02）

#### 3.5.1 字段增列（`plugin_config.cj:72-112`）

| 字段 | 类型 | 缺省 | YAML 键 |
|---|---|---|---|
| `version` | `String` | `""` | `version` |
| `pluginApi` | `Option<String>` | `None` | `pluginApi` |
| `hostVersionRange` | `Option<String>` | `None` | `hostVersionRange` |

#### 3.5.2 解析改造（`fromJsonValue` `:122-208`）

1. 在既有字段解析块**之后**（`:156-173` 附近）追加三段解析，紧邻 `routeClass` 之后，保持既有分支顺序不变。
2. 判定方式沿用本文件既有风格：`if (x is JsonString) { ... }`，非 `JsonString` 一律**回落缺省值**，不 `return None`。
3. `version` 用既有 `jsonToString`（`:319-324`）取串；`pluginApi` / `hostVersionRange` 仅在 `is JsonString` 时取 `Some(...)`。
4. 回落时输出 `LogUtils.warn("[VersionGuard] ...")`，不抛异常。
5. `fromPluginYaml`（`:216-267`）无需改动——它复用 `fromJsonValue`，自动获得三字段。

#### 3.5.3 不做的改动（明确边界）

- 不改 `parseMode`（`:270-277`）的未知值静默降级行为（归 `authoring-toolchain` IF-12）。
- 不给 `fromJsonValue` 增加整份清单的严格 schema 校验。
- 不改 `enabled` / `order` 等既有字段的类型不符静默跳过行为（`:156-165`）。

### 3.6 M6 `VersionGuard`（IF-03 / IF-03R / IF-04）

#### 3.6.1 类设计

新增 `src/plugin/version_guard.cj`，package `magic.plugin`。全部静态方法，无实例状态、无 IO。

#### 3.6.2 接口设计

```cangjie
// src/plugin/version_guard.cj（新增）
public class VersionGuard {
    /// Sync / Process 轨加载前准入校验（dylib 条目亦走此路径，等价于 Sync）
    public static func check(entry: PluginManifestEntry): Result<Unit, PluginError>

    /// 【预留 · 运行时零调用】dylib 轨复活后由该工程在 PluginDylibLoader.loadFromDylib 入口接线
    public static func checkDylib(entry: PluginManifestEntry): Result<Unit, PluginError>

    /// L3 握手门禁：None = 通过，Some(reason) = 拒绝
    public static func checkHandshake(pluginId: String, reported: ?Int32): ?String
}
```

#### 3.6.3 `check` 内部流程

```
check(entry):
  1. api = entry.pluginApi
     - None    -> LogUtils.warn("[VersionGuard] plugin '${entry.name}' declares no pluginApi; allowing (host api ${PluginHostApi.CURRENT})"); goto 2
     - Some(c) -> ApiVersion.satisfies(PluginHostApi.CURRENT, c)
                    Err(d) -> return Err(PluginError.VersionMismatch("${entry.name}: required ${c}, host api ${PluginHostApi.CURRENT} (${d})"))
  2. range = entry.hostVersionRange
     - None    -> goto 3
     - Some(r) -> ApiVersion.satisfies(PluginHostApi.HOST_VERSION, r)
                    Err(d) -> return Err(PluginError.UnsupportedHost("${entry.name}: required ${r}, host ${PluginHostApi.HOST_VERSION} (${d})"))
  3. return Ok(Unit)     // entry.version 仅进日志，不参与判定
```

- 整体包一层 `try/catch`：任何未预期异常 → `LogUtils.error` + `return Ok(Unit)`（可靠性约束 2）。
- `entry.version` 仅在 `info` 日志与错误文案中展示。

#### 3.6.4 `checkHandshake` 内部流程

```
checkHandshake(pluginId, reported):
  match (reported) {
      case None =>
          LogUtils.warn("[VersionGuard] plugin '${pluginId}' reports no protocolVersion; allowing (host protocol ${PluginHostApi.PROTOCOL_VERSION})")
          None
      case Some(v) =>
          if (v == PluginHostApi.PROTOCOL_VERSION) { None }
          else {
              LogUtils.error("[VersionGuard] handshake rejected: plugin '${pluginId}' protocolVersion=${v}, host supports ${PluginHostApi.PROTOCOL_VERSION}")
              Some("protocol version mismatch: plugin=${v}, host=${PluginHostApi.PROTOCOL_VERSION}")
          }
  }
```

#### 3.6.5 `checkDylib` 预留实现口径

- 实现体与 `check` **完全一致**（dylib 在运行时走与 Sync 相同的 `loadSingle`，`plugin_host_manager.cj:135`，因此 v1 语义相同）。
- 文件内与 `tasks.md` 中显式标注「预留，运行时零调用」；**不在本工程任何加载路径中调用**。

### 3.7 M7 Sync/Dylib 轨接线（兑现 REQ-PS-010）

改造点：`src/plugin/plugin_host_manager.cj:302` `loadSingle`。

```
loadSingle(entry, result):
  0. 【新增】let snap = this.registry.snapshot()          // 条目加载前快照
  0a【新增】match (VersionGuard.check(entry)) {
          case Err(err) =>
              this.registry.restore(snap)                 // 注册表零残留（REQ-PS-010）
              LogUtils.error("[PluginHostManager] version check failed '${name}': ${err.message()}")
              this.emitLifecycle("plugin.error", name, error: err.message())
              result.failed.add("${name}(${err.message()})")
              return
          case Ok(_) => ()
      }
  1. 既有：幂等跳过 / setState(Loading) / 构造 context / loader.load / onLoad / onActivate / register ...
```

- **顺序要点**：版本校验插在 `registry.setState(name, PluginState.Loading)`（`:313`）**之前**，因此正常路径下快照为空操作、不产生额外开销。
- **不碰**：既有 `Err` 分支（`:326-331` onLoad/onActivate 失败）的 `Error` 态语义保持不变——那是 `lifecycle-observability` 的域。
- **不碰**：`loadAll` 的 `hasProcess` 分支（`:136-138`）与 `registerProcessPluginRoutes`（`:154`）。

### 3.8 M8 Process 轨接线

改造点：`src/plugin/cordis_host_manager.cj:137` `loadProcessPlugins`。

```
loadProcessPlugins(list, traceReset):
  for entry in list.plugins where entry.enabled && entry.mode == Process:
      【新增】match (VersionGuard.check(entry)) {
          case Err(err) =>
              LogUtils.error(...)
              result.failed.add("${entry.name}(${err.message()})")
              continue          // 关键：不调用 launchPlugin，子进程不被拉起
          case Ok(_) => ()
      }
      既有：构造 PluginEntry / launchPlugin / awaitActive ...
```

- **回滚语义**：Process 轨的「注册表」是 cordis `HostState`；拒绝即 `continue`，`state.actual` 不新增实例 = 天然零残留。
- **不碰**：`awaitActive` / `reconcile` / `healCrashed`（`plugin_host.cj:920-980`）—— 归 `lifecycle-observability`。

### 3.9 M9 + M10 握手协议字段与门禁注入（IF-04）

#### 3.9.1 协议结构体（`cordis_core/src/message.cj`）

- `InitializeParams`：`init` 尾部追加 `protocolVersion!: ?Int32 = None`；`toJson` 在 `config` 之后按 `if (let Some(v) <- this.protocolVersion)` 写入；`fromJson` 的 `match (r.readName())` 追加 `case "protocolVersion" => ...`。
- `InitializeResult`：同法追加 `protocolVersion!: ?Int32 = None` 与 `hostApiVersion!: ?String = None`。
- **零改动保证**：既有字段的参数位置、序列化键名、必填性全部不变；存量调用点继续编译通过。

#### 3.9.2 门禁注入点（`cordis_host/src/plugin_host.cj`）

1. 新增 `private var protocolGate: ?(String, ?Int32) -> ?String = None` 与 `public func setProtocolGate(gate: (String, ?Int32) -> ?String): Unit`。
2. 在 initialize handler（`:104-138`）中，读完 `params` 后、调 `checkMissing`（`:115`）**之前**执行门禁：

```
match (this.protocolGate) {
    case Some(gate) =>
        match (gate(providerId, params.protocolVersion)) {
            case Some(reason) =>
                this.transitionStatus(instance, InstanceStatus.Failed)   // 非 Pending
                this.logger(providerId, "initialize rejected: ${reason}")
                return Some(JsonValue.fromObject(InitializeResult(false, HashMap<String,String>(),
                    protocolVersion: Some(PluginHostApi.PROTOCOL_VERSION),
                    hostApiVersion: Some(PluginHostApi.CURRENT))))
            case None => ()
        }
    case None => ()      // 未注入：默认放行，行为同改造前
}
```

3. **不碰**：`checkMissing`（`:115`）与「依赖未满足 → Pending」（`:126-130`）分支语义。

#### 3.9.3 注入时机

`CordisHostManager`（`cordis_host_manager.cj:38`）构造 `PluginHost` 之后调用 `setProtocolGate { id, v => VersionGuard.checkHandshake(id, v) }`。

- **串行约束（R-05）**：本任务先合入 `message.cj` 的 `protocolVersion` 字段并标记冻结，`capability-handshake` 才在其上追加 IF-08 `declaredCapabilities`；同一时段禁止两个子系统并行改 `message.cj`。

### 3.10 关键决策记录（ADR）

| 编号 | 决策 | 备选方案 | 理由 |
|---|---|---|---|
| ADR-VG-1 | 版本常量落 `libs/plugin-spi`（package `plugin_spi`） | 落在 `magic.plugin` | 插件将来独立包化后须依赖底座包而非宿主包；`plugin-spi` 已是 `PluginError` / `PluginAnnotation` 的既有落点（`plugin_types.cj`、`plugin_annotation.cj`） |
| ADR-VG-2 | 语义判定**不进** `cordis_core`，协议结构体只加哑字段，判定由宿主构造注入 gate | 在 `cordis_core` 里 import `plugin_spi` 直接判 | 避免 vendored 库 `cordis-cj` 反向依赖业务库 `plugin_spi`，形成循环包依赖；注入式也便于下游用恒真 gate 做替身 |
| ADR-VG-3 | v1 缺省（未声明）= **放行 + warn** | 缺省即拒绝 | 存量 55 条目全部无 `pluginApi`，缺省拒绝会造成 100% 回归（R-04）；收紧属 major，须双侧同轮 |
| ADR-VG-4 | dylib 轨**只预留不接线** | 顺手复活 `PluginDylibLoader` | SPECS_INDEX §7 R-01 明确 dylib 轨在运行时不存在（`unloadDylib` 空实现 `plugin_dylib_loader.cj:146-151`），复活需单独立项与产品决策 |
| ADR-VG-5 | 0 新建表 / 0 新建列 | 新建 `plugin_version` 表持久化版本声明 | 版本声明是静态清单属性，运行时无状态可存；铁律 9 复用优先 |
| ADR-VG-6 | 不新增 `Methods` 常量、不改 `initialize` 方法名 | 新增 `hello` / `negotiate` 方法做两阶段协商 | 会抢改协议骨架，与 `capability-handshake` 的 IF-08 冲突（R-05）；单阶段 `initialize` 增字段即可满足 v1 |
| ADR-VG-7 | 握手拒绝置 `Failed` 而非 `Pending` | 复用 Pending 等待插件改版本重发 | Pending 会让插件周期重发 initialize，形成握手风暴 |
| ADR-VG-8 | 不新增 CLI / 不改生成器模板 | 在 `plugingen` 模板里写死 `pluginApi: ">=1.0.0"` | 生成器产物与静态校验归 `authoring-toolchain`（IF-12）；本子系统只保证解析侧兼容 |

---

## 4. 数据设计

### 4.1 数据模型

本子系统**无持久化数据模型**：版本声明是 `plugin.yaml` 的静态属性，握手版本是单次请求的瞬时载荷。

### 4.2 数据表设计

**0 张新建表 / 0 个新建列**（铁律 9，与 SPECS_INDEX §2「0 新表」登记一致）。

### 4.3 复用论证

| 候选新载体 | 复用替代 | 结论 |
|---|---|---|
| `plugin_version` 表 | `plugin.yaml` → `PluginManifestEntry`（`plugin_config.cj:72-112`） | 复用，直接增列 |
| 新增 `hello`/`negotiate` 方法 | 既有 `Methods.INITIALIZE`（`methods.cj:5-22`） | 复用，只加字段 |
| 握手版本持久化 | `InitializeParams` / `InitializeResult`（`message.cj:10-97`）载荷字段 | 复用，瞬时即可 |
| 观测状态回写 | `PluginSyncBridge` → `agent_skills.runtime_status` / `last_error`（R-06） | **只读复用日志通道，不写这两列**（写入与语义归 `lifecycle-observability`） |

### 4.4 数据关系

无表间关系变更。

---

## 5. API 设计

### 5.1 API 列表

| 方法 | 路径 | 描述 |
|---|---|---|
| — | — | **本子系统不提供任何 HTTP API / 路由，无需 `permissions` + `role_has_permission` 登记** |

### 5.2 API 详细设计

不适用。本子系统全部为**进程内静态调用**与**跨轨载荷字段**，不涉及 HTTP 端点、请求参数、响应状态码。

---

## 6. 接口设计

### 6.1 内部接口

| 编号 | 接口 | 提供方 | 消费方 | 求值方式 |
|---|---|---|---|---|
| IF-01 | `PluginHostApi.CURRENT` / `MIN_COMPAT` / `PROTOCOL_VERSION` / `HOST_VERSION` | version-guard | 全量子系统 | 静态常量 |
| IF-02 | `PluginManifestEntry.version` / `pluginApi` / `hostVersionRange` | version-guard | capability-governance, authoring-toolchain | 字段读取 |
| IF-03 | `VersionGuard.check(entry)` | version-guard | 宿主 `PluginHostManager` / `CordisHostManager` | 静态函数 |
| IF-03R | `VersionGuard.checkDylib(entry)`（预留） | version-guard | 无（运行时零调用） | 静态函数 |
| IF-04 | `InitializeParams.protocolVersion` / `InitializeResult.protocolVersion` / `hostApiVersion` + `VersionGuard.checkHandshake` | version-guard | capability-handshake / 宿主 `PluginHost` | 载荷字段 + 构造注入回调 |

- 接口签名以 `contract.md` §1.1 为冻结态；实现若需偏差，先改契约再改代码。
- 求值方式：IF-01 / IF-02 / IF-03 / IF-03R 为静态常量 / 静态函数直接调用；IF-04 的宿主侧校验入口为**构造注入**（`setProtocolGate`）。

### 6.2 外部接口

| 接口 | 方向 | 说明 |
|---|---|---|
| L3 `initialize` 请求 | 插件 → 宿主 | 载荷新增可选 `protocolVersion: ?Int32`，宿主对缺失零假设（放行 + warn） |
| L3 `initialize` 响应 | 宿主 → 插件 | 载荷新增可选 `protocolVersion` / `hostApiVersion`，供插件侧自检对齐 |
| `plugin.yaml` 清单格式 | 插件作者 → 宿主 | 新增可选 `version` / `pluginApi` / `hostVersionRange`，缺省一律向后兼容 |

---

## 7. 安全设计

### 7.1 认证机制

不适用（无跨进程鉴权面）。握手门禁只判定协议版本，**不承担身份认证**；插件进程仍由既有启动路径（`plugin_manager.cj:98-100`）管控。

### 7.2 权限控制

- 版本校验**先于**任何实例化 / 进程拉起，因此不兼容插件拿不到任何宿主资源句柄。
- 校验失败不写 `contexts` / `classNames` / `routeClasses`，不注册任何 service，避免"半成品插件"残留可被调用。

### 7.3 数据安全

1. 错误文案与日志仅含「插件名 + 期望 + 实际」三要素（spec §4.3.1）。
2. 禁止在版本模块中访问 `getVariables()` / `host.secret` / 环境变量 —— R-03 既有缺陷的修复归 `capability-governance`，本子系统不放大也不重复实现。
3. 版本字符串解析对超长 / 空 / 非数字 / 负数输入返回 `None`，避免解析异常外泄内部状态。

---

## 8. 性能设计

### 8.1 性能目标

| 指标 | 目标 |
|---|---|
| `VersionGuard.check` 单条目 | ≤ 1 ms，零 IO / 零反射 / 零 DB |
| 全量加载版本校验总增量（≈55 条目） | ≤ 10 ms |
| `checkHandshake` 单次 | ≤ 0.1 ms |
| 通过路径日志拼接 | 0 次（仅失败/告警分支拼接） |

### 8.2 优化策略

1. `ApiVersion.parse` 只用整数分段解析，不引入正则 / 不分配中间集合的复杂结构。
2. 通过路径不构造任何文案字符串；批量加载只在 `loadAll` 汇总一条 `info`。
3. `check` 为纯静态函数，无锁、无共享状态，可并行安全调用。
4. 快照仅在条目级失败时用于 `restore`，通过路径无额外分配（`PluginRegistry.snapshot()` 已有实现，`:143`）。

---

## 9. 部署设计

### 9.1 部署架构

无新增进程、无新增端口、无新增配置项。变更全部落在宿主编译图内：

- `libs/plugin-spi`：新增 2 个文件 + 修改 1 个枚举（宿主与插件共用底座）
- `libs/cordis-cj`：修改 2 个文件（协议结构体 + 门禁注入点）
- `src/plugin`：新增 1 个文件 + 修改 3 个文件（清单字段/解析、Sync 接线、Process 接线）

### 9.2 环境配置

| 项 | 值 | 说明 |
|---|---|---|
| `PluginHostApi.CURRENT` | `1.0.0` | 常量，随契约 minor/major 演进 |
| `PluginHostApi.MIN_COMPAT` | `1.0.0` | v1 仅公告，不参与判定 |
| `PluginHostApi.PROTOCOL_VERSION` | `1` | L3 握手线格式版本 |
| `PluginHostApi.HOST_VERSION` | `0.0.29` | 与 `cjpm.toml:18` 人工同步 |

- 无环境变量、无 DB 迁移、无 `sql/incremental/` 变更（0 新表 0 新列）。
- 编译与回归验证由人工在独立 cmd 环境执行，AI 不跑 `cjpm build`。

---

## 10. 附录

### 10.1 风险登记（对齐 SPECS_INDEX §7）

| 编号 | 风险 | 本子系统处置 |
|---|---|---|
| R-01 | dylib 轨运行时不存在 | 只预留 `checkDylib`，不复活、不接线（ADR-VG-4） |
| R-03 | 宿主环境全量泄漏给插件进程 | 不在本子系统修复；版本模块禁止触碰 env / secret（§7.3.2） |
| R-04 | 存量 55 条目防回退 | 缺省放行 + warn；硬验收纳入 spec §4.5.1 与 S-VG-05 |
| R-05 | `InitializeParams` 双子系统抢改 | 本子系统串行先手，只加尾部默认参数（ADR-VG-6 / contract §3.3） |
| R-06 | 观测字段倾向新建列 | 本子系统 0 新列，且不写 `runtime_status` / `last_error` |

### 10.2 与下游的接口移交清单

| 下游 | 其所得 | 其须遵守 |
|---|---|---|
| `capability-governance` | IF-01 常量、IF-02 清单字段 | 不得自建第二份版本常量；按缺省语义处理 `pluginApi == None` |
| `capability-handshake` | IF-04 `protocolVersion` 字段（已冻结） | **串行**：本子系统冻结后再追加 IF-08；不得改既有字段 |
| `authoring-toolchain` | IF-02 字段口径与 `VersionGuard.check` | CLI 自行决定调用方式；本子系统不改生成器模板 |
| `lifecycle-observability` | `plugin.error` 事件中的版本拒绝原因 | 握手拒绝置 `Failed` 的语义不得被自愈逻辑改写为 `Pending` |

### 10.3 参考文档

| 文档 | 路径 |
|---|---|
| 主工程边界账本 | `specs/plugin-system-enhancement/SPECS_INDEX.md` |
| 集成契约 | `specs/plugin-system-enhancement--version-guard/contract.md` |
| 需求规格 | `specs/plugin-system-enhancement--version-guard/spec.md` |
| 任务规划 | `specs/plugin-system-enhancement--version-guard/tasks.md` |
| 存量基线 spec | `.codeartsdoer/specs/plugin-system/spec.md:179` |
| 开发规范源 | `skills/uctoo-dev-manual/` + `docs/uctoo-v4/*.md` |
| 模板 | `skills/sdd/templates/{spec_template,ears-format,design_template,tasks-template}.md` |

### 10.4 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-19 | SDD 文档步执行者 | 初始版本：M1~M10 模块设计 + ADR-VG-1~8 + 风险登记 |
