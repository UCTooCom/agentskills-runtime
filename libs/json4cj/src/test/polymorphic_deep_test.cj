package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.{ArrayList, HashMap}
import json4cj.JsonCodec
internal import stdx.encoding.json.{JsonValue, JsonString, JsonObject, JsonNull}
import json4cj.*

// ===== Deep analysis of polymorphic implementation issues =====
// Testing all critical aspects for @JsonTypeInfo feasibility

// ===== Base class =====

open class GeoShape <: JsonCodec<GeoShape> {
    public var name: String = ""

    public static func fromJson(json: String): GeoShape {
        return GeoShape.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue): GeoShape {
        return GeoShape.fromJsonValue(json, "$")
    }

    public static func fromJsonValue(json: JsonValue, _path: String): GeoShape {
        let jsonObject = json.asObject()
        
        var typeStr = ""
        match (jsonObject.get("shapeType")) {
            case Some(typeValue) => typeStr = (typeValue as JsonString).getOrThrow().getValue()
            case None => throw Exception("Missing shapeType discriminator")
        }
        
        if (typeStr == "circle") {
            return GeoCircle.fromJsonValue(json, _path)
        } else if (typeStr == "rect") {
            return GeoRect.fromJsonValue(json, _path)
        } else {
            throw Exception("Unknown shape type: " + typeStr)
        }
    }

    public open func toJsonValue(): JsonValue {
        var map: HashMap<String, JsonValue> = HashMap()
        map.add("shapeType", JsonString("shape"))
        map.add("name", JsonString(this.name))
        return JsonObject(map)
    }

    public func toJson(): String {
        this.toJsonValue().toString()
    }
}

// ===== Subclass: GeoCircle =====

class GeoCircle <: GeoShape {
    public var radius: String = "0"

    public static func fromJson(json: String): GeoCircle {
        return GeoCircle.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue): GeoCircle {
        return GeoCircle.fromJsonValue(json, "$")
    }

    public static func fromJsonValue(json: JsonValue, _path: String): GeoCircle {
        let jsonObject = json.asObject()
        var ret = GeoCircle()
        
        if (jsonObject.getFields().contains("name")) {
            ret.name = jsonObject.get("name").getOrThrow().asString().getValue()
        }
        if (jsonObject.getFields().contains("radius")) {
            ret.radius = jsonObject.get("radius").getOrThrow().asString().getValue()
        }
        
        return ret
    }

    public func toJsonValue(): JsonValue {
        var map: HashMap<String, JsonValue> = HashMap()
        map.add("shapeType", JsonString("circle"))
        map.add("name", JsonString(this.name))
        map.add("radius", JsonString(this.radius))
        return JsonObject(map)
    }
}

// ===== Subclass: GeoRect =====

class GeoRect <: GeoShape {
    public var width: String = "0"
    public var height: String = "0"

    public static func fromJson(json: String): GeoRect {
        return GeoRect.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue): GeoRect {
        return GeoRect.fromJsonValue(json, "$")
    }

    public static func fromJsonValue(json: JsonValue, _path: String): GeoRect {
        let jsonObject = json.asObject()
        var ret = GeoRect()
        
        if (jsonObject.getFields().contains("name")) {
            ret.name = jsonObject.get("name").getOrThrow().asString().getValue()
        }
        if (jsonObject.getFields().contains("width")) {
            ret.width = jsonObject.get("width").getOrThrow().asString().getValue()
        }
        if (jsonObject.getFields().contains("height")) {
            ret.height = jsonObject.get("height").getOrThrow().asString().getValue()
        }
        
        return ret
    }

    public func toJsonValue(): JsonValue {
        var map: HashMap<String, JsonValue> = HashMap()
        map.add("shapeType", JsonString("rect"))
        map.add("name", JsonString(this.name))
        map.add("width", JsonString(this.width))
        map.add("height", JsonString(this.height))
        return JsonObject(map)
    }
}

// ===== Tests =====

@Test
public class TestPolymorphicDeep {

    // Issue 1: 'is' type check works on upcasted reference
    @TestCase
    func testTypeCheckWithIs(): Unit {
        let circle = GeoCircle()
        circle.name = "MyCircle"
        circle.radius = "5"
        
        let shape: GeoShape = circle
        
        @Assert(shape is GeoCircle, true)
        @Assert(shape is GeoRect, false)
    }

