# 子系统集成契约（lifecycle-observability）

> 模板：`templates/subsystem-contract-template.md`
> 产出阶段：`spec` / `design` 步（子系统文档步产出）
> 被谁消费：主工程 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 集成契约汇总 + 下游子系统 tasks.md / 编码步
> 铁律依据：**铁律 15**（大工程拆分：集成契约先定、先改契约再改实现）

> 契约是**承诺**，不是设计说明。本文件在子系统实现开工前冻结；
> **禁止**在实现里单边改动契约——要改就走 §5 演进档位，双侧同轮完成。

## 文档信息

- 所属主工程：`plugin-system-enhancement`
- 子系统 ID：`lifecycle-observability`（稳定标识，跨轮次不变）
- 子系统 `feature_name`：`plugin-system-enhancement--lifecycle-observability`
- 契约版本：`v1`
- 冻结日期：2026-10-19 ／ 冻结状态：**草案**（待主工程闸口确认后转「已冻结」）
- 上游依赖：**无**（SPECS_INDEX §4：`lifecycle-observability` 与 `dependency-graph` 无上游，可并行开工）
- 下游消费方（计划内全部）：
  1. `PluginSyncBridge`（`src/plugin/plugin_sync_bridge.cj:33`）—— 订阅 IF-11 事件写 `agent_skills`
  2. Agent 工具 `plugin_inspect`（`src/plugin/plugin_agent_tools.cj:113`）—— 消费 LO-06 输出
  3. 主工程 L3 端到端用例 3（SPECS_INDEX §5.1 第 3 条：kill -9 → 退避重启 → 熔断 → 状态 Error 且事件可观测）

---

## 1. 本子系统提供什么（能力清单）

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| **LO-01**（= 主工程 **IF-11**） | 进程内调用（`PluginEventBus.emit`，句柄见 `src/plugin/plugin_host_manager.cj:507` `bus()`） | `plugin.crashed` / `plugin.restarted` | `bus().emit(eventType, payload)` | `JsonObject` 事件载荷（§1.1 结构） | `ArrayList<JsonValue>`（订阅者返回值；本子系统不使用） | 订阅者抛异常由总线吞掉并记日志（`libs/plugin-spi/src/plugin_event_bus.cj:121-133`），**不回抛、不影响生命周期** | 同一崩溃序号 `crashSeq` 只发一次，`crashSeq` 为去重键 | 与存量四类事件 `plugin.activated/deactivated/error/unloaded`（`plugin_host_manager.cj:498`）同构、同总线 |
| **LO-02** | 进程内调用（构造注入，`CordisHostManager.init` 注入到 `PluginHost`） | `RestartController`（cordis 侧接口，`libs/cordis-cj/cordis_host/src/plugin_host.cj` 新增注入点） | `onCrash(id: String, instance: PluginInstance) -> RestartDecision` | 插件 id + 崩溃实例快照 | `RestartDecision { action, delayMs, reason }`，`action ∈ {Restart, GiveUp, Skip}` | 控制器内部异常 → 退化 `Skip` 并 `diag` 记日志，**不得**让 `healCrashed` 抛出 | 同一次崩溃在同一 `crashSeq` 上只裁决一次 | 默认实现 `AlwaysRestartController` = 现行行为（立即重拉），保证存量零回归 |
| **LO-03** | 进程内调用（纯函数，无 IO） | `RestartPolicy.decide(state: RestartState, nowMs: Int64) -> RestartDecision` | 同上，纯计算 | `RestartState{restartCount, lastRestartAtMs, firstCrashAtMs, circuit, cooldownUntilMs}` | `RestartDecision` | 不抛异常；非法配置在构造期退缺省值 | 纯函数，天然幂等 | 配置项见 §1.2；退避算法复用 `src/interaction/error_recovery_manager.cj:95-103` 范式 |
| **LO-04** | 进程内调用（读） | `CrashDiagnostics.capture(instance: PluginInstance) -> CrashInfo` | 崩溃时一次性采集 | 崩溃实例 | `CrashInfo { exitCode: ?Int64, signal: ?String, stdoutTail: ArrayList<String>, detectedAtMs: Int64 }` | 采集失败字段置 `None` / 空列表，**不抛** | 单次调用可重复（无害） | exitCode 取 `SubProcess.wait(timeout:)` 返回值（范式见 `src/app/services/tool/CrudGenService.cj:170`） |
| **LO-05** | 进程内调用（读写实例字段） | `PluginInstance` 观测字段扩展（`libs/cordis-cj/cordis_host/src/plugin_instance.cj:17-42`） | 字段读写 | — | `restartCount / crashCount / lastRestartAtMs / nextEligibleAtMs / circuitState / lastCrash: ?CrashInfo` | — | 覆盖写 | 既有字段 `error`（:31）保持语义不变，由 LO-04 写入结构化串 |
| **LO-06** | Agent 工具输出（复用既有 `plugin_inspect`，**不新增工具**） | `CordisHostManager.inspectProcessPlugin(name)`（`src/plugin/cordis_host_manager.cj:395`）+ 接线进 `PluginHostManager.inspect(name:)`（`plugin_host_manager.cj:461`） | 字符串调用 | `pluginName` | 多行 `key=value` 结构化文本（§1.3 字段表） | 插件不存在返回 `process plugin not found: ${name}`（与现 :397 一致） | 只读，天然幂等 | 修复 R-08 的 docstring/实现漂移 |

