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

import std.collection.concurrent.ConcurrentHashMap
import std.sync.AtomicBool
import f_concurrent.eventbus.exception.EventBusException

/**
 * 任务线程
 */
public class Worker {
    private let abilities = ConcurrentHashMap<Event, (Event) -> Event>()
    private let queue: JobQueue
    private let retired = AtomicBool(false)
    let index: Int64
    private let eventBus: EventBus
    /**
     * maxWaitingJob 最大等待任务数
     */
    public init(eventBus: EventBus, index: Int64, maxWaitingJob: Int64,
        abilities!: Array<(Event, (Event) -> Event)> = []) {
        this.eventBus = eventBus
        this.index = index
        queue = JobQueue(maxWaitingJob)
        register(abilities)
        spawn {
            while (!retired.load() || queue.size > 0) {
                var e = if (let Some(e) <- tryRemove()) {
                    e
                } else {
                    eventBus.seizeBy(index)
                    queue.remove()
                }
                while (true) {
                    let ee = this.abilities[e](e)
                    ee.workerId = e.workerId
                    ee.deliverResult = e.deliverResult
                    ee.arrangedThreadId = e.arrangedThreadId
                    e = ee
                    if (e is EndEvent) {
                        break
                    }
                }
                deliverIfNeed(e)
            }
        }
    }
    /**
     * 退役
     */
    public func retire(): Unit {
        retired.store(true)
    }
    private func deliverIfNeed(event: Event) {
        eventBus.deliverIfNeed(event)
    }
    /**
     * 注册工作线程的能力
     */
    func register(event: Event, ability: (Event) -> Event): Unit {
        abilities[event] = ability
    }
    func register(abilities: Array<(Event, (Event) -> Event)>) {
        for (ability in abilities) {
            register(ability[0], ability[1])
        }
    }
    func force(e: Event) {
        if (e is EndEvent) {
            deliverIfNeed(e)
            return
        }
        var ee = e
        while (!queue.tryAdd(ee, Duration.Zero)) {
            ee = abilities[ee](ee)
            if (ee is EndEvent) {
                deliverIfNeed(ee)
                return
            }
        }
        deliverIfNeed(ee)
    }
    func arrange(event: Event): Unit {
        if (retired.load()) {
            throw EventBusException("index of ${index} worker is retired")
        }
        queue.add(event)
    }
    /**
     * 给工作线程安排任务
     */
    func tryArrange(event: Event, timeout!: Duration = Duration.Zero): Bool {
        if (retired.load()) {
            throw EventBusException("index of ${index} worker is retired")
        }
        queue.tryAdd(event, timeout)
    }
    func discard() {
        queue.tryRemove()
    }
    prop waitingJobSize: Int64 {
        get() {
            queue.size
        }
    }
    func tryRemove(): ?Event {
        if (let Some(e) <- queue.tryRemove()) {
            eventBus.putQueueSize(index)
            e.workerId = index
            e
        } else {
            None<Event>
        }
    }
}
