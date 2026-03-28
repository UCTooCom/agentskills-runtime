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

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HeapCache_test {
    @TestCase
    public func test(): Unit {
        let cache = HeapCache<Test>(maxSize: 2)
        cache.set("test1", Test())
        sleep(Duration.second)
        cache.set("test2", Test())
        @Assert(cache.get("test1").isSome())
        @Assert(cache.get("test1").isSome())
        @Assert(cache.get('test1')?.value, cache.get('test1')?.value)
        @Assert(cache.getOrDefault("test99999999", Test(8888888)).value, 8888888)
        cache.set("test3", Test())
        sleep(2 * Duration.second)
        @Assert(!cache.contains("test2"))
        @Assert(cache.contains("test1"))
        @Assert(cache.contains("test3"))
        sleep(5 * Duration.second)
        @Assert(!cache.contains("test1"))
        @Assert(!cache.contains("test3"))
    }
}

public class Test <: ToString {
    private static var serial = 0
    public let value: Int64
    public init() {
        serial++
        value = serial
    }
    public init(val: Int64) {
        this.value = val
    }
    public func toString(): String {
        "Test(${value})"
    }
}
