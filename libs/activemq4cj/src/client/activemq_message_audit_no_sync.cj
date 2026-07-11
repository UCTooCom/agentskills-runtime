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

public open class ActiveMQMessageAuditNoSync {
    public static let DEFAULT_WINDOW_SIZE: Int64 = 2048
    public static let MAXIMUM_PRODUCER_COUNT: Int64 = 64
    private var auditDepthVal: Int64
    private var maximumNumberOfProducersToTrackVal: Int64
    private let map: LRUCache<String, BitSetBin>

    public init() {
        this(Int64(DEFAULT_WINDOW_SIZE), Int64(MAXIMUM_PRODUCER_COUNT))
    }

    public init(auditDepth: Int64, maximumNumberOfProducersToTrack: Int64) {
        this.auditDepthVal = auditDepth
        this.maximumNumberOfProducersToTrackVal = maximumNumberOfProducersToTrack
        this.map = LRUCache<String, BitSetBin>(maximumNumberOfProducersToTrack)
    }

    /**
     * 检查消息是否出现过
     */
    public func isDuplicate(message: ?CJMSMessage): Bool {
        if (let Some(message) <- message) {
            return isDuplicate(message.getCJMSMessageID())
        }
        return false
    }

    /**
     * 检查id是否存在，并将其加入列表
     */
    public open func isDuplicate(id: ?String): Bool {
        var answer = false
        if (let Some(id) <- id) {
            var seed = IdGenerator.getSeedFromId(id)
            var bsb: BitSetBin
            if (let Some(bab) <- map.get(seed)) {
                bsb = bab
            } else {
                bsb = BitSetBin(auditDepth)
                map.add(seed, bsb)
            }
            var index = IdGenerator.getSequenceFromId(id)
            if (index >= 0) {
                answer = bsb.setBit(index, true)
            }
        }
        return answer
    }

    /**
     * 检查MessageId是否存在，并将其加入列表
     */
    public open func isDuplicate(id: ?MessageId): Bool {
        var answer = false
        if (let Some(id) <- id) {
            if (let Some(pid) <- id.producerId) {
                var bsb: BitSetBin
                if (let Some(bab) <- map.get(pid.toString())) {
                    bsb = bab
                } else {
                    bsb = BitSetBin(auditDepth)
                    map.add(pid.toString(), bsb)
                }
                answer = bsb.setBit(id.producerSequenceId, true)
            }
        }
        return answer
    }

    public open func rollback(id: ?String): Unit {
        if (let Some(id) <- id) {
            var seed = IdGenerator.getSeedFromId(id)
            if (let Some(bsb) <- map.get(seed)) {
                var index = IdGenerator.getSequenceFromId(id)
                if (index >= 0) {
                    bsb.setBit(index, false)
                }
            }
        }
    }

    public open func rollback(id: ?MessageId): Unit {
        if (let Some(id) <- id) {
            if (let Some(pid) <- id.producerId) {
                if (let Some(bsb) <- map.get(pid.toString())) {
                    bsb.setBit(id.producerSequenceId, false)
                }
            }
        }
    }

    public func isInOrder(message: CJMSMessage): Bool {
        return isInOrder(message.getCJMSMessageID())
    }

    public open func isInOrder(id: ?String): Bool {
        var answer = true

        if (let Some(id) <- id) {
            var seed = IdGenerator.getSeedFromId(id)
            if (let Some(bsb) <- map.get(seed)) {
                var index = IdGenerator.getSequenceFromId(id)
                if (index >= 0) {
                    answer = bsb.isInOrder(index)
                }
            }
        }
        return answer
    }

    public open func isInOrder(id: ?MessageId): Bool {
        var answer = true

        if (let Some(id) <- id) {
            if (let Some(pid) <- id.producerId) {
                var bsb: BitSetBin
                if (let Some(bab) <- map.get(pid.toString())) {
                    bsb = bab
                } else {
                    bsb = BitSetBin(auditDepth)
                    map.add(pid.toString(), bsb)
                }
                answer = bsb.isInOrder(id.producerSequenceId)
            }
        }
        return answer
    }

    public func getLastSeqId(id: ProducerId): Int64 {
        var result = -1
        if (let Some(bsb) <- map.get(id.toString())) {
            result = bsb.getLastSetIndex()
        }
        return result
    }

    public func clear(): Unit {
        map.clear()
    }

    public mut prop auditDepth: Int64 {
        get() {
            return this.auditDepthVal
        }
        set(value) {
            this.auditDepthVal = value
        }
    }

    public mut prop maximumNumberOfProducersToTrack: Int64 {
        get() {
            return this.maximumNumberOfProducersToTrackVal
        }
        set(value) {
            this.maximumNumberOfProducersToTrackVal = value

            if (value < this.maximumNumberOfProducersToTrack) {
                var newMap = LRUCache<String, BitSetBin>(value)

                newMap.add(all: this.map)
                this.map.clear()
                this.map.add(all: newMap)
            }
            this.map.maxCacheSize = value
            this.maximumNumberOfProducersToTrack = value
        }
    }
}
