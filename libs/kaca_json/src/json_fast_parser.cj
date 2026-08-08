package kaca_json

import std.collection.*

public enum FastValue {
    | FastNull
    | FastTrue
    | FastFalse
    | FastString(Array<Byte>, Int64, Int64)
    | FastNumber(Array<Byte>, Int64, Int64)
    | FastArray(Array<Byte>, Int64, Int64)
    | FastObject(Array<Byte>, Int64, Int64)

    public func getString(): String {
        match (this) {
            case FastString(bytes, start, len) => buildFastString(bytes, start, len)
            case _ => ""
        }
    }

    public func getNumber(): Float64 {
        match (this) {
            case FastNumber(bytes, start, len) => parseJsonNumberBytes(bytes, start, len)
            case _ => 0.0
        }
    }

    public func getArray(): ArrayList<FastValue> {
        match (this) {
            case FastArray(bytes, start, end) => parseFastArray(bytes, start, end)
            case _ => ArrayList<FastValue>()
        }
    }

    public func getObject(): HashMap<String, FastValue> {
        match (this) {
            case FastObject(bytes, start, end) => parseFastObject(bytes, start, end)
            case _ => HashMap<String, FastValue>()
        }
    }

    public func toJsonValue(): JsonValue {
        match (this) {
            case FastNull => JsonValue.JsonNull
            case FastTrue => JsonValue.JsonBool(true)
            case FastFalse => JsonValue.JsonBool(false)
            case FastString(_, _, _) => JsonValue.JsonString(getString())
            case FastNumber(_, _, _) => JsonValue.JsonNumber(getNumber())
            case FastArray(bytes, start, end) => JsonValue.JsonArray(parseFastArrayToJson(bytes, start, end))
            case FastObject(bytes, start, end) => JsonValue.JsonObject(parseFastObjectToJson(bytes, start, end))
        }
    }
}

// Lookup table for JSON escape byte decoding.
// Maps escape character byte -> decoded byte; 0 means not a standard escape.
private let ESCAPE_BYTE_MAP: Array<UInt8> = initEscapeByteMap()

private func initEscapeByteMap(): Array<UInt8> {
    let t = Array<UInt8>(256, {_ => 0})
    t[0x22] = UInt8(0x22)    // " -> "
    t[0x5C] = UInt8(0x5C)    // \ -> \
    t[0x2F] = UInt8(0x2F)    // / -> /
    t[0x62] = UInt8(0x08)    // b -> backspace
    t[0x66] = UInt8(0x0C)    // f -> form feed
    t[0x6E] = UInt8(0x0A)    // n -> newline
    t[0x72] = UInt8(0x0D)    // r -> carriage return
    t[0x74] = UInt8(0x09)    // t -> tab
    t
}

private func buildFastString(bytes: Array<Byte>, start: Int64, len: Int64): String {
    if (len <= 0) { return "" }
    let end = start + len
    var pos = start
    var hasEsc = false
    while (pos < end) {
        if (bytes[pos] == 0x5C) { hasEsc = true; break }
        pos += 1
    }
    if (!hasEsc) {
        return unsafe { String.withRawData(bytes[start..end]) }
    }
    let builder = ByteBuilder(len)
    pos = start
    while (pos < end) {
        let b = bytes[pos]
        if (b == 0x5C && pos + 1 < end) {
            pos += 1
            let e = bytes[pos]
            let decoded = ESCAPE_BYTE_MAP[Int64(UInt8(e))]
            if (decoded != 0) {
                builder.append(UInt8(decoded))
            } else if (e == 0x75 && pos + 4 < end) {
                let cp = hex4Fast(bytes, pos + 1)
                pos += 4
                if (isHighSurrogate(cp)) {
                    let next = pos + 1
                    if (next + 5 < end && bytes[next] == 0x5C && bytes[next + 1] == 0x75) {
                        let low = hex4Fast(bytes, next + 2)
                        if (isLowSurrogate(low)) {
                            builder.appendCodePoint(combineSurrogatePair(cp, low))
                            pos = next + 5
                        } else {
                            builder.appendCodePoint(cp)
                        }
                    } else {
                        builder.appendCodePoint(cp)
                    }
                } else {
                    builder.appendCodePoint(cp)
                }
            } else { builder.append(e) }
        } else { builder.append(b) }
        pos += 1
    }
    builder.build()
}

private func hex4Fast(bytes: Array<Byte>, pos: Int64): Int64 {
    var cp: Int64 = 0
    cp = (cp * 16) + hexValueFast(bytes[pos])
    cp = (cp * 16) + hexValueFast(bytes[pos + 1])
    cp = (cp * 16) + hexValueFast(bytes[pos + 2])
    cp = (cp * 16) + hexValueFast(bytes[pos + 3])
    cp
}

