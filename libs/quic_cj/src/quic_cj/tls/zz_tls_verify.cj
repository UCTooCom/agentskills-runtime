package quic_cj.tls

import jinguissl_core.crypto.digest.{sha256, hmac, HashAlgorithm}
import jinguissl_core.crypto.x509.{x509ParseDer, x509ExtractEcPublicKey, x509ExtractRsaPublicKey, x509BuildSimpleChain, x509VerifySignatureWithIssuer, X509Certificate, X509VerificationPolicy, X509VerificationResult}
import jinguissl_core.crypto.ecc.{EcPublicKey, ecdsaVerify}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.rsa.{RsaPublicKey, RsaHashAlgorithm, rsaVerifyPkcs1v15WithHash}
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.tls.{
    tls13VerifyCertificateChainFromHandshake,
    tls13VerifyServerAuthFlight,
    tls13VerifyServerAuthFlightWithProfile,
    tls13BuildClientAuthFlightEcdsa,
    tls13BuildClientAuthFlightRsaPss,
    tls13BuildCertificateRequestHandshake,
    Tls13AuthFlight,
    Tls13AuthFlightRole
}
import jinguissl_core.crypto.ecc.EcPrivateKey
import jinguissl_core.crypto.rsa.RsaPrivateKey

/// TLS 1.3 签名方案值（RFC 8446 §4.2.3）
public let VERIFY_SIG_ECDSA_SECP256R1_SHA256: UInt16 = 0x0403u16
public let VERIFY_SIG_ECDSA_SECP384R1_SHA384: UInt16 = 0x0503u16
public let VERIFY_SIG_ECDSA_SECP521R1_SHA512: UInt16 = 0x0603u16
public let VERIFY_SIG_ED25519: UInt16 = 0x0807u16
public let VERIFY_SIG_RSA_PSS_RSAE_SHA256: UInt16 = 0x0804u16
public let VERIFY_SIG_RSA_PSS_RSAE_SHA384: UInt16 = 0x0805u16
public let VERIFY_SIG_RSA_PSS_RSAE_SHA512: UInt16 = 0x0806u16
public let VERIFY_SIG_RSA_PKCS1_SHA256: UInt16 = 0x0401u16
public let VERIFY_SIG_RSA_PKCS1_SHA384: UInt16 = 0x0501u16
public let VERIFY_SIG_RSA_PKCS1_SHA512: UInt16 = 0x0601u16

/// 解析 TLS 证书消息体（RFC 8446 §4.4.2）。
/// 按顺序返回证书 DER 条目。
public func parseCertificateMsgBody(body: Array<Byte>): Option<Array<Array<Byte>>> {
    if (body.size < 4) { return None }
    let ctxLen = Int64(UInt8(body[0]))
    let pos: Int64 = 1 + ctxLen
    if (pos + 3 > body.size) { return None }
    let listLen = (Int64(UInt8(body[pos])) << 16) | (Int64(UInt8(body[pos + 1])) << 8) | Int64(UInt8(body[pos + 2]))
    if (listLen <= 0 || pos + 3 + listLen > body.size) { return None }
    let listEnd = pos + 3 + listLen
    var entries: Array<Array<Byte>> = []
    var cursor: Int64 = pos + 3
    while (cursor + 3 <= listEnd) {
        let certLen = (Int64(UInt8(body[cursor])) << 16) | (Int64(UInt8(body[cursor + 1])) << 8) | Int64(UInt8(body[cursor + 2]))
        if (certLen <= 0 || cursor + 3 + certLen > listEnd) { break }
        let certDer = body[cursor + 3 .. cursor + 3 + certLen]
        let n = entries.size
        let out = Array<Array<Byte>>(n + 1, repeat: [])
        var i: Int64 = 0
        while (i < n) { out[i] = entries[i]; i += 1 }
        out[n] = certDer
        entries = out
        let afterCert = cursor + 3 + certLen
        if (afterCert + 2 > listEnd) { break }
        let extLen = (Int64(UInt8(body[afterCert])) << 8) | Int64(UInt8(body[afterCert + 1]))
        cursor = afterCert + 2 + extLen
    }
    if (entries.size > 0) { Some(entries) } else { None }
}

