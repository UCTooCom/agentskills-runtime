package quic_cj.sys

import quic_cj.protocol.{ECN, MAX_PACKET_BUFFER_SIZE}
import quic_cj.wire.PacketBuffer
import std.net.IPAddress

/// 描述 UDP 连接的能力。
public class ConnCapabilities {
    public var df: Bool = false   // 支持不分片位
    public var gso: Bool = false  // 支持通用分段卸载
    public var ecn: Bool = false  // 支持 ECN
}

/// 表示从 UDP 套接字收到的包。
public class ReceivedPacket {
    public var data: Array<Byte> = []
    public var remoteAddr: String = ""
    public var ecn: ECN = ECN.Unsupported
    public var packetInfo: Array<Byte> = []
    public var buffer: PacketBuffer = PacketBuffer(MAX_PACKET_BUFFER_SIZE)
}

/// RawConn 是 UDP 套接字操作的接口（类似于 quic-go 的 rawConn）。
open public class RawConn {
    /// 读取单个 UDP 包。
    open public func readPacket(): ReceivedPacket {
        throw Exception("RawConn.readPacket: not implemented")
    }

    /// 向 UDP 套接字写入一个包。
    /// 返回写入的字节数。
    open public func writePacket(data: Array<Byte>, addr: String, ecn: ECN): Int64 {
        throw Exception("RawConn.writePacket: not implemented")
    }

    /// 返回套接字的本地地址。
    open public func localAddr(): IPAddress {
        throw Exception("RawConn.localAddr: not implemented")
    }

    /// 设置套接字的读取截止时间。
    open public func setReadDeadline(deadlineMs: Int64): Unit {
        throw Exception("RawConn.setReadDeadline: not implemented")
    }

    /// 关闭套接字。
    open public func close(): Unit {
        throw Exception("RawConn.close: not implemented")
    }

    /// 返回套接字的能力。
    open public func capabilities(): ConnCapabilities {
        ConnCapabilities()
    }
}

/// 将 UDP 套接字包装为 RawConn。
/// 在 Linux 上，它尝试设置 ECN、DF 和 GSO。
@When[os != "Linux"]
public func newRawConn(host: String, port: Int64): RawConn {
    StubRawConn(host, port)
}

/// StubRawConn 是未实现平台的占位实现。
public class StubRawConn <: RawConn {
    private var host: String
    private var port: Int64

    public init(host: String, port: Int64) {
        this.host = host
        this.port = port
    }

    public func localAddr(): IPAddress { IPAddress.parse(host) }
    public func capabilities(): ConnCapabilities { ConnCapabilities() }
}

/// 平台特定的套接字创建函数。
public func createUdpSocket(host: String, port: Int64): Int64 {
    -1
}

/// 在 UDP 套接字上设置 QUIC 所需的套接字选项。
public func setSocketOptions(fd: Int64): Bool { false }

/// 从原始文件描述符读取一个包。
public func readPacketFromFd(fd: Int64): Array<Byte> { [] }

/// 向原始文件描述符写入一个包。
public func writePacketToFd(fd: Int64, data: Array<Byte>, addr: Array<Byte>): Int64 { -1 }
