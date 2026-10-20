# 技术设计文档：能力宣告握手（capability-handshake）

> 模板：`skills/sdd/templates/design_template.md`
> 关联需求：`./spec.md` ｜ 关联契约：`./contract.md`
> 全部 `文件:行号` 取自本仓 2026-10-19 工作区快照；行号漂移时以标识符为准。查不到的标「**待核实**」。
> **不跑 `cjpm build`**：编译与类型检查由人工在独立 cmd 环境完成并回传。

## 文档信息

- **项目名称**：`plugin-system-enhancement--capability-handshake`（主工程 `plugin-system-enhancement`）
- **版本**：v1.0
- **创建日期**：2026-10-19
- **作者**：SDD 文档步（capability-handshake 子系统）
- **状态**：草稿（待子系统闸口 confirm 后转「已批准」）
- **语言**：仓颉（cangjie）

---

## 1. 设计概述

### 1.1 设计目标

1. 让 L3（`mode: process`）插件在 `initialize` 握手中**自报**将注册的 Service / Route / 能力项，宿主与 `plugin.yaml` 声明逐项比对，**超出声明即拒绝挂载**。
2. 把「跨进程不能给的能力」这张表（上游 IF-07）在**拉起前静态预检**与**握手比对**两处**复用同一张表**，实现「公开声明哪些能力不能跨进程 + 静态审计复用同一张表」，且**不另建**表。
3. 拒绝必须可安全落地：**进程未被拉起**（预检阶段）或**已被安全终止**（握手阶段），宿主启动不受影响。
4. 0 新建表、0 新建列、0 新增宿主 HTTP 路由（铁律 9 复用优先）。

### 1.2 设计原则

| 原则 | 落地方式 |
|---|---|
| **复用优先（铁律 9）** | 禁列表用 IF-07、能力枚举用 IF-05、终止用既有 `removePlugin`、路由撤销用既有 `unregisterPluginRoutes`、状态回写用既有 `PluginSyncBridge` 通道；**不新开表/列/枚举** |
| **底座优先（铁律 14）** | 规范源 `uctoo-dev-manual` + `docs/uctoo-v4/*.md`；脚手架 `loaddbinfo`→`plugingen`/`crudgen`→`crudweb`（本子系统无 DB 结构变更与新增路由，故**不触发**脚手架与权限登记） |
| **契约先行（铁律 15）** | 先冻结 `contract.md` 的 IF-08/IF-09/CH-01/CH-02，再动代码；与 `version-guard` 在 `message.cj` 上**串行** |
| **fail-closed + 缺省放行并存** | 「上报了就严格比对（未知从严）」⊕「未上报就放行并告警（防回退 R-04）」 |
| **最小侵入** | 宿主接入点用**构造注入回调**（与 `version-guard` 的 `setProtocolGate` 对称），不改写 cordis 状态机、不改 `Reconciler` 拓扑 |
| **边界自守** | 不碰 `topoSort` / `entryChanged`（归 `dependency-graph`）、不碰崩溃自愈（归 `lifecycle-observability`）、不碰能力枚举与运行时门禁（归 `capability-governance`） |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 编程语言 | 仓颉（cangjie） | 与宿主同源；`libs/cordis-cj/` 为本仓内 vendored 副本（**不在** `.gitmodules` 中），可改但须在修订记录登记「回上游存在偏差」 |
| 握手协议 | 既有 cordis JSON-RPC（`Methods.INITIALIZE`，`methods.cj:7`） | **不新增** `Methods` 常量、`不新增` `hello`/`negotiate`/`declare` 方法 |
| 载荷序列化 | 既有 `JsonSerializable & JsonDeserializable<T>`（`message.cj:10`） | 与 `InitializeParams` 同款，走 `JsonValue.toObject<T>`（`plugin_host.cj:109`） |
| 注入方式 | 构造注入（`PluginHost.setHandshakeVerifier`） | 与 `setProtocolGate` 对称，便于测试替身 |
| 进程终止 | 既有 `PluginHost.removePlugin`（`plugin_host.cj:867`） | 不新增进程管理代码 |
| 路由撤销 | 既有 `ExternalPluginRouteGateway.unregisterPluginRoutes`（`external_plugin_route_gateway.cj:524`） | 复用 |
| 数据库 | **0 新表 0 新列** | 比对输入为进程内对象，结论为派生态 |

---

## 2. 系统架构

### 2.1 架构图

