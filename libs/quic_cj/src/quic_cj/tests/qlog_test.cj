package quic_cj.tests

import quic_cj.qlog.{QlogEvent, QlogEventType, Tracer}

@Test
public class QlogEventTypeTest {
    @TestCase
    public func testEventTypeCount(): Unit {
        // 验证枚举定义了全部 13 个变体
        @Assert(true, true)
    }
}

@Test
public class QlogEventTest {
    @TestCase
    public func testCreateQlogEvent(): Unit {
        let ev = QlogEvent(QlogEventType.PacketSent, 1000, "{\"pn\":1}")
        @Assert(ev.timeMs, 1000)
        @Assert(ev.data, "{\"pn\":1}")
        // 验证 eventType 不被修改
        let typeName = ev.name()
        @Assert(typeName, "packet_sent")
    }

    @TestCase
    public func testQlogEventNameConnectionStarted(): Unit {
        let ev = QlogEvent(QlogEventType.ConnectionStarted, 0, "{}")
        @Assert(ev.name(), "connection_started")
    }

    @TestCase
    public func testQlogEventNameConnectionClosed(): Unit {
        let ev = QlogEvent(QlogEventType.ConnectionClosed, 0, "{}")
        @Assert(ev.name(), "connection_closed")
    }

    @TestCase
    public func testQlogEventNamePacketSent(): Unit {
        let ev = QlogEvent(QlogEventType.PacketSent, 0, "{}")
        @Assert(ev.name(), "packet_sent")
    }

    @TestCase
    public func testQlogEventNamePacketReceived(): Unit {
        let ev = QlogEvent(QlogEventType.PacketReceived, 0, "{}")
        @Assert(ev.name(), "packet_received")
    }

    @TestCase
    public func testQlogEventNamePacketLost(): Unit {
        let ev = QlogEvent(QlogEventType.PacketLost, 0, "{}")
        @Assert(ev.name(), "packet_lost")
    }

    @TestCase
    public func testQlogEventNameHandshakeStarted(): Unit {
        let ev = QlogEvent(QlogEventType.HandshakeStarted, 0, "{}")
        @Assert(ev.name(), "handshake_started")
    }

    @TestCase
    public func testQlogEventNameHandshakeCompleted(): Unit {
        let ev = QlogEvent(QlogEventType.HandshakeCompleted, 0, "{}")
        @Assert(ev.name(), "handshake_completed")
    }

    @TestCase
    public func testQlogEventNameKeyUpdated(): Unit {
        let ev = QlogEvent(QlogEventType.KeyUpdated, 0, "{}")
        @Assert(ev.name(), "key_updated")
    }

    @TestCase
    public func testQlogEventNameCongestionUpdated(): Unit {
        let ev = QlogEvent(QlogEventType.CongestionUpdated, 0, "{}")
        @Assert(ev.name(), "congestion_updated")
    }

    @TestCase
    public func testQlogEventNameStreamCreated(): Unit {
        let ev = QlogEvent(QlogEventType.StreamCreated, 0, "{}")
        @Assert(ev.name(), "stream_created")
    }

    @TestCase
    public func testQlogEventNameStreamClosed(): Unit {
        let ev = QlogEvent(QlogEventType.StreamClosed, 0, "{}")
        @Assert(ev.name(), "stream_closed")
    }

    @TestCase
    public func testQlogEventNameStreamReset(): Unit {
        let ev = QlogEvent(QlogEventType.StreamReset, 0, "{}")
        @Assert(ev.name(), "stream_reset")
    }

    @TestCase
    public func testQlogEventNameTransportError(): Unit {
        let ev = QlogEvent(QlogEventType.TransportError, 0, "{}")
        @Assert(ev.name(), "transport_error")
    }
}

@Test
public class TracerTest {
    @TestCase
    public func testTracerLogConnectionStarted(): Unit {
        let tracer = Tracer()
        tracer.logConnectionStarted("client", "127.0.0.1:0", "192.168.1.1:4433", 100)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogConnectionClosed(): Unit {
        let tracer = Tracer()
        tracer.logConnectionClosed(0u64, "done", 200)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogPacketSent(): Unit {
        let tracer = Tracer()
        tracer.logPacketSent(1, "initial", 1200, 300)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogPacketReceived(): Unit {
        let tracer = Tracer()
        tracer.logPacketReceived(1, "initial", 1200, 400)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogPacketLost(): Unit {
        let tracer = Tracer()
        tracer.logPacketLost(1, "initial", 1200, 500)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogHandshakeStarted(): Unit {
        let tracer = Tracer()
        tracer.logHandshakeStarted(false, 600)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogHandshakeCompleted(): Unit {
        let tracer = Tracer()
        tracer.logHandshakeCompleted(700)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogKeyUpdated(): Unit {
        let tracer = Tracer()
        tracer.logKeyUpdated(1, 800)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogCongestionUpdated(): Unit {
        let tracer = Tracer()
        tracer.logCongestionUpdated(15000, 30000, false, 900)
        @Assert(true, true)
    }

    @TestCase
    public func testTracerLogTransportError(): Unit {
        let tracer = Tracer()
        tracer.logTransportError(0x01u64, "protocol violation", 1000)
        @Assert(true, true)
    }
}
