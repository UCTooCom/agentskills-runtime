package quic_cj.tests

import quic_cj.stream.{StreamMap, Stream, StreamState}
import quic_cj.protocol.{StreamType, Perspective, StreamId}

@Test
public class StreamMapTestSuite {
    @TestCase
    public func testEmptyMap(): Unit {
        let sm = StreamMap()
        @Assert(sm.len(), 0)
    }

    @TestCase
    public func testGetOrOpenStreamOnce(): Unit {
        let sm = StreamMap()
        let s = sm.getOrOpenStream(0)
        @Assert(s.getStreamId(), 0)
        @Assert(sm.len(), 1)
    }

    @TestCase
    public func testGetOrOpenStreamTwiceSame(): Unit {
        let sm = StreamMap()
        let s1 = sm.getOrOpenStream(0)
        let s2 = sm.getOrOpenStream(0)
        @Assert(s1.getStreamId(), s2.getStreamId())
        @Assert(sm.len(), 1)
    }

    @TestCase
    public func testGetOrOpenStreamMultiple(): Unit {
        let sm = StreamMap()
        let s0 = sm.getOrOpenStream(0)
        let s4 = sm.getOrOpenStream(4)
        let s8 = sm.getOrOpenStream(8)
        @Assert(s0.getStreamId(), 0)
        @Assert(s4.getStreamId(), 4)
        @Assert(s8.getStreamId(), 8)
        @Assert(sm.len(), 3)
    }

    @TestCase
    public func testRemoveStream(): Unit {
        let sm = StreamMap()
        sm.getOrOpenStream(0)
        sm.getOrOpenStream(4)
        @Assert(sm.len(), 2)
        sm.removeStream(0)
        @Assert(sm.len(), 1)
        sm.removeStream(4)
        @Assert(sm.len(), 0)
    }

    @TestCase
    public func testRemoveNonexistent(): Unit {
        let sm = StreamMap()
        sm.getOrOpenStream(0)
        sm.removeStream(999)
        @Assert(sm.len(), 1)
    }

    @TestCase
    public func testAcceptStream(): Unit {
        let sm = StreamMap()
        sm.getOrOpenStream(4)
        sm.getOrOpenStream(8)
        let s = sm.acceptStream()
        @Assert(s.getStreamId() >= 0, true)
    }
}
