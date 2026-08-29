package jsonvalue.examples.basic

import jsonvalue.*
import stdx.encoding.json.stream.*
import std.collection.{ArrayList, HashMap}

main() {
    testParseAndStringify()
    testTypeCheck()
    testAccess()
    testNested()
    testGenericConvert()
    
    println("all tests passed")
}

func testParseAndStringify() {
    let json = "{\"name\":\"test\",\"count\":42,\"active\":true}"
    let v = JsonValue.parse(json)
    
    if (v.isMap()) {
        println("  testParseAndStringify: isMap OK")
    }
    
    let json2 = v.stringify()
    let v2 = JsonValue.parse(json2)
    if (v2.stringify() == json2) {
        println("  testParseAndStringify: roundtrip OK")
    }
}

func testTypeCheck() {
    if (JsonValue.Null.isNull()) {
        println("  testTypeCheck: Null OK")
    }
    if (JsonValue.Boolean(true).isBool()) {
        println("  testTypeCheck: Boolean OK")
    }
    if (JsonValue.Number(1.0).isNumber()) {
        println("  testTypeCheck: Number OK")
    }
    if (JsonValue.String("a").isString()) {
        println("  testTypeCheck: String OK")
    }
    if (JsonValue.Array(ArrayList<JsonValue>()).isArray()) {
        println("  testTypeCheck: Array OK")
    }
    if (JsonValue.Map(HashMap<String, JsonValue>()).isMap()) {
        println("  testTypeCheck: Map OK")
    }
}

func testAccess() {
    let v = JsonValue.parse("{\"name\":\"test\",\"items\":[1,2,3]}")
    
    if (v["name"]?.asString() == Some("test")) {
        println("  testAccess: map access OK")
    }
    
    match (v["notexist"]) {
        case None => println("  testAccess: notexist OK")
        case _ => println("  testAccess: notexist FAIL")
    }
    
    if (v["items"]?[0]?.asNumber() == Some(1.0)) {
        println("  testAccess: array index 0 OK")
    }
    if (v["items"]?[2]?.asNumber() == Some(3.0)) {
        println("  testAccess: array index 2 OK")
    }
    match (v["items"]?[100]) {
        case None => println("  testAccess: out of bounds OK")
        case Some(None) => println("  testAccess: out of bounds OK")
        case _ => println("  testAccess: out of bounds FAIL")
    }
    
    if (v.get("name", JsonValue.Null).asString() == Some("test")) {
        println("  testAccess: get with default OK")
    }
}

func testNested() {
    let v = JsonValue.parse("{\"a\":{\"b\":{\"c\":[1,2,{\"d\":\"deep\"}]}}}")
    
    if (v["a"]?["b"]?["c"]?[2]?["d"]?.asString() == Some("deep")) {
        println("  testNested: deep access OK")
    }
    if (v["a"]?["b"]?["c"]?[0]?.asNumber() == Some(1.0)) {
        println("  testNested: array in nested OK")
    }
}

func testGenericConvert() {
    let obj = TestObj("hello", 42)
    let v = JsonValue.fromObject(obj)
    
    if (v["name"]?.asString() == Some("hello")) {
        println("  testGenericConvert: fromObject OK")
    }
    if (v["value"]?.asNumber() == Some(42.0)) {
        println("  testGenericConvert: value OK")
    }
    
    let obj2 = JsonValue.toObject<TestObj>(v)
    if (obj2.name == "hello" && obj2.value == 42) {
        println("  testGenericConvert: toObject OK")
    }
}

class TestObj <: JsonSerializable & JsonDeserializable<TestObj> {
    public var name: String = ""
    public var value: Int64 = 0
    
    public init() {}
    public init(name: String, value: Int64) {
        this.name = name
        this.value = value
    }
    
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("name").writeValue(this.name)
        w.writeName("value").writeValue(this.value)
        w.endObject()
    }
    
    public static func fromJson(r: JsonReader): TestObj {
        let obj = TestObj()
        r.startObject()
        while (r.peek() != EndObject) {
            let n = r.readName()
            match (n) {
                case "name" => obj.name = r.readValue<String>()
                case "value" => obj.value = r.readValue<Int64>()
                case _ => r.skip()
            }
        }
        r.endObject()
        obj
    }
}
