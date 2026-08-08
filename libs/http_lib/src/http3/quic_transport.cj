/**
 * QUIC 传输层抽象接口（RFC 9000）。
 *
 * 本文件定义 HTTP/3 所需的 QUIC 传输层接口，包括：
 * - QuicStream: 单向/双向流抽象
 * - QuicConnection: QUIC 连接抽象（流管理、连接生命周期）
 * - QuicListener: QUIC 监听器抽象（接受新连接）
 *
 * 通过这些接口，HTTP/3 协议层可独立于具体 QUIC 实现运行。
 * 需要外部 QUIC 实现（如 quic-go）提供这些接口的具体实现。
 *
 * @see https://www.rfc-editor.org/rfc/rfc9000
 * @see https://www.rfc-editor.org/rfc/rfc9114
 */
package http_lib.http3

import std.sync.Mutex

// ======== 流类型（RFC 9000 §19.11）========

/**
 * QUIC 流方向类型。
 */
public enum QuicStreamType {
    | UNIDIRECTIONAL  // 单向流（仅发送方写入）
    | BIDIRECTIONAL   // 双向流（双方可读可写）

    public operator func ==(that: QuicStreamType): Bool {
        match (this) {
            case UNIDIRECTIONAL => match (that) { case UNIDIRECTIONAL => true; case _ => false }
            case BIDIRECTIONAL => match (that) { case BIDIRECTIONAL => true; case _ => false }
        }
    }

    public operator func !=(that: QuicStreamType): Bool {
        !(this == that)
    }
}

// ======== QUIC 错误码（RFC 9000 §20.1）========

/**
 * QUIC 传输错误码。
 */
public enum QuicErrorCode <: Equatable<QuicErrorCode> {
    | QUIC_NO_ERROR
    | QUIC_INTERNAL_ERROR
    | QUIC_CONNECTION_REFUSED
    | QUIC_FLOW_CONTROL_ERROR
    | QUIC_STREAM_LIMIT_ERROR
    | QUIC_STREAM_STATE_ERROR
    | QUIC_FINAL_SIZE_ERROR
    | QUIC_FRAME_ENCODING_ERROR
    | QUIC_TRANSPORT_PARAMETER_ERROR
    | QUIC_CONNECTION_ID_LIMIT_ERROR
    | QUIC_PROTOCOL_VIOLATION
    | QUIC_INVALID_TOKEN
    | QUIC_APPLICATION_ERROR
    | QUIC_CRYPTO_BUFFER_EXCEEDED
    | QUIC_KEY_UPDATE_ERROR
    | QUIC_AEAD_LIMIT_REACHED
    | QUIC_NO_VIABLE_PATH

    public func toUInt16(): UInt16 {
        match (this) {
            case QUIC_NO_ERROR => 0x00
            case QUIC_INTERNAL_ERROR => 0x01
            case QUIC_CONNECTION_REFUSED => 0x02
            case QUIC_FLOW_CONTROL_ERROR => 0x03
            case QUIC_STREAM_LIMIT_ERROR => 0x04
            case QUIC_STREAM_STATE_ERROR => 0x05
            case QUIC_FINAL_SIZE_ERROR => 0x06
            case QUIC_FRAME_ENCODING_ERROR => 0x07
            case QUIC_TRANSPORT_PARAMETER_ERROR => 0x08
            case QUIC_CONNECTION_ID_LIMIT_ERROR => 0x09
            case QUIC_PROTOCOL_VIOLATION => 0x0A
            case QUIC_INVALID_TOKEN => 0x0B
            case QUIC_APPLICATION_ERROR => 0x0C
            case QUIC_CRYPTO_BUFFER_EXCEEDED => 0x0D
            case QUIC_KEY_UPDATE_ERROR => 0x0E
            case QUIC_AEAD_LIMIT_REACHED => 0x0F
            case QUIC_NO_VIABLE_PATH => 0x10
        }
    }

    public operator func ==(that: QuicErrorCode): Bool {
        this.toUInt16() == that.toUInt16()
    }

    public operator func !=(that: QuicErrorCode): Bool {
        !(this == that)
    }
}


// ======== QUIC 版本（RFC 9369）========

/**
 * QUIC 协议版本。
 * - V1: RFC 9000 (0x00000001)
 * - V2: RFC 9369 (0x6b3343cf)
 */
public enum QuicVersion {
    | V1
    | V2
    | UNKNOWN

    public func toUInt32(): UInt32 {
        match (this) {
            case V1 => 0x00000001u32
            case V2 => 0x6b3343cfu32
            case UNKNOWN => 0x00000000u32
        }
    }

