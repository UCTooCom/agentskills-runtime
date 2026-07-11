/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq_client_unit_test

@Test
public class LRUCacheTest {
    @TestCase
    public func testReSize(): Unit {
        let lruCache = LRUCache<Int64, Int64>(1000)
        for (i in 0..276827) {
            if (!lruCache.contains(i)) {
                lruCache.add(i, i)
            }
        }
        @Assert(1000, lruCache.size)
    }

    @TestCase
    public func testEvict(): Unit {
        let lruCache = LRUCache<Int64, Int64>(2)
        lruCache.add(1, 1)
        lruCache.add(2, 2)
        lruCache.get(1)
        lruCache.add(3, 3)
        @Assert(Option<Int64>.None,lruCache.get(2))

        lruCache.add(4, 4)
        @Assert(Option<Int64>.None,lruCache.get(1))
        @Assert(Option<Int64>.Some(3),lruCache.get(3))
        @Assert(Option<Int64>.Some(4),lruCache.get(4))
    }

    @TestCase
    public func testRemove(): Unit {
        let lruCache = LRUCache<Int64, Int64>(2)
        lruCache.add(1, 1)
        lruCache.add(2, 2)
        lruCache.add(3, 3)
        lruCache.remove(3)
        @Assert(Option<Int64>.None,lruCache.get(3))
        @Assert(Option<Int64>.None,lruCache.get(1))
        @Assert(Option<Int64>.Some(2),lruCache.get(2))
        @Assert(1,lruCache.size)
    }

    @TestCase
    public func testClear(): Unit {
        let lruCache = LRUCache<Int64, Int64>(2)
        lruCache.add(1, 1)
        lruCache.add(2, 2)
        lruCache.clear()
        @Assert(Option<Int64>.None,lruCache.get(1))
        @Assert(Option<Int64>.None,lruCache.get(2))
        @Assert(0,lruCache.size)
    }

    @TestCase
    public func testRemoveIf(): Unit {
        let lruCache = LRUCache<Int64, Int64>(10)
        for (i in 0..20) {
            lruCache.add(i, i)
        }
        lruCache.removeIf({k: Int64, v: Int64 => return k > 9})
        @Assert(0,lruCache.size)
        @Assert(Option<Int64>.None,lruCache.get(8))
        @Assert(Option<Int64>.None,lruCache.get(15))
    }
}
