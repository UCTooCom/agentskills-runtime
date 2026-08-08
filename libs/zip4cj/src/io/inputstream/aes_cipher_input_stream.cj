/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream


class AesCipherInputStream <: CipherInputStream<AESDecrypter> {

    private var aes16ByteBlock = Array<Byte>(16, repeat: 0)
    private var aes16ByteBlockPointer = 0
    private var remainingAes16ByteBlockLength = 0
    private var lengthToRead = 0
    private var offsetWithAesBlock = 0
    private var bytesCopiedInThisIteration = 0
    private var lengthToCopyInThisIteration = 0
    private var aes16ByteBlockReadLength = 0

    public AesCipherInputStream(zipEntryInputStream: ZipEntryInputStream, localFileHeader: LocalFileHeader ,
                                password: ?Array<Rune> , bufferSize: Int64 , useUtf8ForPassword: Bool) {
        super(zipEntryInputStream, localFileHeader, password, bufferSize, useUtf8ForPassword)
        this.decrypter = initializeDecrypter(localFileHeader, password, useUtf8ForPassword)
    }

    protected override func initializeDecrypter(localFileHeader: LocalFileHeader, password: ?Array<Rune>,
                                               useUtf8ForPassword: Bool): AESDecrypter {
        return AESDecrypter(localFileHeader.getAesExtraDataRecord().getOrThrow(), password.getOrThrow(), getSalt(localFileHeader),
                getPasswordVerifier(), useUtf8ForPassword)
    }

    public override func read(b: Array<Byte>): Int64 {
        var off = 0
        var len = b.size
        lengthToRead = len
        offsetWithAesBlock = off
        bytesCopiedInThisIteration = 0

        if (remainingAes16ByteBlockLength != 0) {
            copyBytesFromBuffer(b, offsetWithAesBlock)

            if (bytesCopiedInThisIteration == len) {
                return bytesCopiedInThisIteration
            }
        }

        if (lengthToRead < 16) {
            aes16ByteBlockReadLength = super.read(aes16ByteBlock, 0, aes16ByteBlock.size)
            aes16ByteBlockPointer = 0

            if (aes16ByteBlockReadLength == -1) {
                remainingAes16ByteBlockLength = 0

                if (bytesCopiedInThisIteration > 0) {
                    return bytesCopiedInThisIteration
                }

                return -1
            }

            remainingAes16ByteBlockLength = aes16ByteBlockReadLength

            copyBytesFromBuffer(b, offsetWithAesBlock)

            if (bytesCopiedInThisIteration == len) {
                return bytesCopiedInThisIteration
            }
        }

        let readLen = super.read(b, offsetWithAesBlock, (lengthToRead - lengthToRead % 16))

        if (readLen == -1) {
            if (bytesCopiedInThisIteration > 0) {
                return bytesCopiedInThisIteration
            } else {
                return -1
            }
        } else {
            return readLen + bytesCopiedInThisIteration
        }
    }

    private func copyBytesFromBuffer(b: Array<Byte>, off: Int64 ): Unit {
        lengthToCopyInThisIteration = if (lengthToRead < remainingAes16ByteBlockLength) {
            lengthToRead
        } else {
            remainingAes16ByteBlockLength
        }
        aes16ByteBlock.copyTo(b, aes16ByteBlockPointer, off, lengthToCopyInThisIteration)

        incrementAesByteBlockPointer(lengthToCopyInThisIteration)
        decrementRemainingAesBytesLength(lengthToCopyInThisIteration)

        bytesCopiedInThisIteration += lengthToCopyInThisIteration

        lengthToRead -= lengthToCopyInThisIteration
        offsetWithAesBlock += lengthToCopyInThisIteration
    }

    protected override func endOfEntryReached(inputStream: InputStream , numberOfBytesPushedBack: Int64): Unit {
        verifyContent(readStoredMac(inputStream), numberOfBytesPushedBack)
    }

    private func verifyContent(storedMac: Array<Byte>, numberOfBytesPushedBack: Int64): Unit {
       let calculatedMac: Array<Byte> = getDecrypter().getCalculatedAuthenticationBytes(numberOfBytesPushedBack)
        let first10BytesOfCalculatedMac: Array<Byte> = Array<Byte>(InternalZipConstants.AES_AUTH_LENGTH, repeat: 0)
        calculatedMac.copyTo(first10BytesOfCalculatedMac, 0, 0, InternalZipConstants.AES_AUTH_LENGTH)

        if (storedMac != first10BytesOfCalculatedMac) {
            throw ZipIOException("Reached end of data for this entry, but aes verification failed")
        }
    }

    protected func readStoredMac(inputStream: InputStream ): Array<Byte> {
        let storedMac: Array<Byte> = Array<Byte>(InternalZipConstants.AES_AUTH_LENGTH, repeat: 0)
        var readLen = Zip4cjUtil.readFully(inputStream, storedMac)

        if (readLen != InternalZipConstants.AES_AUTH_LENGTH) {
            throw ZipException("Invalid AES Mac bytes. Could not read sufficient data")
        }

        return storedMac
    }

    private func getSalt(localFileHeader: LocalFileHeader): Array<Byte> {
        if (localFileHeader.getAesExtraDataRecord().isNone()) {
            throw ZipIOException("invalid aes extra data record")
        }

        let aesExtraDataRecord = localFileHeader.getAesExtraDataRecord().getOrThrow()

        let saltBytes = Array<Byte> (aesExtraDataRecord.getAesKeyStrength().getSaltLength(), repeat: 0)
        readRaw(saltBytes)
        return saltBytes
    }

    private func getPasswordVerifier(): Array<Byte> {
        let pvBytes: Array<Byte> = Array<Byte>(2, repeat: 0)
        readRaw(pvBytes)
        return pvBytes
    }

    private func incrementAesByteBlockPointer(incrementBy: Int64) {
        aes16ByteBlockPointer += incrementBy
        if (aes16ByteBlockPointer >= 15) {
            aes16ByteBlockPointer = 15
        }
    }

    private func decrementRemainingAesBytesLength(decrementBy: Int64) {
        remainingAes16ByteBlockLength -= decrementBy

        if (remainingAes16ByteBlockLength <= 0) {
            remainingAes16ByteBlockLength = 0
        }
    }
}
