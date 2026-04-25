package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonTypeInfo}
import json4cj.*

/*
 * Comprehensive test suite for Serde-style enum-based polymorphism.
 * Tests all 4 tagging strategies:
 *   - INTERNAL (default): type field inside object
 *   - EXTERNAL: type name as key, data as value
 *   - ADJACENT: separate type and data fields
 *   - UNTAGGED: no type discriminator
 */

// ========== INTERNAL Strategy (Default) ==========
// Format: {"type":"Dog","v0":"name","v1":"breed"}
@JsonSerialize
@JsonTypeInfo[tag = "type"]
enum InternalAnimal {
    | Dog(String, String)
    | Cat(String, Int64)
}

// ========== EXTERNAL Strategy ==========
// Format: {"Dog":["name","breed"]} or {"Dog":{"name":"value"}}
@JsonSerialize
@JsonTypeInfo[EXTERNAL]
enum ExternalAnimal {
    | Dog(String, String)
    | Cat(String, Int64)
}

// ========== ADJACENT Strategy ==========
// Format: {"type":"Dog","data":{"v0":"name","v1":"breed"}}
@JsonSerialize
@JsonTypeInfo[ADJACENT, tag = "type", content = "data"]
enum AdjacentAnimal {
    | Dog(String, String)
    | Cat(String, Int64)
}

// ========== UNTAGGED Strategy (single variant) ==========
// Format: ["data0","data1"] - no type field
@JsonSerialize
@JsonTypeInfo[UNTAGGED]
enum UntaggedMessage {
    | Data(String, Int64)
}

@Test
public class TestEnumPolymorphism {

    // ============================================
    // INTERNAL Strategy Tests
    // ============================================

    @TestCase
    public func testInternalDogSerialize(): Unit {
        let dog = InternalAnimal.Dog("Buddy", "Labrador")
        let json = dog.toJson()
        println("[INTERNAL] Dog serialized: " + json)

        // Verify JSON structure: {"type":"Dog","v0":"Buddy","v1":"Labrador"}
        @Assert(json.contains("\"type\":\"Dog\""), true)
        @Assert(json.contains("\"v0\":\"Buddy\""), true)
        @Assert(json.contains("\"v1\":\"Labrador\""), true)
    }

    @TestCase
    public func testInternalDogRoundtrip(): Unit {
        let original = InternalAnimal.Dog("Buddy", "Labrador")
        let json = original.toJson()
        let deserialized = InternalAnimal.fromJson(json)

        match (deserialized) {
            case InternalAnimal.Dog(name, breed) =>
                @Assert(name == "Buddy", true)
                @Assert(breed == "Labrador", true)
            case _ =>
                @Assert(false, true)  // Should match Dog pattern
        }
    }

    @TestCase
    public func testInternalCatSerialize(): Unit {
        let cat = InternalAnimal.Cat("Whiskers", 9)
        let json = cat.toJson()
        println("[INTERNAL] Cat serialized: " + json)

        @Assert(json.contains("\"type\":\"Cat\""), true)
        @Assert(json.contains("\"v0\":\"Whiskers\""), true)
        @Assert(json.contains("\"v1\":9"), true)
    }

    @TestCase
    public func testInternalCatRoundtrip(): Unit {
        let original = InternalAnimal.Cat("Whiskers", 9)
        let json = original.toJson()
        let deserialized = InternalAnimal.fromJson(json)

        match (deserialized) {
            case InternalAnimal.Cat(name, lives) =>
                @Assert(name == "Whiskers", true)
                @Assert(lives == 9, true)
            case _ =>
                @Assert(false, true)
        }
    }

    // ============================================
    // EXTERNAL Strategy Tests
    // ============================================

    @TestCase
    public func testExternalDogSerialize(): Unit {
        let dog = ExternalAnimal.Dog("Buddy", "Labrador")
        let json = dog.toJson()
        println("[EXTERNAL] Dog serialized: " + json)

        // Verify JSON structure: {"Dog":["Buddy","Labrador"]}
        @Assert(json.contains("\"Dog\""), true)
        @Assert(json.contains("\"Buddy\""), true)
        @Assert(json.contains("\"Labrador\""), true)
    }

