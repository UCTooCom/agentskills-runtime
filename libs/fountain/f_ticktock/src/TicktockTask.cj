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

import std.reflect.ClassTypeInfo
import std.sync.AtomicInt64

public abstract class TicktockTask <: TicktockTaskDef & Hashable & Equatable<TicktockTaskDef> & Equatable<String> {
    internal let stamped = AtomicInt64(0)
    /**
     * 不需要覆盖本方法，任务逻辑都在void execute()方法实现，
     * 控制逻辑都在concurrentable: Bool executing(boolean): Bool 和  once(): Bool
     */
    protected open func run(): Unit {
        let currentStamp = stamped.fetchAdd(1) + 1
        if (!executing(currentStamp) || (concurrentable && !this.once)) {
            try {
                execute()
            } finally {
                reset(currentStamp)
            }
        }
    }
    public func hashCode(): Int64 {
        return name.hashCode()
    }
    public operator func ==(task: TicktockTaskDef): Bool {
        match(task){
            case x: Object => refEq(this, x)
            case _ => false
        } || return this.name == task.name
    }
    public operator func !=(task: TicktockTaskDef): Bool {
        return this.name != task.name
    }
    public operator func ==(name: String): Bool {
        return this.name == name
    }
    public operator func !=(name: String): Bool {
        return this.name != name
    }

    public open prop once: Bool {
        get() {
            false
        }
    }

    public open prop concurrentable: Bool {
        get() {
            false
        }
    }
    public open prop name: String {
        get() {
            ClassTypeInfo.of(this).qualifiedName
        }
    }

    /**
     * 当前任务是否正在执行
     *
     * @return
     */
    public open func executing(stamp: Int64): Bool {
        return DefaultTicktockTaskExecuting.executing(name, stamp)
    }

    /**
     * 重置执行状态
     */
    public open func reset(stamp: Int64): Unit {
        DefaultTicktockTaskExecuting.reset(name, stamp)
    }
}

public abstract class CronTicktockTask <: TicktockTask & CronTicktockTaskDef {}
