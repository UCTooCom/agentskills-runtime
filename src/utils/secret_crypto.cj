/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.utils

import std.collection.ArrayList
import std.env.getVariable
import stdx.encoding.base64.{toBase64String, fromBase64String}
import blowfish.Blowfish

/**
 * 大模型通道 api_key 可逆加密工具（SecretCrypto）
 *
 * 【禁止依赖 magic.log】本文件属于 `magic.utils`，而 `magic.log`（log_utils_impl.cj）
 * 反向依赖 `magic.utils.exists`、`magic.config` 又依赖 `magic.utils`——这里一旦 import
 * `magic.log.LogUtils` 就会形成 `utils → log → utils` / `config → utils → log → config`
 * 两条 **cyclic dependency**，cjpm build 直接失败。
 * 作为最底层工具包，`magic.utils` 只能依赖 std / stdx / 三方库；失败一律返回空串，
 * 由上层调用方（Controller / ChannelRegistry）负责打日志。
 * 参考：`utils/http` 目录下的 `http_*.cj` 之所以能 import magic.log，是因为它们
 * 声明的是独立的 `package magic.utils.http`（子包，不参与本包的依赖环）。
 * 【注意】仓颉块注释**支持嵌套**，注释正文里绝不能出现「斜杠紧跟星号」这类连写序列
 *        （上面那句踩的就是这个坑），否则会多开或早闭一层。
 *
 * 设计定位：
 * - `uctoo_user.password` 用 `blowfish.Bcrypt`（单向哈希，不可还原）——只能校验、不能还原明文。
 * - api_key 必须**可逆**（runtime 要把明文 key 发给 LLM 网关鉴权），故不能用 bcrypt。
 * - 同库 `blowfish-cj` 的 `Blowfish` 对称加密（blockSize=8）作可逆原语，外层自包 CBC + PKCS7，
 *   纯仓颉、无外部 DLL 依赖；密文以 base64 存 `llm_channel.api_key` 列。
 *
 * 主密钥：
 * - 来自 .env 的 `APP_ENC_KEY`（唯一保留的、非大模型通道的「信封主密钥」）。
 * - 缺失时回退到编译期常量（仅开发兜底，生产必须配置 APP_ENC_KEY）。
 *
 * IV：由主密钥派生（确定性）。对「静态落库密钥」而言 IV 泄露无额外风险，
 *     代价是相同明文→相同密文（api key 本身唯一，可接受）。
 */
public class SecretCrypto {
    // 主密钥缺失时的开发兜底（生产必须配置 APP_ENC_KEY）
    private static let FALLBACK_KEY: String = "uctoo-dev-enc-fallback-change-me"

    /**
     * 加密明文 api_key → base64 密文。空串原样返回空。
     */
    public static func encrypt(plain: String): String {
        if (plain.isEmpty()) {
            return ""
        }
        try {
            let key = masterKey()
            let bf = Blowfish(key)
            let iv = deriveIv(key)
            let padded = pkcs7Pad(plain.toArray())
            var prev = iv
            var cipher = ArrayList<Byte>()
            let blocks = padded.size / 8
            for (i in 0..blocks) {
                let block = blockAt(padded, i * 8)
                let xored = xorBlocks(block, prev)
                let enc = bf.encrypt(xored)
                for (b in enc) {
                    cipher.add(b)
                }
                prev = enc
            }
            return toBase64String(cipher.toArray())
        } catch (_: Exception) {
            // 加密失败一律返回空串（不落不可用的半截密文）；由调用方决定是否告警
            return ""
        }
    }

    /**
     * 解密 base64 密文 → 明文 api_key。空串原样返回空。
     */
    public static func decrypt(cipherB64: String): String {
        if (cipherB64.isEmpty()) {
            return ""
        }
        try {
            let key = masterKey()
            let bf = Blowfish(key)
            let iv = deriveIv(key)
            let rawOpt = fromBase64String(cipherB64)
            if (rawOpt.isNone()) {
                return ""
            }
            let raw = rawOpt.getOrThrow()
            if (raw.size == 0 || raw.size % 8 != 0) {
                return ""
            }
            var prev = iv
            var plain = ArrayList<Byte>()
            let blocks = raw.size / 8
            for (i in 0..blocks) {
                let block = blockAt(raw, i * 8)
                let dec = bf.decrypt(block)
                let xored = xorBlocks(dec, prev)
                for (b in xored) {
                    plain.add(b)
                }
                prev = block
            }
            let unpadded = pkcs7Unpad(plain.toArray())
            return String.fromUtf8(unpadded)
        } catch (_: Exception) {
            // 解密失败（主密钥变更 / 密文被篡改 / base64 非法）一律返回空串，
            // 等价于「该通道未配置密钥」，调用方按无密钥路径处理
            return ""
        }
    }

    // ==================== 内部实现 ====================

    private static func masterKey(): Array<Byte> {
        let raw = getVariable("APP_ENC_KEY") ?? FALLBACK_KEY
        var kb = raw.toArray()
        if (kb.size > 56) {
            var trimmed = ArrayList<Byte>()
            for (i in 0..56) {
                trimmed.add(kb[i])
            }
            kb = trimmed.toArray()
        }
        if (kb.size < 1) {
            kb = FALLBACK_KEY.toArray()
        }
        kb
    }

    // 由主密钥派生 8 字节 IV（确定性，CBC 全程复用）
    private static func deriveIv(key: Array<Byte>): Array<Byte> {
        var iv = ArrayList<Byte>()
        for (i in 0..8) {
            iv.add(key[i % key.size])
        }
        iv.toArray()
    }

    private static func blockAt(data: Array<Byte>, start: Int64): Array<Byte> {
        var b = ArrayList<Byte>()
        for (i in start..(start + 8)) {
            b.add(data[i])
        }
        b.toArray()
    }

    // 按字节异或（CBC 链式）
    private static func xorBlocks(a: Array<Byte>, b: Array<Byte>): Array<Byte> {
        var out = ArrayList<Byte>()
        for (i in 0..8) {
            out.add(UInt8((Int64(a[i]) ^ Int64(b[i])) & 0xFF))
        }
        out.toArray()
    }

    // PKCS7 填充到 8 字节整数倍（满块也补一个完整 padding 块）
    private static func pkcs7Pad(data: Array<Byte>): Array<Byte> {
        var out = ArrayList<Byte>()
        for (b in data) {
            out.add(b)
        }
        let pad = 8 - (data.size % 8)
        let padByte = UInt8(pad & 0xFF)
        for (i in 0..pad) {
            out.add(padByte)
        }
        out.toArray()
    }

    private static func pkcs7Unpad(data: Array<Byte>): Array<Byte> {
        if (data.size == 0) {
            return data
        }
        let pad = Int64(data[data.size - 1])
        if (pad < 1 || pad > 8 || data.size < pad) {
            return data
        }
        var out = ArrayList<Byte>()
        for (i in 0..(data.size - pad)) {
            out.add(data[i])
        }
        out.toArray()
    }
}
