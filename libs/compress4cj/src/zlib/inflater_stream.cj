/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2025. All rights reserved.
 */

/**
 * @file
 *
 * Define commonly used streaming types for decompression
 */
package compress4cj.zlib
import compress4cj.common.Zlib4cjException
import std.io.*

let DEFAULT_BUFSIZE = 1024
sealed abstract class Inflater <: Resource {
    protected var inflater: Inflate
    protected var buf: Array<Byte>
    protected var closed: Bool
    protected var error: Int32
    protected var closeIn: Bool
    protected var myinflater: Bool

    protected init(i: Inflate) {
        this.inflater = i
        this.buf = Array<Byte>(DEFAULT_BUFSIZE, repeat: 0)
        this.closed = false
        this.error = 0
        this.closeIn = true
        this.myinflater = true
    }
    protected init(i: Inflate, bufsize: Int64) {
        this.inflater = i
        this.buf = Array<Byte>(bufsize, repeat: 0)
        this.closed = false
        this.error = 0
        this.closeIn = true
        this.myinflater = true
    }
    
    @Frozen
    public open func getTotalIn(): Int64 {
        return this.inflater.getTotalIn()
    }

    @Frozen
    public open func getTotalOut(): Int64 {
        return this.inflater.getTotalOut()
    }
    
    @Frozen
    public open func getAvailIn(): Int64 {
        return this.inflater.avail_in
    }

    @Frozen
    public open func getPositionOut(): Int64 {
        return this.inflater.getOutDataLength()
    }

    @Frozen
    public open func getAvailInArray(): Array<Byte> {
        if (this.inflater.avail_in<=0) {
            return NULL_ARR_UINT8
        }
        let tmp = Array<Byte>(this.inflater.avail_in, repeat: 0)
        this.inflater.next_in.copyTo(tmp, this.inflater.pos_in, 0, this.inflater.avail_in)
        return tmp
    }

    @Frozen
    public open func getInflater(): Inflate {
        return this.inflater
    }

    @Frozen
    public open func close(): Unit {
        this.inflater.inflateEnd()
        this.closed = true
    }

    @Frozen
    public open func isClosed(): Bool{
        return this.closed
    }

    @Frozen
    public func getRemaining(): Int64
    
    @Frozen
    public func getErrorCode(): Int32 {
        return this.error
    }

    @Frozen
    public open func setDictionary(dict: Array<UInt8>): Unit {
        if (this.inflater.setDictionary(dict) != Z_OK) {
            throw Zlib4cjException("setDictionary: ${this.inflater.message}")
        }
    }
}

public open class InflaterInputStream <: Inflater & InputStream {
    var dictArray: Array<UInt8> = NULL_ARR_UINT8
    private var input: InputStream
    private var b: Array<Byte>
    protected var inputLimit: Int64 = 0

    @Frozen
    public init(inputStream: InputStream) {
        this(inputStream, Inflate(-1), DEFAULT_BUFSIZE)
    }

    @Frozen
    public init(inputStream: InputStream, bufferSize: Int64) {
        this(inputStream, Inflate(-1), bufferSize)
    }

    @Frozen
    protected init(inputStream: InputStream, i: Inflate) {
        super(i)
        this.b = Array<Byte>(DEFAULT_BUFSIZE, repeat: 0)
        this.input = inputStream
    }

    @Frozen
    protected init(inputStream: InputStream, i: Inflate, bufferSize: Int64) {
        super(i, bufferSize)
        this.b = Array<Byte>(bufferSize, repeat: 0)
        this.input = inputStream
    }

