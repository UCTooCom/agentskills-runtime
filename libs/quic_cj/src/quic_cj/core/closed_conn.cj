package quic_cj.core

/// ClosedLocalConn 是由本地关闭的连接。
/// 当收到此类连接的包时，重传 CONNECTION_CLOSE 帧（指数退避）。
public class ClosedLocalConn {
    private var counter: UInt32 = 0u32
    private var sendPacket: (String) -> Unit = { str => () }

    public init(sendPacket: (String) -> Unit) {
        this.sendPacket = sendPacket
    }

    /// 处理收到的包。按指数退避发送 CONNECTION_CLOSE。
    /// 仅在第 1、2、4、8、16... 个包时发送。
    public func handlePacket(remoteAddr: String): Unit {
        counter += 1u32
        // 仅当 counter 是 2 的幂时发送
        if (isPowerOfTwo(counter)) {
            sendPacket(remoteAddr)
        }
    }

    public func destroy(): Unit {}
}

private func isPowerOfTwo(n: UInt32): Bool {
    n > 0u32 && (n & (n - 1u32)) == 0u32
}

/// ClosedRemoteConn 是由远端关闭的连接。
/// 忽略所有后续收到的包。
public class ClosedRemoteConn {
    public init() {}
    public func handlePacket(): Unit {}
    public func destroy(): Unit {}
}

public func newClosedLocalConn(sendPacket: (String) -> Unit): ClosedLocalConn {
    ClosedLocalConn(sendPacket)
}

public func newClosedRemoteConn(): ClosedRemoteConn { ClosedRemoteConn() }
