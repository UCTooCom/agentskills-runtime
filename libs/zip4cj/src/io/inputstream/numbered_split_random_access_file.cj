/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

import std.fs.OpenMode

func getFileModle(mode: String): OpenMode {
    if (mode == "rw") {
        return OpenMode.ReadWrite
    } else if (mode == "r") {
        return OpenMode.Read
    } else {
        return OpenMode.Write
    }
}

public func initializeRandomAccessFileForHeaderReading(zipFile: Path): RandomAccessFile {
    if (FileUtils.isNumberedSplitFile(zipFile)) {
        var allSplitFiles = FileUtils.getAllSortedNumberedSplitFiles(zipFile)
        var numberedSplitRandomAccessFile = NumberedSplitRandomAccessFile(zipFile,
            RandomAccessFileMode.READ.getValue(), allSplitFiles)
        numberedSplitRandomAccessFile.openLastSplitFileForReading()
        return numberedSplitRandomAccessFile
    }
    if (!exists(zipFile)) {
        File.create(zipFile)
    }
    return RandomAccessFile(zipFile, OpenMode.ReadWrite)
}


class NumberedSplitRandomAccessFile <: RandomAccessFile {
    private var splitLength: Int64
    private var allSortedSplitFiles: Array<Path>
    private var randomAccessFile: RandomAccessFile
    private var singleByteBuffer = Array<Byte>(1, repeat: 0)
    private var currentOpenSplitFileCounter: Int64 = 0
    private var rwMode: String

    public init(file: Path, mode: String, allSortedSplitFiles: Array<Path>) {
        super(file, getFileModle(mode))
        this.rawFile.close()

        if (RandomAccessFileMode.WRITE.getValue() == mode) {
            throw IllegalArgumentException("write mode is not allowed for NumberedSplitRandomAccessFile")
        }

        assertAllSplitFilesExist(allSortedSplitFiles)
        this.randomAccessFile = RandomAccessFile(file, getFileModle(mode))
        this.allSortedSplitFiles = allSortedSplitFiles
        this.splitLength = this.rawFile.length
        this.rwMode = mode
    }

    public func read(b: Array<Byte>): Int64 {
        return read(b, 0, b.size)
    }

    public func read(b: Array<Byte>, off: Int64, len: Int64): Int64 {
        var readLen = randomAccessFile.read(b, off, len)

        if (readLen == -1) {
            if (currentOpenSplitFileCounter == allSortedSplitFiles.size - 1) {
                return -1
            }
            openRandomAccessFileForIndex(currentOpenSplitFileCounter + 1)
            return read(b, off, len)
        }

        return readLen
    }

    public func seek(pos: Int64) {
        var splitPartOfPosition = (pos / splitLength)

        if (splitPartOfPosition != currentOpenSplitFileCounter) {
            openRandomAccessFileForIndex(splitPartOfPosition)
        }

        randomAccessFile.seek(pos - (splitPartOfPosition * splitLength))
    }

    public func getFilePointer(): Int64 {
        return randomAccessFile.getFilePointer()
    }

    public prop length: Int64 {
        get() {
            return randomAccessFile.length
        }
    }

    public func close() {
        randomAccessFile.close()
        super.close()
    }

    func seekInCurrentPart(pos: Int64) {
        randomAccessFile.seek(pos)
    }

    public func openLastSplitFileForReading() {
        openRandomAccessFileForIndex(allSortedSplitFiles.size - 1)
    }

    private func openRandomAccessFileForIndex(splitCounter: Int64) {
        if (currentOpenSplitFileCounter == splitCounter) {
            return
        }

        if (splitCounter > allSortedSplitFiles.size - 1) {
            throw ZipIOException("split counter greater than number of split files")
        }

        randomAccessFile.close()
        randomAccessFile = RandomAccessFile(allSortedSplitFiles[splitCounter], getFileModle(rwMode))
        currentOpenSplitFileCounter = splitCounter
    }

    private static func assertAllSplitFilesExist(allSortedSplitFiles: Array<Path>) {
        allSortedSplitFiles
        return
    }
}
