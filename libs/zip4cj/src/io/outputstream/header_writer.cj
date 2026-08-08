/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

public class HeaderWriter {
    private static let ZIP64_EXTRA_DATA_RECORD_SIZE_LFH: Int32 = 16
    private static let ZIP64_EXTRA_DATA_RECORD_SIZE_FH: Int32 = 28
    private static let AES_EXTRA_DATA_RECORD_SIZE: Int32 = 11

    private let rawIO = RawIO()
    private let longBuff = Array<Byte>(8, repeat: 0)
    private let intBuff = Array<Byte>(4, repeat: 0)

    public func writeLocalFileHeader(
        zipModel: ZipModel,
        localFileHeader: LocalFileHeader,
        outputStream: OutputStream
    ) {
        let byteArrayOutputStream = ByteBuffer()
        rawIO.writeIntLittleEndian(byteArrayOutputStream, Int32(localFileHeader.getSignature().getOrThrow().getValue()))
        rawIO.writeShortLittleEndian(byteArrayOutputStream, localFileHeader.getVersionNeededToExtract())
        if (let Some(v) <- localFileHeader.getGeneralPurposeFlag()) {
            byteArrayOutputStream.write(v)
        } else {
            throw NoneValueException("cannot read the array length because array is None")
        }
        rawIO.writeShortLittleEndian(
            byteArrayOutputStream,
            localFileHeader.getCompressionMethod().getOrThrow().getCode()
        )
        rawIO.writeLongLittleEndian(longBuff, 0, localFileHeader.getLastModifiedTime())
        byteArrayOutputStream.write(longBuff[0..4])

        rawIO.writeLongLittleEndian(longBuff, 0, localFileHeader.getCrc())
        byteArrayOutputStream.write(longBuff[0..4])

        var writeZip64Header = localFileHeader.getCompressedSize() >= InternalZipConstants.ZIP_64_SIZE_LIMIT ||
            localFileHeader.getUncompressedSize() >= InternalZipConstants.ZIP_64_SIZE_LIMIT

        if (writeZip64Header) {
            rawIO.writeLongLittleEndian(longBuff, 0, InternalZipConstants.ZIP_64_SIZE_LIMIT)

            //Set the uncompressed size to ZipConstants.InternalZipConstants.ZIP_64_SIZE_LIMIT as
            //these values will be stored in Zip64 extra record
            byteArrayOutputStream.write(longBuff[0..4])
            byteArrayOutputStream.write(longBuff[0..4])

            zipModel.setZip64Format(true)
            localFileHeader.setWriteCompressedSizeInZip64ExtraRecord(true)
        } else {
            rawIO.writeLongLittleEndian(longBuff, 0, localFileHeader.getCompressedSize())
            byteArrayOutputStream.write(longBuff[0..4])

            rawIO.writeLongLittleEndian(longBuff, 0, localFileHeader.getUncompressedSize())
            byteArrayOutputStream.write(longBuff[0..4])

            localFileHeader.setWriteCompressedSizeInZip64ExtraRecord(false)
        }

        var fileNameBytes = InternalZipConstants.NULL_BYTE_ARRAY
        if (Zip4cjUtil.isStringNotNullAndNotEmpty(localFileHeader.getFileName())) {
            fileNameBytes = HeaderUtil.getBytesFromString(localFileHeader.getFileName().getOrThrow())
        }
        rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(fileNameBytes.size))

        var extraFieldLength: Int32 = 0
        if (writeZip64Header) {
            extraFieldLength += Int32(ZIP64_EXTRA_DATA_RECORD_SIZE_LFH) + 4 // 4 for signature + size of record
        }
        if (localFileHeader.getAesExtraDataRecord().isSome()) {
            extraFieldLength += Int32(AES_EXTRA_DATA_RECORD_SIZE)
        }
        rawIO.writeShortLittleEndian(byteArrayOutputStream, extraFieldLength)

        if (fileNameBytes.size > 0) {
            byteArrayOutputStream.write(fileNameBytes)
        }

