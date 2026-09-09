package ystyle::cordis_plugin

import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import stdx.serialization.serialization.*
import stdx.encoding.json.stream.{JsonSerializable, JsonDeserializable}
import std.collection.{HashMap, ArrayList, map, collectArray}
import std.sync.{Mutex, Condition}

/**
 * 插件运行时上下文：暴露给插件业务逻辑的 API（docs/design-impl.md §6）
 *
 * 对应 Cordis 的 ctx 对象：服务提供/撤销、可逆效果、日志、宿主调用转发。
 */
public class PluginContext {
    internal let runtime: PluginRuntime

    internal init(runtime: PluginRuntime) {
        this.runtime = runtime
    }

    /**
     * 提供服务（主动注册到宿主），返回宿主分配的 undo_id
     * @param key 服务 Key
     */
    public func provide(key: String): String {
        this.runtime.provideService(key, { => () })
    }

    /**
     * 提供服务（主动注册到宿主），返回宿主分配的 undo_id
     * @param key 服务 Key
     * @param disposer 撤销该服务时执行的回调
     */
    public func provide(key: String, disposer: () -> Unit): String {
        this.runtime.provideService(key, disposer)
    }

    /**
     * 撤销指定服务
     */
    public func dispose(undoId: String): Bool {
        this.runtime.disposeService(undoId)
    }

    /**
     * 注册服务实现：宿主 invoke 转发到本插件时调用
     * @param key 服务 Key（与 provide 的 Key 对应）
     * @param handler (method, args) -> result
     */
    public func registerHandler(key: String, handler: (String, Array<JsonValue>) -> JsonValue): Unit {
        this.runtime.registry.registerHandler(key, handler)
    }

    /**
     * 注册服务实现（泛型版）：宿主 invoke 转发到本插件时调用
     *
     * 参数自动反序列化（T <: JsonDeserializable<T>），返回值自动序列化
     * （R <: JsonSerializable），服务端 handler 直接操作仓颉类型。
     *
     * @param key 服务 Key（与 provide 的 Key 对应）
     * @param handler (method, args: Array<T>) -> R
     */
    public func registerHandler<T, R>(key: String, handler: (String, Array<T>) -> R): Unit
        where T <: JsonDeserializable<T>, R <: JsonSerializable {
        this.runtime.registry.registerHandler<T, R>(key, handler)
    }

    /**
     * 注册可逆效果：返回 disposer，插件卸载时逆序执行（对应 Cordis ctx.effect）
     */
    public func effect(disposer: () -> Unit): Unit {
        this.runtime.registry.effect(disposer)
    }

    /**
     * 注册可逆效果（带 label，docs/cordis-comparison.md §4 getEffects 诊断树）
     * @param disposer 撤销回调
     * @param label 效果标签（getEffects() 诊断展示）
     */
    public func effect(disposer: () -> Unit, label: String): Unit {
        this.runtime.registry.effect(disposer, label)
    }

    /**
     * 注册异步可逆效果（docs/cordis-comparison.md §4 async effect）
     *
     * disposer 返回 Future<Unit>（如 spawn 的异步清理任务）；插件卸载时
     * disposeAll 等待所有异步 disposer 完成。
     *
     * @param disposer 撤销回调（返回 Future）
     * @param label 效果标签
     */
    public func effectAsync(disposer: () -> Future<Unit>, label!: String = "async"): Unit {
        this.runtime.registry.effectAsync(disposer, label: label)
    }

    /**
     * 效果诊断树（docs/cordis-comparison.md §4，对齐 Cordis Fiber.getEffects）：
     * 返回当前已注册效果的 label 列表（按注册顺序）
     */
    public func getEffects(): ArrayList<String> {
        this.runtime.registry.getEffects()
    }

    /**
     * 经宿主转发调用其他插件的服务
     * @param service 目标服务 Key
     * @param method 服务方法名
     * @param args 参数列表（JsonValue，手动构造）
     * @return 服务返回值（JSON）
     * @throws Exception 宿主返回错误或调用超时
     */
    public func invoke(service: String, method: String, args: Array<JsonValue>): JsonValue {
        this.runtime.invokeService(service, method, args)
    }

