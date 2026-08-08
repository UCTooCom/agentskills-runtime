package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class Json5ParseTests {
    @TestCase
    public func testJson5BasicObject() {
        let v = JSON.parseJson5("{key: 'value'}")
        @Assert(v.isObject())
        @Assert(v.requireObject().size, 1)
    }

    @TestCase
    public func testJson5SingleQuotes() {
        let v = JSON.parseJson5("{'a': 'hello'}")
        @Assert(v.requireObject().get("a").getOrThrow().requireString(), "hello")
    }

    @TestCase
    public func testJson5TrailingComma() {
        @Assert(JSON.parseJson5("{a: 1, b: 2,}").requireObject().size, 2)
    }

    @TestCase
    public func testJson5TrailingCommaArray() {
        @Assert(JSON.parseJson5("[1, 2, 3,]").requireArray().size, 3)
    }

    @TestCase
    public func testJson5UnquotedKey() {
        let v = JSON.parseJson5("{unquoted_key: 123}")
        @Assert(v.requireObject().get("unquoted_key").getOrThrow().requireNumber(), 123.0)
    }

    @TestCase
    public func testJson5HexNumber() {
        @Assert(JSON.parseJson5("0xFF").requireNumber(), 255.0)
    }

    @TestCase
    public func testJson5PositiveSign() {
        @Assert(JSON.parseJson5("+42").requireNumber(), 42.0)
    }

    @TestCase
    public func testJson5Infinity() {
        @Assert(JSON.parseJson5("Infinity").requireNumber() > 1e308)
    }

    @TestCase
    public func testJson5NaN() {
        let n = JSON.parseJson5("NaN").requireNumber()
        @Assert(n != n)
    }

    @TestCase
    public func testJson5LineComment() {
        let v = JSON.parseJson5("{a: 1 // comment\n}")
        @Assert(v.requireObject().size, 1)
    }

    @TestCase
    public func testJson5BlockComment() {
        let v = JSON.parseJson5("{a: 1 /* block */}")
        @Assert(v.requireObject().size, 1)
    }

    @TestCase
    public func testJson5Null() {
        @Assert(JSON.parseJson5("null").isNull())
    }

    @TestCase
    public func testJson5Bool() {
        @Assert(JSON.parseJson5("true").requireBool())
        @Assert(!JSON.parseJson5("false").requireBool())
    }

    @TestCase
    public func testJson5EmptyArray() {
        @Assert(JSON.parseJson5("[]").requireArray().size, 0)
    }

    @TestCase
    public func testJson5EmptyObject() {
        @Assert(JSON.parseJson5("{}").requireObject().size, 0)
    }

    @TestCase
    public func testJson5Decimal() {
        let v = JSON.parseJson5("3.14159")
        @Assert(v.isNumber())
    }

    @TestCase
    public func testJson5LeadingDecimal() {
        @Assert(JSON.parseJson5(".5").requireNumber(), 0.5)
    }

    @TestCase
    public func testJson5OrNullValid() {
        @Assert(JSON.parseJson5OrNull("{a:1}").isSome())
    }

    @TestCase
    public func testJson5OrNullInvalid() {
        @Assert(JSON.parseJson5OrNull("{bad syntax !!}").isNone())
    }

    @TestCase
    public func testJson5HexEscape() {
        let v = JSON.parseJson5("'\\x48\\x69'")
        @Assert(v.requireString(), "Hi")
    }

    @TestCase
    public func testJson5ParserDirect() {
        let parser = Json5Parser("{a: 1}")
        let result = parser.parse()
        @Assert(result.isObject())
    }

    @TestCase
    public func testJson5ParserError() {
        let parser = Json5Parser("{bad}")
        try {
            let _ = parser.parse()
            @Assert(false)
        } catch (_: Exception) {
            @Assert(true)
        }
    }
}
