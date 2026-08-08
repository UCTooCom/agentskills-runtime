package http_lib.client

import http_lib.core.HttpMethod
import http_lib.message.HttpRequest
import http_lib.http2.{CapsuleType, Capsule, encodeCapsule, decodeCapsule}

@Test
public class MasqueTest {

    @TestCase
    public func testMasqueConstants(): Unit {
        if (MASQUE_METHOD_CONNECT_UDP != "CONNECT-UDP") {
            throw Exception("Unexpected CONNECT-UDP method string")
        }
    }

    @TestCase
    public func testMasqueProxyClient(): Unit {
        let client = MasqueUdpProxyClient()
        // Creation without error is sufficient
    }

    @TestCase
    public func testBuildConnectUdpRequest(): Unit {
        let client = MasqueUdpProxyClient()
        let req = client.buildConnectUdpRequest("example.com", 443u16)
        if (req.method != HttpMethod.CONNECT) {
            throw Exception("Expected CONNECT method")
        }
    }

    @TestCase
    public func testDatagramRoundtrip(): Unit {
        let client = MasqueUdpProxyClient()
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let encapsulated = client.encapsulateDatagram(data)
        let decapsulated = client.decapsulateDatagram(encapsulated)
        if (decapsulated.isNone()) {
            throw Exception("Expected decapsulated data")
        }
        let decoded = decapsulated.getOrThrow()
        if (decoded.size != data.size) {
            throw Exception("Data size mismatch")
        }
    }
}
