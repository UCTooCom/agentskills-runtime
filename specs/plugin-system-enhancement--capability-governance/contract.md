# 子系统集成契约（capability-governance）

> 模板：`templates/subsystem-contract-template.md`
> 产出阶段：`spec` / `design` 步（子系统的文档步产出，属该子系统工程内部）
> 被谁消费：主工程 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 集成契约汇总 + 下游子系统的 tasks.md / 编码步
> 铁律依据：**铁律 15**（大工程拆分：集成契约先定、先改契约再改实现）

> 契约是**承诺**，不是设计说明。本文件在子系统实现开工前冻结；
> **禁止**在实现里单边改动契约——要改就走 §5 的演进档位，双侧同轮完成。

## 文档信息

| 项 | 值 |
|---|---|
| 所属主工程 | `plugin-system-enhancement` |
| 子系统 ID | `capability-governance`（稳定标识，跨轮次不变） |
| 子系统 `feature_name` | `plugin-system-enhancement--capability-governance` |
| 契约版本 | `v1` |
| 冻结日期 | 2026-10-19 |
| 冻结状态 | **草案**（待主工程闸口 `confirm` 后转「已冻结」） |
| 语言标签 | `cangjie` |
| 验收档位 | L1 + L2 + L3 |
| 上游依赖 | `version-guard v1`（仅取 IF-02 `PluginManifestEntry.pluginApi/hostVersionRange` 字段口径，用于清单能力块解析同源；**不依赖其版本校验结果**） |
| 下游消费方 | `capability-handshake`（消费 IF-05 / IF-07）、`authoring-toolchain`（消费 IF-05 / IF-07） |
| 新建数据库表 | **0 张**（能力授权以 `plugin.yaml` 声明承载 + 运行时内存注册表；审计落既有 `operate_log`） |

> 证据基线的行号均取自本仓 2026-10-19 工作区快照；行号随后续提交漂移时以标识符为准。

---

## 1. 本子系统提供什么（能力清单）

**类型口径**：`进程内调用`（宿主进程内的宿主侧门禁，求值方式 = `CordisHostServices` 构造持有的 `CapabilityGate` 单例 + `pluginId` 显式传参；下游测试可用「预置 policy 的假 gate」替身）。

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| **IF-05** | 进程内调用 | `magic.security.capability.PluginCapability`（enum）+ `magic.security.capability.CapabilityPolicy` | `CapabilityPolicy.fromManifest(entry: PluginManifestEntry)` | `PluginManifestEntry` | `CapabilityPolicy`（含 `Set<PluginCapability>` + 每能力资源允许清单 + `ResourceLimits`） | 清单能力块非法 → 不抛异常，降级为「全拒」并记 `WARN`（解析失败即拒绝，fail-closed） | 是（同 entry → 同 policy） | **对外**（IF-05）。覆盖六个维度：数据库表 / 网络出口 / 文件访问 / 子进程派生 / 环境变量 / secret 取值。**缺省全拒**：未声明 = 不允许 |
| **IF-06** | 进程内调用 | `magic.security.capability.CapabilityGate` | `check(pluginId: String, cap: PluginCapability)` 与重载 `check(pluginId: String, cap: PluginCapability, resource: String)` | `(pluginId, 能力, [资源标识])` | `PermissionCheckResult`（**复用** `src/security/permission_service.cj:30-72` 既有结构：`.allowed` / `.reason` / `.deniedOperations`） | `allowed=false` 时 `reason` 必非空；宿主侧把 `reason` 转成该 host 服务既有错误结构（`{"error": "..."}`，见 `cordis_host_services.cj:dbError` / `:mcpError` / `:secretError`），**不自造错误码** | 是（不改变状态；仅内部计数/审计副作用） | **对外**（IF-06）。所有 `host.*` handler 统一前置调用此判定 |
| **IF-07** | 进程内调用（常量读取） | `magic.security.capability.HostUnsupportedCapabilities`（常量表） | 常量读取：`Set<PluginCapability>` + `String` 说明表 | — | 常量集合 | 声明即拒绝，错误信息统一含 `unsupported capability across process boundary` 前缀 | 不适用 | **对外**（IF-07）。L3 跨进程（`mode: process`）恒禁能力清单；被 handshake 与静态审计消费 |
| CG-01 | 进程内调用 | `CapabilityGate.register(pluginId, policy)` / `CapabilityGate.unregister(pluginId)` | 注册/注销 | `(pluginId, CapabilityPolicy)` | `Unit` | 重复 register → 覆盖并记 `WARN`（以 pluginId 为幂等键） | 是（幂等键 `pluginId`） | 子系统内。生命周期绑定点：`cordis_host_manager.cj:87-108`（Active 钩子） |
| CG-02 | 进程内调用 | `magic.security.capability.CapabilityDecision` | 结构化拒绝结果 | — | `{pluginId, capability, resource, reason, deniedAt}` | 由 `PermissionCheckResult` 派生，字段名不得再翻译一遍（避免两套错误语义） | 是 | 子系统内。统一错误/审计载荷；供 CG-04 消费 |
| CG-03 | 进程内调用 | `magic.security.capability.CapabilityAuditSink` | `recordDeny(decision: CapabilityDecision)` | `CapabilityDecision` | `Unit` | 审计写失败**不得**阻断主流程，记 `ERROR` 后继续 | 否（追加型，天然重复） | 子系统内。落既有 `operate_log`；不新建表 |
| CG-04 | 进程内调用 | `magic.security.capability.PluginEnvResolver` | `resolve(entry: PluginManifestEntry, base: HashMap<String,String>): HashMap<String,String>` | `PluginManifestEntry` + 宿主最小基础环境 | 供 `launch(environment:)` 使用的最终 env | 任一宿主变量未在 `env.read` 资源清单内 → 不出现在结果里（缺省清除） | 是 | 子系统内。**修复 R-03 env 全量泄漏**的关键；配合 `libs/cordis-cj/cordis_host/src/plugin_manager.cj:98-101` 改造 |
| CG-05 | 进程内调用 | `CapabilityPolicy.intersectWithUnsupported(mode: PluginMode)` | policy × IF-07 | `(policy, PluginMode)` | 扣除禁列表后的有效 policy | 扣减后的差异项记 `WARN`（供 handshake 定位「声明了但拿不到」） | 是 | 子系统内 + handshake 只读消费结果 |
| CG-06 | 进程内调用 | `magic.security.capability.CapabilityMigration` | `deriveFromTableWhitelist(entry)` | `PluginManifestEntry` | `Option<CapabilityPolicy>`（降级推导结果） | 既无 `capabilities` 又无 `tableWhitelist` → `None`（= 全拒） | 是 | 子系统内。**防回退锚点 R-04**：存量 51 skill 插件 + 4 sync 插件零回归迁移通道 |

