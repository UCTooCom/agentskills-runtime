/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

public class ZipInputStream <: InputStream & Resource {
    private var inputStream: PushbackInputStream
    private var decompressedInputStream: ?DecompressedInputStream = None
    private var headerReader: HeaderReader = HeaderReader()
    private var password: ?Array<Rune>
    private var passwordCallback: ?PasswordCallback
    private var localFileHeader: ?LocalFileHeader = None
    private var crc32: CRC32 = CRC32()
    private var endOfEntryBuffer: Array<Byte> = InternalZipConstants.NULL_BYTE_ARRAY
    private var canSkipExtendedLocalFileHeader: Bool = false
    private var zip4cjConfig: Zip4cjConfig
    private var streamClosed: Bool = false
    private var entryEOFReached: Bool = false

    public init(
        inputStream: InputStream,
        password!: ?Array<Rune> = None, 
        passwordCallback!: ?PasswordCallback = None ,
        config!: Zip4cjConfig = Zip4cjConfig(InternalZipConstants.BUFF_SIZE, InternalZipConstants.USE_UTF8_FOR_PASSWORD_ENCODING_DECODING)
    ) {
        if (config.getBufferSize() < InternalZipConstants.MIN_BUFF_SIZE) {
            throw IllegalArgumentException(
                "Buffer size cannot be less than  ${InternalZipConstants.MIN_BUFF_SIZE} bytes")
        }

        this.inputStream = PushbackInputStream(inputStream, Int64(config.getBufferSize()))
        this.password = password
        this.passwordCallback = passwordCallback
        this.zip4cjConfig = config
    }

    public func getNextEntry(fileHeader: ?FileHeader, readUntilEndOfCurrentEntryIfOpen: Bool): ?LocalFileHeader {
        if (!localFileHeader.isNone() && readUntilEndOfCurrentEntryIfOpen) {
            readUntilEndOfEntry()
        }

        localFileHeader = headerReader.readLocalFileHeader(inputStream)

        if (localFileHeader.isNone()) {
            return None
        }
        let localFileHeaderV = localFileHeader.getOrThrow()
        if (localFileHeaderV.isEncrypted() && password.isNone() && passwordCallback.isSome()) {
            setPassword(passwordCallback.getOrThrow().getPassword())
        }

        verifyLocalFileHeader(localFileHeaderV)

        if (let Some(fileHeaderV) <- fileHeader) {
            localFileHeaderV.setCrc(fileHeaderV.getCrc())
            localFileHeaderV.setCompressedSize(fileHeaderV.getCompressedSize())
            localFileHeaderV.setUncompressedSize(fileHeaderV.getUncompressedSize())
            // file header's directory flag is more reliable than local file header's directory flag as file header has
            // additional external file attributes which has a directory flag defined. In local file header, the only way
            // to determine if an entry is directory is to check if the file name has a trailing forward slash "/"
            localFileHeaderV.setDirectory(fileHeaderV.isDirectory())
            canSkipExtendedLocalFileHeader = true
        } else {
            canSkipExtendedLocalFileHeader = false
        }

        this.decompressedInputStream = initializeEntryInputStream(localFileHeaderV)
        this.entryEOFReached = false
        return localFileHeader
    }

    public func read(b: Array<Byte>): Int64 {
        if (b.size == 0) {
            return -1
        }
        if (streamClosed) {
            throw ZipIOException("Stream closed")
        }
        if (localFileHeader.isNone()) {
            // localfileheader can be null when end of compressed data is reached.  If null check is missing, read method will
            // throw a NPE when end of compressed data is reached and read is called again.
            return -1
        }

        try {
            var readLen = decompressedInputStream.getOrThrow().read(b)
            if (readLen > 0) {
                crc32.update(b[0..readLen])
            } else if (readLen <= 0) {
                endOfCompressedDataReached()
            }
            return readLen
        } catch (e: IOException | ZipIOException) {
            if (isEncryptionMethodZipStandard(localFileHeader.getOrThrow())) {
                throw ZipException(e.message)
            }
            throw e
        }
    }