    /**
     * 经宿主转发调用其他插件的服务（泛型版）
     *
     * 参数自动序列化（T <: JsonSerializable），返回值自动反序列化
     * （R <: JsonDeserializable<R>），省去调用方手动 JsonValue 转换。
     *
     * @param service 目标服务 Key
     * @param method 服务方法名
     * @param args 参数列表（任意可序列化类型）
     * @return 服务返回值（自动反序列化为 R）
     * @throws Exception 宿主返回错误或调用超时
     */
    public func invoke<T, R>(service: String, method: String, args: Array<T>): R
        where T <: JsonSerializable, R <: JsonDeserializable<R> {
        let jsonArgs = args |> map { a: T => JsonValue.fromObject(a) } |> collectArray
        let result = this.runtime.invokeService(service, method, jsonArgs)
        JsonValue.toObject<R>(result)
    }

    /**
     * 发送日志到宿主（log 通知）
     */
    public func log(level: String, message: String): Unit {
        this.runtime.sendLog(level, message, None)
    }

    /**
     * 获取命名日志器（docs/cordis-comparison.md §4，对齐 Cordis `ctx.logger(name)`）
     *
     * 返回带名称的日志器，日志经宿主 log 通知并携带 logger 名称
     * （宿主侧 LogParams.logger），可按来源区分。
     *
     * @param name 日志器名称（如 "db"、"http"）
     * @return 命名日志器（trace/debug/info/warn/error 五个级别）
     */
    public func logger(name: String): PluginLogger {
        PluginLogger(name, { n, level, message => this.runtime.sendLog(level, message, Some(n)) })
    }

    // ── 定时器（docs/cordis-comparison.md §4 timer）────────────────────

    /**
     * 一次性定时（对齐 Cordis ctx.timeout）
     * @param delayMs 延迟毫秒
     * @param callback 到期回调
     * @return 撤销函数
     */
    public func timeout(delayMs: Int64, callback: () -> Unit): () -> Unit {
        this.runtime.timers.timeout(delayMs, callback)
    }

    /**
     * 周期定时（对齐 Cordis ctx.interval）
     * @param periodMs 周期毫秒
     * @param callback 周期回调
     * @return 撤销函数
     */
    public func interval(periodMs: Int64, callback: () -> Unit): () -> Unit {
        this.runtime.timers.interval(periodMs, callback)
    }

    /**
     * 节流（对齐 Cordis ctx.throttle）：最小执行间隔内合并调用
     * @param intervalMs 最小间隔毫秒
     * @param callback 回调
     * @return 触发函数
     */
    public func throttle(intervalMs: Int64, callback: () -> Unit): () -> Unit {
        this.runtime.timers.throttle(intervalMs, callback)
    }

    /**
     * 防抖（对齐 Cordis ctx.debounce）：静默 intervalMs 后执行最后一次
     * @param intervalMs 静默毫秒
     * @param callback 回调
     * @return 触发函数
     */
    public func debounce(intervalMs: Int64, callback: () -> Unit): () -> Unit {
        this.runtime.timers.debounce(intervalMs, callback)
    }

    /**
     * 订阅事件（docs/design-events.md §6）
     *
     * 事件经宿主路由：任意插件 emit 该事件时，本监听器被调用。
     * 订阅是效果：插件卸载时自动退订（对齐 Cordis ctx.on 语义）。
     *
     * @param event 事件名
     * @param listener 回调（事件参数列表）
     * @return 订阅 id
     */
    public func on(event: String, listener: (Array<JsonValue>) -> Unit): String {
        this.runtime.subscribeEvent(event, { args, _ => listener(args); None })
    }

    /**
     * 一次性订阅（对齐 Cordis ctx.once）：首次派发后自动退订
     * @param event 事件名
     * @param listener 回调
     * @return 订阅 id
     */
    public func once(event: String, listener: (Array<JsonValue>) -> Unit): String {
        this.runtime.subscribeEvent(event, { args, _ => listener(args); None }, once: true)
    }

    /**
     * 订阅事件（返回值版 listener，供 serial/bail/waterfall 使用）
     *
     * 返回值语义：
     * - None：不产生结果（对 serial/bail 视为未命中 bail；对 waterfall 视为不传值）
     * - Some(v)：对 serial/bail 视为 bail 值（v 非 null/false）；对 waterfall 作为下一个订阅者的参数
     *
     * @param event 事件名
     * @param listener 回调（返回 ?JsonValue）
     * @param once 一次性：首次派发后自动退订
     * @param prepend 插到订阅列表头部
     * @return 订阅 id
     */
    public func onVal(event: String, listener: (Array<JsonValue>) -> ?JsonValue, once!: Bool = false, prepend!: Bool = false): String {
        this.runtime.subscribeEvent(event, { args, _ => listener(args) }, once: once, prepend: prepend)
    }