    public static func fromUInt32(v: UInt32): QuicVersion {
        match (v) {
            case 0x00000001u32 => V1
            case 0x6b3343cfu32 => V2
            case _ => UNKNOWN
        }
    }
}
// ======== QUIC 流抽象 ========

/**
 * QUIC 流抽象接口。
 *
 * QUIC 流提供有序、可靠的字节传输（RFC 9000 §2）。
 * HTTP/3 使用 QUIC 流作为其并发传输单元：
 * - 每个 HTTP 请求/响应使用一条双向流
 * - 控制信息使用单向流（控制流、QPACK 流）
 */
public interface QuicStream {
    /**
     * 从流中读取数据。
     * 返回实际读取的字节数。流结束时返回 0。
     */
    func read(buf: Array<UInt8>): Int64

    /**
     * 向流中写入数据。
     */
    func write(data: Array<UInt8>): Int64

    /**
     * 刷新写入缓冲区。
     */
    func flush(): Unit

    /**
     * 关闭流的写入端。
     */
    func closeWrite(): Unit

    /**
     * 关闭流的读取端。
     */
    func closeRead(): Unit

    /**
     * 完全关闭流。
     */
    func close(): Unit

    /**
     * 获取流 ID。
     */
    func getStreamId(): UInt64

    /**
     * 获取流类型。
     */
    func getStreamType(): QuicStreamType

    /**
     * 流是否已关闭。
     */
    func isClosed(): Bool

    /**
     * 获取已写入流的数据。
     * 用于测试和调试目的。
     */
    func getWrittenData(): Array<UInt8>

    /**
     * 获取已写入流的数据字符串。
     * 用于测试和调试目的。
     */
    func getWrittenString(): String
}

// ======== QUIC 连接抽象 ========

/**
 * QUIC 连接抽象接口。
 *
 * 管理 QUIC 连接生命周期和流创建。
 * HTTP/3 在此连接上创建各种流类型：
 * - 控制流（客户端/服务器各一条）
 * - QPACK 编码器/解码器流
 * - HTTP 请求/响应双向流
 */
public interface QuicConnection {
    /**
     * 打开一条双向流。
     * 用于发起 HTTP 请求（客户端）或响应（服务器）。
     */
    func openStream(): ?QuicStream

    /**
     * 打开一条单向流。
     * 用于创建控制流或 QPACK 流。
     */
    func openUnidirectionalStream(): ?QuicStream

    /**
     * 接受一条新的双向流。
     * 由服务器在接收客户端请求时使用。
     */
    func acceptStream(): ?QuicStream

    /**
     * 接受一条新的单向流。
     * 用于接收控制流或 QPACK 流。
     */
    func acceptUnidirectionalStream(): ?QuicStream

    /**
     * 使用应用层错误码关闭连接。
     */
    func closeWithError(errorCode: QuicErrorCode, message: String): Unit

    /**
     * 优雅关闭连接（发送 GOAWAY 等效信号）。
     */
    func close(): Unit

    /**
     * 连接是否已关闭。
     */
    func isClosed(): Bool

    /**
     * 获取连接的远程地址。
     */
    func getRemoteAddr(): String

    /**
     * 设置连接级别的读超时。
     */
    func setReadTimeout(timeout: Duration): Unit
   func getConnectionId(): ?Array<UInt8>
   func migrateTo(addr: String): Bool
   func getVersion(): QuicVersion
    /**
     * 注册路径迁移回调（RFC 9000 §9）。
     * 当 QUIC 检测到对端地址变更时，调用此处理器。
     * @param handler 接收新远程地址的回调
     */
   func setPathMigrationHandler(handler: (String) -> Unit): Unit

    /**
     * 发送不可靠数据报（RFC 9221）。
     * 数据报按帧发送，不受流控限制。返回 false 表示数据报因拥塞或队列满被丢弃。
     */
    func sendDatagram(data: Array<UInt8>): Bool

    /**
     * 接收到达的数据报。无可达数据报时返回 None。
     * 数据报是无序的、不可靠的（RFC 9221 §5）。
     */
    func receiveDatagram(): ?Array<UInt8>

    /**
     * 注册数据报接收回调。当收到新的数据报时，回调被自动调用。
     * 回调参数为接收到的数据报负载。
     */
    func setDatagramCallback(callback: (Array<UInt8>) -> Unit): Unit

    /**
     * 获取当前 QUIC 连接的最大数据报负载大小（基于 PMTU 和传输参数）。
     * 用于避免 PMTU 分片。
     * @return 最大数据报负载大小（字节），0 表示不可用
     */
    func maxDatagramSize(): Int64

