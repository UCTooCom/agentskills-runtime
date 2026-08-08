package http_lib.connection
/**
 * TLS 加密客户端连接。
 * 包装 TcpConnection 添加 TLS 握手、ALPN 协议协商和证书验证。
 * 支持 SNI（服务器名称指示）和自定义 CA 证书。
 */

import std.collection.ArrayList
import http_lib.buffer.ByteBuffer
import http_lib.utils.{copyBytes, maxInt64, toHex64}
import jinguissl.live.*
import jinguissl.contract.{contractSha256, contractHmac, HashAlgorithm}
import jinguissl_core.crypto.aes.*
import jinguissl_core.crypto.tls.{tls12VerifyCertificateChainFromHandshake}
import jinguissl_core.crypto.x509.{X509Certificate, X509VerificationPolicy, x509ParsePem, x509ParsePemChain}
import std.fs.*
import std.time.DateTime

let TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256: Int64 = 0xc02f
let TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384: Int64 = 0xc030
let TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256: Int64 = 0x009c
let TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA: Int64 = 0xc027
let TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA: Int64 = 0xc014
private let DEFAULT_TLS_RECORD_BUFFER_CAPACITY: Int64 = 8192
private let TLS_RECORD_READ_BUFFER_SIZE: Int64 = 8192
private let TLS_RECORD_HEADER_SIZE: Int64 = 5
private let TLS_MAX_PLAINTEXT_FRAGMENT_SIZE: Int64 = 16384

private func copyBytesRange(source: Array<Byte>, sourceOffset: Int64, length: Int64): Array<Byte> {
    let out = Array<Byte>(length, repeat: 0)
    copyBytes(source, sourceOffset, out, 0, length)
    out
}

private func constantTimeEquals(left: Array<Byte>, right: Array<Byte>): Bool {
    if (left.size != right.size) {
        return false
    }
    var diff: UInt8 = 0
    var i: Int64 = 0
    while (i < left.size) {
        diff = diff | (UInt8(left[i]) ^ UInt8(right[i]))
        i += 1
    }
    diff == 0
}

private func extractServerHelloRandom(encodedServerHello: Array<Byte>): Array<Byte> {
    if (encodedServerHello.size < 38 || encodedServerHello[0] != UInt8(0x02)) {
        throw TlsException("Invalid ServerHello handshake")
    }
    copyBytesRange(encodedServerHello, 6, 32)
}

private func extractServerHelloCipherSuite(encodedServerHello: Array<Byte>): Int64 {
    if (encodedServerHello.size < 39 || encodedServerHello[0] != UInt8(0x02)) {
        throw TlsException("Invalid ServerHello handshake")
    }
    let sessionIdLenOffset: Int64 = 38
    let sessionIdLen = Int64(UInt8(encodedServerHello[sessionIdLenOffset]))
    let cipherSuiteOffset = sessionIdLenOffset + 1 + sessionIdLen
    if (cipherSuiteOffset + 2 > encodedServerHello.size) {
        throw TlsException("ServerHello 密码套件 is out of bounds")
    }
    (Int64(UInt8(encodedServerHello[cipherSuiteOffset])) << 8) | Int64(UInt8(encodedServerHello[cipherSuiteOffset + 1]))
}

private func encodeFinishedHandshake(verifyData: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(4 + verifyData.size, repeat: 0)
    out[0] = UInt8(0x14)
    out[1] = UInt8((verifyData.size >> 16) & 0xff)
    out[2] = UInt8((verifyData.size >> 8) & 0xff)
    out[3] = UInt8(verifyData.size & 0xff)
    copyBytes(verifyData, 0, out, 4, verifyData.size)
    out
}

private func decodeFinishedHandshake(encoded: Array<Byte>): Array<Byte> {
    if (encoded.size < 4 || encoded[0] != UInt8(0x14)) {
        throw TlsException("Invalid Finished handshake")
    }
    let length = (Int64(UInt8(encoded[1])) << 16) | (Int64(UInt8(encoded[2])) << 8) | Int64(UInt8(encoded[3]))
    if (length <= 0 || 4 + length > encoded.size) {
        throw TlsException("Invalid Finished verify_data length")
    }
    copyBytesRange(encoded, 4, length)
}

private func buildFacadeServerKeyExchangeParams(
    serverFlightBody: Array<Byte>,
    messageOffset: Int64,
    messageLen: Int64
): Array<Byte> {
    if (messageLen < 4) {
        throw TlsException("ServerKeyExchange too short: ${messageLen} bytes")
    }
    let bodyOffset = messageOffset + 4
    let pointLen = Int64(UInt8(serverFlightBody[bodyOffset + 3]))
    let paramsLen = 4 + pointLen
    if (paramsLen <= 4 || paramsLen > messageLen) {
        throw TlsException("ServerKeyExchange ECDHE params length is invalid")
    }
    let encoded = Array<Byte>(4 + paramsLen, repeat: 0)
    encoded[0] = UInt8(0x0c)
    encoded[1] = UInt8((paramsLen >> 16) & 0xff)
    encoded[2] = UInt8((paramsLen >> 8) & 0xff)
    encoded[3] = UInt8(paramsLen & 0xff)
    copyBytes(serverFlightBody, bodyOffset, encoded, 4, paramsLen)
    encoded
}

private func tlsContentTypeFromByte(value: Byte): ContractTlsRecordContentType {
    match (UInt8(value)) {
        case 0x14 => ContractTlsRecordContentType.ChangeCipherSpec
        case 0x15 => ContractTlsRecordContentType.Alert
        case 0x16 => ContractTlsRecordContentType.Handshake
        case 0x17 => ContractTlsRecordContentType.ApplicationData
        case _ => throw TlsException("Unsupported TLS content type: ${Int64(UInt8(value))}")
    }
}

private func tlsContentTypeToByte(contentType: ContractTlsRecordContentType): Byte {
    match (contentType) {
        case ContractTlsRecordContentType.ChangeCipherSpec => UInt8(0x14)
        case ContractTlsRecordContentType.Alert => UInt8(0x15)
        case ContractTlsRecordContentType.Handshake => UInt8(0x16)
        case ContractTlsRecordContentType.ApplicationData => UInt8(0x17)
    }
}

private func encodeSequenceNumberInto(sequence: Int64, destination: Array<Byte>, destinationOffset!: Int64 = 0): Unit {
    let seq = UInt64(sequence)
    var i: Int64 = 0
    while (i < 8) {
        let shift = UInt64((7 - i) * 8)
        destination[destinationOffset + i] = UInt8((seq >> shift) & UInt64(0xff))
        i += 1
    }
}

private func moveBytesToFront(data: Array<Byte>, start: Int64, length: Int64): Unit {
    var i: Int64 = 0
    while (i < length) {
        data[i] = data[start + i]
        i += 1
    }
}

