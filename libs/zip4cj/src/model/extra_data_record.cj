/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class ExtraDataRecord <: ZipHeader {
    private var header: Int64 = 0

    private var sizeOfData: Int64 = 0

    private var data: ?Array<Byte> = None

    public func getHeader(): Int64 {
        return header
    }

    public func setHeader(header: Int64): Unit {
        this.header = header
    }

    public func getSizeOfData(): Int64 {
        return sizeOfData
    }

    public func setSizeOfData(sizeOfData: Int64): Unit {
        this.sizeOfData = sizeOfData
    }

    public func getData(): ?Array<Byte> {
        return data
    }

    public func setData(data: Array<Byte>): Unit {
        this.data = data
    }
}
