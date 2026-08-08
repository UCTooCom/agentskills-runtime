/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

import std.fs.*

class ZipStandardSplitFileInputStream <: SplitFileInputStream {
    protected var randomAccessFile: RandomAccessFile
    protected var zipFile: Path
    private var lastSplitZipFileNumber: Int64
    private var isSplitZipArchive: Bool
    private var currentSplitFileCounter: Int64 = 0
    private var singleByteArray = Array<Byte>(1, repeat: 0)

    public init(zipFile: Path, isSplitZipArchive: Bool, lastSplitZipFileNumber: Int64) {
        this.randomAccessFile = RandomAccessFile(zipFile, OpenMode.ReadWrite)
        this.zipFile = zipFile
        this.isSplitZipArchive = isSplitZipArchive
        this.lastSplitZipFileNumber = lastSplitZipFileNumber

        if (isSplitZipArchive) {
            currentSplitFileCounter = lastSplitZipFileNumber
        }
    }

    public func read(b: Array<Byte>): Int64 {
        if (b.isEmpty()) {
            return 0
        }
        return read(b, 0, b.size)
    }

    func read(b: Array<Byte>, off: Int64, len: Int64): Int64 {
        var readLen = randomAccessFile.read(b, off, len)
        if ((readLen != len || readLen == -1) && isSplitZipArchive) {
            openRandomAccessFileForIndex(currentSplitFileCounter + 1)
            currentSplitFileCounter++

            if (readLen < 0) {
                readLen = 0
            }
            var newlyRead = randomAccessFile.read(b, readLen, len - readLen)
            if (newlyRead > 0) {
                readLen += newlyRead
            }
        }
        return readLen
    }

    public func prepareExtractionForFileHeader(fileHeader: FileHeader): Unit {
        if (isSplitZipArchive && (currentSplitFileCounter != Int64(fileHeader.getDiskNumberStart()))) {
            openRandomAccessFileForIndex(Int64(fileHeader.getDiskNumberStart()))
            currentSplitFileCounter = Int64(fileHeader.getDiskNumberStart())
        }

        randomAccessFile.seek(fileHeader.getOffsetLocalHeader())
    }

    public func isClosed(): Bool {
        this.randomAccessFile.isClosed()
    }

    public func close(): Unit {
        randomAccessFile.close()
    }

    protected func openRandomAccessFileForIndex(zipFileIndex: Int64): Unit {
        var nextSplitFile: Path = getNextSplitFile(zipFileIndex)
        if (!exists(nextSplitFile)) {
            throw Exception("zip split file does not exist: ${nextSplitFile}")
        }
        randomAccessFile.close()
        randomAccessFile = RandomAccessFile(nextSplitFile, OpenMode.ReadWrite)
    }

    protected func getNextSplitFile(zipFileIndex: Int64): Path {
        if (zipFileIndex == lastSplitZipFileNumber) {
            return zipFile
        }

        var currZipFileNameWithPath = zipFile.toString()
        var extensionSubString = ".z0"
        if (zipFileIndex >= 9) {
            extensionSubString = ".z"
        }

        return Path(
            currZipFileNameWithPath[0..currZipFileNameWithPath.lastIndexOf(".").getOrThrow()] + extensionSubString +
            "${zipFileIndex + 1}")
    }
}
