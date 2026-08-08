package quic_cj.tests

import quic_cj.core.{ClosedLocalConn, ClosedRemoteConn, newClosedLocalConn, newClosedRemoteConn}

@Test
public class ClosedConnTestSuite {
    @TestCase
    public func testClosedLocalConnInitial(): Unit {
        let sent: Array<Int64> = [0]
        let cb = { addr: String => sent[0] += 1 }
        let conn = newClosedLocalConn(cb)
        conn.destroy()
        @Assert(sent[0], 0)
    }

    @TestCase
    public func testClosedLocalConnHandlePacket(): Unit {
        let sendCount: Array<Int64> = [0]
        let cb = { addr: String => sendCount[0] += 1 }
        let conn = newClosedLocalConn(cb)
        // 第 1 个包应触发发送（2^0 = 1）
        conn.handlePacket("127.0.0.1:4433")
        @Assert(sendCount[0], 1)
        // 第 2 个包应触发（2^1 = 2）
        conn.handlePacket("127.0.0.1:4433")
        @Assert(sendCount[0], 2)
        // 第 3 个包不应触发
        conn.handlePacket("127.0.0.1:4433")
        @Assert(sendCount[0], 2)
        // 第 4 个包应触发（2^2 = 4）
        conn.handlePacket("127.0.0.1:4433")
        @Assert(sendCount[0], 3)
    }

    @TestCase
    public func testClosedRemoteConn(): Unit {
        let conn = newClosedRemoteConn()
        conn.handlePacket()
        conn.destroy()
        @Assert(true, true)
    }
}
