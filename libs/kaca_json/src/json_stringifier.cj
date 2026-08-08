package kaca_json

import std.collection.*

let EMPTY_FILTER: ArrayList<String> = ArrayList<String>()

private enum SerializeMode {
    | CompactNoFilter
    | CompactFilter
    | PrettySpaceNoFilter
    | PrettySpaceFilter
    | PrettyStrNoFilter
    | PrettyStrFilter
}

private class SerializePlan {
    public let mode: SerializeMode
    public let space: Int64
    public let spaceStr: String
    public let filter: ArrayList<String>

    public init(mode: SerializeMode, space: Int64, spaceStr: String, filter: ArrayList<String>) {
        this.mode = mode
        this.space = space
        this.spaceStr = spaceStr
        this.filter = filter
    }
}

public func stringify(value: JsonValue): String {
    stringifyWithPlan(value, SerializePlan(SerializeMode.CompactNoFilter, 0, "", EMPTY_FILTER))
}

public func stringify(value: JsonValue, space: Int64): String {
    let indent = if (space > 0) { space } else { 0 }
    if (indent > 0) {
        return stringifyWithPlan(value, SerializePlan(SerializeMode.PrettySpaceNoFilter, indent, "", EMPTY_FILTER))
    }
    stringifyWithPlan(value, SerializePlan(SerializeMode.CompactNoFilter, 0, "", EMPTY_FILTER))
}

public func stringify(value: JsonValue, space: String): String {
    if (space.size > 0) {
        return stringifyWithPlan(value, SerializePlan(SerializeMode.PrettyStrNoFilter, 0, space, EMPTY_FILTER))
    }
    stringifyWithPlan(value, SerializePlan(SerializeMode.CompactNoFilter, 0, "", EMPTY_FILTER))
}

public func stringifyWithFilter(value: JsonValue, filter: ArrayList<String>): String {
    stringifyWithPlan(value, SerializePlan(SerializeMode.CompactFilter, 0, "", filter))
}

public func stringifyWithFilter(value: JsonValue, filter: ArrayList<String>, space: Int64): String {
    let indent = if (space > 0) { space } else { 0 }
    if (indent > 0) {
        return stringifyWithPlan(value, SerializePlan(SerializeMode.PrettySpaceFilter, indent, "", filter))
    }
    stringifyWithPlan(value, SerializePlan(SerializeMode.CompactFilter, 0, "", filter))
}

public class StringifyOptions {
    public var space: Int64 = 0
    public var spaceStr: ?String = None
    public var filter: ?ArrayList<String> = None

    public init() {}

    public static func withIndent(indent: Int64): StringifyOptions {
        let opts = StringifyOptions()
        opts.space = indent
        opts
    }

    public static func withIndentStr(indent: String): StringifyOptions {
        let opts = StringifyOptions()
        opts.spaceStr = indent
        opts
    }

    public static func withFilter(filter: ArrayList<String>): StringifyOptions {
        let opts = StringifyOptions()
        opts.filter = filter
        opts
    }
}

public func stringifyWithOptions(value: JsonValue, options: StringifyOptions): String {
    if (let Some(spaceStr) <- options.spaceStr) {
        if (spaceStr.size > 0) {
            return stringifyWithPlan(value, buildSerializePlan(options))
        }
    }

    let indent = if (options.space > 0) { options.space } else { 0 }
    if (let Some(filter) <- options.filter) {
        if (indent > 0) {
            return stringifyWithPlan(value, SerializePlan(SerializeMode.PrettySpaceFilter, indent, "", filter))
        }
        return stringifyWithPlan(value, SerializePlan(SerializeMode.CompactFilter, 0, "", filter))
    }

    if (indent > 0) {
        return stringifyWithPlan(value, SerializePlan(SerializeMode.PrettySpaceNoFilter, indent, "", EMPTY_FILTER))
    }

    stringifyWithPlan(value, SerializePlan(SerializeMode.CompactNoFilter, 0, "", EMPTY_FILTER))
}

