package quic_cj.tests

import quic_cj.core.{RetransmissionQueue, newRetransmissionQueue}
import quic_cj.protocol.EncryptionLevel
import quic_cj.wire.{Frame, PingFrame, CryptoFrame}

@Test
public class RetransmissionQueueTestSuite {
    @TestCase
    public func testNewQueueEmpty(): Unit {
        let q = newRetransmissionQueue()
        @Assert(q.hasData(EncryptionLevel.Initial), false)
        @Assert(q.hasData(EncryptionLevel.Handshake), false)
        @Assert(q.hasData(EncryptionLevel.OneRTT), false)
    }

    @TestCase
    public func testAddAndGetInitialCrypto(): Unit {
        let q = newRetransmissionQueue()
        let cf = CryptoFrame()
        cf.data = [0x01u8, 0x02u8, 0x03u8]
        q.addInitial(cf)
        @Assert(q.hasData(EncryptionLevel.Initial), true)
        let some1 = match (q.getFrame(EncryptionLevel.Initial)) { case Some(_) => true; case _ => false }
        @Assert(some1, true)
    }

    @TestCase
    public func testAddAndGetHandshake(): Unit {
        let q = newRetransmissionQueue()
        let pf = PingFrame()
        q.addHandshake(pf)
        @Assert(q.hasData(EncryptionLevel.Handshake), true)
        let some2 = match (q.getFrame(EncryptionLevel.Handshake)) { case Some(_) => true; case _ => false }
        @Assert(some2, true)
    }

    @TestCase
    public func testAddAndGetAppData(): Unit {
        let q = newRetransmissionQueue()
        let pf = PingFrame()
        q.addAppData(pf)
        @Assert(q.hasData(EncryptionLevel.OneRTT), true)
        let some3 = match (q.getFrame(EncryptionLevel.OneRTT)) { case Some(_) => true; case _ => false }
        @Assert(some3, true)
    }

    @TestCase
    public func testDropPackets(): Unit {
        let q = newRetransmissionQueue()
        let cf = CryptoFrame()
        cf.data = [0x01u8]
        q.addInitial(cf)
        @Assert(q.hasData(EncryptionLevel.Initial), true)
        q.dropPackets(EncryptionLevel.Initial)
        @Assert(q.hasData(EncryptionLevel.Initial), false)
    }

    @TestCase
    public func testGetFrameEmpty(): Unit {
        let q = newRetransmissionQueue()
        let none = match (q.getFrame(EncryptionLevel.Initial)) { case None => true; case _ => false }
        @Assert(none, true)
    }
}