```
                        ┌──────────────────────────────────────────┐
                        │  宿主进程（magic.plugin / ystyle::cordis） │
                        └──────────────────────────────────────────┘

 plugin.yaml ──parse──▶ PluginManifestEntry ──┐
 (provides/                                   │  processEntries: HashMap<id, entry>
  capabilities/                               │  (cordis_host_manager.cj:66, :184-185)
  routes)                                     │
                                              ▼
 插件进程 ──initialize(protocolVersion, provide, declaredCapabilities)──▶ PluginHost
   ▲                                                                        │
   │                                          ① protocolGate (version-guard IF-04)
   │                                          ② handshakeVerifier (本子系统 IF-09)
   │                                                                        ▼
   │                                                            HandshakeDecision
   │                                                          ┌──────┴──────┐
   │                                                          │             │
   │                                                          Ok          Reject
   │                                                           │             │
   │◀────────── InitializeResult(ok / ok=false) ───────────────┘             │
   │                                                                        ▼
   │                                                        transitionStatus(Failed)
   │                                                                        │
   │                                        ┌───────────────────────────────┤
   │                                        ▼                               ▼
   │                            HandshakeSafeTerminator (CH-02)   状态回写（既有通道）
   │                                        │                               │
   │                        ┌───────────────┴──────────┐                    ▼
   │                        ▼                          ▼            agent_skills
   │              unregisterPluginRoutes      PluginHost.removePlugin   runtime_status
   │              (gateway:524)               (plugin_host.cj:867)      /last_error
   │                                                                    （复用，不新增列）
   └──────────── 进程终止（无僵尸） ───────────────────────────────────────

 拉起前（更早的一道闸）：
   loadProcessPlugins ──▶ HandshakeVerifier.auditEntry (CH-01) ──▶ IF-07 禁列表
        │                                                            │
        ├── Reject ──▶ LoadResult.failed，**不 addDesired → 进程未被拉起**
        └── Ok ──────▶ addDesired → reconcileDesired → awaitActive(30s)
```

### 2.2 模块划分

| 模块 | 文件落点 | 契约条目 | 归属 |
|---|---|---|---|
| M1 宣告载荷 | `libs/cordis-cj/cordis_core/src/message.cj`（改动）+ 新增 `declared_capabilities.cj` | IF-08 | 本子系统（与 version-guard **串行**改 `message.cj`） |
| M2 比对器 | 新增 `src/plugin/handshake_verifier.cj` | IF-09 + CH-01 | 本子系统 |
| M3 宿主接入点 | `libs/cordis-cj/cordis_host/src/plugin_host.cj:105-138`（改动，注入回调） | IF-09 挂载 | 本子系统 |
| M4 加载流程接入 | `src/plugin/cordis_host_manager.cj`（改动：预检 + 挂载 verifier + 终止） | CH-01 / CH-02 | 本子系统 |
| M5 安全终止器 | 新增 `src/plugin/handshake_safe_terminator.cj` | CH-02 | 本子系统 |
| M6 路由注册联动 | `src/plugin/plugin_host_manager.cj:143-155`、`:280-298`（改动） | FR-CH-14 | 本子系统 |
| M7 清单声明面 | `src/plugin/plugin_config.cj`（改动，追加 `provides`） | FR-CH-07 输入 | 本子系统（与 version-guard / capability-governance **三方串行**） |

### 2.3 组件交互

1. `CordisHostManager` 构造 `PluginHost` 后：`setProtocolGate(...)`（version-guard）→ `setHandshakeVerifier(...)`（本子系统）。**两个 gate 串行生效**，版本不通过时不再进入能力比对。
2. `loadProcessPlugins`：应急开关过滤 → **CH-01 静态预检** → `addDesired` → `reconcileDesired` → `awaitActive(30s)`。
3. `PluginHost` 的 initialize handler：解析参数 → protocolGate → **handshakeVerifier（IF-09）** → `Active` / `Failed`。
4. 拒绝后：CH-02 终止 + 撤销路由；`awaitActive` 返回 `Err` → `LoadResult.failed` → 宿主继续。

### 2.4 存量能力对比与 GAP（复用优先裁决）

| 现有能力 | 落点 | 是否复用 | 裁决 |
|---|---|---|---|
| `InitializeParams` / `InitializeResult` | `message.cj:10-97` | **复用** | 追加尾部命名默认参数，**不新增** `Methods` 常量 |
| `InitializeParams.provide` | `message.cj:13` | **复用** | 服务维上报面已存在，IF-08 **不重复**承载 |
| 宿主 initialize handler | `plugin_host.cj:105-138` | **复用+扩展** | 只插一个注入回调；既有 `checkMissing` 逻辑不动（依赖检查归 dependency-graph） |
| `PluginHost.removePlugin` | `plugin_host.cj:867` | **复用** | CH-02 直接调，不自实现 kill |
| `ExternalPluginRouteGateway.unregisterPluginRoutes` | `external_plugin_route_gateway.cj:524` | **复用** | 拒绝后撤销路由 |
| `processEntries: HashMap<String, PluginManifestEntry>` | `cordis_host_manager.cj:66`、`:184-185` | **复用** | 声明面真源；**不依赖** `toCordisEntry` 是否填满 `PluginEntry` |
| `installStatusListener` + `mapStatusToState` | `cordis_host_manager.cj:73-81`、`:473-482` | **复用** | `Failed` → `Error` 走既有通道，不新增列 |
| `awaitActive` / `LoadResult.failed` | `cordis_host_manager.cj:216`、`:226-231` | **复用** | 拒绝即 `Err`，宿主继续 |
| 应急开关 `CORDIS_SKIP_PROCESS_PLUGINS` | `cordis_host_manager.cj:149-167` | **复用** | 优先级高于预检，行为不变 |
| `buildCapabilityCatalog` | `skill_bridge.cj:112-125` | **不复用** | 只列技能名（`{"plugin","skills"}`），无服务/权限/资源维度，与被 `plugin_host_manager.inspect:475` 消费的软目录同义；本子系统**不改**它（避免影响 `pluginInspect` 既有输出） |
| `PluginCapability` / `CapabilityPolicy` | capability-governance IF-05 | **复用（只读）** | 不定义、不扩展 |
| `HostUnsupportedCapabilities` | capability-governance IF-07 | **复用（只读）×2 处** | 拉起前 CH-01 + 握手 IF-09；**不另建** |
| `CapabilityGate.check` | capability-governance IF-06 | **不消费** | 运行时门禁与握手比对正交 |

