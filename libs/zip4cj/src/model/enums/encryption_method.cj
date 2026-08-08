/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model.enums

public enum EncryptionMethod <: Equal<EncryptionMethod> {
    | NONE
    | ZIP_STANDARD
    | ZIP_STANDARD_VARIANT_STRONG
    | AES

    public operator func ==(that: EncryptionMethod): Bool {
        return match ((this, that)) {
            case (NONE, NONE) => true
            case (ZIP_STANDARD, ZIP_STANDARD) => true
            case (ZIP_STANDARD_VARIANT_STRONG, ZIP_STANDARD_VARIANT_STRONG) => true
            case (AES, AES) => true
            case _ => false
        }
    }
}
