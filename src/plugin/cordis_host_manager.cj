/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import std.core.Duration
import std.time.MonoTime
import std.env.{getWorkingDirectory, getVariable}
import std.fs.{File, Path, OpenMode, exists}
import magic.log.LogUtils
import f_base.Result
import plugin_spi.{Plugin, PluginState, PluginError, PluginContext, LoadResult}
import ystyle::cordis_core.{PluginEntry, InstanceStatus}
import stdx.serialization.serialization.{DataModel, DataModelNull}
import ystyle::cordis_host.{PluginHost, PluginInstance, HostState, PluginManager}

/**
 * CordisHostManager - L3 进程隔离轨宿主侧总控（PS-T025）
 *
 * 职责（spec REQ-PS-015 / design §5.2）：
 * 1. 从 plugin.yaml 的 mode:process 条目构造 cordis PluginEntry 期望状态
 * 2. 包装 ystyle::cordis_host PluginManager(stdio)/PluginHost/reconcile 循环
 * 3. InstanceStatus → PluginState 映射 + PluginSyncBridge 回写 agent_skills.runtime_status
 * 4. 优雅停机：宿主退出时按依赖逆序 terminate 全部 process 插件
 * 5. 日志汇聚：插件进程 stdout/stderr 经 cordis 采集转发宿主 LogUtils
 *
 * 与既有 PluginHostManager 的关系：PluginHostManager 扩展为三轨分发器——
 * sync 走 build-sync 反射、dylib 走 PluginDylibLoader、process 委托 CordisHostManager。
 *
 * 传输固定 stdio（UDS 不启用，spec REQ-PS-015）。
 *
 * 命名消解：宿主侧已将原 PluginManager 重命名为 PluginHostManager、原 PluginEntry
 * 重命名为 PluginManifestEntry，故 cordis 的 PluginEntry/PluginManager 可直接
 * import 短名引用，无任何冲突。
 */
public class CordisHostManager {
    /// cordis 进程管理器（stdio 传输）
    private let cordisManager: PluginManager

    /// cordis 宿主协调器（reconcile/状态机/事件总线）
    private let cordisHost: PluginHost

    /// 宿主侧进程插件登记表（id -> 宿主 PluginManifestEntry，用于优雅停机与状态映射）
    private let processEntries: HashMap<String, PluginManifestEntry>
    private let processLock: Mutex = Mutex()

    /// 状态变更监听器（PluginSyncBridge 订阅，回写 agent_skills.runtime_status）
    /// 签名：(pluginId, PluginState)
    private var statusListener: ?(String, PluginState) -> Unit = None

    /// 已启动的进程插件 id 集合（用于 inspect 与优雅停机）
    private var startedIds: ArrayList<String> = ArrayList<String>()

    /// 宿主侧服务代理（host.db/host.log/host.cache）
    private let hostServices: CordisHostServices

    public init() {
        this.cordisManager = PluginManager({ pluginId, line =>
            LogUtils.info("[cordis][${pluginId}] ${line}")
        })
        this.cordisHost = PluginHost(this.cordisManager, { pluginId, line =>
            LogUtils.info("[cordis][${pluginId}] ${line}")
        })
        this.processEntries = HashMap<String, PluginManifestEntry>()
        this.hostServices = CordisHostServices()
        this.installStatusListener()
        this.installHostServicesHook()
    }

    /// 安装状态变更监听器：InstanceStatus 变化时映射为 PluginState 并回写
    private func installStatusListener(): Unit {
        this.cordisHost.onStatusChange({ pluginId, oldStatus, newStatus =>
            let mapped = this.mapStatusToState(newStatus)
            LogUtils.info(
                "[CordisHostManager] plugin '${pluginId}' status ${oldStatus} -> ${newStatus} (mapped=${mapped})")
            // 回写 agent_skills.runtime_status（复用 PluginSyncBridge 通道）
            this.notifyStatusListener(pluginId, mapped)
        })
    }

