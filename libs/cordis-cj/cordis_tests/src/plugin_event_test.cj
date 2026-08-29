package ystyle::cordis_tests

import ystyle::cordis_plugin.*
import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import stdx.encoding.json.stream.*
import std.collection.{HashMap, ArrayList}
import std.sync.{Mutex, Condition}
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

/**
 * 插件侧事件 API 测试（docs/design-events.md §6）
 *
 * 用 FakeHost 模拟宿主（处理 subscribe/emit/dispatch），
 * 验证 ctx.on / ctx.emit 全链路：
 * 1. 插件 on("evt", listener) → 宿主收到 subscribe，返回订阅 id
 * 2. 插件 emit("evt", args) → 宿主收到 emit 通知
 * 3. 宿主向插件发 events/dispatch → 插件 listener 被调用
 */

/**
 * 模拟宿主：注册 initialize/provide/subscribe/emit 处理器
 * 维护事件订阅，emit 到达时向订阅者（测试中直接调用注入的 dispatch 函数）
 */
private class EventFakeHost {
    let client: JsonRpcClient
    let lock: Mutex = Mutex()
    let cond: Condition
    var provided: ArrayList<String> = ArrayList()
    var subscribed: ArrayList<String> = ArrayList()
    var emitted: ArrayList<String> = ArrayList()
    var dispatched: ArrayList<String> = ArrayList()
    var dispatchFn: ?(String, Array<JsonValue>) -> Unit = None
    // 请求式 emit 的分发函数（serial/bail/waterfall 用）：接收 EmitParams，返回聚合结果
    var emitRequestFn: ?(EmitParams) -> ?JsonValue = None
    // waterfall 洋葱 next：EVENTS_NEXT 请求的响应函数（emitId -> 结果）
    var nextFn: ?(String) -> ?JsonValue = None
    // 收到的 events/next emitId 记录
    var nextEmitIds: ArrayList<String> = ArrayList()
    // 订阅选项记录（once/prepend）
    var onceFlags: ArrayList<Bool> = ArrayList()
    var prependFlags: ArrayList<Bool> = ArrayList()

    init(client: JsonRpcClient) {
        this.client = client
        this.cond = synchronized(this.lock) {
            this.lock.condition()
        }
    }

    func record(list: ArrayList<String>, value: String): Unit {
        synchronized(this.lock) {
            list.add(value)
            this.cond.notifyAll()
        }
    }

    func waitCount(list: ArrayList<String>, n: Int64): Bool {
        synchronized(this.lock) {
            var waited = 0
            while (list.size < n && waited < 100) {
                this.cond.wait(timeout: 50 * Duration.millisecond)
                waited++
            }
            list.size >= n
        }
    }
}