/// 解析 DER 证书并返回 X509Certificate 对象。
public func parseCertDersToX509(certDers: Array<Array<Byte>>): Option<Array<X509Certificate>> {
    if (certDers.size == 0) { return None }
    var certs: Array<X509Certificate> = []
    var i: Int64 = 0
    while (i < certDers.size) {
        try {
            let parsed = x509ParseDer(certDers[i])
            let n = certs.size
            let out = Array<X509Certificate>(n + 1, repeat: parsed)
            var j: Int64 = 0
            while (j < n) { out[j] = certs[j]; j += 1 }
            out[n] = parsed
            certs = out
        } catch (_: Exception) {
            // 跳过无法解析的
        }
        i += 1
    }
    if (certs.size > 0) { Some(certs) } else { None }
}

// ════════════════════════════════════════════════════════════════════
//  新高级验证 API（委托给 jinguissl_core 组合验证）
// ════════════════════════════════════════════════════════════════════

/// verifyServerAuthFlightWithJinguissl — 一次性验证服务端证书 + CertificateVerify。
/// 使用 jinguissl_core 的 tls13VerifyServerAuthFlight 替代手动分步验证。
public func verifyServerAuthFlightWithJinguissl(
    flight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>
): Bool {
    try {
        let _ = tls13VerifyServerAuthFlight(flight, policy, transcriptHash, serverHsTrafficSecret)
        true
    } catch (_: Exception) {
        false
    }
}

/// verifyServerAuthFlightWithProfile — 带合规配置的完整服务端飞行验证。
public func verifyServerAuthFlightWithProfile(
    flight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>,
    profile: FipsProfile
 ): Bool {
    try {
        let _ = tls13VerifyServerAuthFlightWithProfile(flight, policy, transcriptHash, serverHsTrafficSecret, profile)
        true
    } catch (_: Exception) {
        false
    }
 }
 
/// verifyCertificateChainFromHandshakeMsg — 直接从握手消息验证证书链。
/// 取代 parseCertificateMsgBody + verifyCertChain 两步手动操作。
public func verifyCertificateChainFromHandshakeMsg(
    encodedCertificate: Array<Byte>,
    policy: X509VerificationPolicy
 ): Bool {
    try {
        let _ = tls13VerifyCertificateChainFromHandshake(encodedCertificate, policy)
        true
    } catch (_: Exception) {
        false
    }
 }
 
/// buildClientAuthFlightEcdsaWrapper — 构建客户端 ECDSA 证书响应飞行。
 /// 返回三个握手帧串联字节（Certificate + CertificateVerify + Finished）。
public func buildClientAuthFlightEcdsaWrapper(
    certChainDer: Array<Array<Byte>>,
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>
 ): Array<Byte> {
    try {
        let flight = tls13BuildClientAuthFlightEcdsa(certChainDer, privateKey, transcriptHash, clientHsTrafficSecret)
        concatFlightBytes(flight)
    } catch (_: Exception) {
        []
    }
 }
 
/// buildClientAuthFlightRsaPssWrapper — 构建客户端 RSA-PSS 证书响应飞行。
 /// 返回三个握手帧串联字节（Certificate + CertificateVerify + Finished）。
public func buildClientAuthFlightRsaPssWrapper(
    certChainDer: Array<Array<Byte>>,
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>
 ): Array<Byte> {
    try {
        let flight = tls13BuildClientAuthFlightRsaPss(certChainDer, privateKey, transcriptHash, clientHsTrafficSecret)
        concatFlightBytes(flight)
    } catch (_: Exception) {
        []
    }
 }
 
/// buildCertificateRequestHandshakeWrapper — 构建 CertificateRequest 消息。
public func buildCertificateRequestHandshakeWrapper(
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        0x0403,
        0x0503,
        0x0804
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
 ): Array<Byte> {
    try {
        tls13BuildCertificateRequestHandshake(
            requestContext: requestContext,
            signatureSchemes: signatureSchemes,
            certificateAuthorities: certificateAuthorities
        )
    } catch (_: Exception) {
        []
    }
 }
 
 /// verifyClientAuthFlightContract — 使用合约 API 验证客户端 auth flight。
 public func verifyClientAuthFlightContract(
     certDers: Array<Array<Byte>>,
     certVerifyBody: Array<Byte>,
     transcriptHash: Array<Byte>
 ): Bool {
     false // contract API not available, use verifyCertVerifySig
 }
 
