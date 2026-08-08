/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class RemoveFilesFromZipTask <: AbstractModifyFileTask<RemoveFilesFromZipTaskParameters> {
    private let zipModel: ZipModel
    private let headerWriter: HeaderWriter

    public RemoveFilesFromZipTask(
        zipModel: ZipModel,
        headerWriter: HeaderWriter,
        asyncTaskParameters: AsyncTaskParameters
    ) {
        super(asyncTaskParameters)
        this.zipModel = zipModel
        this.headerWriter = headerWriter
    }

    protected func executeTask(taskParameters: RemoveFilesFromZipTaskParameters, progressMonitor: ProgressMonitor): Unit {
        if (zipModel.isSplitArchive()) {
            throw ZipException("This is a split archive. Zip file format does not allow updating split/spanned files")
        }

        var entriesToRemove: ArrayList<String> = filterNonExistingEntries(taskParameters.filesToRemove)

        if (entriesToRemove.isEmpty()) {
            return
        }

        var temporaryZipFile: Path = getTemporaryFile(zipModel.getZipFile().toString())
        var successFlag: Bool = false

        let outputStream: SplitOutputStream = SplitOutputStream(temporaryZipFile)
        let inputStream: RandomAccessFile = RandomAccessFile(zipModel.getZipFile().toString(), OpenMode.Read)
        try {
            var currentFileCopyPointer: Int64 = 0
            var sortedFileHeaders: Array<FileHeader> = cloneAndSortFileHeadersByOffset(
                zipModel.getCentralDirectory().getOrThrow().getFileHeaders())

            for (i in 0..sortedFileHeaders.size) {
                let fileHeader: FileHeader = sortedFileHeaders[i]
                var lengthOfCurrentEntry: Int64 = getOffsetOfNextEntry(sortedFileHeaders, fileHeader, zipModel) -
                    outputStream.getFilePointer()
                if (shouldEntryBeRemoved(fileHeader, entriesToRemove)) {
                    updateHeaders(sortedFileHeaders, fileHeader, lengthOfCurrentEntry)

                    ListRmove(zipModel.getCentralDirectory().getOrThrow().getFileHeaders(), fileHeader)
                    currentFileCopyPointer = currentFileCopyPointer + lengthOfCurrentEntry
                } else {
                    // copy complete entry without any changes
                    currentFileCopyPointer = currentFileCopyPointer + super.copyFile(inputStream, outputStream, currentFileCopyPointer,
                        lengthOfCurrentEntry, progressMonitor, taskParameters.zip4cjConfig.getBufferSize())
                }
                this.verifyIfTaskIsCancelled()
            }
            headerWriter.finalizeZipFile(zipModel, outputStream)
            successFlag = true
        } finally {
            this.cleanupFile(successFlag, zipModel.getZipFile(), temporaryZipFile)
            inputStream.close()
            outputStream.close()
        }
    }

    protected func calculateTotalWork(taskParameters: RemoveFilesFromZipTaskParameters): Int64 {
        return FileInfo(zipModel.getZipFile()).size
    }

    private func filterNonExistingEntries(filesToRemove: Array<String>): ArrayList<String> {
        var filteredFilesToRemove = ArrayList<String>()
        for (i in 0..filesToRemove.size) {
            let fileToRemove = filesToRemove[i]
            if (HeaderUtil.getFileHeader(zipModel, fileToRemove).isSome()) {
                filteredFilesToRemove.add(fileToRemove)
            }
        }

        return filteredFilesToRemove
    }

    private func shouldEntryBeRemoved(fileHeaderToBeChecked: FileHeader, fileNamesToBeRemoved: ArrayList<String>): Bool {
        for (i in 0..fileNamesToBeRemoved.size) {
            let fileNameToBeRemoved = fileNamesToBeRemoved[i]
            // If any of the files to be removed is a directory, check if the fileHeaderToBeChecked is a sub-file or
            // a sub-directory of that directory
            if (fileNameToBeRemoved.endsWith(InternalZipConstants.ZIP_FILE_SEPARATOR) &&
                fileHeaderToBeChecked.getFileName().getOrThrow().startsWith(fileNameToBeRemoved)) {
                return true
            } else if (fileHeaderToBeChecked.getFileName().getOrThrow() == (fileNameToBeRemoved)) {
                return true
            }
        }

        return false
    }

    private func updateHeaders(
        sortedFileHeaders: Array<FileHeader>,
        fileHeaderThatWasRemoved: FileHeader,
        offsetToSubtract: Int64
    ) {
        updateOffsetsForAllSubsequentFileHeaders(sortedFileHeaders, zipModel, fileHeaderThatWasRemoved,
            negate(offsetToSubtract))

        var end: EndOfCentralDirectoryRecord = zipModel.getEndOfCentralDirectoryRecord()
        end.setOffsetOfStartOfCentralDirectory(
            end.getOffsetOfStartOfCentralDirectory() - offsetToSubtract)
        end.setTotalNumberOfEntriesInCentralDirectory(
            end.getTotalNumberOfEntriesInCentralDirectory() - 1)

        if (end.getTotalNumberOfEntriesInCentralDirectoryOnThisDisk() > 0) {
            end.setTotalNumberOfEntriesInCentralDirectoryOnThisDisk(
                end.getTotalNumberOfEntriesInCentralDirectoryOnThisDisk() - 1)
        }

        if (zipModel.isZip64Format()) {
            zipModel.getZip64EndOfCentralDirectoryRecord().setOffsetStartCentralDirectoryWRTStartDiskNumber(
                zipModel.getZip64EndOfCentralDirectoryRecord().getOffsetStartCentralDirectoryWRTStartDiskNumber() -
                offsetToSubtract)

            zipModel.getZip64EndOfCentralDirectoryRecord().setTotalNumberOfEntriesInCentralDirectoryOnThisDisk(
                zipModel.getZip64EndOfCentralDirectoryRecord().getTotalNumberOfEntriesInCentralDirectory() - 1)

            zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().setOffsetZip64EndOfCentralDirectoryRecord(
                zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().getOffsetZip64EndOfCentralDirectoryRecord() -
                offsetToSubtract)
        }
    }

    private func negate(val: Int64): Int64 {
        if (val == -9223372036854775808) {
            throw ArithmeticException("long overflow")
        }

        return -val
    }

    protected func getTask(): ProgressMonitorTask {
        return ProgressMonitorTask.REMOVE_ENTRY
    }
}
