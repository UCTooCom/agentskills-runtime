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
package f_jwt

import std.time.DateTime
import f_cache.*

public interface JwtIdCache<T> where T <: Equatable<T> {
    func put(id: T, expire: Duration): Unit
    func put(id: T, expireAt: DateTime): Unit
    func contains(id: T): Bool
    func remove(id: T): Bool
}

public class NoneJwtIdCache<T> <: JwtIdCache<T> where T <: Equatable<T> {
    public func put(id: T, expire: Duration): Unit {}
    public func put(id: T, expireAt: DateTime): Unit {}
    public func contains(id: T): Bool {
        false
    }
    public func remove(id: T): Bool {
        false
    }
}

public class HeapJwtIdCache<T> <: JwtIdCache<T> where T <: ToString & Equatable<T> { 
    private let cache: HeapCache<HeapJwtIdCache<T>>

    public init(
        concurrencyLevel!: Int64 = DEFAULT_HEAP_CACHE_CONCURRENCY_LEVEL,
        maxLife!: Duration = DEFAULT_HEAP_CACHE_MAX_LIFE,
        maxSize!: Int64 = DEFAULT_HEAP_CACHE_MAX_SIZE,
        checkDuration!: Duration = DEFAULT_HEAP_CHECK_CHECK_DURATION,
        evictionCallback!: (String, HeapJwtIdCache<T>) -> Unit = {_, _ => ()}
    ){
        cache = HeapCache<HeapJwtIdCache<T>>(
            concurrencyLevel: concurrencyLevel,
            maxLife: maxLife,
            maxSize: maxSize,
            checkDuration: checkDuration,
            evictionCallback: evictionCallback
        )
    }

    public func put(id: T, expire: Duration): Unit {
        cache.set(id.toString(), this, life: expire)
    }
    public func put(id: T, expireAt: DateTime): Unit {
        cache.set(id.toString(), this, expireAt)
    }
    public func contains(id: T): Bool {
        cache.contains(id.toString())
    }
    public func remove(id: T): Bool {
        cache.remove(id.toString()).isSome()
    }
} 