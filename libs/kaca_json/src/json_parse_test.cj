package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class JsonParseTests {
    // JSON.parse(input: String): JsonValue
    @TestCase
    public func testParseString() {
        let v = JSON.parse("\"hello\"")
        @Assert(v.isString())
        @Assert(v.requireString(), "hello")
    }

    @TestCase
    public func testParseNumber() {
        let v = JSON.parse("42")
        @Assert(v.isNumber())
        @Assert(v.requireNumber(), 42.0)
    }

    @TestCase
    public func testParseNegativeNumber() {
        let v = JSON.parse("-3.14")
        @Assert(v.requireNumber(), -3.14)
    }

    @TestCase
    public func testParseBoolTrue() {
        let v = JSON.parse("true")
        @Assert(v.isBool())
        @Assert(v.requireBool())
    }

    @TestCase
    public func testParseBoolFalse() {
        let v = JSON.parse("false")
        @Assert(v.isBool())
        @Assert(!v.requireBool())
    }

    @TestCase
    public func testParseNull() {
        let v = JSON.parse("null")
        @Assert(v.isNull())
    }

    @TestCase
    public func testParseEmptyArray() {
        let v = JSON.parse("[]")
        @Assert(v.isArray())
        @Assert(v.requireArray().size, 0)
    }

    @TestCase
    public func testParseEmptyObject() {
        let v = JSON.parse("{}")
        @Assert(v.isObject())
        @Assert(v.requireObject().size, 0)
    }

    @TestCase
    public func testParseSimpleObject() {
        let v = JSON.parse("{\"key\":\"value\"}")
        @Assert(v.isObject())
        let obj = v.requireObject()
        @Assert(obj.size, 1)
        let valOpt = obj.get("key")
        @Assert(valOpt.isSome())
        match (valOpt) {
            case Some(sv) => @Assert(sv.requireString(), "value")
            case None => @Assert(false)
        }
    }

    @TestCase
    public func testParseArrayWithValues() {
        let v = JSON.parse("[1, \"two\", true, null]")
        @Assert(v.isArray())
        let arr = v.requireArray()
        @Assert(arr.size, 4)
        @Assert(arr[0].requireNumber(), 1.0)
        @Assert(arr[1].requireString(), "two")
        @Assert(arr[2].requireBool())
        @Assert(arr[3].isNull())
    }

    @TestCase
    public func testParseNestedArray() {
        let v = JSON.parse("[[1,2],[3,4]]")
        @Assert(v.isArray())
        @Assert(v.requireArray().size, 2)
    }

    // JSON.parse(input: Array<Byte>): JsonValue
    @TestCase
    public func testParseBytes() {
        let bytes = stringToBytes("{\"x\":1}")
        let v = JSON.parse(bytes)
        @Assert(v.isObject())
    }

    // JSON.parseOrNull(input: String): ?JsonValue
    @TestCase
    public func testParseOrNullValid() {
        let r = JSON.parseOrNull("123")
        @Assert(r.isSome())
        match (r) {
            case Some(v) => @Assert(v.requireNumber(), 123.0)
            case None => @Assert(false)
        }
    }

    @TestCase
    public func testParseOrNullInvalid() {
        let r = JSON.parseOrNull("{invalid}")
        @Assert(r.isNone())
    }

    // JSON.parseOrNull(input: Array<Byte>): ?JsonValue
    @TestCase
    public func testParseOrNullBytes() {
        let bytes = stringToBytes("{\"ok\":true}")
        @Assert(JSON.parseOrNull(bytes).isSome())
    }

    // Error cases
    @TestCase
    public func testParseErrorInvalidJson() {
        try {
            let _ = JSON.parse("01")
            @Assert(false)
        } catch (_: Exception) {
            @Assert(true)
        }
    }

    @TestCase
    public func testParseErrorEmptyInput() {
        try {
            let _ = JSON.parse("")
            @Assert(false)
        } catch (_: Exception) {
            @Assert(true)
        }
    }

    @TestCase
    public func testParseWithWhitespace() {
        let v = JSON.parse("  {\"a\": 1}  ")
        @Assert(v.isObject())
    }

    // Not-roundtrip: parse then stringify
    @TestCase
    public func testRoundtrip() {
        let original = "{\"a\":1,\"b\":\"text\",\"c\":true,\"d\":null}"
        let parsed = JSON.parse(original)
        let result = JSON.stringify(parsed)
        let reparsed = JSON.parse(result)
        @Assert(reparsed.isObject())
    }
}
