package http_lib.buffer

/**
 * ByteBuffer 性能基准测试。
 */
@Test public class ByteBufferBench {
    @Bench
    public func writeAndRead(): Unit {
        let buf = ByteBuffer(capacity: 128)
        let data = Array<UInt8>(64, repeat: 0x42)
        buf.write(data)
        let _ = buf.getArray()
        let _ = buf.getLimit()
    }

    @Bench
    public func growBuffer(): Unit {
        let buf = ByteBuffer(capacity: 64)
        var j: Int64 = 0
        while (j < 10) {
            let data = Array<UInt8>(128, repeat: UInt8(j))
            buf.write(data)
            j += 1
        }
        let _ = buf.getArray()
    }

    @Bench
    public func fromOwned(): Unit {
        let data = Array<UInt8>(1024, repeat: 0x42)
        let buf = ByteBuffer.fromOwned(data)
        let _ = buf.getLimit()
    }
}
