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
package f_concurrent.eventbus

import std.sync.{AtomicUInt64, AtomicBool, AtomicInt64, AtomicReference}

/**
 * 如果一个业务流程有许多步，每一步可以定义成一个事件，把这些事件注册到concurrent.eventbus.EventBus
 */
public abstract class Event <: Hashable & Equatable<Event> & ToString {
    private static let ORDINAL_GEN = AtomicUInt64(1)
    public let ordinal = ORDINAL_GEN.fetchAdd(1)
    public prop name: String
    private var data = AtomicReference<Box<?Any>>(Box<?Any>(None<Any>))
    let arrangedThreadId_ = AtomicInt64(0)
    let workerId_ = AtomicInt64(-1)
    private var deliverResult_ = AtomicBool(true)

    mut prop arrangedThreadId: Int64 {
        get() {
            arrangedThreadId_.load()
        }
        set(value) {
            arrangedThreadId_.store(value)
        }
    }
    mut prop workerId: Int64 {
        get() {
            workerId_.load()
        }
        set(value) {
            workerId_.store(value)
        }
    }
    public mut prop deliverResult: Bool {
        get() {
            deliverResult_.load()
        }
        set(value) {
            deliverResult_.store(value)
        }
    }
    public func getData<T>(): ?T {
        match (data.load().value) {
            case Some(x) => x as T
            case _ => None<T>
        }
    }
    public func setData(value: Any) {
        data.store(Box<?Any>(Some(value)))
    }
    public func setNoneData() {
        if (let Some(_) <- data.load().value) {
            data.store(Box<?Any>(None<Any>))
        }
    }
    public open prop startEvent: Bool {
        get() {
            false
        }
    }
    public open func hashCode(): Int64 {
        name.hashCode()
    }
    public operator func ==(e: Event): Bool {
        refEq(this, e) || name == e.name
    }
    public func toString(): String {
        name
    }
}
