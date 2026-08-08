package kaca_json

import std.collection.*

public interface AsJsonValue {
    func toJsonValue(): JsonValue
}

public class JsonTypeError <: Exception {
    public let errMsg: String

    public init(msg: String) {
        this.errMsg = msg
    }
}

public enum JsonValue {
    | JsonNull
    | JsonBool(Bool)
    | JsonNumber(Float64)
    | JsonString(String)
    | JsonArray(ArrayList<JsonValue>)
    | JsonObject(HashMap<String, JsonValue>)

    public func typeName(): String {
        match (this) {
            case JsonNull => "null"
            case JsonBool(_) => "bool"
            case JsonNumber(_) => "number"
            case JsonString(_) => "string"
            case JsonArray(_) => "array"
            case JsonObject(_) => "object"
        }
    }

    public func isNull(): Bool {
        match (this) {
            case JsonNull => true
            case _ => false
        }
    }
    
    public func isBool(): Bool {
        match (this) {
            case JsonBool(_) => true
            case _ => false
        }
    }
    
    public func isNumber(): Bool {
        match (this) {
            case JsonNumber(_) => true
            case _ => false
        }
    }
    
    public func isString(): Bool {
        match (this) {
            case JsonString(_) => true
            case _ => false
        }
    }
    
    public func isArray(): Bool {
        match (this) {
            case JsonArray(_) => true
            case _ => false
        }
    }
    
    public func isObject(): Bool {
        match (this) {
            case JsonObject(_) => true
            case _ => false
        }
    }

    public func asBoolOrNull(): ?Bool {
        match (this) {
            case JsonBool(b) => b
            case _ => None
        }
    }

    public func asNumberOrNull(): ?Float64 {
        match (this) {
            case JsonNumber(n) => n
            case _ => None
        }
    }

    public func asStringOrNull(): ?String {
        match (this) {
            case JsonString(s) => s
            case _ => None
        }
    }

    public func asArrayOrNull(): ?ArrayList<JsonValue> {
        match (this) {
            case JsonArray(arr) => arr
            case _ => None
        }
    }

    public func asObjectOrNull(): ?HashMap<String, JsonValue> {
        match (this) {
            case JsonObject(obj) => obj
            case _ => None
        }
    }

    public func asIntOrNull(): ?Int64 {
        match (this) {
            case JsonNumber(n) =>
                let i = Int64(n)
                if (Float64(i) == n) { i } else { None }
            case _ => None
        }
    }

    public func asBoolOr(defaultValue: Bool): Bool {
        match (this.asBoolOrNull()) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    public func asNumberOr(defaultValue: Float64): Float64 {
        match (this.asNumberOrNull()) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    public func asIntOr(defaultValue: Int64): Int64 {
        match (this.asIntOrNull()) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    public func asStringOr(defaultValue: String): String {
        match (this.asStringOrNull()) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    public func requireBool(): Bool {
        match (this.asBoolOrNull()) {
            case Some(v) => v
            case None => throw JsonTypeError("Expected bool, got ${typeName()}")
        }
    }

    public func requireNumber(): Float64 {
        match (this.asNumberOrNull()) {
            case Some(v) => v
            case None => throw JsonTypeError("Expected number, got ${typeName()}")
        }
    }

    public func requireInt(): Int64 {
        match (this.asIntOrNull()) {
            case Some(v) => v
            case None => throw JsonTypeError("Expected int number, got ${typeName()}")
        }
    }

    public func requireString(): String {
        match (this.asStringOrNull()) {
            case Some(v) => v
            case None => throw JsonTypeError("Expected string, got ${typeName()}")
        }
    }

    public func requireArray(): ArrayList<JsonValue> {
        match (this.asArrayOrNull()) {
            case Some(v) => v
            case None => throw JsonTypeError("Expected array, got ${typeName()}")
        }
    }

    public func requireObject(): HashMap<String, JsonValue> {
        match (this.asObjectOrNull()) {
            case Some(v) => v
            case None => throw JsonTypeError("Expected object, got ${typeName()}")
        }
    }

    public func get(key: String): ?JsonValue {
        match (this) {
            case JsonObject(obj) => obj.get(key)
            case _ => None
        }
    }

    public func has(key: String): Bool {
        match (this.get(key)) {
            case Some(_) => true
            case None => false
        }
    }

    public func at(index: Int64): ?JsonValue {
        match (this) {
            case JsonArray(arr) =>
                if (index < 0 || index >= arr.size) { return None }
                arr[index]
            case _ => None
        }
    }

    public func sizeOrZero(): Int64 {
        match (this) {
            case JsonArray(arr) => arr.size
            case JsonObject(obj) => obj.size
            case _ => 0
        }
    }

    public func push(value: AsJsonValue): Unit {
        match (this) {
            case JsonArray(arr) => arr.add(value.toJsonValue())
            case _ => throw JsonTypeError("Expected array, got ${typeName()}")
        }
    }

    public func put(key: String, value: AsJsonValue): Unit {
        match (this) {
            case JsonObject(obj) => obj[key] = value.toJsonValue()
            case _ => throw JsonTypeError("Expected object, got ${typeName()}")
        }
    }

    public func getBool(): ?Bool { asBoolOrNull() }

    public func getNumber(): ?Float64 { asNumberOrNull() }

    public func getString(): ?String { asStringOrNull() }

    public func getArray(): ?ArrayList<JsonValue> { asArrayOrNull() }

    public func getObject(): ?HashMap<String, JsonValue> { asObjectOrNull() }
}

extend JsonValue <: AsJsonValue {
    public func toJsonValue(): JsonValue { this }
}

extend Bool <: AsJsonValue {
    public func toJsonValue(): JsonValue { JsonValue.JsonBool(this) }
}

extend Int64 <: AsJsonValue {
    public func toJsonValue(): JsonValue { JsonValue.JsonNumber(Float64(this)) }
}

extend Int32 <: AsJsonValue {
    public func toJsonValue(): JsonValue { JsonValue.JsonNumber(Float64(this)) }
}

extend Float64 <: AsJsonValue {
    public func toJsonValue(): JsonValue { JsonValue.JsonNumber(this) }
}

extend String <: AsJsonValue {
    public func toJsonValue(): JsonValue { JsonValue.JsonString(this) }
}