**已验证基线 GAP（直接采信）**：

| GAP | 证据 | 本子系统处置 |
|---|---|---|
| 全仓 `handshake` 零命中 | grep 全仓 → 0 | 新建 M1~M3 |
| `InitializeParams` 无 capabilities / version | `message.cj:10-53` | 追加 IF-08（在 IF-04 之后，**串行**） |
| `Methods` 无 hello/negotiate/declare；`PING`（`methods.cj:13`）无周期性调度 | `methods.cj:5-22`；`plugin_host.cj` | **不新增**方法常量；周期性探活不在本轮 |
| initialize handler 只做 `checkMissing`，无声明比对 | `plugin_host.cj:104-135`（`checkMissing` `:115`） | 插注入回调（M3） |
| `toCordisEntry` 只设 id/source/args | `cordis_host_manager.cj:263-274` | **不碰**（归 dependency-graph）；声明面走 `processEntries` |
| `PluginEntry.inject/provide/config/enabled` 未填 → `topoSort` 恒 no-op、`entryChanged` config 恒等 | `config.cj:16-37`；`plugin_host.cj:984-1010`、`:858-864` | **不碰**（归 dependency-graph） |
| 路由注册**未排除**加载失败插件 | `plugin_host_manager.cj:143-155`（`loadProcessPlugins` 返回后无条件调 `:155`）+ `:288-296`（只判 mode/enabled） | **必须闭环**（M6）：跳过 `procResult.failed` |

---

## 3. 详细设计

### 3.1 M1：宣告载荷 `DeclaredCapabilities`（IF-08）

#### 3.1.1 类设计

```
// libs/cordis-cj/cordis_core/src/declared_capabilities.cj（新增）
public class RouteDecl <: JsonSerializable & JsonDeserializable<RouteDecl> {
    public let method: String        // "GET"|"POST"|"PUT"|"DELETE"，比对前大写归一
    public let path: String          // 精确串，与 ExternalRoute.path 同域
}

public class CapabilityDecl <: JsonSerializable & JsonDeserializable<CapabilityDecl> {
    public let type: String                    // IF-05 type 串（db.read / net.egress / ...）
    public let resources!: Array<String> = []  // 资源标识；空 = 仅能力级
}

public class DeclaredCapabilities <: JsonSerializable & JsonDeserializable<DeclaredCapabilities> {
    public let routes!: Array<RouteDecl> = []
    public let capabilities!: Array<CapabilityDecl> = []
}
```

**关键裁决 —— 为什么 `DeclaredCapabilities` 里没有服务键**：`InitializeParams.provide`（`message.cj:13`）已经是「插件将注册的服务键」的上报面，且与 cordis 的 `provide` 语义同源。再在 IF-08 里放一份会形成**同一语义两处真源**，将来必然漂移。故：
- 服务维度上报面 = **既有 `provide`**（零改动）；
- IF-08 只承载**新增的** routes + capabilities 两维；
- `verify` 第三参 `provide!` 带默认值（契约 §5 已登记为 minor 演进）。

**关键裁决 —— `cordis_core` 不依赖 `magic.security.capability`**：`CapabilityDecl.type` 只以 **字符串** 承载，翻译（`fromCapabilityType`）放在宿主侧 `magic.plugin` 做。避免 vendored 协议层反向依赖宿主安全层。**待核实**：若编译期证明 `cordis_core` 可安全依赖 `plugin_spi`，可改放 `plugin_spi` 包，但 v1 按最保守方案落。

#### 3.1.2 接口设计

| 方法 | 签名 | 说明 |
|---|---|---|
| `toJson` / `fromJson` | 同 `InitializeParams` 款式 | 与 `JsonValue.toObject<T>`（`plugin_host.cj:109`）通路一致 |
| `InitializeParams` 追加字段 | `declaredCapabilities!: ?DeclaredCapabilities = None` | **尾部命名默认参数**，既有构造点零改动 |

#### 3.1.3 数据流

```
插件侧构造 → JSON → InitializeParams.fromJson(:36-53) 追加 case "declaredCapabilities"
   → 解析失败 → None + LogUtils.warn（不拒绝）
   → PluginHost handler 取出 → HandshakeVerifier.verify
```

