package ystyle::cordis_tests

import ystyle::cordis_core.*
import jsonvalue.*
import stdx.encoding.json.stream.*
import std.io.ByteBuffer
import std.collection.HashMap
import std.unittest.*
import std.unittest.testmacro.*

/**
 * 事件总线协议消息测试（docs/design-events.md §4）
 * 覆盖：方法常量 + 4 个消息类序列化往返
 */

// 往返测试：对象 → JsonWriter → JsonReader（json.stream 直通）
private func roundTrip<T>(obj: T): T where T <: JsonSerializable & JsonDeserializable<T> {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    obj.toJson(w)
    w.flush()
    buf.flush()
    let r = JsonReader(buf)
    T.fromJson(r)
}

// 序列化为 JSON 字符串（形状断言）
private func toJsonString<T>(obj: T): String where T <: JsonSerializable {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    obj.toJson(w)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}

@Test
class EventMethodsTest {
    @TestCase
    func testEventMethodNames(): Unit {
        @Expect(Methods.EVENTS_SUBSCRIBE, "events/subscribe")
        @Expect(Methods.EVENTS_UNSUBSCRIBE, "events/unsubscribe")
        @Expect(Methods.EVENTS_EMIT, "events/emit")
        @Expect(Methods.EVENTS_DISPATCH, "events/dispatch")
    }
}

@Test
class SubscribeParamsTest {
    @TestCase
    func testRoundTrip(): Unit {
        let original = SubscribeParams("stats/report")
        let restored = roundTrip(original)
        @Expect(restored.event, "stats/report")
    }

    @TestCase
    func testSerializedShape(): Unit {
        let json = toJsonString(SubscribeParams("agent/request"))
        @Expect(json.contains("\"event\":\"agent/request\""))
    }
}

@Test
class SubscribeResultTest {
    @TestCase
    func testRoundTrip(): Unit {
        let original = SubscribeResult("sub-123")
        let restored = roundTrip(original)
        @Expect(restored.subscriptionId, "sub-123")
    }
}

@Test
class UnsubscribeParamsTest {
    @TestCase
    func testRoundTrip(): Unit {
        let original = UnsubscribeParams("sub-123")
        let restored = roundTrip(original)
        @Expect(restored.subscriptionId, "sub-123")
    }
}

@Test
class EmitParamsTest {
    @TestCase
    func testRoundTripEmptyArgs(): Unit {
        let original = EmitParams("app/started", [])
        let restored = roundTrip(original)
        @Expect(restored.event, "app/started")
        @Expect(restored.args.size, 0)
    }

    @TestCase
    func testRoundTripWithArgs(): Unit {
        let args = [JsonValue.String("a"), JsonValue.Number(1.0)]
        let original = EmitParams("stats/report", args)
        let restored = roundTrip(original)
        @Expect(restored.event, "stats/report")
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
    func testSerializedShape(): Unit {
        let json = toJsonString(EmitParams("app/started", []))
        @Expect(json.contains("\"event\":\"app/started\""))
        @Expect(json.contains("\"args\":[]"))
    }
}

@Test
class DispatchParamsTest {
    @TestCase
    func testRoundTrip(): Unit {
        let args = [JsonValue.String("x")]
        let original = DispatchParams("agent/request", args, "emit-1")
        let restored = roundTrip(original)
        @Expect(restored.event, "agent/request")
        @Expect(restored.emitId, "emit-1")
        @Expect(restored.args.size, 1)
        match (restored.args[0]) {
            case JsonValue.String(s) => @Expect(s, "x")
            case _ => @Fail("expected string arg")
        }
    }

    @TestCase
    func testSerializedShape(): Unit {
        let json = toJsonString(DispatchParams("app/started", [], "emit-9"))
        @Expect(json.contains("\"emitId\":\"emit-9\""))
    }
}
