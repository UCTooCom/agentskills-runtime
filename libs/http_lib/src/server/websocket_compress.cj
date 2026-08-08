/**
 * WebSocket Per-Message Deflate (RFC 7692) 实现。
 *
 * 为 WebSocket 消息提供压缩/解压能力：
 * - compressPayload(): 使用 deflate 压缩消息负载
 * - decompressPayload(): 使用 deflate 解压消息负载
 * - parsePmdExtensions(): 解析 Sec-WebSocket-Extensions 并协商参数
 *
 * 支持参数：
 * - client_no_context_takeover / server_no_context_takeover
 * - client_max_window_bits / server_max_window_bits
 *
 * RFC 7692 §6: 压缩使用 DEFLATE 算法（RFC 1951），窗口大小 15 位。
 * RFC 7692 §7.2: 每个消息末尾发送一个由 BFINAL=1 标记的压缩块。
 */
package http_lib.server

import std.convert.Parsable
import compress4cj.zlib.{Zlib, ZlibType}

/**
 * Per-Message Deflate 扩展配置。
 * 对应于 RFC 7692 §9.1 中定义的参数。
 */
public class PerMessageDeflateConfig {
    /// 服务器端是否启用 no_context_takeover
    public var serverNoContextTakeover: Bool
    /// 客户端是否启用 no_context_takeover
    public var clientNoContextTakeover: Bool
    /// 服务器最大窗口位数（默认 15）
    public var serverMaxWindowBits: Int64
    /// 客户端最大窗口位数（默认 15）
    public var clientMaxWindowBits: Int64

    public init(
        serverNoContextTakeover!: Bool = false,
        clientNoContextTakeover!: Bool = false,
        serverMaxWindowBits!: Int64 = 15,
        clientMaxWindowBits!: Int64 = 15
    ) {
        this.serverNoContextTakeover = serverNoContextTakeover
        this.clientNoContextTakeover = clientNoContextTakeover
        this.serverMaxWindowBits = serverMaxWindowBits
        this.clientMaxWindowBits = clientMaxWindowBits
    }
}

/**
 * Per-Message Deflate 压缩/解压器。
 *
 * 管理 WebSocket 消息的压缩和解压上下文。
 * 当前使用 compress4cj 的 Zlib 单次 API 实现。
 */
public class PerMessageDeflate {
    /// 当前有效的配置
    private let config: PerMessageDeflateConfig
    /// 是否已激活（握手成功后设置为 true）
    private var active: Bool
    /// 压缩时是否需要 no_context_takeover
    private var compressNoTakeover: Bool
    /// 解压时是否需要 no_context_takeover
    private var decompressNoTakeover: Bool

    public init(config!: PerMessageDeflateConfig = PerMessageDeflateConfig()) {
        this.config = config
        this.active = false
        this.compressNoTakeover = false
        this.decompressNoTakeover = false
    }

    /**
     * 激活 PMD（握手成功后调用）。
     * @param isServer  当前端是否为服务器（影响 no_context_takeover 方向）
     */
    public func activate(isServer: Bool): Unit {
        active = true
        if (isServer) {
            compressNoTakeover = config.serverNoContextTakeover
            decompressNoTakeover = config.clientNoContextTakeover
        } else {
            compressNoTakeover = config.clientNoContextTakeover
            decompressNoTakeover = config.serverNoContextTakeover
        }
    }

    /**
     * 检查 PMD 是否已激活。
     */
    public func isActive(): Bool {
        active
    }

    /**
     * 获取当前配置。
     */
    public func getConfig(): PerMessageDeflateConfig {
        config
    }

    /**
     * 压缩消息负载。
     *
     * 使用 raw deflate（ZlibType.DEFLATE）压缩数据。
     * 当 no_context_takeover 启用时，每次压缩重新初始化上下文
     * （由 compress4cj 的 one-shot API 自然满足）。
     *
     * @param data  原始消息负载字节
     * @return 压缩后的负载字节（放入 WebSocket 帧时 RSV1 应置 1）
     */
    public func compressPayload(data: Array<UInt8>): Array<UInt8> {
        if (!active || data.size == 0) {
            return data
        }
        try {
            Zlib.compress(data, wrap: ZlibType.DEFLATE)
        } catch (_: Exception) {
            data
        }
    }

    /**
     * 解压消息负载。
     *
     * 使用 raw inflate（ZlibType.DEFLATE）解压数据。
     * 如果直接解压失败，尝试追加 0x00 0x00 0xFF 0xFF
     * （RFC 7692 §7.2.1 尾标记）后重试。
     *
     * @param data  来自 WebSocket 帧的负载字节（RSV1 已置 1）
     * @return 解压后的原始消息负载
     */
    public func decompressPayload(data: Array<UInt8>): Array<UInt8> {
        if (!active || data.size == 0) {
            return data
        }
        // 尝试直接解压
        try {
            return Zlib.uncompress(data, wrap: ZlibType.DEFLATE)
        } catch (_: Exception) {
            // fall through to try with sync flush suffix
        }
        // 追加 0x00 0x00 0xFF 0xFF（RFC 7692 §7.2.1 尾标记）
        try {
            let paddedData = Array<UInt8>(data.size + 4, repeat: 0)
            data.copyTo(paddedData, 0, 0, data.size)
            paddedData[data.size] = 0x00u8
            paddedData[data.size + 1] = 0x00u8
            paddedData[data.size + 2] = 0xFFu8
            paddedData[data.size + 3] = 0xFFu8
            return Zlib.uncompress(paddedData, wrap: ZlibType.DEFLATE)
        } catch (_: Exception) {
            return data
        }
    }
}