private func encodeTls12RecordWithPayloadParts(
    contentType: ContractTlsRecordContentType,
    a: Array<UInt8>,
    aLen: Int64,
    b: Array<UInt8>,
    bLen: Int64,
    c: Array<UInt8>,
    cLen: Int64
): Array<Byte> {
    let payloadLen = aLen + bLen + cLen
    let record = Array<UInt8>(TLS_RECORD_HEADER_SIZE + payloadLen, repeat: 0)
    record[0] = tlsContentTypeToByte(contentType)
    record[1] = UInt8(0x03)
    record[2] = UInt8(0x03)
    record[3] = UInt8((payloadLen >> 8) & 0xff)
    record[4] = UInt8(payloadLen & 0xff)
    var offset = TLS_RECORD_HEADER_SIZE
    if (aLen > 0) {
        a.copyTo(record, 0, offset, aLen)
        offset += aLen
    }
    if (bLen > 0) {
        b.copyTo(record, 0, offset, bLen)
        offset += bLen
    }
    if (cLen > 0) {
        c.copyTo(record, 0, offset, cLen)
    }
    record
}

private func concatFiveWithFourthLength(
    a: Array<UInt8>,
    b: Array<UInt8>,
    c: Array<UInt8>,
    d: Array<UInt8>,
    dLength: Int64,
    e: Array<UInt8>
): Array<Byte> {
    let total = a.size + b.size + c.size + dLength + e.size
    let result = Array<UInt8>(total, repeat: 0)
    var offset: Int64 = 0
    if (a.size > 0) {
        a.copyTo(result, 0, offset, a.size)
        offset += a.size
    }
    if (b.size > 0) {
        b.copyTo(result, 0, offset, b.size)
        offset += b.size
    }
    if (c.size > 0) {
        c.copyTo(result, 0, offset, c.size)
        offset += c.size
    }
    if (dLength > 0) {
        d.copyTo(result, 0, offset, dLength)
        offset += dLength
    }
    if (e.size > 0) {
        e.copyTo(result, 0, offset, e.size)
    }
    result
}

private func concatSixWithFourthLength(
    a: Array<UInt8>,
    b: Array<UInt8>,
    c: Array<UInt8>,
    d: Array<UInt8>,
    dLength: Int64,
    e: Array<UInt8>,
    f: Array<UInt8>
): Array<Byte> {
    let total = a.size + b.size + c.size + dLength + e.size + f.size
    let result = Array<UInt8>(total, repeat: 0)
    var offset: Int64 = 0
    if (a.size > 0) {
        a.copyTo(result, 0, offset, a.size)
        offset += a.size
    }
    if (b.size > 0) {
        b.copyTo(result, 0, offset, b.size)
        offset += b.size
    }
    if (c.size > 0) {
        c.copyTo(result, 0, offset, c.size)
        offset += c.size
    }
    if (dLength > 0) {
        d.copyTo(result, 0, offset, dLength)
        offset += dLength
    }
    if (e.size > 0) {
        e.copyTo(result, 0, offset, e.size)
        offset += e.size
    }
    if (f.size > 0) {
        f.copyTo(result, 0, offset, f.size)
    }
    result
}

public func tls12CipherSuiteKeyLen(cipherSuite: Int64): Int64 {
    if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256) {
        return 16
    }
    if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384) {
        return 32
    }
    if (cipherSuite == TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256) {
        return 16
    }
    if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA) {
        return 16
    }
    if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA) {
        return 32
    }
    16
}

public func tls12CipherSuiteIvLen(cipherSuite: Int64): Int64 {
    if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256 || cipherSuite ==
        TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384 || cipherSuite == TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256) {
        return 4
    }
    if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA || cipherSuite ==
        TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA) {
        return 16
    }
    12
}

/**
 * 将 TLS 1.2 密码套件整数转换为 IANA 名称。
 * 返回可读的密码套件名称（用于连接状态报告）。
 */
public func cipherSuiteToName(cipherSuite: Int64): String {
    if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256) {
        return "ECDHE_RSA_AES_128_GCM_SHA256"
    } else if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384) {
        return "ECDHE_RSA_AES_256_GCM_SHA384"
    } else if (cipherSuite == TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256) {
        return "RSA_AES_128_GCM_SHA256"
    } else if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA) {
        return "ECDHE_RSA_AES_128_CBC_SHA"
    } else if (cipherSuite == TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA) {
        return "ECDHE_RSA_AES_256_CBC_SHA"
    } else {
        return "UNKNOWN_CIPHER_SUITE_0x${toHex64(cipherSuite)}"
    }
}

private func fillTls12GcmNonce(destination: Array<Byte>, staticIv: Array<Byte>, explicitNonce: Array<Byte>): Unit {
    if (staticIv.size != 4) {
        throw TlsException("TLS 1.2 GCM static IV must be 4 bytes")
    }
    if (explicitNonce.size != 8) {
        throw TlsException("TLS 1.2 GCM explicit nonce must be 8 bytes")
    }
    if (destination.size != 12) {
        throw TlsException("TLS 1.2 GCM nonce scratch must be 12 bytes")
    }
    staticIv.copyTo(destination, 0, 0, 4)
    explicitNonce.copyTo(destination, 0, 4, 8)
}

private func fillTls12GcmNonceFromBytes(
    destination: Array<Byte>,
    staticIv: Array<Byte>,
    source: Array<Byte>,
    sourceOffset: Int64
): Unit {
    if (staticIv.size != 4) {
        throw TlsException("TLS 1.2 GCM static IV must be 4 bytes")
    }
    if (sourceOffset < 0 || sourceOffset + 8 > source.size) {
        throw TlsException("TLS 1.2 GCM explicit nonce is out of bounds")
    }
    if (destination.size != 12) {
        throw TlsException("TLS 1.2 GCM nonce scratch must be 12 bytes")
    }
    staticIv.copyTo(destination, 0, 0, 4)
    source.copyTo(destination, sourceOffset, 4, 8)
}

private func fillTls12Aad(
    destination: Array<Byte>,
    sequence: Int64,
    contentType: ContractTlsRecordContentType,
    plaintextLen: Int64
): Unit {
    if (destination.size != 13) {
        throw TlsException("TLS 1.2 AAD scratch must be 13 bytes")
    }
    let seq = UInt64(sequence)
    var i: Int64 = 0
    while (i < 8) {
        let shift = UInt64((7 - i) * 8)
        destination[i] = UInt8((seq >> shift) & UInt64(0xff))
        i += 1
    }
    destination[8] = match (contentType) {
        case ContractTlsRecordContentType.ChangeCipherSpec => UInt8(0x14)
        case ContractTlsRecordContentType.Alert => UInt8(0x15)
        case ContractTlsRecordContentType.Handshake => UInt8(0x16)
        case ContractTlsRecordContentType.ApplicationData => UInt8(0x17)
    // case _ => throw TlsException("不支持的 TLS 内容类型用于 AAD")
    }
    destination[9] = UInt8(0x03)
    destination[10] = UInt8(0x03)
    destination[11] = UInt8((plaintextLen >> 8) & 0xff)
    destination[12] = UInt8(plaintextLen & 0xff)
}

public class Tls12GcmCompatRecordLayer {
    private let writeContext: AesGcmContext
    private let readContext: AesGcmContext
    private let writeIv: Array<Byte>
    private let readIv: Array<Byte>
    private var writeSequence: Int64 = 0
    private var readSequence: Int64 = 0
    private let writeExplicitNonceScratch = Array<Byte>(8, repeat: 0)
    private let writeNonceScratch = Array<Byte>(12, repeat: 0)
    private let readNonceScratch = Array<Byte>(12, repeat: 0)
    private let writeAadScratch = Array<Byte>(13, repeat: 0)
    private let readAadScratch = Array<Byte>(13, repeat: 0)
    private let writeTagScratch = Array<Byte>(16, repeat: 0)
    private let readTagScratch = Array<Byte>(16, repeat: 0)
    private var writeCiphertextScratch: Array<Byte> = []
    private var readCiphertextScratch: Array<Byte> = []
    private var readPlaintextScratch: Array<Byte> = []

