/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class AddFilesToZipTask <: AbstractAddFileToZipTask<AddFilesToZipTaskParameters> {
    public AddFilesToZipTask(
        zipModel: ZipModel,
        password: ?Array<Rune>,
        headerWriter: HeaderWriter,
        asyncTaskParameters: AsyncTaskParameters
    ) {
        super(zipModel, password, headerWriter, asyncTaskParameters)
    }

    protected func executeTask(taskParameters: AddFilesToZipTaskParameters, progressMonitor: ProgressMonitor) {
        verifyZipParameters(taskParameters.zipParameters)
        var filesToAdd = determineActualFilesToAdd(taskParameters)
        addFilesToZip(filesToAdd, progressMonitor, taskParameters.zipParameters, taskParameters.zip4cjConfig)
    }

    protected func calculateTotalWork(taskParameters: AddFilesToZipTaskParameters): Int64 {
        return calculateWorkForFiles(taskParameters.filesToAdd, taskParameters.zipParameters)
    }

    private func determineActualFilesToAdd(taskParameters: AddFilesToZipTaskParameters): ArrayList<Path> {
        let filesToAdd = ArrayList<Path>()

        for (i in 0..taskParameters.filesToAdd.size) {
            let inputFile = taskParameters.filesToAdd[i]
            filesToAdd.add(inputFile)
            var isSymLink = FileInfo(inputFile).isSymbolicLink()
            var symbolicLinkAction = taskParameters.zipParameters.getSymbolicLinkAction()
            if (isSymLink && !(SymbolicLinkAction.INCLUDE_LINK_ONLY == (symbolicLinkAction))) {
                filesToAdd.add(all: FileUtils.getFilesInDirectoryRecursive(inputFile, taskParameters.zipParameters))
            }
        }

        return filesToAdd
    }

    protected func getTask(): ProgressMonitorTask {
        return super.getTask()
    }
}
