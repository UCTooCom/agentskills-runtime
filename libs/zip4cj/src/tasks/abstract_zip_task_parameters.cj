/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.tasks

public abstract class AbstractZipTaskParameters {
    protected var zip4cjConfig: Zip4cjConfig

    protected init(zip4cjConfig: Zip4cjConfig) {
        this.zip4cjConfig = zip4cjConfig
    }
}

public class ExtractAllFilesTaskParameters <: AbstractZipTaskParameters {
    let outputPath: String

    public ExtractAllFilesTaskParameters(outputPath: String, zip4cjConfig: Zip4cjConfig) {
        super(zip4cjConfig)
        this.outputPath = outputPath
    }
}

public class RemoveFilesFromZipTaskParameters <: AbstractZipTaskParameters {
    let filesToRemove: Array<String>

    public init(filesToRemove: Array<String>, zip4cjConfig: Zip4cjConfig) {
        super(zip4cjConfig)
        this.filesToRemove = filesToRemove
    }
}

public class AddFolderToZipTaskParameters <: AbstractZipTaskParameters {
    let folderToAdd: Path
    let zipParameters: ZipParameters

    public init(folderToAdd: Path, zipParameters: ZipParameters, zip4cjConfig: Zip4cjConfig) {
        super(zip4cjConfig)
        this.folderToAdd = folderToAdd
        this.zipParameters = zipParameters
    }
}

public class AddStreamToZipTaskParameters <: AbstractZipTaskParameters {
    let inputStream: InputStream
    let zipParameters: ZipParameters

    public AddStreamToZipTaskParameters(
        inputStream: InputStream,
        zipParameters: ZipParameters,
        zip4cjConfig: Zip4cjConfig
    ) {
        super(zip4cjConfig)
        this.inputStream = inputStream
        this.zipParameters = zipParameters
    }
}

public class ExtractFileTaskParameters <: AbstractZipTaskParameters {
    var outputPath: String
    var fileToExtract: String
    var newFileName: ?String

    public ExtractFileTaskParameters(
        outputPath: String,
        fileToExtract: String,
        newFileName: ?String,
        zip4cjConfig: Zip4cjConfig
    ) {
        super(zip4cjConfig)
        this.outputPath = outputPath
        this.fileToExtract = fileToExtract
        this.newFileName = newFileName
    }
}

public class MergeSplitZipFileTaskParameters <: AbstractZipTaskParameters {
    var outputZipFile: Path

    public MergeSplitZipFileTaskParameters(outputZipFile: Path, zip4cjConfig: Zip4cjConfig) {
        super(zip4cjConfig)
        this.outputZipFile = outputZipFile
    }
}

public class RenameFilesTaskParameters <: AbstractZipTaskParameters {
    let fileNamesMap: Map<String, String>

    public RenameFilesTaskParameters(fileNamesMap: Map<String, String>, zip4cjConfig: Zip4cjConfig) {
        super(zip4cjConfig)
        this.fileNamesMap = fileNamesMap
    }
}

public class SetCommentTaskTaskParameters <: AbstractZipTaskParameters {
    var comment: String

    public SetCommentTaskTaskParameters(comment: String, zip4cjConfig: Zip4cjConfig) {
        super(zip4cjConfig)
        this.comment = comment
    }
}

public class AddFilesToZipTaskParameters <: AbstractZipTaskParameters {
    let filesToAdd: Array<Path>
    let zipParameters: ZipParameters

    public init(filesToAdd: Array<Path>, zipParameters: ZipParameters, zip4cjConfig: Zip4cjConfig) {
        super(zip4cjConfig)
        this.filesToAdd = filesToAdd
        this.zipParameters = zipParameters
    }
}
