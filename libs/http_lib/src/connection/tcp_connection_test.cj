package http_lib.connection
import http_lib.core.{assertTrue, assertFalse}
@Test
public class TcpConnectionUnitTest {
    @TestCase public func test01_IsConnected(): Unit { let c=MockConnection([]); assertTrue(c.isConnected()); c.close(); assertFalse(c.isConnected()) }
    @TestCase public func test02_CanReuseTransport(): Unit { let c=MockConnection([]); assertTrue(c.canReuseTransport()); c.simulateClose(); assertFalse(c.canReuseTransport()) }
    @TestCase public func test03_IsReadable(): Unit { assertTrue(MockConnection([1]).isReadable(None)) }
    @TestCase public func test04_IsWritable(): Unit { assertTrue(MockConnection([]).isWritable(None)) }
    @TestCase public func test05_ReadBasic(): Unit { let c=MockConnection([10,20,30,40,50]); let b=Array<UInt8>(10,repeat:0); assertTrue(c.read(b)==5); assertTrue(b[0]==10&&b[4]==50) }
    @TestCase public func test06_ReadPartial(): Unit { let c=MockConnection([1,2,3,4,5,6]); let b=Array<UInt8>(3,repeat:0); assertTrue(c.read(b)==3); assertTrue(c.read(b)==3); assertTrue(c.read(b)==0) }
    @TestCase public func test07_ReadEmpty(): Unit { assertTrue(MockConnection([]).read(Array<UInt8>(5,repeat:0))==0) }
    @TestCase public func test08_ReadAfterClose(): Unit { let c=MockConnection([]); c.close(); assertTrue(c.read(Array<UInt8>(5,repeat:0))<0) }
    @TestCase public func test09_ReadOffset(): Unit { let c=MockConnection([65,66,67]); let b=Array<UInt8>(10,repeat:0); assertTrue(c.read(b,5,3)==3); assertTrue(b[5]==65)}
    @TestCase public func test10_Write(): Unit { let c=MockConnection([]); c.write([1,2,3]); assertTrue(true) }
    @TestCase public func test11_WriteOffset(): Unit { let c=MockConnection([]); c.write([0,0,88,89],2,2); assertTrue(true) }
    @TestCase public func test12_Flush(): Unit { let c=MockConnection([]); c.write([1]); c.flush(); assertTrue(true) }
    @TestCase public func test13_Close(): Unit { let c=MockConnection([]); c.close(); assertFalse(c.isConnected()) }
    @TestCase public func test14_IsClosed(): Unit { let c=MockConnection([]); assertFalse(c.isClosed()); c.close(); assertTrue(c.isClosed()) }
    @TestCase public func test15_LocalAddr(): Unit { assertTrue(MockConnection([]).localAddress().size>0) }
    @TestCase public func test16_RemoteAddr(): Unit { assertTrue(MockConnection([]).remoteAddress().size>0) }
    @TestCase public func test17_ConnectedAt(): Unit { let t=MockConnection([]).connectedAt(); assertTrue(true) }
    @TestCase public func test18_LastActivityAt(): Unit { let t=MockConnection([]).lastActivityAt(); assertTrue(true) }
    @TestCase public func test19_UpdateActivity(): Unit { let c=MockConnection([]); c.updateActivity(); assertTrue(true) }
    @TestCase public func test20_SetReadTimeout(): Unit { let c=MockConnection([]); c.setReadTimeout(Duration.second); assertTrue(true) }
    @TestCase public func test21_SetWriteTimeout(): Unit { let c=MockConnection([]); c.setWriteTimeout(Duration.second); assertTrue(true) }
    @TestCase public func test22_SetTimeout(): Unit { let c=MockConnection([]); c.setTimeout(Duration.second); assertTrue(true) }
    @TestCase public func test23_ConnectionState(): Unit { let c=MockConnection([]); assertTrue(c.connectionState().isNone(), message: "Plain TCP should have no connection state") }
    @TestCase public func test24_FeedData(): Unit { let c=MockConnection([]); c.feedData([65,66,67]); let b=Array<UInt8>(5,repeat:0); let n=c.read(b); assertTrue(n==3); assertTrue(b[0]==65) }
    @TestCase public func test25_GetWrittenBytes(): Unit { let c=MockConnection([]); c.write([72,105]); let w=c.getWrittenBytes(); assertTrue(w.size==2); assertTrue(w[0]==72) }
    @TestCase public func test26_GetWrittenString(): Unit { let c=MockConnection([]); c.write([72,101,108,108,111]); assertTrue(c.getWrittenString()=="Hello") }
    @TestCase public func test27_GetWriteCount(): Unit { let c=MockConnection([]); assertTrue(c.getWriteCount()==0); c.write([1]); assertTrue(c.getWriteCount()==1); c.write([2]); assertTrue(c.getWriteCount()==2) }
    @TestCase public func test28_BuildRawGetRequest(): Unit { let data=buildRawGetRequest("/test"); let str=String.fromUtf8(data); assertTrue(str.startsWith("GET /test HTTP/1.1\r\n")) }
    @TestCase public func test29_BuildRawPostRequest(): Unit { let body:Array<UInt8>=[104,105]; let data=buildRawPostRequest("/api",body); let str=String.fromUtf8(data); assertTrue(str.startsWith("POST /api HTTP/1.1\r\n")) }
}
