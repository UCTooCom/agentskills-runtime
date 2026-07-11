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

package hyperion.buffer

import std.unittest.testmacro.*

/**
 * ByteBuffer单元测试
 *
 * @author yangfuping
 */
@Test
public class ByteBufferTest {
    protected static let logger = LoggerFactory.getLogger("transport")

    static func allocateByteBuffer(): ByteBuffer {
        return ByteBuffer.allocate()
    }

    @TestCase
    public func testAllocate(): Unit {
        logger.log(LogLevel.INFO, "Test ByteBuffer.allocate()")

        let buffer = allocateByteBuffer()
        logger.log(LogLevel.INFO, "Allocated ByteBuffer: ${buffer}")
        @Assert(buffer.position() == 0)
        @Assert(buffer.limit() == ByteBuffer.DEFAULT_INITIAL_CAPACITY)
        @Assert(buffer.capacity() == ByteBuffer.DEFAULT_INITIAL_CAPACITY)
        @Assert(buffer.remaining() == ByteBuffer.DEFAULT_INITIAL_CAPACITY)
        @Assert(buffer.hasRemaining() == true)
        logger.log(LogLevel.INFO, "Allocated ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, ByteBufferTestUtis.LINE_SPERATOR)
    }

    @TestCase
    public func testPutAndGetByte(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取Byte

        // 1.1 测试 UInt8.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Min)

        // 1.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, 1)

        // 1.3 测试 UInt8.Max/2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max / 2)

        // 1.4 测试 UInt8.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max - 1)

        // 1.5 测试 UInt8.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max)

        // 2. 测试在中间位置存储和获取Byte
        // 2.1 测试 UInt8.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Min)

        // 2.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, 1)

        // 2.3 测试 UInt8.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max / 2)

        // 2.4 测试 UInt8.Max - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max - 1)

        // 2.5 测试 UInt8.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max)

        // 3. 测试在末尾位置存储和获取Byte
        // 3.1 测试 UInt8.Min
        position = buffer.capacity() - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Min)

        // 3.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, 1)

        // 3.3 测试 UInt8.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max / 2)

        // 3.4 测试 UInt8.Max - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max - 1)

        // 3.5 测试 UInt8.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetByte(buffer, position, UInt8.Max)
    }

    @TestCase
    public func testPutAndGetUInt16(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取UInt16

        // 1.1 测试 UInt16.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Min)

        // 1.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, 1)

        // 1.3 测试 UInt16.Max/2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max / 2)

        // 1.4 测试 UInt16.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max - 1)

        // 1.5 测试 UInt16.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max)

        // 2. 测试在中间位置存储和获取UInt16
        // 2.1 测试 UInt16.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Min)

        // 2.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, 1)

        // 2.3 测试 UInt16.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max / 2)

        // 2.4 测试 UInt16.Max - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max - 1)

        // 2.5 测试 UInt16.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max)

        // 3. 测试在末尾位置存储和获取UInt16
        // 3.1 测试 UInt16.Min
        position = buffer.capacity() - 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Min)

        // 3.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, 1)

        // 3.3 测试 UInt16.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max / 2)

        // 3.4 测试 UInt16.Max - 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max - 1)

