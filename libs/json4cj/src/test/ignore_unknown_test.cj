package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonIgnoreUnknown}
import json4cj.*

// Class annotated with @JsonIgnoreUnknown(true) - explicitly opts in to ignoring unknown fields
@JsonSerialize
@JsonIgnoreUnknown[true]
class ClassWithIgnoreUnknown {
    public var name: String = ""
    public var age: Int64 = 0
}

// Class with strict mode - throws on unknown fields
@JsonSerialize
@JsonIgnoreUnknown[false]
class ClassWithStrictMode {
    public var name: String = ""
    public var age: Int64 = 0
}

// Class without @JsonIgnoreUnknown - default behavior ignores unknown fields
@JsonSerialize
class ClassWithoutIgnoreUnknown {
    public var name: String = ""
    public var age: Int64 = 0
}

@Test
public class TestIgnoreUnknown {
    // JSON with extra unknown fields
    private let JSON_WITH_EXTRA_FIELDS = """
    {
        "name": "Alice",
        "age": 25,
        "email": "alice@example.com",
        "address": "123 Main St",
        "phone": "555-1234"
    }
    """

    // JSON with only known fields
    private let JSON_WITH_KNOWN_FIELDS = """
    {
        "name": "Bob",
        "age": 30
    }
    """

    @TestCase
    func testIgnoreUnknownDeserialization(): Unit {
        // With @JsonIgnoreUnknown(true): extra fields are silently ignored
        let obj = ClassWithIgnoreUnknown.fromJson(JSON_WITH_EXTRA_FIELDS)
        @Assert(obj.name, "Alice")
        @Assert(obj.age, 25)
    }

    @TestCase
    func testIgnoreUnknownSerialization(): Unit {
        // With @JsonIgnoreUnknown(true): serialization only includes known fields
        let obj = ClassWithIgnoreUnknown.fromJson(JSON_WITH_EXTRA_FIELDS)
        let json = obj.toJson()
        @Assert(json.contains("\"name\""), true)
        @Assert(json.contains("\"age\""), true)
        @Assert(!json.contains("email"), true)
        @Assert(!json.contains("address"), true)
        @Assert(!json.contains("phone"), true)
    }

    @TestCase
    func testIgnoreUnknownRoundTrip(): Unit {
        // Round-trip: extra fields are stripped
        let obj = ClassWithIgnoreUnknown.fromJson(JSON_WITH_EXTRA_FIELDS)
        let roundTrip = ClassWithIgnoreUnknown.fromJson(obj.toJson())
        @Assert(roundTrip.name, "Alice")
        @Assert(roundTrip.age, 25)
    }

    @TestCase
    func testWithoutIgnoreUnknownAlsoIgnoresExtraFields(): Unit {
        // Default behavior: unknown fields are ignored (backward compatible)
        let obj = ClassWithoutIgnoreUnknown.fromJson(JSON_WITH_EXTRA_FIELDS)
        @Assert(obj.name, "Alice")
        @Assert(obj.age, 25)
    }

    @TestCase
    func testStrictModeAcceptsKnownFields(): Unit {
        // With @JsonIgnoreUnknown(false): known fields work fine
        let obj = ClassWithStrictMode.fromJson(JSON_WITH_KNOWN_FIELDS)
        @Assert(obj.name, "Bob")
        @Assert(obj.age, 30)
    }

    @TestCase
    func testStrictModeRejectsUnknownFields(): Unit {
        // With @JsonIgnoreUnknown(false): all unknown fields collected and thrown together
        var exceptionMessage = ""
        try {
            ClassWithStrictMode.fromJson(JSON_WITH_EXTRA_FIELDS)
        } catch (e: Exception) {
            exceptionMessage = e.message
        }
        @Assert(exceptionMessage.contains("email"), true)
        @Assert(exceptionMessage.contains("address"), true)
        @Assert(exceptionMessage.contains("phone"), true)
        @Assert(exceptionMessage.contains("unknown fields"), true)
        @Assert(exceptionMessage.contains("$"), true)
    }
}