### 3.2 M2：`HandshakeVerifier`（IF-09 + CH-01）

#### 3.2.1 类设计

```
// src/plugin/handshake_verifier.cj（新增，package magic.plugin）
public enum HandshakeDecision { | Ok | Reject(String) }

public class HandshakeVerifier {
    // CH-01：拉起前静态预检（只读清单，不需要进程）
    public static func auditEntry(entry: PluginManifestEntry): HandshakeDecision
    // IF-09：握手比对
    public static func verify(entry: PluginManifestEntry,
                              declared: ?DeclaredCapabilities,
                              provide!: Array<String> = Array<String>()): HandshakeDecision
}
```

**无状态、无成员字段** —— 纯静态函数，便于单测直接构造 `PluginManifestEntry` 替身；禁列表/能力集每次从上游常量与 entry 现算，不缓存（避免与 `capability-governance` 的 `register/unregister` 生命周期耦合）。

#### 3.2.2 判定流程（顺序固定，不可调换）

```
verify(entry, declared, provide):
  0. if entry.mode != Process            -> return Ok            // 非 L3 轨不比对
  1. if declared == None && provide 空    -> LogUtils.warn; return Ok   // 缺省放行 R-04
  2. effective = CapabilityPolicy.fromManifest(entry)            // IF-05
                 .intersectWithUnsupported(Process)              // CG-05 × IF-07
     —— 取扣减后**有效集**；扣减差异项逐条 WARN
  3. 能力维：for c in declared.capabilities:
        t = PluginCapability.fromCapabilityType(c.type)          // IF-05
        if t == None            -> Reject(dimension=capability, 未知从严)
        if t ∈ IF-07 禁列表      -> Reject(reason = IF-07 说明表原串)   // 禁列表优先
        if t ∉ effective         -> Reject(dimension=capability)
        if c.resources ⊄ effective.resourcesOf(t) -> Reject(dimension=capability, detail=<资源>)
  4. 服务维：for k in provide:
        if k ∉ entry.provides   -> Reject(dimension=service, detail=k)
  5. 路由维：for r in declared.routes:
        m = r.method.toUpper(); p = r.path
        if (m,p) ∉ entry.httpRoutes -> Reject(dimension=route, detail="<m> <p>")
  6. return Ok
```

- **禁列表优先于有效集**：即便上游 CG-05 已扣减，仍显式再判一次 IF-07 —— 防止上游扣减实现变更/未接线时静默放行（纵深防御）。
- **首个失败即返回**，其余失败项逐条 `WARN`（避免原因串爆炸，同时保留完整可诊断信息）。
- **理由串模板**：`handshake rejected: plugin=<id> dimension=<d> detail=<项> reason=<说明>`。

#### 3.2.3 `auditEntry`（CH-01）与 IF-09 的关系

`auditEntry` = 「`verify` 的**无进程**子集」：只跑第 0 步与第 2 步中**命中 IF-07** 的那一次判定，不读任何上报面。实现上**共用同一个 `checkBanned(entry)` 私有函数**，保证两处结论逐字一致（契约 M-04 强制）。

```
auditEntry(entry):
  if entry.mode != Process -> Ok
  banned = HostUnsupportedCapabilities.forMode(Process)      // IF-07，同一张表
  declared = CapabilityPolicy.fromManifest(entry)            // IF-05
  for cap in declared.grantedSet():
      if cap ∈ banned -> Reject(reason = banned.reasonOf(cap))   // 同一张表 + 同一条理由串
  return Ok
```

> **报告要求闭环**：「公开声明哪些能力不能跨进程」= IF-07 常量表（上游提供）；「静态审计复用同一张表」= `auditEntry` 与 `verify` 共用 `checkBanned`。本子系统**不新建**第二张表，且 `authoring-toolchain` 的 `plugin validate` 复用 CH-01 时同样指向 IF-07。

### 3.3 M3：宿主接入点改造（`plugin_host.cj`）

#### 3.3.1 现状

`plugin_host.cj:105-138` 的 `Methods.INITIALIZE` handler：解析 `InitializeParams` → 记 `injects` → `checkMissing(:115)` → `Active`/`Pending` → 返回 `InitializeResult`。**无任何声明比对**。

#### 3.3.2 改造方案（注入式，最小侵入）

```
// PluginHost 新增成员与注入口（与 setProtocolGate 对称）
private var handshakeVerifier: ?(String, InitializeParams) -> ?String = None
public func setHandshakeVerifier(gate: (String, InitializeParams) -> ?String): Unit

// handler 内，在既有 checkMissing 之前插入（顺序：protocolGate → handshakeVerifier → checkMissing）
if (let Some(g) <- this.handshakeVerifier) {
    if (let Some(reason) <- g(providerId, params)) {
        this.transitionStatus(instance, InstanceStatus.Failed)          // 非 Pending
        this.logger(providerId, "handshake rejected: ${reason}")
        // 注：安全终止由 CordisHostManager 侧的状态监听/awaitActive 收口触发（见 §3.4），
        //    避免在 RPC handler 内做阻塞式进程终止
        return Some(JsonValue.fromObject(InitializeResult(false, HashMap<String, String>())))
    }
}
```