    private func endOfCompressedDataReached () {
        var numberOfBytesPushedBack = decompressedInputStream.getOrThrow().pushBackInputStreamIfNecessary(inputStream)
        //First signal the end of data for this entry so that ciphers can read any header data if applicable
        decompressedInputStream.getOrThrow().endOfEntryReached(inputStream, numberOfBytesPushedBack)
        readExtendedLocalFileHeaderIfPresent()
        verifyCrc()
        resetFields()
        this.entryEOFReached = true
    }

    public func isClosed(): Bool {
        streamClosed
    }

    public func close(): Unit {
        if (streamClosed) {
            return
        }
        if (let Some(v) <- decompressedInputStream) {
            v.close()
        }
        this.streamClosed = true
    }

    public func available(): Int64 {
        assertStreamOpen()
        if (entryEOFReached) {
            return 0
        }
        return 1
    }

    public func setPassword(password: ?Array<Rune>): Unit {
        this.password = password
    }

    private func initializeEntryInputStream(localFileHeader: LocalFileHeader): DecompressedInputStream {
        var zipEntryInputStream: ZipEntryInputStream = ZipEntryInputStream(
            inputStream,
            getCompressedSize(localFileHeader)
        )
        var cipherInputStream: ICipherInputStream = initializeCipherInputStream(
            zipEntryInputStream,
            localFileHeader
        )
        return initializeDecompressorForThisEntry(cipherInputStream, localFileHeader)
    }

    private func initializeCipherInputStream(
        zipEntryInputStream: ZipEntryInputStream,
        localFileHeader: LocalFileHeader
    ): ICipherInputStream {
        if (!localFileHeader.isEncrypted()) {
            return NoCipherInputStream(zipEntryInputStream, localFileHeader, password,
                Int64(zip4cjConfig.getBufferSize()))
        }

        if (localFileHeader.getEncryptionMethod() == EncryptionMethod.AES) {
            return AesCipherInputStream(zipEntryInputStream, localFileHeader, password, zip4cjConfig.getBufferSize(),
              zip4cjConfig.isUseUtf8CharsetForPasswords())
        } else if (localFileHeader.getEncryptionMethod() == EncryptionMethod.ZIP_STANDARD) {
            return ZipStandardCipherInputStream(zipEntryInputStream, localFileHeader, password,
                Int64(zip4cjConfig.getBufferSize()), zip4cjConfig.isUseUtf8CharsetForPasswords())
        } else {
            let message: String = "Entry ${localFileHeader.getFileName()} Strong Encryption not supported"
            throw ZipException(message, ZipExceptionType.UNSUPPORTED_ENCRYPTION)
        }
    }

    private func initializeDecompressorForThisEntry(
        cipherInputStream: ICipherInputStream,
        localFileHeader: LocalFileHeader
    ): DecompressedInputStream {
        let compressionMethod = Zip4cjUtil.getCompressionMethod(localFileHeader)

        if (compressionMethod == CompressionMethod.DEFLATE) {
            return InflaterInputStream(cipherInputStream, Int64(zip4cjConfig.getBufferSize()))
        }

        return StoreInputStream(cipherInputStream)
    }

    private func readExtendedLocalFileHeaderIfPresent(): Unit {
        let localFileHeaders = localFileHeader.getOrThrow()
        if (!localFileHeaders.isDataDescriptorExists() || canSkipExtendedLocalFileHeader) {
            return
        }
        let dataDescriptor = headerReader.readDataDescriptor(inputStream,
            checkIfZip64ExtraDataRecordPresentInLFH(localFileHeaders.getExtraDataRecords()))
        localFileHeaders.setCompressedSize(dataDescriptor.getCompressedSize())
        localFileHeaders.setUncompressedSize(dataDescriptor.getUncompressedSize())
        localFileHeaders.setCrc(dataDescriptor.getCrc())
    }

    private func verifyLocalFileHeader(localFileHeader: LocalFileHeader): Unit {
        if (!isEntryDirectory(localFileHeader.getFileName().getOrThrow()) &&
            localFileHeader.getCompressionMethod().getOrThrow() == CompressionMethod.STORE &&
            localFileHeader.getUncompressedSize() < 0) {
            throw ZipIOException(
                "Invalid local file header for: ${localFileHeader.getFileName().getOrThrow()}. Uncompressed size has to be set for entry of compression type store which is not a directory"
            )
        }
    }

