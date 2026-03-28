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
package f_base

public import std.math.*
public import std.math.numeric.*

/**可执行加法运算*/

public interface Number<T> <: Negativable<T> & Addable<T> & Subable<T> & Mulable<T> & Divable<T> & Comparable<T> &
    Hashable & ToString where T <: Number<T> & ToString & Comparable<T> & Hashable {
    static prop BYTES: Int64
}

public interface Integer<T> <: Number<T> & Modable<T> & BitAndable<T> & BitOrable<T> & BitXorable<T> & LeftShiftable<T> &
    RightShiftable<T> where T <: Integer<T> {
    operator func %(right: T): T
    operator func &(right: T): T
    operator func |(right: T): T
    operator func ^(right: T): T
    operator func >>(right: T): T
    operator func <<(right: T): T
    operator func !(): T
    func numberOfLeadingZeros(): T
    prop isOdd: Bool {
        get() {
            !isEven
        }
    }
    prop isEven: Bool
    func to<T>(): T where T <: Integer<T> 
}

public interface SignedInteger<S, T> <: Integer<S> where S <: SignedInteger<S, T>, T <: UnsignedInteger<T, S> {
    func toUInt(): T
}

public interface UnsignedInteger<S, T> <: Integer<S> where S <: UnsignedInteger<S, T>, T <: SignedInteger<T, S> {
    func toInt(): T
}

public interface Float<T> <: Number<T> where T <: Float<T> {}

public interface ExtendInt8 <: SignedInteger<Int8, UInt8> {
    static prop zero: Int8 {
        get() {
            0
        }
    }
    static prop one: Int8 {
        get() {
            1
        }
    }
    static prop ten: Int8 {
        get() {
            10
        }
    }
}

