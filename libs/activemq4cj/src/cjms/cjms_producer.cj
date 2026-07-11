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

/**
 * JMS 2.0
 */
public interface CJMSProducer {

    /**
     * 使用JMSProducer上定义的任何发送选项、消息属性和消息头，向指定的目的地发送消息
     */
    func send(destination: Destination, message: Message): CJMSProducer

    /**
     * 发送一个带有指定正文的TextMessage到指定的目的地，使用在这个JMSProducer上定义的任何发送选项、消息属性和消息头
     */
    func send(destination: Destination, body: String): CJMSProducer

    /**
     * 发送一个带有指定正文的MapMessage到指定的目的地，使用在这个JMSProducer上定义的任何发送选项、消息属性和消息头
     */
    func send(destination: Destination, body: Map<String, Any>): CJMSProducer

    /**
     * 发送一个带有指定正文的BytesMessage到指定的目的地，使用在这个JMSProducer上定义的任何发送选项、消息属性和消息头
     */
    func send(destination: Destination, body: Array<Byte>): CJMSProducer

    /**
     * 发送一个带有指定正文的ObjectMessage到指定的目的地，使用在这个JMSProducer上定义的任何发送选项、消息属性和消息头
     */
    func send(destination: Destination, body: Serializable<Any>): CJMSProducer

    func setDisableMessageID(value: Bool): CJMSProducer

    func getDisableMessageID(): Bool

    func setDisableMessageTimestamp(value: Bool): CJMSProducer

    func getDisableMessageTimestamp(): Bool

    func setDeliveryMode(deliveryMode: DeliveryMode): CJMSProducer

    func getDeliveryMode(): DeliveryMode

    func setPriority(priority: Int32): CJMSProducer

    func getPriority(): Int32

    func setTimeToLive(timeToLive: Int64): CJMSProducer

    func getTimeToLive(): Int64

    func setDeliveryDelay(deliveryDelay: Int64): CJMSProducer

    func getDeliveryDelay(): Int64

    /**
     * 指定对send的调用是同步还是异步，如果CompletionListener不为空，后续调用是异步的，反之，后续调用是同步的
     */
    func setAsync(completionListener: CompletionListener): CJMSProducer

    func getAsync(): CompletionListener

    func setProperty(name: String, value: Bool): CJMSProducer

    func setProperty(name: String, value: Byte): CJMSProducer

    func setProperty(name: String, value: Int16): CJMSProducer

    func setProperty(name: String, value: Int32): CJMSProducer

    func setProperty(name: String, value: Int64): CJMSProducer

    func setProperty(name: String, value: Float32): CJMSProducer

    func setProperty(name: String, value: Float64): CJMSProducer

    func setProperty(name: String, value: String): CJMSProducer

    func clearProperties(): CJMSProducer

    func propertyExists(name: String): Bool

    func getBoolProperty(name: String): Bool

    func getByteProperty(name: String): Byte

    func getInt16Property(name: String): Int16

    func getInt32Property(name: String): Int32

    func getInt64Property(name: String): Int64

    func getFloat32Property(name: String): Float32

    func getFloat64Property(name: String): Float64

    func getStringProperty(name: String): String

    func setCJMSCorrelationID(correlationID: String): CJMSProducer

    func getCJMSCorrelationID(): ?String

    func setCJMSType(CJMSType: String): CJMSProducer

    func getCJMSType(): ?String

    func setCJMSReplyTo(replyTo: Destination): CJMSProducer

    func getCJMSReplyTo(): ?Destination
}
