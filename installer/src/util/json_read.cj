package uc_installer.util

import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonKind}
import std.collection.ArrayList

/// 解析 JSON 文本；失败返回 None（不抛异常）。
public func jsonParse(text: String): Option<JsonValue> {
    try {
        return Some(JsonValue.fromStr(text))
    } catch (_: Exception) {
        return None<JsonValue>
    }
}

/// stdx.encoding.json：asXxx 返回包装子类，类型不符抛 JsonException，
/// 故所有取值都必须先 `match (v.kind())` 判别——**不能用 `==` 比较
/// `JsonKind`**（该枚举未实现 `==` 运算符，写了会报
/// `invalid binary operator '=='`）。

/// 若 JsonValue 是对象则返回 Some，否则 None。
public func asObject(v: JsonValue): Option<JsonObject> {
    return match (v.kind()) {
        case JsonKind.JsObject => Some(v.asObject())
        case _ => None<JsonObject>
    }
}

/// 读取对象字符串字段；缺失或非字符串返回默认值。
public func jsonStr(o: JsonObject, key: String, def: String): String {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsString => v.asString().getValue()
            case _ => def
        }
        case None => def
    }
}

/// 读取对象可选字符串字段；缺失或非字符串返回 None。
public func jsonOptStr(o: JsonObject, key: String): Option<String> {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsString => Some(v.asString().getValue())
            case _ => None<String>
        }
        case None => None<String>
    }
}

/// 读取对象整数字段；缺失或非整数返回默认值。
public func jsonInt(o: JsonObject, key: String, def: Int64): Int64 {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsInt => v.asInt().getValue()
            case _ => def
        }
        case None => def
    }
}

/// 读取对象子对象字段；缺失或非对象返回 None。
public func jsonOptObj(o: JsonObject, key: String): Option<JsonObject> {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsObject => Some(v.asObject())
            case _ => None<JsonObject>
        }
        case None => None<JsonObject>
    }
}

/// 读取对象数组字段；缺失或非数组返回 None。
/// 调用方若不关心"字段不存在"与"空数组"的区别，可直接用 `jsonStrList` 等便捷封装。
public func jsonOptArr(o: JsonObject, key: String): Option<JsonArray> {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsArray => Some(v.asArray())
            case _ => None<JsonArray>
        }
        case None => None<JsonArray>
    }
}

/// 读取对象布尔字段；缺失或非布尔返回默认值。
public func jsonBool(o: JsonObject, key: String, def: Bool): Bool {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsBool => v.asBool().getValue()
            case _ => def
        }
        case None => def
    }
}

/// 读字符串数组为 `ArrayList<String>`（非字符串元素跳过）。
///
/// 形参用 `ArrayList` 而非 `Array`：调用方几乎总是要继续 `add`，
/// 而 `Array<String>` 是定长数组没有 `add`。
public func jsonStrList(o: JsonObject, key: String): ArrayList<String> {
    let out = ArrayList<String>()
    match (jsonOptArr(o, key)) {
        case Some(arr) => collectStrings(arr, out)
        case None => ()
    }
    return out
}

/// 把数组中的字符串元素追加到 `out`（非字符串元素跳过）。
private func collectStrings(arr: JsonArray, out: ArrayList<String>): Unit {
    for (item in arr.getItems()) {
        match (item.kind()) {
            case JsonKind.JsString => out.add(item.asString().getValue())
            case _ => ()
        }
    }
}

/// 是否为敏感键（口令/密钥/令牌/连接串），回显时应脱敏为 ***（AC-014/018）。
public func isSecretKey(key: String): Bool {
    let lower = key.toAsciiLower()
    return lower.contains("password") || lower.contains("pwd") || lower.contains("secret")
        || lower.contains("token") || lower.contains("database_url") || lower.contains("orm_connectionurl")
        || lower.contains("passwd")
}
