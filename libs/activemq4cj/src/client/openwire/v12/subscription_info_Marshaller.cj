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
package activemq4cj.client.openwire.v12

public class SubscriptionInfoMarshaller <: BaseDataStreamMarshaller {

    //                                    [==if not null is 1=================]                                                [==if not null is 1=================]
    // +------+------------+------------+ [ +------+------------------------+ ] +------------+------------------+------------+ [ +------+------------------------+ ] +----------+
    // | type | clientId   | not null   | [ | type | command-specific-fields| ] | selector   | subscriptionName | not null   | [ | type | command-specific-fields| ] | noLocal  |
    // +------+------------+------------+ [ +------+------------------------+ ] +------------+------------------+------------+ [ +------+------------------------+ ] +----------+
    // | Byte | String     | Byte       | [ | Byte |  variable sized        | ] | String     | String           | Byte       | [ | Byte |  variable sized        | ] | Bool     |
    // +------+------------+------------+ [ +------+------------------------+ ] +------------+------------------+------------+ [ +------+------------------------+ ] +----------+
    //                                    [========ActiveMQDestination========]                                                [========ActiveMQDestination========]
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(subscriptionInfo) <- (object as SubscriptionInfo)) {
            super.looseMarshal(subscriptionInfo, dataOut)
            looseMarshalString(subscriptionInfo.clientId, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(subscriptionInfo.destination, dataOut)
            looseMarshalString(subscriptionInfo.selector, dataOut)
            looseMarshalString(subscriptionInfo.subscriptionName, dataOut)
            looseMarshalNestedObject<ActiveMQDestination>(subscriptionInfo.subscribedDestination, dataOut)
            MarshallingSupport.putBool(subscriptionInfo.noLocal, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(subscriptionInfo) <- (data as SubscriptionInfo)) {
            super.looseUnmarshal(subscriptionInfo, dataIn)
            subscriptionInfo.clientId = looseUnmarshalString(dataIn)
            subscriptionInfo.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            subscriptionInfo.selector = looseUnmarshalString(dataIn)
            subscriptionInfo.subscriptionName = looseUnmarshalString(dataIn)
            subscriptionInfo.subscribedDestination = looseUnmarsalNestedObject<ActiveMQDestination>(dataIn)
            subscriptionInfo.noLocal = MarshallingSupport.getBool(dataIn)
        }
    }

    public override func createObject(): SubscriptionInfo {
        return SubscriptionInfo()
    }
}
