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

foreign func malloc(size: UIntNative): CPointer<Unit>

foreign func free(ptr: CPointer<Unit>): Unit

public class MarshallingSupport {

    //以下是几种基础数据类型的代码
    public static let NULL: Int8 = 0
    public static let BOOLEAN_TYPE: Int8 = 1
    public static let BYTE_TYPE: Int8 = 2
    public static let CHAR_TYPE: Int8 = 3
    public static let SHORT_TYPE: Int8 = 4
    public static let INTEGER_TYPE: Int8 = 5
    public static let LONG_TYPE: Int8 = 6
    public static let DOUBLE_TYPE: Int8 = 7
    public static let FLOAT_TYPE: Int8 = 8
    public static let STRING_TYPE: Int8 = 9
    public static let BYTE_ARRAY_TYPE: Int8 = 10
    public static let MAP_TYPE: Int8 = 11
    public static let LIST_TYPE: Int8 = 12
    public static let BIG_STRING_TYPE: Int8 = 13

    /**
     * 对map数据进行编码，所有的key都是String类型，写UTF8，value是所有可能的基本数据类型，在value前写类型代码，再写值
     */
    public static func marshalPrimitiveMap(map: ?HashMap<String, Any>, out: ByteBuffer): Unit {
        if (let Some(map) <- map) {
            out.putInt32(Int32(map.size))
            for ((k, v) in map) {
                writeUTF(k, out)
                if (let Some(v) <- (v as String)) {
                    marshalPrimitiveString(v, out)
                } else if (let Some(v) <- (v as Bool)) {
                    marshalBool(v, out)
                } else if (let Some(v) <- (v as Byte)) {
                    marshalByte(v, out)
                } else if (let Some(v) <- (v as Rune)) {
                    marshalChar(v, out)
                } else if (let Some(v) <- (v as Int16)) {
                    marshalInt16(v, out)
                } else if (let Some(v) <- (v as Int64)) {
                    marshalInt64(v, out)
                } else if (let Some(v) <- (v as Int32)) {
                    marshalInt32(v, out)
                } else if (let Some(v) <- (v as Float32)) {
                    marshalFloat32(v, out)
                } else if (let Some(v) <- (v as Float64)) {
                    marshalFloat64(v, out)
                } else if (let Some(v) <- (v as Array<Byte>)) {
                    marshalByteArray(v, out)
                } else if (let Some(v) <- (v as Option<Any>)) {
                    if (v.isNone()) {
                        out.putInt8(NULL)
                    }
                } else if (let Some(v) <- (v as Option<String>)) {
                    if (let Some(value) <- v) {
                        marshalPrimitiveString(value, out)
                    } else {
                        out.putInt8(NULL)
                    }
                }
            }
        } else {
            out.putInt32(Int32(-1))
        }
    }

    public static func unmarshalPrimitiveMap(dataIn: ByteBuffer, maxPropertySize: Int32): ?HashMap<String, Any> {
        let size = dataIn.getInt32()
        if (size > maxPropertySize) {
            throw IOException("Primitive map is larger than the allowed size: ${size}")
        }
        if (size < 0) {
            return None
        }
        let map = HashMap<String, Any>(Int64(size))
        for (i in 0..size) {
            let key: ?String = readUTF(dataIn)
            let val = unmarshalPrimitive(dataIn)
            if (let Some(key) <- key) {
                map[key] = val
            }
        }
        return map
    }

    public static func unmarshalPrimitiveMap(dataIn: ByteBuffer): ?HashMap<String, Any> {
        let size = dataIn.getInt32()
        if (size < 0) {
            return None
        }
        let map = HashMap<String, Any>(Int64(size))
        for (i in 0..size) {
            let key: ?String = readUTF(dataIn)
            let val = unmarshalPrimitive(dataIn)
            if (let Some(key) <- key) {
                map[key] = val
            }
        }
        return map
    }

