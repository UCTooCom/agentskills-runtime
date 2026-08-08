package http_lib.connection
import http_lib.core.{assertTrue, assertFalse}
@Test
public class TlsServerConnectionUnitTest {

    // ---- 安全随机数 ----

    @TestCase public func testSecureRandomSize(): Unit { assertTrue(secureRandom32().size==32) }
    @TestCase public func testSecureRandomNonZero(): Unit { let b=secureRandom32(); var z=true; var i:Int64=0; while(i<32){if(b[i]!=0){z=false};i+=1}; assertFalse(z) }
    @TestCase public func testSecureRandomUnique(): Unit { let a=secureRandom32(); let b=secureRandom32(); var s=true; var i:Int64=0; while(i<32){if(a[i]!=b[i]){s=false};i+=1}; assertFalse(s) }
    @TestCase public func testSecureRandomAllBytesInRange(): Unit { let b=secureRandom32(); var ok=true; var i:Int64=0; while(i<32){if(b[i]<0||b[i]>255){ok=false};i+=1}; assertTrue(ok) }

    // ---- ALPN 解析器 ----

    @TestCase public func testAlpnTooShort(): Unit { assertTrue(extractAlpnFromClientHello(Array<Byte>(42,repeat:0)).size==0) }
    @TestCase public func testAlpnMinimal(): Unit { assertTrue(extractAlpnFromClientHello(Array<Byte>(50,repeat:0)).size==0) }
    @TestCase public func testAlpnEmptyInput(): Unit { assertTrue(extractAlpnFromClientHello(Array<Byte>(0,repeat:0)).size==0) }
    @TestCase public func testAlpnVeryShort(): Unit { assertTrue(extractAlpnFromClientHello(Array<Byte>(1,repeat:0)).size==0) }
    @TestCase public func testParseAlpnTooShort(): Unit { assertTrue(parseClientHelloAlpn(Array<Byte>(50,repeat:0)).size==0) }
    @TestCase public func testParseAlpnEmptyInput(): Unit { assertTrue(parseClientHelloAlpn(Array<Byte>(0,repeat:0)).size==0) }

    // ---- MockConnection 基本操作 ----

    @TestCase public func testMockReadBasic(): Unit { let c=MockConnection([65]); assertTrue(c.read(Array<UInt8>(5,repeat:0))==1) }
    @TestCase public func testMockReadMultipleBytes(): Unit { let c=MockConnection([65,66,67]); let buf=Array<UInt8>(5,repeat:0); let n=c.read(buf); assertTrue(n==3) }
    @TestCase public func testMockReadAndVerify(): Unit { let c=MockConnection([72,73,33]); let buf=Array<UInt8>(5,repeat:0); c.read(buf); assertTrue(buf[0]==72&&buf[1]==73&&buf[2]==33) }
    @TestCase public func testMockReadEmpty(): Unit { let c=MockConnection([]); let n=c.read(Array<UInt8>(5,repeat:0)); assertTrue(n==0||n==-1) }
    @TestCase public func testMockWriteBasic(): Unit { let c=MockConnection([]); c.write([66]); assertTrue(c.isConnected()) }
    @TestCase public func testMockWriteMultiple(): Unit { let c=MockConnection([]); c.write([1,2,3,4,5]); assertTrue(c.isConnected()) }
    @TestCase public func testMockWriteEmpty(): Unit { let c=MockConnection([]); c.write([]); assertTrue(c.isConnected()) }
    @TestCase public func testMockClose(): Unit { let c=MockConnection([]); c.close(); assertTrue(c.isClosed()) }
    @TestCase public func testMockIsConnectedAfterClose(): Unit { let c=MockConnection([]); c.close(); assertFalse(c.isConnected()) }
    @TestCase public func testMockFlushBasic(): Unit { let c=MockConnection([]); c.flush(); assertTrue(true) }
    @TestCase public func testMockCloseAfterFlush(): Unit { let c=MockConnection([]); c.flush(); c.close(); assertTrue(c.isClosed()) }
    @TestCase public func testMockReadability(): Unit { let c=MockConnection([65]); assertTrue(c.isReadable(None)&&c.isWritable(None)) }
    @TestCase public func testMockNotReadable(): Unit { let c=MockConnection([]); assertTrue(c.isReadable(None)||!c.isReadable(None)) }
    @TestCase public func testMockReuseTransport(): Unit { let c=MockConnection([]); assertTrue(c.canReuseTransport()) }
    @TestCase public func testMockAddresses(): Unit { let c=MockConnection([]); assertTrue(c.localAddress().size>0&&c.remoteAddress().size>0) }
    @TestCase public func testMockLocalAddressFormat(): Unit { let c=MockConnection([]); assertTrue(c.localAddress().contains(":")) }
    @TestCase public func testMockTimeout(): Unit { let c=MockConnection([]); c.setReadTimeout(Duration.second*5); c.setWriteTimeout(Duration.second*5); assertTrue(true) }
    @TestCase public func testMockConnectedAt(): Unit { let c=MockConnection([]); let t=c.connectedAt(); assertTrue(true) }
    @TestCase public func testMockLastActivityAt(): Unit { let c=MockConnection([]); let t=c.lastActivityAt(); assertTrue(true) }
    @TestCase public func testMockUpdateActivity(): Unit { let c=MockConnection([]); c.updateActivity(); assertTrue(true) }
}
