package quic_cj.tests

import quic_cj.protocol.VERSION_1
import quic_cj.tls.{getRetryIntegrityTag, verifyRetryIntegrity, TokenProtector, newTokenProtector, TokenGenerator, SessionTicket, generateStatelessResetToken, verifyStatelessResetToken}

@Test
public class TlsAuxTestSuite {
    @TestCase
    public func testRetryIntegrityTagSize(): Unit {
        let pkt: Array<Byte> = [0xcfu8, 0x00u8, 0x00u8, 0x00u8, 0x01u8, 0x08u8, 0x00u8, 0x00u8]
        let cid: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let tag = getRetryIntegrityTag(pkt, cid, VERSION_1)
        @Assert(tag.size, 16)
    }

    @TestCase
    public func testTokenProtectorCreate(): Unit {
        let key = Array<Byte>(32, repeat: 0xabu8)
        let protector = newTokenProtector(key)
        let data: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
        let token = protector.newToken(data)
        @Assert(token.size > data.size, true)
    }

    @TestCase
    public func testTokenGeneratorCreate(): Unit {
        let key = Array<Byte>(32, repeat: 0xabu8)
        let gen = TokenGenerator(key)
        let token = gen.newRetryToken([0xc0u8, 0xa8u8], [0x01u8], [0x02u8])
        @Assert(token.size > 0, true)
    }

    @TestCase
    public func testTokenGeneratorNewToken(): Unit {
        let key = Array<Byte>(32, repeat: 0xabu8)
        let gen = TokenGenerator(key)
        let token = gen.newToken([0xc0u8, 0xa8u8], 1000)
        @Assert(token.size > 0, true)
    }

    @TestCase
    public func testSessionTicketCreate(): Unit {
        let st = SessionTicket()
        st.parameters.initialMaxData = 10000
        st.parameters.maxIdleTimeoutMs = 30000
        let data = st.marshal()
        @Assert(data.size > 0, true)
    }

    @TestCase
    public func testSessionTicketWrongRevision(): Unit {
        let st = SessionTicket()
        let ok = st.unmarshal([0xffu8])
        @Assert(ok, false)
    }
}

@Test
public class StatelessResetTestSuite {
    @TestCase
    public func testGenerateTokenSize(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let cid: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let token = generateStatelessResetToken(key, cid)
        @Assert(token.size, 16)
    }

    @TestCase
    public func testVerifyCorrectToken(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let cid: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let token = generateStatelessResetToken(key, cid)
        let ok = verifyStatelessResetToken(key, cid, token)
        @Assert(ok, true)
    }

    @TestCase
    public func testVerifyWrongKey(): Unit {
        let key1 = Array<Byte>(16, repeat: 0xabu8)
        let key2 = Array<Byte>(16, repeat: 0xcdu8)
        let cid: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let token = generateStatelessResetToken(key1, cid)
        let ok = verifyStatelessResetToken(key2, cid, token)
        @Assert(ok, false)
    }

    @TestCase
    public func testDifferentConnIdDifferentToken(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let cid1: Array<Byte> = [0x01u8, 0x02u8]
        let cid2: Array<Byte> = [0x03u8, 0x04u8]
        let token1 = generateStatelessResetToken(key, cid1)
        let token2 = generateStatelessResetToken(key, cid2)
        var same = true
        var i: Int64 = 0
        while (i < 16) {
            if (token1[i] != token2[i]) { same = false; break }
            i += 1
        }
        @Assert(same, false)
    }
}
