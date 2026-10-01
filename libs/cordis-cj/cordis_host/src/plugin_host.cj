package ystyle::cordis_host

import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import std.collection.{HashMap, ArrayList, HashSet}
import std.sync.Mutex
import std.time.MonoTime
import std.fs.{File, Path, OpenMode}
import std.env.getWorkingDirectory

/**
 * 宿主协调器（docs/design-impl.md §5、§6.2）
 *
 * 职责：
 * - launchPlugin：拉起插件并注册宿主侧 RPC 处理器（initialize/provide/log/invoke）
 * - reconcile：读期望 → diff → 拓扑排序启动 → 先加后删 → 崩溃自愈
 *
 * 依赖握手流程（docs/design-impl.md §4.2）：
 * 1. 插件启动后向宿主发 initialize 请求（inject/provide 清单）
 * 2. 宿主检查 inject 依赖是否全部就绪，返回 InitializeResult(ok, providers)
 * 3. 插件为每个 provide 的 Key 发 provide 请求，宿主分配 undo_id
 */
public class PluginHost {
    public let state: HostState = HostState()
    public let manager: PluginManager
    public let eventRegistry: EventRegistry = EventRegistry()
    private let logger: (String, String) -> Unit
    private var undoCounter: Int64 = 0
    private var emitCounter: Int64 = 0
    private let lock: Mutex = Mutex()
    // Config schema 注册表：pluginId -> ConfigSchema（docs/cordis-comparison.md §4）
    private let schemas: HashMap<String, ConfigSchema> = HashMap<String, ConfigSchema>()
    // 状态转换监听器（Fiber 状态机：对齐 Cordis internal/status 事件）
    // 签名：(pluginId, oldStatus, newStatus)
    private let statusListeners: ArrayList<(String, InstanceStatus, InstanceStatus) -> Unit> =
        ArrayList<(String, InstanceStatus, InstanceStatus) -> Unit>()

    public init(manager: PluginManager, logger: (String, String) -> Unit) {
        this.manager = manager
        this.logger = logger
    }

    public init(manager: PluginManager) {
        this.manager = manager
        this.logger = { _, _ => () }
    }

    /**
     * 注册插件配置 schema（宿主应用侧声明）
     * @param pluginId 插件 id
     * @param schema 配置字段规格
     */
    public func registerSchema(pluginId: String, schema: ConfigSchema): Unit {
        synchronized(this.lock) {
            this.schemas[pluginId] = schema
        }
    }

    /**
     * 校验插件配置（Config schema）
     * @return None 通过；Some(错误) 含完整路径（如 "plugins[0].config.port: ..."）
     */
    public func validateConfig(entry: PluginEntry, path: String): ?String {
        let schema: ?ConfigSchema = synchronized(this.lock) {
            if (this.schemas.contains(entry.id)) {
                this.schemas[entry.id]
            } else {
                None
            }
        }
        match (schema) {
            case Some(s) => s.validateStrict(entry.config, path)
            case None => None
        }
    }

    /**
     * 拉起插件并注册宿主侧 RPC 处理器
     * @return 新实例（Starting 状态）
     * @throws Exception 配置 schema 校验失败时（含路径化错误）
     */
    public func launchPlugin(entry: PluginEntry): PluginInstance {
        // Config schema 校验（失败抛异常，reconcile 捕获记录日志）
        match (this.validateConfig(entry, "plugins[${entry.id}].config")) {
            case Some(err) => throw Exception("config validation failed: ${err}")
            case None => ()
        }
        let instance = this.manager.launch(entry)
        this.registerHostHandlers(instance)
        // 在 handler 注册之后启动 receiveLoop，避免丢失 initialize 请求
        instance.client.start()
        this.state.addInstance(instance)
        instance
    }