private func hexValueFast(b: Byte): Int64 {
    if (b >= 0x30 && b <= 0x39) { return Int64(b - 0x30) }
    if (b >= 0x41 && b <= 0x46) { return Int64(b - 0x41 + 10) }
    if (b >= 0x61 && b <= 0x66) { return Int64(b - 0x61 + 10) }
    0
}

private func estimateFastArraySize(contentLen: Int64): Int64 {
    if (contentLen <= 2) { return 0 }
    let avgItemSize: Int64 = 16
    let est = contentLen / avgItemSize
    if (est < 4) { 4 } else if (est > 1024) { 1024 } else { est }
}

private func estimateFastObjectSize(contentLen: Int64): Int64 {
    if (contentLen <= 2) { return 0 }
    // Heuristic tuned for common JSON objects with nested values:
    // use denser estimate for small/medium objects, but cap large payloads
    // to avoid huge over-allocation on top-level containers.
    let est = if (contentLen <= 256) {
        contentLen / 12
    } else if (contentLen <= 2048) {
        contentLen / 18
    } else {
        64
    }
    if (est < 6) { 6 } else if (est > 256) { 256 } else { est }
}

private func skipWhitespaceFast(bytes: Array<Byte>, pos: Int64, end: Int64): Int64 {
    var p = pos
    if (p >= end) { return p }
    let b0 = bytes[p]
    if (b0 != 0x20 && b0 != 0x09 && b0 != 0x0D && b0 != 0x0A) { return p }
    p += 1
    while (p < end) {
        let b = bytes[p]
        if (b == 0x20 || b == 0x09 || b == 0x0D || b == 0x0A) {
            p += 1
        } else {
            break
        }
    }
    p
}

private func skipStringFast(bytes: Array<Byte>, start: Int64, end: Int64): Int64 {
    var pos = start
    while (pos < end) {
        if (bytes[pos] == 0x22) { return pos }
        if (bytes[pos] == 0x5C) { pos += 2 } else { pos += 1 }
    }
    end
}

private func skipStringAndEscapeFast(bytes: Array<Byte>, start: Int64, end: Int64): (Int64, Bool) {
    var pos = start
    var hasEsc = false
    while (pos < end) {
        if (bytes[pos] == 0x22) { return (pos, hasEsc) }
        if (bytes[pos] == 0x5C) {
            hasEsc = true
            pos += 2
        } else {
            pos += 1
        }
    }
    (end, hasEsc)
}

private func parseFastArray(bytes: Array<Byte>, start: Int64, end: Int64): ArrayList<FastValue> {
    let contentLen = end - start - 2
    let initCap = estimateFastArraySize(contentLen)
    let result = ArrayList<FastValue>(initCap)
    var pos = start + 1
    let limit = end - 1
    if (pos >= limit) { return result }
    while (pos < limit) {
        pos = skipWhitespaceFast(bytes, pos, limit)
        if (pos >= limit || bytes[pos] == 0x5D) { break }
        let (value, newPos) = parseFastValueNestedNoSkip(bytes, pos, limit)
        result.add(value)
        pos = newPos
        if (pos < limit && bytes[pos] == 0x2C) { pos += 1 }
    }
    result
}

private func parseFastObject(bytes: Array<Byte>, start: Int64, end: Int64): HashMap<String, FastValue> {
    let contentLen = end - start - 2
    let initCap = estimateFastObjectSize(contentLen)
    let result = HashMap<String, FastValue>(initCap)
    var pos = start + 1
    let limit = end - 1
    if (pos >= limit) { return result }
    while (pos < limit) {
        pos = skipWhitespaceFast(bytes, pos, limit)
        if (pos >= limit || bytes[pos] == 0x7D) { break }
        if (bytes[pos] != 0x22) {
            pos += 1
            continue
        }
        let keyStart = pos + 1
        let (keyEnd, keyHasEsc) = skipStringAndEscapeFast(bytes, keyStart, limit)
        let key = if (!keyHasEsc) {
            unsafe { String.withRawData(bytes[keyStart..keyEnd]) }
        } else {
            buildFastString(bytes, keyStart, keyEnd - keyStart)
        }
        pos = keyEnd + 1
        pos = skipWhitespaceFast(bytes, pos, limit)
        if (pos < limit && bytes[pos] == 0x3A) { pos += 1 }
        pos = skipWhitespaceFast(bytes, pos, limit)
        let (value, newPos) = parseFastValueNestedNoSkip(bytes, pos, limit)
        result[key] = value
        pos = newPos
        if (pos < limit && bytes[pos] == 0x2C) { pos += 1 }
    }
    result
}

