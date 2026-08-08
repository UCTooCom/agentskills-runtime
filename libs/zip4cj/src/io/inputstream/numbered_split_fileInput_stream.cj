/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

class NumberedSplitFileInputStream <: SplitFileInputStream {
    private var randomAccessFile: RandomAccessFile

    public init(zipFile: Path) {
        this.randomAccessFile = NumberedSplitRandomAccessFile(zipFile, RandomAccessFileMode.READ.getValue())
    }

    public func read(b: Array<Byte>): Int64 {
        return this.read(b)
    }

    public func prepareExtractionForFileHeader(fileHeader: FileHeader): Unit {
        randomAccessFile.seek(fileHeader.getOffsetLocalHeader())
    }

    public func close(): Unit {
        randomAccessFile.close()
    }

    public func isClosed(): Bool {
        this.randomAccessFile.isClosed()
    }
}
