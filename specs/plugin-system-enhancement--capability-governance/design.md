# 技术设计文档（capability-governance）

> 子系统 `feature_name`：`plugin-system-enhancement--capability-governance`
> 契约版本 `v1`（草案）｜ 配套：`contract.md` / `spec.md` / `tasks.md`
> 章节序：在 `templates/design_template.md` 的 §1~§10 之上**插入 §2「复用论证」并置于最前**，原因是主工程 `SPECS_INDEX.md` §7 **R-02** 强制要求本子系统先证明复用结论再谈设计；其余章节沿用模板原名。

## 文档信息

| 项 | 值 |
|---|---|
| 项目名称 | `plugin-system-enhancement--capability-governance`（能力清单与运行时门禁） |
| 版本 | v1 |
| 创建日期 | 2026-10-19 |
| 作者 | SDD 文档步（capability-governance 子系统） |
| 状态 | 草稿（待主工程闸口 confirm） |
| 语言 | 仓颉（Cangjie） |
| 编译约定 | **AI 不运行 `cjpm build`**；编译/类型检查/lint 由人工在独立 cmd 环境执行并回传 |

---

## 1. 设计概述

### 1.1 设计目标

1. 把今日唯一生效的 DB 表白名单（`tableWhitelist`）升级为覆盖六个维度的**统一能力模型**，并实现**缺省全拒**。
2. 为全部 `host.*` 宿主服务 handler 提供**单一判定入口**（IF-06），消除「各 handler 各自拼一句 if」的散落门禁。
3. 给出可被机器消费的**能力枚举 + 策略**（IF-05）与**跨进程禁列表**（IF-07），供下游 `capability-handshake` 与 `authoring-toolchain` 直接引用，杜绝三处各写一版。
4. 修复两个安全缺陷：**宿主环境全量泄漏**（R-03a）与 **`host.secret` 无 per-plugin 授权**（R-03b）。
5. 对既有 51 个 skill 插件与 4 个 sync 插件做到**清单零修改、行为零回归**（R-04）。

### 1.2 设计原则

| 原则 | 在本设计中的体现 |
|---|---|
| **复用优先（铁律 9）** | 结论：改造复用 `src/security/` 既有能力模型，不新建第二套引擎。完整论证见 §2 |
| **失败即关闭（fail-closed）** | 解析失败 / 未知能力 / 未知 pluginId 一律拒绝；**必须**修掉既有 `checkCapability` 对未知 type 的 fail-open（§2.3 G-0） |
| **单一判定点** | 所有能力判定只经 `CapabilityGate`；handler 侧不再出现第二种权限判断写法 |
| **确定性优先** | 清单字段、错误串、审计记录均为可解析的固定形态（spec §6.2），供 CLI 与日志共用 |
| **防回退优先** | 新增 `capabilities` 为可选字段，旧清单走 CG-06 降级推导，不在本轮强制迁移 |
| **边界清晰** | 不做握手比对、不做版本校验、不做 CLI；见 `contract.md` §4 |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 编程语言 | 仓颉（Cangjie） | 与宿主同源；代码编写使用 `cangjie-coder` 技能 |
| 能力模型载体 | **复用** `magic.skill.domain.models.{Capability, SecurityPolicy, ResourceLimits}` | `src/skill/domain/models/capability.cj:12/40/88` |
| 策略决策点（PDP） | **复用并改造** `magic.security.PermissionService` | `src/security/permission_service.cj:127` |
| 判定结果结构 | **复用** `magic.security.PermissionCheckResult` | `src/security/permission_service.cj:30-72` |
| 沙箱生命周期与记账 | **复用** `magic.security.{SandboxExecutor, SandboxManager}` | `src/security/sandbox_executor.cj:72/153` |
| 授权持久化 | **无**（0 新表 0 新列） | 声明式 `plugin.yaml` + 运行时派生；见 §5 |
| 审计持久化 | **复用** `operate_log` / `OperateLogService` | `src/app/services/uctoo/OperateLogService.cj:1021` |
| 日志 | **复用** `magic.log.LogUtils` | 与 `src/security/**` 现有写法一致 |

---

## 2. 复用论证（铁律 9 / R-02 强制，前置章节）

> R-02 原文要求：「`capability-governance` **必须先评估复用 `src/security/`**（改造复用优先于新建）；只有在论证『语义不可直接复用』后才新建，并把理由写进其 design.md」。

### 2.1 候选方案

| 方案 | 描述 | 结论 |
|---|---|---|
| **A. 改造复用 `src/security/`** | 以既有 `PermissionService` 作为唯一策略决策点（PDP），补全缺失维度与 fail-open 缺陷，在其之上加一层薄适配（翻译 + 编排），不新建第二套引擎 | ✅ **采纳** |
| B. 新建一套 `PluginCapabilityGate` 引擎 | 自建枚举、策略类、Result 类、限额类、审计数组 | ❌ 不采纳 |
| C. 直接调用、零改造 | 现状 `PermissionService` 原样接线 | ❌ 不可行，理由见 §2.3 G-0（对未知 type 走 fail-open） |

### 2.2 现存可复用资产清单（实证，带行号）

