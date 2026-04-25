package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
class NestedChild {
    public var c1: Int64 = 1
}

@JsonSerialize
class NestedParent {
    public var p1: String = "v1"
    public var nested: Option<NestedChild> = NestedChild()
}

@Test
public class TestNested {
    private let NESTED_JSON = """
    {
        "p1": "v1",
        "nested": {"c1": 10}
    }
    """
    private let NESTED_JSON2 = """
    {
        "p1": "v1",
        "nested": null
    }
    """
    @TestCase
    func testNestedFromJson(): Unit {
        var parent = NestedParent()
        var jsonValues = JsonValue.fromStr(NESTED_JSON).asObject()
        parent.p1 = jsonValues.get("p1").getOrThrow().asString().getValue()

        parent.nested = NestedChild()
        var nestedJson = jsonValues.get("nested").getOrThrow().asObject()
        parent.nested?.c1 = nestedJson.get("c1").getOrThrow().asInt().getValue()

        var parent1 = NestedParent.fromJson(NESTED_JSON)
        @Assert(parent.p1, parent1.p1)
        @Assert(parent.nested?.c1, parent1.nested?.c1)
    }

    @TestCase
    func testNestedToJson(): Unit {
        @Assert(
            compactJson(NestedParent.fromJson(NESTED_JSON).toJson()),
            compactJson(NESTED_JSON)
        )
        @Assert(
            compactJson(NestedParent.fromJson(NESTED_JSON2).toJson()),
            compactJson(NESTED_JSON2)
        )
    }
}
