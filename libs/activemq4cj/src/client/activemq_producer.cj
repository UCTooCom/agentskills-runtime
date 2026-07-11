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

public class ActiveMQProducer <: CJMSProducer {
    private let activemqContext: ActiveMQContext
    private let activemqMessageProducer: ActiveMQMessageProducer

    private var correlationId: ?String = None
    private var deliveryMode: ?DeliveryMode = None
    private var disableMessageID: Bool = false
    private var disableMessageTimestamp: Bool = false
    private var priority: ?Int32 = None
    private var replyTo: ?Destination = None
    private var timeToLive: ?Int64 = None
    private var cjmsType: ?String = None

    private var messageProperties: ?HashMap<String, Any> = None

    init(activemqContext: ActiveMQContext, activemqMessageProducer: ActiveMQMessageProducer) {
        this.activemqContext = activemqContext
        this.activemqMessageProducer = activemqMessageProducer
    }

    public override func send(destination: Destination, message: CJMSMessage): CJMSProducer {
        if (let Some(correlationId) <- this.correlationId) {
            message.setCJMSCorrelationID(correlationId)
        }

        if (let Some(replyTo) <- this.replyTo) {
            message.setCJMSReplyTo(replyTo)
        }

        if (let Some(cjmsType) <- this.cjmsType) {
            message.setCJMSType(cjmsType)
        }

        if (let Some(messageProperties) <- messageProperties) {
            for ((k, v) in messageProperties) {
                message.setObjectProperty(k, v)
            }
        }

        activemqMessageProducer.send(destination, message, getDeliveryMode(), getPriority(), getTimeToLive(),
            getDisableMessageID(), getDisableMessageTimestamp(), None)
        return this
    }

    public override func send(destination: Destination, body: String): CJMSProducer {
        let textMessage: TextMessage = activemqContext.createTextMessage(body)
        send(destination, textMessage)
        return this
    }

    public override func send(destination: Destination, body: Map<String, Any>): CJMSProducer {
        var mapMessage: MapMessage = activemqContext.createMapMessage()

        for ((k, v) in body) {
            mapMessage.setObject(k, v)
        }

        send(destination, mapMessage)
        return this
    }

    public override func send(destination: Destination, body: Array<Byte>): CJMSProducer {
        var bytesMessage: BytesMessage = activemqContext.createBytesMessage()
        bytesMessage.writeBytes(body)

        send(destination, bytesMessage)
        return this
    }

    public override func send(destination: Destination, body: Serializable<Any>): CJMSProducer {
        var objectMessage: ObjectMessage = activemqContext.createObjectMessage(body)
        send(destination, objectMessage)
        return this
    }

    public override func setDisableMessageID(value: Bool): CJMSProducer {
        this.disableMessageID = value
        return this
    }

    public override func getDisableMessageID(): Bool {
        return this.disableMessageID
    }

    public override func setDisableMessageTimestamp(value: Bool): CJMSProducer {
        this.disableMessageTimestamp = value
        return this
    }

    public override func getDisableMessageTimestamp(): Bool {
        return this.disableMessageTimestamp
    }

    public override func setDeliveryMode(deliveryMode: DeliveryMode): CJMSProducer {
        this.deliveryMode = deliveryMode
        return this
    }

    public override func getDeliveryMode(): DeliveryMode {
        if (let Some(deliveryMode) <- this.deliveryMode) {
            return deliveryMode
        }
        return this.activemqMessageProducer.deliveryMode
    }

    public override func setPriority(priority: Int32): CJMSProducer {
        this.priority = priority
        return this
    }

    public override func getPriority(): Int32 {
        if (let Some(priority) <- this.priority) {
            return priority
        }
        return this.activemqMessageProducer.priority
    }

    public func setTimeToLive(timeToLive: Int64): CJMSProducer {
        this.timeToLive = timeToLive
        return this
    }

    public override func getTimeToLive(): Int64 {
        if (let Some(timeToLive) <- this.timeToLive) {
            return timeToLive
        }
        return this.activemqMessageProducer.timeToLive
    }