    /**
     * 订阅事件（类型安全版，docs/cordis-comparison.md §4 on<T>）
     *
     * 事件参数自动反序列化为 T（T <: JsonDeserializable<T>）：
     * 订阅者直接操作仓颉类型，省去手动 JsonValue 转换。
     *
     * ```cangjie
     * ctx.on<AddRequest>("calc/add", { req =>
     *     // req: AddRequest（自动从 args[0] 反序列化）
     *     ctx.log("info", "got ${req.a} + ${req.b}")
     * })
     * ```
     *
     * @param event 事件名
     * @param listener 回调（接收 T）
     * @return 订阅 id
     */
    public func on<T>(event: String, listener: (T) -> Unit): String where T <: JsonDeserializable<T> {
        this.runtime.subscribeEvent(event, { args, _ =>
            if (args.size > 0) {
                try {
                    let typed = JsonValue.toObject<T>(args[0])
                    listener(typed)
                } catch (e: Exception) {
                    ()
                }
            }
            None
        })
    }

    /**
     * 一次性订阅（类型安全版）
     */
    public func once<T>(event: String, listener: (T) -> Unit): String where T <: JsonDeserializable<T> {
        this.runtime.subscribeEvent(event, { args, _ =>
            if (args.size > 0) {
                try {
                    let typed = JsonValue.toObject<T>(args[0])
                    listener(typed)
                } catch (e: Exception) {
                    ()
                }
            }
            None
        }, once: true)
    }

    /**
     * 订阅事件（返回值版，类型安全）
     *
     * 事件参数自动反序列化为 T；listener 返回 ?JsonValue
     * （serial/bail/waterfall 派发模式用，语义同 onVal）。
     */
    public func onVal<T>(event: String, listener: (T) -> ?JsonValue, once!: Bool = false, prepend!: Bool = false): String
        where T <: JsonDeserializable<T> {
        this.runtime.subscribeEvent(event, { args, _ =>
            if (args.size > 0) {
                try {
                    let typed = JsonValue.toObject<T>(args[0])
                    listener(typed)
                } catch (e: Exception) {
                    None
                }
            } else {
                None
            }
        }, once: once, prepend: prepend)
    }

    /**
     * 订阅事件（waterfall 洋葱 next 版，docs/design-events.md §7）
     *
     * 完整对齐 Cordis `ctx.on(name, (args, next) => result)`：
     * - listener 收到事件参数 + next 回调
     * - 调用 next() 推进链到下一个订阅者（最终触发宿主内置行为）
     * - 不调 next 直接返回 = veto 短路（该返回值即整条链的结果）
     *
     * 典型洋葱写法：
     * ```cangjie
     * ctx.onWaterfall("request", { args, next =>
     *     // 前处理...
     *     let result = next()          // 调用下一层（最终内置行为）
     *     // 后处理...
     *     result                        // 把结果继续传回上层
     * })
     * ```
     *
     * @param event 事件名
     * @param listener 回调（参数列表, next）-> ?JsonValue
     * @param once 一次性：首次派发后自动退订
     * @param prepend 插到订阅列表头部
     * @return 订阅 id
     */
    public func onWaterfall(event: String, listener: (Array<JsonValue>, () -> ?JsonValue) -> ?JsonValue,
                            once!: Bool = false, prepend!: Bool = false): String {
        this.runtime.subscribeEvent(event, { args, nextOpt =>
            match (nextOpt) {
                case Some(next) => listener(args, next)
                // 非 waterfall 模式派发：next 退化为内置行为（None）
                case None => listener(args, { => None })
            }
        }, once: once, prepend: prepend)
    }

    /**
     * 订阅事件（waterfall 洋葱 next 版，类型安全）
     *
     * 同 onWaterfall，事件参数自动反序列化为 T。
     */
    public func onWaterfall<T>(event: String, listener: (T, () -> ?JsonValue) -> ?JsonValue,
                               once!: Bool = false, prepend!: Bool = false): String
        where T <: JsonDeserializable<T> {
        this.runtime.subscribeEvent(event, { args, nextOpt =>
            if (args.size > 0) {
                try {
                    let typed = JsonValue.toObject<T>(args[0])
                    match (nextOpt) {
                        case Some(next) => listener(typed, next)
                        case None => listener(typed, { => None })
                    }
                } catch (e: Exception) {
                    None
                }
            } else {
                None
            }
        }, once: once, prepend: prepend)
    }

