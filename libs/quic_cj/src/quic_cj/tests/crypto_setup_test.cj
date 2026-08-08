package quic_cj.tests

import quic_cj.protocol.{EncryptionLevel, PacketNumber}
import quic_cj.tls.{CryptoSetup, HandshakeState, UpdatableAEAD, parseTlsHandshakeMessages, extractServerKeyShareFromServerHello, TlsHandshakeMessage, deriveTls13HandshakeSecrets}

// ── TLS 常量（由于苍颉编译顺序，必须在 @Test 类之前） ──

private let KEY_SHARE_EXT: Int64 = 0x0033
private let NAMED_GROUP_X25519: Int64 = 0x001D

@Test
public class CryptoSetupTest {
    @TestCase
    public func testCreateCryptoSetup(): Unit {
        let connId: Array<Byte> = [0x83u8, 0x94u8, 0xc8u8, 0xf0u8, 0x3eu8, 0x51u8, 0x57u8, 0x08u8]
        let cs = CryptoSetup(connId, false, "test.local", [])
        @Assert(cs.getEncodedClientHello().size, 0)
    }

    @TestCase
    public func testBuildClientHelloNonEmpty(): Unit {
        let connId: Array<Byte> = [0x83u8, 0x94u8, 0xc8u8, 0xf0u8, 0x3eu8, 0x51u8, 0x57u8, 0x08u8]
        let alpn: Array<String> = ["h3"]
        let cs = CryptoSetup(connId, false, "example.com", alpn)
        let ch = cs.buildClientHello()
        @Assert(ch.size > 0, true)
    }

    @TestCase
    public func testCryptoSetupGetAead(): Unit {
        let connId: Array<Byte> = [0x83u8, 0x94u8, 0xc8u8, 0xf0u8, 0x3eu8, 0x51u8, 0x57u8, 0x08u8]
        let cs = CryptoSetup(connId, false, "test.local", [])
        let aead = cs.getAead(EncryptionLevel.Initial)
        let hpKey = cs.getHpKey(EncryptionLevel.Initial)
        @Assert(Int64(hpKey.size), 16)

        let plaintext: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
        let aad: Array<Byte> = [0xc0u8, 0x00u8, 0x00u8, 0x00u8, 0x01u8]
        let ciphertext = aead.encrypt(0, plaintext, aad)
        @Assert(ciphertext.size, Int64(plaintext.size) + 16)
        let decrypted = aead.decrypt(0, ciphertext, aad)
        @Assert(decrypted, plaintext)
    }

    @TestCase
    public func testParseSingleTlsHandshakeMessage(): Unit {
        let msgType: UInt8 = 2u8
        let body: Array<Byte> = [0x48u8, 0x65u8, 0x6cu8, 0x6cu8, 0x6fu8, 0x21u8]
        var data = Array<Byte>(4 + body.size, repeat: 0u8)
        data[0] = msgType
        data[1] = 0u8; data[2] = 0u8; data[3] = UInt8(body.size)
        var i: Int64 = 0
        while (i < body.size) { data[4 + i] = body[i]; i += 1 }
        let messages = parseTlsHandshakeMessages(data)
        @Assert(messages.size, 1)
        let isType2 = match (messages[0].msgType) { case 2u8 => true; case _ => false }
        @Assert(isType2, true)
        @Assert(messages[0].body, body)
    }

    @TestCase
    public func testParseMultipleTlsHandshakeMessages(): Unit {
        let body1: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
        let body2: Array<Byte> = [0x04u8, 0x05u8, 0x06u8, 0x07u8]
        var data: Array<Byte> = []
        data = appendTestMsg(data, 2u8, body1)
        data = appendTestMsg(data, 11u8, body2)
        let messages = parseTlsHandshakeMessages(data)
        @Assert(messages.size, 2)
        let isType2 = match (messages[0].msgType) { case 2u8 => true; case _ => false }
        let isType11 = match (messages[1].msgType) { case 11u8 => true; case _ => false }
        @Assert(isType2, true)
        @Assert(isType11, true)
        @Assert(messages[0].body, body1)
        @Assert(messages[1].body, body2)
    }

    @TestCase
    public func testExtractKeyShareFromMinimalServerHello(): Unit {
        let version: Array<Byte> = [0x03u8, 0x03u8]
        let random: Array<Byte> = Array<Byte>(32, repeat: 0xa5u8)
        let sidLen: Array<Byte> = [0x00u8]
        let cs: Array<Byte> = [0x13u8, 0x01u8]
        let comp: Array<Byte> = [0x00u8]
        let pubKey: Array<Byte> = Array<Byte>(32, repeat: 0xabu8)
        pubKey[0] = 0x01u8
        pubKey[31] = 0x02u8
        // 扩展：[extType:2][extLen:2][group:2][keyLen:2][key:32] = 40 字节
        var ext: Array<Byte> = []
        ext = appendTestU16(ext, KEY_SHARE_EXT)
        ext = appendTestU16(ext, 36)
        ext = appendTestU16(ext, NAMED_GROUP_X25519)
        ext = appendTestU16(ext, 32)
        ext = appendTestBytes(ext, pubKey)
        // ServerHello 体：version(2)+random(32)+sidLen(1)+密码套件(2)+压缩算法(1) = 38
        // + 扩展列表长度(2) + 扩展(40) = 80
        var sh: Array<Byte> = []
        sh = appendTestBytes(sh, version)
        sh = appendTestBytes(sh, random)
        sh = appendTestBytes(sh, sidLen)
        sh = appendTestBytes(sh, cs)
        sh = appendTestBytes(sh, comp)
        sh = appendTestU16(sh, ext.size)
        sh = appendTestBytes(sh, ext)
        let extracted = extractServerKeyShareFromServerHello(sh)
        @Assert(extracted.size, 32)
        @Assert(UInt8(extracted[0]), pubKey[0])
        @Assert(UInt8(extracted[31]), pubKey[31])
    }

