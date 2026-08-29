package jsonvalue

import stdx.encoding.json.stream.*
import stdx.serialization.serialization.*
import std.collection.{HashMap, ArrayList}
import std.io.ByteBuffer
import std.deriving.*

public type Value = JsonValue

@Derive[ToString]
public enum JsonValue <: JsonDeserializable<JsonValue> & JsonSerializable {
    | Null
    | Boolean(Bool)
    | Number(Float64)
    | String(String)
    | Array(ArrayList<JsonValue>)
    | Map(HashMap<String, JsonValue>)

    public static func fromJson(r: JsonReader): JsonValue {
        while (let Some(v) <- r.peek()) {
            match (v) {
                case JsonNull =>
                    r.skip()
                    return JsonValue.Null
                case JsonBool =>
                    let b = r.readValue<Bool>()
                    return JsonValue.Boolean(b)
                case JsonNumber =>
                    let f = r.readValue<Float64>()
                    return JsonValue.Number(f)
                case BeginArray =>
                    let arr = r.readValue<ArrayList<JsonValue>>()
                    return JsonValue.Array(arr)
                case JsonString =>
                    let str = r.readValue<String>()
                    return JsonValue.String(str)
                case BeginObject =>
                    let m = r.readValue<HashMap<String, JsonValue>>()
                    return JsonValue.Map(m)
                case _ =>
                    throw Exception("Invalid JSON token")
            }
        }
        return JsonValue.Null
    }

    public func toJson(w: JsonWriter): Unit {
        match (this) {
            case JsonValue.Null => w.writeNullValue()
            case JsonValue.Boolean(b) => w.writeValue(b)
            case JsonValue.Number(n) => w.writeValue(n)
            case JsonValue.String(s) => w.writeValue(s)
            case JsonValue.Array(arr) => w.writeValue(arr)
            case JsonValue.Map(m) => w.writeValue(m)
        }
    }

    public static func parse(json: String): JsonValue {
        let buffer = ByteBuffer(json.toArray())
        let reader = JsonReader(buffer)
        JsonValue.fromJson(reader)
    }

    public static func parse(bytes: Array<UInt8>): JsonValue {
        let buffer = ByteBuffer(bytes)
        let reader = JsonReader(buffer)
        JsonValue.fromJson(reader)
    }

    public func stringify(): String {
        let buffer = ByteBuffer()
        let writer = JsonWriter(buffer)
        this.toJson(writer)
        writer.flush()
        buffer.flush()
        String.fromUtf8(buffer.bytes())
    }

    public func toBytes(): Array<UInt8> {
        let buffer = ByteBuffer()
        let writer = JsonWriter(buffer)
        this.toJson(writer)
        writer.flush()
        buffer.flush()
        buffer.bytes()
    }

    public func isNull(): Bool {
        match (this) {
            case JsonValue.Null => true
            case _ => false
        }
    }

    public func isBool(): Bool {
        match (this) {
            case JsonValue.Boolean(_) => true
            case _ => false
        }
    }

    public func isNumber(): Bool {
        match (this) {
            case JsonValue.Number(_) => true
            case _ => false
        }
    }

    public func isString(): Bool {
        match (this) {
            case JsonValue.String(_) => true
            case _ => false
        }
    }

    public func isArray(): Bool {
        match (this) {
            case JsonValue.Array(_) => true
            case _ => false
        }
    }

    public func isMap(): Bool {
        match (this) {
            case JsonValue.Map(_) => true
            case _ => false
        }
    }

    public func asBool(): Option<Bool> {
        match (this) {
            case JsonValue.Boolean(b) => Some(b)
            case _ => None
        }
    }

    public func asNumber(): Option<Float64> {
        match (this) {
            case JsonValue.Number(n) => Some(n)
            case _ => None
        }
    }

    public func asString(): Option<String> {
        match (this) {
            case JsonValue.String(s) => Some(s)
            case _ => None
        }
    }

    public func asArray(): Option<ArrayList<JsonValue>> {
        match (this) {
            case JsonValue.Array(arr) => Some(arr)
            case _ => None
        }
    }

    public func asMap(): Option<HashMap<String, JsonValue>> {
        match (this) {
            case JsonValue.Map(m) => Some(m)
            case _ => None
        }
    }

