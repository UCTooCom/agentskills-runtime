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

public class BitSetBin {
    private let list: LinkedList<?BitSet>
    private var maxNumberOfBins: Int64
    private var lastInOrderBit: Int64 = -1
    private var firstIndex: Int64 = -1

    public init(windowSize: Int64) {
        this.maxNumberOfBins = ((windowSize + 1) / BitSet.INT64_SIZE) + 1
        this.maxNumberOfBins = max(maxNumberOfBins, 1)
        //初始化链表结点，但是值为None
        this.list = LinkedList<?BitSet>(maxNumberOfBins, {index: Int64 => None})
    }

    public func setBit(index: Int64, value: Bool): Bool {
        var result = false
        var bs: ?BitSet = getBitSet(index)
        if (let Some(bs) <- bs) {
            var offset = getOffset(index)
            if (offset >= 0) {
                result = bs.set(offset, value)
            }
        }
        return result
    }

    public func isInOrder(index: Int64): Bool {
        var result = false
        if (lastInOrderBit == -1) {
            result = true
        } else {
            result = lastInOrderBit + 1 == index
        }
        lastInOrderBit = index
        return result
    }

    public func getBit(index: Int64): Bool {
        var answer = index >= firstIndex
        if (let Some(bs) <- getBitSet(index)) {
            var offset = getOffset(index)
            if (offset >= 0) {
                return bs.get(offset)
            }
        } else {
            answer = true
        }
        return answer
    }

    private func getBitSet(index: Int64): ?BitSet {
        var bin: Int64 = getBin(index)
        var answer: ?BitSet = None
        if (bin >= 0) {
            if (bin >= maxNumberOfBins) {
                var overShoot = bin - maxNumberOfBins + 1
                while (overShoot > 0) {
                    list.removeFirst()
                    firstIndex += BitSet.INT64_SIZE
                    list.addLast(BitSet())
                    overShoot--
                }

                bin = maxNumberOfBins - 1
            }
            if (let Some(node) <- list.nodeAt(bin)) {
                if (node.value.isNone()) {
                    node.value = BitSet()
                }
                answer = node.value
            }
        }
        return answer
    }

    /**
     * 获取所在桶的位置
     */
    private func getBin(index: Int64): Int64 {
        var answer = 0
        if (firstIndex < 0) {
            firstIndex = index
        } else {
            answer = (index - firstIndex) / BitSet.INT64_SIZE
        }
        return answer
    }

    /**
     * 获取所在桶的位偏移
     */
    private func getOffset(index: Int64): Int64 {
        var answer: Int64 = 0
        if (firstIndex >= 0) {
            answer = (index - firstIndex) % BitSet.INT64_SIZE
        }
        return answer
    }

    public func getLastSetIndex(): Int64 {
        var result: Int64 = -1

        if (firstIndex >= 0) {
            result = firstIndex
            var last: ?BitSet = None
            var lastBitArrayIndex = maxNumberOfBins - 1
            while (lastBitArrayIndex >= 0) {
                if (let Some(node) <- list.nodeAt(lastBitArrayIndex)) {
                    last = node.value
                    if (let Some(last) <- last) {
                        result += last.size - 1
                        result += lastBitArrayIndex * BitSet.INT64_SIZE
                        break
                    }
                }
                lastBitArrayIndex--
            }
        }
        return result
    }
}
