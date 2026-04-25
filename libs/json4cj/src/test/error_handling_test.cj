package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonDeserializeException}
import json4cj.jsonmacro.{JsonSerialize, JsonIgnoreUnknown}
import json4cj.*

// ===== Test data types =====

@JsonSerialize
class ErrAddress {
    public var city: String = ""
    public var zip: Int64 = 0
}

@JsonSerialize
class ErrUser {
    public var name: String = ""
    public var age: Int64 = 0
    public var address: ErrAddress = ErrAddress()
}

@JsonSerialize
class ErrOuter {
    public var user: ErrUser = ErrUser()
}

@JsonSerialize
class ErrWithList {
    public var items: ArrayList<ErrAddress> = ArrayList<ErrAddress>()
}

@JsonSerialize
class ErrWithMap {
    public var data: HashMap<String, Int64> = HashMap<String, Int64>()
}

@JsonSerialize
@JsonIgnoreUnknown[false]
class ErrStrict {
    public var name: String = ""
}

@JsonSerialize
enum ErrColor {
    | Red | Green | Blue
}

@JsonSerialize
class ErrWithEnum {
    public var color: ErrColor = ErrColor.Red
}

// ===== Tests =====

@Test
public class TestErrorHandling {
    // Test 1: flat field type mismatch — path is $.name
    @TestCase
    func testFlatFieldTypeMismatch(): Unit {
        let json = "{\"name\": 123, \"age\": 25}"
        var msg = ""
        try {
            ErrUser.fromJson(json)
        } catch (e: Exception) {
            msg = e.message
        }
        @Assert(msg.contains("$.name"), true)
    }

    // Test 2: nested object field error — path is $.address.city
    @TestCase
    func testNestedFieldTypeMismatch(): Unit {
        let json = "{\"name\": \"Alice\", \"age\": 25, \"address\": {\"city\": 42, \"zip\": 10000}}"
        var msg = ""
        try {
            ErrUser.fromJson(json)
        } catch (e: Exception) {
            msg = e.message
        }
        @Assert(msg.contains("$.address"), true)
    }

    // Test 3: deep nesting (3 levels) — path is $.user.address.zip
    @TestCase
    func testDeepNestedFieldError(): Unit {
        let json = "{\"user\": {\"name\": \"Bob\", \"age\": 30, \"address\": {\"city\": \"NYC\", \"zip\": \"notint\"}}}"
        var msg = ""
        try {
            ErrOuter.fromJson(json)
        } catch (e: Exception) {
            msg = e.message
        }
        @Assert(msg.contains("$.user"), true)
    }

    // Test 4: array element error — path contains [index]
    @TestCase
    func testArrayElementError(): Unit {
        let json = "{\"items\": [{\"city\": \"NYC\", \"zip\": 100}, {\"city\": 999, \"zip\": 200}]}"
        var msg = ""
        try {
            ErrWithList.fromJson(json)
        } catch (e: Exception) {
            msg = e.message
        }
        // The error should reference items[1].city
        @Assert(msg.contains("[1]"), true)
        @Assert(msg.contains("city"), true)
    }

    // Test 5: unknown fields with strict mode — path is $
    @TestCase
    func testStrictModeWithPath(): Unit {
        let json = "{\"name\": \"Alice\", \"extra\": \"field\"}"
        var msg = ""
        try {
            ErrStrict.fromJson(json)
        } catch (e: Exception) {
            msg = e.message
        }
        @Assert(msg.contains("$"), true)
        @Assert(msg.contains("unknown fields"), true)
        @Assert(msg.contains("extra"), true)
    }

    // Test 6: built-in type fromJsonValue with path — JsonDeserializeException
    @TestCase
    func testBuiltInTypePath(): Unit {
        let value = JsonString("not a number")
        var caught = false
        var path = ""
        var msg = ""
        try {
            Int64.fromJsonValue(value, "$.user.age")
        } catch (e: JsonDeserializeException) {
            caught = true
            path = e.path
            msg = e.message
        } catch (e: Exception) {
        }
        @Assert(caught, true)
        @Assert(path, "$.user.age")
    }

