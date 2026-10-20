# 任务规划文档（capability-handshake）

> 模板：`skills/sdd/templates/tasks-template.md`
> 基于 `./spec.md` 与 `./design.md` 生成。实施原则：**复用优先**、**确定性优先**、**L3 进程隔离**。
> 仓颉代码编写须使用 cangjie-coder 技能；**严禁运行 cjpm build**（编译与回传由人工在独立 cmd 环境完成）。

## 文档信息

- 关联需求：`specs/plugin-system-enhancement--capability-handshake/spec.md`
- 关联设计：`specs/plugin-system-enhancement--capability-handshake/design.md`
- 关联契约：`specs/plugin-system-enhancement--capability-handshake/contract.md`（IF-08 / IF-09 / CH-01 / CH-02）
- 边界账本：`specs/plugin-system-enhancement/SPECS_INDEX.md`（§2 登记行 v1/4 接口/0 新表；§3 IF-08/IF-09；§4 共享文件 R-05；§5 L2 冒烟；§7 R-04/R-05）
- 生成日期：2026-10-19 ｜ 版本：v1.0 ｜ 状态：草稿
- 任务条数：**17 条**（T-01 ~ T-17）

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：仓颉 → cangjie-coder。**不运行 `cjpm build`**。
- **二次开发底座优先（铁律 14）**：
  1. 规范源：先加载 `uctoo-dev-manual`（`skills/uctoo-dev-manual/`），按要做的事读对应 `docs/uctoo-v4/*.md`。
  2. 脚手架优先确定性生成：`loaddbinfo` → `plugingen`（功能拓展优先做成插件，默认 L3 process 轨）/ `crudgen`（**仅**宿主 `src/app/` 公共基础设施）/ `crudweb`。
     **本子系统 0 新表 0 新列 → 不触发 `loaddbinfo` / `crudgen`；无新增 HTTP 端点 → 不触发 `crudweb` 与权限登记。**
  3. 工具链坑位：`loaddbinfo` 命令行模式有未修问题 → 退 Web 端「数据库管理 → 加载数据库信息」。
  4. **生成后必补**：新增表/列 DDL 放 `sql/incremental/`（须先论证复用不成立）；**新增宿主路由必做 `permissions` + `role_has_permission` 登记，否则 403**。本子系统无新增路由，故**无登记项**（如实现中意外新增路由，必须立刻补登记）。
- **大工程拆分态（铁律 15，强制）**：
  1. 已读主工程 `SPECS_INDEX.md`，确认子系统 ID = `capability-handshake`、`feature_name = plugin-system-enhancement--capability-handshake`、上游 = `version-guard` + `capability-governance`、验收档位 = L1 + L2 + L3。
  2. **每条任务标注「本子系统负责」与「不碰（移交/调用上游）」**；跨子系统一律落成「调用上游契约接口」或「等下游消费」，**禁止**写成"顺手也改一下 X 模块"。
  3. 跨子系统接口改动成对成条；契约版本（minor/major）写明条目编号；major 必须双侧同轮。
  4. **禁止跨界手写**：不直连其他子系统私有表/目录；改动只落本子系统边界内，跨界先回 `SPECS_INDEX` §6 登记。
- **共享文件串行（R-05，强制）**：
  1. `libs/cordis-cj/cordis_core/src/message.cj`：`version-guard` 先冻结 IF-04 → 本子系统再追加 IF-08。**T-04 必须在 version-guard 达 done 之后开工**（阻塞依赖）。
  2. `src/plugin/plugin_config.cj`：`version-guard`（version 字段）→ `capability-governance`（capabilities）→ 本子系统（provides）。**T-03 必须排在 capability-governance 之后**。
- **复用原则**：优先复用 `design.md` §2.4 存量对比清单所列基础设施（`removePlugin` / `unregisterPluginRoutes` / `processEntries` / `mapStatusToState` / `awaitActive` / 应急开关），**不重新实现**已有能力。
- **命名/注释/错误处理**：沿用宿主既有风格（`LogUtils.error` + `[模块名]` 前缀 + 统一 `{"error": ...}` 错误结构），不自造错误码。

---

## 任务总览