/**
 * 解析 Sec-WebSocket-Extensions 头部，提取 permessage-deflate 参数。
 *
 * 输入示例：
 *   Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits=15; server_no_context_takeover
 *
 * @param extensionHeader  Sec-WebSocket-Extensions 头部的值
 * @return 解析成功返回 PerMessageDeflateConfig，未找到或无效返回 None
 */
public func parsePmdExtensions(extensionHeader: String): ?PerMessageDeflateConfig {
    let lowered = toLowerStr(extensionHeader)
    if (!lowered.contains("permessage-deflate")) {
        return None
    }
    let config = PerMessageDeflateConfig()
    let extensions = lowered.split(",")
    for (ext in extensions) {
        let trimmed = trimStr(ext)
        if (trimmed.startsWith("permessage-deflate")) {
            let params = trimmed.split(";")
            for (param in params) {
                let p = trimStr(param)
                if (p == "server_no_context_takeover") {
                    config.serverNoContextTakeover = true
                } else if (p == "client_no_context_takeover") {
                    config.clientNoContextTakeover = true
                } else if (p.startsWith("server_max_window_bits")) {
                    let eqIdx = p.indexOf("=")
                    match (eqIdx) {
                        case Some(idx) =>
                            let valStr = trimStr(p[idx + 1..])
                            try {
                                let bits = Int64.parse(valStr)
                                if (bits >= 8 && bits <= 15) {
                                    config.serverMaxWindowBits = bits
                                }
                            } catch (_: Exception) {}
                        case None => ()
                    }
                } else if (p.startsWith("client_max_window_bits")) {
                    let eqIdx = p.indexOf("=")
                    match (eqIdx) {
                        case Some(idx) =>
                            let valStr = trimStr(p[idx + 1..])
                            try {
                                let bits = Int64.parse(valStr)
                                if (bits >= 8 && bits <= 15) {
                                    config.clientMaxWindowBits = bits
                                }
                            } catch (_: Exception) {}
                        case None => ()
                    }
                }
            }
            return Some(config)
        }
    }
    None
}

/**
 * 构建 Sec-WebSocket-Extensions 请求头值。
 *
 * @param config_  PMD 配置参数
 * @return 用于 Sec-WebSocket-Extensions 头部的值字符串
 */
public func buildPmdExtensionHeader(config_ !: PerMessageDeflateConfig = PerMessageDeflateConfig()): String {
    let sb = StringBuilder()
    sb.append("permessage-deflate")
    if (config_.clientMaxWindowBits != 15) {
        sb.append("; client_max_window_bits=${config_.clientMaxWindowBits}")
    }
    if (config_.clientNoContextTakeover) {
        sb.append("; client_no_context_takeover")
    }
    if (config_.serverMaxWindowBits != 15) {
        sb.append("; server_max_window_bits=${config_.serverMaxWindowBits}")
    }
    if (config_.serverNoContextTakeover) {
        sb.append("; server_no_context_takeover")
    }
    sb.toString()
}

/**
 * 合并服务器端和客户端的 PMD 配置（握手响应）。
 * 服务器在 Sec-WebSocket-Extensions 响应头中返回它接受的参数子集。
 *
 * @param serverConfig  服务器支持的配置
 * @param clientOffer   客户端提议的配置（来自 parsePmdExtensions）
 * @return 握手成功后双方认可的配置
 */
public func negotiatePmdConfig(serverConfig: PerMessageDeflateConfig, clientOffer: PerMessageDeflateConfig): PerMessageDeflateConfig {
    PerMessageDeflateConfig(
        serverNoContextTakeover: clientOffer.serverNoContextTakeover || serverConfig.serverNoContextTakeover,
        clientNoContextTakeover: clientOffer.clientNoContextTakeover || serverConfig.clientNoContextTakeover,
        serverMaxWindowBits: if (clientOffer.serverMaxWindowBits < serverConfig.serverMaxWindowBits) {
            clientOffer.serverMaxWindowBits
        } else {
            serverConfig.serverMaxWindowBits
        },
        clientMaxWindowBits: if (clientOffer.clientMaxWindowBits < serverConfig.clientMaxWindowBits) {
            clientOffer.clientMaxWindowBits
        } else {
            serverConfig.clientMaxWindowBits
        }
    )
}

private func toLowerStr(s: String): String {
    let bytes = s.toArray()
    var i: Int64 = 0
    while (i < bytes.size) {
        if (bytes[i] >= b'A' && bytes[i] <= b'Z') { bytes[i] = bytes[i] + 32 }
        i += 1
    }
    unsafe { String.withRawData(bytes) }
}

private func trimStr(s: String): String {
    let bytes = s.toArray()
    var start: Int64 = 0
    var end: Int64 = bytes.size - 1
    while (start < bytes.size && bytes[start] <= b' ') { start += 1 }
    while (end >= start && bytes[end] <= b' ') { end -= 1 }
    if (start > end) { return "" }
    unsafe { String.withRawData(bytes[start..(end + 1)]) }
}