- **反馈类型**：`?String` —— `None` 放行 / `Some(reason)` 拒绝。与 `version-guard` 的 `setProtocolGate` 完全同形，两个 gate 可组合。
- **拒绝即 `Failed`**：与 `version-guard` 同口径（`status.cj:14`），避免插件周期重发形成握手风暴。
- **不在 handler 内做阻塞终止**：终止交给 `CordisHostManager`（§3.4），保持 RPC handler 非阻塞。

### 3.4 M4：加载流程接入（`cordis_host_manager.cj`）

#### 3.4.1 拉起前静态预检（CH-01）

插入点：`loadProcessPlugins` 的条目循环内，**`addDesired`(`:198`) 之前**，且在应急开关(`:162`)与 `command` 必填校验(`:169-180`)之后。

```
for entry in list.plugins:
    ...既有 mode/enabled/应急开关/command 校验...
    match (HandshakeVerifier.auditEntry(entry)) {         // ← 新增
        case Reject(reason) =>
            LogUtils.error("[CordisHostManager] process plugin '${entry.name}' rejected before launch: ${reason}")
            result.failed.add("${entry.name}(${reason})")
            continue                                       // 不 addDesired -> 进程未被拉起
        case Ok => ()
    }
    let cordisEntry = this.toCordisEntry(entry)
    desired.add(cordisEntry)
```

#### 3.4.2 挂载 verifier

构造 `PluginHost` 后（`cordis_host_manager.cj:63-65` 附近）追加：

```
this.cordisHost.setHandshakeVerifier({ pluginId, params =>
    let entry = synchronized(this.processLock) { this.processEntries.get(pluginId) }
    match (entry) {
        case Some(e) =>
            match (HandshakeVerifier.verify(e, params.declaredCapabilities, provide: params.provide)) {
                case Ok => None
                case Reject(reason) => Some(reason)
            }
        case None => Some("handshake rejected: plugin=${pluginId} reason=manifest entry not found")
    }
})
```

> 声明面取自 `processEntries`（`:66`，由 `:184-185` 按 pluginId 保存完整 `PluginManifestEntry`）—— **不依赖** `PluginEntry` 是否被填满，故与 `dependency-graph` 的 `toCordisEntry` 改造无耦合、可并行。
> **未知从严**：`processEntries` 查不到条目 → 拒绝（宿主不应为无清单的进程做放行）。

#### 3.4.3 拒绝后安全终止（CH-02）

挂在既有状态监听链上：`installStatusListener`(`:73-81`) 已有 `onStatusChange`。新增一条**专用**监听（不合并进既有两条，避免语义混杂）：

```
this.cordisHost.onStatusChange({ pluginId, oldStatus, newStatus =>
    if (newStatus == InstanceStatus.Failed) {
        HandshakeSafeTerminator.terminate(this.cordisHost, pluginId)
    }
})
```

- 触发源唯一：`Failed` 态。**不订阅** `plugin.crashed` / `plugin.restarted`（归 `lifecycle-observability`）。
- `awaitActive(ce.id, timeout: 30 * Duration.second)`(`:216`) 对 `Failed` 返回 `Err` → `result.failed.add`(`:228`) → 宿主继续下一插件。**既有逻辑零改动**即满足「宿主启动不受影响」。

### 3.5 M5：`HandshakeSafeTerminator`（CH-02）

#### 3.5.1 类设计

```
// src/plugin/handshake_safe_terminator.cj（新增，package magic.plugin）
public class HandshakeSafeTerminator {
    public static func terminate(host: PluginHost, pluginId: String): Unit {
        try {
            this.unmountRoutes(pluginId)        // 撤销已挂路由（幂等）
            host.removePlugin(pluginId)         // 既有终止（plugin_host.cj:867）
            LogUtils.info("[HandshakeSafeTerminator] plugin '${pluginId}' safely terminated")
        } catch (e: Exception) {
            LogUtils.error("[HandshakeSafeTerminator] terminate '${pluginId}' failed: ${e.message}")
            // 不重抛
        }
    }
}
```

- **不新增进程管理代码**：全部能力来自既有 `removePlugin`（内部已含 `Unloading` 转换、事件退订、服务清理）。
- **路由撤销在前**：先摘掉对外可达面，再终止进程，缩小暴露窗口。
- **幂等**：进程已退出 / 实例不存在时捕获异常，记 error 后返回。
- **待核实**：`ExternalPluginRouteGateway` 实例当前在 `registerProcessPluginRoutes`（`plugin_host_manager.cj:287`）内**局部构造**，未在 `CordisHostManager` 侧持有。`unmountRoutes` 需要一条到 gateway 的通路 —— v1 方案有二：① 在 `CordisHostManager` 持有 gateway 引用并在终止时使用（**推荐**）；② 由 `PluginHostManager` 侧监听 `Failed` 后撤销。实现时由人工编译确认后二选一，结论回写本文修订记录。

