package kaca_json

import std.collection.*

public class Json5Parser {
    private let bytes: Array<Byte>
    private let len: Int64
    private var pos: Int64 = 0
    private var line: Int64 = 1
    private var column: Int64 = 1

    public Json5Parser(input: String) {
        this.bytes = input.toArray()
        this.len = bytes.size
    }

    public func parse(): JsonValue {
        skipWhitespaceAndComments()
        if (pos >= len) {
            throw parseError("Unexpected end of input", line, column)
        }
        let value = parseValue()
        skipWhitespaceAndComments()
        if (pos != len) {
            throw parseError("Unexpected token after JSON5 value", line, column)
        }
        value
    }

    private func parseValue(): JsonValue {
        if (pos >= len) {
            throw parseError("Unexpected end of input", line, column)
        }

        let b = bytes[pos]
        if (b == 0x7B) { // {
            return parseObject()
        }
        if (b == 0x5B) { // [
            return parseArray()
        }
        if (b == 0x22 || b == 0x27) { // " or '
            return JsonValue.JsonString(parseStringValue())
        }
        if (b == 0x2B || b == 0x2D || b == 0x2E || isDigitByte(b)) {
            return JsonValue.JsonNumber(parseNumberValue())
        }
        if (isIdentifierStartAtCurrent()) {
            return parseKeywordValue()
        }

        throw parseError("Unexpected token", line, column)
    }

    private func parseObject(): JsonValue {
        advanceAscii() // {
        skipWhitespaceAndComments()

        let obj = HashMap<String, JsonValue>(6)
        if (pos < len && bytes[pos] == 0x7D) { // }
            advanceAscii()
            return JsonValue.JsonObject(obj)
        }

        while (true) {
            let key = parseKey()
            skipWhitespaceAndComments()
            if (pos >= len || bytes[pos] != 0x3A) { // :
                throw parseError("Expected ':' after key", line, column)
            }
            advanceAscii()
            skipWhitespaceAndComments()

            obj[key] = parseValue()
            skipWhitespaceAndComments()

            if (pos < len && bytes[pos] == 0x7D) { // }
                advanceAscii()
                return JsonValue.JsonObject(obj)
            }
            if (pos >= len || bytes[pos] != 0x2C) { // ,
                throw parseError("Expected ',' or '}' in object", line, column)
            }
            advanceAscii()
            skipWhitespaceAndComments()
            if (pos < len && bytes[pos] == 0x7D) { // trailing comma
                advanceAscii()
                return JsonValue.JsonObject(obj)
            }
        }
        JsonValue.JsonObject(obj)
    }

    private func parseArray(): JsonValue {
        advanceAscii() // [
        skipWhitespaceAndComments()

        let arr = ArrayList<JsonValue>(6)
        if (pos < len && bytes[pos] == 0x5D) { // ]
            advanceAscii()
            return JsonValue.JsonArray(arr)
        }

        while (true) {
            arr.add(parseValue())
            skipWhitespaceAndComments()

            if (pos < len && bytes[pos] == 0x5D) { // ]
                advanceAscii()
                return JsonValue.JsonArray(arr)
            }
            if (pos >= len || bytes[pos] != 0x2C) { // ,
                throw parseError("Expected ',' or ']'", line, column)
            }
            advanceAscii()
            skipWhitespaceAndComments()
            if (pos < len && bytes[pos] == 0x5D) { // trailing comma
                advanceAscii()
                return JsonValue.JsonArray(arr)
            }
        }
        JsonValue.JsonArray(arr)
    }

    private func parseKey(): String {
        if (pos >= len) {
            throw parseError("Unexpected end while parsing key", line, column)
        }
        let b = bytes[pos]
        if (b == 0x22 || b == 0x27) {
            return parseStringValue()
        }
        if (isIdentifierStartAtCurrent()) {
            return parseIdentifierValue()
        }
        throw parseError("Expected string or identifier key", line, column)
    }

    private func parseKeywordValue(): JsonValue {
        if (matchTrueAt()) {
            pos += 4
            column += 4
            return JsonValue.JsonBool(true)
        }
        if (matchFalseAt()) {
            pos += 5
            column += 5
            return JsonValue.JsonBool(false)
        }
        if (matchNullAt()) {
            pos += 4
            column += 4
            return JsonValue.JsonNull
        }
        if (matchInfinityAt()) {
            pos += 8
            column += 8
            return JsonValue.JsonNumber(1.0 / 0.0)
        }
        if (matchNaNAt()) {
            pos += 3
            column += 3
            return JsonValue.JsonNumber(0.0 / 0.0)
        }
        throw parseError("Unexpected identifier in value", line, column)
    }

