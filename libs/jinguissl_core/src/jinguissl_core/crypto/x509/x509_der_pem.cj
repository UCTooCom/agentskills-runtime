package jinguissl_core.crypto.x509

import std.collection.ArrayList
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.{constantTimeEquals, secureCopyInto}

class DerElement {
    let tag: Int64
    let value: Array<Byte>
    let encoded: Array<Byte>

    init(tag: Int64, value: Array<Byte>, encoded: Array<Byte>) {
        this.tag = tag
        this.value = value
        this.encoded = encoded
    }
}

class DerReader {
    let _bytes: Array<Byte>
    var _offset: Int64 = 0

    init(bytes: Array<Byte>) {
        this._bytes = bytes.clone()
    }

    func hasRemaining(): Bool {
        _offset < _bytes.size
    }

    func peekTag(): Int64 {
        if (_offset >= _bytes.size) {
            throw CryptoException(ParseError, "DER reader has no remaining bytes")
        }
        Int64(UInt8(_bytes[_offset]))
    }

    func readElement(label: String, expectedTag!: Int64 = -1): DerElement {
        if (_offset >= _bytes.size) {
            throw CryptoException(ParseError, "${label} is truncated")
        }

        let start = _offset
        let tagByte = UInt8(_bytes[_offset])
        if ((tagByte & UInt8(0x1f)) == UInt8(0x1f)) {
            throw CryptoException(ParseError, "${label} uses unsupported high-tag-number form")
        }
        _offset += 1

        let (valueLen, lenBytes) = derDecodeLength(_bytes, _offset, label)
        _offset += lenBytes

        if (valueLen < 0 || _offset + valueLen > _bytes.size) {
            throw CryptoException(ParseError, "${label} length exceeds input bounds")
        }

        let end = _offset + valueLen
        let value = _bytes[_offset..end]
        let encoded = _bytes[start..end]
        _offset = end

        let tag = Int64(tagByte)
        if (expectedTag >= 0 && tag != expectedTag) {
            throw CryptoException(ParseError, "${label} tag mismatch, expected=0x${intToHexLower(expectedTag)}, actual=0x${intToHexLower(tag)}")
        }

        DerElement(tag, value, encoded)
    }
}

func derReadSingleElement(bytes: Array<Byte>, label: String): DerElement {
    let reader = DerReader(bytes)
    let elem = reader.readElement(label)
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "${label} contains trailing bytes")
    }
    elem
}

func derWrap(tag: Int64, value: Array<Byte>): Array<Byte> {
    let len = encodeDerLength(value.size)
    let out = Array<Byte>(1 + len.size + value.size, repeat: 0)
    out[0] = UInt8(tag)
    secureCopyInto(len, out, dstOffset: 1)
    secureCopyInto(value, out, dstOffset: 1 + len.size)
    out
}

