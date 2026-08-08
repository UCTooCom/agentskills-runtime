/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.headers

public class FileHeaderFactory {
    public func generateFileHeader(
        zipParameters: ZipParameters,
        isSplitZip: Bool,
        currentDiskNumberStart: Int64,
        rawIO: RawIO
    ): FileHeader {
        let fh = FileHeader()
        fh.setSignature(HeaderSignature.CENTRAL_DIRECTORY)
        fh.setVersionMadeBy(ZipVersionUtils.determineVersionMadeBy(zipParameters, rawIO))
        fh.setVersionNeededToExtract(ZipVersionUtils.determineVersionNeededToExtract(zipParameters).getCode())

        if (zipParameters.isEncryptFiles() && zipParameters.getEncryptionMethod() == EncryptionMethod.AES) {
            fh.setCompressionMethod(CompressionMethod.AES_INTERNAL_ONLY)
            fh.setAesExtraDataRecord(generateAESExtraDataRecord(zipParameters))
            fh.setExtraFieldLength(
                fh.getExtraFieldLength() + InternalZipConstants.AES_EXTRA_DATA_RECORD_SIZE)
        } else {
            fh.setCompressionMethod(zipParameters.getCompressionMethod())
        }

        if (zipParameters.isEncryptFiles()) {
            if (zipParameters.getEncryptionMethod() == EncryptionMethod.NONE) {
                throw ZipException("Encryption method has to be set when encryptFiles flag is set in zip parameters")
            }

            fh.setEncrypted(true)
            fh.setEncryptionMethod(zipParameters.getEncryptionMethod())
        }

        var fileName = validateAndGetFileName(zipParameters.getFileNameInZip())
        fh.setFileName(fileName)
        fh.setFileNameLength(determineFileNameLength(fileName))
        fh.setDiskNumberStart(if (isSplitZip) {
            currentDiskNumberStart
        } else {
            0
        })
        fh.setLastModifiedTime(Zip4cjUtil.epochToExtendedDosTime(zipParameters.getLastModifiedFileTime()))

        var isDirectory = FileUtils.isZipEntryDirectory(fileName)
        fh.setDirectory(isDirectory)
        fh.setExternalFileAttributes(FileUtils.getDefaultFileAttributes(isDirectory))

        if (zipParameters.isWriteExtendedLocalFileHeader() && zipParameters.getEntrySize() == -1) {
            fh.setUncompressedSize(0)
        } else {
            fh.setUncompressedSize(zipParameters.getEntrySize())
        }

        if (zipParameters.isEncryptFiles() && zipParameters.getEncryptionMethod() == EncryptionMethod.ZIP_STANDARD) {
            fh.setCrc(zipParameters.getEntryCRC())
        }

        fh.setGeneralPurposeFlag(determineGeneralPurposeBitFlag(fh.isEncrypted(), zipParameters))
        fh.setDataDescriptorExists(zipParameters.isWriteExtendedLocalFileHeader())
        fh.setFileComment(zipParameters.getFileComment())
        return fh
    }

    public func generateLocalFileHeader(fh: FileHeader): LocalFileHeader {
        let localFileHeader = LocalFileHeader()
        localFileHeader.setSignature(HeaderSignature.LOCAL_FILE_HEADER)
        localFileHeader.setVersionNeededToExtract(fh.getVersionNeededToExtract())
        localFileHeader.setCompressionMethod(fh.getCompressionMethod())
        localFileHeader.setLastModifiedTime(fh.getLastModifiedTime())
        localFileHeader.setUncompressedSize(fh.getUncompressedSize())
        localFileHeader.setFileNameLength(fh.getFileNameLength())
        localFileHeader.setFileName(fh.getFileName())
        localFileHeader.setEncrypted(fh.isEncrypted())
        localFileHeader.setEncryptionMethod(fh.getEncryptionMethod())
        localFileHeader.setAesExtraDataRecord(fh.getAesExtraDataRecord())
        localFileHeader.setCrc(fh.getCrc())
        localFileHeader.setCompressedSize(fh.getCompressedSize())
        localFileHeader.setGeneralPurposeFlag(fh.getGeneralPurposeFlag().getOrThrow({=> throw NoneValueException("FileHeader.getGeneralPurposeFlag() is null")}).clone())
        localFileHeader.setDataDescriptorExists(fh.isDataDescriptorExists())
        localFileHeader.setExtraFieldLength(fh.getExtraFieldLength())
        return localFileHeader
    }