    /**
     * 发布事件（docs/design-events.md §6）
     *
     * emit 模式：通知宿主扇出给所有订阅者，发布者不等待、不感知订阅者。
     *
     * @param event 事件名
     * @param args 事件参数
     */
    public func emit(event: String, args: Array<JsonValue>): Unit {
        this.runtime.emitEvent(event, args, EventMode.EMIT)
    }

    /**
     * 并发派发（docs/design-events.md §7）：宿主并发向所有订阅者派发，等待全部完成
     * @param event 事件名
     * @param args 事件参数
     */
    public func parallel(event: String, args: Array<JsonValue>): Unit {
        this.runtime.emitEvent(event, args, EventMode.PARALLEL)
    }

    /**
     * 按序派发（docs/design-events.md §7）：宿主按订阅顺序派发，
     * 遇 bail 值（listener 返回非 null/false）停止并返回该值
     * @param event 事件名
     * @param args 事件参数
     * @return 首个 bail 值；无订阅者命中时 None
     */
    public func serial(event: String, args: Array<JsonValue>): ?JsonValue {
        this.runtime.emitEventSync(event, args, EventMode.SERIAL)
    }

    /**
     * 同步按序派发（bail 模式）：同 serial，语义对齐 Cordis ctx.bail
     */
    public func bail(event: String, args: Array<JsonValue>): ?JsonValue {
        this.runtime.emitEventSync(event, args, EventMode.BAIL)
    }

    /**
     * 链式派发（waterfall 模式，docs/design-events.md §7 洋葱 next）：
     *
     * 完整对齐 Cordis waterfall：宿主把订阅者串成洋葱链，最外层订阅者
     * 收到 (args, next)；调用 next() 推进到下一层（最终内置行为），
     * 返回非 null 值则 veto 短路。整条链的结果 = 最外层订阅者的返回值。
     *
     * @param event 事件名
     * @param args 事件参数
     * @return 链式派发结果（最外层订阅者返回值）；全部 next 到底时为 None
     */
    public func waterfall(event: String, args: Array<JsonValue>): ?JsonValue {
        this.runtime.emitEventSync(event, args, EventMode.WATERFALL)
    }

    // ── 类型安全发布（docs/cordis-comparison.md §4 emit<T>）──────────────

    /**
     * 发布事件（类型安全版，docs/cordis-comparison.md §4 emit<T>）
     *
     * 事件参数自动序列化（T <: JsonSerializable），发布者直接传仓颉类型，
     * 省去手动 JsonValue 转换（与订阅侧 on<T> 配套）。
     *
     * ```cangjie
     * ctx.emit<AddRequest>("calc/add", [AddRequest(2, 3)])
     * ```
     *
     * @param event 事件名
     * @param args 事件参数（自动序列化为 JsonValue）
     */
    public func emit<T>(event: String, args: Array<T>): Unit where T <: JsonSerializable {
        let jsonArgs = args |> map { a: T => JsonValue.fromObject(a) } |> collectArray
        this.runtime.emitEvent(event, jsonArgs, EventMode.EMIT)
    }

    /**
     * 并发派发（类型安全版）
     */
    public func parallel<T>(event: String, args: Array<T>): Unit where T <: JsonSerializable {
        let jsonArgs = args |> map { a: T => JsonValue.fromObject(a) } |> collectArray
        this.runtime.emitEvent(event, jsonArgs, EventMode.PARALLEL)
    }

    /**
     * 按序派发（类型安全版）
     */
    public func serial<T>(event: String, args: Array<T>): ?JsonValue where T <: JsonSerializable {
        let jsonArgs = args |> map { a: T => JsonValue.fromObject(a) } |> collectArray
        this.runtime.emitEventSync(event, jsonArgs, EventMode.SERIAL)
    }

    /**
     * 同步按序派发（类型安全版）
     */
    public func bail<T>(event: String, args: Array<T>): ?JsonValue where T <: JsonSerializable {
        let jsonArgs = args |> map { a: T => JsonValue.fromObject(a) } |> collectArray
        this.runtime.emitEventSync(event, jsonArgs, EventMode.BAIL)
    }

