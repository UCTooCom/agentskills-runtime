package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
class ClassWithNestedCollection {
    public var p1: String = "v1"
    public var p2: Int64 = 1
    public var array: ArrayList<ArrayList<String>> = ArrayList<ArrayList<String>>()
    //add two elements
    public var mapWithArrayList: HashMap<String, ArrayList<Int64>> = HashMap<String, ArrayList<Int64>>()
}

@Test
class TestNestedCollection {
    private let JSON_WITH_COLLECTION = """
    {
        "p1": "v1",
        "p2": 299,
        "array": [["8"], ["7"], ["999", "25"]],
        "mapWithArrayList": {"key1": [1, 2, 3], "key2": [4, 5, 6]}
    }
    """

    @TestCase
    func testToJson(): Unit {
        @Assert(
            compactJson(ClassWithNestedCollection.fromJson(JSON_WITH_COLLECTION).toJson()),
            compactJson(JSON_WITH_COLLECTION)
        )
    }
}
