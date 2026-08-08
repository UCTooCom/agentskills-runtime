package quic_cj.sys
import quic_cj.protocol.ECN
import std.net.IPAddress


/// NoOobRawConn 是对不支持 OOB 的平台的回退实现。
/// 它不支持 ECN、DF 或 GSO。
public class NoOobRawConn <: RawConn {
    private var host: String
    private var port: Int64
    private var caps: ConnCapabilities = ConnCapabilities()

    public init(host: String, port: Int64) {
        this.host = host
        this.port = port
        caps.ecn = false
        caps.df = false
        caps.gso = false
    }

    public func readPacket(): ReceivedPacket {
        ReceivedPacket()
    }

    public func writePacket(data: Array<Byte>, addr: String, ecn: ECN): Int64 {
        0
    }

    public func localAddr(): IPAddress { IPAddress.parse(host) }
    public func setReadDeadline(deadlineMs: Int64): Unit {}
    public func close(): Unit {}
    public func capabilities(): ConnCapabilities { caps }
}
