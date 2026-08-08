/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

let emptyArrayList = ArrayList<ExtraDataRecord>()

public class HeaderReader {
    private var zipModel: ?ZipModel = None
    private let rawIO = RawIO()
    private let intBuff = Array<Byte>(4, repeat: 0)

    public func readAllHeaders(zip4cjRaf: RandomAccessFile, zip4cjConfig: Zip4cjConfig) {
        if (zip4cjRaf.length == 0) {
            return ZipModel()
        }

        if (zip4cjRaf.length < InternalZipConstants.ENDHDR) {
            throw ZipException(
                "Zip file size less than minimum expected zip file size. Probably not a zip file or a corrupted zip file"
            )
        }

        let myzipModel = ZipModel()
        this.zipModel = myzipModel
        try {
            myzipModel.setEndOfCentralDirectoryRecord(readEndOfCentralDirectoryRecord(zip4cjRaf, rawIO, zip4cjConfig))
        } catch (e: ZipException) {
            throw e
        } catch (e: Exception) {
            throw ZipException("Zip headers not found. Probably not a zip file or a corrupted zip file")
        }
        if (myzipModel.getEndOfCentralDirectoryRecord().getTotalNumberOfEntriesInCentralDirectory() == 0) {
            return myzipModel
        }
        // If file is Zip64 format, Zip64 headers have to be read before reading central directory
        myzipModel.setZip64EndOfCentralDirectoryLocator(
            readZip64EndOfCentralDirectoryLocator(zip4cjRaf, rawIO,
            myzipModel.getEndOfCentralDirectoryRecord().getOffsetOfEndOfCentralDirectory()))

        if (myzipModel.isZip64Format()) {
            myzipModel.setZip64EndOfCentralDirectoryRecord(readZip64EndCentralDirRec(zip4cjRaf, rawIO))
            if (myzipModel.getZip64EndOfCentralDirectoryRecord().getNumberOfThisDisk() > 0) {
                myzipModel.setSplitArchive(true)
            } else {
                myzipModel.setSplitArchive(false)
            }
        }
        myzipModel.setCentralDirectory(readCentralDirectory(zip4cjRaf, rawIO))

        return zipModel.getOrThrow()
    }

    private func readEndOfCentralDirectoryRecord(
        zip4cjRaf: RandomAccessFile,
        rawIO: RawIO,
        zip4cjConfig: Zip4cjConfig
    ): EndOfCentralDirectoryRecord {
        var offsetEndOfCentralDirectory = locateOffsetOfEndOfCentralDirectory(zip4cjRaf)
        seekInCurrentPart(zip4cjRaf, offsetEndOfCentralDirectory + 4)

        var endOfCentralDirectoryRecord = EndOfCentralDirectoryRecord()
        endOfCentralDirectoryRecord.setSignature(HeaderSignature.END_OF_CENTRAL_DIRECTORY)
        endOfCentralDirectoryRecord.setNumberOfThisDisk(rawIO.readShortLittleEndian(zip4cjRaf))
        endOfCentralDirectoryRecord.setNumberOfThisDiskStartOfCentralDir(rawIO.readShortLittleEndian(zip4cjRaf))
        endOfCentralDirectoryRecord.setTotalNumberOfEntriesInCentralDirectoryOnThisDisk(
            rawIO.readShortLittleEndian(zip4cjRaf))
        endOfCentralDirectoryRecord.setTotalNumberOfEntriesInCentralDirectory(
            Int64(rawIO.readShortLittleEndian(zip4cjRaf)))
        endOfCentralDirectoryRecord.setSizeOfCentralDirectory(rawIO.readIntLittleEndian(zip4cjRaf))
        endOfCentralDirectoryRecord.setOffsetOfEndOfCentralDirectory(offsetEndOfCentralDirectory)

        zip4cjRaf.readFully(intBuff)
        endOfCentralDirectoryRecord.setOffsetOfStartOfCentralDirectory(rawIO.readLongLittleEndian(intBuff, 0))

        var commentLength = Int64(rawIO.readShortLittleEndian(zip4cjRaf))
        endOfCentralDirectoryRecord.setComment(readZipComment(zip4cjRaf, commentLength))

        zipModel.getOrThrow().setSplitArchive(endOfCentralDirectoryRecord.getNumberOfThisDisk() > 0)
        return endOfCentralDirectoryRecord
    }

