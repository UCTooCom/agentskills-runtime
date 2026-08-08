package http_lib.message
/**
 * Brotli 压缩/解压（RFC 7932）。
 * 在 HTTP 场景中通过 Accept-Encoding: br 进行内容协商。
 */

import http_lib.core.UnsupportedOperationException
import compress4cj.brotli.{brotliCompress as zBrotliCompress, brotliDecompress as zBrotliDecompress, brotliAvailable as zBrotliAvailable}

/**
 * Brotli 内容编码支持 (RFC 7932)。
 *
 * 压缩/解压由 compress4cj 依赖提供，本模块仅做转发封装。
 * 基于外部 brotli 库提供压缩和解压能力，
 * 支持 0-11 的压缩质量级别。
 */

/**
 * 检查 Brotli 压缩是否可用。
 */
public func brotliAvailable(): Bool {
    zBrotliAvailable()
}

/**
 * 使用 Brotli 压缩数据。
 */
public func brotliCompress(data: Array<UInt8>, quality!: Int64 = 6): Array<UInt8> {
    try {
        zBrotliCompress(data, quality: quality)
    } catch (e: Exception) {
        data
    }
}

/**
 * 解压缩 Brotli 编码的数据。
 * 将解压异常转换为 UnsupportedOperationException。
 */
public func brotliDecompress(data: Array<UInt8>): Array<UInt8> {
    if (data.size == 0) { return data }
    try {
        zBrotliDecompress(data)
    } catch (e: Exception) {
        throw UnsupportedOperationException(
            "Brotli 解压失败: ${e.message}")
    }
}

/**
 * 扩展的内容编码选择，包含 Brotli 和 gzip 回退。
 * 优先级：br > gzip > deflate > identity
 */
public func selectContentEncodingWithBrotli(acceptEncoding: ?String): String {
    match (acceptEncoding) {
        case Some(ae) =>
            if (brotliAvailable()) {
                let entries = parseAcceptEncoding(ae)
                for (entry in entries) {
                    if (entry.value == "br" && entry.quality > 0.0) { return "br" }
                }
            }
            selectContentEncoding(acceptEncoding, ["gzip", "deflate"])
        case None => "identity"
    }
}