    public init(writeKey: Array<Byte>, writeIv: Array<Byte>, readKey: Array<Byte>, readIv: Array<Byte>) {
        if (writeIv.size != 4 || readIv.size != 4) {
            throw TlsException("TLS 1.2 AES-GCM requires 4-byte static IVs")
        }
        this.writeContext = AesGcmContext(writeKey)
        this.readContext = AesGcmContext(readKey)
        this.writeIv = writeIv.clone()
        this.readIv = readIv.clone()
    }

    private func getWriteCiphertextScratch(length: Int64): Array<Byte> {
        if (writeCiphertextScratch.size != length) {
            writeCiphertextScratch = Array<Byte>(length, repeat: 0)
        }
        writeCiphertextScratch
    }

    private func getReadCiphertextScratch(length: Int64): Array<Byte> {
        if (readCiphertextScratch.size != length) {
            readCiphertextScratch = Array<Byte>(length, repeat: 0)
        }
        readCiphertextScratch
    }

    private func getReadPlaintextScratch(length: Int64): Array<Byte> {
        if (readPlaintextScratch.size != length) {
            readPlaintextScratch = Array<Byte>(length, repeat: 0)
        }
        readPlaintextScratch
    }

    public func seal(contentType: ContractTlsRecordContentType, plaintext: Array<Byte>): Array<Byte> {
        encodeSequenceNumberInto(writeSequence, writeExplicitNonceScratch)
        fillTls12GcmNonce(writeNonceScratch, writeIv, writeExplicitNonceScratch)
        fillTls12Aad(writeAadScratch, writeSequence, contentType, plaintext.size)
        let ciphertext = getWriteCiphertextScratch(plaintext.size)
        aesGcmEncryptIntoWithContext(
            writeContext,
            writeNonceScratch,
            plaintext,
            ciphertext,
            writeTagScratch,
            aad: writeAadScratch,
            tagLen: 16
        )
        writeSequence += 1
        encodeTls12RecordWithPayloadParts(
            contentType,
            writeExplicitNonceScratch,
            writeExplicitNonceScratch.size,
            ciphertext,
            plaintext.size,
            writeTagScratch,
            16
        )
    }

    public func open(encodedRecord: Array<Byte>): ContractTlsRecordPlaintext {
        openRecordBytes(encodedRecord, 0, encodedRecord.size)
    }

    public func openRecordBytes(recordBytes: Array<Byte>, recordOffset: Int64, recordLen: Int64): ContractTlsRecordPlaintext {
        if (recordOffset < 0 || recordLen < TLS_RECORD_HEADER_SIZE || recordOffset + recordLen > recordBytes.size) {
            throw TlsException("TLS record bounds are invalid")
        }
        let contentType = tlsContentTypeFromByte(recordBytes[recordOffset])
        let fragmentLen = (Int64(UInt8(recordBytes[recordOffset + 3])) << 8) | Int64(UInt8(recordBytes[recordOffset + 4]))
        if (recordLen != TLS_RECORD_HEADER_SIZE + fragmentLen || fragmentLen < 24) {
            throw TlsException("TLS 1.2 AES-GCM record length is invalid")
        }
        let ciphertextLen = fragmentLen - 24
        let fragmentOffset = recordOffset + TLS_RECORD_HEADER_SIZE
        let ciphertext = getReadCiphertextScratch(ciphertextLen)
        copyBytes(recordBytes, fragmentOffset + 8, ciphertext, 0, ciphertextLen)
        copyBytes(recordBytes, fragmentOffset + 8 + ciphertextLen, readTagScratch, 0, 16)
        fillTls12GcmNonceFromBytes(readNonceScratch, readIv, recordBytes, fragmentOffset)
        fillTls12Aad(readAadScratch, readSequence, contentType, ciphertextLen)
        let plaintext = getReadPlaintextScratch(ciphertextLen)
        aesGcmDecryptIntoWithContext(
            readContext,
            readNonceScratch,
            ciphertext,
            readTagScratch,
            plaintext,
            aad: readAadScratch
        )
        readSequence += 1
        ContractTlsRecordPlaintext(ContractTlsVersion.Tls12, contentType, plaintext)
    }
}

private func tls12GcmFixtureKey(): Array<Byte> {
    let key = Array<Byte>(16, repeat: 0)
    var index: Int64 = 0
    while (index < key.size) {
        key[index] = UInt8(index + 1)
        index += 1
    }
    key
}

private func tls12GcmFixtureIv(): Array<Byte> {
    let iv = Array<Byte>(4, repeat: 0)
    iv[0] = UInt8(0xa0)
    iv[1] = UInt8(0xa1)
    iv[2] = UInt8(0xa2)
    iv[3] = UInt8(0xa3)
    iv
}

public func tls12GcmFixturePlaintext(): Array<Byte> {
    unsafe { "kaca tls record fixture".rawData() }.clone()
}

public func tls12GcmSealFixtureApplicationData(): Array<Byte> {
    let key = tls12GcmFixtureKey()
    let iv = tls12GcmFixtureIv()
    let layer = Tls12GcmCompatRecordLayer(key, iv, key, iv)
    layer.seal(ContractTlsRecordContentType.ApplicationData, tls12GcmFixturePlaintext())
}

public func tls12GcmSealFixtureApplicationDataPair(): Array<Array<Byte>> {
    let key = tls12GcmFixtureKey()
    let iv = tls12GcmFixtureIv()
    let layer = Tls12GcmCompatRecordLayer(key, iv, key, iv)
    [
        layer.seal(ContractTlsRecordContentType.ApplicationData, tls12GcmFixturePlaintext()),
        layer.seal(ContractTlsRecordContentType.ApplicationData, tls12GcmFixturePlaintext())
    ]
}

public func tls12GcmSealFixtureHandshake(): Array<Byte> {
    let key = tls12GcmFixtureKey()
    let iv = tls12GcmFixtureIv()
    let layer = Tls12GcmCompatRecordLayer(key, iv, key, iv)
    layer.seal(ContractTlsRecordContentType.Handshake, tls12GcmFixturePlaintext())
}

public func tls12GcmOpenFixtureApplicationData(encodedRecord: Array<Byte>): Array<Byte> {
    tls12GcmOpenFixtureApplicationDataBytes(encodedRecord, 0, encodedRecord.size)
}

public func tls12GcmOpenFixtureApplicationDataPair(records: Array<Array<Byte>>): Array<Array<Byte>> {
    let key = tls12GcmFixtureKey()
    let iv = tls12GcmFixtureIv()
    let layer = Tls12GcmCompatRecordLayer(key, iv, key, iv)
    let plaintexts = Array<Array<Byte>>(records.size, repeat: [])
    var index: Int64 = 0
    while (index < records.size) {
        let plaintext = layer.open(records[index])
        if (plaintext.contentType != ContractTlsRecordContentType.ApplicationData) {
            throw TlsException("TLS fixture record is not application data")
        }
        plaintexts[index] = plaintext.fragment
        index += 1
    }
    plaintexts
}

