/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class Zip64EndOfCentralDirectoryRecord <: ZipHeader {
    private var sizeOfZip64EndCentralDirectoryRecord: Int64 = 0

    private var versionMadeBy: Int32 = 0

    private var versionNeededToExtract: Int32 = 0

    private var numberOfThisDisk: Int32 = 0

    private var numberOfThisDiskStartOfCentralDirectory: Int32 = 0

    private var totalNumberOfEntriesInCentralDirectoryOnThisDisk: Int64 = 0

    private var totalNumberOfEntriesInCentralDirectory: Int64 = 0

    private var sizeOfCentralDirectory: Int64 = 0

    private var offsetStartCentralDirectoryWRTStartDiskNumber: Int64 = -1

    private var extensibleDataSector: ?Array<Byte> = None

    public func getSizeOfZip64EndCentralDirectoryRecord(): Int64 {
        return sizeOfZip64EndCentralDirectoryRecord
    }

    public func setSizeOfZip64EndCentralDirectoryRecord(sizeOfZip64EndCentralDirectoryRecord: Int64): Unit {
        this.sizeOfZip64EndCentralDirectoryRecord = sizeOfZip64EndCentralDirectoryRecord
    }

    public func getVersionMadeBy(): Int32 {
        return versionMadeBy
    }

    public func setVersionMadeBy(versionMadeBy: Int32): Unit {
        this.versionMadeBy = versionMadeBy
    }

    public func getVersionNeededToExtract(): Int32 {
        return versionNeededToExtract
    }

    public func setVersionNeededToExtract(versionNeededToExtract: Int32): Unit {
        this.versionNeededToExtract = versionNeededToExtract
    }

    public func getNumberOfThisDisk(): Int32 {
        return numberOfThisDisk
    }

    public func setNumberOfThisDisk(numberOfThisDisk: Int32): Unit {
        this.numberOfThisDisk = numberOfThisDisk
    }

    public func getNumberOfThisDiskStartOfCentralDirectory(): Int32 {
        return numberOfThisDiskStartOfCentralDirectory
    }

    public func setNumberOfThisDiskStartOfCentralDirectory(numberOfThisDiskStartOfCentralDirectory: Int32): Unit {
        this.numberOfThisDiskStartOfCentralDirectory = numberOfThisDiskStartOfCentralDirectory
    }

    public func getTotalNumberOfEntriesInCentralDirectoryOnThisDisk(): Int64 {
        return totalNumberOfEntriesInCentralDirectoryOnThisDisk
    }

    public func setTotalNumberOfEntriesInCentralDirectoryOnThisDisk(
        totalNumberOfEntriesInCentralDirectoryOnThisDisk: Int64): Unit {
        this.totalNumberOfEntriesInCentralDirectoryOnThisDisk = totalNumberOfEntriesInCentralDirectoryOnThisDisk
    }

    public func getTotalNumberOfEntriesInCentralDirectory(): Int64 {
        return totalNumberOfEntriesInCentralDirectory
    }

    public func setTotalNumberOfEntriesInCentralDirectory(totalNumberOfEntriesInCentralDirectory: Int64): Unit {
        this.totalNumberOfEntriesInCentralDirectory = totalNumberOfEntriesInCentralDirectory
    }

    public func getSizeOfCentralDirectory(): Int64 {
        return sizeOfCentralDirectory
    }

    public func setSizeOfCentralDirectory(sizeOfCentralDirectory: Int64): Unit {
        this.sizeOfCentralDirectory = sizeOfCentralDirectory
    }

    public func getOffsetStartCentralDirectoryWRTStartDiskNumber(): Int64 {
        return offsetStartCentralDirectoryWRTStartDiskNumber
    }

    public func setOffsetStartCentralDirectoryWRTStartDiskNumber(offsetStartCentralDirectoryWRTStartDiskNumber: Int64): Unit {
        this.offsetStartCentralDirectoryWRTStartDiskNumber = offsetStartCentralDirectoryWRTStartDiskNumber
    }

    public func getExtensibleDataSector(): ?Array<Byte> {
        return extensibleDataSector
    }

    public func setExtensibleDataSector(extensibleDataSector: Array<Byte>): Unit {
        this.extensibleDataSector = extensibleDataSector
    }
}
