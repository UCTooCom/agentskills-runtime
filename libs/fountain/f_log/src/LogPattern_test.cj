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
package f_log

import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.log.LogLevel

@Test
public class LogPattern_test {
    @TestCase
    public func test0(): Unit {
        let pattern = LogPattern("[%level%-%name]% %d{yyyy/MM/dd,HH:mm:ss.SSS}|%%m%")
        let now = DateTime.now()
        let level = LogLevel.ERROR
        let logmsg = pattern.generate("test", level, "test message", now)
        println(logmsg)
        let tpl = "[${level.text}%-test]% ${now.format("yyyy/MM/dd,HH:mm:ss.SSS")}|%test message%\n"
        @Assert(tpl, logmsg)
    }
}
