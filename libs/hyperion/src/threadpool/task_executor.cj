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
 * 线程栈中执行任务的工作线程
 *
 * @author yangfuping
 */
public class TaskExecutor <: Runnable {
    private let workQueue: ThreadPool

    private var running: AtomicBool = AtomicBool(true)

    private let id: String

    protected init(id: String, workQueue: ThreadPool) {
        this.id = id
        this.workQueue = workQueue
    }

    public open func run() {
        while (running.load()) {
            if (let Some(task) <- workQueue.getTask()) {
                task.run()
            } else {
                running.compareAndSwap(true, false)
                workQueue.removeExectutor(id)
            }
        }
    }

    public open func terminate() {
        running.compareAndSwap(true, false)
    }
}
