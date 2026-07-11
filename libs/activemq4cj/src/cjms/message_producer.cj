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

public interface MessageProducer <: Resource {
    mut prop disableMessageID: Bool

    mut prop disableMessageTimestamp: Bool

    mut prop deliveryMode: DeliveryMode

    mut prop priority: Int32

    mut prop timeToLive: Int64

    mut prop deliveryDelay: Int64

    prop destination: Destination

    /**
     * 使用MessageProducer的默认delivery mode, priority, time to live发送消息
     */
    func send(message: Message): Unit

    /**
     * 发送消息，指定delivery mode, priority, time to live
     */
    func send(message: Message, deliveryMode: DeliveryMode, priority: Int32, timeToLive: Int64): Unit

    /**
     * 使用MessageProducer的默认delivery mode, priority, time to live发送消息到目标Destination
     */
    func send(destination: Destination, message: Message): Unit

    /**
     * 发送消息到目标Destination,指定delivery mode, priority, time to live
     */
    func send(destination: Destination, message: Message, deliveryMode: DeliveryMode, priority: Int32, timeToLive: Int64): Unit

    /**
     * 使用MessageProducer的默认delivery mode, priority, time to live发送消息,操作完成时通知指定的CompletionListener，这是异步发送
     */
    func send(message: Message, completionListener: CompletionListener): Unit

    /**
     * 异步发送消息，指定delivery mode, priority, time to live
     */
    func send(
        message: Message,
        deliveryMode: DeliveryMode,
        priority: Int32,
        timeToLive: Int64,
        completionListener: CompletionListener
    ): Unit

    /**
     * 使用MessageProducer的默认delivery mode, priority, time to live异步发送消息到目标Destination
     */
    func send(destination: Destination, message: Message, completionListener: CompletionListener): Unit

    /**
     * 异步发送消息到目标Destination,指定delivery mode, priority, time to live
     */
    func send(
        destination: Destination,
        message: Message,
        deliveryMode: DeliveryMode,
        priority: Int32,
        timeToLive: Int64,
        completionListener: CompletionListener
    ): Unit
}
