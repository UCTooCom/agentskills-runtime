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
 * 默认的日志工厂实现
 *
 *
 * @author yangfuping
 */
public class SimpleLoggerFactory <: ILoggerFactory {
    private static var logFormatter = DefaultSimpleLogFormatter()

    private static var logHandler: ?SimpleLoggerHandler = None

    private static let simpleLoggerMutex = Mutex()

    public static func setLoggerHanlder(logHandler: SimpleLoggerHandler) {
        synchronized(simpleLoggerMutex) {
            SimpleLoggerFactory.logHandler = logHandler
        }
    }

    public static func getLoggerHandler(): SimpleLoggerHandler {
        if (let Some(logHandler) <- logHandler) {
            return logHandler
        }

        synchronized(simpleLoggerMutex) {
            if (let Some(logHandler) <- logHandler) {
                return logHandler
            }

            if (let Some(outputStream) <- LoggerFactory.getOutputStream()) {
                let handler = SimpleStreamLoggerHandler(logFormatter, outputStream)
                logHandler = handler
                return handler
            } else {
                let handler = SimpleStreamLoggerHandler(logFormatter, getStdOut())
                logHandler = handler
                return handler
            }
        }
    }

    public static func setLoggerFormatter(logFormatter: DefaultSimpleLogFormatter) {
        synchronized(simpleLoggerMutex) {
            SimpleLoggerFactory.logFormatter = logFormatter
        }
    }

    public func getInstance(name: String): Logger {
        return SimpleLogger(name, getLoggerHandler())
    }
}