    private func parseNumberValue(): Float64 {
        let start = pos
        var p = pos
        var sign: Float64 = 1.0

        if (bytes[p] == 0x2B || bytes[p] == 0x2D) {
            if (bytes[p] == 0x2D) {
                sign = -1.0
            }
            p += 1
            if (p >= len) {
                pos = p
                column += (p - start)
                throw parseError("Invalid number", line, column)
            }
        }

        if (p + 8 <= len && matchesInfinityRange(p, p + 8) && !isIdentifierPartAt(p + 8)) {
            p += 8
            pos = p
            column += (p - start)
            return sign * (1.0 / 0.0)
        }
        if (p + 3 <= len && matchesNaNRange(p, p + 3) && !isIdentifierPartAt(p + 3)) {
            p += 3
            pos = p
            column += (p - start)
            return 0.0 / 0.0
        }

        if (p + 1 < len && bytes[p] == 0x30 && (bytes[p + 1] == 0x78 || bytes[p + 1] == 0x58)) {
            p += 2
            var num: Float64 = 0.0
            var hasHexDigit = false
            while (p < len && isHexDigitByte(bytes[p])) {
                num = num * 16.0 + Float64(byteToHexValue(bytes[p]))
                hasHexDigit = true
                p += 1
            }
            if (!hasHexDigit) {
                pos = p
                column += (p - start)
                throw parseError("Invalid number", line, column)
            }
            pos = p
            column += (p - start)
            return sign * num
        }

        var num: Float64 = 0.0
        var sawDigit = false

        if (p < len && bytes[p] == 0x2E) {
            p += 1
            if (p >= len || !isDigitByte(bytes[p])) {
                pos = p
                column += (p - start)
                throw parseError("Invalid number", line, column)
            }
            var decimalPlace: Float64 = 0.1
            while (p < len && isDigitByte(bytes[p])) {
                num += Float64(UInt8(bytes[p]) - 48) * decimalPlace
                decimalPlace *= 0.1
                p += 1
            }
            sawDigit = true
        } else {
            if (p < len && isDigitByte(bytes[p])) {
                sawDigit = true
                while (p < len && isDigitByte(bytes[p])) {
                    num = num * 10.0 + Float64(UInt8(bytes[p]) - 48)
                    p += 1
                }
            }
            if (p < len && bytes[p] == 0x2E) {
                p += 1
                var decimalPlace: Float64 = 0.1
                while (p < len && isDigitByte(bytes[p])) {
                    num += Float64(UInt8(bytes[p]) - 48) * decimalPlace
                    decimalPlace *= 0.1
                    p += 1
                }
            }
        }

        if (!sawDigit) {
            pos = p
            column += (p - start)
            throw parseError("Invalid number", line, column)
        }

        if (p < len && (bytes[p] == 0x65 || bytes[p] == 0x45)) {
            p += 1
            var expSign: Float64 = 1.0
            if (p < len && bytes[p] == 0x2D) {
                expSign = -1.0
                p += 1
            } else if (p < len && bytes[p] == 0x2B) {
                p += 1
            }
            if (p >= len || !isDigitByte(bytes[p])) {
                pos = p
                column += (p - start)
                throw parseError("Invalid number", line, column)
            }
            var exp: Int64 = 0
            while (p < len && isDigitByte(bytes[p])) {
                exp = exp * 10 + Int64(UInt8(bytes[p]) - 48)
                p += 1
            }
            if (exp > 308) {
                if (expSign > 0.0) {
                    num = 1.7976931348623157e308
                } else {
                    num = 0.0
                }
            } else {
                let multiplier = POW10_TABLE[exp]
                if (expSign > 0.0) {
                    num *= multiplier
                } else {
                    num /= multiplier
                }
            }
        }

        pos = p
        column += (p - start)
        sign * num
    }

