/*
 * Copyright 2010 The Go Authors. All rights reserved.
 *
 * Portions of this file are derived from golang.org/x/crypto/blowfish,
 * which is licensed under a BSD-style license.
 * The original license can be found in the LICENSE.BSD file in this repository.
 *
 * Copyright 2025 Dacec
 *
 * The remainder of this file, and the project as a whole (unless otherwise noted),
 * is licensed under the MIT License.
 * The full MIT License text can be found in the LICENSE.MIT file in this repository.
 */
package blowfish

import std.crypto.cipher.BlockCipher

public class Blowfish <: BlockCipher {
    private let _cs: CipherState

    // 异常: KeySizeException
    public init(key: Array<Byte>) {
        let size = key.size
        if (size < 1 || size > 56) {
            throw KeySizeException(size)
        }
        this._cs = CipherState()
        expandKey(key, this._cs)
    }

    // 异常: KeySizeException
    public init(key: Array<Byte>, salt: Array<Byte>) {
        if (salt.isEmpty()) {
            let size = key.size
            if (size < 1 || size > 56) {
                throw KeySizeException(size)
            }
            this._cs = CipherState()
            expandKey(key, this._cs)
        } else {
            let size = key.size
            if (size < 1) {
                throw KeySizeException(size)
            }
            this._cs = CipherState()
            expandKeyWithSalt(key, salt, _cs)
        }
    }

    public prop blockSize: Int64 {
        get() {
            8
        }
    }

    public prop algorithm: String {
        get() {
            "blowfish"
        }
    }

    // 异常: IllegalArgumentException
    public func encrypt(input: Array<Byte>): Array<Byte> {
        if (input.size != 8) {
            throw IllegalArgumentException("Input block size must be 8 bytes")
        }
        var output = Array<Byte>(8, repeat: 0)
        encryptBytes(input, output)
        output
    }

    // 异常: IllegalArgumentException
    public func decrypt(input: Array<Byte>): Array<Byte> {
        if (input.size != 8) {
            throw IllegalArgumentException("Input block size must be 8 bytes")
        }
        var output = Array<Byte>(8, repeat: 0)
        decryptBytes(input, output)
        output
    }

    // 异常: IllegalArgumentException
    public func encrypt(input: Array<Byte>, to!: Array<Byte>): Int64 {
        if (input.size != 8 || to.size != 8) {
            throw IllegalArgumentException("Input and output block size must be 8 bytes")
        }
        encryptBytes(input, to)
    }

    // 异常: IllegalArgumentException
    public func decrypt(input: Array<Byte>, to!: Array<Byte>): Int64 {
        if (input.size != 8 || to.size != 8) {
            throw IllegalArgumentException("Input and output block size must be 8 bytes")
        }

        decryptBytes(input, to)
    }

    public static func expandKey(key: Array<Byte>, cs: CipherState): Unit {
        let jKey = Box<Int64>(0)
        for (i in 0..18) {
            cs.p[i] ^= getNextWord(key, jKey)
        }

        var l = 0u32
        var r = 0u32
        for (i in 0..18 : 2) {
            (l, r) = encryptBlock(l, r, cs)
            (cs.p[i], cs.p[i + 1]) = (l, r)
        }

        for (i in 0..256 : 2) {
            (l, r) = encryptBlock(l, r, cs)
            (cs.s0[i], cs.s0[i + 1]) = (l, r)
        }
        for (i in 0..256 : 2) {
            (l, r) = encryptBlock(l, r, cs)
            (cs.s1[i], cs.s1[i + 1]) = (l, r)
        }
        for (i in 0..256 : 2) {
            (l, r) = encryptBlock(l, r, cs)
            (cs.s2[i], cs.s2[i + 1]) = (l, r)
        }
        for (i in 0..256 : 2) {
            (l, r) = encryptBlock(l, r, cs)
            (cs.s3[i], cs.s3[i + 1]) = (l, r)
        }
    }

