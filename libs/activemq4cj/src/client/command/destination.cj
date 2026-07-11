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

public abstract class ActiveMQDestination <: DataStructure & Destination & Equatable<ActiveMQDestination> {
    private var nameVal: ?String = None

    public static let COMPOSITE_SEPERATOR: String = ","

    public static let QUEUE_TYPE: Byte = 0x01
    public static let TOPIC_TYPE: Byte = 0x02
    public static let TEMP_MASK: Byte = 0x04
    public static let TEMP_TOPIC_TYPE: Byte = TOPIC_TYPE | TEMP_MASK
    public static let TEMP_QUEUE_TYPE: Byte = QUEUE_TYPE | TEMP_MASK

    public static let QUEUE_QUALIFIED_PREFIX: String = "queue://"
    public static let TOPIC_QUALIFIED_PREFIX: String = "topic://"
    public static let TEMP_QUEUE_QUALIFED_PREFIX: String = "temp-queue://"
    public static let TEMP_TOPIC_QUALIFED_PREFIX: String = "temp-topic://"

    public static let TEMP_DESTINATION_NAME_PREFIX: String = "ID:"
    public static let IS_DLQ: String = "isDLQ"

    protected var compositeDestinations: ?Array<ActiveMQDestination> = None
    protected var destinationPaths: ?Array<String> = None
    protected var isPatternVal: Bool = false
    private var optionsVal: ?HashMap<String, ?String> = None

    public init() {
    }

    protected init(name: String) {
        this.nameVal = name
    }

    //设置组合目的地，组合目的地的名称以英文,隔开
    public func setCompositeDestinations(destinations: Array<ActiveMQDestination>): Unit {
        this.compositeDestinations = destinations
        this.destinationPaths = None
        this.isPatternVal = false

        let sb = StringBuilder()
        for (i in 0..destinations.size) {
            if (i != 0) {
                sb.append(COMPOSITE_SEPERATOR)
            }
            if (getDestinationType() == destinations[i].getDestinationType()) {
                if (let Some(name) <- destinations[i].name) {
                    sb.append(name)
                }
            } else {
                sb.append(destinations[i].getQualifiedName())
            }
        }
        this.nameVal = sb.toString()
    }

    public func getQualifiedName(): String {
        if (isComposite()) {
            if (let Some(name) <- name) {
                return name
            }
        }
        if (let Some(name) <- name) {
            return getQualifiedPrefix() + name
        }
        throw IllegalStateException("The destination name is a empty name")
    }

    public func setPhysicalName(name: String): Unit {
        var destinationName = name.trimAscii()
        if (destinationName.isEmpty()) {
            throw IllegalArgumentException("Invalid destination name: a non-empty name is required")
        }

        if (let Some(p) <- destinationName.indexOf("?")) {
            optionsVal = URLSupport.parseQuery(destinationName[p + 1..destinationName.size])
            destinationName = destinationName[0..p]
        }
        if (destinationName.count(COMPOSITE_SEPERATOR) > 0) {
            let array: Array<String> = destinationName.split(COMPOSITE_SEPERATOR, removeEmpty: true)
            let constArray = HashSet(array).toArray()
            this.compositeDestinations = Array<ActiveMQDestination>(
                constArray.size,
                {
                    index: Int64 => return createDestinationByName(constArray[index])
                }
            )
        } else {
            if (destinationName.contains("*") || destinationName.contains(">")) {
                this.isPatternVal = true
            }
        }
        this.nameVal = destinationName
    }

    public mut prop name: ?String {
        get() {
            return this.nameVal
        }
        set(value) {
            if (let Some(physicalName) <- value) {
                setPhysicalName(physicalName)
            } else {
                throw IllegalArgumentException("Invalid destination name: a non-none name is required")
            }
        }
    }

    public func createDestinationByName(name: String): ActiveMQDestination {
        return createDestination(name, getDestinationType())
    }

    public static func createDestination(name: String, defaultType: Byte): ActiveMQDestination {
        if (name.startsWith(QUEUE_QUALIFIED_PREFIX)) {
            return ActiveMQQueue(name[QUEUE_QUALIFIED_PREFIX.size..name.size])
        } else if (name.startsWith(TOPIC_QUALIFIED_PREFIX)) {
            return ActiveMQTopic(name[TOPIC_QUALIFIED_PREFIX.size..name.size])
        } else if (name.startsWith(TEMP_QUEUE_QUALIFED_PREFIX)) {
            return ActiveMQTempQueue(name[TEMP_QUEUE_QUALIFED_PREFIX.size..name.size])
        } else if (name.startsWith(TEMP_TOPIC_QUALIFED_PREFIX)) {
            return ActiveMQTempTopic(name[TEMP_TOPIC_QUALIFED_PREFIX.size..name.size])
        }

        match (defaultType) {
            case 1 => ActiveMQQueue(name)
            case 2 => ActiveMQTopic(name)
            case 5 => ActiveMQTempQueue(name)
            case 6 => ActiveMQTempTopic(name)
            case _ => throw IllegalArgumentException("Invalid default destination type: ${defaultType}")
        }
    }

