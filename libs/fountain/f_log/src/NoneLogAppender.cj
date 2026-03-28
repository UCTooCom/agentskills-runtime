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
import stdx.log.LogLevel
import f_io.DummyOutputStream

public class NoneLogAppender <: AbstractLogger {
    public static let instance = NoneLogAppender()
    private init() {
        super("", LogLevel.OFF, LogPattern.default, DummyOutputStream.THROW_ON_ACCESSING, '')
    }

    public static func register(): Unit {
        LoggerAppenderCreator.register("none") {
            _ => [instance]
        }
    }
    protected func append(_: LogLevel, _: String, _: DateTime, _: Option<Exception>): Unit {
        //do nothing
    }
    public mut prop closable: Bool {
        get() {
            false
        }
        set(value){}
    }
}
