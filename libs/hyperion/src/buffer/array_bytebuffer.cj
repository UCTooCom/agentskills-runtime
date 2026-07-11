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
 * 底层使用数组的ByteBuffer实现
 *
 * 非线程安全
 *
 * @author yangfuping
 */
public open class ArrayByteBuffer <: ByteBuffer & ToString {
    private var bufferVal: Array<Byte>

    /**
     * 数组起始位置跳过的字节数
     */
    private var skipBytes: Int64

    /**
     * ByteBuffer的引用计数，池化和回收ByteBuffer使用
     */
    private let refCounted: ?ReferenceCounted

    protected init() {
        this(DEFAULT_INITIAL_CAPACITY)
    }

    protected init(initialSize: Int64) {
        super(
            position: 0,
            limit: initialSize,
            capacity: initialSize,
            maxCapacity: DEFAULT_MAX_CAPACITY,
            expandSupport: true
        )

        this.skipBytes = 0
        this.bufferVal = Array<Byte>(initialSize, repeat: 0)
        this.refCounted = None<ReferenceCounted>
    }

    protected init(initialSize: Int64, expandSupport!: Bool) {
        super(
            position: 0,
            limit: initialSize,
            capacity: initialSize,
            maxCapacity: getMaxCapacity(initialSize, expandSupport),
            expandSupport: expandSupport
        )

        this.skipBytes = 0
        this.bufferVal = Array<Byte>(initialSize, repeat: 0)
        this.refCounted = None<ReferenceCounted>
    }

    protected init(
        initialSize: Int64,
        expandSupport!: Bool,
        allocator!: ByteBufferAllocator,
        refCounted!: ReferenceCounted
    ) {
        super(
            position: 0,
            limit: initialSize,
            capacity: initialSize,
            maxCapacity: getMaxCapacity(initialSize, expandSupport),
            expandSupport: expandSupport,
            allocator: allocator
        )

        this.skipBytes = 0
        this.bufferVal = Array<Byte>(initialSize, repeat: 0)
        this.refCounted = refCounted
    }

    protected init(buffer: Array<Byte>, expandSupport!: Bool) {
        super(
            position: 0,
            limit: buffer.size,
            capacity: buffer.size,
            maxCapacity: getMaxCapacity(buffer.size, expandSupport),
            expandSupport: expandSupport
        )

        this.skipBytes = 0
        this.bufferVal = buffer
        this.refCounted = None<ReferenceCounted>
    }

    protected init(
        buffer: Array<Byte>,
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        expandSupport!: Bool
    ) {
        super(
            position: position,
            limit: limit,
            capacity: capacity,
            maxCapacity: getMaxCapacity(capacity, expandSupport),
            expandSupport: expandSupport
        )

        this.skipBytes = 0
        this.bufferVal = buffer
        this.refCounted = None<ReferenceCounted>
    }

    protected init(
        buffer: Array<Byte>,
        skipBytes!: Int64,
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        expandSupport!: Bool
    ) {
        super(
            position: position,
            limit: limit,
            capacity: capacity,
            maxCapacity: getMaxCapacity(capacity, expandSupport),
            expandSupport: expandSupport
        )

        if (skipBytes < 0) {
            throw IllegalArgumentException("Negative skipBytes values: ${skipBytes}")
        }

        this.skipBytes = skipBytes
        this.bufferVal = buffer
        this.refCounted = None<ReferenceCounted>
    }

    protected init(
        buffer: Array<Byte>,
        skipBytes!: Int64,
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        maxCapacity!: Int64,
        expandSupport!: Bool
    ) {
        super(
            position: position,
            limit: limit,
            capacity: capacity,
            maxCapacity: maxCapacity,
            expandSupport: expandSupport
        )

        if (skipBytes < 0) {
            throw IllegalArgumentException("Negative skipBytes values: ${skipBytes}")
        }
        this.skipBytes = skipBytes
        this.bufferVal = buffer
        this.refCounted = None<ReferenceCounted>
    }

