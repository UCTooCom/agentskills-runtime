/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2025. All rights reserved.
 */

/**
 * @file
 *
 * Define commonly used streaming types for compression
 */
package compress4cj.zlib
import compress4cj.common.Zlib4cjException

import std.io.*

sealed abstract class CompressOutputStream <: OutputStream & Resource {
    let out : OutputStream
    let deflater: Deflate
    var buf: Array<Byte>
    var closed: Bool
    var syncFlush: Bool
    var ownDeflate: Bool
    var aotuOutClose: Bool

    protected var error: Int32
    
    @Frozen
    protected init(out: OutputStream, deflater: Deflate, bufferSize: Int64,
        ownDeflate: Bool, aotuOutClose: Bool) {
        let bufsize = if (bufferSize <= 0) {
            1024
        } else {
            bufferSize
        }
        this.out = out
        this.deflater = deflater
        this.buf = Array<Byte>(bufsize, repeat: 0)
        this.closed = false
        this.error = 0
        this.syncFlush = false
        this.ownDeflate = ownDeflate
        this.aotuOutClose = aotuOutClose
        
    }

    @Frozen
    public open func setDictionary(dict: Array<UInt8>): Int32

    @Frozen
    public func write(buffer: Array<Byte>): Unit {
        if (this.deflater.finished) {
            return
        }
        else if (buffer.size == 0) {
            return
        }
        let flush = if (this.syncFlush) {
            Z_SYNC_FLUSH
        } else {
            Z_NO_FLUSH
        }
        this.deflater.setInBuf(buffer)
        while(this.deflater.avail_in > 0) {
            this.deflater.setOutBuf(this.buf)
            this.error = this.deflater.deflate(flush)
            let len = this.deflater.pos_out
            if (len > 0) {
                this.out.write(this.buf[0..len])
                this.deflater.resetOutBuf()
            }
            if (this.error == Z_OK) {}
            else if (this.error == Z_STREAM_END) {
                break
            }
            else if (this.error == Z_BUF_ERROR) {
                if (this.deflater.avail_out <= 0 && flush != Z_FINISH) {
                    break
                }
            }
            else {
                throw IOException(deflater.message)  // cjlint-ignore !G.ERR.02 description
            }
        }
    }

    @Frozen
    public func getErrorCode(): Int32 {
        return this.error
    }

    @Frozen
    public  func flush(): Unit {
        if (this.closed) {
            return
        }
        if (syncFlush && !deflater.finished) {
            while (true) {
                this.deflater.setOutBuf(this.buf)
                this.error = this.deflater.deflate(Z_SYNC_FLUSH)

                let len = this.deflater.pos_out
                if (len > 0) {
                    this.out.write(this.buf[0..len])
                    this.deflater.resetOutBuf()
                }
                if (this.error == Z_OK) {}
                else if (this.error == Z_STREAM_END) {
                    break
                }
                else if (this.error == Z_BUF_ERROR) {
                    if (this.deflater.avail_out <= 0 && Z_SYNC_FLUSH != Z_FINISH) {
                        break
                    }
                }
                else {
                    throw IOException(deflater.message)  // cjlint-ignore !G.ERR.02 description
                }
                if (this.deflater.pos_out < this.buf.size) {
                    break
                }
                if (this.error == Z_STREAM_END) {
                    break
                }
            }
        }
        this.out.flush()
    }

    @Frozen
    public func close(): Unit {
        if (this.closed) {
            return
        }
        this.finish()
        if (this.aotuOutClose) {
            if (let Some(v) <- (this.out as Resource)) {
                v.close()
            }
        }
        if (this.ownDeflate) {
            this.deflater.deflateEnd()
        }
    }

    @Frozen
    public func finish(): Unit {
        if (this.closed) {
            return
        }
        this.deflater.setOutBuf(this.buf)
        while (true) {
            this.error = this.deflater.deflate(Z_FINISH)
            let len = this.deflater.pos_out
            if (len > 0) {
                this.out.write(this.buf[0..len])
                this.deflater.resetOutBuf()
            }
            if (this.error == Z_OK) {}
            else if (this.error == Z_STREAM_END) {
                break
            }
            else if (this.error == Z_BUF_ERROR) {
            }
            else {
                throw IOException(deflater.message)  // cjlint-ignore !G.ERR.02 description
            }
        }
    }

    @Frozen
    public open func getTotalIn(): Int64 {
        return this.deflater.getTotalIn()
    }

    @Frozen
    public open func getTotalOut(): Int64 {
        return this.deflater.getTotalOut()
    }

    @Frozen
    public open func getAvailIn(): Int64 {
        return this.deflater.avail_in
    }

    @Frozen
    public open func getPositionOut(): Int64 {
        return this.deflater.getOutDataLength()
    }

    @Frozen
    public open func getDeflater(): Deflate {
        return this.deflater
    }

    @Frozen
    public open func isClosed(): Bool{
        return this.closed
    }
}


