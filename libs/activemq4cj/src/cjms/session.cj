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

public interface Session <: Resource {
    mut prop messageListener: ?MessageListener

    /**
     * 创建一个BytesMessage Object,用于发送包含字节流的消息
     */
    func createBytesMessage(): BytesMessage

    /**
     * 创建一个初始化的BytesMessage Object,用于发送包含字节流的消息
     */
    func createBytesMessage(body: Array<Byte>): BytesMessage

    /**
     * 创建一个MapMessage Object,用于发送自定义的名值对集合，其中名称是String类型变量，值是基本数据类型
     */
    func createMapMessage(): MapMessage

    /**
     * 创建一个Message Object
     */
    func createMessage(): Message

    /**
     * 创建一个ObjectMessage Object,用于发送包含可序列化仓颉对象的消息
     */
    func createObjectMessage(): ObjectMessage

    /**
     * 创建一个初始化的ObjectMessage Object,用于发送包含可序列化仓颉对象的消息
     */
    func createObjectMessage(object: Serializable<Any>): ObjectMessage

    /**
     * 创建一个StreamMessage对象
     */
    func createStreamMessage(): StreamMessage

    /**
     * 创建一个TextMessage Object,用于发送包含String对象的消息
     */
    func createTextMessage(): TextMessage

    /**
     * 创建一个初始化的TextMessage Object,用于发送包含String对象的消息
     */
    func createTextMessage(text: String): TextMessage

    /**
     * 指示CMSContext的会话是否处于事务模式
     */
    func getTransacted(): Bool

    /**
     * 返回JMSContext会话的会话模式,可能的值有： SESSION_TRANSACTED、AUTO_ACKNOWLEDGE、CLIENT_ACKNOWLEDGE、DUPS_OK_ACKNOWLEDGE
     */
    func getAcknowledgeMode(): AcknowledgeMode

    /**
     * 提交该事务中完成的所有消息并释放当前持有的所有锁。
     */
    func commit(): Unit

    /**
     * 回滚该事务中执行的所有消息并释放当前持有的所有锁。
     */
    func rollback(): Unit

    /**
     * 关闭CMSContext
     */
    func close(): Unit

    /**
     * 停止CMSContext会话中的消息传递，并使用最早的未确认消息重新开始消息传递。
     */
    func recover(): Unit

    /**
     * 创建一个发送消息到指定目的地的MessageProducer
     */
    func createProducer(destination: Destination): MessageProducer

    /**
     * 为指定的目的地创建一个MessageConsumer，由于Queue和Topic也都继承自Destination,所以也可以在Destination参数中使用它们来创建
     */
    func createConsumer(destination: Destination): MessageConsumer

    /**
     * 使用消息选择器为指定的目的地创建一个MessageConsumer，由于Queue和Topic也都继承自Destination,所以也可以在Destination参数中使用它们来创建
     */
    func createConsumer(destination: Destination, selector: ?String): MessageConsumer

    /**
     * 为指定目的地创建一个MessageConsumer，指定一个消息选择器和noLocal参数。由于Queue和Topic也都继承自Destination,所以也可以在Destination参数中使用它们来创建
     */
    func createConsumer(destination: Destination, selector: ?String, noLocal: Bool): MessageConsumer

    /**
     * 在指定主题(如果不存在)上创建具有指定名称的共享非持久订阅，并在该订阅上创建消费者
     */
    func createSharedConsumer(destination: Topic, name: ?String): MessageConsumer

    /**
     * 在指定主题(如果不存在)上创建具有指定名称的共享非持久订阅，指定消息选择器，并在该订阅上创建消费者
     */
    func createSharedConsumer(destination: Topic, name: ?String, selector: ?String): MessageConsumer

    func createQueue(queueName: String): Queue

    func createTopic(topicName: String): Topic

    /**
     * 在指定主题上创建一个非共享的持久订阅(如果不存在)，并在该持久订阅上创建一个消费者。此方法创建持久订阅，但不使用消息选择器，且noLocal值为false
     */
    func createDurableConsumer(destination: Topic, name: String): MessageConsumer

    /**
     * 在指定主题上创建一个非共享的持久订阅(如果不存在)，指定消息选择器,并在该持久订阅上创建一个消费者
     */
    func createDurableConsumer(destination: Topic, name: String, selector: ?String): MessageConsumer

    /**
     * 在指定主题(如果不存在)上创建非共享持久订阅，指定消息选择器和noLocal参数，并在该持久订阅上创建消费者
     */
    func createDurableConsumer(topic: Topic, name: String, selector: ?String, noLocal: Bool): MessageConsumer

    /**
     * 在指定主题(如果不存在)上创建具有指定名称的共享非持久订阅，并在该订阅上创建消费者
     */
    func createSharedDurableConsumer(destination: Topic, name: String): MessageConsumer

    /**
     * 在指定主题(如果不存在)上创建共享持久订阅，指定消息选择器，并在该持久订阅上创建使用者
     */
    func createSharedDurableConsumer(topic: Topic, name: String, selector: ?String): MessageConsumer

    /**
     * 创建一个QueueBrowser对象来查看指定队列上的消息
     */
    func createBrowser(queue: Queue): QueueBrowser

    /**
     * 创建一个QueueBrowser，使用消息选择器查看指定队列上的消息。
     */
    func createBrowser(queue: Queue, selector: ?String): QueueBrowser

    /**
     * 创建一个TemporaryQueue对象。它的生命周期将是JMSContext的的生命周期，除非它被提前删除。
     */
    func createTemporaryQueue(): TemporaryQueue

    /**
     * 创建一个TemporaryTopic对象。它的生命周期将是JMSContext的的生命周期，除非它被提前删除。
     */
    func createTemporaryTopic(): TemporaryTopic

    /**
     * 取消客户端创建的持久订阅
     */
    func unsubscribe(name: String): Unit

    /**
     * 确认JMSContext会话所使用的所有消息。
     */
    func acknowledge(): Unit
}
