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

package threadpool_idletime

/**
 * 
 * @author yangfuping
 */
main() {
    LoggerFactory.setLevel(LogLevel.TRACE)
    let threadpool = ThreadPoolFactory.createThreadPool(0, 128, 4096, Duration.second * 30)

    let addTask = AtomicBool(true)
    spawn {
        var id = 0;
        while (addTask.load()) {
            id++
            threadpool.addTask(SimpleTask(id))
        }
    }

    // 添加10秒钟任务
    sleep(10 * Duration.second)
    println("===================Stop add task===================")
    // 停止添加任务
    addTask.store(false)

    // 主线程睡眠60秒钟，等待线程空闲超时
    println("===================Sleep 90 seconds: ===================")
    sleep(60 * Duration.second)
    println("===================Sleep 90 seconds ends===================")

    // 再次添加10秒钟任务
    addTask.store(true)
    spawn {
        var id = 0;
        while (addTask.load()) {
            id++
            threadpool.addTask(SimpleTask(id))
        }
    }

    sleep(10 * Duration.second)
    println("===================Stop add task===================")
    // 停止添加任务
    addTask.store(false)

    // 主线程睡眠60秒，等待线程空闲超时
    println("===================Sleep 90 seconds: ===================")
    sleep(60 * Duration.second)
    println("===================Sleep 90 seconds ends===================")

    // 停止线程池
    println("===================threadpool.stop()===================")
    threadpool.stop()
}

public class SimpleTask <: Runnable {
    private let id: Int64

    private static let mutex = Mutex()

    public init(id: Int64) {
        this.id = id
    }

    public func run() {
        synchronized(mutex) {
            println("${Thread.currentThread.name} running SimpleTask${id}")
        }

        sleep(100 * Duration.millisecond)
    }
}
