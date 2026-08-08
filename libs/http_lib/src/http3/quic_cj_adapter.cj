/**
 * quic_cj 传输层适配器。
 *
 * 将 quic_cj 的传输抽象适配到 http_lib 的 QuicTransportFactory 接口。
 * 注意：在 Cangjie 中，Byte 与 UInt8 为同一类型。
 */
package http_lib.http3

import quic_cj.{Config, Conn, Listener, dial, listen}
import quic_cj.tls.{TlsConfig as QuicTlsConfig}
import quic_cj.stream.{Stream as QStream, SendStream, ReceiveStream}
import std.time
import quic_cj.util.TransportErrorCode

private func ec(code: QuicErrorCode): TransportErrorCode {
    match (code) {
        case QuicErrorCode.QUIC_NO_ERROR => 0x00u64
        case QuicErrorCode.QUIC_INTERNAL_ERROR => 0x01u64
        case QuicErrorCode.QUIC_CONNECTION_REFUSED => 0x02u64
        case QuicErrorCode.QUIC_FLOW_CONTROL_ERROR => 0x03u64
        case QuicErrorCode.QUIC_STREAM_LIMIT_ERROR => 0x04u64
        case QuicErrorCode.QUIC_STREAM_STATE_ERROR => 0x05u64
        case QuicErrorCode.QUIC_FINAL_SIZE_ERROR => 0x06u64
        case QuicErrorCode.QUIC_FRAME_ENCODING_ERROR => 0x07u64
        case QuicErrorCode.QUIC_TRANSPORT_PARAMETER_ERROR => 0x08u64
        case QuicErrorCode.QUIC_CONNECTION_ID_LIMIT_ERROR => 0x09u64
        case QuicErrorCode.QUIC_PROTOCOL_VIOLATION => 0x0au64
        case QuicErrorCode.QUIC_INVALID_TOKEN => 0x0bu64
        case _ => 0x00u64
    }
}

public class AdapterQuicStream <: QuicStream {
    private var stream: QStream
    private var send: SendStream
    private var recv: ReceiveStream
    private var isFullyClosed: Bool = false
    private var writeClosed: Bool = false
    private var readClosed: Bool = false

    public init(stream: QStream) { this.stream = stream; this.send = stream.getSendStream(); this.recv = stream.getReceiveStream() }

    public func read(buf: Array<UInt8>): Int64 {
        if (readClosed || recv.isFinReceived()) { return 0 }
        let raw = recv.read()
        if (raw.size == 0) { return 0 }
        let n = if (raw.size > buf.size) { buf.size } else { raw.size }
        var i: Int64 = 0
        while (i < n) { buf[i] = raw[i]; i += 1 }
        n
    }

    public func write(data: Array<UInt8>): Int64 {
        if (writeClosed) { return 0 }
        send.write(data)
        data.size
    }

    public func flush(): Unit {}
    public func closeWrite(): Unit { writeClosed = true; send.close() }
    public func closeRead(): Unit { readClosed = true }
    public func close(): Unit { isFullyClosed = true; writeClosed = true; readClosed = true; send.close() }
    public func getStreamId(): UInt64 { UInt64(stream.getStreamId()) }
    public func getStreamType(): QuicStreamType { QuicStreamType.BIDIRECTIONAL }
    public func isClosed(): Bool { isFullyClosed }
    public func getWrittenData(): Array<UInt8> { [] }
    public func getWrittenString(): String { "" }
    public func canSendEarlyData(): Bool { false }
    public func sendEarlyData(data: Array<UInt8>): Bool { false }
    public func receiveEarlyData(): ?Array<UInt8> { None }
    public func setEarlyDataCallback(callback: ?(Array<UInt8>) -> Unit): Unit {}
}

public class AdapterSendStream <: QuicStream {
    private var send: SendStream
    private var closed: Bool = false
    public init(send: SendStream) { this.send = send }
    public func read(buf: Array<UInt8>): Int64 { 0 }
    public func write(data: Array<UInt8>): Int64 { if (closed) { return 0 }; send.write(data); data.size }
    public func flush(): Unit {}
    public func closeWrite(): Unit { closed = true; send.close() }
    public func closeRead(): Unit {}
    public func close(): Unit { closed = true; send.close() }
    public func getStreamId(): UInt64 { 0u64 }
    public func getStreamType(): QuicStreamType { QuicStreamType.UNIDIRECTIONAL }
    public func isClosed(): Bool { closed }
    public func getWrittenData(): Array<UInt8> { [] }
    public func getWrittenString(): String { "" }
    public func canSendEarlyData(): Bool { false }
    public func sendEarlyData(data: Array<UInt8>): Bool { false }
    public func receiveEarlyData(): ?Array<UInt8> { None }
    public func setEarlyDataCallback(callback: ?(Array<UInt8>) -> Unit): Unit {}
}