| 资产 | 位置 | 现状能力 | 与本子系统需求的契合度 |
|---|---|---|---|
| `Capability` 三元组（`type` / `resources` / `permissions`） | `src/skill/domain/models/capability.cj:12-34` | 已用「类型 + 资源清单 + 权限清单」表达一次能力请求 | **高度契合**：所需八项能力标识（`db.read` 等）可直接作为 `type` 字符串，资源名单进 `resources`，读/写标记进 `permissions`（该字段 `:16/:31-33` 今日无人消费，正好用来承载读写语义，不需加字段） |
| `SecurityPolicy` | 同上 `:40-82` | `allowNetworkAccess` / `allowFileSystemAccess` / `allowCommandExecution` / `executionTimeoutMs`；`default()`（`:74-81`）**三个开关全为 false** | **高度契合**：`default()` 已经是「缺省全拒」语义，S-01 无需新建概念，只需保持不被绕过 |
| `ResourceLimits` | 同上 `:88-130` | `maxMemory` / `maxCpuTime` / `maxNetworkBytes` / `maxFileOperations`；`default()`（`:122-129`）100MB / 30s / 10MB / 100 次 | **完全契合**：所需四类限额已齐备，直接沿用其缺省值（spec §5.5.1 规则 1 已固化） |
| `PermissionCheckResult` | `src/security/permission_service.cj:30-72` | `allowed` / `reason` / `deniedOperations` + `allow()`（`:57-63`）/ `deny(reason)`（`:65-71`） | **完全契合**：IF-06 的返回形态不需要自定义类型，宿主侧直接读 `.allowed` / `.reason` |
| `ResourceUsage` 记账容器 | 同上 `:74-125` | 四类用量 + `reset()`（`:103-108`） | **契合**：配合 `SandboxExecutor.reset()` 满足 spec §5.5.1 规则 3 |
| `PermissionService`（PDP） | 同上 `:127-340` | 六类判定：`checkFileSystemAccess`（`:163-189`）、`checkNetworkAccess`（`:191-215`）、`recordNetworkUsage`（`:217-229`）、`checkCommandExecution`（`:231-248`）、`recordMemoryUsage`（`:250-262`）、`recordCpuTimeUsage`（`:264-276`）、`checkExecutionTimeout`（`:278-290`）、`checkCapability`（`:292-322`） | **核心复用对象** |
| DENY / ALLOW 审计打点 | 同上 `:171/176/184/203/212/224/239/245/257/271/285` | 每个判定分支都有 `_auditLog.add("DENY: ...")` / `"ALLOW: ..."` | **可复用**，但有缺陷，见 §2.3 G-6 |
| `SandboxExecutor` | `src/security/sandbox_executor.cj:72-151` | 持有 per-instance `PermissionService`；`reset()`（`:142-145`）/ `cleanup()`（`:147-150`） | **契合**：天然支持「一个插件一份策略」 |
| `SandboxManager` | 同上 `:153-210` | `createSandbox()`（`:162-167`）/ `createSandbox(permissionService)`（`:169-174`）/ `removeSandbox()`（`:185-197`）/ `cleanupAll()`（`:203-209`） | **契合**：per-plugin 沙箱 ✅，正好映射「register / unregister」生命周期（CG-01），无需自写注册表容器 |

**零引用实证（R-02 前提复核）**：

```
$ cd apps/agentskills-runtime
$ grep -rn "import magic.security" src/
（0 命中）
```

对 `PermissionService` / `SandboxExecutor` 两个标识符在 `src/` 与 `libs/` 全域检索，命中的全部是 `src/app/**` 中名字相近但**语义无关**的 uctoo RBAC 服务（如 `PermissionsService`、`RoleHasPermissionService`、`UctooPermissionProvider`，见 `src/app/registry/AutoRouteConfig.cj:195/199`、`src/app/main.cj:545/596`）。结论：**确认为零引用死代码，与本轮判断一致。**

### 2.3 差距清单（为什么「零改造直接调用」不可行）

| 编号 | 差距 | 证据 | 严重度 | 处置 |
|---|---|---|---|---|
| **G-0** | **未知能力类型走 fail-open**：`checkCapability` 的 `match` 只识别 `filesystem`/`network`/`command` 三类；`case _` 分支只打一条 info 日志（`:308-309`），随后 `deniedOps` 为空 → 落到 `:321 return PermissionCheckResult.allow()` | `src/security/permission_service.cj:295-322` | **P0（阻断）** | **必须改造**。新增的五个能力类型若不在其中补上对应分支，将即时退化为放行动作，与 S-01 缺省全拒、R-01 失败即关闭正面冲突。**这是本次改造的头号理由，也是本子系统之所以存在的安全价值所在** |
| G-1 | 文件/网络/命令三类判定**只判总开关，不做资源匹配**：`checkFileSystemAccess(operation, path, requiredPermission)`（`:163-189`）收到 `path` 但从未参与判定；`requiredPermission` 形参亦未消费 | `src/security/permission_service.cj:163-189`、`:191-215`、`:231-248` | P1 | 改造：在既有方法体内补上资源/权限匹配；不改签名 |
| G-2 | 缺 `env.read`、`secret.read`、`db.read`、`db.write`、`proc.spawn` 五类能力语义 | 同上 match 仅三类 | P1 | 改造：扩展 `capability.cj` 的能力类型字符串集合 + `permission_service.cj` 的 match 分支；**不新增类** |
| G-3 | `SecurityPolicy` 缺 net/fs/cmd 之外的开关（env / secret / db / proc / 资源外键） | `capability.cj:40-56`（仅四个字段） | P1 | 改造：给 `SecurityPolicy` 加新布尔字段（**追加形参并给默认值**，保证既有 `init(...)` 调用点不破，见 §4.2.2）；或由 `CapabilityPolicy` 以「能动条目集合」形式持有，二者二选一，**倾向后者**（不碰既有类，见下方裁决） |
| G-4 | 缺乏 per-plugin 到 per-policy 的绑定与生命周期管理 | 无 | P1 | **不改造**：直接复用 `SandboxManager.createSandbox(permissionService)`（`:169-174`）+ `removeSandbox()`（`:185-197`），本子系统只在其上加一层 `pluginId → sandboxId` 的映射 |
| G-5 | `SandboxExecutor.executeInSandbox`（`:104-129`）只是「跑闭包 + catch 异常」，**不做 OS 级强制**（无 cgroup / Windows Job Object / 进程终止能力），也不存在任何 CPU/内存采集钩子 | `src/security/sandbox_executor.cj:104-136` | P1（范围外） | **不承诺 OS 级强制**（已写入 `contract.md` §4 明确不提供）。记账粒度沿用既有 `ResourceUsage`；采集不到就保持 0 且不据此拒绝（对应 spec §5.5.3 异常 2） |
| G-6 | `_auditLog`（`:131`）是无上界内存 `ArrayList` 且从不落盘，`getAuditLog()`（`:324-326`）无人消费 | `src/security/permission_service.cj:131/324-329` | P2 | 复用 AppendOnly 语义做短周期调试，**持久化另走 CG-03 → `operate_log`**。需给 `OperateLogService.recordPluginLog` 增 `source!` 可选形参（现 `:1039` 硬编码 `"host.db"`），缺省保持原行为 |
| G-7 | vendored cordis-cj 的 `PluginEntry` 无 `env` 字段，导致宿主 `plugin.yaml.env` 无处传道 | `libs/cordis-cj/cordis_core/src/config.cj:16-37`（serialize `:39-48` / deserialize `:50-76`） | P1 | 改造：给 `PluginEntry` 加 `env` 字段并纳入 serialize/deserialize；同时改 `launchStdio` 的取值基数（§4.4） |