    /**
     * 链式传值（类型安全版）
     */
    public func waterfall<T>(event: String, args: Array<T>): ?JsonValue where T <: JsonSerializable {
        let jsonArgs = args |> map { a: T => JsonValue.fromObject(a) } |> collectArray
        this.runtime.emitEventSync(event, jsonArgs, EventMode.WATERFALL)
    }

    /**
     * 插件私有配置（宿主从 entry.config 下发，握手时获得）
     * 类型为 DataModel（stdx.serialization 中间表示），可 match 各子类型读取
     */
    public prop config: DataModel {
        get() {
            this.runtime.pluginConfig
        }
    }

    /**
     * 创建服务代理（@Inject 宏产物）
     *
     * @param serviceKey 目标服务 Key
     * @return 经宿主 invoke 转发的代理
     */
    public func proxy(serviceKey: String): ServiceProxy {
        ServiceProxy(this.runtime.rpcServer, serviceKey)
    }
}

/**
 * 插件运行时（docs/design-impl.md §6）
 *
 * 插件 main 入口：PluginRuntime.run(...) 完成握手、注册服务、进入事件循环。
 *
 * 生命周期：
 * 1. 创建 StdioTransport + JsonRpcServer，注册宿主 → 插件处理器
 * 2. server.start() 启动后台接收线程
 * 3. 向宿主发 initialize 请求（握手）
 * 4. 为每个 provide 的 Key 发 provide 请求，宿主返回 undo_id
 * 5. 调用插件业务 handler(ctx)
 * 6. 阻塞等待连接关闭（宿主 terminate 强杀 → stdin EOF → receiveLoop 自动关闭）
 * 7. 逆序撤销所有效果与服务（disposeAll）
 */
public class PluginRuntime {
    internal let registry: ServiceRegistry = ServiceRegistry()
    private let server: JsonRpcServer
    private let pluginId: String
    private let lock: Mutex = Mutex()
    // 事件监听器：事件名 -> listener（docs/design-events.md §6、§7）
    // listener 返回 ?JsonValue：emit 模式忽略；serial/bail/waterfall 作为派发结果。
    // 第二参数为 next 回调（waterfall 洋葱链用，docs/design-events.md §7）：
    // 宿主派发时 nextAllowed=true 传 Some(next)，其余模式传 None。
    private let listeners: HashMap<String, (Array<JsonValue>, ?(() -> ?JsonValue)) -> ?JsonValue> =
        HashMap<String, (Array<JsonValue>, ?(() -> ?JsonValue)) -> ?JsonValue>()
    // 依赖变更通知：PROVIDER_CHANGED/DEPENDENCY_LOST 到达时唤醒等待中的握手重试
    private let retryCond: Condition
    private var dependencyChanged: Bool = false
    // 最近一次收到的依赖通知（供插件业务感知，docs/cordis-comparison.md §4）
    private var lastNotify: ?NotifyParams = None
    // 插件私有配置（宿主 initialize 响应下发，docs/cordis-comparison.md §4 配置传递）
    internal var pluginConfig: DataModel = DataModelNull()
    // 定时器工具（ctx.timeout/interval/throttle/debounce）
    internal let timers: PluginTimers = PluginTimers()

    /**
     * 以插件自身 stdio 为传输层启动（插件 main 的标准入口）
     *
     * 使用 LineStdioTransport + NewlineFraming（换行帧协议）：
     * 仓颉 ConsoleReader.read(Array<Byte>) 在管道 stdin 下会永久阻塞，
     * readln() 可靠，因此插件侧逐行读取（与 mcp-cj 生产方案一致）。
     * 宿主侧 PipeTransport 必须使用 NewlineFraming 保持一致。
     *
     * @param pluginId 插件唯一 ID
     * @param inject 依赖的服务 Key 列表
     * @param provide 提供的服务 Key 列表
     * @param handler 插件业务逻辑（握手与服务注册完成后调用）
     */
    public static func run(pluginId: String, inject: Array<String>, provide: Array<String>,
                           handler: (PluginContext) -> Unit): Unit {
        eprintln("[${pluginId}] PluginRuntime.run entered")
        // 传输固定 stdio（design §5.2），NewlineFraming 逐行读取
        let transport = LineStdioTransport()
        let server = JsonRpcServer(transport, framing: NewlineFraming())
        let runtime = PluginRuntime(server, pluginId)
        eprintln("[${pluginId}] calling runtime.start...")
        runtime.start(inject, provide, handler)
        eprintln("[${pluginId}] runtime.start returned")
    }

