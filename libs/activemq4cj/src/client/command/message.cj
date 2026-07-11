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
package activemq4cj.client.command

public abstract class Message <: BaseCommand & MarshallAware {
    public static let DEFAULT_MINIMUM_MESSAGE_SIZE: Int64 = 1024
    public static let ORIGINAL_EXPIRATION: String = "originalExpiration"

    //持有IConnection，判断是否启用useCompression
    private var connectionVal: ?IConnection = None

    public mut prop connection: ?IConnection {
        get() {
            return this.connectionVal
        }
        set(value) {
            this.connectionVal = value
        }
    }

    /**
     * 把消息的内容设置到content字段中
     */
    public func storeContent(): Unit

    public open func copy(): Message

    protected func copy(copy: Message) {
        super.copy(copy)
        copy.producerId = producerId
        copy.transactionId = transactionId
        copy.destination = destination
        if (let Some(messageId) <- messageId) {
            copy.messageId = messageId.copy()
        }
        copy.originalDestination = originalDestination
        copy.originalTransactionId = originalTransactionId
        copy.deliveryTime = deliveryTime
        copy.expiration = expiration
        copy.timestamp = timestamp
        copy.correlationId = correlationId
        copy.replyTo = replyTo
        copy.persistent = persistent
        copy.redeliveryCounter = redeliveryCounter
        copy.messageType = messageType
        copy.priority = priority
        copy.size = size
        copy.groupID = groupID
        copy.userID = userID
        copy.groupSequence = groupSequence

        copy.connection = connection

        if (let Some(properties) <- properties) {
            let copyMap = HashMap<String, Any>(properties)

            // The new message hasn't expired, so remove this feild.
            copyMap.remove(ORIGINAL_EXPIRATION)
            copy.properties = copyMap
        } else {
            copy.properties = properties
        }

        if (let Some(content) <- content) {
            copy.content = content.clone()
        }
        if (let Some(marshalledProperties) <- marshalledProperties) {
            copy.marshalledProperties = marshalledProperties.clone()
        }
        copy.dataStructure = dataStructure
        copy.readOnlyProperties = readOnlyProperties
        copy.readOnlyBody = readOnlyBody
        copy.compressed = compressed
        copy.recievedByDFBridge = recievedByDFBridge

        copy.arrival = arrival
        copy.brokerInTime = brokerInTime
        copy.brokerOutTime = brokerOutTime
        copy.brokerPath = brokerPath
        copy.jmsXGroupFirstForConsumer = jmsXGroupFirstForConsumer
    }

    private var messageIdVal: ?MessageId = None
    public mut prop messageId: ?MessageId {
        get() {
            return this.messageIdVal
        }
        set(value) {
            this.messageIdVal = value
        }
    }

    private var originalDestinationVal: ?ActiveMQDestination = None
    public mut prop originalDestination: ?ActiveMQDestination {
        get() {
            return this.originalDestinationVal
        }
        set(value) {
            this.originalDestinationVal = value
        }
    }

    private var originalTransactionIdVal: ?TransactionId = None
    public mut prop originalTransactionId: ?TransactionId {
        get() {
            return this.originalTransactionIdVal
        }
        set(value) {
            this.originalTransactionIdVal = value
        }
    }

    private var producerIdVal: ?ProducerId = None
    public mut prop producerId: ?ProducerId {
        get() {
            return this.producerIdVal
        }
        set(value) {
            this.producerIdVal = value
        }
    }

    private var destinationVal: ?ActiveMQDestination = None
    public mut prop destination: ?ActiveMQDestination {
        get() {
            return this.destinationVal
        }
        set(value) {
            this.destinationVal = value
        }
    }

    private var transactionIdVal: ?TransactionId = None
    public mut prop transactionId: ?TransactionId {
        get() {
            return this.transactionIdVal
        }
        set(value) {
            this.transactionIdVal = value
        }
    }

    private var deliveryTimeVal: Int64 = 0
    public mut prop deliveryTime: Int64 {
        get() {
            return this.deliveryTimeVal
        }
        set(value) {
            this.deliveryTimeVal = value
        }
    }

    private var expirationVal: Int64 = 0
    public mut prop expiration: Int64 {
        get() {
            return this.expirationVal
        }
        set(value) {
            this.expirationVal = value
        }
    }

    private var timestampVal: Int64 = 0
    public mut prop timestamp: Int64 {
        get() {
            return this.timestampVal
        }
        set(value) {
            this.timestampVal = value
        }
    }

    private var arrivalVal: Int64 = 0
    public mut prop arrival: Int64 {
        get() {
            return this.arrivalVal
        }
        set(value) {
            this.arrivalVal = value
        }
    }

