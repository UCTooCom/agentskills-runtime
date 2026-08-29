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
 * 实验：泛型 registerHandler 全链路验证（feat/generic-handler 分支）
 *
 * 服务端用 registerHandler<T, R> 注册（参数 Array<T> 自动反序列化、
 * 返回值 R 自动序列化），宿主 invoke 转发 JsonValue，全链路类型转换正确。
 */

// 自定义 DTO：add 服务参数
public class AddRequest <: JsonSerializable & JsonDeserializable<AddRequest> {
    public let a: Int64
    public let b: Int64

    public init(a: Int64, b: Int64) {
        this.a = a
        this.b = b
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("a").writeValue(this.a)
        w.writeName("b").writeValue(this.b)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): AddRequest {
        r.startObject()
        var a: ?Int64 = None
        var b: ?Int64 = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "a" => a = r.readValue<Int64>()
                case "b" => b = r.readValue<Int64>()
                case _ => r.skip()
            }
        }
        r.endObject()
        AddRequest(a.getOrThrow(), b.getOrThrow())
    }
}

/**
 * 模拟宿主：注册 initialize/provide/invoke 处理器
 * invoke 语义：把 params 原样回传（宿主转发到插件，插件响应）
 */
private class HandlerFakeHost {
    let client: JsonRpcClient
    let lock: Mutex = Mutex()
    let cond: Condition
    var provided: ArrayList<String> = ArrayList()
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
}

private func setupHandlerHost(): (HandlerFakeHost, ExpHandlerDuplexTransport) {
    let (hostT, pluginT) = ExpHandlerDuplexTransport.pair()
    let client = JsonRpcClient(hostT, framing: NewlineFraming())
    let host = HandlerFakeHost(client)

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
    // invoke：插件响应由插件侧 handleInvoke 返回（宿主只需转发请求，这里无需特殊处理）
    client.start()
    (host, pluginT)
}

@Test
class GenericHandlerExperiment {

    @TestCase
    func testPrimitiveHandler(): Unit {
        // 插件用泛型 registerHandler 注册：Int64 参数 → String 返回
        let (host, pluginT) = setupHandlerHost()
        spawn {
            PluginRuntime.run(pluginT, "h-plugin", [], ["svc"], { ctx =>
                ctx.registerHandler<Int64, String>("svc", { method, args =>
                    "sum=${args[0]}"
                })
                host.record("registered")
            })
        }
        @Expect(host.waitResult("registered"))
        // 宿主 invoke：传 [5]，插件 handler 收到 Array<Int64>，返回 "sum=5"
        let result = host.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("svc", "calc",
                [JsonValue.Number(5.0)]))))
        match (result) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "sum=5")
                    case _ => @Fail("expected string result")
                }
            case Err(e) => @Fail("invoke failed: ${e}")
        }
        host.client.close()
        pluginT.close()
    }

    @TestCase
    func testCustomDtoHandler(): Unit {
        // 插件用泛型 registerHandler 注册：AddRequest 参数 → Int64 返回
        let (host, pluginT) = setupHandlerHost()
        spawn {
            PluginRuntime.run(pluginT, "h-plugin2", [], ["calc"], { ctx =>
                ctx.registerHandler<AddRequest, Int64>("calc", { method, args =>
                    args[0].a + args[0].b
                })
                host.record("registered")
            })
        }
        @Expect(host.waitResult("registered"))
        // 宿主 invoke：传 {"a":3,"b":4}，插件 handler 收到 AddRequest，返回 7
        let reqMap = HashMap<String, JsonValue>()
        reqMap["a"] = JsonValue.Number(3.0)
        reqMap["b"] = JsonValue.Number(4.0)
        let reqJson = JsonValue.Map(reqMap)
        let result = host.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("calc", "add", [reqJson]))))
        match (result) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 7.0)
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("invoke failed: ${e}")
        }
        host.client.close()
        pluginT.close()
    }
}

/**
 * 实验用内存双工管道（独立实现）
 */
internal class ExpHandlerDuplexTransport <: Transport {
    private let outPipe: ExpHandlerPipe
    private let inPipe: ExpHandlerPipe
    private var closed: Bool = false
    private let lock: Mutex = Mutex()

    private init(outPipe: ExpHandlerPipe, inPipe: ExpHandlerPipe) {
        this.outPipe = outPipe
        this.inPipe = inPipe
    }

    public static func pair(): (ExpHandlerDuplexTransport, ExpHandlerDuplexTransport) {
        let ab = ExpHandlerPipe()
        let ba = ExpHandlerPipe()
        (ExpHandlerDuplexTransport(ab, ba), ExpHandlerDuplexTransport(ba, ab))
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

internal class ExpHandlerPipe {
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
