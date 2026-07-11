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

public class BitSet {
    public static let INT64_SIZE: Int64 = 64
    private static let ADDRESS_BITS_PER_WORD: Int64 = 6
    private var words: Array<Int64>
    private var sizeVal: Int64 = 0

    public init() {
        //默认只给64位，这样可以与Java客户端在窗口控制达到相同的效果
        words = Array<Int64>(1, repeat: 0)
    }

    private static func wordIndex(bitIndex: Int64): Int64 {
        return bitIndex >> ADDRESS_BITS_PER_WORD
    }

    /**
     * 设置位，并返回旧值
     */
    public func set(bitIndex: Int64, value: Bool): Bool {
        sizeVal = max(sizeVal, bitIndex + 1)
        if (value) {
            return set(bitIndex)
        } else {
            return clear(bitIndex)
        }
    }

    public func set(bitIndex: Int64): Bool {
        var wordIndex = wordIndex(bitIndex)
        //获取旧值，Cangjie的位运算要求有相同的位宽
        var oldValue: Bool = (words[wordIndex] & 1 << (bitIndex % INT64_SIZE)) != 0
        //设置新值
        words[wordIndex] |= (1 << (bitIndex % INT64_SIZE))
        return oldValue
    }

    public func clear(bitIndex: Int64): Bool {
        var wordIndex = wordIndex(bitIndex)
        var oldValue: Bool = (words[wordIndex] & (1 << (bitIndex % INT64_SIZE))) != 0
        //清除对应位的值，!表示取反，与其它语言的~运算符作用相同
        words[wordIndex] &= !(1 << (bitIndex % INT64_SIZE))

        return oldValue
    }

    public func get(bitIndex: Int64): Bool {
        var wordIndex = wordIndex(bitIndex)
        return ((words[wordIndex] & (1 << (bitIndex % INT64_SIZE))) != 0)
    }

    public prop size: Int64 {
        get() {
            return this.sizeVal
        }
    }
}