    private func readCentralDirectory(zip4cjRaf: RandomAccessFile, rawIO: RawIO): CentralDirectory {
        var centralDirectory = CentralDirectory()
        var fileHeaders = ArrayList<FileHeader>()

        var offSetStartCentralDir = HeaderUtil.getOffsetStartOfCentralDirectory(zipModel.getOrThrow())
        var centralDirEntryCount = getNumberOfEntriesInCentralDirectory(zipModel.getOrThrow())
        zip4cjRaf.seek(offSetStartCentralDir)

        var shortBuff = Array<Byte>(2, repeat: 0)
        var intBuff = Array<Byte>(4, repeat: 0)

        for (i in 0..centralDirEntryCount) {
            var fileHeader = FileHeader()
            if (Int64(rawIO.readIntLittleEndian(zip4cjRaf)) != HeaderSignature.CENTRAL_DIRECTORY.getValue()) {
                throw ZipException("Expected central directory entry not found (#${i+1})")
            }
            fileHeader.setSignature(HeaderSignature.CENTRAL_DIRECTORY)
            fileHeader.setVersionMadeBy(rawIO.readShortLittleEndian(zip4cjRaf))
            fileHeader.setVersionNeededToExtract(rawIO.readShortLittleEndian(zip4cjRaf))

            var generalPurposeFlags = Array<Byte>(2, repeat: 0)
            zip4cjRaf.readFully(generalPurposeFlags)
            fileHeader.setEncrypted(BitUtils.isBitSet(generalPurposeFlags[0], 0))
            fileHeader.setDataDescriptorExists(BitUtils.isBitSet(generalPurposeFlags[0], 3))
            fileHeader.setFileNameUTF8Encoded(BitUtils.isBitSet(generalPurposeFlags[1], 3))
            fileHeader.setGeneralPurposeFlag(generalPurposeFlags.clone())

            fileHeader.setCompressionMethod(
                CompressionMethod.getCompressionMethodFromCode(rawIO.readShortLittleEndian(zip4cjRaf)))
            fileHeader.setLastModifiedTime(Int64(rawIO.readIntLittleEndian(zip4cjRaf)))

            zip4cjRaf.readFully(intBuff)
            fileHeader.setCrc(rawIO.readLongLittleEndian(intBuff, 0))

            fileHeader.setCompressedSize(rawIO.readLongLittleEndian(zip4cjRaf, 4))
            fileHeader.setUncompressedSize(rawIO.readLongLittleEndian(zip4cjRaf, 4))

            var fileNameLength = Int64(rawIO.readShortLittleEndian(zip4cjRaf))
            fileHeader.setFileNameLength(fileNameLength)
            fileHeader.setExtraFieldLength(rawIO.readShortLittleEndian(zip4cjRaf))
            var fileCommentLength = rawIO.readShortLittleEndian(zip4cjRaf)
            fileHeader.setFileCommentLength(fileCommentLength)

            fileHeader.setDiskNumberStart(Int64(rawIO.readShortLittleEndian(zip4cjRaf)))

            zip4cjRaf.readFully(shortBuff)
            fileHeader.setInternalFileAttributes(shortBuff.clone())

            zip4cjRaf.readFully(intBuff)
            fileHeader.setExternalFileAttributes(intBuff.clone())

            zip4cjRaf.readFully(intBuff)
            fileHeader.setOffsetLocalHeader(rawIO.readLongLittleEndian(intBuff, 0))

            if (fileNameLength > 0) {
                var fileNameBuff = Array<Byte>(fileNameLength, repeat: 0)
                zip4cjRaf.readFully(fileNameBuff)
                var fileName = HeaderUtil.decodeStringWithCharset(fileNameBuff, fileHeader.isFileNameUTF8Encoded())
                fileHeader.setFileName(fileName)
            } else {
                throw ZipException("Invalid entry name in file header")
            }
            fileHeader.setDirectory(
                isDirectory(fileHeader.getExternalFileAttributes().getOrThrow(), fileHeader.getFileName()))
            readExtraDataRecords(zip4cjRaf, fileHeader)
            readZip64ExtendedInfo(fileHeader, rawIO)
            readAesExtraDataRecord(fileHeader, rawIO)
            if (fileCommentLength > 0) {
                let fileCommentBuff = Array<Byte>(Int64(fileCommentLength), repeat: 0)
                zip4cjRaf.readFully(fileCommentBuff)
                fileHeader.setFileComment(
                    HeaderUtil.decodeStringWithCharset(fileCommentBuff, fileHeader.isFileNameUTF8Encoded()))
            }
            if (fileHeader.isEncrypted()) {
                if (let Some(_) <- fileHeader.getAesExtraDataRecord()) {
                    fileHeader.setEncryptionMethod(EncryptionMethod.ZIP_STANDARD)
                } else {
                    fileHeader.setEncryptionMethod(EncryptionMethod.AES)
                }
            }
            fileHeaders.add(fileHeader)
        }

        centralDirectory.setFileHeaders(fileHeaders)

        var digitalSignature = DigitalSignature()
        if (Int64(rawIO.readIntLittleEndian(zip4cjRaf)) == HeaderSignature.DIGITAL_SIGNATURE.getValue()) {
            digitalSignature.setSignature(HeaderSignature.DIGITAL_SIGNATURE)
            digitalSignature.setSizeOfData(rawIO.readShortLittleEndian(zip4cjRaf))

            if (digitalSignature.getSizeOfData() > 0) {
                var signatureDataBuff = Array<Byte>(Int64(digitalSignature.getSizeOfData()), repeat: 0)
                zip4cjRaf.readFully(signatureDataBuff)
                digitalSignature.setSignatureData(String.fromUtf8(signatureDataBuff))
            }
        }

        return centralDirectory
    }

