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
 * 将Logger委托给仓颉log.SimpleLogger的LoggerFactory
 *
 *
 * @author yangfuping
 */
public class CJLoggerFactory <: ILoggerFactory {
    public func getInstance(name: String): Logger {
        if (let Some(outputStream) <- LoggerFactory.getOutputStream()) {
            return CJLoggerAdater(name, LoggerFactory.getLevel(), outputStream)
        } else {
            return CJLoggerAdater(name, LoggerFactory.getLevel(), getStdOut())
        }
    }
}

/**
 * 适配std模块中的log.Logger
 *
 * @author yangfuping
 */
public class CJLoggerAdater <: Logger {
    private var delegate: CJSimpleLogger
    private var cjLogLevel: CJLogLevel

    public init(name: String, level: LogLevel, outputStream: OutputStream) {
        this.delegate = CJSimpleLogger(outputStream)
        this.cjLogLevel = toCJLoggerLevel(level)
        delegate.level = cjLogLevel
    }

    public static func toCJLoggerLevel(logLevel: LogLevel): CJLogLevel {
        match (logLevel) {
            case ALL => CJLogLevel.ALL
            case TRACE => CJLogLevel.TRACE
            case DEBUG => CJLogLevel.DEBUG
            case INFO => CJLogLevel.INFO
            case WARN => CJLogLevel.WARN
            case ERROR => CJLogLevel.ERROR
            case FATAL => CJLogLevel.FATAL
            case OFF => CJLogLevel.OFF
        }
    }

    public static func toLoggerLevel(cjlogLevel: CJLogLevel): LogLevel {
        match (cjlogLevel.name) {
            case "ALL" => LogLevel.ALL
            case "TRACE" => LogLevel.TRACE
            case "DEBUG" => LogLevel.DEBUG
            case "INFO" => LogLevel.INFO
            case "WARN" => LogLevel.WARN
            case "ERROR" => LogLevel.ERROR
            case "FATAL" => LogLevel.FATAL
            case "OFF" => LogLevel.OFF
            case _ => LogLevel.INFO
        }
    }

    public func isTraceEnabled(): Bool {
        return LogLevel.TRACE >= toLoggerLevel(cjLogLevel)
    }

    public func isDebugEnabled(): Bool {
        return LogLevel.DEBUG >= toLoggerLevel(cjLogLevel)
    }

    public func isInfoEnabled(): Bool {
        return LogLevel.INFO >= toLoggerLevel(cjLogLevel)
    }

    public func isWarnEnabled(): Bool {
        return LogLevel.WARN >= toLoggerLevel(cjLogLevel)
    }

    public func isErrorEnabled(): Bool {
        return LogLevel.ERROR >= toLoggerLevel(cjLogLevel)
    }

    public func isFatalEnabled(): Bool {
        return LogLevel.FATAL >= toLoggerLevel(cjLogLevel)
    }

    public func trace(message: String): Unit {
        delegate.trace(message)
    }

    public func trace(message: String, exception: Exception): Unit {
        let builder = StringBuilder()
        builder.append(message)
        builder.append(DefaultSimpleLogFormatter.LINE_SEPARATOR)
        DefaultSimpleLogFormatter.formatException(builder, exception)
        delegate.trace(builder.toString())
    }

    public func debug(message: String): Unit {
        delegate.debug(message)
    }

    public func debug(message: String, exception: Exception): Unit {
        let builder = StringBuilder()
        builder.append(message)
        builder.append(DefaultSimpleLogFormatter.LINE_SEPARATOR)
        DefaultSimpleLogFormatter.formatException(builder, exception)
        delegate.debug(builder.toString())
    }

    public func info(message: String): Unit {
        delegate.info(message)
    }

    public func info(message: String, exception: Exception): Unit {
        let builder = StringBuilder()
        builder.append(message)
        builder.append(DefaultSimpleLogFormatter.LINE_SEPARATOR)
        DefaultSimpleLogFormatter.formatException(builder, exception)
        delegate.info(builder.toString())
    }

    public func warn(message: String): Unit {
        delegate.warn(message)
    }

    public func warn(message: String, exception: Exception): Unit {
        let builder = StringBuilder()
        builder.append(message)
        builder.append(DefaultSimpleLogFormatter.LINE_SEPARATOR)
        DefaultSimpleLogFormatter.formatException(builder, exception)
        delegate.warn(builder.toString())
    }

    public func error(message: String): Unit {
        delegate.error(message)
    }

    public func error(message: String, exception: Exception): Unit {
        let builder = StringBuilder()
        builder.append(message)
        builder.append(DefaultSimpleLogFormatter.LINE_SEPARATOR)
        DefaultSimpleLogFormatter.formatException(builder, exception)
        delegate.error(builder.toString())
    }

    public func fatal(message: String): Unit {
        return delegate.fatal(message)
    }

    public func fatal(message: String, exception: Exception): Unit {
        let builder = StringBuilder()
        builder.append(message)
        builder.append(DefaultSimpleLogFormatter.LINE_SEPARATOR)
        DefaultSimpleLogFormatter.formatException(builder, exception)
        delegate.fatal(builder.toString())
    }

    public func setLevel(level: LogLevel): Unit {
        let cjLogLevel = toCJLoggerLevel(level)
        this.cjLogLevel = cjLogLevel
        delegate.level = cjLogLevel
    }

    public func getLevel(): LogLevel {
        return toLoggerLevel(delegate.level)
    }

    public func isLoggable(level: LogLevel): Bool {
        return level >= toLoggerLevel(delegate.level)
    }

    public func log(level: LogLevel, message: String): Unit {
        delegate.log(toCJLoggerLevel(level), message)
    }

    public func log(level: LogLevel, message: String, exception: Exception): Unit {
        let builder = StringBuilder()
        builder.append(message)
        builder.append(DefaultSimpleLogFormatter.LINE_SEPARATOR)
        DefaultSimpleLogFormatter.formatException(builder, exception)
        delegate.log(toCJLoggerLevel(level), builder.toString())
    }

    public func setOutput(outputstream: OutputStream): Unit {
        let cjSimpleLogger = CJSimpleLogger(outputstream)
        cjSimpleLogger.level = this.cjLogLevel
        this.delegate = cjSimpleLogger
    }
}
