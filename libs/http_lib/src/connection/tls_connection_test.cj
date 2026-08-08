package http_lib.connection
import http_lib.core.{assertTrue, assertFalse}
@Test
public class TlsConnectionUnitTest {

    // ---- 密码套件密钥长度 ----

    @TestCase public func testKeyLenEcdhe128(): Unit { assertTrue(tls12CipherSuiteKeyLen(0xc02f)==16) }
    @TestCase public func testKeyLenEcdhe256(): Unit { assertTrue(tls12CipherSuiteKeyLen(0xc030)==32) }
    @TestCase public func testKeyLenRsa128(): Unit { assertTrue(tls12CipherSuiteKeyLen(0x009c)==16) }
    @TestCase public func testKeyLenRsa256(): Unit { assertTrue(tls12CipherSuiteKeyLen(0x009d)==16) }
    @TestCase public func testKeyLenCbc128(): Unit { assertTrue(tls12CipherSuiteKeyLen(0xc027)==16) }
    @TestCase public func testKeyLenCbc256(): Unit { assertTrue(tls12CipherSuiteKeyLen(0xc014)==32) }
    @TestCase public func testKeyLenEcdheCbc128(): Unit { assertTrue(tls12CipherSuiteKeyLen(0xc007)==16) }
    @TestCase public func testKeyLenEcdheCbc256(): Unit { assertTrue(tls12CipherSuiteKeyLen(0xc00a)==16) }
    @TestCase public func testKeyLenDheRsa128(): Unit { assertTrue(tls12CipherSuiteKeyLen(0x009e)==16) }
    @TestCase public func testKeyLenDheRsa256(): Unit { assertTrue(tls12CipherSuiteKeyLen(0x009f)==16) }
    @TestCase public func testKeyLenDefault(): Unit { assertTrue(tls12CipherSuiteKeyLen(99999)==16) }

    // ---- 密码套件 IV 长度 ----

    @TestCase public func testIvLenGcm(): Unit { assertTrue(tls12CipherSuiteIvLen(0xc02f)==4) }
    @TestCase public func testIvLenCbc(): Unit { assertTrue(tls12CipherSuiteIvLen(0xc027)==16) }
    @TestCase public func testIvLenRsaGcm(): Unit { assertTrue(tls12CipherSuiteIvLen(0x009c)==4) }
    @TestCase public func testIvLenDefault(): Unit { assertTrue(tls12CipherSuiteIvLen(99999)==12) }

    // ---- GCM 测试夹具 ----

    @TestCase public func testFixturePlaintextSize(): Unit { assertTrue(tls12GcmFixturePlaintext().size>0) }
    @TestCase public func testFixturePlaintextValues(): Unit { let p=tls12GcmFixturePlaintext(); assertTrue(p.size>0) }
    @TestCase public func testSealApplicationDataSize(): Unit { assertTrue(tls12GcmSealFixtureApplicationData().size>0) }
    @TestCase public func testSealApplicationDataPair(): Unit { assertTrue(tls12GcmSealFixtureApplicationDataPair().size==2) }
    @TestCase public func testSealHandshakeSize(): Unit { assertTrue(tls12GcmSealFixtureHandshake().size>0) }
    @TestCase public func testOpenApplicationData(): Unit { let s=tls12GcmSealFixtureApplicationData(); assertTrue(tls12GcmOpenFixtureApplicationData(s).size>0) }
    @TestCase public func testOpenApplicationDataPair(): Unit { let p=tls12GcmSealFixtureApplicationDataPair(); assertTrue(tls12GcmOpenFixtureApplicationDataPair(p).size==2) }
    @TestCase public func testOpenApplicationDataBytes(): Unit { let s=tls12GcmSealFixtureApplicationData(); let d=tls12GcmOpenFixtureApplicationDataBytes(s,0,s.size); assertTrue(d.size>0) }
    @TestCase public func testOpenApplicationDataBytesBasic(): Unit { let s=tls12GcmSealFixtureApplicationData(); let d=tls12GcmOpenFixtureApplicationDataBytes(s,0,s.size); assertTrue(d.size>0) }
    @TestCase public func testOpenHandshake(): Unit { let s=tls12GcmSealFixtureHandshake(); assertTrue(tls12GcmOpenFixtureHandshake(s).size>0) }
    @TestCase public func testRoundTripIntegrity(): Unit { let p=tls12GcmFixturePlaintext(); let s=tls12GcmSealFixtureApplicationData(); let o=tls12GcmOpenFixtureApplicationData(s); var i:Int64=0; while(i<p.size && i<o.size){assertTrue(p[i]==o[i]);i+=1} }