    protected init(
        buffer: Array<Byte>,
        skipBytes!: Int64,
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        maxCapacity!: Int64,
        expandSupport!: Bool,
        allocator!: ByteBufferAllocator
    ) {
        super(
            position: position,
            limit: limit,
            capacity: capacity,
            maxCapacity: maxCapacity,
            expandSupport: expandSupport,
            allocator: allocator
        )

        if (skipBytes < 0) {
            throw IllegalArgumentException("Negative skipBytes values: ${skipBytes}")
        }
        this.skipBytes = skipBytes
        this.bufferVal = buffer
        this.refCounted = None<ReferenceCounted>
    }

    protected init(
        refCounted: ReferenceCounted,
        buffer: Array<Byte>,
        skipBytes!: Int64,
        position!: Int64,
        limit!: Int64,
        capacity!: Int64,
        maxCapacity!: Int64,
        expandSupport!: Bool
    ) {
        super(
            position: position,
            limit: limit,
            capacity: capacity,
            maxCapacity: maxCapacity,
            expandSupport: expandSupport
        )

        if (skipBytes < 0) {
            throw IllegalArgumentException("Negative skipBytes values: ${skipBytes}")
        }
        this.skipBytes = skipBytes
        this.bufferVal = buffer
        this.refCounted = refCounted
    }

    protected func ix(i: Int64): Int64 {
        return i + skipBytes;
    }

    public func remainingCapacity(): Int64 {
        return this.capacityVal - ix(positionVal)
    }

    /**
     * 从当前的起始位置ix(0)开始，跳过skipSize
     *
     * 需要当前的position大于skipSize时，才能调整
     */
    public func skip(skipSize: Int64): Buffer {
        if (skipBytes < 0) {
            throw IllegalArgumentException("Negative skipSize: ${skipBytes}")
        }

        if (positionVal < skipSize) {
            throw IllegalArgumentException("The skipSize: ${skipSize} should less than postion: ${positionVal}")
        }

        // position, limit, capacity均要调整
        this.positionVal = positionVal - skipSize
        this.limitVal = limitVal - skipSize
        this.capacityVal = capacityVal - skipSize
        // 增加skipBytes
        this.skipBytes = skipBytes + skipSize
        return this
    }

    public open func free(): Unit {
        this.skipBytes = 0
        this.positionVal = 0
        // 容量和limit调整为数组的长度
        this.capacityVal = bufferVal.size
        this.limitVal = bufferVal.size
    }

    public func slice(): ByteBuffer {
        let pos = positionVal
        let lim = limitVal
        var remaining = 0
        if (pos < lim) {
            remaining = lim - pos
        }

        if (let Some(refCounted) <- refCounted) {
            refCounted.retainRef()
            return ArrayByteBuffer(
                refCounted,
                bufferVal,
                skipBytes: ix(pos),
                position: 0,
                limit: remaining,
                capacity: remaining,
                maxCapacity: remaining,
                expandSupport: false // 切片不支持扩展容量
            )
        } else {
            return ArrayByteBuffer(
                bufferVal,
                skipBytes: ix(pos),
                position: 0,
                limit: remaining,
                capacity: remaining,
                maxCapacity: remaining,
                expandSupport: false // 切片不支持扩展容量
            )
        }
    }

    public func slice(index!: Int64, length!: Int64): ByteBuffer {
        if (index < 0) {
            throw IndexOutOfBoundsException("Negative index ${index}")
        }

        if (length < 0) {
            throw IndexOutOfBoundsException("Negative length ${length}")
        }

        if (index + length > limitVal) {
            throw IndexOutOfBoundsException(
                "The sum of index ${index} and length ${length} is out of bounds, limit is ${limitVal}")
        }

        if (let Some(refCounted) <- refCounted) {
            refCounted.retainRef()
            return ArrayByteBuffer(
                refCounted,
                bufferVal,
                skipBytes: ix(index),
                position: 0,
                limit: length,
                capacity: length,
                maxCapacity: length,
                expandSupport: false
            )
        } else {
            return ArrayByteBuffer(
                bufferVal,
                skipBytes: ix(index),
                position: 0,
                limit: length,
                capacity: length,
                maxCapacity: length,
                expandSupport: false
            )
        }
    }

