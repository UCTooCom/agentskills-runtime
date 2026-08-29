package jsonvalue

import std.collection.*
import stdx.encoding.json.stream.*
import stdx.serialization.serialization.*

// ---- 泛型断言 `as<T>()` ----

@Test
func genericAs_string() {
    let v = JsonValue.String("hello")
    match (v.cast<String>()) {
        case Some(s) => @Expect(s, "hello")
        case None => @Fail("expected string")
    }
}

@Test
func genericAs_number() {
    let v = JsonValue.Number(42.0)
    match (v.cast<Float64>()) {
        case Some(n) => @Expect(n, 42.0)
        case None => @Fail("expected number")
    }
}

@Test
func genericAs_bool() {
    let v = JsonValue.Boolean(true)
    match (v.cast<Bool>()) {
        case Some(b) => @Expect(b, true)
        case None => @Fail("expected bool")
    }
}

@Test
func genericAs_array() {
    let v = JsonValue.Array(ArrayList<JsonValue>([JsonValue.Number(1.0)]))
    match (v.cast<ArrayList<JsonValue>>()) {
        case Some(a) => @Expect(a.size, 1)
        case None => @Fail("expected array")
    }
}

@Test
func genericAs_map() {
    let mm = HashMap<String, JsonValue>()
    mm["k"] = JsonValue.String("v")
    let v = JsonValue.Map(mm)
    match (v.cast<HashMap<String, JsonValue>>()) {
        case Some(m) => @Expect(m.size, 1)
        case None => @Fail("expected map")
    }
}

@Test
func genericAs_typeMismatch() {
    let v = JsonValue.Number(42.0)
    match (v.cast<String>()) {
        case Some(_) => @Fail("number should not be string")
        case None => ()
    }
    match (v.cast<Int64>()) {
        case Some(_) => @Fail("Float64 should not auto-truncate to Int64")
        case None => ()
    }
}

@Test
func genericAs_null() {
    match (JsonValue.Null.cast<String>()) {
        case Some(_) => @Fail("null should not match")
        case None => ()
    }
}

// ---- 便捷构造 from(...) ----

@Test
func from_bool() {
    let v = JsonValue.from(true)
    match (v) { case JsonValue.Boolean(b) => @Expect(b, true); case _ => @Fail("not bool") }
}

@Test
func from_int() {
    let v = JsonValue.from(42)
    match (v) { case JsonValue.Number(n) => @Expect(n, 42.0); case _ => @Fail("not number") }
}

@Test
func from_float() {
    let v = JsonValue.from(0.9)
    match (v) { case JsonValue.Number(n) => @Expect(n, 0.9); case _ => @Fail("not number") }
}

@Test
func from_string() {
    let v = JsonValue.from("hello")
    match (v) { case JsonValue.String(s) => @Expect(s, "hello"); case _ => @Fail("not string") }
}

@Test
func from_array() {
    let arr = ArrayList<JsonValue>([JsonValue.from(1)])
    let v = JsonValue.from(arr)
    match (v) { case JsonValue.Array(a) => @Expect(a.size, 1); case _ => @Fail("not array") }
}

@Test
func from_map() {
    let mm = HashMap<String, JsonValue>()
    mm["k"] = JsonValue.from("v")
    let v = JsonValue.from(mm)
    match (v) { case JsonValue.Map(m) => @Expect(m.size, 1); case _ => @Fail("not map") }
}

// ---- 链式组合 ----

@Test
func chain_asFrom() {
    let extra = HashMap<String, JsonValue>()
    extra["reasoning_effort"] = JsonValue.from("high")
    extra["top_p"] = JsonValue.from(0.9)
    let v = JsonValue.from(extra)
    let effort = v["reasoning_effort"]?.cast<String>() ?? ""
    let topP = v["top_p"]?.cast<Float64>() ?? 0.0
    @Expect(effort, "high")
    @Expect(topP, 0.9)
}

// ---- DataModel 桥接 ----