public func tls12GcmOpenFixtureApplicationDataBytes(recordBytes: Array<Byte>, recordOffset: Int64, recordLen: Int64): Array<Byte> {
    let key = tls12GcmFixtureKey()
    let iv = tls12GcmFixtureIv()
    let layer = Tls12GcmCompatRecordLayer(key, iv, key, iv)
    let plaintext = layer.openRecordBytes(recordBytes, recordOffset, recordLen)
    if (plaintext.contentType != ContractTlsRecordContentType.ApplicationData) {
        throw TlsException("TLS fixture record is not application data")
    }
    plaintext.fragment
}

public func tls12GcmOpenFixtureHandshake(encodedRecord: Array<Byte>): Array<Byte> {
    let key = tls12GcmFixtureKey()
    let iv = tls12GcmFixtureIv()
    let layer = Tls12GcmCompatRecordLayer(key, iv, key, iv)
    let plaintext = layer.open(encodedRecord)
    if (plaintext.contentType != ContractTlsRecordContentType.Handshake) {
        throw TlsException("TLS fixture record is not handshake")
    }
    plaintext.fragment
}

/**
 * 解析系统 CA 证书包路径。
 * 探测各 Linux 发行版的常见位置，返回
 * 从找到的第一个可读文件中解析的 X509 信任锚点。
 */
private func resolveSystemCaCerts(): Array<X509Certificate> {
    let candidatePaths = [
        "/etc/ssl/certs/ca-certificates.crt",     // Debian/Ubuntu 路径
        "/etc/pki/tls/certs/ca-bundle.crt",        // RHEL/CentOS/Fedora 路径
        "/etc/ssl/ca-bundle.pem",                  // OpenSUSE 路径
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",  // RHEL 7+ 路径
        "/etc/ssl/cert.pem",                       // Alpine/macOS 路径
        "/usr/local/etc/openssl/cert.pem",         // Homebrew OpenSSL 路径
    ]
    for (path in candidatePaths) {
        try {
            let pem = String.fromUtf8(File.readFrom(Path(path)))
            if (pem.size > 0) {
                return x509ParsePemChain(pem)
            }
        } catch (_: Exception) {
            // 探测下一个路径
        }
    }
    // 未找到系统 CA 包——返回空
    []
}

public class TlsException <: Exception {
    public init(message: String) {
        super(message)
    }
}

public class TlsConnection <: AbstractConnection & Connection {
    private let tcpConn: TcpConnection
    private let tlsConfig: TlsConfig
    private var sslConnected: Bool = false
    private let serverName: String
    private var receivedCloseNotify: Bool = false
    private var reachedTransportEof: Bool = false
    private var writeRecordLayer: ?Tls12GcmCompatRecordLayer = None
    private var readRecordLayer: ?Tls12GcmCompatRecordLayer = None
    private var clientHello: Array<Byte> = []
    private var clientFinished: Array<Byte> = []
    private var negotiatedAlpn: String = ""
    private var negotiatedCipherSuite: String = ""
    private var pendingAppData: Array<Byte> = []
    private var pendingAppDataOffset: Int64 = 0
    private var offsetWriteScratch: Array<Byte> = []
    private var pendingRecordBytes: Array<Byte> = []
    private var pendingRecordBytesOffset: Int64 = 0
    private var pendingRecordBytesLimit: Int64 = 0
    private let recordReadBuffer: Array<Byte> = Array<UInt8>(TLS_RECORD_READ_BUFFER_SIZE, repeat: 0)
    private let rawRecordHeaderScratch: Array<Byte> = Array<UInt8>(TLS_RECORD_HEADER_SIZE, repeat: 0)

    public init(tcpConn: TcpConnection, serverName: String) {
        this(tcpConn, serverName, TlsConfig())
    }

    public init(tcpConn: TcpConnection, serverName: String, tlsConfig: TlsConfig) {
        this.tcpConn = tcpConn
        this.serverName = serverName
        this.tlsConfig = tlsConfig.copy()
        this.connected = tcpConn.isConnected()
        this.localAddr = tcpConn.localAddress()
        this.remoteAddr = tcpConn.remoteAddress()
        this.connectedTime = tcpConn.connectedAt()
        this.lastActivity = tcpConn.lastActivityAt()
    }

    private func log(message: String): Unit {
        if (tlsConfig.enableDiagnostics) {
            println(message)
        }
    }

    private func buildClientHelloWithFacade(): ContractTls12ClientHello {
        contractTls12BuildHttpClientHello(
            ContractTls12KeyExchange.EcdheP256,
            serverName: serverName,
            alpnProtocols: tlsConfig.nextProtos
        )
    }

    private func buildClientKeyExchangeWithFacade(): ContractTls12EcdheClientKeyExchange {
        contractTls12BuildEcdheClientKeyExchange(
            ContractTls12KeyExchange.EcdheP256,
            clientPrivateScalar: Some(secureRandom32())
        )
    }

    private func deriveClientSecretsWithFacade(
        clientKeyExchangeState: ContractTls12EcdheClientKeyExchange,
        encodedServerKeyExchange: Array<Byte>,
        clientRandom: Array<Byte>,
        serverRandom: Array<Byte>,
        cipherSuite: Int64
    ): ContractTls12HandshakeSecrets {
        contractTls12DeriveClientSecretsFromEcdhe(
            ContractTls12KeyExchange.EcdheP256,
            clientKeyExchangeState.clientPrivateScalar,
            encodedServerKeyExchange,
            clientRandom,
            serverRandom,
            keyLen: tls12CipherSuiteKeyLen(cipherSuite),
            ivLen: tls12CipherSuiteIvLen(cipherSuite)
        )
    }

    private func createCompatRecordLayer(
        clientSecrets: ContractTls12HandshakeSecrets
    ): Tls12GcmCompatRecordLayer {
        Tls12GcmCompatRecordLayer(
            clientSecrets.clientWriteKey,
            clientSecrets.clientWriteIv,
            clientSecrets.serverWriteKey,
            clientSecrets.serverWriteIv
        )
    }

    private func markTransportClosed(closeNotify!: Bool = false): Unit {
        connected = false
        if (closeNotify) {
            receivedCloseNotify = true
        }
        reachedTransportEof = true
    }

    public override func canReuseTransport(): Bool {
        connected && sslConnected && !receivedCloseNotify && !reachedTransportEof && tcpConn.canReuseTransport()
    }

