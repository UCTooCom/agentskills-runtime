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
package f_log.impl

import std.env

class ConsoleLoggerAppender <: AsyncLogger {
    private static const LOGGER_NAME = 'console'
    private static let appenders = ConcurrentHashMap<ConsoleLoggerParams, AbstractLogger>()
    init(name: String, level: LogLevel, pattern: LogPattern){
        super(name, level, pattern, env.getStdOut(), '${LOGGER_NAME}://')
    }
    protected func new(name: String): AbstractLogger{
        ConsoleLoggerAppender(name, this.level, this.pattern)
    }
    public static func register(): Unit {
        ConsoleLoggerParams.register(LOGGER_NAME, appenders)
    }
    public mut prop closable: Bool {
        get() {
            false
        }
        set(value){}
    }
}
public class ConsoleLoggerParams <: BaseLoggerParams<ConsoleLoggerParams>{
    public init(level: LogLevel, pattern: LogPattern) {
        super(level, pattern)
        super.h = HashBuilder().append(level).append(pattern).build()
    }
    public operator func ==(that: ConsoleLoggerParams): Bool {
        this.hashCode() == that.hashCode() && this.level == that.level && this.pattern == that.pattern
    }
    protected static func newParams(appender: String): ConsoleLoggerParams {
        ConsoleLoggerParams(LoggerConfig.getLevelConf(appender), LoggerConfig.getPatternConf(appender))
    }
    protected func newAppender(name: String): AbstractLogger {
        ConsoleLoggerAppender(name, level, pattern)
    }
}
let _ = ConsoleLoggerAppender.register() //将本实现注册到LoggerAppenderCreator
