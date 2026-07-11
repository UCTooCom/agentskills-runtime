/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq4cj.client.util

public class TypeConversionSupport {
    private static let CONVERSION_MAP: HashMap<ConversionKey, Converter> = HashMap<ConversionKey, Converter>()

    static init() {
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Bool>()), StringToBoolConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Byte>()), StringToByteConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Int8>()), StringToInt8Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Int16>()), StringToInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<UInt16>()), StringToUInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Int32>()), StringToInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<UInt32>()), StringToUInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Int64>()), StringToInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<UInt64>()), StringToUInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Float32>()), StringToFloat32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<String>(), TypeInfo.of<Float64>()), StringToFloat64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<Int8>()), ByteToInt8Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<Int16>()), ByteToInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<UInt16>()), ByteToUInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<Int32>()), ByteToInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<UInt32>()), ByteToUInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<Int64>()), ByteToInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<UInt64>()), ByteToUInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<Byte>()), Int8ToByteConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<Int16>()), Int8ToInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<UInt16>()), Int8ToUInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<Int32>()), Int8ToInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<UInt32>()), Int8ToUInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<Int64>()), Int8ToInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<UInt64>()), Int8ToUInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int16>(), TypeInfo.of<UInt16>()), Int16ToUInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int16>(), TypeInfo.of<Int32>()), Int16ToInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int16>(), TypeInfo.of<Int64>()), Int16ToInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int16>(), TypeInfo.of<UInt32>()), Int16ToUInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int16>(), TypeInfo.of<UInt64>()), Int16ToUInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt16>(), TypeInfo.of<Int16>()), UInt16ToInt16Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt16>(), TypeInfo.of<Int32>()), UInt16ToInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt16>(), TypeInfo.of<Int64>()), UInt16ToInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt16>(), TypeInfo.of<UInt32>()), UInt16ToUInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt16>(), TypeInfo.of<UInt64>()), UInt16ToUInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int32>(), TypeInfo.of<UInt32>()), Int32ToUInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int32>(), TypeInfo.of<Int64>()), Int32ToInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int32>(), TypeInfo.of<UInt64>()), Int32ToUInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt32>(), TypeInfo.of<Int32>()), UInt32ToInt32Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt32>(), TypeInfo.of<Int64>()), UInt32ToInt64Converter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt32>(), TypeInfo.of<UInt64>()), UInt32ToUInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt64>(), TypeInfo.of<Int64>()), UInt64ToInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int64>(), TypeInfo.of<UInt64>()), Int64ToUInt64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Float32>(), TypeInfo.of<Float64>()), Float32ToFloat64Converter())

        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Bool>(), TypeInfo.of<String>()), BoolToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Byte>(), TypeInfo.of<String>()), ByteToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int8>(), TypeInfo.of<String>()), Int8ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int16>(), TypeInfo.of<String>()), Int16ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt16>(), TypeInfo.of<String>()), UInt16ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int32>(), TypeInfo.of<String>()), Int32ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt32>(), TypeInfo.of<String>()), UInt32ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Int64>(), TypeInfo.of<String>()), Int64ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<UInt64>(), TypeInfo.of<String>()), UInt64ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Float32>(), TypeInfo.of<String>()), Float32ToStringConverter())
        CONVERSION_MAP.add(ConversionKey(TypeInfo.of<Float64>(), TypeInfo.of<String>()), Float64ToStringConverter())
    }

    public static func genericConvert<T>(value: Any, to: TypeInfo): T {
        var rc = convert(value, to)
        if (let Some(value) <- (rc as T)) {
            return value
        }
        throw IllegalArgumentException("Fail convert to ${to}")
    }

    public static func convert(value: Any, to: TypeInfo): Any {
        if (let Some(value) <- (value as Option<Any>)) {
            if (value.isNone()) {
                throw IllegalArgumentException("Fail convert a none value to ${to}")
            }
        }

        let (fromType, isOption) = deduceTypeInfo(value)

        //不是option类型，并且转换类型与当前类型一致，直接返回value
        if (!isOption && fromType == to) {
            return value
        }

        if (let Some(converter) <- CONVERSION_MAP.get(ConversionKey(fromType, to))) {
            return converter.convert(value)
        }

        throw IllegalArgumentException("Fail convert to ${to}")
    }

    /**
     * 判断Any类型的Value的真实类型，由于反射尚不支持enum，所以所有的Option原始类型需要枚举出来
     * @return 原始数据类型，是否是option
     */
    private static func deduceTypeInfo(value: Any): (TypeInfo, Bool) {
        //给定的value必须是基础类型变量，否则不支持
        if (value is Option<String>) {
            return (TypeInfo.of<String>(), true)
        }
        if (value is Option<Byte>) {
            return (TypeInfo.of<Byte>(), true)
        }
        if (value is Option<Int8>) {
            return (TypeInfo.of<Int8>(), true)
        }
        if (value is Option<Bool>) {
            return (TypeInfo.of<Bool>(), true)
        }
        if (value is Option<Rune>) {
            return (TypeInfo.of<Rune>(), true)
        }
        if (value is Option<Int16>) {
            return (TypeInfo.of<Int16>(), true)
        }
        if (value is Option<UInt16>) {
            return (TypeInfo.of<UInt16>(), true)
        }
        if (value is Option<Int32>) {
            return (TypeInfo.of<Int32>(), true)
        }
        if (value is Option<UInt32>) {
            return (TypeInfo.of<UInt32>(), true)
        }
        if (value is Option<Int64>) {
            return (TypeInfo.of<Int64>(), true)
        }
        if (value is Option<UInt64>) {
            return (TypeInfo.of<UInt64>(), true)
        }
        if (value is Option<Float32>) {
            return (TypeInfo.of<Float32>(), true)
        }
        if (value is Option<Float64>) {
            return (TypeInfo.of<Float64>(), true)
        }
        return (TypeInfo.of(value), false)
    }

    public static func convertMap<T>(props: HashMap<String, Option<T>>): HashMap<String, Any> {
        let rc = HashMap<String, Any>()
        for ((k, v) in props) {
            rc.add(k, v)
        }
        return rc
    }
}

