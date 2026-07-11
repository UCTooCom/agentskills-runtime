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
 * 不记录日志的LoggerFactory实现
 *
 * @author yangfuping
 */
public class NoOpLogFactory <: ILoggerFactory {
    public func getInstance(name: String): Logger {
        return NoOpLogger()
    }
}

/**
 * 不记录日志
 *
 * @author yangfuping
 */
public class NoOpLogger <: Logger {
    public override func isTraceEnabled(): Bool {
        return false
    }

    public override func isDebugEnabled(): Bool {
        return false
    }

    public override func isInfoEnabled(): Bool {
        return false
    }

    public override func isWarnEnabled(): Bool {
        return false
    }

    public override func isErrorEnabled(): Bool {
        return false
    }

    public override func isFatalEnabled(): Bool {
        return false
    }

    public override func trace(message: String): Unit {
    }

    public override func trace(message: String, exception: Exception): Unit {
    }

    public override func debug(message: String): Unit {
    }

    public override func debug(message: String, exception: Exception): Unit {
    }

    public override func info(message: String): Unit {
    }

    public override func info(message: String, exception: Exception): Unit {
    }

    public override func warn(message: String): Unit {
    }

    public override func warn(message: String, exception: Exception): Unit {
    }

    public override func error(message: String): Unit {
    }

    public override func error(message: String, exception: Exception): Unit {
    }

    public override func fatal(message: String): Unit {
    }

    public override func fatal(message: String, exception: Exception): Unit {
    }

    public override func setLevel(level: LogLevel): Unit {
    }

    public override func getLevel(): LogLevel {
        return LogLevel.OFF
    }

    public override func isLoggable(level: LogLevel): Bool {
        return false
    }

    public override func log(level: LogLevel, message: String): Unit {
    }

    public override func log(level: LogLevel, message: String, exception: Exception): Unit {
    }

    public override func setOutput(outputstream: OutputStream): Unit {
    }
}
