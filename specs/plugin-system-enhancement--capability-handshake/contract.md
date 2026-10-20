# 子系统集成契约（capability-handshake）

> 模板：`skills/sdd/templates/subsystem-contract-template.md`
> 产出阶段：`spec` / `design` 步（子系统的文档步产出，属该子系统工程内部）
> 被谁消费：主工程 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 集成契约汇总 + 下游子系统的 tasks.md / 编码步 + 宿主 `CordisHostManager` / `PluginHost` 编码步
> 铁律依据：**铁律 15**（大工程拆分：集成契约先定、先改契约再改实现）

> 契约是**承诺**，不是设计说明。本文件在子系统实现开工前冻结；
> **禁止**在实现里单边改动契约——要改就走 §5 的演进档位，双侧同轮完成。

## 文档信息

| 项 | 值 |
|---|---|
| 所属主工程 | `plugin-system-enhancement` |
| 子系统 ID | `capability-handshake`（稳定标识，跨轮次不变，改名等同于新建子系统） |
| 子系统 `feature_name` | `plugin-system-enhancement--capability-handshake`（双连字符；与 `sdd_projects` 唯一键对齐） |
| 契约版本 | `v1` |
| 冻结日期 | 2026-10-19 |
| 冻结状态 | **草案**（待主工程闸口 `confirm` 后转「已冻结」） |
| 语言标签 | `cangjie` |
| 验收档位 | L1 + L2 + L3 |
| 上游依赖 | **① `version-guard v1`** —— 消费 **IF-04**（`InitializeParams.protocolVersion`）；**② `capability-governance v1`** —— 消费 **IF-05**（`PluginCapability` 枚举与 type 串）、**IF-07**（`HostUnsupportedCapabilities` 跨进程禁列表及其说明表）、**CG-05**（`intersectWithUnsupported(Process)` 扣减后的有效 policy） |
| 下游消费方 | ① 宿主 `CordisHostManager` / `PluginHost`（消费 IF-08 / IF-09 / CH-01 / CH-02）；② 宿主状态监听 `installStatusListener`（消费拒绝后的状态回写）；③ `authoring-toolchain`（**可选**消费 CH-01 做 `plugin validate` 静态体检，消费前须按 §1 注记提升为 `IF-xx`） |
| 新建数据库表 | **0 张、0 新列** |
| 全局接口计数 | 合计 **4 个**接口，其中 **2 个**登记主工程 §3（IF-08 / IF-09），**2 个**为子系统内部（CH-01 / CH-02） |

> 全部行号取自本仓 2026-10-19 工作区快照；行号随后续提交漂移时**以标识符为准**。

---

## 1. 本子系统提供什么（能力清单）

