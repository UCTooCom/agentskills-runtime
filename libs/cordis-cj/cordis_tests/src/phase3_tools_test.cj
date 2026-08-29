package ystyle::cordis_tests

import ystyle::cordis_core.*
import ystyle::cordis_plugin.*
import ystyle::jsonrpc.*
import jsonvalue.*
import stdx.encoding.json.stream.*
import stdx.serialization.serialization.*
import std.collection.{HashMap, ArrayList}
import std.sync.{Mutex, Condition}
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

/**
 * 第三阶段工具测试（docs/cordis-comparison.md §4 第三阶段）
 *
 * 覆盖：命名 Logger / timer（timeout/interval/throttle/debounce 可撤销）/
 *       effect 诊断树 getEffects / 事件 on<T> 类型安全重载。
 * 用 MemoryDuplexTransport + FakeHost 对接插件侧全链路。
 */

/**
 * 模拟宿主：注册 initialize/provide/log 处理器
 */
private class ToolsFakeHost {
    let client: JsonRpcClient
    let lock: Mutex = Mutex()
    let cond: Condition
    var logs: ArrayList<String> = ArrayList()   // "logger:level:message"
    var emits: ArrayList<String> = ArrayList()  // emit 事件名（emit<T> 测试用）

    init(client: JsonRpcClient) {
        this.client = client
        this.cond = synchronized(this.lock) {
            this.lock.condition()
        }
    }

    func waitCount(n: Int64): Bool {
        synchronized(this.lock) {
            var waited = 0
            while (this.logs.size < n && waited < 200) {
                this.cond.wait(timeout: 50 * Duration.millisecond)
                waited++
            }
            this.logs.size >= n
        }
    }

    func waitEmits(n: Int64): Bool {
        synchronized(this.lock) {
            var waited = 0
            while (this.emits.size < n && waited < 200) {
                this.cond.wait(timeout: 50 * Duration.millisecond)
                waited++
            }
            this.emits.size >= n
        }
    }

    func recordLog(entry: String): Unit {
        synchronized(this.lock) {
            this.logs.add(entry)
            this.cond.notifyAll()
        }
    }

    func recordEmit(entry: String): Unit {
        synchronized(this.lock) {
            this.emits.add(entry)
            this.cond.notifyAll()
        }
    }

    static func countOf(list: ArrayList<String>, target: String): Int64 {
        var n: Int64 = 0
        for (item in list) {
            if (item == target) {
                n++
            }
        }
        n
    }
}

private func setupToolsHost(): (ToolsFakeHost, ToolsDuplexTransport) {
    let (hostT, pluginT) = ToolsDuplexTransport.pair()
    let client = JsonRpcClient(hostT, framing: NewlineFraming())
    let host = ToolsFakeHost(client)

    client.registerRequestHandler(Methods.INITIALIZE, { req =>
        Some(JsonValue.fromObject(InitializeResult(true, HashMap<String, String>())))
    })
    client.registerRequestHandler(Methods.PROVIDE, { req =>
        Some(JsonValue.fromObject(ProvideResult("undo-1")))
    })
    // events/subscribe：返回订阅 id（on/on<T> 订阅需要）
    client.registerRequestHandler(Methods.EVENTS_SUBSCRIBE, { req =>
        Some(JsonValue.fromObject(SubscribeResult("sub-1")))
    })
    // events/emit + log 通知：合并到同一个 callback（setNotificationCallback 是覆盖语义，
    // 分开 set 会互相覆盖——P12 踩坑）
    client.setNotificationCallback({ notif =>
        if (notif.method == Methods.EVENTS_EMIT) {
            match (notif.params) {
                case Some(p) =>
                    try {
                        let ep = JsonValue.toObject<EmitParams>(p)
                        host.recordEmit("${ep.event}:${ep.args.size}:${ep.mode}")
                    } catch (e: Exception) {
                        host.recordEmit("parse-err:${e.message}")
                    }
                case None => host.recordEmit("no-params")
            }
        } else if (notif.method == Methods.LOG) {
            match (notif.params) {
                case Some(p) =>
                    match (JsonValue.toObject<LogParams>(p)) {
                        case lp =>
                            let name = match (lp.logger) {
                                case Some(n) => n
                                case None => "default"
                            }
                            host.recordLog("${name}:${lp.level}:${lp.message}")
                    }
                case None => ()
            }
        }
    })
    client.start()
    (host, pluginT)
}

