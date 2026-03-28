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

import std.collection.HashSet
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class RandomString_test {
    private let randStr = RandomString()
    private let rand = Random()
    @TestCase
    public func test0(): Unit {
        for (i in 0..10_000) {
            var r = randStr.randomAscii(1)
            @Assert(r.size, 1)
            let ch = UInt8(UInt32(r[0]))
            @Assert(ch >= 0 && ch <= 127 )
            let len = rand.nextInt64(11)
            r = randStr.randomAscii(len)
            @Assert(r.size, len)
        }
    }
    @TestCase
    public func test1(): Unit {
        let source = "1a,;kpzxcqp081341;k.xz,".toRuneArray()
        let set = HashSet<Rune>(source)
        for (i in 0..10_000) {
            var r = randStr.random(1, source).toRuneArray()
            @Assert(r.size, 1)
            let ch = r[0]
            @Assert(set.contains(ch))
            let len = rand.nextInt64(11)
            r = randStr.random(len, source).toRuneArray()
            @Assert(r.size, len)
        }
    }
    @TestCase
    public func test2(): Unit {
        for (i in 0..10_000) {
            var r = randStr.randomLowerLetters(1).toRuneArray()
            @Assert(r.size, 1)
            let ch = r[0]
            @Assert(ch>=r'a' && ch<=r'z')
            let len = rand.nextInt64(11)
            r = randStr.randomLowerLetters(len).toRuneArray()
            @Assert(r.size, len)
        }
    }
    @TestCase
    public func test3(): Unit {
        for (i in 0..10_000) {
            var r = randStr.randomUpperLetters(1).toRuneArray()
            @Assert(r.size, 1)
            let ch = r[0]
            @Assert(ch>=r'A' && ch<=r'Z')
            let len = rand.nextInt64(11)
            r = randStr.randomUpperLetters(len).toRuneArray()
            @Assert(r.size, len)
        }
    }
    @TestCase
    public func test4(): Unit {
        for (i in 0..10_0000) {
            var r = randStr.randomAllLetters(1).toRuneArray()
            @Assert(r.size, 1)
            let ch = r[0]
            @Assert((ch>=r'a' && ch<=r'z') || (ch>=r'A' && ch<=r'Z'))
            let len = rand.nextInt64(11)
            r = randStr.randomAllLetters(len).toRuneArray()
            @Assert(r.size, len)
        }
    }
    @TestCase
    public func test5(): Unit {
        for (i in 0..10_0000) {
            var r = randStr.randomNumbers(1).toRuneArray()
            @Assert(r.size, 1)
            let ch = r[0]
            @Assert(ch>=r'0' && ch<=r'9')
            let len = rand.nextInt64(11)
            r = randStr.randomNumbers(len).toRuneArray()
            @Assert(r.size, len)
        }
    }
}