### 3.6 M6：路由注册联动（`plugin_host_manager.cj`）

#### 3.6.1 GAP 与风险

`plugin_host_manager.cj:143-155`：`loadProcessPlugins` 返回后**无条件**调用 `registerProcessPluginRoutes(list, mgr)`(`:155`)；而 `:288-296` 只按 `mode == Process && enabled` 过滤，**不排除加载失败者**。
→ **握手失败的插件，其 `httpRoutes` 仍会被挂到宿主 Router**，形成对外可达的攻击面，且进程已死会转发失败。这是本子系统必须闭环的安全缺口（FR-CH-14 / DFX-CH-S4）。

#### 3.6.2 改造方案（最小改动）

```
// :143-155 区域
let procResult = mgr.loadProcessPlugins(list)
...
let failedIds = HashSet<String>(procResult.failed.toArray())   // ← 新增
this.registerProcessPluginRoutes(list, mgr, failedIds)         // ← 新增第三参

// :280-298
private func registerProcessPluginRoutes(list: PluginList, mgr: CordisHostManager,
                                         failedIds!: HashSet<String> = HashSet<String>()): Unit {
    ...
    for (entry in list.plugins) {
        if (entry.mode != PluginMode.Process || !entry.enabled) { continue }
        if (failedIds.contains(entry.name)) {                   // ← 新增
            LogUtils.warn("[PluginHostManager] skip route registration for failed plugin '${entry.name}'")
            continue
        }
        if (entry.httpRoutes.size > 0) { ... }
    }
}
```

- 保持 `:173-175` 注释中强调的**非幂等**约束：本改动只做**减法**（跳过），不引入重复注册。
- `reconcile`（`:250`）增量路径同样传入失败集；若该路径下已先注册后拒绝，则由 CH-02 的 `unmountRoutes` 撤销。

### 3.7 M7：清单声明面 `provides`（`plugin_config.cj`）

- 在 `PluginManifestEntry`（`plugin_config.cj:72`）追加 `public var provides: ArrayList<String> = ArrayList<String>()`。
- 在既有解析函数（`:122-208`）内追加 `case "provides" =>` 分支，解析字符串数组；类型不符 → 回落空数组 + `LogUtils.warn`（沿用既有「静默跳过」风格，`:161-165`，**不改**既有行为）。
- **三方串行**：`version-guard`（`version`/`pluginApi`/`hostVersionRange`）→ `capability-governance`（`capabilities`）→ 本子系统（`provides`）。本子系统排在最后，只追加一个字段与一个 case 分支。
- **新暴露的共享冲突面**：主工程 `SPECS_INDEX` §4 目前只登记了 `message.cj` 一处，**本设计提出补登记请求**（契约 §3.3 已同步）。

---

## 4. 数据设计

### 4.1 数据模型（新增，均为**进程内对象**）

`DeclaredCapabilities` / `RouteDecl` / `CapabilityDecl` / `HandshakeDecision` / `PluginManifestEntry.provides` —— 约束见 `spec.md` §6。

### 4.2 数据表设计

**0 新表、0 新列。** 论证：

| 候选持久化需求 | 为什么不需要建表/列 |
|---|---|
| 插件上报的宣告内容 | 每次握手重新上报，进程重启即重建；持久化 = 缓存易失态，无收益 |
| 比对结论 | 派生态，随生命周期事件重算；拒绝结论已通过 `LoadResult.failed` + `LogUtils` + `agent_skills.last_error` 三处既有载体表达 |
| 跨进程禁列表 | 上游 IF-07 常量表（代码常量），**不落库** |
| 握手失败观测 | 复用 `agent_skills.runtime_status` / `last_error`（`SPECS_INDEX` R-06）；本子系统只让 `Failed` 映射到既有 `PluginState.Error` |

**因此**：
- `sql/incremental/` **无新增 DDL**；
- `permissions` / `role_has_permission` **无新增登记行**（本子系统不新增任何宿主 HTTP 路由）；
- 若实现中发现确需新列，须**先回主工程 `SPECS_INDEX` §6 登记**并写明复用不成立理由，再走 `loaddbinfo` → `crudgen`/`plugingen` → `crudweb`，禁止手写 DDL。

### 4.3 数据关系

```
PluginManifestEntry 1 ── 1 provides(1:N String)         // 新增字段
PluginManifestEntry 1 ── 1 httpRoutes(1:N ExternalRoute)  // 既有，plugin_config.cj:112
PluginManifestEntry 1 ── 1 CapabilityPolicy ── N PluginCapability   // 上游 IF-05
InitializeParams    1 ── ?1 DeclaredCapabilities
DeclaredCapabilities 1 ─ N RouteDecl ; 1 ─ N CapabilityDecl
InitializeParams    1 ── 1 provide(1:N String)          // 既有，message.cj:13

比对：DeclaredCapabilities + provide  ⊆  (provides ∪ httpRoutes ∪ effectiveCapabilitySet)
拒绝：HandshakeDecision.Reject ── 1 agent_skills.last_error 行（经既有 PluginSyncBridge）
```