| 编号 | 任务 | 关联需求(spec §) | 关联设计(design §) | 负责子 agent | 状态 | 预计产出 |
|---|---|---|---|---|---|---|
| T-01 | 边界与契约对齐复核（读账本 + 上游契约 + 确认串行顺序） | §1.4、附录 A | §2.4 | 文档步 | 已完成 | 复核结论 |
| T-02 | **清单声明面扩展**：`PluginManifestEntry.provides` | FR-CH-07、§6.3 | §3.7 | code | `[ ]` | `plugin_config.cj` 改动 |
| T-03 | **IF-08 载荷结构体** `DeclaredCapabilities` / `RouteDecl` / `CapabilityDecl` | FR-CH-01~04、§6.1 | §3.1 | code | `[ ]` | `declared_capabilities.cj`（新增） |
| T-04 | **`InitializeParams` 追加 `declaredCapabilities` 字段**（串行，在 IF-04 之后） | FR-CH-02、DFX-CH-C2 | §3.1.2 | code | `[ ]` | `message.cj` 改动 |
| T-05 | **IF-09 比对器** `HandshakeVerifier.verify`（三维 + 禁列表优先 + 缺省放行） | FR-CH-05~11、§5.2 | §3.2 | code | `[ ]` | `handshake_verifier.cj`（新增） |
| T-06 | **CH-01 静态预检** `HandshakeVerifier.auditEntry`（与 IF-09 共用 `checkBanned`，复用 IF-07） | FR-CH-12、DFX-CH-S1、§5.3 | §3.2.3 | code | `[ ]` | `handshake_verifier.cj` |
| T-07 | **宿主接入点** `PluginHost.setHandshakeVerifier` + initialize handler 插入判定 | FR-CH-05~11、DFX-CH-R1/R3 | §3.3 | code | `[ ]` | `plugin_host.cj` 改动 |
| T-08 | **挂载 verifier**：`CordisHostManager` 构造后注入（声明面取 `processEntries`） | FR-CH-05~11 | §3.4.2 | code | `[ ]` | `cordis_host_manager.cj` 改动 |
| T-09 | **拉起前预检接入**：`loadProcessPlugins` 在 `addDesired` 前调 CH-01 | FR-CH-12、DFX-CH-S1 | §3.4.1 | code | `[ ]` | `cordis_host_manager.cj` 改动 |
| T-10 | **CH-02 安全终止器** `HandshakeSafeTerminator.terminate` | FR-CH-13、DFX-CH-R2/R3 | §3.5 | code | `[ ]` | `handshake_safe_terminator.cj`（新增） |
| T-11 | **拒绝对接**：`Failed` 态监听触发终止 + 状态回写复用既有通道 | FR-CH-13、DFX-CH-M1 | §3.4.3 | code | `[ ]` | `cordis_host_manager.cj` 改动 |
| T-12 | **路由注册联动**：`registerProcessPluginRoutes` 跳过失败集 | FR-CH-14、DFX-CH-S4 | §3.6 | code | `[ ]` | `plugin_host_manager.cj` 改动 |
| T-13 | **应急开关与既有路径兼容复核**（`CORDIS_SKIP_PROCESS_PLUGINS`、`reconcile` 增量路径） | §5.3.1-4、§5.5.3 | §3.6、§9.2 | code | `[ ]` | 复核记录 |
| T-14 | **防回退验证**（R-04）：存量 51 skill + 4 sync 锚点零回归 | DFX-CH-C1、§5.2.3-5 | §2.4 | test | `[ ]` | 回归报告 |
| T-15 | **L1 单测**（载荷解析 / 三维比对 / 缺省放行 / 幂等 / 禁列表两处一致） | FR-CH-01~12、DFX-CH-S1~S3 | §3.1、§3.2 | test | `[ ]` | 单测 |
| T-16 | **L2 跨子系统冒烟**（契约 §6 M-01~M-10，含硬条件 M-07） | 全部 | §3 全章 | test | `[ ]` | 冒烟报告 |
| T-17 | **文档与账本同步**（`SPECS_INDEX` §2/§3/§6 补登记 + 三方共享文件登记） | §1.4 | §10.3 O-3/O-4 | 文档步 | `[ ]` | 账本更新 |

状态：`[ ]` 待开始 / 进行中 / 已完成 / 阻塞

---

## 任务依赖关系图

```
【上游子系统】version-guard(done) ──┐
                                    ├──▶ T-01 ──▶ T-02 ──▶ T-03 ──▶ T-04 ──┐
【上游子系统】capability-governance(done) ──┘                              │
                                                                          ▼
                                                    T-05 ──▶ T-06 ──▶ T-07 ──▶ T-08 ──▶ T-09
                                                                                          │
                                                                                          ▼
                                                                        T-10 ──▶ T-11 ──▶ T-12 ──▶ T-13
                                                                                                      │
                                                                                                      ▼
                                                                              T-14 ──▶ T-15 ──▶ T-16 ──▶ T-17
```

- **可并行**：T-05 与 T-06（同文件不同函数，建议同一轮提交）；T-14 / T-15 在 T-13 后可并行。
- **必须顺序**：T-02 → T-03 → T-04（字段依赖）；T-04 → T-07（宿主 handler 读新字段）；T-07 → T-08 → T-09；T-10 → T-11。
- **阻塞（外部）**：T-04 **阻塞于** `version-guard` 达 `done`（`message.cj` IF-04 先冻结）；T-02 **阻塞于** `capability-governance` 达 `done`（`plugin_config.cj` capabilities 先落）；T-05/T-06 **阻塞于** `capability-governance` 达 `done`（IF-05/IF-07/CG-05 可用）。
- **不并行改**：`message.cj`（与 version-guard 串行）、`plugin_config.cj`（三方串行）。

