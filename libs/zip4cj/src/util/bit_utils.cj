/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public class BitUtils {
    private init() {}
    
    @OverflowWrapping
    public static func isBitSet(b: Byte, pos: Int64): Bool {
        let t = abs(pos)
        return if (t < 64) {
            (Int64(b) & (1 << t))
        } else {
            (Int64(b) & 
            (1 << (t & 63)))
        } != 0
    }

    @OverflowWrapping
    public static func setBit(b: Byte, pos: Int64): Byte {
        let t = abs(pos)
        if (t < 64) {
            (b | UInt8(1 << t))
        } else {
            (b | UInt8(1 << (t & 63)))
        }
    }

    @OverflowWrapping
    public static func unsetBit(b: Byte, pos: Int64): Byte {
        let t = abs(pos)
        if (t < 64) {
            (b & !(1 << t))
        } else {
            (b & !(1 << (t & 63)))
        }
    }
}
