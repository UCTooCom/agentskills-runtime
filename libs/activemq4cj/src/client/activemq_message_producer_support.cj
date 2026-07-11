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

public abstract class ActiveMQMessageProducerSupport <: MessageProducer {
    protected let session: ActiveMQSession
    private var disableMessageIDVal: Bool = false
    private var disableMessageTimestampVal: Bool
    private var defaultDeliveryModeVal: DeliveryMode
    private var defaultPriorityVal: Int32
    private var defaultTimeToLiveVal: Int64
    protected var sendTimeoutVal: Int32
    private var deliveryDelayVal: Int64 = 0

    public init(session: ActiveMQSession, sendTimeout: Int32) {
        this.session = session
        this.disableMessageTimestampVal = session.connection.disableTimeStampsByDefault
        this.defaultDeliveryModeVal = MessageConstants.DEFAULT_DELIVERY_MODE
        this.defaultPriorityVal = Int32(MessageConstants.DEFAULT_PRIORITY)
        this.defaultTimeToLiveVal = MessageConstants.DEFAULT_TIME_TO_LIVE
        this.sendTimeoutVal = sendTimeout
    }

    public static let CJMS_PROPERTY_NAMES_DISALLOWED: Array<String> = ["JMSDeliveryMode", "JMSPriority", "JMSMessageID",
        "JMSTimestamp", "JMSCorrelationID", "JMSType", "NULL", "TRUE", "FALSE", "NOT", "AND", "OR", "BETWEEN", "LIKE",
        "IN", "IS", "ESCAPE"]

    public static func validateValidPropertyName(propertyName: String) {
        if (propertyName.size == 0 || propertyName.trimAscii().size == 0) {
            throw IllegalArgumentException("Invalid CJMS property name must not be empty")
        }

        if (CJMS_PROPERTY_NAMES_DISALLOWED.contains(propertyName)) {
            throw IllegalArgumentException("Invalid CJMS property: ${propertyName} name is in disallowed list")
        }
    }

    public static func validateValidPropertyValue(propertyName: String, propertyValue: Any) {
        var invalid = checkValueValid(propertyValue)

        if (invalid) {
            throw MessageFormatException("Invalid CJMS property: ${propertyName}")
        }
    }

    private static func checkValueValid(value: Any): Bool {
        if (value is Bool || value is Byte || value is Int8 || value is Int16 || value is UInt16 || value is Int32 ||
            value is UInt32 || value is Int64 || value is UInt64 || value is Float32 || value is Float64 ||
            value is String) {
            return false
        }
        return true
    }

    public func send(message: CJMSMessage): Unit {
        this.send(this.destination, message, this.deliveryMode, this.priority, this.timeToLive)
    }

    public func send(message: CJMSMessage, deliveryMode: DeliveryMode, priority: Int32, timeToLive: Int64): Unit {
        this.send(this.destination, message, deliveryMode, priority, timeToLive)
    }

    public func send(destination: Destination, message: CJMSMessage): Unit {
        this.send(destination, message, this.deliveryMode, this.priority, this.timeToLive)
    }

    protected func checkClosed(): Unit

    public mut prop disableMessageID: Bool {
        get() {
            checkClosed()
            return this.disableMessageIDVal
        }
        set(value) {
            checkClosed()
            this.disableMessageIDVal = value
        }
    }

    public mut prop disableMessageTimestamp: Bool {
        get() {
            checkClosed()
            return this.disableMessageTimestampVal
        }
        set(value) {
            checkClosed()
            this.disableMessageTimestampVal = value
        }
    }

    public mut prop deliveryMode: DeliveryMode {
        get() {
            checkClosed()
            return this.defaultDeliveryModeVal
        }
        set(value) {
            checkClosed()
            this.defaultDeliveryModeVal = value
        }
    }

    public mut prop priority: Int32 {
        get() {
            checkClosed()
            return this.defaultPriorityVal
        }
        set(value) {
            if (value < 0 || value > 9) {
                throw IllegalStateException("Default priority must be a value between 0 and 9")
            }
            checkClosed()
            this.defaultPriorityVal = value
        }
    }

    public mut prop timeToLive: Int64 {
        get() {
            checkClosed()
            return this.defaultTimeToLiveVal
        }
        set(value) {
            if (value < 0) {
                throw IllegalStateException("Cannot set a negative timeToLive")
            }
            checkClosed()
            this.defaultTimeToLiveVal = value
        }
    }

    public mut prop sendTimeout: Int32 {
        get() {
            return this.sendTimeoutVal
        }
        set(value) {
            this.sendTimeoutVal = value
        }
    }

    public mut prop deliveryDelay: Int64 {
        get() {
            throw UnsupportedException("DeliveryDelay is not supported")
        }
        set(value) {
            throw UnsupportedException("DeliveryDelay is not supported")
        }
    }
}
