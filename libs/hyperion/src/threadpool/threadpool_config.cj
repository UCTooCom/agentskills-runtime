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
 * 线程池配置Bean
 *
 * @author yangfuping
 */
public open class ThreadPoolConfig {
    //线程池名称
    private var nameVal: String = "threadpool"

    public mut prop name: String {
        get() {
            nameVal
        }
        set(v) {
            this.nameVal = v
        }
    }

    //队列大小
    private var queueSizeVal: Int64 = 0

    public mut prop queueSize: Int64 {
        get() {
            queueSizeVal
        }
        set(v) {
            this.queueSizeVal = v
        }
    }

    //线程池中的最大线程数
    private var maxThreadsVal: Int64 = 0

    public mut prop maxThreads: Int64 {
        get() {
            maxThreadsVal
        }
        set(v) {
            this.maxThreadsVal = v
        }
    }

    //线程池中的最小线程数
    private var minThreadsVal: Int64 = 0

    public mut prop minThreads: Int64 {
        get() {
            minThreadsVal
        }
        set(v) {
            this.minThreadsVal = v
        }
    }

    //线程空闲超时时间
    private var threadIdleTimeoutVal: Duration = Duration.minute * 2

    public mut prop threadIdleTimeout: Duration {
        get() {
            threadIdleTimeoutVal
        }
        set(v) {
            this.threadIdleTimeoutVal = v
        }
    }
}