/// 构建 CertificateVerify 内容（RFC 8446 §4.4.3）。
public func buildSignContent(transcriptHash: Array<Byte>, isClient: Bool): Array<Byte> {
    let ctxStr = if (isClient) { "TLS 1.3, client CertificateVerify\0" } else { "TLS 1.3, server CertificateVerify\0" }
    let ctxBytes = ctxStr.toArray()
    let total = 64 + ctxBytes.size + transcriptHash.size
    let out = Array<Byte>(total, repeat: 0u8)
    var i: Int64 = 64
    while (i < 64 + Int64(ctxBytes.size)) {
        out[i] = ctxBytes[i - 64]
        i += 1
    }
    i = 64 + Int64(ctxBytes.size)
    var j: Int64 = 0
    while (j < transcriptHash.size) {
        out[i + j] = transcriptHash[j]
        j += 1
    }
    out
}

/// 验证 ECDSA CertificateVerify 签名。
public func verifyEcdsaCertVerify(
    certDer: Array<Byte>,
    certVerifyBody: Array<Byte>,
    transcriptHash: Array<Byte>
): Bool {
    if (certVerifyBody.size < 4) { return false }
    let (sigLen, _) = readVerifyUint16(certVerifyBody, 2)
    if (sigLen <= 0 || 4 + sigLen > certVerifyBody.size) { return false }
    let sigValue = certVerifyBody[4 .. 4 + sigLen]

    let (r, s) = parseEcdsaDerSig(sigValue)
    if (r.size == 0 || s.size == 0) { return false }
    let rBn = BigNum.fromBytesBE(r)
    let sBn = BigNum.fromBytesBE(s)

    try {
        let cert = x509ParseDer(certDer)
        let pubKey = x509ExtractEcPublicKey(cert)
        let content = buildSignContent(transcriptHash, false)
        let digest = sha256(content)
        return ecdsaVerify(pubKey, digest, rBn, sBn)
    } catch (_: Exception) {
        return false
    }
}

/// 验证 RSA CertificateVerify 签名。
public func verifyRsaCertVerify(
    certDer: Array<Byte>,
    certVerifyBody: Array<Byte>,
    transcriptHash: Array<Byte>
): Bool {
    if (certVerifyBody.size < 4) { return false }
    let (scheme, _) = readVerifyUint16(certVerifyBody, 0)
    let (sigLen, _) = readVerifyUint16(certVerifyBody, 2)
    if (sigLen <= 0 || 4 + sigLen > certVerifyBody.size) { return false }
    let sigValue = certVerifyBody[4 .. 4 + sigLen]

    let hashAlg = verifySchemeToRsaHash(UInt16(scheme))
    try {
        let cert = x509ParseDer(certDer)
        let pubKey = x509ExtractRsaPublicKey(cert)
        let content = buildSignContent(transcriptHash, false)
        return rsaVerifyPkcs1v15WithHash(pubKey, content, sigValue, hashAlg)
    } catch (_: Exception) {
        return false
    }
}

/// 自动检测签名方案并分派验证。
public func verifyCertVerifySig(
    certDer: Array<Byte>,
    certVerifyBody: Array<Byte>,
    transcriptHash: Array<Byte>
): Bool {
    if (certVerifyBody.size < 2) { return false }
    let (scheme, _) = readVerifyUint16(certVerifyBody, 0)
    match (scheme) {
        case VERIFY_SIG_ECDSA_SECP256R1_SHA256 => return verifyEcdsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case VERIFY_SIG_ECDSA_SECP384R1_SHA384 => return verifyEcdsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case VERIFY_SIG_ECDSA_SECP521R1_SHA512 => return verifyEcdsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case _ => ()
    }
    // 回退：尝试 RSA
    match (scheme) {
        case VERIFY_SIG_RSA_PSS_RSAE_SHA256 => return verifyRsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case VERIFY_SIG_RSA_PSS_RSAE_SHA384 => return verifyRsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case VERIFY_SIG_RSA_PSS_RSAE_SHA512 => return verifyRsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case VERIFY_SIG_RSA_PKCS1_SHA256 => return verifyRsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case VERIFY_SIG_RSA_PKCS1_SHA384 => return verifyRsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case VERIFY_SIG_RSA_PKCS1_SHA512 => return verifyRsaCertVerify(certDer, certVerifyBody, transcriptHash)
        case _ => return false
    }
}