    /**
     * 注册宿主 → 插件连接上的处理器（插件发起的请求）
     */
    private func registerHostHandlers(instance: PluginInstance): Unit {
        let client = instance.client
        let providerId = instance.entry.id

        // 插件 → 宿主：initialize 握手
        client.registerRequestHandler(Methods.INITIALIZE, { req =>
            match (req.params) {
                case Some(p) =>
                    try {
                        let params = JsonValue.toObject<InitializeParams>(p)
                        // 记录插件上报的依赖（依赖变更通知用，docs/cordis-comparison.md §4）
                        synchronized(this.lock) {
                            instance.injects = ArrayList<String>(params.inject.toArray())
                        }
                        // 检查依赖是否全部就绪
                        let missing = this.checkMissing(params.inject)
                        let statusStr = if (missing.size == 0) { "Active" } else { "Pending" }
                        println("[HS-INIT] ${providerId} injects=${params.inject.size} missing=${missing.size} -> ${statusStr}")
                        if (missing.size == 0) {
                            this.transitionStatus(instance, InstanceStatus.Active)
                            let providers = this.snapshotProviders(params.inject)
                            // 下发插件私有配置（entry.config DataModel → JsonValue）
                            let cfg = JsonValue.fromDataModel(instance.entry.config)
                            Some(JsonValue.fromObject(InitializeResult(true, providers,
                                config: Some(cfg))))
                        } else {
                            // 依赖未满足：保持 Pending 等待重试（插件侧会周期重发 initialize）
                            this.transitionStatus(instance, InstanceStatus.Pending)
                            this.logger(providerId, "initialize pending: missing deps ${missing}")
                            Some(JsonValue.fromObject(InitializeResult(false, HashMap<String, String>())))
                        }
                    } catch (e: Exception) {
                        this.logger(providerId, "initialize parse error: ${e.message}")
                        Some(JsonValue.fromObject(InitializeResult(false, HashMap<String, String>())))
                    }
                case None =>
                    Some(JsonValue.fromObject(InitializeResult(false, HashMap<String, String>())))
            }
        })

        // 插件 → 宿主：provide 注册服务
        client.registerRequestHandler(Methods.PROVIDE, { req =>
            match (req.params) {
                case Some(p) =>
                    try {
                        let params = JsonValue.toObject<ProvideParams>(p)
                        let undoId = this.allocateUndoId()
                        this.state.registerService(params.key, providerId, undoId)
                        println("[HS-PROVIDE] ${providerId} key=${params.key} -> ${undoId}")
                        this.logger(providerId, "provide ${params.key} -> ${undoId}")
                        synchronized(this.lock) {
                            instance.provides[params.key] = undoId
                        }
                        // 唤醒可能在 awaitActive 中等待 provide 服务就绪的线程（PS-T025-BUG 配套）：
                        // 服务齐全后及时通知，避免其睡满整个超时。spurious wakeup 无害（awaitActive 会重查）。
                        synchronized(instance.settleLock) {
                            instance.settleCond.notifyAll()
                        }
                        // 依赖变更通知：服务就绪 → 唤醒 Pending 依赖者重试握手
                        this.notifyDependents(params.key, NotifyKind.PROVIDER_CHANGED, providerId)
                        Some(JsonValue.fromObject(ProvideResult(undoId)))
                    } catch (e: Exception) {
                        this.logger(providerId, "provide error: ${e.message}")
                        None
                    }
                case None => None
            }
        })

        // 插件 → 宿主：log 通知（JsonRpcClient 支持多回调，独立注册）
        client.setNotificationCallback({ notif =>
            if (notif.method == Methods.LOG) {
                match (notif.params) {
                    case Some(p) =>
                        match (JsonValue.toObject<LogParams>(p)) {
                            case lp => this.logger(providerId, "[${lp.level}] ${lp.message}")
                        }
                    case None => ()
                }
            }
        })

        // 插件 → 宿主：events/emit 通知 → 宿主扇出给订阅者（add 追加，不与 log 冲突）
        // emit 模式是 fire-and-forget 通知；其他模式走下方请求 handler
        client.addNotificationCallback({ notif =>
            if (notif.method == Methods.EVENTS_EMIT) {
                match (notif.params) {
                    case Some(p) =>
                        try {
                            let params = JsonValue.toObject<EmitParams>(p)
                            let emitId = this.allocateEmitId()
                            let delivered = this.eventRegistry.dispatchEmit(params, emitId)
                            this.logger(providerId, "emit ${params.event} -> ${delivered} subscribers")
                        } catch (e: Exception) {
                            this.logger(providerId, "emit error: ${e.message}")
                        }
                    case None => ()
                }
            }
        })

        // 插件 → 宿主：events/emit 请求（parallel/serial/bail/waterfall 模式）
        // 宿主按模式派发并聚合结果返回（docs/design-events.md §7）
        client.registerRequestHandler(Methods.EVENTS_EMIT, { req =>
            match (req.params) {
                case Some(p) =>
                    try {
                        let params = JsonValue.toObject<EmitParams>(p)
                        let emitId = this.allocateEmitId()
                        let result = this.eventRegistry.dispatch(params.event, params.args, params.mode, emitId)
                        this.logger(providerId, "emit ${params.event} mode=${params.mode}")
                        match (result) {
                            case Some(v) => Some(v)
                            case None => Some(JsonValue.Null)
                        }
                    } catch (e: Exception) {
                        this.logger(providerId, "emit request error: ${e.message}")
                        Some(JsonValue.Null)
                    }
                case None => Some(JsonValue.Null)
            }
        })

        // 插件 → 宿主：events/next 请求（waterfall 洋葱 next 推进，docs/design-events.md §7）
        // 订阅者调用 next() 时发送；宿主推进链到下一订阅者并返回其结果
        client.registerRequestHandler(Methods.EVENTS_NEXT, { req =>
            match (req.params) {
                case Some(p) =>
                    try {
                        let params = JsonValue.toObject<NextParams>(p)
                        match (this.eventRegistry.dispatchNext(params.emitId)) {
                            case Some(v) => Some(v)
                            case None => Some(JsonValue.Null)
                        }
                    } catch (e: Exception) {
                        this.logger(providerId, "events/next error: ${e.message}")
                        Some(JsonValue.Null)
                    }
                case None => Some(JsonValue.Null)
            }
        })

        // 插件 → 宿主：invoke 服务调用转发（@Inject 代理链路）
        // 消费者发 invoke → 查 serviceIndex 找提供者 → 用提供者连接转发 → 返回结果
        // 宿主内置服务（host.db/host.log/host.cache）由 CordisHostServices 直接注册 handler
        // （registerRequestHandler("host.db", ...)），不经过 INVOKE 转发链路
        client.registerRequestHandler(Methods.INVOKE, { req =>
            match (req.params) {
                case Some(p) =>
                    try {
                        let params = JsonValue.toObject<InvokeParams>(p)
                        // 宿主内置服务（host.*/cache.*等）由 CordisHostServices 注册的
                        // "host.db"/"host.log"/"host.cache" handler 处理，
                        // INVOKE handler 只处理插件间服务转发
                        match (this.state.serviceIndex.get(params.service)) {
                            case Some(providerId) =>
                                match (this.state.getInstance(providerId)) {
                                    case Some(provider) =>
                                        let result = provider.client.call<JsonValue, JsonValue>(
                                            Methods.INVOKE,
                                            params: Some(JsonValue.fromObject(params)),
                                            timeout: 30 * Duration.second)
                                        match (result) {
                                            case Ok(v) => Some(v)
                                            case Err(e) =>
                                                this.logger(providerId, "invoke forward error: ${e}")
                                                None
                                        }
                                    case None =>
                                        this.logger(providerId, "invoke forward: provider '${providerId}' not found")
                                        None
                                }
                            case None =>
                                this.logger(providerId, "invoke forward: service '${params.service}' not available")
                                None
                        }
                    } catch (e: Exception) {
                        this.logger(providerId, "invoke parse error: ${e.message}")
                        None
                    }
                case None => None
            }
        })

        // 事件总线：插件 → 宿主 订阅 / 退订（docs/design-events.md §5.3）
        client.registerRequestHandler(Methods.EVENTS_SUBSCRIBE, { req =>
            match (req.params) {
                case Some(p) =>
                    try {
                        let params = JsonValue.toObject<SubscribeParams>(p)
                        let subscriptionId = this.eventRegistry.subscribe(params.event, providerId, instance,
                            once: params.once, prepend: params.prepend)
                        this.logger(providerId, "subscribe ${params.event} -> ${subscriptionId}")
                        Some(JsonValue.fromObject(SubscribeResult(subscriptionId)))
                    } catch (e: Exception) {
                        this.logger(providerId, "subscribe error: ${e.message}")
                        None
                    }
                case None => None
            }
        })
        client.registerRequestHandler(Methods.EVENTS_UNSUBSCRIBE, { req =>
            match (req.params) {
                case Some(p) =>
                    try {
                        let params = JsonValue.toObject<UnsubscribeParams>(p)
                        let removed = this.eventRegistry.unsubscribe(params.subscriptionId)
                        Some(JsonValue.Boolean(removed))
                    } catch (e: Exception) {
                        // 退订解析/执行异常：插件只拿到 false（与「订阅不存在」无法区分），
                        // 交给日志通道才可诊断（同 subscribe/emit 等 handler 的写法）
                        this.logger(providerId, "unsubscribe error: ${e.message}")
                        Some(JsonValue.Boolean(false))
                    }
                case None => Some(JsonValue.Boolean(false))
            }
        })
    }

