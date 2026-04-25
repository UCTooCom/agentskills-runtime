package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonProperty, JsonIgnore, JsonDeserialize}
import json4cj.*

// ===== Class A: uses @JsonProperty only =====
@JsonSerialize
class IsolationClassA {
    @JsonProperty["user_name"]
    public var name: String = ""

    public var age: Int64 = 0
}

// ===== Class B: uses @JsonIgnore only =====
@JsonSerialize
class IsolationClassB {
    public var name: String = ""

    @JsonIgnore
    public var secret: String = "hidden"

    public var age: Int64 = 0
}

// ===== Class C: uses both @JsonProperty and @JsonIgnore =====
@JsonSerialize
class IsolationClassC {
    @JsonProperty["full_name"]
    public var name: String = ""

    @JsonIgnore
    public var internalId: String = "id_default"

    public var age: Int64 = 0
}

// ===== Class D: uses @JsonDeserialize =====
class IsolationInt64Adapter <: JsonValueSerializable<Int64> {
    public IsolationInt64Adapter(let value: Int64) {
    }

    public static func fromJsonValue(json: JsonValue): Int64 {
        return json.asInt().getValue() * 10
    }

    public static func fromJsonValue(json: JsonValue, _path: String): Int64 {
        return fromJsonValue(json)
    }

    public func toJsonValue(): JsonValue {
        return JsonInt(this.value / 10)
    }
}

@JsonSerialize
class IsolationClassD {
    public var name: String = ""

    @JsonDeserialize[IsolationInt64Adapter]
    public var score: Int64 = 0
}

// ===== Class E: plain class, no special annotations =====
@JsonSerialize
class IsolationClassE {
    public var name: String = ""
    public var age: Int64 = 0
}

@Test
public class TestIsolation {
    private let JSON_A = """
    {
        "user_name": "Alice",
        "age": 25
    }
    """
    private let JSON_B = """
    {
        "name": "Bob",
        "secret": "leaked",
        "age": 30
    }
    """
    private let JSON_C = """
    {
        "full_name": "Charlie",
        "internalId": "should_be_ignored",
        "age": 35
    }
    """
    private let JSON_D = """
    {
        "name": "Dave",
        "score": 5
    }
    """
    private let JSON_E = """
    {
        "name": "Eve",
        "age": 40
    }
    """
    private let JSON_MULTI_A = """
    {
        "user_name": "A",
        "age": 1
    }
    """
    private let JSON_MULTI_B = """
    {
        "name": "B",
        "age": 2,
        "secret": "x"
    }
    """
    private let JSON_MULTI_C = """
    {
        "full_name": "C",
        "age": 3,
        "internalId": "y"
    }
    """
    private let JSON_MULTI_D = """
    {
        "name": "D",
        "score": 7
    }
    """
    private let JSON_MULTI_E = """
    {
        "name": "E",
        "age": 5
    }
    """

    // Test: ClassA's @JsonProperty does not leak to ClassB
    @TestCase
    func testPropertyIsolation(): Unit {
        let a = IsolationClassA.fromJson(JSON_A)
        @Assert(a.name, "Alice")
        @Assert(a.age, 25)

        // ClassA serializes with mapped name "user_name"
        let aJson = a.toJson()
        @Assert(aJson.contains("user_name"), true)
        @Assert(aJson.contains("\"name\""), false)
    }

    // Test: ClassB's @JsonIgnore does not leak to ClassA or ClassE
    @TestCase
    func testIgnoreIsolation(): Unit {
        let b = IsolationClassB.fromJson(JSON_B)
        @Assert(b.name, "Bob")
        @Assert(b.age, 30)
        // secret should retain default value since @JsonIgnore
        @Assert(b.secret, "hidden")

        // ClassB serializes without "secret"
        let bJson = b.toJson()
        @Assert(!bJson.contains("secret"), true)
        @Assert(bJson.contains("name"), true)
    }

    // Test: ClassC's @JsonProperty and @JsonIgnore both work independently
    @TestCase
    func testCombinedIsolation(): Unit {
        let c = IsolationClassC.fromJson(JSON_C)
        @Assert(c.name, "Charlie")
        @Assert(c.age, 35)
        // internalId should retain default since @JsonIgnore
        @Assert(c.internalId, "id_default")

        // ClassC serializes with "full_name" and without "internalId"
        let cJson = c.toJson()
        @Assert(cJson.contains("full_name"), true)
        @Assert(!cJson.contains("internalId"), true)
        @Assert(!cJson.contains("\"name\""), true)
    }

    // Test: ClassD's @JsonDeserialize works independently
    @TestCase
    func testDeserializeIsolation(): Unit {
        let d = IsolationClassD.fromJson(JSON_D)
        @Assert(d.name, "Dave")
        // score should be 5 * 10 = 50 due to adapter
        @Assert(d.score, 50)

        // Round-trip: score 50 -> adapter divides by 10 -> "score":5
        let dJson = d.toJson()
        @Assert(dJson.contains("\"score\":5"), true)
    }

    // Test: ClassE (plain) is not affected by any other class's annotations
    @TestCase
    func testPlainClassIsolation(): Unit {
        let e = IsolationClassE.fromJson(JSON_E)
        @Assert(e.name, "Eve")
        @Assert(e.age, 40)

        // ClassE serializes with original field names, no aliases
        let eJson = e.toJson()
        @Assert(eJson.contains("\"name\""), true)
        @Assert(eJson.contains("\"age\""), true)
    }

    // Test: Multiple classes can be used in the same scope without interference
    @TestCase
    func testMultipleClassesNoCrossContamination(): Unit {
        // All classes used in same function - verifies no global state leaks
        let a = IsolationClassA.fromJson(JSON_MULTI_A)
        let b = IsolationClassB.fromJson(JSON_MULTI_B)
        let c = IsolationClassC.fromJson(JSON_MULTI_C)
        let d = IsolationClassD.fromJson(JSON_MULTI_D)
        let e = IsolationClassE.fromJson(JSON_MULTI_E)

        // A: uses user_name alias
        @Assert(a.toJson().contains("user_name"), true)
        @Assert(a.toJson().contains("\"name\""), false)

        // B: hides secret
        @Assert(!b.toJson().contains("secret"), true)
        @Assert(b.toJson().contains("\"name\""), true)

        // C: full_name alias + hides internalId
        @Assert(c.toJson().contains("full_name"), true)
        @Assert(!c.toJson().contains("internalId"), true)

        // D: custom adapter (score 7 -> fromJson gives 70, toJson gives 7)
        @Assert(d.score, 70)

        // E: plain, all fields present
        @Assert(e.toJson().contains("\"name\""), true)
        @Assert(e.toJson().contains("\"age\""), true)
    }
}
