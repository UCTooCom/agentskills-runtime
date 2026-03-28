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

import std.sync.{ReadWriteLock, Lock}
import f_collection.LinkedHashMap

class SyncLinkedHashMap<V> <: Collection<(String, V)> {
    private let rwl = ReadWriteLock()
    private let rl = rwl.readLock
    private let wl = rwl.writeLock
    private let map = LinkedHashMap<String, V>()
    public func iterator(): Iterator<(String, V)> {
        SyncLinkedHashMapIterator<V>(map.iterator(), rl)
    }
    public func get(key: String): ?V {
        synchronized(rl) {
            map.get(key)
        }
    }
    public func contains(key: String): Bool {
        synchronized(rl) {
            map.contains(key)
        }
    }
    public func add(key: String, value: V): ?V {
        synchronized(wl) {
            map.add(key, value)
        }
    }
    public func computeIfAbsent(key: String, callable: () -> V): V {
        if (let Some(v) <- get(key)) {
            v
        } else {
            synchronized(wl) {
                if (let Some(v) <- map.get(key)) {
                    v
                } else {
                    let v = callable()
                    map.add(key, v)
                    v
                }
            }
        }
    }
    public func remove(key: String): ?V {
        synchronized(wl) {
            map.remove(key)
        }
    }
    func removeIf(predicate: (String, V) -> Bool): Unit {
        synchronized(wl){
            map.removeIf(predicate)
        }
    }
    public prop size: Int64 {
        get() {
            synchronized(rl) {
                map.size
            }
        }
    }
    public func isEmpty(): Bool {
        synchronized(rl) {
            map.isEmpty()
        }
    }
    public func clear(): Unit {
        synchronized(wl) {
            map.clear()
        }
    }
}

class SyncLinkedHashMapIterator<V> <: Iterator<(String, V)> {
    SyncLinkedHashMapIterator(private let itr: Iterator<(String, V)>, private let rl: Lock) {}
    public func next(): ?(String, V) {
        synchronized(rl) {
            itr.next()
        }
    }
}
