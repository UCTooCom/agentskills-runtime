/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public abstract class AbstractModifyFileTask<T> <: AsyncZipTask<T> {
    init(asyncTaskParameters: AsyncTaskParameters) {
        super(asyncTaskParameters)
    }

    protected func getTemporaryFile(zipPathWithName: String): Path {
        var random: SecureRandom = SecureRandom()
        var tmpFile: Path = Path(zipPathWithName + "${random.nextInt32(10000)}")

        while (exists(tmpFile)) {
            tmpFile = Path(zipPathWithName + "${random.nextInt32(10000)}")
        }

        return tmpFile
    }

    func updateOffsetsForAllSubsequentFileHeaders(
        sortedFileHeaders: Array<FileHeader>,
        zipModel: ZipModel,
        fileHeaderModified: FileHeader,
        offsetToAdd: Int64
    ) {
        var indexOfFileHeader: Int32 = getIndexOfFileHeader(sortedFileHeaders, fileHeaderModified)

        if (indexOfFileHeader == -1) {
            throw ZipException("Could not locate modified file header in zipModel")
        }

        for (i in Int64(indexOfFileHeader + 1)..sortedFileHeaders.size) {
            var fileHeaderToUpdate: FileHeader = sortedFileHeaders.get(i).getOrThrow()
            fileHeaderToUpdate.setOffsetLocalHeader(fileHeaderToUpdate.getOffsetLocalHeader() + offsetToAdd)

            if (zipModel.isZip64Format() && fileHeaderToUpdate.getZip64ExtendedInfo().isSome() &&
                fileHeaderToUpdate.getZip64ExtendedInfo().getOrThrow().getOffsetLocalHeader() != -1) {
                fileHeaderToUpdate.getZip64ExtendedInfo().getOrThrow().setOffsetLocalHeader(
                    fileHeaderToUpdate.getZip64ExtendedInfo().getOrThrow().getOffsetLocalHeader() + offsetToAdd)
            }
        }
    }

    func cleanupFile(successFlag: Bool, zipFile: Path, temporaryZipFile: Path) {
        if (successFlag) {
            restoreFileName(zipFile, temporaryZipFile)
            ()
        } else {
            try {
                remove(temporaryZipFile, recursive: true)
            } catch (e: Exception) {
                throw ZipException("Could not delete temporary file")
            }
        }
    }

    func copyFile(
        randomAccessFile: RandomAccessFile,
        outputStream: OutputStream,
        start: Int64,
        length: Int64,
        progressMonitor: ProgressMonitor,
        bufferSize: Int64
    ): Int64 {
        FileUtils.copyFile(randomAccessFile, outputStream, start, start + length, progressMonitor, Int64(bufferSize))
        return length
    }

    func cloneAndSortFileHeadersByOffset(allFileHeaders: ArrayList<FileHeader>): Array<FileHeader> {
        let clonedFileHeaders: Array<FileHeader> = allFileHeaders.toArray()
        stableSort<FileHeader>(clonedFileHeaders, {a,b => 
            if (a.getFileName() == b.getFileName()) {
                return Ordering.EQ
            } else if (a.getOffsetLocalHeader() < b.getOffsetLocalHeader()) {
                return Ordering.LT
            } else if (a.getOffsetLocalHeader() > b.getOffsetLocalHeader()) {
                return Ordering.GT
            } else {
                return Ordering.EQ
            }
        })
        return clonedFileHeaders
    }

    func getOffsetOfNextEntry(sortedFileHeaders: Array<FileHeader>, fileHeader: FileHeader, zipModel: ZipModel): Int64 {
        var indexOfFileHeader: Int32 = getIndexOfFileHeader(sortedFileHeaders, fileHeader)

        if (Int64(indexOfFileHeader) == sortedFileHeaders.size - 1) {
            return HeaderUtil.getOffsetStartOfCentralDirectory(zipModel)
        } else {
            return sortedFileHeaders.get(Int64(indexOfFileHeader + 1)).getOrThrow().getOffsetLocalHeader()
        }
    }

    // TODO restore FileName
    private func restoreFileName(zipFile: Path, temporaryZipFile: Path) {
        try {
            remove(zipFile, recursive: true)
            try {
                rename(temporaryZipFile, to: zipFile, overwrite: true)
            } catch (e: Exception) {
                throw ZipException("cannot rename modified zip file")
            }
        } catch (e: Exception) {
            throw ZipException("cannot delete old zip file")
        }
    }

    private func getIndexOfFileHeader(allFileHeaders: Array<FileHeader>, fileHeaderForIndex: FileHeader): Int32 {
        for (i in 0..allFileHeaders.size) {
            var fileHeader: FileHeader = allFileHeaders.get(i).getOrThrow()
            if (fileHeader.equals(fileHeaderForIndex)) {
                return Int32(i)
            }
        }
        throw ZipException("Could not find file header in list of central directory file headers")
    }
}
