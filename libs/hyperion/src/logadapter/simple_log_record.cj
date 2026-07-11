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
 * 日志记录
 *
 * @author yangfuping
 */
public open class SimpleLogRecord {
    protected let name: String
    protected let level: LogLevel
    protected let threadName: String
    protected let logTime: DateTime
    protected let message: String
    protected var exception: ?Exception = None

    private static func getThreadName(): String {
        let thread = Thread.currentThread

        let builer = StringBuilder()
        builer.append("ThreadId=")
        builer.append(thread.id)
        if (!thread.name.isEmpty()) {
            builer.append("; ")
            builer.append("ThreadName=")
            builer.append(thread.name)
        }

        return builer.toString()
    }

    public init(name: String, level: LogLevel, logTime: DateTime, message: String) {
        this.name = name
        this.level = level
        this.threadName = getThreadName()
        this.logTime = logTime
        this.message = message
    }

    public init(name: String, level: LogLevel, threadName: String, logTime: DateTime, message: String) {
        this.name = name
        this.level = level
        this.threadName = threadName
        this.logTime = logTime
        this.message = message
    }

    public init(name: String, level: LogLevel, logTime: DateTime, message: String, exception: Exception) {
        this.name = name
        this.level = level
        this.threadName = getThreadName()
        this.logTime = logTime
        this.message = message
        this.exception = exception
    }

    public init(
        name: String,
        level: LogLevel,
        threadName: String,
        logTime: DateTime,
        message: String,
        exception: Exception
    ) {
        this.name = name
        this.level = level
        this.threadName = threadName
        this.logTime = logTime
        this.message = message
        this.exception = exception
    }
}