private func parseFastJsonValueNestedNoSkip(bytes: Array<Byte>, pos: Int64, end: Int64): (JsonValue, Int64) {
    let b = bytes[pos]
    if (b == 0x22) {
        let s = pos + 1
        let (e, hasEsc) = skipStringAndEscapeFast(bytes, s, end)
        let value = if (!hasEsc) {
            unsafe { String.withRawData(bytes[s..e]) }
        } else {
            buildFastString(bytes, s, e - s)
        }
        return (JsonValue.JsonString(value), e + 1)
    }
    if (b == 0x5B) {
        return parseFastArrayValueToJson(bytes, pos, end)
    }
    if (b == 0x7B) {
        return parseFastObjectValueToJson(bytes, pos, end)
    }
    if (isDigitFast(b) || b == 0x2D) {
        let numEnd = scanNumberFastShared(bytes, pos, end)
        return (JsonValue.JsonNumber(parseJsonNumberBytes(bytes, pos, numEnd - pos)), numEnd)
    }
    if (b == 0x74 && pos + 4 <= end && bytes[pos + 1] == 0x72 && bytes[pos + 2] == 0x75 && bytes[pos + 3] == 0x65) {
        return (JsonValue.JsonBool(true), pos + 4)
    }
    if (b == 0x66 && pos + 5 <= end && bytes[pos + 1] == 0x61 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x73 && bytes[pos + 4] == 0x65) {
        return (JsonValue.JsonBool(false), pos + 5)
    }
    if (b == 0x6E && pos + 4 <= end && bytes[pos + 1] == 0x75 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x6C) {
        return (JsonValue.JsonNull, pos + 4)
    }
    (JsonValue.JsonNull, pos + 1)
}

private func parseFastArrayValueToJson(bytes: Array<Byte>, start: Int64, end: Int64): (JsonValue, Int64) {
    let contentLen = end - start - 2
    let initCap = estimateFastArraySize(contentLen)
    let result = ArrayList<JsonValue>(initCap)
    var pos = start + 1
    pos = skipWhitespaceFast(bytes, pos, end)
    if (pos < end && bytes[pos] == 0x5D) {
        return (JsonValue.JsonArray(result), pos + 1)
    }
    while (pos < end) {
        let (value, newPos) = parseFastJsonValueNestedNoSkip(bytes, pos, end)
        result.add(value)
        pos = newPos
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos < end && bytes[pos] == 0x2C) {
            pos += 1
            pos = skipWhitespaceFast(bytes, pos, end)
            continue
        }
        if (pos < end && bytes[pos] == 0x5D) {
            return (JsonValue.JsonArray(result), pos + 1)
        }
        break
    }
    (JsonValue.JsonArray(result), pos)
}

private func parseFastObjectValueToJson(bytes: Array<Byte>, start: Int64, end: Int64): (JsonValue, Int64) {
    var pos = start + 1
    pos = skipWhitespaceFast(bytes, pos, end)
    if (pos < end && bytes[pos] == 0x7D) {
        return (JsonValue.JsonObject(HashMap<String, JsonValue>(0)), pos + 1)
    }
    let result = HashMap<String, JsonValue>()
    while (pos < end) {
        if (bytes[pos] != 0x22) { break }
        let keyStart = pos + 1
        let (keyEnd, keyHasEsc) = skipStringAndEscapeFast(bytes, keyStart, end)
        let key = if (!keyHasEsc) {
            unsafe { String.withRawData(bytes[keyStart..keyEnd]) }
        } else {
            buildFastString(bytes, keyStart, keyEnd - keyStart)
        }
        pos = keyEnd + 1
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos < end && bytes[pos] == 0x3A) { pos += 1 }
        pos = skipWhitespaceFast(bytes, pos, end)
        let (value, newPos) = parseFastJsonValueNestedNoSkip(bytes, pos, end)
        result[key] = value
        pos = newPos
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos < end && bytes[pos] == 0x2C) {
            pos += 1
            pos = skipWhitespaceFast(bytes, pos, end)
            continue
        }
        if (pos < end && bytes[pos] == 0x7D) {
            return (JsonValue.JsonObject(result), pos + 1)
        }
        break
    }
    (JsonValue.JsonObject(result), pos)
}

private func parseFastArrayToJson(bytes: Array<Byte>, start: Int64, end: Int64): ArrayList<JsonValue> {
    let (value, _) = parseFastArrayValueToJson(bytes, start, end)
    match (value) {
        case JsonValue.JsonArray(arr) => arr
        case _ => ArrayList<JsonValue>(0)
    }
}

private func parseFastObjectToJson(bytes: Array<Byte>, start: Int64, end: Int64): HashMap<String, JsonValue> {
    let (value, _) = parseFastObjectValueToJson(bytes, start, end)
    match (value) {
        case JsonValue.JsonObject(obj) => obj
        case _ => HashMap<String, JsonValue>(0)
    }
}

