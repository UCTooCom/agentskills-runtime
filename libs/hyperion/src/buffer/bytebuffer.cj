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

/**
 * 字节类型相关操作的接口
 *
 * @author yangfuping
 */
public interface ByteOperation {
    func getByte(): Byte

    func getByte(index: Int64): Byte

    func getUInt16(): UInt16

    func getUInt32(): UInt32

    func getUInt64(): UInt64

    func getInt8(): Int8

    func getInt16(): Int16

    func getInt32(): Int32

    func getInt64(): Int64

    func getUInt16(index: Int64): UInt16

    func getUInt32(index: Int64): UInt32

    func getUInt64(index: Int64): UInt64

    func getInt8(index: Int64): Int8

    func getInt16(index: Int64): Int16

    func getInt32(index: Int64): Int32

    func getInt64(index: Int64): Int64

    func putByte(value: Byte): Unit

    func putUInt16(val: UInt16): Unit

    func putUInt32(val: UInt32): Unit

    func putUInt64(val: UInt64): Unit

    func putInt8(val: Int8): Unit

    func putInt16(val: Int16): Unit

    func putInt32(val: Int32): Unit

    func putInt64(val: Int64): Unit

    func putByte(index: Int64, value: Byte): Unit

    func putUInt16(index: Int64, val: UInt16): Unit

    func putUInt32(index: Int64, val: UInt32): Unit

    func putUInt64(index: Int64, val: UInt64): Unit

    func putInt8(index: Int64, val: Int8): Unit

    func putInt16(index: Int64, val: Int16): Unit

    func putInt32(index: Int64, val: Int32): Unit

    func putInt64(index: Int64, val: Int64): Unit

    func expandAndPutByte(value: Byte): Unit

    func expandAndPutUInt16(val: UInt16): Unit

    func expandAndPutUInt32(val: UInt32): Unit

    func expandAndPutUInt64(val: UInt64): Unit

    func expandAndPutInt8(val: Int8): Unit

    func expandAndPutInt16(val: Int16): Unit

    func expandAndPutInt32(val: Int32): Unit

    func expandAndPutInt64(val: Int64): Unit

    func get(dst: Array<Byte>, startPos: Int64, length: Int64): Unit

    func get(dst: Array<Byte>): Unit

    func get(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Unit

    func get(index: Int64, dst: Array<Byte>): Unit

    func put(src: Array<Byte>, startPos: Int64, length: Int64): Unit

    func put(src: Array<Byte>): Unit

    func put(index: Int64, src: Array<Byte>, startPos: Int64, length: Int64): Unit

    func put(index: Int64, src: Array<Byte>): Unit

    func expandAndPut(src: Array<Byte>, startPos: Int64, length: Int64): Unit

    func expandAndPut(src: Array<Byte>): Unit

    /**
     * 将数据收集到目标字节数组中，收集到的字节数小于需要收集的字节数不会报错
     *
     * @param dst 目标字节数组
     * @param startPos 数组起始位置
     * @param length 需要收集的字节数
     * @return 收集到的字节数
     */
    func partialGather(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Int64

    /**
     * 将数据收集到目标字节数组中，收集到的字节数小于目标数组的长度不会报错
     *
     * @param index 从ByteBuffer的指定位置开始收集
     * @param dst 目标字节数组
     * @return 收集到的字节数
     */
    func partialGather(index: Int64, dst: Array<Byte>): Int64

    /**
     * 将源字节数组的数据存储到ByteBuffer中，ByteBuffe存储容量不够不会报错
     *
     * @param index 从ByteBuffer的指定位置开始存储
     * @param src 源字节数组
     * @param startPos 数组起始位置
     * @param length 需要村粗的字节数
     * @return 完成存储的字节数
     */
    func partialOffer(index: Int64, src: Array<Byte>, startPos: Int64, length: Int64): Int64

    /**
     * 将源字节数组的数据存储到ByteBuffer中，ByteBuffe存储容量不够不会报错
     *
     * @param index 从ByteBuffer的指定位置开始存储
     * @param src 源字节数组
     * @return 完成存储的字节数
     */
    func partialOffer(index: Int64, src: Array<Byte>): Int64
}

/**
 * Buffer接口
 *
 * position 游标位置
 * limit 限制游标访问的位置
 * capacity 容量
 * maxCapactiy 允许的最大容量
 *
 * 如下等式成立：
 *  0 <= position < limit <= capacity
 */
public interface Buffer <: ByteOperation {
    prop expandSupport: Bool

    func position(): Int64

    func position(position: Int64): Buffer

    func limit(): Int64

    func limit(limit: Int64): Buffer

    func capacity(): Int64

    func remainingCapacity(): Int64

    func maxCapacity(): Int64

    func remaining(): Int64

    func hasRemaining(): Bool

    /**
     * 返回position..=limit区间包含的数组
     */
    func toArray(): Array<Byte>

    /**
     * 返回index..=index+length包含的数组
     */
    func toArray(index!: Int64, length!: Int64): Array<Byte>

    func toArray(range: Range<Int64>): Array<Byte>

    /**
     * 将limit的位置设置为capacity
     */
    func limitToCapacity(): Buffer

    /**
     * 扩容容量并限制Limit位置
     */
    func expandAndLimit(limit: Int64): Buffer

    func clear(): Buffer

    func flip(): Buffer

    func rewind(): Buffer

    func slice(): Buffer

    /** 
     * 从当前的起始位置开始(positon = 0的位置)，跳过skipSize
     *
     * 需要当前的position大于skipSize时，才能调整
     */
    func skip(skipSize: Int64): Buffer

    func slice(index!: Int64, length!: Int64): Buffer

    func slice(range: Range<Int64>): Buffer

    func compact(): Buffer

    /**
     * 用于池化的ByteBuffer, 保留引用
     */
    func retain(): Buffer

    /**
     * 用于池化的ByteBuffer, 释放对ByteBuffer的引用
     */
    func release(): Unit

    /**
     * 用于池化的ByteBuffer, 清理ByteBuffer的信息，归还到缓存池之前调用
     */
    func free(): Unit
}

/**
 * 允许扩容ByteBuffer的仓颉实现，参考java.nio.ByteBuffer。
 *
 *
 */
public abstract class ByteBuffer <: Buffer & ToString {
    protected static let logger = LoggerFactory.getLogger("transport")

    static let DEFAULT_INITIAL_CAPACITY = 256
    static let DEFAULT_MAX_CAPACITY = Int64(Int32.Max)

    public static func allocate() {
        let byteBuffer = ArrayByteBuffer()
        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.TRACE, "Allocate ByteBuffer: ${byteBuffer}")
        }
        return byteBuffer
    }

