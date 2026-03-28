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
package f_base

import std.sync.Mutex

public interface OverSizePolicy<T> {
    /**
       o 是待添加的新值，
       fn是执行策略以后要执行的函数，比如执行策略以后又可以添加新值了就可以在fn内包含添加新值的逻辑
     */
    func reject(o: T, fn: () -> Unit): Unit
}

public class AbortOverSizePolicy<T> <: OverSizePolicy<T> {
    public AbortOverSizePolicy(private let max: Int64) {}
    public func reject(o: T, fn: () -> Unit): Unit {
        throw OverSizeException("max size is ${max}")
    }
}

public class DiscardOverSizePolicy<T> <: OverSizePolicy<T> {
    public func reject(o: T, fn: () -> Unit): Unit {}
}

public class RemoveSomeOnePolicy<T> <: OverSizePolicy<T> {
    public RemoveSomeOnePolicy(private let remove: (T) -> Unit) {}
    public func reject(o: T, fn: () -> Unit): Unit {
        remove(o)
        fn()
    }
}

public class CallerRunsOverSizePolicy<T> <: OverSizePolicy<T> {
    public func reject(o: T, fn: () -> Unit): Unit {
        fn()
    }
}

public class BlockingOverSizePolicy<T> <: OverSizePolicy<T> {
    private let monitor = Mutex()
    private let condition = synchronized(monitor) {
        monitor.condition()
    }
    public BlockingOverSizePolicy(
        private let recovered: (T) -> Bool,
        private let timeout!: Duration = Duration.Max,
        private let policy!: OverSizePolicy<T> = DiscardOverSizePolicy<T>()
    ) {}
    public func reject(o: T, fn: () -> Unit): Unit {
        synchronized(monitor) {
            condition.wait(timeout: timeout)
        }
        if (recovered(o)) {
            policy.reject(o, fn)
        }
    }
    public func notifyAll() {
        synchronized(monitor) {
            condition.notifyAll()
        }
    }
    public func notify() {
        synchronized(monitor) {
            condition.notify()
        }
    }
}