private func skipBracketFast(bytes: Array<Byte>, start: Int64, end: Int64, open: Byte, close: Byte): Int64 {
    var pos = start + 1
    var depth = 1
    while (pos < end && depth > 0) {
        let b = bytes[pos]
        if (b == 0x22) {
            pos = skipStringFast(bytes, pos + 1, end) + 1
        } else if (b == open) {
            depth += 1
            pos += 1
        } else if (b == close) {
            depth -= 1
            pos += 1
        } else {
            pos += 1
        }
    }
    pos
}

private func isDigitFast(b: Byte): Bool { b >= 0x30 && b <= 0x39 }

private func parseFastValueNestedNoSkip(bytes: Array<Byte>, pos: Int64, end: Int64): (FastValue, Int64) {
    let b = bytes[pos]
    if (b == 0x22) {
        let s = pos + 1
        let e = skipStringFast(bytes, s, end)
        return (FastValue.FastString(bytes, s, e - s), e + 1)
    }
    if (b == 0x5B) {
        let arrEnd = skipBracketFast(bytes, pos, end, 0x5B, 0x5D)
        return (FastValue.FastArray(bytes, pos, arrEnd), arrEnd)
    }
    if (b == 0x7B) {
        let objEnd = skipBracketFast(bytes, pos, end, 0x7B, 0x7D)
        return (FastValue.FastObject(bytes, pos, objEnd), objEnd)
    }
    if (isDigitFast(b) || b == 0x2D) {
        let numEnd = scanNumberFastShared(bytes, pos, end)
        return (FastValue.FastNumber(bytes, pos, numEnd - pos), numEnd)
    }
    if (b == 0x74 && pos + 4 <= end && bytes[pos + 1] == 0x72 && bytes[pos + 2] == 0x75 && bytes[pos + 3] == 0x65) {
        return (FastValue.FastTrue, pos + 4)
    }
    if (b == 0x66 && pos + 5 <= end && bytes[pos + 1] == 0x61 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x73 && bytes[pos + 4] == 0x65) {
        return (FastValue.FastFalse, pos + 5)
    }
    if (b == 0x6E && pos + 4 <= end && bytes[pos + 1] == 0x75 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x6C) {
        return (FastValue.FastNull, pos + 4)
    }
    (FastValue.FastNull, pos + 1)
}

public func scanNumberFastShared(bytes: Array<Byte>, start: Int64, end: Int64): Int64 {
    var pos = start
    if (pos < end && bytes[pos] == 0x2D) { pos += 1 }
    if (pos < end && bytes[pos] == 0x30) { pos += 1 }
    else { while (pos < end && isDigitFast(bytes[pos])) { pos += 1 } }
    if (pos < end && bytes[pos] == 0x2E) {
        pos += 1
        while (pos < end && isDigitFast(bytes[pos])) { pos += 1 }
    }
    if (pos < end && (bytes[pos] == 0x65 || bytes[pos] == 0x45)) {
        pos += 1
        if (pos < end && (bytes[pos] == 0x2B || bytes[pos] == 0x2D)) { pos += 1 }
        while (pos < end && isDigitFast(bytes[pos])) { pos += 1 }
    }
    pos
}

private func parseFastTopLevelStrict(bytes: Array<Byte>): FastValue {
    let end = bytes.size
    let start = skipWhitespaceFast(bytes, 0, end)
    if (start >= end) {
        throw parseError("Unexpected end of input", 1, 1)
    }
    let (value, newPos) = parseFastValueStrictTop(bytes, start, end)
    let tail = skipWhitespaceFast(bytes, newPos, end)
    if (tail != end) {
        throw parseError("Unexpected token after JSON value", 1, tail + 1)
    }
    value
}

private func parseFastValueStrictTop(bytes: Array<Byte>, pos: Int64, end: Int64): (FastValue, Int64) {
    let b = bytes[pos]
    if (b == 0x22) {
        let next = parseStringStrictFast(bytes, pos, end)
        return (FastValue.FastString(bytes, pos + 1, next - pos - 2), next)
    }
    if (b == 0x5B) {
        let next = parseArrayStrictFast(bytes, pos, end)
        return (FastValue.FastArray(bytes, pos, next), next)
    }
    if (b == 0x7B) {
        let next = parseObjectStrictFast(bytes, pos, end)
        return (FastValue.FastObject(bytes, pos, next), next)
    }
    if (b == 0x2D || isDigitFast(b)) {
        let next = parseNumberStrictFast(bytes, pos, end)
        return (FastValue.FastNumber(bytes, pos, next - pos), next)
    }
    if (b == 0x74 && pos + 4 <= end && bytes[pos + 1] == 0x72 && bytes[pos + 2] == 0x75 && bytes[pos + 3] == 0x65) {
        return (FastValue.FastTrue, pos + 4)
    }
    if (b == 0x66 && pos + 5 <= end && bytes[pos + 1] == 0x61 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x73 && bytes[pos + 4] == 0x65) {
        return (FastValue.FastFalse, pos + 5)
    }
    if (b == 0x6E && pos + 4 <= end && bytes[pos + 1] == 0x75 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x6C) {
        return (FastValue.FastNull, pos + 4)
    }
    throw parseError("Unexpected token", 1, pos + 1)
}

