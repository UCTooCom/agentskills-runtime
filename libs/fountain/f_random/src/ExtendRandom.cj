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
package f_random

import std.math.floor
public import std.random.Random
public import stdx.crypto.crypto.SecureRandom

public interface ExtendRandom<R> where R <: ExtendRandom<R> {
    func nextFloat64(): Float64
    func nextFloat32(): Float32
    func nextFloat64(min: Float64, max: Float64, closed!: Bool): Float64
    func nextFloat32(min: Float32, max: Float32, closed!: Bool): Float32
    func nextInt64(min: Int64, max: Int64, closed!: Bool): Int64
    func nextUInt64(min: UInt64, max: UInt64, closed!: Bool): UInt64
    func nextInt32(min: Int32, max: Int32, closed!: Bool): Int32
    func nextUInt32(min: UInt32, max: UInt32, closed!: Bool): UInt32
}

/*
   生成指定范围内的随机数是一个常用的操作

   首先弄明白Math.random()函数，这个函数默认会返回一个大于等于0但小于1的值[0,1)
   如果想要生成0~X之间的随机数(不包括X)，只需要将Math.random()返回值乘上X，那么范围就是[0,X)
   仔细想想，其实上一步乘的步骤可以看做是放大random函数的值域，因此实际上是乘上(X - 0)，也就是上界减下界
   在上一步可以知道如果想要获得一个范围的随机数，首先需要放大random函数的值域，如果要获得[a,b]范围内的随机数，需要
   放大值域，Math.random()*(b-a)但是这里出现了一个问题
   当a为0时，函数返回[0,b)之间的数，结果中不包括b
   当a不为0时，函数返回[0,b-a)之间的数，结果中不包括b，此时需要改为Maht.random()*(b-a)+a ,范围变为[a,b)
   如果限制加大，仅限整数，可以使用floor函数，已知Math.random()X返回[0,X),那么Math.random()X+1返回[0,x+1)，
   再进行下取整并加上下界Math.floor(Math.random() * (max - min + 1) + min) 就可以获得[min,max]的整数
   如果不加这个限制，那么目前函数没有直接的方法，可以通过仅对超过max的部分下取整来解决
 */
extend Random <: ExtendRandom<Random> {
    public func nextFloat64(min: Float64, max: Float64, closed!: Bool = false): Float64{
        nextFloat64() * (max - min + if (closed) {
            1.0
        } else {
            0.0
        }) + min
    }
    public func nextFloat32(min: Float32, max: Float32, closed!: Bool = false): Float32 {
        nextFloat32() * (max - min + if (closed) {
            1.0
        } else {
            0.0
        }) + min
    }
    public func nextInt64(min: Int64, max: Int64, closed!: Bool = false): Int64 {
        return Int64(floor(nextFloat64(Float64(min), Float64(max), closed: closed)))
    }
    public func nextUInt64(min: UInt64, max: UInt64, closed!: Bool = false): UInt64 {
        return UInt64(floor(nextFloat64(Float64(min), Float64(max), closed: closed)))
    }
    public func nextInt32(min: Int32, max: Int32, closed!: Bool = false): Int32 {
        return Int32(floor(nextFloat32(Float32(min), Float32(max), closed: closed)))
    }
    public func nextUInt32(min: UInt32, max: UInt32, closed!: Bool = false): UInt32 {
        return UInt32(floor(nextFloat32(Float32(min), Float32(max), closed: closed)))
    }
}

extend SecureRandom <: ExtendRandom<SecureRandom> {
    public func nextFloat64(min: Float64, max: Float64, closed!: Bool = false): Float64{
        nextFloat64() * (max - min + if (closed) {
            1.0
        } else {
            0.0
        }) + min
    }
    public func nextFloat32(min: Float32, max: Float32, closed!: Bool = false): Float32 {
        nextFloat32() * (max - min + if (closed) {
            1.0
        } else {
            0.0
        }) + min
    }
    public func nextInt64(min: Int64, max: Int64, closed!: Bool = false): Int64 {
        return Int64(floor(nextFloat64(Float64(min), Float64(max), closed: closed)))
    }
    public func nextUInt64(min: UInt64, max: UInt64, closed!: Bool = false): UInt64 {
        return UInt64(floor(nextFloat64(Float64(min), Float64(max), closed: closed)))
    }
    public func nextInt32(min: Int32, max: Int32, closed!: Bool = false): Int32 {
        return Int32(floor(nextFloat32(Float32(min), Float32(max), closed: closed)))
    }
    public func nextUInt32(min: UInt32, max: UInt32, closed!: Bool = false): UInt32 {
        return UInt32(floor(nextFloat32(Float32(min), Float32(max), closed: closed)))
    }
}

public interface BaseRandom<R> where R <: BaseRandom<R> {
    /**
     * 获取一个布尔类型的随机数，获取失败会抛异常
     * 返回值 Bool - 一个布尔类型的随机数
     */
    func nextBool(): Bool

    /**
     * 获取一个 UInt8 类型的随机数，获取失败会抛异常
     * 返回值 UInt8 - 一个 UInt8 类型的随机数
     */
    func nextUInt8(): UInt8

    /**
     * 获取一个 UInt16 类型的随机数，获取失败会抛异常
     * 返回值 UInt16 - 一个 UInt16 类型的随机数
     */
    func nextUInt16(): UInt16

    /**
     * 获取一个 UInt32 类型的随机数，获取失败会抛异常
     * 返回值 UInt32 - 一个 UInt32 类型的随机数
     */
    func nextUInt32(): UInt32

