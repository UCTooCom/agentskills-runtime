# 技术设计文档：崩溃自愈可观测（lifecycle-observability）

## 文档信息
- **项目名称**: plugin-system-enhancement--lifecycle-observability
- **版本**: v1.0
- **创建日期**: 2026-10-19
- **作者**: SDD 文档步（lifecycle-observability）
- **状态**: 草稿（待主工程闸口评审）
- **关联契约**: `./contract.md`（v1，LO-01~LO-06）
- **关联需求**: `./spec.md`（REQ-LO-001~013 / HA-LO-01 / AC-LO-02~21）

---

## 1. 设计概述

### 1.1 设计目标

1. 让 `healCrashed`（`libs/cordis-cj/cordis_host/src/plugin_host.cj:920-978`）从"无条件立即重拉"升级为"**可裁决、有退避、会计数、能熔断**"。
2. 让每次崩溃留下**结构化证据**（退出码 + stdout 尾帧 + 时刻），取代固定串 `"process exited unexpectedly"`（`:964`）。
3. 让 `autoRestart`（`src/plugin/plugin_config.cj:103-104`）成为**真正被消费**的配置项（R-07）。
4. 让崩溃/重启可观测：**复用**既有 `PluginEventBus` + `PluginSyncBridge` + `agent_skills` 既有列，0 新表 0 新列（R-06 / 铁律 9）。
5. 消灭 `inspectProcessPlugin` 的 docstring/实现漂移（R-08）。

### 1.2 设计原则

| 原则 | 落地约束 |
|---|---|
| **复用优先（铁律 9）** | 事件走既有 `PluginEventBus`；回写走既有 `PluginSyncBridge` + `agent_skills` 既有列；退避算法复用 `src/interaction/error_recovery_manager.cj:95-103` 的 `getBackoffMs` 范式；配置解析复用 `src/app/main.cj:929-944` 范式 |
| **底座优先（铁律 14）** | 不改 `libs/cordis-cj` 的对外协议；新增能力以**注入点**方式接入，不污染 cordis 核心状态机 |
| **观测面非控制面** | 所有观测动作（事件/回写/诊断）失败只记日志，绝不阻断生命周期（`plugin_sync_bridge.cj:25-27` 红线） |
| **死锁红线不回退** | `healCrashed` 的 `tryLock` + 整轮跳过语义（`plugin_host.cj:921-940`）原样保留；新增逻辑一律在**持锁区之外**执行 |
| **最小侵入** | cordis 库只新增"一个可注入接口 + 若干实例字段"，策略实现全部落宿主侧 |
| **禁止编造 API** | 所有仓颉 API 均带 `文件:行号` 佐证；无佐证者标「待核实」 |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 编程语言 | 仓颉（cangjie） | 宿主 `src/plugin/**` 与 vendored `libs/cordis-cj/**` 同栈 |
| 事件通道 | `PluginEventBus`（`libs/plugin-spi/src/plugin_event_bus.cj:60`） | 既有，同步 emit；与 `plugin.activated/deactivated/error/unloaded` 同总线 |
| 持久化 | `agent_skills.runtime_status` / `last_error` / `extra_metadata` | 既有三列，经 `PluginSyncBridge` 单向回写 |
| 进程控制 | `std.process.SubProcess`（`plugin_manager.cj:161-174` 已在用） | `wait(timeout:)` 取退出码，范式见 `src/app/services/tool/CrudGenService.cj:170` |
| 并发原语 | `Mutex` / `Condition`（`plugin_instance.cj:26-29` 已在用） | 新增观测字段不新增锁 |
| 构建 | **不运行 `cjpm build`** | 编译/类型检查由人工在独立 cmd 环境完成（项目既有约定） |

---

## 2. 系统架构

### 2.1 架构图

