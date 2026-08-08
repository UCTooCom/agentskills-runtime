/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

@When[os == "Linux"]
func isLinuxOS(): Bool {true}
@When[os != "Linux"]
func isLinuxOS(): Bool {false}
@When[os == "Windows"]
func isWindowsOS(): Bool {true}
@When[os != "Windows"]
func isWindowsOS(): Bool {false}
@When[os == "macOS"]
func isMacOS(): Bool {true}
@When[os != "macOS"]
func isMacOS(): Bool {false}
func getCurrentOS(): (Bool, Bool, Bool) {
    let islin = isLinuxOS()
    let iswin = isWindowsOS()
    let ismac = isMacOS()

    if (!islin && !iswin && !ismac) {
        return (false, false, false)
    } else if (islin) {
        return (true, false, false)
    }else if (iswin) {
        return (false, true, false)
    }else if (ismac) {
        return (false, false, true)
    } else {
        throw IllegalArgumentException()
    }
}

let (isUnix, isWindows, isMac) = getCurrentOS()

public class FileUtils {
    public static let DEFAULT_POSIX_FILE_ATTRIBUTES: Array<Byte> = [0, 0, 164, 129] //-rw-r--r--
    public static let DEFAULT_POSIX_FOLDER_ATTRIBUTES: Array<Byte> = [0, 0, 237, 65] //drwxr-xr-x

    public static func setFileAttributes(file: Path, fileAttributes: Array<Byte>): Unit {
        if (fileAttributes.size == 0) {
            return
        }

        if (isWindows) {
            applyWindowsFileAttributes(file, fileAttributes)
        } else if (isMac || isUnix) {
            applyPosixFileAttributes(file, fileAttributes)
        }
    }

    // TODO
    public static func setFileLastModifiedTime(file: Path, lastModifiedTime: Int64) {
        if (lastModifiedTime <= 0 || !exists(file)) {
            return
        }

    }

    // TODO
    public static func setFileLastModifiedTimeWithoutNio(file: Path, lastModifiedTime: Int64) {
        (file, lastModifiedTime)
        return
    }

    public static func getFileAttributes(file: FileInfo): Array<Byte> {
        try {
            if ((!file.isSymbolicLink() && !exists(file.path))) {
                return Array<Byte>(4, repeat: 0)
            }

            if (isWindows) {
                return getWindowsFileAttributes(file.path)
            } else if (isMac || isUnix) {
                return getPosixFileAttributes(file.path)
            } else {
                return Array<Byte>(4, repeat: 0)
            }
        } catch (e: Exception) {
            return Array<Byte>(4, repeat: 0)
        }
    }

    // TODO 如果是链接文件
    public static func getFilesInDirectoryRecursive(
        path: Path,
        zipParameters: ZipParameters,
        paths!: ArrayList<Path> = ArrayList<Path>()
    ): ArrayList<Path> {
        if (path.isEmpty() || !exists(path)) {
            return ArrayList<Path>()
        }
        let fileInfo = FileInfo(path)
        if (!fileInfo.isDirectory() || !fileInfo.canRead()) {
            return paths
        }
        for (subPath in Directory.readFrom(path)) {
            if (let Some(v) <- zipParameters.getExcludeFileFilter()) {
                if (v.isExcluded(subPath.path)) {
                    continue
                }
            } 
            let isSymLink = subPath.isSymbolicLink()
            if (isSymLink) {
                paths.add(subPath.path)
                if (zipParameters.getSymbolicLinkAction() != SymbolicLinkAction.INCLUDE_LINK_ONLY) {
                    let linkPath = SymbolicLink.readFrom(subPath.path)
                    getFilesInDirectoryRecursive(linkPath, zipParameters, paths: paths)
                }
                continue
            } 

            if (subPath.isHidden() && !zipParameters.isReadHiddenFiles()) {
                continue
            }
            paths.add(subPath.path)
            
            
            if (!isSymLink && subPath.isDirectory()) {
                getFilesInDirectoryRecursive(subPath.path, zipParameters, paths: paths)
            }
        }
        return paths
    }

    public static func getFileNameWithoutExtension(fileName: String): String {
        if (let Some(pos) <- fileName.lastIndexOf(".")) {
            return String(fileName.toRuneArray()[0..pos])
        }
        return fileName
    }

    public static func getZipFileNameWithoutExtension(zipFile: String): String {
        if (!Zip4cjUtil.isStringNotNullAndNotEmpty(zipFile)) {
            throw ZipException("zip file name is empty or null, cannot determine zip file name")
        }
        return if (zipFile.endsWith(".zip")) {
            zipFile[0..zipFile.size - 4]
        } else {
            zipFile
        }
    }