    private func allocateEmitId(): String {
        synchronized(this.lock) {
            this.emitCounter++
            "emit-${this.emitCounter}"
        }
    }

    // ── Fiber 状态机（docs/cordis-comparison.md §4，对齐 Cordis Fiber）────────

    /**
     * 注册状态转换监听器（对齐 Cordis internal/status 事件）
     * @param listener (pluginId, oldStatus, newStatus) 每次状态转换时调用
     */
    public func onStatusChange(listener: (String, InstanceStatus, InstanceStatus) -> Unit): Unit {
        synchronized(this.lock) {
            this.statusListeners.add(listener)
        }
    }

    /**
     * 状态转换统一入口：更新状态 + 唤醒 awaitActive 等待者 + 通知监听器
     *
     * 对齐 Cordis Fiber._updateState（状态转换 emit internal/status）。
     * 所有状态变更必须经此方法（initialize 握手 / terminate / 崩溃标记）。
     *
     * @param instance 目标实例
     * @param newStatus 新状态
     * @param error 状态相关错误（Failed 时记录，await 重抛）
     */
    private func transitionStatus(instance: PluginInstance, newStatus: InstanceStatus,
                                  error!: ?String = None): Unit {
        let old = synchronized(instance.settleLock) {
            let oldStatus = instance.status
            if (oldStatus != newStatus) {
                instance.status = newStatus
            }
            if (let Some(err) <- error) {
                instance.error = Some(err)
            }
            instance.settleCond.notifyAll()
            oldStatus
        }
        if (old != newStatus) {
            let listeners = synchronized(this.lock) {
                ArrayList<(String, InstanceStatus, InstanceStatus) -> Unit>(this.statusListeners)
            }
            for (listener in listeners) {
                try {
                    listener(instance.entry.id, old, newStatus)
                } catch (e: Exception) {
                    this.logger(instance.entry.id, "status listener error: ${e.message}")
                }
            }
            this.logger(instance.entry.id, "status ${old} -> ${newStatus}")
        }
    }

