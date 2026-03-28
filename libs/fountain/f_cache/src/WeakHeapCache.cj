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

import std.collection.concurrent.ConcurrentHashMap
import std.ref.*
import f_collection.*

private struct WeakKey <: Hashable & Equatable<WeakKey> {
    private let key: WeakRef<Box<String>>
    private init(key: String, policy: CleanupPolicy){
        this.key = WeakRef<Box<String>>(Box<String>(key), policy)
    }
    static func deferred(key: String){
        WeakKey(key, DEFERRED)
    }
    public func hashCode(): Int64 {
        key.value?.hashCode() ?? 0
    }
    public operator func ==(other: WeakKey){
        match((key.value, other.key.value)){
            case (Some(x), Some(y)) => x.value == y.value
            case _ => false
        }
    }
    func isNone(){
        key.value.isNone()
    }
    func getKey(): ?String {
        key.value?.value
    }
}
public class WeakHeapCache<T> where T <: Object {
    private let cache = ConcurrentHashMap<WeakKey, WeakRef<T>>()
    public init() {
        spawn {
            while (true) {
                cache.removeIf{k, v => k.isNone() || v.value.isNone()}
                sleep(Duration.second)
            }
        }
    }
    private func weakRef(value: T) {
        WeakRef(value, DEFERRED)
    }
    public func set(key: String, value: T): ?T {
        try {
            if (let Some(r) <- cache.get(WeakKey.deferred(key)) && let Some(v) <- r.value) {
                return v
            }
            None<T>
        } finally {
            cache[WeakKey.deferred(key)] = weakRef(value)
        }
    }
    public func getOrCompute(key: String, fn: () -> ?T): ?T {
        cache.entryView(WeakKey.deferred(key)) {
            entry => if (let Some(r) <- entry.value && let Some(v) <- r.value) {
            } else {
                entry.value = if (let Some(v) <- fn()) {
                    weakRef(v)
                } else {
                    None
                }
            }
        }?.value ?? None<T>
    }
    public func get(key: String): ?T {
        cache.entryView(WeakKey.deferred(key)){view => 
            if(let Some(r) <- view.value && let Some(v) <- r.value){
                r
            }else{
                None<WeakRef<T>>
            }
        }?.value ?? None
    }
    public func getOrDefault(key: String, default: T): T {
        get(key) ?? default
    }
    public func getOrStore(key: String, value: T): T {
        getOrCompute(key) {value} ?? value
    }
    public func remove(key: String): ?T {
        cache.remove(WeakKey.deferred(key))?.value ?? None<T>
    }
    public func removeIf(predicate: (String, T) -> Bool): Unit {
        cache.removeIf {
            k, r => if (let (Some(k), Some(v)) <- (k.getKey(), r.value)) {
                predicate(k, v)
            } else {
                true
            }
        }
    }
    public prop size: Int64 {
        get() {
            cache.size
        }
    }
    public func clear(): Unit {
        cache.removeIf {_, _ => true}
    }
}