    public func slice(range: Range<Int64>): ByteBuffer {
        var start = 0
        if (range.hasStart) {
            start = range.start
        }

        var end = limitVal
        if (range.hasEnd) {
            end = range.end
        }

        if (!range.isClosed) {
            end = end - 1
        }

        return slice(index: start, length: (end - start) + 1)
    }

    public func compact(): Buffer {
        if (hasRemaining()) {
            bufferVal.copyTo(bufferVal, ix(positionVal), ix(0), remaining())
            position(remaining())
            limit(capacityVal)
        }

        return this
    }

    /**
     * 用于池化的ByteBuffer, 保留引用
     */
    public open func retain(): ByteBuffer {
        if (let Some(refCounted) <- refCounted) {
            refCounted.retainRef()
        }

        return this
    }

    public open func release(): Unit {
        if (let Some(refCounted) <- refCounted) {
            if (refCounted.releaseRef()) {
                if (let Some(delegateBuffer) <- refCounted.getDelegateBuffer()) {
                    if (let Some(allocator) <- delegateBuffer.getAllocator()) {
                        allocator.free(delegateBuffer)
                    }
                }
            }
        }
    }

    /**
     * 扩充容量
     */
    protected func expandCapacity(needCapicity: Int64): ByteBuffer {
        if (needCapicity <= capacityVal) {
            return this
        }

        if (!expandSupport) {
            throw IndexOutOfBoundsException(
                "Expand capacity is not supported, required capicity: ${needCapicity} is exceed capacity: ${capacityVal}"
            )
        }

        if (needCapicity > maxCapacityVal) {
            throw IndexOutOfBoundsException(
                "The required capicity ${needCapicity} is exceed maxCapacityVal: ${maxCapacityVal}")
        }

        let newCapicity: Int64
        if (bufferVal.size << 1 > maxCapacityVal) {
            newCapicity = maxCapacityVal
        } else {
            // 扩容到两倍和需要大小值的最大值
            newCapicity = max(bufferVal.size << 1, needCapicity)
        }

        let expandBuffer = Array<Byte>(newCapicity, repeat: 0)
        bufferVal.copyTo(expandBuffer, 0, 0, bufferVal.size)
        if (limitVal == capacityVal) {
            // 调整limit值为newCapicity
            limitVal = newCapicity
        } else {
            throw IndexOutOfBoundsException(
                "Illegal state to expand capacity, the old limit${limitVal} is not equals to old capacity ${capacityVal}"
            )
        }

        bufferVal = expandBuffer
        capacityVal = newCapicity
        return this
    }

