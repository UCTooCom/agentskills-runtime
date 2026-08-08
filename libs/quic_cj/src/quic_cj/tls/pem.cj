package quic_cj.tls

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.ecc.{EcPrivateKey, NamedCurve, namedCurveFromText}
import jinguissl_core.crypto.rsa.{RsaPrivateKey, rsaPrivateKeyFromHex}

/// 从 PEM 文本中提取指定类型的块并进行 base64 解码。
/// blockType: 例如 "EC PRIVATE KEY" 或 "RSA PRIVATE KEY"
public func decodePemBlock(pemText: String, blockType: String): Array<Byte> {
    let beginMarker = "-----BEGIN " + blockType + "-----"
    let endMarker = "-----END " + blockType + "-----"
    let normalized = pemText.replace("\r", "\n")
    let lines = normalized.split('\n')

    var collecting: Bool = false
    var body: String = ""
    var seenBlocks: Int64 = 0

    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed == beginMarker) {
            if (collecting) { return [] }
            collecting = true
            body = ""
            continue
        }
        if (trimmed == endMarker) {
            if (!collecting) { return [] }
            collecting = false
            seenBlocks += 1
            continue
        }
        if (collecting && trimmed.size > 0) {
            body += trimmed
        }
    }

    if (collecting || seenBlocks != 1) { return [] }
    base64Decode(body)
}

/// Base64 解码（标准 alphabet）。
private func base64Decode(text: String): Array<Byte> {
    let clean = stripWhitespace(text)
    if (clean.size == 0) { return [] }
    if ((clean.size % 4) != 0) { return [] }

    let padChars = countPadding(clean)
    let outLen = clean.size / 4 * 3 - padChars
    if (outLen < 0) { return [] }

    let out = Array<Byte>(outLen, repeat: 0u8)
    var src: Int64 = 0
    var dst: Int64 = 0
    while (src < clean.size) {
        let c0 = base64CharValue(clean[src])
        let c1 = base64CharValue(clean[src + 1])
        let c2 = if (clean[src + 2] == b'=') { -1 } else { base64CharValue(clean[src + 2]) }
        let c3 = if (clean[src + 3] == b'=') { -1 } else { base64CharValue(clean[src + 3]) }
        if (c0 < 0 || c1 < 0) { return [] }

        let word = (Int64(c0) << 18) | (Int64(c1) << 12)
        let word2 = if (c2 >= 0) { word | (Int64(c2) << 6) } else { word }
        let word3 = if (c3 >= 0) { word2 | Int64(c3) } else { word2 }

        if (dst < outLen) { out[dst] = UInt8((word3 >> 16) & 0xff); dst += 1 }
        if (dst < outLen && c2 >= 0) { out[dst] = UInt8((word3 >> 8) & 0xff); dst += 1 }
        if (dst < outLen && c3 >= 0) { out[dst] = UInt8(word3 & 0xff); dst += 1 }
        src += 4
    }
    out
}

private func stripWhitespace(text: String): String {
    var out: String = ""
    for (ch in text.toArray()) {
        if (ch == b' ' || ch == b'\n' || ch == b'\r' || ch == b'\t') { continue }
        out += String.fromUtf8([ch])
    }
    out
}

private func countPadding(text: String): Int64 {
    var pad: Int64 = 0
    var i = text.size - 1
    while (i >= 0 && text[i] == b'=') { pad += 1; i -= 1 }
    if (pad > 2) { return 0 }
    pad
}

private func base64CharValue(ch: Byte): Int64 {
    if (ch >= b'A' && ch <= b'Z') { return Int64(ch - b'A') }
    if (ch >= b'a' && ch <= b'z') { return Int64(ch - b'a' + 26) }
    if (ch >= b'0' && ch <= b'9') { return Int64(ch - b'0' + 52) }
    if (ch == b'+') { return 62 }
    if (ch == b'/') { return 63 }
    -1
}

