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
package f_ticktock

import std.collection.concurrent.ConcurrentHashMap
import f_collection.*

class DefaultTicktockTaskExecuting {
    private static var executingMap = ConcurrentHashMap<String, Int64>()

    static func executing(name: String, stamp: Int64): Bool {
        executingMap.addIfAbsent(name, stamp).isSome()
    }

    static func reset(name: String, stamp: Int64): Unit {
        executingMap.removeIf(name) {v => v == stamp}
    }
}