    public static func getSplitZipFiles(zipModel: ZipModel): ArrayList<Path> {
        if (!exists(zipModel.getZipFile())) {
            throw ZipException("zip file does not exist")
        }
        var splitZipFiles = ArrayList<Path>()
        var currZipFile = zipModel.getZipFile()
        var partFile: String

        if (!zipModel.isSplitArchive()) {
            splitZipFiles.add(currZipFile)
            return splitZipFiles
        }

        var numberOfThisDisk = zipModel.getEndOfCentralDirectoryRecord().getNumberOfThisDisk()

        if (numberOfThisDisk == 0) {
            splitZipFiles.add(currZipFile)
            return splitZipFiles
        } else {
            for (i in 0..numberOfThisDisk) {
                if (i == numberOfThisDisk) {
                    splitZipFiles.add(zipModel.getZipFile())
                } else {
                    var fileExt = ".z0"
                    if (i >= 9) {
                        fileExt = ".z"
                    }
                    partFile = if (currZipFile.fileName.contains(".")) {
                        unsafe{
                            String.fromUtf8Unchecked(
                            currZipFile.toString().toArray()[0..currZipFile.toString().
                                lastIndexOf(".").getOrThrow()])
                        }
                    } else {
                        currZipFile.toString()
                    }
                    partFile = partFile + fileExt + "${(i + 1)}"
                    splitZipFiles.add(Path(partFile))
                }
            }
        }
        return splitZipFiles
    }

    public static func getRelativeFileName(fileToAdd: Path, zipParameters: ZipParameters): String {
        if (fileToAdd.isEmpty()) {
            return ""  
        } else if (!exists(fileToAdd)) {
            return fileToAdd.fileName
        }
        var fileName: String
        try {
            var defaultFolderPath = match (zipParameters.getDefaultFolderPath()) {
                case Some(v) => v.trim()
                case None => ""
            }
            if (defaultFolderPath.size != 0) {
                var fileCanonicalPath: Path
                try {
                    fileCanonicalPath = canonicalize(fileToAdd)
                } catch(_: Exception) {
                    return fileToAdd.fileName
                }
                var rootFolderFile = Path(defaultFolderPath)
                var rootFolderFileRef = canonicalize(rootFolderFile).toString()

                if (!rootFolderFileRef.endsWith(Path.Separator)) {
                    rootFolderFileRef = "${rootFolderFileRef}${Path.Separator}"
                }
                var tmpFileName: String = if (FileInfo(fileToAdd).isSymbolicLink()) {
                    var rootPath = "${canonicalize(fileToAdd.parent)}${Path.Separator}${canonicalize(fileToAdd).fileName}"
                    unsafe { String.fromUtf8Unchecked(rootPath.toArray()[rootFolderFileRef.size..])}
                } else {
                    let canonicalizeFileToAdd = canonicalize(fileToAdd)
                    if (!canonicalizeFileToAdd.toString().startsWith(rootFolderFileRef)) {
                        "${canonicalizeFileToAdd.parent}${Path.Separator}${canonicalizeFileToAdd}"
                    } else {
                        unsafe { String.fromUtf8Unchecked(fileCanonicalPath.toString().toArray()[rootFolderFileRef.size..]) }
                    }
                }
                    
                if (tmpFileName.startsWith(Path.Separator)) {
                    tmpFileName = unsafe { String.fromUtf8Unchecked(tmpFileName.toArray()[1..]) }
                }

                var tmpFile = fileCanonicalPath

                if (FileInfo(tmpFile).isDirectory()) {
                    tmpFileName = "${tmpFileName.replace("\\\\", InternalZipConstants.ZIP_FILE_SEPARATOR)}${InternalZipConstants.ZIP_FILE_SEPARATOR}"
                } else {
                    let bkFileName = unsafe {
                        String.fromUtf8Unchecked(
                            tmpFileName.toArray()[0..tmpFileName.lastIndexOf(tmpFile.fileName).getOrThrow()]
                    )}
                    tmpFileName = "${bkFileName.replace("\\\\", InternalZipConstants.ZIP_FILE_SEPARATOR)}${getNameOfFileInZip(tmpFile, zipParameters.getFileNameInZip())}"
                }

                fileName = tmpFileName
            } else {
                fileName = getNameOfFileInZip(fileToAdd, zipParameters.getFileNameInZip())
                if (FileInfo(fileToAdd).isDirectory()) {
                    fileName += InternalZipConstants.ZIP_FILE_SEPARATOR
                }
            }
        } catch (e: IOException) {
            e.printStackTrace()
            throw ZipException(e.message)
        }

        var rootFolderNameInZip = ""
        if (let Some(v) <- zipParameters.getRootFolderNameInZip()) {
            var rootFolderNameInZip = v
            if (!rootFolderNameInZip.endsWith("\\") && !rootFolderNameInZip.endsWith("/")) {
                rootFolderNameInZip = "${rootFolderNameInZip}${Path.Separator}"
            }
            fileName = "${rootFolderNameInZip.replace("\\\\", InternalZipConstants.ZIP_FILE_SEPARATOR)}${fileName}"
        }

        if (!Zip4cjUtil.isStringNotNullAndNotEmpty(fileName)) {
            var errorMessage = "fileName to add to zip is empty or null. fileName: '${fileName}' DefaultFolderPath: '${zipParameters.getDefaultFolderPath()}'  FileNameInZip: ${zipParameters.getFileNameInZip()}"

            if (FileInfo(fileToAdd).isSymbolicLink()) {
                errorMessage += "isSymlink: true "
            }

            if (Zip4cjUtil.isStringNotNullAndNotEmpty(rootFolderNameInZip)) {
                errorMessage = "rootFolderNameInZip: '" + rootFolderNameInZip + "' "
            }

            throw ZipException(errorMessage)
        }
        return fileName
    }