---

## 任务详细说明（按编号展开）

### T-01 边界与契约对齐复核（文档步）
- **目标**：确认本子系统 ID / 契约条目 / 上游串行顺序 / 验收档位，避免越界开工。
- **步骤**：① 读 `SPECS_INDEX.md` §2/§3/§4/§5/§7；② 读 `version-guard/contract.md` §3.3 与 `capability-governance/contract.md` §1；③ 复核基线 GAP（`message.cj:10-53`、`plugin_host.cj:104-135`、`cordis_host_manager.cj:263-274`、`plugin_host_manager.cj:143-155`）。
- **产出物**：本目录 `contract.md` / `spec.md` / `design.md` 已落。
- **本子系统负责**：边界账本与契约一致性。
- **不碰（移交/调用上游）**：不改上游任何契约文本；发现不一致回主工程 §6 登记。
- **状态**：已完成（本轮）。

### T-02 清单声明面扩展：`PluginManifestEntry.provides`
- **目标**：为「服务维度」建立声明面（`spec.md` §6.3 / FR-CH-07）。
- **输入**：`capability-governance` 已完成 `plugin_config.cj` 的 `capabilities` 解析（三方串行，本条排在最后）。
- **步骤**：① `plugin_config.cj:72` 起追加 `public var provides: ArrayList<String> = ArrayList<String>()`；② 在既有解析函数（`:122-208`）内追加 `case "provides" =>` 解析字符串数组；③ 类型不符 → 回落空数组 + `LogUtils.warn`（沿用 `:161-165` 既有风格）；④ 补一个「无 `provides` 字段」的存量清单解析用例。
- **产出物**：`src/plugin/plugin_config.cj`（改动）。
- **验收**：无 `provides` 的存量清单解析为空数组且**不拒绝**（DFX-CH-C1）；有 `provides` 时正确读出。
- **本子系统负责**：仅 `provides` 一个字段 + 一个 case 分支。
- **不碰（移交/调用上游）**：**不改** `version`/`pluginApi`/`hostVersionRange`（`version-guard`）、**不改** `capabilities`（`capability-governance`）、**不改** `tableWhitelist` 与 `httpRoutes` 既有语义、**不改**「类型不符静默跳过」既有行为。
- **风险**：三方共享文件，未登记即改按契约漂移 P0 计（O-4，须先完成 T-17 的补登记）。

### T-03 IF-08 载荷结构体 `DeclaredCapabilities`
- **目标**：定义握手上行宣告的形状（FR-CH-01~04）。
- **步骤**：① 新增 `libs/cordis-cj/cordis_core/src/declared_capabilities.cj`；② `RouteDecl{method,path}` / `CapabilityDecl{type,resources!}` / `DeclaredCapabilities{routes!,capabilities!}`，均实现 `JsonSerializable & JsonDeserializable<T>`；③ **服务键不放进本结构**（服务维复用既有 `InitializeParams.provide`）；④ `type` 只以**字符串**承载，翻译放宿主侧。
- **产出物**：`declared_capabilities.cj`（新增）。
- **验收**：`spec.md` §6.1 全部字段约束；未知 `type` 不在本层判死（交由 T-05 fail-closed）。
- **本子系统负责**：载荷形状与序列化。
- **不碰（移交/调用上游）**：**不定义、不扩展**能力枚举（IF-05 归 capability-governance）；**不 import** `magic.security.capability`（避免协议层反向依赖宿主安全层）；**不改** `ExternalRoute`（复用其 method/path 语义）。
- **风险**：O-1（包位置与 `Array<T>` 默认参数写法待人工编译确认）。

### T-04 `InitializeParams` 追加 `declaredCapabilities` 字段
- **目标**：把 IF-08 挂到既有握手载荷上（FR-CH-02 / DFX-CH-C2）。
- **输入**：**阻塞前置** —— `version-guard` 已冻结 `protocolVersion`（IF-04）并落库。
- **步骤**：① `message.cj` 追加 `public let declaredCapabilities: ?DeclaredCapabilities`，以**尾部命名默认参数**形式（`declaredCapabilities!: ?DeclaredCapabilities = None`）；② `toJson` 按 `if (let Some(dc) <- ...)` 款式写入；③ `fromJson` 追加 `case "declaredCapabilities" =>`；④ **不动** `InitializeResult`。
- **产出物**：`libs/cordis-cj/cordis_core/src/message.cj`（改动）。
- **验收**：既有构造点零改动即可编译；缺省为 `None`；解析失败回落 `None` + warn（不拒绝）。
- **本子系统负责**：IF-08 字段追加。
- **不碰（移交/调用上游）**：**不动** `protocolVersion`（IF-04 / version-guard）、**不动** `id`/`inject`/`provide`/`config` 既有语义、**不新增** `Methods` 常量（不新增 hello/negotiate/declare）、**不新增**周期性 PING 调度（`methods.cj:13` 的 PING 现状不在本轮）。
- **风险**：R-05 —— 与 version-guard **串行**，禁止并行改同一结构体；改必填位置参数即判 major。