### 1.1 IF-11 事件载荷结构（`plugin.crashed` / `plugin.restarted`）

```jsonc
// plugin.crashed
{
  "name": "<pluginId>",
  "error": "<人类可读一行摘要，取代现行固定串 'process exited unexpectedly'>",
  "crashSeq": 7,                       // 单调递增，本子系统内去重键
  "crash": {
    "exitCode": 1,                     // ?Int64，不可得为 null
    "signal": null,                    // ?String，Windows 平台恒 null
    "stdoutTail": ["...", "..."],      // 宿主侧环形缓冲最近 N 行（默认 20）
    "detectedAtMs": 1760000000000      // Int64 epoch 毫秒
  },
  "restart": {
    "restartCount": 3,
    "maxRestarts": 5,
    "circuit": "closed",               // closed | open | half-open
    "action": "restart",               // restart | give-up | skip
    "delayMs": 4000
  }
}
```

```jsonc
// plugin.restarted
{
  "name": "<pluginId>",
  "crashSeq": 7,
  "restartCount": 4,
  "delayMs": 4000,
  "success": true,                     // launchPlugin 未抛异常
  "attemptAtMs": 1760000004000
}
```

- 字段**只增不改**：下游按名取值，缺失按缺省处理（minor 演进，下游不必同步改）。
- `plugin.crashed` 与 `plugin.restarted` **成对**：先 crashed（含裁决 action），若 `action=restart` 再发 restarted。

### 1.2 配置项（LO-03 入参，环境变量，缺省值即现行兼容值）

| 变量 | 缺省 | 说明 |
|---|---|---|
| `PLUGIN_RESTART_MAX` | `5` | 计数窗口内最大重启次数，超过即熔断 |
| `PLUGIN_RESTART_WINDOW_S` | `300` | 计数窗口；插件连续 Active 超过该时长则 `restartCount` 清零 |
| `PLUGIN_RESTART_BASE_MS` | `1000` | 退避基数 |
| `PLUGIN_RESTART_MAX_MS` | `30000` | 单次退避上限 |
| `PLUGIN_RESTART_COOLDOWN_S` | `300` | 熔断冷却时长；`0` = 熔断后不自动半开（需人工 `plugin_activate`） |
| `PLUGIN_RESTART_TAIL_LINES` | `20` | stdout 环形缓冲行数 |

