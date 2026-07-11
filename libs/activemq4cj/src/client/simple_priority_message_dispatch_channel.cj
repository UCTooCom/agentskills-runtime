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
package activemq4cj.client

public class SimplePriorityMessageDispatchChannel <: MessageDispatchChannel {
    private static let MAX_PRIORITY = 10
    private let lists: Array<LinkedList<MessageDispatch>>
    private let monitor: Mutex = Mutex()
    private let condition: Condition = synchronized(monitor) {
        monitor.condition()
    }
    private var closed: Bool = false
    private var running: Bool = false
    private var sizeVal: Int64 = 0

    public init() {
        //priority的有效值是0~9
        lists = Array<LinkedList<MessageDispatch>>(MAX_PRIORITY, {index: Int64 => LinkedList<MessageDispatch>()})
    }

    public func enqueue(message: MessageDispatch): Unit {
        synchronized(monitor) {
            getList(message).addLast(message)
            this.sizeVal++
            condition.notify()
        }
    }

    public func enqueueFirst(message: MessageDispatch): Unit {
        synchronized(monitor) {
            getList(message).addFirst(message)
            this.sizeVal++
            condition.notify()
        }
    }

    public func isEmpty(): Bool {
        return this.sizeVal == 0
    }

    public func dequeue(timeout: Duration): ?MessageDispatch {
        synchronized(monitor) {
            while (timeout != Duration.Zero && !closed && (isEmpty() || !running)) {
                if (timeout > Duration.Zero) {
                    condition.wait(timeout: timeout)
                    break
                } else {
                    condition.wait()
                }
            }
            if (closed || !running || isEmpty()) {
                return None
            }
            return popFirst()
        }
    }

    public func dequeueNoWait(): ?MessageDispatch {
        synchronized(monitor) {
            if (closed || !running || isEmpty()) {
                return None
            }
            return popFirst()
        }
    }

    public func peek(): ?MessageDispatch {
        synchronized(monitor) {
            if (closed || !running || isEmpty()) {
                return None
            }
            return getFirst()
        }
    }

    public func start(): Unit {
        synchronized(monitor) {
            running = true
            condition.notifyAll()
        }
    }

    public func stop(): Unit {
        synchronized(monitor) {
            running = false
            condition.notifyAll()
        }
    }

    public func close(): Unit {
        synchronized(monitor) {
            if (!closed) {
                running = false
                closed = true
            }
            condition.notifyAll()
        }
    }

    public func clear(): Unit {
        synchronized(monitor) {
            for (i in 0..MAX_PRIORITY) {
                lists[i].clear()
            }
            this.sizeVal = 0
        }
    }

    public func isClosed(): Bool {
        return closed
    }

    public func getMutex(): Mutex {
        return this.monitor
    }

    public func getCondition(): Condition {
        return this.condition
    }

    public func isRunning(): Bool {
        return running
    }

    public func removeAll(): LinkedList<MessageDispatch> {
        synchronized(monitor) {
            let result = LinkedList<MessageDispatch>()
            var x = MAX_PRIORITY
            while (x > 0) {
                x--
                let list = lists[x]
                Collections.addAll<MessageDispatch>(list, result)
                this.sizeVal -= list.size
                list.clear()
            }
            return result
        }
    }

    public prop size: Int64 {
        get() {
            synchronized(monitor) {
                return this.sizeVal
            }
        }
    }

    protected func getList(md: MessageDispatch): LinkedList<MessageDispatch> {
        var priority = MessageConstants.DEFAULT_PRIORITY
        if (let Some(message) <- md.message) {
            priority = max(message.priority, 0)
            priority = min(priority, 9)
        }
        return lists[Int64(priority)]
    }

    private func popFirst(): ?MessageDispatch {
        if (this.sizeVal > 0) {
            var x = MAX_PRIORITY
            while (x > 0) {
                x--
                let list = lists[x]
                if (!list.isEmpty()) {
                    this.sizeVal--
                    return list.removeFirst()
                }
            }
        }
        return None
    }

    private func getFirst(): ?MessageDispatch {
        if (this.sizeVal > 0) {
            var x = MAX_PRIORITY
            while (x > 0) {
                x--
                let list = lists[x]
                if (!list.isEmpty()) {
                    return list.first
                }
            }
        }
        return None
    }
}
