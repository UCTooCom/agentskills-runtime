package quic_cj.tests

import quic_cj.{Config, Transport, Conn, ListenerImpl}

/// ListenerImpl 测试套件
@Test
public class ListenerImplTestSuite {
    /// 测试 ListenerImpl 的地址返回
    @TestCase
    public func testListenerAddr(): Unit {
        let addr = "127.0.0.1:0"
        let cfg = Config()
        let t = Transport(addr, cfg)
        let lis = ListenerImpl(addr, t)
        @Assert(lis.addr(), addr)
    }

    /// 测试 ListenerImpl 的关闭和后续 accept 行为
    @TestCase
    public func testListenerCloseAndReject(): Unit {
        let addr = "127.0.0.1:0"
        let cfg = Config()
        let t = Transport(addr, cfg)
        let lis = ListenerImpl(addr, t)
        lis.close()
        let none = match (lis.accept()) { case None => true; case _ => false }
        @Assert(none, true)
    }
}