public interface Converter {
    func convert(value: Any): Any
}

public class StringToBoolConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Bool.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Bool.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToByteConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Byte.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Byte.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToInt8Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Int8.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Int8.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Int16.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Int16.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToUInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return UInt16.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return UInt16.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Int32.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Int32.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToUInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return UInt32.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return UInt32.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Int64.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Int64.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return UInt64.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return UInt64.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToFloat32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Float32.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Float32.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class StringToFloat64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Option<String>)) {
            if (let Some(s) <- value) {
                return Float64.parse(s)
            }
        }
        if (let Some(s) <- (value as String)) {
            return Float64.parse(s)
        }
        throw IllegalArgumentException("The arg is not a String type")
    }
}

public class ByteToInt8Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return Convert.convertToInt8(value)
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class ByteToInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return Int16(value)
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class ByteToUInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return UInt16(value)
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class ByteToInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return Int32(value)
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class ByteToUInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return UInt32(value)
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class ByteToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return Int64(value)
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class ByteToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return UInt64(value)
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class Int8ToByteConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return Convert.convertToUInt8(value)
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int8ToInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return Int16(value)
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int8ToUInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return Convert.convertToUInt16(Int16(value))
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int8ToInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return Int32(value)
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int8ToUInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return Convert.convertToUInt32(Int32(value))
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int8ToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return Int64(value)
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int8ToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return Convert.convertToUInt64(Int64(value))
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int16ToUInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int16)) {
            return Convert.convertToUInt16(value)
        }
        throw IllegalArgumentException("The arg is not a Int16 type")
    }
}

public class Int16ToInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int16)) {
            return Int32(value)
        }
        throw IllegalArgumentException("The arg is not a Int16 type")
    }
}

public class Int16ToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int16)) {
            return Int64(value)
        }
        throw IllegalArgumentException("The arg is not a Int16 type")
    }
}

public class Int16ToUInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int16)) {
            return Convert.convertToUInt32(Int32(value))
        }
        throw IllegalArgumentException("The arg is not a Int16 type")
    }
}