    /**
     * 以自定义传输层启动（测试或特殊传输场景）
     */
    public static func run(transport: Transport, pluginId: String, inject: Array<String>,
                           provide: Array<String>, handler: (PluginContext) -> Unit): Unit {
        let server = JsonRpcServer(transport, framing: NewlineFraming())
        let runtime = PluginRuntime(server, pluginId)
        runtime.start(inject, provide, handler)
    }

    private init(server: JsonRpcServer, pluginId: String) {
        this.server = server
        this.pluginId = pluginId
        this.retryCond = synchronized(this.lock) {
            this.lock.condition()
        }
    }

    private func start(inject: Array<String>, provide: Array<String>,
                       handler: (PluginContext) -> Unit): Unit {
        eprintln("[${this.pluginId}] start() entered, inject=${inject.size}, provide=${provide.size}")
        this.registerHandlers()
        eprintln("[${this.pluginId}] registerHandlers() done")
        // 注意：不启动 server.start()（receiveLoop）。
        // 仓颉 spawn 创建的仓颉线程在 readln() 阻塞时，会阻塞整个原生线程，
        // 导致主线程无法发送 initialize 请求。
        // 因此 server.request() 在 receiveLoop 未启动时，自己同步读取宿主响应。

        // 握手：向宿主发 initialize 请求。
        // 依赖未满足（ok=false）时保持 Pending 等待重试，而非抛异常退出
        // （对齐 Cordis PENDING 语义，docs/cordis-comparison.md §4）。
        // 等待期间宿主 notify（PROVIDER_CHANGED）会唤醒立即重试。
        var handshakeOk = false
        while (!handshakeOk) {
            if (this.server.isClosed()) {
                eprintln("[${this.pluginId}] server closed before request")
                return   // 宿主终止 → 连接关闭，正常退出
            }
            eprintln("[${this.pluginId}] sending initialize request...")
            let initResult = this.server.request<InitializeParams, InitializeResult>(
                Methods.INITIALIZE,
                params: InitializeParams(this.pluginId, inject, provide),
                timeout: 2 * Duration.second)
            match (initResult) {
                case Ok(r) =>
                    eprintln("[${this.pluginId}] initialize Ok, ok=${r.ok}")
                    if (r.ok) {
                        handshakeOk = true
                        // 保存宿主下发的插件私有配置（JsonValue → DataModel）
                        match (r.config) {
                            case Some(cfg) =>
                                this.pluginConfig = cfg.toDataModel()
                            case None => ()
                        }
                    }
                    // ok=false：依赖未满足，进入等待重试
                case Err(e) =>
                    eprintln("[${this.pluginId}] initialize Err: ${e}")
                    // 连接已关闭（宿主终止）则退出；否则视为临时失败重试
                    if (this.server.isClosed()) {
                        return
                    }
            }
            if (!handshakeOk) {
                this.waitForDependencyChange()
            }
        }

        // 注册服务：为每个 provide 的 Key 向宿主申请 undo_id
        for (key in provide) {
            this.provideService(key, { => () })
        }

        // 插件业务逻辑
        let ctx = PluginContext(this)
        handler(ctx)

        // 握手成功且业务逻辑注册完毕后，启动接收线程处理宿主发来的后续请求。
        // 之前不启动是因为 readln() 阻塞会阻止主线程发送 initialize 请求；
        // 现在 initialize 已完成，可以启动 receiveLoop 了。
        this.server.start()

        // 阻塞等待连接关闭（宿主 terminate → stdin EOF → receiveLoop 关闭 server）
        while (!this.server.isClosed()) {
            sleep(100 * Duration.millisecond)
        }

        // 卸载：逆序撤销所有效果与服务
        this.registry.disposeAll()
    }

    /**
     * 等待依赖变化（最长 1s）：宿主 notify（PROVIDER_CHANGED/DEPENDENCY_LOST）
     * 唤醒后立即重试握手；否则超时后按轮询节奏重试
     */
    private func waitForDependencyChange(): Unit {
        synchronized(this.lock) {
            // 先消费已到达的 notify（若在握手请求期间到达，无需再等）
            this.dependencyChanged = false
            while (!this.dependencyChanged) {
                if (!this.retryCond.wait(timeout: 1 * Duration.second)) {
                    return   // 超时：轮询重试
                }
            }
        }
    }