    /**
     * 启动关键路径诊断输出：只写 stderr。
     *
     * 刻意不写框架 .log —— awaitActive 在主线程上跑，而主线程一旦在日志调用内
     * 部挂起，整个 runtime 就起不来（已多次复现）。stderr 无缓冲，即使后面卡住
     * 也能保证这一行可见。
     */
    /**
     * 启动期一次性诊断输出（stderr，无缓冲）。
     *
     * 【红线】只允许在 awaitActive 的**入口 / 出口**这类「每插件最多一两次」的
     * 一次性节点调用，绝不允许进入轮询循环体（见 traceAwaitP）。
     *
     * 【为什么】cjpm run 把子进程 stdout/stderr 接成管道，stdio 的写是同步阻塞的：
     * 一旦管道/控制台来不及排空，或 Windows CRT 的 stdout 锁字节被异常线程带死，
     * 这一句 eprintln 就会把**主线程**永久钉死 —— awaitActive 再也走不到 deadline
     * 判定，loadAll 永不返回，整个 runtime 起不来。实测症状（PID 836）：进程存活、
     * 5 秒 0ms CPU（是阻塞不是自旋）、其它线程全在 NtReadFile、日志恰好停在某
     * 一句 diag 之后，且 awaitActive 一次都没返回 Ok。
     *
     * 轮询循环内改走 traceAwaitP（直写文件），主线程因此在启动路径上不会卡在 stdio。
     * 另见 src/log/log_utils_impl.cj 的 WRITE_LOCK 注释：多线程并发写同一日志句柄
     * 曾让主线程在日志调用内部挂起。
     */
    private func diag(id: String, msg: String): Unit {
        eprintln("[cordis][${id}] ${msg}")
    }

    /// 启动诊断：awaitActive 内部关键节点写入 logs/await_trace.txt（unbuffered）。
    /// 仅用于定位「主线程卡在 awaitActive」的根因，定位后删除。
    private func traceAwaitP(label: String): Unit {
        // 路径必须绝对路径：cjpm run 可能把子进程工作目录设在 target/release/bin，
        // 相对路径 `logs/...` 会静默写失败（try 吞掉异常 → 文件永远不出现）。
        let base = getWorkingDirectory().toString()
        try (f = File(Path("${base}/logs/await_trace.txt"), OpenMode.Append)) {
            f.write("${label}\n".toArray())
        }
    }

    /**
     * awaitActive 轮询用的短等待。
     *
     * 【重要】刻意不使用 std.core.sleep。awaitActive 跑在**主线程**上，而实测
     * 主线程调用 sleep 会永久挂起：2026-10-01 04:35:48 那次运行里，sdd 在
     * `[DIAG]iter=1 I: before sleep` 之后就再无任何输出——连 5 秒一次的
     * STILL WAITING 和 30 秒的 TIMEOUT 都没打出来，说明主线程没有在循环，
     * 而是死在 sleep 这一句里。工程内 sleep 的全部 18 处调用都位于 spawn 出来的
     * 后台线程（AsyncLogWriter / RetryManager / SchedulerEngine / SSE ping 等），
     * 没有一处跑在主线程上，与上述现象吻合。
     *
     * 改为有界忙等：等待期间不释放主线程，但每次等待时长都很短（10~50ms），
     * 且循环顶部的 deadline 仍然统一兜底，最迟 timeout 后必定返回。
     */
    private func spinWait(d: Duration): Unit {
        let until = MonoTime.now() + d
        var n: Int64 = 0
        while (MonoTime.now() < until) {
            n = n + 1
        }
    }