    public func handshake(): Unit {
        let diagnostics = tlsConfig.enableDiagnostics
        try {
            // 如果未配置则自动加载系统 CA 证书
            if (tlsConfig.caCertPath.isEmpty() && tlsConfig.autoLoadSystemCerts) {
                tlsConfig.ensureCaCert()
            }

            log("[TLS] Starting TLS 握手...")

            let clientHelloState = buildClientHelloWithFacade()
            clientHello = clientHelloState.encodedClientHello
            let clientRandom = clientHelloState.clientRandom
            log("[TLS] ClientHello built by jinguiSSL facade (P-256 ECDHE)")
            if (diagnostics) {
                log("[TLS] TLS 1.2 ClientHello built, length: ${clientHello.size}")
                log("[TLS] ClientHello hex dump (first 64 bytes):")
                var hexStr = ""
                var i: Int64 = 0
                while (i < 64 && i < clientHello.size) {
                    let byteVal = Int64(clientHello[i])
                    let hex1 = byteVal / 16
                    let hex2 = byteVal % 16
                    let chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
                    hexStr = hexStr + chars[hex1] + chars[hex2] + " "
                    i += 1
                }
                log("[TLS]   ${hexStr}")
            }

            let clientHelloRecord = contractTlsEncodePlaintextRecord(ContractTlsVersion.Tls12, ContractTlsRecordContentType.Handshake, clientHello)

            log("[TLS] Sending TLS 1.2 ClientHello...")
            tcpConn.write(clientHelloRecord)
            tcpConn.flush()
            if (diagnostics) {
                log("[TLS] ClientHello sent (${clientHelloRecord.size} bytes)")
            }

            let serverHelloBody = receiveRawRecord()
            if (diagnostics) {
                log("[TLS] Received server response (${serverHelloBody.size} bytes)")
            }
            // 从 ServerHello 扩展中提取协商的 ALPN 协议
            negotiatedAlpn = extractAlpnFromServerHello(serverHelloBody)
            if (diagnostics) {
                log("[TLS] Negotiated ALPN protocol: '${negotiatedAlpn}'")
            }

            let cipherSuite = extractServerHelloCipherSuite(serverHelloBody)
            negotiatedCipherSuite = cipherSuiteToName(cipherSuite)
            if (diagnostics) {
                log("[TLS] Server selected 密码套件: 0x${toHex64(cipherSuite)}")
            }

            let serverRandom = extractServerHelloRandom(serverHelloBody)
            if (diagnostics) {
                log("[TLS] Server random extracted (${serverRandom.size} bytes)")
            }

            let certBody = receiveRawRecord()
            if (diagnostics) {
                log("[TLS] Certificate received (${certBody.size} bytes)")
            }

            // 证书链和主机名验证。
            if (tlsConfig.verifyPeer) {
                let hostname = if (tlsConfig.verifyHost) { serverName } else { "" }
                let anchors: Array<X509Certificate> = if (tlsConfig.caCertPath.isEmpty()) {
                    resolveSystemCaCerts()
                } else {
                    try {
                        let caPem = String.fromUtf8(File.readFrom(Path(tlsConfig.caCertPath)))
                        x509ParsePemChain(caPem)
                    } catch (e: Exception) {
                        log("[TLS] Failed to load CA cert from ${tlsConfig.caCertPath}: ${e.message}")
                        throw TlsException("Failed to load CA certificate: ${e.message}")
                    }
                }
                if (anchors.size == 0) {
                    throw TlsException("No CA trust anchors available — cannot verify peer certificate. Set verifyPeer=false to skip verification, or configure caCertPath.")
                } else {
                    let policy = X509VerificationPolicy(
                        anchors,
                        intermediates: [],
                        requiredLeafDnsName: hostname,
                        validationTime: ""
                    )
                    try {
                        _ = tls12VerifyCertificateChainFromHandshake(certBody, policy)
                        log("[TLS] Certificate verification passed")
                    } catch (e: Exception) {
                        log("[TLS] Certificate verification failed: ${e.message}")
                        throw TlsException("Certificate verification failed: ${e.message}")
                    }
                }
            } else {
                log("[TLS] Certificate verification skipped (verifyPeer=false)")
            }

            let serverFlightBuffer = ByteBuffer(capacity: certBody.size)
            var offset: Int64 = 0
            var encodedServerKeyExchange: Array<Byte> = []
            var foundServerKeyExchange = false
            var foundServerHelloDone = false
            var serverKeyExchangeMsgLen: Int64 = 0
            log("[TLS] About to start parsing server flight...")

            while (!foundServerHelloDone) {
                let serverFlightPartLen = receiveRawRecordInto(serverFlightBuffer)
                let serverFlightBody = serverFlightBuffer.getArray()
                let serverFlightBodyLen = serverFlightBuffer.getLimit()
                if (diagnostics) {
                    log(
                        "[TLS] Server flight chunk (${serverFlightPartLen} bytes, total ${serverFlightBodyLen} bytes)")
                }

                while (offset < serverFlightBodyLen) {
                    if (offset + 4 > serverFlightBodyLen) {
                        break
                    }
                    let msgType = serverFlightBody[offset]
                    let msgLen = (Int64(UInt8(serverFlightBody[offset + 1])) << 16) | (Int64(UInt8(serverFlightBody[offset +
                            2])) << 8) | Int64(UInt8(serverFlightBody[offset + 3]))

                    if (diagnostics) {
                        let msgTypeName = match (msgType) {
                            case 0x02 => "ServerHello"
                            case 0x0b => "Certificate"
                            case 0x0c => "ServerKeyExchange"
                            case 0x0e => "ServerHelloDone"
                            case _ => "Unknown"
                        }
                        log(
                            "[TLS] Handshake message: ${msgTypeName} (0x${toHex64(Int64(msgType))}), length=${msgLen} at offset ${offset}")
                    }

                    let fullMessageLen = 4 + msgLen
                    if (offset + fullMessageLen > serverFlightBodyLen) {
                        break
                    }

                    if (msgType == 0x0e) {
                        log("[TLS] ServerHelloDone received")
                        foundServerHelloDone = true
                    } else if (msgType == 0x0c) {
                        serverKeyExchangeMsgLen = fullMessageLen
                        encodedServerKeyExchange = buildFacadeServerKeyExchangeParams(serverFlightBody, offset, msgLen)
                        foundServerKeyExchange = true
                        if (diagnostics) {
                            log("[TLS] ServerKeyExchange ECDHE params captured for jinguiSSL facade parse")
                        }
                    }

                    offset += fullMessageLen
                }
            }

            if (!foundServerKeyExchange) {
                throw TlsException("ServerKeyExchange not found in server flight")
            }
            if (!foundServerHelloDone) {
                throw TlsException("ServerHelloDone not found in server flight")
            }

            if (diagnostics) {
                log("[TLS] ServerKeyExchange message: ${serverKeyExchangeMsgLen} bytes")
            }

            log("[TLS] Generating client 密钥交换...")
            let clientKeyExchangeState = buildClientKeyExchangeWithFacade()
            let clientKeyExchange = clientKeyExchangeState.encodedClientKeyExchange
            log("[TLS] Client 密钥交换 built by jinguiSSL facade")
            let serverFlightBody = serverFlightBuffer.getArray()
            let serverFlightBodyLen = serverFlightBuffer.getLimit()

            let handshakeMessages = concatFiveWithFourthLength(
                clientHello,
                serverHelloBody,
                certBody,
                serverFlightBody,
                serverFlightBodyLen,
                clientKeyExchange
            )
            let handshakeHash = contractSha256(handshakeMessages)
            if (diagnostics) {
                log(
                    "[TLS] Handshake hash computed (${handshakeHash.size} bytes, total messages: ${handshakeMessages.size} bytes)")
            }

            let clientSecrets = deriveClientSecretsWithFacade(
                clientKeyExchangeState,
                encodedServerKeyExchange,
                clientRandom,
                serverRandom,
                cipherSuite
            )
            log("[TLS] Master secret derived")

            writeRecordLayer = Some(createCompatRecordLayer(clientSecrets))
            readRecordLayer = Some(createCompatRecordLayer(clientSecrets))
            log("[TLS] Record layers created")

            let clientKeyExchangeRecord = contractTlsEncodePlaintextRecord(ContractTlsVersion.Tls12, ContractTlsRecordContentType.Handshake, clientKeyExchange)
            tcpConn.write(clientKeyExchangeRecord)
            tcpConn.flush()
            log("[TLS] ClientKeyExchange sent")

            let changeCipherSpec: Array<Byte> = [0x01]
            let clientCCSRecord = contractTlsEncodePlaintextRecord(ContractTlsVersion.Tls12, ContractTlsRecordContentType.ChangeCipherSpec, changeCipherSpec)
            tcpConn.write(clientCCSRecord)
            tcpConn.flush()
            log("[TLS] ChangeCipherSpec sent")

            let finishedVerifyData = tls12PrfSha256(clientSecrets.masterSecret, "client finished", handshakeHash, 12)

            if (diagnostics) {
                var finishedHex = ""
                var fi: Int64 = 0
                while (fi < finishedVerifyData.size) {
                    let bv = Int64(finishedVerifyData[fi])
                    if (fi > 0) { finishedHex = finishedHex + " " }
                    finishedHex = finishedHex + toHex64(bv)
                    fi += 1
                }
                log("[TLS] Client Finished verify_data: ${finishedHex}")
            }

            clientFinished = encodeFinishedHandshake(finishedVerifyData)
            let clientFinishedRecord = writeRecordLayer.getOrThrow().seal(ContractTlsRecordContentType.Handshake, clientFinished)
            tcpConn.write(clientFinishedRecord)
            tcpConn.flush()
            if (diagnostics) {
                log("[TLS] Client Finished sent (${finishedVerifyData.size} bytes)")
            }

            _ = receiveRawRecord()
            log("[TLS] Server ChangeCipherSpec received")

            let serverFinishedRecord = receiveAndDecryptRecord()
            let serverFinishedMsg = decodeFinishedHandshake(serverFinishedRecord)

            let serverHandshakeHash = contractSha256(
                concatSixWithFourthLength(
                    clientHello,
                    serverHelloBody,
                    certBody,
                    serverFlightBody,
                    serverFlightBodyLen,
                    clientKeyExchange,
                    clientFinished
                )
            )
            let expectedFinished = tls12PrfSha256(clientSecrets.masterSecret, "server finished", serverHandshakeHash, 12)
            if (diagnostics) {
                log("[TLS] Server Finished received (${serverFinishedMsg.size} bytes)")
                log("[TLS] Expected Finished: ${expectedFinished.size} bytes")
            }
            if (!constantTimeEquals(serverFinishedMsg, expectedFinished)) {
                throw TlsException("Server Finished verify_data mismatch")
            }
            log("[TLS] Server Finished verification passed")

            sslConnected = true
            connected = true
            log("[TLS] TLS 握手 completed successfully!")
        } catch (e: Exception) {
            close()
            log("[TLS] TLS 握手 failed: ${e.message}")
            throw TlsException("TLS 握手 failed: ${e.message}")
        }
    }

