/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

class RSAAlgorithm <: Algorithm {
    private let keyProvider: RSAKeyProvider<RSAPublicKey, RSAPrivateKey>

    init(id: String, algorithm: String, keyProvider: RSAKeyProvider<RSAPublicKey, RSAPrivateKey>) {
        super(id, algorithm)
        this.keyProvider = keyProvider
    }

    public func verify(jwt: DecodedJWT): Unit {
        try {
            let content = buildContent(jwt.getHeader(), jwt.getPayload())
            let signature: Array<UInt8> = Base64Util.urlDecode2Byte(jwt.getSignature())
            let valid: Bool = verify(content, signature)
            if (!valid) {
                throw SignatureVerificationException("exception func in verify")
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
            case "SHA256withRSA" => this.verify(content, signature, SHA256())
            case "SHA384withRSA" => this.verify(content, signature, SHA384())
            case "SHA512withRSA" => this.verify(content, signature, SHA512())
            case _ => false
        }
    }

    private func verify(content: Array<UInt8>, signature: Array<UInt8>, digestType: Digest): Bool {
        try {
            let uchash = digest(digestType, content)
            return keyProvider.getPublicKey().verify(digestType, uchash, signature, padType: keyProvider.padType)
        } catch (_) {
            return false
        }
    }

    public func sign(content: Array<UInt8>): Array<UInt8> {
        try {
            match (getDescription()) {
                case "SHA256withRSA" => this.sign(content, SHA256())
                case "SHA384withRSA" => this.sign(content, SHA384())
                case "SHA512withRSA" => this.sign(content, SHA512())
                case _ => Array<UInt8>()
            }
        } catch (_) {
            throw SignatureGenerationException("SignatureGenerationException..")
        }
    }

    private func sign(content: Array<UInt8>, digestType: Digest): Array<UInt8> {
        let uchash = digest(digestType, content)
        keyProvider.getPrivateKey().sign(digestType, uchash, padType: keyProvider.padType)
    }
}
