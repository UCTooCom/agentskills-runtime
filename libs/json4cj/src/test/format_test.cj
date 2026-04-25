package json4cj.test

import std.time.DateTime
internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonFormat}
import json4cj.*

@JsonSerialize
class ClassWithDateFormat {
    public var name: String = ""
    @JsonFormat["yyyy-MM-dd"]
    public var date: DateTime = DateTime.now()
}

@JsonSerialize
class ClassWithDateTimeFormat {
    public var title: String = ""
    @JsonFormat["yyyy/MM/dd HH:mm:ss"]
    public var startTime: DateTime = DateTime.now()
}

@Test
public class TestJsonFormat {
    @TestCase
    func testDateFormatSerialization(): Unit {
        let obj = ClassWithDateFormat()
        obj.name = "Event1"
        obj.date = DateTime.parse("2025-07-15T00:00:00+00:00")
        let json = obj.toJson()
        @Assert(json.contains("\"2025-07-15\""), true)
        @Assert(!json.contains("T00:00:00"), true)
    }

    @TestCase
    func testDateFormatDeserialization(): Unit {
        let obj = ClassWithDateFormat.fromJson(
            """
        {
            "name": "Event2",
            "date": "2025-07-15"
        }
        """)
        @Assert(obj.name, "Event2")
        @Assert(obj.date.year, 2025)
    }

    @TestCase
    func testDateFormatRoundTrip(): Unit {
        let obj = ClassWithDateFormat()
        obj.name = "Event3"
        obj.date = DateTime.parse("2025-03-20T10:30:00+08:00")
        let json = obj.toJson()
        let roundTrip = ClassWithDateFormat.fromJson(json)
        @Assert(roundTrip.name, "Event3")
        @Assert(roundTrip.date.year, 2025)
    }

    @TestCase
    func testDateTimeFormatSerialization(): Unit {
        let obj = ClassWithDateTimeFormat()
        obj.title = "Meeting"
        obj.startTime = DateTime.parse("2025-07-15T14:30:00+08:00")
        let json = obj.toJson()
        @Assert(json.contains("2025/07/15"), true)
        @Assert(json.contains("14:30:00"), true)
    }

    @TestCase
    func testDateTimeFormatDeserialization(): Unit {
        let obj = ClassWithDateTimeFormat.fromJson(
            """
        {
            "title": "Workshop",
            "startTime": "2025/12/25 09:00:00"
        }
        """)
        @Assert(obj.title, "Workshop")
        @Assert(obj.startTime.year, 2025)
    }
}
