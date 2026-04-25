package json4cj.test

import std.unittest.testmacro.{Test, TestCase, Assert}
internal import stdx.encoding.json.stream.*
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

/*
 * Test parameterized enum JSON serialization (serde externally-tagged).
 *
 * Unit variant:   Point       => "Point"
 * Single param:   Circle(3.0) => {"Circle": 3.0}
 * Multi param:    Rect(3, 4)  => {"Rect": [3.0, 4.0]}
 */

// ==================== Parameterized Enum Declarations ====================

// Mixed enum: unit + single-param + multi-param
@JsonSerialize
enum Shape {
    | Circle(Float64)
    | Rect(Float64, Float64)
    | Dot
}

// Recursive enum (AST-like)
@JsonSerialize
enum MathExpr {
    | Val(Int64)
    | Negate(MathExpr)
    | Plus(MathExpr, MathExpr)
}

// Single-param only enum
@JsonSerialize
enum Wrapper {
    | StrVal(String)
    | IntVal(Int64)
    | BoolVal(Bool)
}

// Class with parameterized enum field
@JsonSerialize
public class Drawing {
    var label: String = ""
    var shape: Shape = Dot
}

// ==================== Test Cases ====================

@Test
class TestParamEnumSerialization {

    // --- toJsonValue / toJson ---

    @TestCase
    func testSingleParamToJson(): Unit {
        let s = Shape.Circle(3.14)
        let json = s.toJson()
        println("Circle toJson: ${json}")
        @Assert(json.contains("\"Circle\""))
        @Assert(json.contains("3.14"))
    }

    @TestCase
    func testMultiParamToJson(): Unit {
        let s = Shape.Rect(3.5, 4.5)
        let json = s.toJson()
        println("Rect toJson: ${json}")
        @Assert(json.contains("\"Rect\""))
        @Assert(json.contains("3.5"))
        @Assert(json.contains("4.5"))
    }

    @TestCase
    func testUnitVariantInMixedEnum(): Unit {
        let s: Shape = Dot
        let json = s.toJson()
        // Unit variant in mixed enum still serializes as string
        @Assert(json == "\"Dot\"")
    }

    @TestCase
    func testSingleParamToJsonValue(): Unit {
        let s = Shape.Circle(2.5)
        let jv = s.toJsonValue()
        // Should be a JsonObject with key "Circle"
        let obj = (jv as JsonObject).getOrThrow()
        let fields = obj.getFields()
        @Assert(fields.size == 1)
        @Assert(fields.contains("Circle"))
    }

    @TestCase
    func testMultiParamToJsonValue(): Unit {
        let s = Shape.Rect(10.5, 20.5)
        let jv = s.toJsonValue()
        let obj = (jv as JsonObject).getOrThrow()
        let fields = obj.getFields()
        @Assert(fields.size == 1)
        @Assert(fields.contains("Rect"))
    }

    // --- fromJsonValue / fromJson ---

    @TestCase
    func testSingleParamFromJson(): Unit {
        let json = ##"{"Circle":3.14}"##
        let s = Shape.fromJson(json)
        let roundtrip = s.toJson()
        println("Circle roundtrip: ${roundtrip}")
        @Assert(roundtrip.contains("\"Circle\""))
        @Assert(roundtrip.contains("3.14"))
    }

    @TestCase
    func testMultiParamFromJson(): Unit {
        let json = ##"{"Rect":[5.5,6.5]}"##
        let s = Shape.fromJson(json)
        let roundtrip = s.toJson()
        println("Rect roundtrip: ${roundtrip}")
        @Assert(roundtrip.contains("\"Rect\""))
        @Assert(roundtrip.contains("5.5"))
        @Assert(roundtrip.contains("6.5"))
    }

    @TestCase
    func testUnitVariantFromJsonInMixedEnum(): Unit {
        let json = ##""Dot""##
        let s = Shape.fromJson(json)
        @Assert(s.toJson() == "\"Dot\"")
    }

    // --- Roundtrip ---

    @TestCase
    func testRoundtripSingleParam(): Unit {
        let original = Shape.Circle(99.9)
        let json = original.toJson()
        let restored = Shape.fromJson(json)
        @Assert(restored.toJson() == original.toJson())
    }

    @TestCase
    func testRoundtripMultiParam(): Unit {
        let original = Shape.Rect(7.5, 8.5)
        let json = original.toJson()
        let restored = Shape.fromJson(json)
        @Assert(restored.toJson() == original.toJson())
    }

    @TestCase
    func testRoundtripUnitVariant(): Unit {
        let original: Shape = Dot
        let json = original.toJson()
        let restored = Shape.fromJson(json)
        @Assert(restored.toJson() == original.toJson())
    }

    // --- Wrapper enum (all single-param) ---

