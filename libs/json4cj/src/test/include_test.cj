package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonInclude}
import std.collection.{ArrayList, HashMap}
import json4cj.*

// ALWAYS mode (default) - all fields included, Option None emits null
@JsonSerialize
@JsonInclude[ALWAYS]
class ClassWithAlways {
    public var name: String = ""
    public var bio: Option<String> = None
}

// NON_NULL mode - Option None fields are skipped
@JsonSerialize
@JsonInclude[NON_NULL]
class ClassWithNonNull {
    public var name: String = ""
    public var bio: Option<String> = None
    public var age: Option<Int64> = None
}

// NON_EMPTY mode - Option None, empty String, empty collections are skipped
@JsonSerialize
@JsonInclude[NON_EMPTY]
class ClassWithNonEmpty {
    public var name: String = ""
    public var bio: Option<String> = None
    public var tags: ArrayList<String> = ArrayList<String>()
    public var metadata: HashMap<String, String> = HashMap<String, String>()
    public var age: Option<Int64> = None
}

@Test
public class TestJsonInclude {
    @TestCase
    func testAlwaysModeIncludesNull(): Unit {
        let obj = ClassWithAlways()
        obj.name = "Alice"
        obj.bio = None
        let json = obj.toJson()
        // ALWAYS: null Option should emit "bio": null
        @Assert(json.contains("\"bio\""), true)
        @Assert(json.contains("null"), true)
    }

    @TestCase
    func testNonNullModeSkipsNone(): Unit {
        let obj = ClassWithNonNull()
        obj.name = "Alice"
        obj.bio = None
        obj.age = None
        let json = obj.toJson()
        // NON_NULL: None fields should be skipped entirely
        @Assert(!json.contains("\"bio\""), true)
        @Assert(!json.contains("\"age\""), true)
        @Assert(json.contains("\"name\""), true)
    }

    @TestCase
    func testNonNullModeIncludesSome(): Unit {
        let obj = ClassWithNonNull()
        obj.name = "Alice"
        obj.bio = Some("Hello")
        obj.age = Some(25)
        let json = obj.toJson()
        // NON_NULL: Some fields should be included
        @Assert(json.contains("\"bio\""), true)
        @Assert(json.contains("\"age\""), true)
        @Assert(json.contains("Hello"), true)
    }

    @TestCase
    func testNonEmptyModeSkipsAllEmpty(): Unit {
        let obj = ClassWithNonEmpty()
        obj.name = ""
        obj.bio = None
        obj.tags = ArrayList<String>()
        obj.metadata = HashMap<String, String>()
        obj.age = None
        let json = obj.toJson()
        // NON_EMPTY: empty String, None, empty collections all skipped
        @Assert(!json.contains("\"name\""), true)
        @Assert(!json.contains("\"bio\""), true)
        @Assert(!json.contains("\"tags\""), true)
        @Assert(!json.contains("\"metadata\""), true)
        @Assert(!json.contains("\"age\""), true)
    }

    @TestCase
    func testNonEmptyModeIncludesNonEmpty(): Unit {
        let obj = ClassWithNonEmpty()
        obj.name = "Alice"
        obj.bio = Some("Hello")
        obj.tags.add("tag1")
        obj.metadata.add("key1", "val1")
        obj.age = Some(25)
        let json = obj.toJson()
        // NON_EMPTY: non-empty fields should be included
        @Assert(json.contains("\"name\""), true)
        @Assert(json.contains("\"bio\""), true)
        @Assert(json.contains("\"tags\""), true)
        @Assert(json.contains("\"metadata\""), true)
        @Assert(json.contains("\"age\""), true)
    }

    @TestCase
    func testNonEmptyModePartialEmpty(): Unit {
        let obj = ClassWithNonEmpty()
        obj.name = "Alice"
        obj.bio = None
        obj.tags.add("tag1")
        obj.metadata = HashMap<String, String>()
        obj.age = None
        let json = obj.toJson()
        // NON_EMPTY: only non-empty fields
        @Assert(json.contains("\"name\""), true)
        @Assert(json.contains("\"tags\""), true)
        @Assert(!json.contains("\"bio\""), true)
        @Assert(!json.contains("\"metadata\""), true)
        @Assert(!json.contains("\"age\""), true)
    }
}