    private static func getNameOfFileInZip(fileToAdd: Path, fileNameInZip: ?String): String {
        if (Zip4cjUtil.isStringNotNullAndNotEmpty(fileNameInZip)) {
            return fileNameInZip.getOrThrow()
        }
        // TODO 设置链接文件
        return fileToAdd.fileName
    }

    public static func isZipEntryDirectory(fileNameInZip: String): Bool {
        return fileNameInZip.endsWith("/") || fileNameInZip.endsWith("\\")
    }

    public static func copyFile(
        randomAccessFile: RandomAccessFile,
        outputStream: OutputStream,
        start: Int64,
        end: Int64,
        progressMonitor: ProgressMonitor,
        bufferSize: Int64
    ) {
        if (start < 0 || end < 0 || start > end) {
            throw ZipException("invalid offsets")
        }

        if (start == end) {
            return
        }

        try {
            randomAccessFile.seek(start)
            var readLen: Int64
            var buff: Array<Byte>
            var bytesRead: Int64 = 0
            var bytesToRead: Int64 = end - start

            if ((end - start) < bufferSize) {
                buff = Array<Byte>(bytesToRead, repeat: 0)
            } else {
                buff = Array<Byte>(bufferSize, repeat: 0)
            }
            readLen = randomAccessFile.read(buff)

            while (readLen != -1) {
                outputStream.write(buff[0..readLen])

                progressMonitor.updateWorkCompleted(readLen)
                if (progressMonitor.isCancelAllTasks()) {
                    progressMonitor.setResult(ProgressMonitorResult.CANCELLED)
                    return
                }

                bytesRead += readLen

                if (bytesRead == bytesToRead) {
                    break
                } else if (bytesRead + buff.size > bytesToRead) {
                    buff = Array<Byte>(bytesToRead - bytesRead, repeat: 0)
                }
                readLen = randomAccessFile.read(buff)
            }
        } catch (e: IOException) {
            throw ZipException(e.message)
        }
    }

    public static func isNumberedSplitFile(file: Path): Bool {
        return file.fileName.endsWith(InternalZipConstants.SEVEN_ZIP_SPLIT_FILE_EXTENSION_PATTERN)
    }

    public static func getFileExtension(path: Path): String {
        return path.extensionName
    }

    /**
     * A helper method to retrieve all split files which are of the format split by 7-zip, i.e, .zip.001, .zip.002, etc.
     * This method also sorts all the files by their split part
     * @param firstNumberedFile - first split file
     * @return sorted list of split files. Returns an empty list if no files of that pattern are found in the current directory
     */
    public static func getAllSortedNumberedSplitFiles(firstNumberedFile: Path): Array<Path> {
        var zipFileNameWithoutExtension = FileUtils.getFileNameWithoutExtension(firstNumberedFile.fileName)
        let listFiles = ArrayList<Path>()
        for (file in Directory.readFrom(firstNumberedFile.parent) where file.isRegular()) {
            if (file.path.fileName.startsWith(zipFileNameWithoutExtension)) {
                listFiles.add(file.path)
            }
        }
        return unsafe { listFiles.getRawArray()[0..listFiles.size] }
    }

