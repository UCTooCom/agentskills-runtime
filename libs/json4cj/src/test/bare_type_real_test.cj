package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonCreator}
import json4cj.*

// ===== Test: bare type param WITHOUT Option wrapper =====

// Test 1: var data: T without @JsonCreator (uses Option<T> wrapper)
@JsonSerialize
class BareVarResponse<T> {
    public var code: Int64 = 0
    public var data: Option<T> = Option<T>.None
}

// Test 2: let data: T with @JsonCreator (bare type param)
@JsonSerialize
@JsonCreator
class BareLetResponse<T> {
    let code: Int64
    let data: T

    public init(code: Int64, data: T) {
        this.code = code
        this.data = data
    }
}

// Test 3: Multi type param with @JsonCreator (bare K, V)
@JsonSerialize
@JsonCreator
class BarePair<K, V> {
    let first: K
    let second: V

    public init(first: K, second: V) {
        this.first = first
        this.second = second
    }
}

// Test 4: Mix of bare type param and concrete type with @JsonCreator
@JsonSerialize
@JsonCreator
class BareMixedResponse<T> {
    let status: String
    let code: Int64
    let payload: T

    public init(status: String, code: Int64, payload: T) {
        this.status = status
        this.code = code
        this.payload = payload
    }
}

@Test
public class TestBareTypeParamReal {
    // --- BareVarResponse (Option<T> wrapper) ---

    @TestCase
    func testBareVarSerialization(): Unit {
        let resp = BareVarResponse<String>()
        resp.code = 200
        resp.data = Option<String>.Some("success")
        let json = resp.toJson()
        @Assert(json.contains("code"), true)
        @Assert(json.contains("200"), true)
        @Assert(json.contains("success"), true)
    }

    @TestCase
    func testBareVarDeserialization(): Unit {
        let json = "{\"code\":200,\"data\":\"hello\"}"
        let resp = BareVarResponse<String>.fromJson(json)
        @Assert(resp.code, 200)
        @Assert(resp.data.getOrThrow(), "hello")
    }

    // --- BareLetResponse (bare type param + @JsonCreator) ---

    @TestCase
    func testBareLetWithCreator(): Unit {
        let resp = BareLetResponse<String>.fromJson("{\"code\":200,\"data\":\"world\"}")
        @Assert(resp.code, 200)
        @Assert(resp.data, "world")
    }

    @TestCase
    func testBareLetRoundTrip(): Unit {
        let original = BareLetResponse<Int64>(404, 99)
        let json = original.toJson()
        let restored = BareLetResponse<Int64>.fromJson(json)
        @Assert(restored.code, 404)
        @Assert(restored.data, 99)
    }

    // --- BarePair (multi type param + @JsonCreator) ---

    @TestCase
    func testBarePairSerialization(): Unit {
        let pair = BarePair<String, Int64>("age", 25)
        let json = pair.toJson()
        @Assert(json.contains("age"), true)
        @Assert(json.contains("25"), true)
    }

    @TestCase
    func testBarePairDeserialization(): Unit {
        let json = "{\"first\":\"name\",\"second\":42}"
        let pair = BarePair<String, Int64>.fromJson(json)
        @Assert(pair.first, "name")
        @Assert(pair.second, 42)
    }

    @TestCase
    func testBarePairRoundTrip(): Unit {
        let original = BarePair<String, Int64>("score", 100)
        let json = original.toJson()
        let restored = BarePair<String, Int64>.fromJson(json)
        @Assert(restored.first, "score")
        @Assert(restored.second, 100)
    }

    // --- BareMixedResponse (mix of bare + concrete types) ---

    @TestCase
    func testBareMixedSerialization(): Unit {
        let resp = BareMixedResponse<String>("ok", 200, "hello")
        let json = resp.toJson()
        @Assert(json.contains("status"), true)
        @Assert(json.contains("ok"), true)
        @Assert(json.contains("200"), true)
        @Assert(json.contains("hello"), true)
    }

    @TestCase
    func testBareMixedDeserialization(): Unit {
        let json = "{\"status\":\"error\",\"code\":500,\"payload\":\"server error\"}"
        let resp = BareMixedResponse<String>.fromJson(json)
        @Assert(resp.status, "error")
        @Assert(resp.code, 500)
        @Assert(resp.payload, "server error")
    }

    @TestCase
    func testBareMixedRoundTrip(): Unit {
        let original = BareMixedResponse<Int64>("ok", 200, 42)
        let json = original.toJson()
        let restored = BareMixedResponse<Int64>.fromJson(json)
        @Assert(restored.status, "ok")
        @Assert(restored.code, 200)
        @Assert(restored.payload, 42)
    }

    // --- Error handling: missing required bare type param field ---

    @TestCase
    func testBareLetMissingFieldThrows(): Unit {
        var caught = false
        try {
            let _ = BareLetResponse<String>.fromJson("{\"code\":200}")
        } catch (e: Exception) {
            caught = e.message.contains("data") && e.message.contains("missing")
        }
        @Assert(caught, true)
    }

    @TestCase
    func testBarePairMissingSecondFieldThrows(): Unit {
        var caught = false
        try {
            let _ = BarePair<String, Int64>.fromJson("{\"first\":\"hello\"}")
        } catch (e: Exception) {
            caught = e.message.contains("second") && e.message.contains("missing")
        }
        @Assert(caught, true)
    }

    @TestCase
    func testBareMixedMissingPayloadThrows(): Unit {
        var caught = false
        try {
            let _ = BareMixedResponse<String>.fromJson("{\"status\":\"ok\",\"code\":200}")
        } catch (e: Exception) {
            caught = e.message.contains("payload") && e.message.contains("missing")
        }
        @Assert(caught, true)
    }
}
