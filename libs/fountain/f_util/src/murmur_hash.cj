/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_util

import std.convert.*
import std.math.numeric.BigInt
import std.overflow.WrappingOp
import stdx.encoding.hex.*
import f_base.UnsafeBytes
import f_base.*
import f_util.exception.MurmurHashException

let MURMUR_HASH_MASK = 0xc6a4a7935bd1e995_u64.
toInt()

/**
 * 计算给定字节数组的MurmurHash64哈希值
 * 
 * @param data 要计算哈希的字节数组
 * @param seed 哈希种子值，默认为0x1234567890ABCDEF
 * @return 计算得到的64位MurmurHash值
 * 
 * @note 此实现使用MurmurHash64算法，适用于非加密用途的哈希计算
 * @see 参考MurmurHash算法规范
 */
public func murmurHash64(data: Array<Byte>, seed!: Int64 = 0x1234567890ABCDEF): Int64 {
    let length = data.size
    func getLong(buf: Array<Byte>, cur: Int64): (Int64, Int64) {
        var k = 0
        var i = cur
        do {
            k = (k << 8) | Int64(buf[i])
            i++
        } while (i < length && i % 8 != 0)
        return (k, i)
    }
    let m = MURMUR_HASH_MASK
    let r = 47

    var h = seed ^ (length.wrappingMul(m))
    var k: Int64
    var i = 0
    while (length - i >= 8) {
        let tpl = getLong(data, i)
        k = tpl[0]
        i = tpl[1]
        k = k.wrappingMul(m)
        k ^= k >> r
        k = k.wrappingMul(m)

        h ^= k
        h = k.wrappingMul(m)
    }

    if (length - i > 0) {
        h ^= getLong(data, i)[0]
        h = h.wrappingMul(m)
    }

    h ^= h >> r
    h = h.wrappingMul(m)
    h ^= h >> r

    return h
}

public func murmurHash64(data: String, seed!: Int64 = 0x1234567890ABCDEF): Int64 {
    murmurHash64(data.unsafeBytes(), seed: seed)
}
public struct MurmurHash128X64 <: Hashable & Comparable<MurmurHash128X64> & ToString {
    private let h: Int64
    MurmurHash128X64(private let one: Int64, private let two: Int64){
        h = one ^ two
    }
    
    public func hashCode(){
        h
    }
    public func compare(other: MurmurHash128X64): Ordering {
        let cmp = this.one.compare(other.one)
        if(cmp == EQ){
            this.two.compare(other.two)
        }else{
            cmp
        }
    }
    public func toBytes(): Array<Byte> {
        func to(x: Int64, a: Int64){
            UInt8((x >> (a * 8)) & 0xffi64)
        }
        Array<Byte>(16){i =>
            if(i < 8){
                to(one, 7 - i)
            }else{
                to(two, 15 - i)
            }
        }
    }
    public func toBigInt(): BigInt {
        BigInt(true, toBytes())
    }
    public func toString(): String {
        toHexString(toBytes())
    }
    public static func parse(s: String): MurmurHash128X64 {
        parse(fromHexString(s) ?? [])
    }
    public static func parse(bytes: Array<Byte>): MurmurHash128X64 {
        if(bytes.size != 16){
            throw MurmurHashException('size of byte array must be 16, but ${bytes}')
        }
        var (one, two) = (0, 0)
        for(i in 0 .. 16){
            let b = bytes[i]
            if(i < 8){
                one = (one << 8) | Int64(b)
            }else{
                two = (two << 8) | Int64(b)
            }
        }
        MurmurHash128X64(one, two)
    }
}
/**
 * 计算给定字节数组的128位MurmurHash3哈希值(x64变体)
 * 
 * @param data 要计算哈希的字节数组
 * @param seed 可选的种子值，默认为0x1234567890ABCDEF
 * @return 包含两个64位哈希值的MurmurHash128X64结构体
 * 
 * 算法特点：
 * - 使用MurmurHash3算法的128位x64变体
 * - 处理输入数据为16字节的块
 * - 对剩余字节进行特殊处理
 * - 使用多个混合常量(C1, C2)和旋转操作(R1, R2, R3)
 * - 包含最终的混合步骤(fmix64)
 * 
 * 注意：
 * - 结果由两个64位整数组成，表示128位哈希值
 * - 默认种子为0x1234567890ABCDEF
 */