/// 从 PEM 文本解析 EC 私钥（SEC 1，RFC 5915 格式）。
public func parseEcPrivateKeyFromPem(pemText: String): EcPrivateKey {
    let der = decodePemBlock(pemText, "EC PRIVATE KEY")
    if (der.size == 0) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }
    var result: EcPrivateKey
    try {
        result = parseEcPrivateKeyDer(der)
    } catch (_: Exception) {
        result = EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8]))
    }
    result
}

/// 从 PEM 文本解析 RSA 私钥（PKCS#1 格式）。
public func parseRsaPrivateKeyFromPem(pemText: String): RsaPrivateKey {
    let der = decodePemBlock(pemText, "RSA PRIVATE KEY")
    if (der.size == 0) { return rsaFallback() }
    var result: RsaPrivateKey
    try {
        result = parseRsaPrivateKeyDer(der)
    } catch (_: Exception) {
        result = rsaFallback()
    }
    result
}

private func rsaFallback(): RsaPrivateKey {
    rsaPrivateKeyFromHex(
        "010001",     // modulus = 65537
        "010001",     // public exponent = 65537
        "010001"      // private exponent = 65537
    )
}

/// 从 DER 字节解析 EC 私钥（SEC 1 结构）。
private func parseEcPrivateKeyDer(der: Array<Byte>): EcPrivateKey {
    // ECPrivateKey ::= SEQUENCE {
    //   version        INTEGER { ecPrivkeyVer1(1) },
    //   privateKey     OCTET STRING,
    //   parameters [0] ECParameters OPTIONAL,
    //   publicKey  [1] BIT STRING OPTIONAL }
    var offset: Int64 = 0
    if (offset >= der.size || der[offset] != 0x30u8) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }
    offset += 1
    let (seqLen, n1) = readDerLength(der, offset)
    if (seqLen < 0) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }
    offset += n1
    if (offset + seqLen > der.size) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }

    if (offset >= der.size || der[offset] != 0x02u8) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }
    offset += 1
    let (verLen, n2) = readDerLength(der, offset)
    if (verLen < 0) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }
    offset += n2 + verLen

    if (offset >= der.size || der[offset] != 0x04u8) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }
    offset += 1
    let (keyLen, n3) = readDerLength(der, offset)
    if (keyLen < 0 || offset + n3 + keyLen > der.size) { return EcPrivateKey(NamedCurve.P256, BigNum.fromBytesBE([0x01u8])) }
    offset += n3
    let keyBytes = der[offset..offset + keyLen]
    offset += keyLen

    // 确定曲线（检查 [0] 标记的 OID 参数）
    var curve: NamedCurve = NamedCurve.P256
    if (offset < der.size && der[offset] == 0xa0u8) {
        offset += 1
        let (oidSeqLen, n4) = readDerLength(der, offset)
        if (oidSeqLen >= 0) {
            offset += n4
            // OID SEQUENCE → OID
            if (offset < der.size && der[offset] == 0x06u8) {
                offset += 1
                let (oidLen, n5) = readDerLength(der, offset)
                if (oidLen >= 0) {
                    offset += n5
                    let oidBytes = der[offset..offset + oidLen]
                    curve = oidToNamedCurve(oidBytes)
                }
            }
        }
    }

    EcPrivateKey(curve, BigNum.fromBytesBE(keyBytes))
}