```
┌──────────────────────────────────────────────────────────────────────┐
│ 宿主进程 (magic.plugin)                                                │
│                                                                        │
│  src/app/main.cj:946-961  周期 reconcile (PLUGIN_RECONCILE_INTERVAL)   │
│          │                                                             │
│          ▼                                                             │
│  CordisHostManager (src/plugin/cordis_host_manager.cj:39)              │
│    ├─ processEntries: HashMap<name, PluginManifestEntry>   (:47)       │
│    │     └─ 提供 autoRestart 语义源 (plugin_config.cj:104)             │
│    ├─ [新] DefaultRestartController   ────── 注入 ────┐                │
│    ├─ [新] StdoutTailBuffer  ← 挂在 logger (:60-65)   │                │
│    └─ inspectProcessPlugin (:395)  ← [改] 输出对齐     │                │
│                                                        │               │
│  libs/cordis-cj/cordis_host/src/plugin_host.cj          │               │
│    └─ healCrashed (:920-978)                            │               │
│         ├─ tryLock 死锁红线 (:935-940)  ← 不动          │               │
│         ├─ isExited 检测 (:951-960)     ← 不动          │               │
│         ├─ [新] CrashDiagnostics.capture(instance)       │               │
│         ├─ [调] restartController.onCrash(id, inst) ◄────┘              │
│         ├─ [改] error = 结构化串（取代 :964 固定串）                    │
│         ├─ [改] 退避判定：未到 nextEligibleAtMs → 本轮不拉起            │
│         └─ [调] launchPlugin (:970) 成功/失败 → restartCount++          │
│                                                                        │
│  PluginEventBus (libs/plugin-spi:60)                                   │
│    ├─ plugin.crashed   [新] ──┐                                        │
│    └─ plugin.restarted [新] ──┤                                        │
│                               ▼                                        │
│  PluginSyncBridge (src/plugin/plugin_sync_bridge.cj:33)  [改: +2 订阅]  │
│    └─ agent_skills: runtime_status / last_error / extra_metadata        │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

| 模块 | 落点 | 职责 |
|---|---|---|
| **M1 `CrashInfo` / `CrashDiagnostics`** | `libs/cordis-cj/cordis_host/src/`（新文件 `crash_diagnostics.cj`） | 崩溃一次性快照：退出码 + stdout 尾帧 + 时刻 |
| **M2 `RestartDecision` / `RestartController`** | `libs/cordis-cj/cordis_host/src/`（新文件 `restart_controller.cj`） | cordis 侧**注入点** + 默认实现（恒立即重启 = 现行行为） |
| **M3 `RestartPolicy` / `RestartState`** | 宿主 `src/plugin/`（新文件 `plugin_restart_policy.cj`） | 纯函数策略：退避/计数/熔断/冷却/半开 |
| **M4 `DefaultRestartController`** | 宿主 `src/plugin/plugin_restart_policy.cj` 内 | 把 `RestartPolicy` 与 `processEntries.autoRestart` 缝合，注入 cordis |
| **M5 `StdoutTailBuffer`** | 宿主 `src/plugin/`（新文件 `plugin_stdout_tail.cj`） | per-plugin 环形缓冲，挂在既有 logger 闭包上 |
| **M6 `LifecycleEventEmitter`** | 宿主 `src/plugin/plugin_lifecycle_events.cj` | 组装 IF-11 载荷并 emit |
| **M7 实例观测字段** | `libs/cordis-cj/cordis_host/src/plugin_instance.cj:17-42`（改） | restartCount/crashCount/lastRestartAtMs/nextEligibleAtMs/circuitState/lastCrash |
| **M8 检视输出** | `src/plugin/cordis_host_manager.cj:395-414`（改）+ `src/plugin/plugin_host_manager.cj:461-492`（改） | 输出对齐 + 接线进 `plugin_inspect` |
| **M9 事件消费** | `src/plugin/plugin_sync_bridge.cj:41-60`（改） | 新增 `plugin.crashed` / `plugin.restarted` 两个订阅 |

### 2.3 组件交互

```
reconcile → PluginHost.reconcileDesired (:787)
              → healCrashed (:920)
                  → tryLock? 否 → 跳过(:935)
                  → 快照 desired ∩ actual (:941-947)  [在锁内，仅读]
                  → isExited 逐实例判定 (:950-954)    [锁外]
                  → 逐崩溃实例:
                      ① CrashDiagnostics.capture(instance)      [新增, 锁外]
                      ② instance.error = 结构化串               [改]
                      ③ decision = restartController.onCrash(...) [新增, 锁外]
                      ④ LifecycleEventEmitter.crashed(...)       [新增, 锁外]
                      ⑤ if decision.action == Restart:
                             if now < nextEligibleAtMs: 记日志, 本轮不拉起
                             else: launchPlugin(e) (:970)
                                   instance.restartCount++ / lastRestartAtMs=now
                                   LifecycleEventEmitter.restarted(...)
                         elif GiveUp: circuit=Open, 不拉起
                         elif Skip:   不拉起, restartCount 不变
