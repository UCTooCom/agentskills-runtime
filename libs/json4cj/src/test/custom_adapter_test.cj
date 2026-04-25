package json4cj.test

import std.time.DateTime
internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

struct CustomTime {
    public CustomTime(let value: DateTime) {
    }
}

extend CustomTime <: JsonValueSerializable<CustomTime> {
    public static func fromJson(json: String): CustomTime {
        return CustomTime.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue): CustomTime {
        return CustomTime(DateTime.parse(json.asObject().get("value").getOrThrow().asString().getValue()[5..]))
    }

    public static func fromJsonValue(json: JsonValue, path: String): CustomTime {
        return fromJsonValue(json)
    }

    public func toJsonValue(): JsonValue {
        var map: HashMap<String, JsonValue> = HashMap()
        let s = "CUST_"
        map.add("value", JsonString(String.join(s, this.value.toString())))
        return JsonObject(map)
    }
}

@JsonSerialize
class ClassWithCustomTimeAdapter {
    public var intVar: Int64 = 10
    public var time: CustomTime = CustomTime(DateTime.now())
}

@Test
class TestCustomAdapter {
    private let JSON_WITH_TIME = """
    {
        "intVar": 10,
        "time": {"value": "CUST_2022-12-21T03:21:51+08:00"}
    }
    """

    @TestCase
    func testCustomTime(): Unit {
        @Assert(
            compactJson(ClassWithCustomTimeAdapter.fromJson(JSON_WITH_TIME).toJson()),
            compactJson(JSON_WITH_TIME)
        )
    }
}
