package quic_cj.tests

import quic_cj.tls.{parseCertificateMsgBody, buildSignContent, verifyFinishedMsg, deriveFinishKey, verifyCertVerifySig, parseCertDersToX509}
import jinguissl_core.crypto.digest.{sha256}

@Test
public class TlsVerifyTestSuite {
    @TestCase
    public func testParseCertificateMsgBodyEmpty(): Unit {
        let parsed = parseCertificateMsgBody([])
        let isNone = match (parsed) { case None => true; case _ => false }
        @Assert(isNone, true)
    }

    @TestCase
    public func testParseCertificateMsgBodyTooShort(): Unit {
        let parsed = parseCertificateMsgBody([0x00u8, 0x01u8])
        let isNone = match (parsed) { case None => true; case _ => false }
        @Assert(isNone, true)
    }

    @TestCase
    public func testParseCertificateMsgBodySingle(): Unit {
        // cert_len(3)=4 + cert_data(4) + ext_len(2)=0 = 列表中总计 9
        let body: Array<Byte> = [
            0x00u8,                                    // 上下文长度 = 0
            0x00u8, 0x00u8, 0x09u8,                     // 证书列表长度 = 9
            0x00u8, 0x00u8, 0x04u8,                     // 证书长度 = 4
            0x01u8, 0x02u8, 0x03u8, 0x04u8,            // 证书数据 = 4 字节
            0x00u8, 0x00u8                              // 扩展长度 = 0
        ]
        if (let Some(certs) <- parseCertificateMsgBody(body)) {
            @Assert(certs.size, 1)
            @Assert(certs[0].size, 4)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testParseCertificateMsgBodyMultiple(): Unit {
        // cert1：cert_len(3)=2 + cert_data(2) + ext_len(2)=0 = 7
        // cert2：cert_len(3)=3 + cert_data(3) + ext_len(2)=0 = 8
        // 列表长度 = 7 + 8 = 15
        let body: Array<Byte> = [
            0x00u8,                                                             // 上下文长度 = 0
            0x00u8, 0x00u8, 0x0Fu8,                                              // 列表长度 = 15
            0x00u8, 0x00u8, 0x02u8, 0x01u8, 0x02u8, 0x00u8, 0x00u8,           // cert1
            0x00u8, 0x00u8, 0x03u8, 0x03u8, 0x04u8, 0x05u8, 0x00u8, 0x00u8    // cert2
        ]
        if (let Some(certs) <- parseCertificateMsgBody(body)) {
            @Assert(certs.size, 2)
            @Assert(certs[0].size, 2)
            @Assert(certs[1].size, 3)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testBuildSignContentSize(): Unit {
        let th: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
        let content = buildSignContent(th, true)
        // 64 填充 + "TLS 1.3, client CertificateVerify\0" (34) + th (3) = 101
        @Assert(content.size, 101)
    }

    @TestCase
    public func testVerifyFinishedMsgShortBodyFails(): Unit {
        let ok = verifyFinishedMsg([0x01u8], [], [])
        @Assert(ok, false)
    }

    @TestCase
    public func testVerifyFinishedMsgWrongTagFails(): Unit {
        let body = Array<Byte>(32, repeat: 0xffu8)
        let key = Array<Byte>(32, repeat: 0x01u8)
        let transcript = Array<Byte>(32, repeat: 0x02u8)
        let ok = verifyFinishedMsg(body, key, transcript)
        @Assert(ok, false)
    }

    @TestCase
    public func testDeriveFinishKeySize(): Unit {
        let secret = Array<Byte>(32, repeat: 0xabu8)
        let key = deriveFinishKey(secret)
        @Assert(key.size, 32)
    }

    @TestCase
    public func testParseCertDersToX509Empty(): Unit {
        let parsed = parseCertDersToX509([])
        let isNone = match (parsed) { case None => true; case _ => false }
        @Assert(isNone, true)
    }

    @TestCase
    public func testVerifyCertVerifySigEmpty(): Unit {
        let ok = verifyCertVerifySig([], [], [])
        @Assert(ok, false)
    }
}