        //Zip64 should be the first extra data record that should be written
        //This is NOT according to any specification but if this is changed
        //corresponding logic for updateLocalFileHeader for compressed size
        //has to be modified as well
        if (writeZip64Header) {
            rawIO.writeShortLittleEndian(
                byteArrayOutputStream,
                Int32(HeaderSignature.ZIP64_EXTRA_FIELD_SIGNATURE.getValue())
            )
            rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(ZIP64_EXTRA_DATA_RECORD_SIZE_LFH))
            rawIO.writeLongLittleEndian(byteArrayOutputStream, localFileHeader.getUncompressedSize())
            rawIO.writeLongLittleEndian(byteArrayOutputStream, localFileHeader.getCompressedSize())
        }

        if (let Some(aesExtraDataRecord) <- localFileHeader.getAesExtraDataRecord()) {
            rawIO.writeShortLittleEndian(
                byteArrayOutputStream,
                Int32(aesExtraDataRecord.getSignature().getOrThrow().getValue())
            )
            rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(aesExtraDataRecord.getDataSize()))
            rawIO.writeShortLittleEndian(byteArrayOutputStream, aesExtraDataRecord.getAesVersion().getVersionNumber())
            byteArrayOutputStream.write(HeaderUtil.getBytesFromString(aesExtraDataRecord.getVendorID()))

            var aesStrengthBytes = Array<Byte>(1, repeat: 0)
            aesStrengthBytes[0] = UInt8(aesExtraDataRecord.getAesKeyStrength().getRawCode())
            byteArrayOutputStream.write(aesStrengthBytes)

            rawIO.writeShortLittleEndian(byteArrayOutputStream, aesExtraDataRecord.getCompressionMethod().getCode())
        }
        let bytes = byteArrayOutputStream.bytes()
        outputStream.write(bytes)
    }

    @OverflowWrapping
    public func writeExtendedLocalHeader(localFileHeader: ?LocalFileHeader, outputStream: OutputStream) {
        if (localFileHeader.isNone()) {
            throw ZipException("input parameters is None, cannot write extended local header")
        }
        let byteArrayOutputStream = ByteBuffer()
        rawIO.writeIntLittleEndian(byteArrayOutputStream, Int32(HeaderSignature.EXTRA_DATA_RECORD.getValue()))

        rawIO.writeLongLittleEndian(longBuff, 0, localFileHeader.getOrThrow().getCrc())
        byteArrayOutputStream.write(longBuff[0..4])

        if (localFileHeader.getOrThrow().isWriteCompressedSizeInZip64ExtraRecord()) {
            rawIO.writeLongLittleEndian(byteArrayOutputStream, localFileHeader.getOrThrow().getCompressedSize())
            rawIO.writeLongLittleEndian(byteArrayOutputStream, localFileHeader.getOrThrow().getUncompressedSize())
        } else {
            rawIO.writeLongLittleEndian(longBuff, 0, localFileHeader.getOrThrow().getCompressedSize())
            byteArrayOutputStream.write(longBuff[0..4])

            rawIO.writeLongLittleEndian(longBuff, 0, localFileHeader.getOrThrow().getUncompressedSize())
            byteArrayOutputStream.write(longBuff[0..4])
        }
        outputStream.write(byteArrayOutputStream.bytes())
    }

    public func finalizeZipFile(zipModel: ZipModel, outputStream: OutputStream): Unit {
        let byteArrayOutputStream = ByteBuffer()
        processHeaderData(zipModel, outputStream)
        let offsetCentralDir = getOffsetOfCentralDirectory(zipModel)
        writeCentralDirectory(zipModel, byteArrayOutputStream, rawIO)
        let sizeOfCentralDir = byteArrayOutputStream.length

        if (zipModel.isZip64Format() || offsetCentralDir >= InternalZipConstants.ZIP_64_SIZE_LIMIT ||
            zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size >= InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT) {
            if (zipModel.getZip64EndOfCentralDirectoryLocator().isNone()) {
                zipModel.setZip64EndOfCentralDirectoryLocator(Zip64EndOfCentralDirectoryLocator())
            }

            zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().setOffsetZip64EndOfCentralDirectoryRecord(
                offsetCentralDir + sizeOfCentralDir)

            if (isSplitZipFile(outputStream)) {
                var currentSplitFileCounter = getCurrentSplitFileCounter(outputStream)
                zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().
                    setNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord(currentSplitFileCounter)
                zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().setTotalNumberOfDiscs(
                    currentSplitFileCounter + 1)
            } else {
                zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().
                    setNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord(0)
                zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().setTotalNumberOfDiscs(1)
            }

            var zip64EndOfCentralDirectoryRecord = buildZip64EndOfCentralDirectoryRecord(zipModel,
                Int64(sizeOfCentralDir), offsetCentralDir)
            zipModel.setZip64EndOfCentralDirectoryRecord(zip64EndOfCentralDirectoryRecord)
            writeZip64EndOfCentralDirectoryRecord(zip64EndOfCentralDirectoryRecord, byteArrayOutputStream, rawIO)
            writeZip64EndOfCentralDirectoryLocator(zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow(),
                byteArrayOutputStream, rawIO)
        }

        writeEndOfCentralDirectoryRecord(zipModel, Int32(sizeOfCentralDir), offsetCentralDir, byteArrayOutputStream,
            rawIO)
        writeZipHeaderBytes(zipModel, outputStream, byteArrayOutputStream.bytes())
    }

    public func finalizeZipFileWithoutValidations(zipModel: ZipModel, outputStream: OutputStream) {
        let byteArrayOutputStream: ByteBuffer = ByteBuffer()
        let offsetCentralDir = getOffsetOfCentralDirectory(zipModel)
        writeCentralDirectory(zipModel, byteArrayOutputStream, rawIO)
        let sizeOfCentralDir = byteArrayOutputStream.length

        if (zipModel.isZip64Format() || offsetCentralDir >= InternalZipConstants.ZIP_64_SIZE_LIMIT ||
            zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size >= InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT) {

            zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().setOffsetZip64EndOfCentralDirectoryRecord(
                offsetCentralDir + sizeOfCentralDir)

            var zip64EndOfCentralDirectoryRecord: Zip64EndOfCentralDirectoryRecord = buildZip64EndOfCentralDirectoryRecord(
                zipModel, sizeOfCentralDir, offsetCentralDir)
            zipModel.setZip64EndOfCentralDirectoryRecord(zip64EndOfCentralDirectoryRecord)
            writeZip64EndOfCentralDirectoryRecord(zip64EndOfCentralDirectoryRecord, byteArrayOutputStream, rawIO)
            writeZip64EndOfCentralDirectoryLocator(zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow(),
                byteArrayOutputStream, rawIO)
        }

        writeEndOfCentralDirectoryRecord(zipModel, Int32(sizeOfCentralDir), offsetCentralDir, byteArrayOutputStream,
            rawIO)
        writeZipHeaderBytes(zipModel, outputStream, byteArrayOutputStream.bytes())
    }

    public func updateLocalFileHeader(fileHeader: FileHeader, zipModel: ZipModel, outputStream: SplitOutputStream) {
        var closeFlag = false
        var currOutputStream: SplitOutputStream

        if (fileHeader.getDiskNumberStart() != Int64(outputStream.getCurrentSplitFileCounter())) {
            var parentFile = zipModel.getZipFile().parent
            var fileNameWithoutExt = FileUtils.getZipFileNameWithoutExtension(
                zipModel.getZipFile().fileName)
            var fileName = parentFile.toString() + Path.Separator
            if (fileHeader.getDiskNumberStart() < 9) {
                fileName += fileNameWithoutExt + ".z0${(fileHeader.getDiskNumberStart() + 1)}"
            } else {
                fileName += fileNameWithoutExt + ".z${(fileHeader.getDiskNumberStart() + 1)}"
            }
            currOutputStream = SplitOutputStream(Path(fileName))
            closeFlag = true
        } else {
            currOutputStream = outputStream
        }
        var currOffset = currOutputStream.getFilePointer()

        currOutputStream.seek(fileHeader.getOffsetLocalHeader() + Int64(InternalZipConstants.UPDATE_LFH_CRC))
        rawIO.writeLongLittleEndian(longBuff, 0, fileHeader.getCrc())
        currOutputStream.write(longBuff[0..4])

        updateFileSizesInLocalFileHeader(currOutputStream, fileHeader)
        if (closeFlag) {
            currOutputStream.close()
        } else {
            outputStream.seek(currOffset)
        }
    }

    private func updateFileSizesInLocalFileHeader(outputStream: SplitOutputStream, fileHeader: FileHeader) {
        if (fileHeader.getUncompressedSize() >= InternalZipConstants.ZIP_64_SIZE_LIMIT) {
            rawIO.writeLongLittleEndian(longBuff, 0, InternalZipConstants.ZIP_64_SIZE_LIMIT)
            outputStream.write(longBuff[0..4])
            outputStream.write(longBuff[0..4])

            //2 - file name length
            //2 - extra field length
            //variable - file name which can be determined by fileNameLength
            //2 - Zip64 signature
            //2 - size of zip64 data
            //8 - uncompressed size
            //8 - compressed size
            var zip64CompressedSizeOffset = 2 + 2 + fileHeader.getFileNameLength() + 2 + 2
            if (outputStream.skipBytes(zip64CompressedSizeOffset) != zip64CompressedSizeOffset) {
                throw ZipException("Unable to skip ${zip64CompressedSizeOffset} bytes to update LFH")
            }
            rawIO.writeLongLittleEndian(outputStream, fileHeader.getUncompressedSize())
            rawIO.writeLongLittleEndian(outputStream, fileHeader.getCompressedSize())
        } else {
            rawIO.writeLongLittleEndian(longBuff, 0, fileHeader.getCompressedSize())
            outputStream.write(longBuff[0..4])
        }
    }

    private func isSplitZipFile(outputStream: OutputStream): Bool {
        if (let Some(output) <- (outputStream as SplitOutputStream)) {
            return output.isSplitZipFile()
        } else if (let Some(output) <- (outputStream as CountingOutputStream)) {
            return output.isSplitZipFile()
        }
        return false
    }

    private func getCurrentSplitFileCounter(outputStream: OutputStream): Int32 {
        if (let Some(output) <-( outputStream as SplitOutputStream)) {
            return output.getCurrentSplitFileCounter()
        }
        if (let Some(output) <- (outputStream as CountingOutputStream)) {
            return output.getCurrentSplitFileCounter()
        }
        return -1
    }

    private func writeZipHeaderBytes(
        zipModel: ZipModel,
        outputStream: OutputStream,
        buff: Array<Byte>
    ) {
        if (let Some(output) <- (outputStream as CountingOutputStream)) {
            if (output.checkBuffSizeAndStartNextSplitFile(Int32(buff.size))) {
                finalizeZipFile(zipModel, output)
                return
            }
        }

        outputStream.write(buff)
    }

    private func processHeaderData(zipModel: ZipModel, outputStream: OutputStream) {
        var currentSplitFileCounter: Int32 = 0
        if (let Some(output) <- (outputStream as OutputStreamWithSplitZipSupport)) {
            zipModel.getEndOfCentralDirectoryRecord().setOffsetOfStartOfCentralDirectory(output.getFilePointer())
            currentSplitFileCounter = output.getCurrentSplitFileCounter()
        }
        if (zipModel.isZip64Format()) {
            zipModel.getZip64EndOfCentralDirectoryRecord().setOffsetStartCentralDirectoryWRTStartDiskNumber(
                zipModel.getEndOfCentralDirectoryRecord().getOffsetOfStartOfCentralDirectory())
            zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().
                setNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord(currentSplitFileCounter)
            zipModel.getZip64EndOfCentralDirectoryLocator().getOrThrow().setTotalNumberOfDiscs(
                currentSplitFileCounter + 1)
        }
        zipModel.getEndOfCentralDirectoryRecord().setNumberOfThisDisk(currentSplitFileCounter)
        zipModel.getEndOfCentralDirectoryRecord().setNumberOfThisDiskStartOfCentralDir(currentSplitFileCounter)
    }

    private func writeCentralDirectory(
        zipModel: ZipModel,
        byteArrayOutputStream: ByteBuffer,
        rawIO: RawIO
    ) {
        if (zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size <= 0) {
            return
        }

        let fileHeaders = zipModel.getCentralDirectory().getOrThrow().getFileHeaders()
        for (i in 0..fileHeaders.size) {
            writeFileHeader(zipModel, fileHeaders[i], byteArrayOutputStream, rawIO)
        }
    }

    private func writeFileHeader(
        zipModel: ZipModel,
        fileHeader: FileHeader,
        byteArrayOutputStream: ByteBuffer,
        rawIO: RawIO
    ) {

        let emptyShortByte = Array<Byte>(2, repeat: 0)
        var writeZip64ExtendedInfo = this.isZip64Entry(fileHeader)

        rawIO.writeIntLittleEndian(byteArrayOutputStream, Int32(fileHeader.getSignature().getOrThrow().getValue()))
        rawIO.writeShortLittleEndian(byteArrayOutputStream, fileHeader.getVersionMadeBy())
        rawIO.writeShortLittleEndian(byteArrayOutputStream, fileHeader.getVersionNeededToExtract())
        byteArrayOutputStream.write(fileHeader.getGeneralPurposeFlag().getOrThrow())

        rawIO.writeShortLittleEndian(byteArrayOutputStream, fileHeader.getCompressionMethod().getOrThrow().getCode())

        rawIO.writeLongLittleEndian(longBuff, 0, fileHeader.getLastModifiedTime())
        byteArrayOutputStream.write(longBuff[0..4])
        rawIO.writeLongLittleEndian(longBuff, 0, fileHeader.getCrc())
        byteArrayOutputStream.write(longBuff[0..4])
        if (writeZip64ExtendedInfo) {
            rawIO.writeLongLittleEndian(longBuff, 0, InternalZipConstants.ZIP_64_SIZE_LIMIT)
            byteArrayOutputStream.write(longBuff[0..4])

            byteArrayOutputStream.write(longBuff[0..4])
            zipModel.setZip64Format(true)
        } else {
            rawIO.writeLongLittleEndian(longBuff, 0, fileHeader.getCompressedSize())
            byteArrayOutputStream.write(longBuff[0..4])
            rawIO.writeLongLittleEndian(longBuff, 0, fileHeader.getUncompressedSize())
            byteArrayOutputStream.write(longBuff[0..4])
        }

        var fileNameBytes = Array<Byte>(1, repeat: 0)
        if (Zip4cjUtil.isStringNotNullAndNotEmpty(fileHeader.getFileName())) {
            fileNameBytes = HeaderUtil.getBytesFromString(fileHeader.getFileName().getOrThrow())
        }
        rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(fileNameBytes.size))
        //Compute offset bytes before extra field is written for Zip64 compatibility
        //NOTE: this data is not written now, but written at a later point
        var offsetLocalHeaderBytes = Array<Byte>(4, repeat: 0)
        if (writeZip64ExtendedInfo) {
            rawIO.writeLongLittleEndian(longBuff, 0, InternalZipConstants.ZIP_64_SIZE_LIMIT)
            ArrayCopy(longBuff, 0, offsetLocalHeaderBytes, 0, 4)
        } else {
            rawIO.writeLongLittleEndian(longBuff, 0, fileHeader.getOffsetLocalHeader())
            ArrayCopy(longBuff, 0, offsetLocalHeaderBytes, 0, 4)
        }

        var extraFieldLength = calculateExtraDataRecordsSize(fileHeader, writeZip64ExtendedInfo)
        rawIO.writeShortLittleEndian(byteArrayOutputStream, extraFieldLength)

        var fileComment = fileHeader.getFileComment()
        var fileCommentBytes = InternalZipConstants.NULL_BYTE_ARRAY
        if (Zip4cjUtil.isStringNotNullAndNotEmpty(fileComment)) {
            fileCommentBytes = HeaderUtil.getBytesFromString(fileComment.getOrThrow())
        }
        rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(fileCommentBytes.size))

        if (writeZip64ExtendedInfo) {
            rawIO.writeIntLittleEndian(intBuff, 0, Int32(InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT))
            byteArrayOutputStream.write(intBuff[0..2])
        } else {
            rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(fileHeader.getDiskNumberStart()))
        }

        byteArrayOutputStream.write(emptyShortByte)

        //External file attributes
        byteArrayOutputStream.write(fileHeader.getExternalFileAttributes().getOrThrow())

        //offset local header - this data is computed above
        byteArrayOutputStream.write(offsetLocalHeaderBytes)

        if (fileNameBytes.size > 0) {
            byteArrayOutputStream.write(fileNameBytes)
        }

        if (writeZip64ExtendedInfo) {
            zipModel.setZip64Format(true)

            //Zip64 header
            rawIO.writeShortLittleEndian(
                byteArrayOutputStream,
                Int32(HeaderSignature.ZIP64_EXTRA_FIELD_SIGNATURE.getValue())
            )

            //size of data
            rawIO.writeShortLittleEndian(byteArrayOutputStream, ZIP64_EXTRA_DATA_RECORD_SIZE_FH)
            rawIO.writeLongLittleEndian(byteArrayOutputStream, fileHeader.getUncompressedSize())
            rawIO.writeLongLittleEndian(byteArrayOutputStream, fileHeader.getCompressedSize())
            rawIO.writeLongLittleEndian(byteArrayOutputStream, fileHeader.getOffsetLocalHeader())
            rawIO.writeIntLittleEndian(byteArrayOutputStream, Int32(fileHeader.getDiskNumberStart()))
        }

        if (let Some(aesExtraDataRecord) <- fileHeader.getAesExtraDataRecord()) {
            rawIO.writeShortLittleEndian(
                byteArrayOutputStream,
                Int32(aesExtraDataRecord.getSignature().getOrThrow().getValue())
            )
            rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(aesExtraDataRecord.getDataSize()))
            rawIO.writeShortLittleEndian(byteArrayOutputStream, aesExtraDataRecord.getAesVersion().getVersionNumber())
            byteArrayOutputStream.write(HeaderUtil.getBytesFromString(aesExtraDataRecord.getVendorID()))

            let aesStrengthBytes = Array<Byte>(1, repeat: 0)
            aesStrengthBytes[0] = UInt8(aesExtraDataRecord.getAesKeyStrength().getRawCode())
            byteArrayOutputStream.write(aesStrengthBytes)

            rawIO.writeShortLittleEndian(byteArrayOutputStream, aesExtraDataRecord.getCompressionMethod().getCode())
        }

        writeRemainingExtraDataRecordsIfPresent(fileHeader, byteArrayOutputStream)

        if (fileCommentBytes.size > 0) {
            byteArrayOutputStream.write(fileCommentBytes)
        }
    }

    private func calculateExtraDataRecordsSize(fileHeader: FileHeader, writeZip64ExtendedInfo: Bool) {
        var extraFieldLength: Int32 = 0

        if (writeZip64ExtendedInfo) {
            extraFieldLength += ZIP64_EXTRA_DATA_RECORD_SIZE_FH + 4 // 4 for signature + size of record
        }

        if (fileHeader.getAesExtraDataRecord().isSome()) {
            extraFieldLength += AES_EXTRA_DATA_RECORD_SIZE
        }

        if (let Some(extraDataRecords) <- fileHeader.getExtraDataRecords()) {
            for (i in 0..extraDataRecords.size) {
                let extraDataRecord = extraDataRecords[i]
                if (extraDataRecord.getHeader() == HeaderSignature.AES_EXTRA_DATA_RECORD.getValue() ||
                    extraDataRecord.getHeader() == HeaderSignature.ZIP64_EXTRA_FIELD_SIGNATURE.getValue()) {
                    continue
                }

                extraFieldLength += 4 + Int32(extraDataRecord.getSizeOfData()) // 4  = 2 for header + 2 for size of data
            }
        }

        return extraFieldLength
    }

    private func writeRemainingExtraDataRecordsIfPresent(fileHeader: FileHeader, outputStream: OutputStream) {
        if (fileHeader.getExtraDataRecords().isNone() || fileHeader.getExtraDataRecords().getOrThrow().size == 0) {
            return
        }

        let extraDataRecords = fileHeader.getExtraDataRecords().getOrThrow()
        for (i in 0..extraDataRecords.size) {
            let extraDataRecord = extraDataRecords[i]
            if (extraDataRecord.getHeader() == HeaderSignature.AES_EXTRA_DATA_RECORD.getValue() ||
                extraDataRecord.getHeader() == HeaderSignature.ZIP64_EXTRA_FIELD_SIGNATURE.getValue()) {
                continue
            }

            rawIO.writeShortLittleEndian(outputStream, Int32(extraDataRecord.getHeader()))
            rawIO.writeShortLittleEndian(outputStream, Int32(extraDataRecord.getSizeOfData()))

            if (extraDataRecord.getSizeOfData() > 0 && extraDataRecord.getData() != None) {
                outputStream.write(extraDataRecord.getData().getOrThrow())
            }
        }
    }

    private func writeZip64EndOfCentralDirectoryRecord(
        zip64EndOfCentralDirectoryRecord: Zip64EndOfCentralDirectoryRecord,
        byteArrayOutputStream: ByteBuffer,
        rawIO: RawIO
    ) {
        rawIO.writeIntLittleEndian(
            byteArrayOutputStream,
            Int32(zip64EndOfCentralDirectoryRecord.getSignature().getOrThrow().getValue())
        )
        rawIO.writeLongLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryRecord.getSizeOfZip64EndCentralDirectoryRecord()
        )
        rawIO.writeShortLittleEndian(byteArrayOutputStream, zip64EndOfCentralDirectoryRecord.getVersionMadeBy())
        rawIO.writeShortLittleEndian(byteArrayOutputStream, zip64EndOfCentralDirectoryRecord.getVersionNeededToExtract()
        )
        rawIO.writeIntLittleEndian(byteArrayOutputStream, zip64EndOfCentralDirectoryRecord.getNumberOfThisDisk())
        rawIO.writeIntLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryRecord.getNumberOfThisDiskStartOfCentralDirectory()
        )
        rawIO.writeLongLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryRecord.getTotalNumberOfEntriesInCentralDirectoryOnThisDisk()
        )
        rawIO.writeLongLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryRecord.getTotalNumberOfEntriesInCentralDirectory()
        )
        rawIO.writeLongLittleEndian(byteArrayOutputStream, zip64EndOfCentralDirectoryRecord.getSizeOfCentralDirectory())
        rawIO.writeLongLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryRecord.getOffsetStartCentralDirectoryWRTStartDiskNumber()
        )
    }

    private func writeZip64EndOfCentralDirectoryLocator(
        zip64EndOfCentralDirectoryLocator: Zip64EndOfCentralDirectoryLocator,
        byteArrayOutputStream: ByteBuffer,
        rawIO: RawIO
    ) {
        rawIO.writeIntLittleEndian(
            byteArrayOutputStream,
            Int32(HeaderSignature.ZIP64_END_CENTRAL_DIRECTORY_LOCATOR.getValue())
        )
        rawIO.writeIntLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryLocator.getNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord()
        )
        rawIO.writeLongLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryLocator.getOffsetZip64EndOfCentralDirectoryRecord()
        )
        rawIO.writeIntLittleEndian(
            byteArrayOutputStream,
            zip64EndOfCentralDirectoryLocator.getTotalNumberOfDiscs()
        )
    }

    private func writeEndOfCentralDirectoryRecord(
        zipModel: ZipModel,
        sizeOfCentralDir: Int32,
        offsetCentralDir: Int64,
        byteArrayOutputStream: ByteBuffer,
        rawIO: RawIO
    ) {
        let longByte = Array<Byte>(8, repeat: 0)
        rawIO.writeIntLittleEndian(byteArrayOutputStream, Int32(HeaderSignature.END_OF_CENTRAL_DIRECTORY.getValue()))
        rawIO.writeShortLittleEndian(
            byteArrayOutputStream,
            zipModel.getEndOfCentralDirectoryRecord().getNumberOfThisDisk()
        )
        rawIO.writeShortLittleEndian(
            byteArrayOutputStream,
            zipModel.getEndOfCentralDirectoryRecord().getNumberOfThisDiskStartOfCentralDir()
        )

        var numEntries = zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size
        var numEntriesOnThisDisk = numEntries
        if (zipModel.isSplitArchive()) {
            numEntriesOnThisDisk = countNumberOfFileHeaderEntriesOnDisk(
                zipModel.getCentralDirectory().getOrThrow().getFileHeaders(),
                Int64(zipModel.getEndOfCentralDirectoryRecord().getNumberOfThisDisk())
            )
        }

        if (numEntriesOnThisDisk > InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT) {
            numEntriesOnThisDisk = InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT
        }
        rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(numEntriesOnThisDisk))

        if (numEntries > InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT) {
            numEntries = InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT
        }
        rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(numEntries))

        rawIO.writeIntLittleEndian(byteArrayOutputStream, sizeOfCentralDir)
        if (offsetCentralDir > InternalZipConstants.ZIP_64_SIZE_LIMIT) {
            rawIO.writeLongLittleEndian(longByte, 0, InternalZipConstants.ZIP_64_SIZE_LIMIT)
            byteArrayOutputStream.write(longByte[0..4])
        } else {
            rawIO.writeLongLittleEndian(longByte, 0, offsetCentralDir)
            byteArrayOutputStream.write(longByte[0..4])
        }

        var comment = zipModel.getEndOfCentralDirectoryRecord().getComment()
        if (Zip4cjUtil.isStringNotNullAndNotEmpty(comment)) {
            let commentBytes = HeaderUtil.getBytesFromString(comment)
            rawIO.writeShortLittleEndian(byteArrayOutputStream, Int32(commentBytes.size))
            byteArrayOutputStream.write(commentBytes)
        } else {
            rawIO.writeShortLittleEndian(byteArrayOutputStream, 0)
        }
    }

    private func countNumberOfFileHeaderEntriesOnDisk(fileHeaders: ArrayList<FileHeader>, numOfDisk: Int64): Int64 {
        var noEntries = 0
        for (i in 0..fileHeaders.size) {
            if (fileHeaders[i].getDiskNumberStart() == numOfDisk) {
                noEntries++
            }
        }
        return noEntries
    }

    private func isZip64Entry(fileHeader: FileHeader): Bool {
        return fileHeader.getCompressedSize() >= InternalZipConstants.ZIP_64_SIZE_LIMIT ||
            fileHeader.getUncompressedSize() >= InternalZipConstants.ZIP_64_SIZE_LIMIT ||
            fileHeader.getOffsetLocalHeader() >= InternalZipConstants.ZIP_64_SIZE_LIMIT ||
            fileHeader.getDiskNumberStart() >= InternalZipConstants.ZIP_64_NUMBER_OF_ENTRIES_LIMIT
    }

    private func getOffsetOfCentralDirectory(zipModel: ZipModel): Int64 {
        if (zipModel.isZip64Format() &&
            zipModel.getZip64EndOfCentralDirectoryRecord().getOffsetStartCentralDirectoryWRTStartDiskNumber() != -1) {
            return zipModel.getZip64EndOfCentralDirectoryRecord().getOffsetStartCentralDirectoryWRTStartDiskNumber()
        }

        return zipModel.getEndOfCentralDirectoryRecord().getOffsetOfStartOfCentralDirectory()
    }

    private func buildZip64EndOfCentralDirectoryRecord(
        zipModel: ZipModel,
        sizeOfCentralDir: Int64,
        offsetCentralDir: Int64
    ): Zip64EndOfCentralDirectoryRecord {
        let zip64EndOfCentralDirectoryRecord = Zip64EndOfCentralDirectoryRecord()

        zip64EndOfCentralDirectoryRecord.setSignature(HeaderSignature.ZIP64_END_CENTRAL_DIRECTORY_RECORD)
        zip64EndOfCentralDirectoryRecord.setSizeOfZip64EndCentralDirectoryRecord(44)

        if (zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size > 0) {
            var firstFileHeader = zipModel.getCentralDirectory().getOrThrow().getFileHeaders()[0]
            zip64EndOfCentralDirectoryRecord.setVersionMadeBy(firstFileHeader.getVersionMadeBy())
            zip64EndOfCentralDirectoryRecord.setVersionNeededToExtract(firstFileHeader.getVersionNeededToExtract())
        }

        zip64EndOfCentralDirectoryRecord.setNumberOfThisDisk(
            zipModel.getEndOfCentralDirectoryRecord().getNumberOfThisDisk())
        zip64EndOfCentralDirectoryRecord.setNumberOfThisDiskStartOfCentralDirectory(
            zipModel.getEndOfCentralDirectoryRecord().getNumberOfThisDiskStartOfCentralDir())

        var numEntries = zipModel.getCentralDirectory().getOrThrow().getFileHeaders().size
        var numEntriesOnThisDisk = numEntries
        if (zipModel.isSplitArchive()) {
            numEntriesOnThisDisk = countNumberOfFileHeaderEntriesOnDisk(
                zipModel.getCentralDirectory().getOrThrow().getFileHeaders(),
                Int64(zipModel.getEndOfCentralDirectoryRecord().getNumberOfThisDisk())
            )
        }

        zip64EndOfCentralDirectoryRecord.setTotalNumberOfEntriesInCentralDirectoryOnThisDisk(numEntriesOnThisDisk)
        zip64EndOfCentralDirectoryRecord.setTotalNumberOfEntriesInCentralDirectory(numEntries)
        zip64EndOfCentralDirectoryRecord.setSizeOfCentralDirectory(Int64(sizeOfCentralDir))
        zip64EndOfCentralDirectoryRecord.setOffsetStartCentralDirectoryWRTStartDiskNumber(offsetCentralDir)

        return zip64EndOfCentralDirectoryRecord
    }
}