---

## 5. API 设计

### 5.1 API 列表

本子系统**不提供任何 HTTP API**（比对是进程内调用 + 既有 `initialize` RPC，不产生新端点）。

| 类别 | 标识 | 契约条目 | 描述 |
|---|---|---|---|
| L3 跨轨载荷 | `InitializeParams.declaredCapabilities` | IF-08 | 握手上行宣告（routes + capabilities） |
| 进程内 | `HandshakeVerifier.verify` | IF-09 | 三维比对，返回 `HandshakeDecision` |
| 进程内 | `HandshakeVerifier.auditEntry` | CH-01 | 拉起前静态预检，复用 IF-07 |
| 进程内 | `HandshakeSafeTerminator.terminate` | CH-02 | 拒绝后安全终止 + 撤销路由 |
| 进程内 | `PluginHost.setHandshakeVerifier` | IF-09 挂载 | 构造注入 `(pluginId, InitializeParams) -> ?String` |

### 5.2 详细设计（以 IF-09 为核心）

- **请求**：`(entry: PluginManifestEntry, declared: ?DeclaredCapabilities, provide!: Array<String> = [])`
- **响应**：`HandshakeDecision`
  - `Ok` —— 放行
  - `Reject(reason: String)` —— `reason` 必非空，模板见 §3.2.2
- **错误约定**：比对本身**不抛错**、**不自造错误码**；拒绝经宿主 handler 转成 `InitializeResult(ok=false)` + 日志 + 既有 `plugin.error` 事件。
- **幂等性**：纯函数，同一输入恒得同一输出；重复握手不产生副作用。

---

## 6. 接口设计

### 6.1 内部接口

见 §5.1 表 + `contract.md` §1 完整表格（IF-08 / IF-09 / CH-01 / CH-02）。

`verify` 内部私有函数（不对外）：
- `checkBanned(entry): Option<String>` —— 命中 IF-07 即返回理由串（**CH-01 与 IF-09 共用**）
- `effectiveCaps(entry): HashMap<PluginCapability, ArrayList<String>>` —— IF-05 × CG-05 后的有效集
- `normRoute(method, path): (String, String)` —— method 大写归一 + path 精确串

### 6.2 外部接口（跨子系统）

| 方向 | 对象 | 内容 | 稳定性承诺 |
|---|---|---|---|
| 入（我依赖） | `version-guard` IF-04 | `InitializeParams.protocolVersion` 字段与其先行冻结 | 单向；我只追加字段、不判定版本 |
| 入（我依赖） | `capability-governance` IF-05 | `PluginCapability` type 串 + `fromCapabilityType` | v1 冻结；新增枚举要素属 minor，本子系统零改动支持 |
| 入（我依赖） | `capability-governance` IF-07 | `HostUnsupportedCapabilities.forMode(Process)` + 每项理由串 | v1 冻结；**本子系统两处复用，不另建** |
| 入（我依赖） | `capability-governance` CG-05 | `intersectWithUnsupported(Process)` 有效集 | **待提升为 `IF-07a`**（契约 §3.1 已提出请求）；否则退化为本地等价求差，结果必须一致 |
| 出（被消费） | 宿主 `PluginHost` / `CordisHostManager` | IF-08 / IF-09 / CH-01 / CH-02 | v1 冻结 |
| 出（可选被消费） | `authoring-toolchain` | CH-01 静态预检（`plugin validate` 复用） | 消费前须在 `SPECS_INDEX` §3 提升为 `IF-xx` 并过闸口 |

> **显式不**：不 import `capability-governance` 的 `CapabilityGate`；不 import `dependency-graph` / `lifecycle-observability` 的任何符号；不 import `authoring-toolchain`。违反按 `contract.md` §3.2 判 P0。

---

## 7. 安全设计

### 7.1 认证机制

不适用 —— 插件身份由 cordis 握手建立，`pluginId` 在 handler 闭包中绑定（同 `capability-governance` §8.1）。本子系统不另行认证。

### 7.2 权限控制（本子系统的核心）

1. **声明即边界**：`plugin.yaml` 声明面是唯一授权边界，上报面不得越界。
2. **未知从严**：未知能力 type、查不到清单条目 → 拒绝（fail-closed）。
3. **禁列表单一真源 + 两处复用**：IF-07 在「拉起前」与「握手时」各判一次，共用同一函数与同一理由串；全仓不存在第二份禁列表。
4. **路由最高危**：路由挂载即对外暴露 HTTP 面，故判定最严（method + path 双命中），且挂载必须晚于握手结论（DFX-CH-S4）。
5. **不改行级权限语义**：既有宿主侧附加保持原样，本子系统只在其之前加一道。

### 7.3 数据安全

- 拒绝原因串**禁止**回显凭证明文、环境变量值、宿主敏感路径（对齐 `capability-governance` S-04）。
- 拒绝原因串会经既有通道落入 `agent_skills.last_error`，故脱敏是**持久化前**的硬要求，不只是日志要求。

