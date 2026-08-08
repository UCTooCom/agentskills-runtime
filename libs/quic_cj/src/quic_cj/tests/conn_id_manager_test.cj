package quic_cj.tests

import quic_cj.core.{ConnIDManager, newConnIDManager}
import quic_cj.wire.Frame

@Test
public class ConnIdManagerTestSuite {
    @TestCase
    public func testNewManagerEmpty(): Unit {
        let mgr = newConnIDManager([0x01u8, 0x02u8])
        let id = mgr.get()
        @Assert(id.size, 2)
        @Assert(id[0], 0x01u8)
        @Assert(id[1], 0x02u8)
    }

    @TestCase
    public func testChangeInitialConnId(): Unit {
        let mgr = newConnIDManager([0x01u8, 0x02u8])
        mgr.changeInitialConnId([0x03u8, 0x04u8, 0x05u8])
        let id = mgr.get()
        @Assert(id.size, 3)
        @Assert(id[0], 0x03u8)
    }

    @TestCase
    public func testSetStatelessResetToken(): Unit {
        let mgr = newConnIDManager([0x01u8])
        let token: Array<Byte> = Array<Byte>(16, repeat: 0x42u8)
        mgr.setStatelessResetToken(token)
        @Assert(mgr.isActiveResetToken(token), true)
        @Assert(mgr.isActiveResetToken([0x00u8, 0x01u8]), false)
    }

    @TestCase
    public func testCloseDoesNotClearResetToken(): Unit {
        let mgr = newConnIDManager([0x01u8])
        let token: Array<Byte> = Array<Byte>(16, repeat: 0x42u8)
        mgr.setStatelessResetToken(token)
        @Assert(mgr.isActiveResetToken(token), true)
        mgr.close()
        // 注意：close() 不主动清空 activeResetToken，
        // 而是调用 removeResetToken 回调
        let stillActive = mgr.isActiveResetToken(token)
        @Assert(stillActive, true)
    }

    @TestCase
    public func testSetHandshakeComplete(): Unit {
        let mgr = newConnIDManager([0x01u8])
        mgr.setHandshakeComplete()
        @Assert(true, true)
    }

    @TestCase
    public func testGetConnIdForPathEmptyQueue(): Unit {
        let mgr = newConnIDManager([0x01u8, 0x02u8])
        let none = match (mgr.getConnIdForPath(0)) { case None => true; case _ => false }
        @Assert(none, true)
    }

    @TestCase
    public func testSentPacket(): Unit {
        let mgr = newConnIDManager([0x01u8])
        mgr.sentPacket()
        @Assert(true, true)
    }

    @TestCase
    public func testSetCallbacks(): Unit {
        let mgr = newConnIDManager([0x01u8])
        let addReset: (Array<Byte>) -> Unit = { t => () }
        let removeReset: (Array<Byte>) -> Unit = { t => () }
        let queueFrame: (Frame) -> Unit = { f => () }
        mgr.setCallbacks(addReset, removeReset, queueFrame)
        @Assert(true, true)
    }
}