    private var brokerInTimeVal: Int64 = 0
    public mut prop brokerInTime: Int64 {
        get() {
            return this.brokerInTimeVal
        }
        set(value) {
            this.brokerInTimeVal = value
        }
    }

    private var brokerOutTimeVal: Int64 = 0
    public mut prop brokerOutTime: Int64 {
        get() {
            return this.brokerOutTimeVal
        }
        set(value) {
            this.brokerOutTimeVal = value
        }
    }

    private var correlationIdVal: ?String = None
    public mut prop correlationId: ?String {
        get() {
            return this.correlationIdVal
        }
        set(value) {
            this.correlationIdVal = value
        }
    }

    private var replyToVal: ?ActiveMQDestination = None
    public mut prop replyTo: ?ActiveMQDestination {
        get() {
            return this.replyToVal
        }
        set(value) {
            this.replyToVal = value
        }
    }

    private var persistentVal: Bool = false
    public mut prop persistent: Bool {
        get() {
            return this.persistentVal
        }
        set(value) {
            this.persistentVal = value
        }
    }

    private var typeVal: ?String = None
    public mut prop messageType: ?String {
        get() {
            return this.typeVal
        }
        set(value) {
            this.typeVal = value
        }
    }

    private var priorityVal: Byte = UInt8(4)
    public mut prop priority: Byte {
        get() {
            return this.priorityVal
        }
        set(value) {
            this.priorityVal = value
        }
    }

    private var groupIDVal: ?String = None
    public mut prop groupID: ?String {
        get() {
            return this.groupIDVal
        }
        set(value) {
            this.groupIDVal = value
        }
    }

    private var groupSequenceVal: Int32 = Int32(0)
    public mut prop groupSequence: Int32 {
        get() {
            return this.groupSequenceVal
        }
        set(value) {
            this.groupSequenceVal = value
        }
    }

    private var targetConsumerIdVal: ?ConsumerId = None
    public mut prop targetConsumerId: ?ConsumerId {
        get() {
            return this.targetConsumerIdVal
        }
        set(value) {
            this.targetConsumerIdVal = value
        }
    }

    private var compressedVal: Bool = false
    public mut prop compressed: Bool {
        get() {
            return this.compressedVal
        }
        set(value) {
            this.compressedVal = value
        }
    }

    private var userIDVal: ?String = None
    public mut prop userID: ?String {
        get() {
            return this.userIDVal
        }
        set(value) {
            this.userIDVal = value
        }
    }

    private var contentVal: ?Array<Byte> = None
    public mut prop content: ?Array<Byte> {
        get() {
            return this.contentVal
        }
        set(value) {
            this.contentVal = value
        }
    }

    private var marshalledPropertiesVal: ?Array<Byte> = None
    public mut prop marshalledProperties: ?Array<Byte> {
        get() {
            return this.marshalledPropertiesVal
        }
        set(value) {
            this.marshalledPropertiesVal = value
        }
    }

    private var dataStructureVal: ?DataStructure = None
    public mut prop dataStructure: ?DataStructure {
        get() {
            return this.dataStructureVal
        }
        set(value) {
            this.dataStructureVal = value
        }
    }

    public func isRedelivered(): Bool {
        return redeliveryCounter > 0
    }

    public func setRedelivered(redelivered: Bool) {
        if (redelivered) {
            if (!isRedelivered()) {
                redeliveryCounter = 1
            }
        } else {
            if (isRedelivered()) {
                redeliveryCounter = 1
            }
        }
    }

    private var redeliveryCounterVal: Int32 = 0
    public mut prop redeliveryCounter: Int32 {
        get() {
            return this.redeliveryCounterVal
        }
        set(value) {
            this.redeliveryCounterVal = value
        }
    }

    private var sizeVal: Int64 = 0
    private mut prop size: Int64 {
        get() {
            return this.sizeVal
        }
        set(value) {
            this.sizeVal = value
        }
    }

    private var droppableVal: Bool = false
    public mut prop droppable: Bool {
        get() {
            return this.droppableVal
        }
        set(value) {
            this.droppableVal = value
        }
    }

    private var jmsXGroupFirstForConsumerVal: Bool = false
    public mut prop jmsXGroupFirstForConsumer: Bool {
        get() {
            return this.jmsXGroupFirstForConsumerVal
        }
        set(value) {
            this.jmsXGroupFirstForConsumerVal = value
        }
    }

    private var brokerPathVal: ?Array<BrokerId> = None
    public mut prop brokerPath: ?Array<BrokerId> {
        get() {
            return this.brokerPathVal
        }
        set(value) {
            this.brokerPathVal = value
        }
    }

    private var clusterVal: ?Array<BrokerId> = None
    public mut prop cluster: ?Array<BrokerId> {
        get() {
            return this.clusterVal
        }
        set(value) {
            this.clusterVal = value
        }
    }