@OverflowWrapping
public func murmurHash128X64(data: Array<Byte>, seed!: Int64 = 0x1234567890ABCDEF): MurmurHash128X64 {
    // Constants for 128-bit variant
    let C1 = 0x87c37b91114253d5u64.toInt()
    const C2 = 0x4cf5ad432745937f
    const R1 = 31
    const R2 = 27
    const R3 = 33
    const M = 5
    const N1 = 0x52dce729
    const N2 = 0x38495ab5
    func getLittleEndianLong(data: Array<Byte>, index: Int64) {
        ((Int64(data[index    ]) & 0xff)      ) |
        ((Int64(data[index + 1]) & 0xff) <<  8) |
        ((Int64(data[index + 2]) & 0xff) << 16) |
        ((Int64(data[index + 3]) & 0xff) << 24) |
        ((Int64(data[index + 4]) & 0xff) << 32) |
        ((Int64(data[index + 5]) & 0xff) << 40) |
        ((Int64(data[index + 6]) & 0xff) << 48) |
        ((Int64(data[index + 7]) & 0xff) << 56)
    }
    func rotateLeft(i: Int64, distance: Int64) {
        return (i << distance) | (i >> (64 - distance))
    }
    func fmix64(hash: Int64) {
        var h = hash
        h ^= h >> 33
        h *= 0xff51afd7ed558ccdu64.toInt()
        h ^= h >> 33
        h *= 0xc4ceb9fe1a85ec53u64.toInt()
        h ^= h >> 33
        h
    }
    var h1 = seed
    var h2 = seed
    let length = data.size
    let nblocks = length >> 4
    for(i in 0 .. nblocks){
        let index = i << 4
        var k1 = getLittleEndianLong(data, index)
        var k2 = getLittleEndianLong(data, index + 8)

        k1 *= C1
        k1 = rotateLeft(k1, R1)
        k1 *= C2
        h1 ^= k1
        h1 = rotateLeft(h1, R2)
        h1 += h2
        h1 = h1 * M + N1

        k2 *= C2;
        k2 = rotateLeft(k2, R3)
        k2 *= C1
        h2 ^= k2
        h2 = rotateLeft(h2, R1)
        h2 += h1
        h2 = h2 * M + N2
    }
    var k1 = 0
    var k2 = 0
    let index = nblocks << 4
    let remainder = length - index
    var matched = false
    if(remainder == 15){
        matched = true
        k2 ^= (Int64(data[index + 14]) & 0xff) << 48
    }
    if(matched || remainder == 14){
        matched = true
        k2 ^= (Int64(data[index + 13]) & 0xff) << 40
    }
    if(matched || remainder == 13){
        matched = true
        k2 ^= (Int64(data[index + 12]) & 0xff) << 32
    }
    if(matched || remainder == 12){
        matched = true
        k2 ^= (Int64(data[index + 11]) & 0xff) << 24
    }
    if(matched || remainder == 11){
        matched = true
        k2 ^= (Int64(data[index + 10]) & 0xff) << 16
    }
    if(matched || remainder == 10){
        matched = true
        k2 ^= (Int64(data[index + 9]) & 0xff) << 8
    }
    if(matched || remainder == 9){
        matched = true
        k2 ^= Int64(data[index + 8]) & 0xff
        k2 *= C2
        k2 = rotateLeft(k2, R3)
        k2 *= C1
        h2 ^= k2
    }
    if(matched || remainder == 8){
        matched = true
        k1 ^= (Int64(data[index + 7]) & 0xff) << 56
    }
    if(matched || remainder == 7){
        matched = true
        k1 ^= (Int64(data[index + 6]) & 0xff) << 48
    }
    if(matched || remainder == 6){
        matched = true
        k1 ^= (Int64(data[index + 5]) & 0xff) << 40
    }
    if(matched || remainder == 5){
        matched = true
        k1 ^= (Int64(data[index + 4]) & 0xff) << 32
    }
    if(matched || remainder == 4){
        matched = true
        k1 ^= (Int64(data[index + 3]) & 0xff) << 24
    }
    if(matched || remainder == 3){
        matched = true
        k1 ^= (Int64(data[index + 2]) & 0xff) << 16
    }
    if(matched || remainder == 2){
        matched = true
        k1 ^= (Int64(data[index + 1]) & 0xff) << 8
    }
    if(matched || remainder == 1){
        matched = true
        k1 ^= Int64(data[index]) & 0xff
        k1 *= C1
        k1 = rotateLeft(k1, R1)
        k1 *= C2
        h1 ^= k1
    }
    h1 ^= length
    h2 ^= length

    h1 += h2
    h2 += h1

    h1 = fmix64(h1)
    h2 = fmix64(h2)

    h1 += h2
    h2 += h1
    MurmurHash128X64(h1, h2)
}

public func murmurHash128X64(data: String, seed!: Int64 = 0x1234567890ABCDEF): MurmurHash128X64 {
    murmurHash128X64(data.unsafeBytes(), seed: seed)
}