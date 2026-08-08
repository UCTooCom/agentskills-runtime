/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto



public class AesCipherUtil {
    private static let START_INDEX: Int64 = 0

    /**
     * Derive Password-Based Key for AES according to AE-1 and AE-2 Specifications
     *
     * @param salt Salt used for PBKDF2
     * @param password Password used for PBKDF2 containing characters matching ISO-8859-1 character set
     * @param aesKeyStrength Requested AES Key and MAC Strength
     * @return Derived Password-Based Key
     * @throws ZipException Thrown when Derived Key is not valid
     */
    public static func derivePasswordBasedKey(salt: Array<Byte> , password: Array<Rune> ,
                                                aesKeyStrength: AesKeyStrength,
                                                useUtf8ForPassword: Bool) : Array<Byte> {
        let parameters: PBKDF2Parameters = PBKDF2Parameters(InternalZipConstants.AES_MAC_ALGORITHM, InternalZipConstants.AES_HASH_CHARSET, salt, InternalZipConstants.AES_HASH_ITERATIONS)
        let engine: PBKDF2Engine = PBKDF2Engine(parameters)

        let keyLength: Int64 = aesKeyStrength.getKeyLength()
        let macLength: Int64 = aesKeyStrength.getMacLength()
        let derivedKeyLength: Int64 = keyLength + macLength + InternalZipConstants.AES_PASSWORD_VERIFIER_LENGTH
        let derivedKey: Array<Byte> = engine.deriveKey(password, derivedKeyLength, useUtf8ForPassword)
        if (derivedKey.size == derivedKeyLength) {
            return derivedKey
        } else {
            throw ZipException("Derived Key invalid for Key Length [${keyLength}] MAC Length [${macLength}]")
        }
    }

    /**
     * Derive Password Verifier using Derived Key and requested AES Key Strength
     *
     * @param derivedKey Derived Key
     * @param aesKeyStrength AES Key Strength
     * @return Derived Password Verifier
     */
    public static func derivePasswordVerifier(derivedKey: Array<Byte>, aesKeyStrength: AesKeyStrength): Array<Byte> {
        let derivedPasswordVerifier: Array<Byte> = Array<Byte>(InternalZipConstants.AES_PASSWORD_VERIFIER_LENGTH, repeat: 0)
        let keyMacLength = aesKeyStrength.getKeyLength() + aesKeyStrength.getMacLength()
        derivedKey.copyTo(derivedPasswordVerifier, keyMacLength, START_INDEX, InternalZipConstants.AES_PASSWORD_VERIFIER_LENGTH)
        return derivedPasswordVerifier
    }

    /**
     * Get MAC-Based PRF using default HMAC Algorithm defined in AE-1 and AE-2 Specification
     *
     * @param derivedKey Derived Key
     * @param aesKeyStrength AES Key Strength
     * @return Initialized MAC-Based PRF
     */
    public static func getMacBasedPRF(derivedKey: Array<Byte>, aesKeyStrength: AesKeyStrength): MacBasedPRF {
        let macLength = aesKeyStrength.getMacLength()
        let macKey: Array<Byte> = Array<Byte>(macLength, repeat: 0)
        derivedKey.copyTo(macKey, aesKeyStrength.getKeyLength(), START_INDEX, macLength)
        let macBasedPRF: MacBasedPRF = MacBasedPRF(InternalZipConstants.AES_MAC_ALGORITHM)
        macBasedPRF.initialize(macKey)
        return macBasedPRF
    }

    /**
     * Get AES Engine using derived key and requested AES Key Strength
     *
     * @param derivedKey Derived Key
     * @param aesKeyStrength AES Key Strength
     * @return AES Engine configured with AES Key
     * @throws ZipException Thrown on AESEngine initialization failures
     */
    public static func getAESEngine(derivedKey: Array<Byte>, aesKeyStrength: AesKeyStrength): AESEngine {
        let keyLength: Int64 = aesKeyStrength.getKeyLength()
        let aesKey: Array<Byte> = Array<Byte>(keyLength, repeat: 0)
        derivedKey.copyTo(aesKey, START_INDEX, START_INDEX, keyLength)
        return AESEngine(aesKey)
    }

    @OverflowWrapping
    public static func prepareBuffAESIVBytes(buff: Array<Byte>, nonce: Int64): Unit {
        buff[0] = UInt8(nonce)
        buff[1] = UInt8(nonce >> 8)
        buff[2] = UInt8(nonce >> 16)
        buff[3] = UInt8(nonce >> 24)
        for (i in 4..=15) {
            buff[i] = 0
        }
    }

}
