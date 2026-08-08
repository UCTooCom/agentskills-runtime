/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model.enums

public enum AesVersion <: Equal<AesVersion> {
    | ONE
    | TWO

    public func getVersionNumber(): Int32 {
        return match(this) {
            case ONE => 1
            case TWO => 2
        }
    }

    public static func getFromVersionNumber(versionNumber: Int32): AesVersion {
        return match(versionNumber) {
            case 1 => ONE
            case 2 => TWO
            case _ => throw ZipException("Unsupported Aes version")
        }
    }

    public operator func == (that: AesVersion): Bool {
        if (this.getVersionNumber() == that.getVersionNumber()) {
            return true
        }
        return false
    }
}