> **G-3 裁决**：`SecurityPolicy` 是否需要加字段取决于「策略是不是必须由 PDP 全量解释」。本设计确定**不加**：新增的五个能力维度全部「粒度到资源」，`SecurityPolicy` 的那种「一个布尔管一类」的粗粒度开关语义不匹配。改为在新增的 `CapabilityPolicy` 中以「能力 → 资源清单」映射持有，再由 `CapabilityGate` 翻译成对既有 PDP 的一次调用。**这样 `capability.cj` 与 `permission_service.cj` 的改动面最小，只动 G-0 / G-1 / G-2 三处。**

### 2.4 复用结论

**结论：改造复用（方案 A）。**

- **复用**：`Capability` 三元组、`SecurityPolicy`、`ResourceLimits`、`PermissionCheckResult`、`PermissionService`（作为唯一 PDP）、`SandboxExecutor`/`SandboxManager`（生命周期与记账）、`LogUtils`、`operate_log`。
- **改造** 三处（且仅此三处落在既有文件上）：
  1. `permission_service.cj:292-322` —— 修复 G-0 fail-open + 扩展 G-2 能力类型 + 补 G-1 资源匹配。
  2. `libs/cordis-cj/cordis_core/src/config.cj:16-76` —— G-7 加 `env` 字段。
  3. `libs/cordis-cj/cordis_host/src/plugin_manager.cj:91-162` —— R-03a 环境收窄（§4.4）。
- **新建** 五个薄适配层文件（只做「翻译 + 编排」，不含策略引擎）：
  1. `src/security/capability/plugin_capability.cj` —— `PluginCapability` 枚举 + 与 `Capability.type` 字符串的双向映射（IF-05）
  2. `src/security/capability/capability_policy.cj` —— `CapabilityPolicy` + `fromManifest` + `intersectWithUnsupported`（IF-05 / CG-05）
  3. `src/security/capability/capability_gate.cj` —— `CapabilityGate`（`check` / `register` / `unregister`）（IF-06 / CG-01）
  4. `src/security/capability/host_unsupported_capabilities.cj` —— IF-07 常量表
  5. `src/security/capability/plugin_env_resolver.cj` —— `PluginEnvResolver`（CG-04）
  - 另:`CapabilityDecision`（CG-02）与 `CapabilityAuditSink`（CG-03）、`CapabilityMigration`（CG-06）合并入上述 3、5 两个文件，不单独开文件，避免过度拆分。
- **明确不新建**：不建第二套策略引擎、不建自定义 Result 类型、不建自定义限额类型、不建能力审计表、不建能力授权表（0 新表 0 新列）。

> 采信顺序提醒：以上五个新文件路径为**本设计提议**，落地前须与宿主既有包布局（`src/security/` 为 `package magic.security`）确认一致，仓颉子包 `magic.security.capability` 是否需要在 `src/` 下新建目录并纳入 `cjpm.toml` 编译清单 —— **待核实**（详见 §11.2 开放项 O-1）。

---

## 3. 系统架构

### 3.1 分层结构

```
┌──────────────────────────────────────────────────────────────┐
│ 插件侧（L3 process 轨 / L1-L2 sync 轨）                        │
│   host.db / host.mcp / host.secret / host.log /               │
│   host.cache / host.event / host.db_schema_lookup             │
└───────────────────────────┬──────────────────────────────────┘
                            │ JSON-RPC（cordis）
┌───────────────────────────▼──────────────────────────────────┐
│ 宿主接入层  CordisHostServices（src/plugin/cordis_host_services.cj）│
│   · 每个 host.* handler 在业务逻辑之前统一调用 CapabilityGate      │
│   · 拒绝 → 沿用既有 dbError / mcpError / secretError 结构         │
└───────────────────────────┬──────────────────────────────────┘
                            │ 进程内调用
┌───────────────────────────▼──────────────────────────────────┐
│ 本子系统新增「薄适配层」 magic.security.capability（5 个文件）    │
│   PluginCapability  CapabilityPolicy  CapabilityGate           │
│   HostUnsupportedCapabilities  PluginEnvResolver               │
│   CapabilityDecision / CapabilityAuditSink / CapabilityMigration│
└───────────────────────────┬──────────────────────────────────┘
                            │ 委托（唯一方向）
┌───────────────────────────▼──────────────────────────────────┐
│ 既有能力底座（改造复用）                                         │
│   PermissionService(PDP)  PermissionCheckResult                │
│   SandboxManager / SandboxExecutor（生命周期 + 记账）            │
│   Capability / SecurityPolicy / ResourceLimits                  │
└───────────────────────────┬──────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
   operate_log       LogUtils 日志       plugin.yaml 声明
   （既有审计表）      （既有）            （新增 capabilities 块）
```

