/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public abstract class AbstractFileHeader <: ZipHeader & Equatable<AbstractFileHeader> {

    private var versionNeededToExtract: Int32 = 0

    private var generalPurposeFlag: ?Array<Byte> = None

    private var compressionMethod: ?CompressionMethod = None

    private var lastModifiedTime: Int64 = 0

    private var crc: Int64 = 0

    private var compressedSize: Int64 = 0

    private var uncompressedSize: Int64 = 0

    private var fileNameLength: Int64 = 0

    private var extraFieldLength: Int32 = 0

    private var fileName: ?String = None

    private var isEncryptedBool: Bool = false

    private var encryptionMethod: EncryptionMethod = EncryptionMethod.NONE

    private var dataDescriptorExists: Bool = false

    private var zip64ExtendedInfo: ?Zip64ExtendedInfo = None

    private var aesExtraDataRecord: ?AESExtraDataRecord = None

    private var fileNameUTF8Encoded: Bool = false

    private var extraDataRecords: ?ArrayList<ExtraDataRecord> = None

    private var isDirectoryBool: Bool = false

    public func getVersionNeededToExtract(): Int32 {
        return versionNeededToExtract
    }

    public func setVersionNeededToExtract(versionNeededToExtract: Int32): Unit {
        this.versionNeededToExtract = versionNeededToExtract
    }

    public func getGeneralPurposeFlag(): ?Array<Byte> {
        return generalPurposeFlag
    }

    public func setGeneralPurposeFlag(generalPurposeFlag: ?Array<Byte>): Unit {
        this.generalPurposeFlag = generalPurposeFlag
    }

    public func getCompressionMethod(): ?CompressionMethod {
        return compressionMethod
    }

    public func setCompressionMethod(compressionMethod: ?CompressionMethod): Unit {
        this.compressionMethod = compressionMethod
    }

    public func getLastModifiedTime(): Int64 {
        return lastModifiedTime
    }

    public func setLastModifiedTime(lastModifiedTime: Int64): Unit {
        this.lastModifiedTime = lastModifiedTime
    }

    public func getLastModifiedTimeEpoch(): Int64 {
        return lastModifiedTime
    }

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

    public func getFileNameLength(): Int64 {
        return fileNameLength
    }

    public func setFileNameLength(fileNameLength: Int64): Unit {
        this.fileNameLength = fileNameLength
    }

    public func getExtraFieldLength(): Int32 {
        return extraFieldLength
    }

    public func setExtraFieldLength(extraFieldLength: Int32): Unit {
        this.extraFieldLength = extraFieldLength
    }

    public func getFileName(): ?String {
        return fileName
    }

    public func setFileName(fileName: ?String): Unit {
        this.fileName = fileName
    }

    public func isEncrypted(): Bool {
        return isEncryptedBool
    }

    public func setEncrypted(encrypted: Bool): Unit {
        isEncryptedBool = encrypted
    }

    public func getEncryptionMethod(): EncryptionMethod {
        return encryptionMethod
    }

    public func setEncryptionMethod(encryptionMethod: EncryptionMethod): Unit {
        this.encryptionMethod = encryptionMethod
    }

    public func isDataDescriptorExists(): Bool {
        return dataDescriptorExists
    }

    public func setDataDescriptorExists(dataDescriptorExists: Bool): Unit {
        this.dataDescriptorExists = dataDescriptorExists
    }

    public func getZip64ExtendedInfo(): ?Zip64ExtendedInfo {
        return zip64ExtendedInfo
    }

    public func setZip64ExtendedInfo(zip64ExtendedInfo: Zip64ExtendedInfo): Unit {
        this.zip64ExtendedInfo = zip64ExtendedInfo
    }

    public func getAesExtraDataRecord(): ?AESExtraDataRecord {
        return aesExtraDataRecord
    }

    public func setAesExtraDataRecord(aesExtraDataRecord: ?AESExtraDataRecord): Unit {
        this.aesExtraDataRecord = aesExtraDataRecord
    }

    public func isFileNameUTF8Encoded(): Bool {
        return fileNameUTF8Encoded
    }

    public func setFileNameUTF8Encoded(fileNameUTF8Encoded: Bool): Unit {
        this.fileNameUTF8Encoded = fileNameUTF8Encoded
    }

    public func getExtraDataRecords(): ?ArrayList<ExtraDataRecord> {
        return extraDataRecords
    }

    public func setExtraDataRecords(extraDataRecords: ?ArrayList<ExtraDataRecord>): Unit {
        this.extraDataRecords = extraDataRecords
    }

    public func isDirectory(): Bool {
        return isDirectoryBool
    }

    public func setDirectory(directory: Bool): Unit {
        isDirectoryBool = directory
    }

    public func equals(obj: AbstractFileHeader): Bool {
        match ((this.getFileName(), obj.getFileName())) {
            case (Some(v), Some(m)) => return v == m
            case _ => return false
        }
    }

    public operator func ==(that: AbstractFileHeader): Bool {
        return equals(that)
    }

    public operator func !=(that: AbstractFileHeader): Bool {
        return !(this == that)
    }
}