private func parseValueStrictFastNoSkip(bytes: Array<Byte>, pos: Int64, end: Int64): Int64 {
    let b = bytes[pos]
    if (b == 0x22) { return parseStringStrictFast(bytes, pos, end) }
    if (b == 0x5B) { return parseArrayStrictFast(bytes, pos, end) }
    if (b == 0x7B) { return parseObjectStrictFast(bytes, pos, end) }
    if (b == 0x2D || isDigitFast(b)) { return parseNumberStrictFast(bytes, pos, end) }
    if (b == 0x74 && pos + 4 <= end && bytes[pos + 1] == 0x72 && bytes[pos + 2] == 0x75 && bytes[pos + 3] == 0x65) { return pos + 4 }
    if (b == 0x66 && pos + 5 <= end && bytes[pos + 1] == 0x61 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x73 && bytes[pos + 4] == 0x65) { return pos + 5 }
    if (b == 0x6E && pos + 4 <= end && bytes[pos + 1] == 0x75 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x6C) { return pos + 4 }
    throw parseError("Unexpected token", 1, pos + 1)
}

private func parseObjectStrictFast(bytes: Array<Byte>, start: Int64, end: Int64): Int64 {
    var pos = start + 1
    pos = skipWhitespaceFast(bytes, pos, end)
    if (pos < end && bytes[pos] == 0x7D) {
        return pos + 1
    }
    while (true) {
        if (pos >= end || bytes[pos] != 0x22) {
            throw parseError("Expected string key", 1, pos + 1)
        }
        pos = parseStringStrictFast(bytes, pos, end)
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end || bytes[pos] != 0x3A) {
            throw parseError("Expected ':' after key", 1, pos + 1)
        }
        pos += 1
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end) {
            throw parseError("Unexpected end of input", 1, pos + 1)
        }
        pos = parseValueStrictFastNoSkip(bytes, pos, end)
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end) {
            throw parseError("Unterminated object", 1, pos + 1)
        }
        if (bytes[pos] == 0x7D) {
            return pos + 1
        }
        if (bytes[pos] == 0x2C) {
            pos += 1
            pos = skipWhitespaceFast(bytes, pos, end)
            if (pos < end && bytes[pos] == 0x7D) {
                throw parseError("Trailing comma in object", 1, pos + 1)
            }
            continue
        }
        throw parseError("Expected ',' or '}' in object", 1, pos + 1)
    }
    throw parseError("Unreachable object parse state", 1, pos + 1)
}

private func parseArrayStrictFast(bytes: Array<Byte>, start: Int64, end: Int64): Int64 {
    var pos = start + 1
    pos = skipWhitespaceFast(bytes, pos, end)
    if (pos < end && bytes[pos] == 0x5D) {
        return pos + 1
    }
    while (true) {
        if (pos >= end) {
            throw parseError("Unexpected end of input", 1, pos + 1)
        }
        pos = parseValueStrictFastNoSkip(bytes, pos, end)
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end) {
            throw parseError("Unterminated array", 1, pos + 1)
        }
        if (bytes[pos] == 0x5D) {
            return pos + 1
        }
        if (bytes[pos] == 0x2C) {
            pos += 1
            pos = skipWhitespaceFast(bytes, pos, end)
            if (pos < end && bytes[pos] == 0x5D) {
                throw parseError("Trailing comma in array", 1, pos + 1)
            }
            continue
        }
        throw parseError("Expected ',' or ']' in array", 1, pos + 1)
    }
    throw parseError("Unreachable array parse state", 1, pos + 1)
}

// Lookup table for fast string character classification.
// true for ASCII chars 0x20-0x7F excluding 0x22 (") and 0x5C (\).
private let FAST_CHAR_TABLE: Array<Bool> = initFastCharTable()

private func initFastCharTable(): Array<Bool> {
    let t = Array<Bool>(256, {_ => false})
    var i: Int64 = 0x20
    while (i <= 0x21) { t[i] = true; i += 1 }
    i = 0x23
    while (i <= 0x5B) { t[i] = true; i += 1 }
    i = 0x5D
    while (i <= 0x7F) { t[i] = true; i += 1 }
    t
}

