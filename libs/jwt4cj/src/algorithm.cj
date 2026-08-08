/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public abstract class Algorithm {
    private var name: String
    private var description: String

    protected init(name: String, description: String) {
        this.name = name
        this.description = description
    }

    public static func RSA256(keyProvider: RSAKeyProvider<RSAPublicKey, RSAPrivateKey>): Algorithm {
        return RSAAlgorithm("RS256", "SHA256withRSA", keyProvider)
    }

    public static func RSA384(keyProvider: RSAKeyProvider<RSAPublicKey, RSAPrivateKey>): Algorithm {
        return RSAAlgorithm("RS384", "SHA384withRSA", keyProvider)
    }

    public static func RSA512(keyProvider: RSAKeyProvider<RSAPublicKey, RSAPrivateKey>): Algorithm {
        return RSAAlgorithm("RS512", "SHA512withRSA", keyProvider)
    }

    public static func HMAC256(secret: String): Algorithm {
        return HMACAlgorithm("HS256", "HmacSHA256", secret)
    }

    public static func HMAC256(secret: Array<UInt8>): Algorithm {
        return HMACAlgorithm("HS256", "HmacSHA256", secret)
    }

    public static func HMAC384(secret: String): Algorithm {
        return HMACAlgorithm("HS384", "HmacSHA384", secret)
    }

    public static func HMAC384(secret: Array<UInt8>): Algorithm {
        return HMACAlgorithm("HS384", "HmacSHA384", secret)
    }

    public static func HMAC512(secret: String): Algorithm {
        return HMACAlgorithm("HS512", "HmacSHA512", secret)
    }

    public static func HMAC512(secret: Array<UInt8>): Algorithm {
        return HMACAlgorithm("HS512", "HmacSHA512", secret)
    }

    public static func ECDSA256(keyProvider: ECDSAKeyProvider<ECDSAPublicKey, ECDSAPrivateKey>): Algorithm {
        return ECDSAAlgorithm("ES256", "SHA256withECDSA", 32, keyProvider)
    }

    public static func ECDSA384(keyProvider: ECDSAKeyProvider<ECDSAPublicKey, ECDSAPrivateKey>): Algorithm {
        return ECDSAAlgorithm("ES384", "SHA384withECDSA", 32, keyProvider)
    }

    public static func ECDSA512(keyProvider: ECDSAKeyProvider<ECDSAPublicKey, ECDSAPrivateKey>): Algorithm {
        return ECDSAAlgorithm("ES512", "SHA512withECDSA", 32, keyProvider)
    }

    func getDescription(): String {
        return description
    }

    public static func none(): Algorithm {
        return NoneAlgorithm()
    }

    public open func getSigningKeyId(): String {
        return ""
    }

    public func getName(): String {
        return name
    }

    public func toString(): String {
        return description
    }

    public func verify(jwt: DecodedJWT): Unit

    public open func sign(headerBytes: Array<UInt8>, payloadBytes: Array<UInt8>): Array<UInt8> {
        return sign(buildContent(headerBytes, payloadBytes))
    }

    public func sign(contentBytes: Array<UInt8>): Array<UInt8>
}

func buildContent(header: String, payload: String): Array<UInt8> {
    "${header}.${payload}".toArray()
}

func buildContent(header: Array<UInt8>, payload: Array<UInt8>): Array<UInt8> {
    let content: Array<UInt8> = Array<UInt8>((header.size + payload.size + 1), repeat: 0)
    header.copyTo(content, 0, 0, header.size)
    content[header.size] = ".".toArray()[0]
    payload.copyTo(content, 0, (header.size + 1), payload.size)
    content
}
