/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto.PBKDF2

public class PBKDF2Parameters {

    // 盐
    protected var salt: Array<Byte>
    // 迭代次数
    protected var iterationCount: Int32
    // hash算法
    protected var hashAlgorithm: HashType
    // 散列字符集
    protected var hashCharset: String
    // 派生密钥
    protected var derivedKey: ?Array<Byte>

    public init(hashAlgorithm: HashType, hashCharset: String, salt: Array<Byte>, iterationCount: Int32) {
        this(hashAlgorithm, hashCharset, salt, iterationCount, None)
    }

    public init(
        hashAlgorithm: HashType,
        hashCharset: String,
        salt: Array<Byte>,
        iterationCount: Int32,
        derivedKey: ?Array<Byte>
    ) {
        this.hashAlgorithm = hashAlgorithm
        this.hashCharset = hashCharset
        this.salt = salt
        this.iterationCount = iterationCount
        this.derivedKey = derivedKey
    }

    public func getIterationCount(): Int32 {
        return iterationCount
    }

    public func setIterationCount(iterationCount: Int32) {
        this.iterationCount = iterationCount
    }

    public func getSalt(): Array<Byte> {
        return salt
    }

    public func setSalt(salt: Array<Byte>) {
        this.salt = salt
    }

    public func getDerivedKey(): ?Array<Byte> {
        return derivedKey
    }

    public func setDerivedKey(derivedKey: Array<Byte>) {
        this.derivedKey = derivedKey
    }

    public func getHashAlgorithm(): HashType {
        return hashAlgorithm
    }

    public func setHashAlgorithm(hashAlgorithm: HashType) {
        this.hashAlgorithm = hashAlgorithm
    }

    public func getHashCharset(): String {
        return hashCharset
    }

    public func setHashCharset(hashCharset: String) {
        this.hashCharset = hashCharset
    }
}