private func setupEventHost(): (EventFakeHost, ExpEventDuplexTransport) {
    let (hostT, pluginT) = ExpEventDuplexTransport.pair()
    let client = JsonRpcClient(hostT, framing: NewlineFraming())
    let host = EventFakeHost(client)

    client.registerRequestHandler(Methods.INITIALIZE, { req =>
        Some(JsonValue.fromObject(InitializeResult(true, HashMap<String, String>())))
    })
    client.registerRequestHandler(Methods.PROVIDE, { req =>
        match (req.params) {
            case Some(p) =>
                match (p["key"]) {
                    case Some(JsonValue.String(k)) =>
                        synchronized(host.lock) {
                            host.provided.add(k)
                            host.cond.notifyAll()
                        }
                    case _ => ()
                }
            case None => ()
        }
        Some(JsonValue.fromObject(ProvideResult("undo-${host.provided.size}")))
    })
    // events/subscribe：记录并返回订阅 id
    client.registerRequestHandler(Methods.EVENTS_SUBSCRIBE, { req =>
        match (req.params) {
            case Some(p) =>
                match (JsonValue.toObject<SubscribeParams>(p)) {
                    case params =>
                        synchronized(host.lock) {
                            host.subscribed.add(params.event)
                            host.onceFlags.add(params.once)
                            host.prependFlags.add(params.prepend)
                            host.cond.notifyAll()
                        }
                        Some(JsonValue.fromObject(SubscribeResult("sub-${host.subscribed.size}")))
                }
            case None => Some(JsonValue.fromObject(SubscribeResult("sub-0")))
        }
    })
    // events/emit：记录并调用注入的 dispatch（模拟宿主扇出）
    client.setNotificationCallback({ notif =>
        if (notif.method == Methods.EVENTS_EMIT) {
            match (notif.params) {
                case Some(p) =>
                    match (JsonValue.toObject<EmitParams>(p)) {
                        case params =>
                            synchronized(host.lock) {
                                host.emitted.add(params.event)
                                host.cond.notifyAll()
                            }
                            match (host.dispatchFn) {
                                case Some(fn) => fn(params.event, params.args)
                                case None => ()
                            }
                    }
                case None => ()
            }
        }
    })
    // events/emit 请求（parallel/serial/bail/waterfall）：按注入的请求分发函数处理
    client.registerRequestHandler(Methods.EVENTS_EMIT, { req =>
        match (req.params) {
            case Some(p) =>
                match (JsonValue.toObject<EmitParams>(p)) {
                    case params =>
                        synchronized(host.lock) {
                            host.emitted.add(params.event)
                            host.cond.notifyAll()
                        }
                        match (host.emitRequestFn) {
                            case Some(fn) => fn(params)
                            case None => Some(JsonValue.Null)
                        }
                }
            case None => Some(JsonValue.Null)
        }
    })
    // events/next（waterfall 洋葱 next）：记录 emitId，按注入的 nextFn 响应
    client.registerRequestHandler(Methods.EVENTS_NEXT, { req =>
        match (req.params) {
            case Some(p) =>
                match (JsonValue.toObject<NextParams>(p)) {
                    case params =>
                        synchronized(host.lock) {
                            host.nextEmitIds.add(params.emitId)
                            host.cond.notifyAll()
                        }
                        match (host.nextFn) {
                            case Some(fn) =>
                                match (fn(params.emitId)) {
                                    case Some(v) => Some(v)
                                    case None => Some(JsonValue.Null)
                                }
                            case None => Some(JsonValue.Null)
                        }
                }
            case None => Some(JsonValue.Null)
        }
    })
    client.start()
    (host, pluginT)
}

@Test
class PluginEventTest {