    /**
     * 安装宿主服务注册钩子：插件握手成功（Active）后，
     * 为该插件实例注册 host.db/host.log/host.cache 服务 handler
     */
    private func installHostServicesHook(): Unit {
        this.cordisHost.onStatusChange({ pluginId, oldStatus, newStatus =>
            if (newStatus == InstanceStatus.Active) {
                match (this.cordisHost.state.getInstance(pluginId)) {
                    case Some(instance) =>
                        this.hostServices.registerFor(instance, pluginId)
                        // 从 plugin.yaml 声明式配置读取表白名单（替代硬编码）
                        synchronized(this.processLock) {
                            match (this.processEntries.get(pluginId)) {
                                case Some(entry) =>
                                    if (entry.tableWhitelist.size > 0) {
                                        this.hostServices.setTableWhitelist(pluginId, entry.tableWhitelist)
                                        LogUtils.info("[CordisHostManager] table whitelist for '${pluginId}': ${entry.tableWhitelist.toString()}")
                                    }
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        })
    }

    /// 启动诊断：把关键节点写入 logs/await_trace.txt（unbuffered，进程被杀也能落盘）。
    /// 专门用于定位「主线程卡在 loadProcessPlugins / awaitActive」的根因，绕开 stdout 管道缓冲。
    /// 临时探针，根因定位后删除。
    private func traceAwait(label: String): Unit {
        let base = getWorkingDirectory().toString()
        try (f = File(Path("${base}/logs/await_trace.txt"), OpenMode.Append)) {
            f.write("${label}\n".toArray())
        }
    }

    private func traceAwaitReset(): Unit {
        let base = getWorkingDirectory().toString()
        try (f = File(Path("${base}/logs/await_trace.txt"), OpenMode.Write)) {
            f.write("=== await_trace reset ===\n".toArray())
        }
    }

    // ── 启动编排 ──────────────────────────────────────────────────────

    /**
     * 从 PluginList 启动所有 mode:process 条目（期望状态生成 → reconcile）
     *
     * @param list plugin.yaml 自动发现产物
     * @return LoadResult（loaded/skipped/failed，与 PluginHostManager.loadAll 同构）
     */
    public func loadProcessPlugins(list: PluginList): LoadResult {
        let result = LoadResult()
        let desired = ArrayList<PluginEntry>()
        // 重置必须放在入口：这样即便主线程卡在后面某个 println 上，
        // await_trace.txt 也一定存在且能看到「最后一条真的执行到的 trace」。
        this.traceAwaitReset()

        // 应急开关：CORDIS_SKIP_PROCESS_PLUGINS=sdd（多个用逗号或空格分隔）可让
        // 指定的 process 插件**完全不启动**（在拉起前就跳过，不占端口、不握手）。
        // 用于在不改代码、不删 plugin.yaml 的前提下隔离「某个插件把启动卡住」的问题。
        let skipRaw = match (getVariable("CORDIS_SKIP_PROCESS_PLUGINS")) {
            case Some(v) => v
            case None => ""
        }

        for (entry in list.plugins) {
            if (entry.mode != PluginMode.Process) {
                continue
            }
            if (!entry.enabled) {
                result.skipped.add("${entry.name}(disabled)")
                continue
            }
            if (!skipRaw.isEmpty() && skipRaw.contains(entry.name)) {
                LogUtils.error("[CordisHostManager] process plugin '${entry.name}' SKIPPED by CORDIS_SKIP_PROCESS_PLUGINS")
                println("[CordisHostManager][DIAG] '${entry.name}' SKIPPED by CORDIS_SKIP_PROCESS_PLUGINS")
                result.skipped.add("${entry.name}(skipped-by-env)")
                continue
            }
            // 必填校验：process 模式 command 必须提供
            match (entry.command) {
                case None =>
                    LogUtils.error("[CordisHostManager] process plugin '${entry.name}' missing required 'command'")
                    result.failed.add("${entry.name}(missing command)")
                    continue
                case Some(cmd) =>
                    if (cmd.isEmpty()) {
                        LogUtils.error("[CordisHostManager] process plugin '${entry.name}' empty 'command'")
                        result.failed.add("${entry.name}(empty command)")
                        continue
                    }
            }
            // 构造 cordis PluginEntry 期望状态
            let cordisEntry = this.toCordisEntry(entry)
            desired.add(cordisEntry)
            synchronized(this.processLock) {
                this.processEntries[entry.name] = entry
            }
        }

        if (desired.size == 0) {
            return result
        }

        // 设置期望状态并 reconcile（先加后删 + 拓扑排序 + 崩溃自愈）
        println("[CordisHostManager][DIAG] desired built: ${desired.size.toString()} -> [${this.joinIds(desired)}]")
        this.traceAwait("TRACE[loadProcessPlugins] desired built")
        synchronized(this.cordisHost.state.lock) {
            for (ce in desired) {
                this.cordisHost.state.addDesired(ce)
            }
        }
        println("[CordisHostManager][DIAG] addDesired done; >>> reconcileDesired enter")
        this.cordisHost.reconcileDesired()
        println("[CordisHostManager][DIAG] <<< reconcileDesired returned")
        this.traceAwait("TRACE[loadProcessPlugins] reconcileDesired returned; desired.size=${desired.size.toString()}")

        // 收集启动结果（awaitActive 确认握手完成）
        let totalStart = MonoTime.now()
        this.traceAwait("TRACE[loadProcessPlugins] before loop, totalStart set")
        var pluginIndex = 0
        for (ce in desired) {
            pluginIndex = pluginIndex + 1
            let pluginStart = MonoTime.now()
            this.traceAwait("TRACE[loadProcessPlugins] loop iter#${pluginIndex.toString()} '${ce.id}' BEFORE awaitActive println")
            println("[CordisHostManager][DIAG] awaitActive #${pluginIndex}/${desired.size.toString()} '${ce.id}' start")
            this.traceAwait("TRACE[loadProcessPlugins] loop iter#${pluginIndex.toString()} '${ce.id}' AFTER awaitActive println, calling awaitActive")
            match (this.cordisHost.awaitActive(ce.id, timeout: 30 * Duration.second)) {
                case Ok(_) =>
                    let elapsed = MonoTime.now() - pluginStart
                    synchronized(this.processLock) {
                        this.startedIds.add(ce.id)
                    }
                    result.loaded.add(ce.id)
                    LogUtils.info("[CordisHostManager] process plugin started: ${ce.id}")
                    println("[CordisHostManager][DIAG] awaitActive #${pluginIndex}/${desired.size.toString()} '${ce.id}' OK (elapsed=${elapsed})")
                    this.traceAwait("TRACE[loadProcessPlugins] awaitActive OK '${ce.id}' (elapsed=${elapsed})")
                case Err(reason) =>
                    let elapsed = MonoTime.now() - pluginStart
                    result.failed.add("${ce.id}(${reason})")
                    LogUtils.error("[CordisHostManager] process plugin '${ce.id}' failed to activate: ${reason}")
                    println("[CordisHostManager][DIAG] awaitActive #${pluginIndex}/${desired.size.toString()} '${ce.id}' FAILED (elapsed=${elapsed}, reason=${reason})")
                    this.traceAwait("TRACE[loadProcessPlugins] awaitActive FAILED '${ce.id}': ${reason}")
            }
        }
        let totalElapsed = MonoTime.now() - totalStart
        println("[CordisHostManager][DIAG] all ${desired.size.toString()} process plugins awaitActive done (total=${totalElapsed})")
        this.traceAwait("TRACE[loadProcessPlugins] all plugins awaitActive done (total=${totalElapsed})")

        return result
    }

    /**
     * 启动诊断用：把期望启动的插件 id 拼成字符串。
     * 【注意】仓颉 ArrayList 没有 join 成员方法，必须用 String.join(arr.toArray(), delimiter:)。
     */
    private func joinIds(list: ArrayList<PluginEntry>): String {
        let names = ArrayList<String>()
        for (ce in list) {
            names.add(ce.id)
        }
        String.join(names.toArray(), delimiter: ", ")
    }

    /**
     * 将宿主 PluginManifestEntry 转换为 cordis PluginEntry（期望状态）
     *
     * 映射：name -> id, command -> source, args -> args, config -> config
     *
     * 重要：plugin.yaml 中 command 字段是相对于 plugin.yaml 所在目录的路径，
     * 但 launch() 会从宿主工作目录解析相对路径。
     * 因此需要把 command 转换为相对于宿主工作目录的路径：
     *   ./skills/{name}/{command}
     */
    private func toCordisEntry(entry: PluginManifestEntry): PluginEntry {
        let rawCmd = match (entry.command) {
            case Some(c) => c
            case None => ""
        }
        // 把相对于 plugin.yaml 所在目录的 command 路径
        // 转换为相对于宿主工作目录的路径
        let cmd = this.resolvePluginCommand(entry.name, rawCmd)
        let cordisEntry = PluginEntry(entry.name, cmd)
        cordisEntry.args = entry.args
        return cordisEntry
    }

    /**
     * 把 plugin.yaml 中的 command 路径转换为绝对路径。
     *
     * plugin.yaml 中 command 字段是相对于插件目录的路径，
     * 如 ./skills/codelabs/target/release/bin/skill_codelabs.exe
     *
     * launch() 从宿主工作目录解析相对路径，
     * 因此需要把 command 转换为绝对路径，避免路径解析错误。
     *
     * 如果 command 已经是绝对路径（以 / 或盘符 D: 开头），则原样返回。
     */
    private func resolvePluginCommand(name: String, command: String): String {
        if (command.isEmpty()) {
            return command
        }
        // 绝对路径检测：Unix 绝对路径（/）或 Windows 盘符开头（D:/、C:\ 等）
        let isAbsolute = command.startsWith("/") || (command.size >= 2 && command[1..2] == ":")
        if (isAbsolute) {
            return command
        }
        // 相对路径：拼接宿主工作目录，转换为绝对路径
        let cwd = getWorkingDirectory().toString().replace("\\", "/")
        // command 可能以 ./ 开头，也可能直接以 skills/ 开头
        let normalizedCmd = if (command.startsWith("./")) {
            command[2..]
        } else {
            command
        }
        let primary = "${cwd}/${normalizedCmd}"
        // 兜底 1：大量既有 plugin.yaml（含本机 CrudPluginGenerator / PluginGenerator 生成的）
        // 写的是**相对插件目录**的短路径 `./target/release/bin/skill_x.exe`，
        // 与本函数的 cwd 拼接语义并不匹配，直接拼出来的路径不存在。
        // launch() 对不存在的路径不会给出可读错误，只会表现为「插件拉不起来」，
        // 排障成本极高。这里按 skills/{name}/ 前缀再探一次，让两种写法都可用。
        if (exists(Path(primary))) {
            return primary
        }
        let skillPrefixed = "${cwd}/skills/${name}/${normalizedCmd}"
        if (exists(Path(skillPrefixed))) {
            LogUtils.warn("CordisHostManager: plugin_command_relative_fallback name=${name} used=${skillPrefixed}")
            LogUtils.warn("[CordisHostManager] plugin '${name}' command 是相对插件目录的短路径，"
                + "已按 skills/{name}/ 前缀兜底解析；建议把 command 改写成 "
                + "./skills/${name}/${normalizedCmd}")
            return skillPrefixed
        }
        return primary
    }

    // ── Agent 工具映射 ─────────────────────────────────────────────────

    /**
     * 激活 process 插件（期望状态 enabled 变更 → 拉起）
     *
     * @param name 插件名（cordis PluginEntry.id）
     * @return Ok(()) 拉起成功；Err 失败原因
     */
    public func activateProcessPlugin(name: String): Result<Unit, PluginError> {
        match (this.cordisHost.state.getInstance(name)) {
            case Some(_) =>
                // 已存在实例，检查状态
                let status = synchronized(this.cordisHost.state.lock) {
                    match (this.cordisHost.state.actual.get(name)) {
                        case Some(inst) => inst.status
                        case None => InstanceStatus.Starting
                    }
                }
                if (status == InstanceStatus.Active) {
                    return Ok(())
                }
                // 非 Active：重启
                match (this.cordisHost.restartPlugin(name)) {
                    case Ok(_) => return Ok(())
                    case Err(e) => return Err(PluginError.LifecycleError("restart: ${e}"))
                }
            case None =>
                // 不存在实例：检查 desired 并拉起
                let desiredEntry = synchronized(this.cordisHost.state.lock) {
                    if (this.cordisHost.state.desired.contains(name)) {
                        this.cordisHost.state.desired[name]
                    } else {
                        None<PluginEntry>
                    }
                }
                match (desiredEntry) {
                    case None => return Err(PluginError.NotFound(name))
                    case Some(entry) =>
                        try {
                            this.cordisHost.launchPlugin(entry)
                            match (this.cordisHost.awaitActive(name, timeout: 10 * Duration.second)) {
                                case Ok(_) => return Ok(())
                                case Err(e) => return Err(PluginError.LifecycleError("awaitActive: ${e}"))
                            }
                        } catch (e: Exception) {
                            return Err(PluginError.LifecycleError("launch: ${e.message}"))
                        }
                }
        }
    }

    /**
     * 停用 process 插件（期望状态 enabled 变更 → terminate 杀进程）
     *
     * @param name 插件名
     * @return Ok(()) terminate 成功；Err 实例不存在
     */
    public func deactivateProcessPlugin(name: String): Result<Unit, PluginError> {
        match (this.cordisHost.state.getInstance(name)) {
            case None => return Err(PluginError.NotFound(name))
            case Some(_) =>
                this.cordisHost.removePlugin(name)
                return Ok(())
        }
    }

    /**
     * 检视 process 插件（pid/status/restartCount/lastError）
     *
     * @return 结构化文本（Agent 易解析）
     */
    public func inspectProcessPlugin(name: String): String {
        match (this.cordisHost.state.getInstance(name)) {
            case None => return "process plugin not found: ${name}"
            case Some(instance) =>
                let status = match (instance.status) {
                    case InstanceStatus.Starting => "Starting"
                    case InstanceStatus.Pending => "Pending"
                    case InstanceStatus.Active => "Active"
                    case InstanceStatus.Unloading => "Unloading"
                    case InstanceStatus.Failed => "Failed"
                    case InstanceStatus.Unreachable => "Unreachable"
                }
                let error = match (instance.error) {
                    case Some(e) => e
                    case None => "(none)"
                }
                let cmd = instance.entry.source
                return "process plugin=${name}\nstatus=${status}\ncommand=${cmd}\nlastError=${error}"
        }
    }

    // ── 优雅停机 ──────────────────────────────────────────────────────

    /**
     * 宿主优雅退出时按依赖逆序 terminate 全部 process 插件
     */
    public func shutdownAll(): Unit {
        let ids = synchronized(this.processLock) {
            ArrayList<String>(this.startedIds)
        }
        for (id in ids) {
            try {
                this.cordisHost.removePlugin(id)
                LogUtils.info("[CordisHostManager] process plugin terminated on shutdown: ${id}")
            } catch (e: Exception) {
                LogUtils.error("[CordisHostManager] terminate error on shutdown '${id}': ${e.message}")
            }
        }
        try {
            this.cordisManager.close()
        } catch (e: Exception) {
            LogUtils.error("[CordisHostManager] close error: ${e.message}")
        }
    }

    // ── 状态映射与回写 ─────────────────────────────────────────────────

    /**
     * 注册状态变更监听器（PluginSyncBridge 订阅用）
     */
    public func setStatusListener(listener: (String, PluginState) -> Unit): Unit {
        this.statusListener = listener
    }

    /// 通知状态监听器（InstanceStatus → PluginState 映射后回写）
    private func notifyStatusListener(pluginId: String, state: PluginState): Unit {
        match (this.statusListener) {
            case Some(l) =>
                try {
                    l(pluginId, state)
                } catch (e: Exception) {
                    LogUtils.error("[CordisHostManager] status listener error: ${e.message}")
                }
            case None => ()
        }
    }

    /**
     * InstanceStatus → PluginState 映射（design §5.2.2）
     *
     * | cordis InstanceStatus | PluginState |
     * |---|---|
     * | Starting | Loading |
     * | Pending | Pending |
     * | Active | Active |
     * | Unloading | Disposed |
     * | Failed / Unreachable | Error |
     */
    public func mapStatusToState(status: InstanceStatus): PluginState {
        match (status) {
            case InstanceStatus.Starting => PluginState.Loading
            case InstanceStatus.Pending => PluginState.Pending
            case InstanceStatus.Active => PluginState.Active
            case InstanceStatus.Unloading => PluginState.Disposed
            case InstanceStatus.Failed => PluginState.Error
            case InstanceStatus.Unreachable => PluginState.Error
        }
    }

    // ── 进程插件路由网关支持（PS-T027 用）──────────────────────────────

    /**
     * 获取 process 插件实例（ExternalPluginRouteGateway 经 JSON-RPC invoke 用）
     *
     * @param name 插件名
     * @return Option<PluginInstance>（None 表示插件未启动或不存在）
     */
    public func getInstance(name: String): ?PluginInstance {
        this.cordisHost.state.getInstance(name)
    }

    /**
     * 获取 cordis 宿主协调器（供宿主侧服务代理注册 host.db/host.log/host.cache handler 用）
     */
    public func host(): PluginHost {
        this.cordisHost
    }

    /**
     * 获取 cordis 进程管理器（供 inspect 获取 pid 等）
     */
    public func manager(): PluginManager {
        this.cordisManager
    }

    /// 已启动的 process 插件 id 列表（inspect 全量展示用）
    public func startedProcessIds(): ArrayList<String> {
        synchronized(this.processLock) {
            ArrayList<String>(this.startedIds)
        }
    }
}
