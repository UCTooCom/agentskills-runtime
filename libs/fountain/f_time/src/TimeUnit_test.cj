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
package f_time

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class TimeUnitTest {
    @TestCase
    public func test(): Unit {
        let fmt = 'yyyy-MM-dd HH:mm:ss.SSS'
        let date = DateTime.parse('2024-11-24 14:34:55.123456789', fmt)
        @Assert('2024-11-24 14:34:55.000000000', TU.SECOND.trim(date).toString(fmt))
        @Assert('2024-11-24 14:34:00.000000000', TU.MINUTE.trim(date).toString(fmt))
        @Assert('2024-11-24 14:00:00.000000000', TU.HOUR.trim(date).toString(fmt))
        @Assert('2024-11-24 00:00:00.000000000', TU.DAY.trim(date).toString(fmt))
        @Assert('2024-11-01 00:00:00.000000000', TU.MONTH.trim(date).toString(fmt))
        @Assert('2024-11-24 00:00:00.000000000', TU.WEEK.trim(date).toString(fmt))
        @Assert('2024-01-01 00:00:00.000000000', TU.YEAR.trim(date).toString(fmt))
    }
}