        // 3.5 测试 UInt16.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt16(buffer, position, UInt16.Max)
    }

    @TestCase
    public func testPutAndGetUInt32(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取UInt32

        // 1.1 测试 UInt32.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Min)

        // 1.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, 1)

        // 1.3 测试 UInt32.Max/2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max / 2)

        // 1.4 测试 UInt32.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max - 1)

        // 1.5 测试 UInt32.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max)

        // 2. 测试在中间位置存储和获取UInt32
        // 2.1 测试 UInt32.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Min)

        // 2.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, 1)

        // 2.3 测试 UInt32.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max / 2)

        // 2.4 测试 UInt32.Max - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max - 1)

        // 2.5 测试 UInt32.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max)

        // 3. 测试在末尾位置存储和获取UInt32
        // 3.1 测试 UInt32.Min
        position = buffer.capacity() - 4
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Min)

        // 3.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, 1)

        // 3.3 测试 UInt32.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max / 2)

        // 3.4 测试 UInt32.Max - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max - 1)

        // 3.5 测试 UInt32.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt32(buffer, position, UInt32.Max)
    }

    @TestCase
    public func testPutAndGetUInt64(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取UInt64

        // 1.1 测试 UInt64.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Min)

        // 1.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, 1)

        // 1.3 测试 UInt64.Max/2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max / 2)

        // 1.4 测试 UInt64.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max - 1)

        // 1.5 测试 UInt64.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max)

        // 2. 测试在中间位置存储和获取UInt64
        // 2.1 测试 UInt64.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Min)

        // 2.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, 1)

        // 2.3 测试 UInt64.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max / 2)

        // 2.4 测试 UInt64.Max - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max - 1)

        // 2.5 测试 UInt64.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max)

        // 3. 测试在末尾位置存储和获取UInt64
        // 3.1 测试 UInt64.Min
        position = buffer.capacity() - 8
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Min)

        // 3.2 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, 1)

        // 3.3 测试 UInt64.Max / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max / 2)

        // 3.4 测试 UInt64.Max - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max - 1)

        // 3.5 测试 UInt64.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetUInt64(buffer, position, UInt64.Max)
    }

    @TestCase
    public func testPutAndGetInt8(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取Byte

        // 1.1 测试 Int8.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Min)

        // 1.2 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, -1)

        // 1.3 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, 0)

        // 1.4 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, 1)

        // 1.5 测试 Int8.Max/2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max / 2)

        // 1.6 测试 Int8.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max - 1)

        // 1.7 测试 Int8.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max)

        // 2. 测试在中间位置存储和获取Byte
        // 2.1 测试 Int8.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Min)

        // 2.2 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, -1)

        // 2.3 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, 0)

        // 2.4 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, 1)

        // 2.5 测试 Int8.Max/2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max / 2)

        // 2.6 测试 Int8.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max - 1)

        // 2.7 测试 Int8.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max)

        // 3. 测试在末尾位置存储和获取Byte
        // 3.1 测试 Int8.Min
        position = buffer.capacity() - 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Min)

        // 3.2 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, -1)

        // 3.3 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, 0)

        // 3.4 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, 1)

        // 3.5 测试 Int8.Max/2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max / 2)

        // 3.6 测试 Int8.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max - 1)

        // 3.7 测试 Int8.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt8(buffer, position, Int8.Max)
    }

    @TestCase
    public func testPutAndGetInt16(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取Int16

        // 1.1 测试 Int16.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Min)

        // 1.2 测试 -(Int8.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, -(Int16(Int8.Max) + 1))

        // 1.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, -1)

        // 1.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, 0)

        // 1.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, 1)

        // 1.6 测试 Int8.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16(Int8.Max) + 1)

        // 1.7 测试 Int16.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Max - 1)

        // 1.8 测试 Int16.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Max)

        // 2. 测试在中间位置存储和获取Int16
        // 2.1 测试 Int16.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Min)

        // 2.2 测试 -(Int8.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, -(Int16(Int8.Max) + 1))

        // 2.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, -1)

        // 2.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, 0)

        // 2.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, 1)

        // 2.6 测试 Int8.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16(Int8.Max) + 1)

        // 2.7 测试 Int16.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Max - 1)

        // 2.8 测试 Int16.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Max)

        // 3. 测试在末尾位置存储和获取Int16
        // 3.1 测试 Int16.Min
        position = buffer.capacity() - 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Min)

        // 3.2 测试 -(Int8.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, -(Int16(Int8.Max) + 1))

        // 3.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, -1)

        // 3.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, 0)

        // 3.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, 1)

        // 3.6 测试 Int8.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16(Int8.Max) + 1)

        // 3.7 测试 Int16.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Max - 1)

        // 3.8 测试 Int16.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt16(buffer, position, Int16.Max)
    }

    @TestCase
    public func testPutAndGetInt32(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取Int32

        // 1.1 测试 Int32.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Min)

        // 1.2 测试 -(Int16.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, -(Int32(Int16.Max) + 1))

        // 1.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, -1)

        // 1.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, 0)

        // 1.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, 1)

        // 1.6 测试 Int16.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32(Int16.Max) + 1)

        // 1.7 测试 Int16.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Max - 1)

        // 1.8 测试 Int32.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Max)

        // 2. 测试在中间位置存储和获取Int32
        // 2.1 测试 Int32.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Min)

        // 2.2 测试 -(Int8.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, -(Int32(Int16.Max) + 1))

        // 2.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, -1)

        // 2.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, 0)

        // 2.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, 1)

        // 2.6 测试 Int8.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32(Int8.Max) + 1)

        // 2.7 测试 Int16.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Max - 1)

        // 2.8 测试 Int32.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Max)

        // 3. 测试在末尾位置存储和获取Int32
        // 3.1 测试 Int32.Min
        position = buffer.capacity() - 4
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Min)

        // 3.2 测试 -(Int8.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, -(Int32(Int16.Max) + 1))

        // 3.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, -1)

        // 3.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, 0)

        // 3.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, 1)

        // 3.6 测试 Int16.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32(Int16.Max) + 1)

        // 3.7 测试 Int32.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Max - 1)

        // 3.8 测试 Int32.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt32(buffer, position, Int32.Max)
    }

    @TestCase
    public func testPutAndGetInt64(): Unit {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取Int64

        // 1.1 测试 Int64.Min
        var position = 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Min)

        // 1.2 测试 -(Int32.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, -(Int64(Int32.Max) + 1))

        // 1.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, -1)

        // 1.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, 0)

        // 1.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, 1)

        // 1.6 测试 Int32.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64(Int32.Max) + 1)

        // 1.7 测试 Int32.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Max - 1)

        // 1.8 测试 Int64.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Max)

        // 2. 测试在中间位置存储和获取Int64
        // 2.1 测试 Int64.Min
        position = buffer.capacity() / 2
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Min)

        // 2.2 测试 -(Int8.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, -(Int64(Int32.Max) + 1))

        // 2.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, -1)

        // 2.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, 0)

        // 2.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, 1)

        // 2.6 测试 Int8.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64(Int8.Max) + 1)

        // 2.7 测试 Int32.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Max - 1)

        // 2.8 测试 Int64.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Max)

        // 3. 测试在末尾位置存储和获取Int64
        // 3.1 测试 Int64.Min
        position = buffer.capacity() - 8
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Min)

        // 3.2 测试 -(Int8.Max + 1)
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, -(Int64(Int32.Max) + 1))

        // 3.3 测试 -1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, -1)

        // 3.4 测试 0
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, 0)

        // 3.5 测试 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, 1)

        // 3.6 测试 Int32.Max + 1
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64(Int32.Max) + 1)

        // 3.7 测试 Int64.Max -1 
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Max - 1)

        // 3.8 测试 Int64.Max
        buffer.position(position)
        ByteBufferTestUtis.putAndGetInt64(buffer, position, Int64.Max)
    }

    @TestCase
    public func testPutAndGetSimpleString() {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取String
        var position = 0
        buffer.position(position)
        var message = "This is a sample message"
        var size = ByteBufferTestUtis.putString(buffer, message)
        var dst = Array<Byte>(size, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, dst, message)
        var expandDst = Array<Byte>(size + 5, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, expandDst, 5, size, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, dst, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, expandDst, 5, size, message)

        // 2. 测试在中间位置存储和获取String
        position = buffer.capacity() / 2
        buffer.position(position)
        size = ByteBufferTestUtis.putString(buffer, message)
        dst = Array<Byte>(size, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, dst, message)

        expandDst = Array<Byte>(size + 7, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, expandDst, 7, size, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, dst, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, expandDst, 7, size, message)

        // 3. 测试在末尾位置存储和获取String
        let arr = message.toArray()
        position = buffer.capacity() - arr.size
        buffer.position(position)
        size = ByteBufferTestUtis.putString(buffer, message)

        expandDst = Array<Byte>(size + 12, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, expandDst, 12, size, message)

        @Assert((buffer.hasRemaining() == false))
        @Assert(buffer.remaining() == 0)

        dst = Array<Byte>(size, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, dst, message)
        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, dst, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, expandDst, 12, size, message)
    }

    @TestCase
    public func testPutAndGetLongString() {
        let buffer = allocateByteBuffer()

        // 1. 测试在起始位置存储和获取String
        var position = 0
        buffer.position(position)
        var message = ByteBufferTestUtis.generateLengthedString(buffer.capacity() - 1)
        var size = ByteBufferTestUtis.putString(buffer, message)
        var dst = Array<Byte>(size, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, dst, message)
        var expandDst = Array<Byte>(size + 5, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, expandDst, 5, size, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, dst, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, expandDst, 5, size, message)

        // 2. 测试在末尾位置存储和获取String
        var arr = message.toArray()
        position = buffer.capacity() - arr.size
        buffer.position(position)
        size = ByteBufferTestUtis.putString(buffer, message)

        expandDst = Array<Byte>(size + 12, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, expandDst, 12, size, message)

        @Assert((buffer.hasRemaining() == false))
        @Assert(buffer.remaining() == 0)

        dst = Array<Byte>(size, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, dst, message)
        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, dst, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, expandDst, 12, size, message)

        // 1. 测试在起始位置存储和获取String
        position = 0
        buffer.position(position)
        message = ByteBufferTestUtis.generateLengthedString(buffer.capacity())
        size = ByteBufferTestUtis.putString(buffer, message)
        dst = Array<Byte>(size, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, dst, message)
        expandDst = Array<Byte>(size + 5, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, expandDst, 5, size, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, dst, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, expandDst, 5, size, message)

        // 2. 测试在末尾位置存储和获取String
        arr = message.toArray()
        position = buffer.capacity() - arr.size
        buffer.position(position)
        size = ByteBufferTestUtis.putString(buffer, message)

        expandDst = Array<Byte>(size + 12, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, expandDst, 12, size, message)

        @Assert((buffer.hasRemaining() == false))
        @Assert(buffer.remaining() == 0)

        dst = Array<Byte>(size, repeat: 0)
        ByteBufferTestUtis.getStringAtIndex(buffer, position, dst, message)
        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, dst, message)

        buffer.position(position)
        ByteBufferTestUtis.getStringAtPosition(buffer, expandDst, 12, size, message)
    }

    @TestCase
    public func testExpandPutAndGetByte(): Unit {

        // 1. 测试在末尾位置扩容并存取Byte

        // 1.1 测试 UInt8.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetByte(buffer, UInt8.Min)

        // 1.2 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetByte(buffer, 1)

        // 1.3 测试 UInt8.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetByte(buffer, UInt8.Max / 2)

        // 1.4 测试 UInt8.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetByte(buffer, UInt8.Max - 1)

        // 1.5 测试 UInt8.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetByte(buffer, UInt8.Max)
    }

    @TestCase
    public func testExpandPutAndGetUInt16(): Unit {

        // 1. 测试在末尾位置扩容并存取UInt16

        // 1.1 测试 UInt16.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt16(buffer, UInt16.Min)

        // 1.2 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt16(buffer, 1)

        // 1.3 测试 UInt16.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt16(buffer, UInt16.Max / 2)

        // 1.4 测试 UInt16.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt16(buffer, UInt16.Max - 1)

        // 1.5 测试 UInt16.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt16(buffer, UInt16.Max)
    }

    @TestCase
    public func testExpandPutAndGetUInt32(): Unit {

        // 1. 测试在末尾位置扩容并存取UInt32

        // 1.1 测试 UInt32.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt32(buffer, UInt32.Min)

        // 1.2 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt32(buffer, 1)

        // 1.3 测试 UInt32.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt32(buffer, UInt32.Max / 2)

        // 1.4 测试 UInt32.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt32(buffer, UInt32.Max - 1)

        // 1.5 测试 UInt32.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt32(buffer, UInt32.Max)
    }

    @TestCase
    public func testExpandPutAndGetUInt64(): Unit {

        // 1. 测试在末尾位置扩容并存取UInt64

        // 1.1 测试 UInt64.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt64(buffer, UInt64.Min)

        // 1.2 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt64(buffer, 1)

        // 1.3 测试 UInt64.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt64(buffer, UInt64.Max / 2)

        // 1.4 测试 UInt64.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt64(buffer, UInt64.Max - 1)

        // 1.5 测试 UInt64.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetUInt64(buffer, UInt64.Max)
    }

    @TestCase
    public func testExpandPutAndGetIn8(): Unit {

        // 1. 测试在末尾位置扩容并存取Byte

        // 1.1 测试 Int8.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt8(buffer, Int8.Min)

        // 1.2 测试 -1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt8(buffer, -1)

        // 1.3 测试 0
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt8(buffer, 0)

        // 1.4 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt8(buffer, 1)

        // 1.5 测试 Int8.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt8(buffer, Int8.Max / 2)

        // 1.6 测试 Int8.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt8(buffer, Int8.Max - 1)

        // 1.7 测试 Int8.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt8(buffer, Int8.Max)
    }

    @TestCase
    public func testExpandPutAndGetInt16(): Unit {

        // 1. 测试在末尾位置扩容并存取Byte

        // 1.1 测试 Int16.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt16(buffer, Int16.Min)

        // 1.2 测试 -1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt16(buffer, -1)

        // 1.3 测试 0
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt16(buffer, 0)

        // 1.4 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt16(buffer, 1)

        // 1.5 测试 Int16.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt16(buffer, Int16.Max / 2)

        // 1.6 测试 Int16.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt16(buffer, Int16.Max - 1)

        // 1.7 测试 Int16.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt16(buffer, Int16.Max)
    }

    @TestCase
    public func testExpandPutAndGetInt32(): Unit {

        // 1. 测试在末尾位置扩容并存取Byte

        // 1.1 测试 Int32.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt32(buffer, Int32.Min)

        // 1.2 测试 -1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt32(buffer, -1)

        // 1.3 测试 0
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt32(buffer, 0)

        // 1.4 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt32(buffer, 1)

        // 1.5 测试 Int32.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt32(buffer, Int32.Max / 2)

        // 1.6 测试 Int32.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt32(buffer, Int32.Max - 1)

        // 1.7 测试 Int32.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt32(buffer, Int32.Max)
    }

    @TestCase
    public func testExpandPutAndGetInt64(): Unit {

        // 1. 测试在末尾位置扩容并存取Byte

        // 1.1 测试 Int64.Min
        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt64(buffer, Int64.Min)

        // 1.2 测试 -1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt64(buffer, -1)

        // 1.3 测试 0
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt64(buffer, 0)

        // 1.4 测试 1
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt64(buffer, 1)

        // 1.5 测试 Int64.Max/2
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt64(buffer, Int64.Max / 2)

        // 1.6 测试 Int64.Max -1 
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt64(buffer, Int64.Max - 1)

        // 1.7 测试 Int64.Max
        buffer = allocateByteBuffer()
        buffer.limitToCapacity()
        ByteBufferTestUtis.expandPutAndGetInt64(buffer, Int64.Max)
    }

    @TestCase
    public func testExpandPutAndGetSimpleString(): Unit {

        // 1. 测试在末尾位置扩容并存取字符数组

        var buffer = allocateByteBuffer()
        buffer.limitToCapacity()

        var value = "A simple String"
        ByteBufferTestUtis.expandPutAndGetSimpleString(buffer, value)
    }
}
