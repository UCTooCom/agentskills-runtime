package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class JsonPathTests {
    private func buildSample(): JsonValue {
        let inner = HashMap<String, JsonValue>()
        inner["c"] = JsonValue.JsonNumber(3.0)
        let obj = HashMap<String, JsonValue>()
        obj["a"] = JsonValue.JsonNumber(1.0)
        obj["b"] = JsonValue.JsonString("two")
        obj["nested"] = JsonValue.JsonObject(inner)
        let arr = ArrayList<JsonValue>()
        arr.add(JsonValue.JsonNumber(10.0))
        arr.add(JsonValue.JsonNumber(20.0))
        obj["arr"] = JsonValue.JsonArray(arr)
        return JsonValue.JsonObject(obj)
    }

    @TestCase
    public func testPathRoot() {
        @Assert(JSON.path(buildSample(), "$").size, 1)
    }

    @TestCase
    public func testPathField() {
        let r = JSON.path(buildSample(), "$.a")
        @Assert(r.size, 1)
        @Assert(r[0].requireNumber(), 1.0)
    }

    @TestCase
    public func testPathStringField() {
        let r = JSON.path(buildSample(), "$.b")
        @Assert(r.size, 1)
        @Assert(r[0].requireString(), "two")
    }

    @TestCase
    public func testPathNestedField() {
        let r = JSON.path(buildSample(), "$.nested.c")
        @Assert(r.size, 1)
        @Assert(r[0].requireNumber(), 3.0)
    }

    @TestCase
    public func testPathArrayIndex() {
        let r = JSON.path(buildSample(), "$.arr[0]")
        @Assert(r.size, 1)
        @Assert(r[0].requireNumber(), 10.0)
    }

    @TestCase
    public func testPathArrayIndex2() {
        let r = JSON.path(buildSample(), "$.arr[1]")
        @Assert(r.size, 1)
        @Assert(r[0].requireNumber(), 20.0)
    }

    @TestCase
    public func testPathBracketField() {
        @Assert(JSON.path(buildSample(), "$['a']").size, 1)
    }

    @TestCase
    public func testPathMissingField() {
        @Assert(JSON.path(buildSample(), "$.nonexistent").size, 0)
    }

    @TestCase
    public func testPathFieldOnNonObject() {
        @Assert(JSON.path(JsonValue.JsonNumber(1.0), "$.x").size, 0)
    }

    @TestCase
    public func testPathFirstRoot() {
        @Assert(JSON.pathFirst(buildSample(), "$").isSome())
    }

    @TestCase
    public func testPathFirstField() {
        let r = JSON.pathFirst(buildSample(), "$.a")
        @Assert(r.isSome())
        @Assert(r.getOrThrow().requireNumber(), 1.0)
    }

    @TestCase
    public func testPathFirstMissing() {
        @Assert(JSON.pathFirst(buildSample(), "$.missing").isNone())
    }

    @TestCase
    public func testJsonPathFunc() {
        @Assert(jsonPath(buildSample(), "$.a").size, 1)
    }

    @TestCase
    public func testJsonPathFirstFunc() {
        @Assert(jsonPathFirst(buildSample(), "$.a").isSome())
    }

    @TestCase
    public func testPathWildcard() {
        let r = JSON.path(buildSample(), "$.arr[*]")
        @Assert(r.size, 2)
    }
}
