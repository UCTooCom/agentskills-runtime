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

extend Random <: BaseRandom<Random> {
    public prop current: Random {
        get() {
            this
        }
    }
    public func randomInt64(min: Int64, max: Int64, closed!: Bool = false): Iterator<Int64> {
        return RangeRandomInt64Iterator<Random>(this, min, max, closed)
    }
    public func randomUInt64(min: UInt64, max: UInt64, closed!: Bool = false): Iterator<UInt64> {
        return RangeRandomUInt64Iterator<Random>(this, min, max, closed)
    }
    public func randomInt32(min: Int32, max: Int32, closed!: Bool = false): Iterator<Int32> {
        return RangeRandomInt32Iterator<Random>(this, min, max, closed)
    }
    public func randomUInt32(min: UInt32, max: UInt32, closed!: Bool = false): Iterator<UInt32> {
        return RangeRandomUInt32Iterator<Random>(this, min, max, closed)
    }
    /**
     * 获取高斯 Float16 的随机数
     * 返回值 Float16 - 返回一个 Float16 类型的高斯随机数
     */
    public func randomGaussianFloat16Stream(mean!: Float16 = 0.0, sigma!: Float16 = 1.0): Iterator<Float16> {
        RandomGaussianFloat16Iterator<Random>(current, mean: mean, sigma: sigma)
    }

    /**
     * 获取高斯 Float32 的随机数
     * 返回值 Float32 - 返回一个 Float32 类型的高斯随机数
     */
    public func randomGaussianFloat32Stream(mean!: Float32 = 0.0, sigma!: Float32 = 1.0): Iterator<Float32> {
        RandomGaussianFloat32Iterator<Random>(current, mean: mean, sigma: sigma)
    }

    /**
     * 获取高斯 Float64 的随机数
     * 返回值 Float64 - 返回一个 Float64 类型的高斯随机数
     */
    public func randomGaussianFloat64Stream(mean!: Float64 = 0.0, sigma!: Float64 = 1.0): Iterator<Float64> {
        RandomGaussianFloat64Iterator<Random>(current, mean: mean, sigma: sigma)
    }
}

extend SecureRandom <: BaseRandom<SecureRandom> {
    public prop current: SecureRandom {
        get() {
            this
        }
    }
    public func randomInt64(min: Int64, max: Int64, closed!: Bool = false): Iterator<Int64> {
        return RangeRandomInt64Iterator<SecureRandom>(this, min, max, closed)
    }
    public func randomUInt64(min: UInt64, max: UInt64, closed!: Bool = false): Iterator<UInt64> {
        return RangeRandomUInt64Iterator<SecureRandom>(this, min, max, closed)
    }
    public func randomInt32(min: Int32, max: Int32, closed!: Bool = false): Iterator<Int32> {
        return RangeRandomInt32Iterator<SecureRandom>(this, min, max, closed)
    }
    public func randomUInt32(min: UInt32, max: UInt32, closed!: Bool = false): Iterator<UInt32> {
        return RangeRandomUInt32Iterator<SecureRandom>(this, min, max, closed)
    }
    /**
     * 获取高斯 Float16 的随机数
     * 返回值 Float16 - 返回一个 Float16 类型的高斯随机数
     */
    public func randomGaussianFloat16Stream(mean!: Float16 = 0.0, sigma!: Float16 = 1.0): Iterator<Float16> {
        RandomGaussianFloat16Iterator<SecureRandom>(current, mean: mean, sigma: sigma)
    }

    /**
     * 获取高斯 Float32 的随机数
     * 返回值 Float32 - 返回一个 Float32 类型的高斯随机数
     */
    public func randomGaussianFloat32Stream(mean!: Float32 = 0.0, sigma!: Float32 = 1.0): Iterator<Float32> {
        RandomGaussianFloat32Iterator<SecureRandom>(current, mean: mean, sigma: sigma)
    }

    /**
     * 获取高斯 Float64 的随机数
     * 返回值 Float64 - 返回一个 Float64 类型的高斯随机数
     */
    public func randomGaussianFloat64Stream(mean!: Float64 = 0.0, sigma!: Float64 = 1.0): Iterator<Float64> {
        RandomGaussianFloat64Iterator<SecureRandom>(current, mean: mean, sigma: sigma)
    }
}

