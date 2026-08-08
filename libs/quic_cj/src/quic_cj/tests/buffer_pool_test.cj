package quic_cj.tests

import quic_cj.sys.{UdpBufferPool, getUdpBuffer, putUdpBuffer}

@Test
public class BufferPoolTestSuite {
    @TestCase
    public func testUdpBufferPoolBasics(): Unit {
        let pool = UdpBufferPool()
        @Assert(pool.len(), 0)
        let buf = pool.get()
        @Assert(buf.size, 1452)
        pool.put(buf)
        @Assert(pool.len(), 1)
        let recycled = pool.get()
        @Assert(recycled.size, 1452)
        @Assert(pool.len(), 0)
    }

    @TestCase
    public func testGlobalPool(): Unit {
        let buf = getUdpBuffer()
        @Assert(buf.size, 1452)
        putUdpBuffer(buf)
    }

    @TestCase
    public func testPoolMultipleBuffers(): Unit {
        let pool = UdpBufferPool()
        var i: Int64 = 0
        while (i < 5) {
            let b = pool.get()
            pool.put(b)
            i += 1
        }
        @Assert(pool.len(), 1)
    }

    @TestCase
    public func testPoolGetAfterPutMaintainsCapacity(): Unit {
        let pool = UdpBufferPool()
        let buf1 = pool.get()
        pool.put(buf1)
        let recycled = pool.get()
        @Assert(recycled.size, 1452)
        pool.put(recycled)
    }

    @TestCase
    public func testGlobalPoolRoundTrip(): Unit {
        let buf = getUdpBuffer()
        @Assert(buf.size, 1452)
        putUdpBuffer(buf)
        let buf2 = getUdpBuffer()
        @Assert(buf2.size, 1452)
        putUdpBuffer(buf2)
    }
}
