/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class ExtractAllFilesTask <: AbstractExtractFileTask<ExtractAllFilesTaskParameters> {
    private let password: ?Array<Rune>
    private var splitInputStream: SplitFileInputStream = unsafe { zeroValue<SplitFileInputStream>() }
    private var isSplitInputStream: Bool = false

    public init(
        zipModel: ZipModel,
        password: ?Array<Rune>,
        unzipParameters: UnzipParameters,
        asyncTaskParameters: AsyncTaskParameters
    ) {
        super(zipModel, unzipParameters, asyncTaskParameters)
        this.password = password
    }

    protected func executeTask(taskParameters: ExtractAllFilesTaskParameters, progressMonitor: ProgressMonitor) {
        let zipInputStream = prepareZipInputStream(taskParameters.zip4cjConfig)
        try {
            let fileHeaders = getZipModel().getCentralDirectory().getOrThrow().getFileHeaders()
            for (i in 0..fileHeaders.size) {
                let fileHeader = fileHeaders[i]
                if (fileHeader.getFileName().getOrThrow().startsWith("__MACOSX")) {
                    progressMonitor.updateWorkCompleted(fileHeader.getUncompressedSize())
                    continue
                }

                splitInputStream.prepareExtractionForFileHeader(fileHeader)

                var readBuff = Array<Byte>(taskParameters.zip4cjConfig.getBufferSize(), repeat: 0)
                extractFile(zipInputStream, fileHeader, taskParameters.outputPath, None, progressMonitor, readBuff)
                verifyIfTaskIsCancelled()
            }
        } finally {
            // TODO  Resource close
        }
    }

    protected func calculateTotalWork(taskParameters: ExtractAllFilesTaskParameters): Int64 {
        taskParameters
        return HeaderUtil.getTotalUncompressedSizeOfAllFileHeaders(getZipModel().getCentralDirectory().getOrThrow().getFileHeaders())
    }

    private func prepareZipInputStream(zip4cjConfig: Zip4cjConfig): ZipInputStream {
        splitInputStream = UnzipUtil.createSplitInputStream(getZipModel())
        if (let Some(fileHeader) <- getFirstFileHeader(getZipModel())) {
            splitInputStream.prepareExtractionForFileHeader(fileHeader)
        }
        return ZipInputStream(splitInputStream, password: password, config: zip4cjConfig)
    }

    private func getFirstFileHeader(zipModel: ZipModel): ?FileHeader {
        if (zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size == 0) {
            return None
        }
        return zipModel.getCentralDirectory().getOrThrow().getFileHeaders()[0]
    }
}