### 3.2 模块划分

| 模块 | 职责 | 是否本轮新建 | 依赖方向 |
|---|---|---|---|
| `plugin_capability` | 稳定能力枚举 + 与 `Capability.type` 字符串互转 | 新建 | 被 policy / gate / handshake / toolchain 单向依赖 |
| `capability_policy` | 清单 → 策略；禁列表扣减；降级推导（CG-06） | 新建 | 依赖 `plugin_capability`、`SecurityPolicy`、`ResourceLimits`、`PluginManifestEntry` |
| `capability_gate` | per-plugin 注册表 + `check` 判定 + 统一错误/决策结构（CG-01/CG-02/CG-03） | 新建 | 依赖 `capability_policy` → `PermissionService`（单向） |
| `host_unsupported_capabilities` | IF-07 常量表 | 新建 | 无依赖（纯常量） |
| `plugin_env_resolver` | 子进程环境收窄（CG-04） | 新建 | 依赖 `capability_policy` |
| `PermissionService`（既有） | 策略决策点，执行实际 allow/deny 与记账 | **改造** | 被 `capability_gate` 单向调用 |
| `CordisHostServices`（既有） | 在每个 handler 前置门禁 | **改造** | 调用 `capability_gate` |
| `CordisHostManager`（既有） | Active 钩子注册/注销策略 | **改造** | 调用 `capability_gate` |
| `PluginManifestEntry`（既有） | 解析 `capabilities` 块 | **改造** | 被 `capability_policy` 读 |
| `cordis-cj PluginEntry / PluginManager`（vendored） | 承载 `env`；收窄后拉起子进程 | **改造** | 被 `plugin_env_resolver` 提供输入 |

### 3.3 组件交互（一次 host.db 调用的完整链路）

```
插件进程
  │ host.db { operation:"execute", table:"agent_tasks", ... }
  ▼
CordisHostServices.createDbHandler  (cordis_host_services.cj:224-241)
  ▼ unwrapInvokeParams → executeDbOperation (:450)
  ▼ 【本轮新增】CapabilityGate.check(pluginId, DbWrite, "agent_tasks")
      │
      ├─ 未注册 / 能力未授予 / 资源不在清单 / 超限
      │     → deny(reason) → CapabilityAuditSink.recordDeny → {"error": reason}
      │
      └─ allow
            ▼ 既有表白名单校验（:457-467，保留不删，作为第二道）
            ▼ 既有行级权限附加（:470-473，保留不改）
            ▼ executeExecute → ORM
```

> **为什么保留既有 `tableWhitelist` 校验而不替换为 `CapabilityGate` 独一道**：既有逻辑已经过验证且被 51 个插件依赖，替换风险高于收益；能力门禁作为**统一前置**，既有白名单退化为纵深防御的第二道。资源清单来源就是同一份 `tableWhitelist`（CG-06），两道结论天然一致。

---

## 4. 详细设计

### 4.1 模块一：`plugin_capability.cj`（IF-05 枚举）

#### 4.1.1 类/枚举设计

```
public enum PluginCapability {
    | DbRead        // type 串 "db.read"      资源单位：表名
    | DbWrite       // type 串 "db.write"     资源单位：表名
    | NetEgress     // type 串 "net.egress"   资源单位："alias" 或 "alias/tool"
    | FileRead      // type 串 "fs.read"      资源单位：路径前缀
    | FileWrite     // type 串 "fs.write"     资源单位：路径前缀
    | ProcessSpawn  // type 串 "proc.spawn"   资源单位：可执行名
    | EnvRead       // type 串 "env.read"     资源单位：环境变量名
    | SecretRead    // type 串 "secret.read"  资源单位："env:NAME" 或 通道 code
}
```

- 每个枚举要素映射到 `Capability.type` 字符串，`permissions` 列表承载 `read` / `write` 语义（复用既有未消费字段 `capability.cj:16/:31-33`，不新增）。
- 提供 `toCapabilityType()` / `fromCapabilityType(String): Option<PluginCapability>`；后者对无法识别的串返回 `None`，由调用方按 fail-closed 处理（对应 G-0）。

#### 4.1.2 接口设计

| 方法 | 签名 | 说明 |
|---|---|---|
| `toCapabilityType` | `(PluginCapability) -> String` | 枚举 → `Capability.type` 串 |
| `fromCapabilityType` | `(String) -> Option<PluginCapability>` | 串 → 枚举；未知返回 `None` |
| `all` | `() -> Array<PluginCapability>` | 全枚举，供 handshake / toolchain 遍历 |

#### 4.1.3 数据流

`plugin.yaml capabilities 键` → `fromCapabilityType` → 枚举 → `Policy` 内部 Map → `check` 时反向 `toCapabilityType` → `PermissionService.checkCapability(Capability(...))`。

### 4.2 模块二：`capability_policy.cj`（IF-05 策略 + CG-05 + CG-06）

#### 4.2.1 类设计

```
CapabilityPolicy
  pluginId            : String
  mode                : PluginMode
  resourceScopes      : HashMap<PluginCapability, ArrayList<String>>   // 仅授予的能力才有条目
  securityPolicy      : SecurityPolicy      // 复用既有（capability.cj:40）
  resourceLimits      : ResourceLimits      // 复用既有（capability.cj:88）
  derivedFromLegacy   : Bool                // CG-06 标记
```

