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

public class AdvisorySupport {
    public static let ADVISORY_TOPIC_PREFIX = "ActiveMQ.Advisory."
    public static let CONNECTION_ADVISORY_TOPIC: ActiveMQTopic = ActiveMQTopic(ADVISORY_TOPIC_PREFIX + "Connection")
    public static let QUEUE_ADVISORY_TOPIC: ActiveMQTopic = ActiveMQTopic(ADVISORY_TOPIC_PREFIX + "Queue")
    public static let TOPIC_ADVISORY_TOPIC: ActiveMQTopic = ActiveMQTopic(ADVISORY_TOPIC_PREFIX + "Topic")
    public static let TEMP_QUEUE_ADVISORY_TOPIC: ActiveMQTopic = ActiveMQTopic(ADVISORY_TOPIC_PREFIX + "TempQueue")
    public static let TEMP_TOPIC_ADVISORY_TOPIC: ActiveMQTopic = ActiveMQTopic(ADVISORY_TOPIC_PREFIX + "TempTopic")
    public static let PRODUCER_ADVISORY_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "Producer."
    public static let QUEUE_PRODUCER_ADVISORY_TOPIC_PREFIX = PRODUCER_ADVISORY_TOPIC_PREFIX + "Queue."
    public static let TOPIC_PRODUCER_ADVISORY_TOPIC_PREFIX = PRODUCER_ADVISORY_TOPIC_PREFIX + "Topic."
    public static let CONSUMER_ADVISORY_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "Consumer."
    public static let QUEUE_CONSUMER_ADVISORY_TOPIC_PREFIX = CONSUMER_ADVISORY_TOPIC_PREFIX + "Queue."
    public static let TOPIC_CONSUMER_ADVISORY_TOPIC_PREFIX = CONSUMER_ADVISORY_TOPIC_PREFIX + "Topic."
    public static let EXPIRED_TOPIC_MESSAGES_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "Expired.Topic."
    public static let EXPIRED_QUEUE_MESSAGES_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "Expired.Queue."
    public static let NO_TOPIC_CONSUMERS_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "NoConsumer.Topic."
    public static let NO_QUEUE_CONSUMERS_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "NoConsumer.Queue."
    public static let SLOW_CONSUMER_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "SlowConsumer."
    public static let FAST_PRODUCER_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "FastProducer."
    public static let MESSAGE_DISCAREDED_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "MessageDiscarded."
    public static let FULL_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "FULL."
    public static let MESSAGE_DELIVERED_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "MessageDelivered."
    public static let MESSAGE_CONSUMED_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "MessageConsumed."
    public static let MESSAGE_DLQ_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "MessageDLQd."
    public static let MASTER_BROKER_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "MasterBroker"
    public static let NETWORK_BRIDGE_TOPIC_PREFIX = ADVISORY_TOPIC_PREFIX + "NetworkBridge"
    public static let AGENT_TOPIC = "ActiveMQ.Agent"
    public static let ADIVSORY_MESSAGE_TYPE = "Advisory"
    public static let MSG_PROPERTY_ORIGIN_BROKER_ID = "originBrokerId"
    public static let MSG_PROPERTY_ORIGIN_BROKER_NAME = "originBrokerName"
    public static let MSG_PROPERTY_ORIGIN_BROKER_URL = "originBrokerURL"
    public static let MSG_PROPERTY_USAGE_NAME = "usageName"
    public static let MSG_PROPERTY_CONSUMER_ID = "consumerId"
    public static let MSG_PROPERTY_PRODUCER_ID = "producerId"
    public static let MSG_PROPERTY_MESSAGE_ID = "orignalMessageId"
    public static let MSG_PROPERTY_CONSUMER_COUNT = "consumerCount"
    public static let MSG_PROPERTY_DISCARDED_COUNT = "discardedCount"

    public static let TEMP_DESTINATION_COMPOSITE_ADVISORY_TOPIC: ActiveMQTopic = ActiveMQTopic(
        ADVISORY_TOPIC_PREFIX + "TempQueue," + ADVISORY_TOPIC_PREFIX + "TempTopic")
}
