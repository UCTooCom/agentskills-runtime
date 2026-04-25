package json4cj.test

import std.time.DateTime
internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
class ClassWithTime {
    public var intVar: Int64 = 10
    public var time: DateTime = DateTime.now()
}

@Test
class TestTime {
    private let JSON_WITH_TIME = """
    {
        "intVar": 20,
        "time": "2025-12-31T12:12:12+01:00"
    }
    """

    @TestCase
    func testTime(): Unit {
        @Assert(
            compactJson(ClassWithTime.fromJson(JSON_WITH_TIME).toJson()),
            compactJson(JSON_WITH_TIME)
        )
    }
}
