package json4cj.test

import std.time.DateTime
internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonDeserialize}
import json4cj.*

class Int64JsonSerializer <: JsonValueSerializable<Int64> {
    public Int64JsonSerializer(let value: Int64) {
    }

    public static func fromJsonValue(json: JsonValue): Int64 {
        return json.asInt().getValue() * 100
    }

    public static func fromJsonValue(json: JsonValue, path: String): Int64 {
        return fromJsonValue(json)
    }

    public func toJsonValue(): JsonValue {
        return JsonInt(this.value / 100)
    }
}

class DateTimeJsonSerializer <: JsonValueSerializable<DateTime> {
    public DateTimeJsonSerializer(let value: DateTime) {
    }

    public static func fromJsonValue(json: JsonValue): DateTime {
        let time = DateTime.parse(json.asString().getValue())
        return time.addYears(-1)
    }

    public static func fromJsonValue(json: JsonValue, path: String): DateTime {
        return fromJsonValue(json)
    }

    public func toJsonValue(): JsonValue {
        return JsonString(this.value.addYears(1).toString())
    }
}

@JsonSerialize
public class DeserializeTest {
    @JsonDeserialize[Int64JsonSerializer]
    var count: Int64 = 99

    @JsonDeserialize[DateTimeJsonSerializer]
    var time: DateTime = DateTime.now()
}

@Test
public class TestDeserialize {
    private let DESERIALIZE_TEST_JSON = """
    {
        "count": 88,
        "time": "2023-12-25T00:00:00+01:00"
    }
    """
    @TestCase
    func testDeserializeFromJson(): Unit {
        let result = DeserializeTest.fromJson(DESERIALIZE_TEST_JSON)
        @Assert(result.count, 8800)
        @Assert(result.time.year, 2022)
    }

    @TestCase
    func testDeserializeToJson(): Unit {
        @Assert(
            compactJson(DeserializeTest.fromJson(DESERIALIZE_TEST_JSON).toJson()),
            compactJson(DESERIALIZE_TEST_JSON)
        )
    }
}
