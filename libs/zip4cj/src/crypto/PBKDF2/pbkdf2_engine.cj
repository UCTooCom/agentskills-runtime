/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto.PBKDF2

public class PBKDF2Engine {
    private var parameters: PBKDF2Parameters

    private var prf: ?PRF

    public init(parameters: PBKDF2Parameters) {
        this(parameters, None)
    }

    public init(parameters: PBKDF2Parameters, prf: ?PRF) {
        this.parameters = parameters
        this.prf = prf
    }

    public func deriveKey(inputPassword: Array<Rune>, dkLen: Int64, useUtf8ForPassword: Bool): Array<Byte> {
        var p: Array<Byte> = Zip4cjUtil.convertCharArrayToByteArray(inputPassword, useUtf8ForPassword)
        
        assertPRF(p)
        var dklength = dkLen
        if (dklength == 0) {
            dklength = prf.getOrThrow().getHLen()
        }
        return PBKDF2(prf.getOrThrow(), parameters.getSalt(), parameters.getIterationCount(), dkLen)
    } 

    private func assertPRF(P: Array<Byte>): Unit {
        if (prf.isNone()) {
            prf = MacBasedPRF(parameters.getHashAlgorithm())
        }
        this.prf?.initialize(P)
    }

    private func PBKDF2(prf: PRF, S: Array<Byte>, c: Int32, dkLen: Int64): Array<Byte> {
        var hLen = prf.getHLen()
        var l = ceil(dkLen, hLen)
        var r = dkLen - (l - 1) * hLen
        var T = Array<Byte>(Int64(l * hLen), repeat: 0)
        var ti_offset: Int64 = 0
        for (i in 1..=l) {
            _F(T, ti_offset, prf, S, c, i)
            ti_offset += hLen
        }
        if (r < hLen) {
            // Incomplete last block
            let DK = Array<Byte>(dkLen, repeat: 0)
            T.copyTo(DK, 0, 0, dkLen)
            return DK
        }
        return T
    }

    private func ceil(a: Int64, b: Int64): Int64 {
        var m: Int64 = 0
        if (a % b > 0) {
            m = 1
        }
        return a / b + m
    }

    private func _F(dest: Array<Byte>, offset: Int64, prf: PRF, S: Array<Byte>, c: Int32, blockIndex: Int64): Unit {
        var hLen = prf.getHLen()
        var U_r = Array<Byte> (Int64(hLen), repeat: 0)

        // U0 = S || INT (i)
        var U_i = Array<Byte>(S.size + 4, repeat: 0)
        S.copyTo(U_i, 0, 0, S.size)
        
        INT(U_i, S.size, blockIndex)

        for (_ in 0..c) {
            U_i = prf.doFinal(U_i)
            xor(U_r, U_i)
        }
        U_r.copyTo(dest, 0, offset, hLen)
    }

    private func xor(dest: Array<Byte>, src: Array<Byte>): Unit {
        for (i in 0..dest.size) {
            dest[i] ^= src[i]
        }
    }

    @OverflowWrapping
    protected func INT(dest: Array<Byte>, offset: Int64, i: Int64): Unit {
        dest[offset] = UInt8(i / (256 * 256 * 256))
        dest[offset + 1] = UInt8(i / (256 * 256))
        dest[offset + 2] = UInt8(i / (256))
        dest[offset + 3] = UInt8(i)
    }

    public func getParameters(): PBKDF2Parameters {
        return parameters
    }

    public func setParameters(parameters: PBKDF2Parameters): Unit {
        this.parameters = parameters
    }

    public func setPseudoRandomFunction(prf: PRF): Unit {
        this.prf = prf
    }
}
