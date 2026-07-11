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
package activemq_client_unit_test

@Test
public class ConsumerInfoTest {
    private var connection: ?ActiveMQConnection = None
    private var format: ?WireFormat = None

    @BeforeAll
    protected func beforeAll(): Unit {
        connection = TestUtils.getConnection() as ActiveMQConnection
        format = TestUtils.getWireFormat()
    }

    @TestCase
    public func testMarshallAndUnmarshallIsTheSame() {
        let connection = connection.getOrThrow()
        connection.start()
        connection.createSession()
        let expected: DataStructure = createObject()
        if (let Some(command) <- (expected as Command)) {
            connection.syncSendPacket(command)
        }
        let format = format.getOrThrow()
        let dataOut: ByteBuffer = ByteBuffer.allocate(8192)
        format.marshal(expected, dataOut)
        let actual = format.unmarshal(dataOut)
        @Assert(actual == expected)
        @Assert((actual != expected) == false)
    }

    public func createObject(): ConsumerInfo {
        let consumerInfo = ConsumerInfo()
        consumerInfo.consumerId = createConsumerId()
        consumerInfo.destination = ActiveMQQueue("cangjie_test_queue")
        consumerInfo.prefetchSize = 1000
        consumerInfo.maximumPendingMessageLimit = 1
        consumerInfo.browser = true
        consumerInfo.dispatchAsync = false
        //consumerInfo.selector = "Selector:3"
        consumerInfo.clientId = "client:1"
        consumerInfo.subscriptionName = "subscriptionName:1"
        consumerInfo.noLocal = true
        consumerInfo.exclusive = true
        consumerInfo.retroactive = false
        consumerInfo.priority = 6
        consumerInfo.brokerPath = Array<BrokerId>(3, {index: Int64 => BrokerId()})
        consumerInfo.optimizedAcknowledge = true
        consumerInfo.noRangeAcks = false
        consumerInfo.networkSubscription = true
        consumerInfo.networkConsumerIds = Array<ConsumerId>(2, {index: Int64 => createConsumerId()})
        return consumerInfo
    }

    private func createConsumerId(): ConsumerId {
        let consumerId = ConsumerId()
        if (let Some(connectionId) <- connection.getOrThrow().connectionInfo.connectionId) {
            consumerId.connectionId = connectionId.value
        }
        consumerId.sessionId = 1
        consumerId.value = 0xFFFF << 8
        return consumerId
    }
}