#### 4.2.2 接口设计

| 方法 | 语义 | 备注 |
|---|---|---|
| `fromManifest(entry: PluginManifestEntry)` | 解析 `capabilities` 块 → policy；解析失败/未知键 → 忽略该项 + `WARN`（spec §5.1.1 规则 4） | **不是**整份失败 |
| `intersectWithUnsupported(mode)` | 用 IF-07 扣除 `Process` 模式下禁列表 | Sync/Dylib 不扣 FS/proc（因其在宿主进程内可被 PDP 直接检查） |
| `deriveFromTableWhitelist(entry)`（CG-06，静态） | 降级推导：仅产出 `DbRead`+`DbWrite`，且 `derivedFromLegacy=true` | 同时出现 `capabilities` 时不启用（spec §5.6.1 规则 3） |
| `grants(cap, resource?)` | 内部谓词：能力在 map 中 **且**（资源为空或命中清单） | fail-closed |

**为什么不落到 `SecurityPolicy` 加字段**：见 §2.3 G-3 裁决。后果是 `CapabilityPolicy` 需要自行提供 `SecurityPolicy`，构造时使用既有 `SecurityPolicy.default()`（`capability.cj:74-81`，三开关全 false）作为基值，再由 policy 决定 net/fs/cmd 三个布尔是否被打开 —— 这样既有 PDP 的三类粗粒度开关仍然生效，且与新的资源级判定叠加（**两者是「与」关系，不是替代**）。

#### 4.2.3 数据流

```
PluginManifestEntry
   ├─ capabilities 块存在 ──→ 逐项 fromCapabilityType + parseStringArray → resourceScopes
   ├─ 仅 tableWhitelist ───→ CapabilityMigration.deriveFromTableWhitelist → {DbRead,DbWrite}
   └─ 两者皆无 ────────────→ 空 map（全拒）+ 迁移 WARN
        ↓
   intersectWithUnsupported(mode)  ← HostUnsupportedCapabilities
        ↓
   CapabilityPolicy 实例 → CapabilityGate.register(pluginId, policy)
```

### 4.3 模块三：`capability_gate.cj`（IF-06 + CG-01~CG-03）

#### 4.3.1 类设计

```
CapabilityGate
  policies : HashMap<String, CapabilityPolicy>       // key = pluginId（幂等键）
  sandboxes: SandboxManager                          // 复用既有 sandbox_executor.cj:153
  sandboxOf: HashMap<String, String>                 // pluginId → sandboxId
```

#### 4.3.2 接口设计

| 方法 | 契约条目 | 语义 |
|---|---|---|
| `register(pluginId, policy)` | CG-01 | 幂等；重复注册覆盖 + `WARN`；内部 `sandboxes.createSandbox(buildPermissionService(policy))`（`sandbox_executor.cj:169-174`） |
| `unregister(pluginId)` | CG-01 | 移除 policy + `sandboxes.removeSandbox(id)`（`sandbox_executor.cj:185-197`，内部自动 `cleanup()`） |
| `check(pluginId, cap)` | IF-06 | 能力级判定（不看资源） |
| `check(pluginId, cap, resource)` | IF-06 minor 演进 | 资源级判定；返回 `PermissionCheckResult`（复用 `permission_service.cj:30-72`） |

**判定顺序（固定，不可调换）**：

1. `pluginId` 是否已在注册表 → 否：`deny("plugin '<id>' is not registered")`
2. `cap` 是否在 `resourceScopes` 中 → 否：`deny("capability '<type>' is not granted to plugin '<id>'")`
3. 若传了 `resource`：`resourceScopes[cap]` 是否包含该资源 → 否：`deny("resource '<r>' is not within the granted scope of capability '<type>'")`
4. 委托 `PermissionService.checkCapability(Capability(type, resources, permissions))`（`permission_service.cj:292-322`，改造后） → 返回其结果
5. 若 1~4 全部放行并且用了 sandbox 记账 → 调用 `SandboxExecutor.reset()`（`sandbox_executor.cj:142-145`）复位用量

> 第 4 步是刻意保留的：既有的三类粗粒度开关（`allowFileSystemAccess` / `allowNetworkAccess` / `allowCommandExecution`）应当作为**第二道**继续生效，即便某个 capability 已进白名单。**安全上的「与」叠加优于替换。**

#### 4.3.3 统一错误/审计结构

`CapabilityDecision`（CG-02）字段见 spec §6.2。错误串模板（转给 handler 时即 `{"error": <reason>}`）：

```
capability denied: plugin=<id> capability=<type>[ resource=<r>] reason=<具体原因>
```

- `resource` 部分在能力级拒绝时省略。
- **禁止**在 `<具体原因>` 中回显凭证明文或环境变量值（S-04）。

#### 4.3.4 数据流 / 时序

见 §3.3 与 spec §5.2.2。

### 4.4 模块四：`plugin_env_resolver.cj`（CG-04，修复 R-03a）

#### 4.4.1 现状与根因

| 事实 | 证据 |
|---|---|
| 宿主声明「L3 进程轨环境变量缺省空映射，**宿主侧不自动注入宿主环境**」 | `src/plugin/plugin_config.cj:100-101` |
| 但该字段解析后**从未被使用** | `src/plugin/plugin_config.cj:182-184` 解析 → `toCordisEntry`（`cordis_host_manager.cj:263-274`）不传 `env` |
| 而 vendored `launchStdio` 实际把宿主环境**全量**拷进 `envMap` 后 launch | `libs/cordis-cj/cordis_host/src/plugin_manager.cj:98-101` + `:161-162` |
| `PluginEntry` 根本没有 `env` 字段，宿主无处传值 | `libs/cordis-cj/cordis_core/src/config.cj:16-37` |

