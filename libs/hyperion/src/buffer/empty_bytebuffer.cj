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
 * 空的ByteBuffer实现
 *
 * @author yangfuping
 */
public class EmptyByteBuffer <: ByteBuffer {
    protected init() {
        super(
            position: 0,
            limit: 0,
            capacity: 0,
            maxCapacity: 0,
            expandSupport: false
        )
    }

    public func remainingCapacity(): Int64 {
        return 0
    }

    public func skip(skipSize: Int64): Buffer {
        return this
    }

    public func free(): Unit {
    }

    public func slice(): ByteBuffer {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func slice(index!: Int64, length!: Int64): ByteBuffer {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func slice(range: Range<Int64>): ByteBuffer {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func compact(): ByteBuffer {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    /**
     * 扩充容量
     */
    protected func expandCapacity(needCapicity: Int64): ByteBuffer {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func toArray(): Array<Byte> {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func toArray(index!: Int64, length!: Int64): Array<Byte> {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func toArray(range: Range<Int64>): Array<Byte> {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getByte(): Byte {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getUInt16(): UInt16 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getUInt32(): UInt32 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getUInt64(): UInt64 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt8(): Int8 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt16(): Int16 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt32(): Int32 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt64(): Int64 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getByte(index: Int64): Byte {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getUInt16(index: Int64): UInt16 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getUInt32(index: Int64): UInt32 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func getUInt64(index: Int64): UInt64 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt8(index: Int64): Int8 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt16(index: Int64): Int16 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt32(index: Int64): Int32 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    @OverflowWrapping
    public func getInt64(index: Int64): Int64 {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putByte(value: Byte) {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putUInt16(val: UInt16): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putUInt32(val: UInt32): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putUInt64(val: UInt64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putInt8(val: Int8): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putInt16(val: Int16): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putInt32(val: Int32): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putInt64(val: Int64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putByte(index: Int64, value: Byte): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putUInt16(index: Int64, val: UInt16): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putUInt32(index: Int64, val: UInt32): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func putUInt64(index: Int64, val: UInt64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
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
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPutUInt16(val: UInt16): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPutUInt32(val: UInt32): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPutUInt64(val: UInt64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPutInt8(val: Int8): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPutInt16(val: Int16): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPutInt32(val: Int32): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPutInt64(val: Int64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func get(dst: Array<Byte>, startPos: Int64, length: Int64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func get(dst: Array<Byte>): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func get(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func get(index: Int64, dst: Array<Byte>): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func put(src: Array<Byte>, startPos: Int64, length: Int64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func put(src: Array<Byte>): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func put(index: Int64, src: Array<Byte>, startPos: Int64, length: Int64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func put(index: Int64, src: Array<Byte>): Unit {
        put(index, src, 0, src.size)
    }

    public func expandAndPut(src: Array<Byte>, startPos: Int64, length: Int64): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func expandAndPut(src: Array<Byte>): Unit {
        throw IndexOutOfBoundsException("Operation not supported by EmptyByteBuffer")
    }

    public func partialGather(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Int64 {
        return 0
    }

    public func partialGather(index: Int64, dst: Array<Byte>): Int64 {
        return partialGather(index, dst, 0, dst.size)
    }

    public func partialOffer(index: Int64, dst: Array<Byte>, startPos: Int64, length: Int64): Int64 {
        return 0
    }

    public func partialOffer(index: Int64, dst: Array<Byte>): Int64 {
        return 0
    }

    public func toString() {
        return "EmptyByteBuffer{position:${position()},limit:${limit()},capacity:${capacity()},maxCapacity: ${maxCapacityVal}}"
    }
}
