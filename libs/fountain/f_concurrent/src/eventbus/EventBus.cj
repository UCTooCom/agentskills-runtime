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
package f_concurrent.eventbus

import std.collection.concurrent.{LinkedBlockingQueue, ConcurrentHashMap}
import std.runtime.getProcessorCount
import std.sync.{Mutex, AtomicBool}
import std.time.DateTime
import stdx.crypto.crypto.SecureRandom
import f_base.WorkerStrategy
import f_concurrent.eventbus.exception.EventBusException

/**
 * 工作线程集合
 */
public class EventBus {
    private static let THREAD_LOCAL_RANDOM = ThreadLocal<SecureRandom>()
    private let mutex = Mutex()
    private let monitor = Mutex()
    private let condition = synchronized(monitor) {
        monitor.condition()
    }
    private var workers: Array<Worker> = []

    private var maxQueueSize = (-1, -1) // (maxQueueSize, longestQueueIndex)
    private let queueMutex = Mutex()
    private let seizeQueue: LinkedBlockingQueue<Int64>
    private let toThrowIfNotMatch: Bool
    private var doArrange: (Int64, Event) -> Bool = {_, _ => false}
    /**
     * workers 工作线程数，初始化后不可修改
     * maxWaitingJobPerWorker 最大等待任务数
     * fullJobQueueStrategy 满任务队列处理策略，默认是Block
     */
    public init(
        workers!: Int64 = getProcessorCount(),
        maxWaitingJobPerWorker!: Int64 = 1,
        fullJobQueueStrategy!: WorkerStrategy = Block,
        toThrowIfNotMatch!: Bool = false,
        abilities!: Array<(Event, (Event) -> Event)> = []
    ) {
        this.toThrowIfNotMatch = toThrowIfNotMatch
        seizeQueue = LinkedBlockingQueue<Int64>(workers)
        this.workers = Array<Worker>(workers) {
            i => Worker(this, i, maxWaitingJobPerWorker, abilities: abilities)
        }
        doArrange = genDoArrange(maxWaitingJobPerWorker, fullJobQueueStrategy)
        seize()
    }
    private func seize() {
        spawn {
            var (prevMaxQueueSize, prevMaxQueueIndex): (Int64, Int64) = (-1, -1)
            while (true) {
                let sizedBy = seizeQueue.remove()
                var (maxQueueSize, maxQueueIndex) = synchronized(queueMutex) {
                    this.maxQueueSize
                }
                var i = 0
                while ((prevMaxQueueIndex == maxQueueIndex || prevMaxQueueSize > maxQueueSize) && i < this.workers.size) {
                    if (i == maxQueueIndex) {
                        i++
                        continue
                    }
                    if (let s <- this.workers[i].waitingJobSize && maxQueueSize < s) {
                        (maxQueueSize, maxQueueIndex) = (s, i)
                        break
                    }
                    i++
                }
                (prevMaxQueueSize, prevMaxQueueIndex) = (maxQueueSize, maxQueueIndex)
                if (maxQueueSize > 0 && maxQueueIndex != sizedBy && let Some(e) <- this
                    .workers[maxQueueIndex]
                    .tryRemove()) {
                    e.workerId = sizedBy
                    this.workers[sizedBy].arrange(e)
                    putQueueSize(sizedBy)
                }
            }
        }
    }
    private func genDoArrange(maxWaitingJobPerWorker: Int64, fullJobQueueStrategy: WorkerStrategy): (Int64, Event) -> Bool {
        match (fullJobQueueStrategy) {
            case Abort => abortStrategy(maxWaitingJobPerWorker)
            case DiscardCurrent => discardCurrent
            case DiscardOldest => discardOldestStrategy
            case AbortAfter(d) => abortAfterStrategy(d, maxWaitingJobPerWorker)
            case DiscardCurrentAfter(d) => discardCurrentAfterStrategy(d)
            case DiscardOldestDuring(d) => discardOldestDuringStrategy(d)
            case Block => blockStrategy
            case CurrentThread | New => currentThreadStrategy
        }
    }
    private func abortStrategy(maxWaitingJobPerWorker: Int64): (Int64, Event) -> Bool {
        {
            id, e => if (e is EndEvent) {
                deliverIfNeed(e)
                false
            } else if (tryArrange(id, e) || tryArrangeOther(id, e)) {
                true
            } else {
                throw EventBusException("job queue is full, max size of queue is ${maxWaitingJobPerWorker}")
            }
        }
    }
    private func discardCurrent(id: Int64, e: Event) {
        if (e is EndEvent) {
            deliverIfNeed(e)
            false
        } else if (tryArrange(id, e) || tryArrangeOther(id, e)) {
            true
        } else {
            deliverIfNeed(e)
            false
        }
    }
    private func discardOldestStrategy(id: Int64, e: Event) {
        if (e is EndEvent) {
            deliverIfNeed(e)
            return false
        }
        while (!(tryArrange(id, e) || tryArrangeOther(id, e))) {
            discard(id)
        }
        true
    }
    private func abortAfterStrategy(d: Duration, maxWaitingJobPerWorker: Int64): (Int64, Event) -> Bool {
        {
            id, e => if (e is EndEvent) {
                deliverIfNeed(e)
                false
            } else if (tryArrange(id, e) || tryArrangeOther(id, e) || tryArrange(id, e, timeout: d)) {
                true
            } else {
                throw EventBusException("job queue is full, max size of queue is ${maxWaitingJobPerWorker}")
            }
        }
    }
    private func discardCurrentAfterStrategy(d: Duration): (Int64, Event) -> Bool {
        {
            id, e => if (e is EndEvent) {
                deliverIfNeed(e)
                false
            } else if (tryArrange(id, e) || tryArrangeOther(id, e) || tryArrange(id, e, timeout: d)) {
                true
            } else {
                e.setNoneData()
                deliverIfNeed(e)
                false
            }
        }
    }
    private func discardOldestDuringStrategy(d: Duration): (Int64, Event) -> Bool {
        {
            id, e =>
            if (e is EndEvent) {
                deliverIfNeed(e)
                return false
            }
            let start = DateTime.now()
            while (!(tryArrange(id, e) || tryArrangeOther(id, e))) {
                if (DateTime.now() - start < d) {
                    discard(id)
                } else {
                    e.setNoneData()
                    deliverIfNeed(e)
                    return false
                }
            }
            true
        }
    }
    private func blockStrategy(id: Int64, e: Event) {
        if (e is EndEvent) {
            deliverIfNeed(e)
        } else {
            arrange(id, e)
        }
        true
    }
    private func currentThreadStrategy(id: Int64, e: Event) {
        arrange(id, e, true)
    }

