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

extend Int8 <: DataFields<Int8> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToInt8()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toInt8(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toInt8(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toInt8(strategy: Saturating)
            case _: DataNone => None<Int8>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Int8>()}')
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToInt8()
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt8(strategy: Wrapping)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt8(strategy: Throwing)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt8(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<Int8>()}')
            case _ => None<Int8>
        }
    }
}

extend UInt8 <: DataFields<UInt8> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToUInt8()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toUInt8(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toUInt8(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toUInt8(strategy: Saturating)
            case _: DataNone => None<UInt8>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<UInt8>()}')
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToUInt8()
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt8(strategy: Wrapping)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt8(strategy: Throwing)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt8(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<UInt8>()}')
            case _ => None<UInt8>
        }
    }
}

extend Int16 <: DataFields<Int16> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToInt16()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toInt16(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toInt16(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toInt16(strategy: Saturating)
            case _: DataNone => None<Int16>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Int16>()}')
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToInt16()
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt16(strategy: Wrapping)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt16(strategy: Throwing)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt16(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<Int16>()}')
            case _ => None<Int16>
        }
    }
}

extend UInt16 <: DataFields<UInt16> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToUInt16()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toUInt16(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toUInt16(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toUInt16(strategy: Saturating)
            case _: DataNone => None<UInt16>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<UInt16>()}')
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToUInt16()
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt16(strategy: Wrapping)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt16(strategy: Throwing)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt16(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<UInt16>()}')
            case _ => None<UInt16>
        }
    }
}

extend Int32 <: DataFields<Int32> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToInt32()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toInt32(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toInt32(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toInt32(strategy: Saturating)
            case _: DataNone => None<Int32>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Int32>()}')
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToInt32()
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt32(strategy: Wrapping)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt32(strategy: Throwing)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt32(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<Int32>()}')
            case _ => None<Int32>
        }
    }
}

extend UInt32 <: DataFields<UInt32> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToUInt32()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toUInt32(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toUInt32(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toUInt32(strategy: Saturating)
            case _: DataNone => None<UInt32>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<UInt32>()}')
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToUInt32()
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt32(strategy: Wrapping)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt32(strategy: Throwing)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt32(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<UInt32>()}')
            case _ => None<UInt32>
        }
    }
}

extend Int64 <: DataFields<Int64> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToInt64()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toInt64(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toInt64(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toInt64(strategy: Saturating)
            case _: DataNone => None<Int64>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Int64>()}')
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToInt64()
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt64(strategy: Wrapping)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt64(strategy: Throwing)
            case x: DataString where #'^-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toInt64(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<Int64>()}')
            case _ => None<Int64>
        }
    }
}

extend UInt64 <: DataFields<UInt64> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToUInt64()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toUInt64(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toUInt64(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toUInt64(strategy: Saturating)
            case _: DataNone => None<UInt64>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<UInt64>()}')
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToUInt64()
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt64(strategy: Wrapping)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt64(strategy: Throwing)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUInt64(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<UInt64>()}')
            case _ => None<UInt64>
        }
    }
}

extend IntNative <: DataFields<IntNative> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToIntNative()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toIntNative(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toIntNative(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toIntNative(strategy: Saturating)
            case _: DataNone => None<IntNative>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<IntNative>()}')
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToIntNative()
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toIntNative(strategy: Wrapping)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toIntNative(strategy: Throwing)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toIntNative(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<IntNative>()}')
            case _ => None<IntNative>
        }
    }
}

extend UIntNative <: DataFields<UIntNative> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => x.tryToUIntNative()
            case x: DataReal where (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => x.toUIntNative(strategy: Wrapping)
            case x: DataReal where (flag & THROWING_ON_INT_OVERFLOW) != 0 => x.toUIntNative(strategy: Throwing)
            case x: DataReal where (flag & SATURATING_ON_INT_OVERFLOW) != 0 => x.toUIntNative(strategy: Saturating)
            case _: DataNone => None<UIntNative>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<UIntNative>()}')
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => DataReal(
                x.toString().trimAscii()).tryToUIntNative()
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & WRAPPING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUIntNative(strategy: Wrapping)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & THROWING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUIntNative(strategy: Throwing)
            case x: DataString where #'^(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+)$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) && (flag & SATURATING_ON_INT_OVERFLOW) != 0 => DataReal(
                x.toString().trimAscii()).toUIntNative(strategy: Saturating)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<UIntNative>()}')
            case _ => None<UIntNative>
        }
    }
}

extend Float64 <: DataFields<Float64> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal => x.tryToFloat64()
            case _: DataNone => None<Float64>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Float64>()}')
            case x: DataString where #'^(-?((\d+(\.\d+)?|\.\d+)(-?[eE]\d+)?|0[xX][0-9a-fA-F]+(\.[0-9a-fA-F]+)?(-?[pP]\d+)?))$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) => DataReal(x.toString().trimAscii()).tryToFloat64()
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<Float64>()}')
            case _ => None<Float64>
        }
    }
}

extend Float32 <: DataFields<Float32> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal => x.tryToFloat32()
            case _: DataNone => None<Float32>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Float32>()}')
            case x: DataString where #'^(-?((\d+(\.\d+)?|\.\d+)(-?[eE]\d+)?|0[xX][0-9a-fA-F]+(\.[0-9a-fA-F]+)?(-?[pP]\d+)?))$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) => DataReal(x.toString().trimAscii()).tryToFloat32()
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<Float32>()}')
            case _ => None<Float32>
        }
    }
}

extend Float16 <: DataFields<Float16> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal => x.tryToFloat16()
            case _: DataNone => None<Float16>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Float16>()}')
            case x: DataString where #'^(-?((\d+(\.\d+)?|\.\d+)(-?[eE]\d+)?|0[xX][0-9a-fA-F]+(\.[0-9a-fA-F]+)?(-?[pP]\d+)?))$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) => DataReal(x.toString().trimAscii()).tryToFloat16()
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted ${TypeInfo.of<Float16>()}')
            case _ => None<Float16>
        }
    }
}

extend BigInt <: DataFields<BigInt> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal => x.tryToBigInt()
            case _: DataNone => None<BigInt>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<BigInt>()}')
            case x: DataString where #'^(-?(\d+|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+))$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) => DataReal(x.toString().trimAscii()).tryToBigInt()
            case _ => None<BigInt>
        }
    }
}

extend Decimal <: DataFields<Decimal> {
    public func toData(): Data {
        DataReal(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataReal => x.tryToDecimal()
            case _: DataNone => None<Decimal>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Decimal>()}')
            case x: DataString where #'^(-?((\d+(\.\d+)?|\.\d+)(-?[eE]\d+)?|0[xX][0-9a-fA-F]+(\.[0-9a-fA-F]+)?(-?[pP]\d+)?))$'#
                .regex(solid: true)
                .matches(x.toString().trimAscii()) => DataReal(x.toString().trimAscii()).tryToDecimal()
            case _ => None<Decimal>
        }
    }
}