```

---

## 3. 详细设计

### 3.1 M1 崩溃诊断捕获

#### 3.1.1 数据结构

```cangjie
// libs/cordis-cj/cordis_host/src/crash_diagnostics.cj
public class CrashInfo {
    public var exitCode: ?Int64 = None          // SubProcess.wait(timeout:) 返回值
    public var signal: ?String = None           // Windows 恒 None（待核实跨平台取值）
    public var stdoutTail: ArrayList<String> = ArrayList()
    public var detectedAtMs: Int64 = 0
}
```

#### 3.1.2 退出码获取

- 依据：`src/app/services/tool/CrudGenService.cj:170` `let exitCode = subProcess.wait(timeout: timeoutDuration)`，随后 `:180` 与 0 比较 —— 佐证 `SubProcess.wait(timeout:)` 存在且返回可比较的整型退出码。
- 实现：`capture()` 内 `try { instance.process.wait(timeout: Duration.second * 1) }`，异常/超时 → `exitCode = None`。
- **风险**：插件进程若在 `isExited` 判定时已被 OS 回收，`wait` 可能返回平台相关值；**待核实**仓颉在 Windows 下对已回收子进程的 `wait` 语义。兜底：异常即 `None`，不影响裁决。

#### 3.1.3 stdout 尾帧（stderr 的等价替代）

**为什么不用 stderr**：
`plugin_manager.cj:163-174` 明确记载——stderr 改为 `ProcessRedirect.Inherit` 是为修复"每插件 1 条阻塞读线程 × 4 插件 占满 8 线程池导致主线程饿死"的启动挂死。改回 `Pipe` 会**重现 P0 故障**。本设计**禁止**改动该行（contract §4）。

**替代方案**：
在宿主侧既有 stdout 转发闭包（`cordis_host_manager.cj:60-65`，`LogUtils.info("[cordis][${pluginId}] ${line}")`）内追加一行 `StdoutTailBuffer.push(pluginId, line)`。该闭包**已在同步路径上被调用**，不新增线程、不新增阻塞读，零线程开销。

```cangjie
// src/plugin/plugin_stdout_tail.cj
public class StdoutTailBuffer {
    private let maxLines: Int64          // PLUGIN_RESTART_TAIL_LINES，缺省 20
    private let maxLineBytes: Int64 = 1024
    private let tails: ConcurrentHashMap<String, ArrayList<String>>

    public func push(pluginId: String, line: String): Unit   // 截断 + 环形覆盖
    public func snapshot(pluginId: String): ArrayList<String> // 崩溃时取副本
    public func clear(pluginId: String): Unit                 // 卸载时清理
}
```

- 内存上界：`maxLines(20) × 1KB × 插件数`，满足 REQ-LO-DFX-02（≤512KB @ ≤25 插件）。

#### 3.1.4 结构化 error 串

取代 `plugin_host.cj:964` 的固定串：

```
exitCode=3 signal=none at=<epochMs> tail=<最后一行截断至200字符>
```

`instance.error`（`plugin_instance.cj:31`）保持 `?String` 类型不变，避免下游匹配逻辑破坏。

### 3.2 M2 重启裁决注入点（cordis 侧）

#### 3.2.1 接口

```cangjie
// libs/cordis-cj/cordis_host/src/restart_controller.cj
public enum RestartAction { | Restart | GiveUp | Skip }

public class RestartDecision {
    public var action: RestartAction = RestartAction.Restart
    public var delayMs: Int64 = 0
    public var reason: String = ""
}

public interface RestartController {
    func onCrash(id: String, instance: PluginInstance): RestartDecision
}