    public override func setDeliveryDelay(deliveryDelay: Int64): CJMSProducer {
        throw UnsupportedException("setDeliveryDelay(i64) is not supported")
    }

    public override func getDeliveryDelay(): Int64 {
        throw UnsupportedException("getDeliveryDelay() is not supported")
    }

    public override func setAsync(completionListener: CompletionListener): CJMSProducer {
        throw UnsupportedException("setAsync(CompletionListener) is not supported")
    }

    public override func getAsync(): CompletionListener {
        throw UnsupportedException("getAsync() is not supported")
    }

    public override func setProperty(name: String, value: Bool): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func setProperty(name: String, value: Byte): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func setProperty(name: String, value: Int16): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func setProperty(name: String, value: Int32): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func setProperty(name: String, value: Int64): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func setProperty(name: String, value: Float32): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func setProperty(name: String, value: Float64): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func setProperty(name: String, value: String): CJMSProducer {
        checkProperty(name, value)
        getCreatedMessageProperties().add(name, value)
        return this
    }

    public override func clearProperties(): CJMSProducer {
        getCreatedMessageProperties().clear()
        return this
    }

    public override func propertyExists(name: String): Bool {
        if (name.size == 0 || name.trimAscii().size == 0) {
            return false
        }
        return getCreatedMessageProperties().contains(name)
    }

    public override func getBoolProperty(name: String): Bool {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<Bool>())
            if (let Some(rc) <- (rc as Bool)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a Bool")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func getByteProperty(name: String): Byte {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<Byte>())
            if (let Some(rc) <- (rc as Byte)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a Byte")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func getInt16Property(name: String): Int16 {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<Int16>())
            if (let Some(rc) <- (rc as Int16)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a Int16")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func getInt32Property(name: String): Int32 {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<Int32>())
            if (let Some(rc) <- (rc as Int32)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a Int32")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func getInt64Property(name: String): Int64 {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<Int64>())
            if (let Some(rc) <- (rc as Int64)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a Int64")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func getFloat32Property(name: String): Float32 {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<Float32>())
            if (let Some(rc) <- (rc as Float32)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a Float32")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func getFloat64Property(name: String): Float64 {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<Float64>())
            if (let Some(rc) <- (rc as Float64)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a Float64")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func getStringProperty(name: String): String {
        var value = getCreatedMessageProperties().get(name)
        if (let Some(value) <- value) {
            var rc = TypeConversionSupport.convert(value, TypeInfo.of<String>())
            if (let Some(rc) <- (rc as String)) {
                return rc
            } else {
                throw MessageFormatException("Property ${name} cannot be read as a String")
            }
        } else {
            throw NoneValueException("Property ${name} was none")
        }
    }

    public override func setCJMSCorrelationID(correlationID: String): CJMSProducer {
        this.correlationId = correlationID
        return this
    }

    public override func getCJMSCorrelationID(): ?String {
        return this.correlationId
    }

    public override func setCJMSType(cjmsType: String): CJMSProducer {
        this.cjmsType = cjmsType
        return this
    }

    public override func getCJMSType(): ?String {
        return this.cjmsType
    }

    public override func setCJMSReplyTo(replyTo: Destination): CJMSProducer {
        this.replyTo = replyTo
        return this
    }

    public override func getCJMSReplyTo(): ?Destination {
        return this.replyTo
    }

    private func checkProperty(name: String, value: Any) {
        ActiveMQMessageProducerSupport.validateValidPropertyName(name)
        ActiveMQMessageProducerSupport.validateValidPropertyValue(name, value)
    }

    private func getCreatedMessageProperties(): HashMap<String, Any> {
        var properties: HashMap<String, Any>

        if (let Some(messageProperties) <- messageProperties) {
            properties = messageProperties
        } else {
            properties = HashMap<String, Any>()
            this.messageProperties = properties
        }
        return properties
    }
}