    /**
     * 返回position..=limit区间包含的数组
     */
    public func toArray(): Array<Byte> {
        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(
                LogLevel.TRACE,
                "ByteBuffer::toArray, slice [${ix(positionVal)}..${ix(limitVal)}] from ${toString()}"
            )
        }
        return bufferVal[ix(positionVal)..ix(limitVal)]
    }

    /**
     * 返回index..=index+length包含的数组
     */
    public func toArray(index!: Int64, length!: Int64): Array<Byte> {
        if (index < 0) {
            throw IndexOutOfBoundsException("Negative index ${index}")
        }

        if (length < 0) {
            throw IndexOutOfBoundsException("Negative length ${length}")
        }

        if (index + length > limitVal) {
            throw IndexOutOfBoundsException(
                "The sum of index ${index} and length ${length} is out of bounds, limit is ${limitVal}")
        }

        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(
                LogLevel.TRACE,
                "ByteBuffer::toArray, slice [${ix(index)}..${ix(index + length)}] from ${toString()}"
            )
        }
        return bufferVal[ix(index)..ix(index + length)]
    }

    public func toArray(range: Range<Int64>): Array<Byte> {
        var start = 0
        if (range.hasStart) {
            start = range.start
        }

        var end = limitVal
        if (range.hasEnd) {
            end = range.end
        }

        if (!range.isClosed) {
            end = end - 1
        }

        return toArray(index: start, length: (end - start) + 1)
    }

    public func getByte(): Byte {
        return bufferVal[ix(nextGetIndex())];
    }

    public func getUInt16(): UInt16 {
        checkIndex(positionVal + 2)
        return UInt16(bufferVal[ix(nextGetIndex())] & 0xff) << 8 | UInt16(bufferVal[ix(nextGetIndex())] & 0xff)
    }

    public func getUInt32(): UInt32 {
        checkIndex(positionVal + 4)
        return UInt32(bufferVal[ix(nextGetIndex())] & 0xff) << 24 | UInt32(bufferVal[ix(nextGetIndex())] & 0xff) << 16 |
            UInt32(bufferVal[ix(nextGetIndex())] & 0xff) << 8 | UInt32(bufferVal[ix(nextGetIndex())] & 0xff)
    }

    public func getUInt64(): UInt64 {
        checkIndex(positionVal + 8)
        return UInt64(bufferVal[ix(nextGetIndex())] & 0xff) << 56 | UInt64(bufferVal[ix(nextGetIndex())] & 0xff) << 48 |
            UInt64(bufferVal[ix(nextGetIndex())] & 0xff) << 40 | UInt64(bufferVal[ix(nextGetIndex())] & 0xff) << 32 |
            UInt64(bufferVal[ix(nextGetIndex())] & 0xff) << 24 | UInt64(bufferVal[ix(nextGetIndex())] & 0xff) << 16 |
            UInt64(bufferVal[ix(nextGetIndex())] & 0xff) << 8 | UInt64(bufferVal[ix(nextGetIndex())] & 0xff)
    }

    @OverflowWrapping
    public func getInt8(): Int8 {
        return Int8(getByte())
    }

    @OverflowWrapping
    public func getInt16(): Int16 {
        return Int16(getUInt16())
    }

    @OverflowWrapping
    public func getInt32(): Int32 {
        return Int32(getUInt32())
    }

    @OverflowWrapping
    public func getInt64(): Int64 {
        return Int64(getUInt64())
    }

    public func getByte(index: Int64): Byte {
        checkIndex(index + 1)
        return bufferVal[ix(index)];
    }

    public func getUInt16(index: Int64): UInt16 {
        checkIndex(index + 2)
        return UInt16(bufferVal[ix(index)] & 0xff) << 8 | UInt16(bufferVal[ix(index + 1)] & 0xff)
    }

    public func getUInt32(index: Int64): UInt32 {
        checkIndex(index + 4)
        return UInt32(bufferVal[ix(index)] & 0xff) << 24 | UInt32(bufferVal[ix(index + 1)] & 0xff) << 16 |
            UInt32(bufferVal[ix(index + 2)] & 0xff) << 8 | UInt32(bufferVal[ix(index + 3)] & 0xff)
    }

    public func getUInt64(index: Int64): UInt64 {
        checkIndex(index + 8)
        return UInt64(bufferVal[ix(index + 0)] & 0xff) << 56 | UInt64(bufferVal[ix(index + 1)] & 0xff) << 48 |
            UInt64(bufferVal[ix(index + 2)] & 0xff) << 40 | UInt64(bufferVal[ix(index + 3)] & 0xff) << 32 |
            UInt64(bufferVal[ix(index + 4)] & 0xff) << 24 | UInt64(bufferVal[ix(index + 5)] & 0xff) << 16 |
            UInt64(bufferVal[ix(index + 6)] & 0xff) << 8 | UInt64(bufferVal[ix(index + 7)] & 0xff)
    }

    @OverflowWrapping
    public func getInt8(index: Int64): Int8 {
        return Int8(getByte(index))
    }

    @OverflowWrapping
    public func getInt16(index: Int64): Int16 {
        return Int16(getUInt16(index))
    }

    @OverflowWrapping
    public func getInt32(index: Int64): Int32 {
        return Int32(getUInt32(index))
    }

    @OverflowWrapping
    public func getInt64(index: Int64): Int64 {
        return Int64(getUInt64(index))
    }

    public func putByte(value: Byte) {
        checkIndex(positionVal + 1)
        bufferVal[ix(nextPutIndex())] = value
    }

    public func putUInt16(val: UInt16): Unit {
        checkIndex(positionVal + 2)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val & 0xFF)
    }

    public func putUInt32(val: UInt32): Unit {
        checkIndex(positionVal + 4)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 24 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 16 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val & 0xFF)
    }

    public func putUInt64(val: UInt64): Unit {
        checkIndex(positionVal + 8)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 56 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 48 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 40 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 32 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 24 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 16 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val & 0xFF)
    }

    @OverflowWrapping
    public func putInt8(val: Int8): Unit {
        putByte(UInt8(val))
    }

    @OverflowWrapping
    public func putInt16(val: Int16): Unit {
        putUInt16(UInt16(val))
    }

    @OverflowWrapping
    public func putInt32(val: Int32): Unit {
        putUInt32(UInt32(val))
    }

    @OverflowWrapping
    public func putInt64(val: Int64): Unit {
        putUInt64(UInt64(val))
    }

    public func putByte(index: Int64, value: Byte): Unit {
        checkIndex(index + 1)
        bufferVal[ix(index)] = value
    }

    public func putUInt16(index: Int64, val: UInt16): Unit {
        checkIndex(index + 2)
        bufferVal[ix(index)] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(index + 1)] = UInt8(val & 0xFF)
    }

    public func putUInt32(index: Int64, val: UInt32): Unit {
        checkIndex(index + 4)
        bufferVal[ix(index)] = UInt8(val >> 24 & 0xFF)
        bufferVal[ix(index + 1)] = UInt8(val >> 16 & 0xFF)
        bufferVal[ix(index + 2)] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(index + 3)] = UInt8(val & 0xFF)
    }

    public func putUInt64(index: Int64, val: UInt64): Unit {
        checkIndex(index + 8)
        bufferVal[ix(index)] = UInt8(val >> 56 & 0xFF)
        bufferVal[ix(index + 1)] = UInt8(val >> 48 & 0xFF)
        bufferVal[ix(index + 2)] = UInt8(val >> 40 & 0xFF)
        bufferVal[ix(index + 3)] = UInt8(val >> 32 & 0xFF)
        bufferVal[ix(index + 4)] = UInt8(val >> 24 & 0xFF)
        bufferVal[ix(index + 5)] = UInt8(val >> 16 & 0xFF)
        bufferVal[ix(index + 6)] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(index + 7)] = UInt8(val & 0xFF)
    }

    @OverflowWrapping
    public func putInt8(index: Int64, val: Int8): Unit {
        putByte(index, UInt8(val))
    }

    @OverflowWrapping
    public func putInt16(index: Int64, val: Int16): Unit {
        putUInt16(index, UInt16(val))
    }

    @OverflowWrapping
    public func putInt32(index: Int64, val: Int32): Unit {
        putUInt32(index, UInt32(val))
    }

    @OverflowWrapping
    public func putInt64(index: Int64, val: Int64): Unit {
        putUInt64(index, UInt64(val))
    }

    public func expandAndPutByte(value: Byte): Unit {
        expandAndCheckIndex(positionVal + 1)
        bufferVal[ix(nextPutIndex())] = value
    }

    public func expandAndPutUInt16(val: UInt16): Unit {
        expandAndCheckIndex(positionVal + 2)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val & 0xFF)
    }

    public func expandAndPutUInt32(val: UInt32): Unit {
        expandAndCheckIndex(positionVal + 4)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 24 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 16 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val & 0xFF)
    }

    public func expandAndPutUInt64(val: UInt64): Unit {
        expandAndCheckIndex(positionVal + 8)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 56 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 48 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 40 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 32 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 24 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 16 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val >> 8 & 0xFF)
        bufferVal[ix(nextPutIndex())] = UInt8(val & 0xFF)
    }

    @OverflowWrapping
    public func expandAndPutInt8(val: Int8): Unit {
        expandAndPutByte(UInt8(val))
    }

    @OverflowWrapping
    public func expandAndPutInt16(val: Int16): Unit {
        expandAndPutUInt16(UInt16(val))
    }

    @OverflowWrapping
    public func expandAndPutInt32(val: Int32): Unit {
        expandAndPutUInt32(UInt32(val))
    }

    @OverflowWrapping
    public func expandAndPutInt64(val: Int64): Unit {
        expandAndPutUInt64(UInt64(val))
    }

    public func get(dst: Array<Byte>, startPos: Int64, length: Int64): Unit {
        checkBounds(dst, startPos, length)
        if (length > remaining()) {
            throw IndexOutOfBoundsException("The required data size: ${length} is exceed remaining: ${remaining()}")
        }

        bufferVal.copyTo(dst, ix(positionVal), startPos, length)
        position(positionVal + length)
    }

    public func get(dst: Array<Byte>): Unit {
        get(dst, 0, dst.size)
    }

    public func get(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Unit {
        checkBounds(dst, startPos, length)
        if (index + length > limitVal) {
            throw IndexOutOfBoundsException("The sum of index ${index} and ${length} is exceeding limit: ${limitVal}")
        }

        bufferVal.copyTo(dst, ix(index), startPos, length)
    }

    public func get(index: Int64, dst: Array<Byte>): Unit {
        return get(index, dst, 0, dst.size)
    }

    public func put(src: Array<Byte>, startPos: Int64, length: Int64): Unit {
        checkBounds(src, startPos, length)
        if (length > remaining()) {
            throw IndexOutOfBoundsException(
                "The required data size: ${length} is exceed remaining ${remaining()}, position: ${positionVal}, limit: ${limitVal}, capacity: ${capacityVal}"
            )
        }

        src.copyTo(bufferVal, startPos, ix(positionVal), length)
        position(positionVal + length)
    }

    public func put(src: Array<Byte>): Unit {
        put(src, 0, src.size)
    }

    public func put(index: Int64, src: Array<Byte>, startPos: Int64, length: Int64): Unit {
        checkBounds(src, startPos, length)
        if (index + length > limitVal) {
            throw IndexOutOfBoundsException(
                "The sum of index ${index} and ${length} is exceeding limit ${limitVal}, remaining: ${remaining()}, position: ${positionVal}, limit: ${limitVal}, capacity: ${capacityVal}"
            )
        }

        src.copyTo(bufferVal, startPos, ix(index), length)
    }

    public func put(index: Int64, src: Array<Byte>): Unit {
        return get(index, src, 0, src.size)
    }

    public func expandAndPut(src: Array<Byte>, startPos: Int64, length: Int64): Unit {
        checkBounds(src, startPos, length)
        // 如果容量不够则扩容容量
        expandAndCheckIndex(positionVal + length)

        if (length > remaining()) {
            throw IndexOutOfBoundsException("The required data size: ${length} is exceed remaining: ${remaining()}")
        }

        src.copyTo(bufferVal, startPos, ix(positionVal), length)
        position(positionVal + length)
    }

    public func expandAndPut(src: Array<Byte>): Unit {
        expandAndPut(src, 0, src.size)
    }

    /**
     * 将数据收集到目标字节数组中，收集到的字节数小于需要收集的字节数不会报错
     *
     * @param index 从ByteBuffer的指定位置开始收集
     * @param dst 目标字节数组
     * @param startPos 数组起始位置
     * @param length 需要收集的字节数
     * @return 收集到的字节数
     */
    public func partialGather(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Int64 {
        checkBounds(dst, startPos, length)
        checkIndex(index)
        let copyLen = min(length, limitVal - index)
        if (copyLen > 0) {
            // 只拷贝，不移动position
            bufferVal.copyTo(dst, ix(index), startPos, copyLen)
        }
        return copyLen
    }

    /**
     * 将数据收集到目标字节数组中，收集到的字节数小于目标数组的长度不会报错
     *
     * @param index 从ByteBuffer的指定位置开始收集
     * @param dst 目标字节数组
     * @param startPos 数组起始位置
     * @param length 需要收集的字节数
     * @return 收集到的字节数
     */
    public func partialGather(index: Int64, dst: Array<Byte>): Int64 {
        return partialGather(index, dst, 0, dst.size)
    }

    /**
     * 将目标数组的数据存储到ByteBuffer中，ByteBuffe存储容量不够不会报错
     *
     * @param index 从ByteBuffer的指定位置开始收集
     * @param dst 目标字节数组
     * @param startPos 数组起始位置
     * @param length 需要村粗的字节数
     * @return 完成存储的字节数
     */
    public func partialOffer(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Int64 {
        if (logger.isTraceEnabled()) {
            logger.log(
                LogLevel.TRACE,
                "PartialOffer array to  ${toString()}: index: ${index}, array size: ${dst.size}, startPos: ${startPos}, length: ${length}"
            )
        }

        checkBounds(dst, startPos, length)
        checkIndex(index)
        let copyLen = min(length, (limitVal - index))
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "PartialOffer copyed ${copyLen}")
        }

        if (copyLen > 0) {
            dst.copyTo(bufferVal, startPos, ix(index), copyLen)
        }
        return copyLen
    }

    /**
     * 将目标数组的数据存储到ByteBuffer中，ByteBuffe存储容量不够不会报错
     *
     * @param index 从ByteBuffer的指定位置开始收集
     * @param dst 目标字节数组
     * @return 完成存储的字节数
     */
    public func partialOffer(index: Int64, dst: Array<Byte>): Int64 {
        return partialOffer(index, dst, 0, dst.size)
    }

    public func toString() {
        return "ArrayByteBuffer{skipBytes: ${skipBytes}, position:${positionVal},limit:${limitVal},capacity:${capacityVal},maxCapacity: ${maxCapacityVal}}"
    }

    public func indexOf(needle: Buffer, pos: Int64): Int64 {
        if (pos < limitVal && hasRemaining()) {
            if (needle.hasRemaining() && remaining() > needle.remaining()) {
                let max: Int64 = pos + needle.remaining()
                for (i in pos..max) {
                    if (matches(needle, i)) {
                        return i;
                    }
                }
            }
        }

        return -1;
    }

    private func matches(needle: Buffer, pos: Int64): Bool {
        for (i in 0..needle.capacity()) {
            if (getByte(positionVal + pos + i) != needle.getByte(needle.position() + i)) {
                return false;
            }
        }
        return true;
    }

    public func indexOf(value: Byte, pos: Int64): Int64 {
        for (i in pos..capacityVal) {
            if (getByte(positionVal + i) == value) {
                return i;
            }
        }
        return -1;
    }

    public func startsWith(bytes: Array<Byte>): Bool {
        if (capacityVal - positionVal < bytes.size) {
            return false;
        }

        for (i in 0..bytes.size) {
            if (bufferVal[positionVal + i] != bytes[i]) {
                return false;
            }
        }
        return true;
    }
}
