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

public let DEFAULT_HEAP_CACHE_MAX_LIFE = Duration.second * 5
public let DEFAULT_HEAP_CACHE_MAX_SIZE = Int64.Max
public let DEFAULT_HEAP_CACHE_CONCURRENCY_LEVEL = 128
public let DEFAULT_HEAP_CHECK_CHECK_DURATION = Duration.second

public open class HeapCacheBuilder<V> where V <: Object {
    private var maxLife = DEFAULT_HEAP_CACHE_MAX_LIFE
    private var concurrencyLevel = DEFAULT_HEAP_CACHE_CONCURRENCY_LEVEL
    private var maxSize = DEFAULT_HEAP_CACHE_MAX_SIZE
    private var checkDuration = DEFAULT_HEAP_CHECK_CHECK_DURATION
    private var evictionCallback: (String, V) -> Unit = {_, _ => ()}

    public func setMaxLife(maxLife: Duration): HeapCacheBuilder<V> {
        if (maxLife < Duration.Zero) {
            throw IllegalArgumentException("maxLife must not be less than zero. however current is ${maxLife}")
        }
        this.maxLife = maxLife
        return this
    }
    public func setConcurrencyLevel(concurrencyLevel: Int64): HeapCacheBuilder<V> {
        if (concurrencyLevel <= 0) {
            throw IllegalArgumentException(
                "concurrencyLevel must be greater than zero. however current is ${concurrencyLevel}")
        }
        this.concurrencyLevel = concurrencyLevel
        return this
    }
    public func setMaxSize(maxSize: Int64): HeapCacheBuilder<V> {
        if (maxSize <= 0) {
            throw IllegalArgumentException("maxSize must be greater than zero. however current is ${maxSize}")
        }
        this.maxSize = maxSize
        this
    }
    public func setEvictionCallback(callback: (String, V) -> Unit): HeapCacheBuilder<V> {
        this.evictionCallback = callback
        this
    }
    public func setCheckDuration(checkDuration: Duration): HeapCacheBuilder<V> {
        if (checkDuration <= Duration.Zero) {
            throw IllegalArgumentException("checkDuration must be greater Duration.Zero")
        }
        this.checkDuration = checkDuration
        this
    }
    public open func build(): HeapCache<V> {
        return HeapCache<V>(concurrencyLevel: concurrencyLevel, maxLife: maxLife, maxSize: maxSize,
            checkDuration: checkDuration, evictionCallback: evictionCallback)
    }
}
