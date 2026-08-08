package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class StringifyTests {
    private func buildSample(): JsonValue {
        let obj = HashMap<String, JsonValue>()
        obj["name"] = JsonValue.JsonString("test")
        obj["count"] = JsonValue.JsonNumber(42.0)
        obj["active"] = JsonValue.JsonBool(true)
        obj["data"] = JsonValue.JsonNull
        return JsonValue.JsonObject(obj)
    }

    @TestCase
    public func testStringifyNull() {
        @Assert(JSON.stringify(JsonValue.JsonNull), "null")
    }

    @TestCase
    public func testStringifyBool() {
        @Assert(JSON.stringify(JsonValue.JsonBool(true)), "true")
        @Assert(JSON.stringify(JsonValue.JsonBool(false)), "false")
    }

    @TestCase
    public func testStringifyNumber() {
        @Assert(JSON.stringify(JsonValue.JsonNumber(123.0)), "123")
    }

    @TestCase
    public func testStringifyString() {
        @Assert(JSON.stringify(JsonValue.JsonString("hello")), "\"hello\"")
    }

    @TestCase
    public func testStringifyEmptyArray() {
        @Assert(JSON.stringify(JsonValue.JsonArray(ArrayList<JsonValue>())), "[]")
    }

    @TestCase
    public func testStringifyEmptyObject() {
        @Assert(JSON.stringify(JsonValue.JsonObject(HashMap<String, JsonValue>())), "{}")
    }

    @TestCase
    public func testStringifyArray() {
        let arr = ArrayList<JsonValue>()
        arr.add(JsonValue.JsonNumber(1.0))
        arr.add(JsonValue.JsonNumber(2.0))
        arr.add(JsonValue.JsonNumber(3.0))
        @Assert(JSON.stringify(JsonValue.JsonArray(arr)), "[1,2,3]")
    }

    @TestCase
    public func testStringifyObject() {
        let s = JSON.stringify(buildSample())
        @Assert(s.size > 0)
        @Assert(s.contains("name"))
        @Assert(s.contains("42"))
    }

    @TestCase
    public func testStringifyIndent() {
        let s = JSON.stringify(buildSample(), 2)
        @Assert(s.size > 0)
        @Assert(s.contains("\n"))
    }

    @TestCase
    public func testStringifyOptionsIndent() {
        let opts = StringifyOptions.withIndent(4)
        @Assert(JSON.stringify(buildSample(), opts).size > 0)
    }

    @TestCase
    public func testStringifyOptionsIndentStr() {
        let opts = StringifyOptions.withIndentStr("\t")
        @Assert(JSON.stringify(buildSample(), opts).size > 0)
    }

    @TestCase
    public func testStringifyOptionsFilter() {
        let opts = StringifyOptions()
        let filter = ArrayList<String>()
        filter.add("name")
        opts.filter = filter
        @Assert(JSON.stringify(buildSample(), opts).size > 0)
    }

    @TestCase
    public func testStringifyOptionsDefault() {
        let opts = StringifyOptions()
        @Assert(JSON.stringify(buildSample(), opts).size > 0)
    }


    // stringify with string space param
    @TestCase
    public func testStringifyStringSpace() {
        let s = stringify(buildSample(), "  ")
        @Assert(s.size > 0)
    }

    // stringifyWithFilter
    @TestCase
    public func testStringifyWithFilter() {
        let filter = ArrayList<String>()
        filter.add("name")
        let s = stringifyWithFilter(buildSample(), filter)
        @Assert(s.size > 0)
    }

    // stringifyWithOptions
    @TestCase
    public func testStringifyWithOptionsFunc() {
        let opts = StringifyOptions()
        opts.space = 2
        @Assert(stringifyWithOptions(buildSample(), opts).size > 0)
    }

    
}
