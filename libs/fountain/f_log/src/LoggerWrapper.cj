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

import std.env
import std.sync.AtomicReference
import std.time.DateTime
import stdx.log.{LogLevel, LogRecord}
import f_io.DummyOutputStream

public class LoggerWrapper <: AbstractLogger {
    private var facade: AtomicReference<LoggerAppenderFacade>

    public LoggerWrapper(name: String) {
        super(name, LogLevel.ALL, LogPattern.default, DummyOutputStream.THROW_ON_ACCESSING, name)
        this.facade = AtomicReference<LoggerAppenderFacade>(LoggerConfig.createFacade(name))
        env.atExit {this.facade.load().close()}
    }
    public func logLevelEnabled(level: LogLevel): Bool {
        facade.load().logLevelEnabled(level)
    }

    public open func log(record: LogRecord): Unit {
        facade.load().log(record)
    }
    protected func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        facade.load().append(level, message, now, tid, ex)
    }
    public func refresh() {
        var replaced = false
        while (!replaced) {
            try {
                let (facade, replaced_) = super.doLock {
                    let new = LoggerConfig.createFacade(name)
                    let old = this.facade.load()
                    if (this.facade.compareAndSwap(old, new)) {
                        (old, true)
                    } else {
                        (new, true)
                    }
                }
                replaced = replaced_
                facade.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
