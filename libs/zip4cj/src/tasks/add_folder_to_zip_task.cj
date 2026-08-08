/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public class AddFolderToZipTask <: AbstractAddFileToZipTask<AddFolderToZipTaskParameters> {
    public AddFolderToZipTask(
        zipModel: ZipModel,
        password: ?Array<Rune>,
        headerWriter: HeaderWriter,
        asyncTaskParameters: AsyncTaskParameters
    ) {
        super(zipModel, password, headerWriter, asyncTaskParameters)
    }

    protected func executeTask(taskParameters: AddFolderToZipTaskParameters, progressMonitor: ProgressMonitor) {
        var filesToAdd = getFilesToAdd(taskParameters)
        setDefaultFolderPath(taskParameters)
        addFilesToZip(filesToAdd, progressMonitor, taskParameters.zipParameters, taskParameters.zip4cjConfig)
    }

    protected func calculateTotalWork(taskParameters: AddFolderToZipTaskParameters): Int64 {
        var filesToAdd = getFilesToAdd(taskParameters)

        if (taskParameters.zipParameters.isIncludeRootFolder()) {
            filesToAdd.add(taskParameters.folderToAdd)
        }

        return calculateWorkForFiles(
            unsafe {filesToAdd.getRawArray()[0..filesToAdd.size]},
            taskParameters.zipParameters)
    }

    private func setDefaultFolderPath(taskParameters: AddFolderToZipTaskParameters) {
        var folderToAdd = taskParameters.folderToAdd
        let rootFolderPath: Path = if (taskParameters.zipParameters.isIncludeRootFolder()) {
            let parent = folderToAdd.parent
            if (parent.isEmpty()) {
                InternalZipConstants.FILE_CURRENT_PATH
            } else {
                parent
            }
        } else {
            folderToAdd
        }
        taskParameters.zipParameters.setDefaultFolderPath(canonicalize(rootFolderPath).toString())
    }

    private func getFilesToAdd(taskParameters: AddFolderToZipTaskParameters): ArrayList<Path> {
        // TODO getFilesInDirectoryRecursive
        var filesToAdd: ArrayList<Path> = FileUtils.getFilesInDirectoryRecursive(
            taskParameters.folderToAdd,
            taskParameters.zipParameters
        )
        if (taskParameters.zipParameters.isIncludeRootFolder()) {
            filesToAdd.add(taskParameters.folderToAdd)
        }

        return filesToAdd
    }
}