    // Issue 2: 'as' returns Option<T>, unwrap with getOrThrow
    @TestCase
    func testDowncastWithAs(): Unit {
        let circle = GeoCircle()
        circle.name = "MyCircle"
        circle.radius = "5"
        
        let shape: GeoShape = circle
        let downcast = (shape as GeoCircle).getOrThrow()
        
        @Assert(downcast.radius, "5")
        @Assert(downcast.name, "MyCircle")
    }

    // Issue 3: Dynamic dispatch - toJsonValue on base ref calls subclass impl
    @TestCase
    func testDynamicDispatchToJsonValue(): Unit {
        let circle = GeoCircle()
        circle.name = "TestCircle"
        circle.radius = "7"
        
        let shape: GeoShape = circle
        let json = shape.toJsonValue().toString()
        
        @Assert(json.contains("\"shapeType\":\"circle\""), true)
        @Assert(json.contains("\"radius\":\"7\""), true)
    }

    // Issue 4: Round trip preserves type, downcast with as+getOrThrow
    @TestCase
    func testRoundTripPreservesType(): Unit {
        let rect = GeoRect()
        rect.name = "MyRect"
        rect.width = "10"
        rect.height = "20"
        
        let json = rect.toJson()
        let restored = GeoShape.fromJson(json)
        
        @Assert(restored is GeoRect, true)
        @Assert(restored.name, "MyRect")
        
        let restoredRect = (restored as GeoRect).getOrThrow()
        @Assert(restoredRect.width, "10")
        @Assert(restoredRect.height, "20")
    }

    // Issue 5: CRITICAL - Can subclasses be stored in ArrayList<GeoShape>?
    // This tests whether generic invariance blocks polymorphic collections.
    @TestCase
    func testArrayListOfBaseType(): Unit {
        let circle = GeoCircle()
        circle.name = "C1"
        circle.radius = "5"
        
        let rect = GeoRect()
        rect.name = "R1"
        rect.width = "3"
        rect.height = "4"
        
        // KEY TEST: Can subclasses be added to ArrayList<BaseClass>?
        let shapes = ArrayList<GeoShape>()
        shapes.add(circle)  // Upcast GeoCircle -> GeoShape
        shapes.add(rect)    // Upcast GeoRect -> GeoShape
        
        @Assert(shapes.size, 2)
        @Assert(shapes[0] is GeoCircle, true)
        @Assert(shapes[1] is GeoRect, true)
    }

    // Issue 6: Dynamic dispatch works through ArrayList<GeoShape>
    @TestCase
    func testArrayListSerializationDynamicDispatch(): Unit {
        let circle = GeoCircle()
        circle.name = "C1"
        circle.radius = "5"
        
        let rect = GeoRect()
        rect.name = "R1"
        rect.width = "3"
        rect.height = "4"
        
        let shapes = ArrayList<GeoShape>()
        shapes.add(circle)
        shapes.add(rect)
        
        // Each element should use its own toJsonValue (dynamic dispatch)
        let json0 = shapes[0].toJsonValue().toString()
        let json1 = shapes[1].toJsonValue().toString()
        
        @Assert(json0.contains("\"shapeType\":\"circle\""), true)
        @Assert(json0.contains("\"radius\":\"5\""), true)
        
        @Assert(json1.contains("\"shapeType\":\"rect\""), true)
        @Assert(json1.contains("\"width\":\"3\""), true)
        @Assert(json1.contains("\"height\":\"4\""), true)
    }

    // Issue 7: Mixed list round-trip (serialize + deserialize via base class)
    @TestCase
    func testMixedArrayListRoundTrip(): Unit {
        let circle = GeoCircle()
        circle.name = "C1"
        circle.radius = "5"
        
        let rect = GeoRect()
        rect.name = "R1"
        rect.width = "3"
        rect.height = "4"
        
        // Serialize
        let circleJson = circle.toJson()
        let rectJson = rect.toJson()
        
        // Deserialize via base class
        let restoredCircle = GeoShape.fromJson(circleJson)
        let restoredRect = GeoShape.fromJson(rectJson)
        
        @Assert(restoredCircle is GeoCircle, true)
        @Assert(restoredRect is GeoRect, true)
        @Assert(restoredCircle.name, "C1")
        @Assert(restoredRect.name, "R1")
        
        // Downcast and verify subclass fields
        let c = (restoredCircle as GeoCircle).getOrThrow()
        @Assert(c.radius, "5")
        
        let r = (restoredRect as GeoRect).getOrThrow()
        @Assert(r.width, "3")
        @Assert(r.height, "4")
    }
}