    @Frozen
    public func read(buffer: Array<Byte>): Int64 {
        if (error == Z_STREAM_END) {
            return 0
        }

        if (this.inflater.avail_in == 0) {
            if (this.fill() <= 0) {
                return 0
            }
        }
        inflater.setOutBuf(buffer)
        while(inflater.avail_out > 0 && this.inflater.avail_in > 0) {
            this.error = inflater.inflate(Z_NO_FLUSH)
            if (error >= 0) {
                if (error == Z_STREAM_END) {
                    break
                }
                if (error == Z_NEED_DICT) {
                    if (dictArray.size > 0) {
                        if (this.inflater.setDictionary(dictArray) != Z_OK) {
                            throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                        }
                    } else {
                        throw Zlib4cjException("inflate error: ${error}, ${erroMsg(error)}, but no dictionary set")
                    }
                }
            } else if (error == Z_DATA_ERROR) {
                let syncRet = this.inflater.inflateSync()
                if (syncRet == Z_OK) { // 成功找到同步点，恢复解压
                    continue
                } else if (syncRet == Z_BUF_ERROR) { // 需要更多数据才能恢复
                    break
                } else if (syncRet == Z_STREAM_END) { //恢复失败
                    throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                }
            } else if (error == Z_BUF_ERROR) {
                // Z_BUF_ERROR may indicate insufficient buffer space, just break and continue later
                break
            } else {
                throw Zlib4cjException("inflate error: ${this.inflater.message}")
            }
        }
        return buffer.size - inflater.avail_out
    }
    @Frozen
    protected func fill() {
        if (this.closed) {
            throw IOException("Stream closed")  // cjlint-ignore !G.ERR.02 description
        }
        this.inputLimit = this.input.read(b)
        if (this.inputLimit <= 0) {
            return 0
        }
        else if (this.inputLimit == DEFAULT_BUFSIZE) {
            this.inflater.setInBuf(b)
            return DEFAULT_BUFSIZE
        } else {
            this.inflater.setInBuf(b[0..this.inputLimit])
            return this.inputLimit
        }
    }

    @Frozen
    public func getRemaining(): Int64 {
        return this.inputLimit - this.inflater.pos_in
    }

    @Frozen
    public func close(): Unit {
        super.close()
        this.b = NULL_ARR_UINT8
    }
}

