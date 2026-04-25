package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonTypeInfo, JsonSubTypes, JsonType}
import std.collection.ArrayList
import json4cj.*

// ===== Macro-based polymorphic serialization test =====
// Uses @JsonTypeInfo + @JsonSubTypes on base class, @JsonType on subclass

@JsonSerialize
@JsonTypeInfo[tag = "type"]
@JsonSubTypes["dog" => MacroDog, "cat" => MacroCat]
open class MacroAnimal {
    var name: String = ""
}

@JsonSerialize
@JsonType["dog"]
class MacroDog <: MacroAnimal {
    var breed: String = ""
}

@JsonSerialize
@JsonType["cat"]
class MacroCat <: MacroAnimal {
    var lives: Int64 = 9
}

@Test
public class TestPolymorphicMacro {

    @TestCase
    func testDogToJsonValue(): Unit {
        let dog = MacroDog()
        dog.name = "Buddy"
        dog.breed = "Labrador"

        // Direct call — no dynamic dispatch involved
        let jv = dog.toJsonValue()
        let json = jv.toString()

        @Assert(json.contains("\"type\":\"dog\""), true)
    }

    @TestCase
    func testDogDynamicDispatch(): Unit {
        // Test via base class reference to verify dynamic dispatch
        let dog = MacroDog()
        dog.name = "Buddy"
        dog.breed = "Labrador"
        let animal: MacroAnimal = dog

        let jv = animal.toJsonValue()
        let json = jv.toString()

        @Assert(json.contains("\"type\":\"dog\""), true)
    }

    @TestCase
    func testCatToJsonValue(): Unit {
        let cat = MacroCat()
        cat.name = "Whiskers"
        cat.lives = 7

        let jv = cat.toJsonValue()
        let json = jv.toString()

        @Assert(json.contains("\"type\":\"cat\""), true)
        @Assert(json.contains("\"name\":\"Whiskers\""), true)
        @Assert(json.contains("\"lives\":7"), true)
    }

    @TestCase
    func testDogDeserializationViaBaseClass(): Unit {
        let json = "{\"type\":\"dog\",\"name\":\"Buddy\",\"breed\":\"Labrador\"}"
        let animal = MacroAnimal.fromJson(json)

        @Assert(animal.name, "Buddy")
        let dog = (animal as MacroDog).getOrThrow()
        @Assert(dog.breed, "Labrador")
    }

    @TestCase
    func testCatDeserializationViaBaseClass(): Unit {
        let json = "{\"type\":\"cat\",\"name\":\"Whiskers\",\"lives\":7}"
        let animal = MacroAnimal.fromJson(json)

        @Assert(animal.name, "Whiskers")
        let cat = (animal as MacroCat).getOrThrow()
        @Assert(cat.lives, 7)
    }

    @TestCase
    func testUnknownTypeThrows(): Unit {
        let json = "{\"type\":\"bird\",\"name\":\"Tweety\"}"

        try {
            let _ = MacroAnimal.fromJson(json)
            @Assert(false, true)  // should not reach here
        } catch (e: Exception) {
            @Assert(e.message.contains("unknown"), true)
        }
    }

    @TestCase
    func testMissingDiscriminatorThrows(): Unit {
        let json = "{\"name\":\"Unknown\"}"

        try {
            let _ = MacroAnimal.fromJson(json)
            @Assert(false, true)  // should not reach here
        } catch (e: Exception) {
            @Assert(e.message.contains("missing"), true)
        }
    }

    @TestCase
    func testDogRoundTrip(): Unit {
        let dog = MacroDog()
        dog.name = "Rex"
        dog.breed = "Bulldog"

        let json = dog.toJsonValue().toString()
        @Assert(json.contains("\"type\":\"dog\""), true)

        let restored = MacroAnimal.fromJson(json)

        @Assert(restored.name, "Rex")
        let restoredDog = (restored as MacroDog).getOrThrow()
        @Assert(restoredDog.breed, "Bulldog")
    }

    @TestCase
    func testCatRoundTrip(): Unit {
        let cat = MacroCat()
        cat.name = "Mittens"
        cat.lives = 5

        let json = cat.toJsonValue().toString()
        @Assert(json.contains("\"type\":\"cat\""), true)

        let restored = MacroAnimal.fromJson(json)

        @Assert(restored.name, "Mittens")
        let restoredCat = (restored as MacroCat).getOrThrow()
        @Assert(restoredCat.lives, 5)
    }

    @TestCase
    func testIsTypeCheckAfterDeserialization(): Unit {
        let dogJson = "{\"type\":\"dog\",\"name\":\"Buddy\",\"breed\":\"Labrador\"}"
        let catJson = "{\"type\":\"cat\",\"name\":\"Whiskers\",\"lives\":3}"

        let dogAnimal = MacroAnimal.fromJson(dogJson)
        let catAnimal = MacroAnimal.fromJson(catJson)

        @Assert(dogAnimal is MacroDog, true)
        @Assert(catAnimal is MacroCat, true)
        @Assert(dogAnimal is MacroCat, false)
        @Assert(catAnimal is MacroDog, false)
    }

    @TestCase
    func testArrayListOfPolymorphicTypes(): Unit {
        var animals = ArrayList<MacroAnimal>()

        let dog = MacroDog()
        dog.name = "Buddy"
        dog.breed = "Labrador"
        animals.add(dog)

        let cat = MacroCat()
        cat.name = "Whiskers"
        cat.lives = 7
        animals.add(cat)

        @Assert(animals.size, 2)
        @Assert(animals[0] is MacroDog, true)
        @Assert(animals[1] is MacroCat, true)
    }

    @TestCase
    func testBaseClassToJsonValue(): Unit {
        // Base class instance with default type discriminator
        let animal = MacroAnimal()
        animal.name = "Generic"

        let json = animal.toJsonValue().toString()
        @Assert(json.contains("\"type\":\"macroAnimal\""), true)
        @Assert(json.contains("\"name\":\"Generic\""), true)
    }
}
