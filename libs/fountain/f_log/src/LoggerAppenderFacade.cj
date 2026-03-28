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
import stdx.log.{LogLevel, LogRecord}
import f_io.DummyOutputStream

public class LoggerAppenderFacade <: AsyncLogger {
    private let appenders: Array<AbstractLogger>
    public init(name: String, appenders: Array<AbstractLogger>) {
        super(name, LogLevel.ALL, LogPattern.default, DummyOutputStream.THROW_ON_ACCESSING,
            'f_log.LoggerAppenderFacade_${name}')
        this.appenders = appenders
    }
    func isEmpty(){
        appenders.isEmpty()
    }
    public func logLevelEnabled(level: LogLevel): Bool {
        for (appender in appenders where appender.logLevelEnabled(level)) {
            return true
        }
        return false
    }
    public open func log(record: LogRecord): Unit {
        append {
            for (appender in appenders) {
                appender.log(record)
            }
        }
    }
    protected func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        append {
            for (appender in appenders) {
                appender.append(level, message, now, tid, ex)
            }
        }
    }
    public func close(): Unit {
        for (appender in appenders) {
            try {
                if(!appender.isClosed()){
                    appender.close()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