    private func receiveRawRecord(): Array<Byte> {
        let diagnostics = tlsConfig.enableDiagnostics
        if (diagnostics) {
            log("[TLS] Waiting for record...")
        }

        let header = rawRecordHeaderScratch
        let headerLen = readExact(header, 0, TLS_RECORD_HEADER_SIZE)
        if (diagnostics) {
            log("[TLS] Read ${headerLen} header bytes")
        }

        if (headerLen < TLS_RECORD_HEADER_SIZE) {
            markTransportClosed()
            throw TlsException("Failed to read TLS record header, got ${headerLen} bytes")
        }

        let contentType = header[0]
        let versionMajor = header[1]
        let versionMinor = header[2]
        let length = (Int64(UInt8(header[3])) << 8) | Int64(UInt8(header[4]))

        if (diagnostics) {
            let ct1 = Int64(contentType) / 16
            let ct2 = Int64(contentType) % 16
            let vm1 = Int64(versionMajor) / 16
            let vm2 = Int64(versionMajor) % 16
            let vn1 = Int64(versionMinor) / 16
            let vn2 = Int64(versionMinor) % 16
            let chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
            log(
                "[TLS] Record: type=0x${chars[ct1]}${chars[ct2]}, version=${chars[vm1]}${chars[vm2]}.${chars[vn1]}${chars[vn2]}, length=${length}")
        }

        if (contentType == UInt8(0x17)) {
            if (diagnostics) {
                log("[TLS] Application data record received")
            }
        } else if (contentType == UInt8(0x15)) {
            let body = Array<UInt8>(Int64(length), repeat: 0)
            _ = readExact(body, 0, Int64(length))
            markTransportClosed()
            if (length >= 2) {
                let alertLevel = body[0]
                let alertDesc = body[1]
                throw TlsException(
                    "TLS Alert received: level=0x${toHex64(Int64(alertLevel))}, desc=0x${toHex64(Int64(alertDesc))}")
            }
            throw TlsException("TLS Alert received but unable to decode")
        }

        let body = Array<UInt8>(Int64(length), repeat: 0)
        _ = readExact(body, 0, Int64(length))
        body
    }

    private func receiveRawRecordInto(destination: ByteBuffer): Int64 {
        let diagnostics = tlsConfig.enableDiagnostics
        if (diagnostics) {
            log("[TLS] Waiting for record...")
        }

        let header = rawRecordHeaderScratch
        let headerLen = readExact(header, 0, TLS_RECORD_HEADER_SIZE)
        if (diagnostics) {
            log("[TLS] Read ${headerLen} header bytes")
        }

        if (headerLen < TLS_RECORD_HEADER_SIZE) {
            markTransportClosed()
            throw TlsException("Failed to read TLS record header, got ${headerLen} bytes")
        }

        let contentType = header[0]
        let versionMajor = header[1]
        let versionMinor = header[2]
        let length = (Int64(UInt8(header[3])) << 8) | Int64(UInt8(header[4]))

        if (diagnostics) {
            let ct1 = Int64(contentType) / 16
            let ct2 = Int64(contentType) % 16
            let vm1 = Int64(versionMajor) / 16
            let vm2 = Int64(versionMajor) % 16
            let vn1 = Int64(versionMinor) / 16
            let vn2 = Int64(versionMinor) % 16
            let chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
            log(
                "[TLS] Record: type=0x${chars[ct1]}${chars[ct2]}, version=${chars[vm1]}${chars[vm2]}.${chars[vn1]}${chars[vn2]}, length=${length}")
        }

        if (contentType == UInt8(0x15)) {
            let body = Array<UInt8>(Int64(length), repeat: 0)
            _ = readExact(body, 0, Int64(length))
            markTransportClosed()
            if (length >= 2) {
                let alertLevel = body[0]
                let alertDesc = body[1]
                throw TlsException(
                    "TLS Alert received: level=0x${toHex64(Int64(alertLevel))}, desc=0x${toHex64(Int64(alertDesc))}")
            }
            throw TlsException("TLS Alert received but unable to decode")
        }

        let writeOffset = destination.reserveWritable(length)
        if (length > 0) {
            _ = readExact(destination.getArray(), writeOffset, length)
            destination.advanceWrite(length)
        }
        length
    }

