/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

class CountingOutputStream <: OutputStream & Resource & OutputStreamWithSplitZipSupport {
    var outputStream: OutputStream
    var closed = false
    private var numberOfBytesWritten: Int64 = 0

    public init(outputStream: OutputStream) {
        this.outputStream = outputStream
    }

    public func write(b: Array<UInt8>): Unit {
        this.outputStream.write(b)
        numberOfBytesWritten += b.size
    }

    public func getCurrentSplitFileCounter(): Int32 {
        if (isSplitZipFile()) {
            return (outputStream as SplitOutputStream).getOrThrow().getCurrentSplitFileCounter()
        }
        return 0
    }

    public func getOffsetForNextEntry(): Int64 {
        if (outputStream is SplitOutputStream) {
            return (outputStream as SplitOutputStream).getOrThrow().getFilePointer()
        }

        return numberOfBytesWritten
    }

    public func getSplitLength(): Int64 {
        if (isSplitZipFile()) {
            return (outputStream as SplitOutputStream).getOrThrow().getSplitLength()
        }

        return 0
    }

    public func isSplitZipFile(): Bool {
        if (let Some(output) <- (outputStream as SplitOutputStream)) {
            output.isSplitZipFile()
        } else {
            false
        }
    }

    public func getNumberOfBytesWritten(): Int64 {
        if (outputStream is SplitOutputStream) {
            return (outputStream as SplitOutputStream).getOrThrow().getFilePointer()
        }

        return numberOfBytesWritten
    }

    public func checkBuffSizeAndStartNextSplitFile(bufferSize: Int32): Bool {
        if (!isSplitZipFile()) {
            return false
        }
        return (outputStream as SplitOutputStream).getOrThrow().checkBufferSizeAndStartNextSplitFile(Int64(bufferSize))
    }

    public func getFilePointer(): Int64 {
        if (outputStream is SplitOutputStream) {
            return (outputStream as SplitOutputStream).getOrThrow().getFilePointer()
        }

        return numberOfBytesWritten
    }

    public func flush(): Unit {
        outputStream.flush()
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        this.outputStream.flush()
        match ((outputStream as Resource)) {
            case Some(v) => v.close()
            case None => ()
        }
        closed = true
    }
}