### 7.4 审计与留痕

每次拒绝 → ① `LogUtils.error`（含 `handshake rejected:` 前缀）→ ② 既有 `plugin.error` 生命周期事件（`plugin_host_manager.cj:499-506`）→ ③ `agent_skills.runtime_status` / `last_error`。**不新增**审计表、`不重复`落 `operate_log`（该职责归 `capability-governance` 的 CG-03）。

---

## 8. 性能设计

### 8.1 性能目标

- 握手比对在单次 `initialize` 请求内完成，复杂度 = O(上报项数)。
- 不引入任何常驻/周期性任务；`awaitActive` 30s 超时（`:216`）保持不变。

### 8.2 优化策略

- **有效集现算不缓存**：能力集条目数极少（≤8 类 × 少量资源），现算成本远低于缓存一致性维护成本，且避免与上游 `register/unregister` 生命周期耦合。
- **短-circuit**：首个失败项即返回，不做全量比对。
- **拉起前预检前置**：命中禁列表的插件**根本不启动进程**，节省一次进程创建 + 30s 超时等待 —— 这是本设计最大的性能收益。

---

## 9. 部署设计

### 9.1 部署架构

无新增部署单元。全部改动随宿主二进制发布；`libs/cordis-cj/` 为 vendored 副本，随仓编译。

### 9.2 环境配置

| 配置项 | 行为 | 备注 |
|---|---|---|
| `CORDIS_SKIP_PROCESS_PLUGINS` | 命中的插件仍被跳过（既有，`:149-167`） | 优先级**高于**预检与握手；本子系统不改动其语义 |
| （无新增环境变量） | —— | 本子系统**不新增**开关；「整体关闭握手比对」的开关**待核实**是否需要：v1 不提供，避免形成绕过安全闸口的后门。若运维确需，须回主工程 §6 登记后另议 |

**灰度与回滚**：本子系统改动集中在 3 个新增文件 + 4 个既有文件的局部插入；回滚 = 摘除 `setHandshakeVerifier` 注入与预检调用两处，即可退回现状行为（缺省放行路径保证存量不受影响）。

---

## 10. 附录

### 10.1 参考文档

| 文档 | 用途 |
|---|---|
| `specs/plugin-system-enhancement/SPECS_INDEX.md` | 权威边界账本（§2 登记行、§3 IF-08/IF-09、§4 共享文件预警 R-05、§5 L2 冒烟、§7 R-04/R-05） |
| `specs/plugin-system-enhancement--version-guard/contract.md` | IF-04 字段与 `setProtocolGate` 注入范式、§3.3 串行约定 |
| `specs/plugin-system-enhancement--capability-governance/contract.md` / `design.md` | IF-05 枚举与 type 串（`design.md:212-222`）、IF-07 禁列表与理由串（`:367-380`）、CG-05 有效集（`:258`） |
| `skills/uctoo-dev-manual/` + `docs/uctoo-v4/*.md` | 规范源（本轮无 DB 结构变更与新增路由，未触发具体章节） |
| `skills/sdd/templates/{spec_template,design_template,tasks-template,subsystem-contract-template,ears-format}.md` | 模板与 EARS 句式 |

### 10.2 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-19 | SDD 文档步（capability-handshake） | 初始版本：M1~M7 模块设计；判定口径「上报 ⊆ 声明」+ 缺省放行；IF-07 两处复用；硬条件（未拉起/已安全终止）落地路径；0 新表 0 新列 |

### 10.3 开放项（**待核实**）

| 编号 | 开放项 | 处置 |
|---|---|---|
| O-1 | `DeclaredCapabilities` 放 `cordis_core` 还是 `plugin_spi`；`Array<T>` 默认参数写法是否可编译 | v1 按「放 `cordis_core` + type 以字符串承载」最保守方案落；由人工编译确认后回写 |
| O-2 | CH-02 的 `unmountRoutes` 到 `ExternalPluginRouteGateway` 的通路（gateway 现为 `plugin_host_manager.cj:287` 局部构造） | 推荐方案 ①（在 `CordisHostManager` 持有 gateway 引用）；由人工编译确认后二选一并回写 |
| O-3 | CG-05（`intersectWithUnsupported`）作为 capability-governance **内部**接口被跨子系统消费，须提升为 `IF-07a` | 契约 §3.1 已提出请求；若主工程不提升，退化为本地等价求差，结果必须一致 |
| O-4 | `plugin_config.cj` 三方共享（`version-guard` / `capability-governance` / 本子系统）未登记在主工程 §4 | 已提出补登记请求（契约 §3.3）；未登记不得开工 |
| O-5 | 是否需要「整体关闭握手比对」的运维开关 | v1 不提供（避免安全后门）；确需须回主工程 §6 登记 |
| O-6 | process 插件自有路由是否需逐条登记 `permissions` | 存量行为，本轮不改；确需须回主工程 §6 登记后另立任务 |