/**
 * 事件参数 DTO（on<T> 类型安全测试）
 * 注意：数值字段用 Float64（jsonvalue 序列化 Number 为 float，跨进程一致）
 */
public class GreetPayload <: JsonDeserializable<GreetPayload> & JsonSerializable {
    public let name: String
    public let count: Float64
    public init(name: String, count: Float64) {
        this.name = name
        this.count = count
    }
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("name").writeValue(this.name)
        w.writeName("count").writeValue(this.count)
        w.endObject()
    }
    public static func fromJson(r: JsonReader): GreetPayload {
        r.startObject()
        var name: String = ""
        var count: Float64 = 0.0
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "name" => name = r.readValue<String>()
                case "count" => count = r.readValue<Float64>()
                case _ => r.skip()
            }
        }
        r.endObject()
        GreetPayload(name, count)
    }
}

@Test
class Phase3ToolsTest {

    @TestCase
    func testAutoUdsPathDetection(): Unit {
        // 传输自动检测（docs/cordis-comparison.md）：run() 内部用
        // std.env.getCommandLine() 获取进程命令行，无需用户从 main 传参。
        // 1. parseUdsArg：带 --uds 解析出路径；无则 None
        @Expect(PluginRuntime.parseUdsArg(["prog", "--uds", "/tmp/x.sock"]), Some("/tmp/x.sock"))
        @Expect(PluginRuntime.parseUdsArg(["prog", "-x"]).isNone())
        // 2. autoUdsPath：当前测试进程无 --uds 参数 → None（stdio 模式）
        //    有 --uds 的场景由 UdsModeEndToEndTest（真实宿主拉起 + getCommandLine）覆盖
        let detected = PluginRuntime.autoUdsPath()
        @Expect(detected.isNone())   // 测试进程命令行不含 --uds
    }

