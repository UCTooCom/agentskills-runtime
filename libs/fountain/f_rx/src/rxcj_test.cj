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
package f_rx

import std.collection.*
import std.sync.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class RxcjTest{
    private let mutex = Mutex()
    @TestCase
    public func testFutureIterableAndImmediately(): Unit {
        let i = AtomicInt64(1)
        Observable<Int64>.iterable({=> spawn{[1,2,3]}})
        .subscribe(FuncObserver<Int64>('testFutureIterableAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(i.load(), v)
                i.fetchAdd(1)
                println(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testFutureIterableAndImmediately")
            }
        }).immediately()
    }
    @TestCase
    public func testFutureIterableAndDefer(): Unit {
        let i = AtomicInt64(2)
        Observable<Int64>.iterable({=> spawn{[2,4,6]}})
        .subscribe(FuncObserver<Int64>('testFutureIterableAndDefer').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(i.load(), v)
                i.fetchAdd(2)
                println(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testFutureIterableAndDefer")
            }
        }).defer()
    }
    @TestCase
    public func testIterableAndDefer(): Unit {
        let i = AtomicInt64(1)
        Observable<Int64>.iterable({=> spawn{[1,3,5]}})
        .subscribe(FuncObserver<Int64>('testIterableAndDefer').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(i.load(), v)
                i.fetchAdd(2)
                println(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testIterableAndDefer")
            }
        }).defer()
    }
    @TestCase
    public func testIterableAndImmediately(): Unit {
        let i = AtomicInt64(11)
        Observable<Int64>.iterable({=> spawn{[11,13,15]}})
        .subscribe(FuncObserver<Int64>('testIterableAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(i.load(), v)
                i.fetchAdd(2)
                println(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testIterableAndImmediately")
            }
        }).immediately()
    }
    @TestCase
    public func testEmptyAndImmediately(): Unit {
        Observable<Int64>.empty()
        .subscribe(FuncObserver<Int64>('testEmptyAndImmediately').setNext{v: Int64 => 
            throw Exception('unreachable')
        }.setComplete{
            synchronized(mutex){
                println("complete testEmptyAndImmediately")
            }
        }).immediately()
    }
    @TestCase
    public func testEmptyAndDefer(): Unit {
        Observable<Int64>.empty()
        .subscribe(FuncObserver<Int64>('testEmptyAndDefer').setNext{v: Int64 => 
            throw Exception('unreachable')
        }.setComplete{
            synchronized(mutex){
                println("complete testEmptyAndDefer")
            }
        }).defer()
    }
    @TestCase
    public func testSingleAndDefer(): Unit {
        Observable<Int64>.single(100)
        .subscribe(FuncObserver<Int64>('testSingleAndDefer').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(100, v)
                println(100)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testSingleAndDefer")
            }
        }).defer()
    }
    @TestCase
    public func testSingleAndImmediately(): Unit {
        Observable<Int64>.single(101)
        .subscribe(FuncObserver<Int64>('testSingleAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(101, v)
                println(101)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testSingleAndImmediately")
            }
        }).immediately()
    }
    @TestCase
    public func testMaybeAndImmediately(): Unit {
        Observable<Int64>.maybe(200)
        .subscribe(FuncObserver<Int64>('testMaybeAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(200, v)
                println(200)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testMaybeAndImmediately")
            }
        }).immediately()
    }
    @TestCase
    public func testConcatAndImmediately(): Unit {
        let n = AtomicInt64(10)
        Observable<Int64>.concat([[10, 20, 30], [40, 50, 60], [70, 80, 90]])
        .subscribe(FuncObserver<Int64>('testConcatAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(n.load(), v)
                n.fetchAdd(10)
                println(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testConcatAndImmediately")
            }
        }).immediately()
    }
    @TestCase
    public func testEmitterAndImmediately(): Unit {
        let m = AtomicInt64(1000)
        let n = AtomicInt64(1000)
        Observable<Int64>.emitter({emitter =>
            while(let v <- m.fetchAdd(1000) && v <= 3000){
                emitter.onNext(v)
            }
            emitter.onComplete()
        })
        .subscribe(FuncObserver<Int64>('testEmitterAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(n.load(), v)
                n.fetchAdd(1000)
                println(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testConcatAndImmediately")
            }
        }).immediately()
        // sleep(Duration.second * 5)
    }
    @TestCase
    public func testEmitterErrorAndImmediately(): Unit {
        let m = AtomicInt64(4000)
        let n = AtomicInt64(4000)
        Observable<Int64>.emitter({emitter =>
            while(let v <- m.fetchAdd(1000) && v <= 3000){
                emitter.onNext(v)
            }
            emitter.onError(Exception('too large'))
        })
        .subscribe(FuncObserver<Int64>('testEmitterErrorAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                @Assert(n.load(), v)
                n.fetchAdd(1000)
                println(v)
            }
        }.setComplete{
            synchronized(mutex){
                throw Exception('unreachable')
            }
        }.setError{e => 
            synchronized(mutex){
                @Assert("too large", e.message)
                println('emitter error too large ${e.message}')
            }
        }).immediately()
    }
    @TestCase
    public func testCurrentAndImmediately(): Unit {
        let map = HashMap<Int64, ArrayList<Int64>>()
        Observable<Int64>.iterable([10000, 20000, 30000])
        .subscribe(FuncObserver<Int64>('testCurrentAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                println(v)
                map.addIfAbsent(Thread.currentThread.id, ArrayList<Int64>())?.add(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testAlwaysNewAndImmediately")
            }
        }).withCurrent().immediately()
        sleep(Duration.second * 5)
        println('currently threads: ${map}')
        @Assert(map.size, 1)
    }
    @TestCase
    public func testAlwaysNewAndImmediately(): Unit {
        let map = HashMap<Int64, ArrayList<Int64>>()
        Observable<Int64>.iterable([10000, 20000, 30000])
        .subscribe(FuncObserver<Int64>('testAlwaysNewAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                println(v)
                map.addIfAbsent(Thread.currentThread.id, ArrayList<Int64>())?.add(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testAlwaysNewAndImmediately")
            }
        }).withAlwaysNew().immediately()
        sleep(Duration.second * 5)
        println('always new threads: ${map}')
        @Assert(map.size, 3)
    }
    @TestCase
    public func testFixedAndImmediately(): Unit {
        let map = HashMap<Int64, ArrayList<Int64>>()
        Observable<Int64>.iterable([40000, 50000, 60000])
        .subscribe(FuncObserver<Int64>('testFixedAndImmediately').setNext{v: Int64 => 
            synchronized(mutex){
                println(v)
                map.addIfAbsent(Thread.currentThread.id, ArrayList<Int64>())?.add(v)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testFixedAndImmediately")
            }
        }).withFixed(2).immediately()
        sleep(Duration.second * 5)
        println('fixed threads: ${map}')
        @Assert(map.size, 2)
    }
    @TestCase
    public func testMultiSyncObserver(): Unit {
        let i = AtomicInt64(4000)
        let onet = AtomicOptionReference<Thread>(None<Thread>)
        let twot = AtomicOptionReference<Thread>(None<Thread>)
        Observable<Int64>.iterable([4000,5000,6000], asyncCombined: false)
        .subscribe(FuncObserver<Int64>('testMultiSyncObserver-0').setNext{v: Int64 => 
            synchronized(mutex){
                onet.store(Thread.currentThread)
                @Assert(i.load(), v)
                i.fetchAdd(1000)
                println('${v} one')
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testMultiObserver one")
            }
        }).subscribe(FuncObserver<Int64>('testMultiSyncObserver-1').setNext{v: Int64 => 
            twot.store(Thread.currentThread)
            println('${v} two')
        }.setComplete{
            synchronized(mutex){
                println("complete testMultiObserver two")
            }
        }).immediately()
        sleep(Duration.second * 5)
        let sameThread = refEq(onet.load().getOrThrow(), twot.load().getOrThrow())
        @Assert(sameThread, true)
    }
    @TestCase
    public func testMultiAsyncObserver(): Unit {
        let i = AtomicInt64(4000)
        let onet = AtomicOptionReference<Thread>(None<Thread>)
        let twot = AtomicOptionReference<Thread>(None<Thread>)
        Observable<Int64>.iterable([4000,5000,6000], asyncCombined: true)
        .subscribe(FuncObserver<Int64>('testMultiAsyncObserver-0').setNext{v: Int64 => 
            synchronized(mutex){
                println('${v} one')
                onet.store(Thread.currentThread)
                @Assert(i.load(), v)
                i.fetchAdd(1000)
            }
        }.setComplete{
            synchronized(mutex){
                println("complete testMultiObserver one")
            }
        }).subscribe(FuncObserver<Int64>('testMultiAsyncObserver-1').setNext{v: Int64 => 
            twot.store(Thread.currentThread)
            println('${v} two')
        }.setComplete{
            synchronized(mutex){
                println("complete testMultiObserver two")
            }
        }).immediately()
        sleep(Duration.second * 5)
        let sameThread = refEq(onet.load().getOrThrow(), twot.load().getOrThrow())
        @Assert(sameThread, false)
    }
    @TestCase
    public func testSleep(){
        sleep(Duration.second * 5)
    }
}