净效果：插件子进程可读 `orm_connectionUrl`、LLM key 等明文 —— 与 `host.secret` 的设计前提（"插件进程不继承宿主环境变量"，`cordis_host_services.cj:91`）**直接矛盾**。

#### 4.4.2 改造方案（白名单正向构造，非黑名单扣减）

```
resolve(entry, base) :
    1. out = 最小基础集（BaseMinimalSet，见下表）
    2. 叠加既有 cordis 元数据变量 CORDIS_PLUGIN_ID / _PROVIDE / _INJECT
       （plugin_manager.cj:158-160 现状行为，必须保留）
    3. 叠加既有 PATH 注入结果（plugin_manager.cj:125-151 的方案 A，必须保留，
       否则 Windows 下 stdx DLL 加载失败）
    4. 遍历 entry.env：
         仅当 EnvRead 资源清单包含该变量名时写入 out
         否则丢弃并 WARN
    5. return out
```

**BaseMinimalSet（最小基础集，需固化并在 §11.2 开放项 O-2 中复核）**：

| 变量 | 必要性 |
|---|---|
| `PATH` | 既有 DLL 搜索 PATH 注入机制依赖（`plugin_manager.cj:125-151`） |
| `PATHEXT` / `SYSTEMROOT` / `COMSPEC` / `TEMP` / `TMP` | Windows 子进程基础运行环境；缺失可能导致动态库加载或临时文件失败 |
| `USERPROFILE` | 部分运行时依赖 HOME 类路径 |
| `CORDIS_PLUGIN_ID` / `CORDIS_PLUGIN_PROVIDE` / `CORDIS_PLUGIN_INJECT` | 既有 cordis 协议下发（`plugin_manager.cj:158-160`） |

> 该集合的具体成员是否完备、是否有平台差异，属**待核实**（O-2）。实现时以「既有 process 插件能正常启动」为回归判据，不足则补，**禁止**用「恢复全量继承」来兜。

#### 4.4.3 与 vendored cordis-cj 的改动协调

需同时改三处，缺一不可：`config.cj` 加 `env` 字段（G-7）、`cordis_host_manager.cj:263-274` 的 `toCordisEntry` 传入 `entry.env`、`plugin_manager.cj:98-101` 改为接收外部提供的基底而非 `getVariables()`。

> **注意**：`libs/cordis-cj/` 是本仓内的 vendored 副本（`.gitmodules` 只登记 `submodules/CangjieMagic-Examples` 与 `submodules/CangjieCorpus`，cordis-cj **不在其中**），可改；但属上游库改动，须在 `design.md` 修订记录与 `tasks.md` 风险栏登记「回上游存在偏差」，避免将来拉新版时被静默覆盖。

### 4.5 模块五：`host_unsupported_capabilities.cj`（IF-07）

```
HostUnsupportedCapabilities.forMode(Process) = {
    FileRead, FileWrite,     // 无 host.fs handler：全仓 grep '"host.fs"' → 0 命中
    ProcessSpawn,            // 无对应宿主服务代派生
    EnvRead（仅限「继承宿主全部」语义，命名上以 EnvInheritHost 备注区别于具名单变量）,
    SecretRead 中的泛匹配引用
}
```

**依据**：L3 跨进程下，宿主能施加约束的**唯有自己代它做的事**（六个 `host.*` RPC 通道 + 子进程 env）。凡是没有宿主侧服务通道的能力，宿主既无法代理也无法验证，授予即等于「宣布有效但从不校验」→ 一律列入恒禁。

> **严谨性说明**：`EnvRead` 本身在后三种模式下是可授予的（具名单变量）。IF-07 禁的是「宿主环境全量继承」这一语义，二者在 policy 中需分列（见 spec §6.4 键名 `env.read` 仅限具名单）。实现时若发现命名易混淆，应在 `HostUnsupportedCapabilities` 里以**说明表**形式附加每个条目的禁用理由串，`capability-handshake` 直接取用该理由。

### 4.6 宿主 6 类 handler 的门禁接入点

| handler | 现状 | 本轮改动 |
|---|---|---|
| `host.db` | 表白名单生效（`cordis_host_services.cj:457-467`）；三种 operation 一律放行（`:476-482`） | **前置** `check(pluginId, DbRead/DbWrite, table)`：按 operation 分流——`query`/`count` → `DbRead`，`execute` → `DbWrite` |
| `host.db_schema_lookup` | 表白名单生效（`:293-302`） | **前置** `check(pluginId, DbRead, table)` |
| `host.mcp` | 只校验 alias/tool 非空（`:1162-1173`），**无白名单** | **前置** `check(pluginId, NetEgress, "<alias>/<tool>")`，并对 `listTools` 也判 `<alias>` 级（粗粒度） |
| `host.secret` | `env:NAME` 分支直接返明文（`:116-128`）；通道 code 分支（`:132-141`）同 | `method` 取值后、任何 `getEnv`/`resolveChannelSecret` 之前：**前置** `check(pluginId, SecretRead, ref)`；`has` 与 `get` 同权 |
| `host.log` / `host.cache` / `host.event` | 无门禁（键空间按插件名隔离：`cordis_host_services.cj:52`） | **不接入**门禁（键空间隔离已足够，避免范围蔓延，见 `contract.md` §4 明确不提供项） |

---

## 5. 数据设计

### 5.1 数据模型（新增，均为进程内对象）