public class DeflaterOutputStream <: CompressOutputStream {
    @Frozen
    public init(out: OutputStream,
                bufferSize!: Int64 = 1024,
                level!: Int64 = 6,
                memLevel!: UInt32 = DEF_MEM_LEVEL,
                strategy!: UInt32 = Z_DEFAULT_STRATEGY) {
        super(out, Deflate(), bufferSize, true, true)
        let lev = if (level < 0 || level > 9) {
            6
        } else {
            level
        }
        let mem = if (memLevel < 1 || memLevel > 9) {
            DEF_MEM_LEVEL
        } else {
            memLevel
        }
        let str = if (strategy < 0 || strategy > 4) {
            Z_DEFAULT_STRATEGY
        } else {
            strategy
        }
        this.deflater.deflateInit2(lev, -15, mem, str)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {
        return this.deflater.setDictionary(dict)
    }
}

public class GzipOutputStream <: CompressOutputStream {
    @Frozen
    public init(out: OutputStream,
                bufferSize!: Int64 = 1024,
                level!: Int64 = 6,
                memLevel!: UInt32 = DEF_MEM_LEVEL,
                strategy!: UInt32 = Z_DEFAULT_STRATEGY) {
        super(out, Deflate(), bufferSize, true, true)
        let lev = if (level < 0 || level > 9) {
            6
        } else {
            level
        }
        let mem = if (memLevel < 1 || memLevel > 9) {
            DEF_MEM_LEVEL
        } else {
            memLevel
        }
        let str = if (strategy < 0 || strategy > 4) {
            Z_DEFAULT_STRATEGY
        } else {
            strategy
        }
        this.deflater.deflateInit2(lev, 15 + 16, mem, str)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {   // cjlint-ignore !G.FUN.02 description
        throw Zlib4cjException("GzipOutputStream does not support setDictionary")
    }
}

public class ZlibOutputStream <: CompressOutputStream {
    @Frozen
    public init(out: OutputStream,
                bufferSize!: Int64 = 1024,
                level!: Int64 = 6,
                memLevel!: UInt32 = DEF_MEM_LEVEL,
                strategy!: UInt32 = Z_DEFAULT_STRATEGY) {
        super(out, Deflate(), bufferSize, true, true)
        let lev = if (level < 0 || level > 9) {
            6
        } else {
            level
        }
        let mem = if (memLevel < 1 || memLevel > 9) {
            DEF_MEM_LEVEL
        } else {
            memLevel
        }
        let str = if (strategy < 0 || strategy > 4) {
            Z_DEFAULT_STRATEGY
        } else {
            strategy
        }
        this.deflater.deflateInit2(lev, 15, mem, str)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {
        return this.deflater.setDictionary(dict)
    }
}

sealed abstract class CompressInputStream <: InputStream {
    let input: InputStream
    //从输入流中读取数据，存在 this.buf 中，用于后续压缩。
    var inbuf: Array<Byte>
    //let out: ByteArrayStream
    let deflater: Deflate
    var buf: Array<Byte>
    var closed: Bool
    var syncFlush: Bool
    var ownDeflate: Bool
    var aotuOutClose: Bool
    var totalread: Int64

    //已到达基础输入流的末尾。
    private var reachEOF: Bool = false

    //读取到的压缩好的数据长度
    var cnt: Int64 = 0
    //需要读取的压缩好的数据长度
    var sum: Int64 = 0
    