    //目的地路径，路径以.隔开
    public func getDestinationPaths(): Array<String> {
        if (let Some(destinationPaths) <- this.destinationPaths) {
            return destinationPaths.clone()
        }
        if (let Some(name) <- this.name) {
            let path = name.split(".", removeEmpty: false)
            this.destinationPaths = path
            return path
        }
        throw IllegalArgumentException("The destination path is empty: ${this}.")
    }

    public static func transform(dest: Destination): ActiveMQDestination {
        if (let Some(destination) <- (dest as ActiveMQDestination)) {
            return destination
        }
        if (let Some(queue) <- (dest as Queue)) {
            return ActiveMQQueue(queue.getQueueName())
        }
        if (let Some(topic) <- (dest as Topic)) {
            return ActiveMQTopic(topic.getTopicName())
        }
        if (let Some(temporaryQueue) <- (dest as TemporaryQueue)) {
            return ActiveMQTempQueue(temporaryQueue.getQueueName())
        }
        if (let Some(temporaryTopic) <- (dest as TemporaryTopic)) {
            return ActiveMQTempTopic(temporaryTopic.getTopicName())
        }
        throw CJMSException("Could not transform the destination into a ActiveMQ destination: ${dest}")
    }

    public func getDestinationType(): Byte

    protected func getQualifiedPrefix(): String

    public open func isMarshallAware(): Bool {
        return false
    }

    public func isComposite(): Bool {
        return compositeDestinations.isSome()
    }

    public prop isPattern: Bool {
        get() {
            return this.isPatternVal
        }
    }

    public func getCompositeDestinations(): ?Array<ActiveMQDestination> {
        if (let Some(compositeDestinations) <- this.compositeDestinations) {
            return compositeDestinations.clone()
        }
        return None
    }

    public open func isQueue(): Bool {
        return false
    }

    public open func isTopic(): Bool {
        return false
    }

    public open func isTemporary(): Bool {
        return false
    }

    public func isDLQ(): Bool {
        if (let Some(options) <- optionsVal) {
            return options.contains(IS_DLQ)
        }
        return false
    }

    public func setDLQ(val: Bool): Unit {
        if (let Some(options) <- optionsVal) {
            options.add(IS_DLQ, val.toString())
        } else {
            optionsVal = HashMap<String, ?String>()
            setDLQ(val)
        }
    }

    public prop options: ?HashMap<String, ?String> {
        get() {
            if (let Some(options) <- this.optionsVal) {
                return HashMap<String, ?String>(options)
            }
            return None
        }
    }

    public func checkEquals(other: DataStructure): Bool {
        if (!(other is ActiveMQDestination)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQDestination)) {
            if (this.nameVal != other.nameVal) {
                return false
            }
        }
        return true
    }

    public operator func ==(other: ActiveMQDestination): Bool {
        if (!this.checkEquals(other)) {
            return false
        }
        return true
    }

    public operator func !=(other: ActiveMQDestination): Bool {
        if (!this.checkEquals(other)) {
            return true
        }
        return false
    }

    public static func compareTo(destination: ?ActiveMQDestination, destination2: ?ActiveMQDestination): Ordering {
        if (destination == destination2) {
            return Ordering.EQ
        }
        if (let Some(destination) <- destination) {
            if (let Some(destination2) <- destination2) {
                if (destination2 is AnyDestination) {
                    return Ordering.LT
                }
                if (destination is AnyDestination) {
                    return Ordering.GT
                }
                if (destination.getDestinationType() == destination2.getDestinationType()) {
                    if (let Some(name) <- destination.name) {
                        if (let Some(name2) <- destination2.name) {
                            return name.compare(name2)
                        } else {
                            return Ordering.GT
                        }
                    } else {
                        if (destination2.name.isNone()) {
                            return Ordering.EQ
                        }
                        return Ordering.LT
                    }
                } else {
                    if (destination.isQueue()) {
                        return Ordering.LT
                    } else {
                        return Ordering.GT
                    }
                }
            } else {
                return Ordering.GT
            }
        } else {
            return Ordering.LT
        }
    }

    @OverflowWrapping
    public open func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(name) <- nameVal) {
            hashCode += prime * name.hashCode()
        }
        return hashCode
    }

    public open func toString(): String {
        return getQualifiedName()
    }
}

public class AnyDestination <: ActiveMQDestination {
    public AnyDestination(destinations: Array<ActiveMQDestination>) {
        setCompositeDestinations(destinations)
        // ensure we are small when it comes to comparison in DestinationMap
        this.name = "!0"
    }

    protected override func getQualifiedPrefix(): String {
        return "Any://"
    }

    public override func getDestinationType(): Byte {
        return ActiveMQDestination.QUEUE_TYPE & ActiveMQDestination.TOPIC_TYPE;
    }

    public override func getDataStructureType(): Byte {
        throw IllegalStateException("not for marshalling")
    }

    public override func isQueue(): Bool {
        return true
    }

    public override func isTopic(): Bool {
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is AnyDestination)) {
            return false
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is AnyDestination)) {
            return true
        }
        return false
    }
}

public class ActiveMQQueue <: ActiveMQDestination & Queue {
    public init() {
    }

