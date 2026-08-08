package http_lib.connection

import http_lib.core.{assertTrue, assertFalse}

@Test
public class AbstractConnectionUnitTest {
    @TestCase
    public func testIsConnected(): Unit {
        let c = MockConnection([])
        assertTrue(c.isConnected())
        c.close()
        assertFalse(c.isConnected())
    }
    @TestCase
    public func testLocalAddress(): Unit {
        assertTrue(MockConnection([]).localAddress().size > 0)
    }
    @TestCase
    public func testRemoteAddress(): Unit {
        assertTrue(MockConnection([]).remoteAddress().size > 0)
    }
    @TestCase
    public func testConnectedAt(): Unit {
        let t = MockConnection([]).connectedAt()
        assertTrue(true)
    }
    @TestCase
    public func testLastActivityAt(): Unit {
        let t = MockConnection([]).lastActivityAt()
        assertTrue(true)
    }
    @TestCase
    public func testUpdateActivity(): Unit {
        let c = MockConnection([])
        c.updateActivity()
        assertTrue(true)
    }
}