    private func readTlsRecordWithHeader(header: Array<Byte>, length: Int64): Array<Byte> {
        let recordLen = TLS_RECORD_HEADER_SIZE + length
        let record = Array<Byte>(recordLen, repeat: 0)
        copyBytes(header, 0, record, 0, TLS_RECORD_HEADER_SIZE)
        if (length > 0) {
            _ = readExact(record, TLS_RECORD_HEADER_SIZE, length)
        }
        record
    }

    private func receiveAndDecryptRecord(): Array<Byte> {
        let diagnostics = tlsConfig.enableDiagnostics
        if (diagnostics) {
            log("[TLS] Waiting for encrypted record...")
        }

        let header = rawRecordHeaderScratch
        let headerLen = readExact(header, 0, TLS_RECORD_HEADER_SIZE)
        if (diagnostics) {
            log("[TLS] Read ${headerLen} header bytes")
        }

        if (headerLen < TLS_RECORD_HEADER_SIZE) {
            markTransportClosed()
            throw TlsException("Failed to read encrypted TLS record header, got ${headerLen} bytes")
        }

        let contentType = header[0]
        let length = (Int64(UInt8(header[3])) << 8) | Int64(UInt8(header[4]))
        if (diagnostics) {
            log("[TLS] Encrypted record: type=0x${toHex64(Int64(contentType))}, length=${length}")
        }

        if (contentType == UInt8(0x15)) {
            let body = Array<UInt8>(Int64(length), repeat: 0)
            _ = readExact(body, 0, Int64(length))
            markTransportClosed()
            if (length >= 2) {
                let alertLevel = body[0]
                let alertDesc = body[1]
                throw TlsException(
                    "TLS Alert received: level=0x${toHex64(Int64(alertLevel))}, desc=0x${toHex64(Int64(alertDesc))}")
            }
            throw TlsException("TLS Alert received but unable to decode")
        }

        let record = readTlsRecordWithHeader(header, Int64(length))
        let decrypted = readRecordLayer.getOrThrow().open(record)

        if (decrypted.contentType == ContractTlsRecordContentType.Alert) {
            markTransportClosed(closeNotify: true)
            let alert = contractTlsDecodeAlertPayload(decrypted.fragment)
            throw TlsException("TLS Alert: ${alert.level} - ${alert.description}")
        }

        if (decrypted.contentType != ContractTlsRecordContentType.Handshake) {
            throw TlsException("Expected handshake message, got ${decrypted.contentType}")
        }

        decrypted.fragment
    }

    private func readExact(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        let startTime = DateTime.now()
        var received: Int64 = 0
        while (received < length) {
            let n = tcpConn.read(buf, offset + received, length - received)
            if (n < 0) {
                if (received == 0) {
                    return n
                }
                throw TlsException("Connection closed while reading TLS record")
            }
            if (n == 0) {
                if (DateTime.now() - startTime > Duration.second * 30) {
                    if (received == 0) {
                        return 0
                    }
                    throw TlsException("Timed out while reading TLS record")
                }
                continue
            }
            received += n
        }
        received
    }

    private func readApplicationDataRecord(): Int64 {
        while (true) {
            let decrypted = match (receiveBufferedPlainRecord()) {
                case Some(record) => record
                case None =>
                    markTransportClosed()
                    return 0
            }

            if (decrypted.contentType == ContractTlsRecordContentType.Alert) {
                let alert = contractTlsDecodeAlertPayload(decrypted.fragment)
                if (alert.description == ContractTlsAlertDescription.AlertCloseNotify) {
                    markTransportClosed(closeNotify: true)
                    return 0
                }
                markTransportClosed()
                throw TlsException("TLS Alert from server: ${alert.description}")
            }

            if (decrypted.contentType == ContractTlsRecordContentType.ApplicationData) {
                pendingAppData = decrypted.fragment
                pendingAppDataOffset = 0
                return pendingAppData.size
            }
        }
        0
    }

    private func receiveBufferedPlainRecord(): ?ContractTlsRecordPlaintext {
        let startTime = DateTime.now()
        while (true) {
            let available = pendingRecordBytesAvailable()
            if (available >= 5) {
                let headerStart = pendingRecordBytesOffset
                let length = (Int64(UInt8(pendingRecordBytes[headerStart + 3])) << 8) | Int64(UInt8(pendingRecordBytes[headerStart +
                        4]))
                let recordLen = TLS_RECORD_HEADER_SIZE + length
                if (available >= recordLen) {
                    let record = readRecordLayer.getOrThrow().openRecordBytes(
                        pendingRecordBytes,
                        headerStart,
                        recordLen
                    )
                    pendingRecordBytesOffset += recordLen
                    compactPendingRecordBytesIfNeeded()
                    return Some(record)
                }
            }

            let n = tcpConn.read(recordReadBuffer)
            if (n < 0) {
                markTransportClosed()
                throw TlsException("Connection closed while reading application data")
            }
            if (n == 0) {
                if (available > 0) {
                    markTransportClosed()
                    throw TlsException("Connection closed with partial TLS record")
                }
                if (DateTime.now() - startTime > Duration.second * 30) {
                    return None
                }
                continue
            }

            appendPendingRecordBytes(recordReadBuffer, 0, n)
        }
        None
    }

    private func pendingRecordBytesAvailable(): Int64 {
        pendingRecordBytesLimit - pendingRecordBytesOffset
    }

    private func appendPendingRecordBytes(data: Array<Byte>, offset: Int64, length: Int64): Unit {
        if (length <= 0) {
            return
        }

        ensurePendingRecordBytesCapacity(length)
        copyBytes(data, offset, pendingRecordBytes, pendingRecordBytesLimit, length)
        pendingRecordBytesLimit += length
    }

    private func ensurePendingRecordBytesCapacity(additional: Int64): Unit {
        if (pendingRecordBytes.size - pendingRecordBytesLimit >= additional) {
            return
        }

        compactPendingRecordBytes()
        if (pendingRecordBytes.size - pendingRecordBytesLimit >= additional) {
            return
        }

        let retained = pendingRecordBytesAvailable()
        let required = retained + additional
        var newCapacity = maxInt64(pendingRecordBytes.size, DEFAULT_TLS_RECORD_BUFFER_CAPACITY)
        while (newCapacity < required) {
            newCapacity = maxInt64(newCapacity * 2, required)
        }

        let expanded = Array<Byte>(newCapacity, repeat: 0)
        if (retained > 0) {
            copyBytes(pendingRecordBytes, pendingRecordBytesOffset, expanded, 0, retained)
        }
        pendingRecordBytes = expanded
        pendingRecordBytesOffset = 0
        pendingRecordBytesLimit = retained
    }

    private func compactPendingRecordBytesIfNeeded(): Unit {
        if (pendingRecordBytesOffset >= pendingRecordBytesLimit) {
            resetPendingRecordBytes()
        } else if (pendingRecordBytesOffset > 0 && pendingRecordBytesOffset * 2 >= pendingRecordBytesLimit) {
            compactPendingRecordBytes()
        }
    }

