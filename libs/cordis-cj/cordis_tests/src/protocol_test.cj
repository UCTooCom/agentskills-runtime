package ystyle::cordis_tests

import ystyle::cordis_core.*
import jsonvalue.*
import stdx.encoding.json.stream.*
import std.io.ByteBuffer
import std.collection.HashMap
import std.unittest.*
import std.unittest.testmacro.*

// 往返测试：对象 → JsonWriter 序列化 → JsonReader 反序列化（json.stream 直通，不经 jsonvalue）
private func roundTrip<T>(obj: T): T where T <: JsonSerializable & JsonDeserializable<T> {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    obj.toJson(w)
    w.flush()
    buf.flush()
    let r = JsonReader(buf)
    T.fromJson(r)
}

// 序列化为 JSON 字符串（用于形状断言）
private func toJsonString<T>(obj: T): String where T <: JsonSerializable {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    obj.toJson(w)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}

@Test
class MethodsTest {
    @TestCase
    func testMethodNames(): Unit {
        @Expect(Methods.INITIALIZE, "initialize")
        @Expect(Methods.INITIALIZED, "initialized")
        @Expect(Methods.PROVIDE, "provide")
        @Expect(Methods.DISPOSE, "dispose")
        @Expect(Methods.NOTIFY, "notify")
        @Expect(Methods.LOG, "log")
        @Expect(Methods.INVOKE, "invoke")
        @Expect(Methods.PING, "ping")
        @Expect(Methods.PONG, "pong")
    }

    @TestCase
    func testNotifyKinds(): Unit {
        @Expect(NotifyKind.DEPENDENCY_LOST, "dependency-lost")
        @Expect(NotifyKind.PROVIDER_CHANGED, "provider-changed")
    }
}

@Test
class InitializeParamsTest {
    @TestCase
    func testRoundTripBasic(): Unit {
        let original = InitializeParams("plugin-a", ["db"], ["api"])
        let restored = roundTrip(original)
        @Expect(restored.id, "plugin-a")
        @Expect(restored.inject, ["db"])
        @Expect(restored.provide, ["api"])
        @Expect(restored.config.isNone())
    }

    @TestCase
    func testRoundTripWithConfig(): Unit {
        let cfg = HashMap<String, JsonValue>()
        cfg["host"] = JsonValue.String("127.0.0.1")
        cfg["port"] = JsonValue.Number(5432.0)
        let original = InitializeParams("plugin-a", ["db"], [], config: Some(cfg))
        let restored = roundTrip(original)
        @Expect(restored.config.isSome())
        if (let Some(c) <- restored.config) {
            match (c["host"]) {
                case JsonValue.String(s) => @Expect(s, "127.0.0.1")
                case _ => @Fail("expected string host")
            }
            match (c["port"]) {
                case JsonValue.Number(n) => @Expect(n, 5432.0)
                case _ => @Fail("expected number port")
            }
        }
    }

    @TestCase
    func testSerializedShape(): Unit {
        let original = InitializeParams("p1", ["db"], ["api"])
        let json = toJsonString(original)
        // 无 config 字段时不应输出 "config"
        @Expect(!json.contains("config"))
        @Expect(json.contains("\"id\":\"p1\""))
        @Expect(json.contains("\"inject\":[\"db\"]"))
    }
}

@Test
class InitializeResultTest {
    @TestCase
    func testRoundTrip(): Unit {
        let providers = HashMap<String, String>()
        providers["db"] = "plugin-b"
        let original = InitializeResult(true, providers)
        let restored = roundTrip(original)
        @Expect(restored.ok)
        @Expect(restored.providers["db"], "plugin-b")
    }

    @TestCase
    func testRoundTripFailed(): Unit {
        let original = InitializeResult(false, HashMap<String, String>())
        let restored = roundTrip(original)
        @Expect(!restored.ok)
        @Expect(restored.providers.size, 0)
    }
}

@Test
class ProvideParamsTest {
    @TestCase
    func testRoundTrip(): Unit {
        let original = ProvideParams("db")
        let restored = roundTrip(original)
        @Expect(restored.key, "db")
    }
}

@Test
class ProvideResultTest {
    @TestCase
    func testRoundTrip(): Unit {
        let original = ProvideResult("uuid-123")
        let restored = roundTrip(original)
        @Expect(restored.undoId, "uuid-123")
    }
}

@Test
class DisposeParamsTest {
    @TestCase
    func testRoundTrip(): Unit {
        let original = DisposeParams("uuid-123")
        let restored = roundTrip(original)
        @Expect(restored.undoId, "uuid-123")
    }
}

@Test
class NotifyParamsTest {
    @TestCase
    func testRoundTripDependencyLost(): Unit {
        let original = NotifyParams(NotifyKind.DEPENDENCY_LOST, "db")
        let restored = roundTrip(original)
        @Expect(restored.kind, NotifyKind.DEPENDENCY_LOST)
        @Expect(restored.key, "db")
        @Expect(restored.provider.isNone())
    }

    @TestCase
    func testRoundTripProviderChanged(): Unit {
        let original = NotifyParams(NotifyKind.PROVIDER_CHANGED, "db", provider: Some("plugin-c"))
        let restored = roundTrip(original)
        @Expect(restored.kind, NotifyKind.PROVIDER_CHANGED)
        @Expect(restored.key, "db")
        @Expect(restored.provider, Some("plugin-c"))
    }

    @TestCase
    func testSerializedShape(): Unit {
        let original = NotifyParams(NotifyKind.DEPENDENCY_LOST, "db")
        let json = toJsonString(original)
        @Expect(!json.contains("provider"))
    }
}

@Test
class LogParamsTest {
    @TestCase
    func testRoundTrip(): Unit {
        let original = LogParams(LogLevel.INFO, "hello world")
        let restored = roundTrip(original)
        @Expect(restored.level, LogLevel.INFO)
        @Expect(restored.message, "hello world")
    }
}

@Test
class InvokeParamsTest {
    @TestCase
    func testRoundTrip(): Unit {
        let args = [JsonValue.String("a"), JsonValue.Number(1.0)]
        let original = InvokeParams("db", "query", args)
        let restored = roundTrip(original)
        @Expect(restored.service, "db")
        @Expect(restored.method, "query")
        @Expect(restored.args.size, 2)
        match (restored.args[0]) {
            case JsonValue.String(s) => @Expect(s, "a")
            case _ => @Fail("expected string arg")
        }
        match (restored.args[1]) {
            case JsonValue.Number(n) => @Expect(n, 1.0)
            case _ => @Fail("expected number arg")
        }
    }

    @TestCase
    func testRoundTripEmptyArgs(): Unit {
        let original = InvokeParams("db", "health", [])
        let restored = roundTrip(original)
        @Expect(restored.args.size, 0)
    }
}
