/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto.PBKDF2

import std.convert.*

class PBKDF2HexFormatter {

    public func fromString(p: PBKDF2Parameters, s: String): Bool {

        let pSplit = s.split(":")
        if (pSplit.size != 3) {
            return true
        }

        let salt = BinTools.hex2bin(pSplit[0])
        var iterationCount = Int32.parse(pSplit[1])
        let bDK = BinTools.hex2bin(pSplit[2])

        p.setSalt(salt)
        p.setIterationCount(iterationCount)
        p.setDerivedKey(bDK)
        return false
    }

    public func toString(p: PBKDF2Parameters): String {
        return "${BinTools.bin2hex(p.getSalt())}:${p.getIterationCount()}:${BinTools.bin2hex(p.getDerivedKey().getOrThrow())}"
    }

}