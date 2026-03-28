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

import std.collection.concurrent.ArrayBlockingQueue
import std.env
import std.sync.{AtomicInt64, AtomicBool}
import std.time.MonoTime
import f_log.impl.LoggerFactory

public interface PooledManager<T> {
    func create(): T
    func check(object: T): Bool
    func destroy(object: T): Unit
    func clear(object: T): Unit
}
/**
 * 本类型无法分辨返还的实例是不是从Pool借出去的，也无法分辨借出实例的Pool跟返回实例的Pool是不是同一个，因此调用giveBack返还实例的时候，如果返回时检查失败了一定会销毁返还的实例，池维护的实例数随之减1。
 */
public class Pool<T> <: Resource {
    private static let log = LoggerFactory.getLogger('fountain.pool.Pool')
    private let queue: ArrayBlockingQueue<(T, MonoTime)>
    private let tasks: ArrayBlockingQueue<Unit>
    private let size = AtomicInt64(0)
    private let running = AtomicBool(true)
    public Pool(
        private let initSize!: Int64 = 0,
        private let minSize!: Int64 = 0,
        private let maxSize!: Int64 = Int64.Max,
        private let idleTimeout!: Duration = Duration.hour,
        private let checkOnCreation!: Bool = false,
        private let checkOnBorrowing!: Bool = true,
        private let checkOnReturning!: Bool = true,
        private let clearOnReturning!: Bool = false,
        private let checkInterval!: Duration = Duration.minute,
        private let creator!: () -> T,
        private let checker!: (T) -> Bool,
        private let destroier!: (T) -> Unit,
        private let clear!: (T) -> Unit = {_ =>}
    ) {
        queue = ArrayBlockingQueue<(T, MonoTime)>(maxSize)
        tasks = ArrayBlockingQueue<Unit>(maxSize)
        startCheckingSchedule()
        startCreationSchedule()
        for (_ in 0..initSize) {
            tasks.add(())
        }
        env.atExit(close)
    }
    public init(
        initSize!: Int64 = 0,
        minSize!: Int64 = 0,
        maxSize!: Int64 = Int64.Max,
        idleTimeout!: Duration = Duration.hour,
        checkOnCreation!: Bool = false,
        checkOnBorrowing!: Bool = true,
        checkOnReturning!: Bool = true,
        checkInterval!: Duration = Duration.minute,
        manager!: PooledManager<T>
    ) {
        this(initSize: initSize, minSize: minSize, maxSize: maxSize, idleTimeout: idleTimeout,
            checkOnCreation: checkOnCreation, checkOnBorrowing: checkOnBorrowing, checkOnReturning: checkOnReturning,
            checkInterval: checkInterval, creator: manager.create, checker: manager.check, destroier: manager.destroy,
            clear: manager.clear)
    }
    private func startCheckingSchedule() {
        if (checkInterval <= Duration.Zero) {
            return
        }
        spawn {
            while (running.load()) {
                var i = 0
                while (running.load() && i < this.size.load() && let (o, t) <- queue.remove()) {
                    i++
                    try {
                        if ((idleTimeout > Duration.Zero && MonoTime.now() - t >= idleTimeout) || !checker(o)) {
                            destroy(o, true)
                            if (this.size.load() < minSize) {
                                tasks.tryAdd(())
                            }
                        } else {
                            queue.add((o, t))
                        }
                    } catch (e: Exception) {
                        log.warn('Pool checking schedule', e)
                    }
                    sleep(Duration.Zero)
                }
                sleep(checkInterval)
            }
        }
    }
    private func startCreationSchedule() {
        spawn {
            while (running.load() && let _ <- tasks.remove()) {
                if (running.load() && size.load() < maxSize) {
                    let object = creator()
                    if (checkOnCreation && !checker(object)) {
                        destroy(object, true, decr: false)
                    } else if (add(object, decrIfOverload: false)) {
                        size.fetchAdd(1)
                    }
                }
            }
        }
    }
    private func destroy(o: T, logOnEx: Bool, decr!: Bool = true) {
        try {
            destroier(o)
        } catch (e: Exception) {
            if (logOnEx) {
                log.warn('error occurred on destring object in pool', e)
            } else {
                throw e
            }
        } finally {
            if (decr) {
                size.fetchSub(1)
            }
        }
        if (size.load() < 0) {
            let ex = PoolException(
                'current size of pool is less than zero, may be some instances which were not be created by current pool were destroied by current pool on giving back.')
            if (logOnEx) {
                log.warn(ex)
            } else {
                throw ex
            }
        }
    }
    private func add(object: T, decrIfOverload!: Bool = true): Bool {
        if (!queue.tryAdd((object, MonoTime.now()))) {
            log.warn {
                "current size of pool is larger than maxSize(${maxSize}), may be some instances which were not be created by current pool were given back to current pool."
            }
            destroy(object, false, decr: decrIfOverload)
            false
        } else {
            true
        }
    }
    public func isClosed(): Bool {
        !running.load()
    }
    public func close(): Unit {
        running.store(false)
        while (let Some(c) <- tasks.tryRemove()) {}
        while (let Some((o, _)) <- queue.tryRemove()) {
            destroy(o, true)
        }
    }
    public func borrow(timeout!: Duration = Duration.Max): ?T {
        func doCheck(o: T): ?T {
            if (checkOnBorrowing && !checker(o)) {
                destroy(o, true)
                return None<T>
            }
            o
        }
        let start = MonoTime.now()
        while (running.load() && MonoTime.now() - start < timeout) {
            if (let Some((o, _)) <- queue.tryRemove()) {
                if (let Some(x) <- doCheck(o)) {
                    return x
                }
            } else {
                tasks.tryAdd(())
                if (let consumed <- MonoTime.now() - start && consumed < timeout && let Some((o, _)) <- queue.remove(
                    timeout - consumed) && let Some(x) <- doCheck(o)) {
                    return x
                }
            }
        }
        None<T>
    }
    public func giveBack(object: T): Unit {
        func doAdd() {
            if (clearOnReturning) {
                clear(object)
            }
            add(object)
        }
        if (!running.load()) {
            destroy(object, true)
        } else if (checkOnReturning) {
            if (checker(object)) {
                doAdd()
            } else {
                destroy(object, true)
            }
        } else {
            doAdd()
        }
    }
}