/// 验证 Finished 消息 HMAC（RFC 8446 §4.4.4）。
public func verifyFinishedMsg(
    finishedBody: Array<Byte>,
    finishedKey: Array<Byte>,
    transcriptHash: Array<Byte>
): Bool {
    if (finishedBody.size < 32) { return false }
    let expectedTag = hmac(HashAlgorithm.SHA256, finishedKey, transcriptHash)
    if (expectedTag.size < 32) { return false }
    var i: Int64 = 0
    while (i < 32) {
        if (expectedTag[i] != finishedBody[i]) { return false }
        i += 1
    }
    true
}

/// 从流量密钥派生完成密钥。
public func deriveFinishKey(baseSecret: Array<Byte>): Array<Byte> {
    quicHkdfExpandLabel(baseSecret, "finished", [], 32)
}

/// 执行完整的 TLS 服务端飞行验证：
/// 证书 → CertificateVerify 签名 → Finished HMAC。
public func verifyServerFlightFull(
    serverFlightData: Array<Byte>,
    clientHello: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>
): Bool {
    let messages = parseTlsHandshakeMessages(serverFlightData)
    if (messages.size < 3) { return false }

    var certMsg: TlsHandshakeMessage = TlsHandshakeMessage()
    var certVerifyMsg: TlsHandshakeMessage = TlsHandshakeMessage()
    var finishedMsg: TlsHandshakeMessage = TlsHandshakeMessage()
    var foundCert: Bool = false
    var foundCV: Bool = false
    var foundFin: Bool = false

    var idx: Int64 = 0
    while (idx < messages.size) {
        let mt = messages[idx].msgType
        if (mt == TLS_HANDSHAKE_TYPE_CERTIFICATE) {
            certMsg = messages[idx]; foundCert = true
        } else if (mt == TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY) {
            certVerifyMsg = messages[idx]; foundCV = true
        } else if (mt == TLS_HANDSHAKE_TYPE_FINISHED) {
            finishedMsg = messages[idx]; foundFin = true
        }
        idx += 1
    }
    if (!foundCert || !foundCV || !foundFin) { return false }

    // 到 Certificate 为止的交互记录（供 CertificateVerify 使用）
    var transcriptUpToCert: Array<Array<Byte>> = [clientHello]
    idx = 0
    while (idx < messages.size) {
        let mt = messages[idx].msgType
        if (mt == TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY || mt == TLS_HANDSHAKE_TYPE_FINISHED) { break }
        transcriptUpToCert = appendTranscript(transcriptUpToCert, messages[idx].rawBytes)
        idx += 1
    }
    let transcriptHashCert = computeTranscriptHash(transcriptUpToCert)

    // 解析叶子证书
    let certsOpt = parseCertificateMsgBody(certMsg.body)
    var certs: Array<Array<Byte>> = []
    if (let Some(c) <- certsOpt) {
        if (c.size == 0) { return false }
        certs = c
    } else { return false }
    let cvOk = verifyCertVerifySig(certs[0], certVerifyMsg.body, transcriptHashCert)
    if (!cvOk) { return false }

    // 2. 到 CertificateVerify 为止的交互记录（供 Finished 使用）
    var transcriptUpToCV: Array<Array<Byte>> = [clientHello]
    idx = 0
    while (idx < messages.size) {
        let mt = messages[idx].msgType
        if (mt == TLS_HANDSHAKE_TYPE_FINISHED) { break }
        transcriptUpToCV = appendTranscript(transcriptUpToCV, messages[idx].rawBytes)
        idx += 1
    }
    let transcriptHashCV = computeTranscriptHash(transcriptUpToCV)
    let finishedKey = deriveFinishKey(serverHsTrafficSecret)
    return verifyFinishedMsg(finishedMsg.body, finishedKey, transcriptHashCV)
}

