package ystyle::cordis_tests

import ystyle::cordis_plugin.*
import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import stdx.encoding.json.stream.*
import std.collection.{HashMap, ArrayList, map, collectArray}
import std.sync.{Mutex, Condition}
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

/**
 * 实验：泛型 invoke 全链路验证（feat/generic-invoke 分支）
 *
 * 验证 PluginContext.invoke<T, R> 泛型重载：
 *   - T <: JsonSerializable（参数自动序列化）
 *   - R <: JsonDeserializable<R>（返回值自动反序列化）
 * 通过 ExpMemoryDuplexTransport + FakeHost 走真实 RPC 链路。
 */

// 自定义可序列化类型（模拟真实业务 DTO）
public class GreetRequest <: JsonSerializable & JsonDeserializable<GreetRequest> {
    public let name: String
    public let count: Int64

    public init(name: String, count: Int64) {
        this.name = name
        this.count = count
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("name").writeValue(this.name)
        w.writeName("count").writeValue(this.count)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): GreetRequest {
        r.startObject()
        var name: ?String = None
        var count: ?Int64 = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "name" => name = r.readValue<String>()
                case "count" => count = r.readValue<Int64>()
                case _ => r.skip()
            }
        }
        r.endObject()
        GreetRequest(name.getOrThrow(), count.getOrThrow())
    }
}

/**
 * 模拟宿主：注册 initialize/provide/invoke 处理器
 * invoke 语义：echo（返回第一个参数）/ add（两个数字相加）
 */
private class GenericFakeHost {
    let client: JsonRpcClient
    let lock: Mutex = Mutex()
    let cond: Condition
    var provided: ArrayList<String> = ArrayList()
    // 插件 handler 写入的结果（跨线程收集）
    var results: ArrayList<String> = ArrayList()

    init(client: JsonRpcClient) {
        this.client = client
        this.cond = synchronized(this.lock) {
            this.lock.condition()
        }
    }

    func record(result: String): Unit {
        synchronized(this.lock) {
            this.results.add(result)
            this.cond.notifyAll()
        }
    }

    func waitResult(expected: String): Bool {
        synchronized(this.lock) {
            var waited = 0
            while (this.results.size == 0 && waited < 100) {
                this.cond.wait(timeout: 50 * Duration.millisecond)
                waited++
            }
            this.results.size > 0 && this.results[0] == expected
        }
    }

    func waitFor(predicate: () -> Bool): Bool {
        synchronized(this.lock) {
            var waited = 0
            while (!predicate() && waited < 100) {
                this.cond.wait(timeout: 50 * Duration.millisecond)
                waited++
            }
            predicate()
        }
    }
}

private func setupGenericHost(): (GenericFakeHost, ExpMemoryDuplexTransport) {
    let (hostT, pluginT) = ExpMemoryDuplexTransport.pair()
    let client = JsonRpcClient(hostT, framing: NewlineFraming())
    let host = GenericFakeHost(client)

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
    // invoke：echo 返回第一个参数；add 两个数字相加
    client.registerRequestHandler(Methods.INVOKE, { req =>
        match (req.params) {
            case Some(p) =>
                match (JsonValue.toObject<InvokeParams>(p)) {
                    case params =>
                        if (params.method == "echo" && params.args.size > 0) {
                            Some(params.args[0])
                        } else if (params.method == "add" && params.args.size >= 2) {
                            let a = match (params.args[0]) { case JsonValue.Number(n) => n; case _ => 0.0 }
                            let b = match (params.args[1]) { case JsonValue.Number(n) => n; case _ => 0.0 }
                            Some(JsonValue.Number(a + b))
                        } else {
                            Some(JsonValue.Null)
                        }
                }
            case None => None
        }
    })
    client.start()
    (host, pluginT)
}

@Test
class GenericInvokeExperiment {

    @TestCase
    func testPrimitiveEchoViaRpc(): Unit {
        // 泛型 invoke：Int64 参数 → String 返回（echo 语义）
        let (host, pluginT) = setupGenericHost()
        spawn {
            PluginRuntime.run(pluginT, "gen-plugin", [], ["svc"], { ctx =>
                let resultStr = ctx.invoke<Int64, String>("svc", "echo", [42])
                host.record(resultStr)
            })
        }
        let ok = host.waitFor({ => host.provided.size >= 1 })
        @Expect(ok)
        @Expect(host.waitResult("42"))
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testAddViaRpc(): Unit {
        // 泛型 invoke：Int64 参数 → Int64 返回（add 计算）
        let (host, pluginT) = setupGenericHost()
        spawn {
            PluginRuntime.run(pluginT, "gen-plugin2", [], ["svc"], { ctx =>
                let resultInt = ctx.invoke<Int64, Int64>("svc", "add", [3, 4])
                host.record("${resultInt}")
            })
        }
        let ok = host.waitFor({ => host.provided.size >= 1 })
        @Expect(ok)
        @Expect(host.waitResult("7"))
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testCustomDtoViaRpc(): Unit {
        // 泛型 invoke：自定义 DTO 参数 + 返回
        let (host, pluginT) = setupGenericHost()
        spawn {
            PluginRuntime.run(pluginT, "gen-plugin3", [], ["svc"], { ctx =>
                let req = GreetRequest("world", 3)
                let resp = ctx.invoke<GreetRequest, GreetRequest>("svc", "echo", [req])
                host.record("${resp.name}:${resp.count}")
            })
        }
        let ok = host.waitFor({ => host.provided.size >= 1 })
        @Expect(ok)
        @Expect(host.waitResult("world:3"))
        host.client.close()
        pluginT.close()
    }
}

/**
 * 实验用内存双工管道（独立实现，避免与 plugin_runtime_test 的类冲突）
 */
internal class ExpMemoryDuplexTransport <: Transport {
    private let outPipe: ExpMemoryPipe
    private let inPipe: ExpMemoryPipe
    private var closed: Bool = false
    private let lock: Mutex = Mutex()

    private init(outPipe: ExpMemoryPipe, inPipe: ExpMemoryPipe) {
        this.outPipe = outPipe
        this.inPipe = inPipe
    }

    public static func pair(): (ExpMemoryDuplexTransport, ExpMemoryDuplexTransport) {
        let ab = ExpMemoryPipe()
        let ba = ExpMemoryPipe()
        (ExpMemoryDuplexTransport(ab, ba), ExpMemoryDuplexTransport(ba, ab))
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

internal class ExpMemoryPipe {
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