解析范式复用 `src/app/main.cj:929-944`（`getVariable` + `Int64.parse` + try 兜底退回缺省，**配错不让宿主起不来**）。

### 1.3 LO-06 `inspectProcessPlugin` 输出字段（与 docstring 逐项对齐）

| 行 | 字段 | 来源 | 缺失时 |
|---|---|---|---|
| `process plugin=<name>` | 同现 :412 | — | — |
| `status=<InstanceStatus>` | `instance.status`（现 :399-406 保留） | — | — |
| `command=<source>` | `instance.entry.source`（现 :411 保留） | — | — |
| `pid=<n>` | **待核实**：仓颉 `std.process.SubProcess` 是否暴露 pid 属性（全仓 `grep ".pid"` 零命中）。若不可得 → docstring 改为不承诺 pid（文档侧对齐，见 tasks T-14 分支 B） | `unknown` |
| `restartCount=<n>` | LO-05 `restartCount` | `0` |
| `crashCount=<n>` | LO-05 `crashCount` | `0` |
| `circuit=<closed\|open\|half-open>` | LO-05 `circuitState` | `closed` |
| `nextRestartAtMs=<epochMs>` | LO-05 `nextEligibleAtMs` | `0`（= 立即可重启） |
| `lastExitCode=<n>` | LO-05 `lastCrash.exitCode` | `(none)` |
| `lastError=<text>` | `instance.error`（现 :407-410 保留） | `(none)` |

---

## 2. 数据契约

| 表 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| `agent_skills` | **写**（仅经 `PluginSyncBridge`，单向 内存→库，`plugin_sync_bridge.cj:29` 红线） | `runtime_status`、`last_error`、`extra_metadata`（JSON 承载字段） | 其余全部字段（本子系统不读、不解释） | 复用既有定位口径：按 `name` 匹配且 `deleted_at IS NULL`（`plugin_sync_bridge.cj:133-141`）；**下游不得自行解释 creator/owner 语义** | 所有查询显式 `deleted_at IS NULL`；下游不得自己拼删除过滤 |

- **0 新表 / 0 新列**（与主工程 SPECS_INDEX §2 登记「0 新表」一致）。
- **复用成立理由（铁律 9 / R-06）**：
  1. `restartCount` / `crashInfo` 是**高频、可丢弃、只关心"最近一次"**的运行态快照，语义上就是 `last_error` 的"最近一次错误详情"，无需独立列；
  2. `PluginSyncBridge.mergePluginMetadata`（`plugin_sync_bridge.cj:104-130`）已提供 `extra_metadata` 的**读-改-写 JSON fragment 合并**通道，可承载结构化 crash 载荷，无需新列；
  3. 观测面非控制面（`plugin_sync_bridge.cj:25-27`）：回写失败只记日志 + 尽力 `sync_status=error`，绝不阻断插件生命周期 —— 若改成新建表并强一致写入，反而会引入新的失败域。
- 若后续确需独立列（如要求"崩溃历史留痕/可查询 N 次"），**复用即不成立**，须写明理由 + 走 `loaddbinfo` → `crudgen`/`crudweb` + `sql/incremental/`，不在本轮契约内。

---

## 3. 依赖方向

- **我依赖的上游**：无。
  - 复用（非子系统依赖）的既有设施：`PluginEventBus`（`libs/plugin-spi/src/plugin_event_bus.cj:60`）、`PluginSyncBridge`（`src/plugin/plugin_sync_bridge.cj:33`）、`cordis PluginHost/PluginManager/PluginInstance`、`RecoveryConfig` 退避范式（`src/interaction/error_recovery_manager.cj:72-103`）、`main.cj` 环境变量解析范式（`:929-944`）。
