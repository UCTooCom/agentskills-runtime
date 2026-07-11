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
package activemq_client_unit_test

@Test
public class TypeConversionSupportTest {
    @TestCase
    public func testConvertToBool(): Unit {
        var s1: String = "true"
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Bool>()) as Bool == Some(true))

        var s2: ?String = "false"
        @Assert(TypeConversionSupport.convert(s2, TypeInfo.of<Bool>()) as Bool == Some(false))

        var s3 = true
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Bool>()) as Bool == Some(true))

        var s4 = 3
        try {
            TypeConversionSupport.convert(s4, TypeInfo.of<Bool>())
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }
    }

    @TestCase
    public func testConvertToByte(): Unit {
        var s1: String = "0"
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Byte>()) as Byte == Some(0))

        var s2: ?String = "256"
        try {
            TypeConversionSupport.convert(s2, TypeInfo.of<Byte>()) as Byte
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s3: Byte = 255
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Byte>()) as Byte == Some(255))

        var s4 = "hello"
        try {
            TypeConversionSupport.convert(s4, TypeInfo.of<Byte>())
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s5 = Int8(8)
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<Byte>()) as Byte == Some(8))
    }

    @TestCase
    public func testConvertToInt8(): Unit {
        var s1: String = "0"
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Int8>()) as Int8 == Some(0))

        var s2: ?String = "256"
        try {
            TypeConversionSupport.convert(s2, TypeInfo.of<Int8>()) as Int8
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s3: Byte = 1
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Byte>()) as Byte == Some(1))

        var s4 = "hello"
        try {
            TypeConversionSupport.convert(s4, TypeInfo.of<Byte>())
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s5 = Int8(8)
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<Byte>()) as Byte == Some(8))
    }

    @TestCase
    public func testConvertToInt16(): Unit {
        var s1: String = Int16.Min.toString()
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Int16>()) as Int16 == Some(Int16.Min))

        var s2: ?String = "32800"
        try {
            TypeConversionSupport.convert(s2, TypeInfo.of<Int16>()) as Int16
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s3: ?String = Some(Int16.Max.toString())
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Int16>()) as Int16 == Some(Int16.Max))

        var s4: Byte = 110
        @Assert(TypeConversionSupport.convert(s4, TypeInfo.of<Int16>()) as Int16 == Some(110))

        var s5: Int16 = 200
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<Int16>()) as Int16 == Some(200))

        var s6: Int8 = -1
        @Assert(TypeConversionSupport.convert(s6, TypeInfo.of<Int16>()) as Int16 == Some(-1))

        var s7: UInt16 = 3
        @Assert(TypeConversionSupport.convert(s7, TypeInfo.of<Int16>()) as Int16 == Some(3))
    }

    @TestCase
    public func testConvertToUInt16(): Unit {
        var s1: String = UInt16.Max.toString()
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<UInt16>()) as UInt16 == Some(UInt16.Max))

        var s3: ?String = Some(UInt16.Max.toString())
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<UInt16>()) as UInt16 == Some(UInt16.Max))

        var s4: Byte = 110
        @Assert(TypeConversionSupport.convert(s4, TypeInfo.of<UInt16>()) as UInt16 == Some(110))

        var s5: Int16 = 200
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<UInt16>()) as UInt16 == Some(200))

        var s6: Int8 = 1
        @Assert(TypeConversionSupport.convert(s6, TypeInfo.of<UInt16>()) as UInt16 == Some(1))

        var s7: UInt16 = 3
        @Assert(TypeConversionSupport.convert(s7, TypeInfo.of<UInt16>()) as UInt16 == Some(3))
    }

    @TestCase
    public func testConvertToInt32(): Unit {
        var s1: String = Int32.Min.toString()
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Int32>()) as Int32 == Some(Int32.Min))

        var s2: ?String = Some((Int64(Int32.Max) + 100).toString())
        try {
            TypeConversionSupport.convert(s2, TypeInfo.of<Int32>()) as Int32
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s3: ?String = Some(Int32.Max.toString())
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Int32>()) as Int32 == Some(Int32.Max))

        var s4: Byte = 110
        @Assert(TypeConversionSupport.convert(s4, TypeInfo.of<Int32>()) as Int32 == Some(110))

        var s5: Int16 = 200
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<Int32>()) as Int32 == Some(200))

        var s6: Int32 = 360
        @Assert(TypeConversionSupport.convert(s6, TypeInfo.of<Int32>()) as Int32 == Some(360))

        var s7: Int8 = 1
        @Assert(TypeConversionSupport.convert(s7, TypeInfo.of<Int32>()) as Int32 == Some(1))

        var s8: UInt16 = 1
        @Assert(TypeConversionSupport.convert(s8, TypeInfo.of<Int32>()) as Int32 == Some(1))

        var s9: UInt32 = 1
        @Assert(TypeConversionSupport.convert(s9, TypeInfo.of<Int32>()) as Int32 == Some(1))
    }

    @TestCase
    public func testConvertToUInt32(): Unit {
        var s1: String = UInt32.Max.toString()
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<UInt32>()) as UInt32 == Some(UInt32.Max))

        var s2: ?String = Some((UInt64(UInt32.Max) + 100).toString())
        try {
            TypeConversionSupport.convert(s2, TypeInfo.of<UInt32>()) as UInt32
            @Assert(false)
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s3: ?String = Some(UInt32.Max.toString())
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<UInt32>()) as UInt32 == Some(UInt32.Max))

        var s4: Byte = 110
        @Assert(TypeConversionSupport.convert(s4, TypeInfo.of<UInt32>()) as UInt32 == Some(110))

        var s5: Int16 = 200
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<UInt32>()) as UInt32 == Some(200))

        var s6: Int32 = 360
        @Assert(TypeConversionSupport.convert(s6, TypeInfo.of<UInt32>()) as UInt32 == Some(360))

        var s7: Int8 = 1
        @Assert(TypeConversionSupport.convert(s7, TypeInfo.of<UInt32>()) as UInt32 == Some(1))

        var s8: UInt16 = 1
        @Assert(TypeConversionSupport.convert(s8, TypeInfo.of<UInt32>()) as UInt32 == Some(1))

        var s9: UInt32 = 1
        @Assert(TypeConversionSupport.convert(s9, TypeInfo.of<UInt32>()) as UInt32 == Some(1))
    }

    @TestCase
    public func testConvertToInt64(): Unit {
        var s1: String = Int64.Min.toString()
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Int64>()) as Int64 == Some(Int64.Min))

        var s2: ?String = Some(UInt64.Max.toString())
        try {
            TypeConversionSupport.convert(s2, TypeInfo.of<Int64>()) as Int64
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s3: ?String = Some(Int64.Max.toString())
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Int64>()) as Int64 == Some(Int64.Max))

        var s4: Byte = 110
        @Assert(TypeConversionSupport.convert(s4, TypeInfo.of<Int64>()) as Int64 == Some(110))

        var s5: Int16 = 200
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<Int64>()) as Int64 == Some(200))

        var s6: Int32 = 360
        @Assert(TypeConversionSupport.convert(s6, TypeInfo.of<Int64>()) as Int64 == Some(360))

        var s7: Int64 = 580
        @Assert(TypeConversionSupport.convert(s7, TypeInfo.of<Int64>()) as Int64 == Some(580))

        var s8: Byte = 1
        @Assert(TypeConversionSupport.convert(s8, TypeInfo.of<Int64>()) as Int64 == Some(1))

        var s9: UInt16 = 1
        @Assert(TypeConversionSupport.convert(s9, TypeInfo.of<Int64>()) as Int64 == Some(1))

        var s10: UInt32 = 1
        @Assert(TypeConversionSupport.convert(s10, TypeInfo.of<Int64>()) as Int64 == Some(1))

        var s11: UInt64 = 1
        @Assert(TypeConversionSupport.convert(s11, TypeInfo.of<Int64>()) as Int64 == Some(1))
    }

    @TestCase
    public func testConvertToUInt64(): Unit {
        var s1: String = UInt64.Max.toString()
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<UInt64>()) as UInt64 == Some(UInt64.Max))

        var s3: ?String = Some(UInt64.Max.toString())
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<UInt64>()) as UInt64 == Some(UInt64.Max))

        var s4: Byte = 110
        @Assert(TypeConversionSupport.convert(s4, TypeInfo.of<UInt64>()) as UInt64 == Some(110))

        var s5: Int16 = 200
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<UInt64>()) as UInt64 == Some(200))

        var s6: Int32 = 360
        @Assert(TypeConversionSupport.convert(s6, TypeInfo.of<UInt64>()) as UInt64 == Some(360))

        var s7: Int64 = 580
        @Assert(TypeConversionSupport.convert(s7, TypeInfo.of<UInt64>()) as UInt64 == Some(580))

        var s8: Byte = 1
        @Assert(TypeConversionSupport.convert(s8, TypeInfo.of<UInt64>()) as UInt64 == Some(1))

        var s9: UInt16 = 1
        @Assert(TypeConversionSupport.convert(s9, TypeInfo.of<UInt64>()) as UInt64 == Some(1))

        var s10: UInt32 = 1
        @Assert(TypeConversionSupport.convert(s10, TypeInfo.of<UInt64>()) as UInt64 == Some(1))

        var s11: UInt64 = 1
        @Assert(TypeConversionSupport.convert(s11, TypeInfo.of<UInt64>()) as UInt64 == Some(1))
    }

    @TestCase
    public func testConvertToFloat32(): Unit {
        var s1: String = "0"
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Float32>()) as Float32 == Some(Float32(0)))

        var s2: ?String = "3.369"
        @Assert(TypeConversionSupport.convert(s2, TypeInfo.of<Float32>()) as Float32 == Some(3.369))

        var s3: Float32 = 3.321
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Float32>()) as Float32 == Some(3.321))

        var s4 = "hello"
        try {
            TypeConversionSupport.convert(s4, TypeInfo.of<Float32>())
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }
    }

    @TestCase
    public func testConvertToFloat64(): Unit {
        var s1: String = "0"
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<Float64>()) as Float64 == Some(Float64(0)))

        var s2: ?String = "3.369"
        @Assert(TypeConversionSupport.convert(s2, TypeInfo.of<Float64>()) as Float64 == Some(3.369))

        var s3: Float32 = 3.321
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<Float64>()) as Float64 == Some(Float64(s3)))

        var s4 = "hello"
        try {
            TypeConversionSupport.convert(s4, TypeInfo.of<Float64>())
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        var s5: Float64 = 6.321
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<Float64>()) as Float64 == Some(6.321))
    }

    @TestCase
    public func testConvertToString(): Unit {
        var s1: String = "test"
        @Assert(TypeConversionSupport.convert(s1, TypeInfo.of<String>()) as String == Some(s1))

        var s2: Bool = false
        @Assert(TypeConversionSupport.convert(s2, TypeInfo.of<String>()) as String == Some(s2.toString()))

        var s3: Byte = 6
        @Assert(TypeConversionSupport.convert(s3, TypeInfo.of<String>()) as String == Some(s3.toString()))

        var s4: Int16 = 3000
        @Assert(TypeConversionSupport.convert(s4, TypeInfo.of<String>()) as String == Some(s4.toString()))

        var s5: Int32 = 31006
        @Assert(TypeConversionSupport.convert(s5, TypeInfo.of<String>()) as String == Some(s5.toString()))

        var s6: Int64 = Int64(Int32.Max)
        @Assert(TypeConversionSupport.convert(s6, TypeInfo.of<String>()) as String == Some(s6.toString()))

        var s7: Float32 = -3.321
        @Assert(TypeConversionSupport.convert(s7, TypeInfo.of<String>()) as String == Some(s7.toString()))

        var s8: Float64 = 6.321
        @Assert(TypeConversionSupport.convert(s8, TypeInfo.of<String>()) as String == Some(s8.toString()))
    }

    @TestCase
    public func testGenericConvert(): Unit {
        var s1: String = "164"
        @Assert(TypeConversionSupport.genericConvert<Int64>(s1, TypeInfo.of<Int64>()) == 164)
    }
}
