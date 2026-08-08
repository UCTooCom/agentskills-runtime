/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model.enums
public enum AesKeyStrength <: Equatable<AesKeyStrength> {
    /**
     * 128-bit AES key length 
     */
    | KEY_STRENGTH_128

    /**
     * 192-bit AES key length 
     */
    | KEY_STRENGTH_192

    /**
     * 256-bit AES key length 
     */
    | KEY_STRENGTH_256

    public func getRawCode(): Int32 {
        return match(this){
            case KEY_STRENGTH_128 => 1
            case KEY_STRENGTH_192 => 2
            case KEY_STRENGTH_256 => 3
        }
    }

    public func getSaltLength(): Int64 {
        return match(this){
            case KEY_STRENGTH_128 => 8
            case KEY_STRENGTH_192 => 12
            case KEY_STRENGTH_256 => 16
        }
    }

    public func getMacLength(): Int64 {
        return match(this){
            case KEY_STRENGTH_128 => 16
            case KEY_STRENGTH_192 => 24
            case KEY_STRENGTH_256 => 32
        }
    }

    public func getKeyLength(): Int64 {
        return match(this){
            case KEY_STRENGTH_128 => 16
            case KEY_STRENGTH_192 => 24
            case KEY_STRENGTH_256 => 32
        }
    }

    public static func getAesKeyStrengthFromRawCode(code: Int32): ?AesKeyStrength {
        match (code) {
            case 1 => return KEY_STRENGTH_128
            case 2 => return KEY_STRENGTH_192
            case 3 => return KEY_STRENGTH_256
            case _ => return None
        }
    }

    public operator func ==(that: AesKeyStrength): Bool {
        match ((this, that)) {
            case (KEY_STRENGTH_128, KEY_STRENGTH_128) => true
            case (KEY_STRENGTH_192, KEY_STRENGTH_192) => true
            case (KEY_STRENGTH_256, KEY_STRENGTH_256) => true
            case _ => false
        }
    }

    public operator func !=(that: AesKeyStrength): Bool {
        !(this == that)
    }
}