    private static func unmarshalPrimitive(dataIn: ByteBuffer): Any {
        let dataType = dataIn.getInt8()
        let value = match (dataType) {
            case 0 => return Option<Any>.None
            case 1 => return getBool(dataIn)
            case 2 => return dataIn.getByte()
            case 3 => return Rune(dataIn.getUInt32())
            case 4 => return dataIn.getInt16()
            case 5 => return dataIn.getInt32()
            case 6 => return dataIn.getInt64()
            case 7 => return getFloat64(dataIn)
            case 8 => return getFloat32(dataIn)
            case 9 =>
                var value = readUTF(dataIn)
                if (let Some(value) <- value) {
                    return value
                }
                return None<String>
            case 10 =>
                let byteArray = Array<Byte>(Int64(dataIn.getInt32()), repeat: 0)
                dataIn.get(byteArray)
                return byteArray
            case 13 =>
                var value = readUTF8(dataIn)
                if (let Some(value) <- value) {
                    return value
                }
                return None<String>
            case _ => return None<Any>
        }
        return value
    }

    /**
     * 编码String，一个字节用于标示是否有值，有值则继续写值，无值则结束
     */
    public static func marshalPrimitiveString(s: ?String, byteBuffer: ByteBuffer): Unit {
        putBool(s.isSome(), byteBuffer)
        if (let Some(str) <- s) {
            marshalPrimitiveString(str, byteBuffer)
        }
    }

    public static func marshalPrimitiveString(s: String, byteBuffer: ByteBuffer): Unit {
        let len = Int64(32767) / 4
        if (s.size < len) {
            byteBuffer.putInt8(STRING_TYPE)
            writeUTF(s, byteBuffer)
        } else {
            byteBuffer.putInt8(BIG_STRING_TYPE)
            writeUTF8(s, byteBuffer)
        }
    }

    public static func marshalByte(value: Byte, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(BYTE_TYPE)
        byteBuffer.putByte(value)
    }

    public static func marshalBool(value: Bool, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(BOOLEAN_TYPE)
        putBool(value, byteBuffer)
    }

    public static func marshalChar(value: Rune, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(CHAR_TYPE)
        //所有的有效char都是有效的u32
        byteBuffer.putUInt32(UInt32(value))
    }

    public static func marshalInt16(value: Int16, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(SHORT_TYPE)
        byteBuffer.putInt16(value)
    }

    public static func marshalInt32(value: Int32, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(INTEGER_TYPE)
        byteBuffer.putInt32(value)
    }

    public static func marshalInt64(value: Int64, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(LONG_TYPE)
        byteBuffer.putInt64(value)
    }

    public static func marshalFloat32(value: Float32, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(FLOAT_TYPE)
        putFloat32(value, byteBuffer)
    }

    public static func marshalFloat64(value: Float64, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(DOUBLE_TYPE)
        putFloat64(value, byteBuffer)
    }

    public static func marshalByteArray(value: Array<Byte>, byteBuffer: ByteBuffer): Unit {
        byteBuffer.putInt8(BYTE_ARRAY_TYPE)
        byteBuffer.putInt32(Int32(value.size))
        byteBuffer.put(value)
    }

    public static func readUTF8(dataIn: ByteBuffer): ?String {
        //先读取四字节字符串长度
        let strLen = dataIn.getInt32()
        if (strLen == 0) {
            return None
        }
        let byteArray = Array<Byte>(Int64(strLen), repeat: 0)
        dataIn.get(byteArray)
        return String.fromUtf8(byteArray)
    }

    public static func readUTF(dataIn: ByteBuffer): ?String {
        //先读取两字节字符串长度
        let strLen = dataIn.getInt16()
        if (strLen == 0) {
            return None
        }
        let byteArray = Array<Byte>(Int64(strLen), repeat: 0)
        dataIn.get(byteArray)
        return String.fromUtf8(byteArray)
    }

