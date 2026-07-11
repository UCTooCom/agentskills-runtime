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

public class ActiveMQPrefetchPolicy {
    private static let logger = LoggerFactory.getLogger("ActiveMQPrefetchPolicy")

    public static let MAX_PREFETCH_SIZE: Int32 = Int32(Int16.Max)
    public static let DEFAULT_QUEUE_PREFETCH: Int32 = 1000
    public static let DEFAULT_QUEUE_BROWSER_PREFETCH: Int32 = 500
    public static let DEFAULT_DURABLE_TOPIC_PREFETCH: Int32 = 100
    public static let DEFAULT_OPTIMIZE_DURABLE_TOPIC_PREFETCH: Int32 = 1000
    public static let DEFAULT_TOPIC_PREFETCH: Int32 = MAX_PREFETCH_SIZE

    private var queuePrefetchVal: Int32
    private var queueBrowserPrefetchVal: Int32
    private var topicPrefetchVal: Int32
    private var durableTopicPrefetchVal: Int32
    private var optimizeDurableTopicPrefetchVal: Int32
    private var maximumPendingMessageLimitVal: Int32 = 0

    public init() {
        this.queuePrefetchVal = DEFAULT_QUEUE_PREFETCH
        this.queueBrowserPrefetchVal = DEFAULT_QUEUE_BROWSER_PREFETCH
        this.topicPrefetchVal = DEFAULT_TOPIC_PREFETCH
        this.durableTopicPrefetchVal = DEFAULT_DURABLE_TOPIC_PREFETCH
        this.optimizeDurableTopicPrefetchVal = DEFAULT_OPTIMIZE_DURABLE_TOPIC_PREFETCH
    }

    private func getMaxPrefetchLimit(value: Int32): Int32 {
        var result = min(value, MAX_PREFETCH_SIZE)
        if (result < value) {
            logger.warn("maximum prefetch limit has been reset from ${value} to  ${MAX_PREFETCH_SIZE}")
        }
        return result
    }

    public func setAll(i: Int32): Unit {
        this.durableTopicPrefetch = getMaxPrefetchLimit(i)
        this.queueBrowserPrefetch = getMaxPrefetchLimit(i)
        this.queuePrefetch = getMaxPrefetchLimit(i)
        this.topicPrefetch = getMaxPrefetchLimit(i)
        this.optimizeDurableTopicPrefetch = getMaxPrefetchLimit(i)
    }

    public mut prop queuePrefetch: Int32 {
        get() {
            return this.queuePrefetchVal
        }
        set(value) {
            this.queuePrefetchVal = value
        }
    }

    public mut prop queueBrowserPrefetch: Int32 {
        get() {
            return this.queueBrowserPrefetchVal
        }
        set(value) {
            this.queueBrowserPrefetchVal = value
        }
    }

    public mut prop topicPrefetch: Int32 {
        get() {
            return this.topicPrefetchVal
        }
        set(value) {
            this.topicPrefetchVal = value
        }
    }

    public mut prop durableTopicPrefetch: Int32 {
        get() {
            return this.durableTopicPrefetchVal
        }
        set(value) {
            this.durableTopicPrefetchVal = value
        }
    }

    public mut prop optimizeDurableTopicPrefetch: Int32 {
        get() {
            return this.optimizeDurableTopicPrefetchVal
        }
        set(value) {
            this.optimizeDurableTopicPrefetchVal = value
        }
    }

    public mut prop maximumPendingMessageLimit: Int32 {
        get() {
            return this.maximumPendingMessageLimitVal
        }
        set(value) {
            this.maximumPendingMessageLimitVal = value
        }
    }
}
