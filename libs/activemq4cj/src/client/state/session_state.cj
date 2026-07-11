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
package activemq4cj.client.state

public class SessionState {
    private let infoVal: SessionInfo

    private let consumersVal: ConcurrentHashMap<ConsumerId, ConsumerInfo> = ConcurrentHashMap<ConsumerId, ConsumerInfo>(
    )
    private let producersVal: ConcurrentHashMap<ProducerId, ProducerInfo> = ConcurrentHashMap<ProducerId, ProducerInfo>(
    )

    public init(info: SessionInfo) {
        this.infoVal = info
    }

    public func addConsumer(info: ConsumerInfo): Unit {
        if (let Some(consumerId) <- info.consumerId) {
            consumersVal.put(consumerId, info)
        }
    }

    public func removeConsumer(id: ConsumerId): Unit {
        consumersVal.remove(id)
    }

    public prop consumers: ConcurrentHashMap<ConsumerId, ConsumerInfo> {
        get() {
            return this.consumersVal
        }
    }

    public func addProducer(info: ProducerInfo): Unit {
        if (let Some(producerId) <- info.producerId) {
            producersVal.put(producerId, info)
        }
    }

    public func removeProducer(id: ProducerId): Unit {
        producersVal.remove(id)
    }

    public prop producers: ConcurrentHashMap<ProducerId, ProducerInfo> {
        get() {
            return this.producersVal
        }
    }

    public prop info: SessionInfo {
        get() {
            return this.infoVal
        }
    }
}
