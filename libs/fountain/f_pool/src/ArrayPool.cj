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

public struct ArrayPool<T> {
    private let pool: Pool<Array<T>>
    public ArrayPool(
        initSize!: Int64 = 0, 
        minSize!: Int64 = 0, 
        maxSize!: Int64 = Int64.Max,
        elementLife!: Duration = Duration.Max, 
        checkInterval!: Duration = Duration.Zero,
        clearOnReturning!: Bool = false,
        private let arraySize!: Int64 = 128, 
        private let creator!: () -> T = {=> unsafe { zeroValue<T>() }}) {
        let initValue = creator()
        pool = Pool<Array<T>>(
            initSize: initSize,
            minSize: minSize,
            maxSize: maxSize,
            idleTimeout: elementLife,
            checkOnCreation: false,
            checkOnBorrowing: false,
            checkOnReturning: false,
            checkInterval: checkInterval,
            clearOnReturning: clearOnReturning,
            creator: {
                => Array<T>(arraySize) {_ => initValue}
            },
            checker: {_ => true},
            destroier: {_ =>},
            clear: {
                o => for (i in 0..o.size) {
                    o[i] = initValue
                }
            }
        )
    }
    public func borrow(timeout!: Duration = Duration.Max): ?Array<T> {
        pool.borrow(timeout: timeout)
    }
    public func giveBack(array: Array<T>): Bool {
        if (array.size == arraySize) {
            pool.giveBack(array)
            true
        } else {
            false
        }
    }
}