public class UnZlibInputStream <: InflaterInputStream {
    @Frozen
    public init(inputStream: InputStream) {
        super(inputStream, Inflate(1))
    }
    @Frozen
    public init(inputStream: InputStream, bufferSize: Int64) {
        super(inputStream, Inflate(1), bufferSize)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Unit {
        let ret = this.inflater.setDictionary(dict)
        if (ret == Z_OK) {
            return
        }
        if (ret == Z_STREAM_ERROR) {
            this.dictArray = dict
            return
        }
        throw Zlib4cjException("setDictionary: ${this.inflater.message}")
    }
}

public class GunzipInputStream <: InflaterInputStream {
    @Frozen
    public init(inputStream: InputStream) {
        super(inputStream, Inflate(2))
    }
    @Frozen
    public init(inputStream: InputStream, bufferSize: Int64) {
        super(inputStream, Inflate(2), bufferSize)
    }
}

public class AutoDecompressInputStream <: Inflater & Resource {
    var dictArray: Array<UInt8> = NULL_ARR_UINT8
    private var input: InputStream
    private var b: Array<Byte>
    protected var inputLimit: Int64 = 0
    protected var isAuto: Bool = false
    var wrap = 0
    @Frozen
    public init(input: InputStream) {
        this(input, unsafe { zeroValue<Inflate>()}, DEFAULT_BUFSIZE)
    }
    @Frozen
    init(input: InputStream, i: Inflate, bufferSize: Int64) {
        super(i, bufferSize)
        this.input = input
        this.b = Array<Byte>(bufferSize, repeat: 0)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Unit {
        if (this.wrap == 2) {
            throw Zlib4cjException("setDictionary: Cannot set dictionary for gzip stream")
        }
        this.dictArray = dict
    }

    @Frozen
    public func read(buffer: Array<Byte>): Int64 {
        if (error == Z_STREAM_END || closed) {
            return 0
        }
        if (!isAuto) {
            // Automatically detect the compression format
            let header = this.input.read(this.b[0..3])
            if (header < 2) {
                throw IOException("Not enough data to determine compression format")  // cjlint-ignore !G.ERR.02 description
            }
            this.inflater = if (this.b[0] == 0x1F && this.b[1] == 0x8B && this.b[2] == 0x08) {
                wrap = 2
                Inflate(2)
            } else if (
                (this.b[0] & 15) != 8 ||
                (this.b[0] >> 4) > 7 ||
                Int64(Int64(this.b[0]) << 8 | Int64(this.b[1])) % 31 != 0
            ) {
                wrap = 0
                Inflate(-1)
            } else {
                wrap = 1
                Inflate(1)
            }
            this.prefill()
            this.isAuto = true
        }

        if (this.inflater.avail_in == 0) {
            if (this.fill() <= 0) {
                return 0
            }
        }

        this.inflater.setOutBuf(buffer)
        while(inflater.avail_out > 0 && this.inflater.avail_in > 0) {
            this.error = inflater.inflate(Z_NO_FLUSH)
            if (error >= 0) {
                if (error == Z_STREAM_END) {
                    break
                }
                if (error == Z_NEED_DICT) {
                    if (dictArray.size > 0) {
                        if (this.inflater.setDictionary(dictArray) != Z_OK) {
                            throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                        }
                    } else {
                        throw Zlib4cjException("inflate error: ${error}, ${erroMsg(error)}, but no dictionary set")
                    }
                }
            } else if (error == Z_DATA_ERROR) {
                let syncRet = this.inflater.inflateSync()
                if (syncRet == Z_OK) { // 成功找到同步点，恢复解压
                    continue
                } else if (syncRet == Z_BUF_ERROR) { // 需要更多数据才能恢复
                    break
                } else if (syncRet == Z_STREAM_END) { //恢复失败
                    throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                }
            } else if (error == Z_BUF_ERROR) {
                // Z_BUF_ERROR may indicate insufficient buffer space, just break and continue later
                break
            } else {
                throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
            }
        }
        return buffer.size - inflater.avail_out
    }
    
    @Frozen
    protected func prefill() {
        if (this.closed) {
            throw IOException("Stream closed")  // cjlint-ignore !G.ERR.02 description
        }
        this.inputLimit = this.input.read(b[3..]) + 3
        if (this.inputLimit == DEFAULT_BUFSIZE) {
            this.inflater.setInBuf(b)
            return DEFAULT_BUFSIZE
        } else {
            this.inflater.setInBuf(b[0..this.inputLimit])
            return this.inputLimit
        }
    }

    @Frozen
    protected func fill() {
        if (this.closed) {
            throw IOException("Stream closed")  // cjlint-ignore !G.ERR.02 description
        }
        this.inputLimit = this.input.read(b)
        if (this.inputLimit <= 0) {
            return 0
        }
        else if (this.inputLimit == DEFAULT_BUFSIZE) {
            this.inflater.setInBuf(b)
            return DEFAULT_BUFSIZE
        } else {
            this.inflater.setInBuf(b[0..this.inputLimit])
            return this.inputLimit
        }
    }

    @Frozen
    public func getRemaining(): Int64 {
        return this.inputLimit - this.inflater.pos_in
    }

    @Frozen
    public func close(): Unit {
        if (isAuto) {
            this.inflater.inflateEnd()
        }
        this.closed = true
        this.b = NULL_ARR_UINT8
    }

    @Frozen
    public func getTotalIn(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.getTotalIn()
    }

    @Frozen
    public func getTotalOut(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.getTotalOut()
    }
    @Frozen
    public func getAvailIn(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.avail_in
    }
    @Frozen
    public func getPositionOut(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.getOutDataLength()
    }
    @Frozen
    public func getAvailInArray(): Array<Byte> {
        if (!isAuto) {
            return NULL_ARR_UINT8
        }
        if (this.inflater.avail_in<=0) {
            return NULL_ARR_UINT8
        }
        let tmp = Array<Byte>(this.inflater.avail_in, repeat: 0)
        this.inflater.next_in.copyTo(tmp, this.inflater.pos_in, 0, this.inflater.avail_in)
        return tmp
    }

    @Frozen
    public func getInflater(): Inflate {
        if (!isAuto) {
            throw Zlib4cjException("Inflater not initialized. Call read() to initialize.")
        }
        return this.inflater
    }

    @Frozen
    public func isClosed(): Bool{
        return this.closed
    }

}

public class AutoDecompressOutputStream <: Inflater & OutputStream {
    var dictArray: Array<UInt8> = NULL_ARR_UINT8
    var out : OutputStream
    protected var inputLimit: Int64 = 0
    var isAuto = false
    let autoArr = Array<Byte>(3, repeat: 0)
    var autoArrI = 0
    var wrap = 0

