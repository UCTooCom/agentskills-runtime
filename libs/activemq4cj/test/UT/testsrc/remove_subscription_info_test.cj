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
public class RemoveSubscriptionInfoTest {
    private var connection: ?ActiveMQConnection = None
    private var format: ?WireFormat = None

    private let subscriptionName: String = "subscriptionName:1"
    private let clientID = "clientID:1"

    @BeforeAll
    protected func beforeAll(): Unit {
        format = TestUtils.getWireFormat()
    }

    @TestCase
    public func testMarshallAndUnmarshallIsTheSame() {
        let connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()
        this.connection = connection
        connection.setClientID(clientID)
        connection.start()
        let session = connection.createSession()
        //先创建一个持久化订阅
        let durableConsumer = session.createDurableConsumer(ActiveMQTopic("test_durable_topic"), subscriptionName)
        //再把创建的Consumer移除，否则会报Consumer in use异常，导致无法取消订阅
        durableConsumer.close()
        let expected = createObject()
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

    public func createObject(): RemoveSubscriptionInfo {
        let removeSubscriptionInfo = RemoveSubscriptionInfo()
        let connectionInfo: ConnectionInfo = connection.getOrThrow().connectionInfo
        removeSubscriptionInfo.connectionId = connectionInfo.connectionId
        removeSubscriptionInfo.clientId = clientID
        removeSubscriptionInfo.subscriptionName = subscriptionName
        return removeSubscriptionInfo
    }
}