    @TestCase
    func testNamedLogger(): Unit {
        // ctx.logger("db") → 宿主收到 LogParams(logger="db", ...)
        let (host, pluginT) = setupToolsHost()
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                let logger = ctx.logger("db")
                logger.info("connected")
                ctx.log("info", "plain")
            })
        }
        @Expect(host.waitCount(2))
        @Expect(host.logs.contains("db:info:connected"))
        @Expect(host.logs.contains("default:info:plain"))
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testTimeoutFiresAndCancels(): Unit {
        // ctx.timeout：到期触发；撤销后不触发
        let (host, pluginT) = setupToolsHost()
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                ctx.timeout(200, { =>
                    host.recordLog("timeout-fired")
                })
                let cancel = ctx.timeout(200, { =>
                    host.recordLog("timeout-cancelled-fired")
                })
                cancel()
            })
        }
        // 等待触发（仅未撤销的那个）
        var fired = false
        for (i in 0..50) {
            if (host.logs.contains("timeout-fired")) {
                fired = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(fired)
        // 已撤销的不触发
        sleep(300 * Duration.millisecond)
        @Expect(!host.logs.contains("timeout-cancelled-fired"))
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testIntervalFiresAndCancels(): Unit {
        // ctx.interval：周期触发多次；撤销后停止
        let (host, pluginT) = setupToolsHost()
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                let cancel = ctx.interval(100, { =>
                    host.recordLog("tick")
                })
                ctx.timeout(500, { => cancel() })
            })
        }
        // 等待至少 2 次 tick
        var count = 0
        for (i in 0..50) {
            synchronized(host.lock) {
                count = ToolsFakeHost.countOf(host.logs, "tick")
            }
            if (count >= 2) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(count >= 2)
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testThrottleAndDebounce(): Unit {
        // throttle：间隔内合并；debounce：静默后执行最后一次
        let (host, pluginT) = setupToolsHost()
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                let throttled = ctx.throttle(300, { =>
                    host.recordLog("throttled")
                })
                // 连续调用 3 次（间隔内合并）
                throttled()
                throttled()
                throttled()
                let debounced = ctx.debounce(200, { =>
                    host.recordLog("debounced")
                })
                // 连续调用 2 次（只执行最后一次）
                debounced()
                debounced()
            })
        }
        // throttle：300ms 内 3 次调用只执行 1 次
        var throttledCount = 0
        for (i in 0..30) {
            synchronized(host.lock) {
                throttledCount = ToolsFakeHost.countOf(host.logs, "throttled")
            }
            if (throttledCount >= 1) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(throttledCount, 1)   // 合并：3 次调用 1 次执行
        // debounce：静默 200ms 后执行最后一次
        var debouncedSeen = false
        for (i in 0..30) {
            if (host.logs.contains("debounced")) {
                debouncedSeen = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(debouncedSeen)
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testGetEffectsDiagnostics(): Unit {
        // effect 带 label → getEffects 诊断树
        let (host, pluginT) = setupToolsHost()
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                ctx.effect({ => () }, "cleanup-temp")
                ctx.effect({ => () }, "cleanup-conn")
                let effects = ctx.getEffects()
                for (e in effects) {
                    host.recordLog("effect:${e}")
                }
            })
        }
        @Expect(host.waitCount(2))
        @Expect(host.logs.contains("effect:cleanup-temp"))
        @Expect(host.logs.contains("effect:cleanup-conn"))
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testOnTypedEvent(): Unit {
        // on<T> 类型安全：事件参数自动反序列化为 T
        let (host, pluginT) = setupToolsHost()
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                ctx.on<GreetPayload>("greet", { payload =>
                    host.recordLog("greet:${payload.name}:${payload.count}")
                })
            })
        }
        // 等订阅完成（sleep 确保 on 已注册）
        sleep(300 * Duration.millisecond)
        // 先验证 GreetPayload 序列化往返（on<T> 依赖）
        let roundtripOk = try {
            let back = JsonValue.toObject<GreetPayload>(JsonValue.fromObject(GreetPayload("t", 1.0)))
            back.name == "t" && back.count == 1.0
        } catch (e: Exception) {
            false
        }
        @Expect(roundtripOk)
        let payload = GreetPayload("world", 42.0)
        let result = host.client.call<JsonValue, JsonValue>(Methods.EVENTS_DISPATCH,
            params: Some(JsonValue.fromObject(DispatchParams("greet",
                [JsonValue.fromObject(payload)], "emit-1"))))
        match (result) {
            case Ok(v) => host.recordLog("dispatch-ok:${v}")
            case Err(e) => host.recordLog("dispatch-err:${e}")
        }
        // 分步验证：dispatch 是否成功 + listener 是否触发
        var dispatchSucceeded = false
        var dispatchErrMsg = ""
        var greetSeen = false
        for (i in 0..50) {
            synchronized(host.lock) {
                for (l in host.logs) {
                    if (l.startsWith("dispatch-ok:")) {
                        dispatchSucceeded = true
                    }
                    if (l.startsWith("dispatch-err:")) {
                        dispatchErrMsg = l
                    }
                    if (l.startsWith("greet:world:42")) {
                        greetSeen = true
                    }
                }
            }
            if (dispatchSucceeded && greetSeen) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        if (!dispatchSucceeded && dispatchErrMsg != "") {
            @Fail("dispatch failed: ${dispatchErrMsg}")
        }
        @Expect(dispatchSucceeded)   // 宿主 → 插件 dispatch 成功
        @Expect(greetSeen)           // 插件 on<T> listener 触发
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testEmitTyped(): Unit {
        // emit<T> 发布侧类型安全：参数自动序列化为 JsonValue 传给宿主
        let (host, pluginT) = setupToolsHost()
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                // 对照：非泛型 emit（已知链路）+ 泛型 emit<T>（参数自动序列化）
                ctx.emit("greet-plain", [JsonValue.String("x")])
                ctx.emit<GreetPayload>("greet", [GreetPayload("alice", 1.0)])
                ctx.emit<GreetPayload>("greet", [GreetPayload("bob", 2.0)])
            })
        }
        // 断言：非泛型 emit + 泛型 emit<T> 通知均到达宿主（参数自动序列化）
        var plainOk = false
        var typedOk = false
        for (i in 0..100) {
            synchronized(host.lock) {
                if (host.emits.contains("greet-plain:1:emit")) { plainOk = true }
                if (host.emits.contains("greet:1:emit")) { typedOk = true }
            }
            if (plainOk && typedOk) { break }
            sleep(50 * Duration.millisecond)
        }
        if (!plainOk) {
            let allEmits = synchronized(host.lock) { ArrayList<String>(host.emits) }
            @Fail("plain emit not received; emits=${allEmits}")
        }
        @Expect(plainOk)
        @Expect(typedOk)
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testAsyncEffectWaitedOnDispose(): Unit {
        // async effect：disposeAll 等待异步 disposer 完成（同步+异步+服务）
        let registry = ServiceRegistry()
        let order = ArrayList<String>()
        let lock = Mutex()
        // 同步效果
        registry.effect({ =>
            synchronized(lock) { order.add("sync-1") }
        }, "sync-1")
        // 异步效果：延迟 200ms 完成
        registry.effectAsync({ =>
            spawn {
                sleep(200 * Duration.millisecond)
                synchronized(lock) { order.add("async-2") }
            }
        }, label: "async-2")
        // 服务 disposer
        registry.register("undo-1", { =>
            synchronized(lock) { order.add("service-3") }
        })
        @Expect(registry.effectCount, 2)
        @Expect(registry.serviceCount, 1)
        registry.disposeAll()
        @Expect(registry.effectCount, 0)
        @Expect(registry.serviceCount, 0)
        // 全部执行（异步被等待）：逆序效果（async-2 → sync-1）+ 服务最后
        let snapshot = synchronized(lock) { ArrayList<String>(order) }
        @Expect(snapshot.size, 3)
        // 全部执行；异步效果（async-2）被等待完成（disposeAll 不提前返回）
        @Expect(snapshot.contains("sync-1"))
        @Expect(snapshot.contains("async-2"))
        @Expect(snapshot.contains("service-3"))
    }

    @TestCase
    func testSerialTyped(): Unit {
        // serial<T> 发布侧类型安全：参数自动序列化 + 宿主聚合结果返回
        let (host, pluginT) = setupToolsHost()
        // 宿主请求式 emit：返回预设 bail 值
        host.client.registerRequestHandler(Methods.EVENTS_EMIT, { req =>
            match (req.params) {
                case Some(p) =>
                    match (JsonValue.toObject<EmitParams>(p)) {
                        case ep =>
                            synchronized(host.lock) {
                                host.emits.add("${ep.event}:${ep.args.size}:${ep.mode}")
                                host.cond.notifyAll()
                            }
                            Some(JsonValue.String("bailed"))
                    }
                case None => Some(JsonValue.Null)
            }
        })
        spawn {
            PluginRuntime.run(pluginT, "tools-plugin", [], [], { ctx =>
                let result = ctx.serial<GreetPayload>("greet", [GreetPayload("carol", 3.0)])
                match (result) {
                    case Some(v) =>
                        match (v) {
                            case JsonValue.String(s) => host.recordLog("serial-result:${s}")
                            case _ => host.recordLog("serial-unexpected")
                        }
                    case None => host.recordLog("serial-none")
                }
            })
        }
        var ok = false
        for (i in 0..50) {
            synchronized(host.lock) {
                if (host.emits.contains("greet:1:serial") && host.logs.contains("serial-result:bailed")) {
                    ok = true
                }
            }
            if (ok) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(ok)
        host.client.close()
        pluginT.close()
    }
}

/**
 * 内存双工传输（复用同构实现）
 */
internal class ToolsDuplexTransport <: Transport {
    private let outPipe: ToolsPipe
    private let inPipe: ToolsPipe
    private var closed: Bool = false
    private let lock: Mutex = Mutex()

    private init(outPipe: ToolsPipe, inPipe: ToolsPipe) {
        this.outPipe = outPipe
        this.inPipe = inPipe
    }

    public static func pair(): (ToolsDuplexTransport, ToolsDuplexTransport) {
        let ab = ToolsPipe()
        let ba = ToolsPipe()
        (ToolsDuplexTransport(ab, ba), ToolsDuplexTransport(ba, ab))
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

internal class ToolsPipe {
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