**接口计数对账**：子系统合计 **9 个接口**，其中 **3 个**登记在主工程全局表（IF-05 / IF-06 / IF-07），**6 个**为本子系统内部接口（CG-01 ~ CG-06）。CG-* 当前**无跨子系统消费方**，故不占 §3 全局行；将来任一子系统需要消费某个 CG-*，必须先在 SPECS_INDEX §3 提升为 `IF-xx` 行并过闸口，**禁止**在实现里直接 import 过去（按依赖漂移 P0 计）。

**错误约定**（红线）：
- 跨子系统**不得自造错误码**。宿主侧既有错误结构是 `{ "error": "<message>" }`（`cordis_host_services.cj` 的 `dbError` / `mcpError` / `secretError` 三处同构），能力门禁拒绝沿用同一形状，`message` 内容由 `PermissionCheckResult.reason` 提供。
- 门禁拒绝**不得**抛异常穿透到 cordis RPC 层；一律在该 handler 内转成上述错误结构返回（对齐 `SPECS_INDEX` §5 L2 冒烟第 4 条「插件进程不残留、无僵尸进程」）。

---

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| `permissions` | **不读写** | — | — | — | — |
| `role_has_permission` | **不读写** | — | — | — | — |
| `operate_log` | **写**（CG-03 审计例外，DENY 事件） | `plugin_id`、`source`、`status`、`error_message`、`actor_type`、`created_at` | 其余全部 | 沿用 `row-level-permission-system.md`；本子系统只追加不查询 | 审计行不软删 |
| `agent_skills` | **不改变结构**（0 新列） | — | — | — | — |

**红线声明（铁律 9 复用优先）**：
- 本子系统**新建表 0 张、新建列 0 列**。能力授权是**声明式配置**（`plugin.yaml` 的 `capabilities` 块），运行时授权态是**派生态**（`CapabilityGate` 内存注册表），二者都不需要持久化载体。
- 已知超出项：若后续确需「宿主管理员在线授予/吊销某插件能力」的持久化场景，则**不属于本轮范围**，须回主工程 §6 登记后再议，禁止本子系统先开表。
- 由于无新增表/列：**无 `sql/incremental/` DDL 产出**；由于无新增宿主 HTTP 路由（门禁是进程内调用，非 HTTP 端点）：**无新增 `permissions` / `role_has_permission` 登记**。此结论与设计步骤 T-02 的「DB 变更自检」一致（见 `tasks.md` T-02）。
- 行级权限宿主侧附加**沿用既有实现**（`cordis_host_services.cj:470-473`），本子系统不修改其语义。