    @TestCase
    public func testExternalDogRoundtrip(): Unit {
        let original = ExternalAnimal.Dog("Buddy", "Labrador")
        let json = original.toJson()
        let deserialized = ExternalAnimal.fromJson(json)

        match (deserialized) {
            case ExternalAnimal.Dog(name, breed) =>
                @Assert(name == "Buddy", true)
                @Assert(breed == "Labrador", true)
            case _ =>
                @Assert(false, true)
        }
    }

    @TestCase
    public func testExternalCatSerialize(): Unit {
        let cat = ExternalAnimal.Cat("Whiskers", 9)
        let json = cat.toJson()
        println("[EXTERNAL] Cat serialized: " + json)

        @Assert(json.contains("\"Cat\""), true)
        @Assert(json.contains("\"Whiskers\""), true)
    }

    @TestCase
    public func testExternalCatRoundtrip(): Unit {
        let original = ExternalAnimal.Cat("Whiskers", 9)
        let json = original.toJson()
        let deserialized = ExternalAnimal.fromJson(json)

        match (deserialized) {
            case ExternalAnimal.Cat(name, lives) =>
                @Assert(name == "Whiskers", true)
                @Assert(lives == 9, true)
            case _ =>
                @Assert(false, true)
        }
    }

    // ============================================
    // ADJACENT Strategy Tests
    // ============================================

    @TestCase
    public func testAdjacentDogSerialize(): Unit {
        let dog = AdjacentAnimal.Dog("Buddy", "Labrador")
        let json = dog.toJson()
        println("[ADJACENT] Dog serialized: " + json)

        // Verify JSON structure: {"type":"Dog","data":{"v0":"Buddy","v1":"Labrador"}}
        @Assert(json.contains("\"type\":\"Dog\""), true)
        @Assert(json.contains("\"data\""), true)
        @Assert(json.contains("\"v0\":\"Buddy\""), true)
        @Assert(json.contains("\"v1\":\"Labrador\""), true)
    }

    @TestCase
    public func testAdjacentDogRoundtrip(): Unit {
        let original = AdjacentAnimal.Dog("Buddy", "Labrador")
        let json = original.toJson()
        let deserialized = AdjacentAnimal.fromJson(json)

        match (deserialized) {
            case AdjacentAnimal.Dog(name, breed) =>
                @Assert(name == "Buddy", true)
                @Assert(breed == "Labrador", true)
            case _ =>
                @Assert(false, true)
        }
    }

    @TestCase
    public func testAdjacentCatSerialize(): Unit {
        let cat = AdjacentAnimal.Cat("Whiskers", 9)
        let json = cat.toJson()
        println("[ADJACENT] Cat serialized: " + json)

        @Assert(json.contains("\"type\":\"Cat\""), true)
        @Assert(json.contains("\"data\""), true)
    }

    @TestCase
    public func testAdjacentCatRoundtrip(): Unit {
        let original = AdjacentAnimal.Cat("Whiskers", 9)
        let json = original.toJson()
        let deserialized = AdjacentAnimal.fromJson(json)

        match (deserialized) {
            case AdjacentAnimal.Cat(name, lives) =>
                @Assert(name == "Whiskers", true)
                @Assert(lives == 9, true)
            case _ =>
                @Assert(false, true)
        }
    }

    // ============================================
    // UNTAGGED Strategy Tests
    // ============================================

    @TestCase
    public func testUntaggedSerialize(): Unit {
        let msg = UntaggedMessage.Data("Alice", 30)
        let json = msg.toJson()
        println("[UNTAGGED] Data serialized: " + json)

        // Verify no type field and correct data
        @Assert(json.contains("\"Alice\""), true)
        @Assert(json.contains("30"), true)
        @Assert(!json.contains("\"type\""), true)  // No type discriminator
    }

    @TestCase
    public func testUntaggedRoundtrip(): Unit {
        let original = UntaggedMessage.Data("Alice", 30)
        let json = original.toJson()
        let deserialized = UntaggedMessage.fromJson(json)

        match (deserialized) {
            case UntaggedMessage.Data(name, age) =>
                @Assert(name == "Alice", true)
                @Assert(age == 30, true)
            case _ =>
                @Assert(false, true)
        }
    }
}