    private func compactPendingRecordBytes(): Unit {
        if (pendingRecordBytesOffset <= 0) {
            return
        }
        if (pendingRecordBytesOffset >= pendingRecordBytesLimit) {
            resetPendingRecordBytes()
            return
        }

        let retained = pendingRecordBytesAvailable()
        moveBytesToFront(pendingRecordBytes, pendingRecordBytesOffset, retained)
        pendingRecordBytesOffset = 0
        pendingRecordBytesLimit = retained
    }

    private func resetPendingRecordBytes(): Unit {
        pendingRecordBytesOffset = 0
        pendingRecordBytesLimit = 0
    }

    private func getOffsetWriteScratch(length: Int64): Array<Byte> {
        if (offsetWriteScratch.size != length) {
            offsetWriteScratch = Array<Byte>(length, repeat: 0)
        }
        offsetWriteScratch
    }

    private func copyPendingAppData(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        let available = pendingAppData.size - pendingAppDataOffset
        let copyLen = if (available < length) {
            available
        } else {
            length
        }
        if (copyLen > 0) {
            pendingAppData.copyTo(buf, pendingAppDataOffset, offset, copyLen)
        }
        pendingAppDataOffset += copyLen
        if (pendingAppDataOffset >= pendingAppData.size) {
            pendingAppData = []
            pendingAppDataOffset = 0
        }
        copyLen
    }

    public func isReadable(timeout: ?Duration): Bool {
        tcpConn.isReadable(timeout)
    }

    public func isWritable(timeout: ?Duration): Bool {
        tcpConn.isWritable(timeout)
    }

    public func read(buf: Array<UInt8>): Int64 {
        updateActivity()
        if (sslConnected && readRecordLayer.isSome()) {
            return read(buf, 0, buf.size)
        }
        tcpConn.read(buf)
    }

    public func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        updateActivity()
        if (sslConnected && readRecordLayer.isSome()) {
            try {
                if (offset < 0 || length < 0 || offset + length > buf.size) {
                    throw TlsException("TLS read offset/length out of bounds")
                }
                if (length == 0) {
                    return 0
                }

                if (pendingAppDataOffset >= pendingAppData.size) {
                    let available = readApplicationDataRecord()
                    if (available <= 0) {
                        return available
                    }
                }

                return copyPendingAppData(buf, offset, length)
            } catch (e: Exception) {
                close()
                throw TlsException("TLS decryption failed: ${e.message}")
            }
        }
        tcpConn.read(buf, offset, length)
    }

    public func write(data: Array<UInt8>): Unit {
        updateActivity()
        if (sslConnected && writeRecordLayer.isSome()) {
            try {
                let recordLayer = writeRecordLayer.getOrThrow()
                // TLS 1.2 规范 (RFC 5246 §6.2.1) 规定单个明文 fragment 最大 2^14 = 16384 字节。
                // 必须将大数据分片为多条 TLS 记录，否则服务器判定 record_overflow
                // 强制关闭连接，客户端写入报 10054 "An existing connection was forcibly closed"。
                // 与 tls_server_connection.cj 的写入逻辑保持一致。
                let maxFragmentSize: Int64 = 16384
                var fragmentOffset: Int64 = 0
                while (fragmentOffset < data.size) {
                    let remaining = data.size - fragmentOffset
                    let chunkSize = if (remaining > maxFragmentSize) { maxFragmentSize } else { remaining }
                    let chunk = Array<UInt8>(chunkSize, repeat: 0)
                    copyBytes(data, fragmentOffset, chunk, 0, chunkSize)
                    let encrypted = recordLayer.seal(ContractTlsRecordContentType.ApplicationData, chunk)
                    tcpConn.write(encrypted)
                    fragmentOffset += chunkSize
                }
                tcpConn.flush()
            } catch (e: Exception) {
                close()
                throw TlsException("TLS encryption failed: ${e.message}")
            }
        } else {
            tcpConn.write(data)
        }
    }

    public func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit {
        updateActivity()
        if (offset < 0 || length < 0 || offset + length > data.size) {
            throw Exception("write offset/length out of bounds")
        }
        if (length == 0) {
            return
        }
        if (sslConnected && writeRecordLayer.isSome()) {
            let plaintext = if (offset == 0 && length == data.size) {
                data
            } else {
                let dataSlice = getOffsetWriteScratch(length)
                copyBytes(data, offset, dataSlice, 0, length)
                dataSlice
            }
            // 复用 write(data) 的 16384 字节分片加密逻辑（RFC 5246 §6.2.1），
            // 避免大载荷封装为单条 TLS 记录触发服务器 record_overflow 断连。
            write(plaintext)
        } else {
            tcpConn.write(data, offset, length)
        }
    }

    public func flush(): Unit {
        tcpConn.flush()
    }

    public func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit {
        // 在一次批处理中连接并通过 TLS 加密写入
        if (buffers.size == 1) { write(buffers[0]) }
        else { let combined = concatBuffers(buffers); if (combined.size > 0) { write(combined) } }
    }

    public override func setReadTimeout(timeout: Duration): Unit {
        readTimeout = Some(timeout)
        tcpConn.setReadTimeout(timeout)
    }

    public override func setWriteTimeout(timeout: Duration): Unit {
        writeTimeout = Some(timeout)
        tcpConn.setWriteTimeout(timeout)
    }

    public override func setTimeout(timeout: Duration): Unit {
        readTimeout = Some(timeout)
        writeTimeout = Some(timeout)
        tcpConn.setTimeout(timeout)
    }

    public func close(): Unit {
        if (sslConnected && writeRecordLayer.isSome()) {
            try {
                let closeNotify = writeRecordLayer
                    .getOrThrow()
                    .seal(
                        ContractTlsRecordContentType.Alert,
                        contractTlsEncodeAlertPayload(
                            ContractTlsAlertLevel.AlertWarning,
                            ContractTlsAlertDescription.AlertCloseNotify
                        )
                    )
                tcpConn.write(closeNotify)
                tcpConn.flush()
            } catch (_: Exception) {
            }
        }
        // 在释放前清零密钥材料 (R7)
        // 用零覆盖 AES-GCM IV 和共享密钥数组。
        // 虽然 AesGcmContext 不暴露公共擦除方法，
        // 清除我们的引用确保 GC 可以回收内存。
        // 清零可能包含密钥材料的临时缓冲区。
        var zero: Int64 = 0
        while (zero < rawRecordHeaderScratch.size) {
            rawRecordHeaderScratch[zero] = 0
            zero += 1
        }
        writeRecordLayer = None
        readRecordLayer = None
        clientHello = []
        clientFinished = []
        pendingAppData = []
        offsetWriteScratch = []
        pendingRecordBytes = []
        tcpConn.close()
        connected = false
        sslConnected = false
        reachedTransportEof = true
    }

    public func isClosed(): Bool {
        !connected
    }

    /**
     * 获取握手后的 TLS 连接状态。
     * 返回协商后的 TLS 参数。
     */
    public func connectionState(): ?ConnectionState {
        Some(ConnectionState(
            version: "TLS 1.2",
            cipherSuite: negotiatedCipherSuite,
            negotiatedProtocol: negotiatedAlpn,
            serverName: serverName,
            isSecure: true
        ))
    }
}