    // 泛型断言：运行时检查变体携带值的实际类型是否为 T，是则解包，否则 None。
    // 通过变体参数绑定 `case JsonValue.String(s: T)` 实现，等价于 Go 的 x.(T)。
    public func cast<T>(): Option<T> {
        match (this) {
            case JsonValue.Boolean(b: T) => Some(b)
            case JsonValue.Number(n: T) => Some(n)
            case JsonValue.String(s: T) => Some(s)
            case JsonValue.Array(a: T) => Some(a)
            case JsonValue.Map(m: T) => Some(m)
            case _ => None
        }
    }

    public operator func [](key: String): ?JsonValue {
        match (this) {
            case JsonValue.Map(m) => m.get(key)
            case _ => None
        }
    }

    public operator func [](index: Int64): ?JsonValue {
        match (this) {
            case JsonValue.Array(arr) =>
                if (index >= 0 && index < arr.size) {
                    Some(arr[index])
                } else {
                    None
                }
            case _ => None
        }
    }

    public func get(key: String, default: JsonValue): JsonValue {
        match (this[key]) {
            case Some(v) => v
            case None => default
        }
    }

    public func getOr(default: JsonValue): JsonValue {
        match (this) {
            case JsonValue.Null => default
            case _ => this
        }
    }

    // 便捷构造：基本类型 → JsonValue
    public static func from(v: Bool): JsonValue {
        JsonValue.Boolean(v)
    }

    public static func from(v: Int64): JsonValue {
        JsonValue.Number(Float64(v))
    }

    public static func from(v: Float64): JsonValue {
        JsonValue.Number(v)
    }

    public static func from(v: String): JsonValue {
        JsonValue.String(v)
    }

    public static func from(v: ArrayList<JsonValue>): JsonValue {
        JsonValue.Array(v)
    }

    public static func from(v: HashMap<String, JsonValue>): JsonValue {
        JsonValue.Map(v)
    }

    // 泛型对象 → JsonValue（转发现有 fromObject）
    public static func from<T>(obj: T): JsonValue where T <: JsonSerializable {
        JsonValue.fromObject(obj)
    }

    public static func fromObject<T>(obj: T): JsonValue where T <: JsonSerializable {
        let buffer = ByteBuffer()
        let writer = JsonWriter(buffer)
        obj.toJson(writer)
        writer.flush()
        buffer.flush()
        let reader = JsonReader(buffer)
        JsonValue.fromJson(reader)
    }

    public static func toObject<T>(jsonValue: JsonValue): T where T <: JsonDeserializable<T> {
        let buffer = ByteBuffer()
        let writer = JsonWriter(buffer)
        jsonValue.toJson(writer)
        writer.flush()
        buffer.flush()
        let reader = JsonReader(buffer)
        T.fromJson(reader)
    }

    // DataModel（stdx.serialization 通用数据模型）→ JsonValue
    public static func fromDataModel(dm: DataModel): JsonValue {
        match (dm) {
            case d: DataModelNull => JsonValue.Null
            case d: DataModelBool => JsonValue.Boolean(d.getValue())
            case d: DataModelInt => JsonValue.Number(Float64(d.getValue()))
            case d: DataModelFloat => JsonValue.Number(d.getValue())
            case d: DataModelString => JsonValue.String(d.getValue())
            case d: DataModelSeq =>
                let arr = ArrayList<JsonValue>()
                for (e in d.getItems()) { arr.add(JsonValue.fromDataModel(e)) }
                JsonValue.Array(arr)
            case d: DataModelStruct =>
                let m = HashMap<String, JsonValue>()
                for (f in d.getFields()) { m[f.getName()] = JsonValue.fromDataModel(f.getData()) }
                JsonValue.Map(m)
            case _ => JsonValue.Null
        }
    }

    // JsonValue → DataModel（stdx.serialization 通用数据模型）
    public func toDataModel(): DataModel {
        match (this) {
            case JsonValue.Null => DataModelNull()
            case JsonValue.Boolean(b) => DataModelBool(b)
            case JsonValue.Number(n) => DataModelFloat(n)
            case JsonValue.String(s) => DataModelString(s)
            case JsonValue.Array(arr) =>
                let items = ArrayList<DataModel>()
                for (v in arr) { items.add(v.toDataModel()) }
                DataModelSeq(items)
            case JsonValue.Map(m) =>
                let dms = DataModelStruct()
                for ((k, v) in m) { dms.add(Field(k, v.toDataModel())) }
                dms
        }
    }
}
