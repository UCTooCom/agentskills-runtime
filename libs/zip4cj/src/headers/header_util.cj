/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.headers

public class HeaderUtil {
    private init() {}
    public static func getFileHeader(zipModel: ZipModel, fileNameArg: String): ?FileHeader {
        var fileName = fileNameArg
        var fileHeader = getFileHeaderWithExactMatch(zipModel, fileName)
        if (fileHeader.isNone()) {
            fileName = fileName.replace("\\\\", "/")
            fileHeader = getFileHeaderWithExactMatch(zipModel, fileName)

            if (fileHeader.isNone()) {
                fileName = fileName.replace("/", "\\\\")
                fileHeader = getFileHeaderWithExactMatch(zipModel, fileName)
            }
        }

        return fileHeader
    }

    public static func decodeStringWithCharset(data: Array<Byte>, isUtf8Encoded: Bool) {
        if (isUtf8Encoded) {
            return String.fromUtf8(data)
        }

        try {
            return decodeCp437(data)
        } catch (_: ZipException) {
            return String.fromUtf8(data)
        } catch (e: Exception) {
            throw e
        }
    }

    public static func getBytesFromString(string: String): Array<Byte> {
        return string.toArray()
    }

    public static func getOffsetStartOfCentralDirectory(zipModel: ZipModel): Int64 {
        if (zipModel.isZip64Format()) {
            return zipModel.getZip64EndOfCentralDirectoryRecord().getOffsetStartCentralDirectoryWRTStartDiskNumber()
        }
        return zipModel.getEndOfCentralDirectoryRecord().getOffsetOfStartOfCentralDirectory()
    }

    public static func getFileHeadersUnderDirectory(allFileHeaders: ArrayList<FileHeader>, fileName: String): ArrayList<FileHeader> {
        let fileHeadersUnderDirectory = ArrayList<FileHeader>()
        for (i in 0..allFileHeaders.size) {
            let fileHeader = allFileHeaders[i]
            if (let Some(v) <- fileHeader.getFileName()) {
                if (v.startsWith(fileName)) {
                    fileHeadersUnderDirectory.add(fileHeader)
                }
            } else {
                throw NoneValueException("FileHeader.getFileName() is null.")
            }
        }
        return fileHeadersUnderDirectory
    }

    public static func getTotalUncompressedSizeOfAllFileHeaders(fileHeaders: ArrayList<FileHeader>): Int64 {
        var totalUncompressedSize = 0
        for (i in 0..fileHeaders.size) {
            let fileHeader = fileHeaders[i]
            if (fileHeader.getZip64ExtendedInfo().isSome() &&
                fileHeader.getZip64ExtendedInfo().getOrThrow().getUncompressedSize() > 0) {
                totalUncompressedSize += fileHeader.getZip64ExtendedInfo().getOrThrow().getUncompressedSize()
            } else {
                totalUncompressedSize += fileHeader.getUncompressedSize()
            }
        }
        return totalUncompressedSize
    }

    private static func getFileHeaderWithExactMatch(zipModel: ZipModel, fileName: String): ?FileHeader {
        if (!Zip4cjUtil.isStringNotNullAndNotEmpty(fileName)) {
            throw ZipException(
                "file name is null, cannot determine file header with exact match for fileName: " + fileName)
        }
        if (zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size == 0) {
            return None
        }
        let fileHeaders = zipModel.getCentralDirectory().getOrThrow().getFileHeaders()
        for (i in 0..fileHeaders.size) {
            let fileHeader = fileHeaders[i]
            var fileNameForHdr = fileHeader.getFileName()
            if (!Zip4cjUtil.isStringNotNullAndNotEmpty(fileNameForHdr)) {
                continue
            }

            if (fileName == fileNameForHdr.getOrThrow()) {
                return fileHeader
            }
        }
        return None
    }
}
