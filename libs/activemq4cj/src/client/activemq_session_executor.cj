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

/**
 * message的异步调度
 */
public class ActiveMQSessionExecutor <: Runnable {
    private let session: ActiveMQSession
    //用于异步转发的线程池
    private var taskRunner: AtomicOptionReference<ThreadPool> = AtomicOptionReference<ThreadPool>()
    private let messageQueue: MessageDispatchChannel
    private var maxIterationsPerRun = 1000

    private let monitor: Mutex = Mutex()
    private let runnableMutex: Mutex = Mutex()

    private var queued = false
    private var iterating = false

    public init(session: ActiveMQSession) {
        this.session = session
        if (session.connection.messagePrioritySupported) {
            this.messageQueue = SimplePriorityMessageDispatchChannel()
        } else {
            this.messageQueue = FifoMessageDispatchChannel()
        }
    }

    public func wakeup(): Unit {
        if (session.sessionAsyncDispatch) {
            if (this.taskRunner.load().isNone()) {
                this
                    .taskRunner
                    .compareAndSwap(
                        None,
                        ThreadPoolFactory.createThreadPool(0, ActiveMQConnection.DEFAULT_THREAD_POOL_SIZE,
                            ActiveMQConnection.DEFAULT_QUEUE_SIZE, Duration.minute * 2)
                    )
            }
            if (let Some(taskRunner) <- taskRunner.load()) {
                synchronized(runnableMutex) {
                    //queued=false, iterating=false 表示wakeup未被调用，任务未运行。
                    //queued=true, iterating=false 表示wakeup已被调用，任务还没开始运行。
                    //queued=false, iterating=true 表示wakeup被调用，任务已经开始运行。
                    //queued=true, iterating=true 表示任务开始执行后调用wakeup。
                    if (queued) {
                        return
                    }
                    queued = true

                    if (!iterating) {
                        taskRunner.addTask(this)
                    }
                }
            }
        }
    }

    protected func execute(message: MessageDispatch): Unit {
        if (!session.sessionAsyncDispatch) {
            dispatch(message)
        } else {
            messageQueue.enqueue(message)
            wakeup()
        }
    }

    private func dispatch(md: MessageDispatch) {
        if (let Some(consumerId) <- md.consumerId) {
            if (let Some(consumer) <- session.consumers.get(consumerId)) {
                consumer.dispatch(md)
            }
        }
    }

    public func run(): Unit {
        synchronized(runnableMutex) {
            queued = false
            iterating = true
        }

        var done = false

        try {
            for (i in 0..maxIterationsPerRun) {
                if (!iterate()) {
                    done = true
                    break
                }
            }
        } finally {
            synchronized(runnableMutex) {
                iterating = false

                if (!done) {
                    queued = true
                }

                if (queued) {
                    if (let Some(taskRunner) <- taskRunner.load()) {
                        taskRunner.addTask(this)
                    }
                }
            }
        }
    }

    private func iterate(): Bool {
        //先把consumer中积压的消息投递给MessageListener
        for ((consumerId, consumer) in session.consumers) {
            if (consumer.iterate()) {
                return true
            }
        }

        let md: ?MessageDispatch = messageQueue.dequeueNoWait()
        if (let Some(message) <- md) {
            dispatch(message)
            return !messageQueue.isEmpty()
        }
        return false
    }

    func executeFirst(message: MessageDispatch): Unit {
        messageQueue.enqueueFirst(message)
        wakeup()
    }

    public func hasUncomsumedMessages(): Bool {
        return !messageQueue.isClosed() && messageQueue.isRunning() && !messageQueue.isEmpty()
    }

    protected func start(): Unit {
        synchronized(runnableMutex) {
            if (!messageQueue.isRunning()) {
                messageQueue.start()
                if (hasUncomsumedMessages()) {
                    wakeup()
                }
            }
        }
    }

    protected func stop(): Unit {
        if (messageQueue.isRunning()) {
            synchronized(runnableMutex) {
                messageQueue.stop()
                if (let Some(taskRunner) <- taskRunner.load()) {
                    taskRunner.stop()
                    this.taskRunner.store(None)
                }

                queued = false
            }
        }
    }

    func close(): Unit {
        if (let Some(taskRunner) <- taskRunner.load()) {
            taskRunner.stop()
        }
        this.messageQueue.close()
    }

    protected func clearMessages(): Unit {
        this.messageQueue.clear()
    }
}