/// 默认实现 = 现行行为（立即重拉），保证存量零回归与 cordis 库独立可用性
public class AlwaysRestartController <: RestartController {
    public func onCrash(id: String, instance: PluginInstance): RestartDecision {
        RestartDecision(RestartAction.Restart, 0, "default")
    }
}
```

#### 3.2.2 注入方式

`PluginHost` 新增 `public func setRestartController(c: RestartController): Unit`，内部字段缺省 `AlwaysRestartController`。
宿主 `CordisHostManager.init()`（`cordis_host_manager.cj:57-70`）在 `installStatusListener()` 之后调用注入。

- **求值方式（供下游测试替身）**：构造注入，宿主可在单测中注入 `FakeRestartController` 断言 `healCrashed` 的分支行为。
- **不改 `PluginEntry`**（`libs/cordis-cj/cordis_core/src/config.cj:16-48`）：避免 cordis 库耦合 `plugin.yaml` 语义（spec AC-LO-10 / §5.4.1 禁止项）。

### 3.3 M3 退避与熔断策略（宿主侧纯函数）

#### 3.3.1 状态与算法

```cangjie
// src/plugin/plugin_restart_policy.cj
public enum CircuitState { | Closed | Open | HalfOpen }

public class RestartState {
    public var restartCount: Int64 = 0
    public var crashCount: Int64 = 0
    public var lastRestartAtMs: Int64 = 0
    public var firstCrashAtMs: Int64 = 0
    public var circuit: CircuitState = CircuitState.Closed
    public var cooldownUntilMs: Int64 = 0
    public var nextEligibleAtMs: Int64 = 0
    public var lastCrash: ?CrashInfo = None
}

public class RestartPolicyConfig {
    public var maxRestarts: Int64 = 5
    public var windowSeconds: Int64 = 300
    public var baseBackoffMs: Int64 = 1000
    public var maxBackoffMs: Int64 = 30000
    public var cooldownSeconds: Int64 = 300
    public var tailLines: Int64 = 20
    // 解析：getVariable + Int64.parse + try 兜底（范式 src/app/main.cj:929-944）
    public static func fromEnv(): RestartPolicyConfig
}
```

**退避**（复用 `src/interaction/error_recovery_manager.cj:95-103` 同款公式）：

```
delayMs = min(baseBackoffMs × 2^restartCount, maxBackoffMs)
```

**裁决伪码**（`RestartPolicy.decide(state, nowMs)`）：

```
1. if state.circuit == Open:
       if cooldownSeconds == 0 -> return {Skip, reason="circuit-open-manual-reset"}
       if nowMs < state.cooldownUntilMs -> return {GiveUp, reason="circuit-open-cooling"}
       else -> state.circuit = HalfOpen; fallthrough (允许 1 次)
2. if nowMs < state.nextEligibleAtMs -> return {GiveUp, reason="backoff-pending"}  // 本轮不拉起
3. if state.restartCount >= maxRestarts:
       state.circuit = Open
       state.cooldownUntilMs = nowMs + cooldownSeconds*1000
       return {GiveUp, reason="restart-storm", delayMs=0}
4. delayMs = min(base × 2^restartCount, maxBackoff)
   state.nextEligibleAtMs = nowMs + delayMs
   return {Restart, delayMs, reason="backoff"}
```

**窗口清零**：`healCrashed` 之外，宿主侧在 `onStatusChange` 回调（`cordis_host_manager.cj:71-80`）中，当 `newStatus == Active` 时记录 `activeSinceMs`；`decide` 入口先判 `nowMs - activeSinceMs > windowSeconds*1000` → `restartCount = 0`、`firstCrashAtMs = nowMs`（`crashCount` 不清零，符合 REQ-LO-003 / AC-LO-06）。

#### 3.3.2 状态存放位置

| 数据 | 存放 | 理由 |
|---|---|---|
| `restartCount` / `crashCount` / `circuitState` / `nextEligibleAtMs` | **`PluginInstance` 新增字段**（M7） | `inspectProcessPlugin` 直接读 `instance`，无需跨层查询；实例销毁即状态销毁，无泄漏 |
| `RestartPolicyConfig` | 进程级单例（`CordisHostManager` 成员） | 全局配置，读一次 |
| `activeSinceMs` | `PluginInstance` 新增字段 | 与计数同生命周期 |

### 3.4 M4 `DefaultRestartController`（宿主侧）

```cangjie
public class DefaultRestartController <: RestartController {
    private let policy: RestartPolicy
    private let entries: HashMap<String, PluginManifestEntry>  // cordis_host_manager.cj:47