    /**
     * 等待插件进入 Active 状态（对齐 Cordis Fiber.await()）
     *
     * 阻塞直到实例 Active **且其 provide 的服务全部注册**（Active 是握手完成，
     * 服务注册在其后；对齐 Cordis ACTIVE = 插件回调执行完、服务可用）。
     * 进程死亡/启动失败 → Err(错误原因)；超时 → Err("timeout")。
     * Pending（依赖未满足）继续等待（依赖就绪后自动 Active）。
     *
     * 【注意】实现约束：本方法**保证在 timeout 内一定返回**，且全程 tryLock 不阻塞在
     * 任何互斥锁上（见函数体注释）。禁止改回 synchronized / Condition.wait 的
     * 阻塞式等待 —— sdd 插件曾因此永久挂起，导致整个 runtime 无法启动。
     *
     * @param id 插件 id
     * @param timeout 最长等待时间
     * @return Ok(实例) 已 Active 且服务就绪；Err 失败原因/超时/实例不存在
     */
    public func awaitActive(id: String, timeout!: Duration = 30 * Duration.second): Result<PluginInstance> {
        // 【注意】启动关键路径：awaitActive 绝不允许永久挂起（sdd 曾在此永久卡死导致
        // 整个 runtime 起不来）。两道保险：
        //   ① 全程 tryLock（state.lock / instance.settleLock），拿不到锁就下一轮重试，
        //      绝不阻塞在锁上 —— 规避死锁、锁被长持、条件变量丢唤醒等一切卡死成因；
        //   ② deadline 在每轮循环顶部统一判定，最迟 timeout 后必定返回 Err。
        // 这样即便某个插件真有问题，启动也只会「降级跳过该插件」，不会整体挂起。
        this.diag(id, "awaitActive: enter, waiting for Active (timeout=${timeout})")
        this.traceAwaitP("AWAIT enter ${id}")
        let deadline = MonoTime.now() + timeout
        let warnInterval = 5 * Duration.second
        var nextWarn = MonoTime.now() + warnInterval
        var iter = 0
        var lastStatus: ?InstanceStatus = None
        var lastDiagPoint = "start"
        var stateLockBusyCount = 0
        var settleLockBusyCount = 0
        var servicesPendingCount = 0
        while (true) {
            iter = iter + 1
            if (iter % 250 == 0) {
                // 带上 lastDiagPoint：主线程若停在某一句（尤其 isExited，见下方 G/H 段），
                // trace 会直接指名是哪一行，而不只是「在转圈」。
                this.traceAwaitP("AWAIT spinning ${id} iter=${iter} point=${lastDiagPoint}")
            }
            if (MonoTime.now() >= deadline) {
                this.diag(id, "awaitActive: TIMEOUT after ${iter} polls, giving up")
                this.traceAwaitP("AWAIT TIMEOUT ${id} iter=${iter}")
                return Err("timeout waiting for plugin '${id}' active")
            }
            // 周期性诊断：每 5 秒输出一次等待详情，便于定位卡点
            if (MonoTime.now() >= nextWarn) {
                let elapsed = MonoTime.now() - (deadline - timeout)
                // Option<T> 不做隐式 toString 兜底：显式解包成字符串再插值
                let statusText = match (lastStatus) {
                    case Some(s) => s.toString()
                    case None => "(unknown)"
                }
                var pendingList = "n/a"
                match (this.diagPendingServices(id)) {
                    case Some(list) =>
                        if (list.size == 0) {
                            pendingList = "(none, provide=0)"
                        } else {
                            pendingList = String.join(list.toArray(), delimiter: ", ")
                        }
                    case None =>
                        pendingList = "(state.lock busy)"
                }
                this.traceAwaitP("awaitActive: STILL WAITING after ${elapsed} (iter=${iter}, status=${statusText}, lastPoint=${lastDiagPoint}, stateLockBusy=${stateLockBusyCount.toString()}, settleLockBusy=${settleLockBusyCount.toString()}, svcPendingCycles=${servicesPendingCount.toString()}, pendingServices=[${pendingList}])")
                nextWarn = MonoTime.now() + warnInterval
                stateLockBusyCount = 0
                settleLockBusyCount = 0
                servicesPendingCount = 0
            }
            this.traceAwaitP("[DIAG]iter=${iter} A: before tryGetInstance")
            lastDiagPoint = "A"
            let instance = this.state.tryGetInstance(id)
            match (instance) {
                case None =>
                    // 实例尚未登记，或 state.lock 忙 → 下一轮重试（不阻塞）
                    this.traceAwaitP("[DIAG]iter=${iter} A2: instance None or state.lock busy")
                    lastDiagPoint = "A2"
                    stateLockBusyCount = stateLockBusyCount + 1
                    this.spinWait(20 * Duration.millisecond)
                    continue
                case Some(inst) =>
                    this.traceAwaitP("[DIAG]iter=${iter} C: before settleLock.tryLock")
                    lastDiagPoint = "C"
                    var statusOpt: ?InstanceStatus = None
                    if (inst.settleLock.tryLock()) {
                        statusOpt = Some(inst.status)
                        inst.settleLock.unlock()
                    }
                    match (statusOpt) {
                        case None =>
                            this.traceAwaitP("[DIAG]iter=${iter} C2: settleLock busy")
                            lastDiagPoint = "C2"
                            settleLockBusyCount = settleLockBusyCount + 1
                            this.spinWait(20 * Duration.millisecond)
                            continue
                        case Some(status) =>
                            lastStatus = Some(status)
                            this.traceAwaitP("[DIAG]iter=${iter} D: status=${status}")
                            lastDiagPoint = "D"
                            if (status == InstanceStatus.Active) {
                                // Active 是握手完成；等服务注册（provide 在握手之后）
                                this.traceAwaitP("[DIAG]iter=${iter} E: before tryAllServicesRegistered")
                                lastDiagPoint = "E"
                                match (this.tryAllServicesRegistered(inst)) {
                                    case Some(v) =>
                                        if (v) {
                                        this.diag(id, "awaitActive: Active observed, returning Ok")
                                        this.traceAwaitP("AWAIT OK ${id}")
                                        return Ok(inst)
                                        }
                                        this.traceAwaitP("[DIAG]iter=${iter} F: services not all registered")
                                        lastDiagPoint = "F"
                                        servicesPendingCount = servicesPendingCount + 1
                                        this.spinWait(10 * Duration.millisecond)
                                    case None =>
                                        this.traceAwaitP("[DIAG]iter=${iter} F2: state.lock busy")
                                        lastDiagPoint = "F2"
                                        stateLockBusyCount = stateLockBusyCount + 1
                                        this.spinWait(10 * Duration.millisecond)
                                }
                            } else if (status == InstanceStatus.Failed || status == InstanceStatus.Unreachable) {
                                this.diag(id, "awaitActive: plugin terminated during startup: ${status}")
                                this.traceAwaitP("AWAIT ERR terminated ${id} ${status}")
                                return Err("plugin '${id}' ${status}")
                            } else if (status == InstanceStatus.Unloading) {
                                this.diag(id, "awaitActive: plugin unloading")
                                this.traceAwaitP("AWAIT ERR unloading ${id}")
                                return Err("plugin '${id}' is unloading")
                            } else {
                                // Starting / Pending：进程已死 → 直接判失败（不调用
                                // transitionStatus，避免再进入 synchronized 持锁路径）
                                this.traceAwaitP("[DIAG]iter=${iter} G: before isExited")
                                lastDiagPoint = "G"
                                this.traceAwaitP("AWAIT ${id} iter=${iter} G before isExited")
                                let exited = this.manager.isExited(inst)
                                this.traceAwaitP("AWAIT ${id} iter=${iter} H isExited=${exited}")
                                this.traceAwaitP("[DIAG]iter=${iter} H: isExited=${exited}")
                                lastDiagPoint = "H"
                                if (exited) {
                                    this.diag(id, "awaitActive: process exited during startup (status=${status})")
                                    this.traceAwaitP("AWAIT ERR exited ${id} ${status}")
                                    return Err("plugin '${id}' process exited during startup")
                                }
                                this.traceAwaitP("[DIAG]iter=${iter} I: before wait")
                                lastDiagPoint = "I"
                                this.spinWait(50 * Duration.millisecond)
                            }
                    }
            }
        }
        // while(true) 内所有路径均 return；此处仅为类型完整
        Err("unreachable")
    }