    /**
     * 获取当前待发送的数据报队列中等待的帧数量（用于背压）。
     * @return 队列中待发送的数据报数量
     */
    func datagramSendQueue(): Int64

    /**
     * 检查是否可以发送 0-RTT 数据（RFC 9000 §7.4.1）。
     * 在连接恢复场景中可用，允许在握手完成前发送数据。
     */
    func canSendEarlyData(): Bool

    /**
     * 发送 0-RTT 数据（RFC 9000 §7.4.1）。
     * 在握手完成前发送应用数据。
     */
    func sendEarlyData(data: Array<UInt8>): Bool

    /**
     * 接收 0-RTT 数据（RFC 9000 §7.4.1）。
     * 服务端在握手期间接收客户端提前发送的数据。
     */
    func receiveEarlyData(): ?Array<UInt8>

    /**
     * 设置 0-RTT 数据接收回调。
     * 当收到 0-RTT 数据时调用此回调。
     */
    func setEarlyDataCallback(callback: ?(Array<UInt8>) -> Unit): Unit
}

// ======== QUIC 监听器抽象 ========

/**
 * QUIC 监听器抽象接口。
 *
 * 监听指定地址并接受 QUIC 连接。
 * HTTP/3 服务器使用此接口接受新连接。
 */
public interface QuicListener {
    /**
     * 接受一个新的 QUIC 连接。
     * 阻塞直到有新连接到达或监听器关闭。
     */
    func accept(): ?QuicConnection

    /**
     * 关闭监听器。
     * 关闭后 accept() 将返回 None。
     */
    func close(): Unit

    /**
     * 获取监听器的本地地址。
     */
    func getLocalAddr(): String
}

// ======== QUIC 传输工厂 ========

/**
 * QUIC 传输层工厂。
 * 用于创建 QUIC 监听器和拨号器。
 * 外部 QUIC 实现（如 quic-go 适配）实现此接口。
 */
public interface QuicTransportFactory {
    /**
     * 在指定地址上创建 QUIC 监听器。
     * @param host 监听主机地址
     * @param port 监听端口
     * @param tlsConfig TLS 配置（QUIC 需要 TLS 1.3）
     * @return QUIC 监听器
     */
    func listen(host: String, port: UInt16, tlsConfig: H3TlsConfig): ?QuicListener

    /**
     * 拨号连接到指定地址。
     * @param host 目标主机
     * @param port 目标端口
     * @param tlsConfig TLS 配置（QUIC 需要 TLS 1.3）
     * @return QUIC 连接
     */
    func dial(host: String, port: UInt16, tlsConfig: H3TlsConfig): ?QuicConnection

    /**
     * 获取工厂名称。
     */
    func getName(): String
}

// ======== 连接迁移回调类型 ========

/**
 * QUIC 连接路径迁移回调。
 */

// ======== QUIC 连接事件 ========

/**
 * QUIC 连接事件处理器。
 * 当 QUIC 连接上发生重要事件时，HTTP/3 连接处理器接收通知。
 */
public interface QuicConnectionHandler {
    /**
     * 当新的双向流被接受时调用。
     * @param stream 新接受的 QUIC 流
     */
    func onNewStream(stream: QuicStream): Unit

    /**
     * 当新的单向流被接受时调用。
     * @param stream 新接受的单向流
     */
    func onNewUnidirectionalStream(stream: QuicStream): Unit

    /**
     * 当连接因错误关闭时调用。
     * @param errorCode QUIC 错误码
     * @param message 错误描述
     */
    func onConnectionError(errorCode: QuicErrorCode, message: String): Unit

    /**
     * 当连接被优雅关闭时调用。
     */
   func onConnectionClosed(): Unit
    /**
     * 当连接路径发生迁移时调用（RFC 9000 §9）。
     * @param newAddr 新的远程地址
     */
    func onPathMigration(newAddr: String): Unit
}

// ======== HTTP/3 TLS 配置（简化版）========

/**
 * HTTP/3 所需的最简 TLS 配置。
 * QUIC 使用 TLS 1.3 进行握手和加密。
 */
public class H3TlsConfig {
    public var serverCertPath: String = ""
    public var serverKeyPath: String = ""
    public var caCertPath: String = ""
    public var serverName: String = ""

    public init() {}

    public static func defaultServer(certPath: String, keyPath: String): H3TlsConfig {
        let cfg = H3TlsConfig()
        cfg.serverCertPath = certPath
        cfg.serverKeyPath = keyPath
        cfg
    }

    public static func defaultClient(serverName: String): H3TlsConfig {
        let cfg = H3TlsConfig()
        cfg.serverName = serverName
        cfg
    }
}
