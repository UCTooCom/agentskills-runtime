package quic_cj

import quic_cj.protocol.{Version, VERSION_1, VERSION_2, DEFAULT_IDLE_TIMEOUT_MS, DEFAULT_HANDSHAKE_IDLE_TIMEOUT_MS, DEFAULT_MAX_INCOMING_STREAMS, DEFAULT_MAX_INCOMING_UNI_STREAMS, DEFAULT_INITIAL_MAX_STREAM_DATA}
import quic_cj.tls.TlsConfig

/// CONGESTION_ALGORITHM_CUBIC 表示 CUBIC 拥塞控制算法。
public let CONGESTION_ALGORITHM_CUBIC: Int64 = 0
/// CONGESTION_ALGORITHM_NEW_RENO 表示 NewReno 拥塞控制算法。
public let CONGESTION_ALGORITHM_NEW_RENO: Int64 = 1

/// Config 保存 QUIC 连接配置。
public class Config {
    public var versions: Array<Version> = [VERSION_1, VERSION_2]
    public var handshakeIdleTimeoutMs: Int64 = DEFAULT_HANDSHAKE_IDLE_TIMEOUT_MS
    public var maxIdleTimeoutMs: Int64 = DEFAULT_IDLE_TIMEOUT_MS
    public var maxIncomingStreams: Int64 = DEFAULT_MAX_INCOMING_STREAMS
    public var maxIncomingUniStreams: Int64 = DEFAULT_MAX_INCOMING_UNI_STREAMS
    public var initialStreamReceiveWindow: Int64 = DEFAULT_INITIAL_MAX_STREAM_DATA
    public var maxStreamReceiveWindow: Int64 = DEFAULT_INITIAL_MAX_STREAM_DATA * 4
    public var initialConnectionReceiveWindow: Int64 = DEFAULT_INITIAL_MAX_STREAM_DATA * 16
    public var maxConnectionReceiveWindow: Int64 = DEFAULT_INITIAL_MAX_STREAM_DATA * 64
    public var initialPacketSize: Int64 = 1200
    public var serverName: String = ""
    public var preferredAddressData: Array<Byte> = []
    public var disableActiveMigration: Bool = false
    public var maxDatagramFrameSize: Int64 = 0

    /// 拥塞控制算法选择。默认使用 CUBIC。
    /// 可取值：CONGESTION_ALGORITHM_CUBIC 或 CONGESTION_ALGORITHM_NEW_RENO。
    public var congestionAlgorithm: Int64 = CONGESTION_ALGORITHM_CUBIC

    /// TLS 配置（可选）。用于 ALPN、服务器名称、早期数据等 TLS 握手参数。
    public var tlsConfig: ?TlsConfig = None

    /// 是否启用服务端 Retry 包（地址验证）。启用后，服务端在接收 Initial 包时
    /// 先发送 Retry 包进行地址验证（RFC 9000 §8），客户端需携带 Retry 令牌重发 Initial。
    /// 禁用时（默认），服务端直接处理 Initial 包以建立连接。
    public var enableRetry: Bool = false

    /// 重试令牌加密密钥（可选，32 字节）。若未设置则自动生成。
    /// 用于加密 Retry 和 NEW_TOKEN 帧中的地址令牌。
    public var retryTokenKey: Array<Byte> = []

    /// 无状态重置密钥（可选，16 字节 AES-128 密钥）。
    /// 若设置，服务器可为每个连接自动生成无状态重置令牌，
    /// 并在收到未知连接 ID 的短包头包时发送无状态重置包（RFC 9000 §10.3）。
    /// 若未设置，无状态重置功能禁用。
    public var statelessResetKey: Array<Byte> = []

    public init() {}

    /// 验证配置并应用默认值。
    public func validate(): Bool {
        serverName = serverName.trimStart().trimEnd()
        if (versions.size == 0) { return false }
        if (initialPacketSize < 1200) { initialPacketSize = 1200 }
        if (maxIncomingStreams > Int64(1) << 60) { maxIncomingStreams = Int64(1) << 60 }
        if (maxIncomingUniStreams > Int64(1) << 60) { maxIncomingUniStreams = Int64(1) << 60 }
        true
    }
}

/// 返回一个带有合理默认值的 Config。
public func defaultConfig(): Config {
    Config()
}
