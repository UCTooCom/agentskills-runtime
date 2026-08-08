package http_lib.connection
/**
 * 安全随机数生成。使用系统密码学安全随机源生成随机字节。
 * 用于 TLS、HTTP/2 帧构建和 WebSocket 握手。
 *
 * 跨平台实现：使用 jinguissl_core 的 csprngBytes（支持 Linux/Mac/Windows）。
 */

import jinguissl_core.crypto.utils.{csprngBytes}

/**
 * 生成 n 个密码学安全的随机字节。
 * 使用 jinguissl_core 的 csprngBytes（跨平台 CSPRNG）。
 *
 * 注意：std.random.Random 不具备密码学安全性（它使用
 * 通用 PRNG（如梅森旋转）。请勿用于密钥材料。
 * 用于 TLS ECDHE 密钥交换、HTTP/2 流 ID 生成和安全令牌等场景。
 */
public func secureRandom(n: Int64): Array<UInt8> {
    if (n <= 0) {
        return []
    }
    let bytes = csprngBytes(n)
    let out = Array<UInt8>(n, repeat: 0)
    for (i in 0..n) {
        out[i] = UInt8(bytes[i])
    }
    out
}

/**
 * 生成 32 字节密码学安全随机数（用于 ECDHE 密钥）。
 * 使用 jinguissl_core 的 csprngBytes（跨平台 CSPRNG）。
 *
 * 注意：std.random.Random 不具备密码学安全性（它使用
 * 通用 PRNG（如梅森旋转）。请勿用于密钥材料。
 */
public func secureRandom32(): Array<UInt8> {
    secureRandom(32)
}
