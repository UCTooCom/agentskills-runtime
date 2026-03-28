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

import std.collection.HashMap
import std.collection.concurrent.LinkedBlockingQueue
import std.env.atExit
import std.time.DateTime
import std.sync.{Timer, AtomicBool}
import f_base.*
import f_collection.PriorityQueue

public class HeapCache<V> where V <: Object {
    private let store: ConcHashMap<Priority<V>>
    private let alive = AtomicBool(true)

    public HeapCache(
        private let concurrencyLevel!: Int64 = DEFAULT_HEAP_CACHE_CONCURRENCY_LEVEL,
        private let maxLife!: Duration = DEFAULT_HEAP_CACHE_MAX_LIFE,
        private let maxSize!: Int64 = DEFAULT_HEAP_CACHE_MAX_SIZE,
        private let checkDuration!: Duration = DEFAULT_HEAP_CHECK_CHECK_DURATION,
        private let evictionCallback!: (String, V) -> Unit = {_, _ => ()}
    ) {
        if (maxLife < Duration.Zero || maxSize <= 0 || concurrencyLevel <= 0 || checkDuration <= Duration.Zero) {
            throw IllegalArgumentException(
                "maxLife must not be less than zero. maxSize and concurrencyLevel must be greater than zero. checkDuration must be greater than Duration.Zero. however current are ${maxLife}, ${maxSize}, ${concurrencyLevel}, ${checkDuration}")
        }
        this.store = ConcHashMap<Priority<V>>.create(concurrencyLevel: concurrencyLevel)
        startTimer()
        atExit(destroy)
    }

    public static func builder(): HeapCacheBuilder<V> {
        return HeapCacheBuilder<V>()
    }
    private func onEviction(): LinkedBlockingQueue<(String, V)> {
        let q = LinkedBlockingQueue<(String, V)>()
        spawn {
            while (let (k, v) <- q.remove()) {
                evictionCallback(k, v)
            }
        }
        q
    }
    private func startTimer() {
        let topVals = PriorityQueue<Priority<V>>.create<Priority<V>>(capacity: concurrencyLevel)
        let tops = HashMap<String, Priority<V>>()
        let q = onEviction()
        Timer.after(checkDuration) {
            let iterator = (store.iterator() as ConcHashMapIterator<Priority<V>>).getOrThrow()
            checkTimeout(q)
            checkOverSize(topVals, tops, iterator, q)
            if (alive.load()) {
                checkDuration
            } else {
                None<Duration>
            }
        }
    }
    private func checkTimeout(evictionQueue: LinkedBlockingQueue<(String, V)>): Unit {
        removeIf {
            k, p => if (alive.load()) {
                if (evicated(p)) {
                    evictionQueue.add((k, p.load()))
                    true
                } else {
                    false
                }
            } else {
                return true
            }
        }
    }
    private func checkOverSize(
        topVals: PriorityQueue<Priority<V>>,
        tops: HashMap<String, Priority<V>>,
        iterator: ConcHashMapIterator<Priority<V>>,
        evictionQueue: LinkedBlockingQueue<(String, V)>
    ): Unit {
        let store = this.store
        let maxSize = this.maxSize
        let current = DateTime.now()
        while (store.size > maxSize && alive.load()) {
            let segmItrs = iterator.segmentIterators()
            var segmItrMap = HashMap<Int64, Iterator<(String, Priority<V>)>>()
            var i = 0
            for (segmItr in segmItrs where alive.load()) {
                if (let Some((k, p)) <- segmItr.next()) {
                    segmItrMap[i] = segmItr
                    p.index = i
                    topVals.add(p)
                }
                i++
            }
            while (store.size > maxSize && alive.load()) {
                var minIdx = -1
                if (let Some(p) <- topVals.remove()) {
                    store.remove(p.key)
                    minIdx = p.index
                    evictionQueue.add((p.key, p.load()))
                }
                if (minIdx < 0 || store.size <= maxSize) {
                    break
                } else if (let Some(segm) <- segmItrMap.get(minIdx) && let Some(next) <- segm.next()) {
                    next[1].index = minIdx
                    topVals.add(next[1])
                }
            }
            while (let Some(p) <- topVals.remove() && alive.load()) {
                tops.add(p.key, p)
            }
        }
        for (p in tops.values() where alive.load()) { //不给Priority增加已删除标记，此处也不判断Priority是不是已被主动删除，因为这样做不节省时间
            p.updateLastChecked(current)
        }
        tops.clear()
    }
    private func evicated(p: Priority<V>): Bool {
        DateTime.now() >= p.deathTime
    }

    public func get(key: String): Option<V> {
        match (store.get(key)) {
            case Some(p) where !evicated(p) => p.load()
            case _ => None<V>
        }
    }
    public func contains(key: String): Bool {
        get(key).isSome()
    }
    public func once(key: String): Bool {
        match (store.get(key)) {
            case Some(p) => synchronized(p.lock) {
                p.load()
                p.once = true
                true
            }
            case _ => false
        }
    }
    public func prolong(key: String, life: Duration, once!: Bool = false): Bool {
        match (store.get(key)) {
            case Some(p) => synchronized(p.lock) {
                p.load()
                p.maxLife = life
                p.once = once
                true
            }
            case _ => false
        }
    }
    public func prolong(key: String, deathTime: DateTime): Bool {
        match (store.get(key)) {
            case Some(p) => synchronized(p.lock) {
                p.load()
                p.deathTime = deathTime
                p.once = true
                true
            }
            case _ => false
        }
    }
    public func set(key: String, value: V, life!: Duration = this.maxLife, once!: Bool = false): ?V {
        if (let Some(p) <- store.get(key)) {
            synchronized(p.lock) {
                let old = p.load()
                p.store(value)
                p.maxLife = life
                p.once = once
                old
            }
        } else {
            store.add(key, Priority<V>(key, value, maxLife, checkDuration, once))
            Option<V>.None
        }
    }
    public func set(key: String, value: V, dieAt: DateTime): ?V {
        set(key, value, life: dieAt - DateTime.now(), once: true)
    }
    public func getOrDefault(key: String, default: V): V {
        return get(key) ?? default
    }
    public func getOrStore(key: String, value: V): V {
        getOrCompute(key) {value}
    }
    public func getOrCompute(key: String, callable: () -> V): V {
        getOrCompute(key) {
            (callable(), this.maxLife, false)
        }
    }
    public func getOrCompute(key: String, callable: () -> (V, DateTime)): V {
        store.computeIfAbsent(key) {
            let data = callable()
            Priority<V>(key, data[0], data[1] - DateTime.now(), checkDuration, true)
        }.load()
    }
    public func getOrCompute(key: String, callable: () -> (V, Duration, Bool)): V {
        store.computeIfAbsent(key) {
            let data = callable()
            Priority<V>(key, data[0], data[1], checkDuration, data[2])
        }.load()
    }
    public func remove(key: String): Option<V> {
        store.remove(key)?.load()
    }
    public func removeIf(predicate: (String, V) -> Bool): Unit {
        removeIf {k: String, p: Priority<V> => predicate(k, p.load())}
    }
    private func removeIf(predicate: (String, Priority<V>) -> Bool): Unit {
        store.removeIf(predicate)
    }
    public prop size: Int64 {
        get() {
            store.size
        }
    }
    public func clear() {
        store.clear()
    }
    public func destroy(): Unit {
        alive.store(false)
        store.clear()
    }
}