### T-05 IF-09 比对器 `HandshakeVerifier.verify`
- **目标**：三维比对 + 禁列表优先 + 缺省放行（FR-CH-05~11）。
- **步骤**：① 新增 `src/plugin/handshake_verifier.cj`；② 按 `design.md` §3.2.2 **固定顺序**实现（mode 门 → 缺省放行 → 有效集 → 能力维 → 服务维 → 路由维）；③ 有效集 = `CapabilityPolicy.fromManifest(entry)`（IF-05）经 `intersectWithUnsupported(Process)`（CG-05 × IF-07）；④ 禁列表**显式再判一次**（纵深防御）；⑤ 原因串模板 `handshake rejected: plugin=<id> dimension=<d> detail=<项> reason=<说明>`，脱敏；⑥ 首个失败即返回，其余逐条 WARN。
- **产出物**：`handshake_verifier.cj`（新增）。
- **验收**：M-02 / M-06 / M-09；`spec.md` §5.2.1 规则 1~9 全条。
- **本子系统负责**：比对逻辑与原因串。
- **不碰（移交/调用上游）**：**不调** `CapabilityGate.check`（IF-06，运行时门禁归上游）；**不定义**枚举与禁列表；**不改** `CapabilityPolicy` 内部字段；**不改** `plugin.yaml` 能力块解析（T-02 之外的部分）。
- **风险**：O-3 —— CG-05 为上游内部接口，跨子系统消费须提升为 `IF-07a`；若不提升，退化为本地等价求差（`fromManifest` 结果 − IF-07 集），**结果必须与 CG-05 一致**并写入修订记录。

### T-06 CH-01 静态预检 `HandshakeVerifier.auditEntry`
- **目标**：拉起前复用 IF-07 拒掉恒禁能力，使进程**未被拉起**（FR-CH-12 / DFX-CH-S1 / 硬条件 A）。
- **步骤**：① 抽出私有 `checkBanned(entry): Option<String>`；② `auditEntry` = mode 门 + `checkBanned`，**不读任何上报面**；③ **IF-09 与 CH-01 共用 `checkBanned`**，保证两处结论与理由串逐字一致；④ 理由串**直接取用** IF-07 说明表原串（`capability-governance/design.md:380`）。
- **产出物**：`handshake_verifier.cj`（与 T-05 同文件）。
- **验收**：M-03 / M-04；DFX-CH-S1「两处结论完全一致 + 全仓只有一处禁列表」。
- **本子系统负责**：预检函数与共用逻辑。
- **不碰（移交/调用上游）**：**不另建**禁列表（唯一真源 IF-07）；**不改** IF-07 内容；**不消费** `authoring-toolchain`（其 `plugin validate` 复用 CH-01 属它自己那条任务，且须先提升为 `IF-xx`）。
- **风险**：上游 IF-07 不可用时的处置是「拒绝并记 error」而非静默放行（属阻塞态，不得在该状态下报 done）。

### T-07 宿主接入点 `PluginHost.setHandshakeVerifier` + initialize handler 插入判定
- **目标**：把 IF-09 挂进握手主链路（DFX-CH-R1/R3）。
- **步骤**：① `plugin_host.cj` 新增 `private var handshakeVerifier: ?(String, InitializeParams) -> ?String` 与 `public func setHandshakeVerifier(...)`（与 `setProtocolGate` 同形）；② 在 `Methods.INITIALIZE` handler（`:105-138`）内、**既有 `checkMissing`(:115) 之前**插入判定；③ 拒绝 → `transitionStatus(instance, InstanceStatus.Failed)`（**非** `Pending`）+ `logger` + 返回 `InitializeResult(false, ...)`；④ 异常 → 捕获并记 error，不穿透。
- **产出物**：`libs/cordis-cj/cordis_host/src/plugin_host.cj`（改动）。
- **验收**：M-01 / M-02 / M-07；DFX-CH-R1（置 `Failed`）、DFX-CH-R3（异常不穿透）。
- **本子系统负责**：注入口 + 判定插入 + `Failed` 态。
- **不碰（移交/调用上游）**：**不改** `checkMissing` 与依赖语义（归 dependency-graph IF-10）；**不改** `topoSort`(`:984-1010`) / `entryChanged`(`:858-864`)；**不改** protocolGate 顺序（version-guard 在前）；**不做** handler 内阻塞式终止（交 T-10/T-11）；**不改** cordis 状态机其余部分。
- **风险**：vendored `libs/cordis-cj/` 改动须在修订记录登记「回上游存在偏差」。