private func buildSerializePlan(options: StringifyOptions): SerializePlan {
    if (let Some(spaceStr) <- options.spaceStr) {
        if (spaceStr.size > 0) {
            if (let Some(filter) <- options.filter) {
                return SerializePlan(SerializeMode.PrettyStrFilter, 0, spaceStr, filter)
            }
            return SerializePlan(SerializeMode.PrettyStrNoFilter, 0, spaceStr, EMPTY_FILTER)
        }
    }

    let indent = if (options.space > 0) { options.space } else { 0 }
    if (let Some(filter) <- options.filter) {
        if (indent > 0) {
            return SerializePlan(SerializeMode.PrettySpaceFilter, indent, "", filter)
        }
        return SerializePlan(SerializeMode.CompactFilter, 0, "", filter)
    }

    if (indent > 0) {
        return SerializePlan(SerializeMode.PrettySpaceNoFilter, indent, "", EMPTY_FILTER)
    }

    SerializePlan(SerializeMode.CompactNoFilter, 0, "", EMPTY_FILTER)
}

private func stringifyWithPlan(value: JsonValue, plan: SerializePlan): String {
    let writer = StringBuilder(256)

    match (plan.mode) {
        case SerializeMode.CompactNoFilter => writeCompactNoFilter(writer, value)
        case SerializeMode.CompactFilter => writeCompactFilter(writer, value, plan.filter)
        case SerializeMode.PrettySpaceNoFilter => writePrettySpaceNoFilter(writer, value, plan.space, 0)
        case SerializeMode.PrettySpaceFilter => writePrettySpaceFilter(writer, value, plan.space, 0, plan.filter)
        case SerializeMode.PrettyStrNoFilter => writePrettyStrNoFilter(writer, value, plan.spaceStr, 0)
        case SerializeMode.PrettyStrFilter => writePrettyStrFilter(writer, value, plan.spaceStr, 0, plan.filter)
    }

    writer.build()
}

private func writeCompactNoFilter(writer: StringBuilder, value: JsonValue): Unit {
    match (value) {
        case JsonNull => writer.append("null")
        case JsonBool(b) => writer.append(b.toString())
        case JsonNumber(n) => writer.append(numberToString(n))
        case JsonString(s) => appendEscapedString(writer, s)
        case JsonArray(arr) => writeArrayCompactNoFilter(writer, arr)
        case JsonObject(obj) => writeObjectCompactNoFilter(writer, obj)
    }
}

private func writeArrayCompactNoFilter(writer: StringBuilder, arr: ArrayList<JsonValue>): Unit {
    writer.append("[")

    let len = arr.size
    var i: Int64 = 0
    while (i < len) {
        if (i > 0) {
            writer.append(",")
        }
        writeCompactNoFilter(writer, arr[i])
        i += 1
    }

    writer.append("]")
}

private func writeObjectCompactNoFilter(writer: StringBuilder, obj: HashMap<String, JsonValue>): Unit {
    writer.append("{")

    var first = true
    for ((key, val) in obj) {
        if (!first) {
            writer.append(",")
        }
        first = false
        appendEscapedString(writer, key)
        writer.append(":")
        writeCompactNoFilter(writer, val)
    }

    writer.append("}")
}

private func writeCompactFilter(writer: StringBuilder, value: JsonValue, filter: ArrayList<String>): Unit {
    match (value) {
        case JsonNull => writer.append("null")
        case JsonBool(b) => writer.append(b.toString())
        case JsonNumber(n) => writer.append(numberToString(n))
        case JsonString(s) => appendEscapedString(writer, s)
        case JsonArray(arr) => writeArrayCompactFilter(writer, arr, filter)
        case JsonObject(obj) => writeObjectCompactFilter(writer, obj, filter)
    }
}

private func writeArrayCompactFilter(writer: StringBuilder, arr: ArrayList<JsonValue>, filter: ArrayList<String>): Unit {
    writer.append("[")

    let len = arr.size
    var i: Int64 = 0
    while (i < len) {
        if (i > 0) {
            writer.append(",")
        }
        writeCompactFilter(writer, arr[i], filter)
        i += 1
    }

    writer.append("]")
}

