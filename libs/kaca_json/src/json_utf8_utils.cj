package kaca_json

import std.collection.*

private let HEX_VALUE_TABLE: Array<Int8> = [
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
     0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,
    -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
]

private let CHAR_CLASS_TABLE: Array<UInt8> = [
    0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x21,0x21,0x20,0x20,0x21,0x20,0x20,
    0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,
    0x01,0x00,0x20,0x00,0x10,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x1A,0x1A,0x1A,0x1A,0x1A,0x1A,0x1A,0x1A,0x1A,0x1A,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x1C,0x1C,0x1C,0x1C,0x1C,0x1C,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,
    0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x18,
    0x00,0x1C,0x1C,0x1C,0x1C,0x1C,0x1C,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,
    0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
]

public func utf8DecodeByte(bytes: Array<Byte>, pos: Int64): (Rune, Int64) {
    if (pos >= bytes.size) {
        return (r'\0', 0)
    }
    
    let b0 = UInt8(bytes[pos])
    
    if ((b0 & 0x80) == 0) {
        (Rune(b0), 1)
    } else if ((b0 & 0xE0) == 0xC0) {
        if (pos + 1 >= bytes.size) {
            return (Rune(b0), 1)
        }
        let b1 = UInt8(bytes[pos + 1])
        let codePoint = (Int64(b0 & 0x1F) << 6) | Int64(b1 & 0x3F)
        (Rune(codePoint), 2)
    } else if ((b0 & 0xF0) == 0xE0) {
        if (pos + 2 >= bytes.size) {
            return (Rune(b0), 1)
        }
        let b1 = UInt8(bytes[pos + 1])
        let b2 = UInt8(bytes[pos + 2])
        let codePoint = (Int64(b0 & 0x0F) << 12) | (Int64(b1 & 0x3F) << 6) | Int64(b2 & 0x3F)
        (Rune(codePoint), 3)
    } else if ((b0 & 0xF8) == 0xF0) {
        if (pos + 3 >= bytes.size) {
            return (Rune(b0), 1)
        }
        let b1 = UInt8(bytes[pos + 1])
        let b2 = UInt8(bytes[pos + 2])
        let b3 = UInt8(bytes[pos + 3])
        let codePoint = (Int64(b0 & 0x07) << 18) | (Int64(b1 & 0x3F) << 12) | (Int64(b2 & 0x3F) << 6) | Int64(b3 & 0x3F)
        (Rune(codePoint), 4)
    } else {
        (Rune(b0), 1)
    }
}

public func utf8EncodeCodePoint(codePoint: Int64): Array<Byte> {
    if (codePoint < 0x80) {
        let arr = Array<Byte>(1, {_ => 0})
        arr[0] = UInt8(codePoint)
        arr
    } else if (codePoint < 0x800) {
        let arr = Array<Byte>(2, {_ => 0})
        arr[0] = UInt8(0xC0 | ((codePoint >> 6) & 0x1F))
        arr[1] = UInt8(0x80 | (codePoint & 0x3F))
        arr
    } else if (codePoint < 0x10000) {
        let arr = Array<Byte>(3, {_ => 0})
        arr[0] = UInt8(0xE0 | ((codePoint >> 12) & 0x0F))
        arr[1] = UInt8(0x80 | ((codePoint >> 6) & 0x3F))
        arr[2] = UInt8(0x80 | (codePoint & 0x3F))
        arr
    } else {
        let arr = Array<Byte>(4, {_ => 0})
        arr[0] = UInt8(0xF0 | ((codePoint >> 18) & 0x07))
        arr[1] = UInt8(0x80 | ((codePoint >> 12) & 0x3F))
        arr[2] = UInt8(0x80 | ((codePoint >> 6) & 0x3F))
        arr[3] = UInt8(0x80 | (codePoint & 0x3F))
        arr
    }
}

public func byteToHexValue(byte: Byte): Int64 {
    Int64(HEX_VALUE_TABLE[Int64(UInt8(byte))])
}

public func stringToBytes(s: String): Array<Byte> {
    return unsafe { s.rawData()}
}
public class ByteBuilder {
    private var bytes: Array<Byte>
    private var size: Int64 = 0
    
    public init(capacity: Int64) {
        let cap = if (capacity > 0) { capacity } else { 64 }
        this.bytes = Array<Byte>(cap, {_ => 0})
    }
    
