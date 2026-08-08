package kaca_json

public func parseJsonNumberBytes(input: Array<Byte>, start: Int64, len: Int64): Float64 {
    if (len <= 0) {
        throw numberError("Empty number", start)
    }
    parseStrictJsonNumberBytesSinglePassRange(input, start, start + len)
}

public func parseJson5NumberText(input: String): Float64 {
    let bytes = stringToBytes(input)
    parseJson5NumberBytesRange(bytes, 0, bytes.size)
}

public func parseJson5NumberBytesRange(bytes: Array<Byte>, start: Int64, end: Int64): Float64 {
    if (start >= end) {
        throw numberError("Empty number", start)
    }
    var idx: Int64 = 0
    var sign: Float64 = 1.0
    idx = start

    if (idx < end && (bytes[idx] == 0x2B || bytes[idx] == 0x2D)) {
        if (bytes[idx] == 0x2D) {
            sign = -1.0
        }
        idx += 1
    }

    let remainLen = end - idx
    if (remainLen == 8) {
        if (matchesInfinityRange(bytes, idx, end)) {
            return sign * (1.0 / 0.0)
        }
    } else if (remainLen == 3) {
        if (matchesNaNRange(bytes, idx, end)) {
            return 0.0 / 0.0
        }
    }

    if (idx + 1 < end && bytes[idx] == 0x30 && (bytes[idx + 1] == 0x78 || bytes[idx + 1] == 0x58)) {
        let hexVal = parseJson5HexFloat(bytes, idx + 2, end)
        return sign * hexVal
    }

    parseJsonNumberBytesCore(bytes, start, end)
}

private func matchesInfinityRange(bytes: Array<Byte>, start: Int64, end: Int64): Bool {
    if (end - start != 8) {
        return false
    }
    bytes[start] == 0x49
        && bytes[start + 1] == 0x6E
        && bytes[start + 2] == 0x66
        && bytes[start + 3] == 0x69
        && bytes[start + 4] == 0x6E
        && bytes[start + 5] == 0x69
        && bytes[start + 6] == 0x74
        && bytes[start + 7] == 0x79
}

private func matchesNaNRange(bytes: Array<Byte>, start: Int64, end: Int64): Bool {
    if (end - start != 3) {
        return false
    }
    bytes[start] == 0x4E && bytes[start + 1] == 0x61 && bytes[start + 2] == 0x4E
}

private func parseJsonNumberBytesCore(bytes: Array<Byte>, startPos: Int64, len: Int64): Float64 {
    var pos = startPos
    var sign: Float64 = 1.0

    if (pos < len && bytes[pos] == 0x2D) {
        sign = -1.0
        pos += 1
    } else if (pos < len && bytes[pos] == 0x2B) {
        pos += 1
    }

    let (num, endPos) = parseUnsignedNumberBytesCore(bytes, pos, len)

    if (endPos != len) {
        throw numberError("Invalid number suffix", endPos)
    }

    sign * num
}

private func parseStrictJsonNumberBytesSinglePassRange(bytes: Array<Byte>, startPos: Int64, endPos: Int64): Float64 {
    let len = endPos
    var pos: Int64 = startPos

    if (pos >= len) {
        throw numberError("Empty number", 0)
    }

    var sign: Float64 = 1.0
    if (bytes[pos] == 0x2D) { // -
        sign = -1.0
        pos += 1
    } else if (bytes[pos] == 0x2B) { // +
        throw numberError("Invalid number start", pos)
    }

    if (pos >= len) {
        throw numberError("Invalid number", pos)
    }

    var num: Float64 = 0.0
    if (bytes[pos] == 0x30) {
        pos += 1
        if (pos < len && isDigitByte(bytes[pos])) {
            throw numberError("Leading zero in number", pos)
        }
    } else {
        if (bytes[pos] < 0x31 || bytes[pos] > 0x39) {
            throw numberError("Invalid number start", pos)
        }
        while (pos < len && isDigitByte(bytes[pos])) {
            num = num * 10.0 + Float64(UInt8(bytes[pos]) - 48)
            pos += 1
        }
    }

    if (pos < len && bytes[pos] == 0x2E) { // .
        pos += 1
        if (pos >= len || !isDigitByte(bytes[pos])) {
            throw numberError("Missing fractional digits", pos)
        }
        let (fraction, nextPos) = parseFractionBytesCore(bytes, pos, len)
        num = num + fraction
        pos = nextPos
    }

    if (pos < len && (bytes[pos] == 0x65 || bytes[pos] == 0x45)) { // e/E
        let (withExp, nextPos) = parseExponentBytesCore(bytes, pos + 1, len, num)
        num = withExp
        pos = nextPos
    }

    if (pos != len) {
        throw numberError("Invalid number suffix", pos)
    }

    sign * num
}

