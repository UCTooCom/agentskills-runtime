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
package f_cache

import std.sync.{AtomicInt64, AtomicBool, AtomicReference, Mutex}
import std.time.DateTime

/*
    maxLife: 超时时间
    once: true 从birth开始计算超时时间，false 从最后访问时间开始算超时时间
    lastUsedTime: 最后使用时间
    ref: 访问次数
 */
public open class Priority<V> <: Comparable<Priority<V>> where V <: Object {
    let lock = Mutex()
    var index = -1
    private let ref = AtomicInt64(1) //缓存数据的使用次数
    private let birth = DateTime.now() //缓存数据的创建时间
    private var lastChecked = birth //缓存数据的最后使用时间
    private var usedUtilLastChecked = ref.load() //缓存数据截至上次检查时间的使用次数
    private var lastUsed = birth //缓存数据上次使用时间
    private var maxLife_: Duration //缓存数据的最大生存期，每条数据的生存期可以不同
    private let checkDuration: Duration
    private let once_ = AtomicBool(false) //控制缓存数据的生存时间，true从出生开始算，false从上次使用时间开始算
    let key: String
    private let value: AtomicReference<V>

    protected init(key: String, value: V, maxLife: Duration, checkDuration: Duration, once: Bool) {
        this.key = key
        this.value = AtomicReference<V>(value)
        this.maxLife_ = maxLife
        this.checkDuration = checkDuration
        this.once_.store(once)
    }
    public open func compare(other: Priority<V>): Ordering {
        let lastUsed = this.lastUsedTime
        let otherLastUsed = other.lastUsedTime
        func cmp(): Ordering {
            let duration = (lastUsed - lastCheckedTime)
            let otherDuration = (otherLastUsed - other.lastCheckedTime)

            var ordering: Ordering = (usedCount - usedCountUtilLastChecked).compare(
                other.usedCount - other.usedCountUtilLastChecked)
            ordering = match (ordering) {
                case EQ => otherDuration.compare(duration)
                case _ => return ordering
            }
            ordering = match (ordering) {
                case EQ => otherLastUsed.compare(lastUsed)
                case _ => return ordering
            }
            ordering = match (ordering) {
                case EQ => other.ref.load().compare(this.ref.load())
                case _ => ordering
            }
            match (ordering) {
                case EQ => this.birth.compare(other.birth)
                case _ => ordering
            }
        }
        let age = this.age
        let otherAge = other.age
        let ageSub = age - otherAge
        //参与比较的都是在数据段头的，
        //在数据段头同时最后访问时间还在最近一个生命周期之内，要么是整个数据段都是刚刚出生，要么是整个数据段使用都很频繁
        if (ageSub >= -1.0 && ageSub <= 1.0) {
            cmp() //两个待比较数据都在最近一个生命周期内刚访问过
        } else if (ageSub > 1.0) { //两个待比较数据的最后访问时间距今的时间差超过一个生命周期，保护新生
            GT
        } else if (age < -1.0) {
            LT
        } else { //两个待比较数据的最后访问时间距今都超过了一个生命周期，成年了不需要保护了
            cmp()
        }
    }
    protected prop age: Float64 {
        get() {
            synchronized(lock) {
                (DateTime.now() - if (once_.load()) {
                    birth
                } else {
                    lastUsed
                }) / checkDuration
            }
        }
    }
    protected mut prop maxLife: Duration {
        get() {
            synchronized(lock) {
                maxLife_
            }
        }
        set(value) {
            synchronized(lock) {
                maxLife_ = value
            }
        }
    }
    protected mut prop once: Bool {
        get() {
            once_.load()
        }
        set(value) {
            once_.store(value)
        }
    }
    protected prop lastUsedTime: DateTime {
        get() {
            synchronized(lock) {
                lastUsed
            }
        }
    }
    protected prop lastCheckedTime: DateTime {
        get() {
            lastChecked
        }
    }
    protected prop usedCount: Int64 {
        get() {
            ref.load()
        }
    }
    protected prop usedCountUtilLastChecked: Int64 {
        get() {
            usedUtilLastChecked
        }
    }
    protected prop birthTime: DateTime {
        get() {
            birth
        }
    }
    protected mut prop deathTime: DateTime {
        get() {
            synchronized(lock) {
                if (once) {
                    birth + maxLife_
                } else {
                    lastUsed + maxLife_
                }
            }
        }
        set(value) {
            synchronized(lock) {
                if (once) {
                    maxLife_ = value - birth
                } else {
                    maxLife_ = value - lastUsed
                }
            }
        }
    }
    protected func updateLastChecked(current: DateTime) {
        lastChecked = current
        usedUtilLastChecked = ref.load()
    }
    protected open func incr() {
        ref.fetchAdd(1)
        lastUsed = DateTime.now()
    }
    protected func load(): V {
        synchronized(lock) {
            incr()
            return value.load()
        }
    }
    protected func store(value: V) {
        synchronized(lock) {
            this.value.store(value)
            incr()
        }
    }
}