abstract sealed class RandomIterator<R, T> <: Iterator<T> where R <: BaseRandom<R> {
    RandomIterator(protected let rand: R) {}
}

class RangeRandomInt32Iterator<R> <: RandomIterator<R, Int32> where R <: BaseRandom<R> & ExtendRandom<R> {
    RangeRandomInt32Iterator(rand: R, private let minValue: Int32, private let maxValue: Int32, private let closed: Bool) {
        super(rand)
    }
    public func next(): Option<Int32> {
        rand.nextInt32(minValue, maxValue, closed: closed)
    }
}

class RangeRandomUInt32Iterator<R> <: RandomIterator<R, UInt32> where R <: BaseRandom<R> & ExtendRandom<R> {
    RangeRandomUInt32Iterator(rand: R, private let minValue: UInt32, private let maxValue: UInt32,
        private let closed: Bool) {
        super(rand)
    }
    public func next(): Option<UInt32> {
        rand.nextUInt32(minValue, maxValue, closed: closed)
    }
}

class RangeRandomInt64Iterator<R> <: RandomIterator<R, Int64> where R <: BaseRandom<R> & ExtendRandom<R> {
    RangeRandomInt64Iterator(rand: R, private let minValue: Int64, private let maxValue: Int64, private let closed: Bool) {
        super(rand)
    }
    public func next(): Option<Int64> {
        rand.nextInt64(minValue, maxValue, closed: closed)
    }
}

class RangeRandomUInt64Iterator<R> <: RandomIterator<R, UInt64> where R <: BaseRandom<R> & ExtendRandom<R> {
    RangeRandomUInt64Iterator(rand: R, private let minValue: UInt64, private let maxValue: UInt64,
        private let closed: Bool) {
        super(rand)
    }
    public func next(): Option<UInt64> {
        rand.nextUInt64(minValue, maxValue, closed: closed)
    }
}

class RandomBoolIterator<R> <: RandomIterator<R, Bool> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Bool> {
        rand.nextBool()
    }
}

class RandomInt8Iterator<R> <: RandomIterator<R, Int8> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Int8> {
        rand.nextInt8()
    }
}

class RandomUInt8Iterator<R> <: RandomIterator<R, UInt8> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<UInt8> {
        rand.nextUInt8()
    }
}

class UpperRandomInt8Iterator<R> <: RandomIterator<R, Int8> where R <: BaseRandom<R> {
    UpperRandomInt8Iterator(rand: R, private var upper: Int8) {
        super(rand)
    }
    public func next(): Option<Int8> {
        rand.nextInt8(upper)
    }
}

class UpperRandomUInt8Iterator<R> <: RandomIterator<R, UInt8> where R <: BaseRandom<R> {
    UpperRandomUInt8Iterator(rand: R, private var upper: UInt8) {
        super(rand)
    }
    public func next(): Option<UInt8> {
        rand.nextUInt8(upper)
    }
}

class RandomUInt8sIterator<R> <: RandomIterator<R, Array<UInt8>> where R <: BaseRandom<R> {
    RandomUInt8sIterator(rand: R, private let size: Int64) {
        super(rand)
    }

    public func next(): Option<Array<UInt8>> {
        Array<UInt8>(size) {_ => rand.nextUInt8()}
    }
}

class RandomInt16Iterator<R> <: RandomIterator<R, Int16> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Int16> {
        rand.nextInt16()
    }
}

class RandomUInt16Iterator<R> <: RandomIterator<R, UInt16> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<UInt16> {
        rand.nextUInt16()
    }
}

