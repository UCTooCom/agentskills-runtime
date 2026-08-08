/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class AddStreamToZipTask <: AbstractAddFileToZipTask<AddStreamToZipTaskParameters> {
    public AddStreamToZipTask(
        zipModel: ZipModel,
        password: ?Array<Rune>,
        headerWriter: HeaderWriter,
        asyncTaskParameters: AsyncTaskParameters
    ) {
        super(zipModel, password, headerWriter, asyncTaskParameters)
    }

    protected func executeTask(taskParameters: AddStreamToZipTaskParameters, progressMonitor: ProgressMonitor) {
        verifyZipParameters(taskParameters.zipParameters)

        if (!Zip4cjUtil.isStringNotNullAndNotEmpty(taskParameters.zipParameters.getFileNameInZip())) {
            throw ZipException("fileNameInZip has to be set in zipParameters when adding stream")
        }

        removeFileIfExists(getZipModel(), taskParameters.zip4cjConfig,
            taskParameters.zipParameters.getFileNameInZip().getOrThrow(), progressMonitor)

        // For streams, it is necessary to write extended local file header because of Zip standard encryption.
        // If we do not write extended local file header, zip standard encryption needs a crc upfront for key,
        // which cannot be calculated until we read the complete stream. If we use extended local file header,
        // last modified file time is used, or current system time if not available.
        taskParameters.zipParameters.setWriteExtendedLocalFileHeader(true)

        if (taskParameters.zipParameters.getCompressionMethod() == (CompressionMethod.STORE)) {
            // Set some random value here. This will be updated again when closing entry
            taskParameters.zipParameters.setEntrySize(0)
        }

        let splitOutputStream = SplitOutputStream(
            getZipModel().getZipFile(),
            getZipModel().getSplitLength()
        )
        let zipOutputStream = initializeOutputStream(splitOutputStream, taskParameters.zip4cjConfig)
        try {
            var readBuff = Array<Byte>(taskParameters.zip4cjConfig.getBufferSize(), repeat: 0)
            var readLen: Int64

            var zipParameters = taskParameters.zipParameters
            zipOutputStream.putNextEntry(zipParameters)

            if (!zipParameters.getFileNameInZip().getOrThrow().endsWith("/") &&
                !zipParameters.getFileNameInZip().getOrThrow().endsWith("\\")) {
                readLen = taskParameters.inputStream.read(readBuff)
                while (readLen > 0) {
                    zipOutputStream.write(readBuff[0..readLen])
                    readLen = taskParameters.inputStream.read(readBuff)
                }
            }

            var fileHeader = zipOutputStream.closeEntry()

            if (CompressionMethod.STORE == (Zip4cjUtil.getCompressionMethod(fileHeader))) {
                updateLocalFileHeader(fileHeader, splitOutputStream)
            }
        } finally {
            zipOutputStream.close()
            splitOutputStream.close()
        }
    }

    protected func calculateTotalWork(taskParameters: AddStreamToZipTaskParameters): Int64 {
        taskParameters
        return 0
    }

    private func removeFileIfExists(
        zipModel: ZipModel,
        zip4cjConfig: Zip4cjConfig,
        fileNameInZip: String,
        progressMonitor: ProgressMonitor
    ) {
        var fileHeader = HeaderUtil.getFileHeader(zipModel, fileNameInZip)
        if (fileHeader.isSome()) {
            removeFile(fileHeader.getOrThrow(), progressMonitor, zip4cjConfig)
        }
    }
}
