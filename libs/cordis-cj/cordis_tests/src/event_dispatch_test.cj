package ystyle::cordis_tests

import ystyle::cordis_host.*
import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.sync.{Mutex, Condition}
import std.io.ByteBuffer
import std.process.{launch, SubProcess, ProcessRedirect}
import std.unittest.*
import std.unittest.testmacro.*

/**
 * EventRegistry 派发模式测试（docs/design-events.md §7）
 *
 * 用「内存双端 + 简易订阅者 server」做真实 dispatch 往返：
 * 每个订阅者 = PluginInstance（真实子进程对象 + 内存 client），
 * 内存对端挂一个 JsonRpcServer 模拟插件监听 events/dispatch，
 * 响应由测试注入（模拟插件 listener 的返回值）。
 *
 * 覆盖：emit 广播 / serial+bail / waterfall 链 / parallel 并发 /
 *       once 自动退订 / prepend 顺序。
 */

/**
 * 内存订阅者辅助：包装一个订阅者的 JSON-RPC 对端
 * @param respond 注入的 dispatch 响应函数（返回 JsonValue，模拟 listener 结果）
 *
 * waterfall 洋葱 next（docs/design-events.md §7）：
 * - `waterfallRespond`：nextAllowed=true 时使用的响应函数，收到 (args, next)，
 *   可调 next()（发 events/next 请求推进链）或直接返回值（veto 短路）
 * - `registerNextHandler`：宿主侧注册 EVENTS_NEXT 处理器（推进 EventRegistry 链）
 */
internal class MemSubscriber {
    let client: JsonRpcClient       // 宿主 → 订阅者 连接（装入 PluginInstance）
    let server: JsonRpcServer       // 订阅者侧 server（处理 events/dispatch）
    let instance: PluginInstance
    let proc: SubProcess
    let lock: Mutex = Mutex()
    let cond: Condition
    var calls: ArrayList<String> = ArrayList()   // 收到的 (emitId, args) 记录
    var respond: (Array<JsonValue>) -> JsonValue = { _ => JsonValue.Boolean(true) }
    // waterfall 模式（nextAllowed=true）的响应函数：可调 next() 推进链
    var waterfallRespond: ?(Array<JsonValue>, () -> ?JsonValue) -> JsonValue = None

    init(pluginId: String, respondFn: (Array<JsonValue>) -> JsonValue) {
        this.respond = respondFn
        let (hostT, pluginT) = MemSubscriberTransport.pair()
        this.client = JsonRpcClient(hostT, framing: NewlineFraming())
        this.server = JsonRpcServer(pluginT, framing: NewlineFraming())
        this.cond = synchronized(this.lock) {
            this.lock.condition()
        }
        // PluginInstance 需要真实 SubProcess（仅占位，不使用其 IO）
        this.proc = launch("/bin/true", [],
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let entry = PluginEntry(pluginId, "/bin/true")
        this.instance = PluginInstance(entry, this.proc, this.client)
        this.server.start()
        this.client.start()
        this.registerDispatchHandler()
    }

    private func registerDispatchHandler(): Unit {
        // events/dispatch 处理器：记录调用，返回注入的响应
        // waterfall（nextAllowed=true）：构造 next 闭包（发 events/next 请求）
        // 传给 waterfallRespond；否则用普通 respond
        this.server.registerAsync(Methods.EVENTS_DISPATCH, { ctx, complete =>
            spawn {
                match (ctx.getParams<DispatchParams>()) {
                    case Some(params) =>
                        synchronized(this.lock) {
                            this.calls.add("${params.emitId}:${params.mode}")
                            this.cond.notifyAll()
                        }
                        if (params.nextAllowed) {
                            match (this.waterfallRespond) {
                                case Some(fn) =>
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
                                    complete(fn(params.args, next))
                                case None =>
                                    complete(this.respond(params.args))
                            }
                        } else {
                            complete(this.respond(params.args))
                        }
                    case None => complete(JsonValue.Boolean(false))
                }
            }
        })
    }

    /**
     * 宿主侧注册 EVENTS_NEXT 处理器（waterfall 链推进）
     * @param handler emitId -> 推进结果（通常转发给 EventRegistry.dispatchNext）
     */
    func registerNextHandler(handler: (String) -> ?JsonValue): Unit {
        this.client.registerRequestHandler(Methods.EVENTS_NEXT, { req =>
            match (req.params) {
                case Some(p) =>
                    let params = JsonValue.toObject<NextParams>(p)
                    // 链结束/未找到链 → None：必须回 Some(Null)，否则请求方超时
                    match (handler(params.emitId)) {
                        case Some(v) => Some(v)
                        case None => Some(JsonValue.Null)
                    }
                case None => Some(JsonValue.Null)
            }
        })
    }

    func waitCalls(n: Int64): Bool {
        synchronized(this.lock) {
            var waited = 0
            while (this.calls.size < n && waited < 100) {
                this.cond.wait(timeout: 50 * Duration.millisecond)
                waited++
            }
            this.calls.size >= n
        }
    }

    func close(): Unit {
        this.client.close()
        this.server.close()
        try {
            this.proc.terminate(force: true)
            this.proc.wait()
        } catch (e: Exception) {
            ()
        }
    }
}

@Test
class EventDispatchModeTest {

