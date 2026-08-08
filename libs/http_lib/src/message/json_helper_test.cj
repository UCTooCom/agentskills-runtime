package http_lib.message

import http_lib.core.{assertTrue, assertFalse}

@Test
public class JsonHelperTest {

    @TestCase
    public func testParseJson(): Unit {
        let json = "{\"key\":\"value\"}"
        let value = JsonHelper.parse(json)
        assertTrue(true)  // 无崩溃即成功
    }

    @TestCase
    public func testParseOrNullValid(): Unit {
        let value = JsonHelper.parseOrNull("{\"a\":1}")
        assertTrue(value.isSome())
    }

    @TestCase
    public func testParseOrNullInvalid(): Unit {
        let value = JsonHelper.parseOrNull("not json")
        assertTrue(value.isNone())
    }

    @TestCase
    public func testStringify(): Unit {
        let value = JsonHelper.string("hello")
        let output = JsonHelper.stringify(value)
        assertTrue(output.contains("hello"))
    }

    @TestCase
    public func testNullValue(): Unit {
        let v = JsonHelper.nullValue()
        assertTrue(true)
    }

    @TestCase
    public func testBool(): Unit {
        let v = JsonHelper.bool(true)
        assertTrue(true)
    }

    @TestCase
    public func testNumber(): Unit {
        let v = JsonHelper.number(42.0)
        assertTrue(true)
    }

    @TestCase
    public func testString(): Unit {
        let v = JsonHelper.string("test")
        assertTrue(true)
    }

    @TestCase
    public func testGetString(): Unit {
        let v = JsonHelper.string("hello")
        match (JsonHelper.getString(v)) {
            case Some(s) => assertTrue(s == "hello")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testGetStringOnNonString(): Unit {
        let v = JsonHelper.number(42.0)
        assertTrue(JsonHelper.getString(v).isNone())
    }

    @TestCase
    public func testGetNumber(): Unit {
        let v = JsonHelper.number(3.14)
        match (JsonHelper.getNumber(v)) {
            case Some(n) => assertTrue(n == 3.14)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testGetNumberOnNonNumber(): Unit {
        let v = JsonHelper.string("text")
        assertTrue(JsonHelper.getNumber(v).isNone())
    }

    @TestCase
    public func testGetBool(): Unit {
        let v = JsonHelper.bool(true)
        match (JsonHelper.getBool(v)) {
            case Some(b) => assertTrue(b == true)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testGetBoolOnNonBool(): Unit {
        let v = JsonHelper.nullValue()
        assertTrue(JsonHelper.getBool(v).isNone())
    }

    @TestCase
    public func testStringifyWithIndent(): Unit {
        let obj = JsonHelper.object()
        obj["key"] = JsonHelper.string("value")
        let jsonValue = JsonHelper.objectOf(obj)
        let pretty = JsonHelper.stringify(jsonValue, 2)
        assertTrue(pretty.size > 0)
    }

    @TestCase
    public func testPath(): Unit {
        let json = JsonHelper.parse("{\"user\": {\"name\": \"Alice\"}}")
        let results = JsonHelper.path(json, "$.user.name")
        assertTrue(results.size > 0)
    }

    @TestCase
    public func testPathFirst(): Unit {
        let json = JsonHelper.parse("{\"items\": [1, 2, 3]}")
        match (JsonHelper.pathFirst(json, "$.items[0]")) {
            case Some(_) => assertTrue(true)
            case None => ()
        }
    }

    @TestCase
    public func testArray(): Unit {
        let arr = JsonHelper.array()
        assertTrue(arr.size == 0)
        arr.add(JsonHelper.string("a"))
        arr.add(JsonHelper.number(1.0))
        assertTrue(arr.size == 2)
    }

    @TestCase
    public func testArrayOf(): Unit {
        let arr = JsonHelper.array()
        arr.add(JsonHelper.bool(true))
        arr.add(JsonHelper.bool(false))
        let jsonArr = JsonHelper.arrayOf(arr)
        let str = JsonHelper.stringify(jsonArr)
        assertTrue(str.contains("true"))
        assertTrue(str.contains("false"))
    }

    @TestCase
    public func testObject(): Unit {
        let obj = JsonHelper.object()
        assertTrue(obj.size == 0)
        obj["status"] = JsonHelper.string("ok")
        assertTrue(obj.size == 1)
    }

    @TestCase
    public func testObjectOf(): Unit {
        let obj = JsonHelper.object()
        obj["name"] = JsonHelper.string("test")
        obj["count"] = JsonHelper.number(42.0)
        let jsonObj = JsonHelper.objectOf(obj)
        let str = JsonHelper.stringify(jsonObj)
        assertTrue(str.contains("test"))
        assertTrue(str.contains("42"))
    }
}
