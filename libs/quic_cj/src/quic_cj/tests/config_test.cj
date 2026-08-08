package quic_cj.tests

import quic_cj.{Config, defaultConfig, QError, newTransportError, newApplicationError}
import quic_cj.protocol.{VERSION_1, VERSION_2}

@Test
public class ConfigTestSuite {
    @TestCase
    public func testDefaultConfigValues(): Unit {
        let cfg = defaultConfig()
        @Assert(cfg.versions.size, 2)
        @Assert(cfg.maxIdleTimeoutMs, 30000)
        @Assert(cfg.maxIncomingStreams > 0, true)
        @Assert(cfg.initialPacketSize, 1200)
        @Assert(cfg.handshakeIdleTimeoutMs, 5000)
    }

    @TestCase
    public func testConfigValidation(): Unit {
        let cfg = defaultConfig()
        @Assert(cfg.validate(), true)
    }

    @TestCase
    public func testConfigValidationEmptyVersions(): Unit {
        let cfg = defaultConfig()
        cfg.versions = []
        @Assert(cfg.validate(), false)
    }

    @TestCase
    public func testConfigValidationSingleVersion(): Unit {
        let cfg = defaultConfig()
        cfg.versions = [VERSION_1]
        @Assert(cfg.validate(), true)
    }

    @TestCase
    public func testConfigSmallInitialPacketSize(): Unit {
        let cfg = defaultConfig()
        cfg.initialPacketSize = 500
        cfg.validate()
        @Assert(cfg.initialPacketSize, 1200)
    }

    @TestCase
    public func testConfigLargeInitialPacketSize(): Unit {
        let cfg = defaultConfig()
        cfg.initialPacketSize = 9000
        cfg.validate()
        @Assert(cfg.initialPacketSize, 9000)
    }

    @TestCase
    public func testConfigExtremeStreamLimits(): Unit {
        let cfg = defaultConfig()
        cfg.maxIncomingStreams = Int64(1) << 61
        cfg.validate()
        @Assert(cfg.maxIncomingStreams, Int64(1) << 60)
    }
}

@Test
public class QErrorTestSuite {
    @TestCase
    public func testTransportError(): Unit {
        let err = newTransportError(0x01u64, "internal error")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, 0x01u64)
        @Assert(err.errorMessage, "internal error")
    }

    @TestCase
    public func testApplicationError(): Unit {
        let err = newApplicationError(0x100u64, "app error")
        @Assert(err.isTransport, false)
        @Assert(err.appCode, 0x100u64)
        @Assert(err.errorMessage, "app error")
    }

    @TestCase
    public func testQErrorDefaultTransport(): Unit {
        let err = newTransportError(0x0au64, "protocol violation")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, 0x0au64)
    }
}
