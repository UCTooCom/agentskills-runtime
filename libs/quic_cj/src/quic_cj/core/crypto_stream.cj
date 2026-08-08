 package quic_cj.core

 import quic_cj.protocol.{EncryptionLevel, MAX_BYTE_COUNT}
 import quic_cj.wire.CryptoFrame

 /// BaseCryptoStream 提供 CRYPTO 数据帧的基本处理逻辑。
 /// 使用 FrameSorter 对乱序到达的 CRYPTO 帧数据进行排序重组。
 internal class BaseCryptoStream {
     private var sorter: FrameSorter = FrameSorter()
     private var recvBuf: Array<Byte> = []
     private var highestOffset: Int64 = 0
     private var finished: Bool = false

     // 用于发送
     private var writeBuf: Array<Byte> = []
     private var writeOffset: Int64 = 0

     public init() {}

     /// 处理收到的 CRYPTO 帧。
     public func handleCryptoFrame(f: CryptoFrame): Bool {
         let highestOff: Int64 = f.offset + Int64(f.data.size)
         if (highestOff > highestOffset) { highestOffset = highestOff }
         if (finished) { return false }
         sorter.push(f.data, f.offset)
         true
     }

     /// 获取已排序的 CRYPTO 数据。
     public func getCryptoData(): Array<Byte> {
         let (offset, data) = sorter.pop()
         if (data.size == 0) { return [] }
         recvBuf = appendBytesToArray(recvBuf, data)
         recvBuf
     }

     /// 标记流已完成。
     public func finish(): Bool {
         if (sorter.hasMoreData()) { return false }
         finished = true
         true
     }

     /// 写入待发送的数据。
     public func writeData(data: Array<Byte>): Unit {
         writeBuf = appendBytesToArray(writeBuf, data)
     }

     public func hasData(): Bool { writeBuf.size > 0 }

    /// 弹出下一个待发送的 CRYPTO 帧。
    public func popCryptoFrame(maxLen: Int64): Option<CryptoFrame> {
        if (writeBuf.size == 0) { return None }
        let n: Int64 = min(maxLen, Int64(writeBuf.size))
        if (n <= 0) { return None }
        let cf = CryptoFrame()
        cf.offset = writeOffset
        cf.data = writeBuf[..n]
        writeBuf = writeBuf[n..]
        writeOffset += n
        Some(cf)
    }
 }

 /// CryptoStream 用于握手和 1-RTT 加密级别。
 public class CryptoStream {
     private var inner: BaseCryptoStream = BaseCryptoStream()

     public init() {}

     public func handleCryptoFrame(f: CryptoFrame): Bool { inner.handleCryptoFrame(f) }
     public func getCryptoData(): Array<Byte> { inner.getCryptoData() }
     public func finish(): Bool { inner.finish() }
     public func writeData(data: Array<Byte>): Unit { inner.writeData(data) }
     public func hasData(): Bool { inner.hasData() }
    public func popCryptoFrame(maxLen: Int64): Option<CryptoFrame> { inner.popCryptoFrame(maxLen) }
}

/// InitialCryptoStream 用于初始加密级别，包含 ClientHello 混淆支持。
public class InitialCryptoStream {
    private var inner: BaseCryptoStream = BaseCryptoStream()

    public init() {}

    public func handleCryptoFrame(f: CryptoFrame): Bool { inner.handleCryptoFrame(f) }
    public func getCryptoData(): Array<Byte> { inner.getCryptoData() }
    public func finish(): Bool { inner.finish() }
    public func writeData(data: Array<Byte>): Unit { inner.writeData(data) }
    public func hasData(): Bool { inner.hasData() }
    public func popCryptoFrame(maxLen: Int64): Option<CryptoFrame> { inner.popCryptoFrame(maxLen) }
 }

 /// 创建新的 CryptoStream。
 public func newCryptoStream(): CryptoStream { CryptoStream() }

 /// 创建新的 InitialCryptoStream。
 public func newInitialCryptoStream(): InitialCryptoStream { InitialCryptoStream() }

 internal func appendBytesToArray(dst: Array<Byte>, src: Array<Byte>): Array<Byte> {
     let n = dst.size
     let m = src.size
     var out = Array<Byte>(n + m, repeat: 0u8)
     var i: Int64 = 0
     while (i < n) { out[i] = dst[i]; i += 1 }
     i = 0
     while (i < m) { out[n + i] = src[i]; i += 1 }
     out
 }