    @TestCase
    func testEmitBroadcastsToAll(): Unit {
        let registry = EventRegistry()
        let sub1 = MemSubscriber("a") { _ => JsonValue.Boolean(true) }
        let sub2 = MemSubscriber("b") { _ => JsonValue.Boolean(true) }
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance)

        let result = registry.dispatch("evt", [JsonValue.Number(1.0)], EventMode.EMIT, "emit-1")
        @Expect(result.isNone())   // emit 模式无聚合结果
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.waitCalls(1))

        sub1.close()
        sub2.close()
    }

    @TestCase
    func testSerialReturnsFirstBail(): Unit {
        let registry = EventRegistry()
        // 订阅者1：返回 null（不 bail）
        let sub1 = MemSubscriber("a") { _ => JsonValue.Null }
        // 订阅者2：返回 "found"（bail）
        let sub2 = MemSubscriber("b") { _ => JsonValue.String("found") }
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance)

        let result = registry.dispatch("evt", [], EventMode.SERIAL, "emit-1")
        match (result) {
            case Some(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "found")
                    case _ => @Fail("expected string bail value")
                }
            case None => @Fail("serial should return bail value")
        }
        // 两个订阅者都被调用（第一个未 bail，继续）
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.waitCalls(1))

        sub1.close()
        sub2.close()
    }

    @TestCase
    func testSerialStopsAtFirstBail(): Unit {
        let registry = EventRegistry()
        // 订阅者1：返回 42（bail）
        let sub1 = MemSubscriber("a") { _ => JsonValue.Number(42.0) }
        // 订阅者2：不应被调用
        let sub2 = MemSubscriber("b") { _ => JsonValue.String("never") }
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance)

        let result = registry.dispatch("evt", [], EventMode.BAIL, "emit-1")
        match (result) {
            case Some(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 42.0)
                    case _ => @Fail("expected number bail value")
                }
            case None => @Fail("bail should return first bail value")
        }
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.calls.size, 0)   // bail 短路，第二个未调用

        sub1.close()
        sub2.close()
    }

    @TestCase
    func testWaterfallVetoShortCircuits(): Unit {
        // 洋葱 next：订阅者1 不调 next 直接返回 = veto 短路，订阅者2 不应被调用
        let registry = EventRegistry()
        let sub1 = MemSubscriber("a") { _ => JsonValue.Boolean(true) }
        let sub2 = MemSubscriber("b") { _ => JsonValue.String("never") }
        // 订阅者1：veto（返回 "veto"，不调 next）
        sub1.waterfallRespond = { _, _ => JsonValue.String("veto") }
        sub1.registerNextHandler({ emitId => registry.dispatchNext(emitId) })
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance)

        let result = registry.dispatch("evt", [JsonValue.Number(1.0)], EventMode.WATERFALL, "emit-1")
        match (result) {
            case Some(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "veto")
                    case _ => @Fail("expected veto value")
                }
            case None => @Fail("veto should return value")
        }
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.calls.size, 0)   // veto 短路，订阅者2 未调用

        sub1.close()
        sub2.close()
    }

    @TestCase
    func testWaterfallNextChainsToNext(): Unit {
        // 洋葱 next：订阅者1 调 next() → 链推进到订阅者2；订阅者2 veto "final"
        // 订阅者1 返回 next() 的结果 → 最终结果 "final"
        let registry = EventRegistry()
        let sub1 = MemSubscriber("a") { _ => JsonValue.Boolean(true) }
        let sub2 = MemSubscriber("b") { _ => JsonValue.String("never") }
        // 订阅者1：调 next() 并返回其结果（洋葱透传）
        sub1.waterfallRespond = { _, next =>
            match (next()) {
                case Some(v) => v
                case None => JsonValue.Null
            }
        }
        // 订阅者2：veto "final"
        sub2.waterfallRespond = { _, _ => JsonValue.String("final") }
        sub1.registerNextHandler({ emitId => registry.dispatchNext(emitId) })
        sub2.registerNextHandler({ emitId => registry.dispatchNext(emitId) })
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance)

        let result = registry.dispatch("evt", [JsonValue.Number(1.0)], EventMode.WATERFALL, "emit-1")
        match (result) {
            case Some(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "final")
                    case _ => @Fail("expected chained result")
                }
            case None => @Fail("next chain should return final value")
        }
        // 两个订阅者都被调用（next 推进链）
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.waitCalls(1))

        sub1.close()
        sub2.close()
    }

    @TestCase
    func testWaterfallAllNextReturnsBuiltin(): Unit {
        // 洋葱 next：所有订阅者都调 next（无人 veto）→ 链结束，返回内置行为 None
        let registry = EventRegistry()
        let sub1 = MemSubscriber("a") { _ => JsonValue.Boolean(true) }
        let sub2 = MemSubscriber("b") { _ => JsonValue.Boolean(true) }
        // 两个订阅者都透传 next() 的结果（不 veto）
        sub1.waterfallRespond = { _, next =>
            match (next()) {
                case Some(v) => v
                case None => JsonValue.Null
            }
        }
        sub2.waterfallRespond = { _, next =>
            match (next()) {
                case Some(v) => v
                case None => JsonValue.Null
            }
        }
        sub1.registerNextHandler({ emitId => registry.dispatchNext(emitId) })
        sub2.registerNextHandler({ emitId => registry.dispatchNext(emitId) })
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance)

        let result = registry.dispatch("evt", [JsonValue.Number(1.0)], EventMode.WATERFALL, "emit-1")
        @Expect(result.isNone())   // 全部 next 到底 → 内置行为 None
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.waitCalls(1))

        sub1.close()
        sub2.close()
    }

    @TestCase
    func testParallelWaitsAll(): Unit {
        let registry = EventRegistry()
        let sub1 = MemSubscriber("a") { _ => JsonValue.Number(1.0) }
        let sub2 = MemSubscriber("b") { _ => JsonValue.Number(2.0) }
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance)

        let result = registry.dispatch("evt", [], EventMode.PARALLEL, "emit-1")
        @Expect(result.isNone())   // parallel 无聚合结果
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.waitCalls(1))

        sub1.close()
        sub2.close()
    }

    @TestCase
    func testOnceAutoUnsubscribes(): Unit {
        let registry = EventRegistry()
        let sub = MemSubscriber("a") { _ => JsonValue.Boolean(true) }
        let id = registry.subscribe("evt", "a", sub.instance, once: true)
        @Expect(registry.subscriberCount("evt"), 1)

        // 首次派发
        registry.dispatch("evt", [], EventMode.EMIT, "emit-1")
        @Expect(sub.waitCalls(1))
        // once 自动退订
        @Expect(registry.subscriberCount("evt"), 0)

        // 再次派发：不再调用
        registry.dispatch("evt", [], EventMode.EMIT, "emit-2")
        @Expect(sub.calls.size, 1)

        sub.close()
    }

    @TestCase
    func testPrependReversesOrder(): Unit {
        let registry = EventRegistry()
        let order = ArrayList<String>()
        let lock = Mutex()
        let sub1 = MemSubscriber("a") { _ =>
            synchronized(lock) { order.add("first") }
            JsonValue.Boolean(true)
        }
        let sub2 = MemSubscriber("b") { _ =>
            synchronized(lock) { order.add("second") }
            JsonValue.Boolean(true)
        }
        registry.subscribe("evt", "a", sub1.instance)
        registry.subscribe("evt", "b", sub2.instance, prepend: true)

        registry.dispatch("evt", [], EventMode.EMIT, "emit-1")
        @Expect(sub1.waitCalls(1))
        @Expect(sub2.waitCalls(1))
        // prepend 的 sub2 先被调用
        @Expect(order.size, 2)
        @Expect(order[0], "second")
        @Expect(order[1], "first")

        sub1.close()
        sub2.close()
    }
}

