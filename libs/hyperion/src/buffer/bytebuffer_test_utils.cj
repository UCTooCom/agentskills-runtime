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
 * 辅助ByteBuffer单元测试的工具类
 * 
 * @author yangfuping
 */
public class ByteBufferTestUtis {
    private static let logger = LoggerFactory.getLogger("transport")

    static let LINE_SPERATOR = "--------------------------------------------------------------------------------\n"

    static func putAndGetByte(buffer: ByteBuffer, position: Int64, value: Byte) {
        putUInt8(buffer, value)
        getByteAtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getByteAtPosition(buffer, value)
        buffer.clear()
    }

    protected static func putAndGetUInt16(buffer: ByteBuffer, position: Int64, value: UInt16) {
        putUInt16(buffer, value)
        getUInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt16AtPosition(buffer, value)
        buffer.clear()
    }

    protected static func putAndGetUInt32(buffer: ByteBuffer, position: Int64, value: UInt32) {
        putUInt32(buffer, value)
        getUInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt32AtPosition(buffer, value)
        buffer.clear()
    }

    protected static func putAndGetUInt64(buffer: ByteBuffer, position: Int64, value: UInt64) {
        putUInt64(buffer, value)
        getUInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt64AtPosition(buffer, value)
        buffer.clear()
    }

    static func putAndGetInt8(buffer: ByteBuffer, position: Int64, value: Int8) {
        putInt8(buffer, value)
        getInt8AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt8AtPosition(buffer, value)
        buffer.clear()
    }

    static func putAndGetInt16(buffer: ByteBuffer, position: Int64, value: Int16) {
        putInt16(buffer, value)
        getInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt16AtPosition(buffer, value)
        buffer.clear()
    }

    protected static func putAndGetInt32(buffer: ByteBuffer, position: Int64, value: Int32) {
        putInt32(buffer, value)
        getInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt32AtPosition(buffer, value)
        buffer.clear()
    }

