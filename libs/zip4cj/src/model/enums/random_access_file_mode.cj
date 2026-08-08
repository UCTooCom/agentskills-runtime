/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model.enums

public enum RandomAccessFileMode {
    | READ
    | WRITE

    public func getValue(): String {
        return match(this) {
            case READ => "r"
            case WRITE => "rw"
        }
    }
}
