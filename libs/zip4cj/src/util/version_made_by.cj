/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public enum VersionMadeBy {
    | SPECIFICATION_VERSION
    | WINDOWS
    | UNIX

    public func getCode(): Byte {
        return match (this) {
            case SPECIFICATION_VERSION => 51
            case WINDOWS => 0
            case UNIX => 3
        }
    }
}

public enum VersionNeededToExtract {
    | DEFAULT
    | DEFLATE_COMPRESSED
    | ZIP_64_FORMAT
    | AES_ENCRYPTED

    public func getCode(): Int32 {
        return match (this) {
            case DEFAULT => 10
            case DEFLATE_COMPRESSED => 20
            case ZIP_64_FORMAT => 45
            case AES_ENCRYPTED => 51
        }
    }
}
