package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import std.collection.ArrayList
import json4cj.*

// ===== Test data: simple generic class =====

@JsonSerialize
class GenericWithOption<T> {
    public var data: Option<T> = Option<T>.None
}

@JsonSerialize
class GenericWithList<T> {
    public var items: ArrayList<T> = ArrayList<T>()
}

// @JsonSerialize
// class MultiGeneric<K, V> {
//     public var key: K = 0 as K
//     public var value: V = 0 as V
// }

// ===== Tests =====

@Test
public class TestGenericClassExtraction {
    // Test 1: Generic class with Option<T> field - serialization
    @TestCase
    func testGenericWithOptionSerialization(): Unit {
        let wrapper = GenericWithOption<String>()
        wrapper.data = Option<String>.Some("hello")
        let json = wrapper.toJson()
        @Assert(json.contains("data"), true)
        @Assert(json.contains("hello"), true)
    }

    // Test 2: Generic class with ArrayList<T> field - serialization
    @TestCase
    func testGenericWithListSerialization(): Unit {
        let wrapper = GenericWithList<Int64>()
        wrapper.items.add(1)
        wrapper.items.add(2)
        let json = wrapper.toJson()
        @Assert(json.contains("items"), true)
        @Assert(json.contains("1"), true)
        @Assert(json.contains("2"), true)
    }

    // Test 3: Deserialize generic class with Option<T>
    @TestCase
    func testGenericWithOptionDeserialization(): Unit {
        let json = "{\"data\":\"test\"}"
        let wrapper = GenericWithOption<String>.fromJson(json)
        @Assert(wrapper.data.isSome(), true)
        @Assert(wrapper.data.getOrThrow(), "test")
    }

    // Test 4: Deserialize generic class with ArrayList<T>
    @TestCase
    func testGenericWithListDeserialization(): Unit {
        let json = "{\"items\":[10,20,30]}"
        let wrapper = GenericWithList<Int64>.fromJson(json)
        @Assert(wrapper.items.size, 3)
        @Assert(wrapper.items[0], 10)
        @Assert(wrapper.items[1], 20)
        @Assert(wrapper.items[2], 30)
    }

    // Test 5: Round-trip serialization
    @TestCase
    func testGenericRoundTrip(): Unit {
        let original = GenericWithList<String>()
        original.items.add("a")
        original.items.add("b")
        let json = original.toJson()
        let restored = GenericWithList<String>.fromJson(json)
        @Assert(restored.items.size, original.items.size)
        @Assert(restored.items[0], original.items[0])
        @Assert(restored.items[1], original.items[1])
    }
}