### T-08 挂载 verifier（声明面取 `processEntries`）
- **目标**：把清单声明面接到宿主侧判定回调上（FR-CH-05~11）。
- **步骤**：① `cordis_host_manager.cj` 构造 `PluginHost`（`:63-65`）后调 `setHandshakeVerifier`；② 回调内按 `pluginId` 从 `processEntries`(`:66`，由 `:184-185` 保存) 取 `PluginManifestEntry`；③ 调 `HandshakeVerifier.verify(entry, params.declaredCapabilities, provide: params.provide)`；④ 取不到条目 → 拒绝（未知从严）。
- **产出物**：`src/plugin/cordis_host_manager.cj`（改动）。
- **验收**：M-01 / M-02 / M-06。
- **本子系统负责**：注入与声明面取值。
- **不碰（移交/调用上游）**：**不依赖、不修改** `toCordisEntry`(`:263-274`) 与 `PluginEntry` 字段填充（归 dependency-graph）；**不改** `installHostServicesHook`(`:87-108`) 的表白名单逻辑（归 capability-governance CG-06 相关）。

### T-09 拉起前预检接入：`loadProcessPlugins` 在 `addDesired` 前调 CH-01
- **目标**：命中禁列表的插件**进程未被拉起**（FR-CH-12 / 硬条件 A）。
- **步骤**：① 在 `loadProcessPlugins` 条目循环内、应急开关(`:162`)与 command 必填校验(`:169-180`)之后、`addDesired`(`:198`) 之前插入 `auditEntry` 调用；② `Reject` → `LogUtils.error` + `result.failed.add("${name}(${reason})")` + `continue`（**不加入 desired**）；③ `Ok` → 走既有路径。
- **产出物**：`src/plugin/cordis_host_manager.cj`（改动）。
- **验收**：M-03（进程列表无对应 pid、端口未占用、其余插件照常加载）。
- **本子系统负责**：预检插入点与失败落地。
- **不碰（移交/调用上游）**：**不改** `reconcileDesired` / `awaitActive`(`:216`) / `LoadResult` 既有语义；**不改**应急开关(`:149-167`)。

### T-10 CH-02 安全终止器 `HandshakeSafeTerminator.terminate`
- **目标**：拒绝后进程安全终止、无僵尸（FR-CH-13 / DFX-CH-R2）。
- **步骤**：① 新增 `src/plugin/handshake_safe_terminator.cj`；② 先撤销路由（幂等）→ 再调既有 `host.removePlugin(pluginId)`（`plugin_host.cj:867`）；③ 全程 try/catch，失败记 `LogUtils.error` 后返回，不重抛；④ 重复调用无副作用。
- **产出物**：`handshake_safe_terminator.cj`（新增）。
- **验收**：M-07 ①；DFX-CH-R2/R3。
- **本子系统负责**：终止编排（顺序 + 异常兜底）。
- **不碰（移交/调用上游）**：**不自实现** kill / 进程句柄管理（复用 `removePlugin`）；**不订阅** `plugin.crashed` / `plugin.restarted`、**不做**退避/计数/熔断（归 lifecycle-observability IF-11）。
- **风险**：O-2 —— `ExternalPluginRouteGateway` 现为 `plugin_host_manager.cj:287` 局部构造，撤销通路待定；推荐 `CordisHostManager` 持有 gateway 引用，由人工编译确认后回写。

### T-11 拒绝对接：`Failed` 态触发终止 + 状态回写复用既有通道
- **目标**：把「拒绝」接到终止与可观测上（FR-CH-13 / DFX-CH-M1）。
- **步骤**：① `cordis_host_manager.cj` 新增**专用** `onStatusChange` 监听：`newStatus == Failed` → `HandshakeSafeTerminator.terminate`；② 确认既有 `installStatusListener`(`:73-81`) + `mapStatusToState`(`:473-482`) 把 `Failed` 映射到既有 `PluginState.Error`；③ 拒绝原因经既有通道落入 `agent_skills.last_error`（**脱敏后**）；④ 确认 `awaitActive` 对 `Failed` 返回 `Err` → `result.failed`(`:228`) → 宿主继续。
- **产出物**：`src/plugin/cordis_host_manager.cj`（改动，最小插入）。
- **验收**：M-07 ②③；DFX-CH-M1（三条留痕：日志 + `plugin.error` 事件 + 状态回写）；`agent_skills` **表结构零变更**。
- **本子系统负责**：监听挂载与脱敏后回写。
- **不碰（移交/调用上游）**：**不改** `mapStatusToState` 既有映射语义；**不新增**列/表/枚举值（R-06）；**不写** `operate_log`（审计归 capability-governance CG-03）。