`PluginCapability`（枚举）｜`CapabilityPolicy`｜`CapabilityDecision`｜`PluginEnvResolver` 输出 `HashMap<String,String>` —— 见 spec §6。

### 5.2 数据表设计

**0 新表、0 新列。** 论证如下：

| 候选持久化需求 | 为什么不需要建表/列 |
|---|---|
| 能力授权集 | 来源是声明式 `plugin.yaml`，宿主启动时一次性读取；无运行时在线变更诉求。持久化 = 把配置文件搬进数据库，属无收益搬运 |
| 运行时授权态 | 是配置 + 生命周期事件的**派生物**，进程重启后重新推导即可，无跨重启状态 |
| DENY 审计 | 复用既有 `operate_log` + `OperateLogService.recordPluginLog`（`src/app/services/uctoo/OperateLogService.cj:1021-1041`），仅需给 `source` 加可选形参（G-6） |

**因此**：
- `sql/incremental/` **无新增 DDL 文件**；
- `permissions` / `role_has_permission` **无新增登记行** —— 本子系统不新增任何宿主 HTTP 路由（`RequirePermissionMiddleware` 管的是 HTTP 路径，进程内调用不经过它）；
- 若后续实现中发现确需新列，须**先回主工程 SPECS_INDEX §6 登记**、写明复用不成立理由，再走 `loaddbinfo` → `crudgen`/`plugingen` → `crudweb` 确定性生成，禁止手写 DDL。

### 5.3 数据关系

```
PluginManifestEntry 1 ── 1 CapabilityPolicy  N ── M PluginCapability（带资源清单）
PluginManifestEntry 1 ── 1 PluginEntry.env（vendored，新增字段）
CapabilityPolicy    N ── 1 SecurityPolicy   N ── 1 ResourceLimits   （均复用既有类）
CapabilityDecision  N ── 1 operate_log 行    （经 CapabilityAuditSink）
```

---

## 6. API 设计

### 6.1 API 列表

本子系统**不提供 HTTP API**（铁律依据：门禁是进程内调用而非对外端点，无路由即无 API）。下表为对内 OpenAPI 等效清单。

| 类别 | 标识 | 契约条目 | 描述 |
|---|---|---|---|
| 进程内 | `PluginCapability.fromCapabilityType` | IF-05 | 串 → 枚举，未知返回 `None` |
| 进程内 | `CapabilityPolicy.fromManifest` | IF-05 | 清单 → 策略 |
| 进程内 | `CapabilityPolicy.intersectWithUnsupported` | CG-05 | 禁列表扣减 |
| 进程内 | `CapabilityGate.check(pluginId, cap[, resource])` | IF-06 | 能力门禁判定 |
| 进程内 | `CapabilityGate.register/unregister` | CG-01 | 生命周期绑定 |
| 进程内 | `HostUnsupportedCapabilities.forMode` | IF-07 | 常量读取 |
| 进程内 | `PluginEnvResolver.resolve` | CG-04 | 子进程环境收窄 |

### 6.2 详细设计（以 IF-06 为核心）

- **请求**：`(pluginId: String, cap: PluginCapability, resource!: String = "")`
- **响应**：`PermissionCheckResult`（复用 `permission_service.cj:30-72`）
  - `allowed: Bool`
  - `reason: Option<String>` —— 拒绝时**必非空**
  - `deniedOperations: ArrayList<String>` —— 拒绝时填入 `[cap.toCapabilityType()]`
- **错误约定**：门禁本身不抛错；拒绝经由宿主 handler 转成 `{"error": "<reason>"}` 返回。
- **幂等性**：`check` 无写副作用（除审计追加）；`register` 以 `pluginId` 为幂等键（contract §1 CG-01）。

---

## 7. 接口设计

### 7.1 内部接口

见 §6.1 表 + `contract.md` §1 完整表格（IF-05/06/07 + CG-01~06）。

### 7.2 外部接口（跨子系统）

| 方向 | 对象 | 内容 | 稳定性承诺 |
|---|---|---|---|
| 出（被消费） | `capability-handshake` | `PluginCapability` 枚举、`HostUnsupportedCapabilities`、`CapabilityPolicy`（经 CG-05 扣减后的有效集） | v1 冻结；新增枚举要素属 minor |
| 出（被消费） | `authoring-toolchain` | 同一份 `CapabilityPolicy.fromManifest` 语义，供 `plugin validate`（IF-12）静态复用 | v1 冻结 |
| 入（我依赖） | `version-guard` IF-02 | 仅依赖「清单字段解析在 `PluginManifestEntry` 内同源」这一口径 | 单向 |

> **显式不**：不 import `capability-handshake` 的任何符号；不让 `authoring-toolchain` 反向调用宿主内部状态。违反按 `contract.md` §3.3 判 P0。

---

## 8. 安全设计

### 8.1 认证机制

不适用 —— 插件身份由 cordis 握手建立，`pluginId` 在 Active 钩子处与 `CordisHostServices` 的 handler 闭包绑定（`cordis_host_services.cj:70-81`），本子系统不另行认证。

### 8.2 权限控制（本子系统的核心）

1. **缺省全拒**：未注册、未授予、资源不在清单，三者任一成立即拒绝（§4.3.2 判定顺序）。
2. **fail-closed**：`PluginCapability.fromCapabilityType` 返回 `None` → 拒绝；不因解析异常放行（对应 G-0 修复）。
3. **与既有粗粒度开关叠加**：即便能力已授予，仍需通过 `PermissionService` 的 net/fs/cmd 总开关（第二道）。
4. **不改行级权限语义**：既有宿主侧附加（`cordis_host_services.cj:470-473`）保持原样，本子系统只在其之前加一道。

### 8.3 数据安全（两个安全缺陷的闭环）