    public func append(b: Byte): Unit {
        if (size >= bytes.size) {
            let newCap = bytes.size * 2
            let newArr = Array<Byte>(newCap, {i: Int64 => 
                if (i < size) { bytes[i] } else { 0 }
            })
            bytes = newArr
        }
        bytes[size] = b
        size += 1
    }
    
    public func appendAll(arr: Array<Byte>): Unit {
        appendBytes(arr, 0, arr.size)
    }
    
    public func appendRune(r: Rune): Unit {
        let codePoint = Int64(UInt32(r))
        let encoded = utf8EncodeCodePoint(codePoint)
        appendAll(encoded)
    }
    
    public func appendString(s: String): Unit {
        let strBytes = stringToBytes(s)
        appendAll(strBytes)
    }
    
    public func appendCodePoint(codePoint: Int64): Unit {
        let encoded = utf8EncodeCodePoint(codePoint)
        appendAll(encoded)
    }
    
    public func ensureCapacity(cap: Int64): Unit {
        if (bytes.size < cap) {
            let newCap = max(cap, bytes.size * 2)
            let newArr = Array<Byte>(newCap, {i: Int64 => 
                if (i < size) { bytes[i] } else { 0 }
            })
            bytes = newArr
        }
    }
    
    public func appendBytes(src: Array<Byte>, start: Int64, len: Int64): Unit {
        ensureCapacity(size + len)
        var i: Int64 = 0
        while (i < len) {
            bytes[size + i] = src[start + i]
            i++
        }
        size += len
    }
    
    public func getBytes(): Array<Byte> {
        let result = Array<Byte>(size, {i: Int64 => bytes[i]})
        result
    }
    
    public func build(): String {
        let resultBytes = getBytes()
        // resultBytes is a fresh snapshot and is not mutated after return.
        unsafe { String.withRawData(resultBytes) }
    }
    
    public func clear(): Unit {
        size = 0
    }
    
    public func getSize(): Int64 {
        size
    }
}

public let POW10_TABLE: Array<Float64> = [
    1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
    1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
    1e20, 1e21, 1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29,
    1e30, 1e31, 1e32, 1e33, 1e34, 1e35, 1e36, 1e37, 1e38, 1e39,
    1e40, 1e41, 1e42, 1e43, 1e44, 1e45, 1e46, 1e47, 1e48, 1e49,
    1e50, 1e51, 1e52, 1e53, 1e54, 1e55, 1e56, 1e57, 1e58, 1e59,
    1e60, 1e61, 1e62, 1e63, 1e64, 1e65, 1e66, 1e67, 1e68, 1e69,
    1e70, 1e71, 1e72, 1e73, 1e74, 1e75, 1e76, 1e77, 1e78, 1e79,
    1e80, 1e81, 1e82, 1e83, 1e84, 1e85, 1e86, 1e87, 1e88, 1e89,
    1e90, 1e91, 1e92, 1e93, 1e94, 1e95, 1e96, 1e97, 1e98, 1e99,
    1e100, 1e101, 1e102, 1e103, 1e104, 1e105, 1e106, 1e107, 1e108, 1e109,
    1e110, 1e111, 1e112, 1e113, 1e114, 1e115, 1e116, 1e117, 1e118, 1e119,
    1e120, 1e121, 1e122, 1e123, 1e124, 1e125, 1e126, 1e127, 1e128, 1e129,
    1e130, 1e131, 1e132, 1e133, 1e134, 1e135, 1e136, 1e137, 1e138, 1e139,
    1e140, 1e141, 1e142, 1e143, 1e144, 1e145, 1e146, 1e147, 1e148, 1e149,
    1e150, 1e151, 1e152, 1e153, 1e154, 1e155, 1e156, 1e157, 1e158, 1e159,
    1e160, 1e161, 1e162, 1e163, 1e164, 1e165, 1e166, 1e167, 1e168, 1e169,
    1e170, 1e171, 1e172, 1e173, 1e174, 1e175, 1e176, 1e177, 1e178, 1e179,
    1e180, 1e181, 1e182, 1e183, 1e184, 1e185, 1e186, 1e187, 1e188, 1e189,
    1e190, 1e191, 1e192, 1e193, 1e194, 1e195, 1e196, 1e197, 1e198, 1e199,
    1e200, 1e201, 1e202, 1e203, 1e204, 1e205, 1e206, 1e207, 1e208, 1e209,
    1e210, 1e211, 1e212, 1e213, 1e214, 1e215, 1e216, 1e217, 1e218, 1e219,
    1e220, 1e221, 1e222, 1e223, 1e224, 1e225, 1e226, 1e227, 1e228, 1e229,
    1e230, 1e231, 1e232, 1e233, 1e234, 1e235, 1e236, 1e237, 1e238, 1e239,
    1e240, 1e241, 1e242, 1e243, 1e244, 1e245, 1e246, 1e247, 1e248, 1e249,
    1e250, 1e251, 1e252, 1e253, 1e254, 1e255, 1e256, 1e257, 1e258, 1e259,
    1e260, 1e261, 1e262, 1e263, 1e264, 1e265, 1e266, 1e267, 1e268, 1e269,
    1e270, 1e271, 1e272, 1e273, 1e274, 1e275, 1e276, 1e277, 1e278, 1e279,
    1e280, 1e281, 1e282, 1e283, 1e284, 1e285, 1e286, 1e287, 1e288, 1e289,
    1e290, 1e291, 1e292, 1e293, 1e294, 1e295, 1e296, 1e297, 1e298, 1e299,
    1e300, 1e301, 1e302, 1e303, 1e304, 1e305, 1e306, 1e307, 1e308
]