- **我不依赖谁**（保留位，防止依赖漂移）：
  - **不依赖** `dependency-graph` 的实现细节，也不调用其 IF-10；停机排序一律走既有 `shutdownAll`（`cordis_host_manager.cj:421`），本子系统不改动、不读取其排序结果。
  - **不依赖** `version-guard` / `capability-governance` / `capability-handshake` 的任何接口（IF-01~IF-09 全部不消费）；崩溃重拉不重新做版本/能力校验——重拉沿用已注入的 `PluginEntry`。
  - **不依赖** `authoring-toolchain` 的 `plugin validate`（IF-12）。
- **禁止成环**：本子系统无上游，任一边反向即为拆边界错误，回主工程重切。

---

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| **依赖逆序停机**（停机顺序编排） | `dependency-graph`（IF-10） | **本子系统不提供依赖逆序停机，也不改 `shutdownAll` 排序逻辑**（`cordis_host_manager.cj:421-438` 保持现状）。本子系统只在单个插件维度做重启裁决，不涉及多插件顺序。 |
| 加载前版本协商 | `version-guard` | 重拉不重做版本校验；版本不兼容的插件应被 `version-guard` 在加载前拒绝，本子系统不会遇到 |
| 能力清单与运行时门禁 | `capability-governance` | 崩溃重拉沿用已授权的能力集，不重新判定 |
| L3 启动能力宣告握手 | `capability-handshake` | 重拉后握手由既有 `launchPlugin`（`plugin_host.cj:83`）流程完成，本子系统不介入比对 |
| 依赖拓扑推导（替代 `order`） | `dependency-graph` | 本子系统不消费拓扑序 |
| `plugin validate` CLI / 创作模板 | `authoring-toolchain` | 不在本轮 |
| **周期性 ping 探活接线**（`Methods.PING`，`methods.cj:13`） | **本轮不接线（明确不提供）** | 崩溃判据保持**单一**：`manager.isExited(instance)`（stdout EOF，`plugin_manager.cj:78-80`）。现状 `plugin_host.cj` 无 ping 调度；既有文档声称"探活 ping 超时→Unreachable→重启"属**未接线的文档超前描述**。接线 ping 会引入第二条崩溃判据 + 新的超时/并发失败域，且需解决绿线程占用问题，**移交后续立项**；本轮改为在 spec 中把该描述降级为「未实现」。 |
| 插件进程 **stderr 尾帧落库** | **本轮不提供（硬约束冲突）** | `stdErr: ProcessRedirect.Inherit`（`plugin_manager.cj:174`）是**启动挂死修复**的产物（注释 :163-173：改回 Pipe 需 spawn 阻塞读线程，4 插件 × 2 线程占满 8 线程池导致主线程饿死）。**本子系统不得改回 Pipe**。等价替代：捕获 exit code + **stdout 尾帧**（宿主侧环形缓冲，复用既有 logger 通道 `cordis_host_manager.cj:60-65`）。真需 stderr 尾帧须单独立项解决绿线程饥饿。 |
| 可观测 UI 面板 / metrics 端点 | 不在本轮（主工程范围约束） | 复用既有 Agent 工具 + `plugin_inspect` 输出扩展（LO-06），不新建面板、不新增 metrics |
| 新建表 / 新列承载观测数据 | 无（铁律 9） | 见 §2 复用成立理由 |
| `plugin_restart` / `plugin_logs` / `plugin_health` 新 Agent 工具 | 不在本轮 | 现有 `plugin_inspect`/`plugin_activate`/`plugin_deactivate`/`plugin_refresh`（`plugin_agent_tools.cj:113/191/268/352`）已够承载；熔断后恢复走既有 `plugin_activate` |

---

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不动 §1/§2/§3 | 本文不动；在子系统 `tasks.md` 修订记录留痕 |
| 向后兼容（minor） | 只增接口/只增可选字段/只增事件字段，不改既有语义 | 改本文 + 主工程 §3 汇总（IF-11 行）；下游不必同步改 |
| 破坏性（major） | 改事件名/改 `agent_skills` 落库字段语义/删接口/改行级口径 | **必须双侧同轮**：本子系统 + `PluginSyncBridge` + Agent 工具侧在同一轮 code 里改完；主工程 SPECS_INDEX §6 登记；单侧先改 = P0 缺陷 |