private func writeObjectCompactFilter(writer: StringBuilder, obj: HashMap<String, JsonValue>, filter: ArrayList<String>): Unit {
    writer.append("{")

    var first = true
    for (key in filter) {
        let valOpt = getFieldFromMap(obj, key)
        if (let Some(val) <- valOpt) {
            if (!first) {
                writer.append(",")
            }
            first = false
            appendEscapedString(writer, key)
            writer.append(":")
            writeCompactFilter(writer, val, filter)
        }
    }

    writer.append("}")
}

private func writePrettySpaceNoFilter(writer: StringBuilder, value: JsonValue, space: Int64, level: Int64): Unit {
    match (value) {
        case JsonNull => writer.append("null")
        case JsonBool(b) => writer.append(b.toString())
        case JsonNumber(n) => writer.append(numberToString(n))
        case JsonString(s) => appendEscapedString(writer, s)
        case JsonArray(arr) => writeArrayPrettySpaceNoFilter(writer, arr, space, level)
        case JsonObject(obj) => writeObjectPrettySpaceNoFilter(writer, obj, space, level)
    }
}

private func writeArrayPrettySpaceNoFilter(writer: StringBuilder, arr: ArrayList<JsonValue>, space: Int64, level: Int64): Unit {
    if (arr.size == 0) {
        writer.append("[]")
        return
    }

    writer.append("[\n")

    let len = arr.size
    var i: Int64 = 0
    while (i < len) {
        appendIndentSpaces(writer, space * (level + 1))
        writePrettySpaceNoFilter(writer, arr[i], space, level + 1)
        if (i < len - 1) {
            writer.append(",")
        }
        writer.append("\n")
        i += 1
    }

    appendIndentSpaces(writer, space * level)
    writer.append("]")
}

private func writeObjectPrettySpaceNoFilter(writer: StringBuilder, obj: HashMap<String, JsonValue>, space: Int64, level: Int64): Unit {
    if (obj.size == 0) {
        writer.append("{}")
        return
    }

    writer.append("{\n")

    var first = true
    for ((key, val) in obj) {
        if (!first) {
            writer.append(",\n")
        }
        first = false
        appendIndentSpaces(writer, space * (level + 1))
        appendEscapedString(writer, key)
        writer.append(": ")
        writePrettySpaceNoFilter(writer, val, space, level + 1)
    }

    writer.append("\n")
    appendIndentSpaces(writer, space * level)
    writer.append("}")
}

private func writePrettySpaceFilter(writer: StringBuilder, value: JsonValue, space: Int64, level: Int64, filter: ArrayList<String>): Unit {
    match (value) {
        case JsonNull => writer.append("null")
        case JsonBool(b) => writer.append(b.toString())
        case JsonNumber(n) => writer.append(numberToString(n))
        case JsonString(s) => appendEscapedString(writer, s)
        case JsonArray(arr) => writeArrayPrettySpaceFilter(writer, arr, space, level, filter)
        case JsonObject(obj) => writeObjectPrettySpaceFilter(writer, obj, space, level, filter)
    }
}

private func writeArrayPrettySpaceFilter(writer: StringBuilder, arr: ArrayList<JsonValue>, space: Int64, level: Int64, filter: ArrayList<String>): Unit {
    if (arr.size == 0) {
        writer.append("[]")
        return
    }

    writer.append("[\n")

    let len = arr.size
    var i: Int64 = 0
    while (i < len) {
        appendIndentSpaces(writer, space * (level + 1))
        writePrettySpaceFilter(writer, arr[i], space, level + 1, filter)
        if (i < len - 1) {
            writer.append(",")
        }
        writer.append("\n")
        i += 1
    }

    appendIndentSpaces(writer, space * level)
    writer.append("]")
}