func derDecodeLength(bytes: Array<Byte>, offset: Int64, label: String): (Int64, Int64) {
    if (offset >= bytes.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    let first = UInt8(bytes[offset])
    if ((first & UInt8(0x80)) == UInt8(0)) {
        return (Int64(first), 1)
    }

    let width = Int64(first & UInt8(0x7f))
    if (width == 0) {
        throw CryptoException(ParseError, "${label} DER length uses indefinite form")
    }
    if (width > 4) {
        throw CryptoException(ParseError, "${label} DER length width is too large")
    }
    if (offset + 1 + width > bytes.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    var length: Int64 = 0
    var i = 0
    while (i < width) {
        length = (length << 8) | Int64(UInt8(bytes[offset + 1 + i]))
        i += 1
    }
    if (length < 0) {
        throw CryptoException(ParseError, "${label} DER length is negative")
    }
    if (length < 128) {
        throw CryptoException(ParseError, "${label} DER length uses non-minimal long form")
    }
    (length, 1 + width)
}

func encodeDerLength(length: Int64): Array<Byte> {
    if (length < 0) {
        throw CryptoException(OutOfBounds, "DER length must be non-negative")
    }
    if (length < 128) {
        return [UInt8(length)]
    }

    let tmp = ArrayList<Byte>()
    var x = length
    while (x > 0) {
        tmp.add(UInt8(x & 0xff))
        x >>= 8
    }
    if (tmp.size > 4) {
        throw CryptoException(OutOfBounds, "DER length exceeds 4-byte support limit")
    }

    let out = Array<Byte>(1 + tmp.size, repeat: 0)
    out[0] = UInt8(0x80 | UInt8(tmp.size))
    var i = 0
    while (i < tmp.size) {
        out[1 + i] = tmp[tmp.size - 1 - i]
        i += 1
    }
    out
}

func decodeOid(encoded: Array<Byte>, label: String): String {
    if (encoded.size == 0) {
        throw CryptoException(ParseError, "${label} OID is empty")
    }

    let firstByte = Int64(UInt8(encoded[0]))
    var first = firstByte / 40
    var second = firstByte % 40
    if (first > 2) {
        second = second + (first - 2) * 40
        first = 2
    }

    let nodes = ArrayList<String>()
    nodes.add(first.toString())
    nodes.add(second.toString())

    var value: Int64 = 0
    var open = false
    var i = 1
    while (i < encoded.size) {
        let b = Int64(UInt8(encoded[i]))
        value = (value << 7) | (b & 0x7f)
        open = true
        if ((b & 0x80) == 0) {
            nodes.add(value.toString())
            value = 0
            open = false
        }
        i += 1
    }
    if (open) {
        throw CryptoException(ParseError, "${label} OID has unterminated base-128 node")
    }

    var out = nodes[0]
    i = 1
    while (i < nodes.size) {
        out += ".${nodes[i]}"
        i += 1
    }
    out
}

func encodeOid(oid: String): Array<Byte> {
    let parts = oid.trimAscii().split('.', removeEmpty: true)
    if (parts.size < 2) {
        throw CryptoException(InvalidArgument, "OID must have at least two nodes")
    }

    let first = parseDecimal(parts[0], "OID first node")
    let second = parseDecimal(parts[1], "OID second node")
    if (first < 0 || first > 2) {
        throw CryptoException(InvalidArgument, "OID first node must be 0..2")
    }
    if (first < 2 && second >= 40) {
        throw CryptoException(InvalidArgument, "OID second node must be < 40 when first node is 0 or 1")
    }

    let out = ArrayList<Byte>()
    out.add(UInt8(first * 40 + second))

    var idx = 2
    while (idx < parts.size) {
        let node = parseDecimal(parts[idx], "OID node")
        if (node < 0) {
            throw CryptoException(InvalidArgument, "OID node must be non-negative")
        }
        appendBase128Node(out, node)
        idx += 1
    }
    out.toArray()
}

func appendBase128Node(out: ArrayList<Byte>, node: Int64): Unit {
    let tmp = ArrayList<Byte>()
    var value = node
    tmp.add(UInt8(value & 0x7f))
    value >>= 7
    while (value > 0) {
        tmp.add(UInt8(value & 0x7f))
        value >>= 7
    }

    var i = tmp.size - 1
    while (i >= 0) {
        let base = UInt8(tmp[i])
        if (i != 0) {
            out.add(base | UInt8(0x80))
        } else {
            out.add(base)
        }
        i -= 1
    }
}

func parseDecimal(text: String, label: String): Int64 {
    let s = text.trimAscii()
    if (s.size == 0) {
        throw CryptoException(InvalidArgument, "${label} must not be empty")
    }
    var value: Int64 = 0
    for (ch in s.toArray()) {
        if (ch < b'0' || ch > b'9') {
            throw CryptoException(InvalidArgument, "${label} is not a decimal integer")
        }
        value = value * 10 + Int64(ch - b'0')
    }
    value
}

func decodeSinglePemBlock(pemText: String, blockType: String): Array<Byte> {
    let beginMarker = "-----BEGIN ${blockType}-----"
    let endMarker = "-----END ${blockType}-----"
    let normalized = pemText.replace("\r", "\n")
    let lines = normalized.split('\n')

    var collecting = false
    var body = ""
    var seenBlocks = 0

    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed == beginMarker) {
            if (collecting) {
                throw CryptoException(ParseError, "nested PEM block BEGIN for ${blockType}")
            }
            collecting = true
            body = ""
            continue
        }
        if (trimmed == endMarker) {
            if (!collecting) {
                throw CryptoException(ParseError, "PEM END marker without BEGIN for ${blockType}")
            }
            collecting = false
            seenBlocks += 1
            continue
        }
        if (collecting && trimmed.size > 0) {
            body += trimmed
        }
    }

    if (collecting) {
        throw CryptoException(ParseError, "unterminated PEM block for ${blockType}")
    }
    if (seenBlocks != 1) {
        throw CryptoException(ParseError, "expected exactly one PEM block for ${blockType}")
    }
    base64Decode(body)
}