### T-12 路由注册联动：`registerProcessPluginRoutes` 跳过失败集
- **目标**：闭环「握手失败插件的 HTTP 路由仍被挂载」缺口（FR-CH-14 / DFX-CH-S4）。
- **步骤**：① `plugin_host_manager.cj:143-155` 收集 `procResult.failed` 为 id 集合并传入 `registerProcessPluginRoutes`(`:155`)；② `:280-298` 新增第三参 `failedIds!`（带默认值），循环内跳过命中者并记 warn；③ 保持「非幂等、不得拿全量 list 重跑」的既有约束（`:173-175`）；④ `reconcile` 路径(`:250`)同样传入失败集。
- **产出物**：`src/plugin/plugin_host_manager.cj`（改动）。
- **验收**：M-05 ②③（未声明路由不挂载；已声明路由在拒绝后不挂载或已撤销）；`inspectRoutes()` 输出核对。
- **本子系统负责**：跳过失败集 + 拒绝后撤销。
- **不碰（移交/调用上游）**：**不改** `ExternalPluginRouteGateway` 转发实现（`external_plugin_route_gateway.cj`）；**不改**路由鉴权语义；**不做**插件自有路由的 `permissions` 逐条登记（O-6，须回主工程 §6 登记后另立任务）。

### T-13 应急开关与既有路径兼容复核
- **目标**：确认本子系统改动不破坏既有旁路（FR-CH-12 / §5.3.1-4）。
- **步骤**：① 验证 `CORDIS_SKIP_PROCESS_PLUGINS`（`cordis_host_manager.cj:149-167`）命中的插件仍被跳过、不进入预检与握手；② 验证 `reconcile` 增量路径（`:250`）下「先注册路由 → 后握手失败」由 T-10 撤销；③ 验证 `pluginInspect`（`plugin_host_manager.cj:475` 消费 `buildCapabilityCatalog`）输出未被本子系统改动影响。
- **产出物**：复核记录（写进 `test-report.md`）。
- **验收**：M-10。
- **本子系统负责**：兼容复核。
- **不碰（移交/调用上游）**：**不改** `buildCapabilityCatalog`（`skill_bridge.cj:112-125`）与其消费方 `inspect`；**不改**应急开关语义。

### T-14 防回退验证（R-04）
- **目标**：存量 51 个 skill 插件 + 4 个 sync 锚点行为零回归（DFX-CH-C1）。
- **步骤**：① 全量存量清单跑 `auditEntry` + `verify`（无 `provides`、不上报宣告）→ 期望 100% `Ok`；② 每条未上报者产生一条 warn；③ 宿主全量启动回归，比对 `loadAll` 的 loaded/failed/skipped 与基线一致。
- **产出物**：回归报告。
- **验收**：主工程 §5.1 用例 5「全量既有 51 个 skill 插件行为零回归」。
- **本子系统负责**：回归执行与结论。
- **不碰（移交/调用上游）**：回归中若发现非本子系统引入的失败，回主工程 §6 登记，**不顺手改**其他子系统代码。

### T-15 L1 单测
- **目标**：覆盖本子系统自身全部验收条件（FR-CH-01~14）。
- **步骤**：① 载荷：合法/非法 JSON/未知 type/空数组；② 比对：三维各自的通过与拒绝；③ 缺省放行；④ 非 process 轨直通；⑤ 幂等；⑥ **禁列表两处一致性**（`auditEntry` vs `verify` 同条目同理由串）；⑦ 脱敏（原因串不含明文）。
- **产出物**：单测代码 + 结果。
- **验收**：全部 L1 用例通过；P0 清零。
- **本子系统负责**：自身单测。
- **不碰（移交/调用上游）**：**不为**上游接口写单测（`version-guard` / `capability-governance` 各自负责）；上游用**假 verifier / 假 policy** 做替身。

### T-16 L2 跨子系统冒烟（含硬条件）
- **目标**：在与**已 done 的上游**合并后的运行态上跑契约 §6 全部用例（M-01 ~ M-10）。
- **步骤**：① M-01 主干（version-guard → 本子系统）；② M-02/M-06 三维拒绝（capability-governance → 本子系统）；③ M-03/M-04 禁列表两处复用；④ M-05 路由高危面；⑤ **M-07 硬条件**（进程未被拉起 / 已被安全终止 + 宿主启动不受影响）；⑥ M-08 防回退；⑦ M-09 载荷畸形；⑧ M-10 幂等与应急开关。
- **产出物**：冒烟报告 + `test-report.md`。
- **验收**：契约 §6 全部用例绿；**M-07 未通过则主工程闸口不予 confirm**。
- **本子系统负责**：用例执行与结论。
- **不碰（移交/调用上游）**：上游未达 `done` 时**不得**开跑（避免假失败）；L3 端到端由主工程 test 步执行，不在这里重复。