    private func checkIfZip64ExtraDataRecordPresentInLFH(extraDataRecord: ?ArrayList<ExtraDataRecord>): Bool {
        if (let Some(extraDataRecords) <- extraDataRecord) {
            if (extraDataRecords.isEmpty()) {
                return false
            }
            for (i in 0..extraDataRecords.size) {
                if (extraDataRecords[i].getHeader() == HeaderSignature.ZIP64_EXTRA_FIELD_SIGNATURE.getValue()) {
                    return true
                }
            }
        }
        return false
    }

    private func verifyCrc(): Unit {
        if (localFileHeader.getOrThrow().getEncryptionMethod() == EncryptionMethod.AES &&
            localFileHeader.getOrThrow().getAesExtraDataRecord().getOrThrow().getAesVersion().getVersionNumber() ==
            AesVersion.TWO.getVersionNumber()) {
            // Verification will be done in this case by AesCipherInputStream
            return
        }

        if (localFileHeader.getOrThrow().getCrc() != Int64(crc32.getValue())) {
            var exceptionType = ZipExceptionType.CHECKSUM_MISMATCH

            if (isEncryptionMethodZipStandard(localFileHeader.getOrThrow())) {
                exceptionType = ZipExceptionType.WRONG_PASSWORD
            }

            throw ZipException(
                "Reached end of entry, but crc verification failed for " +
                    localFileHeader.getOrThrow().getFileName().getOrThrow(),
                exceptionType
            )
        }
    }

    private func resetFields(): Unit {
        localFileHeader = None
        crc32.reset()
    }

    private func isEntryDirectory(entryName: String): Bool {
        return entryName.endsWith("/") || entryName.endsWith("\\")
    }

    private func getCompressedSize(localFileHeader: LocalFileHeader): Int64 {
        if (Zip4cjUtil.getCompressionMethod(localFileHeader) == (CompressionMethod.STORE)) {
            return localFileHeader.getUncompressedSize()
        }

        if (localFileHeader.isDataDescriptorExists() && !canSkipExtendedLocalFileHeader) {
            return -1
        }

        return localFileHeader.getCompressedSize() - getEncryptionHeaderSize(localFileHeader)
    }

    private func getEncryptionHeaderSize(localFileHeader: LocalFileHeader) {
        if (!localFileHeader.isEncrypted()) {
            return 0
        }

        if (localFileHeader.getEncryptionMethod() == (EncryptionMethod.AES)) {
            return getAesEncryptionHeaderSize(localFileHeader.getAesExtraDataRecord())
        } else if (localFileHeader.getEncryptionMethod() == (EncryptionMethod.ZIP_STANDARD)) {
            return InternalZipConstants.STD_DEC_HDR_SIZE
        } else {
            return 0
        }
    }

    private func readUntilEndOfEntry(): Unit {
        if (endOfEntryBuffer.isEmpty()) {
            endOfEntryBuffer = Array<Byte>(512, repeat: 0)
        }

        //noinspection StatementWithEmptyBody
        while (read(endOfEntryBuffer) != -1) {
            this.entryEOFReached = true
        }
    }

    private func getAesEncryptionHeaderSize(aesExtraDataRecord: ?AESExtraDataRecord): Int64 {
        if (aesExtraDataRecord.isNone()) {
            throw ZipException("AesExtraDataRecord not found or invalid for Aes encrypted entry")
        }

        return Int64(InternalZipConstants.AES_AUTH_LENGTH + InternalZipConstants.AES_PASSWORD_VERIFIER_LENGTH +
                aesExtraDataRecord.getOrThrow().getAesKeyStrength().getSaltLength())
    }

    private func isEncryptionMethodZipStandard(localFileHeader: LocalFileHeader): Bool {
        return localFileHeader.isEncrypted() && EncryptionMethod.ZIP_STANDARD == localFileHeader.getEncryptionMethod()
    }

    private func assertStreamOpen(): Unit {
        if (streamClosed) {
            throw ZipIOException("Stream closed")
        }
    }
}