    @TestCase
    func testWrapperStrVal(): Unit {
        let w = Wrapper.StrVal("hello")
        let json = w.toJson()
        println("StrVal: ${json}")
        @Assert(json.contains("\"StrVal\""))
        @Assert(json.contains("\"hello\""))
        let restored = Wrapper.fromJson(json)
        @Assert(restored.toJson() == json)
    }

    @TestCase
    func testWrapperIntVal(): Unit {
        let w = Wrapper.IntVal(42)
        let json = w.toJson()
        @Assert(json.contains("\"IntVal\""))
        @Assert(json.contains("42"))
        let restored = Wrapper.fromJson(json)
        @Assert(restored.toJson() == json)
    }

    @TestCase
    func testWrapperBoolVal(): Unit {
        let w = Wrapper.BoolVal(true)
        let json = w.toJson()
        @Assert(json.contains("\"BoolVal\""))
        @Assert(json.contains("true"))
        let restored = Wrapper.fromJson(json)
        @Assert(restored.toJson() == json)
    }

    // --- Error cases ---

    @TestCase
    func testUnknownVariantThrows(): Unit {
        let json = ##"{"Triangle":1.0}"##
        var threw = false
        try {
            let _ = Shape.fromJson(json)
        } catch (_: Exception) {
            threw = true
        }
        @Assert(threw)
    }

    @TestCase
    func testUnknownUnitVariantThrows(): Unit {
        let json = ##""UnknownShape""##
        var threw = false
        try {
            let _ = Shape.fromJson(json)
        } catch (_: Exception) {
            threw = true
        }
        @Assert(threw)
    }
}

@Test
class TestRecursiveEnum {

    @TestCase
    func testSimpleVal(): Unit {
        let e = MathExpr.Val(42)
        let json = e.toJson()
        println("Val: ${json}")
        @Assert(json.contains("\"Val\""))
        @Assert(json.contains("42"))
    }

    @TestCase
    func testNegate(): Unit {
        let e = MathExpr.Negate(MathExpr.Val(5))
        let json = e.toJson()
        println("Negate: ${json}")
        @Assert(json.contains("\"Negate\""))
        @Assert(json.contains("\"Val\""))
        @Assert(json.contains("5"))
    }

    @TestCase
    func testPlus(): Unit {
        let e = MathExpr.Plus(MathExpr.Val(1), MathExpr.Val(2))
        let json = e.toJson()
        println("Plus: ${json}")
        // {"Plus":[{"Val":1},{"Val":2}]}
        @Assert(json.contains("\"Plus\""))
        @Assert(json.contains("\"Val\""))
    }

    @TestCase
    func testRecursiveRoundtrip(): Unit {
        // Plus(Val(10), Negate(Val(3)))
        let original = MathExpr.Plus(MathExpr.Val(10), MathExpr.Negate(MathExpr.Val(3)))
        let json = original.toJson()
        println("Recursive roundtrip json: ${json}")
        let restored = MathExpr.fromJson(json)
        @Assert(restored.toJson() == original.toJson())
    }
}

@Test
class TestParamEnumInClass {

    @TestCase
    func testClassWithParamEnumFieldSerialization(): Unit {
        let d = Drawing()
        d.label = "My Circle"
        d.shape = Shape.Circle(5.5)
        let json = d.toJson()
        println("Drawing serialized: ${json}")
        @Assert(json.contains("\"label\""))
        @Assert(json.contains("\"My Circle\""))
        @Assert(json.contains("\"shape\""))
        @Assert(json.contains("\"Circle\""))
        @Assert(json.contains("5.5"))
    }

    @TestCase
    func testClassWithParamEnumFieldDeserialization(): Unit {
        let json = ##"{"label":"Square","shape":{"Rect":[1.0,1.0]}}"##
        let d = Drawing.fromJson(json)
        @Assert(d.label == "Square")
        @Assert(d.shape.toJson().contains("\"Rect\""))
    }

    @TestCase
    func testClassWithUnitEnumFieldInMixedEnum(): Unit {
        let d = Drawing()
        d.label = "Origin"
        d.shape = Dot
        let json = d.toJson()
        println("Drawing with Dot: ${json}")
        @Assert(json.contains("\"Dot\""))
        let restored = Drawing.fromJson(json)
        @Assert(restored.shape.toJson() == "\"Dot\"")
    }

    @TestCase
    func testClassWithParamEnumRoundtrip(): Unit {
        let d = Drawing()
        d.label = "Test"
        d.shape = Shape.Rect(100.5, 200.5)
        let json = d.toJson()
        let restored = Drawing.fromJson(json)
        @Assert(restored.label == "Test")
        @Assert(restored.shape.toJson() == d.shape.toJson())
    }
}