    /**
     * tryLock 版 allServicesRegistered：拿不到 state.lock 返回 None（调用方重试）
     * @return Some(true) 已就绪 / Some(false) 未就绪 / None 锁忙
     */
    private func tryAllServicesRegistered(inst: PluginInstance): ?Bool {
        if (inst.entry.provide.size == 0) {
            return Some(true)
        }
        if (!this.state.lock.tryLock()) {
            return None
        }
        var ok = true
        for (key in inst.entry.provide) {
            if (this.state.serviceIndex.get(key) != Some(inst.entry.id)) {
                ok = false
            }
        }
        this.state.lock.unlock()
        Some(ok)
    }

    /**
     * 诊断用：获取指定插件尚未注册的 provide 服务列表（tryLock，不阻塞）
     * @return Some(ArrayList) 未注册服务名列表；None 表示 state.lock 忙或实例不存在
     */
    private func diagPendingServices(id: String): ?ArrayList<String> {
        let inst = match (this.state.tryGetInstance(id)) {
            case Some(i) => i
            case None => return None
        }
        if (inst.entry.provide.size == 0) {
            return Some(ArrayList<String>())
        }
        if (!this.state.lock.tryLock()) {
            return None
        }
        let pending = ArrayList<String>()
        for (key in inst.entry.provide) {
            if (this.state.serviceIndex.get(key) != Some(inst.entry.id)) {
                pending.add(key)
            }
        }
        this.state.lock.unlock()
        Some(pending)
    }

    /**
     * 检查实例的 provide 服务是否全部注册（awaitActive 用）
     */
    private func allServicesRegistered(inst: PluginInstance): Bool {
        if (inst.entry.provide.size == 0) {
            return true
        }
        synchronized(this.state.lock) {
            for (key in inst.entry.provide) {
                if (this.state.serviceIndex.get(key) != Some(inst.entry.id)) {
                    return false
                }
            }
            true
        }
    }

    /**
     * 重启插件（对齐 Cordis Fiber.restart()）
     *
     * 终止当前进程 → 用当前 desired entry（无 desired 时用 instance.entry）
     * 重新拉起 → 等待 Active。
     *
     * @param id 插件 id
     * @return Ok(新实例)；Err 实例不存在/重启失败
     */
    public func restartPlugin(id: String): Result<PluginInstance> {
        let instance = this.state.getInstance(id)
        match (instance) {
            case None => Err("plugin '${id}' not found")
            case Some(inst) =>
                let entry = synchronized(this.state.lock) {
                    if (this.state.desired.contains(id)) {
                        this.state.desired[id]
                    } else {
                        inst.entry
                    }
                }
                this.removePlugin(id)
                try {
                    let fresh = this.launchPlugin(entry)
                    match (this.awaitActive(id, timeout: 10 * Duration.second)) {
                        case Ok(a) => Ok(a)
                        case Err(e) =>
                            // 重启后未能 Active：记录失败
                            this.transitionStatus(fresh, InstanceStatus.Failed, error: Some(e))
                            Err("restart '${id}' failed: ${e}")
                    }
                } catch (e: Exception) {
                    Err("restart '${id}' failed: ${e.message}")
                }
        }
    }

    /**
     * 更新插件配置并重启（对齐 Cordis Fiber.update(config)）
     *
     * 1. 校验新配置（Config schema，失败 → Err 且不重启）
     * 2. 更新 desired 与实例 entry
     * 3. 重启 → 等待 Active
     *
     * @param id 插件 id
     * @param newEntry 新配置条目（id 必须匹配）
     * @return Ok(新实例)；Err 校验失败/实例不存在/重启失败
     */
    public func updatePlugin(id: String, newEntry: PluginEntry): Result<PluginInstance> {
        if (newEntry.id != id) {
            return Err("update '${id}': entry id mismatch '${newEntry.id}'")
        }
        let instance = this.state.getInstance(id)
        match (instance) {
            case None => Err("plugin '${id}' not found")
            case Some(inst) =>
                // 1. config schema 校验（对齐 Cordis update 的 resolveConfig）
                match (this.validateConfig(newEntry, "plugins[${id}].config")) {
                    case Some(err) => Err("update '${id}': config validation failed: ${err}")
                    case None =>
                        // 2. 更新 desired（若存在）与实例 entry
                        synchronized(this.state.lock) {
                            if (this.state.desired.contains(id)) {
                                this.state.desired[id] = newEntry
                            }
                        }
                        synchronized(inst.settleLock) {
                            inst.entry = newEntry
                        }
                        // 3. 重启 → 等待 Active
                        this.restartPlugin(id)
                }
        }
    }

