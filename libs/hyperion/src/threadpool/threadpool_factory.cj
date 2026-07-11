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
 * 线程池工厂
 *
 * @author yangfuping
 */
public open class ThreadPoolFactory {

    /**
     * Create thread pool.
     *
     * @param minThreads
     * @param maxThreads
     * @param queueSize
     * @param idleTimeout
     */
    public static func createThreadPool(minThreads: Int64, maxThreads: Int64, queueSize: Int64, idleTimeout: Duration): ThreadPool {
        let config: ThreadPoolConfig = ThreadPoolConfig()
        config.minThreads = minThreads
        config.maxThreads = maxThreads
        config.queueSize = queueSize
        config.threadIdleTimeout = idleTimeout
        return createThreadPool(config)
    }

    /**
     * Create thread pool.
     *
     * @param threadPoolConfig
     */
    public static func createThreadPool(threadPoolConfig: ThreadPoolConfig): ThreadPool {
        if (threadPoolConfig.minThreads < 0) {
            throw IllegalArgumentException(
                "Illegal minThreads param: ${threadPoolConfig.minThreads}, minThreads cannot be less than zero!")
        }

        if (threadPoolConfig.maxThreads <= 0) {
            throw IllegalArgumentException(
                "Illegal maxThreads param: ${threadPoolConfig.maxThreads}, maxThreads cannot be less than or equal to zero!"
            )
        }

        if (threadPoolConfig.maxThreads < threadPoolConfig.minThreads) {
            throw IllegalArgumentException(
                "Illegal maxThreads param: ${threadPoolConfig.maxThreads}, maxThreads cannot be less than minThreads ${threadPoolConfig.minThreads}!"
            )
        }

        if (threadPoolConfig.queueSize <= 0) {
            throw IllegalArgumentException(
                "Illegal queueSize param: ${threadPoolConfig.queueSize}, queueSize cannot be less than or equal to zero!"
            )
        }

        if (threadPoolConfig.threadIdleTimeout.toSeconds() <= 0) {
            throw IllegalArgumentException(
                "Illegal threadIdleTimeout param: ${threadPoolConfig.threadIdleTimeout}, threadIdleTimeout cannot be less than or equal to zero!"
            )
        }

        return ThreadPool(threadPoolConfig)
    }
}
