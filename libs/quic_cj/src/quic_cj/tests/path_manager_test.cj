package quic_cj.tests

import quic_cj.core.{PathManager, newPathManager}
import quic_cj.wire.{PathChallengeFrame, PathResponseFrame, Frame}

@Test
public class PathManagerTestSuite {
    @TestCase
    public func testNewManagerMigrationNotDisabled(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        @Assert(pm.isMigrationDisabled(), false)
    }

    @TestCase
    public func testSetMigrationDisabled(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        pm.setMigrationDisabled(true)
        @Assert(pm.isMigrationDisabled(), true)
    }

    @TestCase
    public func testSetMigrationDisabledBackToFalse(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        pm.setMigrationDisabled(true)
        pm.setMigrationDisabled(false)
        @Assert(pm.isMigrationDisabled(), false)
    }

    @TestCase
    public func testPathCountInitialZero(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        @Assert(pm.pathCount(), 0)
    }

    @TestCase
    public func testInitialAddr(): Unit {
        let pm = newPathManager("10.0.0.1:8080")
        @Assert(pm.getCurrentAddr(), "10.0.0.1:8080")
    }

    @TestCase
    public func testSwitchToPath(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        pm.switchToPath("10.0.0.1:80")
        @Assert(pm.getCurrentAddr(), "10.0.0.1:80")
        @Assert(pm.pathCount(), 0)
    }

    @TestCase
    public func testHandlePacketNewPath(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        let pcf = PathChallengeFrame()
        pcf.data = [0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8]
        let (frames, _, ok) = pm.handlePacket("10.0.0.1:80", 1000000, pcf, true, false)
        @Assert(ok, true)
        @Assert(frames.size > 0, true)  // 应包含 PATH_RESPONSE
    }

    @TestCase
    public func testHandlePacketExistingPath(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        // 首次调用添加路径
        let pcf = PathChallengeFrame()
        pcf.data = [0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8]
        pm.handlePacket("10.0.0.1:80", 1000000, pcf, true, false)
        // 再次调用应找到已有路径
        let (frames2, _, ok2) = pm.handlePacket("10.0.0.1:80", 2000000, pcf, false, false)
        @Assert(ok2, true)
        @Assert(pm.pathCount() >= 1, true)
    }

    @TestCase
    public func testHandlePathResponseFrameValidates(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        let pcf = PathChallengeFrame()
        pcf.data = [0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8]
        pm.handlePacket("10.0.0.1:80", 1000000, pcf, true, false)
        pm.handlePathResponseFrame([0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8])
        let none1 = match (pm.getCurrentPath()) { case None => true; case _ => false }
        @Assert(none1, true)  // 当前路径仍是原始地址
    }

    @TestCase
    public func testGetCurrentPathNotFound(): Unit {
        let pm = newPathManager("10.0.0.1:8080")
        let none2 = match (pm.getCurrentPath()) { case None => true; case _ => false }
        @Assert(none2, true)
    }

    @TestCase
    public func testInitiatePreferredAddressMigration(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        let frames = pm.initiatePreferredAddressMigration("10.0.0.1:80", 1000000)
        @Assert(frames.size > 0, true)
    }

    @TestCase
    public func testInitiatePreferredAddressMigrationDisabled(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        pm.setMigrationDisabled(true)
        let frames = pm.initiatePreferredAddressMigration("10.0.0.1:80", 1000000)
        @Assert(frames.size, 0)  // 禁用迁移时应返回空
    }

    @TestCase
    public func testHandlePacketMigrationDisabledNewAddr(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        pm.setMigrationDisabled(true)
        let pcf = PathChallengeFrame()
        pcf.data = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let (frames, _, ok) = pm.handlePacket("10.0.0.1:80", 1000000, pcf, true, false)
        @Assert(ok, true)
        @Assert(frames.size > 0, true)  // 应回复 PATH_RESPONSE
    }

    @TestCase
    public func testHandlePacketNonProbingSetsFlag(): Unit {
        let pm = newPathManager("192.168.1.1:443")
        let pcf = PathChallengeFrame()
        pcf.data = [0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8]
        pm.handlePacket("10.0.0.1:80", 1000000, pcf, true, true)
        // 当前路径仍为初始路径，非探测包路径未验证
        @Assert(pm.pathCount(), 1)
        let none3 = match (pm.getCurrentPath()) { case None => true; case _ => false }
        @Assert(none3, true)
    }
}
