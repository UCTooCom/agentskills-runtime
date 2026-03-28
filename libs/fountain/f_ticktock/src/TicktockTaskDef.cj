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

public interface TicktockTaskDef <: ToString {
    /**
     * 是否只执行一次的任务，需要只执行一次的重写这个方法
     *
     * @return
     */
    prop once: Bool {
        get() {
            return false
        }
    }

    /**
     * 是否可以并发执行任务
     *
     * @return
     */
    prop concurrentable: Bool {
        get() {
            return false
        }
    }

    /**
     * 当前任务是否正在执行
     *
     * @return
     */
    func executing(stamp: Int64): Bool {
        return DefaultTicktockTaskExecuting.executing(name, stamp)
    }

    /**
     * 重置执行状态
     */
    func reset(stamp: Int64): Unit {
        DefaultTicktockTaskExecuting.reset(name, stamp)
    }

    /**
     * 必须确保在整个时间轮内所有任务拥有惟一的name，否则后加入的任务会覆盖前面加入的同名任务
     *
     * @return
     */
    prop name: String

    /**
     * 定时任务逻辑
     */
    func execute(): Unit

    func toString(): String {
        return this.name
    }
}
