package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
struct StructInTest {
    var name: String = "name"
    var age: Int64 = 0
}

@Test
class TestStruct {
    private let JSON = """
    {
        "name": "new name",
        "age": 18
    }
    """

    // TODO: fix type mismatch issue with age below (int vs string),
    //in this case, deserialized age value will be default value 0, not 18
    //the expected behavior would be either throw or 18
    //private let JSON = "{\"name\":\"new name\",\"age\":\"18\"}"

    @TestCase
    func testTime(): Unit {
        @Assert(
            compactJson(StructInTest.fromJson(JSON).toJson()),
            compactJson(JSON)
        )
    }
}
