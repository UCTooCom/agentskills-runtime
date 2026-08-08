package quic_cj.tests

import quic_cj.wire.AckRange

@Test
public class AckRangeTestSuite {
    @TestCase
    public func testAckRangeDefaults(): Unit {
        let r = AckRange()
        @Assert(r.smallest, 0)
        @Assert(r.largest, 0)
    }

    @TestCase
    public func testAckRangeSinglePacket(): Unit {
        let r = AckRange()
        r.smallest = 5
        r.largest = 5
        @Assert(r.len(), 1)
    }

    @TestCase
    public func testAckRangeMultiple(): Unit {
        let r = AckRange()
        r.smallest = 10
        r.largest = 20
        @Assert(r.len(), 11)
    }

    @TestCase
    public func testAckRangeLarge(): Unit {
        let r = AckRange()
        r.smallest = 0
        r.largest = 1000
        @Assert(r.len(), 1001)
    }
}
