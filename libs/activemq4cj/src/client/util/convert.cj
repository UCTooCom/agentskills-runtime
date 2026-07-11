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

public class Convert {
    /**
     * u8转i8
     */
    public static func convertToInt8(value: UInt8): Int8 {
        let u8Pointer: CPointer<UInt8> = LibC.malloc<UInt8>(count: Int64(sizeOf<UInt8>()))
        unsafe {
            u8Pointer.write(value)
            let rc = CPointer<Int8>(u8Pointer).read()
            LibC.free<UInt8>(u8Pointer)
            return rc
        }
    }

    /**
     * i8转u8
     */
    public static func convertToUInt8(value: Int8): UInt8 {
        let i8Pointer: CPointer<Int8> = LibC.malloc<Int8>(count: Int64(sizeOf<Int8>()))
        unsafe {
            i8Pointer.write(value)
            let rc = CPointer<UInt8>(i8Pointer).read()
            LibC.free<Int8>(i8Pointer)
            return rc
        }
    }

    /**
     * u16转i16
     */
    public static func convertToInt16(value: UInt16): Int16 {
        let u16Pointer: CPointer<UInt16> = LibC.malloc<UInt16>(count: Int64(sizeOf<UInt16>()))
        unsafe {
            u16Pointer.write(value)
            let rc = CPointer<Int16>(u16Pointer).read()
            LibC.free<UInt16>(u16Pointer)
            return rc
        }
    }

    /**
     * i16转u16
     */
    public static func convertToUInt16(value: Int16): UInt16 {
        let i16Pointer: CPointer<Int16> = LibC.malloc<Int16>(count: Int64(sizeOf<Int16>()))
        unsafe {
            i16Pointer.write(value)
            let rc = CPointer<UInt16>(i16Pointer).read()
            LibC.free<Int16>(i16Pointer)
            return rc
        }
    }

    /**
     * u32转i32
     */
    public static func convertToInt32(value: UInt32): Int32 {
        let u32Pointer: CPointer<UInt32> = LibC.malloc<UInt32>(count: Int64(sizeOf<UInt32>()))
        unsafe {
            u32Pointer.write(value)
            let rc = CPointer<Int32>(u32Pointer).read()
            LibC.free<UInt32>(u32Pointer)
            return rc
        }
    }

    /**
     * i32转u32
     */
    public static func convertToUInt32(value: Int32): UInt32 {
        let i32Pointer: CPointer<Int32> = LibC.malloc<Int32>(count: Int64(sizeOf<Int32>()))
        unsafe {
            i32Pointer.write(value)
            let rc = CPointer<UInt32>(i32Pointer).read()
            LibC.free<Int32>(i32Pointer)
            return rc
        }
    }

    /**
     * u32转i32
     */
    public static func convertToInt64(value: UInt64): Int64 {
        let u64Pointer: CPointer<UInt64> = LibC.malloc<UInt64>(count: Int64(sizeOf<UInt64>()))
        unsafe {
            u64Pointer.write(value)
            let rc = CPointer<Int64>(u64Pointer).read()
            LibC.free<UInt64>(u64Pointer)
            return rc
        }
    }

    /**
     * i32转u32
     */
    public static func convertToUInt64(value: Int64): UInt64 {
        let i64Pointer: CPointer<Int64> = LibC.malloc<Int64>(count: Int64(sizeOf<Int64>()))
        unsafe {
            i64Pointer.write(value)
            let rc = CPointer<UInt64>(i64Pointer).read()
            LibC.free<Int64>(i64Pointer)
            return rc
        }
    }
}
