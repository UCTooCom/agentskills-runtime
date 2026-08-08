package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class FastParseTests {
    @TestCase
    public func testFastString() {
        let fv = JSON.parseFast("\"hello\"")
        @Assert(fv.getString(), "hello")
    }

    @TestCase
    public func testFastNumber() {
        let fv = JSON.parseFast("42")
        @Assert(fv.getNumber(), 42.0)
    }

    @TestCase
    public func testFastBool() {
        @Assert(JSON.parseFast("true").toJsonValue().requireBool())
        @Assert(!JSON.parseFast("false").toJsonValue().requireBool())
    }

    @TestCase
    public func testFastNull() {
        @Assert(JSON.parseFast("null").toJsonValue().isNull())
    }

    @TestCase
    public func testFastEmptyArray() {
        @Assert(JSON.parseFast("[]").getArray().size, 0)
    }

    @TestCase
    public func testFastEmptyObject() {
        @Assert(JSON.parseFast("{}").getObject().size, 0)
    }

    @TestCase
    public func testFastArrayLazy() {
        let fv = JSON.parseFast("[1,2,3]")
        let arr = fv.getArray()
        @Assert(arr.size, 3)
        @Assert(arr[0].getNumber(), 1.0)
    }

    @TestCase
    public func testFastObjectLazy() {
        let fv = JSON.parseFast("{\"a\":1,\"b\":\"two\"}")
        let obj = fv.getObject()
        @Assert(obj.size, 2)
        let aVal = obj.get("a")
        @Assert(aVal.isSome())
    }

    @TestCase
    public func testFastToJsonValue() {
        let fv = JSON.parseFast("{\"x\":[1,2,3]}")
        let jv = fv.toJsonValue()
        @Assert(jv.isObject())
    }

    @TestCase
    public func testFastBytes() {
        let bytes = stringToBytes("[true,false,null]")
        @Assert(JSON.parseFast(bytes).getArray().size, 3)
    }

    @TestCase
    public func testFastOrNullValid() {
        @Assert(JSON.parseFastOrNull("\"ok\"").isSome())
    }

    @TestCase
    public func testFastOrNullInvalid() {
        @Assert(JSON.parseFastOrNull("{bad}").isNone())
    }

    @TestCase
    public func testFastOrNullBytes() {
        let bytes = stringToBytes("null")
        @Assert(JSON.parseFastOrNull(bytes).isSome())
    }

    @TestCase
    public func testFastGetStringWrongType() {
        @Assert(JSON.parseFast("42").getString(), "")
    }

    @TestCase
    public func testFastGetNumberWrongType() {
        @Assert(JSON.parseFast("\"s\"").getNumber(), 0.0)
    }

    @TestCase
    public func testFastNegativeNumber() {
        @Assert(JSON.parseFast("-3.14").getNumber(), -3.14)
    }

    @TestCase
    public func testFastNestedLazy() {
        let fv = JSON.parseFast("{\"a\":{\"b\":[10,20]}}")
        let obj = fv.getObject()
        let innerObj = obj.get("a").getOrThrow().getObject()
        let innerArr = innerObj.get("b").getOrThrow().getArray()
        @Assert(innerArr.size, 2)
        @Assert(innerArr[0].getNumber(), 10.0)
    }
}
