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

package hyperion.logadapter

/**
 * 打印日志到控制台
 *
 * @author yangfuping
 */
public class SimpleLogger <: Logger {
    private let name: String

    private var level: LogLevel

    private var handler: SimpleLoggerHandler

    public init(name: String) {
        this(
            name,
            LogLevel.INFO,
            SimpleStreamLoggerHandler(DefaultSimpleLogFormatter(), getStdOut())
        )
    }

    public init(name: String, handler: SimpleLoggerHandler) {
        this.name = name
        this.level = LogLevel.INFO
        this.handler = handler
    }

    public init(name: String, level: LogLevel, handler: SimpleLoggerHandler) {
        this.name = name
        this.level = level
        this.handler = handler
    }

    public func isTraceEnabled(): Bool {
        return LogLevel.TRACE >= this.level
    }

    public func isDebugEnabled(): Bool {
        return LogLevel.DEBUG >= this.level
    }

    public func isInfoEnabled(): Bool {
        return LogLevel.INFO >= this.level
    }

    public func isWarnEnabled(): Bool {
        return LogLevel.WARN >= this.level
    }

    public func isErrorEnabled(): Bool {
        return LogLevel.ERROR >= this.level
    }

    public override func isFatalEnabled(): Bool {
        return LogLevel.FATAL >= this.level
    }

    public func trace(message: String): Unit {
        log(LogLevel.TRACE, message)
    }

    public func trace(message: String, exception: Exception): Unit {
        log(LogLevel.TRACE, message, exception)
    }

    public func debug(message: String): Unit {
        log(LogLevel.DEBUG, message)
    }

    public func debug(message: String, exception: Exception): Unit {
        log(LogLevel.DEBUG, message, exception)
    }

    public func info(message: String): Unit {
        log(LogLevel.INFO, message)
    }

    public func info(message: String, exception: Exception): Unit {
        log(LogLevel.INFO, message, exception)
    }

    public func warn(message: String): Unit {
        log(LogLevel.WARN, message)
    }

    public func warn(message: String, exception: Exception): Unit {
        log(LogLevel.WARN, message, exception)
    }

    public func error(message: String): Unit {
        log(LogLevel.ERROR, message)
    }

    public func error(message: String, exception: Exception): Unit {
        log(LogLevel.ERROR, message, exception)
    }

    public override func fatal(message: String): Unit {
        log(LogLevel.FATAL, message)
    }

    public override func fatal(message: String, exception: Exception): Unit {
        log(LogLevel.FATAL, message, exception)
    }

    public func setLevel(level: LogLevel): Unit {
        this.level = level
    }

    public func getLevel(): LogLevel {
        return level
    }

    public func isLoggable(level: LogLevel): Bool {
        return level >= this.level
    }

    public func log(level: LogLevel, message: String): Unit {
        let currentTime = DateTime.now()
        let record = SimpleLogRecord(name, level, currentTime, message)
        log(record)
    }

    public func log(level: LogLevel, message: String, exception: Exception): Unit {
        let currentTime = DateTime.now()
        let record = SimpleLogRecord(name, level, currentTime, message, exception)
        log(record)
    }

    public func log(record: SimpleLogRecord): Unit {
        handler.publish(record)
    }

    public func setOutput(outputstream: OutputStream): Unit {
        if (let Some(streamHandler) <- (handler as StreamLoggerHandler)) {
            streamHandler.updateStream(outputstream)
        }
    }
}