    private func registerHandlers(): Unit {
        // initialized：宿主确认依赖满足，允许开始工作（通知，无响应）
        this.server.register(Methods.INITIALIZED, { _ => HandlerResult.ok(JsonValue.Boolean(true)) })
        // dispose：宿主请求撤销指定服务
        this.server.register(Methods.DISPOSE, { ctx => this.handleDispose(ctx) })
        // notify：宿主广播依赖图变化
        this.server.register(Methods.NOTIFY, { ctx => this.handleNotify(ctx) })
        // ping：探活
        this.server.register(Methods.PING, { _ => HandlerResult.ok(JsonValue.Boolean(true)) })
        // invoke：宿主转发的服务调用（异步 handler，支持 handler 内再发请求
        // —— 如 @Inject 代理调用远程服务，接收线程不阻塞避免死锁）
        this.server.registerAsync(Methods.INVOKE, { ctx, complete =>
            spawn {
                match (ctx.getParams<InvokeParams>()) {
                    case Some(params) =>
                        try {
                            let result = this.registry.invokeHandler(params.service, params.method, params.args)
                            complete(result)
                        } catch (e: Exception) {
                            // 异常信息透传（调试/协议错误可见）；协议化错误在后续版本完善
                            complete(JsonValue.String("INVOKE-ERROR: ${e.message}"))
                        }
                    case None => complete(JsonValue.String("INVOKE-ERROR: missing params"))
                }
            }
        })
        // events/dispatch：宿主派发事件（异步 handler，listener 在独立线程执行，
        // 支持 listener 内再发请求，接收线程不阻塞）
        // listener 返回值 ?JsonValue 作为派发结果回给宿主（serial/bail/waterfall 用）
        // waterfall 模式（params.nextAllowed）：构造 next 闭包传给 listener——
        // next() 发 events/next 请求推进链，返回下一订阅者的结果
        // （docs/design-events.md §7 洋葱 next）
        this.server.registerAsync(Methods.EVENTS_DISPATCH, { ctx, complete =>
            spawn {
                match (ctx.getParams<DispatchParams>()) {
                    case Some(params) =>
                        var listener: ?(Array<JsonValue>, ?(() -> ?JsonValue)) -> ?JsonValue = None
                        synchronized(this.lock) {
                            if (this.listeners.contains(params.event)) {
                                listener = this.listeners[params.event]
                            }
                        }
                        match (listener) {
                            case Some(l) =>
                                if (params.nextAllowed) {
                                    // waterfall：构造 next 闭包（发 events/next 请求）
                                    let next: () -> ?JsonValue = { =>
                                        let result = this.server.request<NextParams, JsonValue>(
                                            Methods.EVENTS_NEXT,
                                            params: NextParams(params.emitId))
                                        match (result) {
                                            case Ok(v) =>
                                                match (v) {
                                                    case JsonValue.Null => None
                                                    case other => Some(other)
                                                }
                                            case Err(e) => None
                                        }
                                    }
                                    match (l(params.args, Some(next))) {
                                        case Some(v) => complete(v)
                                        case None => complete(JsonValue.Null)
                                    }
                                } else {
                                    match (l(params.args, None)) {
                                        case Some(v) => complete(v)
                                        case None => complete(JsonValue.Null)
                                    }
                                }
                            case None =>
                                complete(JsonValue.Boolean(false))
                        }
                    case None => complete(JsonValue.Boolean(false))
                }
            }
        })
    }

    private func handleDispose(ctx: HandlerContext): HandlerResult {
        match (ctx.getParams<DisposeParams>()) {
            case Some(params) =>
                let removed = this.registry.dispose(params.undoId)
                HandlerResult.ok(JsonValue.Boolean(removed))
            case None => HandlerResult.err(ErrorCodes.INVALID_PARAMS, "invalid dispose params")
        }
    }

    private func handleNotify(ctx: HandlerContext): HandlerResult {
        match (ctx.getParams<NotifyParams>()) {
            case Some(params) =>
                // 记录通知；PROVIDER_CHANGED（依赖就绪）唤醒等待中的握手重试
                synchronized(this.lock) {
                    this.lastNotify = params
                    if (params.kind == NotifyKind.PROVIDER_CHANGED) {
                        this.dependencyChanged = true
                        this.retryCond.notifyAll()
                    }
                }
                HandlerResult.ok(JsonValue.Boolean(true))
            case None => HandlerResult.err(ErrorCodes.INVALID_PARAMS, "invalid notify params")
        }
    }

