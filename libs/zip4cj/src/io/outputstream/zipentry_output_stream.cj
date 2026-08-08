/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

public class ZipEntryOutputStream <: OutputStream {
    private var numberOfBytesWrittenForThisEntry: Int64 = 0
    var outputStream: OutputStream
    var entryClosed: Bool

    public init(outputStream: OutputStream) {
        this.outputStream = outputStream
        entryClosed = false
    }

    public func write(b: Array<UInt8>): Unit {
        if (entryClosed) {
            throw Exception("ZipEntryOutputStream is closed")
        }
        this.outputStream.write(b)
        numberOfBytesWrittenForThisEntry += b.size
    }

    public func closeEntry(): Unit {
        entryClosed = true
    }

    public func getNumberOfBytesWrittenForThisEntry(): Int64 {
        return numberOfBytesWrittenForThisEntry
    }

    public func flush(): Unit {}
}

extend ZipEntryOutputStream <: Resource {
    public func isClosed(): Bool {
        entryClosed
    }

    public func close(): Unit {
        // Do nothing
        // Do not close the outputstream yet. This will be closed by countingOutputStream
    }
}
