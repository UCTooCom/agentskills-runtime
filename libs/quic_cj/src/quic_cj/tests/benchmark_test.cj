package quic_cj.tests

import quic_cj.wire.{Frame, readVarint, writeVarintLen, appendVarint, appendByte, appendBytes, VARINT_MAX_4, PingFrame, CryptoFrame, StreamFrame, MaxDataFrame, ConnectionCloseFrame, appendFrame, DatagramFrame}
import quic_cj.protocol.{VERSION_1, VERSION_2, EncryptionLevel, Perspective, StreamType, ECN, isValidVersion, chooseSupportedVersion, generateConnectionId, streamNumToStreamId, decodePacketNumber, PACKET_NUMBER_LEN_2}
import quic_cj.ack.{AckHandler, newAckHandler}
import quic_cj.congestion.{Cubic, newCubicSender, Pacer, bandwidthFromDelta}
import quic_cj.flow.{StreamFlowController, ConnectionFlowController}
import quic_cj.stream.{Stream, SendStream, CryptoStream, ReceiveStream}
import quic_cj.core.{PacketPacker, Framer, PacketNumberSpace, Connection, DatagramQueue, newDatagramQueue, PathManager, newPathManager, RetransmissionQueue, newRetransmissionQueue, toQlogFrame, toQlogEcn, toQlogPacketTypeStr}
import quic_cj.{Config, defaultConfig, QError, CryptoError, newProtocolViolation, newCryptoError, newApplicationError}
import quic_cj.util.{RingBuffer, RTTStats}
import quic_cj.tls.CipherSuite

@Test public class VarintBench {
    @Bench
    public func readVarint1Byte(): Unit {
        let data: Array<Byte> = [0x25u8]
        let _ = readVarint(data)
    }

    @Bench
    public func appendVarintSmall(): Unit {
        let _ = appendVarint([], 42)
    }

    @Bench
    public func appendVarintLarge(): Unit {
        let _ = appendVarint([], 1000000000)
    }
}

@Test public class BufferOpsBench {
    @Bench
    public func appendByteSingle(): Unit {
        let _ = appendByte([], 0x42u8)
    }

    @Bench
    public func appendBytesSmall(): Unit {
        let _ = appendBytes([], [0x01u8, 0x02u8, 0x03u8])
    }

    @Bench
    public func appendBytesLarge(): Unit {
        let src = Array<Byte>(1000, repeat: 0xabu8)
        let extra = Array<Byte>(500, repeat: 0xcdu8)
        let _ = appendBytes(src, extra)
    }
}

@Test public class ProtocolBench {
    @Bench
    public func isValidVersionV1(): Unit {
        let _ = isValidVersion(VERSION_1)
    }

    @Bench
    public func chooseSupportedVersionMatch(): Unit {
        let ours: Array<UInt32> = [VERSION_1, 0x6b3343cfu32]
        let theirs: Array<UInt32> = [VERSION_1]
        let _ = chooseSupportedVersion(ours, theirs)
    }

    @Bench
    public func generateConnIdStandard(): Unit {
        let _ = generateConnectionId(8)
    }
}

@Test public class FrameSerializationBench {
    @Bench
    public func serializePing(): Unit {
        let f = PingFrame()
        let _ = appendFrame([], f)
    }

    @Bench
    public func serializeCrypto(): Unit {
        let cf = CryptoFrame()
        cf.data = Array<Byte>(100, repeat: 0x42u8)
        let _ = appendFrame([], cf)
    }

    @Bench
    public func serializeStreamSmall(): Unit {
        let sf = StreamFrame()
        sf.streamId = 4
        sf.data = Array<Byte>(50, repeat: 0xabu8)
        sf.offset = 0
        sf.fin = true
        let _ = appendFrame([], sf)
    }

    @Bench
    public func serializeMaxData(): Unit {
        let mdf = MaxDataFrame()
        mdf.maxData = 1048576
        let _ = appendFrame([], mdf)
    }

    @Bench
    public func serializeConnectionClose(): Unit {
        let ccf = ConnectionCloseFrame()
        ccf.errorCode = 0u64
        ccf.reasonPhrase = Array<Byte>(12, repeat: 0x00u8)
        ccf.trigFrameType = 0
        let _ = appendFrame([], ccf)
    }
}