/// 构建并验证证书链。
public func verifyCertChain(certDers: Array<Array<Byte>>): Bool {
    if (certDers.size < 2) { return false }
    let certsOpt = parseCertDersToX509(certDers)
    var certs: Array<X509Certificate> = []
    if (let Some(c) <- certsOpt) {
        if (!(c.size >= 2)) { return false }
        certs = c
    } else { return false }

    var candidates: Array<X509Certificate> = []
    var i: Int64 = 1
    while (i < certs.size) {
        let n = candidates.size
        let out = Array<X509Certificate>(n + 1, repeat: certs[i])
        var j: Int64 = 0
        while (j < n) { out[j] = candidates[j]; j += 1 }
        candidates = out
        i += 1
    }

    let chain = x509BuildSimpleChain(certs[0], candidates)
    if (chain.size < 2) { return false }

    var k: Int64 = 0
    while (k < chain.size - 1) {
        try {
            x509VerifySignatureWithIssuer(chain[k], chain[k + 1])
        } catch (_: Exception) {
            return false
        }
        k += 1
    }
    true
}

private func appendTranscript(arr: Array<Array<Byte>>, msg: Array<Byte>): Array<Array<Byte>> {
    let n = arr.size
    let out = Array<Array<Byte>>(n + 1, repeat: [])
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = msg
    out
}

private func readVerifyUint16(data: Array<Byte>, offset: Int64): (Int64, Int64) {
    if (offset + 2 > data.size) { return (0, -1) }
    let val = (Int64(UInt8(data[offset])) << 8) | Int64(UInt8(data[offset + 1]))
    (val, 2)
}

private func readEcdsaDerInt(data: Array<Byte>, pos: Int64): (Array<Byte>, Int64) {
    if (pos >= data.size || UInt8(data[pos]) != 0x02u8) { return ([], pos) }
    let itemLen = Int64(UInt8(data[pos + 1]))
    if (itemLen <= 0 || pos + 2 + itemLen > data.size) { return ([], pos) }
    let val = data[pos + 2 .. pos + 2 + itemLen]
    (val, pos + 2 + itemLen)
}

/// 解析 DER 编码的 ECDSA 签名 (r, s) 对。
private func parseEcdsaDerSig(data: Array<Byte>): (Array<Byte>, Array<Byte>) {
    if (data.size < 8 || UInt8(data[0]) != 0x30u8) { return ([], []) }
    let seqLen = Int64(UInt8(data[1]))
    if (seqLen <= 0 || 2 + seqLen > data.size) { return ([], []) }
    let (r, nextPos) = readEcdsaDerInt(data, 2)
    let (s, _) = readEcdsaDerInt(data, nextPos)
    (r, s)
}

private func verifySchemeToRsaHash(scheme: UInt16): RsaHashAlgorithm {
    match (scheme) {
        case VERIFY_SIG_RSA_PSS_RSAE_SHA256 => RsaHashAlgorithm.SHA256
        case VERIFY_SIG_RSA_PSS_RSAE_SHA384 => RsaHashAlgorithm.SHA384
        case VERIFY_SIG_RSA_PSS_RSAE_SHA512 => RsaHashAlgorithm.SHA512
        case VERIFY_SIG_RSA_PKCS1_SHA256 => RsaHashAlgorithm.SHA256
        case VERIFY_SIG_RSA_PKCS1_SHA384 => RsaHashAlgorithm.SHA384
        case VERIFY_SIG_RSA_PKCS1_SHA512 => RsaHashAlgorithm.SHA512
        case _ => RsaHashAlgorithm.SHA256
    }
}

/// 使用 SHA-256 哈希包装 buildSignContent。
private func buildDigestContent(transcriptHash: Array<Byte>, isClient: Bool): Array<Byte> {
    sha256(buildSignContent(transcriptHash, isClient))
}
private func concatFlightBytes(flight: Tls13AuthFlight): Array<Byte> {
    let a = flight.certificateHandshake
    let b = flight.certificateVerifyHandshake
    let c = flight.finishedHandshake
    let n1 = a.size
    let n2 = b.size
    let n3 = c.size
    let total = n1 + n2 + n3
    let out = Array<Byte>(total, repeat: 0u8)
    var i: Int64 = 0
    while (i < n1) { out[i] = a[i]; i += 1 }
    i = 0
    while (i < n2) { out[n1 + i] = b[i]; i += 1 }
    i = 0
    while (i < n3) { out[n1 + n2 + i] = c[i]; i += 1 }
    out
}
