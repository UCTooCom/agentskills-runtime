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
package f_data

public struct DataReal <: Data & Hashable & Comparable<DataReal> {
    public let integer: Bool
    public DataReal(public let data: Decimal) {
        integer = data.scale == 0
    }
    public init(data: BigInt) {
        this(Decimal(data))
    }
    public init(data: BigInt, scale: Int32){
        this(Decimal(data, scale))
    }
    public init(data: Int8) {
        this(Decimal(data))
    }
    public init(data: UInt8) {
        this(Decimal(data))
    }
    public init(data: Int16) {
        this(Decimal(data))
    }
    public init(data: UInt16) {
        this(Decimal(data))
    }
    public init(data: Int32) {
        this(Decimal(data))
    }
    public init(data: UInt32) {
        this(Decimal(data))
    }
    public init(data: Int64) {
        this(Decimal(data))
    }
    public init(data: UInt64) {
        this(Decimal(data))
    }
    public init(data: IntNative) {
        this(Decimal(data))
    }
    public init(data: UIntNative) {
        this(Decimal(data))
    }
    public init(data: Float16) {
        this(Decimal(data))
    }
    public init(data: Float32) {
        this(Decimal(data))
    }
    public init(data: Float64) {
        this(Decimal(data))
    }
    public init(data: String) {
        this(Decimal.parse(data))
    }

    public func toDecimal() {
        data
    }
    public func tryToDecimal(): ?Decimal {
        toDecimal()
    }
    public func toBigInt() {
        data.toBigInt()
    }
    public func tryToBigInt(): ?BigInt {
        data.toBigInt()
    }
    public func toFloat64() {
        data.toFloat64()
    }
    public func tryToFloat64(): ?Float64 {
        data.toFloat64()
    }
    public func toFloat32() {
        data.toFloat32()
    }
    public func tryToFloat32(): ?Float32 {
        data.toFloat32()
    }
    public func toFloat16() {
        data.toFloat16()
    }
    public func tryToFloat16(): ?Float16 {
        data.toFloat16()
    }
    private static let int8Range = [Decimal(Int8.Min), Decimal(Int8.Max)]
    private static let uint8Range = [Decimal(UInt8.Min), Decimal(UInt8.Max)]
    private static let int16Range = [Decimal(Int16.Min), Decimal(Int16.Max)]
    private static let uint16Range = [Decimal(UInt16.Min), Decimal(UInt16.Max)]
    private static let int32Range = [Decimal(Int32.Min), Decimal(Int32.Max)]
    private static let uint32Range = [Decimal(UInt32.Min), Decimal(UInt32.Max)]
    private static let int64Range = [Decimal(Int64.Min), Decimal(Int64.Max)]
    private static let uint64Range = [Decimal(UInt64.Min), Decimal(UInt64.Max)]
    public func toInt8(strategy!: OverflowStrategy = Throwing): Int8 {
        data.toInt8(overflowHandling: strategy)
    }
    public func tryToInt8(): ?Int8 {
        if (data >= int8Range[0] && data <= int8Range[1]) {
            data.toInt8()
        } else {
            None<Int8>
        }
    }
    public func toUInt8(strategy!: OverflowStrategy = Throwing): UInt8 {
        data.toUInt8(overflowHandling: strategy)
    }
    public func tryToUInt8(): ?UInt8 {
        if (data >= uint8Range[0] && data <= uint8Range[1]) {
            data.toUInt8()
        } else {
            None<UInt8>
        }
    }

    public func toInt16(strategy!: OverflowStrategy = Throwing): Int16 {
        data.toInt16(overflowHandling: strategy)
    }
    public func tryToInt16(): ?Int16 {
        if (data >= int16Range[0] && data <= int16Range[1]) {
            data.toInt16()
        } else {
            None<Int16>
        }
    }
    public func toUInt16(strategy!: OverflowStrategy = Throwing): UInt16 {
        data.toUInt16(overflowHandling: strategy)
    }
    public func tryToUInt16(): ?UInt16 {
        if (data >= uint16Range[0] && data <= uint16Range[1]) {
            data.toUInt16()
        } else {
            None<UInt16>
        }
    }

    public func toInt32(strategy!: OverflowStrategy = Throwing): Int32 {
        data.toInt32(overflowHandling: strategy)
    }
    public func tryToInt32(): ?Int32 {
        if (data >= int32Range[0] && data <= int32Range[1]) {
            data.toInt32()
        } else {
            None<Int32>
        }
    }
    public func toUInt32(strategy!: OverflowStrategy = Throwing): UInt32 {
        data.toUInt32(overflowHandling: strategy)
    }
    public func tryToUInt32(): ?UInt32 {
        if (data >= uint32Range[0] && data <= uint32Range[1]) {
            data.toUInt32()
        } else {
            None<UInt32>
        }
    }

    public func toInt64(strategy!: OverflowStrategy = Throwing): Int64 {
        data.toInt64(overflowHandling: strategy)
    }
    public func tryToInt64(): ?Int64 {
        if (data >= int64Range[0] && data <= int64Range[1]) {
            data.toInt64()
        } else {
            None<Int64>
        }
    }
    public func toUInt64(strategy!: OverflowStrategy = Throwing): UInt64 {
        data.toUInt64(overflowHandling: strategy)
    }
    public func tryToUInt64(): ?UInt64 {
        if (data >= uint64Range[0] && data <= uint64Range[1]) {
            data.toUInt64()
        } else {
            None<UInt64>
        }
    }
    public func toIntNative(strategy!: OverflowStrategy = Throwing): IntNative {
        data.toIntNative(overflowHandling: strategy)
    }
    public func tryToIntNative(): ?IntNative {
        if (data >= int64Range[0] && data <= int64Range[1]) {
            data.toIntNative()
        } else {
            None<IntNative>
        }
    }
    public func toUIntNative(strategy!: OverflowStrategy = Throwing): UIntNative {
        data.toUIntNative(overflowHandling: strategy)
    }
    public func tryToUIntNative(): ?UIntNative {
        if (data >= int64Range[0] && data <= int64Range[1]) {
            data.toUIntNative()
        } else {
            None<UIntNative>
        }
    }

    public func toString(): String {
        this.data.toString()
    }

    public static func parse(data: String): Data {
        DataReal(extractPureString(data))
    }
    public static func tryParse(data: String): ?Data {
        let d = extractPureString(data)
        if (Regex.REAL_NUMBER.matches(d)) {
            parse(d)
        } else {
            None<Data>
        }
    }
    public func hashCode(): Int64 {
        data.hashCode()
    }
    public func compare(other: DataReal): Ordering {
        data.compare(other.data)
    }
}