extend Int8 <: ExtendInt8 {
    public static prop BYTES: Int64 {
        get() {
            1
        }
    }
    public func numberOfLeadingZeros(): Int8 {
        if (this < 0) {
            return 0
        } else if (this == 0) {
            return 8
        }
        var i = this
        var n = 7i8
        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }
    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toUInt(): UInt8 {
        UInt8(this & 0x7f) | if (this < 0) {
            !0x7fu8
        } else {
            0u8
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => this
            case _: ?Int16 => Int16(this)
            case _: ?Int32 => Int32(this)
            case _: ?Int64 => Int64(this)
            case _: ?UInt8 => this.toUInt()
            case _: ?UInt16 => UInt16(this.toUInt())
            case _: ?UInt32 => UInt32(this.toUInt())
            case _: ?UInt64 => UInt64(this.toUInt())
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendInt16 <: SignedInteger<Int16, UInt16> {
    static prop zero: Int16 {
        get() {
            0
        }
    }
    static prop one: Int16 {
        get() {
            1
        }
    }
    static prop ten: Int16 {
        get() {
            10
        }
    }
}

extend Int16 <: ExtendInt16 {
    public static prop BYTES: Int64 {
        get() {
            2
        }
    }
    public func numberOfLeadingZeros(): Int16 {
        if (this < 0) {
            return 0
        } else if (this == 0) {
            return 16
        }
        var i = this
        var n = 15i16
        if (i >= 1 << 8) {
            n -= 8
            i >>= 8
        }
        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }
    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toUInt(): UInt16 {
        UInt16(this & 0x7f_ff) | if (this < 0) {
            !0x7f_ffu16
        } else {
            0u16
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => Int8(this)
            case _: ?Int16 => this
            case _: ?Int32 => Int32(this)
            case _: ?Int64 => Int64(this)
            case _: ?UInt8 => UInt8(this.toUInt())
            case _: ?UInt16 => this.toUInt()
            case _: ?UInt32 => UInt32(this.toUInt())
            case _: ?UInt64 => UInt64(this.toUInt())
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendInt32 <: SignedInteger<Int32, UInt32> {
    static prop zero: Int32 {
        get() {
            0
        }
    }
    static prop one: Int32 {
        get() {
            1
        }
    }
    static prop ten: Int32 {
        get() {
            10
        }
    }
}

extend Int32 <: ExtendInt32 {
    public static prop BYTES: Int64 {
        get() {
            4
        }
    }
    public func numberOfLeadingZeros(): Int32 {
        if (this < 0) {
            return 0
        } else if (this == 0) {
            return 32
        }
        var i = this
        var n = 31i32

        if (i >= 1 << 16) {
            n -= 16
            i >>= 16
        }
        if (i >= 1 << 8) {
            n -= 8
            i >>= 8
        }
        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }
    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toUInt(): UInt32 {
        UInt32(this & 0x7fff_ffff) | if (this < 0) {
            !0x7fff_ffffu32
        } else {
            0u32
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => Int8(this)
            case _: ?Int16 => Int16(this)
            case _: ?Int32 => this
            case _: ?Int64 => Int64(this)
            case _: ?UInt8 => UInt8(this.toUInt())
            case _: ?UInt16 => UInt16(this.toUInt())
            case _: ?UInt32 => this.toUInt()
            case _: ?UInt64 => UInt64(this.toUInt())
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendInt64 <: SignedInteger<Int64, UInt64> {
    static prop zero: Int64 {
        get() {
            0
        }
    }
    static prop one: Int64 {
        get() {
            1
        }
    }
    static prop ten: Int64 {
        get() {
            10
        }
    }
}

extend Int64 <: ExtendInt64 {
    public static prop BYTES: Int64 {
        get() {
            8
        }
    }
    public func numberOfLeadingZeros(): Int64 {
        if (this < 0) {
            return 0
        } else if (this == 0) {
            return 64
        }
        var i = this
        var n = 63

        if (i >= 1 << 32) {
            n -= 32
            i >>= 32
        }
        if (i >= 1 << 16) {
            n -= 16
            i >>= 16
        }
        if (i >= 1 << 8) {
            n -= 8
            i >>= 8
        }
        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }
    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toUInt(): UInt64 {
        UInt64(this & 0x7fff_ffff_ffff_ffff) | if (this < 0) {
            !0x7fff_ffff_ffff_ffffu64
        } else {
            0u64
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => Int8(this)
            case _: ?Int16 => Int16(this)
            case _: ?Int32 => Int32(this)
            case _: ?Int64 => this
            case _: ?UInt8 => UInt8(this.toUInt())
            case _: ?UInt16 => UInt16(this.toUInt())
            case _: ?UInt32 => UInt32(this.toUInt())
            case _: ?UInt64 => this.toUInt()
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendUInt8 <: UnsignedInteger<UInt8, Int8> {
    static prop zero: UInt8 {
        get() {
            0
        }
    }
    static prop one: UInt8 {
        get() {
            1
        }
    }
    static prop ten: UInt8 {
        get() {
            10
        }
    }
}

extend UInt8 <: ExtendUInt8 {
    public static prop BYTES: Int64 {
        get() {
            1
        }
    }
    public func numberOfLeadingZeros(): UInt8 {
        if (this == 0) {
            return 8
        }
        var i = this
        var n = 7u8

        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }
    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toInt(): Int8 {
        Int8(this & 0x7f) | if (this > 0x7fu8) {
            !0x7fi8
        } else {
            0i8
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => this.toInt()
            case _: ?Int16 => Int16(this.toInt())
            case _: ?Int32 => Int32(this.toInt())
            case _: ?Int64 => Int64(this.toInt())
            case _: ?UInt8 => this
            case _: ?UInt16 => UInt16(this)
            case _: ?UInt32 => UInt32(this)
            case _: ?UInt64 => UInt64(this)
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendUInt16 <: UnsignedInteger<UInt16, Int16> {
    static prop zero: UInt16 {
        get() {
            0
        }
    }
    static prop one: UInt16 {
        get() {
            1
        }
    }
    static prop ten: UInt16 {
        get() {
            10
        }
    }
}

extend UInt16 <: ExtendUInt16 {
    public static prop BYTES: Int64 {
        get() {
            2
        }
    }
    public func numberOfLeadingZeros(): UInt16 {
        if (this == 0) {
            return 16
        }
        var i = this
        var n = 15u16

        if (i >= 1 << 8) {
            n -= 8
            i >>= 8
        }
        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }
    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toInt(): Int16 {
        Int16(this & 0x7fff) | if (this > 0x7fffu16) {
            !0x7fffi16
        } else {
            0i16
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => Int8(this.toInt())
            case _: ?Int16 => this.toInt()
            case _: ?Int32 => Int32(this.toInt())
            case _: ?Int64 => Int64(this.toInt())
            case _: ?UInt8 => UInt8(this)
            case _: ?UInt16 => this
            case _: ?UInt32 => UInt32(this)
            case _: ?UInt64 => UInt64(this)
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendUInt32 <: UnsignedInteger<UInt32, Int32> {
    static prop zero: UInt32 {
        get() {
            0
        }
    }
    static prop one: UInt32 {
        get() {
            1
        }
    }
    static prop ten: UInt32 {
        get() {
            10
        }
    }
}

extend UInt32 <: ExtendUInt32 {
    public static prop BYTES: Int64 {
        get() {
            4
        }
    }
    public func numberOfLeadingZeros(): UInt32 {
        if (this == 0) {
            return 32
        }
        var i = this
        var n = 31u32

        if (i >= 1 << 16) {
            n -= 16
            i >>= 16
        }
        if (i >= 1 << 8) {
            n -= 8
            i >>= 8
        }
        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }
    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toInt(): Int32 {
        Int32(this & 0x7fff_ffff) | if (this > 0x7fff_ffffu32) {
            !0x7fff_ffffi32
        } else {
            0i32
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => Int8(this.toInt())
            case _: ?Int16 => Int16(this.toInt())
            case _: ?Int32 => this.toInt()
            case _: ?Int64 => Int64(this.toInt())
            case _: ?UInt8 => UInt8(this)
            case _: ?UInt16 => UInt16(this)
            case _: ?UInt32 => this
            case _: ?UInt64 => UInt64(this)
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendUInt64 <: UnsignedInteger<UInt64, Int64> {
    static prop zero: UInt64 {
        get() {
            0
        }
    }
    static prop one: UInt64 {
        get() {
            1
        }
    }
    static prop ten: UInt64 {
        get() {
            10
        }
    }
}

extend UInt64 <: ExtendUInt64 {
    public static prop BYTES: Int64 {
        get() {
            8
        }
    }
    public func numberOfLeadingZeros(): UInt64 {
        if (this == 0) {
            return 64
        }
        var i = this
        var n = 63u64

        if (i >= 1 << 32) {
            n -= 32
            i >>= 32
        }
        if (i >= 1 << 16) {
            n -= 16
            i >>= 16
        }
        if (i >= 1 << 8) {
            n -= 8
            i >>= 8
        }
        if (i >= 1 << 4) {
            n -= 4
            i >>= 4
        }
        if (i >= 1 << 2) {
            n -= 2
            i >>= 2
        }
        return n - (i >> 1)
    }

    public prop isEven: Bool {
        get() {
            (this & 1) == 0
        }
    }
    public prop isOdd: Bool {
        get() {
            !isEven
        }
    }

    @OverflowWrapping
    public func toInt(): Int64 {
        Int64(this & 0x7fff_ffff_ffff_ffff) | if (this > 0x7fff_ffff_ffff_ffffu64) {
            !0x7fff_ffff_ffff_ffffi64
        } else {
            0i64
        }
    }
    public func to<T>(): T where T <: Integer<T> {
        let any: Any = match(None<T>){
            case _: ?Int8 => Int8(this.toInt())
            case _: ?Int16 => Int16(this.toInt())
            case _: ?Int32 => Int32(this.toInt())
            case _: ?Int64 => this.toInt()
            case _: ?UInt8 => UInt8(this)
            case _: ?UInt16 => UInt16(this)
            case _: ?UInt32 => UInt32(this)
            case _: ?UInt64 => this
            case _ => this
        }
        (any as T).getOrThrow()
    }
}

public interface ExtendFloat16 <: Float<Float16> {
    static prop zero: Float16 {
        get() {
            0.0
        }
    }
    static prop one: Float16 {
        get() {
            1.0
        }
    }
    static prop ten: Float16 {
        get() {
            10.0
        }
    }
    static prop NaN: Float16
    static prop Inf: Float16
    static prop PI: Float16
    static prop E: Float16
    static prop MinDenormal: Float16
    static prop MinNormal: Float16
    static prop NegInf: Float16 {
        get() {
            -Inf
        }
    }
}

extend Float16 <: ExtendFloat16 {
    public static prop BYTES: Int64 {
        get() {
            2
        }
    }

    public static prop PI: Float16 {
        get() {
            Float16.getPI()
        }
    }
    public static prop E: Float16 {
        get() {
            Float16.getE()
        }
    }
}

public interface ExtendFloat32 <: Float<Float32> {
    static prop zero: Float32 {
        get() {
            0.0
        }
    }
    static prop one: Float32 {
        get() {
            1.0
        }
    }
    static prop ten: Float32 {
        get() {
            10.0
        }
    }
    static prop NaN: Float32
    static prop Inf: Float32
    static prop PI: Float32
    static prop E: Float32
    static prop MinDenormal: Float32
    static prop MinNormal: Float32
    static prop NegInf: Float32 {
        get() {
            -Inf
        }
    }
}

extend Float32 <: ExtendFloat32 {
    public static prop BYTES: Int64 {
        get() {
            4
        }
    }
    public static prop PI: Float32 {
        get() {
            Float32.getPI()
        }
    }
    public static prop E: Float32 {
        get() {
            Float32.getE()
        }
    }
}

public interface ExtendFloat64 <: Float<Float64> {
    static prop zero: Float64 {
        get() {
            0.0
        }
    }
    static prop one: Float64 {
        get() {
            1.0
        }
    }
    static prop ten: Float64 {
        get() {
            10.0
        }
    }
    static prop NaN: Float64
    static prop Inf: Float64
    static prop PI: Float64
    static prop E: Float64
    static prop MinDenormal: Float64
    static prop MinNormal: Float64
    static prop NegInf: Float64 {
        get() {
            -Inf
        }
    }
}

extend Float64 <: ExtendFloat64 {
    public static prop BYTES: Int64 {
        get() {
            8
        }
    }
    public static prop PI: Float64 {
        get() {
            Float64.getPI()
        }
    }
    public static prop E: Float64 {
        get() {
            Float64.getE()
        }
    }
}

private let zeroBigInt = BigInt(0)
private let oneBigInt = BigInt(1)
private let tenBigInt = BigInt(10)
private let oneHundredBigInt = BigInt(100)

public interface ExtendBigInt {
    static prop zero: BigInt
    static prop one: BigInt
    static prop ten: BigInt
    static prop oneHundred: BigInt
}

extend BigInt <: ExtendBigInt {
    public static prop zero: BigInt {
        get() {
            zeroBigInt
        }
    }
    public static prop one: BigInt {
        get() {
            oneBigInt
        }
    }
    public static prop ten: BigInt {
        get() {
            tenBigInt
        }
    }
    public static prop oneHundred: BigInt {
        get() {
            oneHundredBigInt
        }
    }
}

private let zeroDecimal = Decimal.parse('0')
private let oneDecimal = Decimal.parse('1')
private let tenDecimal = Decimal.parse('10')
private let oneHundredDecimal = Decimal.parse("100")
private let piDecimal = Decimal.parse(Float64.PI.toString())
private let eDecimal = Decimal.parse(Float64.E.toString())

public interface ExtendDecimal {
    static prop zero: Decimal
    static prop one: Decimal
    static prop ten: Decimal
    static prop oneHundred: Decimal
    static prop PI: Decimal
    static prop E: Decimal
}

extend Decimal <: ExtendDecimal {
    public static prop zero: Decimal {
        get() {
            zeroDecimal
        }
    }
    public static prop one: Decimal {
        get() {
            oneDecimal
        }
    }
    public static prop ten: Decimal {
        get() {
            tenDecimal
        }
    }
    public static prop oneHundred: Decimal {
        get() {
            oneHundredDecimal
        }
    }
    public static prop PI: Decimal {
        get() {
            piDecimal
        }
    }
    public static prop E: Decimal {
        get() {
            eDecimal
        }
    }
}

public interface Powerable<T, P> where T <: Powerable<T, P> {
    operator func **(right: P): T
}

extend Int64 <: Powerable<Int64, UInt64> {}

extend Float64 <: Powerable<Float64, Int64> {}

extend Float64 <: Powerable<Float64, Float64> {}

extend Decimal <: Powerable<Decimal, Int64> {}