---

## 3. 依赖方向

### 3.1 我依赖的上游（有限名单）

1. **`version-guard v1`** —— 只依赖 IF-02「清单版本字段解析」建立的 **`PluginManifestEntry` 字段解析同源口径**（新增 `capabilities` 块与 `pluginApi` 在同一解析函数 `plugin_config.cj:122-208` 内追加）。**不依赖**其 IF-03 版本校验结果与 IF-01 版本常量取值。

### 3.2 我不依赖谁（保留位）

- **不依赖 `capability-handshake` 的任何东西**。本子系统只**被**它消费；不 import 其 `HandshakeVerifier`、不读其 IF-08 字段。handshake 拿低估/高估 degrade 的地方由它自己调 IF-05/IF-07 完成。
- **不依赖 `authoring-toolchain`**。它的 `plugin validate`（IF-12）怎么报 capability 错误是它自己的事；本子系统只保证 IF-05 的 policy 语义与 IF-07 常量表是机器可读的。
- **不依赖 `dependency-graph` / `lifecycle-observability`**（无共享文件、无共享语义）。
- **不依赖 `dylib` 轨**（见 `SPECS_INDEX` R-01）。本子系统对 `PluginMode.Dylib` 的处置与 `Sync` 同轨标记，且不保证 dylib 轨上的行为已验证——因为该轨运行时不可达。

### 3.3 禁止成环

本子系统与上游 `version-guard` 为单向依赖（`version-guard → capability-governance`），无回边；与下游 `capability-handshake` / `authoring-toolchain` 亦单向。**出现反向 import 即视为依赖漂移，按 P0 计。**

---

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| L3 启动能力**宣告握手**（声明 vs 实际注册比对、拒绝挂载） | `capability-handshake` | 本子系统只提供「能给它什么」（IF-05 枚举/策略、IF-07 禁列表），不做「它实际注册了什么」的比对。**交界**：CG-05 只返回扣减后的有效 policy，据此拒绝挂载的判定由 handshake 做 |
| 版本协商 / 加载前拒绝 | `version-guard` | 与本子系统无交叠代码落点 |
| 插件模板生成、`plugin validate` CLI | `authoring-toolchain` | 本子系统不提供 CLI；只保证 `CapabilityPolicy.fromManifest` 可被复用做静态校验（CG-01~06 为进程内 API） |
| 依赖拓扑推导（替代 `order`） | `dependency-graph` | 无交叉 |
| 崩溃退避 / 重启计数 / 风暴熔断 | `lifecycle-observability` | `ResourceLimits` 里的 CPU/内存/超时是**单次执行**限额，不是崩溃自愈；两者不得混用同一计数器 |
| `dylib` 轨能力门禁接线 | 无归属（单独立项） | R-01：dylib 轨运行时不可达，本子系统不为它补接线 |
| 新增数据库表 / 列承载能力授权 | 无（明确不做） | 铁律 9：声明式 + 派生态，见 §2 |
| 进程沙箱的 **OS 级**（cgroup / job object）强制限额 | 无（超出本轮） | `SandboxExecutor`（`sandbox_executor.cj:104-136`）只做记账与异常捕获，**无 OS 级强制**；本轮把它作为记账层复用，OS 级强制不在本契约承诺范围内（见 `design.md` §3.6 差距 G-5） |

---

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动；在子系统 `tasks.md` 修订记录留痕 |
| 向后兼容（minor） | 只增接口 / 只增可选字段 / 只增枚举要素 + 相应策略，不改既有语义 | 改本文 + 主工程 §3 汇总；下游不必同步改 |
| 破坏性（major） | 改 §1 路径/方法名 / 改 `PermissionCheckResult` 语义 / 改 "缺省全拒" 口径 / 把某个 CG-* 从内部提升为跨子系统消费 | **必须双侧同轮**：提供方与全量消费方在同一轮 code 里改完；主工程 SPECS_INDEX §6 登记；单侧先改 = P0 缺陷 |