    @Frozen
    public init(out: OutputStream) {
        this(out, unsafe { zeroValue<Inflate>()}, DEFAULT_BUFSIZE)
    }

    @Frozen
    init(out: OutputStream, i: Inflate, bufferSize: Int64) {
        super(i, bufferSize)
        this.out = out
    }

    @Frozen
    public func write(buffer: Array<Byte>): Unit {
        if (error == Z_STREAM_END) {
            return
        }
        if (buffer.size == 0) {
            return
        }
        
        if (!this.isAuto) {
            // Collect bytes for format detection
            var bufferOff = 0
            while (autoArrI < 3 && bufferOff < buffer.size) {
                autoArr[autoArrI] = buffer[bufferOff]
                autoArrI++
                bufferOff++
            }
            
            if (autoArrI == 3) {
                // Format detection complete, create appropriate inflater
                if (autoArr[0] == 0x1F && autoArr[1] == 0x8B && autoArr[2] == 0x08) {   // gzip format
                    this.wrap = 2
                    this.inflater = Inflate(2)
                } else {  // Check for zlib format (CMF byte check)
                    let cmf = autoArr[0]
                    let flg = autoArr[1]
                    let compressionMethod = cmf & 0x0F
                    let windowSize = (cmf >> 4) & 0x0F
                    
                    // Check if this looks like zlib format: CMF and FLG bytes follow zlib specification
                    if (compressionMethod == 8 && windowSize <= 7) {
                        let checkSum = ((Int64(cmf) << 8) | Int64(flg)) % 31
                        if (checkSum == 0) {
                            wrap = 1
                            this.inflater = Inflate(1)
                        } else {
                            // Not a valid zlib header, use raw deflate
                            wrap = 0
                            this.inflater = Inflate(-1)
                        }
                    } else { 
                        // Not a valid zlib header, use raw deflate
                        wrap = 0
                        this.inflater = Inflate(-1)
                    }
                }
                
                // Apply dictionary if one was set before format detection
                // Note: Gzip format (wrap == 2) doesn't support dictionaries
                if (this.dictArray.size > 0 && this.wrap != 2) {
                    let ret = this.inflater.setDictionary(this.dictArray)
                    if (ret != Z_OK) {
                        if (ret == Z_STREAM_ERROR) {
                            // If setDictionary fails with Z_STREAM_ERROR, store the dictionary
                            // for later use when the inflater is in the right state
                            // This follows the same pattern as InflaterOutputStream
                        } else {
                            throw Zlib4cjException("setDictionary: ${this.inflater.message}")
                        }
                    }
                }
                
                // Process any remaining input in the inflater before setting new input
                while (this.inflater.avail_in > 0) {
                    inflateFunc()
                }
                
                // Set the detected bytes as input
                this.inflater.setInBuf(autoArr)
                this.inputLimit = 3
                this.isAuto = true
                
                // Process the format detection bytes
                while (this.inflater.avail_in > 0 && this.error != Z_STREAM_END) {
                    inflateFunc()
                }
                
                // Process any remaining bytes from the original buffer
                if (bufferOff < buffer.size) {
                    let remainingBuffer = buffer[bufferOff..buffer.size]
                    this.inflater.setInBuf(remainingBuffer)
                    this.inputLimit = remainingBuffer.size
                    while (this.inflater.avail_in > 0 && this.error != Z_STREAM_END) {
                        inflateFunc()
                    }
                }
            } else {
                // Not enough bytes for format detection, return
                return
            }
        } else {
            // Process any remaining input in the inflater before setting new input
            while (this.inflater.avail_in > 0) {
                inflateFunc()
            }
            
            // Format already detected, process the buffer
            this.inflater.setInBuf(buffer)
            this.inputLimit = buffer.size
            while (this.inflater.avail_in > 0 && this.error != Z_STREAM_END) {
                inflateFunc()
            }
        }
    }

