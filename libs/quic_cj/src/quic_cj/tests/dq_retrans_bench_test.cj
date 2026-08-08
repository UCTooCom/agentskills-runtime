package quic_cj.tests

import quic_cj.wire.{DatagramFrame, CryptoFrame, Frame}
import quic_cj.core.{DatagramQueue, newDatagramQueue, RetransmissionQueue, newRetransmissionQueue}
import quic_cj.protocol.EncryptionLevel

@Test public class DQBench {
    @Bench
    public func createDQ(): Unit {
        let _ = newDatagramQueue()
    }

    @Bench
    public func closeDQ(): Unit {
        let dq = newDatagramQueue()
        dq.close()
    }

    @Bench
    public func recvHandle(): Unit {
        let dq = newDatagramQueue()
        let data: Array<Byte> = [0x01u8]
        dq.handleDatagramFrame(data)
        let _ = dq.receive()
    }

    @Bench
    public func addFrame(): Unit {
        let dq = newDatagramQueue()
        let df = DatagramFrame()
        let _ = dq.add(df)
    }

    @Bench
    public func peekFrame(): Unit {
        let dq = newDatagramQueue()
        let df = DatagramFrame()
        dq.add(df)
        let _ = dq.peek()
    }

    @Bench
    public func popFrame(): Unit {
        let dq = newDatagramQueue()
        let df = DatagramFrame()
        dq.add(df)
        dq.peek()
        dq.pop()
    }

    @Bench
    public func querySendLen(): Unit {
        let dq = newDatagramQueue()
        let _ = dq.sendLen()
    }

    @Bench
    public func queryRecvLen(): Unit {
        let dq = newDatagramQueue()
        let _ = dq.recvLen()
    }

    @Bench
    public func queryHasData(): Unit {
        let dq = newDatagramQueue()
        let _ = dq.hasSendData()
        let _ = dq.hasRecvData()
    }

    @Bench
    public func configureDQ(): Unit {
        let dq = newDatagramQueue()
        dq.setHasDataCallback({ => })
        dq.setMaxDatagramPayload(1024)
    }
}

@Test public class RQBench {
    @Bench
    public func createRQ(): Unit {
        let _ = newRetransmissionQueue()
    }

    @Bench
    public func addInitialCrypto(): Unit {
        let rq = newRetransmissionQueue()
        let cf = CryptoFrame()
        rq.addInitial(cf)
    }

    @Bench
    public func addHandshakeCrypto(): Unit {
        let rq = newRetransmissionQueue()
        let cf = CryptoFrame()
        rq.addHandshake(cf)
    }

    @Bench
    public func addAppDataFrame(): Unit {
        let rq = newRetransmissionQueue()
        let f = Frame()
        rq.addAppData(f)
    }

    @Bench
    public func checkHasDataInitial(): Unit {
        let rq = newRetransmissionQueue()
        let cf = CryptoFrame()
        rq.addInitial(cf)
        let _ = rq.hasData(EncryptionLevel.Initial)
    }

    @Bench
    public func getFrameInitial(): Unit {
        let rq = newRetransmissionQueue()
        let cf = CryptoFrame()
        rq.addInitial(cf)
        let _ = rq.getFrame(EncryptionLevel.Initial)
    }

    @Bench
    public func dropPacketsInitial(): Unit {
        let rq = newRetransmissionQueue()
        let cf = CryptoFrame()
        rq.addInitial(cf)
        rq.dropPackets(EncryptionLevel.Initial)
    }

    @Bench
    public func fullCycle(): Unit {
        let rq = newRetransmissionQueue()
        rq.addInitial(CryptoFrame())
        rq.addHandshake(CryptoFrame())
        rq.addAppData(Frame())
        let h1 = rq.hasData(EncryptionLevel.Initial)
        let h2 = rq.hasData(EncryptionLevel.Handshake)
        let h3 = rq.hasData(EncryptionLevel.OneRTT)
        let _ = rq.getFrame(EncryptionLevel.Initial)
        let _ = rq.getFrame(EncryptionLevel.Handshake)
        rq.dropPackets(EncryptionLevel.Initial)
        let _ = h1 && h2 && h3
    }
}
