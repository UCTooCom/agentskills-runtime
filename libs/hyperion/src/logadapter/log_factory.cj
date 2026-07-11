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
 * LoggerFactory接口
 * @author yangfuping
 */
public interface ILoggerFactory {
    func getInstance(name: String): Logger
}

/**
 * 默认的LoggerFactory实现
 *
 * @author yangfuping
 */
public class LoggerFactory {
    private static var level: LogLevel = LogLevel.INFO

    private static var factory: ILoggerFactory = SimpleLoggerFactory()

    private static var outputStream: ?OutputStream = None

    private static let loggers = ConcurrentHashMap<String, FactoryDelegateLogger>()

    private static let logMutex = Mutex()

    public static func setLevel(level: LogLevel) {
        LoggerFactory.level = level

        synchronized(logMutex) {
            // 依次更新已创建Logger的LogLevel
            for ((_, logger) in loggers) {
                logger.setLevel(level)
            }
        }
    }

    public static func getLevel(): LogLevel {
        return level
    }

    public static func setLogFactory(factory: ILoggerFactory) {
        synchronized(logMutex) {
            LoggerFactory.factory = factory

            // 依次更新已创建Logger的LogFactory
            for ((_, logger) in loggers) {
                logger.setFactory(factory)
            }
        }
    }

    public static func getLogFactory(): ILoggerFactory {
        return LoggerFactory.factory
    }

    public static func setOutputStream(outputStream: OutputStream) {
        synchronized(logMutex) {
            LoggerFactory.outputStream = outputStream

            // 依次更新已创建Logger的OutputStream
            for ((_, logger) in loggers) {
                logger.setOutput(outputStream)
            }
        }
    }

    public static func getOutputStream(): ?OutputStream {
        return LoggerFactory.outputStream
    }

    public static func getLogger(name: String): Logger {
        if (let Some(logger) <- loggers.get(name)) {
            return logger
        }

        synchronized(logMutex) {
            if (let Some(logger) <- loggers.get(name)) {
                return logger
            }

            let logger = FactoryDelegateLogger(LoggerFactory.factory, name, level)
            loggers.add(name, logger)
            return logger
        }
    }
}
