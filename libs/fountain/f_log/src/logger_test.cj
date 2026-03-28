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

import std.unittest.*
import std.unittest.testmacro.*
import std.env
import stdx.log.*
import std.process.Process

public open class TestLogAppender <: AbstractLogger {
    init(name!: String, level!: LogLevel) {
        super(name, level, LogPattern("[%level-%name] %d{yyyy/MM/dd,HH:mm:ss.SSS}|%m"), env.getStdOut())
    }
}

let _ = Test1LogAppender.register(LogLevel.INFO)

public class Test1LogAppender <: TestLogAppender {
    public init(level!: LogLevel) {
        super(name: "test1", level: level)
    }
    public static func register(level: LogLevel): Unit {
        LoggerAppenderCreator.register("test1") {
            name => [Test1LogAppender(level: level)]
        }
    }
}

let _ = Test2LogAppender.register(LogLevel.ERROR)

public class Test2LogAppender <: TestLogAppender {
    public init(level!: LogLevel) {
        super(name: "test2", level: level)
    }
    public static func register(level: LogLevel): Unit {
        LoggerAppenderCreator.register("test2") {
            name => [Test2LogAppender(level: level)]
        }
    }
}

@Test
public class LoggerTest {
    @TestCase
    public func test(): Unit {
        let log = LoggerFactory.getLogger("LoggerTest")
        log.debug("no")
        log.info("all")
        log.warn("warn")
        log.error("err")
    }
}