    private func readExtraDataRecords(zip4cjRaf: RandomAccessFile, fileHeader: FileHeader) {
        var extraFieldLength: Int64 = Int64(fileHeader.getExtraFieldLength())

        if (extraFieldLength <= 0) {
            return
        }
        fileHeader.setExtraDataRecords(readExtraDataRecords(zip4cjRaf, extraFieldLength))
    }

    private func readExtraDataRecords(inputStream: InputStream, localFileHeader: LocalFileHeader) {
        var extraFieldLength: Int64 = Int64(localFileHeader.getExtraFieldLength())
        if (extraFieldLength <= 0) {
            return
        }
        localFileHeader.setExtraDataRecords(readExtraDataRecords(inputStream, extraFieldLength))
    }

    private func readExtraDataRecords(zip4cjRaf: RandomAccessFile, extraFieldLength: Int64): ?ArrayList<ExtraDataRecord> {
        var extraFieldBuf = Array<Byte>(1, repeat: 0)
        if (extraFieldLength < 4) {
            if (extraFieldLength > 0) {
                // zip4cjRaf.skipBytes(extraFieldLength)

                for (_ in 0..extraFieldLength) {
                    zip4cjRaf.read(extraFieldBuf)
                }
            }

            return None
        }

        extraFieldBuf = Array<Byte>(extraFieldLength, repeat: 0)
        zip4cjRaf.read(extraFieldBuf)

        try {
            return parseExtraDataRecords(extraFieldBuf, extraFieldLength)
        } catch (e: Exception) {
            // Ignore any errors when parsing extra data records
            return emptyArrayList
        }
    }

    private func readExtraDataRecords(inputStream: InputStream, extraFieldLength: Int64): ?ArrayList<ExtraDataRecord> {
        var extraFieldBuf = Array<Byte>(1, repeat: 0)
        if (extraFieldLength < 4) {
            if (extraFieldLength > 0) {
                for (_ in 0..extraFieldLength) {
                    inputStream.read(extraFieldBuf)
                }
            }

            return None
        }

        extraFieldBuf = Array<Byte>(extraFieldLength, repeat: 0)
        Zip4cjUtil.readFully(inputStream, extraFieldBuf)

        try {
            return parseExtraDataRecords(extraFieldBuf, extraFieldLength)
        } catch (e: Exception) {
            // Ignore any errors when parsing extra data records
            return emptyArrayList
        }
    }