    @Frozen
    func inflateFunc(): Unit {
        inflater.setOutBuf(buf)
        while(inflater.avail_out > 0 && this.inflater.avail_in > 0) {
            this.error = inflater.inflate(Z_NO_FLUSH)
            if (error >= 0) {
                if (error == Z_STREAM_END) {
                    break
                }
                if (error == Z_NEED_DICT) {
                    if (dictArray.size > 0) {
                        if (this.inflater.setDictionary(dictArray) != Z_OK) {
                            throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                        }
                    } else {
                        throw Zlib4cjException("inflate error: ${error}, ${erroMsg(error)}, but no dictionary set")
                    }
                }
            } else if (error == Z_DATA_ERROR) {
                let syncRet = this.inflater.inflateSync()
                if (syncRet == Z_OK) { // 成功找到同步点，恢复解压
                    continue
                } else if (syncRet == Z_BUF_ERROR) { // 需要更多数据才能恢复
                    break
                } else if (syncRet == Z_STREAM_END) { //恢复失败
                    throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                }
            } else if (error == Z_BUF_ERROR) {
                // Z_BUF_ERROR may indicate insufficient buffer space, just break and continue later
                break
            } else {
                throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
            }
        }
        this.out.write(this.buf[0..(this.buf.size - this.inflater.avail_out)])
    }

    @Frozen
    public func flush(): Unit {
        if (!this.isAuto) {
            return
        }
        while (this.inflater.avail_in > 0 && this.error != Z_STREAM_END) {
            inflateFunc()
        }
        this.out.flush()
    }

    @Frozen
    public func getTotalIn(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.getTotalIn()
    }

    @Frozen
    public func getTotalOut(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.getTotalOut()
    }
    @Frozen
    public func getAvailIn(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.avail_in
    }
    @Frozen
    public func getPositionOut(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inflater.getOutDataLength()
    }
    @Frozen
    public func getAvailInArray(): Array<Byte> {
        if (this.inflater.avail_in<=0 || !this.isAuto) {
            return NULL_ARR_UINT8
        }
        let tmp = Array<Byte>(this.inflater.avail_in, repeat: 0)
        this.inflater.next_in.copyTo(tmp, this.inflater.pos_in, 0, this.inflater.avail_in)
        return tmp
    }

    @Frozen
    public func getRemaining(): Int64 {
        if (!this.isAuto) {
            return 0
        }
        return this.inputLimit - this.inflater.pos_in
    }

    @Frozen
    public override func setDictionary(dict: Array<UInt8>): Unit {
        if (this.isAuto) {
            if (this.inflater.setDictionary(dict) != Z_OK) {
                throw Zlib4cjException("setDictionary: ${this.inflater.message}")
            }
        } else {
            this.dictArray = dict
        }
    }

    @Frozen
    public func getInflater(): Inflate {
        if (!isAuto) {
            throw Zlib4cjException("Inflater not initialized. Call read() to initialize.")
        }
        return this.inflater
    }
}

public open class InflaterOutputStream <: Inflater & OutputStream {
    var dictArray: Array<UInt8> = NULL_ARR_UINT8
    var out : OutputStream
    protected var inputLimit: Int64 = 0
    @Frozen
    public init(out: OutputStream) {
        this(out, Inflate(-1), DEFAULT_BUFSIZE)
    }