    protected static func putAndGetInt64(buffer: ByteBuffer, position: Int64, value: Int64) {
        putInt64(buffer, value)
        getInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt64AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetByte(buffer: ByteBuffer, value: Byte) {
        let size = 1

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt8 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutByte(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt8 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getByteAtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getByteAtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt8 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutByte(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt8 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getByteAtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getByteAtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetUInt16(buffer: ByteBuffer, value: UInt16) {
        let size = 2

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutUInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getUInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt16AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 差1个字节存储数据
        buffer.position(buffer.capacity() - (size - 1))
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt16AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 差size - 1个字节存储数据
        buffer.position(buffer.capacity() - 1)
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt16AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt16AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetUInt32(buffer: ByteBuffer, value: UInt32) {
        let size = 4

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutUInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getUInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt32AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为size - 1字节
        buffer.position(buffer.capacity() - (size - 1))
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt32AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为1字节
        buffer.position(buffer.capacity() - 1)
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt32AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了，容量剩余为0
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt32AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetUInt64(buffer: ByteBuffer, value: UInt64) {
        let size = 8

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutUInt64(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getUInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt64AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为size - 1字节
        buffer.position(buffer.capacity() - (size - 1))
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt64(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt64AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为1字节
        buffer.position(buffer.capacity() - 1)
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt64(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt64AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了，容量剩余为0
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put UInt64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutUInt64(value)
        logger.log(LogLevel.INFO, "After Expand and put UInt64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getUInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getUInt64AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetInt8(buffer: ByteBuffer, value: Int8) {
        let size = 1

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put Int8 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutInt8(value)
        logger.log(LogLevel.INFO, "After Expand and put Int8 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getInt8AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt8AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put Int8 value ${value} at position: ${buffer.position()}, Int8Buffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt8(value)
        logger.log(LogLevel.INFO, "After Expand and put Int8 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt8AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt8AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetInt16(buffer: ByteBuffer, value: Int16) {
        let size = 2

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put Int16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put Int16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt16AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 差1个字节存储数据
        buffer.position(buffer.capacity() - (size - 1))
        logger.log(
            LogLevel.INFO,
            "Expand and put Int16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put Int16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt16AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 差size - 1个字节存储数据
        buffer.position(buffer.capacity() - 1)
        logger.log(
            LogLevel.INFO,
            "Expand and put Int16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put Int16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt16AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put Int16 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt16(value)
        logger.log(LogLevel.INFO, "After Expand and put Int16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt16AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt16AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetInt32(buffer: ByteBuffer, value: Int32) {
        let size = 4

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put Int32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put Int32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt32AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为size - 1字节
        buffer.position(buffer.capacity() - (size - 1))
        logger.log(
            LogLevel.INFO,
            "Expand and put Int32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put Int32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt32AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为1字节
        buffer.position(buffer.capacity() - 1)
        logger.log(
            LogLevel.INFO,
            "Expand and put Int32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put Int32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt32AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了，容量剩余为0
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put Int32 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt32(value)
        logger.log(LogLevel.INFO, "After Expand and put Int32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt32AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt32AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetInt64(buffer: ByteBuffer, value: Int64) {
        let size = 8

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put Int64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPutInt64(value)
        logger.log(LogLevel.INFO, "After expand and put Int64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        getInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt64AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为size - 1字节
        buffer.position(buffer.capacity() - (size - 1))
        logger.log(
            LogLevel.INFO,
            "Expand and put Int64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt64(value)
        logger.log(LogLevel.INFO, "After expand and put Int64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt64AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为1字节
        buffer.position(buffer.capacity() - 1)
        logger.log(
            LogLevel.INFO,
            "Expand and put Int64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt64(value)
        logger.log(LogLevel.INFO, "After Expand and put Int64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt64AtPosition(buffer, value)
        buffer.clear()

        // 测试扩容了，容量剩余为0
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put Int64 value ${value} at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPutInt64(value)
        logger.log(LogLevel.INFO, "After expand and put Int64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getInt64AtIndex(buffer, position, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getInt64AtPosition(buffer, value)
        buffer.clear()
    }

    static func expandPutAndGetSimpleString(buffer: ByteBuffer, value: String) {
        let arr = value.toArray()
        let size = arr.size

        //测试没有扩容
        buffer.position(buffer.capacity() - size)
        logger.log(
            LogLevel.INFO,
            "Expand and put String value \"${value}\" at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        var position = buffer.position()
        var limit = buffer.limit()
        var capacity = buffer.capacity()
        var remaining = buffer.remaining()

        buffer.expandAndPut(arr)
        logger.log(LogLevel.INFO, "After Expand and put String value \"${value}\", ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)

        var retArr = Array<Byte>(size, repeat: 0)
        getStringAtIndex(buffer, position, retArr, value)

        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getStringAtPosition(buffer, retArr, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为size - 1字节
        buffer.position(buffer.capacity() - (size - 1))
        logger.log(
            LogLevel.INFO,
            "Expand and put String value \"${value}\" at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        var largeArr = Array<Byte>(size + 20, repeat: 0)
        arr.copyTo(largeArr, 0, 20, arr.size)
        buffer.expandAndPut(largeArr, 20, arr.size)
        logger.log(LogLevel.INFO, "After Expand and put String value \"${value}\", ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        var largeRetArr = Array<Byte>(size + 20, repeat: 0)
        getStringAtIndex(buffer, position, largeRetArr, 20, arr.size, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getStringAtPosition(buffer, largeRetArr, 20, arr.size, value)
        buffer.clear()

        // 测试扩容了, 容量剩余为1字节
        buffer.position(buffer.capacity() - 1)
        logger.log(
            LogLevel.INFO,
            "Expand and put String value \"${value}\" at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        largeArr = Array<Byte>(size + 30, repeat: 0)
        arr.copyTo(largeArr, 0, 30, arr.size)
        buffer.expandAndPut(largeArr, 30, arr.size)
        logger.log(LogLevel.INFO, "After Expand and put String value \"${value}\", ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        largeRetArr = Array<Byte>(size + 30, repeat: 0)
        getStringAtIndex(buffer, position, largeRetArr, 30, arr.size, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getStringAtPosition(buffer, largeRetArr, 30, arr.size, value)
        buffer.clear()

        // 测试扩容了，容量剩余为0
        buffer.position(buffer.capacity())
        logger.log(
            LogLevel.INFO,
            "Expand and put String value \"${value}\" at position: ${buffer.position()}, ByteBuffer: ${buffer}"
        )

        position = buffer.position()
        limit = buffer.limit()
        capacity = buffer.capacity()
        remaining = buffer.remaining()

        buffer.expandAndPut(arr)
        logger.log(LogLevel.INFO, "After Expand and put String value \"${value}\", ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.capacity() != capacity)
        @Expect(buffer.limit() != limit)

        getStringAtIndex(buffer, position, retArr, value)
        buffer.flip()
        if (position != 0) {
            buffer.position(position)
        }
        getStringAtPosition(buffer, retArr, value)
        buffer.clear()
    }

    static func putUInt8(buffer: ByteBuffer, value: UInt8) {
        logger.log(LogLevel.INFO, "Put UInt8 value ${value} at position: ${buffer.position()}")

        let size = 1
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putByte(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put UInt8 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func putUInt16(buffer: ByteBuffer, value: UInt16) {
        logger.log(LogLevel.INFO, "Put UInt16 value ${value} at position: ${buffer.position()}")

        let size = 2
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putUInt16(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put UInt16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func putUInt32(buffer: ByteBuffer, value: UInt32) {
        logger.log(LogLevel.INFO, "Put UInt32 value ${value} at position: ${buffer.position()}")

        let size = 4
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putUInt32(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put UInt32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func putUInt64(buffer: ByteBuffer, value: UInt64) {
        logger.log(LogLevel.INFO, "Put UInt64 value ${value} at position: ${buffer.position()}")

        let size = 8
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putUInt64(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put UInt64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func putInt8(buffer: ByteBuffer, value: Int8) {
        logger.log(LogLevel.INFO, "Put Int8 value ${value} at position: ${buffer.position()}")

        let size = 1
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putInt8(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put Int8 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func putInt16(buffer: ByteBuffer, value: Int16) {
        logger.log(LogLevel.INFO, "Put Int16 value ${value} at position: ${buffer.position()}")

        let size = 2
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putInt16(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put Int16 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func putInt32(buffer: ByteBuffer, value: Int32) {
        logger.log(LogLevel.INFO, "Put Int32 value ${value} at position: ${buffer.position()}")

        let size = 4
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putInt32(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put Int32 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func putInt64(buffer: ByteBuffer, value: Int64) {
        logger.log(LogLevel.INFO, "Put Int64 value ${value} at position: ${buffer.position()}")

        let size = 8
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.putInt64(value)
        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put Int64 value ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getByteAtPosition(buffer: ByteBuffer, expectValue: UInt8) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt8() at position")
        var uInt8Ret = buffer.getByte()
        logger.log(LogLevel.INFO, "Get UInt8: ${uInt8Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt8Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getUInt16AtPosition(buffer: ByteBuffer, expectValue: UInt16) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt16() at position")
        var uInt16Ret = buffer.getUInt16()
        logger.log(LogLevel.INFO, "Get UInt16: ${uInt16Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt16Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getUInt32AtPosition(buffer: ByteBuffer, expectValue: UInt32) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt32() at position")
        var uInt32Ret = buffer.getUInt32()
        logger.log(LogLevel.INFO, "Get UInt32: ${uInt32Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt32Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getUInt64AtPosition(buffer: ByteBuffer, expectValue: UInt64) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt64() at position")
        var uInt64Ret = buffer.getUInt64()
        logger.log(LogLevel.INFO, "Get UInt64: ${uInt64Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt64Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getInt8AtPosition(buffer: ByteBuffer, expectValue: Int8) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getInt8() at position")
        var int8Ret = buffer.getInt8()
        logger.log(LogLevel.INFO, "Get Int8: ${int8Ret}, expect value ${expectValue}")
        @Expect(expectValue == int8Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getInt16AtPosition(buffer: ByteBuffer, expectValue: Int16) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getInt16() at position")
        var int16Ret = buffer.getInt16()
        logger.log(LogLevel.INFO, "Get Int16: ${int16Ret}, expect value ${expectValue}")
        @Expect(expectValue == int16Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getInt32AtPosition(buffer: ByteBuffer, expectValue: Int32) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getInt32() at position")
        var int32Ret = buffer.getInt32()
        logger.log(LogLevel.INFO, "Get Int32: ${int32Ret}, expect value ${expectValue}")
        @Expect(expectValue == int32Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getInt64AtPosition(buffer: ByteBuffer, expectValue: Int64) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getInt64() at position")
        var int64Ret = buffer.getInt64()
        logger.log(LogLevel.INFO, "Get Int64: ${int64Ret}, expect value ${expectValue}")
        @Expect(expectValue == int64Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
    }

    static func getByteAtIndex(buffer: ByteBuffer, index: Int64, expectValue: UInt8) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt8(index:Int64)")
        var uInt8Ret = buffer.getByte(index)
        logger.log(LogLevel.INFO, "Get UInt8: ${uInt8Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt8Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return uInt8Ret
    }

    static func getUInt16AtIndex(buffer: ByteBuffer, index: Int64, expectValue: UInt16) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt16(index:Int64)")
        var uInt16Ret = buffer.getUInt16(index)
        logger.log(LogLevel.INFO, "Get UInt16: ${uInt16Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt16Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return uInt16Ret
    }

    static func getUInt32AtIndex(buffer: ByteBuffer, index: Int64, expectValue: UInt32) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt32(index:Int64)")
        var uInt32Ret = buffer.getUInt32(index)
        logger.log(LogLevel.INFO, "Get UInt32: ${uInt32Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt32Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return uInt32Ret
    }

    static func getUInt64AtIndex(buffer: ByteBuffer, index: Int64, expectValue: UInt64) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt64(index:Int64)")
        var uInt64Ret = buffer.getUInt64(index)
        logger.log(LogLevel.INFO, "Get UInt64: ${uInt64Ret}, expect value ${expectValue}")
        @Expect(expectValue == uInt64Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return uInt64Ret
    }
    static func getInt8AtIndex(buffer: ByteBuffer, index: Int64, expectValue: Int8) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getUInt8(index:Int64)")
        var int8Ret = buffer.getInt8(index)
        logger.log(LogLevel.INFO, "Get Int8: ${int8Ret}, expect value ${expectValue}")
        @Expect(expectValue == int8Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return int8Ret
    }

    static func getInt16AtIndex(buffer: ByteBuffer, index: Int64, expectValue: Int16) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getInt16(index:Int64)")
        var int16Ret = buffer.getInt16(index)
        logger.log(LogLevel.INFO, "Get Int16: ${int16Ret}, expect value ${expectValue}")
        @Expect(expectValue == int16Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return int16Ret
    }

    static func getInt32AtIndex(buffer: ByteBuffer, index: Int64, expectValue: Int32) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getInt32(index:Int64)")
        var int32Ret = buffer.getInt32(index)
        logger.log(LogLevel.INFO, "Get Int32: ${int32Ret}, expect value ${expectValue}")
        @Expect(expectValue == int32Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return int32Ret
    }

    static func getInt64AtIndex(buffer: ByteBuffer, index: Int64, expectValue: Int64) {
        logger.log(LogLevel.INFO, "Test ByteBuffer.getInt64(index:Int64)")
        var int64Ret = buffer.getInt64(index)
        logger.log(LogLevel.INFO, "Get Int64: ${int64Ret}, expect value ${expectValue}")
        @Expect(expectValue == int64Ret)
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return int64Ret
    }

    static func putString(buffer: ByteBuffer, value: String): Int64 {
        logger.log(LogLevel.INFO, "Test put ${value} at position: ${buffer.position()}")
        var message1Array = value.toArray()
        let size = message1Array.size
        let position = buffer.position()
        let limit = buffer.limit()
        let capacity = buffer.capacity()
        let remaining = buffer.remaining()
        buffer.put(message1Array)

        @Expect(buffer.position() == position+size)
        @Expect(buffer.limit() == limit)
        @Expect(buffer.capacity() == capacity)
        @Expect(buffer.remaining() == remaining -size)
        logger.log(LogLevel.INFO, "After put ${value}, ByteBuffer: ${buffer}")
        logger.log(LogLevel.INFO, LINE_SPERATOR)
        return size
    }

    static func getStringAtIndex(buffer: ByteBuffer, index: Int64, dst: Array<Byte>, expectValue: String): String {
        logger.log(LogLevel.INFO, "Test ByteBuffer.get(index: Int64, dst: Array<Byte>) at index ${index}")

        buffer.get(index, dst)
        let retString = String.fromUtf8(dst)

        logger.log(LogLevel.INFO, "Get String: ${retString}, \nexpect value ${expectValue}")
        @Expect(expectValue == retString)
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        return retString
    }

    static func getStringAtIndex(
        buffer: ByteBuffer,
        index: Int64,
        dst: Array<Byte>,
        startPos: Int64,
        len: Int64,
        expectValue: String
    ): String {
        logger.log(
            LogLevel.INFO,
            "Test ByteBuffer.get(index: ${index}, array size: ${dst.size}, startPos: ${startPos}, length: ${len}) at index ${index}, buffer: ${buffer}"
        )

        buffer.get(index, dst, startPos, len)
        logger.log(
            LogLevel.INFO,
            "After ByteBuffer.get(index: ${index}, array size: ${dst.size}, startPos: ${startPos}, length: ${len}) at index ${index}, buffer: ${buffer}"
        )
        let retString = String.fromUtf8(dst[startPos..(startPos + len)])
        logger.log(
            LogLevel.INFO,
            "After ByteBuffer.get(index: ${index}, array size: ${dst.size}, startPos: ${startPos}, length: ${len}) at index ${index}, retString: ${retString}"
        )

        logger.log(LogLevel.INFO, "Get String: ${retString}, \nexpect value ${expectValue}")
        @Expect(expectValue == retString)
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        return retString
    }

    static func getStringAtPosition(buffer: ByteBuffer, dst: Array<Byte>, expectValue: String): String {
        logger.log(
            LogLevel.INFO,
            "Test ByteBuffer.get(dst: Array<Byte>) at position ${buffer.position()}, buffer: ${buffer}"
        )

        buffer.get(dst)
        let retString = String.fromUtf8(dst)

        logger.log(LogLevel.INFO, "Get String: ${retString}, \nexpect value ${expectValue}")
        @Expect(expectValue == retString)
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        return retString
    }

    static func getStringAtPosition(
        buffer: ByteBuffer,
        dst: Array<Byte>,
        startPos: Int64,
        len: Int64,
        expectValue: String
    ): String {
        logger.log(
            LogLevel.INFO,
            "Test ByteBuffer.get(dst: Array<Byte>, startPos: Int64, length: Int64) at position ${buffer.position()}"
        )

        buffer.get(dst, startPos, len)
        logger.log(
            LogLevel.INFO,
            "After ByteBuffer.get(dst: Array<Byte>, startPos: Int64, length: Int64), buffer: ${buffer}"
        )

        // let retArray = Array<Byte>(len, repeat: 0)
        // dst.copyTo(retArray, startPos, 0, len)
        let retString = String.fromUtf8(dst[startPos..(startPos + len)])
        logger.log(
            LogLevel.INFO,
            "After ByteBuffer.get(dst: Array<Byte>, startPos: Int64, length: Int64), retString: ${retString}"
        )

        logger.log(LogLevel.INFO, "Get String: ${retString}, \nexpect value ${expectValue}")
        @Expect(expectValue == retString)
        logger.log(LogLevel.INFO, LINE_SPERATOR)

        return retString
    }

    static func generateLengthedString(size: Int64): String {
        var i = 0
        let builder = StringBuilder(size)
        while (i < size) {
            builder.append(Rune(b'A' + UInt8(i % 26)))
            builder.append()
            i++
        }

        return builder.toString()
    }
}
