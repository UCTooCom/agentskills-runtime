/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class RenameFilesTask <: AbstractModifyFileTask<RenameFilesTaskParameters> {
    private let zipModel: ZipModel
    private let headerWriter: HeaderWriter
    private let rawIO: RawIO

    public RenameFilesTask(
        zipModel: ZipModel,
        headerWriter: HeaderWriter,
        rawIO: RawIO,
        asyncTaskParameters: AsyncTaskParameters
    ) {
        super(asyncTaskParameters)
        this.zipModel = zipModel
        this.headerWriter = headerWriter
        this.rawIO = rawIO
    }

    protected func executeTask(taskParameters: RenameFilesTaskParameters, progressMonitor: ProgressMonitor): Unit {
        var fileNamesMap = filterNonExistingEntriesAndAddSeparatorIfNeeded(taskParameters.fileNamesMap)
        if (fileNamesMap.size == 0) {
            return
        }

        let temporaryFile = getTemporaryFile(zipModel.getZipFile().toString())
        var successFlag = false
        let inputStream = RandomAccessFile(zipModel.getZipFile(), OpenMode.ReadWrite)
        let outputStream = SplitOutputStream(temporaryFile)
        try {
            var currentFileCopyPointer = 0
            // Maintain a different list to iterate, so that when the file name is changed in the central directory
            // we still have access to the original file names. If iterating on the original list from central directory,
            // it might be that a file name has changed because of other file name, ex: if a directory name has to be changed
            // and the file is part of that directory, by the time the file has to be changed, its name might have changed
            // when changing the name of the directory. There is some overhead with this approach, but is safer.
            var sortedFileHeaders: Array<FileHeader> = cloneAndSortFileHeadersByOffset(zipModel.getCentralDirectory().getOrThrow().getFileHeaders())

            for (i in 0..sortedFileHeaders.size) {
                let fileHeader = sortedFileHeaders[i]
                var fileNameMapForThisEntry: Option<(String, String)> = getCorrespondingEntryFromMap(
                    fileHeader,
                    fileNamesMap
                )
                progressMonitor.setFileName(fileHeader.getFileName().getOrThrow())

                var lengthToCopy = getOffsetOfNextEntry(sortedFileHeaders, fileHeader, zipModel) -
                    outputStream.getFilePointer()
                if (let Some(entry) <- fileNameMapForThisEntry) {
                    var newFileName: String = getNewFileName(entry[1], entry[0], fileHeader.getFileName().getOrThrow())
                    var newFileNameBytes = HeaderUtil.getBytesFromString(newFileName)
                    var headersOffset = newFileNameBytes.size - fileHeader.getFileNameLength()

                    currentFileCopyPointer = copyEntryAndChangeFileName(newFileNameBytes, fileHeader,
                        currentFileCopyPointer, lengthToCopy, inputStream, outputStream, progressMonitor,
                        taskParameters.zip4cjConfig.getBufferSize())

                    updateHeadersInZipModel(sortedFileHeaders, fileHeader, newFileName, newFileNameBytes, headersOffset)
                } else {
                    // copy complete entry without any changes
                    currentFileCopyPointer += copyFile(inputStream, outputStream, currentFileCopyPointer, lengthToCopy,
                        progressMonitor, taskParameters.zip4cjConfig.getBufferSize())
                }

                verifyIfTaskIsCancelled()
            }

            headerWriter.finalizeZipFile(zipModel, outputStream)
            successFlag = true
        } finally {
            cleanupFile(successFlag, zipModel.getZipFile(), temporaryFile)
            outputStream.close()
            inputStream.close()
        }
    }

    protected func calculateTotalWork(taskParameters: RenameFilesTaskParameters): Int64 {
        taskParameters
        return FileInfo(zipModel.getZipFile()).size
    }

    protected func getTask(): ProgressMonitorTask {
        return ProgressMonitorTask.RENAME_FILE
    }

    private func copyEntryAndChangeFileName(
        newFileNameBytes: Array<Byte>,
        fileHeader: FileHeader,
        start: Int64,
        totalLengthOfEntry: Int64,
        inputStream: RandomAccessFile,
        outputStream: OutputStream,
        progressMonitor: ProgressMonitor,
        bufferSize: Int64
    ): Int64 {
        var currentFileCopyPointer = start

        currentFileCopyPointer += copyFile(inputStream, outputStream, currentFileCopyPointer, 26, progressMonitor,
            bufferSize) // 26 is offset until file name length

        rawIO.writeShortLittleEndian(outputStream, Int32(newFileNameBytes.size))

        currentFileCopyPointer += 2 // length of file name length
        currentFileCopyPointer += copyFile(inputStream, outputStream, currentFileCopyPointer, 2, progressMonitor,
            bufferSize) // 2 is for length of extra field length

        outputStream.write(newFileNameBytes)
        currentFileCopyPointer += fileHeader.getFileNameLength()

        var remainingLengthToCopy = totalLengthOfEntry - (currentFileCopyPointer - start)

        currentFileCopyPointer += copyFile(inputStream, outputStream, currentFileCopyPointer, remainingLengthToCopy,
            progressMonitor, bufferSize)

        return currentFileCopyPointer
    }

    private func getCorrespondingEntryFromMap(fileHeaderToBeChecked: FileHeader, fileNamesMap: Map<String, String>): ?(String, String) {
        for (entry in fileNamesMap) {
            if (fileHeaderToBeChecked.getFileName().getOrThrow().startsWith(entry[0])) {
                return entry
            }
        }
        return None
    }

    private func updateHeadersInZipModel(
        sortedFileHeaders: Array<FileHeader>,
        fileHeader: FileHeader,
        newFileName: String,
        newFileNameBytes: Array<Byte>,
        headersOffset: Int64
    ) {
        var fileHeaderToBeChangedOption: ?FileHeader = HeaderUtil.getFileHeader(
            zipModel,
            fileHeader.getFileName().getOrThrow()
        )

        if (fileHeaderToBeChangedOption.isNone()) {
            // If this is the case, then the file name in the header that was passed to this method was already changed.
            // In theory, should never be here.
            throw ZipException("could not find any header with name: ${fileHeader.getFileName()}")
        }
        let fileHeaderToBeChanged = fileHeaderToBeChangedOption.getOrThrow()
        fileHeaderToBeChanged.setFileName(newFileName)
        fileHeaderToBeChanged.setFileNameLength(newFileNameBytes.size)

        updateOffsetsForAllSubsequentFileHeaders(sortedFileHeaders, zipModel, fileHeaderToBeChanged, headersOffset)

        zipModel.getEndOfCentralDirectoryRecord().setOffsetOfStartOfCentralDirectory(
            zipModel.getEndOfCentralDirectoryRecord().getOffsetOfStartOfCentralDirectory() + headersOffset)

        if (zipModel.isZip64Format()) {
            zipModel.getZip64EndOfCentralDirectoryRecord().setOffsetStartCentralDirectoryWRTStartDiskNumber(
                zipModel.getZip64EndOfCentralDirectoryRecord().getOffsetStartCentralDirectoryWRTStartDiskNumber() +
                headersOffset)

            zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().setOffsetZip64EndOfCentralDirectoryRecord(
                zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().getOffsetZip64EndOfCentralDirectoryRecord() +
                headersOffset)
        }
    }

    private func filterNonExistingEntriesAndAddSeparatorIfNeeded(inputFileNamesMap: Map<String, String>): Map<String,
        String> {
        let fileNamesMapToBeChanged = HashMap<String, String>()
        for ((key, value) in inputFileNamesMap) {
            if (!Zip4cjUtil.isStringNotNullAndNotEmpty(key)) {
                continue
            }

            if (let Some(fileHeaderToBeChanged) <- HeaderUtil.getFileHeader(zipModel, key)) {
                if (fileHeaderToBeChanged.isDirectory() && !value.endsWith(InternalZipConstants.ZIP_FILE_SEPARATOR)) {
                    fileNamesMapToBeChanged.add(key, "${value}${InternalZipConstants.ZIP_FILE_SEPARATOR}")
                } else {
                    fileNamesMapToBeChanged.add(key, value)
                }
            }
        }
        return fileNamesMapToBeChanged
    }

    private func getNewFileName(newFileName: String, oldFileName: String, fileNameFromHeaderToBeChanged: String): String {
        if (fileNameFromHeaderToBeChanged == (oldFileName)) {
            return newFileName
        } else if (fileNameFromHeaderToBeChanged.startsWith(oldFileName)) {
            var fileNameWithoutOldName = String(
                fileNameFromHeaderToBeChanged.toRuneArray()[0..oldFileName.toRuneArray().size])
            return newFileName + fileNameWithoutOldName
        }

        // Should never be here.
        // If here by any chance, it means that the file header was marked as to-be-modified, even when the file names do not
        // match. Logic in the method getCorrespondingEntryFromMap() has to be checked
        throw ZipException("old file name was neither an exact match nor a partial match")
    }
}
