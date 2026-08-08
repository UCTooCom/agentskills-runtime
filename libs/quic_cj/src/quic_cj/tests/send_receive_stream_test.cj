package quic_cj.tests

import quic_cj.stream.{SendStream, ReceiveStream}
import quic_cj.wire.StreamFrame

@Test
public class SendStreamTestSuite {
    @TestCase
    public func testSendStreamEmptyWrite(): Unit {
        let ss = SendStream()
        let n = ss.write([])
        @Assert(n, 0)
        @Assert(ss.getOffset(), 0)
    }

    @TestCase
    public func testSendStreamMultipleWrites(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(65535)
        ss.write([0x01u8, 0x02u8])
        @Assert(ss.getOffset(), 2)
        ss.write([0x03u8, 0x04u8, 0x05u8])
        @Assert(ss.getOffset(), 5)
    }

    @TestCase
    public func testSendStreamClose(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(65535)
        ss.write([0x01u8, 0x02u8])
        ss.close()
        @Assert(ss.isFinSent(), true)
        let n = ss.write([0x03u8])
        @Assert(n, 0)
    }

    @TestCase
    public func testSendStreamDataForSendingPartial(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(65535)
        ss.write([0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8])
        let partial = ss.getDataForSending(3)
        @Assert(partial.size, 3)
        @Assert(partial[0], 0x01u8)
        @Assert(partial[1], 0x02u8)
        @Assert(partial[2], 0x03u8)
    }

    @TestCase
    public func testSendStreamDataForSendingFull(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(65535)
        ss.write([0x01u8, 0x02u8])
        let full = ss.getDataForSending(100)
        @Assert(full.size, 2)
    }

    @TestCase
    public func testSendStreamDataSentPartial(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(65535)
        ss.write([0x01u8, 0x02u8, 0x03u8])
        ss.dataSent(2)
        let remaining = ss.getDataForSending(100)
        @Assert(remaining.size, 1)
        @Assert(remaining[0], 0x03u8)
    }

    @TestCase
    public func testSendStreamDataSentAll(): Unit {
        let ss = SendStream()
        ss.updateSendWindow(65535)
        ss.write([0x01u8, 0x02u8])
        ss.dataSent(2)
        let remaining = ss.getDataForSending(100)
        @Assert(remaining.size, 0)
    }
}

@Test
public class ReceiveStreamTestSuite {
    @TestCase
    public func testReceiveStreamEmpty(): Unit {
        let rs = ReceiveStream()
        let data = rs.read()
        @Assert(data.size, 0)
    }

    @TestCase
    public func testReceiveStreamSingleFrame(): Unit {
        let rs = ReceiveStream()
        let frame = StreamFrame()
        frame.streamId = 4
        frame.offset = 0
        frame.data = [0x0au8, 0x0bu8, 0x0cu8]
        rs.handleStreamFrame(frame)
        let data = rs.read()
        @Assert(data.size, 3)
        @Assert(data[0], 0x0au8)
        @Assert(data[1], 0x0bu8)
        @Assert(data[2], 0x0cu8)
    }

    @TestCase
    public func testReceiveStreamWithFin(): Unit {
        let rs = ReceiveStream()
        let frame = StreamFrame()
        frame.streamId = 4
        frame.offset = 0
        frame.fin = true
        frame.data = [0xaau8]
        rs.handleStreamFrame(frame)
        @Assert(rs.isFinReceived(), true)
        let data = rs.read()
        @Assert(data.size, 1)
        @Assert(data[0], 0xaau8)
    }

    @TestCase
    public func testReceiveStreamReadClearsBuffer(): Unit {
        let rs = ReceiveStream()
        let frame = StreamFrame()
        frame.streamId = 4
        frame.data = [0x01u8, 0x02u8]
        rs.handleStreamFrame(frame)
        let d1 = rs.read()
        @Assert(d1.size, 2)
        let d2 = rs.read()
        @Assert(d2.size, 0)
    }
}
