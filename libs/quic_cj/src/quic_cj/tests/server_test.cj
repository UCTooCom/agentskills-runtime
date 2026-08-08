package quic_cj.tests

import quic_cj.{listenAddr, listen, dialAddr, dial, Config}

@Test
public class ServerTestSuite {
    @TestCase
    public func testListenAddr(): Unit {
        let some1 = match (listenAddr("127.0.0.1:0", Config())) { case Some(_) => true; case _ => false }
        @Assert(some1, true)
    }

    @TestCase
    public func testListen(): Unit {
        let some2 = match (listen("127.0.0.1:0")) { case Some(_) => true; case _ => false }
        @Assert(some2, true)
    }

    @TestCase
    public func testDial(): Unit {
        let some3 = match (dial("127.0.0.1:1234")) { case Some(_) => true; case _ => false }
        @Assert(some3, true)
    }
}