@Test public class AckBench {
    @Bench
    public func newAckHandlerCreate(): Unit {
        let _ = newAckHandler()
    }

    @Bench
    public func ackHandlerSendMode(): Unit {
        let h = newAckHandler()
        let _ = h.sendMode()
    }

    @Bench
    public func ackHandlerLossTimeout(): Unit {
        let h = newAckHandler()
        let _ = h.getLossDetectionTimeout()
    }
}

@Test public class CubicBench {
    @Bench
    public func cubicInit(): Unit {
        let _ = Cubic()
    }

    @Bench
    public func cubicCongestionEvent(): Unit {
        let c = Cubic()
        let _ = c.onCongestionEvent(10000)
    }

    @Bench
    public func cubicPacketAcked(): Unit {
        let c = Cubic()
        let _ = c.onPacketAcked(0, 10000, 0)
    }

    @Bench
    public func cubicSenderNew(): Unit {
        let _ = newCubicSender()
    }

    @Bench
    public func pacerBudget(): Unit {
        let pacer = Pacer()
        pacer.setBandwidth(1000000u64)
        let _ = pacer.budget(0)
    }

    @Bench
    public func bandwidthEstimate(): Unit {
        let _ = bandwidthFromDelta(1000, 100000000)
    }
}

@Test public class FlowControlBench {
    @Bench
    public func streamFlowControllerNew(): Unit {
        let _ = StreamFlowController(0)
    }

    @Bench
    public func streamFlowControllerAddBytes(): Unit {
        let fc = StreamFlowController(0)
        fc.addBytesSent(1000)
    }

    @Bench
    public func connectionFlowControllerNew(): Unit {
        let _ = ConnectionFlowController()
    }

    @Bench
    public func connectionFlowControllerRead(): Unit {
        let fc = ConnectionFlowController()
        fc.addBytesRead(10000)
    }
}

@Test public class StreamBench {
    @Bench
    public func streamNew(): Unit {
        let _ = Stream(0, StreamType.Bidi, Perspective.Client)
    }

    @Bench
    public func sendStreamWriteSmall(): Unit {
        let ss = SendStream()
        let _ = ss.write([0x01u8, 0x02u8, 0x03u8])
    }

    @Bench
    public func sendStreamWriteLarge(): Unit {
        let ss = SendStream()
        let data = Array<Byte>(1400, repeat: 0x42u8)
        let _ = ss.write(data)
    }

    @Bench
    public func cryptoStreamWriteRead(): Unit {
        let cs = CryptoStream(Perspective.Client)
        cs.writeCryptoData([0x01u8, 0x02u8, 0x03u8])
        let _ = cs.readCryptoData()
    }
}

@Test public class CoreBench {
    @Bench
    public func packetNumberSpaceNext(): Unit {
        let pns = PacketNumberSpace()
        var i: Int64 = 0
        while (i < 5) {
            let _ = pns.nextPacketNumber()
            i += 1
        }
    }

    @Bench
    public func packetPackerShortHeader(): Unit {
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame()]
        let _ = pp.packShortHeaderPacket(frames, 1u8)
    }

    @Bench
    public func packetPackerLongHeader(): Unit {
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame()]
        let _ = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, 1u8)
    }

    @Bench
    public func framerQueueCrypto(): Unit {
        let f = Framer()
        f.queueCryptoData([0x01u8, 0x02u8, 0x03u8])
        let _ = f.hasData()
    }

    @Bench
    public func framerGetFrames(): Unit {
        let f = Framer()
        f.queueCryptoData([0x01u8, 0x02u8, 0x03u8])
        let _ = f.getFrames()
    }
}

@Test public class UtilBench {
    @Bench
    public func ringBufferPush(): Unit {
        let rb = RingBuffer(64, -1)
        let _ = rb.push(42)
        let _ = rb.push(100)
        let _ = rb.push(200)
    }

    @Bench
    public func ringBufferPushPop(): Unit {
        let rb = RingBuffer(64, -1)
        var i: Int64 = 0
        while (i < 10) {
            rb.push(i)
            i += 1
        }
        var j: Int64 = 0
        while (j < 5) {
            let _ = rb.pop(-1)
            j += 1
        }
    }

    @Bench
    public func rttStatsUpdate(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(100000, 0)
        let _ = rtt.smoothedRtt()
    }

