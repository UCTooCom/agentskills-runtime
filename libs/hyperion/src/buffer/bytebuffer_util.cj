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
 *  检查是否越界
 * 
 * @author yangfuping
 */
public func checkBounds(dst: Array<Byte>, startPos: Int64, length: Int64) {
    if (startPos < 0) {
        throw IllegalArgumentException("Negative array start positon ${startPos}")
    }

    if (length < 0) {
        throw IllegalArgumentException("Negative length ${length}")
    }

    if (startPos + length > dst.size) {
        throw IndexOutOfBoundsException(
            "The sum of start position ${startPos} and length ${length} is out of bounds, array's size is ${dst.size}")
    }
}

/**
 * 检查ByteBuffer的构造函数的参数释放合法
 * 
 * @author yangfuping
 */
public func checkBufferInitParams(
    position!: Int64,
    limit!: Int64,
    capacity!: Int64,
    maxCapacity!: Int64
) {
    if (position < 0) {
        throw IllegalArgumentException("Negative position is not allowed, provided position is ${position}")
    }

    if (capacity < 0) {
        throw IllegalArgumentException("Negative capacity is not allowed, provided capacity is ${capacity}")
    }

    if (maxCapacity < 0) {
        throw IllegalArgumentException("Negative maxCapacity is not allowed, provided maxCapacity is ${maxCapacity}")
    }

    if (limit > capacity) {
        throw IllegalArgumentException("Invalid limit ${limit}, provided capacity is ${capacity}")
    }

    if (capacity > maxCapacity) {
        throw IllegalArgumentException("Invalid maxCapacity ${maxCapacity}, provided capacity is ${capacity}")
    }

    if (position > limit) {
        throw IllegalArgumentException("Invalid position ${position}, provided limit is ${limit}")
    }
}

/**
 * 获取最大容量
 *
 * @author yangfuping
 */
public func getMaxCapacity(capacity: Int64, expandSupport: Bool): Int64 {
    if (!expandSupport) {
        return capacity
    }

    return ByteBuffer.DEFAULT_MAX_CAPACITY
}