private func parseUnsignedNumberBytesCore(bytes: Array<Byte>, startPos: Int64, len: Int64): (Float64, Int64) {
    var pos = startPos

    if (pos >= len) {
        throw numberError("Empty number", pos)
    }

    if (bytes[pos] == 0x2E) {
        return parseDecimalOnlyBytesCore(bytes, pos + 1, len)
    }

    if (!isDigitByte(bytes[pos])) {
        throw numberError("Invalid number start", pos)
    }

    var num: Float64 = 0.0
    if (bytes[pos] == 0x30) {
        pos += 1
        while (pos < len && isDigitByte(bytes[pos])) {
            num = num * 10.0 + Float64(UInt8(bytes[pos]) - 48)
            pos += 1
        }
    } else {
        while (pos < len && isDigitByte(bytes[pos])) {
            num = num * 10.0 + Float64(UInt8(bytes[pos]) - 48)
            pos += 1
        }
    }

    if (pos < len && bytes[pos] == 0x2E) {
        let (fraction, nextPos) = parseFractionBytesCore(bytes, pos + 1, len)
        num = num + fraction
        pos = nextPos
    }

    if (pos < len && (bytes[pos] == 0x65 || bytes[pos] == 0x45)) {
        return parseExponentBytesCore(bytes, pos + 1, len, num)
    }

    (num, pos)
}

private func parseDecimalOnlyBytesCore(bytes: Array<Byte>, startPos: Int64, len: Int64): (Float64, Int64) {
    if (startPos >= len || !isDigitByte(bytes[startPos])) {
        throw numberError("Expected digits after decimal point", startPos)
    }
    let (fraction, pos) = parseFractionBytesCore(bytes, startPos, len)
    if (pos < len && (bytes[pos] == 0x65 || bytes[pos] == 0x45)) {
        return parseExponentBytesCore(bytes, pos + 1, len, fraction)
    }
    (fraction, pos)
}

private func parseFractionBytesCore(bytes: Array<Byte>, startPos: Int64, len: Int64): (Float64, Int64) {
    var pos = startPos
    var num: Float64 = 0.0
    var decimalPlace: Float64 = 0.1

    while (pos < len && isDigitByte(bytes[pos])) {
        num = num + Float64(UInt8(bytes[pos]) - 48) * decimalPlace
        decimalPlace = decimalPlace * 0.1
        pos += 1
    }

    (num, pos)
}

private func parseExponentBytesCore(bytes: Array<Byte>, startPos: Int64, len: Int64, num: Float64): (Float64, Int64) {
    var pos = startPos
    var expSign: Float64 = 1.0

    if (pos < len && bytes[pos] == 0x2D) {
        expSign = -1.0
        pos += 1
    } else if (pos < len && bytes[pos] == 0x2B) {
        pos += 1
    }

    if (pos >= len || !isDigitByte(bytes[pos])) {
        throw numberError("Expected digits in exponent", pos)
    }

    var exp: Int64 = 0
    while (pos < len && isDigitByte(bytes[pos])) {
        exp = exp * 10 + Int64(UInt8(bytes[pos]) - 48)
        pos += 1
    }

    if (exp > 308) {
        if (expSign > 0.0) {
            return (1.7976931348623157e308, pos)
        }
        return (0.0, pos)
    }

    let multiplier = POW10_TABLE[exp]
    if (expSign > 0.0) {
        (num * multiplier, pos)
    } else {
        (num / multiplier, pos)
    }
}

private func parseJson5HexFloat(bytes: Array<Byte>, startIdx: Int64, endIdx: Int64): Float64 {
    var num: Float64 = 0.0
    var idx = startIdx
    var hasDigit = false

    while (idx < endIdx) {
        let b = bytes[idx]
        let v = UInt8(b)
        var digit: Int64 = -1
        if (v >= 48 && v <= 57) {
            digit = Int64(v - 48)
        } else if (v >= 97 && v <= 102) {
            digit = Int64(v - 97 + 10)
        } else if (v >= 65 && v <= 70) {
            digit = Int64(v - 65 + 10)
        }
        if (digit < 0) {
            break
        }
        num = num * 16.0 + Float64(digit)
        hasDigit = true
        idx += 1
    }

    if (!hasDigit) {
        throw numberError("Expected hex digits", startIdx)
    }
    if (idx != endIdx) {
        throw numberError("Invalid number suffix", idx)
    }

    num
}

