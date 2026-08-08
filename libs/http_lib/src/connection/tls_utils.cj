package http_lib.connection
/**
 * TLS 工具函数：证书加载、私钥加载、指纹计算。
 * 从 PEM 格式文件加载 X.509 证书链和 PKCS#8 私钥。
 */

import jinguissl.contract.{contractHmac, HashAlgorithm}

/**
 * TLS 1.2 共享工具函数。
 * 集中管理 PRF 和字节数组拼接辅助函数 used by
 * TlsConnection（客户端）和 TlsServerConnection（服务器）的共享工具。
 */

/**
 * 拼接两个字节数组.
 */
public func concatByteArrays(a: Array<UInt8>, b: Array<UInt8>): Array<Byte> {
    a.concat(b)
}

/**
 * 拼接三个字节数组.
 */
public func concatThree(a: Array<UInt8>, b: Array<UInt8>, c: Array<UInt8>): Array<Byte> {
    let total = a.size + b.size + c.size
    let result = Array<UInt8>(total, repeat: 0)
    var offset: Int64 = 0
    if (a.size > 0) {
        a.copyTo(result, 0, offset, a.size)
        offset += a.size
    }
    if (b.size > 0) {
        b.copyTo(result, 0, offset, b.size)
        offset += b.size
    }
    if (c.size > 0) {
        c.copyTo(result, 0, offset, c.size)
    }
    result
}

/**
 * 拼接五个字节数组.
 */
public func concatFive(
    a: Array<UInt8>,
    b: Array<UInt8>,
    c: Array<UInt8>,
    d: Array<UInt8>,
    e: Array<UInt8>
): Array<Byte> {
    let total = a.size + b.size + c.size + d.size + e.size
    let result = Array<UInt8>(total, repeat: 0)
    var offset: Int64 = 0
    if (a.size > 0) {
        a.copyTo(result, 0, offset, a.size)
        offset += a.size
    }
    if (b.size > 0) {
        b.copyTo(result, 0, offset, b.size)
        offset += b.size
    }
    if (c.size > 0) {
        c.copyTo(result, 0, offset, c.size)
        offset += c.size
    }
    if (d.size > 0) {
        d.copyTo(result, 0, offset, d.size)
        offset += d.size
    }
    if (e.size > 0) {
        e.copyTo(result, 0, offset, e.size)
    }
    result
}

/**
 * TLS 1.2 连接。
 * 实现基于 P_SHA-256 的密钥派生函数。
 */
public func tls12PrfSha256(
    secret: Array<Byte>,
    label: String,
    seed: Array<Byte>,
    outputLen: Int64
): Array<Byte> {
    if (secret.size == 0) {
        throw TlsException("TLS12 PRF secret must not be empty")
    }
    if (outputLen < 0) {
        throw TlsException("TLS12 PRF output length must be >= 0")
    }
    if (outputLen == 0) {
        return []
    }

    let labelSeed = concatByteArrays(unsafe { label.rawData() }, seed)
    pHashSha256(secret, labelSeed, outputLen)
}

/**
 * P_SHA-256 扩展函数（RFC 5246 Section 5）。
 * 迭代 HMAC-SHA256 以生成请求的输出长度。
 */
public func pHashSha256(
    secret: Array<Byte>,
    seed: Array<Byte>,
    outputLen: Int64
): Array<Byte> {
    let out = Array<UInt8>(outputLen, repeat: 0)
    var a = seed.clone()
    var blockInput: Array<Byte> = []
    var offset: Int64 = 0
    while (offset < outputLen) {
        a = contractHmac(HashAlgorithm.SHA256, secret, a)
        let blockInputLen = a.size + seed.size
        if (blockInput.size != blockInputLen) {
            blockInput = Array<Byte>(blockInputLen, repeat: 0)
        }
        if (a.size > 0) {
            a.copyTo(blockInput, 0, 0, a.size)
        }
        if (seed.size > 0) {
            seed.copyTo(blockInput, 0, a.size, seed.size)
        }
        let block = contractHmac(HashAlgorithm.SHA256, secret, blockInput)
        let remain = outputLen - offset
        let take = if (remain < block.size) {
            remain
        } else {
            block.size
        }
        if (take > 0) {
            block.copyTo(out, 0, offset, take)
        }
        offset += take
    }
    out
}