    public func retireAll() {
        for (worker in workers) {
            worker.retire()
        }
    }
    public func register(event: Event, ability: (Event) -> Event): Unit {
        for (worker in workers) {
            worker.register(event, ability)
        }
    }
    public func register(abilities: Array<(Event, (Event) -> Event)>) {
        for (worker in workers) {
            worker.register(abilities)
        }
    }
    /**
     *  当前函数传入事件，触发任务，直到任务函数返回EndEvent实例
     */
    public func arrange(event: Event): Unit {
        event.arrangedThreadId = Thread.currentThread.id
        var workerId = event.workerId
        if (workerId < 0) {
            workerId = synchronized(mutex) {
                let id = event.workerId
                if (id >= 0) {
                    id
                } else {
                    let id = if (let Some(random) <- THREAD_LOCAL_RANDOM
                        .get()) {
                            random
                        } else {
                            let random = SecureRandom()
                            THREAD_LOCAL_RANDOM
                            .set(random)
                            random
                        }
                        .nextInt64(workers.size)
                    event.workerId = id
                    id
                }
            }
        }
        doArrange(workerId, event)
        putQueueSize(workerId)
    }

    private func arrange(workerId: Int64, event: Event, currentThread: Bool) {
        if (event is EndEvent) {
            deliverIfNeed(event)
            false
        } else if (tryArrange(workerId, event) || tryArrangeOther(workerId, event)) {
            true
        } else if (currentThread) {
            this.workers[workerId].force(event)
            false
        } else {
            spawn {
                this.workers[workerId].force(event)
            }
            false
        }
    }
    private func arrange(workerId: Int64, event: Event): Unit {
        workers[workerId].arrange(event)
    }
    private func tryArrange(workerId: Int64, event: Event, timeout!: Duration = Duration.Zero): Bool {
        workers[workerId].tryArrange(event, timeout: timeout)
    }
    private func tryArrangeOther(workerId: Int64, event: Event): Bool {
        var i = 1
        while (i < workers.size && !tryArrange((workerId + i) % workers.size, event)) {
            i++
        }
        i < workers.size
    }
    private func discard(workerId: Int64) {
        workers[workerId].discard()
    }

    func putQueueSize(workerId: Int64) { //分别在增加减少Worker任务队列的时候调用了此函数
        synchronized(queueMutex) {
            let waitingJobSize = workers[workerId].waitingJobSize
            if (waitingJobSize > maxQueueSize[0] || workerId == maxQueueSize[1]) {
                maxQueueSize = (waitingJobSize, workerId)
            }
        }
    }
    func seizeBy(workerId: Int64): Unit {
        seizeQueue.add(workerId)
    }
    private let datas = ConcurrentHashMap<Int64, Any>()
    private let notified = AtomicBool(false)
    /**
     * 安排任务并在timeout的时间内等待执行结果。
     * 如果超时会抛出异常。
     * 不论任务执行成功与否整个任务流程必须以返回EndEvent实例为任务终点。
     */
    public func arrangeAndGet<T>(event: Event, timeout!: Duration = Duration.Max): ?T {
        event.deliverResult = true
        arrange(event)
        func convert(d: ?Any): ?T {
            match (d) {
                case Some(x) => match (x) {
                    case x: T => Some(x)
                    case _ =>
                        if (toThrowIfNotMatch) {
                            throw EventBusException("data in current Event does not match.")
                        } else {
                            None<T>
                        }
                }
                case _ => None<T>
            }
        }
        let threadId = Thread.currentThread.id
        func get(toWaitIfNeed: Bool): ?T {
            if (let Some(x) <- datas.remove(threadId)) {
                convert(x)
            } else if (notified.load()) {
                None<T>
            } else {
                synchronized(monitor) {
                    if (let Some(x) <- datas.remove(threadId)) {
                        convert(x)
                    } else if (notified.load()) {
                        None<T>
                    } else if (toWaitIfNeed && condition.wait(timeout: timeout)) {
                        get(false)
                    } else if (let Some(x) <- datas.remove(threadId)) {
                        convert(x)
                    } else {
                        throw EventBusException("monitor is timeout")
                    }
                }
            }
        }
        get(true)
    }
    func deliverIfNeed(event: Event) {
        if (event.deliverResult) {
            deliver(event.arrangedThreadId, event.getData<Any>())
        }
    }
    func deliver(arrangedThreadId: Int64, data: ?Any): Unit {
        synchronized(monitor) {
            this.datas.add(arrangedThreadId, data)
            notified.store(true)
            condition.notify()
        }
    }
}
