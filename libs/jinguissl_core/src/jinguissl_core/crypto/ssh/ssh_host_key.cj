package jinguissl_core.crypto.ssh

import std.collection.ArrayList
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.digest.{sha1, sha256, sha384, sha512}
import jinguissl_core.crypto.ed25519.{ed25519PublicKeyFromSeed, ed25519Sign, ed25519Verify, ED25519_PUBLIC_KEY_LEN, ED25519_SIGNATURE_LEN}
import jinguissl_core.crypto.ecc.{NamedCurve, EcPublicKey, EcPrivateKey, ecdsaSign, ecdsaVerify}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaHashAlgorithm, RsaPrivateKey, RsaPublicKey, rsaSignPkcs1v15WithHash, rsaVerifyPkcs1v15WithHash}
import jinguissl_core.crypto.utils.constantTimeEquals

private let SSH_P256_FIELD_LEN: Int64 = 32
private let SSH_P384_FIELD_LEN: Int64 = 48

/**
 * sshComputeHostKeySha256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshComputeHostKeySha256(serverHostKey: Array<Byte>): Array<Byte> {
    if (serverHostKey.size == 0) {
        throw CryptoException(InvalidArgument, "SSH host key blob must not be empty")
    }
    sha256(serverHostKey)
}

/**
 * sshRequireVerifiedHostIdentity.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshRequireVerifiedHostIdentity(
    kexResult: SshX25519KexResult,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHostVerificationResult {
    let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(kexResult.serverHostKey)
    let hostSignatureAlgorithm = sshExtractHostSignatureAlgorithm(kexResult.hostSignature)
    let hostKeySha256 = sshComputeHostKeySha256(kexResult.serverHostKey)

    if (policy.expectedHostKeySha256.size != 0) {
        if (!constantTimeEquals(policy.expectedHostKeySha256, hostKeySha256)) {
            if (policy.requireKnownHost) {
                throw CryptoException(ParseError, "SSH known-host fingerprint verification failed")
            }
        }
    }

    var signatureVerified = false
    if (policy.requireHostSignature) {
        signatureVerified = sshVerifyServerHostSignatureFromKexResult(
            kexResult,
            negotiatedHostKeyAlgorithm: policy.negotiatedHostKeyAlgorithm,
            allowLegacyRsaSha1: policy.allowLegacyRsaSha1
        )
        if (!signatureVerified) {
            throw CryptoException(ParseError, "SSH server host signature verification failed")
        }
    }

    SshHostVerificationResult(
        hostKeyAlgorithm,
        hostSignatureAlgorithm,
        hostKeySha256,
        signatureVerified
    )
}

/**
 * sshVerifyHostIdentityWithRequirement.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshVerifyHostIdentityWithRequirement(
    kexResult: SshX25519KexResult,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
    requireVerifiedHost!: Bool = true
): ?SshHostVerificationResult {
    if (requireVerifiedHost) {
        return Some(sshRequireVerifiedHostIdentity(kexResult, policy: policy))
    }

    try {
        return Some(sshRequireVerifiedHostIdentity(kexResult, policy: policy))
    } catch (e: CryptoException) {
        if (e.code == ParseError || e.code == Unsupported) {
            return None
        }
        throw e
    }
}

public func sshVerifyHostIdentityWithConfig(
    kexResult: SshX25519KexResult,
    config!: SshHostVerificationConfig = SshHostVerificationConfig()
): ?SshHostVerificationResult {
    sshVerifyHostIdentityWithRequirement(
        kexResult,
        policy: config.policy,
        requireVerifiedHost: config.requireVerifiedHost
    )
}

public func sshHostVerificationConfigRequired(
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHostVerificationConfig {
    SshHostVerificationConfig(policy: policy, requireVerifiedHost: true)
}

public func sshHostVerificationConfigOptional(
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHostVerificationConfig {
    SshHostVerificationConfig(policy: policy, requireVerifiedHost: false)
}

public func sshVerifyServerHostSignatureFromKexResult(
    kexResult: SshX25519KexResult,
    negotiatedHostKeyAlgorithm!: String = "",
    allowLegacyRsaSha1!: Bool = false
): Bool {
    sshVerifyServerHostSignature(
        kexResult.exchangeHash,
        kexResult.serverHostKey,
        kexResult.hostSignature,
        negotiatedHostKeyAlgorithm: negotiatedHostKeyAlgorithm,
        allowLegacyRsaSha1: allowLegacyRsaSha1
    )
}

public func sshExtractHostKeyAlgorithm(serverHostKey: Array<Byte>): String {
    sshDecodeHostKeyAlgorithm(serverHostKey)
}

public func sshExtractHostSignatureAlgorithm(hostSignature: Array<Byte>): String {
    let (algorithm, _) = sshDecodeHostSignature(hostSignature)
    algorithm
}

public func sshEncodeRsaHostPublicKey(publicKey: RsaPublicKey): Array<Byte> {
    let out = ArrayList<Byte>()
    sshHostAppendString(out, SSH_HOST_KEY_ALGORITHM_RSA.toArray())
    sshHostAppendString(out, sshEncodePositiveMpint(publicKey.exponent.toBytesBE()))
    sshHostAppendString(out, sshEncodePositiveMpint(publicKey.modulus.toBytesBE()))
    out.toArray()
}

/**
 * sshEncodeRsaHostSignature.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeRsaHostSignature(signatureAlgorithm: String, signature: Array<Byte>): Array<Byte> {
    let normalized = sshNormalizeRsaHostSignatureAlgorithm(signatureAlgorithm)
    if (signature.size == 0) {
        throw CryptoException(InvalidArgument, "SSH RSA host signature must not be empty")
    }

    let out = ArrayList<Byte>()
    sshHostAppendString(out, normalized.toArray())
    sshHostAppendString(out, signature)
    out.toArray()
}

/**
 * sshSignExchangeHashRsa.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshSignExchangeHashRsa(
    privateKey: RsaPrivateKey,
    exchangeHash: Array<Byte>,
    signatureAlgorithm!: String = SSH_HOST_KEY_ALGORITHM_RSA_SHA256
): Array<Byte> {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }

    let normalized = sshNormalizeRsaHostSignatureAlgorithm(signatureAlgorithm)
    let digest = if (normalized == SSH_HOST_KEY_ALGORITHM_RSA) {
        sha1(exchangeHash)
    } else if (normalized == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        sha256(exchangeHash)
    } else {
        sha512(exchangeHash)
    }
    let hashAlgorithm = if (normalized == SSH_HOST_KEY_ALGORITHM_RSA) {
        RsaHashAlgorithm.SHA1
    } else if (normalized == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        RsaHashAlgorithm.SHA256
    } else {
        RsaHashAlgorithm.SHA512
    }
    sshEncodeRsaHostSignature(normalized, rsaSignPkcs1v15WithHash(privateKey, digest, hashAlgorithm))
}

public func sshEncodeEcdsaHostPublicKey(publicKey: EcPublicKey): Array<Byte> {
    let (algorithm, curveName, fieldLen) = sshEcdsaCurveEncoding(publicKey.curve)
    let encodedPoint = sshEncodeEcdsaUncompressedPoint(publicKey, fieldLen)
    let out = ArrayList<Byte>()
    sshHostAppendString(out, algorithm.toArray())
    sshHostAppendString(out, curveName.toArray())
    sshHostAppendString(out, encodedPoint)
    out.toArray()
}

public func sshEncodeEcdsaHostSignature(curve: NamedCurve, r: BigNum, s: BigNum): Array<Byte> {
    let (algorithm, _curveName, _fieldLen) = sshEcdsaCurveEncoding(curve)
    let signaturePair = ArrayList<Byte>()
    sshHostAppendString(signaturePair, sshEncodePositiveMpint(r.toBytesBE()))
    sshHostAppendString(signaturePair, sshEncodePositiveMpint(s.toBytesBE()))

    let out = ArrayList<Byte>()
    sshHostAppendString(out, algorithm.toArray())
    sshHostAppendString(out, signaturePair.toArray())
    out.toArray()
}

/**
 * sshSignExchangeHashEcdsa.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshSignExchangeHashEcdsa(privateKey: EcPrivateKey, exchangeHash: Array<Byte>): Array<Byte> {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }

    let digest = match (privateKey.curve) {
        case NamedCurve.P256 => sha256(exchangeHash)
        case NamedCurve.P384 => sha384(exchangeHash)
        case _ =>
            throw CryptoException(Unsupported, "SSH ECDSA host signature curve is unsupported: ${privateKey.curve.toString()}")
    }
    let (r, s) = ecdsaSign(privateKey, digest)
    sshEncodeEcdsaHostSignature(privateKey.curve, r, s)
}

/**
 * sshEncodeEd25519HostPublicKey.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeEd25519HostPublicKey(publicKey: Array<Byte>): Array<Byte> {
    if (publicKey.size != ED25519_PUBLIC_KEY_LEN) {
        throw CryptoException(InvalidArgument, "SSH ed25519 host public key must be 32 bytes")
    }

    let out = ArrayList<Byte>()
    sshHostAppendString(out, SSH_HOST_KEY_ALGORITHM_ED25519.toArray())
    sshHostAppendString(out, publicKey)
    out.toArray()
}

public func sshBuildEd25519HostKeyBlobFromSeed(privateKeySeed: Array<Byte>): Array<Byte> {
    sshEncodeEd25519HostPublicKey(ed25519PublicKeyFromSeed(privateKeySeed))
}

/**
 * sshEncodeEd25519HostSignature.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeEd25519HostSignature(signature: Array<Byte>): Array<Byte> {
    if (signature.size != ED25519_SIGNATURE_LEN) {
        throw CryptoException(InvalidArgument, "SSH ed25519 host signature must be 64 bytes")
    }

    let out = ArrayList<Byte>()
    sshHostAppendString(out, SSH_HOST_KEY_ALGORITHM_ED25519.toArray())
    sshHostAppendString(out, signature)
    out.toArray()
}

/**
 * sshSignExchangeHashEd25519.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshSignExchangeHashEd25519(privateKeySeed: Array<Byte>, exchangeHash: Array<Byte>): Array<Byte> {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }
    sshEncodeEd25519HostSignature(ed25519Sign(privateKeySeed, exchangeHash))
}

/**
 * sshVerifyServerHostSignature.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshVerifyServerHostSignature(
    exchangeHash: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    negotiatedHostKeyAlgorithm!: String = "",
    allowLegacyRsaSha1!: Bool = false
): Bool {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }

    let hostAlgorithm = sshDecodeHostKeyAlgorithm(serverHostKey)
    let (signatureAlgorithm, signatureData) = sshDecodeHostSignature(hostSignature)
    let negotiated = negotiatedHostKeyAlgorithm.trimAscii().toAsciiLower()
    if (
        negotiated.size != 0 &&
        !sshSignatureMatchesNegotiatedHostKey(negotiated, hostAlgorithm, signatureAlgorithm)
    ) {
        return false
    }

    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
            return false
        }
        let publicKey = sshDecodeRsaHostPublicKey(serverHostKey)
        let digest = sha256(exchangeHash)
        return rsaVerifyPkcs1v15WithHash(publicKey, digest, signatureData, RsaHashAlgorithm.SHA256)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA512) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
            return false
        }
        let publicKey = sshDecodeRsaHostPublicKey(serverHostKey)
        let digest = sha512(exchangeHash)
        return rsaVerifyPkcs1v15WithHash(publicKey, digest, signatureData, RsaHashAlgorithm.SHA512)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256) {
            return false
        }
        let publicKey = sshDecodeEcdsaP256HostPublicKey(serverHostKey)
        let (r, s) = sshDecodeEcdsaSignature(signatureData)
        let digest = sha256(exchangeHash)
        return ecdsaVerify(publicKey, digest, r, s)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384) {
            return false
        }
        let publicKey = sshDecodeEcdsaP384HostPublicKey(serverHostKey)
        let (r, s) = sshDecodeEcdsaSignature(signatureData)
        let digest = sha384(exchangeHash)
        return ecdsaVerify(publicKey, digest, r, s)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_ED25519) {
            return false
        }
        let publicKey = sshDecodeEd25519HostPublicKey(serverHostKey)
        let signature = sshDecodeEd25519HostSignature(signatureData)
        return ed25519Verify(publicKey, exchangeHash, signature)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
            return false
        }
        if (!allowLegacyRsaSha1) {
            throw CryptoException(Unsupported, "SSH rsa-sha1 host signature verify is blocked")
        }
        let publicKey = sshDecodeRsaHostPublicKey(serverHostKey)
        let digest = sha1(exchangeHash)
        return rsaVerifyPkcs1v15WithHash(publicKey, digest, signatureData, RsaHashAlgorithm.SHA1)
    }
    throw CryptoException(Unsupported, "SSH host signature algorithm is unsupported: ${signatureAlgorithm}")
}

private func sshDecodeHostKeyAlgorithm(serverHostKey: Array<Byte>): String {
    let (algorithmBytes, _) = sshHostDecodeString(serverHostKey, 0, "host key algorithm")
    sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
}

private func sshDecodeHostSignature(hostSignature: Array<Byte>): (String, Array<Byte>) {
    let (algorithmBytes, offset) = sshHostDecodeString(hostSignature, 0, "host signature algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host signature algorithm")
    let (signatureData, nextOffset) = sshHostDecodeString(hostSignature, offset, "host signature data")
    if (nextOffset != hostSignature.size) {
        throw CryptoException(ParseError, "SSH host signature blob has trailing bytes")
    }
    (algorithm, signatureData)
}

private func sshDecodeRsaHostPublicKey(serverHostKey: Array<Byte>): RsaPublicKey {
    let (algorithmBytes, offset) = sshHostDecodeString(serverHostKey, 0, "host key algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
    if (algorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
        throw CryptoException(ParseError, "SSH RSA host key blob algorithm mismatch: ${algorithm}")
    }

    let (exponentBytes, exponentOffset) = sshDecodePositiveMpint(serverHostKey, offset, "host key exponent")
    let (modulusBytes, nextOffset) = sshDecodePositiveMpint(serverHostKey, exponentOffset, "host key modulus")
    if (nextOffset != serverHostKey.size) {
        throw CryptoException(ParseError, "SSH RSA host key blob has trailing bytes")
    }
    if (exponentBytes.size == 0 || modulusBytes.size == 0) {
        throw CryptoException(ParseError, "SSH RSA host key requires non-zero modulus/exponent")
    }

    let exponent = sshUnsignedBigNumFromBytes(exponentBytes)
    let modulus = sshUnsignedBigNumFromBytes(modulusBytes)
    RsaPublicKey(modulus, exponent)
}

private func sshDecodeEcdsaP256HostPublicKey(serverHostKey: Array<Byte>): EcPublicKey {
    sshDecodeEcdsaHostPublicKey(
        serverHostKey,
        SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256,
        "nistp256",
        P256,
        SSH_P256_FIELD_LEN
    )
}

private func sshDecodeEcdsaP384HostPublicKey(serverHostKey: Array<Byte>): EcPublicKey {
    sshDecodeEcdsaHostPublicKey(
        serverHostKey,
        SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384,
        "nistp384",
        P384,
        SSH_P384_FIELD_LEN
    )
}

private func sshDecodeEcdsaHostPublicKey(
    serverHostKey: Array<Byte>,
    expectedAlgorithm: String,
    expectedCurveName: String,
    curve: NamedCurve,
    fieldLen: Int64
): EcPublicKey {
    let (algorithmBytes, offset) = sshHostDecodeString(serverHostKey, 0, "host key algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
    if (algorithm != expectedAlgorithm) {
        throw CryptoException(ParseError, "SSH ECDSA host key blob algorithm mismatch: ${algorithm}")
    }

    let (curveNameBytes, curveOffset) = sshHostDecodeString(serverHostKey, offset, "host key curve name")
    let curveName = sshDecodeAlgorithmToken(curveNameBytes, "host key curve name")
    if (curveName != expectedCurveName) {
        throw CryptoException(Unsupported, "SSH ECDSA host key curve is unsupported: ${curveName}")
    }

    let (encodedPoint, nextOffset) = sshHostDecodeString(serverHostKey, curveOffset, "host key EC point")
    if (nextOffset != serverHostKey.size) {
        throw CryptoException(ParseError, "SSH ECDSA host key blob has trailing bytes")
    }
    if (encodedPoint.size != 1 + fieldLen * 2 || UInt8(encodedPoint[0]) != UInt8(0x04)) {
        throw CryptoException(ParseError, "SSH ECDSA host key point must be uncompressed")
    }

    let x = BigNum.fromBytesBE(encodedPoint[1..(1 + fieldLen)])
    let y = BigNum.fromBytesBE(encodedPoint[(1 + fieldLen)..])
    EcPublicKey(curve, x, y)
}

private func sshDecodeEd25519HostPublicKey(serverHostKey: Array<Byte>): Array<Byte> {
    let (algorithmBytes, offset) = sshHostDecodeString(serverHostKey, 0, "host key algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
    if (algorithm != SSH_HOST_KEY_ALGORITHM_ED25519) {
        throw CryptoException(ParseError, "SSH ed25519 host key blob algorithm mismatch: ${algorithm}")
    }
    let (publicKey, nextOffset) = sshHostDecodeString(serverHostKey, offset, "host key ed25519 public key")
    if (nextOffset != serverHostKey.size) {
        throw CryptoException(ParseError, "SSH ed25519 host key blob has trailing bytes")
    }
    if (publicKey.size != 32) {
        throw CryptoException(ParseError, "SSH ed25519 host key public key must be 32 bytes")
    }
    publicKey
}

private func sshDecodeEd25519HostSignature(signatureData: Array<Byte>): Array<Byte> {
    if (signatureData.size != 64) {
        throw CryptoException(ParseError, "SSH ed25519 host signature must be 64 bytes")
    }
    signatureData
}

private func sshDecodeEcdsaSignature(signatureData: Array<Byte>): (BigNum, BigNum) {
    let (rBytes, offset) = sshDecodePositiveMpint(signatureData, 0, "host signature r")
    let (sBytes, nextOffset) = sshDecodePositiveMpint(signatureData, offset, "host signature s")
    if (nextOffset != signatureData.size) {
        throw CryptoException(ParseError, "SSH ECDSA signature has trailing bytes")
    }
    (sshUnsignedBigNumFromBytes(rBytes), sshUnsignedBigNumFromBytes(sBytes))
}

private func sshDecodePositiveMpint(encoded: Array<Byte>, offset: Int64, label: String): (Array<Byte>, Int64) {
    let (rawValue, nextOffset) = sshHostDecodeString(encoded, offset, label)
    if (rawValue.size == 0) {
        return ([], nextOffset)
    }
    if ((UInt8(rawValue[0]) & UInt8(0x80)) != UInt8(0x00)) {
        throw CryptoException(ParseError, "SSH ${label} must be non-negative mpint")
    }

    var start = 0
    while (
        start + 1 < rawValue.size &&
        UInt8(rawValue[start]) == UInt8(0x00) &&
        (UInt8(rawValue[start + 1]) & UInt8(0x80)) == UInt8(0x00)
    ) {
        start += 1
    }
    (rawValue[start..], nextOffset)
}

private func sshUnsignedBigNumFromBytes(data: Array<Byte>): BigNum {
    if (data.size == 0) {
        return BigNum.zero()
    }
    BigNum.fromBytesBE(data)
}

private func sshEncodePositiveMpint(unsigned: Array<Byte>): Array<Byte> {
    if (unsigned.size == 0) {
        return []
    }

    var start = 0
    while (start + 1 < unsigned.size && UInt8(unsigned[start]) == UInt8(0x00)) {
        start += 1
    }
    let trimmed = unsigned[start..]
    if (trimmed.size == 0) {
        return []
    }
    if ((UInt8(trimmed[0]) & UInt8(0x80)) != UInt8(0x00)) {
        let out = Array<Byte>(trimmed.size + 1, repeat: 0)
        var i = 0
        while (i < trimmed.size) {
            out[i + 1] = trimmed[i]
            i += 1
        }
        return out
    }
    trimmed
}

private func sshDecodeAlgorithmToken(raw: Array<Byte>, label: String): String {
    let token = String.fromUtf8(raw).trimAscii().toAsciiLower()
    if (token.size == 0) {
        throw CryptoException(ParseError, "SSH ${label} must not be empty")
    }
    if (token.contains(" ") || token.contains("\r") || token.contains("\n") || token.contains("\t")) {
        throw CryptoException(ParseError, "SSH ${label} contains invalid whitespace")
    }
    token
}

private func sshSignatureMatchesNegotiatedHostKey(
    negotiatedHostKeyAlgorithm: String,
    hostAlgorithm: String,
    signatureAlgorithm: String
): Bool {
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA512) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA512
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256 &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384 &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519 &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519
    }
    hostAlgorithm == negotiatedHostKeyAlgorithm &&
        signatureAlgorithm == negotiatedHostKeyAlgorithm
}

private func sshNormalizeRsaHostSignatureAlgorithm(signatureAlgorithm: String): String {
    let normalized = signatureAlgorithm.trimAscii().toAsciiLower()
    if (
        normalized != SSH_HOST_KEY_ALGORITHM_RSA &&
        normalized != SSH_HOST_KEY_ALGORITHM_RSA_SHA256 &&
        normalized != SSH_HOST_KEY_ALGORITHM_RSA_SHA512
    ) {
        throw CryptoException(Unsupported, "SSH RSA host signature algorithm is unsupported: ${signatureAlgorithm}")
    }
    normalized
}

private func sshEcdsaCurveEncoding(curve: NamedCurve): (String, String, Int64) {
    match (curve) {
        case NamedCurve.P256 => (SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256, "nistp256", SSH_P256_FIELD_LEN)
        case NamedCurve.P384 => (SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384, "nistp384", SSH_P384_FIELD_LEN)
        case _ =>
            throw CryptoException(Unsupported, "SSH ECDSA host key curve is unsupported: ${curve.toString()}")
    }
}

private func sshEncodeEcdsaUncompressedPoint(publicKey: EcPublicKey, fieldLen: Int64): Array<Byte> {
    let encodedPoint = Array<Byte>(1 + (fieldLen * 2), repeat: 0)
    encodedPoint[0] = UInt8(0x04)
    let x = publicKey.x.toBytesBE(paddedLen: fieldLen)
    let y = publicKey.y.toBytesBE(paddedLen: fieldLen)
    var i = 0
    while (i < fieldLen) {
        encodedPoint[1 + i] = x[i]
        encodedPoint[1 + fieldLen + i] = y[i]
        i += 1
    }
    encodedPoint
}

private func sshHostAppendString(out: ArrayList<Byte>, data: Array<Byte>): Unit {
    sshHostAppendUInt32(out, data.size)
    sshHostAppendBytes(out, data)
}

private func sshHostDecodeString(
    encoded: Array<Byte>,
    offset: Int64,
    label: String
): (Array<Byte>, Int64) {
    let stringLen = sshHostDecodeUInt32(encoded, offset, label)
    let cursor = offset + 4
    if (cursor + stringLen > encoded.size) {
        throw CryptoException(ParseError, "SSH ${label} exceeds packet bounds")
    }
    (encoded[cursor..(cursor + stringLen)], cursor + stringLen)
}

private func sshHostAppendBytes(out: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    var i = 0
    while (i < bytes.size) {
        out.add(bytes[i])
        i += 1
    }
}

private func sshHostAppendUInt32(out: ArrayList<Byte>, value: Int64): Unit {
    if (value < 0 || value > 0xffff_ffff) {
        throw CryptoException(OutOfBounds, "SSH uint32 value is out of range")
    }
    out.add(UInt8((value >> 24) & 0xff))
    out.add(UInt8((value >> 16) & 0xff))
    out.add(UInt8((value >> 8) & 0xff))
    out.add(UInt8(value & 0xff))
}

private func sshHostDecodeUInt32(encoded: Array<Byte>, offset: Int64, label: String): Int64 {
    if (offset < 0 || offset + 4 > encoded.size) {
        throw CryptoException(ParseError, "SSH ${label} uint32 read out of bounds")
    }
    (Int64(UInt8(encoded[offset])) << 24) |
    (Int64(UInt8(encoded[offset + 1])) << 16) |
    (Int64(UInt8(encoded[offset + 2])) << 8) |
    Int64(UInt8(encoded[offset + 3]))
}