public func isDigitByte(b: Byte): Bool {
    (CHAR_CLASS_TABLE[Int64(UInt8(b))] & 0x02) != 0
}

public func isWhitespaceByte(b: Byte): Bool {
    (CHAR_CLASS_TABLE[Int64(UInt8(b))] & 0x01) != 0
}

public enum EscapeResult {
    | Char(Rune)
    | Unicode
    | Invalid
}

public func decodeEscapeChar(b: Byte): EscapeResult {
    if (b == 0x22) { // '"'
        return EscapeResult.Char(r'\"')
    }
    if (b == 0x5C) { // '\'
        return EscapeResult.Char(r'\\')
    }
    if (b == 0x2F) { // '/'
        return EscapeResult.Char(r'/')
    }
    if (b == 0x62) { // 'b'
        return EscapeResult.Char(r'\b')
    }
    if (b == 0x66) { // 'f'
        return EscapeResult.Char(r'\f')
    }
    if (b == 0x6E) { // 'n'
        return EscapeResult.Char(r'\n')
    }
    if (b == 0x72) { // 'r'
        return EscapeResult.Char(r'\r')
    }
    if (b == 0x74) { // 't'
        return EscapeResult.Char(r'\t')
    }
    if (b == 0x75) { // 'u'
        return EscapeResult.Unicode
    }
    EscapeResult.Invalid
}

public func parseHexCodePoint(bytes: Array<Byte>, pos: Int64): (Int64, Bool) {
    var codePoint: Int64 = 0
    var i: Int64 = 0
    while (i < 4) {
        let digit = byteToHexValue(bytes[pos + i])
        if (digit < 0) {
            return (0, false)
        }
        codePoint = codePoint * 16 + digit
        i++
    }
    (codePoint, true)
}

public func isHighSurrogate(codePoint: Int64): Bool {
    codePoint >= 0xD800 && codePoint <= 0xDBFF
}

public func isLowSurrogate(codePoint: Int64): Bool {
    codePoint >= 0xDC00 && codePoint <= 0xDFFF
}

public func combineSurrogatePair(high: Int64, low: Int64): Int64 {
    0x10000 + ((high - 0xD800) * 0x400) + (low - 0xDC00)
}

public func isHexDigitByte(b: Byte): Bool {
    (b >= 0x30 && b <= 0x39)
        || (b >= 0x41 && b <= 0x46)
        || (b >= 0x61 && b <= 0x66)
}

public func isIdentifierStartByte(b: Byte): Bool {
    (CHAR_CLASS_TABLE[Int64(UInt8(b))] & 0x08) != 0 && !isDigitByte(b)
}

public func isIdentifierPartByte(b: Byte): Bool {
    (CHAR_CLASS_TABLE[Int64(UInt8(b))] & 0x10) != 0
}

public func needsEscapeInString(b: Byte): Bool {
    (CHAR_CLASS_TABLE[Int64(UInt8(b))] & 0x20) != 0
}

