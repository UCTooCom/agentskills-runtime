/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class EndOfCentralDirectoryRecord <: ZipHeader {
    private var numberOfThisDisk: Int32 = 0

    private var numberOfThisDiskStartOfCentralDir: Int32 = 0

    private var totalNumberOfEntriesInCentralDirectoryOnThisDisk: Int32 = 0

    private var totalNumberOfEntriesInCentralDirectory: Int64 = 0

    private var sizeOfCentralDirectory: Int32 = 0

    private var offsetOfStartOfCentralDirectory: Int64 = 0

    private var offsetOfEndOfCentralDirectory: Int64 = 0

    private var comment: String = ""

    public init() {
        setSignature(HeaderSignature.END_OF_CENTRAL_DIRECTORY)
    }

    public func getNumberOfThisDisk(): Int32 {
        return numberOfThisDisk
    }

    public func setNumberOfThisDisk(numberOfThisDisk: Int32): Unit {
        this.numberOfThisDisk = numberOfThisDisk
    }

    public func getNumberOfThisDiskStartOfCentralDir(): Int32 {
        return numberOfThisDiskStartOfCentralDir
    }

    public func setNumberOfThisDiskStartOfCentralDir(numberOfThisDiskStartOfCentralDir: Int32): Unit {
        this.numberOfThisDiskStartOfCentralDir = numberOfThisDiskStartOfCentralDir
    }

    public func getTotalNumberOfEntriesInCentralDirectoryOnThisDisk(): Int32 {
        return totalNumberOfEntriesInCentralDirectoryOnThisDisk
    }

    public func setTotalNumberOfEntriesInCentralDirectoryOnThisDisk(
        totalNumberOfEntriesInCentralDirectoryOnThisDisk: Int32): Unit {
        this.totalNumberOfEntriesInCentralDirectoryOnThisDisk = totalNumberOfEntriesInCentralDirectoryOnThisDisk
    }

    public func getTotalNumberOfEntriesInCentralDirectory(): Int64 {
        return totalNumberOfEntriesInCentralDirectory
    }

    public func setTotalNumberOfEntriesInCentralDirectory(totalNumberOfEntriesInCentralDirectory: Int64): Unit {
        this.totalNumberOfEntriesInCentralDirectory = totalNumberOfEntriesInCentralDirectory
    }

    public func getSizeOfCentralDirectory(): Int32 {
        return sizeOfCentralDirectory
    }

    public func setSizeOfCentralDirectory(sizeOfCentralDirectory: Int32): Unit {
        this.sizeOfCentralDirectory = sizeOfCentralDirectory
    }

    public func getOffsetOfStartOfCentralDirectory(): Int64 {
        return offsetOfStartOfCentralDirectory
    }

    public func setOffsetOfStartOfCentralDirectory(offsetOfStartOfCentralDirectory: Int64): Unit {
        this.offsetOfStartOfCentralDirectory = offsetOfStartOfCentralDirectory
    }

    public func getOffsetOfEndOfCentralDirectory(): Int64 {
        return offsetOfEndOfCentralDirectory
    }

    public func setOffsetOfEndOfCentralDirectory(offsetOfEndOfCentralDirectory: Int64): Unit {
        this.offsetOfEndOfCentralDirectory = offsetOfEndOfCentralDirectory
    }

    public func getComment(): String {
        return comment
    }

    public func setComment(comment: ?String): Unit {
        if (comment != None) {
            this.comment = comment.getOrThrow()
        }
    }
}
