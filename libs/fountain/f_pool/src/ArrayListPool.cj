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
package f_pool

public import std.collection.ArrayList

public struct ArrayListPool<T> {
    private let pool: Pool<ArrayList<T>>
    public ArrayListPool(
        initSize!: Int64 = 0, 
        minSize!: Int64 = 0, 
        maxSize!: Int64 = Int64.Max,
        elementLife!: Duration = Duration.Max, 
        checkInterval!: Duration = Duration.Zero,
        clearOnReturning!: Bool = false) {
        pool = Pool<ArrayList<T>>(
            initSize: initSize,
            minSize: minSize,
            maxSize: maxSize,
            idleTimeout: elementLife,
            checkOnCreation: false,
            checkOnBorrowing: false,
            checkOnReturning: false,
            checkInterval: checkInterval,
            clearOnReturning: clearOnReturning,
            checker: {_ => true},
            creator: {=> ArrayList<T>()},
            clear: {o => o.clear()},
            destroier: {_ =>}
        )
    }
    public func borrow(timeout!: Duration = Duration.Max): ?ArrayList<T> {
        pool.borrow(timeout: timeout)
    }
    public func giveBack(list: ArrayList<T>): Unit {
        pool.giveBack(list)
    }
}