    @Frozen
    protected init(input: InputStream, deflater: Deflate, size: Int64,
        ownDeflate: Bool, aotuOutClose: Bool) {
        let bufsize = if (size <= 0) {
            1024
        } else {
            size
        }
        this.input = input
        //this.out = ByteArrayStream()
        this.deflater = deflater
        //从输入流中读取数据，存在 this.buf 中，用于后续压缩。
        this.inbuf = Array<Byte>(bufsize, repeat: 0)
        this.buf = NULL_ARR_UINT8
        this.closed = false
        this.syncFlush = false
        this.ownDeflate = ownDeflate
        this.aotuOutClose = aotuOutClose
        this.totalread = 0
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32

    @Frozen
    public func read(buffer: Array<Byte>): Int64 {
        if (this.deflater.finished) {
            return -1
        }
        else if (buffer.size == 0) {
            return 0
        }
        let flush = if (this.syncFlush) {
            Z_SYNC_FLUSH
        } else {
            Z_NO_FLUSH
        }

        this.buf = buffer

        var off: Int64 = 0
        var len: Int64 = buffer.size
        this.cnt = 0
        this.sum = buffer.size

        while(cnt < sum && len > 0 && !this.deflater.finished) {
            var n: Int64 = 0
            if (this.deflater.avail_in <= 0) {
                n = this.input.read(this.inbuf)
                this.totalread += n
                if (n <= 0 && this.totalread > 0) {
                    //已到达输入流的末尾
                    this.finish()
                } else if (n > 0) {
                    this.deflater.setInBuf(this.inbuf, 0, n)
                } else if (n <= 0) {//从 arkts 流端多次向 InputStream 中写入待压缩数据
                    return cnt
                }
            }

            while(cnt < sum && this.deflater.avail_in > 0) {
                this.deflater.setOutBuf(this.buf, cnt, sum - cnt)

                let err = this.deflater.deflate(flush)
                n = this.deflater.pos_out - cnt
                if (n > 0) {
                    cnt += n
                    off += n
                    len -= n

                    this.deflater.resetOutBuf()
                }
                if (err == Z_OK) {}
                else if (err == Z_STREAM_END) {
                    break
                }
                else if (err == Z_BUF_ERROR) {
                    if (this.deflater.avail_out <= 0 && flush != Z_FINISH) {
                        break
                    }
                }
                else {
                    throw IOException(deflater.message)   // cjlint-ignore !G.ERR.02 description
                }
            }
        }
        if (cnt == 0 && this.deflater.finished) {
            reachEOF = true
            cnt = -1
        }

        return cnt
    }

    @Frozen
    public func close(): Unit {
        if (this.closed) {
            return
        }
        // this.finish()
        if (this.ownDeflate) {
            this.deflater.deflateEnd()
        }
    }

    func finish(): Unit {
        if (this.closed) {
            return
        }
        this.deflater.setOutBuf(this.buf, cnt, sum - cnt)
        while (cnt < sum) {
            let err = this.deflater.deflate(Z_FINISH)
            let len = this.deflater.pos_out - cnt
            if (len > 0) {
                cnt += len
                this.deflater.resetOutBuf()
            }
            if (err == Z_OK) {}
            else if (err == Z_STREAM_END) {
                break
            }
            else if (err == Z_BUF_ERROR) {
            }
            else {
                throw IOException(deflater.message)  // cjlint-ignore !G.ERR.02 description
            }
        }
    }

    public open func getTotalIn(): Int64 {
        return this.deflater.getTotalIn()
    }

    public open func getTotalOut(): Int64 {
        return this.deflater.getTotalOut()
    }
    public open func getAvailIn(): Int64 {
        return this.deflater.avail_in
    }
    public open func getPositionOut(): Int64 {
        return this.deflater.getOutDataLength()
    }

    public open func getDeflater(): Deflate {
        return this.deflater
    }

    public open func isClosed(): Bool{
        return this.closed
    }
}

public class DeflaterInputStream <: CompressInputStream {
    public init(in_: InputStream, 
                bufferSize!: Int64 = 1024,
                level!: Int64 = 6,
                memLevel!: UInt32 = DEF_MEM_LEVEL,
                strategy!: UInt32 = Z_DEFAULT_STRATEGY) {
        super(in_, Deflate(), bufferSize, true, true)
        let lev = if (level < 0 || level > 9) {
            6
        } else {
            level
        }
        let mem = if (memLevel < 1 || memLevel > 9) {
            DEF_MEM_LEVEL
        } else {
            memLevel
        }
        let str = if (strategy < 0 || strategy > 4) {
            Z_DEFAULT_STRATEGY
        } else {
            strategy
        }
        this.deflater.deflateInit2(lev, -15, mem, str)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {
        return this.deflater.setDictionary(dict)
    }
}

public class GzipInputStream <: CompressInputStream {
    public init(in_: InputStream, 
                bufferSize!: Int64 = 1024,
                level!: Int64 = 6,
                memLevel!: UInt32 = DEF_MEM_LEVEL,
                strategy!: UInt32 = Z_DEFAULT_STRATEGY) {
        super(in_, Deflate(), bufferSize, true, true)
        let lev = if (level < 0 || level > 9) {
            6
        } else {
            level
        }
        let mem = if (memLevel < 1 || memLevel > 9) {
            DEF_MEM_LEVEL
        } else {
            memLevel
        }
        let str = if (strategy < 0 || strategy > 4) {
            Z_DEFAULT_STRATEGY
        } else {
            strategy
        }
        this.deflater.deflateInit2(lev, 15 + 16, mem, str)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {  // cjlint-ignore !G.FUN.02 description
        throw Zlib4cjException("GzipInputStream does not support setDictionary")
    }
}

public class ZlibInputStream <: CompressInputStream {
    public init(in_: InputStream, 
                bufferSize!: Int64 = 1024,
                level!: Int64 = 6,
                memLevel!: UInt32 = DEF_MEM_LEVEL,
                strategy!: UInt32 = Z_DEFAULT_STRATEGY) {
        super(in_, Deflate(), bufferSize, true, true)
        let lev = if (level < 0 || level > 9) {
            6
        } else {
            level
        }
        let mem = if (memLevel < 1 || memLevel > 9) {
            DEF_MEM_LEVEL
        } else {
            memLevel
        }
        let str = if (strategy < 0 || strategy > 4) {
            Z_DEFAULT_STRATEGY
        } else {
            strategy
        }
        this.deflater.deflateInit2(lev, 15, mem, str)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {
        return this.deflater.setDictionary(dict)
    }
}