private func writeObjectPrettySpaceFilter(writer: StringBuilder, obj: HashMap<String, JsonValue>, space: Int64, level: Int64, filter: ArrayList<String>): Unit {
    if (obj.size == 0) {
        writer.append("{}")
        return
    }

    writer.append("{\n")

    var first = true
    for (key in filter) {
        let valOpt = getFieldFromMap(obj, key)
        if (let Some(val) <- valOpt) {
            if (!first) {
                writer.append(",\n")
            }
            first = false
            appendIndentSpaces(writer, space * (level + 1))
            appendEscapedString(writer, key)
            writer.append(": ")
            writePrettySpaceFilter(writer, val, space, level + 1, filter)
        }
    }

    writer.append("\n")
    appendIndentSpaces(writer, space * level)
    writer.append("}")
}

private func writePrettyStrNoFilter(writer: StringBuilder, value: JsonValue, spaceStr: String, level: Int64): Unit {
    match (value) {
        case JsonNull => writer.append("null")
        case JsonBool(b) => writer.append(b.toString())
        case JsonNumber(n) => writer.append(numberToString(n))
        case JsonString(s) => appendEscapedString(writer, s)
        case JsonArray(arr) => writeArrayPrettyStrNoFilter(writer, arr, spaceStr, level)
        case JsonObject(obj) => writeObjectPrettyStrNoFilter(writer, obj, spaceStr, level)
    }
}

private func writeArrayPrettyStrNoFilter(writer: StringBuilder, arr: ArrayList<JsonValue>, spaceStr: String, level: Int64): Unit {
    if (arr.size == 0) {
        writer.append("[]")
        return
    }

    writer.append("[\n")

    let len = arr.size
    var i: Int64 = 0
    while (i < len) {
        appendIndentStr(writer, spaceStr, level + 1)
        writePrettyStrNoFilter(writer, arr[i], spaceStr, level + 1)
        if (i < len - 1) {
            writer.append(",")
        }
        writer.append("\n")
        i += 1
    }

    appendIndentStr(writer, spaceStr, level)
    writer.append("]")
}

private func writeObjectPrettyStrNoFilter(writer: StringBuilder, obj: HashMap<String, JsonValue>, spaceStr: String, level: Int64): Unit {
    if (obj.size == 0) {
        writer.append("{}")
        return
    }

    writer.append("{\n")

    var first = true
    for ((key, val) in obj) {
        if (!first) {
            writer.append(",\n")
        }
        first = false
        appendIndentStr(writer, spaceStr, level + 1)
        appendEscapedString(writer, key)
        writer.append(": ")
        writePrettyStrNoFilter(writer, val, spaceStr, level + 1)
    }

    writer.append("\n")
    appendIndentStr(writer, spaceStr, level)
    writer.append("}")
}

private func writePrettyStrFilter(writer: StringBuilder, value: JsonValue, spaceStr: String, level: Int64, filter: ArrayList<String>): Unit {
    match (value) {
        case JsonNull => writer.append("null")
        case JsonBool(b) => writer.append(b.toString())
        case JsonNumber(n) => writer.append(numberToString(n))
        case JsonString(s) => appendEscapedString(writer, s)
        case JsonArray(arr) => writeArrayPrettyStrFilter(writer, arr, spaceStr, level, filter)
        case JsonObject(obj) => writeObjectPrettyStrFilter(writer, obj, spaceStr, level, filter)
    }
}

private func writeArrayPrettyStrFilter(writer: StringBuilder, arr: ArrayList<JsonValue>, spaceStr: String, level: Int64, filter: ArrayList<String>): Unit {
    if (arr.size == 0) {
        writer.append("[]")
        return
    }

    writer.append("[\n")

    let len = arr.size
    var i: Int64 = 0
    while (i < len) {
        appendIndentStr(writer, spaceStr, level + 1)
        writePrettyStrFilter(writer, arr[i], spaceStr, level + 1, filter)
        if (i < len - 1) {
            writer.append(",")
        }
        writer.append("\n")
        i += 1
    }

    appendIndentStr(writer, spaceStr, level)
    writer.append("]")
}