**类型口径**：
- IF-08 = **L3 插件跨轨**（cordis JSON-RPC 握手载荷字段，随 `Methods.INITIALIZE` 上行）。
- IF-09 / CH-01 / CH-02 = **进程内调用**。求值方式统一为**构造注入**：`CordisHostManager` 构造 `PluginHost` 后调用 `PluginHost.setHandshakeVerifier(...)` 注入判定回调（与 `version-guard` 的 `setProtocolGate` 完全对称，见 `version-guard/contract.md` §1 类型口径说明），下游测试可注入「恒放行 / 恒拒绝」假 verifier 做替身。

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| **IF-08** | L3 插件跨轨（握手载荷字段） | `ystyle::cordis_core.InitializeParams.declaredCapabilities: ?DeclaredCapabilities`；结构体 `ystyle::cordis_core.DeclaredCapabilities` | `DeclaredCapabilities.toJson(w)` / `fromJson(r)` | 握手载荷 JSON：`{"routes":[{"method":"POST","path":"/api/..."}],"capabilities":[{"type":"db.read","resources":["agent_skills"]}]}` | `?DeclaredCapabilities`（`None` = 插件未上报） | 载荷解析失败 → **回落 `None` + `LogUtils.warn`**，不抛异常、不直接拒绝（防回退 R-04，与 `version-guard` IF-04 缺省放行口径一致） | 是（纯解析，无副作用） | **对外**。只承载 **routes + capabilities** 两个维度；**服务维度复用既有 `InitializeParams.provide`**（`message.cj:13`），IF-08 **不重复承载**，避免同一语义出现两处真源 |
| **IF-09** | 进程内调用 | `magic.plugin.HandshakeVerifier` | `verify(entry: PluginManifestEntry, declared: ?DeclaredCapabilities, provide: Array<String>): HandshakeDecision` | 清单条目 + 上报宣告（+ 既有 `provide` 服务键） | `HandshakeDecision` = `Ok` \| `Reject(reason: String)` | 拒绝 → `InitializeResult(ok=false)` + 实例置 `InstanceStatus.Failed`（**不**置 `Pending`，避免插件周期重发形成握手风暴）；`reason` 必非空且统一含 `handshake rejected:` 前缀。**不自造错误码** | 是（纯函数；同一 (entry, declared) 恒得同一决策） | **对外**。判定口径 = 「上报 ⊆ 声明」，三项维度逐一比对：能力 / 服务 / 路由 |
| **CH-01** | 进程内调用（静态预检，拉起前） | `magic.plugin.HandshakeVerifier` | `auditEntry(entry: PluginManifestEntry): HandshakeDecision` | 单个 `PluginManifestEntry` | `HandshakeDecision` | 命中 IF-07 禁列表 → `Reject`，**在 `addDesired` 之前返回**，`LoadResult.failed` 记录，**进程未被拉起** | 是 | 子系统内。**复用 capability-governance IF-07 同一张表**，本子系统**不另建**禁列表；拒绝理由串**直接取用** IF-07 说明表提供的文案（见 `capability-governance/design.md:380`） |
| **CH-02** | 进程内调用（安全终止） | `magic.plugin.HandshakeSafeTerminator` | `terminate(host: PluginHost, pluginId: String): Unit` | `(PluginHost 引用, 插件 id)` | `Unit` | 终止失败（进程已退出 / 实例不存在）不得抛异常穿透，记 `LogUtils.error` 后继续 | 是（重复调用无副作用） | 子系统内。内部**复用**既有 `PluginHost.removePlugin(id)`（`plugin_host.cj:867`）与 `ExternalPluginRouteGateway.unregisterPluginRoutes(pluginId)`（`external_plugin_route_gateway.cj:524`），**不新增进程管理代码** |

**接口计数对账**：合计 **4 个**接口 —— 2 个登记主工程 §3（IF-08 / IF-09，与 `SPECS_INDEX.md:55` 登记的「v1 / 4 接口 / 0 新表」一致），2 个子系统内（CH-01 / CH-02）。
CH-* 当前**仅宿主消费**，无跨子系统消费方，故不占 §3 全局行。若将来 `authoring-toolchain` 的 `plugin validate`（IF-12）要复用 CH-01 做静态体检，**必须先在 `SPECS_INDEX` §3 提升为 `IF-xx` 并过闸口**；禁止在实现里直接 import（按依赖漂移 P0 计）。

**错误约定（红线）**：
- 跨子系统**不得自造错误码**。本子系统只产出**原因串 `reason`**，由宿主侧转成既有结构：
  - 握手响应：`InitializeResult(ok=false)`（`message.cj:60-69` 既有类，不新增方法常量）；
  - 宿主日志 / 状态回写：`LogUtils.error` + 既有 `plugin.error` 生命周期事件（`plugin_host_manager.cj:499-506`）；
  - 加载结果：`LoadResult.failed.add("${name}(${reason})")`（既有形状，`cordis_host_manager.cj:228`）。
- 拒绝原因串统一模板：`handshake rejected: plugin=<id> dimension=<capability|service|route> detail=<具体项> reason=<说明>`；**禁止**回显凭证明文、环境变量值或宿主敏感路径（对齐 `capability-governance` 的 S-04）。
- 门禁/握手拒绝**不得**抛异常穿透到 cordis RPC 层（对齐 `SPECS_INDEX` §5 L2 冒烟第 4 条「插件进程不残留、无僵尸进程」）。

