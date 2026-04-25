/*
 * Core serialization interfaces and built-in type extensions.
 *
 * Naming note: The HashMap-based interface is named JsonCodec<T> (not JsonSerializable<T>)
 * to avoid naming collision with stdx.encoding.json.stream.JsonSerializable.
 * When both are imported in the same file, identical short names cause "ambiguous use" errors.
 * See TROUBLESHOOTING.md section 5.1 for details.
 *
 * Interface hierarchy:
 *   JsonCodec<T> <: JsonValueSerializable<T>  — HashMap-based (toJson/fromJson via JsonValue tree)
 *   stdx JsonSerializable                     — Stream-based (toJson(w: JsonWriter) direct write)
 *   stdx JsonDeserializable<T>                — Stream-based (static fromJson(r: JsonReader) direct read)
 *
 * Path-aware deserialization:
 *   fromJsonValue(value, path) propagates JSON path context for error reporting.
 *   Path format: dot notation ($.user.address.city, $.items[0].name)
 */
package json4cj

internal import stdx.encoding.json.{JsonValue, JsonString, JsonBool, JsonInt, JsonFloat, JsonObject, JsonArray, JsonNull}
import std.time.DateTime
import std.convert.*
internal import std.collection.{ArrayList, HashSet, HashMap}

/*
 * HashMap-based JSON codec interface.
 *
 * Renamed from JsonSerializable<T> to JsonCodec<T> to avoid collision with
 * stdx.encoding.json.stream.JsonSerializable. Both names may appear in the
 * same file when the @JsonSerialize macro generates extend blocks for stdx
 * stream interfaces.
 *
 * Implementing classes get: toJson(), fromJson(), toJsonValue(), fromJsonValue()
 */
public interface JsonCodec<T> <: JsonValueSerializable<T> {
    static func fromJson(json: String): T
    func toJson(): String
}

public interface JsonValueSerializable<T> {
    static func fromJsonValue(value: JsonValue): T
    static func fromJsonValue(value: JsonValue, path: String): T
    func toJsonValue(): JsonValue
}

extend String <: JsonValueSerializable<String> {
    public static func fromJsonValue(value: JsonValue): String {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): String {
        try {
            return value.asString().getValue()
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected String, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonString(this)
    }
}

extend Bool <: JsonValueSerializable<Bool> {
    public static func fromJsonValue(value: JsonValue): Bool {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): Bool {
        try {
            return value.asBool().getValue()
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Bool, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonBool(this)
    }
}

extend Int64 <: JsonValueSerializable<Int64> {
    public static func fromJsonValue(value: JsonValue): Int64 {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): Int64 {
        try {
            return value.asInt().getValue()
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Int64, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(this)
    }
}

extend Int32 <: JsonValueSerializable<Int32> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Int32 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): Int32 {
        try {
            return Int32(value.asInt().getValue())
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Int32, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(Int64(this))
    }
}

extend Int16 <: JsonValueSerializable<Int16> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Int16 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): Int16 {
        try {
            return Int16(value.asInt().getValue())
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Int16, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(Int64(this))
    }
}

extend Int8 <: JsonValueSerializable<Int8> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Int8 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): Int8 {
        try {
            return Int8(value.asInt().getValue())
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Int8, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(Int64(this))
    }
}

extend UInt64 <: JsonValueSerializable<UInt64> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): UInt64 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): UInt64 {
        try {
            return UInt64(value.asInt().getValue())
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected UInt64, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(Int64(this))
    }
}

extend UInt32 <: JsonValueSerializable<UInt32> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): UInt32 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): UInt32 {
        try {
            return UInt32(value.asInt().getValue())
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected UInt32, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(Int64(this))
    }
}

extend UInt16 <: JsonValueSerializable<UInt16> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): UInt16 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): UInt16 {
        try {
            return UInt16(value.asInt().getValue())
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected UInt16, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(Int64(this))
    }
}

extend UInt8 <: JsonValueSerializable<UInt8> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): UInt8 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): UInt8 {
        try {
            return UInt8(value.asInt().getValue())
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected UInt8, got " + value.toString())
        }
    }

    public func toJsonValue(): JsonValue {
        JsonInt(Int64(this))
    }
}

extend Float64 <: JsonValueSerializable<Float64> {
    public static func fromJsonValue(value: JsonValue): Float64 {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): Float64 {
        try {
            return value.asFloat().getValue()
        } catch (_: Exception) {}
        try {
            return Float64(value.asInt().getValue())
        } catch (_: Exception) {}
        throw JsonDeserializeException(path, "expected Float64, got " + value.toString())
    }

    public func toJsonValue(): JsonValue {
        JsonFloat(this)
    }
}

