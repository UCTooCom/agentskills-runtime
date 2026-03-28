/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_ticktock

import std.collection.ArrayList

@Test
public class TicktockUnitTest {
    @TestCase
    public func testSecond(): Unit {
        var result = TicktockUnit.SECONDLY.convertDuration(0, 59, 1)
        @Assert(0,result[0])
        @Assert(59,result[1])
        @Assert(1,result[2])

        result = TicktockUnit.SECONDLY.convertDuration(1, 30, 4)
        @Assert(1,result[0])
        @Assert(30,result[1])
        @Assert(4,result[2])

        try {
            result = TicktockUnit.SECONDLY.convertDuration(1, 30, 0)
            @Assert(1,0)
        } catch (e: IllegalArgumentException) {}
        try {
            result = TicktockUnit.SECONDLY.convertDuration(1, 0, 1)
            @Assert(1,0)
        } catch (e: IllegalArgumentException) {}
        try {
            result = TicktockUnit.SECONDLY.convertDuration(2, 1, 1)
            @Assert(1,0)
        } catch (e: IllegalArgumentException) {}

        result = TicktockUnit.SECONDLY.convertRange(ArrayList<Int64>([0, 59]))
        @Assert(0,result[0].start)
        @Assert(59,result[0].end)

        result = TicktockUnit.SECONDLY.convertRange(ArrayList<Int64>([1, 58]))
        @Assert(1,result[0].start)
        @Assert(58,result[0].end)

        try {
            result = TicktockUnit.SECONDLY.convertRange(ArrayList<Int64>([1, 60]))
            @Assert(1,0)
        } catch (e: IllegalArgumentException) {}
        try {
            result = TicktockUnit.SECONDLY.convertRange(ArrayList<Int64>([60, 59]))
            @Assert(1,0)
        } catch (e: IllegalArgumentException) {}
    }
    @TestCase
    public func testMonthDaily(): Unit {
        var result = TicktockUnit.MONTH_DAILY.convertDuration(1, 31, 1)
        @Assert(1,result[0].start)
        @Assert(31,result[0].end)
        @Assert(1,result[0].step)

        result = TicktockUnit.MONTH_DAILY.convertDuration(1, 31, 4)
        @Assert(1,result[0].start)
        @Assert(31,result[0].end)
        @Assert(4,result[0].step)

        result = TicktockUnit.MONTH_DAILY.convertRange(ArrayList<Int64>([1, 31]))
        @Assert(1,result[0].start)
        @Assert(31,result[0].end)

        try {
            result = TicktockUnit.MONTH_DAILY.convertRange(ArrayList<Int64>([1, 32]))
            @Assert(1,0)
        } catch (e: IllegalArgumentException) {}
    }
    @TestCase
    public func testWeekDaily(): Unit {
        var result = TicktockUnit.WEEK_DAILY.convertDuration(1, 7, 1)
        @Assert(1,result[0].start)
        @Assert(7,result[0].end)
        @Assert(1,result[0].step)

        result = TicktockUnit.WEEK_DAILY.convertDuration(1, 7, 4)
        @Assert(1,result[0].start)
        @Assert(7,result[0].end)
        @Assert(4,result[0].step)

        result = TicktockUnit.WEEK_DAILY.convertDuration(0, 7, 4)
        @Assert(4,result[0].start)
        @Assert(7,result[0].end)
        @Assert(4,result[0].step)
        @Assert(7,result[1].start)
        @Assert(7,result[1].end)
        @Assert(1,result[1].step)

        result = TicktockUnit.WEEK_DAILY.convertRange(ArrayList<Int64>([1, 7]))
        @Assert(1,result[0].start)
        @Assert(7,result[0].end)

        result = TicktockUnit.WEEK_DAILY.convertRange(ArrayList<Int64>([0, 7]))
        @Assert(1,result[0].start)
        @Assert(7,result[0].end)

        result = TicktockUnit.WEEK_DAILY.convertRange(ArrayList<Int64>([0, 6]))
        @Assert(1,result[0].start)
        @Assert(7,result[0].end)

        result = TicktockUnit.WEEK_DAILY.convertRange(ArrayList<Int64>([0, 5]))
        @Assert(1, result[0].start)
        @Assert(5, result[0].end)
        @Assert(7, result[1].start)
        @Assert(7, result[1].end)

        result = TicktockUnit.WEEK_DAILY.convertRange(ArrayList<Int64>([1, 6]))
        @Assert(1, result[0].start)
        @Assert(6, result[0].end)
    }
}
