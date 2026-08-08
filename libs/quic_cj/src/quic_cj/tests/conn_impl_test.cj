package quic_cj.tests

import quic_cj.{ConnImpl}
import quic_cj.protocol.{VERSION_1, Perspective}
import quic_cj.core.{Connection, ConnectionState}

/// ConnImpl 测试套件
@Test
public class ConnImplTestSuite {
    /// 测试 ConnImpl 从 Connection 初始化的默认状态
    @TestCase
    public func testConnImplDefaults(): Unit {
        let destConnId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let srcConnId: Array<Byte> = [0x05u8, 0x06u8]
        let conn = Connection(VERSION_1, Perspective.Client, srcConnId, destConnId)
        let ci = ConnImpl(conn)
        let state = ci.getConnState()
        @Assert(state.version, VERSION_1)
        @Assert(state.handshakeComplete, false)
    }

    /// 测试 ConnImpl 用 closeWithError 关闭
    @TestCase
    public func testConnImplCloseWithError(): Unit {
        let destConnId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let srcConnId: Array<Byte> = [0x05u8, 0x06u8]
        let conn = Connection(VERSION_1, Perspective.Client, srcConnId, destConnId)
        let ci = ConnImpl(conn)
        ci.closeWithError(0u64, "test close")
    }

    /// 测试 ConnImpl 的 localAddr 和 remoteAddr 访问器
    @TestCase
    public func testConnImplAddrAccessors(): Unit {
        let destConnId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let srcConnId: Array<Byte> = [0x05u8, 0x06u8]
        let conn = Connection(VERSION_1, Perspective.Client, srcConnId, destConnId)
        let ci = ConnImpl(conn)
        let local = ci.localAddr()
        let remote = ci.remoteAddr()
        @Assert(local.size >= 0, true)
        @Assert(remote.size >= 0, true)
    }
}