    private var recievedByDFBridgeVal: Bool = false
    public mut prop recievedByDFBridge: Bool {
        get() {
            return this.recievedByDFBridgeVal
        }
        set(value) {
            this.recievedByDFBridgeVal = value
        }
    }

    private var readOnlyBodyVal: Bool = false
    public mut prop readOnlyBody: Bool {
        get() {
            return this.readOnlyBodyVal
        }
        set(value) {
            this.readOnlyBodyVal = value
        }
    }

    private var readOnlyPropertiesVal: Bool = false
    public mut prop readOnlyProperties: Bool {
        get() {
            return this.readOnlyPropertiesVal
        }
        set(value) {
            this.readOnlyPropertiesVal = value
        }
    }

    private var propertiesVal: ?HashMap<String, Any> = None
    public mut prop properties: ?HashMap<String, Any> {
        get() {
            return this.propertiesVal
        }
        set(value) {
            this.propertiesVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return true
    }

    public func getSize(): Int64 {
        if (size < DEFAULT_MINIMUM_MESSAGE_SIZE || size == 0) {
            size = DEFAULT_MINIMUM_MESSAGE_SIZE
            if (let Some(marshalledProperties) <- marshalledProperties) {
                size += marshalledProperties.size
            }
            if (let Some(content) <- content) {
                size += content.size
            }
        }
        return size
    }

    public open func clearProperties(): Unit {
        marshalledProperties = None
        properties = None
    }

    public func setProperty(name: String, value: Any) {
        lazyCreateProperties()
        if (let Some(properties) <- this.properties) {
            properties.add(name, value)
        }
    }

    public func getProperty(name: String): ?Any {
        match (name) {
            case "JMSDestination" =>
                var dest = originalDestination
                if (dest.isNone()) {
                    dest = destination
                }
                if (let Some(dest) <- dest) {
                    return dest.toString()
                } else {
                    return None
                }
            case "JMSXDeliveryCount" => return this.redeliveryCounter + 1
            case "JMSReplyTo" =>
                if (let Some(replyTo) <- replyTo) {
                    return replyTo.toString()
                }
                return None
            case "JMSType" =>
                if (let Some(messageType) <- messageType) {
                    return messageType
                }
                return None
            case "JMSDeliveryMode" =>
                if (persistent) {
                    return "PERSISTENT"
                }
                return "NON_PERSISTENT"
            case "JMSPriority" => return priority
            case "JMSMessageID" =>
                if (let Some(messageId) <- messageId) {
                    return messageId.toString()
                }
                return None
            case "JMSTimestamp" => return timestamp
            case "JMSCorrelationID" =>
                if (let Some(correlationId) <- correlationId) {
                    return correlationId
                }
                return None
            case "JMSExpiration" => return expiration
            case "JMSRedelivered" => return isRedelivered
            case "JMSXGroupID" =>
                if (let Some(groupID) <- groupID) {
                    return groupID
                }
                return None
            case "JMSXUserID" =>
                if (let Some(userID) <- userID) {
                    return userID
                }
                return None
            case "JMSXGroupSeq" => return groupSequence
            case "JMSXProducerTXID" =>
                var txId = originalTransactionId
                if (txId.isNone()) {
                    txId = transactionId
                }
                if (let Some(txId) <- txId) {
                    return txId.toString()
                }
                return None
            case "JMSActiveMQBrokerInTime" => return brokerInTime
            case "JMSActiveMQBrokerOutTime" => return brokerOutTime
            case "JMSActiveMQBrokerPath" =>
                if (let Some(brokerPath) <- brokerPath) {
                    return brokerPath.toString()
                }
                return None
            case "JMSXGroupFirstForConsumer" => return jmsXGroupFirstForConsumer
            case _ =>
                if (let Some(properties) <- this.properties) {
                    return properties.get(name)
                } else {
                    if (let Some(marshalledProperties) <- this.marshalledProperties) {
                        this.properties = MarshallingSupport.unmarshalPrimitiveMap(
                            ByteBuffer.wrap(marshalledProperties))
                        this.marshalledProperties = None
                        return getProperty(name)
                    } else {
                        return None
                    }
                }
        }
    }

    protected func lazyCreateProperties(): Unit {
        if (properties.isNone()) {
            if (let Some(marshalledProperties) <- this.marshalledProperties) {
                properties = MarshallingSupport.unmarshalPrimitiveMap(ByteBuffer.wrap(marshalledProperties))
                this.marshalledProperties = None
            } else {
                properties = HashMap<String, Any>()
            }
        } else {
            marshalledProperties = None
        }
    }

    public open func beforeMarshall(): Unit {
        // Need to marshal the properties.
        if (marshalledProperties.isNone() && properties.isSome()) {
            if (let Some(properties) <- properties) {
                let byteBuffer = ByteBuffer.allocate(8192, expandSupport: true)
                MarshallingSupport.marshalPrimitiveMap(properties, byteBuffer)
                byteBuffer.flip()
                marshalledProperties = byteBuffer.toArray()
            }
        }
    }

    public override func afterMarshall(): Unit {
    }

    public override func beforeUnmarshall(): Unit {
    }

    public override func afterUnmarshall(): Unit {
    }

    /**
     * 消息是否过期
     */
    public func isExpired(): Bool {
        return expiration > 0 && DateTime.now() > DateTime.fromUnixTimeStamp(Duration.millisecond * expiration)
    }

    public func onMessageRolledBack(): Unit {
        this.redeliveryCounter++
    }

    public func checkEquals(other: Message): Bool {
        if (this.messageIdVal != other.messageIdVal) {
            return false
        }

        if (this.originalDestinationVal != other.originalDestinationVal) {
            return false
        }

        if (this.originalTransactionIdVal != other.originalTransactionIdVal) {
            return false
        }

        if (this.producerIdVal != other.producerIdVal) {
            return false
        }

        if (this.destinationVal != other.destinationVal) {
            return false
        }

        if (this.transactionIdVal != other.transactionIdVal) {
            return false
        }

        if (this.expirationVal != other.expirationVal) {
            return false
        }

        if (this.timestampVal != other.timestampVal) {
            return false
        }

        if (this.arrivalVal != other.arrivalVal) {
            return false
        }

        if (this.brokerInTimeVal != other.brokerInTimeVal) {
            return false
        }

        if (this.brokerOutTimeVal != other.brokerOutTimeVal) {
            return false
        }

        if (this.correlationIdVal != other.correlationIdVal) {
            return false
        }

        if (this.replyToVal != other.replyToVal) {
            return false
        }

        if (this.persistentVal != other.persistentVal) {
            return false
        }

        if (this.typeVal != other.typeVal) {
            return false
        }

        if (this.priorityVal != other.priorityVal) {
            return false
        }

        if (this.groupIDVal != other.groupIDVal) {
            return false
        }

        if (this.groupSequenceVal != other.groupSequenceVal) {
            return false
        }

        if (this.targetConsumerIdVal != other.targetConsumerIdVal) {
            return false
        }

        if (this.compressedVal != other.compressedVal) {
            return false
        }

        if (this.userIDVal != other.userIDVal) {
            return false
        }

        if (this.contentVal != other.contentVal) {
            return false
        }

        if (this.marshalledPropertiesVal != other.marshalledPropertiesVal) {
            return false
        }
        if (this.dataStructureVal != other.dataStructureVal) {
            return false
        }

        if (this.redeliveryCounterVal != other.redeliveryCounterVal) {
            return false
        }

        if (this.droppableVal != other.droppableVal) {
            return false
        }

        if (this.jmsXGroupFirstForConsumerVal != other.jmsXGroupFirstForConsumerVal) {
            return false
        }

        if (let Some(brokerPath) <- this.brokerPathVal) {
            if (let Some(otherBrokerPath) <- other.brokerPathVal) {
                if (brokerPath.size != otherBrokerPath.size) {
                    return false
                }
                for (i in 0..brokerPath.size) {
                    if (brokerPath[i] != otherBrokerPath[i]) {
                        return false
                    }
                }
            } else {
                return false
            }
        } else {
            if (other.brokerPathVal.isSome()) {
                return false
            }
        }

        if (let Some(cluster) <- this.clusterVal) {
            if (let Some(otherCluster) <- other.clusterVal) {
                if (cluster.size != otherCluster.size) {
                    return false
                }
                for (i in 0..cluster.size) {
                    if (cluster[i] != otherCluster[i]) {
                        return false
                    }
                }
            } else {
                return false
            }
        } else {
            if (other.clusterVal.isSome()) {
                return false
            }
        }

        if (this.recievedByDFBridgeVal != other.recievedByDFBridgeVal) {
            return false
        }

        if (!super.checkEquals(other)) {
            return false
        }
        return true
    }

    public open func toString(): String {
        let sb = StringBuilder()
        sb.append("Message: {${super.toString()},")
        sb.append(
            "producerId: ${producerIdVal},destination: ${destinationVal},transactionId: ${transactionIdVal},originalDestination: ${originalDestinationVal},"
        )
        sb.append(
            "messageId: ${messageIdVal},originalTransactionId: ${originalTransactionIdVal},groupID: ${groupIDVal},groupSequence: ${groupSequenceVal},correlationId: ${correlationId},"
        )
        sb.append(
            "persistent: ${persistentVal},expiration: ${expirationVal},priority: ${priorityVal},replyTo: ${replyToVal},timestamp: ${timestampVal},type: ${messageType},"
        )
        sb.append(
            "content: ${contentVal},marshalledProperties: ${marshalledPropertiesVal},dataStructure: ${dataStructureVal}, targetConsumerId: ${targetConsumerIdVal},compressed: ${compressedVal},"
        )
        sb.append(
            "redeliveryCounter: ${redeliveryCounterVal},brokerPath: ${brokerPathVal},arrival: ${arrivalVal},userID: ${userIDVal},recievedByDFBridge: ${recievedByDFBridgeVal},"
        )
        sb.append(
            "droppable: ${droppableVal},cluster: ${clusterVal},brokerInTime: ${brokerInTimeVal},brokerOutTime: ${brokerOutTimeVal},jmsXGroupFirstForConsumer: ${jmsXGroupFirstForConsumerVal}"
        )
        sb.append("}")
        return sb.toString()
    }
}

public open class ActiveMQMessage <: Message & CJMSMessage {
    public static let DLQ_DELIVERY_FAILURE_CAUSE_PROPERTY = "dlqDeliveryFailureCause"
    private static let NON_PERSISTENT: Int32 = 1
    private static let PERSISTENT: Int32 = 2

