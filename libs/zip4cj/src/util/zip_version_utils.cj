/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public class ZipVersionUtils {
    init(){}
    public static func determineVersionMadeBy(zipParameters: ZipParameters, rawIO: RawIO): Int32 {
        let versionMadeBy = Array<Byte>(2, repeat: 0)
        versionMadeBy[0] = VersionMadeBy.SPECIFICATION_VERSION.getCode()
        versionMadeBy[1] = VersionMadeBy.UNIX.getCode()
        if (isWindows && !zipParameters.isUnixMode()) { // skip setting windows mode if unix mode is forced
            versionMadeBy[1] = VersionMadeBy.WINDOWS.getCode()
        }

        return rawIO.readShortLittleEndian(versionMadeBy, 0)
    }

    public static func determineVersionNeededToExtract(zipParameters: ZipParameters): VersionNeededToExtract {
        var versionRequired = VersionNeededToExtract.DEFAULT

        if (zipParameters.getCompressionMethod() == CompressionMethod.DEFLATE) {
            versionRequired = VersionNeededToExtract.DEFLATE_COMPRESSED
        }

        if (zipParameters.getEntrySize() > InternalZipConstants.ZIP_64_SIZE_LIMIT) {
            versionRequired = VersionNeededToExtract.ZIP_64_FORMAT
        }

        if (zipParameters.isEncryptFiles() && zipParameters.getEncryptionMethod() == (EncryptionMethod.AES)) {
            versionRequired = VersionNeededToExtract.AES_ENCRYPTED
        }

        return versionRequired
    }
}