- 演进一律「**先改契约 → 再改实现**」，顺序反了按铁律 15 打回。
- **本轮已知的两次 minor 演进（实现时必须照做）**：
  1. IF-06 增加 `resource` 重载：原摘要写作 `check(pluginId, cap)`，实际需要资源级判定（DB 表名 / MCP alias+tool / env 名 / secret 引用名 / 路径）。**保留双参签名并追加三参签名**，属向后兼容。
  2. CG-03 落 `operate_log` 时，既有 `OperateLogService.recordPluginLog`（`src/app/services/uctoo/OperateLogService.cj:1021-1041`）内部把 `source` 硬编码为 `"host.db"`（`:1039`）。需**增一个 `source!` 可选形参**（缺省 `"host.db"` 以保既有行为），而非新建一套审计写入。
- 契约冻结后到实现完成之间的任何偏差，在子系统 `test-report.md` 里必须归因到具体契约条目，禁止笼统写"实现与文档略有差异"。

---

## 6. 集成验收（本子系统对下游的交付承诺）

> 归属档位：以下用例由**本子系统 test 步**产出与执行（L1 + L2）；L3 由主工程 test 步执行。
> **上游就位前提**：`version-guard` 处于 `done` 且不晚于本文冻结日；否则 M-02 用例可能因共享文件 `plugin_config.cj` 的版本字段尚未稳定而误判。

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| M-01 | 跨 `capability-governance → authoring-toolchain`：`plugingen` 生成的插件清单 → `CapabilityPolicy.fromManifest` 解析出预期 policy → `plugin validate` 全绿；手工删一项能力声明 → validate 报对应错 | 进程内调用 + CLI 联合 | version-guard(IF-02) | 两份判定结论一致（同一份来源:同一套清单解析语义），不存在宿主与 CLI 各判一套的情况 |
| M-02 | **缺省全拒**：构造一个 `capabilities` 全缺省（缺 `capabilities` 且缺 `tableWhitelist`）的 process 插件 → 其 `host.db` / `host.mcp` / `host.secret` 三类调用**全部**被拒 | 宿主集成运行 | version-guard(IF-02) | 三类调用各自返回 `{"error": ...}`；宿主日志出现 CG-03 审计记录；插件进程不残留 |
| M-03 | **资源级收窄**：插件声明 `db.read: ["agent_skills"]` 且请求非白名单表 `agent_tasks` → 被拒；请求 `agent_skills` → 放行 | 宿主集成运行 | — | 非白名单表的拒绝原因串包含表名；白名单表结果与既有行为一致（不回归） |
| M-04 | **IF-07 禁列表**：process 模式插件声明 `fs.write` / `proc.spawn` → CG-05 扣除后为空集，且任何调用返回统一 `unsupported capability across process boundary` 前缀错误 | 进程内调用 | — | 扣除结果与 `HostUnsupportedCapabilities` 常量集完全一致；每一次 DENY 均有 CG-03 审计记录 |
| M-05 | **异常（宿主环境泄漏回归）**：process 插件启动后，枚举自身进程环境变量 → **不得**见到 `orm_connectionUrl`、LLM key 等宿主敏感变量；`host.secret` 索取未授权的 `env:XXX` → 被拒 | 宿主集成运行 + 子进程内自检 | — | 子进程 env 与 CG-04 输出逐个比对一致；未授权 secret 返回 `{"error":...}` 且**不含明文** |
| M-06 | **防回退（R-04）**：既有 51 个 skill 插件与 4 个 sync 插件加载后，经 CG-06 降级推导出的 policy 与其历史 `tableWhitelist` 语义等价，DB 访问行为零变更 | 宿主回归运行 | — | `tableWhitelist` 内表的 query/execute/count 全部放行；不在其内的照旧被拒（沿用 `cordis_host_services.cj:457-467` 既有行为） |
| M-07 | **异常（重复注册 / 幂等）**：同一 pluginId 重复 `register` → 后者覆盖，且 WARN 有记录；未 register 的 pluginId 调用 `check` → 一律 deny（未知插件从严） | 进程内调用 | — | 幂等键 `pluginId` 生效；未知 pluginId 不抛异常、不崩溃 |

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|:---:|---|---|---|
| 2026-10-19 | v1.0 | `SPECS_INDEX.md` §2 登记行 + §3 IF-05/06/07 + §7 R-02/R-03 + 基线侦察 | 首次落约：3 个全局接口（IF-05/06/07）+ 6 个子系统内接口（CG-01~CG-06）；0 新表 0 新列；明确 two-phase:缺省全拒 + CG-06 存量降级通道 | `capability-handshake`（消费 IF-05 枚举 + CG-05 扣减结果 + IF-07 常量）、`authoring-toolchain`（消费 IF-05 policy 语义） |

> 主工程账本同步：本节每次改动，**必须**同步到 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 / §6。