### 1.1 接口签名（冻结态，仓颉）

```cangjie
// libs/cordis-cj/cordis_core/src/message.cj（改动，package ystyle::cordis_core）—— IF-08
// 在 version-guard 冻结 IF-04（protocolVersion）之后追加，串行，见 §3.3
public class DeclaredCapabilities <: JsonSerializable & JsonDeserializable<DeclaredCapabilities> {
    public let routes: Array<RouteDecl>
    public let capabilities: Array<CapabilityDecl>
    public init(routes!: Array<RouteDecl> = Array<RouteDecl>(),
                capabilities!: Array<CapabilityDecl> = Array<CapabilityDecl>()) { ... }
    // 注：服务维度不在此承载，沿用 InitializeParams.provide（message.cj:13）
}

public class RouteDecl      { public let method: String; public let path: String }   // 与 ExternalRoute 同形
public class CapabilityDecl  { public let type: String; public let resources: Array<String> }  // type 取 IF-05 的 type 串

public class InitializeParams <: JsonSerializable & JsonDeserializable<InitializeParams> {
    public let id: String
    public let inject: Array<String>
    public let provide: Array<String>                        // 既有：服务维度上报面
    public let config: ?HashMap<String, JsonValue>
    public let protocolVersion: ?Int32                       // IF-04（version-guard 先冻结）
    public let declaredCapabilities: ?DeclaredCapabilities   // IF-08（本子系统后追加）
    // 追加一律用「尾部命名默认参数」，既有构造点零改动（对齐 version-guard §3.3）
}

// src/plugin/handshake_verifier.cj（新增，package magic.plugin）—— IF-09 / CH-01
public class HandshakeVerifier {
    public static func auditEntry(entry: PluginManifestEntry): HandshakeDecision          // CH-01，拉起前静态预检
    public static func verify(entry: PluginManifestEntry,
                              declared: ?DeclaredCapabilities,
                              provide!: Array<String> = Array<String>()): HandshakeDecision  // IF-09
}

public enum HandshakeDecision {
    | Ok
    | Reject(String)   // reason，必非空
}

// src/plugin/handshake_safe_terminator.cj（新增，package magic.plugin）—— CH-02
public class HandshakeSafeTerminator {
    public static func terminate(host: PluginHost, pluginId: String): Unit
}
```

> **待核实（编译期）**：`Array<T>` 默认参数写法、以及 `DeclaredCapabilities` 放在 `cordis_core` 还是 `plugin_spi`，须由人工编译确认；若 `cordis_core` 不允许依赖 `magic.security.capability`，则 `CapabilityDecl.type` 仅以 **字符串** 承载，由宿主侧 `magic.plugin` 调 `PluginCapability.fromCapabilityType` 翻译（本契约按此最保守方案落，见 §3.1 注）。

### 1.2 宣告比对规则（冻结态）

| 维度 | 上报面（插件侧） | 声明面（plugin.yaml 侧） | 判定规则 | 不匹配时的处置 |
|---|---|---|---|---|
| 能力 capability | `DeclaredCapabilities.capabilities[].type` + `resources` | `entry.capabilities`（由 capability-governance IF-05 解析）经 **CG-05** 扣除 IF-07 后的**有效集** | 每项 `type` ∈ 有效集 **且** `resources` ⊆ 该 type 的授予清单 | `Reject`，dimension=capability |
| 服务 service | 既有 `InitializeParams.provide[]` | `entry.provides`（**本子系统新增**清单字段，见 §3.3） | `provide` 每项 ∈ `entry.provides` | `Reject`，dimension=service |
| 路由 route | `DeclaredCapabilities.routes[]`（method 大写归一 + path 精确串） | `entry.httpRoutes`（既有，`plugin_config.cj:112`，元素 `ExternalRoute(method,path)`） | 每项 ∈ `entry.httpRoutes`（**method + path 同时命中**） | `Reject`，dimension=route |
| **缺省（未上报）** | `declaredCapabilities == None` 且 `provide` 为空 | 任意 | **放行 + `LogUtils.warn`** | 不适用 |

