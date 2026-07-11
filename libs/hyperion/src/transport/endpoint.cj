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

package hyperion.transport

/**
 * TCP通信客户端或者服务端入口
 * 
 * @author yangfuping
 */
public interface Endpoint {
    prop filterChain: IoFilterChain

    prop threadPool: ThreadPool

    prop running: Bool

    func addFilter(filter: IoFilter): Unit

    func start(): Unit

    func stop(): Unit
}

/**
 *  TCP通信客户端或者服务端入口的公共父类
 *
 * @author yangfuping
 */
public abstract class AbstractEndPoint <: Endpoint {
    protected let ioFilterChain = IoFilterChain()

    private let endpointThreadPool: ThreadPool

    private let runningVal = AtomicBool(true)

    public init(threadPool: ThreadPool) {
        this.endpointThreadPool = threadPool
    }

    public prop filterChain: IoFilterChain {
        get() {
            return ioFilterChain
        }
    }

    public prop threadPool: ThreadPool {
        get() {
            return endpointThreadPool
        }
    }

    public prop running: Bool {
        get() {
            return runningVal.load()
        }
    }

    public func addFilter(filter: IoFilter): Unit {
        ioFilterChain.addFilter(filter)
    }

    public func clearFilters() {
        ioFilterChain.clearFilters()
    }

    public func setMessageCompletedHandler(messageCompletedListener: MessageCompletedHandler) {
        ioFilterChain.setMessageCompletedHandler(messageCompletedListener)
    }

    public func getFilterChain() {
        return this.ioFilterChain
    }

    public func getThreadPool(): ThreadPool {
        return this.threadPool
    }

    public open func isStoped() {
        return !runningVal.load()
    }

    public open func stop() {
        // ThreadPool应该由外部关闭，此处不关闭ThreadPool
        if (!runningVal.compareAndSwap(true, false)) {
            return
        }
    }
}
