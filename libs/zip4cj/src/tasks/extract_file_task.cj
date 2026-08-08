/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class ExtractFileTask <: AbstractExtractFileTask<ExtractFileTaskParameters> {
    private var password: ?Array<Rune>
    private var splitInputStream: ?SplitFileInputStream = None

    public ExtractFileTask(
        zipModel: ZipModel,
        password: ?Array<Rune>,
        unzipParameters: UnzipParameters,
        asyncTaskParameters: AsyncTaskParameters
    ) {
        super(zipModel, unzipParameters, asyncTaskParameters)
        this.password = password
    }

    protected func executeTask(taskParameters: ExtractFileTaskParameters, progressMonitor: ProgressMonitor) {
        let fileHeadersUnderDirectory = getFileHeadersToExtract(taskParameters.fileToExtract)
        try (zipInputStream = createZipInputStream(taskParameters.zip4cjConfig)) {
            var readBuff = Array<Byte>(taskParameters.zip4cjConfig.getBufferSize(), repeat: 0)
            for (i in 0..fileHeadersUnderDirectory.size) {
                let fileHeader = fileHeadersUnderDirectory[i]
                splitInputStream.getOrThrow().prepareExtractionForFileHeader(fileHeader)
                var newFileName = determineNewFileName(taskParameters.newFileName.getOrThrow(), taskParameters.fileToExtract,
                    fileHeader)
                extractFile(zipInputStream, fileHeader, taskParameters.outputPath, newFileName, progressMonitor,
                    readBuff)
            }
        } finally {
            if (let Some(v) <- splitInputStream) {
                v.close()
            }
        }
    }

    protected func calculateTotalWork(taskParameters: ExtractFileTaskParameters): Int64 {
        var fileHeadersUnderDirectory = getFileHeadersToExtract(taskParameters.fileToExtract)
        return HeaderUtil.getTotalUncompressedSizeOfAllFileHeaders(fileHeadersUnderDirectory)
    }

    private func getFileHeadersToExtract(fileNameToExtract: String): ArrayList<FileHeader> {
        if (!FileUtils.isZipEntryDirectory(fileNameToExtract)) {
            var fileHeader = HeaderUtil.getFileHeader(getZipModel(), fileNameToExtract)
            if (fileHeader.isNone()) {
                throw ZipException("No file found with name " + fileNameToExtract + " in zip file", FILE_NOT_FOUND)
            }
            return ArrayList<FileHeader>([fileHeader.getOrThrow()])
        }

        return HeaderUtil.getFileHeadersUnderDirectory(
            getZipModel().getCentralDirectory().getOrThrow().getFileHeaders(),
            fileNameToExtract
        )
    }

    private func createZipInputStream(zip4cjConfig: Zip4cjConfig): ZipInputStream {
        splitInputStream = UnzipUtil.createSplitInputStream(getZipModel())
        return ZipInputStream(splitInputStream.getOrThrow(), password: password, config: zip4cjConfig)
    }

    private func determineNewFileName(
        newFileName: String,
        fileNameToExtract: String,
        fileHeaderBeingExtracted: FileHeader
    ): String {
        if (!Zip4cjUtil.isStringNotNullAndNotEmpty(newFileName)) {
            return newFileName
        }

        if (!FileUtils.isZipEntryDirectory(fileNameToExtract)) {
            return newFileName
        }

        var fileSeparator = InternalZipConstants.ZIP_FILE_SEPARATOR
        if (newFileName.endsWith(InternalZipConstants.ZIP_FILE_SEPARATOR)) {
            fileSeparator = ""
        }
        let str = fileHeaderBeingExtracted.getFileName().getOrThrow()
        var arr = str.split(fileNameToExtract, 2)
        return "${arr[0]}${newFileName + fileSeparator}${arr[1]}"
    }
}