private func parseStringStrictFast(bytes: Array<Byte>, start: Int64, end: Int64): Int64 {
    var p = start + 1
    while (p < end) {
        while (p < end && FAST_CHAR_TABLE[Int64(UInt8(bytes[p]))]) {
            p += 1
        }
        if (p >= end) { break }

        let b = bytes[p]
        if (b == 0x22) {
            return p + 1
        }
        if (b == 0x5C) {
            p += 1
            if (p >= end) {
                throw parseError("Unexpected end in string escape", 1, p + 1)
            }
            let e = bytes[p]
            p += 1
            if (ESCAPE_BYTE_MAP[Int64(UInt8(e))] != 0) {
                continue
            }
            if (e != 0x75) {
                throw parseError("Invalid escape sequence", 1, p + 1)
            }
            if (p + 4 > end) {
                throw parseError("Unexpected end in unicode escape", 1, p + 1)
            }
            let (codePoint, valid) = parseHexCodePoint(bytes, p)
            if (!valid) {
                throw parseError("Invalid unicode escape", 1, p + 1)
            }
            p += 4
            if (isHighSurrogate(codePoint)) {
                if (p + 6 > end || bytes[p] != 0x5C || bytes[p + 1] != 0x75) {
                    throw parseError("Expected low surrogate after high surrogate", 1, p + 1)
                }
                p += 2
                let (low, lowValid) = parseHexCodePoint(bytes, p)
                if (!lowValid || !isLowSurrogate(low)) {
                    throw parseError("Invalid low surrogate", 1, p + 1)
                }
                p += 4
            } else if (isLowSurrogate(codePoint)) {
                throw parseError("Lone low surrogate", 1, p + 1)
            }
            continue
        }
        if (UInt8(b) < UInt8(0x20)) {
            throw parseError("Unescaped control character in string", 1, p + 1)
        }
        if (UInt8(b) < UInt8(0x80)) {
            p += 1
            continue
        }

        let utf8Len = validateUtf8CharAtFast(bytes, p, end)
        if (utf8Len == 0) {
            throw parseError("Invalid UTF-8 sequence in string", 1, p + 1)
        }
        p += utf8Len
    }
    throw parseError("Unterminated string", 1, p + 1)
}

private func parseNumberStrictFast(bytes: Array<Byte>, start: Int64, end: Int64): Int64 {
    var p = start
    if (bytes[p] == 0x2D) {
        p += 1
        if (p >= end) {
            throw parseError("Invalid number", 1, p + 1)
        }
    }
    if (p >= end || !isDigitByte(bytes[p])) {
        throw parseError("Invalid number", 1, p + 1)
    }
    if (bytes[p] == 0x30) {
        p += 1
        if (p < end && isDigitByte(bytes[p])) {
            throw parseError("Leading zero in number", 1, p + 1)
        }
    } else {
        while (p < end && isDigitByte(bytes[p])) {
            p += 1
        }
    }
    if (p < end && bytes[p] == 0x2E) {
        p += 1
        if (p >= end || !isDigitByte(bytes[p])) {
            throw parseError("Missing fractional digits", 1, p + 1)
        }
        while (p < end && isDigitByte(bytes[p])) {
            p += 1
        }
    }
    if (p < end && (bytes[p] == 0x65 || bytes[p] == 0x45)) {
        p += 1
        if (p < end && (bytes[p] == 0x2B || bytes[p] == 0x2D)) {
            p += 1
        }
        if (p >= end || !isDigitByte(bytes[p])) {
            throw parseError("Missing exponent digits", 1, p + 1)
        }
        while (p < end && isDigitByte(bytes[p])) {
            p += 1
        }
    }
    p
}