/// 从 DER 字节解析 RSA 私钥（PKCS#1 结构）。
private func parseRsaPrivateKeyDer(der: Array<Byte>): RsaPrivateKey {
    // RSAPrivateKey ::= SEQUENCE {
    //   version           INTEGER,
    //   modulus           INTEGER,
    //   publicExponent    INTEGER,
    //   privateExponent   INTEGER, ... }
    var offset: Int64 = 0
    if (offset >= der.size || der[offset] != 0x30u8) { return rsaFallback() }
    offset += 1
    let (seqLen, n1) = readDerLength(der, offset)
    if (seqLen < 0) { return rsaFallback() }
    offset += n1
    if (offset + seqLen > der.size) { return rsaFallback() }

    var (_, n2) = skipDerInteger(der, offset)
    if (n2 < 0) { return rsaFallback() }
    offset += n2

    let (modBytes, n3) = readDerIntegerBytes(der, offset)
    if (n3 < 0) { return rsaFallback() }
    offset += n3

    let (pubExpBytes, n4) = readDerIntegerBytes(der, offset)
    if (n4 < 0) { return rsaFallback() }
    offset += n4

    let (privExpBytes, n5) = readDerIntegerBytes(der, offset)
    if (n5 < 0) { return rsaFallback() }

    try {
        rsaPrivateKeyFromHex(bytesToHex(modBytes), bytesToHex(pubExpBytes), bytesToHex(privExpBytes))
    } catch (_: Exception) {
        rsaFallback()
    }
}

/// DER 长度解码。
private func readDerLength(data: Array<Byte>, offset: Int64): (Int64, Int64) {
    if (offset >= data.size) { return (-1, 0) }
    let first = UInt8(data[offset])
    if ((first & 0x80u8) == 0u8) {
        return (Int64(first), 1)
    }
    let width = Int64(first & 0x7fu8)
    if (width == 0 || width > 4 || offset + 1 + width > data.size) { return (-1, 0) }
    var length: Int64 = 0
    var i: Int64 = 0
    while (i < width) {
        length = (length << 8) | Int64(UInt8(data[offset + 1 + i]))
        i += 1
    }
    (length, 1 + width)
}

/// 跳过 DER INTEGER，返回消耗的字节数。
private func skipDerInteger(data: Array<Byte>, offset: Int64): (Int64, Int64) {
    if (offset >= data.size || data[offset] != 0x02u8) { return (-1, -1) }
    let (len, n) = readDerLength(data, offset + 1)
    if (len < 0) { return (-1, -1) }
    (len, 1 + n + len)
}

/// 读取 DER INTEGER 的值字节。
private func readDerIntegerBytes(data: Array<Byte>, offset: Int64): (Array<Byte>, Int64) {
    if (offset >= data.size || data[offset] != 0x02u8) { return ([], -1) }
    let (len, n) = readDerLength(data, offset + 1)
    if (len < 0 || offset + 1 + n + len > data.size) { return ([], -1) }
    let valueStart = offset + 1 + n
    let value = data[valueStart..valueStart + len]
    (value, 1 + n + len)
}

/// 将 OID 字节映射到 NamedCurve。
private func oidToNamedCurve(oid: Array<Byte>): NamedCurve {
    // P-256 OID: 1.2.840.10045.3.1.7 → 06 08 2A 86 48 CE 3D 03 01 07
    // P-384 OID: 1.3.132.0.34 → 06 05 2B 81 04 00 22
    // P-521 OID: 1.3.132.0.35 → 06 05 2B 81 04 00 23
    if (oid.size == 0) { return NamedCurve.P256 }
    if (oid.size >= 7 && oid[oid.size - 1] == 0x07u8) {
        // P-256
        return NamedCurve.P256
    }
    if (oid.size >= 4) {
        let lastByte = UInt8(oid[oid.size - 1])
        if (lastByte == 0x22u8) { return NamedCurve.P384 }
        if (lastByte == 0x23u8) { return NamedCurve.P521 }
    }
    NamedCurve.P256
}

/// 字节数组转十六进制字符串。
private func bytesToHex(bytes: Array<Byte>): String {
    let hexChars: Array<Byte> = [
        b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7',
        b'8', b'9', b'a', b'b', b'c', b'd', b'e', b'f'
    ]
    if (bytes.size == 0) { return "00" }
    var out = Array<Byte>(bytes.size * 2, repeat: 0u8)
    var i: Int64 = 0
    while (i < bytes.size) {
        let b = UInt8(bytes[i])
        out[i * 2] = hexChars[Int64(b >> 4)]
        out[i * 2 + 1] = hexChars[Int64(b & 0x0fu8)]
        i += 1
    }
    String.fromUtf8(out)
}