    public static func allocate(capacity: Int64) {
        let byteBuffer = ArrayByteBuffer(capacity)
        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.TRACE, "Allocate ByteBuffer: ${byteBuffer}, required capacity ${capacity}")
        }
        return byteBuffer
    }

    public static func allocate(capacity: Int64, expandSupport!: Bool) {
        let byteBuffer = ArrayByteBuffer(capacity, expandSupport: expandSupport)
        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.TRACE, "Allocate ByteBuffer: ${byteBuffer}, required capacity ${capacity}")
        }
        return byteBuffer
    }

    public static func wrap(buffer: Array<Byte>) {
        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.TRACE, "ByteBuffer wrap: buffer[0..${buffer.size -1}]")
        }

        let byteBuffer = ArrayByteBuffer(
            buffer,
            skipBytes: 0,
            position: 0,
            limit: buffer.size,
            capacity: buffer.size,
            maxCapacity: buffer.size,
            expandSupport: false
        )
        return byteBuffer
    }

    public static func wrap(buffer: Array<Byte>, startPos: Int64, length: Int64) {
        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.TRACE, "ByteBuffer wrap: buffer[${startPos}..${startPos + length}]")
        }

        if (startPos < 0) {
            throw IllegalArgumentException(
                "Negative start position is not allowed, provided start position is ${startPos}")
        }

        if (startPos + length > buffer.size) {
            throw IndexOutOfBoundsException(
                "The sum of start position ${startPos} and length ${length} is out of bounds, array size is ${buffer.size}"
            )
        }

        let byteBuffer = ArrayByteBuffer(
            buffer,
            skipBytes: startPos,
            position: 0,
            limit: length,
            capacity: length,
            maxCapacity: buffer.size,
            expandSupport: false
        )
        return byteBuffer
    }

    /**
     * ByteBuffer的分配器，池化和回收ByteBuffer使用
     */
    private let allocator: ?ByteBufferAllocator

    /**
     * 是否支持扩展容量
     */
    private let expandSupportVal: Bool

    /**
     * 游标位置
     */
    protected var positionVal: Int64

    /**
     * 读取限制位置
     */
    protected var limitVal: Int64

    /**
     * 当前最大容量
     */
    protected var capacityVal: Int64

    /**
     * 允许扩容的最大容量
     */
    protected let maxCapacityVal: Int64

    public init(
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        expandSupport!: Bool
    ) {
        if (expandSupport == false) {
            this.maxCapacityVal = capacity
        } else {
            this.maxCapacityVal = DEFAULT_MAX_CAPACITY
        }
        checkBufferInitParams(position: position, limit: limit, capacity: capacity, maxCapacity: maxCapacityVal)

        this.positionVal = position
        this.limitVal = limit
        this.capacityVal = capacity
        this.expandSupportVal = expandSupport
        this.allocator = None<ByteBufferAllocator>
    }

    public init(
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        maxCapacity!: Int64,
        expandSupport!: Bool
    ) {
        checkBufferInitParams(position: position, limit: limit, capacity: capacity, maxCapacity: maxCapacity)
        this.positionVal = position
        this.limitVal = limit
        this.capacityVal = capacity
        this.expandSupportVal = expandSupport
        if (expandSupport == false) {
            this.maxCapacityVal = capacity
        } else {
            this.maxCapacityVal = maxCapacity
        }
        this.allocator = None<ByteBufferAllocator>
    }

    public init(
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        maxCapacity!: Int64,
        expandSupport!: Bool,
        allocator!: ByteBufferAllocator
    ) {
        checkBufferInitParams(position: position, limit: limit, capacity: capacity, maxCapacity: maxCapacity)

        this.positionVal = position
        this.limitVal = limit
        this.capacityVal = capacity
        this.expandSupportVal = expandSupport
        if (expandSupport == false) {
            this.maxCapacityVal = capacity
        } else {
            this.maxCapacityVal = maxCapacity
        }
        this.allocator = allocator
    }

    public prop expandSupport: Bool {
        get() {
            return expandSupportVal
        }
    }

    public func position(): Int64 {
        return positionVal
    }

    public func position(position: Int64): Buffer {
        if (position > limitVal) {
            throw IllegalArgumentException("Out of bound position: ${position}, limit is ${limitVal}")
        }

        this.positionVal = position
        return this
    }

    public func limit(): Int64 {
        return limitVal
    }

    public func limit(limit: Int64): Buffer {
        if (limit > capacityVal) {
            throw IllegalArgumentException(
                "Out of bound new limit: ${limit}, position is ${positionVal}, current limit is ${limitVal}, capacity is ${capacityVal}"
            )
        }

        this.limitVal = limit
        return this
    }

    public func capacity(): Int64 {
        return capacityVal
    }

    public func maxCapacity(): Int64 {
        return maxCapacityVal
    }

    public func remaining(): Int64 {
        return limitVal - positionVal
    }

    public func hasRemaining(): Bool {
        return positionVal < limitVal
    }

    public func limitToCapacity(): ByteBuffer {
        this.limitVal = capacityVal
        return this
    }

    public open func expand(): ByteBuffer {
        expandAndLimit(capacityVal * 2)
        return this
    }

    public func expandAndLimit(limit: Int64): ByteBuffer {
        if (limit > capacityVal) {
            if (!this.expandSupportVal) {
                throw IllegalArgumentException(
                    "Out of bound new limit: ${limit}, position is ${positionVal}, current limit is ${limitVal}, capacity is ${capacityVal}"
                )
            }

            expandCapacity(limit)
        }

        this.limitVal = limit
        return this
    }

    public func clear(): ByteBuffer {
        positionVal = 0
        limitVal = capacityVal
        return this;
    }

    public func flip(): ByteBuffer {
        limitVal = positionVal
        positionVal = 0
        return this;
    }

    public func rewind(): ByteBuffer {
        positionVal = 0
        return this;
    }

    public func slice(): ByteBuffer

    public func slice(index!: Int64, length!: Int64): ByteBuffer

    public func slice(range: Range<Int64>): ByteBuffer

    public func getAllocator(): ?ByteBufferAllocator {
        return allocator
    }

    /**
     * 用于池化的ByteBuffer, 保留引用
     */
    public open func retain(): ByteBuffer {
        return this
    }

    public open func release(): Unit {
    }

    /**
     * 搜索指定的Byte数组的起始位置
     */
    public open func indexOf(needle: Array<Byte>): Int64 {
        if (remaining() >= needle.size) {
            for (i in positionVal..limitVal) {
                if (matches(needle, i)) {
                    return i;
                }
            }
        }

        return -1;
    }

    private func matches(needle: Array<Byte>, pos: Int64): Bool {
        for (i in 0..needle.size) {
            let compareIndex = pos + i
            if (compareIndex >= limitVal) {
                // 游标等于或超过Limit，返回false
                return false
            }

            if (getByte(compareIndex) != needle[i]) {
                return false;
            }
        }

        return true;
    }

    protected func nextGetIndex(): Int64 {
        let p = positionVal;
        if (p >= limitVal) {
            throw IndexOutOfBoundsException("Position ${p} is out of bounds, limit is ${limitVal}")
        }
        positionVal = p + 1
        return p;
    }

    protected func nextGetIndex(needBytes: Int64): Int64 {
        let p = positionVal;
        if (limitVal - p < needBytes) {
            throw IndexOutOfBoundsException(
                "The sum of position ${p} and ${needBytes} is out of bounds, limit is ${limitVal}");
        }
        positionVal = p + needBytes
        return p;
    }

    protected func nextPutIndex(): Int64 {
        let p = positionVal;
        if (p >= limitVal) {
            throw IndexOutOfBoundsException("Position ${p} is out of bounds, limit is ${limitVal}")
        }

        positionVal = p + 1
        return p;
    }

    protected func nextPutIndex(needBytes: Int64): Int64 {
        let p = positionVal;
        if (limitVal - p < needBytes) {
            throw IndexOutOfBoundsException(
                "The sum of position ${p} and ${needBytes} is out of bounds, limit is ${limitVal}");
        }
        positionVal = p + needBytes
        return p;
    }

    protected func checkIndex(i: Int64) {
        if (i < 0 || i > limitVal) {
            throw IndexOutOfBoundsException("Index ${i} is out of bounds, limit is ${limitVal}")
        }

        return i
    }

    protected func expandAndCheckIndex(i: Int64) {
        if (i < 0) {
            throw IndexOutOfBoundsException("Negative index ${i}")
        }

        if (i > capacityVal) {
            expandCapacity(i)
        }

        return i
    }

    protected func expandCapacity(needCapicity: Int64): Buffer
}
