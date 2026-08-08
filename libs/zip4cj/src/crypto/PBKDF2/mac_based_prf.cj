/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto.PBKDF2

@OverflowWrapping
func ccc (arr: Array<UInt8>) : Array<Int8> {
    let t = Array<Int8>(arr.size, repeat: 0)
    for (i in 0..arr.size) {
        t[i] = Int8(arr[i])
    }
    return t
}

public class MacBasedPRF <: PRF {
    private var mac: ?HMAC
    private let macAlgorithm: HashType
    private let macCache: ArrayList<Byte>

    public MacBasedPRF(macAlgorithm: HashType) {
        this.macAlgorithm = macAlgorithm
        this.mac = None
        this.macCache = ArrayList<Byte>(InternalZipConstants.BUFF_SIZE)
    }

    public override func doFinal(M: Array<Byte>): Array<Byte> {
        if (macCache.size > 0) {
            doMacUpdate(0)
        }
        let v = this.mac.getOrThrow()
        v.write(M)
        let arr = v.finish()
        v.reset()
        return arr
    }

    public func doFinal(): Array<Byte> {
        if (macCache.size > 0) {
            doMacUpdate(0)
        }
        let v = this.mac.getOrThrow()
        let arr = v.finish()
        v.reset()
        return arr
    }

    public func doFinal(numberOfBytesToPushbackForMac: Int64): Array<Byte> {
        if (macCache.size > 0) {
            doMacUpdate(numberOfBytesToPushbackForMac)
        }
        let v = this.mac.getOrThrow()
        let arr = v.finish()
        v.reset()
        return arr
    }

    public override func getHLen(): Int64 {
        if (let Some(v) <- this.mac) {
            return v.size
        } else {
            throw NoneValueException()
        }
    }

    public override func initialize(P: Array<Byte>): Unit {
        this.mac = HMAC(P, this.macAlgorithm)
    }

    public func update(u: Array<Byte>): Unit {
        if (this.macCache.size + u.size > InternalZipConstants.BUFF_SIZE) {
            this.doMacUpdate(0)
        }
        this.macCache.add(all: u)
    }

    private func doMacUpdate(numberOfBytesToPushBack: Int64): Unit {
        var macBytes = unsafe{this.macCache.getRawArray()[0..this.macCache.size]}
        let numberOfBytesToRead = macBytes.size - numberOfBytesToPushBack
        var updateLength: Int64

        var i: Int64 = 0
        while (i < numberOfBytesToRead) {
            updateLength = if ((i + InternalZipConstants.AES_BLOCK_SIZE) <= numberOfBytesToRead) {
                InternalZipConstants.AES_BLOCK_SIZE
            } else {
                numberOfBytesToRead - i
            } 
            this.mac?.write(macBytes[i..i+updateLength])
            i += InternalZipConstants.AES_BLOCK_SIZE
        }
        this.macCache.clear()
    }
}
