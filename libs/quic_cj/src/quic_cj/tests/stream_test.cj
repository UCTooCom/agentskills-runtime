package quic_cj.tests

import quic_cj.protocol.{StreamType, Perspective}
import quic_cj.stream.{Stream, StreamState, SendStream, ReceiveStream, CryptoStream}
import quic_cj.wire.{StreamFrame, ResetStreamFrame, StopSendingFrame}

@Test
public class StreamTestSuite {
    @TestCase
    public func testStreamCreation(): Unit {
        let s = Stream(0, StreamType.Bidi, Perspective.Client)
        @Assert(s.getStreamId(), 0)
        let isIdle = match (s.getState()) { case StreamState.Idle => true; case _ => false }
        @Assert(isIdle, true)
    }

    @TestCase
    public func testSendStreamWrite(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(65535)
        let n = ss.write([0x01u8, 0x02u8, 0x03u8])
        @Assert(n, 3)
        @Assert(ss.getOffset(), 3)
    }

    @TestCase
    public func testReceiveStream(): Unit {
        let rs = ReceiveStream()
        let data: Array<Byte> = [0x0au8, 0x0bu8]
        let frame = StreamFrame()
        frame.streamId = 4
        frame.data = data
        rs.handleStreamFrame(frame)
        let read = rs.read()
        @Assert(read, data)
    }

    @TestCase
    public func testCryptoStreamCreation(): Unit {
        let cs = CryptoStream(Perspective.Client)
        cs.writeCryptoData([0x01u8, 0x02u8])
        let data = cs.readCryptoData()
        @Assert(data.size, 2)
    }
}


@Test
public class StreamResetTestSuite {
    @TestCase
    public func testReceiveStreamResetSetsFlags(): Unit {
        let rs = ReceiveStream()
        let frame = ResetStreamFrame(0, 0u64, 100)
        rs.handleResetStreamFrame(frame)
        @Assert(rs.isFinReceived(), true)
        @Assert(rs.isResetReceived(), true)
        @Assert(rs.getFinalSize(), 100)
    }

    @TestCase
    public func testReceiveStreamIgnoresFrameAfterReset(): Unit {
        let rs = ReceiveStream()
        let resetFrame = ResetStreamFrame(0, 0u64, 100)
        rs.handleResetStreamFrame(resetFrame)
        // After reset, stream frames should be ignored
        let streamFrame = StreamFrame()
        streamFrame.streamId = 0
        streamFrame.data = [0x01u8, 0x02u8]
        rs.handleStreamFrame(streamFrame)
        let data = rs.read()
        @Assert(data.size, 0)  // Data should not accumulate after reset
    }

    @TestCase
    public func testSendStreamStopSendingTriggersReset(): Unit {
        let ss = SendStream()
        ss.write([0x01u8, 0x02u8, 0x03u8])
        let frame = StopSendingFrame()
        frame.streamId = 0
        ss.handleStopSendingFrame(frame)
        @Assert(ss.isResetSent(), true)
        // Data should be cleared after stop sending
        let data = ss.getDataForSending(100)
        @Assert(data.size, 0)
    }

    @TestCase
    public func testSendStreamStopSendingNoEffectIfFinSent(): Unit {
        let ss = SendStream()
        ss.write([0x01u8, 0x02u8])
        ss.close()
        @Assert(ss.isFinSent(), true)
        let frame = StopSendingFrame()
        frame.streamId = 0
        // stop_sending_processed flag might not be exposed via public API,
        // but finSent should remain true
        ss.handleStopSendingFrame(frame)
        @Assert(ss.isFinSent(), true)
    }

    @TestCase
    public func testUpdateSendWindowIncreasesMax(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(1000)
        // write 500 bytes
        ss.write(Array<Byte>(500, repeat: 0xabu8))
        @Assert(ss.getOffset(), 500)
        // After writing 500, we can write more if window allows
        ss.updateSendWindow(2000)
        let more = ss.write(Array<Byte>(1500, repeat: 0xbbu8))
        @Assert(more, 1500)
    }

    @TestCase
    public func testUpdateSendWindowDoesNotDecrease(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(1000)
        ss.updateSendWindow(500)  // Should not decrease
        let n = ss.write(Array<Byte>(800, repeat: 0xabu8))
        @Assert(n, 800)  // Should be able to write 800
    }

    @TestCase
    public func testReceiveStreamHandleResetValidFinalSize(): Unit {
        let rs = ReceiveStream()
        let frame = ResetStreamFrame(0, 0u64, 50)
        // Receive some data first
        let sf = StreamFrame()
        sf.streamId = 0
        sf.data = Array<Byte>(30, repeat: 0xabu8)
        rs.handleStreamFrame(sf)
        @Assert(rs.getOffset(), 30)
        // Reset with finalSize=50 is consistent (30 < 50)
        rs.handleResetStreamFrame(frame)
        @Assert(rs.isResetReceived(), true)
        @Assert(rs.isFinReceived(), true)
        @Assert(rs.getFinalSize(), 50)
    }
}
