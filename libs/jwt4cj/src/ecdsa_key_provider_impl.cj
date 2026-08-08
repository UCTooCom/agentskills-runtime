/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class ECDSAKeyProviderFileImpl <: ECDSAKeyProvider<ECDSAPublicKey, ECDSAPrivateKey> {
    private var ecPublicKey: ?ECDSAPublicKey
    private var ecPrivateKey: ?ECDSAPrivateKey

    public init(filePath: String) {
        this(filePath, filePath, None)
    }

    public init(privateKeyFile: ?String, publicKeyFile: ?String) {
        this(privateKeyFile, publicKeyFile, None)
    }

    public init(privateKeyFile: ?String, publicKeyFile: ?String, pwd: ?String) {
        this.ecPublicKey = try {
            let textpub = String.fromUtf8(File.readFrom(publicKeyFile.getOrThrow()))
            ECDSAPublicKey.decodeFromPem(textpub)
        } catch (_) {
            None
        }
        this.ecPrivateKey = try {
            let textpri = String.fromUtf8(File.readFrom(privateKeyFile.getOrThrow()))
            ECDSAPrivateKey.decodeFromPem(textpri, password: pwd)
        } catch (_) {
            None
        }
    }

    public func getPublicKey(): ECDSAPublicKey {
        return ecPublicKey.getOrThrow()
    }

    public func getPrivateKey(): ECDSAPrivateKey {
        return ecPrivateKey.getOrThrow()
    }
}

public class ECDSAKeyProviderImpl <: ECDSAKeyProvider<ECDSAPublicKey, ECDSAPrivateKey> {
    private var ecPublicKey: ?ECDSAPublicKey
    private var ecPrivateKey: ?ECDSAPrivateKey

    public init(privateKey: ?ECDSAPrivateKey, publicKey: ?ECDSAPublicKey) {
        this.ecPublicKey = publicKey
        this.ecPrivateKey = privateKey
    }
    public func getPublicKey(): ECDSAPublicKey {
        return ecPublicKey.getOrThrow()
    }
    public func getPrivateKey(): ECDSAPrivateKey {
        return ecPrivateKey.getOrThrow()
    }
}
