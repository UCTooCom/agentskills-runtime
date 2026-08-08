/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto

/**
 * AES Decrypter supports AE-1 and AE-2 decryption for AES-CTR with 128, 192, or 256 Key Strength
 */
public class AESDecrypter <: Decrypter {

    private var aesEngine: AESEngine
    private var mac: MacBasedPRF

    private var nonce: Int64 = 1
    private let iv: Array<Byte>
    private let counterBlock: Array<Byte>

    public AESDecrypter(aesExtraDataRecord: AESExtraDataRecord, password: Array<Rune>, salt: Array<Byte>,
                        passwordVerifier: Array<Byte>, useUtf8ForPassword: Bool) {
        this.iv = Array<Byte>(InternalZipConstants.AES_BLOCK_SIZE, repeat: 0)
        this.counterBlock = Array<Byte>(InternalZipConstants.AES_BLOCK_SIZE, repeat: 0)
        if (password.size <= 0) {
            throw ZipException("empty or null password provided for AES decryption", WRONG_PASSWORD)
        }

        let aesKeyStrength: AesKeyStrength  = aesExtraDataRecord.getAesKeyStrength()
        let derivedKey: Array<Byte> = AesCipherUtil.derivePasswordBasedKey(salt, password, aesKeyStrength, useUtf8ForPassword)
        let derivedPasswordVerifier: Array<Byte> = AesCipherUtil.derivePasswordVerifier(derivedKey, aesKeyStrength)
        if (passwordVerifier != derivedPasswordVerifier) {
            throw ZipException("Wrong Password", ZipExceptionType.WRONG_PASSWORD)
        }

        aesEngine = AesCipherUtil.getAESEngine(derivedKey, aesKeyStrength)
        mac = AesCipherUtil.getMacBasedPRF(derivedKey, aesKeyStrength)
    }

    // public override func decryptData(buff: Array<Byte>, start: Int64, len: Int64): Int64 {
    public override func decryptData(buff: Array<Byte>): Int64 {
        var j = 0
        let len = buff.size
        let start = 0
        while (j < (start + len)) {
            var loopCount: Int64 = if (j + InternalZipConstants.AES_BLOCK_SIZE <= (start + len)) {
                InternalZipConstants.AES_BLOCK_SIZE
            } else {
                ((start + len) - j)
            }
            mac.update(buff[j..j+loopCount])
            AesCipherUtil.prepareBuffAESIVBytes(iv, nonce)
            aesEngine.processBlock(iv, counterBlock)

            for (k in 0..loopCount) {
                buff[j + k] = UInt8(buff[j + k] ^ counterBlock[k])
            }
            nonce++
            j += InternalZipConstants.AES_BLOCK_SIZE
        }

        return len
    }

    public func getCalculatedAuthenticationBytes(numberOfBytesPushedBack: Int64): Array<Byte> {
        return mac.doFinal(numberOfBytesPushedBack)
    }
}
