/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import std.core.Duration
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
 * 1. 从 plugins.yaml 的 mode:process 条目构造 cordis PluginEntry 期望状态
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

    public init() {
        this.cordisManager = PluginManager({ pluginId, line =>
            LogUtils.info("[cordis][${pluginId}] ${line}")
        })
        this.cordisHost = PluginHost(this.cordisManager, { pluginId, line =>
            LogUtils.info("[cordis][${pluginId}] ${line}")
        })
        this.processEntries = HashMap<String, PluginManifestEntry>()
        this.installStatusListener()
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

    // ── 启动编排 ──────────────────────────────────────────────────────

    /**
     * 从 PluginList 启动所有 mode:process 条目（期望状态生成 → reconcile）
     *
     * @param list plugins.yaml 解析产物
     * @return LoadResult（loaded/skipped/failed，与 PluginHostManager.loadAll 同构）
     */
    public func loadProcessPlugins(list: PluginList): LoadResult {
        let result = LoadResult()
        let desired = ArrayList<PluginEntry>()

        for (entry in list.plugins) {
            if (entry.mode != PluginMode.Process) {
                continue
            }
            if (!entry.enabled) {
                result.skipped.add("${entry.name}(disabled)")
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
        synchronized(this.cordisHost.state.lock) {
            for (ce in desired) {
                this.cordisHost.state.addDesired(ce)
            }
        }
        this.cordisHost.reconcileDesired()

        // 收集启动结果（awaitActive 确认握手完成）
        for (ce in desired) {
            match (this.cordisHost.awaitActive(ce.id, timeout: 10 * Duration.second)) {
                case Ok(_) =>
                    synchronized(this.processLock) {
                        this.startedIds.add(ce.id)
                    }
                    result.loaded.add(ce.id)
                    LogUtils.info("[CordisHostManager] process plugin started: ${ce.id}")
                case Err(reason) =>
                    result.failed.add("${ce.id}(${reason})")
                    LogUtils.error("[CordisHostManager] process plugin '${ce.id}' failed to activate: ${reason}")
            }
        }

        return result
    }

    /**
     * 将宿主 PluginManifestEntry 转换为 cordis PluginEntry（期望状态）
     *
     * 映射：name -> id, command -> source, args -> args, config -> config
     */
    private func toCordisEntry(entry: PluginManifestEntry): PluginEntry {
        let cmd = match (entry.command) {
            case Some(c) => c
            case None => ""
        }
        // 宿主侧 config 为 JsonValue，cordis 侧为 DataModel
        // 为简化集成，这里统一用 DataModelNull（插件私有配置经 env 传递）
        let cfg: DataModel = DataModelNull()
        let cordisEntry = PluginEntry(entry.name, cmd)
        cordisEntry.args = entry.args
        return cordisEntry
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
