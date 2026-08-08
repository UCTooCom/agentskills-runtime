/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class Zip64ExtendedInfo <: ZipHeader & Equatable<Zip64ExtendedInfo> {
    private var size: Int32

    private var compressedSize: Int64

    private var uncompressedSize: Int64

    private var offsetLocalHeader: Int64

    private var diskNumberStart: Int32

    public init() {
        size = 0
        compressedSize = -1
        uncompressedSize = -1
        offsetLocalHeader = -1
        diskNumberStart = -1
    }

    public func getSize(): Int32 {
        return size
    }

    public func setSize(size: Int32): Unit {
        this.size = size
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

    public func getOffsetLocalHeader(): Int64 {
        return offsetLocalHeader
    }

    public func setOffsetLocalHeader(offsetLocalHeader: Int64): Unit {
        this.offsetLocalHeader = offsetLocalHeader
    }

    public func getDiskNumberStart(): Int32 {
        return diskNumberStart
    }

    public func setDiskNumberStart(diskNumberStart: Int32): Unit {
        this.diskNumberStart = diskNumberStart
    }

    public operator func ==(that: Zip64ExtendedInfo): Bool {
        return refEq(this, that)
    }

    public operator func !=(that: Zip64ExtendedInfo): Bool {
        return !(this == that)
    }
}
