package http_lib.connection

import std.collection.ArrayList
import std.io.{InputStream, OutputStream, IOStream}
import std.time.DateTime

/**
 * TLS 连接状态（协商参数）。
 * 提供 TLS 握手结果可见性
 * （如密码套件、协商协议、服务器名称）。
 * 协商的协议和服务器名称）。
 */
public class ConnectionState {
    public let version: String         // TLS 版本字符串（例如 "TLS 1.2"）
    public let cipherSuite: String     // 密码套件名称
    public let negotiatedProtocol: String  // ALPN 协商协议（例如 "h2"、"http/1.1"）
    public let serverName: String      // SNI 服务器名称
    public let isSecure: Bool          // 是否启用了 TLS

    public init(
        version!: String,
        cipherSuite!: String,
        negotiatedProtocol!: String = "",
        serverName!: String = "",
        isSecure!: Bool = false
    ) {
        this.version = version
        this.cipherSuite = cipherSuite
        this.negotiatedProtocol = negotiatedProtocol
        this.serverName = serverName
        this.isSecure = isSecure
    }
}

/**
 * 网络连接接口（实现 std.io.IOStream）。
 * 定义所有连接类型（TCP、TLS）的操作。
 *
 * 所有连接类型必须提供基础 I/O（read/write）、地址查询、超时控制、
 * 连接状态查询和批量写入能力。
 *
 * @see TcpConnection TCP 套接字实现
 * @see TlsConnection TLS 加密连接实现
 * @see TlsServerConnection 服务端 TLS 连接
 * @see BufferedConnection 带写入缓冲区的装饰器
 * @see MockConnection 内存模拟连接（测试用）
 */
public interface Connection <: Resource & IOStream {
    func isConnected(): Bool
    func canReuseTransport(): Bool
    func isReadable(timeout: ?Duration): Bool
    func isWritable(timeout: ?Duration): Bool
    func read(buf: Array<UInt8>): Int64
    func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64
    func write(data: Array<UInt8>): Unit
    func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit
    func close(): Unit
    func localAddress(): String
    func remoteAddress(): String
    func connectedAt(): DateTime
    func lastActivityAt(): DateTime
    func updateActivity(): Unit
    func setReadTimeout(timeout: Duration): Unit
    func setWriteTimeout(timeout: Duration): Unit
    func setTimeout(timeout: Duration): Unit
    /**
     * 在可能的情况下在单个 I/O 操作中写入多个缓冲区。
     * 与为每个缓冲区单独调用 write() 相比，减少系统调用次数。
     * 默认实现连接各缓冲区；平台特定实现可能使用 writev。
     */
    func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit
    // 批量写入多个缓冲区，减少系统调用
    /**
     * 获取握手后的 TLS 连接状态。
     * 对非 TLS 连接（例如纯 TCP）返回 None。
     */
    func connectionState(): ?ConnectionState
}

/**
 * 辅助函数：将多个字节数组合并为一个。
 * 由 writeBuffers() 实现使用以减少系统调用次数。
 *
 * 直接逐字节拷贝以兼容平台 API，性能可满足 HTTP 场景需求。
 */
public func concatBuffers(buffers: ArrayList<Array<UInt8>>): Array<UInt8> {
    var total: Int64 = 0
    for (b in buffers) { total += b.size }
    if (total == 0) { return [] }
    let result = Array<UInt8>(total, repeat: 0)
    var offset: Int64 = 0
    for (b in buffers) {
        if (b.size > 0) {
            b.copyTo(result, 0, offset, b.size)
            offset += b.size
        }
    }
    result
}
