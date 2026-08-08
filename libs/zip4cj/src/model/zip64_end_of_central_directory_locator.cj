/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class Zip64EndOfCentralDirectoryLocator <: ZipHeader {
    private var numberOfDiskStartOfZip64EndOfCentralDirectoryRecord: Int32 = 0

    private var offsetZip64EndOfCentralDirectoryRecord: Int64 = 0

    private var totalNumberOfDiscs: Int32 = 0

    public func getNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord(): Int32 {
        return numberOfDiskStartOfZip64EndOfCentralDirectoryRecord
    }

    public func setNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord(
        numberOfDiskStartOfZip64EndOfCentralDirectoryRecord: Int32): Unit {
        this.numberOfDiskStartOfZip64EndOfCentralDirectoryRecord = numberOfDiskStartOfZip64EndOfCentralDirectoryRecord
    }

    public func getOffsetZip64EndOfCentralDirectoryRecord(): Int64 {
        return offsetZip64EndOfCentralDirectoryRecord
    }

    public func setOffsetZip64EndOfCentralDirectoryRecord(offsetZip64EndOfCentralDirectoryRecord: Int64): Unit {
        this.offsetZip64EndOfCentralDirectoryRecord = offsetZip64EndOfCentralDirectoryRecord
    }

    public func getTotalNumberOfDiscs(): Int32 {
        return totalNumberOfDiscs
    }

    public func setTotalNumberOfDiscs(totalNumberOfDiscs: Int32): Unit {
        this.totalNumberOfDiscs = totalNumberOfDiscs
    }
}