    @Bench
    public func rttStatsMultipleUpdates(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(100000, 0)
        rtt.updateRtt(150000, 10000)
        rtt.updateRtt(80000, 5000)
        let _ = rtt.smoothedRtt()
        let _ = rtt.latestRtt()
        let _ = rtt.minRtt()
        let _ = rtt.meanDeviation()
    }
}

@Test public class CipherSuiteBench {
    @Bench
    public func aes128GcmCreation(): Unit {
        let _ = CipherSuite(0x1301u16)
    }

    @Bench
    public func cipherSuiteFieldAccess(): Unit {
        let cs = CipherSuite(0x1301u16)
        let _ = cs.keyLen
        let _ = cs.ivLen
        let _ = cs.tagLen
        let _ = cs.isChaCha
    }
}

@Test public class ConnectionBench {
    @Bench
    public func createConnection(): Unit {
        let _ = Connection(VERSION_1, Perspective.Client, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
    }

    @Bench
    public func connectionGetState(): Unit {
        let conn = Connection(VERSION_1, Perspective.Client, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let _ = conn.getState()
    }

    @Bench
    public func connectionClose(): Unit {
        let conn = Connection(VERSION_1, Perspective.Server, [0x05u8, 0x06u8], [0x07u8, 0x08u8])
        conn.closeWithError(0u64, "bench close")
    }
}

@Test public class ConfigBench {
    @Bench
    public func createDefaultConfig(): Unit {
        let _ = defaultConfig()
    }

    @Bench
    public func configValidate(): Unit {
        let cfg = defaultConfig()
        let _ = cfg.validate()
    }

    @Bench
    public func configModifyAndValidate(): Unit {
        let cfg = defaultConfig()
        cfg.versions = [VERSION_1]
        cfg.maxIdleTimeoutMs = 60000
        cfg.maxIncomingStreams = 500
        cfg.initialPacketSize = 1450
        let _ = cfg.validate()
    }
}

@Test public class StreamMapBench {
    @Bench
    public func createStreamWithId(): Unit {
        let _ = Stream(16, StreamType.Bidi, Perspective.Server)
    }

    @Bench
    public func createCryptoStream(): Unit {
        let _ = CryptoStream(Perspective.Client)
    }

    @Bench
    public func cryptoStreamWriteRead(): Unit {
        let cs = CryptoStream(Perspective.Client)
        cs.writeCryptoData([0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8])
        let _ = cs.readCryptoData()
    }
}

@Test public class PathManagerBench {
    @Bench
    public func newPathManager(): Unit {
        let _ = newPathManager("192.168.1.1:443")
    }

    @Bench
    public func pathManagerMigrationDisabled(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        pm.setMigrationDisabled(true)
        let _ = pm.isMigrationDisabled()
    }

    @Bench
    public func pathManagerSwitch(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        pm.switchToPath("10.0.0.1:80")
        let _ = pm.getCurrentAddr()
    }
}

@Test public class ErrorBench {
    @Bench
    public func newProtocolViolationCreate(): Unit {
        let _ = newProtocolViolation("test error")
    }

    @Bench
    public func newCryptoErrorCreate(): Unit {
        let _ = newCryptoError(20u8, "bad certificate")
    }

    @Bench
    public func newApplicationErrorCreate(): Unit {
        let _ = newApplicationError(0x100u64, "app error")
    }
}

// Test whether DatagramQueue methods work in @Test (not @Bench)
// (This is intentionally left as a test case for verification)

@Test public class ConnLoggingBench {
    @Bench
    public func toQlogFrameCrypto(): Unit {
        let cf = CryptoFrame()
        cf.offset = 0
        cf.data = [0x01u8, 0x02u8, 0x03u8]
        let _ = toQlogFrame(cf)
    }

    @Bench
    public func toQlogEcnEct0(): Unit {
        let _ = toQlogEcn(ECN.ECT0)
    }

    @Bench
    public func toQlogEcnCe(): Unit {
        let _ = toQlogEcn(ECN.CE)
    }

    @Bench
    public func toQlogPacketTypeInitial(): Unit {
        let _ = toQlogPacketTypeStr(0xC0u8)
    }

    @Bench
    public func toQlogPacketTypeShort(): Unit {
        let _ = toQlogPacketTypeStr(0x40u8)
    }
}