/**
 * 内存双工传输（与 plugin_runtime_test 的 MemoryDuplexTransport 同构，
 * 此处独立实现避免跨文件依赖）
 */
internal class MemSubscriberTransport <: Transport {
    private let outPipe: MemSubscriberPipe
    private let inPipe: MemSubscriberPipe
    private var closed: Bool = false
    private let lock: Mutex = Mutex()

    private init(outPipe: MemSubscriberPipe, inPipe: MemSubscriberPipe) {
        this.outPipe = outPipe
        this.inPipe = inPipe
    }

    public static func pair(): (MemSubscriberTransport, MemSubscriberTransport) {
        let ab = MemSubscriberPipe()
        let ba = MemSubscriberPipe()
        (MemSubscriberTransport(ab, ba), MemSubscriberTransport(ba, ab))
    }

    public func send(data: Array<Byte>): Unit {
        synchronized(this.lock) {
            if (!this.closed) {
                this.outPipe.write(data)
            }
        }
    }

    public func receive(): ?Array<Byte> {
        this.inPipe.read()
    }

    public func close(): Unit {
        synchronized(this.lock) {
            this.closed = true
            this.inPipe.close()
        }
    }

    public func isClosed(): Bool {
        synchronized(this.lock) {
            this.closed
        }
    }
}

internal class MemSubscriberPipe {
    private let buffer = ByteBuffer()
    private let lock: Mutex = Mutex()
    private let cond: Condition
    private var closed: Bool = false

    public init() {
        this.cond = synchronized(this.lock) {
            this.lock.condition()
        }
    }

    public func write(data: Array<Byte>): Unit {
        synchronized(this.lock) {
            this.buffer.write(data)
            this.cond.notifyAll()
        }
    }

    public func read(): ?Array<Byte> {
        synchronized(this.lock) {
            while (this.buffer.remainLength == 0 && !this.closed) {
                if (!this.cond.wait(timeout: Duration.second)) {
                    continue
                }
            }
            if (this.buffer.remainLength == 0) {
                return None
            }
            let size = this.buffer.remainLength
            let data = Array<Byte>(size, repeat: 0)
            this.buffer.read(data)
            Some(data)
        }
    }

    public func close(): Unit {
        synchronized(this.lock) {
            this.closed = true
            this.cond.notifyAll()
        }
    }
}