    /**
     * 获取一个 UInt64 类型的随机数，获取失败会抛异常
     * 返回值 UInt64 - 一个 UInt64 类型的随机数
     */
    func nextUInt64(): UInt64

    /**
     * 获取一个 Int8 类型的随机数，获取失败会抛异常
     * 返回值 Int8 - 一个 Int8 类型的随机数
     */
    func nextInt8(): Int8

    /**
     * 获取一个 Int16 类型的随机数，获取失败会抛异常
     * 返回值 Int16 - 一个 Int16 类型的随机数
     */
    func nextInt16(): Int16

    /**
     * 获取一个 Int32 类型的随机数，获取失败会抛异常
     * 返回值 Int32 - 一个 Int32 类型的随机数
     */
    func nextInt32(): Int32

    /**
     * 获取一个 Int64 类型的随机数，获取失败会抛异常
     * 返回值 Int64 - 一个 Int64 类型的随机数
     */
    func nextInt64(): Int64

    /**
     * 获取一个 UInt8 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 UInt8 - 一个 UInt8 类型的随机数
     */
    func nextUInt8(max: UInt8): UInt8

    /**
     * 获取一个 UInt16 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
             414
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 UInt16 - 一个 UInt16 类型的随机数
     */
    func nextUInt16(max: UInt16): UInt16

    /**
     * 获取一个 UInt32 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 UInt32 - 一个 UInt32 类型的随机数
     */
    func nextUInt32(max: UInt32): UInt32

    /**
     * 获取一个 UInt64 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 UInt64 - 一个 UInt64 类型的随机数
     */
    func nextUInt64(max: UInt64): UInt64

    /**
     * 获取一个 Int8 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 Int8 - 一个 Int8 类型的随机数
     */
    func nextInt8(max: Int8): Int8

    /**
     * 获取一个 Int16 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 Int16 - 一个 Int16 类型的随机数
     */
    func nextInt16(max: Int16): Int16

    /**
     * 获取一个 Int32 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 Int32 - 一个 Int32 类型的随机数
     */
    func nextInt32(max: Int32): Int32

    /**
     * 获取一个 Int64 类型且在区间 [0, max) 内的随机数，获取失败会抛异常
     * 参数 max - 区间最大值， max <= 0 会抛出参数非法异常
     * 返回值 Int64 - 一个 Int64 类型的随机数
     */
    func nextInt64(max: Int64): Int64

    /**
     * 获取一个 Float16 类型的随机数，范围在 0.0 到 1.0 之间，获取失败会抛异常
     * 返回值 Float16 - 一个 Float16 类型的随机数
     */
    func nextFloat16(): Float16

    /**
     * 获取一个 Float32 类型的随机数，范围在 0.0 到 1.0 之间，获取失败会抛异常
     * 返回值 Float32 - 一个 Float32 类型的随机数
     */
    func nextFloat32(): Float32

    /**
     * 获取一个 Float64 类型的随机数，范围在 0.0 到 1.0 之间，获取失败会抛异常
     * 返回值 Float64 - 一个 Float64 类型的随机数
     */
    func nextFloat64(): Float64

    /**
     * 获取一个 Float16 类型且符合均值为 0.0 标准差为 1.0 的高斯分布的随机数，获取失败会抛异
             常
     * 返回值 Float16 - 一个 Float16 类型的随机数
     */
    func nextGaussianFloat16(mean!: Float16, sigma!: Float16): Float16

    /**
     * 获取一个 Float32 类型且符合均值为 0.0 标准差为 1.0 的高斯分布的随机数，获取失败会抛异
             常
     * 返回值 Float32 - 一个 Float32 类型的随机数
     */
    func nextGaussianFloat32(mean!: Float32, sigma!: Float32): Float32

    /**
     * 获取一个 Float64 类型且符合均值为 0.0 标准差为 1.0 的高斯分布的随机数，获取失败会抛异
             常
     * 返回值 Float64 - 一个 Float64 类型的随机数
     */
    func nextGaussianFloat64(mean!: Float64, sigma!: Float64): Float64

    func randomInt64(min: Int64, max: Int64, closed!: Bool): Iterator<Int64>
    func randomUInt64(min: UInt64, max: UInt64, closed!: Bool): Iterator<UInt64>
    func randomInt32(min: Int32, max: Int32, closed!: Bool): Iterator<Int32>
    func randomUInt32(min: UInt32, max: UInt32, closed!: Bool): Iterator<UInt32>
    func nextBytes(length: Int64): Array<Byte> {
        Array<UInt8>(length) {_ => nextUInt8()}
    }
    /**
     * 生成随机数替换入参数组中的每个元素
     * 参数类型 array - 传入一个数组
     * 返回值 Array<UInt8> - 返回替换后的 Array
     */
    func nextUInt8s(array: Array<UInt8>): Array<UInt8> {
        for (i in 0..array.size) {
            array[i] = nextUInt8()
        }
        array
    }

    /**
     * 获取高斯 Float16 的随机数
     * 返回值 Float16 - 返回一个 Float16 类型的高斯随机数
     */
    func randomGaussianFloat16Stream(mean!: Float16, sigma!: Float16): Iterator<Float16>

    /**
     * 获取高斯 Float32 的随机数
     * 返回值 Float32 - 返回一个 Float32 类型的高斯随机数
     */
    func randomGaussianFloat32Stream(mean!: Float32, sigma!: Float32): Iterator<Float32>

    /**
     * 获取高斯 Float64 的随机数
     * 返回值 Float64 - 返回一个 Float64 类型的高斯随机数
     */
    func randomGaussianFloat64Stream(mean!: Float64, sigma!: Float64): Iterator<Float64>
}