@Test
func fromDataModel_allVariants() {
    // DataModel 全变体 → JsonValue
    let dmStruct = DataModelStruct()
        .add(field<String>("s", "hello"))
        .add(field<Int64>("i", 42))
        .add(field<Float64>("f", 0.9))
        .add(field<Bool>("b", true))
    let seq = DataModelSeq()
    seq.add(DataModelInt(1))
    seq.add(DataModelString("two"))
    dmStruct.add(Field("arr", seq))

    let v = JsonValue.fromDataModel(dmStruct)
    match (v) {
        case JsonValue.Map(m) =>
            match (m.get("s")) {
                case Some(JsonValue.String(x)) => @Expect(x, "hello")
                case _ => @Fail("string variant")
            }
            match (m.get("i")) {
                case Some(JsonValue.Number(x)) => @Expect(x, 42.0)
                case _ => @Fail("int variant")
            }
            match (m.get("f")) {
                case Some(JsonValue.Number(x)) => @Expect(x, 0.9)
                case _ => @Fail("float variant")
            }
            match (m.get("b")) {
                case Some(JsonValue.Boolean(x)) => @Expect(x, true)
                case _ => @Fail("bool variant")
            }
            match (m.get("arr")) {
                case Some(JsonValue.Array(a)) => @Expect(a.size, 2)
                case _ => @Fail("seq variant")
            }
        case _ => @Fail("expected map")
    }
}

@Test
func fromDataModel_nullAndNested() {
    let dm = DataModelStruct()
        .add(field<String>("null_field", ""))
    // 直接测 DataModelNull 和嵌套 struct
    let v = JsonValue.fromDataModel(DataModelNull())
    match (v) { case JsonValue.Null => (); case _ => @Fail("null") }

    let nested = DataModelStruct().add(field<String>("type", "json"))
    let outer = DataModelStruct().add(Field("resp", nested))
    let v2 = JsonValue.fromDataModel(outer)
    match (v2) {
        case JsonValue.Map(m) =>
            match (m.get("resp")) {
                case Some(JsonValue.Map(nm)) =>
                    match (nm.get("type")) {
                        case Some(JsonValue.String(t)) => @Expect(t, "json")
                        case _ => @Fail("nested type")
                    }
                case _ => @Fail("nested struct")
            }
        case _ => @Fail("expected map")
    }
}

@Test
func toDataModel_allVariants() {
    // JsonValue 全变体 → DataModel
    let mm = HashMap<String, JsonValue>()
    mm["s"] = JsonValue.String("hello")
    mm["n"] = JsonValue.Number(42.5)
    mm["b"] = JsonValue.Boolean(true)
    let arr = ArrayList<JsonValue>()
    arr.add(JsonValue.Number(1.0))
    arr.add(JsonValue.String("two"))
    mm["arr"] = JsonValue.Array(arr)
    let v = JsonValue.Map(mm)

    let dm = v.toDataModel()
    match (dm) {
        case dms: DataModelStruct =>
            match (dms.get("s")) {
                case ds: DataModelString => @Expect(ds.getValue(), "hello")
                case _ => @Fail("string")
            }
            match (dms.get("n")) {
                case df: DataModelFloat => @Expect(df.getValue(), 42.5)
                case _ => @Fail("number")
            }
            match (dms.get("b")) {
                case db: DataModelBool => @Expect(db.getValue(), true)
                case _ => @Fail("bool")
            }
            match (dms.get("arr")) {
                case dseq: DataModelSeq => @Expect(dseq.getItems().size, 2)
                case _ => @Fail("array")
            }
        case _ => @Fail("expected struct")
    }
}

@Test
func dataModel_roundTrip() {
    // round-trip: JsonValue → DataModel → JsonValue
    let mm = HashMap<String, JsonValue>()
    mm["reasoning_effort"] = JsonValue.String("high")
    mm["top_p"] = JsonValue.Number(0.9)
    let original = JsonValue.Map(mm)

    let dm = original.toDataModel()
    let back = JsonValue.fromDataModel(dm)

    match (back) {
        case JsonValue.Map(m) =>
            match (m.get("reasoning_effort")) {
                case Some(JsonValue.String(x)) => @Expect(x, "high")
                case _ => @Fail("effort lost")
            }
            match (m.get("top_p")) {
                case Some(JsonValue.Number(x)) => @Expect(x, 0.9)
                case _ => @Fail("top_p lost")
            }
        case _ => @Fail("expected map")
    }
}
