package jinguissl_core.crypto.tls

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.digest.{sha256, sha384}
import jinguissl_core.crypto.ecc.{EcPrivateKey, NamedCurve, ecdsaSign, ecdsaVerify}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaHashAlgorithm, RsaPrivateKey, rsaSignPssWithHash, rsaVerifyPssWithHash}
import jinguissl_core.crypto.utils.secureCopyInto
import jinguissl_core.crypto.x509.{X509Certificate, x509ExtractEcPublicKey, x509ExtractRsaPublicKey}

private let TLS13_CERT_VERIFY_PREFIX_LEN: Int64 = 64
private let TLS13_CERT_VERIFY_CONTEXT_SERVER: String = "TLS 1.3, server CertificateVerify"
private let TLS13_CERT_VERIFY_CONTEXT_CLIENT: String = "TLS 1.3, client CertificateVerify"

public func tls13BuildServerCertificateVerifyEcdsa(
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyEcdsa(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_SERVER)
}

public func tls13BuildClientCertificateVerifyEcdsa(
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyEcdsa(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_CLIENT)
}

public func tls13BuildServerCertificateVerifyRsaPss(
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyRsaPss(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_SERVER)
}

public func tls13BuildClientCertificateVerifyRsaPss(
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyRsaPss(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_CLIENT)
}

public func tls13VerifyServerCertificateVerify(
    encodedCertificateVerify: Array<Byte>,
    certificate: X509Certificate,
    transcriptHash: Array<Byte>
): Bool {
    tls13VerifyCertificateVerify(encodedCertificateVerify, certificate, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_SERVER)
}

public func tls13VerifyClientCertificateVerify(
    encodedCertificateVerify: Array<Byte>,
    certificate: X509Certificate,
    transcriptHash: Array<Byte>
): Bool {
    tls13VerifyCertificateVerify(encodedCertificateVerify, certificate, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_CLIENT)
}

private func tls13BuildCertificateVerifyEcdsa(
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>,
    contextLabel: String
): Array<Byte> {
    let signatureScheme = tls13ResolveEcdsaCertificateVerifyScheme(privateKey.curve)
    let digest = tls13ComputeCertificateVerifyDigestForScheme(contextLabel, transcriptHash, signatureScheme)
    let (r, s) = ecdsaSign(privateKey, digest)
    let signature = tls13EncodeEcdsaSignatureDer(r, s)
    tlsEncodeCertificateVerifyHandshake(
        TlsCertificateVerifyMessage(signatureScheme, signature)
    )
}

private func tls13BuildCertificateVerifyRsaPss(
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>,
    contextLabel: String
): Array<Byte> {
    let digest = tls13ComputeCertificateVerifyDigestForScheme(
        contextLabel,
        transcriptHash,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    )
    let signature = rsaSignPssWithHash(
        privateKey,
        digest,
        RsaHashAlgorithm.SHA256,
        saltLen: TLS13_HASH_LEN
    )
    tlsEncodeCertificateVerifyHandshake(
        TlsCertificateVerifyMessage(TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256, signature)
    )
}

private func tls13VerifyCertificateVerify(
    encodedCertificateVerify: Array<Byte>,
    certificate: X509Certificate,
    transcriptHash: Array<Byte>,
    contextLabel: String
): Bool {
    let message = try {
        tlsDecodeCertificateVerifyHandshake(encodedCertificateVerify)
    } catch (_: CryptoException) {
        return false
    }
    if (
        message.signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256 ||
        message.signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384
    ) {
        let publicKey = try {
            x509ExtractEcPublicKey(certificate)
        } catch (_: CryptoException) {
            return false
        }
        if (!tls13IsCertificateCurveAllowedForScheme(publicKey.curve, message.signatureScheme)) {
            return false
        }
        let digest = try {
            tls13ComputeCertificateVerifyDigestForScheme(contextLabel, transcriptHash, message.signatureScheme)
        } catch (_: CryptoException) {
            return false
        }
        let (r, s) = try {
            tls13DecodeEcdsaSignatureDer(message.signature)
        } catch (_: CryptoException) {
            return false
        }
        return ecdsaVerify(publicKey, digest, r, s)
    }

    if (message.signatureScheme == TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256) {
        let publicKey = try {
            x509ExtractRsaPublicKey(certificate)
        } catch (_: CryptoException) {
            return false
        }
        let digest = try {
            tls13ComputeCertificateVerifyDigestForScheme(contextLabel, transcriptHash, message.signatureScheme)
        } catch (_: CryptoException) {
            return false
        }
        return rsaVerifyPssWithHash(
            publicKey,
            digest,
            message.signature,
            RsaHashAlgorithm.SHA256,
            saltLen: TLS13_HASH_LEN
        )
    }

    false
}