- **判定口径是「上报 ⊆ 声明」（不得超出声明），不是「相等」**。理由：存量 51 个 skill 插件 + 4 个 sync 插件的 `plugin.yaml` 无 `provides`、插件侧也不上报宣告，若按「相等」判定将造成全量回归（**R-04 防回退硬约束**）。
- **少报无害**：插件未上报的能力/路由/服务，宿主侧本就不会为其开通，且运行时还有 `capability-governance` 的 IF-06 门禁兜底；**多报才是风险**（多报 = 试图拿到未声明的东西），故只禁「超出声明」。
- **IF-07 命中即拒绝**：任一 `type` 属 `HostUnsupportedCapabilities.forMode(Process)`，无论清单是否声明，一律 `Reject`（且 CH-01 会在**拉起前**就拒掉）。
- 三项维度**逐项独立判定**，任一项失败即整体 `Reject`；`reason` 只报**首个**失败项（避免日志爆炸），全量失败项由 WARN 逐条记录。

---

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| `agent_skills` | **读**（取清单与既有状态）+ **经既有通道回写** `runtime_status` / `last_error`（复用 `installStatusListener` → `notifyStatusListener`，`cordis_host_manager.cj:73-81`；映射 `mapStatusToState`，`:473-482`） | 不改列结构 | — | 沿用 `row-level-permission-system.md`；本子系统**不新增**任何 `creator` / `owner_user_id` 解释 | 沿用既有 |
| `permissions` | **不读写** | — | — | — | — |
| `role_has_permission` | **不读写** | — | — | — | — |
| `operate_log` | **不直接写**（拒绝留痕走宿主既有 `plugin.error` 事件 + `LogUtils`；是否落 `operate_log` 由 `capability-governance` 的 CG-03 统一负责，本子系统不重复落一份） | — | — | — | — |

**红线声明（铁律 9 复用优先）**：
- 本子系统**新建表 0 张、新建列 0 列**。宣告比对的全部输入都是**进程内对象**（`PluginManifestEntry` + 握手载荷），比对结论是**派生态**（`HandshakeDecision`），二者都不需要持久化载体。
- 观测/状态回写**复用**既有 `PluginSyncBridge` 通道与 `agent_skills.runtime_status` / `last_error`（对齐 `SPECS_INDEX` R-06）；本子系统只让「握手失败」这一新态**映射到既有 `PluginState.Error`**，不新增状态枚举值、不新增列。
- 由于无新增表/列：**`sql/incremental/` 无新增 DDL**。
- 由于本子系统**不新增任何宿主 HTTP 路由**（比对是进程内调用 + 既有 `initialize` RPC，不产生新 HTTP 端点）：**`permissions` / `role_has_permission` 无新增登记行**。
- 关联提示（**不在本子系统范围**）：process 插件的 `httpRoutes` 经 `ExternalPluginRouteGateway` 挂到宿主 Router 后，这些**插件自有路由**当前是否需要逐条登记 `permissions` 属存量行为，本轮不改；若后续要求显式登记，须回主工程 §6 登记后另立任务。

---

## 3. 依赖方向

### 3.1 我依赖的上游（有限名单）

