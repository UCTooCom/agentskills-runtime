package json4cj.test

import std.unittest.*
import std.unittest.testmacro.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.*

/*
 * Prototype: Serde-style enum-based polymorphism
 * 
 * Key insight: Use Cangjie enum with parameterized constructors
 * instead of class inheritance. This matches Serde's approach exactly.
 * 
 * Advantages:
 * - Strategy defined once on enum (no inheritance issues)
 * - All variants in one place (closed set)
 * - Compiler knows all variants
 * - Simpler code generation
 */

// Simple enum - will test if @JsonSerialize works on enums
enum Message {
    | Request(String, String)  // id, method
    | Response(String, String) // id, result
}

@Test
public class TestEnumPolymorphismPrototype {
    
    @TestCase
    func testEnumCreation(): Unit {
        // Test that we can create enum instances
        let req = Message.Request("123", "get_user")
        let resp = Message.Response("123", "user_data")
        
        // Just verify they compile and work
        println("Created Request and Response enum variants")
        @Assert(true, true)
    }
    
    @TestCase
    func testEnumMatch(): Unit {
        let msg = Message.Request("456", "login")
        
        // Test pattern matching
        let msgType = match (msg) {
            case Message.Request(id, method) => "Request: " + method
            case Message.Response(id, result) => "Response: " + result
        }
        
        println("Message type: " + msgType)
        @Assert(msgType == "Request: login", true)
    }
    
    @TestCase
    func testEnumFields(): Unit {
        let req = Message.Request("789", "logout")
        
        // Extract fields via pattern matching
        match (req) {
            case Message.Request(id, method) => 
                println("id=" + id + ", method=" + method)
            case _ => println("Unknown")
        }
    }
}
