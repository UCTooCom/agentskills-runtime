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
package f_random

import std.collection.ArrayList
import stdx.crypto.crypto.SecureRandom

public func randomReservoir<T>(count: Int64, source: Iterable<T>, priv!: Bool = false): ArrayList<T> {
    let rand = SecureRandom(priv: priv)
    var result = ArrayList<T>()
    var c = 0
    for (v in source) {
        if (c < count) {
            result.add(v)
        } else {
            let r = rand.nextInt64(c)
            if (r < count) {
                result[r] = v
            }
        }
        c++
    }
    return result
}