    /**
     * 提供服务：向宿主申请 undo_id 并注册撤销回调
     */
    internal func provideService(key: String, disposer: () -> Unit): String {
        let result = this.server.request<ProvideParams, ProvideResult>(
            Methods.PROVIDE,
            params: ProvideParams(key))
        match (result) {
            case Ok(r) =>
                this.registry.register(r.undoId, disposer)
                r.undoId
            case Err(e) => throw Exception("provide '${key}' failed: ${e}")
        }
    }

    /**
     * 撤销服务
     */
    internal func disposeService(undoId: String): Bool {
        this.registry.dispose(undoId)
    }

    /**
     * 经宿主转发调用其他插件的服务
     */
    internal func invokeService(service: String, method: String, args: Array<JsonValue>): JsonValue {
        // 宿主内置服务（host.db/host.log/host.cache）直接以服务名为 JSON-RPC method
        // 插件间服务调用走 INVOKE 转发链路
        let rpcMethod = if (service.startsWith("host.")) {
            service
        } else {
            Methods.INVOKE
        }
        let result = this.server.request<InvokeParams, JsonValue>(
            rpcMethod,
            params: InvokeParams(service, method, args))
        match (result) {
            case Ok(v) => v
            case Err(e) => throw Exception("invoke ${service}.${method} failed: ${e}")
        }
    }

    /**
     * 发送日志到宿主
     */
    internal func sendLog(level: String, message: String, logger: ?String): Unit {
        this.server.notify<LogParams>(Methods.LOG, params: LogParams(level, message, logger: logger))
    }

    internal prop rpcServer: JsonRpcServer {
        get() {
            this.server
        }
    }

    /**
     * 订阅事件（docs/design-events.md §6、§7）
     * @param event 事件名
     * @param listener 回调（参数列表, next?）-> 可选结果；next 仅在 waterfall
     *                 模式派发时非 None（docs/design-events.md §7 洋葱 next）
     * @param once 一次性：首次派发后自动退订
     * @param prepend 插到订阅列表头部
     * @return 订阅 id；插件卸载时自动退订（effect 语义）
     */
    internal func subscribeEvent(event: String, listener: (Array<JsonValue>, ?(() -> ?JsonValue)) -> ?JsonValue,
                                 once!: Bool = false, prepend!: Bool = false): String {
        // 1. 向宿主发 events/subscribe 请求
        let result = this.server.request<SubscribeParams, SubscribeResult>(
            Methods.EVENTS_SUBSCRIBE,
            params: SubscribeParams(event, once: once, prepend: prepend))
        let subscriptionId = match (result) {
            case Ok(r) => r.subscriptionId
            case Err(e) => throw Exception("subscribe '${event}' failed: ${e}")
        }
        // 2. 存本地监听器（按事件名）
        synchronized(this.lock) {
            this.listeners[event] = listener
        }
        // 3. 注册退订 effect：插件卸载时自动退订
        this.registry.effect({ =>
            try {
                this.server.request<UnsubscribeParams, JsonValue>(
                    Methods.EVENTS_UNSUBSCRIBE,
                    params: UnsubscribeParams(subscriptionId))
                ()
            } catch (e: Exception) {
                ()
            }
        })
        subscriptionId
    }

    /**
     * 发布事件（docs/design-events.md §6、§7）：通知宿主扇出，不等待订阅者（emit 模式）
     */
    internal func emitEvent(event: String, args: Array<JsonValue>, mode: String): Unit {
        this.server.notify<EmitParams>(Methods.EVENTS_EMIT,
            params: EmitParams(event, args, mode: mode))
    }

    /**
     * 发布事件（同步模式：serial/bail/waterfall）：
     * 请求宿主按模式派发，等待聚合结果返回
     * @return 派发聚合结果（serial/bail/waterfall 有值；无命中时 None）
     */
    internal func emitEventSync(event: String, args: Array<JsonValue>, mode: String): ?JsonValue {
        let result = this.server.request<EmitParams, JsonValue>(
            Methods.EVENTS_EMIT,
            params: EmitParams(event, args, mode: mode))
        match (result) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Null => None
                    case other => Some(other)
                }
            case Err(e) => throw Exception("emit '${event}' (${mode}) failed: ${e}")
        }
    }
}
