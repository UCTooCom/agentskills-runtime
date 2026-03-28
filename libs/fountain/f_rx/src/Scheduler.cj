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

/**
 * 观察者调度器
 */
public abstract class Scheduler<T> {
    public Scheduler(protected var observer: Observer<T>) {}
    /**
     * 伪代码
     * try {
     *   match (item) {
     *     case Some(x) => observer.onNext(x)
     *     case _ => observer.onComplete()
     *   }
     * } catch(e: Exception) {
     *    observer.onError(e)
     * }
     */
    public func schedule(item: ?T): Unit
    /**
     * observer.onError(ex)
     */
    public func schedule(ex: Exception): Unit
    /**
     * 一直使用新线程执行观察者，observer是待执行的观察者
     */
    public static func alwaysNew(observer: Observer<T>): Scheduler<T> {
        AlwaysNewScheduler(observer)
    }
    /**
     * 使用当前线程执行观察者，observer是待执行的观察者
     */
    public static func current(observer: Observer<T>): Scheduler<T> {
        CurrentScheduler(observer)
    }
    /**
     * 开启一个新线程执行观察者，observer是待执行的观察者，被观察者产生的数据推入数据队列，这个线程不停地从队列取出数据。
     * queueSize是线程队列容量，policy是背压策略
     */
    public static func single(observer: Observer<T>, queueSize: Int64, policy!: BackPressure<T> = CurrentThread<T>()): Scheduler<T> {
        SingleScheduler(observer, queueSize, policy: policy)
    }
    /**
     * 开启一个新线程执行观察者，observer是待执行的观察者
     * policy是背压策略
     */
    public static func single(observer: Observer<T>, policy!: BackPressure<T> = CurrentThread<T>()): Scheduler<T> {
        SingleScheduler(observer, policy: policy)
    }
    /**
     * 开启threads个新线程执行观察者，observer是待执行的观察者，
     * 一个线程对应一个数据队列，被观察者的产生的数据按循环推入数据队列
     * queueSize是线程队列容量，policy是背压策略
     */
    public static func fixed(observer: Observer<T>, threads: Int64, policy!: BackPressure<T> = CurrentThread<T>()): Scheduler<T> {
        FixedScheduler(observer, threads, policy: policy)
    }
    /**
     * 开启threads个新线程执行观察者，observer是待执行的观察者，
     * 一个线程对应一个数据队列，被观察者的产生的数据按循环推入数据队列
     * queueSize是线程队列容量，policy是背压策略
     */
    public static func fixed(observer: Observer<T>, threads: Int64, queueSize: Int64,
        policy!: BackPressure<T> = CurrentThread<T>()): Scheduler<T> {
        FixedScheduler(observer, threads, queueSize, policy: policy)
    }
}

class AlwaysNewScheduler<T> <: Scheduler<T> {
    init(observer: Observer<T>) {
        super(observer)
    }
    public func schedule(item: ?T): Unit {
        spawn {
            try {
                if (let Some(v) <- item) {
                    this.observer.onNext(v)
                } else {
                    this.observer.onComplete()
                }
            } catch (e: Exception) {
                this.observer.onError(e)
            }
        }
    }
    public func schedule(ex: Exception): Unit {
        spawn {
            this.observer.onError(ex)
        }
    }
}

class CurrentScheduler<T> <: Scheduler<T> {
    init(observer: Observer<T>) {
        super(observer)
    }
    public func schedule(item: ?T): Unit {
        try {
            if (let Some(v) <- item) {
                this.observer.onNext(v)
            } else {
                this.observer.onComplete()
            }
        } catch (e: Exception) {
            this.observer.onError(e)
        }
    }
    public func schedule(ex: Exception): Unit {
        this.observer.onError(ex)
    }
}

public enum SingleSchedulerState<T> {
    | Item(?T)
    | Ex(Exception)
    | Poison(SyncCounter, SingleScheduler<T>, Int64)
}

