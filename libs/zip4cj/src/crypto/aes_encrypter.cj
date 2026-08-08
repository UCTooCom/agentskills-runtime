/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto
import std.unittest.prop_test.RandomSource

let random: SecureRandom = SecureRandom()

@OverflowWrapping
func generateSalt(size: Int64): Array<Byte> {

    if (size != 8 && size != 16) {
        throw ZipException("invalid salt size, cannot generate salt")
    }

    var rounds = 0

    if (size == 8) {
        rounds = 2
    } else {
        rounds = 4
    }

    let salt: Array<Byte> = Array<Byte>(size, repeat: 0)
    for (j in 0..rounds) {
        let i = random.nextInt32()
        salt[j * 4] =  UInt8((i >> 24) & 0xff)
        salt[1 + j * 4] = UInt8((i >> 16) & 0xff)
        salt[2 + j * 4] = UInt8((i >> 8) & 0xff)
        salt[3 + j * 4] = UInt8(i & 0xff)
    }
    return salt
}

/**
 * AES Encrypter supports AE-1 and AE-2 encryption using AES-CTR with either 128 or 256 Key Strength
 */
public class AESEncrypter <: Encrypter {

    private var aesEngine: AESEngine
    private var mac: MacBasedPRF
    private var finished: Bool
    private var nonce = 1
    private var loopCount = 0

    private let iv: Array<Byte>
    private let counterBlock: Array<Byte>
    private var derivedPasswordVerifier: Array<Byte>
    private var saltBytes: Array<Byte>

    public AESEncrypter(password: Array<Rune>, aesKeyStrength: AesKeyStrength, useUtf8ForPassword: Bool) {
        if (password.size == 0) {
            throw ZipException("input password is empty or null")
        }
        if (aesKeyStrength != AesKeyStrength.KEY_STRENGTH_128 &&
                aesKeyStrength != AesKeyStrength.KEY_STRENGTH_256) {
            throw ZipException("Invalid AES key strength")
        }

        this.finished = false
        this.counterBlock = Array<Byte>(InternalZipConstants.AES_BLOCK_SIZE, repeat: 0)
        this.iv = Array<Byte>(InternalZipConstants.AES_BLOCK_SIZE, repeat: 0)
        this.saltBytes = generateSalt(aesKeyStrength.getSaltLength())
        let derivedKey: Array<Byte> = AesCipherUtil.derivePasswordBasedKey(saltBytes, password, aesKeyStrength, useUtf8ForPassword)
        this.derivedPasswordVerifier = AesCipherUtil.derivePasswordVerifier(derivedKey, aesKeyStrength)
        this.aesEngine = AesCipherUtil.getAESEngine(derivedKey, aesKeyStrength)
        this.mac = AesCipherUtil.getMacBasedPRF(derivedKey, aesKeyStrength)
    }

    // public func encryptData(buff: Array<Byte>, start: Int64, len: Int64): Int64 { 
    //     encryptData(buff[start..start+len])
    // }
    public func encryptData(buff: Array<Byte>): Int64 {

        let len = buff.size
        let start = 0
        if (finished) {
            // A non 16 byte block has already been passed to encrypter
            // non 16 byte block should be the last block of compressed data in AES encryption
            // any more encryption will lead to corruption of data
            throw ZipException("AES Encrypter is in finished state (A non 16 byte block has already been passed to encrypter)")
        }

        if (len % 16 != 0) {
            this.finished = true
        }

        var j = start
        while (j < (start + len)) {
            loopCount = if (j + InternalZipConstants.AES_BLOCK_SIZE <= (start + len)) {
                InternalZipConstants.AES_BLOCK_SIZE
            } else {
                ((start + len) - j)
            }
            AesCipherUtil.prepareBuffAESIVBytes(iv, nonce)
            aesEngine.processBlock(iv, counterBlock)
            for (k in 0..loopCount) {
                buff[j + k] = UInt8(buff[j + k] ^ counterBlock[k])
            }
            mac.update(buff[j..j+loopCount])
            nonce++
            j += InternalZipConstants.AES_BLOCK_SIZE
        }
        return len
    }

    public func getFinalMac(): Array<Byte> {
        let macBytes: Array<Byte> = this.mac.doFinal()
        return macBytes[0..10]
    }

    public func getDerivedPasswordVerifier(): Array<Byte> {
        return derivedPasswordVerifier
    }

    public func getSaltBytes(): Array<Byte> {
        return saltBytes
    }
}