### T-17 文档与账本同步
- **目标**：把本子系统结论回写主工程账本，并补登记新暴露的共享冲突面。
- **步骤**：① `SPECS_INDEX.md` §2 把 `capability-handshake` 状态推进；② §3 核对 IF-08/IF-09 行；③ §4 **补登记 `plugin_config.cj` 三方共享冲突**（O-4）；④ §6 登记本轮变更影响面；⑤ 提出 CG-05 提升为 `IF-07a` 的请求（O-3）；⑥ 同步 §10.3 开放项结论（O-1/O-2 由人工编译确认后回填）。
- **产出物**：`SPECS_INDEX.md` 更新 + 本目录三份文档修订记录。
- **验收**：账本与本目录契约/设计**无漂移**。
- **本 subsystem 负责**：账本同步。
- **不碰（移交/调用上游）**：**不改**其他子系统的登记行内容，只补本子系统相关与共享冲突面。

---

## 需求覆盖追踪矩阵

| spec 需求编号/条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| FR-CH-01 载荷形状（服务维复用 `provide`） | T-03 | 全覆盖 | IF-08 |
| FR-CH-02 载荷可选与解析容错 | T-03、T-04 | 全覆盖 | 回落 `None` + warn |
| FR-CH-03 type 串同源 IF-05、未知从严 | T-03、T-05 | 全覆盖 | 依赖 IF-05 done |
| FR-CH-04 禁止自造能力枚举 | T-03、T-05 | 全覆盖 | 契约 §3.2 红线 |
| FR-CH-05 判定口径「上报 ⊆ 声明」 | T-05 | 全覆盖 | IF-09 |
| FR-CH-06 能力维比对（禁列表优先） | T-05、T-06 | 全覆盖 | IF-07 + CG-05 |
| FR-CH-07 服务维比对 | T-02、T-05 | 全覆盖 | 新增 `provides` |
| FR-CH-08 路由维比对（method+path 双命中） | T-05 | 全覆盖 | 复用 `httpRoutes` |
| FR-CH-09 缺省放行（R-04） | T-05、T-14 | 全覆盖 | 硬约束 |
| FR-CH-10 非 process 轨不比对 | T-05、T-06 | 全覆盖 | dylib/sync 直通 |
| FR-CH-11 幂等 + 不调用 IF-06 | T-05、T-15 | 全覆盖 | 纯函数 |
| FR-CH-12 拉起前静态预检（复用 IF-07） | T-06、T-09 | 全覆盖 | CH-01，硬条件 A |
| FR-CH-13 安全终止与状态回写 | T-10、T-11 | 全覆盖 | CH-02，硬条件 B |
| FR-CH-14 路由注册联动 | T-12 | 全覆盖 | 闭环 `plugin_host_manager.cj:143-155` 缺口 |
| DFX-CH-P1 单次线性比对 | T-05、T-15 | 全覆盖 | 无常驻任务 |
| DFX-CH-P2 不延长启动超时 | T-09、T-16 | 全覆盖 | `awaitActive` 30s 不变 |
| DFX-CH-R1 置 `Failed` 非 `Pending` | T-07 | 全覆盖 | 防握手风暴 |
| **DFX-CH-R2 硬条件：未拉起 / 已安全终止 + 宿主不受影响** | **T-09、T-10、T-11、T-16(M-07)** | **全覆盖** | **终验硬门槛** |
| DFX-CH-R3 异常不穿透 | T-07、T-10 | 全覆盖 | try/catch |
| DFX-CH-S1 禁列表单一真源、两处复用 | T-06、T-15、T-16(M-04) | 全覆盖 | 共用 `checkBanned` |
| DFX-CH-S2 未知从严（type / 路由） | T-05 | 全覆盖 | fail-closed |
| DFX-CH-S3 原因串不回显明文 | T-05、T-11 | 全覆盖 | 落 `last_error` 前脱敏 |
| DFX-CH-S4 路由挂载晚于握手结论 | T-12、T-10 | 全覆盖 | 跳过 + 撤销 |
| DFX-CH-M1 拒绝留痕走既有通道 | T-11 | 全覆盖 | 0 新列 |
| DFX-CH-M2 原因可定位维度 | T-05 | 全覆盖 | `dimension=` |
| DFX-CH-C1 存量零回归（R-04） | T-14、T-16(M-08) | 全覆盖 | 51 + 4 |
| DFX-CH-C2 字段追加向后兼容 | T-04、T-15 | 全覆盖 | 尾部默认参数 |
| 契约 §1 IF-08 | T-03、T-04 | 全覆盖 | — |
| 契约 §1 IF-09 | T-05、T-07、T-08 | 全覆盖 | — |
| 契约 §1 CH-01 | T-06、T-09 | 全覆盖 | — |
| 契约 §1 CH-02 | T-10、T-11 | 全覆盖 | — |
| 契约 §2 数据契约（0 新表 0 新列 / 无权限登记） | T-11、T-17 | 全覆盖 | 复核项 |
| 契约 §3.3 共享文件串行（R-05 + O-4） | T-02、T-04、T-17 | 全覆盖 | 阻塞依赖 |
| 契约 §6 M-01~M-10 | T-15、T-16 | 全覆盖 | M-07 为硬条件 |

