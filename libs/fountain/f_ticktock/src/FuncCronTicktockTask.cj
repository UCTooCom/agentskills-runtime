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

public class FuncCronTicktockTask <: CronTicktockTask {
    public FuncCronTicktockTask(
        private let taskName!: String,
        private let taskCron!: String,
        private let execOnce!: Bool = false,
        private let concurrenctly!: Bool = false,
        private let executor!: () -> Unit,
        private let isExecuting!: (Int64) -> Bool = {stamp => DefaultTicktockTaskExecuting.executing(taskName, stamp)},
        private let toReset!: (Int64) -> Unit = {stamp => DefaultTicktockTaskExecuting.reset(taskName, stamp)}
    ) {}
    public prop name: String {
        get() {
            taskName
        }
    }
    public prop cron: String {
        get() {
            taskCron
        }
    }
    public func execute(): Unit {
        executor()
    }
    public prop once: Bool {
        get() {
            execOnce
        }
    }
    public prop concurrentable: Bool {
        get() {
            concurrenctly
        }
    }
    public func executing(stamp: Int64): Bool {
        return isExecuting(stamp)
    }

    public func reset(stamp: Int64): Unit {
        toReset(stamp)
    }
}
