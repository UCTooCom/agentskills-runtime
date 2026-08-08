/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public open class RandomAccessFile <: Resource {
    public var postion_: Int64
    protected var rawFile: File = unsafe { zeroValue<File>() }

    public open prop remainLength: Int64 {
        get() {
            rawFile.remainLength
        }
    }
    
    public open prop length: Int64 {
        get() {
            rawFile.length
        }
    }

    public init(path: String, mode: OpenMode) {
        this.postion_ = 0
        this.rawFile = File(path, mode)
    }

    public init(path: Path, mode: OpenMode) {
        this.postion_ = 0
        this.rawFile = File(path, mode)
    }

    public init(file: File) {
        this.postion_ = 0
        this.rawFile = file
    }

    public open func getFilePointer(): Int64 {
        return this.postion_
    }

    public open func seek(loc: Int64): Unit {
        this.postion_ = loc
        this.rawFile.seek(Begin(loc))
    }

    public open func read(buffer: Array<Byte>): Int64 {
        if (buffer.size == 0) {
            return 0
        }
        let see = this.rawFile.read(buffer)
        this.postion_ += see
        return see
    }

    public open func read(buffer: Array<Byte>, off: Int64, count: Int64): Int64 {
        let see = this.rawFile.read(buffer[off..off + count])
        this.postion_ += see
        return see
    }

    public open func readFully(b: Array<Byte>): Unit {
        if (b.size == 0) {
            return
        }
        var see = this.rawFile.read(b)
        if (see >= 0) {
            this.postion_ += see
        }
    }

    public open func write(buffer: Array<Byte>): Unit {
        this.rawFile.write(buffer)
        this.postion_ += buffer.size
    }

    public open func flush(): Unit {
        this.rawFile.flush()
    }
    public open func close(): Unit {
        this.rawFile.close()
    }
    public open func isClosed(): Bool {
        this.rawFile.isClosed()
    }
}