func base64Decode(text: String): Array<Byte> {
    let clean = stripAsciiWhitespace(text)
    if (clean.size == 0) {
        return []
    }
    if ((clean.size % 4) != 0) {
        throw CryptoException(ParseError, "base64 text length must be multiple of 4")
    }

    let padChars = countBase64Padding(clean)
    let outLen = clean.size / 4 * 3 - padChars
    if (outLen < 0) {
        throw CryptoException(ParseError, "invalid base64 padding length")
    }

    let out = Array<Byte>(outLen, repeat: 0)
    var src = 0
    var dst = 0
    while (src < clean.size) {
        let c0 = base64DecodeChar(clean[src], false)
        let c1 = base64DecodeChar(clean[src + 1], false)
        let c2 = base64DecodeChar(clean[src + 2], true)
        let c3 = base64DecodeChar(clean[src + 3], true)

        let v0 = UInt32(c0)
        let v1 = UInt32(c1)
        let v2 = UInt32(maxI64(c2, 0))
        let v3 = UInt32(maxI64(c3, 0))
        let word = (v0 << 18) | (v1 << 12) | (v2 << 6) | v3

        if (dst < outLen) {
            out[dst] = UInt8((word >> 16) & UInt32(0xff))
            dst += 1
        }
        if (dst < outLen && c2 >= 0) {
            out[dst] = UInt8((word >> 8) & UInt32(0xff))
            dst += 1
        }
        if (dst < outLen && c3 >= 0) {
            out[dst] = UInt8(word & UInt32(0xff))
            dst += 1
        }
        src += 4
    }
    out
}

func base64Encode(bytes: Array<Byte>): String {
    if (bytes.size == 0) {
        return ""
    }

    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let out = ArrayList<Byte>()
    var i = 0
    while (i < bytes.size) {
        let remaining = bytes.size - i
        let b0 = UInt32(UInt8(bytes[i]))
        let b1 = if (remaining > 1) {
            UInt32(UInt8(bytes[i + 1]))
        } else {
            UInt32(0)
        }
        let b2 = if (remaining > 2) {
            UInt32(UInt8(bytes[i + 2]))
        } else {
            UInt32(0)
        }

        let word = (b0 << 16) | (b1 << 8) | b2
        let c0 = Int64((word >> 18) & UInt32(0x3f))
        let c1 = Int64((word >> 12) & UInt32(0x3f))
        let c2 = Int64((word >> 6) & UInt32(0x3f))
        let c3 = Int64(word & UInt32(0x3f))

        out.add(alphabet[c0])
        out.add(alphabet[c1])
        out.add(if (remaining > 1) { alphabet[c2] } else { b'=' })
        out.add(if (remaining > 2) { alphabet[c3] } else { b'=' })
        i += 3
    }

    String.fromUtf8(out.toArray())
}

func stripAsciiWhitespace(text: String): String {
    var out = ""
    for (ch in text.toArray()) {
        if (ch == b' ' || ch == b'\n' || ch == b'\r' || ch == b'\t') {
            continue
        }
        out += String.fromUtf8([ch])
    }
    out
}

func countBase64Padding(text: String): Int64 {
    var pad = 0
    var i = text.size - 1
    while (i >= 0 && text[i] == b'=') {
        pad += 1
        i -= 1
    }
    if (pad > 2) {
        throw CryptoException(ParseError, "base64 padding exceeds 2 chars")
    }
    pad
}

func base64DecodeChar(ch: Byte, allowPadding: Bool): Int64 {
    if (ch >= b'A' && ch <= b'Z') {
        return Int64(ch - b'A')
    }
    if (ch >= b'a' && ch <= b'z') {
        return Int64(ch - b'a' + 26)
    }
    if (ch >= b'0' && ch <= b'9') {
        return Int64(ch - b'0' + 52)
    }
    if (ch == b'+') {
        return 62
    }
    if (ch == b'/') {
        return 63
    }
    if (allowPadding && ch == b'=') {
        return -1
    }
    throw CryptoException(ParseError, "invalid base64 character")
}

func isContextSpecificTag(tag: Int64): Bool {
    let b = UInt8(tag)
    (b & UInt8(0xc0)) == UInt8(0x80)
}

func trimLeadingZeroBytes(input: Array<Byte>): Array<Byte> {
    if (input.size == 0) {
        return []
    }
    var i = 0
    while (i < input.size && input[i] == 0) {
        i += 1
    }
    if (i >= input.size) {
        return [UInt8(0)]
    }
    input[i..]
}

func appendBytes(out: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    for (b in bytes) {
        out.add(b)
    }
}

func concatBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    secureCopyInto(left, out)
    secureCopyInto(right, out, dstOffset: left.size)
    out
}

func bytesEqual(left: Array<Byte>, right: Array<Byte>): Bool {
    constantTimeEquals(left, right)
}

func intToHexLower(value: Int64): String {
    let digits: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    ]
    if (value == 0) {
        return "0"
    }
    var x = value
    var out = ""
    while (x > 0) {
        let nibble = x & 0x0f
        out = digits[nibble] + out
        x >>= 4
    }
    out
}

func minI64(left: Int64, right: Int64): Int64 {
    if (left < right) {
        return left
    }
    right
}

func maxI64(left: Int64, right: Int64): Int64 {
    if (left > right) {
        return left
    }
    right
}
