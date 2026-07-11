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
 * 日志级别
 * 
 * @author yangfuping
 */
public enum LogLevel {
    ALL | TRACE | DEBUG | INFO | WARN | ERROR | FATAL | OFF

    public func getLevel(): Int64 {
        match (this) {
            case ALL => 0
            case TRACE => 100
            case DEBUG => 200
            case INFO => 300
            case WARN => 400
            case ERROR => 500
            case FATAL => 600
            case OFF => 700
        }
    }

    public func getName(): String {
        match (this) {
            case ALL => "ALL"
            case TRACE => "TRACE"
            case DEBUG => "DEBUG"
            case INFO => "INFO"
            case WARN => "WARN"
            case ERROR => "ERROR"
            case FATAL => "FATAL"
            case OFF => "OFF"
        }
    }

    public operator func >=(other: LogLevel): Bool {
        return this.getLevel() >= other.getLevel()
    }
}

/**
 * Logger接口
 *
 * 支持打印异常的堆栈
 *
 * @author yangfuping
 */
public interface Logger {
    func isTraceEnabled(): Bool

    func isDebugEnabled(): Bool

    func isInfoEnabled(): Bool

    func isWarnEnabled(): Bool

    func isErrorEnabled(): Bool

    func isFatalEnabled(): Bool

    func trace(message: String): Unit

    func trace(message: String, exception: Exception): Unit

    func debug(message: String): Unit

    func debug(message: String, exception: Exception): Unit

    func info(message: String): Unit

    func info(message: String, exception: Exception): Unit

    func warn(message: String): Unit

    func warn(message: String, exception: Exception): Unit

    func error(message: String): Unit

    func error(message: String, exception: Exception): Unit

    func fatal(message: String): Unit

    func fatal(message: String, exception: Exception): Unit

    func setLevel(level: LogLevel): Unit

    func getLevel(): LogLevel

    func isLoggable(level: LogLevel): Bool

    func log(level: LogLevel, message: String): Unit

    func log(level: LogLevel, message: String, exception: Exception): Unit

    func setOutput(outputstream: OutputStream): Unit
}
