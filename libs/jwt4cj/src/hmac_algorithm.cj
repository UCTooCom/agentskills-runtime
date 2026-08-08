/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class HMACAlgorithm <: Algorithm {
    private var secret: Array<UInt8>

    init(id: String, algorithm: String, secretBytes: Array<UInt8>) {
        super(id, algorithm)
        secret = secretBytes
    }

    init(id: String, algorithm: String, secret: String) {
        this(id, algorithm, getSecretBytes(secret))
    }

    static func getSecretBytes(secretStr: String): Array<UInt8> {
        return secretStr.toArray()
    }

    public func verify(jwt: DecodedJWT): Unit {
        try {
            var signatureBytes: Array<UInt8> = Base64Util.urlDecode2Byte(jwt.getSignature())
            var valid: Bool = verifySignatureFor(
                getDescription(),
                secret,
                jwt.getHeader(),
                jwt.getPayload(),
                signatureBytes
            )
            if (!valid) {
                throw SignatureVerificationException("HMAC exception")
            }
        } catch (e: IllegalArgumentException) {
            throw SignatureVerificationException("HMAC Algorithm exception")
        }
    }

    public func sign(headerBytes: Array<UInt8>, payloadBytes: Array<UInt8>): Array<UInt8> {
        try {
            return createSignatureFor(getDescription(), secret, headerBytes, payloadBytes)
        } catch (e: SignatureVerificationException) {
            throw SignatureVerificationException("sign fail")
        }
    }

    public func sign(contentBytes: Array<UInt8>): Array<UInt8> {
        try {
            return createSignatureFor(getDescription(), secret, contentBytes)
        } catch (e: SignatureVerificationException) {
            throw SignatureVerificationException("sign fail")
        }
    }

    func verifySignatureFor(
        algorithm: String,
        secretBytes: Array<UInt8>,
        header: String,
        payload: String,
        signatureBytes: Array<UInt8>
    ): Bool {
        return verifySignatureFor(algorithm, secretBytes, header.toArray(), payload.toArray(), signatureBytes)
    }

    func verifySignatureFor(
        algorithm: String,
        secretBytes: Array<UInt8>,
        headerBytes: Array<UInt8>,
        payloadBytes: Array<UInt8>,
        signatureBytes: Array<UInt8>
    ): Bool {
        return createSignatureFor(algorithm, secretBytes, headerBytes, payloadBytes) == signatureBytes
    }

    func createSignatureFor(
        algorithm: String,
        privateKey: Array<UInt8>,
        headerBytes: Array<UInt8>,
        payloadBytes: Array<UInt8>
    ): Array<UInt8> {
        var contentBytes: Array<UInt8> = Array<UInt8>((headerBytes.size + payloadBytes.size + 1), repeat: 0)
        headerBytes.copyTo(contentBytes, 0, 0, headerBytes.size)
        contentBytes[headerBytes.size] = ".".toArray()[0]
        payloadBytes.copyTo(contentBytes, 0, (headerBytes.size + 1), payloadBytes.size)
        var hmac: HMAC = match (algorithm) {
            case "HmacSHA256" => HMAC(privateKey, HashType.SHA256)
            case "HmacSHA384" => HMAC(privateKey, HashType.SHA384)
            case "HmacSHA512" => HMAC(privateKey, HashType.SHA512)
            case v => throw UnsupportedException(v)
        }
        hmac.write(contentBytes)
        let arr = hmac.finish()
        return arr
    }

    func createSignatureFor(algorithm: String, privateKey: Array<UInt8>, contentBytes: Array<UInt8>): Array<UInt8> {
        var hmac: HMAC = match (algorithm) {
            case "HmacSHA256" => HMAC(privateKey, HashType.SHA256)
            case "HmacSHA384" => HMAC(privateKey, HashType.SHA384)
            case "HmacSHA512" => HMAC(privateKey, HashType.SHA512)
            case v => throw UnsupportedException(v)
        }
        hmac.write(contentBytes)
        let arr = hmac.finish()
        return arr
    }
}
