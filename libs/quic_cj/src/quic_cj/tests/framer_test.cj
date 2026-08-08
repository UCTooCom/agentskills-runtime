package quic_cj.tests

import quic_cj.core.Framer
import quic_cj.protocol.EncryptionLevel
import quic_cj.wire.{Frame, PingFrame, CryptoFrame, StreamFrame, MaxDataFrame, MaxStreamDataFrame, MaxStreamsFrame, DataBlockedFrame, StreamDataBlockedFrame, StreamsBlockedFrame}

@Test
public class FramerTestSuite {
    @TestCase
    public func testFramerInitialState(): Unit {
        let f = Framer()
        @Assert(f.hasData(), false)
        let frames = f.getFrames()
        @Assert(frames.size, 0)
    }

    @TestCase
    public func testFramerQueueCrypto(): Unit {
        let f = Framer()
        f.queueCryptoData([0x01u8, 0x02u8, 0x03u8])
        @Assert(f.hasData(), true)
    }

    @TestCase
    public func testFramerQueueMultipleCrypto(): Unit {
        let f = Framer()
        f.queueCryptoData([0x01u8, 0x02u8, 0x03u8])
        f.queueCryptoData([0x04u8, 0x05u8])
        let frames = f.getFrames()
        @Assert(frames.size > 0, true)
    }

    @TestCase
    public func testFramerPriority(): Unit {
        let f = Framer()
        f.queueCryptoData([0x01u8, 0x02u8])
        // 在 getFrames 之后，hasData 应返回 false，直到新数据入队
        _ = f.getFrames()
        @Assert(f.hasData(), false)
        f.queueCryptoData([0x03u8, 0x04u8])
        @Assert(f.hasData(), true)
    }
}

@Test
public class FramerExtendedTestSuite {
    @TestCase
    public func testHandle0RttRejection(): Unit {
        let f = Framer()
        let maxData = MaxDataFrame()
        maxData.maxData = 100
        f.queueFrame(maxData)
        let maxStreamData = MaxStreamDataFrame()
        maxStreamData.streamId = 4
        maxStreamData.maxStreamData = 2000
        f.queueFrame(maxStreamData)
        let maxStreams = MaxStreamsFrame()
        maxStreams.maxStreams = 10
        f.queueFrame(maxStreams)
        let dataBlocked = DataBlockedFrame()
        dataBlocked.maxData = 500
        f.queueFrame(dataBlocked)
        let streamDataBlocked = StreamDataBlockedFrame()
        streamDataBlocked.streamId = 5
        streamDataBlocked.maxStreamData = 300
        f.queueFrame(streamDataBlocked)
        let streamsBlocked = StreamsBlockedFrame()
        streamsBlocked.maxStreams = 5
        f.queueFrame(streamsBlocked)
        f.queueFrame(PingFrame())
        f.queueFrame(CryptoFrame())
        f.handle0RttRejection()
        let frames = f.getFrames()
        @Assert(frames.size, 2)
        @Assert(Int64(frames[0].frameType()), Int64(PingFrame().frameType()))
        @Assert(Int64(frames[1].frameType()), Int64(CryptoFrame().frameType()))
    }

    @TestCase
    public func testFramerSetBlocked(): Unit {
        let f = Framer()
        f.setBlocked(500)
        if (let Some(bf) <- f.getBlockedFrame()) {
            @Assert(bf.getMaxData(), 500)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testFramerSetBlockedDuplicate(): Unit {
        let f = Framer()
        f.setBlocked(500)
        f.setBlocked(500)
        let some1 = match (f.getBlockedFrame()) { case Some(_) => true; case _ => false }
        @Assert(some1, true)
        let none1 = match (f.getBlockedFrame()) { case None => true; case _ => false }
        @Assert(none1, true)
    }

    @TestCase
    public func testFramerGetBlockedNoBlock(): Unit {
        let f = Framer()
        let none2 = match (f.getBlockedFrame()) { case None => true; case _ => false }
        @Assert(none2, true)
    }

    @TestCase
    public func testFramerMaxPayloadLen(): Unit {
        let f = Framer()
        let mtu: Int64 = 1500
        let initialLen = f.maxPayloadLen(mtu, EncryptionLevel.Initial)
        let handshakeLen = f.maxPayloadLen(mtu, EncryptionLevel.Handshake)
        let oneRttLen = f.maxPayloadLen(mtu, EncryptionLevel.OneRTT)
        @Assert(initialLen >= 1200, true)
        @Assert(handshakeLen, mtu - 25)
        @Assert(oneRttLen, mtu - 25)
    }

    @TestCase
    public func testFramerQueueCryptoFrame(): Unit {
        let f = Framer()
        let cf = CryptoFrame()
        cf.data = [0x01u8, 0x02u8, 0x03u8]
        f.queueCryptoFrame(cf)
        @Assert(f.hasData(), true)
        let frames = f.getFrames()
        @Assert(frames.size, 1)
        @Assert(Int64(frames[0].frameType()), Int64(CryptoFrame().frameType()))
    }
}