private func validateUtf8CharAtFast(bytes: Array<Byte>, p: Int64, end: Int64): Int64 {
    let b0 = UInt8(bytes[p])
    if (b0 >= UInt8(0xC2) && b0 <= UInt8(0xDF)) {
        if (p + 1 >= end) { return 0 }
        let b1 = UInt8(bytes[p + 1])
        if ((b1 & 0xC0) != 0x80) { return 0 }
        return 2
    }
    if (b0 >= UInt8(0xE0) && b0 <= UInt8(0xEF)) {
        if (p + 2 >= end) { return 0 }
        let b1 = UInt8(bytes[p + 1])
        let b2 = UInt8(bytes[p + 2])
        if ((b2 & 0xC0) != 0x80) { return 0 }
        if (b0 == UInt8(0xE0)) {
            if (b1 < UInt8(0xA0) || b1 > UInt8(0xBF)) { return 0 }
            return 3
        }
        if (b0 == UInt8(0xED)) {
            if (b1 < UInt8(0x80) || b1 > UInt8(0x9F)) { return 0 }
            return 3
        }
        if ((b1 & 0xC0) != 0x80) { return 0 }
        return 3
    }
    if (b0 >= UInt8(0xF0) && b0 <= UInt8(0xF4)) {
        if (p + 3 >= end) { return 0 }
        let b1 = UInt8(bytes[p + 1])
        let b2 = UInt8(bytes[p + 2])
        let b3 = UInt8(bytes[p + 3])
        if ((b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) { return 0 }
        if (b0 == UInt8(0xF0)) {
            if (b1 < UInt8(0x90) || b1 > UInt8(0xBF)) { return 0 }
            return 4
        }
        if (b0 == UInt8(0xF4)) {
            if (b1 < UInt8(0x80) || b1 > UInt8(0x8F)) { return 0 }
            return 4
        }
        if ((b1 & 0xC0) != 0x80) { return 0 }
        return 4
    }
    0
}

private func parseJsonTopLevelStrict(bytes: Array<Byte>): JsonValue {
    let end = bytes.size
    let start = skipWhitespaceFast(bytes, 0, end)
    if (start >= end) {
        throw parseError("Unexpected end of input", 1, 1)
    }
    let (value, newPos) = parseJsonValueStrictNoSkip(bytes, start, end)
    let tail = skipWhitespaceFast(bytes, newPos, end)
    if (tail != end) {
        throw parseError("Unexpected token after JSON value", 1, tail + 1)
    }
    value
}

private func parseJsonValueStrictNoSkip(bytes: Array<Byte>, pos: Int64, end: Int64): (JsonValue, Int64) {
    let b = bytes[pos]
    if (b == 0x22) {
        let (s, next) = parseStringValueStrictFast(bytes, pos, end)
        return (JsonValue.JsonString(s), next)
    }
    if (b == 0x5B) {
        return parseArrayValueStrictFast(bytes, pos, end)
    }
    if (b == 0x7B) {
        return parseObjectValueStrictFast(bytes, pos, end)
    }
    if (b == 0x2D || isDigitFast(b)) {
        let next = parseNumberStrictFast(bytes, pos, end)
        return (JsonValue.JsonNumber(parseJsonNumberBytes(bytes, pos, next - pos)), next)
    }
    if (b == 0x74 && pos + 4 <= end && bytes[pos + 1] == 0x72 && bytes[pos + 2] == 0x75 && bytes[pos + 3] == 0x65) {
        return (JsonValue.JsonBool(true), pos + 4)
    }
    if (b == 0x66 && pos + 5 <= end && bytes[pos + 1] == 0x61 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x73 && bytes[pos + 4] == 0x65) {
        return (JsonValue.JsonBool(false), pos + 5)
    }
    if (b == 0x6E && pos + 4 <= end && bytes[pos + 1] == 0x75 && bytes[pos + 2] == 0x6C && bytes[pos + 3] == 0x6C) {
        return (JsonValue.JsonNull, pos + 4)
    }
    throw parseError("Unexpected token", 1, pos + 1)
}

private func parseObjectValueStrictFast(bytes: Array<Byte>, start: Int64, end: Int64): (JsonValue, Int64) {
    var pos = start + 1
    pos = skipWhitespaceFast(bytes, pos, end)
    if (pos < end && bytes[pos] == 0x7D) {
        return (JsonValue.JsonObject(HashMap<String, JsonValue>(0)), pos + 1)
    }
    let result = HashMap<String, JsonValue>()
    while (true) {
        if (pos >= end || bytes[pos] != 0x22) {
            throw parseError("Expected string key", 1, pos + 1)
        }
        let (key, keyNext) = parseStringValueStrictFast(bytes, pos, end)
        pos = keyNext
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end || bytes[pos] != 0x3A) {
            throw parseError("Expected ':' after key", 1, pos + 1)
        }
        pos += 1
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end) {
            throw parseError("Unexpected end of input", 1, pos + 1)
        }
        let (value, newPos) = parseJsonValueStrictNoSkip(bytes, pos, end)
        result[key] = value
        pos = newPos
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end) {
            throw parseError("Unterminated object", 1, pos + 1)
        }
        if (bytes[pos] == 0x7D) {
            return (JsonValue.JsonObject(result), pos + 1)
        }
        if (bytes[pos] == 0x2C) {
            pos += 1
            pos = skipWhitespaceFast(bytes, pos, end)
            if (pos < end && bytes[pos] == 0x7D) {
                throw parseError("Trailing comma in object", 1, pos + 1)
            }
            continue
        }
        throw parseError("Expected ',' or '}' in object", 1, pos + 1)
    }
    throw parseError("Unreachable object parse state", 1, pos + 1)
}