    /**
     * 检查依赖：返回缺失的服务 Key 列表
     */
    private func checkMissing(inject: Array<String>): ArrayList<String> {
        let missing = ArrayList<String>()
        for (key in inject) {
            if (!this.state.hasService(key)) {
                missing.add(key)
            }
        }
        missing
    }

    /**
     * 生成 providers 快照：serviceKey -> providerId
     */
    private func snapshotProviders(inject: Array<String>): HashMap<String, String> {
        let providers = HashMap<String, String>()
        synchronized(this.state.lock) {
            for (key in inject) {
                if (this.state.serviceIndex.contains(key)) {
                    providers[key] = this.state.serviceIndex[key]
                }
            }
        }
        providers
    }

    private func allocateUndoId(): String {
        synchronized(this.lock) {
            this.undoCounter++
            "undo-${this.undoCounter}"
        }
    }

    /**
     * 调谐一轮：读期望 → diff → 拓扑启动 → 先加后删 → 崩溃自愈
     * @param configPath TOML 配置路径
     */
    public func reconcile(configPath: String): Unit {
        let config = ConfigLoader.load(configPath)
        // 重建 desired（enabled=true 的条目）
        synchronized(this.state.lock) {
            this.state.desired = HashMap<String, PluginEntry>()
            for (entry in config.entries) {
                if (entry.enabled) {
                    this.state.desired[entry.id] = entry
                }
            }
        }
        this.reconcileDesired()
    }

    /**
     * 对当前 desired 状态执行一次调谐（测试可直接调用）
     */
    public func reconcileDesired(): Unit {
        // 1. 计算 diff
        let toRemove = this.computeToRemove()
        let toAdd = this.computeToAdd()
        let toUpdate = this.computeToUpdate()

        // 2. 先加后删：新进程握手成功后再杀旧进程（服务不中断）
        for (entry in toAdd) {
            try {
                this.launchPlugin(entry)
                this.logger(entry.id, "launched")
            } catch (e: Exception) {
                this.logger(entry.id, "launch failed: ${e.message}")
            }
        }
        for (id in toRemove) {
            this.removePlugin(id)
        }
        for (entry in toUpdate) {
            // 配置更新走 Fiber 状态机 updatePlugin（校验 + 重启 + 等待 Active）
            match (this.updatePlugin(entry.id, entry)) {
                case Ok(inst) => this.logger(entry.id, "updated")
                case Err(e) => this.logger(entry.id, "update failed: ${e}")
            }
        }

        // 3. 崩溃自愈：desired 存在但进程已退出 → 重新拉起
        this.healCrashed()
    }

    private func computeToRemove(): ArrayList<String> {
        let result = ArrayList<String>()
        synchronized(this.state.lock) {
            for (id in this.state.actual.keys()) {
                if (!this.state.desired.contains(id)) {
                    result.add(id)
                }
            }
        }
        result
    }

    private func computeToAdd(): ArrayList<PluginEntry> {
        let result = ArrayList<PluginEntry>()
        synchronized(this.state.lock) {
            for ((id, entry) in this.state.desired) {
                if (!this.state.actual.contains(id)) {
                    result.add(entry)
                }
            }
        }
        // 拓扑排序：依赖方后启动
        this.topoSort(result)
        return result
    }

    private func computeToUpdate(): ArrayList<PluginEntry> {
        let result = ArrayList<PluginEntry>()
        synchronized(this.state.lock) {
            for ((id, entry) in this.state.desired) {
                if (this.state.actual.contains(id)) {
                    let instance = this.state.actual[id]
                    if (this.entryChanged(instance.entry, entry)) {
                        result.add(entry)
                    }
                }
            }
        }
        result
    }

    private func entryChanged(old: PluginEntry, new: PluginEntry): Bool {
        old.source != new.source ||
        old.args != new.args ||
        JsonValue.fromDataModel(old.config).stringify() != JsonValue.fromDataModel(new.config).stringify()
    }

    /**
     * 移除插件：终止进程 + 清理服务注册表
     */
    public func removePlugin(id: String): Unit {
        let instance = this.state.getInstance(id)
        match (instance) {
            case Some(inst) =>
                this.logger(id, "removing")
                // 状态 → Unloading（Fiber 状态机统一转换）
                this.transitionStatus(inst, InstanceStatus.Unloading)
                this.eventRegistry.unsubscribeAll(id)   // 清理事件订阅（docs/design-events.md §8）
                // 依赖变更通知：先收集被移除的服务 Key，通知依赖者（DEPENDENCY_LOST）
                let removedKeys = this.state.servicesOf(id)
                this.state.clearServicesByProvider(id)
                for (key in removedKeys) {
                    this.notifyDependents(key, NotifyKind.DEPENDENCY_LOST, None)
                }
                try {
                    this.manager.terminate(inst)
                } catch (e: Exception) {
                    this.logger(id, "terminate error: ${e.message}")
                }
                this.state.removeInstance(id)
            case None => ()
        }
    }

