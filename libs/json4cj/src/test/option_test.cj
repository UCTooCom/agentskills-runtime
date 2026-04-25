package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
class ClassWithOption {
    public var optionalStringWithoutValue: Option<String> = None
    public var optionalInt64WithoutValue: Option<Int64> = None

    public var optionalStringWithValue: Option<String> = "StringValue"
    public var optionalInt64WithValue: Option<Int64> = 199
}

@Test
public class TestOption {
    private let MYCLASS_JSON_WITH_OPTION = """
    {
        "stringVar": "String1",
        "intVar": 10,
        "optionalStringWithoutValue": null,
        "optionalInt64WithoutValue": null,
        "optionalInt64WithValue": 1001,
        "optionalStringWithValue": "StringValue"
    }
    """
    private let JSON_NULL_OPTION = """
    {
        "optionalInt64WithValue": null
    }
    """
    private let JSON_WRONG_TYPE_OPTION = """
    {
        "optionalInt64WithValue": "not_a_number"
    }
    """

    @TestCase
    func testOption(): Unit {
        var json = JsonValue.fromStr(MYCLASS_JSON_WITH_OPTION).asObject()
        var classWithOption = ClassWithOption()
        @Assert(classWithOption.toJson().contains("StringValue"), true)
        @Assert(classWithOption.toJson().contains("199"), true)

        let fromJson = ClassWithOption.fromJson(MYCLASS_JSON_WITH_OPTION)
        @Assert(fromJson.optionalStringWithoutValue, None)
        @Assert(fromJson.optionalInt64WithoutValue, None)
        @Assert(fromJson.optionalStringWithValue, "StringValue")
        @Assert(fromJson.optionalInt64WithValue, 1001)
    }

    // Test: null JSON value for Option field -> None
    @TestCase
    func testOptionNullValue(): Unit {
        let obj = ClassWithOption.fromJson(JSON_NULL_OPTION)
        @Assert(obj.optionalInt64WithValue, None)
    }

    // Test: missing Option field -> keeps default value
    @TestCase
    func testOptionMissingField(): Unit {
        let obj = ClassWithOption.fromJson("{}")
        @Assert(obj.optionalStringWithoutValue, None)
        @Assert(obj.optionalInt64WithoutValue, None)
        @Assert(obj.optionalStringWithValue, "StringValue")
        @Assert(obj.optionalInt64WithValue, 199)
    }

    // Test: wrong type value for Option field -> should throw, not silently return None
    @TestCase
    func testOptionWrongTypeThrows(): Unit {
        var caught = false
        try {
            let _ = ClassWithOption.fromJson(JSON_WRONG_TYPE_OPTION)
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }
}
