/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

class StoreOutputStream <: CompressedOutputStream {
    public init(cipherOutputStream: ICipherOutputStream) {
        super(cipherOutputStream)
    }
}
