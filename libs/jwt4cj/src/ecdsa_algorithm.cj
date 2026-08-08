/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

class ECDSAAlgorithm <: Algorithm {
    private let keyProvider: ECDSAKeyProvider<ECDSAPublicKey, ECDSAPrivateKey>
    private let ecNumberSize: Int64

    init(id: String, algorithm: String, ecNumberSize: Int64,
        keyProvider: ECDSAKeyProvider<ECDSAPublicKey, ECDSAPrivateKey>) {
        super(id, algorithm)
        this.keyProvider = keyProvider
        this.ecNumberSize = ecNumberSize
    }

    public func verify(jwt: DecodedJWT): Unit {
        try {
            let content = buildContent(jwt.getHeader(), jwt.getPayload())
            let signature = Base64Util.urlDecode2Byte(jwt.getSignature())
            let valid = verify(content, signature)
            if (!valid) {
                throw SignatureVerificationException("SignatureVerificationException..")
            }
        } catch (e: Exception) {
            throw match (e) {
                case v: SignatureVerificationException => v
                case _ => SignatureVerificationException("SignatureVerificationException..")
            }
        }
    }

    func verify(content: Array<UInt8>, signature: Array<UInt8>): Bool {
        match (getDescription()) {
            case "SHA256withECDSA" => verify(content, signature, SHA256())
            case "SHA384withECDSA" => verify(content, signature, SHA384())
            case "SHA512withECDSA" => verify(content, signature, SHA512())
            case _ => false
        }
    }

    private func verify(
        content: Array<UInt8>,
        signature: Array<UInt8>,
        digestType: Digest
    ): Bool {
        try {
            let uchash = digest(digestType, content)
            return keyProvider.getPublicKey().verify(uchash, signature)
        } catch (_) {
            return false
        }
    }

    public func sign(content: Array<UInt8>): Array<UInt8> {
        try {
            match (getDescription()) {
                case "SHA256withECDSA" => sign(content, SHA256())
                case "SHA384withECDSA" => sign(content, SHA384())
                case "SHA512withECDSA" => sign(content, SHA512())
                case _ => return Array<UInt8>()
            }
        } catch (e: SignatureGenerationException) {
            throw SignatureGenerationException("SignatureGenerationException..")
        }
    }

    private func sign(content: Array<UInt8>, digestType: Digest): Array<UInt8> {
        let uchash = digest(digestType, content)
        keyProvider.getPrivateKey().sign(uchash)
    }
}