1. **`version-guard v1`** —— 依赖 **IF-04**：`InitializeParams.protocolVersion` 字段与其宿主侧注入方式 `setProtocolGate`。本子系统**在其之后**追加 IF-08，**不改动** `protocolVersion` 的任何语义，**不消费** IF-01/IF-02/IF-03。
2. **`capability-governance v1`** —— 依赖 **IF-05**（`PluginCapability` 枚举与 type 串：`db.read` / `db.write` / `net.egress` / `fs.read` / `fs.write` / `proc.spawn` / `env.read` / `secret.read`）、**IF-07**（`HostUnsupportedCapabilities.forMode(Process)` 禁列表 + 每个条目的**说明/理由串**）、**CG-05**（`CapabilityPolicy.intersectWithUnsupported(Process)` 返回扣减后的有效 policy）。
   - **不消费 IF-06（`CapabilityGate.check`）**：运行时门禁是「每次调用时判」，本子系统是「一次握手时判」，两者语义正交；本子系统**不调用** `check`、不读 `CapabilityGate` 注册表。
   - **待核实**：`CG-05` 属 capability-governance 的内部接口。本子系统按其 `contract.md` §1 注记（「CG-* 若被跨子系统消费须先提升为 IF-xx 并过闸口」）——本文冻结即视为**已提出提升请求**，实现前须由主工程在 §3 追加一行 `IF-xx`（建议 `IF-07a`，语义 = 「按 mode 扣减后的有效能力集」），否则退化为「本子系统自行调 `fromManifest` + IF-07 求差」的等价实现（结果必须一致）。

### 3.2 我不依赖谁（明确保留位）

- **不依赖 `capability-governance` 的 CG-01 / CG-02 / CG-03 / CG-04 / CG-06**。能力注册/注销、审计 sink、env 收窄、存量降级推导全部与握手比对无关；本子系统只读「清单 → 有效能力集」这一静态推导结果。
- **不依赖 `dependency-graph`**。`toCordisEntry`（`cordis_host_manager.cj:263-274`）当前未填 `inject` / `provide` / `enabled`，导致 `topoSort` 对宿主恒为 no-op —— 该修复**归 `dependency-graph`（IF-10）**，本子系统**不碰**；本子系统读声明面走 `processEntries`（`cordis_host_manager.cj:66`，`:184-185` 已按 pluginId 保存完整 `PluginManifestEntry`），不依赖 `PluginEntry` 是否被填满。
- **不依赖 `lifecycle-observability`**。握手失败置 `Failed` 是为**避免握手风暴**（与 `version-guard` IF-04 同口径），**不是**自愈策略；退避/计数/熔断归 IF-11，本子系统不订阅 `plugin.crashed` / `plugin.restarted`。
- **不依赖 `authoring-toolchain`**。`plugin validate`（IF-12）是否复用 CH-01 由它单方决定，本子系统不反向调用它。
- **不依赖 `dylib` 轨**（`SPECS_INDEX` R-01）。本子系统只对 `PluginMode.Process` 生效；`Sync` / `Dylib` 条目在 `auditEntry` / `verify` 中一律直接返回 `Ok`。
- **禁止成环**：本子系统与全部上游均为单向。出现反向 import 即判依赖漂移，按 P0 计。

### 3.3 共享文件冲突约定（R-05，强制执行）

| 共享文件 | 共同改动方 | 串行约定 |
|---|---|---|
| `libs/cordis-cj/cordis_core/src/message.cj` 的 `InitializeParams` | `version-guard`（IF-04）→ **本子系统**（IF-08） | **version-guard 先冻结 `protocolVersion`，本子系统再追加 `declaredCapabilities`，串行、禁止并行**（`SPECS_INDEX.md:104-105`）。双方一律用**尾部命名默认参数**追加（既有 `config!: ?HashMap<...> = None` 同款，`message.cj:17`），既有位置参数与既有构造点零改动；任一侧改为必填位置参数即判 **major**，须双侧同轮。 |
| `src/plugin/plugin_config.cj` 的 `PluginManifestEntry` 解析函数（`:122-208`） | `version-guard`（`version` / `pluginApi` / `hostVersionRange`）→ `capability-governance`（`capabilities` 块）→ **本子系统**（`provides` 列表） | **新发现的第三方共享**，主工程 `SPECS_INDEX` §4 目前只登记了 `message.cj` 一处，**本契约提出补登记请求**。约定同样**串行**：本子系统排在 `capability-governance` 之后，只追加一个 `provides: ArrayList<String>` 字段与对应 YAML 分支，**不动**既有字段解析、不改既有「类型不符静默跳过」行为（`plugin_config.cj:161-165`）。 |