    private func parseStringValue(): String {
        if (pos >= len) {
            throw parseError("Unexpected end in string", line, column)
        }
        let quoteByte = bytes[pos]
        advanceAscii()
        let contentStart = pos
        var p = pos
        while (p < len) {
            while (p < len) {
                let c = bytes[p]
                if (c >= 0x20 && c <= 0x7F && c != quoteByte && c != 0x5C) {
                    p += 1
                } else {
                    break
                }
            }
            if (p >= len) {
                break
            }
            let b = bytes[p]
            if (b == quoteByte) {
                let s = unsafe { String.withRawData(bytes[contentStart..p]) }
                pos = p + 1
                column += (p - contentStart) + 1
                return s
            }
            if (b == 0x5C) {
                break
            }
            if (b == 0x0A || b == 0x0D) {
                throw parseError("Unexpected line terminator in string", line, column)
            }
            if ((UInt8(b) & 0x80) == 0) {
                p += 1
            } else {
                let (_, byteLen) = utf8DecodeByte(bytes, p)
                p += byteLen
            }
        }

        let out = ByteBuilder(64)
        if (p > contentStart) {
            out.appendBytes(bytes, contentStart, p - contentStart)
            pos = p
            column += (p - contentStart)
        }

        while (pos < len) {
            let b = bytes[pos]
            if (b == quoteByte) {
                advanceAscii()
                return out.build()
            }

            if (b == 0x5C) { // \
                advanceAscii()
                if (pos >= len) {
                    throw parseError("Unexpected end in string escape", line, column)
                }
                scanStringEscape(out)
                continue
            }

            if (b == 0x0A || b == 0x0D) {
                throw parseError("Unexpected line terminator in string", line, column)
            }

            if ((UInt8(b) & 0x80) == 0) {
                out.append(b)
                advanceAscii()
            } else {
                let (r, byteLen) = utf8DecodeByte(bytes, pos)
                out.appendRune(r)
                pos += byteLen
                column += 1
            }
        }

        throw parseError("Unterminated string", line, column)
    }

    private func scanStringEscape(out: ByteBuilder): Unit {
        let b = bytes[pos]
        advanceAscii()

        if (b == 0x27) { out.append(UInt8(0x27)); return } // '
        if (b == 0x22) { out.append(UInt8(0x22)); return } // "
        if (b == 0x5C) { out.append(UInt8(0x5C)); return } // \
        if (b == 0x2F) { out.append(UInt8(0x2F)); return } // /
        if (b == 0x62) { out.append(UInt8(0x08)); return } // b
        if (b == 0x66) { out.append(UInt8(0x0C)); return } // f
        if (b == 0x6E) { out.append(UInt8(0x0A)); return } // n
        if (b == 0x72) { out.append(UInt8(0x0D)); return } // r
        if (b == 0x74) { out.append(UInt8(0x09)); return } // t
        if (b == 0x76) { out.append(UInt8(0x0B)); return } // v

        if (b == 0x30) { // 0
            if (pos < len && isDigitByte(bytes[pos])) {
                throw parseError("Invalid character in escape", line, column)
            }
            out.append(UInt8(0x00))
            return
        }
        if (b >= 0x31 && b <= 0x39) { // 1..9
            throw parseError("Invalid character in escape", line, column)
        }
        if (b == 0x78) { // xHH
            scanHexEscape(out)
            return
        }
        if (b == 0x75) { // uXXXX
            scanUnicodeEscape(out)
            return
        }
        if (b == 0x0A) { // line continuation
            return
        }
        if (b == 0x0D) { // CR or CRLF continuation
            if (pos < len && bytes[pos] == 0x0A) {
                pos += 1
            }
            return
        }

        if ((UInt8(b) & 0x80) == 0) {
            out.append(b)
        } else {
            pos -= 1
            column -= 1
            let (r, byteLen) = utf8DecodeByte(bytes, pos)
            out.appendRune(r)
            pos += byteLen
            column += 1
        }
    }

    private func scanHexEscape(out: ByteBuilder): Unit {
        if (pos + 2 > len) {
            throw parseError("Unexpected end in hex escape", line, column)
        }
        let h1 = byteToHexValue(bytes[pos])
        let h2 = byteToHexValue(bytes[pos + 1])
        if (h1 < 0 || h2 < 0) {
            throw parseError("Invalid hex digit in hex escape", line, column)
        }
        out.append(UInt8(h1 * 16 + h2))
        pos += 2
        column += 2
    }