private func writeObjectPrettyStrFilter(writer: StringBuilder, obj: HashMap<String, JsonValue>, spaceStr: String, level: Int64, filter: ArrayList<String>): Unit {
    if (obj.size == 0) {
        writer.append("{}")
        return
    }

    writer.append("{\n")

    var first = true
    for (key in filter) {
        let valOpt = getFieldFromMap(obj, key)
        if (let Some(val) <- valOpt) {
            if (!first) {
                writer.append(",\n")
            }
            first = false
            appendIndentStr(writer, spaceStr, level + 1)
            appendEscapedString(writer, key)
            writer.append(": ")
            writePrettyStrFilter(writer, val, spaceStr, level + 1, filter)
        }
    }

    writer.append("\n")
    appendIndentStr(writer, spaceStr, level)
    writer.append("}")
}

private let ESCAPE_MAP: Array<String> = [
    "\\u0000","\\u0001","\\u0002","\\u0003","\\u0004","\\u0005","\\u0006","\\u0007",
    "\\b","\\t","\\n","\\u000B","\\f","\\r","\\u000E","\\u000F",
    "\\u0010","\\u0011","\\u0012","\\u0013","\\u0014","\\u0015","\\u0016","\\u0017",
    "\\u0018","\\u0019","\\u001A","\\u001B","\\u001C","\\u001D","\\u001E","\\u001F",
    " ","!", "\\\"", "#","$","%","&","'",
    "(",")","*","+",",","-",".","/",
    "0","1","2","3","4","5","6","7",
    "8","9",":",";","<","=",">","?",
    "@","A","B","C","D","E","F","G",
    "H","I","J","K","L","M","N","O",
    "P","Q","R","S","T","U","V","W",
    "X","Y","Z","[","\\\\","]","^","_",
    "`","a","b","c","d","e","f","g",
    "h","i","j","k","l","m","n","o",
    "p","q","r","s","t","u","v","w",
    "x","y","z","{","|","}","~",""
]

private func appendEscapedString(writer: StringBuilder, s: String): Unit {
    writer.append("\"")

    let bytes = stringToBytes(s)
    var i: Int64 = 0
    let len = bytes.size

    while (i < len) {
        let b = bytes[i]
        let idx = Int64(UInt8(b))

        if (idx < 128) {
            if (idx >= 0x20 && idx != 0x22 && idx != 0x5C) {
                writer.appendByte(b)
            } else {
                writer.append(ESCAPE_MAP[idx])
            }
            i += 1
        } else {
            let (r, byteLen) = utf8DecodeByte(bytes, i)
            writer.append(r)
            i += byteLen
        }
    }

    writer.append("\"")
}

private func appendIndentSpaces(writer: StringBuilder, count: Int64): Unit {
    var i: Int64 = 0
    while (i < count) {
        writer.append(r' ')
        i += 1
    }
}

private func appendIndentStr(writer: StringBuilder, s: String, count: Int64): Unit {
    var i: Int64 = 0
    while (i < count) {
        writer.append(s)
        i += 1
    }
}

private func numberToString(n: Float64): String {
    if (n != n) {
        return "null"
    }
    if (n > 1.7976931348623157e308) {
        return "null"
    }
    if (n < -1.7976931348623157e308) {
        return "null"
    }

    let intVal = Int64(n)
    if (n == Float64(intVal) && intVal >= -9007199254740992 && intVal <= 9007199254740992) {
        return intVal.toString()
    }

    n.toString()
}

private func getFieldFromMap(obj: HashMap<String, JsonValue>, key: String): ?JsonValue {
    obj.get(key)
}














class StringBuilder {
    private var builder: ByteBuilder

    public init(capacity: Int64) {
        this.builder = ByteBuilder(capacity)
    }

    public func append(s: String): Unit {
        builder.appendString(s)
    }

    public func append(ch: Rune): Unit {
        builder.appendRune(ch)
    }

    public func appendByte(b: Byte): Unit {
        builder.append(b)
    }

    public func build(): String {
        builder.build()
    }
}

