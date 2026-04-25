package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

// ===== Test data: generic class with bare type parameter field =====
// NOTE: Bare type params need a valid default value. We use Option<T>.None trick
// or require @JsonCreator for construction.

@JsonSerialize
class BareTypeWrapper<T> {
    public var value: Option<T> = Option<T>.None
}

// ===== Tests =====

@Test
public class TestBareTypeParam {
    // Test 1: Serialization with Option<T> (wraps bare type param)
    @TestCase
    func testBareTypeSerialization(): Unit {
        let wrapper = BareTypeWrapper<Int64>()
        wrapper.value = Option<Int64>.Some(42)
        let json = wrapper.toJson()
        @Assert(json.contains("value"), true)
        @Assert(json.contains("42"), true)
    }

    // Test 2: Deserialization with Option<T>
    @TestCase
    func testBareTypeDeserialization(): Unit {
        let json = "{\"value\":123}"
        let wrapper = BareTypeWrapper<Int64>.fromJson(json)
        @Assert(wrapper.value.isSome(), true)
        @Assert(wrapper.value.getOrThrow(), 123)
    }

    // Test 3: Round-trip
    @TestCase
    func testBareTypeRoundTrip(): Unit {
        let original = BareTypeWrapper<String>()
        original.value = Option<String>.Some("hello world")
        let json = original.toJson()
        let restored = BareTypeWrapper<String>.fromJson(json)
        @Assert(restored.value.getOrThrow(), "hello world")
    }
}
