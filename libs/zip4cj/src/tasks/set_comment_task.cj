/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class SetCommentTask <: AsyncZipTask<SetCommentTaskTaskParameters> {
    private let zipModel: ZipModel

    public SetCommentTask(zipModel: ZipModel, asyncTaskParameters: AsyncTaskParameters) {
        super(asyncTaskParameters)
        this.zipModel = zipModel
    }

    protected func executeTask(taskParameters: SetCommentTaskTaskParameters, progressMonitor: ProgressMonitor) {
        taskParameters
        var endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord = zipModel.getEndOfCentralDirectoryRecord()
        endOfCentralDirectoryRecord.setComment(taskParameters.comment)

        try (outputStream = SplitOutputStream(zipModel.getZipFile())) {
            if (zipModel.isZip64Format()) {
                outputStream.seek(
                    zipModel.getZip64EndOfCentralDirectoryRecord().getOffsetStartCentralDirectoryWRTStartDiskNumber())
            } else {
                outputStream.seek(endOfCentralDirectoryRecord.getOffsetOfStartOfCentralDirectory())
            }

            var headerWriter: HeaderWriter = HeaderWriter()
            headerWriter.finalizeZipFileWithoutValidations(zipModel, outputStream)
        }
    }

    protected func calculateTotalWork(taskParameters: SetCommentTaskTaskParameters): Int64 {
        taskParameters
        return 0
    }

    protected func getTask(): ProgressMonitorTask {
        return ProgressMonitorTask.SET_COMMENT
    }
}