    public init(name: String) {
        super(name)
        setPhysicalName(name)
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_QUEUE
    }

    public override func getDestinationType(): Byte {
        return QUEUE_TYPE
    }

    public override func getQueueName(): String {
        if (let Some(name) <- this.name) {
            return name
        }
        throw IllegalArgumentException("The destination name is a empty name")
    }

    protected override func getQualifiedPrefix(): String {
        return QUEUE_QUALIFIED_PREFIX
    }

    public override func isQueue(): Bool {
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQQueue)) {
            return false
        }
        return super.checkEquals(other)
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQQueue)) {
            return true
        }
        return !super.checkEquals(other)
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        return super.hashCode()
    }
}

public class ActiveMQTopic <: ActiveMQDestination & Topic {
    public init() {
    }

    public init(name: String) {
        super(name)
        setPhysicalName(name)
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_TOPIC
    }

    public override func getTopicName(): String {
        if (let Some(name) <- this.name) {
            return name
        }
        throw IllegalArgumentException("The destination name is a empty name")
    }

    public override func getDestinationType(): Byte {
        return TOPIC_TYPE
    }

    protected override func getQualifiedPrefix(): String {
        return TOPIC_QUALIFIED_PREFIX
    }

    public override func isTopic(): Bool {
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQTopic)) {
            return false
        }
        return super.checkEquals(other)
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQTopic)) {
            return true
        }
        return !super.checkEquals(other)
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        return super.hashCode()
    }
}

public class DestinationInfo <: BaseCommand {
    public static let ADD_OPERATION_TYPE: Byte = 0
    public static let REMOVE_OPERATION_TYPE: Byte = 1

    private var connectionIdVal: ?ConnectionId = None
    private var destinationVal: ?ActiveMQDestination = None
    private var operationTypeVal: Byte = 0
    private var timeoutVal: Int64 = 0
    private var brokerPathVal: ?Array<BrokerId> = None

    public func getDataStructureType(): Byte {
        return CommandTypes.DESTINATION_INFO
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return match (operationType) {
            case 0 => visitor.processAddDestination(this)
            case 1 => visitor.processRemoveDestination(this)
            case _ => None
        }
    }

    public mut prop connectionId: ?ConnectionId {
        get() {
            return this.connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop destination: ?ActiveMQDestination {
        get() {
            return this.destinationVal
        }
        set(value) {
            this.destinationVal = value
        }
    }

    public mut prop operationType: Byte {
        get() {
            return this.operationTypeVal
        }
        set(value) {
            this.operationTypeVal = value
        }
    }

    public mut prop timeout: Int64 {
        get() {
            return this.timeoutVal
        }
        set(value) {
            this.timeoutVal = value
        }
    }

    public mut prop brokerPath: ?Array<BrokerId> {
        get() {
            return this.brokerPathVal
        }
        set(value) {
            this.brokerPathVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is DestinationInfo)) {
            return false
        }
        if (let Some(other) <- (other as DestinationInfo)) {
            if (let Some(connectionId) <- connectionIdVal) {
                if (let Some(otherConnectionId) <- other.connectionIdVal) {
                    if (connectionId != otherConnectionId) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.connectionIdVal.isSome()) {
                    return false
                }
            }
            if (let Some(destination) <- destinationVal) {
                if (let Some(otherDestination) <- other.destinationVal) {
                    if (destination != otherDestination) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.destinationVal.isSome()) {
                    return false
                }
            }
            if (this.operationTypeVal != other.operationTypeVal) {
                return false
            }
            if (this.timeoutVal != other.timeoutVal) {
                return false
            }
            if (let Some(brokerPath) <- brokerPathVal) {
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
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is DestinationInfo)) {
            return true
        }
        if (let Some(other) <- (other as DestinationInfo)) {
            if (let Some(connectionId) <- connectionIdVal) {
                if (let Some(otherConnectionId) <- other.connectionIdVal) {
                    if (connectionId != otherConnectionId) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.connectionIdVal.isSome()) {
                    return true
                }
            }
            if (let Some(destination) <- destinationVal) {
                if (let Some(otherDestination) <- other.destinationVal) {
                    if (destination != otherDestination) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.destinationVal.isSome()) {
                    return true
                }
            }
            if (this.operationTypeVal != other.operationTypeVal) {
                return true
            }
            if (this.timeoutVal != other.timeoutVal) {
                return true
            }
            if (let Some(brokerPath) <- brokerPathVal) {
                if (let Some(otherBrokerPath) <- other.brokerPathVal) {
                    if (brokerPath.size != otherBrokerPath.size) {
                        return true
                    }
                    for (i in 0..brokerPath.size) {
                        if (brokerPath[i] != otherBrokerPath[i]) {
                            return true
                        }
                    }
                } else {
                    return true
                }
            } else {
                if (other.brokerPathVal.isSome()) {
                    return true
                }
            }
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        return "DestinationInfo: {connectionId: ${connectionIdVal}, destination: ${destinationVal}, operationType: ${operationTypeVal}, timeout: ${timeoutVal}, brokerPath: ${brokerPathVal}}"
    }
}
