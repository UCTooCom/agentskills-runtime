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
package f_concurrent

public class BloomFilter<T> where T <: Hashable {
    private let lock = ReadWriteLock()
    private let wl = lock.writeLock
    private let rl = lock.readLock
    private let bits = BitSet()
    public BloomFilter(private let hashers: Array<(T, Int64) -> Int64>) {}
    public init(iterate!: Int64 = 5) {
        this(genHashers(iterate))
    }
    public init(hashers: Array<(T) -> Int64>) {
        this(Array<(T, Int64) -> Int64>(hashers.size) {
            i => {
                v: T, _: Int64 => hashers[i](v)
            }
        })
    }
    private static func genHashers(iterate: Int64): Array<(T, Int64) -> Int64> {
        @OverflowWrapping
        func hash(v: T, h: Int64) {
            h * 131 + v.hashCode()
        }
        Array<(T, Int64) -> Int64>(iterate, repeat: hash)
    }
    public func set(value: T): Unit {
        var h = value.hashCode()
        synchronized(wl) {
            bits[h] = true
            for (hasher in hashers) {
                h = hasher(value, h)
                bits[h] = true
            }
        }
    }
    public func contains(value: T): Bool {
        var h = value.hashCode()
        synchronized(rl) {
            var result = bits[h]
            if (result) {
                var i = 0
                while (result && i < hashers.size) {
                    h = hashers[i](value, h)
                    result &&= bits[h]
                    i++
                }
            }
            result
        }
    }
}
