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
public class BitSetBinTest {
    @TestCase
    public func testSetHiLo(): Unit {
        var toTest = BitSetBin(50)
        toTest.setBit(0, true)
        toTest.setBit(100, true)
        toTest.setBit(150, true)
        @Assert(true, toTest.getBit(0))

        toTest.setBit(0, true)
        @Assert(true, toTest.getBit(0))
    }

    @TestCase
    public func testSetAroundWindow(): Unit {
        doTestSetAroundWindow(500, 2000)
        doTestSetAroundWindow(512, 2000)
        doTestSetAroundWindow(128, 512)
    }

    private func doTestSetAroundWindow(window: Int64, dataSize: Int64): Unit {
        var toTest = BitSetBin(window)

        for (i in 0..dataSize + 1) {
            @Assert(false, toTest.setBit(i, true))
            @Assert(i, toTest.getLastSetIndex())
        }

        @Assert(dataSize, toTest.getLastSetIndex())

        var windowOfValidData = roundWindow(dataSize, window)
        var i = dataSize
        while (i >= dataSize - windowOfValidData) {
            @Assert(true, toTest.setBit(i, true))
            i--
        }

        @Assert(dataSize, toTest.getLastSetIndex())

        while (i >= 0) {
            @Assert(false, toTest.setBit(i, true))
            i--
        }

        var j = dataSize + 1
        while (j <= (2 * dataSize)) {
            @Assert(false, toTest.setBit(j, true))
            j++
        }

        @Assert(2 * dataSize, toTest.getLastSetIndex())
    }

    private func roundWindow(dataSetEnd: Int64, windowSize: Int64): Int64 {
        var validData = dataSetEnd - windowSize
        var validDataBin = validData / BitSet.INT64_SIZE
        if (windowSize % BitSet.INT64_SIZE > 0) {
            validDataBin += 1
        }
        var startOfValid = validDataBin * BitSet.INT64_SIZE

        return dataSetEnd - startOfValid
    }

    @TestCase
    public func testSetUnsetAroundWindow(): Unit {
        doTestSetUnSetAroundWindow(500, 2000)
        doTestSetUnSetAroundWindow(512, 2000)
        doTestSetUnSetAroundWindow(128, 512)
    }

    private func doTestSetUnSetAroundWindow(dataSize: Int64, window: Int64): Unit {
        var toTest = BitSetBin(window)

        for (i in 0..dataSize + 1) {
            @Assert(!toTest.setBit(i, true))
        }

        var windowOfValidData = roundWindow(dataSize, window)

        var i = dataSize
        while (i >= 0 && i >= dataSize - windowOfValidData) {
            @Assert(toTest.setBit(i, false))
            i--
        }

        for (i in 0..dataSize + 1) {
            @Assert(!toTest.setBit(i, true))
        }

        var j = 2 * dataSize
        while (j < 4 * dataSize) {
            @Assert(!toTest.setBit(j, true))
            j++
        }
    }

    @TestCase
    public func testSetAroundLongSizeMultiplier(): Unit {
        var window = 512
        var dataSize = 1000
        var muliplier = 1
        while (muliplier < 8) {
            for (value in 0..dataSize) {
                var toTest = BitSetBin(window)

                var instance = value + muliplier * BitSet.INT64_SIZE
                @Assert(!toTest.setBit(instance, true))
                @Assert(!toTest.setBit(value, true))
                @Assert(instance, toTest.getLastSetIndex())
            }
            muliplier++
        }
    }

    @TestCase
    public func testLargeGapInData(): Unit {
        doTestLargeGapInData(128)
        doTestLargeGapInData(500)
    }

    public func doTestLargeGapInData(window: Int64): Unit {
        var toTest = BitSetBin(window)

        var instance = BitSet.INT64_SIZE
        @Assert(!toTest.setBit(instance, true))

        instance = 12 * BitSet.INT64_SIZE
        @Assert(!toTest.setBit(instance, true))

        instance = 9 * BitSet.INT64_SIZE
        @Assert(!toTest.setBit(instance, true))
    }

    @TestCase
    public func testLastSeq(): Unit {
        var toTest = BitSetBin(512)
        @Assert(-1, toTest.getLastSetIndex())

        toTest.setBit(1, true)
        @Assert(1, toTest.getLastSetIndex())

        toTest.setBit(64, true)
        @Assert(64, toTest.getLastSetIndex())

        toTest.setBit(68, true)
        @Assert(68, toTest.getLastSetIndex())
    }

    @TestCase
    public func testLargeNumber(): Unit {
        var toTest = BitSetBin(512)
        toTest.setBit(1, true)
        var largeNum: Int64 = Int64(Int32.Max) * 2 + 100
        toTest.setBit(largeNum, true);
        @Assert(true, toTest.getBit(largeNum))
    }

    @TestCase
    public func testLargeNumber2(): Unit {
        var toTest = BitSetBin(1024)
        var largeNum: Int64 = Int64(Int32.Max) + 100
        toTest.setBit(largeNum, true)
        @Assert(true, toTest.getBit(largeNum))
    }
}
