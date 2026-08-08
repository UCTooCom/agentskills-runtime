/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class LocalFileHeader <: AbstractFileHeader {
    private var extraField: ?Array<Byte> = None

    private var offsetStartOfData: Int64 = 0

    private var writeCompressedSizeInZip64ExtraRecord: Bool = false

    public init() {
        setSignature(HeaderSignature.LOCAL_FILE_HEADER)
    }

    public func getExtraField(): ?Array<Byte> {
        return extraField
    }

    public func setExtraField(extraField: Array<Byte>): Unit {
        this.extraField = extraField
    }

    public func getOffsetStartOfData(): Int64 {
        return offsetStartOfData
    }

    public func setOffsetStartOfData(offsetStartOfData: Int64): Unit {
        this.offsetStartOfData = offsetStartOfData
    }

    public func isWriteCompressedSizeInZip64ExtraRecord(): Bool {
        return writeCompressedSizeInZip64ExtraRecord
    }

    public func setWriteCompressedSizeInZip64ExtraRecord(writeCompressedSizeInZip64ExtraRecord: Bool): Unit {
        this.writeCompressedSizeInZip64ExtraRecord = writeCompressedSizeInZip64ExtraRecord
    }
}
