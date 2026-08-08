/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class ArchiveExtraDataRecord <: ZipHeader {
    private var extraFieldLength: Int32 = 0

    private var extraFieldData: ?String = None

    public func getExtraFieldLength(): Int32 {
        return extraFieldLength
    }

    public func setExtraFieldLength(extraFieldLength: Int32): Unit {
        this.extraFieldLength = extraFieldLength
    }

    public func getExtraFieldData(): ?String {
        return extraFieldData
    }

    public func setExtraFieldData(extraFieldData: String): Unit {
        this.extraFieldData = extraFieldData
    }
}