> 上述第二行属本子系统新暴露的共享冲突面，实现开工前须回主工程 `SPECS_INDEX.md` §4 / §6 补登记；未登记即改按契约漂移 P0 计。

---

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| 能力枚举 `PluginCapability` 与缺省策略 `CapabilityPolicy` | `capability-governance`（IF-05） | 本子系统只**读**其 type 串做比对，**不定义、不扩展**枚举 |
| 运行时能力门禁判定（`check(pluginId, cap[, resource])`） | `capability-governance`（IF-06） | 握手是「启动时一次性」，门禁是「每次调用时」，两者不得互相替代 |
| 跨进程能力禁列表 `HostUnsupportedCapabilities` **的定义与维护** | `capability-governance`（IF-07） | 本子系统只在**两处复用**同一张表（CH-01 拉起前静态预检 / IF-09 握手比对），**不另建**第二张表 |
| 版本协商（清单版本字段、加载前版本校验、`protocolVersion` 语义） | `version-guard`（IF-01/02/03/04） | 与本子系统在 `message.cj` 上串行落字段，语义互不侵占 |
| 依赖拓扑推导（替代 `order`）、`toCordisEntry` 补齐 `inject`/`provide`/`enabled`、`topoSort` 修复 | `dependency-graph`（IF-10） | 本子系统读声明面走 `processEntries`，不依赖也不修 `PluginEntry` |
| 崩溃退避 / 重启计数 / 风暴熔断 / `inspectProcessPlugin` 的 `pid`·`restartCount` 补齐 | `lifecycle-observability`（IF-11，R-07/R-08） | 握手失败置 `Failed` 是**避免**风暴，不是自愈 |
| `plugin validate` CLI / 存量清单体检 | `authoring-toolchain`（IF-12） | 本子系统只提供可被复用的 CH-01，不提供命令行入口 |
| `dylib` 轨握手接线 | 无归属（单独立项） | R-01：dylib 轨运行时不可达 |
| HTTP 路由转发 / 请求代理 / 路由鉴权 | 既有 `ExternalPluginRouteGateway`（复用） | 本子系统只做「该不该挂载这条路由」的判定与拒绝后撤销，**不改**转发实现 |
| 宿主环境变量白名单 / `host.secret` per-plugin 授权 | `capability-governance`（R-03 修复 / CG-04） | 不在本子系统范围 |
| 新增数据库表 / 列承载能力宣告 | 无（明确不做） | 铁律 9：进程内对象 + 派生态，见 §2 |
| OS 级进程强制（cgroup / job object） | 无（超出本轮） | CH-02 复用既有 `removePlugin` 的终止能力，不新增 OS 级强制 |

---

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动；在子系统 `tasks.md` 修订记录留痕即可 |
| 向后兼容（minor） | 只增接口 / 只增**可选**载荷字段（如 `RouteDecl` 增加可选 `auth`）/ 只增比对维度且缺省放行 / IF-05 新增枚举要素后本子系统同步支持 | 改本文 + 主工程 `SPECS_INDEX.md` §3；下游不必同步改 |
| 破坏性（major） | 改 IF-08 载荷字段名或类型 / 把「上报 ⊆ 声明」改为「相等」/ 把「缺省放行」改为「缺省拒绝」/ 改 `HandshakeDecision` 语义 / 改 `provides` 字段语义 / 把 CH-01 提升为跨子系统消费 / 把 IF-08 改为必填位置参数 | **必须双侧同轮**：提供方与全量消费方（宿主 `PluginHost` / `CordisHostManager` / `authoring-toolchain`）在同一轮 code 里改完；主工程 `SPECS_INDEX.md` §6 登记；单侧先改 = P0 缺陷 |

