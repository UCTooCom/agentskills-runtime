package ystyle::cordis_plugin

import jsonvalue.JsonValue
import std.collection.HashMap
import std.sync.Mutex

/**
 * 服务基类（docs/cordis-comparison.md §4 Service 类化，对齐 Cordis `Service`）
 *
 * 「类即服务」：插件作者继承本类并在构造中调用 `super(ctx, name)`，
 * 自动完成：
 * 1. `ctx.provide(name)` —— 服务注册到宿主（可带撤销回调）
 * 2. `registerHandler(name, ...)` —— 宿主 invoke 转发到 `onCall`
 *
 * 子类职责：
 * - 在构造中注册服务方法（`register(method, handler)`）
 * - 可选覆写 `check()`（可用性谓词，对齐 Cordis `[Service.check]`）
 *
 * ```cangjie
 * public class EchoService <: Service {
 *     public init(ctx: PluginContext) {
 *         super(ctx, "echo")
 *         this.register("echo", { args => if (args.size > 0) { args[0] } else { JsonValue.Null } })
 *     }
 * }
 * // 插件内：let svc = EchoService(ctx)
 * ```
 */
public abstract class Service {
    public let name: String
    protected let ctx: PluginContext
    // 服务方法路由：method -> handler（宿主 invoke 转发到本服务时查表）
    private let handlers: HashMap<String, (Array<JsonValue>) -> JsonValue> = HashMap<String, (Array<JsonValue>) -> JsonValue>()
    private let lock: Mutex = Mutex()

    /**
     * @param ctx 插件上下文
     * @param name 服务 Key（宿主 serviceIndex 中的标识）
     * @param disposer 撤销该服务时执行的回调（可选）
     */
    public init(ctx: PluginContext, name: String, disposer!: () -> Unit = { => () }) {
        this.ctx = ctx
        this.name = name
        ctx.provide(name, disposer)
    }

    /**
     * 完成服务注册（子类构造末尾调用）：
     * 注册服务方法路由（register）后，调用本方法把 invoke 分发接入。
     *
     * 仓颉限制：可继承类的构造函数不能捕获 `this`（子类未构造完成），
     * 因此 registerHandler 的闭包需在子类构造完成后注册（对齐 Cordis
     * `[Service.init]` 构造后钩子的语义）。
     *
     * ```cangjie
     * public init(ctx: PluginContext) {
     *     super(ctx, "echo")
     *     this.register("echo", { args => ... })
     *     this.bind()   // 构造末尾
     * }
     * ```
     */
    protected open func bind(): Unit {
        let self = this
        self.ctx.registerHandler(self.name, { method, args => self.onCall(method, args) })
    }

    /**
     * 注册服务方法：宿主 invoke `<service>.<method>` 时调用
     * @param method 方法名
     * @param handler (args) -> result
     */
    protected open func register(method: String, handler: (Array<JsonValue>) -> JsonValue): Unit {
        synchronized(this.lock) {
            this.handlers[method] = handler
        }
    }

    /**
     * 可用性谓词（对齐 Cordis `[Service.check]`）：服务是否可用于依赖者。
     * 默认 true；子类可覆写（如连接未就绪时返回 false）。
     */
    public open func check(): Bool {
        true
    }

    /**
     * 服务调用分发入口（registerHandler 的 target）：查方法表调用
     * @param method 方法名
     * @param args 参数
     * @return 调用结果
     * @throws Exception 方法未注册时
     */
    private func onCall(method: String, args: Array<JsonValue>): JsonValue {
        var handler: ?(Array<JsonValue>) -> JsonValue = None
        synchronized(this.lock) {
            if (this.handlers.contains(method)) {
                handler = this.handlers[method]
            }
        }
        match (handler) {
            case Some(h) => h(args)
            case None => throw Exception("service '${this.name}' has no method '${method}'")
        }
    }
}
