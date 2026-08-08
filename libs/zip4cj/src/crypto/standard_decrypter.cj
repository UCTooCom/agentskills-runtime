/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto

public class StandardDecrypter <: Decrypter {
    private var zipCryptoEngine: ZipCryptoEngine

    @OverflowWrapping
    public init(
        password: ?Array<Rune>,
        crc: Int64,
        lastModifiedFileTime: Int64,
        headerBytes: Array<Byte>,
        useUtf8ForPassword: Bool
    ) {
        this.zipCryptoEngine = ZipCryptoEngine()
        if (password.isNone()) {
            throw ZipException("Wrong password!", ZipExceptionType.WRONG_PASSWORD)
        }

        zipCryptoEngine.initKeys(password.getOrThrow(), useUtf8ForPassword)

        var result = headerBytes[0]
        for (i in 0..InternalZipConstants.STD_DEC_HDR_SIZE) {
            if (i + 1 == InternalZipConstants.STD_DEC_HDR_SIZE) {
                let verificationByte = UInt8(result ^ zipCryptoEngine.decryptByte())
                if (verificationByte != UInt8(crc >> 24) && verificationByte != UInt8(lastModifiedFileTime >> 8)) {
                    throw ZipException("Wrong password!", ZipExceptionType.WRONG_PASSWORD)
                }
            }

            zipCryptoEngine.updateKeys(UInt8(result ^ zipCryptoEngine.decryptByte()))

            if (i + 1 != InternalZipConstants.STD_DEC_HDR_SIZE) {
                result = headerBytes[i + 1]
            }
        }
    }

    public func decryptData(buff: Array<Byte>): Int64 {
        for (i in 0..buff.size) {
            var val = UInt8(buff[i] & 0xff)
            val = UInt8((val ^ zipCryptoEngine.decryptByte()) & 0xff)
            zipCryptoEngine.updateKeys(val)
            buff[i] = val
        }
        return buff.size
    }
}
