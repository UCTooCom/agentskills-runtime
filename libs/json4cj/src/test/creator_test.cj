package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonCreator}
import json4cj.*

// Class with let fields + @JsonCreator for constructor-based deserialization
@JsonSerialize
@JsonCreator
class ImmutableUser {
    public let name: String
    public let age: Int64

    public init(name: String, age: Int64) {
        this.name = name
        this.age = age
    }
}

// Class with mixed let/var fields + @JsonCreator
@JsonSerialize
@JsonCreator
class MixedUser {
    public let id: String
    public let name: String
    public var score: Int64

    public init(id: String, name: String, score: Int64) {
        this.id = id
        this.name = name
        this.score = score
    }
}

@Test
public class TestJsonCreator {
    private let JSON_USER = """
    {
        "name": "Alice",
        "age": 25
    }
    """

    private let JSON_MIXED = """
    {
        "id": "u001",
        "name": "Bob",
        "score": 88
    }
    """

    @TestCase
    func testCreatorDeserialize(): Unit {
        let user = ImmutableUser.fromJson(JSON_USER)
        @Assert(user.name, "Alice")
        @Assert(user.age, 25)
    }

    @TestCase
    func testCreatorSerialize(): Unit {
        let user = ImmutableUser("Charlie", 30)
        let json = user.toJson()
        @Assert(json.contains("\"name\""), true)
        @Assert(json.contains("\"age\""), true)
        @Assert(json.contains("Charlie"), true)
    }

    @TestCase
    func testCreatorRoundTrip(): Unit {
        let user = ImmutableUser.fromJson(JSON_USER)
        let json = user.toJson()
        let roundTrip = ImmutableUser.fromJson(json)
        @Assert(roundTrip.name, "Alice")
        @Assert(roundTrip.age, 25)
    }

    @TestCase
    func testMixedLetVarDeserialize(): Unit {
        let user = MixedUser.fromJson(JSON_MIXED)
        @Assert(user.id, "u001")
        @Assert(user.name, "Bob")
        @Assert(user.score, 88)
    }

    @TestCase
    func testMixedLetVarRoundTrip(): Unit {
        let user = MixedUser.fromJson(JSON_MIXED)
        user.score = 99 // var field is mutable
        let json = user.toJson()
        let roundTrip = MixedUser.fromJson(json)
        @Assert(roundTrip.id, "u001")
        @Assert(roundTrip.name, "Bob")
        @Assert(roundTrip.score, 99)
    }
}
