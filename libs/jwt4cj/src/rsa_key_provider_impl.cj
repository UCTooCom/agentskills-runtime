/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class RSAKeyProviderFileImpl <: RSAKeyProvider<RSAPublicKey, RSAPrivateKey> {
    private var rsaPublicKey: ?RSAPublicKey
    private var rsaPrivateKey: ?RSAPrivateKey
    private var padding: PadOption = PKCS1
    public mut prop padType: PadOption {
        get() {
            this.padding
        }
        set(value) {
            this.padding = value
        }
    }

    public init(filePath: String) {
        this(filePath, filePath, None)
    }

    public init(privateKeyFile: ?String, publicKeyFile: ?String) {
        this(privateKeyFile, publicKeyFile, None)
    }

    public init(privateKeyFile: ?String, publicKeyFile: ?String, pwd: ?String) {
        this.rsaPublicKey = try {
            let textpub = String.fromUtf8(File.readFrom(publicKeyFile.getOrThrow()))
            RSAPublicKey.decodeFromPem(textpub)
        } catch (_) {
            None
        }
        this.rsaPrivateKey = try {
            let textpri = String.fromUtf8(File.readFrom(privateKeyFile.getOrThrow()))
            RSAPrivateKey.decodeFromPem(textpri, password: pwd)
        } catch (_) {
            None
        }
    }

    public func getPublicKey(): RSAPublicKey {
        rsaPublicKey.getOrThrow()
    }

    public func getPrivateKey(): RSAPrivateKey {
        rsaPrivateKey.getOrThrow()
    }
}

public class RSAKeyProviderImpl <: RSAKeyProvider<RSAPublicKey, RSAPrivateKey> {
    private var rsaPublicKey: ?RSAPublicKey
    private var rsaPrivateKey: ?RSAPrivateKey

    public init(privateKey: ?RSAPrivateKey, publicKey: ?RSAPublicKey) {
        this.rsaPublicKey = publicKey
        this.rsaPrivateKey = privateKey
    }
    public func getPublicKey(): RSAPublicKey {
        rsaPublicKey.getOrThrow()
    }
    public func getPrivateKey(): RSAPrivateKey {
        rsaPrivateKey.getOrThrow()
    }
}