    @TestCase
    public func testExtractKeyShareNoExtension(): Unit {
        let version: Array<Byte> = [0x03u8, 0x03u8]
        let random: Array<Byte> = Array<Byte>(32, repeat: 0xa5u8)
        var body: Array<Byte> = []
        body = appendTestBytes(body, version)
        body = appendTestBytes(body, random)
        body = appendTestBytes(body, [0x00u8])  // sid长度=0
        body = appendTestBytes(body, [0x13u8, 0x01u8])  // 密码套件
        body = appendTestBytes(body, [0x00u8])  // 压缩算法
        body = appendTestU16(body, 0)  // 空扩展
        @Assert(extractServerKeyShareFromServerHello(body).size, 0)
    }

    @TestCase
    public func testDeriveTls13SecretsDeterministic(): Unit {
        let sharedSecret: Array<Byte> = Array<Byte>(32, repeat: 0x42u8)
        let clientHello: Array<Byte> = [0x01u8, 0x00u8, 0x00u8, 0x02u8, 0xabu8, 0xcdu8]
        var serverHello: Array<Byte> = []
        serverHello = appendTestMsg(serverHello, 2u8, [0x03u8, 0x03u8, 0xa5u8])
        let transcript: Array<Array<Byte>> = [clientHello, serverHello]
        let s1 = deriveTls13HandshakeSecrets(sharedSecret, transcript)
        @Assert(s1.handshakeSecret.size, 32)
        @Assert(s1.masterSecret.size, 32)
        @Assert(s1.clientHsTrafficSecret.size, 32)
        @Assert(s1.clientAppTrafficSecret.size, 32)
        let s2 = deriveTls13HandshakeSecrets(sharedSecret, transcript)
        @Assert(s2.handshakeSecret, s1.handshakeSecret)
        @Assert(s2.clientHsTrafficSecret, s1.clientHsTrafficSecret)
        @Assert(s2.clientAppTrafficSecret, s1.clientAppTrafficSecret)
    }

    @TestCase
    public func testHandleServerFlightNoBuild(): Unit {
        let connId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let cs = CryptoSetup(connId, false, "test.local", [])
        @Assert(cs.handleServerFlight([]), false)
        let isInit = match (cs.getState()) { case HandshakeState.Initial => true; case _ => false }
        @Assert(isInit, true)
    }

    @TestCase
    public func testHandleServerFlightNoBuildWithData(): Unit {
        let connId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let cs = CryptoSetup(connId, false, "test.local", [])
        let body: Array<Byte> = [0x02u8, 0x00u8, 0x00u8, 0x03u8, 0x01u8, 0x02u8, 0x03u8]
        @Assert(cs.handleServerFlight(body), false)
    }
}

// ── 测试辅助函数 ──

private func appendTestMsg(data: Array<Byte>, msgType: UInt8, body: Array<Byte>): Array<Byte> {
    let len = body.size
    var out = Array<Byte>(data.size + 4 + len, repeat: 0u8)
    var i: Int64 = 0
    while (i < data.size) { out[i] = data[i]; i += 1 }
    out[data.size] = msgType
    out[data.size + 1] = UInt8((len >> 16) & 0xff)
    out[data.size + 2] = UInt8((len >> 8) & 0xff)
    out[data.size + 3] = UInt8(len & 0xff)
    i = 0
    while (i < len) { out[data.size + 4 + i] = body[i]; i += 1 }
    out
}

private func appendTestBytes(existing: Array<Byte>, more: Array<Byte>): Array<Byte> {
    let n = existing.size
    let m = more.size
    var out = Array<Byte>(n + m, repeat: 0u8)
    var i: Int64 = 0
    while (i < n) { out[i] = existing[i]; i += 1 }
    i = 0
    while (i < m) { out[n + i] = more[i]; i += 1 }
    out
}

private func appendTestU16(existing: Array<Byte>, val: Int64): Array<Byte> {
    let n = existing.size
    var out = Array<Byte>(n + 2, repeat: 0u8)
    var i: Int64 = 0
    while (i < n) { out[i] = existing[i]; i += 1 }
    out[n] = UInt8((val >> 8) & 0xff)
    out[n + 1] = UInt8(val & 0xff)
    out
}
