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
public class BitSetTest {
    @TestCase
    public func testBitSetInitialization(): Unit {
        var bitSet = BitSet()
        @Assert(false, bitSet.get(0))
    }

    @TestCase
    public func testSetAndGetBits(): Unit {
        var bitSet = BitSet()
        bitSet.set(5, true)
        @Assert(true, bitSet.get(5))
        @Assert(false, bitSet.get(6))
    }

    @TestCase
    public func testClearBits(): Unit {
        var bitSet = BitSet()
        // 设置第5位为true
        bitSet.set(5)
        // 清除第5位
        bitSet.clear(5)
        // 验证第5位为false
        @Assert(false, bitSet.get(5))
    }

    @TestCase
    public func testBitSetSize(): Unit {
        var bitSet = BitSet()
        bitSet.set(10)
    }

    @TestCase
    public func testSetAllBits() {
        var bitSet = BitSet()
        // 设置第0到第9位为true
        for (i in 0..10) {
            @Assert(false, bitSet.set(i))
        }

        for (i in 0..10) {
            @Assert(true, bitSet.get(i))
        }

        for (i in 10..15) {
            @Assert(false, bitSet.get(i))
        }
    }
}