private func tls13ComputeCertificateVerifyDigestForScheme(
    contextLabel: String,
    transcriptHash: Array<Byte>,
    signatureScheme: Int64
): Array<Byte> {
    tls13RequireCertificateVerifyTranscriptHash(transcriptHash)
    let contextBytes = contextLabel.toArray()
    let input = Array<Byte>(TLS13_CERT_VERIFY_PREFIX_LEN + contextBytes.size + 1 + transcriptHash.size, repeat: UInt8(0x20))
    secureCopyInto(contextBytes, input, dstOffset: TLS13_CERT_VERIFY_PREFIX_LEN)
    input[TLS13_CERT_VERIFY_PREFIX_LEN + contextBytes.size] = UInt8(0x00)
    secureCopyInto(transcriptHash, input, dstOffset: TLS13_CERT_VERIFY_PREFIX_LEN + contextBytes.size + 1)
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256 || signatureScheme == TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256) {
        return sha256(input)
    }
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384) {
        return sha384(input)
    }
    throw CryptoException(Unsupported, "TLS1.3 CertificateVerify signature scheme is unsupported: ${signatureScheme}")
}

private func tls13RequireCertificateVerifyTranscriptHash(transcriptHash: Array<Byte>): Unit {
    if (transcriptHash.size != TLS13_SHA256_HASH_LEN && transcriptHash.size != TLS13_SHA384_HASH_LEN) {
        throw CryptoException(InvalidArgument, "TLS1.3 hash length must be SHA-256 or SHA-384 sized")
    }
}

private func tls13ResolveEcdsaCertificateVerifyScheme(curve: NamedCurve): Int64 {
    if (curve == P256) {
        return TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256
    }
    if (curve == P384) {
        return TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384
    }
    throw CryptoException(Unsupported, "TLS1.3 ECDSA CertificateVerify curve is unsupported: ${curve.toString()}")
}

private func tls13IsCertificateCurveAllowedForScheme(curve: NamedCurve, signatureScheme: Int64): Bool {
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256) {
        return curve == P256
    }
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384) {
        return curve == P384
    }
    false
}

private func tls13EncodeEcdsaSignatureDer(r: BigNum, s: BigNum): Array<Byte> {
    let encodedR = tls13DerEncodeUnsignedInteger(r, "TLS1.3 ECDSA signature.r")
    let encodedS = tls13DerEncodeUnsignedInteger(s, "TLS1.3 ECDSA signature.s")
    let payload = tls13CertificateVerifyConcat(encodedR, encodedS)
    tls13DerWrap(0x30, payload)
}

private func tls13DecodeEcdsaSignatureDer(signatureDer: Array<Byte>): (BigNum, BigNum) {
    let (tag, sequenceValue, consumed) = tls13DerReadElement(signatureDer, 0, "TLS1.3 ECDSA signature")
    if (tag != 0x30) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature must be DER SEQUENCE")
    }
    if (consumed != signatureDer.size) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature has trailing bytes")
    }

    let (rTag, rValue, rConsumed) = tls13DerReadElement(sequenceValue, 0, "TLS1.3 ECDSA signature.r")
    if (rTag != 0x02) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature.r must be DER INTEGER")
    }
    let (sTag, sValue, sConsumed) = tls13DerReadElement(sequenceValue, rConsumed, "TLS1.3 ECDSA signature.s")
    if (sTag != 0x02) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature.s must be DER INTEGER")
    }
    if (rConsumed + sConsumed != sequenceValue.size) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature sequence has trailing bytes")
    }

    let rBytes = tls13ParsePositiveDerInteger(rValue, "TLS1.3 ECDSA signature.r")
    let sBytes = tls13ParsePositiveDerInteger(sValue, "TLS1.3 ECDSA signature.s")
    (BigNum.fromBytesBE(rBytes), BigNum.fromBytesBE(sBytes))
}