- 演进一律「**先改契约 → 再改实现**」（铁律 15）。
- 本轮 v1 冻结后到实现完成之间的任何偏差，在 `test-report.md` 中必须归因到具体条目（LO-01~LO-06 / §2 行），禁止笼统写"实现与文档略有差异"。

---

## 6. 集成验收（本子系统对下游的交付承诺）

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| SMOKE-LO-01 | 主干：启动即崩插件 → 退避重启 N 次 → 熔断 → 停止重拉 | 造一个 `main` 立即 `exit(1)` 的 process 插件，`PLUGIN_RESTART_BASE_MS=200`、`PLUGIN_RESTART_MAX=3`，跑 3 轮 reconcile | 无 | 恰好 3 次重启；第 4 次检测崩溃时 `action=give-up`；进程不再被拉起；`circuit=open` |
| SMOKE-LO-02 | 主干（跨边界，IF-11 消费方）：崩溃事件 → `PluginSyncBridge` → `agent_skills` 落库 | 触发 SMOKE-LO-01 后查 `agent_skills` 对应行 | 无（消费方为存量 `PluginSyncBridge`，须与本子系统**同轮**改） | `runtime_status='error'`；`last_error` 含 exitCode/restartCount；`extra_metadata` 含 crash fragment；无新表新列 |
| SMOKE-LO-03 | 主干（跨边界，Agent 观测）：`plugin_inspect <name>` 对 process 插件输出健康字段 | 调 Agent 工具 `plugin_inspect` | 无（复用既有工具 `plugin_agent_tools.cj:113`） | 输出含 `status/restartCount/crashCount/circuit/lastError`；字段数与 docstring 逐项一致（pid 按 §1.3 待核实结论） |
| SMOKE-LO-04 | 异常/边界：`autoRestart: false` 的插件崩溃后**不重拉**，且状态为 Error、事件可观测 | plugin.yaml 置 `autoRestart: false`，kill 进程 | 无 | `plugin.crashed` 的 `action=skip`、`reason=autoRestart-disabled`；`restartCount` 不增；进程数保持 0 |
| SMOKE-LO-05 | 异常/边界：熔断冷却后自动半开，稳定运行的插件计数清零 | `PLUGIN_RESTART_COOLDOWN_S=2` + 一个"崩 3 次后自愈"的插件 | 无 | 冷却后 `circuit=half-open` 并允许 1 次重拉；插件连续 Active 超过 `PLUGIN_RESTART_WINDOW_S` 后 `restartCount` 归 0 |

- 归属档位：本节用例由**本子系统 test 步**产出与执行（L1 + L2）；主工程端到端 L3（SPECS_INDEX §5.1 第 3 条）在主工程 test 步执行，不在此重复。
- **上游就位前提**：本子系统**无上游**（SPECS_INDEX §4），无需等待任何子系统 done 即可跑冒烟。
- **双侧同轮前提**：SMOKE-LO-02 要求 `PluginSyncBridge`（存量代码，非子系统）的订阅扩展与本子系统**同一轮 code** 完成；只派一条任务判覆盖不全（tasks T-11 + T-12 成对）。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|:---:|---|---|---|
| 2026-10-19 | v1 | 基线侦察 + SPECS_INDEX §7 R-06/R-07/R-08 | 首次落契：LO-01(=IF-11)~LO-06 共 6 接口；0 新表 0 新列；明确不提供依赖逆序停机 / ping 探活接线 / stderr 落库 | 无上游；下游仅 `PluginSyncBridge`（存量）与 `plugin_inspect`（存量） |

> 主工程账本同步：本节每次改动，**必须**同步到 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 / §6。
