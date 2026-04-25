package json4cj.test

import std.unittest.testmacro.{Test, TestCase, Assert}
internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.JsonSerialize
import json4cj.*

// Helper: normalize JSON string for comparison by removing whitespace between tokens
func compactJson(json: String): String {
    var result = StringBuilder()
    var inString = false
    var i = 0
    let chars = json.toRuneArray()
    while (i < chars.size) {
        let c = chars[i]
        let cs = String(c)
        if (cs == "\\" && inString && i + 1 < chars.size) {
            result.append(cs)
            result.append(String(chars[i + 1]))
            i += 2
            continue
        }
        if (cs == "\"") {
            inString = !inString
        }
        if (!inString && (cs == " " || cs == "\n" || cs == "\r" || cs == "\t")) {
            i += 1
            continue
        }
        result.append(cs)
        i += 1
    }
    result.toString()
}

@JsonSerialize
class MyInstance {
    var myName: String = "MyName"
    var myAge: Int64 = 88
}

@JsonSerialize
class ClassWithCollection {
    public var p1: String = "v1"
    public var p2: Int64 = 1
    public var array: ArrayList<String> = ArrayList<String>()
    public var instances: ArrayList<MyInstance> = ArrayList<MyInstance>([MyInstance()])
    public var map: HashMap<String, Int64> = HashMap<String, Int64>([("k1", 1), ("k2", 2), ("k3", 3), ("k4", 4),
        ("k5", 5)])
}

@Test
class TestCollection {
    private let JSON_WITH_COLLECTION = """
    {
        "p1": "v1",
        "p2": 299,
        "array": ["8", "7"],
        "instances": [{"myName": "MyName", "myAge": 88}],
        "map": {"k1": 1, "k2": 2, "k3": 3, "k4": 4, "k5": 5}
    }
    """

    @TestCase
    func testToJson(): Unit {
        @Assert(compactJson(ClassWithCollection.fromJson(JSON_WITH_COLLECTION).toJson()),
            compactJson(JSON_WITH_COLLECTION))
    }
}

@JsonSerialize
class ClassWithMoreTypeOfCollections {
    public var stringArray: ArrayList<String> = ArrayList<String>()
    public var int64Set: HashSet<Int64> = HashSet<Int64>()
    public var boolArray: ArrayList<Bool> = ArrayList<Bool>()
    public var float64Set: HashSet<Float64> = HashSet<Float64>()
}

@Test
class TestMoreTypeOfCollections {
    private let JSON_WITH_COLLECTION = """
    {
        "stringArray": ["8", "7"],
        "int64Set": [88, 109],
        "boolArray": [false, true, false],
        "float64Set": [88.8, -111.092]
    }
    """

    @TestCase
    func testToJson(): Unit {
        @Assert(compactJson(ClassWithMoreTypeOfCollections.fromJson(JSON_WITH_COLLECTION).toJson()),
            compactJson(JSON_WITH_COLLECTION))
    }
}