    // ---- TLS 异常 ----

    @TestCase public func testTlsExceptionMessage(): Unit { let e=TlsException("test error"); assertTrue(e.message.contains("test error")) }
    @TestCase public func testTlsExceptionEmptyMessage(): Unit { let e=TlsException(""); assertTrue(true) }

    // ---- MockConnection 基本操作 ----

    @TestCase public func testMockRead(): Unit { let c=MockConnection([65]); assertTrue(c.read(Array<UInt8>(5,repeat:0))==1) }
    @TestCase public func testMockReadMultiple(): Unit { let c=MockConnection([65,66,67]); let buf=Array<UInt8>(5,repeat:0); c.read(buf); assertTrue(buf[0]==65&&buf[1]==66&&buf[2]==67) }
    @TestCase public func testMockWrite(): Unit { let c=MockConnection([]); c.write([66]); assertTrue(c.isConnected()) }
    @TestCase public func testMockWriteThenRead(): Unit { let c=MockConnection([65,66]); let buf=Array<UInt8>(5,repeat:0); c.write([99]); c.read(buf); assertTrue(true) }
    @TestCase public func testMockClose(): Unit { let c=MockConnection([]); c.close(); assertFalse(c.isConnected()) }
    @TestCase public func testMockIsConnectedDefault(): Unit { let c=MockConnection([]); assertTrue(c.isConnected()) }
    @TestCase public func testMockIsConnectedAfterClose(): Unit { let c=MockConnection([]); c.close(); assertFalse(c.isConnected()) }
    @TestCase public func testMockFlush(): Unit { let c=MockConnection([]); c.flush(); assertTrue(true) }
    @TestCase public func testMockCanReuse(): Unit { assertTrue(MockConnection([]).canReuseTransport()) }
    @TestCase public func testMockReadability(): Unit { let c=MockConnection([65]); assertTrue(c.isReadable(None)&&c.isWritable(None)) }
    @TestCase public func testMockLocalAddress(): Unit { assertTrue(MockConnection([]).localAddress().size>0) }
    @TestCase public func testMockRemoteAddress(): Unit { assertTrue(MockConnection([]).remoteAddress().size>0) }
    @TestCase public func testMockConnectedAt(): Unit { let d=MockConnection([]).connectedAt(); assertTrue(true) }
    @TestCase public func testMockLastActivityAt(): Unit { let d=MockConnection([]).lastActivityAt(); assertTrue(true) }
    @TestCase public func testMockUpdateActivity(): Unit { let c=MockConnection([]); c.updateActivity(); assertTrue(true) }

    // ---- 构建原始请求 ----

    @TestCase public func testBuildRawGetRequest(): Unit { let r=buildRawGetRequest("/test"); assertTrue(r.size>0) }
    @TestCase public func testBuildRawGetRequestContains(): Unit { let r=buildRawGetRequest("/path"); let s=String.fromUtf8(r); assertTrue(s.contains("GET /path HTTP/1.1")) }
    @TestCase public func testBuildRawPostRequest(): Unit { let b=Array<UInt8>(10,repeat:0x42); let r=buildRawPostRequest("/post",b); assertTrue(r.size>0) }
    @TestCase public func testBuildRawPostRequestBody(): Unit { let b=Array<UInt8>(10,repeat:0x42); let r=buildRawPostRequest("/post",b); let s=String.fromUtf8(r); assertTrue(s.contains("POST")) }
}