    public static func expandKeyWithSalt(key: Array<Byte>, salt: Array<Byte>, cs: CipherState): Unit {
        let jKey = Box<Int64>(0)
        for (i in 0..18) {
            cs.p[i] ^= getNextWord(key, jKey)
        }

        let jSalt = Box<Int64>(0)
        var l = 0u32
        var r = 0u32
        for (i in 0..18 : 2) {
            l ^= getNextWord(salt, jSalt)
            r ^= getNextWord(salt, jSalt)
            (l, r) = encryptBlock(l, r, cs)
            (cs.p[i], cs.p[i + 1]) = (l, r)
        }

        for (i in 0..256 : 2) {
            l ^= getNextWord(salt, jSalt)
            r ^= getNextWord(salt, jSalt)
            (l, r) = encryptBlock(l, r, cs)
            (cs.s0[i], cs.s0[i + 1]) = (l, r)
        }

        for (i in 0..256 : 2) {
            l ^= getNextWord(salt, jSalt)
            r ^= getNextWord(salt, jSalt)
            (l, r) = encryptBlock(l, r, cs)
            (cs.s1[i], cs.s1[i + 1]) = (l, r)
        }

        for (i in 0..256 : 2) {
            l ^= getNextWord(salt, jSalt)
            r ^= getNextWord(salt, jSalt)
            (l, r) = encryptBlock(l, r, cs)
            (cs.s2[i], cs.s2[i + 1]) = (l, r)
        }

        for (i in 0..256 : 2) {
            l ^= getNextWord(salt, jSalt)
            r ^= getNextWord(salt, jSalt)
            (l, r) = encryptBlock(l, r, cs)
            (cs.s3[i], cs.s3[i + 1]) = (l, r)
        }
    }

    @OverflowWrapping
    private static func encryptBlock(l: UInt32, r: UInt32, cs: CipherState): (UInt32, UInt32) {
        var (xl, xr) = (l, r)
        xl ^= cs.p[0]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[1]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[2]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[3]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[4]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[5]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[6]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[7]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[8]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[9]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[10]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[11]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[12]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[13]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[14]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[15]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[16]
        xr ^= cs.p[17]
        (xr, xl)
    }

    @OverflowWrapping
    private static func decryptBlock(l: UInt32, r: UInt32, cs: CipherState): (UInt32, UInt32) {
        var (xl, xr) = (l, r)
        xl ^= cs.p[17]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[16]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[15]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[14]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[13]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[12]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[11]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[10]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[9]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[8]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[7]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[6]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[5]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[4]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[3]
        xr ^= ((cs.s0[Int64(UInt8(xl >> 24))] + cs.s1[Int64(UInt8(xl >> 16))]) ^ cs.s2[Int64(UInt8(xl >> 8))]) + cs
            .s3[Int64(UInt8(xl))] ^ cs.p[2]
        xl ^= ((cs.s0[Int64(UInt8(xr >> 24))] + cs.s1[Int64(UInt8(xr >> 16))]) ^ cs.s2[Int64(UInt8(xr >> 8))]) + cs
            .s3[Int64(UInt8(xr))] ^ cs.p[1]
        xr ^= cs.p[0]
        (xr, xl)
    }

    @OverflowWrapping
    private func encryptBytes(input: Array<Byte>, to: Array<Byte>): Int64 {
        let l = (UInt32(input[0]) << 24) | (UInt32(input[1]) << 16) | (UInt32(input[2]) << 8) | UInt32(input[3])
        let r = (UInt32(input[4]) << 24) | (UInt32(input[5]) << 16) | (UInt32(input[6]) << 8) | UInt32(input[7])

        var (encryptedL, encryptedR) = encryptBlock(l, r, _cs)

        to[0] = UInt8(encryptedL >> 24)
        to[1] = UInt8(encryptedL >> 16)
        to[2] = UInt8(encryptedL >> 8)
        to[3] = UInt8(encryptedL)
        to[4] = UInt8(encryptedR >> 24)
        to[5] = UInt8(encryptedR >> 16)
        to[6] = UInt8(encryptedR >> 8)
        to[7] = UInt8(encryptedR)

        8
    }

    @OverflowWrapping
    private func decryptBytes(input: Array<Byte>, to: Array<Byte>): Int64 {
        let l = (UInt32(input[0]) << 24) | (UInt32(input[1]) << 16) | (UInt32(input[2]) << 8) | UInt32(input[3])
        let r = (UInt32(input[4]) << 24) | (UInt32(input[5]) << 16) | (UInt32(input[6]) << 8) | UInt32(input[7])

        var (decryptedL, decryptedR) = decryptBlock(l, r, _cs)

        to[0] = UInt8(decryptedL >> 24)
        to[1] = UInt8(decryptedL >> 16)
        to[2] = UInt8(decryptedL >> 8)
        to[3] = UInt8(decryptedL)
        to[4] = UInt8(decryptedR >> 24)
        to[5] = UInt8(decryptedR >> 16)
        to[6] = UInt8(decryptedR >> 8)
        to[7] = UInt8(decryptedR)

        8
    }
}

public class CipherState {
    var p: VArray<UInt32, $18>
    var s0: VArray<UInt32, $256>
    var s1: VArray<UInt32, $256>
    var s2: VArray<UInt32, $256>
    var s3: VArray<UInt32, $256>

    public init() {
        this.p = P
        this.s0 = S0
        this.s1 = S1
        this.s2 = S2
        this.s3 = S3
    }
}