class UpperRandomInt16Iterator<R> <: RandomIterator<R, Int16> where R <: BaseRandom<R> {
    UpperRandomInt16Iterator(rand: R, private var upper: Int16) {
        super(rand)
    }
    public func next(): Option<Int16> {
        rand.nextInt16(upper)
    }
}

class UpperRandomUInt16Iterator<R> <: RandomIterator<R, UInt16> where R <: BaseRandom<R> {
    UpperRandomUInt16Iterator(rand: R, private var upper: UInt16) {
        super(rand)
    }
    public func next(): Option<UInt16> {
        rand.nextUInt16(upper)
    }
}

class RandomInt32Iterator<R> <: RandomIterator<R, Int32> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Int32> {
        rand.nextInt32()
    }
}

class RandomUInt32Iterator<R> <: RandomIterator<R, UInt32> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<UInt32> {
        rand.nextUInt32()
    }
}

class UpperRandomInt32Iterator<R> <: RandomIterator<R, Int32> where R <: BaseRandom<R> {
    UpperRandomInt32Iterator(rand: R, private var upper: Int32) {
        super(rand)
    }
    public func next(): Option<Int32> {
        rand.nextInt32(upper)
    }
}

class UpperRandomUInt32Iterator<R> <: RandomIterator<R, UInt32> where R <: BaseRandom<R> {
    UpperRandomUInt32Iterator(rand: R, private var upper: UInt32) {
        super(rand)
    }
    public func next(): Option<UInt32> {
        rand.nextUInt32(upper)
    }
}

class RandomInt64Iterator<R> <: RandomIterator<R, Int64> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Int64> {
        rand.nextInt64()
    }
}

class RandomUInt64Iterator<R> <: RandomIterator<R, UInt64> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<UInt64> {
        rand.nextUInt64()
    }
}

class UpperRandomInt64Iterator<R> <: RandomIterator<R, Int64> where R <: BaseRandom<R> {
    UpperRandomInt64Iterator(rand: R, private var upper: Int64) {
        super(rand)
    }
    public func next(): Option<Int64> {
        rand.nextInt64(upper)
    }
}

class UpperRandomUInt64Iterator<R> <: RandomIterator<R, UInt64> where R <: BaseRandom<R> {
    UpperRandomUInt64Iterator(rand: R, private var upper: UInt64) {
        super(rand)
    }
    public func next(): Option<UInt64> {
        rand.nextUInt64(upper)
    }
}

class RandomFloat16Iterator<R> <: RandomIterator<R, Float16> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Float16> {
        rand.nextFloat16()
    }
}

class RandomFloat32Iterator<R> <: RandomIterator<R, Float32> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Float32> {
        rand.nextFloat32()
    }
}

class RandomFloat64Iterator<R> <: RandomIterator<R, Float64> where R <: BaseRandom<R> {
    init(rand: R) {
        super(rand)
    }
    public func next(): Option<Float64> {
        rand.nextFloat64()
    }
}

class RandomGaussianFloat16Iterator<R> <: RandomIterator<R, Float16> where R <: BaseRandom<R> {
    RandomGaussianFloat16Iterator(rand: R, private let mean!: Float16, private let sigma!: Float16) {
        super(rand)
    }
    public func next(): Option<Float16> {
        rand.nextGaussianFloat16(mean: mean, sigma: sigma)
    }
}

class RandomGaussianFloat32Iterator<R> <: RandomIterator<R, Float32> where R <: BaseRandom<R> {
    RandomGaussianFloat32Iterator(rand: R, private let mean!: Float32, private let sigma!: Float32) {
        super(rand)
    }
    public func next(): Option<Float32> {
        rand.nextGaussianFloat32(mean: mean, sigma: sigma)
    }
}

class RandomGaussianFloat64Iterator<R> <: RandomIterator<R, Float64> where R <: BaseRandom<R> {
    RandomGaussianFloat64Iterator(rand: R, private let mean!: Float64, private let sigma!: Float64) {
        super(rand)
    }
    public func next(): Option<Float64> {
        rand.nextGaussianFloat64(mean: mean, sigma: sigma)
    }
}
