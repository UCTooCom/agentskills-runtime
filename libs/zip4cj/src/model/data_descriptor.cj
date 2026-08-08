/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class DataDescriptor <: ZipHeader {
    private var crc: Int64 = 0

    private var compressedSize: Int64 = 0

    private var uncompressedSize: Int64 = 0

    public func getCrc(): Int64 {
        return crc
    }

    public func setCrc(crc: Int64): Unit {
        this.crc = crc
    }

    public func getCompressedSize(): Int64 {
        return compressedSize
    }

    public func setCompressedSize(compressedSize: Int64): Unit {
        this.compressedSize = compressedSize
    }

    public func getUncompressedSize(): Int64 {
        return uncompressedSize
    }

    public func setUncompressedSize(uncompressedSize: Int64): Unit {
        this.uncompressedSize = uncompressedSize
    }
}
