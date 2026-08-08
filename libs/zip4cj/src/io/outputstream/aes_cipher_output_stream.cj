/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

class AesCipherOutputStream <: CipherOutputStream<AESEncrypter> {

    private var pendingBuffer = Array<Byte>(InternalZipConstants.AES_BLOCK_SIZE, repeat: 0)
    private var pendingBufferLength = 0

    public init(outputStream: ZipEntryOutputStream,
                zipParameters: ZipParameters,
                password: ?Array<Rune>,
                useUtf8ForPassword: Bool){
        super(outputStream, zipParameters, password, useUtf8ForPassword)
        this.encrypter = initializeEncrypter(outputStream, zipParameters, password, useUtf8ForPassword)
    }

    protected override func initializeEncrypter(outputStream: OutputStream,
                                                zipParameters: ZipParameters,
                                                password: ?Array<Rune>,
                                                useUtf8ForPassword: Bool) : AESEncrypter {
        if (password.isNone()) {
            throw ZipException("input password is null")
        }
        let encrypter: AESEncrypter  = AESEncrypter(password.getOrThrow(), zipParameters.getAesKeyStrength(), useUtf8ForPassword)
        this.writeAesEncryptionHeaderData(encrypter)
        return encrypter
    }

    private func writeAesEncryptionHeaderData(encrypter: AESEncrypter): Unit{
        let saltBytes =encrypter.getSaltBytes()
        writeHeaders(saltBytes)
        let derivedPasswordVerifier = encrypter.getDerivedPasswordVerifier()
        writeHeaders(derivedPasswordVerifier)
    }

    public override func write(b: Array<Byte>): Unit {
        var off = 0
        var len = b.size
        if (len >= (InternalZipConstants.AES_BLOCK_SIZE - pendingBufferLength)) {
            b.copyTo(pendingBuffer, off, pendingBufferLength, (InternalZipConstants.AES_BLOCK_SIZE - pendingBufferLength))
            super.write(pendingBuffer)
            off = (InternalZipConstants.AES_BLOCK_SIZE - pendingBufferLength)
            len = len - off
            pendingBufferLength = 0
        } else {
            b.copyTo(pendingBuffer, off, pendingBufferLength, len)
            // System.arraycopy(b, off, pendingBuffer, pendingBufferLength, len)
            pendingBufferLength += len
            return
        }

        if (len != 0 && len % 16 != 0) {
            b.copyTo(pendingBuffer, (len + off) - (len % 16), 0, len % 16)
            // System.arraycopy(b, (len + off) - (len % 16), pendingBuffer, 0, len % 16)
            pendingBufferLength = len % 16
            len = len - pendingBufferLength
        }
        super.write(b[off..off+len])
    }

    public override func closeEntry(): Unit{
        if (this.pendingBufferLength != 0) {
            super.write(pendingBuffer[..pendingBufferLength])
            pendingBufferLength = 0
        }

        writeHeaders((getEncrypter() as AESEncrypter).getOrThrow().getFinalMac())
        super.closeEntry()
    }
}
