package http_lib.client

private func assertTrue(condition: Bool, msg!: String = ""): Unit {
    if (!condition) { throw Exception("assertion failed: ${msg}") }
}

private func assertFalse(condition: Bool, msg!: String = ""): Unit {
    assertTrue(!condition, msg: msg)
}

@Test
public class ClientTraceTest {

    @TestCase
    public func testTraceInitNone(): Unit {
        let trace = ClientTrace()
        assertTrue(trace.dnsStartHook.isNone())
        assertTrue(trace.dnsDoneHook.isNone())
        assertTrue(trace.connectStartHook.isNone())
        assertTrue(trace.connectDoneHook.isNone())
        assertTrue(trace.tlsHandshakeStartHook.isNone())
        assertTrue(trace.tlsHandshakeDoneHook.isNone())
        assertTrue(trace.gotConnectionHook.isNone())
        assertTrue(trace.wroteRequestHook.isNone())
        assertTrue(trace.gotFirstResponseByteHook.isNone())
    }

    @TestCase
    public func testTraceSetHooks(): Unit {
        let trace = ClientTrace()
        trace.dnsStartHook = {host => ()}
        trace.dnsDoneHook = {host, addrs => ()}
        trace.connectStartHook = {host, port => ()}
        trace.connectDoneHook = {host, port, net => ()}
        trace.tlsHandshakeStartHook = {=> ()}
        trace.tlsHandshakeDoneHook = {version, cipher, server => ()}
        trace.gotConnectionHook = {reused => ()}
        trace.wroteRequestHook = {=> ()}
        trace.gotFirstResponseByteHook = {=> ()}
        assertTrue(trace.dnsStartHook.isSome())
        assertTrue(trace.gotFirstResponseByteHook.isSome())
    }
}
