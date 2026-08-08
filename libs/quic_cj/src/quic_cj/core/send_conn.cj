package quic_cj.core

import quic_cj.protocol.ECN
import quic_cj.sys.{RawConn, ConnCapabilities}
import std.net.IPAddress

/// SendConn 封装 RawConn，提供 GSO 支持和远端地址管理。
/// 这对应于 quic-go 的 send_conn.go / sconn 类型。
public class SendConn {
    private var raw: RawConn = RawConn()
    private var localAddrStr: IPAddress = IPAddress.parse("0.0.0.0")
    private var remoteAddrStr: String = ""
    private var gotGsoError: Bool = false
    private var wroteFirstPacket: Bool = false
    private var caps: ConnCapabilities = ConnCapabilities()

    public init(rawConn: RawConn, remoteAddr: String, localAddr: IPAddress) {
        this.raw = rawConn
        this.remoteAddrStr = remoteAddr
        this.localAddrStr = localAddr
        this.caps = rawConn.capabilities()
    }

    /// Write 发送一个包到远端地址，支持可选的 GSO。
    public func write(data: Array<Byte>, gsoSize: UInt16, ecn: ECN): Unit {
        if (gotGsoError && gsoSize > 0u16) {
            var offset: Int64 = 0
            let segSize = Int64(gsoSize)
            while (offset < data.size) {
                var end = offset + segSize
                if (end > data.size) { end = data.size }
                raw.writePacket(data[offset..end], remoteAddrStr, ecn)
                offset = end
            }
            return
        }

        var sent = raw.writePacket(data, remoteAddrStr, ecn)
        if (sent <= 0) {
            if (gsoSize > 0u16) {
                gotGsoError = true
                var offset: Int64 = 0
                let gSize = Int64(gsoSize)
                while (offset < data.size) {
                    var next = offset + gSize
                    if (next > data.size) { next = data.size }
                    raw.writePacket(data[offset..next], remoteAddrStr, ecn)
                    offset = next
                }
            }
        }
        wroteFirstPacket = true
    }

    /// WriteTo 发送一个包到任意地址。
    public func writeTo(data: Array<Byte>, addr: String): Unit {
        raw.writePacket(data, addr, ECN.Unsupported)
        ()
    }

    /// ChangeRemoteAddr 更改远端地址。
    public func changeRemoteAddr(addr: String): Unit {
        remoteAddrStr = addr
    }

    /// LocalAddr 返回本地地址。
    public func localAddr(): IPAddress { localAddrStr }

    /// RemoteAddr 返回远端地址。
    public func remoteAddr(): String { remoteAddrStr }

    /// Capabilities 返回连接能力信息。
    public func capabilities(): ConnCapabilities {
        let c = ConnCapabilities()
        c.df = caps.df
        c.ecn = caps.ecn
        c.gso = caps.gso && !gotGsoError
        c
    }

    /// Close 关闭底层原始连接。
    public func close(): Unit {
        raw.close()
    }
}