- 演进一律「**先改契约 → 再改实现**」，顺序反了按铁律 15 打回。
- **本轮已知的两次 minor 演进（实现时必须照做）**：
  1. IF-08 原摘要仅写作「`InitializeParams.declaredCapabilities`」。实际比对需要**二维**结构（routes + capabilities），故载荷定为结构体而非字符串数组。属只增可选字段，向后兼容。
  2. IF-09 原摘要写作 `verify(entry, declared)`。实际服务维度上报面在既有 `InitializeParams.provide` 上，故追加**带默认值的第三参** `provide!: Array<String> = Array<String>()`，保留双参签名可用。属向后兼容。
- **已知 v2 候选（不在 v1 范围）**：① 把「缺省放行」收紧为「缺省拒绝」（major，需先由 `authoring-toolchain` 为全量存量清单补全 `provides` / `capabilities`）；② 路由维度从「method+path 精确命中」升级为「路径前缀 + 通配」（minor）；③ 握手成功后对上报路由做**周期性重比对**（需新增 `Methods` 常量，major）。
- 契约冻结后到实现完成之间的任何偏差，在子系统 `test-report.md` 里必须归因到具体契约条目，禁止笼统写"实现与文档略有差异"。

---

## 6. 集成验收（本子系统对下游的交付承诺）

> 归属档位：以下用例由**本子系统 test 步**产出与执行（L1 + L2）；主工程端到端（L3，含 `SPECS_INDEX` §5.1 用例 1/2/5）在主工程 test 步执行，不在这里重复。
> **上游就位前提**：`version-guard` 处于 `done`（IF-04 已冻结且 `message.cj` 已落字段）、`capability-governance` 处于 `done`（IF-05 / IF-07 / CG-05 可用），**且不晚于本文冻结日**；否则 M-02 / M-04 / M-06 可能因上游半成品而误判。

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| **M-01** | **跨子系统主干（version-guard → capability-handshake）**：process 插件版本协商通过 → L3 进程被拉起 → 上报 `protocolVersion: 1` + 合法 `declaredCapabilities`（能力/服务/路由均 ≤ 清单声明）→ 握手通过 | 宿主集成运行（`PluginHostManager.loadAll` + `CordisHostManager.loadProcessPlugins`） | version-guard(IF-04) | `LoadResult.loaded` 含该插件；`awaitActive` 返回 `Ok`；实例 `Active`；日志含 `[HandshakeVerifier] verified ok` |
| **M-02** | **跨子系统主干（capability-governance → capability-handshake）**：插件清单声明 `db.read:["agent_skills"]`，但握手上报 `db.read:["agent_tasks"]`（超出资源清单）→ 拒绝挂载 | 宿主集成运行 | capability-governance(IF-05) | ① `InitializeResult(ok=false)`；② 实例 `InstanceStatus.Failed`（**非** `Pending`）；③ 拒绝原因串含 `dimension=capability` 与表名；④ 该插件**未**出现在 `LoadResult.loaded` |
| **M-03** | **IF-07 禁列表复用（静态预检，硬条件 A）**：process 插件清单声明 `fs.write` → **CH-01 在拉起前拒绝** | 宿主集成运行 + 进程列表核对 | capability-governance(IF-07) | ① `LoadResult.failed` 含该插件与 `unsupported capability across process boundary` 前缀理由（**取用 IF-07 说明表原串**）；② **L3 进程未被拉起**（进程列表无对应 pid）；③ 宿主无崩溃、其余插件照常加载 |
| **M-04** | **IF-07 禁列表复用（同一张表，第二处消费）**：对同一份清单分别跑「拉起前 CH-01 静态预检」与「握手 IF-09 比对」，结论一致 | 进程内调用对比 | capability-governance(IF-07) | 两次判定对同一条目给出**完全一致的 Reject 与同一条理由串**；全仓 grep 确认不存在第二份「跨进程禁能力」常量表 |
| **M-05** | **路由维度（最高危面）**：插件清单声明 2 条 `httpRoutes`，握手上报第 3 条未声明路由 → 拒绝 | 宿主集成运行 + `ExternalPluginRouteGateway.inspectRoutes()` | — | ① 拒绝原因串含 `dimension=route` 与未声明的 method+path；② `inspectRoutes()` 输出中**不含**该未声明路由；③ 已声明的 2 条路由在拒绝后**未被挂载**（或已撤销） |
| **M-06** | **服务维度**：插件清单 `provides: ["svc.a"]`，握手 `provide: ["svc.a","svc.b"]` → 拒绝 | 宿主集成运行 | — | 拒绝原因串含 `dimension=service` 与 `svc.b`；`state.servicesOf(pluginId)` 为空 |
| **M-07** | **硬条件 B（安全终止）**：握手被拒后 —— ① L3 进程**已被安全终止**（进程列表无残留、无僵尸）；② 宿主启动**不受影响** | 宿主集成运行 + 进程列表核对 | version-guard(IF-04) | ① 被拒插件进程退出且无残留；② `awaitActive` 返回 `Err` → 记入 `LoadResult.failed`，宿主主流程继续；③ 其余插件 `loaded` 数量与基线一致；④ 宿主进程本身未崩溃、HTTP 端口正常监听 |
| **M-08** | **防回退（R-04）**：存量 51 个 skill 插件 + 4 个 sync 锚点（无 `provides`、不上报宣告）→ 全部放行 | 存量回归运行 | — | 100% 存量条目握手 `Ok`；未上报者各产生一条 `warn`；主工程 §5.1 用例 5「行为零回归」不被破坏 |
| **M-09** | **异常（载荷畸形）**：握手上报 `declaredCapabilities` 为非法 JSON / 未知 `type` 串 → 不崩溃 | 进程内调用 + 集成 | capability-governance(IF-05) | 非法 JSON → 回落 `None` + `warn`（放行，防回退）；未知 `type` 串 → `Reject`（fail-closed，未知从严） |
| **M-10** | **异常（幂等 / 应急开关）**：① 同一插件重复握手（周期重发）→ 判定结果一致、不产生重复拒绝风暴；② `CORDIS_SKIP_PROCESS_PLUGINS` 命中的插件 → 仍被跳过，不进入握手比对 | 宿主集成运行 | — | ① 重复握手决策幂等；② 应急开关行为与现状一致（`cordis_host_manager.cj:149-167`），不被本子系统改动破坏 |