private func parseArrayValueStrictFast(bytes: Array<Byte>, start: Int64, end: Int64): (JsonValue, Int64) {
    let contentLen = end - start - 2
    let initCap = estimateFastArraySize(contentLen)
    let result = ArrayList<JsonValue>(initCap)
    var pos = start + 1
    pos = skipWhitespaceFast(bytes, pos, end)
    if (pos < end && bytes[pos] == 0x5D) {
        return (JsonValue.JsonArray(result), pos + 1)
    }
    while (true) {
        if (pos >= end) {
            throw parseError("Unexpected end of input", 1, pos + 1)
        }
        let (value, newPos) = parseJsonValueStrictNoSkip(bytes, pos, end)
        result.add(value)
        pos = newPos
        pos = skipWhitespaceFast(bytes, pos, end)
        if (pos >= end) {
            throw parseError("Unterminated array", 1, pos + 1)
        }
        if (bytes[pos] == 0x5D) {
            return (JsonValue.JsonArray(result), pos + 1)
        }
        if (bytes[pos] == 0x2C) {
            pos += 1
            pos = skipWhitespaceFast(bytes, pos, end)
            if (pos < end && bytes[pos] == 0x5D) {
                throw parseError("Trailing comma in array", 1, pos + 1)
            }
            continue
        }
        throw parseError("Expected ',' or ']' in array", 1, pos + 1)
    }
    throw parseError("Unreachable array parse state", 1, pos + 1)
}

private func parseStringValueStrictFast(bytes: Array<Byte>, start: Int64, end: Int64): (String, Int64) {
    var p = start + 1
    var segStart = p
    var hasBuilder = false
    var out = ByteBuilder(1)
    while (p < end) {
        while (p < end && FAST_CHAR_TABLE[Int64(UInt8(bytes[p]))]) {
            p += 1
        }
        if (p >= end) { break }

        let b = bytes[p]
        if (b == 0x22) {
            if (!hasBuilder) {
                return (unsafe { String.withRawData(bytes[start + 1..p]) }, p + 1)
            }
            if (p > segStart) {
                out.appendBytes(bytes, segStart, p - segStart)
            }
            return (out.build(), p + 1)
        }
        if (b == 0x5C) {
            if (!hasBuilder) {
                hasBuilder = true
                out = ByteBuilder(end - start)
            }
            if (p > segStart) {
                out.appendBytes(bytes, segStart, p - segStart)
            }
            p += 1
            if (p >= end) {
                throw parseError("Unexpected end in string escape", 1, p + 1)
            }
            let e = bytes[p]
            p += 1
            let decoded = ESCAPE_BYTE_MAP[Int64(UInt8(e))]
            if (decoded != 0) {
                out.append(UInt8(decoded))
            } else if (e == 0x75) {
                if (p + 4 > end) {
                    throw parseError("Unexpected end in unicode escape", 1, p + 1)
                }
                let (codePoint, valid) = parseHexCodePoint(bytes, p)
                if (!valid) {
                    throw parseError("Invalid unicode escape", 1, p + 1)
                }
                p += 4
                if (isHighSurrogate(codePoint)) {
                    if (p + 6 > end || bytes[p] != 0x5C || bytes[p + 1] != 0x75) {
                        throw parseError("Expected low surrogate after high surrogate", 1, p + 1)
                    }
                    p += 2
                    let (low, lowValid) = parseHexCodePoint(bytes, p)
                    if (!lowValid || !isLowSurrogate(low)) {
                        throw parseError("Invalid low surrogate", 1, p + 1)
                    }
                    p += 4
                    out.appendCodePoint(combineSurrogatePair(codePoint, low))
                } else if (isLowSurrogate(codePoint)) {
                    throw parseError("Lone low surrogate", 1, p + 1)
                } else {
                    out.appendCodePoint(codePoint)
                }
            } else {
                throw parseError("Invalid escape sequence", 1, p + 1)
            }
            segStart = p
            continue
        }
        if (UInt8(b) < UInt8(0x20)) {
            throw parseError("Unescaped control character in string", 1, p + 1)
        }
        if (UInt8(b) < UInt8(0x80)) {
            p += 1
            continue
        }

        let utf8Len = validateUtf8CharAtFast(bytes, p, end)
        if (utf8Len == 0) {
            throw parseError("Invalid UTF-8 sequence in string", 1, p + 1)
        }
        p += utf8Len
    }
    throw parseError("Unterminated string", 1, p + 1)
}

public func parseStrictJsonBytes(bytes: Array<Byte>): JsonValue {
    parseJsonTopLevelStrict(bytes)
}

public func parseFastBytes(bytes: Array<Byte>): FastValue {
    parseFastTopLevelStrict(bytes)
}


