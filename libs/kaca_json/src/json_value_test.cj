package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class JsonValueTests {
    @TestCase
    public func testTypeName() {
        @Assert(JsonValue.JsonNull.typeName(), "null")
        @Assert(JsonValue.JsonBool(true).typeName(), "bool")
        @Assert(JsonValue.JsonNumber(1.0).typeName(), "number")
        @Assert(JsonValue.JsonString("s").typeName(), "string")
        @Assert(JsonValue.JsonArray(ArrayList<JsonValue>()).typeName(), "array")
        @Assert(JsonValue.JsonObject(HashMap<String, JsonValue>()).typeName(), "object")
    }

    @TestCase
    public func testIsChecks() {
        @Assert(JsonValue.JsonNull.isNull())
        @Assert(JsonValue.JsonBool(true).isBool())
        @Assert(JsonValue.JsonNumber(0.0).isNumber())
        @Assert(JsonValue.JsonString("").isString())
        @Assert(JsonValue.JsonArray(ArrayList<JsonValue>()).isArray())
        @Assert(JsonValue.JsonObject(HashMap<String, JsonValue>()).isObject())
        @Assert(!JsonValue.JsonNull.isBool())
    }

    @TestCase
    public func testAsBoolOrNull() {
        @Assert(JsonValue.JsonBool(true).asBoolOrNull().getOrThrow())
        @Assert(JsonValue.JsonNull.asBoolOrNull().isNone())
    }

    @TestCase
    public func testAsNumberOrNull() {
        @Assert(JsonValue.JsonNumber(3.14).asNumberOrNull().getOrThrow(), 3.14)
        @Assert(JsonValue.JsonNull.asNumberOrNull().isNone())
    }

    @TestCase
    public func testAsStringOrNull() {
        @Assert(JsonValue.JsonString("hi").asStringOrNull().getOrThrow(), "hi")
        @Assert(JsonValue.JsonNull.asStringOrNull().isNone())
    }

    @TestCase
    public func testAsArrayOrNull() {
        @Assert(JsonValue.JsonArray(ArrayList<JsonValue>()).asArrayOrNull().isSome())
        @Assert(JsonValue.JsonNull.asArrayOrNull().isNone())
    }

    @TestCase
    public func testAsObjectOrNull() {
        @Assert(JsonValue.JsonObject(HashMap<String, JsonValue>()).asObjectOrNull().isSome())
        @Assert(JsonValue.JsonNull.asObjectOrNull().isNone())
    }

    @TestCase
    public func testAsIntOrNull() {
        @Assert(JsonValue.JsonNumber(42.0).asIntOrNull().getOrThrow(), 42)
        @Assert(JsonValue.JsonNumber(3.14).asIntOrNull().isNone())
        @Assert(JsonValue.JsonNull.asIntOrNull().isNone())
    }

    @TestCase
    public func testAsDefaults() {
        @Assert(JsonValue.JsonBool(true).asBoolOr(false))
        @Assert(JsonValue.JsonNull.asBoolOr(false) == false)
        @Assert(JsonValue.JsonNumber(5.0).asNumberOr(0.0), 5.0)
        @Assert(JsonValue.JsonNull.asNumberOr(-1.0), -1.0)
        @Assert(JsonValue.JsonString("x").asStringOr(""), "x")
        @Assert(JsonValue.JsonNull.asStringOr("def"), "def")
        @Assert(JsonValue.JsonNumber(10.0).asIntOr(0), 10)
        @Assert(JsonValue.JsonNull.asIntOr(-1), -1)
    }

    @TestCase
    public func testRequireBool() {
        @Assert(JsonValue.JsonBool(true).requireBool())
        try {
            let _ = JsonValue.JsonNull.requireBool()
            @Assert(false)
        } catch (_: Exception) { @Assert(true) }
    }

    @TestCase
    public func testRequireNumber() {
        @Assert(JsonValue.JsonNumber(99.0).requireNumber(), 99.0)
        try {
            let _ = JsonValue.JsonNull.requireNumber()
            @Assert(false)
        } catch (_: Exception) { @Assert(true) }
    }

    @TestCase
    public func testRequireString() {
        @Assert(JsonValue.JsonString("ok").requireString(), "ok")
    }

    @TestCase
    public func testRequireArray() {
        @Assert(JsonValue.JsonArray(ArrayList<JsonValue>()).requireArray().size, 0)
    }

    @TestCase
    public func testRequireObject() {
        @Assert(JsonValue.JsonObject(HashMap<String, JsonValue>()).requireObject().size, 0)
    }

    @TestCase
    public func testGet() {
        let obj = HashMap<String, JsonValue>()
        obj["k"] = JsonValue.JsonNumber(1.0)
        let v = JsonValue.JsonObject(obj)
        @Assert(v.get("k").getOrThrow().requireNumber(), 1.0)
        @Assert(v.get("missing").isNone())
    }

    @TestCase
    public func testHas() {
        let obj = HashMap<String, JsonValue>()
        obj["k"] = JsonValue.JsonNull
        let v = JsonValue.JsonObject(obj)
        @Assert(v.has("k"))
        @Assert(!v.has("x"))
    }

    @TestCase
    public func testAt() {
        let arr = ArrayList<JsonValue>()
        arr.add(JsonValue.JsonNumber(10.0))
        let v = JsonValue.JsonArray(arr)
        @Assert(v.at(0).getOrThrow().requireNumber(), 10.0)
        @Assert(v.at(5).isNone())
    }

    @TestCase
    public func testSizeOrZero() {
        let arr = ArrayList<JsonValue>()
        arr.add(JsonValue.JsonNull)
        @Assert(JsonValue.JsonArray(arr).sizeOrZero(), 1)
        @Assert(JsonValue.JsonNull.sizeOrZero(), 0)
    }

    @TestCase
    public func testPush() {
        let arr = ArrayList<JsonValue>()
        let v = JsonValue.JsonArray(arr)
        v.push(JsonValue.JsonNumber(1.0))
        @Assert(arr.size, 1)
    }

    @TestCase
    public func testPut() {
        let obj = HashMap<String, JsonValue>()
        let v = JsonValue.JsonObject(obj)
        v.put("key", JsonValue.JsonString("val"))
        @Assert(obj.size, 1)
    }

    @TestCase
    public func testExtendToJsonValue() {
        @Assert(true.toJsonValue().isBool())
        @Assert(42.toJsonValue().isNumber())
        @Assert("text".toJsonValue().isString())
        @Assert(3.14.toJsonValue().isNumber())
    }

    // Alias shortcuts
    @TestCase
    public func testGetAliases() {
        @Assert(JsonValue.JsonBool(true).getBool() == Some(true))
        @Assert(JsonValue.JsonNumber(2.0).getNumber() == Some(2.0))
        @Assert(JsonValue.JsonString("hi").getString() == Some("hi"))
    }
}