    public static func writeUTF(s: String, byteBuffer: ByteBuffer): Unit {
        let array = s.toArray()
        let size = array.size
        if (size > 65535) {
            throw IOException("Encoded string too long: ${size} length")
        }
        byteBuffer.putInt16(Int16(size))
        putByteArray(array, byteBuffer)
    }

    public static func writeUTF8(s: String, byteBuffer: ByteBuffer): Unit {
        let array = s.toArray()
        byteBuffer.putInt32(Int32(array.size))
        putByteArray(array, byteBuffer)
    }

    public static func putByteArray(value: Array<Byte>, byteBuffer: ByteBuffer): Unit {
        capacityCheckAndExpand(value.size, byteBuffer)
        byteBuffer.put(value)
    }

    public static func getBool(dataIn: ByteBuffer): Bool {
        return dataIn.getByte() == 1
    }

    public static func putBool(bool: Bool, byteBuffer: ByteBuffer) {
        capacityCheckAndExpand(Int64(sizeOf<Bool>()), byteBuffer)
        if (bool) {
            byteBuffer.putByte(1)
        } else {
            byteBuffer.putByte(0)
        }
    }

    public static func getFloat32(dataIn: ByteBuffer): Float32 {
        //先读同等位数的UInt32，然后利用C指针转换
        let val: UInt32 = dataIn.getUInt32()
        unsafe {
            var cpoint = malloc(sizeOf<UInt32>())
            var ptrUInt32: CPointer<UInt32> = CPointer<UInt32>(cpoint)
            ptrUInt32.write(val)
            var ptrFloat32 = CPointer<Float32>(ptrUInt32)
            let result: Float32 = ptrFloat32.read()
            free(cpoint)
            return result
        }
    }

    public static func putFloat32(f: Float32, byteBuffer: ByteBuffer): Unit {
        capacityCheckAndExpand(Int64(sizeOf<Float32>()), byteBuffer)
        unsafe {
            var cpoint = malloc(sizeOf<Float32>())
            var ptrFloat32: CPointer<Float32> = CPointer<Float32>(cpoint)
            ptrFloat32.write(f)
            var ptrUInt32 = CPointer<UInt32>(ptrFloat32)
            byteBuffer.putUInt32(ptrUInt32.read())
            free(cpoint)
        }
    }

    public static func getFloat64(dataIn: ByteBuffer): Float64 {
        //先读同等位数的UInt64，然后利用C指针转换
        let val: UInt64 = dataIn.getUInt64()
        unsafe {
            var cpoint = malloc(sizeOf<UInt64>())
            var ptrUInt64: CPointer<UInt64> = CPointer<UInt64>(cpoint)
            ptrUInt64.write(val)
            var ptrFloat64 = CPointer<Float64>(ptrUInt64)
            let result: Float64 = ptrFloat64.read()
            free(cpoint)
            return result
        }
    }

    public static func putFloat64(f: Float64, byteBuffer: ByteBuffer): Unit {
        capacityCheckAndExpand(Int64(sizeOf<Float64>()), byteBuffer)
        unsafe {
            var cpoint = malloc(sizeOf<Float64>())
            var ptrFloat64: CPointer<Float64> = CPointer<Float64>(cpoint)
            ptrFloat64.write(f)
            var ptrUInt64 = CPointer<UInt64>(ptrFloat64)
            byteBuffer.putUInt64(ptrUInt64.read())
            free(cpoint)
        }
    }

    private static func capacityCheckAndExpand(requiresCapacity: Int64, byteBuffer: ByteBuffer): Unit {
        let minLimit = byteBuffer.position() + requiresCapacity
        if (minLimit > byteBuffer.limit()) {
            if (byteBuffer.expandSupport) {
                let newLimit = byteBuffer.position() + requiresCapacity
                if (newLimit < 1024) {
                    byteBuffer.expandAndLimit(newLimit << 1)
                } else {
                    byteBuffer.expandAndLimit(newLimit + 1024)
                }
            }
        }
    }
}
