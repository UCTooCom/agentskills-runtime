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

package hyperion.threadpool

/**
 * 线程池实现
 *
 * @author yangfuping
 */
public open class ThreadPool {
    private static let logger = LoggerFactory.getLogger("objectpool")

    //任务列表
    private let workQueue: ArrayBlockingQueue<Runnable>

    private let config: ThreadPoolConfig

    private let executors: ConcurrentHashMap<String, TaskExecutor>

    private let runningThreads: AtomicInt64 = AtomicInt64(0)

    private let waitingThreads: AtomicInt64 = AtomicInt64(0)

    private let threadIdGen: AtomicInt64 = AtomicInt64(0)

    protected init(threadPoolConfig: ThreadPoolConfig) {
        this.config = threadPoolConfig
        this.workQueue = ArrayBlockingQueue<Runnable>(config.queueSize)
        this.executors = ConcurrentHashMap<String, TaskExecutor>(config.maxThreads)
    }

    public open func addTask(task: Runnable) {
        workQueue.add(task)

        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.DEBUG, "Add a task to workqueue, queue size: ${workQueue.size}")
        }

        if (runningThreads.load() < config.maxThreads && waitingThreads.load() < (workQueue.size + 1)) {
            // 创建新线程
            increaseExecutor()
        }
    }

    /**
     * 增加线程
     *
     */
    private func increaseExecutor() {
        let threads = runningThreads.load()
        if (threads < config.maxThreads) {
            if (runningThreads.compareAndSwap(threads, threads + 1)) {
                let executorName = "${config.name}-${threadIdGen.fetchAdd(1)}"
                let executor: TaskExecutor = TaskExecutor(executorName, this)
                executors.add(executorName, executor)
                let fut: Future<Any> = spawn {
                    Thread.currentThread.name = executorName
                    executor.run()
                }

                if (logger.isLoggable(LogLevel.DEBUG)) {
                    logger.log(LogLevel.DEBUG, "Increase a thread: ${executorName}")
                }
            }
        }
    }

    public open func getTask(): ?Runnable {
        var result: ?Runnable
        try {
            waitingThreads.fetchAdd(1)
            result = workQueue.remove(config.threadIdleTimeout)
        } finally {
            waitingThreads.fetchSub(1)
        }

        if (logger.isLoggable(LogLevel.TRACE)) {
            if (let Some(result) <- result) {
                logger.log(LogLevel.DEBUG, "Get a task from workqueue, queue size: ${workQueue.size}")
            }
        }

        return result
    }

    public open func removeExectutor(id: String): Unit {
        if (let Some(executor) <- executors.remove(id)) {
            // Decrement thread counts
            runningThreads.fetchSub(1)
            if (logger.isLoggable(LogLevel.DEBUG)) {
                logger.log(LogLevel.DEBUG, "Decrease a thread: ${id}")
            }
        }
    }

    public open func stop(): Unit {
        let iterator = executors.iterator()
        while (let Some(item) <- iterator.next()) {
            item[1].terminate()
        }

        if (logger.isLoggable(LogLevel.DEBUG)) {
            logger.log(LogLevel.DEBUG, "Stop threadpool: ${config.name}")
        }
    }
}