- **归属档位**：M-01 ~ M-06、M-08 ~ M-10 由本子系统 test 步执行（L1 单测 + L2 跨子系统集成）；**M-07 为硬条件**，L1/L2/L3 三档均须复现通过，未通过则主工程闸口不予 confirm。
- **不跑编译**：AI 不执行 `cjpm build`；编译、类型检查、lint 由人工在独立 cmd 环境完成并回传结果。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|:---:|---|---|---|
| 2026-10-19 | v1.0 | `SPECS_INDEX.md` §2 登记行（v1 / 4 接口 / 0 新表）+ §3 IF-08/IF-09 + §4 共享文件预警（R-05）+ §5 L2 冒烟第 2 条 + §7 R-04/R-05 + 基线侦察 | 首次落约：2 个全局接口（IF-08 / IF-09）+ 2 个子系统内接口（CH-01 / CH-02）；0 新表 0 新列；判定口径定为「上报 ⊆ 声明」+ 缺省放行；IF-07 在「拉起前静态预检」与「握手比对」两处复用同一张表；新暴露 `plugin_config.cj` 三方共享冲突并提出补登记请求 | 宿主 `PluginHost` / `CordisHostManager`（消费 IF-08/IF-09/CH-01/CH-02）；`version-guard`（`message.cj` 串行顺序）；`capability-governance`（被消费 IF-05/IF-07/CG-05，并提出 CG-05 提升为 IF-07a 的请求）；`authoring-toolchain`（可选消费 CH-01，须先提升为 IF-xx） |

> 主工程账本同步：本节每次改动，**必须**同步到 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 / §6。