    public func onCrash(id: String, instance: PluginInstance): RestartDecision {
        // 1. autoRestart 优先（R-07 真正消费点）
        match (this.entries.get(id)) {
            case Some(e) =>
                if (!e.autoRestart) {
                    return RestartDecision(Skip, 0, "autoRestart-disabled")
                }
            case None => LogUtils.warn("[Restart] no manifest entry for '${id}', assume autoRestart=true")
        }
        // 2. 策略裁决
        return this.policy.decide(instance.restartState, nowMs())
    }
}
```

- 异常兜底：整体 `try/catch`，异常 → `{Skip, 0, "controller-error"}` + `diag` 日志，**不向 `healCrashed` 抛**（contract LO-02 错误约定）。

### 3.5 M6 事件发射（IF-11）

```cangjie
// src/plugin/plugin_lifecycle_events.cj
public class LifecycleEventEmitter {
    private let bus: PluginEventBus        // PluginHostManager.bus(): plugin_host_manager.cj:507
    private var crashSeq: Int64 = 0        // 单调，进程级

    public func crashed(id: String, crash: CrashInfo, decision: RestartDecision,
                        state: RestartState): Unit
    public func restarted(id: String, seq: Int64, count: Int64,
                          delayMs: Int64, success: Bool): Unit
}
```

- 载荷结构见 `contract.md` §1.1；`crashSeq` 由 `synchronized` 自增，作为去重键。
- **`bus()` 获取方式**：`CordisHostManager` 需持有 `PluginHostManager` 句柄。**待核实**：当前 `CordisHostManager.init()`（`cordis_host_manager.cj:57-70`）无该句柄；需确认 `PluginHostManager` 创建 `CordisHostManager` 的位置（推测在 `plugin_host_manager.cj` 三轨分发处），以构造参数或 setter 注入。

### 3.6 M7 `PluginInstance` 字段扩展

在 `plugin_instance.cj:18-31` 现有字段之后追加（**不改既有字段语义**）：

```cangjie
public var restartCount: Int64 = 0
public var crashCount: Int64 = 0
public var lastRestartAtMs: Int64 = 0
public var firstCrashAtMs: Int64 = 0
public var nextEligibleAtMs: Int64 = 0
public var activeSinceMs: Int64 = 0
public var circuitState: CircuitState = CircuitState.Closed
public var cooldownUntilMs: Int64 = 0
public var lastCrash: ?CrashInfo = None
```

- `CircuitState` / `CrashInfo` 定义在 `libs/cordis-cj/cordis_host/src/`（cordis 侧自洽，宿主 import）。
- 不新增锁：所有写发生在 `healCrashed` 的**锁外单线程路径**或 `settleLock` 已保护的 `transitionTo` 邻近区；读发生在 `inspectProcessPlugin`（只读展示，容忍瞬时不一致）。

### 3.7 M8 检视输出对齐

```cangjie
// src/plugin/cordis_host_manager.cj:395 改写
public func inspectProcessPlugin(name: String): String {
    // 输出行（顺序固定，便于 Agent 解析）：
    // process plugin=<name>
    // status=<InstanceStatus>
    // command=<source>
    // pid=<n | unknown>            ← 待核实（见下）
    // restartCount=<n>
    // crashCount=<n>
    // circuit=<closed|open|half-open>
    // nextRestartAtMs=<epochMs>
    // lastExitCode=<n | (none)>
    // lastError=<text>
}
```

**pid 待核实**：全仓 `grep "\.pid"` 零命中，**未找到**仓颉 `std.process.SubProcess` 暴露 pid 的佐证。处理分支：
- **分支 A（可获取）**：正常输出 `pid=<n>`，docstring 保留 pid 承诺。
- **分支 B（不可获取）**：输出行改为不出现 `pid`，并**同步修改 `:391` 的 docstring** 去掉 pid 承诺（R-08 的另一种合规解法：文档对齐实现）。两分支由 tasks T-14 在编码步实测裁定，禁止输出占位假值（spec AC-LO-13b）。

**接线进 `plugin_inspect`**：`PluginHostManager.inspect(name:)`（`plugin_host_manager.cj:461-477`）在 `registry.get(n)` 为 `None` 时，改为先查 process 轨；命中则拼接 `inspectProcessPlugin(n)` 的返回段，仍为 `None` 才返回 `plugin not found`。

### 3.8 M9 事件消费侧（`PluginSyncBridge` 改造）

在 `plugin_sync_bridge.cj:41-60` 的 `bind()` 内追加两个订阅（**与 M6 同轮完成**）：

```cangjie
eventBus.subscribe("plugin-sync-bridge", "plugin.crashed", { payload =>
    let name = this.extractField(payload, "name")
    let summary = this.buildCrashSummary(payload)     // "exitCode=3 restartCount=5 circuit=open"
    this.writeRuntimeState(name, "error", errorMessage: Some(summary))
    this.mergePluginMetadata(name, this.crashFragment(payload))  // extra_metadata.lifecycle.crash
    JsonString("ok")
})
eventBus.subscribe("plugin-sync-bridge", "plugin.restarted", { payload =>
    let name = this.extractField(payload, "name")
    this.mergePluginMetadata(name, this.restartFragment(payload))
    JsonString("ok")
})
```

- **复用** `writeRuntimeState`（:67-97）与 `mergePluginMetadata`（:104-130）两个既有方法，不新增 DAO、不改 PO。
- 单向红线（:29）保持：只读事件 → 只写库，不反向改 `plugin.yaml`。

---

## 4. 数据设计

### 4.1 数据模型

进程内三元组：`CrashInfo`（单次崩溃证据）/ `RestartState`（单实例重启账本）/ `RestartDecision`（单次裁决结果）。三者均**不落库为独立结构**。

### 4.2 数据表设计

**0 新表 / 0 新列**（contract §2）。落库映射：

| 进程内数据 | 落库列 | 写入通道 | 写入者 |
|---|---|---|---|
| `CrashInfo.exitCode` / `restartCount` / `circuit` | `agent_skills.last_error`（单行摘要，≤2KB） | `writeRuntimeState(name,"error",errorMessage:)` | `PluginSyncBridge` |
| `CrashInfo` 完整结构 + `RestartState` 快照 | `agent_skills.extra_metadata`（JSON fragment，键前缀 `lifecycle.`） | `mergePluginMetadata(name, fragment)` | `PluginSyncBridge` |
| `Failed`/`Unreachable` → Error | `agent_skills.runtime_status = 'error'` | 同上 | `PluginSyncBridge` |

`extra_metadata` fragment 示例：

```jsonc
{
  "lifecycle.crash": {
    "crashSeq": 7, "exitCode": 3, "signal": null,
    "stdoutTail": ["...", "..."], "detectedAtMs": 1760000000000,
    "restartCount": 5, "maxRestarts": 5, "circuit": "open", "action": "give-up"
  },
  "plugin": true
}
```

### 4.3 数据关系

- `agent_skills.name` ↔ 插件 id（`findByName` 按 name + `deleted_at IS NULL`，`plugin_sync_bridge.cj:133-141`）—— 既有关系，不变。
- 进程内 `RestartState` ↔ `PluginInstance` 一对一，随实例销毁而销毁（**不持久化**，`agent_skills` 中只保留"最近一次"快照）。

---

## 5. API 设计

### 5.1 API 列表

**本子系统不新增任何 HTTP 路由**（无 UI、无 metrics 端点、无新 Agent 工具），因此**不触发 `permissions` / `role_has_permission` 登记**（铁律 14 的路由补登记条款在本子系统无适用面，显式声明以免漏项误判）。

对外仅**进程内调用**与**事件**两类（contract §1）：

| 编号 | 类型 | 标识 | 方向 |
|---|---|---|---|
| LO-01 / IF-11 | 事件 | `plugin.crashed` / `plugin.restarted` | 本子系统 → 总线 → `PluginSyncBridge` |
| LO-02 | 进程内 | `RestartController.onCrash` | cordis → 宿主（注入） |
| LO-03 | 进程内 | `RestartPolicy.decide` | 宿主内部纯函数 |
| LO-04 | 进程内 | `CrashDiagnostics.capture` | cordis 内部 |
| LO-05 | 进程内 | `PluginInstance` 观测字段 | 读写 |
| LO-06 | Agent 工具输出 | `plugin_inspect`（既有） | Agent → 本子系统 |

### 5.2 详细设计（事件载荷）

见 `contract.md` §1.1（唯一权威口径，本文件不复制以免双源漂移）。

---

## 6. 接口设计

### 6.1 内部接口

| 调用方 | 被调方 | 签名 | 失败语义 |
|---|---|---|---|
| `PluginHost.healCrashed` | `CrashDiagnostics.capture` | `(PluginInstance) -> CrashInfo` | 字段置 None，不抛 |
| `PluginHost.healCrashed` | `RestartController.onCrash` | `(String, PluginInstance) -> RestartDecision` | 实现内部兜底为 Skip，不抛 |
| `PluginHost.healCrashed` | `LifecycleEventEmitter.crashed/restarted` | `(...) -> Unit` | 仅记日志 |
| `CordisHostManager.init` | `PluginHost.setRestartController` | `(RestartController) -> Unit` | — |
| `CordisHostManager.init` | `StdoutTailBuffer.push`（闭包内） | `(String, String) -> Unit` | 静默丢弃 |
| `PluginHostManager.inspect` | `CordisHostManager.inspectProcessPlugin` | `(String) -> String` | 未命中返回 not found |

### 6.2 外部接口

无（不新增对外 HTTP / RPC 端点）。

---

## 7. 安全设计

### 7.1 认证机制
不涉及（无新增端点，全部进程内）。

### 7.2 权限控制
- Agent 侧沿用既有 `plugin_inspect` 工具的权限口径，不新增工具即不新增权限面。
- DB 回写沿用 `PluginSyncBridge` 既有 DAO 权限路径（`ORM.executor() as AgentSkillsDAO`），不绕过行级判定。

### 7.3 数据安全
- **REQ-LO-DFX-06**：stdout 尾帧双截断（行级 1KB + 帧数 20），防止插件刷屏打爆 `last_error` 与 `extra_metadata`。
- **REQ-LO-DFX-07**：crash 载荷**只含** exitCode / signal / stdoutTail / 时刻 / 计数；**不含** `instance.entry.source` 完整命令行、不含宿主 env（规避 R-03 泄漏面在本子系统被放大）。
- 熔断本身是**资源可用性保护**：防止崩溃插件耗尽 PID / 内存 / 线程池。

---

## 8. 性能设计

### 8.1 性能目标
- 单插件崩溃裁决 ≤ 5ms；单轮 20 崩溃插件裁决 ≤ 100ms（REQ-LO-DFX-01）。
- `StdoutTailBuffer` 总内存 ≤ 512KB（REQ-LO-DFX-02）。
- 不新增常驻线程、不新增阻塞读（`healCrashed` 仍在既有 reconcile 线程内）。

### 8.2 优化策略
1. **退避等待不 sleep 在 reconcile 线程**：裁决给出 `nextEligibleAtMs`，未到期则**本轮直接不拉起**，下一轮 reconcile 再判定 —— 避免 N 个插件串行 sleep 累加阻塞（spec §5.2.1 规则 5）。代价：实际重启时刻粒度 = reconcile 间隔（默认 60s）。
   - **权衡说明**：reconcile 默认 60s 远大于退避上限 30s，会导致退避精度失真（实际延迟被取整到 60s 边界）。缓解：`main.cj:929` 的 `PLUGIN_RECONCILE_INTERVAL_SECONDS` 可下调；本设计**不改**默认 60s（避免影响启动期诊断现场，`cordis_host_manager.cj:133-134` 注释）。
2. `isExited` / `capture` 全部在 `state.lock` 之外执行（死锁红线 + 减少临界区）。
3. stdout 尾帧写入为 O(1) 环形覆盖，无分配抖动。

---

## 9. 部署设计

### 9.1 部署架构
无变化（进程内增强，不引入新进程/新服务）。

### 9.2 环境配置

| 变量 | 缺省 | 生效点 |
|---|---|---|
| `PLUGIN_RESTART_MAX` | `5` | `RestartPolicyConfig.fromEnv()` |
| `PLUGIN_RESTART_WINDOW_S` | `300` | 同上 |
| `PLUGIN_RESTART_BASE_MS` | `1000` | 同上 |
| `PLUGIN_RESTART_MAX_MS` | `30000` | 同上 |
| `PLUGIN_RESTART_COOLDOWN_S` | `300` | 同上（`0` = 永不自动半开） |
| `PLUGIN_RESTART_TAIL_LINES` | `20` | `StdoutTailBuffer` 构造 |

解析范式严格复用 `src/app/main.cj:929-944`：`getVariable` → `Int64.parse` → `try/catch` 退回缺省 + `LogUtils.warn`；**配错不让宿主起不来**（REQ-LO-DFX-12）。

**回滚开关**：不注入 `DefaultRestartController` 时 cordis 自动使用 `AlwaysRestartController`（= 改造前行为）。因此把注入调用包在 `match (getVariable("PLUGIN_RESTART_ENABLED"))` 判定下（缺省 `true`，置 `false` 即整体回退到现状），提供一键回滚能力。

---

## 10. 附录

### 10.1 参考文档

| 主题 | 位置 |
|---|---|
| 主工程账本 | `specs/plugin-system-enhancement/SPECS_INDEX.md`（§2 登记表 / §3 IF-11 / §7 R-06/R-07/R-08） |
| 集成契约 | `./contract.md` |
| 需求规格 | `./spec.md` |
| EARS 句式 | `skills/sdd/templates/ears-format.md` |
| 底线：崩溃自愈现状 | `libs/cordis-cj/cordis_host/src/plugin_host.cj:920-978` |
| 底线：实例结构 | `libs/cordis-cj/cordis_host/src/plugin_instance.cj:17-42` |
| 底线：stderr Inherit 与挂死教训 | `libs/cordis-cj/cordis_host/src/plugin_manager.cj:161-188` |
| 底线：检视漂移 | `src/plugin/cordis_host_manager.cj:390-414`、`:461-492`（`plugin_host_manager.cj`） |
| 底线：回写通道 | `src/plugin/plugin_sync_bridge.cj:29-130` |
| 退避范式 | `src/interaction/error_recovery_manager.cj:72-103` |
| 配置解析范式 | `src/app/main.cj:929-961` |
| exitCode 获取范式 | `src/app/services/tool/CrudGenService.cj:170-183` |
| 事件总线 | `libs/plugin-spi/src/plugin_event_bus.cj:60-152` |

### 10.2 待核实清单（编码步必须先裁定，禁止凭空假设）

| # | 事项 | 影响 | 裁定方式 |
|---|---|---|---|
| Q-01 | 仓颉 `std.process.SubProcess` 是否暴露 pid 属性 | `inspectProcessPlugin` 的 pid 行（分支 A/B） | 查仓颉 std 文档或实测；无据则走分支 B（改 docstring） |
| Q-02 | `SubProcess.wait(timeout:)` 对**已退出并被回收**的子进程的返回值语义 | `CrashInfo.exitCode` 可靠性 | 实测；不可靠则降级为 `None` |
| Q-03 | Windows 下仓颉是否提供 signal 语义 | `CrashInfo.signal` | 预期恒 `None`；确认后写入注释 |
| Q-04 | `CordisHostManager` 如何拿到 `PluginHostManager.bus()`（`plugin_host_manager.cj:507`） | LO-01 事件发射落点 | 查 `CordisHostManager` 的创建点，用构造参数或 setter 注入 |
| Q-05 | 仓颉获取 epoch 毫秒的标准 API | `detectedAtMs` / `nextRestartAtMs` / `cooldownUntilMs` | 查 `std.time`；不可得则改用 `MonoTime` 相对毫秒（语义改为相对量，需回改契约 §1.1） |
| Q-06 | `PLUGIN_RESTART_COOLDOWN_S=0` 时的"永不半开"是否为期望产品行为 | AC-LO-09 | 与产品确认；若不接受则改为"冷却后必半开" |

### 10.3 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-19 | SDD 文档步（lifecycle-observability） | 初始版本：M1~M9 模块划分；退出码/stdout 尾帧捕获；退避+计数+熔断；`autoRestart` 消费；IF-11 事件；0 新表 0 新列 |