| 缺陷 | 闭环手段 | 回归判据 |
|---|---|---|
| 宿主环境全量泄漏（R-03a） | §4.4 白名单正向构造；移除 `plugin_manager.cj:98-101` 的 `getVariables()` 全量拷贝 | 子进程 env 枚举不得出现 `orm_connectionUrl` / LLM key；既有 process 插件仍能启动（`contract.md` M-05） |
| `host.secret` 任意取值（R-03b） | §4.6 在 `method` 判定之后、取值之前加 `check(pluginId, SecretRead, ref)`；`has` 与 `get` 同权 | 未授权 ref 返回 `{"ok": false, "error": ...}` 且不含 `value`（`contract.md` M-05） |

### 8.4 审计与留痕

- 每次 DENY → `CapabilityAuditSink.recordDeny`（CG-03）→ `operate_log`（`source` 标明宿主服务名）。
- 既有问题 `_auditLog` 仅作短周期调试，不做合规依据（G-6）。

---

## 9. 性能设计

### 9.1 性能目标

见 spec §4.1 P-01~P-04：单次 `check` < 1 ms（P99）、hot path 零 I/O、全部插件策略构建增量 ≤ 基线 5%。

### 9.2 优化策略

1. **预解析**：策略在 Active 钩子一次性构建（`cordis_host_manager.cj:87-108`），handler 只读内存。
2. **哈希查找**：`resourceScopes` 的值统一转为 Hash 结构（用 std 现成集合，不手写），避免列表线性扫描。
3. **零 I/O**：`check` 内部不得出现 DB / 网络 / 文件操作；审计写盘放在 `check` 返回之后异步/尽力而为（R-03）。
4. **记账复用**：资源用量由 `SandboxExecutor` 内部 `ResourceUsage` 承担（`permission_service.cj:74-125`），不在 `CapabilityGate` 另设计数器。

---

## 10. 部署设计

### 10.1 部署架构

无独立进程；随宿主二进制一同发布。新增代码为宿主进程内库代码。

### 10.2 环境配置（兼容性开关）

| 开关 | 缺省 | 作用 |
|---|---|---|
| 迁移期 WARN 开关 | 开 | 存量清单未声明 `capabilities` 时输出迁移提示（spec §5.6.3 异常 2） |
| 严格模式（强制显式声明） | **关** | 本轮**不实现**；是否实现交由 `authoring-toolchain` 的 `plugin validate` 决定，本子系统不参与，避免两个子系统都做「阻断」导致行为不一致 |

### 10.3 编译与回归

- AI 不运行 `cjpm build`；编译由人工在独立 cmd 环境完成并回传。
- 回归锚点：既有 51 个 skill 插件 + 4 个 sync 插件清单零修改、行为零变化（R-04 / `contract.md` M-06）。

---

## 11. 附录

### 11.1 参考文档

| 文档 | 用途 |
|---|---|
| `specs/plugin-system-enhancement/SPECS_INDEX.md` §2/§3/§7 | 边界账本、IF-05~07、R-02/R-03/R-04 |
| `docs/uctoo-v4/user-permission-system.md` / `row-level-permission-system.md` | 行级权限口径（沿用，不改） |
| `docs/uctoo-v4/uctoo-database-design-specification.md` | 0 新表的判定口径（铁律 9） |
| `design-principles.md`（legacy） | 命名 / 分层 / 统一错误响应约定 |
| `src/security/permission_service.cj`、`src/security/sandbox_executor.cj` | 复用对象源码 |
| `src/plugin/plugin_config.cj`、`cordis_host_manager.cj`、`cordis_host_services.cj` | 宿主接入点源码 |
| `libs/cordis-cj/cordis_core/src/config.cj`、`cordis_host/src/plugin_manager.cj` | vendored 库改动点 |

### 11.2 开放项 / 待核实清单

| 编号 | 问题 | 影响 | 处理建议 |
|---|---|---|---|
| **O-1** | 新包 `magic.security.capability` 是否需在 `cjpm.toml` 显式登记源码目录 | 不登记可能不参与编译 | 实现步第一步确认 `cjpm.toml`（已存在，见 `cjpm.toml:1`）的包/路径约定 |
| **O-2** | `BaseMinimalSet` 成员在各平台是否完备 | 漏变量 → 既有 process 插件启动失败 | 以「既有插件能启动」为回归判据逐步补齐；**禁止**回退到全量继承兜底 |
| **O-3** | `OperateLogService.recordPluginLog` 加 `source!` 可选形参 vs 新增 `recordCapabilityDeny` | 影响既有调用点兼容面 | 倾向加可选形参（向后兼容），实现步与code review 确认 |
| **O-4** | 资源用量（内存/CPU）在宿主上是否被可移植采集 | 采集不到则 G-5 相关判定无法启用 | 采集不到时保持 0 且不据此拒绝（spec §5.5.3 异常 2） |
| **O-5** | `LrtCompositionRunner`（`src/skill/lrt_composition_runner.cj:745`）的 `newProcess` 派生点是否可被归属到某个 pluginId | 决定 `ProcessSpawn` 门禁能否在其上落地 | 本轮只保证「策略 + 门禁 API」就绪；落地点接入需先核实插件上下文可达性，**待核实**，不得臆造归属关系 |
| **O-6** | `Dylib` 轨能力行为 | R-01：该轨运行时不可达 | 本轮标注未验证，不承诺 |

### 11.3 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-19 | SDD 文档步（capability-governance） | 初始版本：§2 完成 R-02 强制的复用论证（结论=改造复用），识别 G-0 fail-open 为首要改造点；0 新表 0 新列；锁定 vendored cordis-cj 三处改动用于修复 R-03a |