public class Int16ToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int16)) {
            return Convert.convertToUInt64(Int64(value))
        }
        throw IllegalArgumentException("The arg is not a Int16 type")
    }
}

public class Int32ToUInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int32)) {
            return Convert.convertToUInt32(value)
        }
        throw IllegalArgumentException("The arg is not a Int32 type")
    }
}

public class Int32ToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int32)) {
            return Convert.convertToUInt64(Int64(value))
        }
        throw IllegalArgumentException("The arg is not a Int32 type")
    }
}

public class Int32ToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int32)) {
            return Int64(value)
        }
        throw IllegalArgumentException("The arg is not a Int32 type")
    }
}

public class Float32ToFloat64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Float32)) {
            return Float64(value)
        }
        throw IllegalArgumentException("The arg is not a Float32 type")
    }
}

public class BoolToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Bool)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Bool type")
    }
}

public class ByteToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Byte)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Byte type")
    }
}

public class Int8ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int8)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Int8 type")
    }
}

public class Int16ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int16)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Int16 type")
    }
}

public class UInt16ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt16)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a UInt16 type")
    }
}

public class Int32ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int32)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Int32 type")
    }
}

public class UInt32ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt32)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a UInt32 type")
    }
}

public class Int64ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int64)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Int64 type")
    }
}

public class UInt64ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt64)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a UInt64 type")
    }
}

public class Float32ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Float32)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Float32 type")
    }
}

public class Float64ToStringConverter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Float64)) {
            return value.toString()
        }
        throw IllegalArgumentException("The arg is not a Float64 type")
    }
}

public class UInt16ToInt16Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt16)) {
            return Convert.convertToInt16(value)
        }
        throw IllegalArgumentException("The arg is not a UInt16 type")
    }
}

public class UInt16ToInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt16)) {
            return Convert.convertToInt32(UInt32(value))
        }
        throw IllegalArgumentException("The arg is not a UInt16 type")
    }
}

public class UInt16ToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt16)) {
            return Convert.convertToInt64(UInt64(value))
        }
        throw IllegalArgumentException("The arg is not a UInt16 type")
    }
}

public class UInt16ToUInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt16)) {
            return UInt32(value)
        }
        throw IllegalArgumentException("The arg is not a UInt16 type")
    }
}

public class UInt16ToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt16)) {
            return UInt64(value)
        }
        throw IllegalArgumentException("The arg is not a UInt16 type")
    }
}

public class UInt32ToInt32Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt32)) {
            return Convert.convertToInt32(value)
        }
        throw IllegalArgumentException("The arg is not a UInt32 type")
    }
}

public class UInt32ToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt32)) {
            return UInt64(value)
        }
        throw IllegalArgumentException("The arg is not a UInt32 type")
    }
}

public class UInt32ToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt32)) {
            return Convert.convertToInt64(UInt64(value))
        }
        throw IllegalArgumentException("The arg is not a UInt32 type")
    }
}

public class UInt64ToInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as UInt64)) {
            return Convert.convertToInt64(value)
        }
        throw IllegalArgumentException("The arg is not a UInt64 type")
    }
}

public class Int64ToUInt64Converter <: Converter {
    public override func convert(value: Any): Any {
        if (let Some(value) <- (value as Int64)) {
            return Convert.convertToUInt64(value)
        }
        throw IllegalArgumentException("The arg is not a Int64 type")
    }
}

public class ConversionKey <: Equatable<ConversionKey> & Hashable {
    private let fromType: TypeInfo
    private let toType: TypeInfo

    public init(fromType: TypeInfo, toType: TypeInfo) {
        this.fromType = fromType
        this.toType = toType
    }

    public operator func ==(other: ConversionKey): Bool {
        if (this.fromType != other.fromType) {
            return false
        }
        if (this.toType != other.toType) {
            return false
        }
        return true
    }

    public operator func !=(other: ConversionKey): Bool {
        if (this.fromType != other.fromType) {
            return true
        }
        if (this.toType != other.toType) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = prime * fromType.hashCode()
        hashCode += prime * toType.hashCode()
        return hashCode
    }
}