private func tls13DerEncodeUnsignedInteger(value: BigNum, label: String): Array<Byte> {
    if (value.isNegative() || value.isZero()) {
        throw CryptoException(InvalidArgument, "${label} must be positive")
    }
    let magnitude = value.toBytesBE()
    if (magnitude.size == 0) {
        throw CryptoException(InvalidArgument, "${label} must not be empty")
    }
    let highBitSet = (Int64(UInt8(magnitude[0])) & 0x80) != 0
    if (!highBitSet) {
        return tls13DerWrap(0x02, magnitude)
    }
    let withPad = Array<Byte>(magnitude.size + 1, repeat: 0)
    secureCopyInto(magnitude, withPad, dstOffset: 1)
    tls13DerWrap(0x02, withPad)
}

private func tls13ParsePositiveDerInteger(value: Array<Byte>, label: String): Array<Byte> {
    if (value.size == 0) {
        throw CryptoException(ParseError, "${label} must not be empty")
    }
    if ((Int64(UInt8(value[0])) & 0x80) != 0) {
        throw CryptoException(ParseError, "${label} must be non-negative")
    }
    if (value.size > 1 && UInt8(value[0]) == UInt8(0x00) && (Int64(UInt8(value[1])) & 0x80) == 0) {
        throw CryptoException(ParseError, "${label} uses non-minimal encoding")
    }
    if (value.size > 1 && UInt8(value[0]) == UInt8(0x00)) {
        return value[1..]
    }
    value
}

private func tls13DerWrap(tag: Int64, value: Array<Byte>): Array<Byte> {
    if (tag < 0 || tag > 255) {
        throw CryptoException(InvalidArgument, "DER tag must be uint8")
    }
    let length = tls13DerEncodeLength(value.size)
    let out = Array<Byte>(1 + length.size + value.size, repeat: 0)
    out[0] = UInt8(tag)
    secureCopyInto(length, out, dstOffset: 1)
    secureCopyInto(value, out, dstOffset: 1 + length.size)
    out
}

private func tls13DerEncodeLength(length: Int64): Array<Byte> {
    if (length < 0) {
        throw CryptoException(OutOfBounds, "DER length must be non-negative")
    }
    if (length < 128) {
        return [UInt8(length)]
    }

    let width = if (length <= 0xff) {
        1
    } else if (length <= 0xffff) {
        2
    } else if (length <= 0xffffff) {
        3
    } else if (length <= 0xffffffff) {
        4
    } else {
        throw CryptoException(OutOfBounds, "DER length exceeds 4-byte support limit")
    }

    let out = Array<Byte>(1 + width, repeat: 0)
    out[0] = UInt8(0x80 | width)
    var i = 0
    while (i < width) {
        let shift = (width - 1 - i) * 8
        out[1 + i] = UInt8((length >> shift) & 0xff)
        i += 1
    }
    out
}

private func tls13DerReadElement(der: Array<Byte>, offset: Int64, label: String): (Int64, Array<Byte>, Int64) {
    if (offset < 0 || offset >= der.size) {
        throw CryptoException(ParseError, "${label} is truncated")
    }
    let tag = Int64(UInt8(der[offset]))
    let (length, lengthBytes) = tls13DerDecodeLength(der, offset + 1, label)
    let valueOffset = offset + 1 + lengthBytes
    if (valueOffset + length > der.size) {
        throw CryptoException(ParseError, "${label} value is truncated")
    }
    let value = der[valueOffset..(valueOffset + length)]
    let consumed = 1 + lengthBytes + length
    (tag, value, consumed)
}

private func tls13DerDecodeLength(der: Array<Byte>, offset: Int64, label: String): (Int64, Int64) {
    if (offset < 0 || offset >= der.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }
    let first = Int64(UInt8(der[offset]))
    if ((first & 0x80) == 0) {
        return (first, 1)
    }

    let width = first & 0x7f
    if (width == 0) {
        throw CryptoException(ParseError, "${label} DER length uses indefinite form")
    }
    if (width > 4) {
        throw CryptoException(ParseError, "${label} DER length width is too large")
    }
    if (offset + 1 + width > der.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    var length: Int64 = 0
    var i = 0
    while (i < width) {
        length = (length << 8) | Int64(UInt8(der[offset + 1 + i]))
        i += 1
    }
    if (length < 128) {
        throw CryptoException(ParseError, "${label} DER length uses non-minimal long form")
    }
    (length, 1 + width)
}

private func tls13CertificateVerifyConcat(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    var i = 0
    while (i < left.size) {
        out[i] = left[i]
        i += 1
    }
    i = 0
    while (i < right.size) {
        out[left.size + i] = right[i]
        i += 1
    }
    out
}
