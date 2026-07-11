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

public abstract class ActiveMQTempDestination <: ActiveMQDestination & Equatable<ActiveMQTempDestination> & Hashable {
    /**
     * 需要调用Connection的deleteDestination方法，以实现JMS规范中的delete Api
     */
    private var connectionVal: ?IConnection = None

    public init() {
    }

    public init(name: String) {
        super(name)
    }

    public init(connectionId: String, sequenceId: Int64) {
        super(connectionId + ":" + sequenceId.toString())
    }

    public mut prop connection: ?IConnection {
        get() {
            return this.connectionVal
        }
        set(value) {
            this.connectionVal = value
        }
    }

    public open func delete(): Unit {
        if (let Some(connection) <- this.connection) {
            connection.deleteDestination(this)
        }
    }

    public override func isTemporary(): Bool {
        return true;
    }

    public operator func ==(other: ActiveMQTempDestination): Bool {
        if (this.name != other.name) {
            return false
        }
        return true
    }

    public operator func !=(other: ActiveMQTempDestination): Bool {
        if (this.name != other.name) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        return super.hashCode()
    }
}

public class ActiveMQTempQueue <: ActiveMQTempDestination & TemporaryQueue {
    public init() {
    }

    public init(name: String) {
        super(name)
        setPhysicalName(name)
    }

    public init(connectionId: String, sequenceId: Int64) {
        super(connectionId + ":" + sequenceId.toString())
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_TEMP_QUEUE
    }

    public override func getQueueName(): String {
        if (let Some(name) <- this.name) {
            return name
        }
        throw IllegalArgumentException("The destination name is a empty name")
    }

    public override func getDestinationType(): Byte {
        return TEMP_QUEUE_TYPE
    }

    protected override func getQualifiedPrefix(): String {
        return TEMP_QUEUE_QUALIFED_PREFIX
    }

    public override func isQueue(): Bool {
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQTempQueue)) {
            return false
        }
        return super.checkEquals(other)
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQTempQueue)) {
            return true
        }
        return !super.checkEquals(other)
    }
}

public class ActiveMQTempTopic <: ActiveMQTempDestination & TemporaryTopic {
    public init() {
    }

    public init(name: String) {
        super(name)
        setPhysicalName(name)
    }

    public init(connectionId: String, sequenceId: Int64) {
        super("${connectionId}:${sequenceId}")
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_TEMP_TOPIC
    }

    public override func getTopicName(): String {
        if (let Some(name) <- this.name) {
            return name
        }
        throw IllegalArgumentException("The destination name is a empty name")
    }

    public override func getDestinationType(): Byte {
        return TEMP_TOPIC_TYPE
    }

    protected override func getQualifiedPrefix(): String {
        return TEMP_TOPIC_QUALIFED_PREFIX
    }

    public override func isTopic(): Bool {
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQTempTopic)) {
            return false
        }
        return super.checkEquals(other)
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQTempTopic)) {
            return true
        }
        return !super.checkEquals(other)
    }
}