    // Test 7: ArrayList with index path — JsonDeserializeException
    @TestCase
    func testArrayListIndexPath(): Unit {
        // Build a JSON array where element [2] is wrong type
        let json = "[1, 2, \"bad\", 4]"
        let value = JsonValue.fromStr(json)
        var msg = ""
        try {
            ArrayList<Int64>.fromJsonValue(value, "$.numbers")
        } catch (e: JsonDeserializeException) {
            msg = e.message
        }
        @Assert(msg.contains("$.numbers[2]"), true)
        @Assert(msg.contains("expected Int64"), true)
    }

    // Test 8: HashMap entry path
    @TestCase
    func testHashMapEntryPath(): Unit {
        let json = "{\"a\": 1, \"b\": \"wrong\"}"
        let value = JsonValue.fromStr(json)
        var msg = ""
        try {
            HashMap<String, Int64>.fromJsonValue(value, "$.data")
        } catch (e: JsonDeserializeException) {
            msg = e.message
        }
        @Assert(msg.contains("$.data.b"), true)
        @Assert(msg.contains("expected Int64"), true)
    }

    // Test 9: enum deserialization error with path
    @TestCase
    func testEnumErrorWithPath(): Unit {
        let json = "{\"color\": \"Purple\"}"
        var msg = ""
        try {
            ErrWithEnum.fromJson(json)
        } catch (e: Exception) {
            msg = e.message
        }
        @Assert(msg.contains("unknown"), true)
        @Assert(msg.contains("ErrColor"), true)
        @Assert(msg.contains("Purple"), true)
    }

    // Test 10: successful deserialization still works
    @TestCase
    func testSuccessfulDeserialization(): Unit {
        let json = "{\"user\": {\"name\": \"OK\", \"age\": 1, \"address\": {\"city\": \"A\", \"zip\": 100}}}"
        let result = ErrOuter.fromJson(json)
        @Assert(result.user.name, "OK")
        @Assert(result.user.age, 1)
        @Assert(result.user.address.city, "A")
        @Assert(result.user.address.zip, 100)
    }

    // Test 11: fromJsonValue(value, path) overload exists and works
    @TestCase
    func testFromJsonValueWithPath(): Unit {
        let json = "{\"name\": \"Test\", \"age\": 42, \"address\": {\"city\": \"B\", \"zip\": 200}}"
        let value = JsonValue.fromStr(json)
        let result = ErrUser.fromJsonValue(value, "$.root")
        @Assert(result.name, "Test")
        @Assert(result.age, 42)
    }

    // Test 12: fromJsonValue(value, path) propagates custom path in error
    @TestCase
    func testFromJsonValueCustomPathPropagation(): Unit {
        let json = "{\"name\": 999, \"age\": 42, \"address\": {\"city\": \"C\", \"zip\": 300}}"
        let value = JsonValue.fromStr(json)
        var msg = ""
        try {
            ErrUser.fromJsonValue(value, "$.myRoot")
        } catch (e: Exception) {
            msg = e.message
        }
        @Assert(msg.contains("$.myRoot.name"), true)
    }

    // Test 13: Float64 type mismatch
    @TestCase
    func testFloat64TypeMismatch(): Unit {
        let value = JsonString("not a float")
        var caught = false
        try {
            Float64.fromJsonValue(value, "$.weight")
        } catch (e: JsonDeserializeException) {
            caught = true
            @Assert(e.path, "$.weight")
        }
        @Assert(caught, true)
    }

    // Test 14: Bool type mismatch
    @TestCase
    func testBoolTypeMismatch(): Unit {
        let value = JsonInt(42)
        var caught = false
        try {
            Bool.fromJsonValue(value, "$.active")
        } catch (e: JsonDeserializeException) {
            caught = true
            @Assert(e.path, "$.active")
        }
        @Assert(caught, true)
    }
}
