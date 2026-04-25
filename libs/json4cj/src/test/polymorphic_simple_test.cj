package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import json4cj.JsonCodec
internal import stdx.encoding.json.{JsonValue, JsonString, JsonObject, JsonNull}
import json4cj.*

// ===== Polymorphic serialization test with class inheritance =====

// ===== Base class (must be open for inheritance) =====

open class Pet <: JsonCodec<Pet> {
    public var name: String = ""

    public static func fromJson(json: String): Pet {
        return Pet.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue): Pet {
        return Pet.fromJsonValue(json, "$")
    }

    public static func fromJsonValue(json: JsonValue, _path: String): Pet {
        let jsonObject = json.asObject()
        
        // Extract discriminator
        var typeStr = ""
        match (jsonObject.get("type")) {
            case Some(typeValue) => typeStr = (typeValue as JsonString).getOrThrow().getValue()
            case None => throw Exception("Missing type discriminator")
        }
        
        // Dispatch to concrete type using covariant return
        if (typeStr == "dog") {
            return DogPet.fromJsonValue(json, _path)
        } else if (typeStr == "cat") {
            return CatPet.fromJsonValue(json, _path)
        } else {
            throw Exception("Unknown animal type: " + typeStr)
        }
    }

    public open func toJsonValue(): JsonValue {
        var map: HashMap<String, JsonValue> = HashMap()
        map.add("type", JsonString("animal"))
        map.add("name", JsonString(this.name))
        return JsonObject(map)
    }

    public func toJson(): String {
        this.toJsonValue().toString()
    }
}

// ===== Dog (subclass) =====

class DogPet <: Pet {
    public var breed: String = ""

    public static func fromJson(json: String): DogPet {
        return DogPet.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue): DogPet {
        return DogPet.fromJsonValue(json, "$")
    }

    public static func fromJsonValue(json: JsonValue, _path: String): DogPet {
        let jsonObject = json.asObject()
        var ret = DogPet()
        
        if (jsonObject.getFields().contains("name")) {
            ret.name = jsonObject.get("name").getOrThrow().asString().getValue()
        }
        if (jsonObject.getFields().contains("breed")) {
            ret.breed = jsonObject.get("breed").getOrThrow().asString().getValue()
        }
        
        return ret
    }

    public func toJsonValue(): JsonValue {
        var map: HashMap<String, JsonValue> = HashMap()
        map.add("type", JsonString("dog"))
        map.add("name", JsonString(this.name))
        map.add("breed", JsonString(this.breed))
        return JsonObject(map)
    }
}

// ===== Cat (subclass) =====

class CatPet <: Pet {
    public var lives: String = "9"

    public static func fromJson(json: String): CatPet {
        return CatPet.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue): CatPet {
        return CatPet.fromJsonValue(json, "$")
    }

    public static func fromJsonValue(json: JsonValue, _path: String): CatPet {
        let jsonObject = json.asObject()
        var ret = CatPet()
        
        if (jsonObject.getFields().contains("name")) {
            ret.name = jsonObject.get("name").getOrThrow().asString().getValue()
        }
        if (jsonObject.getFields().contains("lives")) {
            ret.lives = jsonObject.get("lives").getOrThrow().asString().getValue()
        }
        
        return ret
    }

    public func toJsonValue(): JsonValue {
        var map: HashMap<String, JsonValue> = HashMap()
        map.add("type", JsonString("cat"))
        map.add("name", JsonString(this.name))
        map.add("lives", JsonString(this.lives))
        return JsonObject(map)
    }
}

// ===== Tests =====

@Test
public class TestPolymorphicSimple {
    
    @TestCase
    func testDogSerialization(): Unit {
        let dog = DogPet()
        dog.name = "Buddy"
        dog.breed = "Labrador"
        
        let json = dog.toJson()
        
        @Assert(json.contains("\"type\":\"dog\""), true)
        @Assert(json.contains("\"name\":\"Buddy\""), true)
        @Assert(json.contains("\"breed\":\"Labrador\""), true)
    }

    @TestCase
    func testCatSerialization(): Unit {
        let cat = CatPet()
        cat.name = "Whiskers"
        cat.lives = "7"
        
        let json = cat.toJson()
        
        @Assert(json.contains("\"type\":\"cat\""), true)
        @Assert(json.contains("\"name\":\"Whiskers\""), true)
        @Assert(json.contains("\"lives\":\"7\""), true)
    }

    @TestCase
    func testDogDeserializationViaBaseClass(): Unit {
        let json = "{\"type\":\"dog\",\"name\":\"Buddy\",\"breed\":\"Labrador\"}"
        let pet = Pet.fromJson(json)
        
        @Assert(pet.name, "Buddy")
    }

    @TestCase
    func testCatDeserializationViaBaseClass(): Unit {
        let json = "{\"type\":\"cat\",\"name\":\"Whiskers\",\"lives\":\"7\"}"
        let pet = Pet.fromJson(json)
        
        @Assert(pet.name, "Whiskers")
    }

    @TestCase
    func testUnknownType(): Unit {
        let json = "{\"type\":\"bird\",\"name\":\"Tweety\"}"
        
        try {
            let pet = Pet.fromJson(json)
            @Assert(false, true)
        } catch (e: Exception) {
            @Assert(e.message.contains("Unknown animal type: bird"), true)
        }
    }

    @TestCase
    func testMissingDiscriminator(): Unit {
        let json = "{\"name\":\"Unknown\"}"
        
        try {
            let pet = Pet.fromJson(json)
            @Assert(false, true)
        } catch (e: Exception) {
            @Assert(e.message.contains("Missing type discriminator"), true)
        }
    }

    @TestCase
    func testPolymorphicRoundTrip(): Unit {
        let originalDog = DogPet()
        originalDog.name = "Rex"
        originalDog.breed = "Bulldog"
        
        let dogJson = originalDog.toJson()
        let restoredDog = Pet.fromJson(dogJson)
        
        @Assert(restoredDog.name, "Rex")
        
        let originalCat = CatPet()
        originalCat.name = "Mittens"
        originalCat.lives = "5"
        
        let catJson = originalCat.toJson()
        let restoredCat = Pet.fromJson(catJson)
        
        @Assert(restoredCat.name, "Mittens")
    }
}