**游离任务检查**：无。T-01（边界复核）与 T-17（账本同步）属铁律 15 强制动作，非游离。

---

## 验收检查清单（终验）

- [ ] 全部 spec 功能需求（FR-CH-01 ~ FR-CH-14）有对应实现并通过其验收条件
- [ ] DFX 约束（性能 P1/P2、可靠 R1/R2/R3、安全 S1~S4、可维护 M1/M2、兼容 C1/C2）已验证或标注豁免
- [ ] **硬条件 DFX-CH-R2 通过**：不兼容/不符声明的插件被拒绝时，L3 进程未被拉起或已被安全终止，宿主启动不受影响（契约 M-07，L1/L2/L3 三档复现）
- [ ] 复用项未被重新实现：`removePlugin` / `unregisterPluginRoutes` / `processEntries` / `mapStatusToState` / `awaitActive` / 应急开关均走既有（对照 `design.md` §2.4）
- [ ] **IF-07 单一真源**：全仓不存在第二份「跨进程禁能力」常量表；`auditEntry` 与 `verify` 结论与理由串逐字一致
- [ ] **未越界**：无 `CapabilityGate.check` 调用；未改 `checkMissing` / `topoSort` / `entryChanged` / `buildCapabilityCatalog`；未改崩溃自愈相关代码
- [ ] 0 新表 0 新列；`sql/incremental/` 无新增 DDL；`permissions` / `role_has_permission` 无新增登记行（本子系统无新增 HTTP 路由）
- [ ] 三方共享文件串行已遵守：`message.cj`（version-guard 先）、`plugin_config.cj`（capability-governance 先）
- [ ] 编译 / 类型检查 / lint 通过（**人工确认**，AI 不跑 `cjpm build`）
- [ ] spec / design / contract / tasks 四份文档与最终实现一致（无漂移）；开放项 O-1~O-6 已闭环或显式标注
- [ ] 主工程 `SPECS_INDEX.md` §2/§3/§4/§6 已同步（T-17）

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果 |
|---|---|---|---|---|
| 2026-10-19 | 第 1 轮（文档步） | `SPECS_INDEX.md` §2 登记行 + §3 IF-08/IF-09 + §4 R-05 + 基线侦察（全仓 `handshake` 0 命中） | 新建 `contract.md` / `spec.md` / `design.md` / `tasks.md` | 契约 4 接口（IF-08/IF-09/CH-01/CH-02）、0 新表 0 新列；判定口径「上报 ⊆ 声明」+ 缺省放行；IF-07 两处复用；任务 17 条，覆盖矩阵无游离项 |

**本轮已知风险与缺口（防回归锚点）**：

| 编号 | 级别 | 描述 | 归属 |
|---|---|---|---|
| RK-01 | P0 | `message.cj` 与 version-guard 并行改动 → 握手字段不一致（R-05） | T-04（阻塞于 version-guard done） |
| RK-02 | P0 | `plugin_config.cj` 三方共享未登记（O-4）→ 契约漂移 | T-02、T-17 |
| RK-03 | P0 | 若 `auditEntry`/`verify` 跑在上游未 done 的半成品上，会得到假失败 | T-16（上游 done 才开跑） |
| RK-04 | P1 | 握手失败插件的 HTTP 路由仍被挂载（基线 `plugin_host_manager.cj:143-155` 缺口） | T-12（必须闭环） |
| RK-05 | P1 | CG-05 作为上游内部接口被跨子系统消费（O-3） | T-05、T-17 |
| RK-06 | P2 | `DeclaredCapabilities` 包位置 / `Array<T>` 默认参数写法（O-1）、gateway 撤销通路（O-2） | 人工编译确认后回填 |

> 配套：本目录另可产出 `test-report.md`（模板 `skills/sdd/templates/test-report-template.md`），由 T-15 / T-16 执行阶段填写。