public class SingleScheduler<T> <: Scheduler<T> {
    var wrapper = None<FixedScheduler<T>>
    private SingleScheduler(observer: Observer<T>, private let queue: LinkedBlockingQueue<SingleSchedulerState<T>>,
        private let policy!: BackPressure<T> = CurrentThread<T>(), private let index!: Int64 = 0) {
        super(observer)
        policy.scheduler = this
        spawn {
            try {
                var toSteal = true
                while (let state <- queue.remove()) {
                    func exec(state: SingleSchedulerState<T>, steal: Bool): Bool {
                        match (state) {
                            case Item(item) => match (item) {
                                case Some(v) => this.observer.onNext(v)
                                case _ =>
                                    if (let Some(w) <- wrapper) {
                                        let queues = w.queues
                                        let qsize = queues.size
                                        let counter = SyncCounter(qsize)
                                        for (ss in queues) {
                                            ss.queue.add(Poison(counter, ss, index)) //这里不能使用ss.schedule代替ss.queue.add，毒丸必须发送成功
                                        }
                                    } else {
                                        this.observer.onComplete() //当前是单线程调度器立即结束
                                        return false
                                    }
                            }
                            case Ex(e) => this.observer.onError(e)
                            case Poison(c, ss, idx) where steal =>
                                ss.queue.add(Poison(c, ss, idx))
                                return false
                            case Poison(c, _, idx) =>
                                c.dec()
                                if (idx == this.index) {
                                    c.waitUntilZero()
                                    this.observer.onComplete()
                                }
                                return false
                        }
                        true
                    }
                    if (!exec(state, false)) {
                        return
                    }
                    while (toSteal && this.queue.size == 0 && let Some(w) <- wrapper) {
                        let queues = w.queues
                        let qsize = queues.size
                        var stolen = 0
                        for (i in 1..qsize) {
                            if (let Some(state) <- queues[(index + i) % qsize].queue.tryRemove()) {
                                stolen++
                                if (!exec(state, true)) {
                                    toSteal = false
                                    break
                                }
                            }
                            if (this.queue.size > 0) {
                                break
                            }
                        }
                        if (stolen == 0) {
                            break
                        }
                        stolen = 0
                    }
                }
            } catch (e: Exception) {
                this.observer.onError(e)
            }
        }
    }

    init(observer: Observer<T>, size: Int64, policy!: BackPressure<T> = CurrentThread<T>(), index!: Int64 = 0) {
        this(observer, LinkedBlockingQueue<SingleSchedulerState<T>>(size), policy: policy, index: index)
    }
    init(observer: Observer<T>, policy!: BackPressure<T> = CurrentThread<T>(), index!: Int64 = 0) {
        this(observer, LinkedBlockingQueue<SingleSchedulerState<T>>(), policy: policy, index: index)
    }
    private func schedule(state: SingleSchedulerState<T>): Unit {
        if (queue.size < queue.capacity) {
            queue.add(state)
        } else {
            policy.schedule(state)
        }
    }
    public func schedule(item: ?T): Unit {
        schedule(Item(item))
    }
    public func schedule(ex: Exception): Unit {
        schedule(Ex(ex))
    }
    public func doSchedule(state: SingleSchedulerState<T>): Unit {
        try {
            match (state) {
                case Item(item) => match (item) {
                    case Some(v) => this.observer.onNext(v)
                    case _ => this.observer.onComplete()
                }
                case Ex(ex) => this.observer.onError(ex)
                case Poison(c, _, idx) =>
                    c.dec()
                    if (idx == this.index) {
                        c.waitUntilZero()
                        this.observer.onComplete()
                    }
            }
        } catch (e: Exception) {
            this.observer.onError(e)
        }
    }
    public func tryRemove(){
        queue.tryRemove()
    }
    public func add(state: SingleSchedulerState<T>){
        queue.add(state)
    }
    public func add(state: SingleSchedulerState<T>, timeout: Duration): Bool {
        queue.add(state, timeout)
    }
}

class FixedScheduler<T> <: Scheduler<T> {
    private let index = AtomicInt64(0)
    private FixedScheduler(let queues: Array<SingleScheduler<T>>) {
        super(queues[0].observer)
        for (scheduler in queues) {
            scheduler.wrapper = this
        }
    }

    public init(observer: Observer<T>, threads: Int64, policy!: BackPressure<T> = CurrentThread<T>()) {
        this(Array<SingleScheduler<T>>(threads) {i => SingleScheduler<T>(observer, policy: policy.clone(), index: i)})
    }
    public init(observer: Observer<T>, threads: Int64, queueSize: Int64, policy!: BackPressure<T> = CurrentThread<T>()) {
        this(Array<SingleScheduler<T>>(threads) {i => SingleScheduler(observer, queueSize, policy: policy.clone(), index: i)})
    }
    private prop nextIndex: Int64 {
        get() {
            var idx = index.fetchAdd(1) % queues.size
            if (idx < 0) {
                idx = -idx
            }
            idx
        }
    }
    public func schedule(item: ?T): Unit {
        queues[nextIndex].schedule(item)
    }
    public func schedule(ex: Exception): Unit {
        queues[nextIndex].schedule(ex)
    }
}
