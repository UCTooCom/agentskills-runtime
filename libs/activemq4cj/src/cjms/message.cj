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
package activemq4cj.cjms

public interface Message {
    func getCJMSMessageID(): ?String

    func setCJMSMessageID(id: ?String): Unit

    func getCJMSTimestamp(): Int64

    func setCJMSTimestamp(timestamp: Int64): Unit

    func getCJMSCorrelationID(): ?String

    func setCJMSCorrelationID(correlationID: ?String): Unit

    func getCJMSReplyTo(): ?Destination

    func setCJMSReplyTo(replyTo: ?Destination): Unit

    func getCJMSDestination(): ?Destination

    func setCJMSDestination(destination: ?Destination): Unit

    func setCJMSDeliveryMode(deliveryMode: DeliveryMode): Unit

    func getCJMSDeliveryMode(): DeliveryMode

    func getCJMSRedelivered(): Bool

    func setCJMSRedelivered(redelivered: Bool): Unit

    func getCJMSType(): ?String

    func setCJMSType(CJMSType: ?String): Unit

    func getCJMSExpiration(): Int64

    func setCJMSExpiration(expiration: Int64): Unit

    func getCJMSDeliveryTime(): Int64

    func setCJMSDeliveryTime(deliveryTime: Int64): Unit

    func getCJMSPriority(): Int32

    func setCJMSPriority(priority: Int32): Unit

    /**
     * 清空properties，不清header和body
     */
    func clearProperties(): Unit

    func propertyExists(name: String): Bool

    func getBoolProperty(name: String): Bool

    func getByteProperty(name: String): Byte

    func getInt16Property(name: String): Int16

    func getInt32Property(name: String): Int32

    func getInt64Property(name: String): Int64

    func getFloat32Property(name: String): Float32

    func getFloat64Property(name: String): Float64

    func getStringProperty(name: String): String

    func getObjectProperty(name: String): Any

    /**
     * 返回所有属性的名称
     */
    func getPropertyNames(): ?LinkedList<String>

    func setBoolProperty(name: String, value: Bool): Unit

    func setByteProperty(name: String, value: Byte): Unit

    func setInt16Property(name: String, value: Int16): Unit

    func setInt32Property(name: String, value: Int32): Unit

    func setInt64Property(name: String, value: Int64): Unit

    func setFloat32Property(name: String, value: Float32): Unit

    func setFloat64Property(name: String, value: Float64): Unit

    func setStringProperty(name: String, value: String): Unit

    func setObjectProperty(name: String, value: Any): Unit

    /**
     * 确认此消费消息的会话的所有消费消息
     */
    func acknowledge(): Unit

    /**
     * 清空消息body的内容，不清header和properties
     */
    func clearBody(): Unit
}

public class MessageConstants {
    private init() {
    }

    public static let DEFAULT_DELIVERY_MODE: DeliveryMode = DeliveryMode.PERSISTENT
    public static let DEFAULT_PRIORITY: Byte = 4
    public static let DEFAULT_TIME_TO_LIVE: Int64 = 0
    public static let DEFAULT_DELIVERY_DELAY: Int64 = 0
}