    private func determineGeneralPurposeBitFlag(isEncrypted: Bool, zipParameters: ZipParameters): Array<Byte> {
        var generalPurposeBitFlag = Array<Byte>(2, repeat: 0)
        generalPurposeBitFlag[0] = generateFirstGeneralPurposeByte(isEncrypted, zipParameters)
        generalPurposeBitFlag[1] = BitUtils.setBit(generalPurposeBitFlag[1], 3)
        return generalPurposeBitFlag
    }

    private func generateFirstGeneralPurposeByte(isEncrypted: Bool, zipParameters: ZipParameters): Byte {
        var firstByte: Byte = 0

        if (isEncrypted) {
            firstByte = BitUtils.setBit(firstByte, 0)
        }

        if (CompressionMethod.DEFLATE == (zipParameters.getCompressionMethod())) {
            if (CompressionLevel.NORMAL == (zipParameters.getCompressionLevel())) {
                firstByte = BitUtils.unsetBit(firstByte, 1)
                firstByte = BitUtils.unsetBit(firstByte, 2)
            } else if (CompressionLevel.MAXIMUM == (zipParameters.getCompressionLevel())) {
                firstByte = BitUtils.setBit(firstByte, 1)
                firstByte = BitUtils.unsetBit(firstByte, 2)
            } else if (CompressionLevel.FAST == (zipParameters.getCompressionLevel())) {
                firstByte = BitUtils.unsetBit(firstByte, 1)
                firstByte = BitUtils.setBit(firstByte, 2)
            } else if (CompressionLevel.FASTEST == (zipParameters.getCompressionLevel()) || CompressionLevel.ULTRA == (zipParameters.
                getCompressionLevel())) {
                firstByte = BitUtils.setBit(firstByte, 1)
                firstByte = BitUtils.setBit(firstByte, 2)
            }
        }

        if (zipParameters.isWriteExtendedLocalFileHeader()) {
            firstByte = BitUtils.setBit(firstByte, 3)
        }

        return firstByte
    }

    private func validateAndGetFileName(fileNameInZip: ?String): String {
        if (!Zip4cjUtil.isStringNotNullAndNotEmpty(fileNameInZip)) {
            throw ZipException("fileNameInZip is null or empty")
        }
        return fileNameInZip.getOrThrow()
    }

    private func generateAESExtraDataRecord(parameters: ZipParameters): AESExtraDataRecord {
        var aesData = AESExtraDataRecord()

        aesData.setAesVersion(parameters.getAesVersion())

        if (parameters.getAesKeyStrength() == AesKeyStrength.KEY_STRENGTH_128) {
            aesData.setAesKeyStrength(AesKeyStrength.KEY_STRENGTH_128)
        } else if (parameters.getAesKeyStrength() == AesKeyStrength.KEY_STRENGTH_192) {
            aesData.setAesKeyStrength(AesKeyStrength.KEY_STRENGTH_192)
        } else if (parameters.getAesKeyStrength() == AesKeyStrength.KEY_STRENGTH_256) {
            aesData.setAesKeyStrength(AesKeyStrength.KEY_STRENGTH_256)
        } else {
            throw ZipException("invalid AES key strength")
        }

        aesData.setCompressionMethod(parameters.getCompressionMethod())
        return aesData
    }

    private func determineFileNameLength(fileName: String): Int64 {
        return HeaderUtil.getBytesFromString(fileName).size
    }
}