    private func scanUnicodeEscape(out: ByteBuilder): Unit {
        if (pos + 4 > len) {
            throw parseError("Unexpected end in unicode escape", line, column)
        }
        let (cp, valid) = parseHexCodePoint(bytes, pos)
        if (!valid) {
            throw parseError("Invalid hex digit in unicode escape", line, column)
        }
        pos += 4
        column += 4

        if (isHighSurrogate(cp) && pos + 6 <= len && bytes[pos] == 0x5C && bytes[pos + 1] == 0x75) {
            let savedPos = pos
            let savedColumn = column
            pos += 2
            column += 2
            let (low, lowValid) = parseHexCodePoint(bytes, pos)
            if (!lowValid) {
                throw parseError("Invalid hex digit in low surrogate", line, column)
            }
            if (isLowSurrogate(low)) {
                pos += 4
                column += 4
                out.appendCodePoint(combineSurrogatePair(cp, low))
                return
            }
            pos = savedPos
            column = savedColumn
        }

        out.appendCodePoint(cp)
    }

    private func parseIdentifierValue(): String {
        let out = ByteBuilder(32)
        var isFirst = true
        while (pos < len) {
            let b = bytes[pos]
            if (b == 0x5C && peekByte(1) == 0x75) {
                if (pos + 6 > len) {
                    throw parseError("Unexpected end in identifier escape", line, column)
                }
                let (cp, valid) = parseHexCodePoint(bytes, pos + 2)
                if (!valid) {
                    throw parseError("Invalid identifier character", line, column)
                }
                if (isFirst) {
                    if (!isIdentifierStartCodePoint(cp)) {
                        throw parseError("Invalid identifier character", line, column)
                    }
                } else if (!isIdentifierPartCodePoint(cp)) {
                    throw parseError("Invalid identifier character", line, column)
                }
                out.appendCodePoint(cp)
                pos += 6
                column += 6
                isFirst = false
                continue
            }

            if ((UInt8(b) & 0x80) == 0) {
                if (isFirst) {
                    if (!isIdentifierStartAscii(b)) { break }
                } else if (!isIdentifierPartAscii(b)) {
                    break
                }
                out.append(b)
                advanceAscii()
                isFirst = false
                continue
            }

            let (r, byteLen) = utf8DecodeByte(bytes, pos)
            let cp = Int64(UInt32(r))
            if (isFirst) {
                if (!isIdentifierStartCodePoint(cp)) { break }
            } else if (!isIdentifierPartCodePoint(cp)) {
                break
            }
            out.appendRune(r)
            pos += byteLen
            column += 1
            isFirst = false
        }
        if (isFirst) {
            throw parseError("Invalid identifier start", line, column)
        }
        out.build()
    }

    private func skipWhitespaceAndComments(): Unit {
        var p = pos
        var ln = line
        var col = column
        while (p < len) {
            let b = bytes[p]
            if (b == 0x20 || b == 0x09 || b == 0x0B || b == 0x0C || b == 0x0D) {
                p += 1
                col += 1
                continue
            }
            if (b == 0x0A) {
                p += 1
                ln += 1
                col = 1
                continue
            }
            if (b == 0x2F && p + 1 < len) { // /
                let b1 = bytes[p + 1]
                if (b1 == 0x2F) {
                    p += 2
                    col += 2
                    let start = p
                    while (p < len && bytes[p] != 0x0A) {
                        p += 1
                    }
                    col += (p - start)
                    continue
                }
                if (b1 == 0x2A) {
                    let startLine = ln
                    let startColumn = col
                    p += 2
                    col += 2
                    var closed = false
                    while (p < len) {
                        if (bytes[p] == 0x2A && p + 1 < len && bytes[p + 1] == 0x2F) {
                            p += 2
                            col += 2
                            closed = true
                            break
                        }
                        if (bytes[p] == 0x0A) {
                            p += 1
                            ln += 1
                            col = 1
                        } else {
                            p += 1
                            col += 1
                        }
                    }
                    if (!closed) {
                        throw parseError("Unterminated block comment", startLine, startColumn)
                    }
                    continue
                }
            }
            if ((UInt8(b) & 0x80) == 0) {
                break
            }
            let (r, byteLen) = utf8DecodeByte(bytes, p)
            let cp = Int64(UInt32(r))
            if (cp == 0x2028 || cp == 0x2029) {
                p += byteLen
                ln += 1
                col = 1
                continue
            }
            if (isExtraJson5Whitespace(cp)) {
                p += byteLen
                col += 1
                continue
            }
            break
        }
        pos = p
        line = ln
        column = col
    }

    private func advanceAscii(): Unit {
        pos += 1
        column += 1
    }

