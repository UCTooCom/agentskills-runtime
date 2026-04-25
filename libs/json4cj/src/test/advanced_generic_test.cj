package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
internal import stdx.encoding.json.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.JsonSerialize
import json4cj.*

// ===== Test 1: Two Type Parameters (var-based, simple) =====

@JsonSerialize
class KeyValuePair<K, V> {
    var key: Option<K> = Option<K>.None
    var value: Option<V> = Option<V>.None
}

// ===== Test 2: Nested Generic Types =====

@JsonSerialize
class Container<T> {
    var item: Option<T> = Option<T>.None
    var timestamp: Int64 = 0
}

@JsonSerialize
class Envelope<T> {
    var data: Option<Container<T>> = Option<Container<T>>.None
    var version: String = ""
}

// ===== Tests =====

@Test
public class TestAdvancedGenericPatterns {
    
    // ===== Test 1: Two Type Parameters =====
    
    @TestCase
    func testKeyValuePairSerialization(): Unit {
        let kv = KeyValuePair<String, Int64>()
        kv.key = Option<String>.Some("age")
        kv.value = Option<Int64>.Some(25)
        let json = kv.toJson()
        
        @Assert(json.contains("key"), true)
        @Assert(json.contains("value"), true)
        @Assert(json.contains("age"), true)
        @Assert(json.contains("25"), true)
    }

    @TestCase
    func testKeyValuePairDeserialization(): Unit {
        let json = "{\"key\":\"temperature\",\"value\":36.5}"
        let kv = KeyValuePair<String, Float64>.fromJson(json)
        
        @Assert(kv.key.isSome(), true)
        @Assert(kv.key.getOrThrow(), "temperature")
        @Assert(kv.value.isSome(), true)
        @Assert(kv.value.getOrThrow(), 36.5)
    }

    @TestCase
    func testKeyValuePairRoundTrip(): Unit {
        let original = KeyValuePair<Int64, String>()
        original.key = Option<Int64>.Some(100)
        original.value = Option<String>.Some("test")
        let json = original.toJson()
        let restored = KeyValuePair<Int64, String>.fromJson(json)
        
        @Assert(restored.key.getOrThrow(), 100)
        @Assert(restored.value.getOrThrow(), "test")
    }

    // ===== Test 2: Nested Generic Types =====
    
    @TestCase
    func testNestedGenericSerialization(): Unit {
        let container = Container<String>()
        container.item = Option<String>.Some("nested value")
        container.timestamp = 1234567890
        
        let envelope = Envelope<String>()
        envelope.data = Option<Container<String>>.Some(container)
        envelope.version = "v2.0"
        
        let json = envelope.toJson()
        @Assert(json.contains("data"), true)
        @Assert(json.contains("timestamp"), true)
        @Assert(json.contains("version"), true)
        @Assert(json.contains("v2.0"), true)
    }

    @TestCase
    func testNestedGenericDeserialization(): Unit {
        let json = "{\"data\":{\"item\":\"deep nested\",\"timestamp\":9876543210},\"version\":\"v3.0\"}"
        let envelope = Envelope<String>.fromJson(json)
        
        @Assert(envelope.version, "v3.0")
        @Assert(envelope.data.isSome(), true)
        
        let container = envelope.data.getOrThrow()
        @Assert(container.timestamp, 9876543210)
        @Assert(container.item.isSome(), true)
        @Assert(container.item.getOrThrow(), "deep nested")
    }

    @TestCase
    func testNestedGenericRoundTrip(): Unit {
        let inner = Container<Int64>()
        inner.item = Option<Int64>.Some(999)
        inner.timestamp = 111
        
        let original = Envelope<Int64>()
        original.data = Option<Container<Int64>>.Some(inner)
        original.version = "v1.0"
        
        let json = original.toJson()
        let restored = Envelope<Int64>.fromJson(json)
        
        @Assert(restored.version, "v1.0")
        @Assert(restored.data.isSome(), true)
        @Assert(restored.data.getOrThrow().item.getOrThrow(), 999)
        @Assert(restored.data.getOrThrow().timestamp, 111)
    }
}
