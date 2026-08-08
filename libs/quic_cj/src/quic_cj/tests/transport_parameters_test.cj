package quic_cj.tests

import quic_cj.wire.{TransportParameters, marshalTransportParameters, parseTransportParameters, TP_INITIAL_MAX_DATA, TP_MAX_IDLE_TIMEOUT, TP_ACK_DELAY_EXPONENT, PreferredAddress, makePreferredAddressData, parsePreferredAddress}

@Test
public class TransportParametersTestSuite {
    @TestCase
    public func testMarshalParseRoundTrip(): Unit {
        let params = TransportParameters()
        params.initialMaxData = 10000
        params.maxIdleTimeoutMs = 30000
        params.ackDelayExponent = 4

        let buf = marshalTransportParameters(params)
        if (let Some(parsed) <- parseTransportParameters(buf)) {
            @Assert(parsed.initialMaxData, 10000)
            @Assert(parsed.maxIdleTimeoutMs, 30000)
            @Assert(parsed.ackDelayExponent, 4)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testDefaultsPreserved(): Unit {
        let params = TransportParameters()
        // 默认值：maxUdpPayloadSize=65527、ackDelayExponent=3 等。
        let buf = marshalTransportParameters(params)
        @Assert(buf.size > 0, true) // 非零默认值产生输出
        if (let Some(parsed) <- parseTransportParameters(buf)) {
            @Assert(parsed.maxUdpPayloadSize, 65527)
            @Assert(parsed.activeConnectionIdLimit, 2)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testParseEmpty(): Unit {
        if (let Some(params) <- parseTransportParameters([])) {
            @Assert(params.initialMaxData, 0)
        } else {
            @Assert(false, true)
        }
    }
}


@Test
public class PreferredAddressTestSuite {
    @TestCase
    public func testPreferredAddressRoundtrip(): Unit {
        let addr = PreferredAddress([192u8, 168u8, 1u8, 1u8], 443, [0x01u8, 0x02u8], Array<Byte>(16, repeat: 0xabu8))
        let data = makePreferredAddressData(addr)
        if (let Some(parsed) <- parsePreferredAddress(data)) {
            @Assert(parsed.ipv4Addr.size, 4)
            @Assert(parsed.ipv4Addr[0], 192u8)
            @Assert(parsed.ipv4Addr[1], 168u8)
            @Assert(parsed.ipv4Addr[2], 1u8)
            @Assert(parsed.ipv4Addr[3], 1u8)
            @Assert(parsed.ipv4Port, 443)
            @Assert(parsed.connId.size, 2)
            @Assert(parsed.connId[0], 0x01u8)
            @Assert(parsed.connId[1], 0x02u8)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testPreferredAddressIPv4PortEncoding(): Unit {
        let addr = PreferredAddress([10u8, 0u8, 0u8, 1u8], 8080, [0x03u8], Array<Byte>(16, repeat: 0xccu8))
        let data = makePreferredAddressData(addr)
        // IPv4 addr at [0..3]
        @Assert(data[0], 10u8)
        @Assert(data[1], 0u8)
        @Assert(data[2], 0u8)
        @Assert(data[3], 1u8)
        // Port at [4..5] (8080 = 0x1f90)
        @Assert(data[4], 0x1fu8)
        @Assert(data[5], 0x90u8)
    }

    @TestCase
    public func testParsePreferredAddressTooShort(): Unit {
        let none = match (parsePreferredAddress([0x01u8, 0x02u8, 0x03u8])) { case None => true; case _ => false }
        @Assert(none, true)
    }

    @TestCase
    public func testPreferredAddressEmptyConstructor(): Unit {
        let addr = PreferredAddress()
        @Assert(addr.ipv4Addr.size, 4)
        @Assert(addr.ipv4Port, 0)
    }

    @TestCase
    public func testPreferredAddressDefaultResetToken(): Unit {
        let addr = PreferredAddress()
        @Assert(addr.statelessResetToken.size, 16)
    }
}