    private func advanceIdentifierByte(): Unit {
        let b = bytes[pos]
        if ((UInt8(b) & 0x80) == 0) {
            advanceAscii()
        } else {
            let (_, byteLen) = utf8DecodeByte(bytes, pos)
            pos += byteLen
            column += 1
        }
    }

    private func peekByte(offset: Int64): Byte {
        let idx = pos + offset
        if (idx >= len) { return 0 }
        bytes[idx]
    }

    private func isIdentifierStartAtCurrent(): Bool {
        if (pos >= len) { return false }
        let b = bytes[pos]
        if (b == 0x5C && peekByte(1) == 0x75) { return true }
        if ((UInt8(b) & 0x80) != 0) { return true }
        isIdentifierStartAscii(b)
    }

    private func isIdentifierStartAscii(b: Byte): Bool {
        b == 0x24 || b == 0x5F || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
    }

    private func isIdentifierPartAscii(b: Byte): Bool {
        isIdentifierStartAscii(b) || (b >= 0x30 && b <= 0x39)
    }

    private func isIdentifierStartCodePoint(cp: Int64): Bool {
        if (cp < 0 || cp > 255) { return cp >= 0x80 }
        isIdentifierStartAscii(UInt8(cp))
    }

    private func isIdentifierPartCodePoint(cp: Int64): Bool {
        if (cp == 0x200C || cp == 0x200D) { return true }
        if (cp < 0 || cp > 255) { return cp >= 0x80 }
        isIdentifierPartAscii(UInt8(cp))
    }

    private func isIdentifierPartAt(idx: Int64): Bool {
        if (idx >= len) { return false }
        let b = bytes[idx]
        if (b == 0x5C && idx + 1 < len && bytes[idx + 1] == 0x75) { return true }
        if ((UInt8(b) & 0x80) != 0) { return true }
        isIdentifierPartAscii(b)
    }

    private func matchTrueAt(): Bool {
        if (pos + 4 > len) { return false }
        if (bytes[pos] != 0x74 || bytes[pos + 1] != 0x72 || bytes[pos + 2] != 0x75 || bytes[pos + 3] != 0x65) {
            return false
        }
        !isIdentifierPartAt(pos + 4)
    }

    private func matchFalseAt(): Bool {
        if (pos + 5 > len) { return false }
        if (bytes[pos] != 0x66 || bytes[pos + 1] != 0x61 || bytes[pos + 2] != 0x6C || bytes[pos + 3] != 0x73 || bytes[pos + 4] != 0x65) {
            return false
        }
        !isIdentifierPartAt(pos + 5)
    }

    private func matchNullAt(): Bool {
        if (pos + 4 > len) { return false }
        if (bytes[pos] != 0x6E || bytes[pos + 1] != 0x75 || bytes[pos + 2] != 0x6C || bytes[pos + 3] != 0x6C) {
            return false
        }
        !isIdentifierPartAt(pos + 4)
    }

    private func matchInfinityAt(): Bool {
        if (pos + 8 > len) { return false }
        if (!matchesInfinityRange(pos, pos + 8)) { return false }
        !isIdentifierPartAt(pos + 8)
    }

    private func matchNaNAt(): Bool {
        if (pos + 3 > len) { return false }
        if (!matchesNaNRange(pos, pos + 3)) { return false }
        !isIdentifierPartAt(pos + 3)
    }

    private func matchesInfinityRange(start: Int64, endPos: Int64): Bool {
        if (endPos - start != 8) { return false }
        bytes[start] == 0x49
            && bytes[start + 1] == 0x6E
            && bytes[start + 2] == 0x66
            && bytes[start + 3] == 0x69
            && bytes[start + 4] == 0x6E
            && bytes[start + 5] == 0x69
            && bytes[start + 6] == 0x74
            && bytes[start + 7] == 0x79
    }

    private func matchesNaNRange(start: Int64, endPos: Int64): Bool {
        if (endPos - start != 3) { return false }
        bytes[start] == 0x4E && bytes[start + 1] == 0x61 && bytes[start + 2] == 0x4E
    }

    private func isExtraJson5Whitespace(cp: Int64): Bool {
        cp == 0x00A0
            || cp == 0xFEFF
            || cp == 0x1680
            || cp == 0x180E
            || (cp >= 0x2000 && cp <= 0x200A)
            || cp == 0x202F
            || cp == 0x205F
            || cp == 0x3000
    }
}