    @Frozen
    public init(out: OutputStream, bufferSize: Int64) {
        this(out, Inflate(-1), bufferSize)
    }

    @Frozen
    init(out: OutputStream, i: Inflate) {
        this(out, i, DEFAULT_BUFSIZE)
    }

    @Frozen
    init(out: OutputStream, i: Inflate, bufferSize: Int64) {
        super(i, bufferSize)
        this.out = out
    }

    @Frozen
    public func write(buffer: Array<Byte>): Unit {
        if (error == Z_STREAM_END) {
            return
        }
        if (buffer.size == 0) {
            return
        }
        while (this.inflater.avail_in > 0) {
            inflateFunc()
        }
        this.inflater.setInBuf(buffer)
        this.inputLimit = buffer.size
        while (this.inflater.avail_in > 0 && this.error != Z_STREAM_END) {
            inflateFunc()
        }
    }

    @Frozen
    func inflateFunc(): Unit {
        inflater.setOutBuf(buf)
        while(inflater.avail_out > 0 && this.inflater.avail_in > 0) {
            this.error = inflater.inflate(Z_NO_FLUSH)
            if (error >= 0) {
                if (error == Z_STREAM_END) {
                    break
                }
                if (error == Z_NEED_DICT) {
                    if (dictArray.size > 0) {
                        if (this.inflater.setDictionary(dictArray) != Z_OK) {
                            throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                        }
                    } else {
                        throw Zlib4cjException("inflate error: ${error}, ${erroMsg(error)}, but no dictionary set")
                    }
                }
            } else if (error == Z_DATA_ERROR) {
                let syncRet = this.inflater.inflateSync()
                if (syncRet == Z_OK) { // 成功找到同步点，恢复解压
                    continue
                } else if (syncRet == Z_BUF_ERROR) { // 需要更多数据才能恢复
                    break
                } else if (syncRet == Z_STREAM_END) { //恢复失败
                    throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
                }
            } else if (error == Z_BUF_ERROR) {
                // Z_BUF_ERROR may indicate insufficient buffer space, just break and continue later
                break
            } else {
                throw Zlib4cjException("inflate error: ${error}, ${this.inflater.message}")
            }
        }
        this.out.write(this.buf[0..(this.buf.size - this.inflater.avail_out)])
    }

    @Frozen
    public func flush(): Unit {
        while (this.inflater.avail_in > 0 && this.error != Z_STREAM_END) {
            inflateFunc()
        }
        this.out.flush()
    }

    @Frozen
    public func getRemaining(): Int64 {
        return this.inputLimit - this.inflater.pos_in
    }

    @Frozen
    public open func setDictionary(dict: Array<UInt8>): Unit {
        if (this.inflater.setDictionary(dict) != Z_OK) {
            throw Zlib4cjException("setDictionary: ${this.inflater.message}")
        }
    }
}

public class UnZlibOutputStream <: InflaterOutputStream {
    @Frozen
    public init(output: OutputStream) {
        super(output, Inflate(1))
    }

    @Frozen
    public init(output: OutputStream, bufferSize: Int64) {
        super(output, Inflate(1), bufferSize)
    }

    @Frozen
    public func setDictionary(dict: Array<UInt8>): Unit {
        let ret = this.inflater.setDictionary(dict)
        if (ret == Z_OK) {
            return
        }
        if (ret == Z_STREAM_ERROR) {
            this.dictArray = dict
            return
        }
        throw Zlib4cjException("setDictionary: ${this.inflater.message}")
    }
}

public class GunzipOutputStream <: InflaterOutputStream {  
    @Frozen
    public init(output: OutputStream) {
        super(output, Inflate(2))
    }
    @Frozen
    public init(output: OutputStream, bufferSize: Int64) {
        super(output, Inflate(2), bufferSize)
    }
}