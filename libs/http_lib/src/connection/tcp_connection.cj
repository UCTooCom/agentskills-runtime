package http_lib.connection

import std.collection.ArrayList
import std.net.TcpSocket
import std.time.DateTime

/**
 * TCP 套接字连接（封装 std.net.TcpSocket）。
 *
 * 实现 Connection 接口，提供 TCP 层面的读写、连接状态管理、
 * 超时控制、地址查询和活动时间跟踪。
 * 内部维护连接时间、最后活动时间等元数据，用于连接池的
 * 空闲淘汰和健康检查。
 */
public class TcpConnection <: Connection {
    private var socket: TcpSocket
    private var closed: Bool = false
    private var connTime: DateTime = DateTime.now()
    private var lastActive: DateTime = DateTime.now()
    /// 建立连接后的本地地址缓存
    private var remoteHost: String = ""
    /// 建立连接后的远程端口缓存
    private var remotePort: UInt16 = 0

    public init(socket: TcpSocket, remoteHost!: String = "", remotePort!: UInt16 = 0) {
        this.socket = socket
        this.remoteHost = remoteHost
        this.remotePort = remotePort
        socket.noDelay = true
    }

    /**
     * 快速连接工厂方法：使用默认超时建立 TCP 连接。
     *
     * @param host 目标主机名或 IP 地址
     * @param port 目标端口
     * @return 已建立的 TcpConnection
     */
    public static func connect(host: String, port: UInt16): TcpConnection {
        connect(host, port, connectTimeout: Duration.second * 30, readTimeout: Duration.second * 30, writeTimeout: Duration.second * 30)
    }

    /**
     * 完整连接工厂方法：使用自定义超时建立 TCP 连接。
     *
     * 在套接字上设置 TCP_NODELAY 以禁用 Nagle 算法，降低交互延迟。
     *
     * @param host 目标主机名或 IP 地址
     * @param port 目标端口
     * @param connectTimeout 连接建立超时
     * @param readTimeout 读取超时
     * @param writeTimeout 写入超时
     * @return 已建立的 TcpConnection
     */
    public static func connect(
        host: String,
        port: UInt16,
        connectTimeout!: Duration,
        readTimeout!: Duration,
        writeTimeout!: Duration
    ): TcpConnection {
        let socket = TcpSocket(host, port)
        socket.noDelay = true
        socket.readTimeout = readTimeout
        socket.writeTimeout = writeTimeout
        socket.connect(timeout: connectTimeout)
        TcpConnection(socket, remoteHost: host, remotePort: port)
    }

    /// 连接已关闭则返回 false；否则返回 true。
    public func isConnected(): Bool { !closed }
    /// 连接可重用于传输则返回 true；等同于 isConnected()。
    public func canReuseTransport(): Bool { !closed }
    /// 连接可读则返回 true；忽略 timeout 参数（当前由底层 TcpSocket 控制）。
    public func isReadable(timeout: ?Duration): Bool { !closed }
    /// 连接可写则返回 true；忽略 timeout 参数（当前由底层 TcpSocket 控制）。
    public func isWritable(timeout: ?Duration): Bool { !closed }

    public func read(buf: Array<UInt8>): Int64 {
        updateActivity()
        socket.read(buf)
    }

    public func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        updateActivity()
        if (offset < 0 || length < 0 || offset + length > buf.size) {
            throw Exception("read offset/length out of bounds")
        }
        if (length == 0) { return 0 }
        if (offset == 0 && length == buf.size) { return read(buf) }
        let temp = Array<UInt8>(length, repeat: 0)
        let n = socket.read(temp)
        if (n > 0) {
            var i: Int64 = 0
            while (i < n) {
                buf[offset + i] = temp[i]
                i++
            }
        }
        n
    }

    public func write(data: Array<UInt8>): Unit {
        updateActivity()
        socket.write(data)
    }

    public func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit {
        updateActivity()
        if (offset == 0 && length == data.size) { socket.write(data); return }
        let temp = Array<UInt8>(length, repeat: 0)
        var i: Int64 = 0
        while (i < length) {
            temp[i] = data[offset + i]
            i++
        }
        socket.write(temp)
    }

    public func flush(): Unit {}

    public func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit {
        if (buffers.size == 1) {
            socket.write(buffers[0])
        } else {
            let combined = concatBuffers(buffers)
            if (combined.size > 0) { socket.write(combined) }
        }
    }

    public func close(): Unit {
        socket.close()
        closed = true
    }

    public func isClosed(): Bool { closed }

    /**
     * 获取此连接的本地地址。
     *
     * 注意：std.net.TcpSocket 当前未暴露查询方法
     * 绑定的本地地址/端口。返回 "0.0.0.0" 作为占位符。
     * 如果未来 socket API 增加了本地地址查询方法，
     * 用实际的绑定地址替换此处。
     */
    public func localAddress(): String { "0.0.0.0" }
    public func remoteAddress(): String { "${remoteHost}:${remotePort}" }
    public func connectedAt(): DateTime { connTime }
    public func lastActivityAt(): DateTime { lastActive }
    public func updateActivity(): Unit { lastActive = DateTime.now() }

    public func setReadTimeout(timeout: Duration): Unit {
        socket.readTimeout = timeout
    }

    public func setWriteTimeout(timeout: Duration): Unit {
        socket.writeTimeout = timeout
    }

    public func setTimeout(timeout: Duration): Unit {
        socket.readTimeout = timeout
        socket.writeTimeout = timeout
    }

    public func connectionState(): ?ConnectionState { None }
}