    /**
     * 依赖变更通知（docs/cordis-comparison.md §4，对齐 Cordis reflect.notify）：
     * 服务提供/撤销时，向 inject 了该服务 Key 的所有存活实例发 notify。
     *
     * - PROVIDER_CHANGED：服务就绪，唤醒 Pending 依赖者立即重试握手（而非等轮询）
     * - DEPENDENCY_LOST：服务撤销，通知 Active 依赖者感知依赖丢失
     *
     * 通知以 notify 消息发送（不等待响应，fire-and-forget）；
     * 插件侧 handleNotify 唤醒等待中的握手重试循环。
     */
    private func notifyDependents(key: String, kind: String, provider: ?String): Unit {
        let dependents = this.state.dependentsOf(key)
        if (dependents.size == 0) {
            return
        }
        let params = NotifyParams(kind, key, provider: provider)
        for (dep in dependents) {
            try {
                dep.client.notify<NotifyParams>(Methods.NOTIFY, params: Some(params))
                this.logger(dep.entry.id, "notify ${kind} ${key}")
            } catch (e: Exception) {
                this.logger(dep.entry.id, "notify failed: ${e.message}")
            }
        }
    }

    /**
     * 崩溃自愈：desired 存在但实际进程已退出 → 标记 Failed 后重新拉起
     */
    private func healCrashed(): Unit {
        // 【死锁红线】本方法跑在启动关键路径上（reconcileDesired 的最后一环，
        // 主线程），必须保证「既不持锁等待、也不持锁调外部对象」：
        //
        // ① 绝不持 state.lock 去调外部对象。isExited → client.isClosed() 会再取
        //    client 自己的锁；插件 IPC 线程可能正持有它、反过来要 state.lock
        //    （provide / initialize 回调链），形成 AB-BA 交叉死锁。
        // ② state.lock 用 tryLock，拿不到就整轮跳过。崩溃自愈只是尽力而为的
        //    补偿动作，不值得让启动关键路径为它无限等待 —— 下一轮 reconcile /
        //    awaitActive 的超时兜底会再次走到这里。
        //    依据：2026-10-01 05:29:05 那次运行，4 个插件全部 launched 之后主线程
        //    就永久静默 —— cmd-runtime.md 最后一行是 [HS-INIT] sdd（IPC 线程打的），
        //    而主线程本该紧接着打印的 [CordisHostManager][DIAG] awaitActive #1/4
        //    始终没出现。reconcileDesired 里 4 个插件已全部拉起、toRemove/toUpdate
        //    为空，唯一剩下的阻塞点就是这里的取锁 + isExited。
        if (!this.state.lock.tryLock()) {
            // 刻意走 diag（stderr，无缓冲）而非 this.logger：本分支的存在意义就是
            // 「不能在启动关键路径上为自愈动作冒险」，日志子系统同样不许碰。
            this.diag("reconcile", "healCrashed skipped: state.lock busy")
            return
        }
        let snapshot = ArrayList<(String, PluginInstance)>()
        for ((id, instance) in this.state.actual) {
            if (this.state.desired.contains(id)) {
                snapshot.add((id, instance))
            }
        }
        this.state.lock.unlock()

        let crashed = ArrayList<String>()
        for ((id, instance) in snapshot) {
            if (this.manager.isExited(instance)) {
                crashed.add(id)
            }
        }
        for (id in crashed) {
            let entry = this.state.desired.get(id)
            match (entry) {
                case Some(e) =>
                    this.logger(id, "crashed, restarting")
                    // 先标记 Failed（Fiber 状态机：awaitActive/监听器可感知崩溃）
                    match (this.state.getInstance(id)) {
                        case Some(inst) =>
                            this.transitionStatus(inst, InstanceStatus.Failed,
                                error: Some("process exited unexpectedly"))
                        case None => ()
                    }
                    this.state.removeInstance(id)
                    this.state.clearServicesByProvider(id)
                    try {
                        this.launchPlugin(e)
                        this.logger(id, "restarted")
                    } catch (ex: Exception) {
                        this.logger(id, "restart failed: ${ex.message}")
                    }
                case None => ()
            }
        }
    }

    /**
     * 拓扑排序：inject 依赖者后启动（简单的依赖分层）
     * 无依赖/依赖已满足的优先；有循环依赖时按原顺序（避免死循环）
     */
    private func topoSort(entries: ArrayList<PluginEntry>): Unit {
        // 构建 serviceKey -> 提供者集合
        let providerOf = HashMap<String, ArrayList<String>>()
        for (entry in entries) {
            for (key in entry.provide) {
                if (!providerOf.contains(key)) {
                    providerOf[key] = ArrayList<String>()
                }
                providerOf[key].add(entry.id)
            }
        }
        let result = ArrayList<PluginEntry>()
        let placed = HashSet<String>()
        var remaining = ArrayList<PluginEntry>(entries)
        var progress = true
        while (progress && remaining.size > 0) {
            progress = false
            let defer = ArrayList<PluginEntry>()
            for (entry in remaining) {
                // 所有依赖都已放置？
                let depsOk = entry.inject.all { key =>
                    if (placed.contains(key) || !providerOf.contains(key)) {
                        true   // 依赖已就绪，或无人提供（等待外部/已存在服务）
                    } else {
                        // 有提供者但尚未放置 → 未就绪
                        providerOf[key].all { pid => placed.contains(pid) }
                    }
                }
                if (depsOk) {
                    result.add(entry)
                    placed.add(entry.id)
                    for (key in entry.provide) {
                        placed.add(key)
                    }
                    progress = true
                } else {
                    defer.add(entry)
                }
            }
            remaining = defer
        }
        // 剩余（循环依赖）按原顺序追加
        for (entry in remaining) {
            result.add(entry)
        }
        entries.clear()
        entries.add(all: result)
    }
}
