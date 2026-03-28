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
package f_time

public class TimeDuration {
    public TimeDuration(
        public let value: Int64,
        public let timeunit: TimeUnit
    ) {}
    public prop duration: Option<Duration> {
        get() {
            timeunit.duration(value)
        }
    }
    public prop ago: DateTime {
        get() {
            timeunit.ago(value)
        }
    }
    public prop later: DateTime {
        get() {
            timeunit.later(value)
        }
    }
    public func before(t: DateTime) {
        timeunit.before(t, value)
    }
    public func after(t: DateTime) {
        timeunit.after(t, value)
    }
}