    public static func readSymbolicLink(file: Path): String {
        return try {
            SymbolicLink.readFrom(file).toString()
        } catch (_) {
            return ""
        }
    }

    public static func getDefaultFileAttributes(isDirectory: Bool): Array<Byte> {
        var permissions = Array<Byte>(4, repeat: 0)
        if (isUnix || isMac) {
            if (isDirectory) {
                ArrayCopy(DEFAULT_POSIX_FOLDER_ATTRIBUTES, 0, permissions, 0, permissions.size)
            } else {
                ArrayCopy(DEFAULT_POSIX_FILE_ATTRIBUTES, 0, permissions, 0, permissions.size)
            }
        } else if (isWindows && isDirectory) {
            permissions[0] = BitUtils.setBit(permissions[0], 4)
        }
        return permissions
    }

    private static func getExtensionZerosPrefix(index: Int64): String {
        return if (index < 9) {
             "00"
        } else if (index < 99) {
            "0"
        } else {
            ""
        }
    }

    // TODO 文件权限设置
    private static func applyWindowsFileAttributes(file: Path, fileAttributes: Array<Byte>) {
        file
        if (fileAttributes[0] == 0) {
            // No file attributes defined in the archive
            return
        }
    }

    // TODO 文件权限设置
    private static func applyPosixFileAttributes(file: Path, fileAttributes: Array<Byte>): Unit {
        file
        if (fileAttributes[2] == 0 && fileAttributes[3] == 0) {
            // No file attributes defined
            return
        }
    }

    private static func getWindowsFileAttributes(file: Path): Array<Byte>  {
        var fileAttributes = Array<Byte>(4, repeat:0)
        try {
            let dosFileAttributes = FileInfo(file)
            var windowsAttribute: Byte = 0
            windowsAttribute = setBitIfApplicable(dosFileAttributes.isReadOnly(), windowsAttribute, 0)
            windowsAttribute = setBitIfApplicable(dosFileAttributes.isHidden(), windowsAttribute, 1)
            windowsAttribute = setBitIfApplicable(false, windowsAttribute, 2)
            windowsAttribute = setBitIfApplicable(dosFileAttributes.isDirectory(), windowsAttribute, 4)
            windowsAttribute = setBitIfApplicable(true, windowsAttribute, 5)
            fileAttributes[0] = windowsAttribute
        } catch (_) {
            // ignore
        }
        return fileAttributes
    }

    private static func assertFileExists(path: Path) {
        if (!exists(path)) {
            throw ZipException("File does not exist ${path}")
        }
    }

    private static func assertSymbolicLinkTargetExists(path: Path) {
        if (!exists(path)) {
            throw ZipException("Symlink target '" + readSymbolicLink(path) + "' does not exist for link '${path}'")
        }
    }

    private static func getPosixFileAttributes(file: Path): Array<Byte> {
        var fileAttributes = Array<Byte>(4, repeat: 0)

        try {
            let fileInfo = FileInfo(file)
            let isSymlink = fileInfo.isSymbolicLink()
            if (isSymlink) {
                // Mark as a regular file and not a directory if file is a symlink and even if the symlink points to a directory
                fileAttributes[3] = BitUtils.setBit(fileAttributes[3], 7)
                fileAttributes[3] = BitUtils.unsetBit(fileAttributes[3], 6)
            } else {
                fileAttributes[3] = setBitIfApplicable(fileInfo.isRegular(), fileAttributes[3], 7)
                fileAttributes[3] = setBitIfApplicable(fileInfo.isDirectory(), fileAttributes[3], 6)
            }
            fileAttributes[3] = setBitIfApplicable(isSymlink, fileAttributes[3], 5)
            fileAttributes[3] = setBitIfApplicable(fileInfo.canRead(), fileAttributes[3], 0)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canWrite(), fileAttributes[2], 7)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canExecute(), fileAttributes[2], 6)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canRead(), fileAttributes[2], 5)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canWrite(), fileAttributes[2], 4)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canExecute(), fileAttributes[2], 3)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canRead(), fileAttributes[2], 2)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canWrite(), fileAttributes[2], 1)
            fileAttributes[2] = setBitIfApplicable(fileInfo.canExecute(), fileAttributes[2], 0)
        } catch (e: Exception) {
            // Ignore
        }

        return fileAttributes
    }

    private static func setBitIfApplicable(applicable: Bool, b: Byte, pos: Int64): Byte {
        if (applicable) {
            return BitUtils.setBit(b, pos)
        }

        return b
    }
}
