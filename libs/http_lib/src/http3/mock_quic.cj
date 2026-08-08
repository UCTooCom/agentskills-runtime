/**
 * Mock QUIC 实现。
 * 用于 HTTP/3 单元测试：提供模拟 QUIC 流和连接的内存实现。
 *
 * 注意：本文件是 http3_test.cj 中 Mock 类的独立版本，
 * 抽取到独立文件以避免 Cangjie 测试工具链的循环依赖检测。
 */
package http_lib.http3

import std.collection.ArrayList
import std.sync.Mutex

public class MockQuicStream <: QuicStream {
    private var readData: ArrayList<UInt8>
    private var writeData: ArrayList<UInt8>
    private var streamId: UInt64
    private var streamType: QuicStreamType
    private var readClosed: Bool = false
    private var writeClosed: Bool = false
    private var fullyClosed: Bool = false
    private var readIndex: Int64 = 0

    public init(data!: Array<UInt8> = [], streamId!: UInt64 = 0, streamType!: QuicStreamType = QuicStreamType.BIDIRECTIONAL) {
        this.readData = ArrayList<UInt8>()
        for (b in data) { readData.add(b) }
        this.writeData = ArrayList<UInt8>()
        this.streamId = streamId
        this.streamType = streamType
    }

    /**
     * 添加更多可读数据。
     */
    public func addReadData(data: Array<UInt8>): Unit {
        for (b in data) { readData.add(b) }
    }

    /**
     * 获取已写入的数据。
     */
    public func getWrittenData(): Array<UInt8> {
        writeData.toArray()
    }

    /**
     * 获取写入数据字符串。
     */
    public func getWrittenString(): String {
        String.fromUtf8(writeData.toArray())
    }

    public func read(buf: Array<UInt8>): Int64 {
        if (readClosed || readIndex >= readData.size) { return 0 }
        var count: Int64 = 0
        while (count < buf.size && readIndex < readData.size) {
            buf[count] = readData[readIndex]
            readIndex += 1
            count += 1
        }
        count
    }

    public func write(data: Array<UInt8>): Int64 {
        if (writeClosed) { return 0 }
        for (b in data) { writeData.add(b) }
        data.size
    }

    public func flush(): Unit {}

    public func closeWrite(): Unit { writeClosed = true }
    public func closeRead(): Unit { readClosed = true }
    public func close(): Unit { fullyClosed = true; readClosed = true; writeClosed = true }
    public func getStreamId(): UInt64 { streamId }
    public func getStreamType(): QuicStreamType { streamType }
    public func isClosed(): Bool { fullyClosed }

    public func getReadIndex(): Int64 { readIndex }
    public func getAllWrittenData(): ArrayList<UInt8> { writeData }
    public func canSendEarlyData(): Bool { false }
    public func sendEarlyData(data: Array<UInt8>): Bool { false }
    public func receiveEarlyData(): ?Array<UInt8> { None }
    public func setEarlyDataCallback(callback: ?(Array<UInt8>) -> Unit): Unit {}
}

/**
 * Mock QUIC 连接实现。
 * 模拟 QUIC 连接的流管理。
 */
public class MockQuicConnection <: QuicConnection {
    private var serverMode: Bool
    private var incomingBidirStreams: ArrayList<QuicStream>
    private var incomingUnidirStreams: ArrayList<QuicStream>
    private var outgoingBidirStreams: ArrayList<QuicStream>
    private var outgoingUnidirStreams: ArrayList<QuicStream>
    private var streamIdCounter: UInt64 = 0
    private var closed: Bool = false
    private var remoteAddr: String = ""
    private var lastError: (?QuicErrorCode, String) = (None, "")
    private var acceptedBidirIndex: Int64 = 0
    private var acceptedUnidirIndex: Int64 = 0
    private var mu: Mutex = Mutex()
    private var migrationHandler: ?(String) -> Unit = None

    private var sentDatagrams: ArrayList<Array<UInt8>> = ArrayList<Array<UInt8>>()
    private var receivedDatagrams: ArrayList<Array<UInt8>> = ArrayList<Array<UInt8>>()
    private var datagramCallback: ?(Array<UInt8>) -> Unit = None

    public init(serverMode!: Bool = false) {
        this.serverMode = serverMode
        this.incomingBidirStreams = ArrayList<QuicStream>()
        this.incomingUnidirStreams = ArrayList<QuicStream>()
        this.outgoingBidirStreams = ArrayList<QuicStream>()
        this.outgoingUnidirStreams = ArrayList<QuicStream>()
    }

