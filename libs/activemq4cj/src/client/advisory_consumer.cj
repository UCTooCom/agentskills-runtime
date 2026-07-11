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

public class AdvisoryConsumer <: ActiveMQDispatcher {
    protected static let logger = LoggerFactory.getLogger("AdvisoryConsumer")

    private var deliveredCounter: Int32 = 0

    private let connection: ActiveMQConnection
    private let info: ConsumerInfo
    private var closed = false

    private let monitor = ReentrantMutex()

    public init(connection: ActiveMQConnection, consumerId: ConsumerId) {
        this.connection = connection
        info = ConsumerInfo()
        info.consumerId = consumerId
        info.destination = AdvisorySupport.TEMP_DESTINATION_COMPOSITE_ADVISORY_TOPIC
        info.prefetchSize = 1000
        info.noLocal = true
        info.dispatchAsync = true

        this.connection.addDispatcher(consumerId, this)
        this.connection.syncSendPacket(this.info)
    }

    public func dispose(): Unit {
        synchronized(monitor) {
            if (!closed) {
                try {
                    this.connection.asyncSendPacket(info.createRemoveInfo())
                } catch (e: CJMSException) {
                    logger.debug("Failed to send remove command: ${e}", e)
                }
                if (let Some(consumerId) <- info.consumerId) {
                    this.connection.removeDispatcher(consumerId)
                }
                closed = true
            }
        }
    }

    public override func dispatch(md: MessageDispatch): Unit {
        // 达到预取的75%时自动确认
        deliveredCounter++
        if (Float64(deliveredCounter) > (0.75 * Float64(info.prefetchSize))) {
            try {
                var ack: MessageAck = MessageAck(md, MessageAck.STANDARD_ACK_TYPE, deliveredCounter)
                connection.asyncSendPacket(ack)
                deliveredCounter = 0
            } catch (e: CJMSException) {
                connection.onClientInternalException(e)
            }
        }

        if (let Some(message) <- md.message) {
            if (let Some(ds) <- message.dataStructure) {
                if (let Some(destinationInfo) <- (ds as DestinationInfo)) {
                    processDestinationInfo(destinationInfo)
                } else {
                    if (logger.isDebugEnabled()) {
                        logger.debug("Unexpected message was dispatched to the AdvisoryConsumer: ${md}")
                    }
                }
            }
        }
    }

    private func processDestinationInfo(dinfo: DestinationInfo): Unit {
        if (let Some(dest) <- dinfo.destination) {
            if (let Some(tempDest) <- (dest as ActiveMQTempDestination)) {
                var tempDestCopy: ?ActiveMQTempDestination = tempDest
                if (dinfo.operationType == DestinationInfo.ADD_OPERATION_TYPE) {
                    if (let Some(connection) <- tempDest.connection) {
                        if (let Some(name) <- tempDest.name) {
                            tempDestCopy = tempDest.createDestinationByName(name) as ActiveMQTempDestination
                        }
                    }
                    if (let Some(tempDestCopy) <- tempDestCopy) {
                        connection.activeTempDestinations.add(tempDestCopy)
                    }
                } else if (dinfo.operationType == DestinationInfo.REMOVE_OPERATION_TYPE) {
                    connection.activeTempDestinations.remove(tempDest)
                }
            }
        }
    }

    public operator func ==(other: ActiveMQDispatcher): Bool {
        if (!(other is AdvisoryConsumer)) {
            return false
        }
        if (let Some(other) <- (other as AdvisoryConsumer)) {
            if (this.info != other.info) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: ActiveMQDispatcher): Bool {
        if (!(other is AdvisoryConsumer)) {
            return true
        }
        if (let Some(other) <- (other as AdvisoryConsumer)) {
            if (this.info != other.info) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        return this.info.hashCode()
    }
}
