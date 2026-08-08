/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

class PushbackInputStream <: InputStream {
    protected var buf: Array<Byte>

    protected var pos: Int64

    protected var input: InputStream

    private func ensureOpen(): Unit {
    }

    public init(input: InputStream, size: Int64) {
        this.input = input
        if (size <= 0) {
            throw IllegalArgumentException("size <= 0")
        }
        this.buf = Array<Byte>(size, repeat: 0)
        this.pos = size
    }

    public init(input: InputStream) {
        this(input, 1)
    }

    public func read(b: Array<Byte>): Int64 {
        return this.read(b, 0, b.size)
    }

    func read(b: Array<Byte>, off: Int64, len: Int64): Int64 {
        ensureOpen()
        var off_p = off
        var len_p = len
        if (off_p < 0 || len_p < 0 || len_p > b.size - off_p) {
            throw IndexOutOfBoundsException()
        } else if (len_p == 0) {
            return 0
        }

        var avail = buf.size - pos
        if (avail > 0) {
            if (len < avail) {
                avail = len
            }
            buf.copyTo(b, pos, off, avail)
            pos += avail
            off_p += avail
            len_p -= avail
        }
        if (len > 0) {
            len_p = input.read(b[off_p..off_p + len_p]) //read(b, off_p, len_p)
            if (len_p == 0) {
                if (avail == 0) {
                    return -1
                }
                return avail
            }
            return avail + len_p
        }
        return avail
    }

    public func unread(b: Int64) {
        ensureOpen()
        if (pos == 0) {
            throw ZipIOException("Push back buffer is full")
        }
        buf[pos - 1] = UInt8(b)
    }

    public func unread(b: Array<Byte>, off: Int64, len: Int64) {
        ensureOpen()
        if (len > pos) {
            throw ZipIOException("Push back buffer is full")
        }
        pos -= len
        b.copyTo(buf, off, pos, len)
    }

    public func unread(b: Array<Byte>) {
        unread(b, 0, b.size)
    }

    public func skip(n: Int64): Int64 {
        ensureOpen()
        var singleByteBuffer = Array<Byte>(1, repeat: 0)
        for (i in 0..n) {
            var flag = input.read(singleByteBuffer)
            if (flag <= 0) {
                return i
            }
        }
        return n
    }

    public func markSupported(): Bool {
        return false
    }

    public func mark(readlimit: Int64) {
        readlimit
        return
    }

    public func reset() {
        throw ZipIOException("mark/reset not supported")
    }

    public func close() {
        match ((input as Resource)) {
            case Some(v) => v.close()
            case _ => ()
        }
    }
}
