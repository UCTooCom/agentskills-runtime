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
package f_ticktock

import std.sync.Timer
import f_base.ZERO_TIMER

class Chrono {
    private var timer: Timer = ZERO_TIMER
    init() {}
    func start(emitter: Emitter) {
        func next(now: DateTime, n: Int64) {
            DateTime.of(
                year: now.year,
                month: now.month,
                dayOfMonth: now.dayOfMonth,
                hour: now.hour,
                minute: now.minute,
                second: now.second
            ) + Duration.second * n - DateTime.now()
        }
        let now = DateTime.now()
        timer = Timer.after(next(now, 2)) {
            let now = DateTime.now()
            spawn {
                emitter.emit(now)
            }
            next(now, 1)
        }
    }
    func shutdown() {
        timer.cancel()
    }
}