    protected var acknowledgeCallbackVal: ?Callback = None

    public open func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_MESSAGE
    }

    public open func copy(): Message {
        let copy: ActiveMQMessage = ActiveMQMessage()
        this.copy(copy)
        return copy
    }

    protected func copy(copy: ActiveMQMessage) {
        super.copy(copy)
        copy.acknowledgeCallback = acknowledgeCallback
    }

    public open operator func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQMessage)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQMessage)) {
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public open operator func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQMessage)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQMessage)) {
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public open func storeContent(): Unit {
    }

    /**
     * 压缩数据
     */
    protected func doCompress(arr: Array<Byte>): Array<Byte> {
        var rc = arr
        if (let Some(connection) <- connection) {
            if (connection.isUseCompression()) {
                compressed = true

                let stream = ByteArrayStream()
                var compressOutputStream: CompressOutputStream = CompressOutputStream(stream)

                compressOutputStream.write(rc)
                compressOutputStream.flush()
                compressOutputStream.close()

                rc = Array<Byte>(stream.length, repeat: 0)
                stream.read(rc)
            }
        }
        return rc
    }

    /**
     * 解压缩数据
     */
    protected func doDecompress(arr: Array<Byte>): Array<Byte> {
        var rc = arr
        if (let Some(connection) <- connection) {
            if (connection.isUseCompression()) {
                let stream = ByteArrayStream()
                var decompressOutStream = DecompressOutputStream(stream)

                decompressOutStream.write(rc)
                decompressOutStream.flush()
                decompressOutStream.close()

                rc = Array<Byte>(stream.length, repeat: 0)
                stream.read(rc)
            }
        }
        return rc
    }

    public open func onSend(): Unit {
        readOnlyBody = true
        readOnlyProperties = true
    }

    public override func acknowledge(): Unit {
        if (let Some(acknowledgeCallback) <- acknowledgeCallback) {
            try {
                acknowledgeCallback.execute()
            } catch (e: CJMSException) {
                throw e
            } catch (e: Exception) {
                throw CJMSException(e.message)
            }
        }
    }

    public open func clearBody(): Unit {
        this.content = None
        readOnlyBody = false
    }

    public override func clearProperties(): Unit {
        super.clearProperties()
        readOnlyProperties = false
    }

    public override func getPropertyNames(): ?LinkedList<String> {
        if (let Some(properties) <- properties) {
            let keys = properties.keys()
            return LinkedList<String>(keys.toArray())
        } else {
            if (let Some(marshalledProperties) <- this.marshalledProperties) {
                this.properties = MarshallingSupport.unmarshalPrimitiveMap(ByteBuffer.wrap(marshalledProperties))
                this.marshalledProperties = None
                return getPropertyNames()
            }
        }
        return None
    }

    public override func propertyExists(name: String): Bool {
        return getProperty(name).isSome()
    }

    public override func setCJMSCorrelationID(correlationID: ?String): Unit {
        this.correlationId = correlationID
    }

    public override func getCJMSCorrelationID(): ?String {
        return this.correlationId
    }

    public override func setCJMSDestination(destination: ?Destination): Unit {
        if (let Some(destination) <- destination) {
            this.destination = ActiveMQDestination.transform(destination)
        } else {
            this.destination = None
        }
    }

    public override func getCJMSDestination(): ?Destination {
        if (let Some(destination) <- this.destination) {
            return Some(destination)
        }
        return None
    }

    public override func setCJMSMessageID(id: ?String): Unit {
        if (let Some(id) <- id) {
            try {
                this.messageId = MessageId(id)
            } catch (e: IllegalArgumentException) {
                let messageId = MessageId()
                messageId.textView = id
                this.messageId = messageId
            }
        } else {
            this.messageId = None
        }
    }

    public override func getCJMSMessageID(): ?String {
        if (let Some(messageId) <- messageId) {
            return messageId.toString()
        }
        return None
    }

    public override func setCJMSDeliveryMode(deliveryMode: DeliveryMode): Unit {
        this.persistent = match (deliveryMode) {
            case PERSISTENT => true
            case NON_PERSISTENT => false
        }
    }

    public override func getCJMSDeliveryMode(): DeliveryMode {
        if (persistent) {
            return DeliveryMode.PERSISTENT
        }
        return DeliveryMode.NON_PERSISTENT
    }

    public override func setCJMSPriority(priority: Int32): Unit {
        var rc = priority
        if (priority < 0) {
            rc = 0
        } else if (priority > 9) {
            rc = 9
        }
        this.priority = UInt8(rc)
    }

    public override func getCJMSPriority(): Int32 {
        return Int32(this.priority)
    }

    public override func setCJMSRedelivered(redelivered: Bool): Unit {
        this.setRedelivered(redelivered)
    }

    public override func getCJMSRedelivered(): Bool {
        return this.isRedelivered()
    }

    public override func setCJMSReplyTo(replyTo: ?Destination): Unit {
        if (let Some(replyTo) <- replyTo) {
            this.replyTo = ActiveMQDestination.transform(replyTo)
        } else {
            this.replyTo = None
        }
    }

    public override func getCJMSReplyTo(): ?Destination {
        if (let Some(replyTo) <- this.replyTo) {
            return replyTo
        }
        return None
    }

    public override func setCJMSTimestamp(timestamp: Int64): Unit {
        this.timestamp = timestamp
    }

    public override func getCJMSTimestamp(): Int64 {
        return this.timestamp
    }

    public override func setCJMSType(CJMSType: ?String): Unit {
        this.messageType = CJMSType
    }

    public override func getCJMSType(): ?String {
        return this.messageType
    }

    public override func setCJMSDeliveryTime(deliveryTime: Int64): Unit {
        this.deliveryTime = deliveryTime
    }

    public override func getCJMSDeliveryTime(): Int64 {
        return this.deliveryTime
    }

    public override func setCJMSExpiration(expiration: Int64): Unit {
        this.expiration = expiration
    }

    public override func getCJMSExpiration(): Int64 {
        return this.expiration
    }

    public override func setBoolProperty(name: String, value: Bool): Unit {
        setObjectProperty(name, value)
    }

    public func getBoolProperty(name: String): Bool {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Bool>(value, TypeInfo.of<Bool>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a Bool")
            }
        }
        return false
    }

    public override func setByteProperty(name: String, value: Byte): Unit {
        setObjectProperty(name, value)
    }

    public override func getByteProperty(name: String): Byte {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Byte>(value, TypeInfo.of<Byte>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a Byte")
            }
        }
        throw NoneValueException("Property: ${name} was none")
    }

    public override func setFloat32Property(name: String, value: Float32): Unit {
        setObjectProperty(name, value)
    }

    public override func getFloat32Property(name: String): Float32 {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Float32>(value, TypeInfo.of<Float32>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a Float32")
            }
        }
        throw NoneValueException("Property: ${name} was none")
    }

    public override func setFloat64Property(name: String, value: Float64): Unit {
        setObjectProperty(name, value)
    }

    public override func getFloat64Property(name: String): Float64 {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Float64>(value, TypeInfo.of<Float64>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a Float64")
            }
        }
        throw NoneValueException("Property: ${name} was none")
    }

    public override func setInt16Property(name: String, value: Int16): Unit {
        setObjectProperty(name, value)
    }

    public func getInt16Property(name: String): Int16 {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Int16>(value, TypeInfo.of<Int16>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a Int16")
            }
        }
        throw NoneValueException("Property: ${name} was none")
    }

    public func setInt32Property(name: String, value: Int32): Unit {
        setObjectProperty(name, value)
    }

    public func getInt32Property(name: String): Int32 {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Int32>(value, TypeInfo.of<Int32>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a Int32")
            }
        }
        throw NoneValueException("Property: ${name} was none")
    }

    public override func setInt64Property(name: String, value: Int64): Unit {
        setObjectProperty(name, value)
    }

    public override func getInt64Property(name: String): Int64 {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Int64>(value, TypeInfo.of<Int64>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a Int64")
            }
        }
        throw NoneValueException("Property: ${name} was none")
    }

    public override func setStringProperty(name: String, value: String): Unit {
        setObjectProperty(name, value)
    }

    public override func getStringProperty(name: String): String {
        let value = getProperty(name)
        if (let Some(value) <- value) {
            if (let Some(s) <- (value as Option<String>)) {
                if (let Some(str) <- s) {
                    return str
                }
            }

            try {
                return TypeConversionSupport.genericConvert<String>(value, TypeInfo.of<String>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property: ${name} cannot be read as a String")
            }
        }
        throw NoneValueException("Property: ${name} was none")
    }

    public func checkValidObject(value: Any) {
        // 允许设置None<Any>
        if (let Some(value) <- (value as Option<Any>)) {
            if (value.isNone()) {
                return
            }
        }

        //根据JMS2.0规范，属性值只能是Bool,Byte,Int16,Int32,Int64,Float32,Float64,String这些原始类型
        if (!(value is Bool || value is Byte || value is Int16 || value is Int32 || value is Int64 || value is Float32 ||
            value is Float64 || value is String || value is Rune)) {
            throw MessageFormatException("Only objectified primitive objects and String types")
        }
    }

    public override func getObjectProperty(name: String): Any {
        if (let Some(value) <- getProperty(name)) {
            return value
        }
        return None<Any>
    }

    public override func setObjectProperty(name: String, value: Any): Unit {
        checkValidObject(value)
        setObjectProperty(name, value, true)
    }

    protected func setObjectProperty(name: String, value: Any, checkReadOnly: Bool) {
        if (checkReadOnly) {
            checkReadOnlyProperties()
        }
        let trimName = name.trimAscii()
        if (trimName.isEmpty()) {
            throw IllegalArgumentException("Property name cannot be empty")
        }

        if (!setCJMSProperty(name, value)) {
            super.setProperty(name, value)
        }
    }

    private func setCJMSProperty(name: String, value: Any): Bool {
        var setFlag = true
        match (name) {
            case "JMSXDeliveryCount" => try {
                var rc = TypeConversionSupport.genericConvert<Int32>(value, TypeInfo.of<Int32>())
                this.redeliveryCounter = rc - 1
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSXDeliveryCount cannot be set")
            }

            case "JMSXGroupID" => try {
                this.groupID = TypeConversionSupport.genericConvert<String>(value, TypeInfo.of<String>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSXGroupID cannot be set")
            }

            case "JMSXGroupSeq" => try {
                this.groupSequence = TypeConversionSupport.genericConvert<Int32>(value, TypeInfo.of<Int32>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSXGroupSeq cannot be set")
            }

            case "JMSCorrelationID" => try {
                setCJMSCorrelationID(TypeConversionSupport.genericConvert<String>(value, TypeInfo.of<String>()))
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSCorrelationID cannot be set")
            }

            case "JMSDeliveryMode" =>
                if (let Some(value) <- (value as String)) {
                    if (value == "PERSISTENT") {
                        setCJMSDeliveryMode(DeliveryMode.PERSISTENT)
                    } else if (value == "NON_PERSISTENT") {
                        setCJMSDeliveryMode(DeliveryMode.NON_PERSISTENT)
                    }
                } else if (let Some(value) <- (value as Int32)) {
                    if (value == PERSISTENT) {
                        setCJMSDeliveryMode(DeliveryMode.PERSISTENT)
                    } else if (value == NON_PERSISTENT) {
                        setCJMSDeliveryMode(DeliveryMode.NON_PERSISTENT)
                    }
                } else {
                    try {
                        var rc = TypeConversionSupport.genericConvert<Bool>(value, TypeInfo.of<Bool>())
                        if (rc) {
                            setCJMSDeliveryMode(DeliveryMode.PERSISTENT)
                        } else {
                            setCJMSDeliveryMode(DeliveryMode.NON_PERSISTENT)
                        }
                    } catch (e: IllegalArgumentException) {
                        throw MessageFormatException("Property JMSDeliveryMode cannot be set")
                    }
                }

            case "JMSExpiration" => try {
                setCJMSExpiration(TypeConversionSupport.genericConvert<Int64>(value, TypeInfo.of<Int64>()))
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSExpiration cannot be set")
            }

            case "JMSPriority" => try {
                setCJMSPriority(TypeConversionSupport.genericConvert<Int32>(value, TypeInfo.of<Int32>()))
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSPriority cannot be set")
            }

            case "JMSRedelivered" => try {
                setCJMSRedelivered(TypeConversionSupport.genericConvert<Bool>(value, TypeInfo.of<Bool>()))
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSRedelivered cannot be set")
            }

            case "JMSReplyTo" => try {
                var name = TypeConversionSupport.genericConvert<String>(value, TypeInfo.of<String>())
                setCJMSReplyTo(ActiveMQDestination.createDestination(name, ActiveMQDestination.QUEUE_TYPE))
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSRedelivered cannot be set")
            }

            case "JMSTimestamp" => try {
                setCJMSTimestamp(TypeConversionSupport.genericConvert<Int64>(value, TypeInfo.of<Int64>()))
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSRedelivered cannot be set")
            }

            case "JMSType" => try {
                setCJMSType(TypeConversionSupport.genericConvert<String>(value, TypeInfo.of<String>()))
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Property JMSRedelivered cannot be set")
            }
            case _ => setFlag = false
        }
        return setFlag
    }

    protected func checkReadOnlyProperties(): Unit {
        if (readOnlyProperties) {
            throw MessageNotWriteableException("Message properties are read-only");
        }
    }

    protected func checkReadOnlyBody(): Unit {
        if (readOnlyBody) {
            throw MessageNotWriteableException("Message body is read-only");
        }
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processMessage(this)
    }

    public mut prop acknowledgeCallback: ?Callback {
        get() {
            return this.acknowledgeCallbackVal
        }
        set(value) {
            this.acknowledgeCallbackVal = value
        }
    }
}

public class MessageId <: DataStructure & Equatable<MessageId> & Hashable {
    private var textViewVal: ?String = None
    private var producerIdVal: ?ProducerId = None
    private var producerSequenceIdVal: Int64 = 1
    private var brokerSequenceIdVal: Int64 = 0

    public init() {
    }

    public MessageId(messageKey: String) {
        setValue(messageKey)
    }

    public init(producerId: ?ProducerId, producerSequenceId: Int64) {
        this.producerIdVal = producerId
        this.producerSequenceIdVal = producerSequenceId
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.MESSAGE_ID
    }

    private func setValue(messageKey: String): Unit {
        var key = messageKey
        // 解析出序列号
        let p = messageKey.lastIndexOf(":")
        if (let Some(p) <- messageKey.lastIndexOf(":")) {
            if (p >= 0) {
                key = messageKey[0..p]
                producerSequenceId = Int64.parse(messageKey[p + 1..messageKey.size])
            }
        } else {
            throw IllegalArgumentException()
        }
        producerId = ProducerId(key)
    }

    public func copy(): MessageId {
        let copy: MessageId = MessageId()
        copy.producerId = producerId
        copy.brokerSequenceId = brokerSequenceId
        copy.producerSequenceId = producerSequenceId
        copy.textView = textView
        return copy
    }

    public mut prop textView: ?String {
        get() {
            return this.textViewVal
        }
        set(value) {
            this.textViewVal = value
        }
    }

    public mut prop producerId: ?ProducerId {
        get() {
            return this.producerIdVal
        }
        set(value) {
            this.producerIdVal = value
        }
    }

    public mut prop producerSequenceId: Int64 {
        get() {
            return this.producerSequenceIdVal
        }
        set(value) {
            this.producerSequenceIdVal = value
        }
    }

    public mut prop brokerSequenceId: Int64 {
        get() {
            return this.brokerSequenceIdVal
        }
        set(value) {
            this.brokerSequenceIdVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public func checkEquals(other: MessageId): Bool {
        if (this.textViewVal != other.textViewVal) {
            return false
        }

        if (this.producerIdVal != other.producerIdVal) {
            return false
        }

        if (this.producerSequenceIdVal != other.producerSequenceIdVal) {
            return false
        }

        if (this.brokerSequenceIdVal != other.brokerSequenceIdVal) {
            return false
        }
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is MessageId)) {
            return false
        }
        if (let Some(other) <- (other as MessageId)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is MessageId)) {
            return true
        }
        if (let Some(other) <- (other as MessageId)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public operator override func ==(other: MessageId): Bool {
        if (!checkEquals(other)) {
            return false
        }
        return true
    }

    public operator override func !=(other: MessageId): Bool {
        if (!checkEquals(other)) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(textView) <- this.textViewVal) {
            hashCode += prime * textView.hashCode()
        }
        if (let Some(producerId) <- this.producerIdVal) {
            hashCode += prime * producerId.hashCode()
        }
        hashCode += prime * this.producerSequenceIdVal
        hashCode += prime * this.brokerSequenceIdVal
        return hashCode
    }

    public func toString(): String {
        if (let Some(textView) <- textViewVal) {
            if (textView.startsWith("ID:")) {
                return textView
            } else {
                return "ID:" + textView
            }
        } else {
            var sb = StringBuilder()
            if (let Some(producerId) <- producerId) {
                sb.append(producerId.toString())
            }
            sb.append(":${producerSequenceId}")
            return sb.toString()
        }
    }
}