    @TestCase
    func testOnSubscribesToHost(): Unit {
        // 插件 ctx.on → 宿主收到 subscribe 请求
        let (host, pluginT) = setupEventHost()
        spawn {
            PluginRuntime.run(pluginT, "evt-plugin", [], [], { ctx =>
                let subId = ctx.on("stats/report", { args =>
                    host.record(host.dispatched, "listener-called")
                })
                host.record(host.subscribed, "subId=${subId}")
            })
        }
        // 等待 subscribe 完成（subscribed 有 "stats/report" 且 subId 记录）
        @Expect(host.waitCount(host.subscribed, 1))
        @Expect(host.subscribed[0], "stats/report")
        // subId 记录在 subscribed 列表第二个元素
        @Expect(host.waitCount(host.subscribed, 2))
        @Expect(host.subscribed[1].startsWith("subId=sub-"))
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testEmitDispatchesToListener(): Unit {
        // 插件 emit → 宿主扇出（测试中注入 dispatchFn）→ 插件 listener 被调用
        let (host, pluginT) = setupEventHost()
        // 宿主侧注入 dispatch：向插件发 events/dispatch 请求
        host.dispatchFn = { event, args =>
            // 通过 pluginT 对端（插件 server）发 dispatch
            // 注：host.client 是宿主连接，pluginT 是插件端——用 host.client 直接调用即可
            let result = host.client.call<JsonValue, JsonValue>(Methods.EVENTS_DISPATCH,
                params: Some(JsonValue.fromObject(DispatchParams(event, args, "emit-1"))))
            match (result) {
                case Ok(_) => ()
                case Err(e) => host.record(host.dispatched, "dispatch-err:${e}")
            }
        }
        spawn {
            PluginRuntime.run(pluginT, "evt-plugin2", [], [], { ctx =>
                ctx.on("greet", { args =>
                    let name = match (args[0]) { case JsonValue.String(s) => s; case _ => "?" }
                    host.record(host.dispatched, "greeted:${name}")
                })
                // 发布事件
                ctx.emit("greet", [JsonValue.String("world")])
            })
        }
        // 等待 listener 被调用（emit → host.dispatchFn → events/dispatch → listener）
        @Expect(host.waitCount(host.dispatched, 1))
        @Expect(host.dispatched[0], "greeted:world")
        // 宿主确实收到了 emit
        @Expect(host.emitted.size >= 1)
        @Expect(host.emitted[0], "greet")
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testSerialBailReturnsFirstBailValue(): Unit {
        // serial 模式协议往返：插件 serial() → 宿主 EVENTS_EMIT 请求（mode=serial）
        // → 返回聚合结果 → 插件收到。宿主响应由 emitRequestFn 预设
        // （真实聚合逻辑由 EventDispatchModeTest 覆盖）
        let (host, pluginT) = setupEventHost()
        host.emitRequestFn = { params =>
            // 验证 mode 正确传递
            host.record(host.dispatched, "mode:${params.mode}")
            Some(JsonValue.String("found"))
        }
        spawn {
            PluginRuntime.run(pluginT, "evt-serial", [], [], { ctx =>
                let result = ctx.serial("serial-evt", [JsonValue.Number(1.0)])
                match (result) {
                    case Some(v) =>
                        match (v) {
                            case JsonValue.String(s) => host.record(host.dispatched, "serial:${s}")
                            case _ => host.record(host.dispatched, "serial:unexpected")
                        }
                    case None => host.record(host.dispatched, "serial:none")
                }
            })
        }
        // 宿主收到 mode=serial 请求，插件拿到 "found"
        @Expect(host.waitCount(host.dispatched, 2))
        @Expect(host.dispatched[0], "mode:serial")
        @Expect(host.dispatched[1], "serial:found")
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testWaterfallModePassesThrough(): Unit {
        // waterfall 模式协议往返：插件 waterfall() → 宿主请求（mode=waterfall）→ 返回结果
        let (host, pluginT) = setupEventHost()
        host.emitRequestFn = { params =>
            host.record(host.dispatched, "mode:${params.mode}")
            Some(JsonValue.String("got:x"))
        }
        spawn {
            PluginRuntime.run(pluginT, "evt-waterfall", [], [], { ctx =>
                let result = ctx.waterfall("wf-evt", [JsonValue.Number(1.0)])
                match (result) {
                    case Some(v) =>
                        match (v) {
                            case JsonValue.String(s) => host.record(host.dispatched, "wf:${s}")
                            case _ => host.record(host.dispatched, "wf:unexpected")
                        }
                    case None => host.record(host.dispatched, "wf:none")
                }
            })
        }
        @Expect(host.waitCount(host.dispatched, 2))
        @Expect(host.dispatched[0], "mode:waterfall")
        @Expect(host.dispatched[1], "wf:got:x")
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testOnWaterfallNextRoundTrip(): Unit {
        // 完整洋葱 next 协议往返（docs/design-events.md §7）：
        // 宿主 events/dispatch(nextAllowed=true) → 插件 onWaterfall listener
        // → listener 调 next() → 插件发 events/next → 宿主响应
        // → listener 返回结果 → dispatch 响应回宿主
        let (host, pluginT) = setupEventHost()
        // 宿主侧 events/next 响应：推进链（模拟链中下一订阅者 veto "inner"）
        host.nextFn = { emitId =>
            host.record(host.dispatched, "next:${emitId}")
            Some(JsonValue.String("inner"))
        }
        host.dispatchFn = { event, args =>
            // 宿主向插件发 events/dispatch（waterfall 模式 nextAllowed=true）
            let result = host.client.call<JsonValue, JsonValue>(Methods.EVENTS_DISPATCH,
                params: Some(JsonValue.fromObject(DispatchParams(event, args, "emit-1",
                    mode: EventMode.WATERFALL, nextAllowed: true))))
            match (result) {
                case Ok(v) => host.record(host.dispatched, "dispatch-result:${v}")
                case Err(e) => host.record(host.dispatched, "dispatch-err:${e}")
            }
        }
        spawn {
            PluginRuntime.run(pluginT, "evt-onion", [], [], { ctx =>
                ctx.onWaterfall("onion-evt", { args, next =>
                    // 洋葱：调 next() 推进链，取回结果（模拟 veto 短路时用返回值）
                    let inner = next()
                    match (inner) {
                        case Some(v) =>
                            host.record(host.dispatched, "inner:${v}")
                            Some(v)
                        case None =>
                            host.record(host.dispatched, "inner:none")
                            None
                    }
                })
                // 触发一次 dispatch（宿主侧 dispatchFn 直接调 events/dispatch）
                host.record(host.subscribed, "setup-done")
            })
        }
        // 等待订阅完成（onWaterfall 注册 + setup-done），再手动触发 dispatch
        @Expect(host.waitCount(host.subscribed, 2))
        // 触发宿主扇出：模拟事件 emit → dispatch 到插件
        match (host.dispatchFn) {
            case Some(fn) => fn("onion-evt", [JsonValue.Number(1.0)])
            case None => @Fail("dispatchFn should be set")
        }
        // 断言：插件收到 dispatch → listener 调 next → 宿主 nextFn 响应 → listener 返回
        @Expect(host.waitCount(host.dispatched, 3))
        @Expect(host.dispatched[0], "next:emit-1")
        @Expect(host.dispatched[1].contains("inner"))
        @Expect(host.dispatched[2].startsWith("dispatch-result:"))
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testOnceAndPrependSubscriptionOptions(): Unit {
        // once：订阅标记传递；prepend：订阅标记传递（真实退订逻辑由 EventDispatchModeTest 覆盖）
        let (host, pluginT) = setupEventHost()
        spawn {
            PluginRuntime.run(pluginT, "evt-options", [], [], { ctx =>
                ctx.once("once-evt", { args =>
                    host.record(host.dispatched, "once-called")
                })
                ctx.onVal("prepend-evt", { args => None }, prepend: true)
            })
        }
        // 等待两个订阅完成
        @Expect(host.waitCount(host.subscribed, 2))
        @Expect(host.onceFlags.size >= 1)
        @Expect(host.onceFlags[0])
        @Expect(host.prependFlags.size >= 2)
        @Expect(host.prependFlags[1])
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testParallelDispatchesToAll(): Unit {
        // parallel 模式：插件 parallel() 以通知发出（mode=parallel，fire-and-forget）
        // 宿主 notificationCallback 记录；插件侧不等待
        let (host, pluginT) = setupEventHost()
        host.dispatchFn = { event, args =>
            host.record(host.emitted, "dispatched:${event}")
        }
        spawn {
            PluginRuntime.run(pluginT, "evt-parallel", [], [], { ctx =>
                ctx.parallel("par-evt", [JsonValue.Number(1.0)])
                host.record(host.dispatched, "parallel-done")
            })
        }
        // 宿主收到 parallel 通知
        @Expect(host.waitCount(host.emitted, 1))
        @Expect(host.emitted[0], "par-evt")
        // 插件侧 parallel() 不阻塞（立即返回后标记 done）
        @Expect(host.waitCount(host.dispatched, 1))
        @Expect(host.dispatched[0], "parallel-done")
        host.client.close()
        pluginT.close()
    }
}

/**
 * 实验用内存双工管道（独立实现）
 */
internal class ExpEventDuplexTransport <: Transport {
    private let outPipe: ExpEventPipe
    private let inPipe: ExpEventPipe
    private var closed: Bool = false
    private let lock: Mutex = Mutex()

    private init(outPipe: ExpEventPipe, inPipe: ExpEventPipe) {
        this.outPipe = outPipe
        this.inPipe = inPipe
    }

    public static func pair(): (ExpEventDuplexTransport, ExpEventDuplexTransport) {
        let ab = ExpEventPipe()
        let ba = ExpEventPipe()
        (ExpEventDuplexTransport(ab, ba), ExpEventDuplexTransport(ba, ab))
    }

    public func send(data: Array<Byte>): Unit {
        synchronized(this.lock) {
            if (this.closed) {
                return
            }
        }
        this.outPipe.write(data)
    }

    public func receive(): ?Array<Byte> {
        this.inPipe.read()
    }

    public func close(): Unit {
        synchronized(this.lock) {
            if (this.closed) {
                return
            }
            this.closed = true
        }
        this.inPipe.close()
    }

    public func isClosed(): Bool {
        synchronized(this.lock) {
            this.closed
        }
    }
}

internal class ExpEventPipe {
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

    public func isClosed(): Bool {
        synchronized(this.lock) {
            this.closed
        }
    }
}