    private func parseExtraDataRecords(extraFieldBuf: Array<Byte>, extraFieldLength: Int64): ArrayList<ExtraDataRecord> {
        var counter = 0
        var extraDataRecords = ArrayList<ExtraDataRecord>()
        while (counter < extraFieldLength) {
            var extraDataRecord = ExtraDataRecord()
            var header = rawIO.readShortLittleEndian(extraFieldBuf, counter)
            extraDataRecord.setHeader(Int64(header))
            counter += 2

            var sizeOfRec = rawIO.readShortLittleEndian(extraFieldBuf, counter)
            extraDataRecord.setSizeOfData(Int64(sizeOfRec))
            counter += 2

            if (sizeOfRec > 0) {
                var data = Array<Byte>(Int64(sizeOfRec), repeat: 0)
                ArrayCopy(extraFieldBuf, counter, data, 0, Int64(sizeOfRec))
                extraDataRecord.setData(data)
            }
            counter += Int64(sizeOfRec)
            extraDataRecords.add(extraDataRecord)
        }
        return if (extraDataRecords.size > 0) {
            extraDataRecords
        } else {
            emptyArrayList
        }
    }

    private func readZip64EndOfCentralDirectoryLocator(
        zip4cjRaf: RandomAccessFile,
        rawIO: RawIO,
        offsetEndOfCentralDirectoryRecord: Int64
    ): ?Zip64EndOfCentralDirectoryLocator {
        let zip64EndOfCentralDirectoryLocator = Zip64EndOfCentralDirectoryLocator()
        setFilePointerToReadZip64EndCentralDirLoc(zip4cjRaf, offsetEndOfCentralDirectoryRecord)

        var signature = rawIO.readIntLittleEndian(zip4cjRaf)
        if (signature == Int32(HeaderSignature.ZIP64_END_CENTRAL_DIRECTORY_LOCATOR.getValue())) {
            zipModel.getOrThrow().setZip64Format(true)
            zip64EndOfCentralDirectoryLocator.setSignature(HeaderSignature.ZIP64_END_CENTRAL_DIRECTORY_LOCATOR)
        } else {
            zipModel.getOrThrow().setZip64Format(false)
            return None
        }

        zip64EndOfCentralDirectoryLocator.setNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord(
            rawIO.readIntLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryLocator.setOffsetZip64EndOfCentralDirectoryRecord(
            rawIO.readLongLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryLocator.setTotalNumberOfDiscs(rawIO.readIntLittleEndian(zip4cjRaf))

        return zip64EndOfCentralDirectoryLocator
    }

    private func readZip64EndCentralDirRec(zip4cjRaf: RandomAccessFile, rawIO: RawIO): Zip64EndOfCentralDirectoryRecord {
        let offSetStartOfZip64CentralDir = zipModel.getOrThrow().getZip64EndOfCentralDirectoryLocator().getOrThrow().
            getOffsetZip64EndOfCentralDirectoryRecord()

        if (offSetStartOfZip64CentralDir < 0) {
            throw ZipException("invalid offset for start of end of central directory record")
        }

        zip4cjRaf.seek(offSetStartOfZip64CentralDir)

        var zip64EndOfCentralDirectoryRecord = Zip64EndOfCentralDirectoryRecord()

        var signature: Int32 = rawIO.readIntLittleEndian(zip4cjRaf)
        if (Int64(signature) != HeaderSignature.ZIP64_END_CENTRAL_DIRECTORY_RECORD.getValue()) {
            throw ZipException("invalid signature for zip64 end of central directory record")
        }
        zip64EndOfCentralDirectoryRecord.setSignature(HeaderSignature.ZIP64_END_CENTRAL_DIRECTORY_RECORD)
        zip64EndOfCentralDirectoryRecord.setSizeOfZip64EndCentralDirectoryRecord(rawIO.readLongLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setVersionMadeBy(rawIO.readShortLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setVersionNeededToExtract(rawIO.readShortLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setNumberOfThisDisk(rawIO.readIntLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setNumberOfThisDiskStartOfCentralDirectory(
            rawIO.readIntLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setTotalNumberOfEntriesInCentralDirectoryOnThisDisk(
            rawIO.readLongLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setTotalNumberOfEntriesInCentralDirectory(
            rawIO.readLongLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setSizeOfCentralDirectory(rawIO.readLongLittleEndian(zip4cjRaf))
        zip64EndOfCentralDirectoryRecord.setOffsetStartCentralDirectoryWRTStartDiskNumber(
            rawIO.readLongLittleEndian(zip4cjRaf))

        //zip64 extensible data sector
        //44 is the size of fixed variables in this record
        let extDataSecSize = zip64EndOfCentralDirectoryRecord.getSizeOfZip64EndCentralDirectoryRecord() - 44
        if (extDataSecSize > 0) {
            let extDataSecRecBuf = Array<Byte>(extDataSecSize, repeat: 0)
            zip4cjRaf.readFully(extDataSecRecBuf)
            zip64EndOfCentralDirectoryRecord.setExtensibleDataSector(extDataSecRecBuf)
        }

        return zip64EndOfCentralDirectoryRecord
    }

    private func readZip64ExtendedInfo(fileHeader: FileHeader, rawIO: RawIO) {
        if (fileHeader.getExtraDataRecords().isNone() || fileHeader.getExtraDataRecords().getOrThrow().size <= 0) {
            return
        }
        if (let Some(zip64ExtendedInfo) <- readZip64ExtendedInfo(fileHeader.getExtraDataRecords().getOrThrow(), rawIO,
            fileHeader.getUncompressedSize(), fileHeader.getCompressedSize(), fileHeader.getOffsetLocalHeader(),
            fileHeader.getDiskNumberStart())) {
            fileHeader.setZip64ExtendedInfo(zip64ExtendedInfo)
            if (-1 != zip64ExtendedInfo.getUncompressedSize()) {
                fileHeader.setUncompressedSize(zip64ExtendedInfo.getUncompressedSize())
            }

            if (-1 != zip64ExtendedInfo.getCompressedSize()) {
                fileHeader.setCompressedSize(zip64ExtendedInfo.getCompressedSize())
            }

            if (-1 != zip64ExtendedInfo.getOffsetLocalHeader()) {
                fileHeader.setOffsetLocalHeader(zip64ExtendedInfo.getOffsetLocalHeader())
            }
            if (-1 != zip64ExtendedInfo.getDiskNumberStart()) {
                fileHeader.setDiskNumberStart(Int64(zip64ExtendedInfo.getDiskNumberStart()))
            }
        } else {
            return
        }
    }

    private func readZip64ExtendedInfo(localFileHeaderOpt: ?LocalFileHeader, rawIO: RawIO): Unit {
        if (localFileHeaderOpt.isNone()) {
            throw ZipException("file header is null in reading Zip64 Extended Info")
        }
        let localFileHeader = localFileHeaderOpt.getOrThrow()
        if (localFileHeader.getExtraDataRecords().isNone() || localFileHeader.getExtraDataRecords().getOrThrow().size <=
            0) {
            return
        }

        var zip64ExtendedInfo = readZip64ExtendedInfo(localFileHeader.getExtraDataRecords().getOrThrow(), rawIO,
            localFileHeader.getUncompressedSize(), localFileHeader.getCompressedSize(), 0, 0)

        if (zip64ExtendedInfo.isNone()) {
            return
        }

        localFileHeader.setZip64ExtendedInfo(zip64ExtendedInfo.getOrThrow())

        if (zip64ExtendedInfo.getOrThrow().getUncompressedSize() != -1) {
            localFileHeader.setUncompressedSize(zip64ExtendedInfo.getOrThrow().getUncompressedSize())
        }

        if (zip64ExtendedInfo.getOrThrow().getCompressedSize() != -1) {
            localFileHeader.setCompressedSize(zip64ExtendedInfo.getOrThrow().getCompressedSize())
        }
    }

    private func readZip64ExtendedInfo(
        extraDataRecords: ArrayList<ExtraDataRecord>,
        rawIO: RawIO,
        uncompressedSize: Int64,
        compressedSize: Int64,
        offsetLocalHeader: Int64,
        diskNumberStart: Int64
    ): ?Zip64ExtendedInfo {
        for (i in 0..extraDataRecords.size) {
            let extraDataRecord = extraDataRecords[i]
            if (HeaderSignature.ZIP64_EXTRA_FIELD_SIGNATURE.getValue() == extraDataRecord.getHeader()) {
                var zip64ExtendedInfo = Zip64ExtendedInfo()
                var extraData = extraDataRecord.getData().getOrThrow()

                if (extraDataRecord.getSizeOfData() <= 0) {
                    return None
                }

                var counter = 0
                if (counter < extraDataRecord.getSizeOfData() && uncompressedSize == InternalZipConstants.
                    ZIP_64_SIZE_LIMIT) {
                    zip64ExtendedInfo.setUncompressedSize(rawIO.readLongLittleEndian(extraData, counter))
                    counter += 8
                }

                if (counter < extraDataRecord.getSizeOfData() && compressedSize == InternalZipConstants.
                    ZIP_64_SIZE_LIMIT) {
                    zip64ExtendedInfo.setCompressedSize(rawIO.readLongLittleEndian(extraData, counter))
                    counter += 8
                }

                if (counter < extraDataRecord.getSizeOfData() && offsetLocalHeader == InternalZipConstants.
                    ZIP_64_SIZE_LIMIT) {
                    zip64ExtendedInfo.setOffsetLocalHeader(rawIO.readLongLittleEndian(extraData, counter))
                    counter += 8
                }

                if (counter < extraDataRecord.getSizeOfData() && diskNumberStart == InternalZipConstants.
                    ZIP_64_NUMBER_OF_ENTRIES_LIMIT) {
                    zip64ExtendedInfo.setDiskNumberStart(rawIO.readIntLittleEndian(extraData, counter))
                }

                return zip64ExtendedInfo
            }
        }
        return None
    }

    private func setFilePointerToReadZip64EndCentralDirLoc(
        zip4cjRaf: RandomAccessFile,
        offsetEndOfCentralDirectoryRecord: Int64
    ): Unit {
        /* Now the file pointer is at the end of signature of Central Dir Rec
        Seek back with the following values
        4 -> total number of disks
        8 -> relative offset of the zip64 end of central directory record
        4 -> number of the disk with the start of the zip64 end of central directory
        4 -> zip64 end of central dir locator signature
        Refer to Appnote for more information */
        seekInCurrentPart(zip4cjRaf, offsetEndOfCentralDirectoryRecord - 4 - 8 - 4 - 4)
    }

    public func readLocalFileHeader(inputStream: InputStream): ?LocalFileHeader {
        var localFileHeader = LocalFileHeader()
        let intBuff = Array<Byte>(4, repeat: 0)

        //signature
        var sig = rawIO.readIntLittleEndian(inputStream)
        if (sig == Int32(HeaderSignature.TEMPORARY_SPANNING_MARKER.getValue())) {
            sig = rawIO.readIntLittleEndian(inputStream)
        }
        if (sig != Int32(HeaderSignature.LOCAL_FILE_HEADER.getValue())) {
            return None
        }
        localFileHeader.setSignature(HeaderSignature.LOCAL_FILE_HEADER)
        localFileHeader.setVersionNeededToExtract(rawIO.readShortLittleEndian(inputStream))

        let generalPurposeFlags = Array<Byte>(2, repeat: 0)
        if (Zip4cjUtil.readFully(inputStream, generalPurposeFlags) != 2) {
            throw ZipException("Could not read enough bytes for generalPurposeFlags")
        }
        localFileHeader.setEncrypted(BitUtils.isBitSet(generalPurposeFlags[0], 0))
        localFileHeader.setDataDescriptorExists(BitUtils.isBitSet(generalPurposeFlags[0], 3))
        localFileHeader.setFileNameUTF8Encoded(BitUtils.isBitSet(generalPurposeFlags[1], 3))
        localFileHeader.setGeneralPurposeFlag(generalPurposeFlags.clone())

        localFileHeader.setCompressionMethod(
            CompressionMethod.getCompressionMethodFromCode(rawIO.readShortLittleEndian(inputStream)))
        localFileHeader.setLastModifiedTime(Int64(rawIO.readIntLittleEndian(inputStream)))

        Zip4cjUtil.readFully(inputStream, intBuff)
        localFileHeader.setCrc(rawIO.readLongLittleEndian(intBuff, 0))

        localFileHeader.setCompressedSize(rawIO.readLongLittleEndian(inputStream, 4))
        localFileHeader.setUncompressedSize(rawIO.readLongLittleEndian(inputStream, 4))

        var fileNameLength = rawIO.readShortLittleEndian(inputStream)
        localFileHeader.setFileNameLength(Int64(fileNameLength))
        localFileHeader.setExtraFieldLength(rawIO.readShortLittleEndian(inputStream))

        if (fileNameLength > 0) {
            let fileNameBuf = Array<Byte>(Int64(fileNameLength), repeat: 0)
            Zip4cjUtil.readFully(inputStream, fileNameBuf)

            var fileName = HeaderUtil.decodeStringWithCharset(fileNameBuf, localFileHeader.isFileNameUTF8Encoded())
            localFileHeader.setFileName(fileName)
            localFileHeader.setDirectory(fileName.endsWith("/") || fileName.endsWith("\\"))
        } else {
            throw ZipException("Invalid entry name in local file header")
        }
        this.readExtraDataRecords(inputStream, localFileHeader)
        this.readZip64ExtendedInfo(localFileHeader, rawIO)
        this.readAesExtraDataRecord(localFileHeader, rawIO)

        if (localFileHeader.isEncrypted()) {
            if (EncryptionMethod.AES == localFileHeader.getEncryptionMethod()) {
                //Do nothing
            } else {
                if (BitUtils.isBitSet(localFileHeader.getGeneralPurposeFlag().getOrThrow()[0], 6)) {
                    localFileHeader.setEncryptionMethod(EncryptionMethod.ZIP_STANDARD_VARIANT_STRONG)
                } else {
                    localFileHeader.setEncryptionMethod(EncryptionMethod.ZIP_STANDARD)
                }
            }
        }

        return localFileHeader
    }

    public func readDataDescriptor(inputStream: InputStream, isZip64Format: Bool): DataDescriptor {

        let dataDescriptors = DataDescriptor()
        let intBuff = Array<Byte>(4, repeat:0)
        Zip4cjUtil.readFully(inputStream, intBuff)
        var sigOrCrc = rawIO.readLongLittleEndian(intBuff, 0)
        //According to zip specification, presence of extra data record header signature is optional.
        //If this signature is present, read it and read the next 4 bytes for crc
        //If signature not present, assign the read 4 bytes for crc
        if (sigOrCrc == HeaderSignature.EXTRA_DATA_RECORD.getValue()) {
            dataDescriptors.setSignature(HeaderSignature.EXTRA_DATA_RECORD)
            Zip4cjUtil.readFully(inputStream, intBuff)
            dataDescriptors.setCrc(rawIO.readLongLittleEndian(intBuff, 0))
        } else {
            dataDescriptors.setCrc(sigOrCrc)
        }
        if (isZip64Format) {
            dataDescriptors.setCompressedSize(rawIO.readLongLittleEndian(inputStream))
            dataDescriptors.setUncompressedSize(rawIO.readLongLittleEndian(inputStream))
        } else {
            dataDescriptors.setCompressedSize(Int64(rawIO.readIntLittleEndian(inputStream)))
            dataDescriptors.setUncompressedSize(Int64(rawIO.readIntLittleEndian(inputStream)))
        }
        return dataDescriptors
    }

    private func readAesExtraDataRecord(fileHeader: AbstractFileHeader, rawIO: RawIO) {
        if (let Some(fileHead) <- fileHeader.getExtraDataRecords()) {
            if (fileHead.size <= 0) {
                return
            }

            let aesExtraDataRecord: ?AESExtraDataRecord = readAesExtraDataRecord(fileHead, rawIO)
            if (let Some(v) <- aesExtraDataRecord) {
                fileHeader.setAesExtraDataRecord(v)
                fileHeader.setEncryptionMethod(EncryptionMethod.AES)
            }
        } else {
            return
        }
    }

    private func readAesExtraDataRecord(extraDataRecords: ArrayList<ExtraDataRecord>, rawIO: RawIO): ?AESExtraDataRecord {
        
        for (i in 0..extraDataRecords.size) {
            let extraDataRecord = extraDataRecords[i]
            if (extraDataRecord.getHeader() == HeaderSignature.AES_EXTRA_DATA_RECORD.getValue()) {
                var aesExtraDataRecordBytes = extraDataRecord.getData()
                if (aesExtraDataRecordBytes == None || aesExtraDataRecordBytes.getOrThrow().size != 7) {
                    throw ZipException("corrupt AES extra data records")
                }
                let aesExtraDataRecord = AESExtraDataRecord()
                aesExtraDataRecord.setSignature(HeaderSignature.AES_EXTRA_DATA_RECORD)
                aesExtraDataRecord.setDataSize(extraDataRecord.getSizeOfData())

                var aesData = extraDataRecord.getData().getOrThrow()
                aesExtraDataRecord.setAesVersion(
                    AesVersion.getFromVersionNumber(rawIO.readShortLittleEndian(aesData, 0)))
                var vendorIDBytes = Array<Byte>(2, repeat: 0)
                ArrayCopy(aesData, 2, vendorIDBytes, 0, 2)
                aesExtraDataRecord.setVendorID(String.fromUtf8(vendorIDBytes))
                aesExtraDataRecord.setAesKeyStrength(
                    AesKeyStrength.getAesKeyStrengthFromRawCode(Int32(aesData[4] & 0xFF)).getOrThrow())
                aesExtraDataRecord.setCompressionMethod(
                    CompressionMethod.getCompressionMethodFromCode(rawIO.readShortLittleEndian(aesData, 5)))
                return aesExtraDataRecord
            }
        }

        return None
    }

    private func getNumberOfEntriesInCentralDirectory(zipModel: ZipModel): Int64 {
        if (zipModel.isZip64Format()) {
            return zipModel.getZip64EndOfCentralDirectoryRecord().getTotalNumberOfEntriesInCentralDirectory()
        }
        return zipModel.getEndOfCentralDirectoryRecord().getTotalNumberOfEntriesInCentralDirectory()
    }

    private func locateOffsetOfEndOfCentralDirectory(randomAccessFile: RandomAccessFile): Int64 {
        var zipFileSize = randomAccessFile.length
        if (zipFileSize < InternalZipConstants.ENDHDR) {
            throw ZipException("Zip file size less than size of zip headers. Probably not a zip file.")
        }

        seekInCurrentPart(randomAccessFile, zipFileSize - InternalZipConstants.ENDHDR)
        if (Int64(rawIO.readIntLittleEndian(randomAccessFile)) == HeaderSignature.END_OF_CENTRAL_DIRECTORY.getValue()) {
            return zipFileSize - InternalZipConstants.ENDHDR
        }

        return locateOffsetOfEndOfCentralDirectoryByReverseSeek(randomAccessFile)
    }

    private func locateOffsetOfEndOfCentralDirectoryByReverseSeek(randomAccessFile: RandomAccessFile): Int64 {
        var currentFilePointer = randomAccessFile.length - InternalZipConstants.ENDHDR
        // reverse seek for a maximum of MAX_COMMENT_SIZE bytes
        var numberOfBytesToRead = if (randomAccessFile.length < InternalZipConstants.MAX_COMMENT_SIZE) {
            randomAccessFile.length
        } else {
            InternalZipConstants.MAX_COMMENT_SIZE
        }
        while (numberOfBytesToRead > 0 && currentFilePointer > 0) {
            currentFilePointer--
            seekInCurrentPart(randomAccessFile, currentFilePointer)
            if (Int64(rawIO.readIntLittleEndian(randomAccessFile)) == HeaderSignature.END_OF_CENTRAL_DIRECTORY.getValue()) {
                return currentFilePointer
            }
            numberOfBytesToRead--
        }
        throw ZipException("Zip headers not found. Probably not a zip file")
    }

    private func seekInCurrentPart(randomAccessFile: RandomAccessFile, pos: Int64): Unit {
        if (randomAccessFile is NumberedSplitRandomAccessFile) {
            (randomAccessFile as NumberedSplitRandomAccessFile).getOrThrow().seekInCurrentPart(pos)
        } else {
            randomAccessFile.seek(pos)
        }
    }

    private func readZipComment(raf: RandomAccessFile, commentLength: Int64): ?String {
        if (commentLength <= 0) {
            return None
        }

        try {
            let commentBuf = Array<Byte>(commentLength, repeat: 0)
            raf.readFully(commentBuf)
            return HeaderUtil.decodeStringWithCharset(commentBuf, false)
        } catch (e: Exception) {
            // Ignore any exception and set comment to null if comment cannot be read
            return None
        }
    }

    public func isDirectory(externalFileAttributes: Array<Byte>, fileName: ?String): Bool {
        // first check if DOS attributes are set (lower order bytes from external attributes). If yes, check if the 4th bit
        // which represents a directory is set. If UNIX attributes are set (higher order two bytes), check for the 6th bit
        // in 4th byte which  represents a directory flag.
        if (externalFileAttributes.size <= 0 ) {
            throw IndexOutOfBoundsException("Index 0 out of bounds for length 0")
        }
        if (externalFileAttributes[0] != 0 && BitUtils.isBitSet(externalFileAttributes[0], 4)) {
            return true
        } else if (externalFileAttributes[3] != 0 && BitUtils.isBitSet(externalFileAttributes[3], 6)) {
            return true
        }

        return fileName != None && (fileName.getOrThrow().endsWith("/") || fileName.getOrThrow().endsWith("\\"))
    }
}