    /**
     * 添加一个入站双向流（模拟对端打开的流）。
     */
    public func addIncomingBidirStream(stream: QuicStream): Unit {
        incomingBidirStreams.add(stream)
    }

    /**
     * 添加一个入站单向流。
     */
    public func addIncomingUnidirStream(stream: QuicStream): Unit {
        incomingUnidirStreams.add(stream)
    }

    /**
     * 获取已打开的出站双向流。
     */
    public func getOutgoingBidirStreams(): ArrayList<QuicStream> {
        outgoingBidirStreams
    }

    /**
     * 获取已打开的出站单向流。
     */
    public func getOutgoingUnidirStreams(): ArrayList<QuicStream> {
        outgoingUnidirStreams
    }

    public func openStream(): ?QuicStream {
        let id = streamIdCounter
        streamIdCounter += 1
        let stream = MockQuicStream(streamId: id * 2, streamType: QuicStreamType.BIDIRECTIONAL)
        outgoingBidirStreams.add(stream)
        Some(stream)
    }

    public func openUnidirectionalStream(): ?QuicStream {
        let id = streamIdCounter
        streamIdCounter += 1
        let stream = MockQuicStream(streamId: id * 2 + 1, streamType: QuicStreamType.UNIDIRECTIONAL)
        outgoingUnidirStreams.add(stream)
        Some(stream)
    }

    public func acceptStream(): ?QuicStream {
        if (acceptedBidirIndex < incomingBidirStreams.size) {
            let s = incomingBidirStreams[acceptedBidirIndex]
            acceptedBidirIndex += 1
            return Some(s)
        }
        None
    }

    public func acceptUnidirectionalStream(): ?QuicStream {
        if (acceptedUnidirIndex < incomingUnidirStreams.size) {
            let s = incomingUnidirStreams[acceptedUnidirIndex]
            acceptedUnidirIndex += 1
            return Some(s)
        }
        None
    }

    public func closeWithError(errorCode: QuicErrorCode, message: String): Unit {
        lastError = (Some(errorCode), message)
        closed = true
    }

    public func close(): Unit { closed = true }

    public func isClosed(): Bool { closed }

    public func getRemoteAddr(): String { remoteAddr }

    public func setRemoteAddr(addr: String): Unit { remoteAddr = addr }

    public func setReadTimeout(timeout: Duration): Unit {}

    public func getLastError(): (?QuicErrorCode, String) { lastError }

    public func getConnectionId(): ?Array<UInt8> {
        None
    }

    public func migrateTo(addr: String): Bool {
        remoteAddr = addr
        match (migrationHandler) {
            case Some(handler) => handler(addr)
            case None => ()
        }
        true
    }

    public func setPathMigrationHandler(handler: (String) -> Unit): Unit {
        migrationHandler = Some(handler)
    }

    public func getVersion(): QuicVersion {
        QuicVersion.V1
    }


    public func sendDatagram(data: Array<UInt8>): Bool {
        sentDatagrams.add(data)
        true
    }

    public func receiveDatagram(): ?Array<UInt8> {
        if (receivedDatagrams.size == 0) { return None }
        let d = receivedDatagrams[0]
        receivedDatagrams.remove(0..1)
        Some(d)
    }

    public func setDatagramCallback(callback: (Array<UInt8>) -> Unit): Unit {
        datagramCallback = Some(callback)
    }

    public func maxDatagramSize(): Int64 { 1200 }

    public func datagramSendQueue(): Int64 { 0 }

    public func canSendEarlyData(): Bool { false }
    public func sendEarlyData(data: Array<UInt8>): Bool { false }
    public func receiveEarlyData(): ?Array<UInt8> { None }
    public func setEarlyDataCallback(callback: ?(Array<UInt8>) -> Unit): Unit {}

    /**
     * 添加入站数据报（测试用）。
     */
    public func addIncomingDatagram(data: Array<UInt8>): Unit {
        receivedDatagrams.add(data)
        match (datagramCallback) {
            case Some(cb) => cb(data)
            case None => ()
        }
    }

    /**
     * 获取已发送的所有数据报（测试用）。
     */
    public func getSentDatagrams(): ArrayList<Array<UInt8>> {
        sentDatagrams
    }

}