public class AdapterReceiveStream <: QuicStream {
    private var recv: ReceiveStream
    private var closed: Bool = false
    public init(recv: ReceiveStream) { this.recv = recv }
    public func read(buf: Array<UInt8>): Int64 {
        if (closed || recv.isFinReceived()) { return 0 }
        let raw = recv.read()
        if (raw.size == 0) { return 0 }
        let n = if (raw.size > buf.size) { buf.size } else { raw.size }
        var i: Int64 = 0
        while (i < n) { buf[i] = raw[i]; i += 1 }
        n
    }
    public func write(data: Array<UInt8>): Int64 { 0 }
    public func flush(): Unit {}
    public func closeWrite(): Unit {}
    public func closeRead(): Unit { closed = true }
    public func close(): Unit { closed = true }
    public func getStreamId(): UInt64 { 0u64 }
    public func getStreamType(): QuicStreamType { QuicStreamType.UNIDIRECTIONAL }
    public func isClosed(): Bool { closed }
    public func getWrittenData(): Array<UInt8> { [] }
    public func getWrittenString(): String { "" }
}

public class AdapterQuicConnection <: QuicConnection {
    private var conn: Conn
    private var closed: Bool = false
    private var migrationHandler: ?(String) -> Unit = None
    public init(conn: Conn) { this.conn = conn }

    public func openStream(): ?QuicStream {
        match (conn.openStream()) {
            case Some(s) => Some(AdapterQuicStream(s))
            case None => None
        }
    }

    public func openUnidirectionalStream(): ?QuicStream {
        match (conn.openUniStream()) {
            case Some(s) => Some(AdapterSendStream(s))
            case None => None
        }
    }

    public func acceptStream(): ?QuicStream {
        match (conn.acceptStream()) {
            case Some(s) => Some(AdapterQuicStream(s))
            case None => None
        }
    }

    public func acceptUnidirectionalStream(): ?QuicStream {
        match (conn.acceptUniStream()) {
            case Some(s) => Some(AdapterReceiveStream(s))
            case None => None
        }
    }

    public func closeWithError(errorCode: QuicErrorCode, message: String): Unit {
        closed = true
        conn.closeWithError(ec(errorCode), message)
    }

    public func close(): Unit { closed = true }
    public func isClosed(): Bool { closed }
    public func getRemoteAddr(): String { conn.remoteAddr() }
    public func setReadTimeout(timeout: Duration): Unit {
        conn.setReadTimeoutMs(timeout.toMilliseconds())
    }
    public func getConnectionId(): ?Array<UInt8> {
        let state = conn.getConnState()
        if (state.srcConnId.size == 0) { return None }
        Some(state.srcConnId)
    }

    public func migrateTo(addr: String): Bool {
        conn.setRemoteAddr(addr)
        match (migrationHandler) {
            case Some(h) => h(addr)
            case None => ()
        }
        true
    }

    public func setPathMigrationHandler(handler: (String) -> Unit): Unit {
        migrationHandler = Some(handler)
    }

    public func getVersion(): QuicVersion {
        let state = conn.getConnState()
        QuicVersion.fromUInt32(state.version)
    }


    public func sendDatagram(data: Array<UInt8>): Bool {
        conn.sendDatagram(data)
    }

    public func receiveDatagram(): ?Array<UInt8> {
        conn.receiveDatagram()
    }

    public func setDatagramCallback(callback: (Array<UInt8>) -> Unit): Unit {
        conn.setDatagramCallback(Some(callback))
    }
    public func maxDatagramSize(): Int64 { 1200 }

    public func datagramSendQueue(): Int64 { 0 }

    public func canSendEarlyData(): Bool { false }
    public func sendEarlyData(data: Array<UInt8>): Bool { false }
    public func receiveEarlyData(): ?Array<UInt8> { None }
    public func setEarlyDataCallback(callback: ?(Array<UInt8>) -> Unit): Unit {}

}

public class AdapterQuicListener <: QuicListener {
    private var listener: Listener
    private var closed: Bool = false
    public init(listener: Listener) { this.listener = listener }

    public func accept(): ?QuicConnection {
        if (closed) { return None }
        match (listener.accept()) {
            case Some(conn) => Some(AdapterQuicConnection(conn))
            case None => None
        }
    }

    public func close(): Unit { closed = true; listener.close() }
    public func getLocalAddr(): String { listener.addr() }
}

public class QuicCjTransportFactory <: QuicTransportFactory {
    private var name: String
    private var config: Config

    public init(name!: String = "quic_cj") {
        this.name = name
        this.config = Config()
    }

    public func setConfig(cfg: Config): Unit { config = cfg }

    public func listen(host: String, port: UInt16, tlsConfig: H3TlsConfig): ?QuicListener {
        let addr = host + ":" + port.toString()
        config.serverName = tlsConfig.serverName
        // 映射 H3TlsConfig -> quic_cj TlsConfig
        let qTls = QuicTlsConfig()
        qTls.serverName = tlsConfig.serverName
        qTls.alpn = ["h3", "h3-29"]
        config.tlsConfig = Some(qTls)
        match (listen(addr, config)) {
            case Some(listener) => Some(AdapterQuicListener(listener))
            case None => None
        }
    }

    public func dial(host: String, port: UInt16, tlsConfig: H3TlsConfig): ?QuicConnection {
        config.serverName = tlsConfig.serverName
        // 映射 H3TlsConfig -> quic_cj TlsConfig
        let qTls = QuicTlsConfig()
        qTls.serverName = tlsConfig.serverName
        qTls.alpn = ["h3", "h3-29"]
        config.tlsConfig = Some(qTls)
        match (dial(host, port, config)) {
            case Some(conn) => Some(AdapterQuicConnection(conn))
            case None => None
        }
    }

    public func getName(): String { name }

}