extend Float32 <: JsonValueSerializable<Float32> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Float32 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): Float32 {
        try {
            return Float32(value.asFloat().getValue())
        } catch (_: Exception) {}
        try {
            return Float32(value.asInt().getValue())
        } catch (_: Exception) {}
        throw JsonDeserializeException(path, "expected Float32, got " + value.toString())
    }

    public func toJsonValue(): JsonValue {
        JsonFloat(Float64(this))
    }
}

extend Float16 <: JsonValueSerializable<Float16> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Float16 {
        return fromJsonValue(value, "$")
    }

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue, path: String): Float16 {
        try {
            return Float16(value.asFloat().getValue())
        } catch (_: Exception) {}
        try {
            return Float16(value.asInt().getValue())
        } catch (_: Exception) {}
        throw JsonDeserializeException(path, "expected Float16, got " + value.toString())
    }

    public func toJsonValue(): JsonValue {
        JsonFloat(Float64(this))
    }
}

extend DateTime <: JsonValueSerializable<DateTime> {
    public static func fromJsonValue(value: JsonValue): DateTime {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): DateTime {
        let str: String
        try {
            str = value.asString().getValue()
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected DateTime string, got " + value.toString())
        }
        try {
            return DateTime.parse(str)
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "invalid DateTime format: " + str)
        }
    }

    public func toJsonValue(): JsonValue {
        JsonString(this.toString())
    }
}

extend<T> ArrayList<T> <: JsonValueSerializable<ArrayList<T>> where T <: JsonValueSerializable<T> {
    public static func fromJsonValue(value: JsonValue): ArrayList<T> {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): ArrayList<T> {
        var res = ArrayList<T>()
        let jv: JsonArray
        try {
            jv = value.asArray()
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Array, got " + value.toString())
        }
        let items = jv.getItems()
        for (i in 0..items.size) {
            let elemPath = path + "[" + i.toString() + "]"
            try {
                res.add(T.fromJsonValue(items[i], elemPath))
            } catch (e: JsonDeserializeException) {
                throw e
            } catch (e: Exception) {
                throw JsonDeserializeException(elemPath, e.message)
            }
        }
        res
    }

    public func toJsonValue(): JsonValue {
        var jsonArray = JsonArray()
        for (item in this) {
            jsonArray.add(item.toJsonValue())
        }
        jsonArray
    }
}

extend<T> HashSet<T> <: JsonValueSerializable<HashSet<T>> where T <: JsonValueSerializable<T> {
    public static func fromJsonValue(value: JsonValue): HashSet<T> {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): HashSet<T> {
        var res = HashSet<T>()
        let jv: JsonArray
        try {
            jv = value.asArray()
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Array, got " + value.toString())
        }
        let items = jv.getItems()
        for (i in 0..items.size) {
            let elemPath = path + "[" + i.toString() + "]"
            try {
                res.add(T.fromJsonValue(items[i], elemPath))
            } catch (e: JsonDeserializeException) {
                throw e
            } catch (e: Exception) {
                throw JsonDeserializeException(elemPath, e.message)
            }
        }
        res
    }

    public func toJsonValue(): JsonValue {
        var jsonArray = JsonArray()
        for (item in this) {
            jsonArray.add(item.toJsonValue())
        }
        jsonArray
    }
}

extend<K, V> HashMap<K, V> <: JsonValueSerializable<HashMap<K, V>> where K <: ToString & Hashable & Equatable<K> & JsonValueSerializable<K>,
    V <: JsonValueSerializable<V> {
    public static func fromJsonValue(value: JsonValue): HashMap<K, V> {
        return fromJsonValue(value, "$")
    }

    public static func fromJsonValue(value: JsonValue, path: String): HashMap<K, V> {
        var res = HashMap<K, V>()
        let jv: JsonObject
        try {
            jv = value.asObject()
        } catch (_: Exception) {
            throw JsonDeserializeException(path, "expected Object, got " + value.toString())
        }
        for ((x, y) in jv.getFields()) {
            let entryPath = path + "." + x
            try {
                res.add(K.fromJsonValue(JsonString(x), entryPath), V.fromJsonValue(y, entryPath))
            } catch (e: JsonDeserializeException) {
                throw e
            } catch (e: Exception) {
                throw JsonDeserializeException(entryPath, e.message)
            }
        }
        res
    }

    public func toJsonValue(): JsonValue {
        var jsonObj = JsonObject()
        for ((k, v) in this) {
            jsonObj.put(k.toString(), v.toJsonValue())
        }
        jsonObj
    }
}
