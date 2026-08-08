package http_lib.message
/**
 * HTTP Content-Encoding 压缩/解压工具（RFC 7231 §3.1.2.2）。
 * 支持 gzip、deflate 编码。包含 64 MB 最大解压限制防止解压炸弹攻击。
 */

import compress4cj.zlib.{Zlib, ZlibType}
import std.unicode.*
import http_lib.core.ProtocolException

/**
 * HTTP Content-Encoding 压缩/解压辅助类（RFC 2616）。
 *
 * 支持 gzip 和 deflate 编码。
 * 实际压缩/解压由 compress4cj 提供。
 */
public class Compression {
    /// 最大解压后大小（64 MB），防止解压炸弹攻击
    public static let MAX_DECOMPRESSED_SIZE: Int64 = 64 * 1024 * 1024

    /**
     * 根据 Content-Encoding 响应头值解压响应体。
     */
    /**
     * 按传输编码（Transfer-Encoding）解压数据。
     * 支持 "gzip" 传输编码。
     */
    public static func decompressTransfer(data: Array<UInt8>, encoding: String): Array<UInt8> {
        let lower = toLowerStr(encoding)
        if (lower.contains("gzip")) {
            return decompressGzip(data)
        }
        data
    }

    /**
     * 按传输编码（Transfer-Encoding）压缩数据。
     * 支持 "gzip" 传输编码。
     */
    public static func compressTransfer(data: Array<UInt8>, encoding: String): Array<UInt8> {
        let lower = toLowerStr(encoding)
        if (lower.contains("gzip")) {
            return compressGzip(data)
        }
        data
    }

    public static func decompress(data: Array<UInt8>, contentEncoding: String): Array<UInt8> {
        if (data.size == 0) {
            return data
        }
        let lowered = toLowerStr(contentEncoding)
        if (lowered.startsWith("gzip") || lowered.startsWith("x-gzip")) {
            return decompressGzip(data)
        }
        if (lowered.startsWith("deflate")) {
            return decompressDeflate(data)
        }
        // identity 或未知编码 — 原样返回
        data
    }

    /**
     * 解压 gzip 编码数据。通过 compress4cj 的 maxOutputSize 参数防止解压炸弹。
     */
    public static func decompressGzip(data: Array<UInt8>): Array<UInt8> {
        try {
            let result = Zlib.uncompress(data, wrap: ZlibType.GZIP, maxOutputSize: MAX_DECOMPRESSED_SIZE)
            result
        } catch (e: Exception) {
            throw ProtocolException("gzip 解压失败: ${e.message}")
        }
    }

    /**
     * 解压 deflate 编码数据。通过 compress4cj 的 maxOutputSize 参数防止解压炸弹。
     */
    public static func decompressDeflate(data: Array<UInt8>): Array<UInt8> {
        try {
            let result = Zlib.uncompress(data, wrap: ZlibType.DEFLATE, maxOutputSize: MAX_DECOMPRESSED_SIZE)
            result
        } catch (e: Exception) {
            throw ProtocolException("deflate 解压失败: ${e.message}")
        }
    }

    /**
     * 使用 gzip 压缩数据。压缩失败时返回原始数据。
     */
    public static func compressGzip(data: Array<UInt8>, level!: Int64 = 6): Array<UInt8> {
        if (data.size == 0) {
            return data
        }
        try {
            Zlib.compress(data, wrap: ZlibType.GZIP, level: level)
        } catch (e: Exception) {
            data
        }
    }

    /**
     * 使用 deflate 压缩数据。压缩失败时返回原始数据。
     */
    public static func compressDeflate(data: Array<UInt8>, level!: Int64 = 6): Array<UInt8> {
        if (data.size == 0) {
            return data
        }
        try {
            Zlib.compress(data, wrap: ZlibType.DEFLATE, level: level)
        } catch (e: Exception) {
            data
        }
    }

    private static func toLowerStr(s: String): String {
        s.toLower()
    }
}
