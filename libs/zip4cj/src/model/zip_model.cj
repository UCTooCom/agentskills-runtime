/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class ZipModel {
    private var localFileHeaders: ArrayList<LocalFileHeader> = ArrayList<LocalFileHeader>()

    private var dataDescriptors: ArrayList<DataDescriptor> = ArrayList<DataDescriptor>()

    private var archiveExtraDataRecord: ArchiveExtraDataRecord = ArchiveExtraDataRecord()

    private var centralDirectory: ?CentralDirectory = CentralDirectory()

    private var endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord = EndOfCentralDirectoryRecord()

    private var zip64EndOfCentralDirectoryLocator: ?Zip64EndOfCentralDirectoryLocator = Zip64EndOfCentralDirectoryLocator()

    private var zip64EndOfCentralDirectoryRecord: Zip64EndOfCentralDirectoryRecord = Zip64EndOfCentralDirectoryRecord()

    private var splitArchive: Bool = false

    private var splitLength: Int64

    private var zipFile: Path = unsafe { zeroValue<Path>() }
    private var hasZipFile: Bool = false

    private var isZip64FormatBool: Bool = false

    private var isNestedZipFileBool: Bool = false

    private var start: Int64 = 0

    private var end: Int64 = 0

    public init() {
        splitLength = -1
    }

    public func getLocalFileHeaders(): ArrayList<LocalFileHeader> {
        return localFileHeaders
    }

    public func setLocalFileHeaders(localFileHeaderList: ArrayList<LocalFileHeader>): Unit {
        this.localFileHeaders = localFileHeaderList
    }

    public func getDataDescriptors(): ArrayList<DataDescriptor> {
        return dataDescriptors
    }

    public func setDataDescriptors(dataDescriptors: ArrayList<DataDescriptor>): Unit {
        this.dataDescriptors = dataDescriptors
    }

    public func getCentralDirectory(): ?CentralDirectory {
        return centralDirectory
    }

    public func setCentralDirectory(centralDirectory: ?CentralDirectory): Unit {
        this.centralDirectory = centralDirectory
    }

    public func getEndOfCentralDirectoryRecord(): EndOfCentralDirectoryRecord {
        return endOfCentralDirectoryRecord
    }

    public func setEndOfCentralDirectoryRecord(endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord): Unit {
        this.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord
    }

    public func getArchiveExtraDataRecord(): ArchiveExtraDataRecord {
        return archiveExtraDataRecord
    }

    public func setArchiveExtraDataRecord(archiveExtraDataRecord: ArchiveExtraDataRecord): Unit {
        this.archiveExtraDataRecord = archiveExtraDataRecord
    }

    public func isSplitArchive(): Bool {
        return splitArchive
    }

    public func setSplitArchive(splitArchive: Bool): Unit {
        this.splitArchive = splitArchive
    }

    public func getZipFile(): Path {
        return if (hasZipFile) {
            zipFile
        } else {
            throw NoneValueException("zipFile is null")
        }
    }

    public func setZipFile(zipFile: Path): Unit {
        this.hasZipFile = true
        this.zipFile = zipFile
    }

    public func getZip64EndOfCentralDirectoryLocator(): ?Zip64EndOfCentralDirectoryLocator {
        return zip64EndOfCentralDirectoryLocator
    }

    public func setZip64EndOfCentralDirectoryLocator(
        zip64EndOfCentralDirectoryLocator: ?Zip64EndOfCentralDirectoryLocator): Unit {
        this.zip64EndOfCentralDirectoryLocator = zip64EndOfCentralDirectoryLocator
    }

    public func getZip64EndOfCentralDirectoryRecord(): Zip64EndOfCentralDirectoryRecord {
        return zip64EndOfCentralDirectoryRecord
    }

    public func setZip64EndOfCentralDirectoryRecord(zip64EndOfCentralDirectoryRecord: Zip64EndOfCentralDirectoryRecord): Unit {
        this.zip64EndOfCentralDirectoryRecord = zip64EndOfCentralDirectoryRecord
    }

    public func isZip64Format(): Bool {
        return isZip64FormatBool
    }

    public func setZip64Format(isZip64FormatBool: Bool): Unit {
        this.isZip64FormatBool = isZip64FormatBool
    }

    public func isNestedZipFile(): Bool {
        return isNestedZipFileBool
    }

    public func setNestedZipFile(isNestedZipFileBool: Bool): Unit {
        this.isNestedZipFileBool = isNestedZipFileBool
    }

    public func getStart(): Int64 {
        return start
    }

    public func setStart(start: Int64): Unit {
        this.start = start
    }

    public func getEnd(): Int64 {
        return end
    }

    public func setEnd(end: Int64): Unit {
        this.end = end
    }

    public func getSplitLength(): Int64 {
        return splitLength
    }

    public func setSplitLength(splitLength: Int64): Unit {
        this.splitLength = splitLength
    }

    public func clone(): ZipModel {
        var zipModel: ZipModel = ZipModel()
        zipModel.setLocalFileHeaders(this.getLocalFileHeaders())
        zipModel.setDataDescriptors(this.getDataDescriptors())
        zipModel.setCentralDirectory(this.getCentralDirectory())
        zipModel.setEndOfCentralDirectoryRecord(this.getEndOfCentralDirectoryRecord())
        zipModel.setArchiveExtraDataRecord(this.getArchiveExtraDataRecord())
        zipModel.setSplitArchive(this.isSplitArchive())
        if (this.hasZipFile) {
            zipModel.setZipFile(this.zipFile)
        }
        zipModel.setZip64EndOfCentralDirectoryLocator(this.getZip64EndOfCentralDirectoryLocator())
        zipModel.setZip64EndOfCentralDirectoryRecord(this.getZip64EndOfCentralDirectoryRecord())
        zipModel.setZip64Format(this.isZip64Format())
        zipModel.setNestedZipFile(this.isNestedZipFile())
        zipModel.setStart(this.getStart())
        zipModel.setEnd(this.getEnd())
        zipModel.setSplitLength(this.getSplitLength())
        return zipModel
    }
}
