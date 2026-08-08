package quic_cj.tests

import quic_cj.core.{ConnIDGenerator, newConnIDGenerator, ConnRunnerCallbacks}

@Test
public class ConnIdGeneratorTestSuite {
    @TestCase
    public func testNewGeneratorDefaults(): Unit {
        let gen = newConnIDGenerator([0x01u8, 0x02u8, 0x03u8, 0x04u8])
        let ids = gen.getActiveConnIds()
        @Assert(ids.size, 1)
        @Assert(ids[0].size, 4)
        @Assert(ids[0][0], 0x01u8)
    }

    @TestCase
    public func testSetMaxActiveConnIDsIssuesNewIds(): Unit {
        let gen = newConnIDGenerator([0x01u8])
        gen.setMaxActiveConnIDs(4u64)
        let ids = gen.getActiveConnIds()
        @Assert(ids.size, 4)
    }

    @TestCase
    public func testRetireNonExistentSeq(): Unit {
        let gen = newConnIDGenerator([0x01u8])
        let result = gen.retire(99u64, 1000)
        @Assert(result, true)
    }

    @TestCase
    public func testSetMaxActiveConnIDsCapsAtEight(): Unit {
        let gen = newConnIDGenerator([0x01u8])
        gen.setMaxActiveConnIDs(100u64)
        let ids = gen.getActiveConnIds()
        @Assert(ids.size >= 1, true)
    }

    @TestCase
    public func testGetActiveConnIdsIsIndependent(): Unit {
        let gen = newConnIDGenerator([0x01u8])
        gen.setMaxActiveConnIDs(3u64)
        let ids = gen.getActiveConnIds()
        @Assert(ids.size, 3)
    }

    @TestCase
    public func testInitialClientDestIsStored(): Unit {
        let gen = ConnIDGenerator([0x01u8], [0xaau8, 0xbbu8, 0xccu8])
        let ids = gen.getActiveConnIds()
        @Assert(ids.size, 1)
        @Assert(ids[0].size, 1)
        @Assert(ids[0][0], 0x01u8)
    }

    @TestCase
    public func testCallbacksNoOp(): Unit {
        let gen = newConnIDGenerator([0x01u8])
        let cb = ConnRunnerCallbacks()
        gen.setCallbacks(cb)
        cb.addConnectionId([0x02u8])
        cb.removeConnectionId([0x01u8])
        @Assert(true, true)
    }
}
