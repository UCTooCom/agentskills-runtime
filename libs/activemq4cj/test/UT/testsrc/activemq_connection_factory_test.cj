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
public class ActiveMQConnectionFactoryTest {
    protected static let logger = LoggerFactory.getLogger("ActiveMQConnectionFactoryTest")

    @TestCase
    public func testUseURIToSetUseClientIDPrefixOnConnectionFactory(): Unit {
        let connectionFactory = ActiveMQConnectionFactory(
            "tcp://localhost?jms.clientIDPrefix=Cheese&broker.persistent=false")

        let connection = connectionFactory.createConnection()
        connection.start()

        @Assert(Some("Cheese"), connectionFactory.clientIDPrefix)

        let clientID = connection.getClientID()

        if (let Some(clientID) <- clientID) {
            @Assert(clientID.startsWith("Cheese"))
        }
    }

    @TestCase
    public func testUseURIToSetOptionsOnConnectionFactory(): Unit {
        var connectionFactory = ActiveMQConnectionFactory(
            "tcp://localhost?jms.useAsyncSend=true&jms.alwaysSessionAsync=false&jms.alwaysSyncSend=true&jms.auditDepth=48&jms.auditMaximumProducerNumber=24&jms.checkForDuplicates=false"
        )
        var connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        @Assert(true, connectionFactory.useAsyncSend)
        @Assert(true, connection.useAsyncSend)

        @Assert(false, connectionFactory.alwaysSessionAsync)
        @Assert(false, connection.alwaysSessionAsync)

        @Assert(true, connectionFactory.alwaysSyncSend)
        @Assert(true, connection.alwaysSyncSend)

        @Assert(connectionFactory.auditDepth, 48)
        @Assert(connectionFactory.auditMaximumProducerNumber, 24)

        @Assert(false, connectionFactory.checkForDuplicates)
        @Assert(false, connection.checkForDuplicates)
        // the broker url have been adjusted.
        @Assert("tcp://localhost", connectionFactory.getBrokerURL())

        connectionFactory = ActiveMQConnectionFactory(
            "tcp://localhost?jms.useAsyncSend=false&jms.clientID=testClient&jms.closeTimeout=150&jms.consumerExpiryCheckEnabled=false&jms.copyMessageOnSend=false"
        )
        connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        @Assert(connectionFactory.useAsyncSend, false)
        @Assert(connection.useAsyncSend, false)

        @Assert(connectionFactory.clientID, "testClient")
        @Assert(connection.getClientID(), "testClient")

        @Assert(connectionFactory.closeTimeout, 150)
        @Assert(connection.closeTimeout, 150)

        @Assert(connectionFactory.consumerExpiryCheckEnabled, false)
        @Assert(connection.consumerExpiryCheckEnabled, false)

        @Assert(connectionFactory.copyMessageOnSend, false)
        @Assert(connection.copyMessageOnSend, false)
        // the broker url have been adjusted.
        @Assert("tcp://localhost", connectionFactory.getBrokerURL())

        connectionFactory = ActiveMQConnectionFactory(
            "tcp://localhost?jms.disableTimeStampsByDefault=true&jms.dispatchAsync=true&jms.nestedMapAndListEnabled=false&jms.objectMessageSerializationDefered=true"
        )
        connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        @Assert(true, connectionFactory.disableTimeStampsByDefault)
        @Assert(true, connection.disableTimeStampsByDefault)

        @Assert(true, connectionFactory.dispatchAsync)
        @Assert(true, connection.dispatchAsync)

        @Assert(false, connectionFactory.nestedMapAndListEnabled)
        @Assert(false, connection.nestedMapAndListEnabled)

        @Assert(true, connectionFactory.objectMessageSerializationDefered)
        @Assert(true, connection.objectMessageSerializationDefered)

        connectionFactory = ActiveMQConnectionFactory(
            "tcp://localhost?jms.optimizeAcknowledge=true&jms.optimizeAcknowledgeTimeOut=30&jms.optimizedAckScheduledAckInterval=10&jms.optimizedMessageDispatch=false"
        )
        connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        @Assert(true, connectionFactory.optimizeAcknowledge)
        @Assert(true, connection.optimizeAcknowledge)

        @Assert(30, connectionFactory.optimizeAcknowledgeTimeOut)
        @Assert(30, connection.optimizeAcknowledgeTimeOut)

        @Assert(10, connectionFactory.optimizedAckScheduledAckInterval)
        @Assert(10, connection.optimizedAckScheduledAckInterval)

        @Assert(false, connectionFactory.optimizedMessageDispatch)
        @Assert(false, connection.optimizedMessageDispatch)

        connectionFactory = ActiveMQConnectionFactory(
            "tcp://localhost?jms.useCompression=true&jms.useRetroactiveConsumer=true&jms.warnAboutUnstartedConnectionTimeout=50&jms.nonBlockingRedelivery=true"
        )
        connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        @Assert(true, connectionFactory.useCompression)
        @Assert(true, connection.useCompression)

        @Assert(true, connectionFactory.useRetroactiveConsumer)
        @Assert(true, connection.useRetroactiveConsumer)

        @Assert(50, connectionFactory.warnAboutUnstartedConnectionTimeout)
        @Assert(50, connection.warnAboutUnstartedConnectionTimeout)

        @Assert(true, connectionFactory.nonBlockingRedelivery)
        @Assert(true, connection.nonBlockingRedelivery)
    }

    @TestCase
    public func testConnectAttemptTimeotOptionIsApplied(): Unit {
        var connectionFactory = ActiveMQConnectionFactory("tcp://localhost")

        @Assert(0, connectionFactory.connectResponseTimeout)

        @Assert("tcp://localhost", connectionFactory.getBrokerURL())

        var connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        @Assert(0, connection.connectResponseTimeout)

        connectionFactory = ActiveMQConnectionFactory("tcp://localhost?jms.connectResponseTimeout=1000")
        connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        @Assert(1000, connectionFactory.connectResponseTimeout)

        @Assert("tcp://localhost", connectionFactory.getBrokerURL())

        @Assert(1000, connection.connectResponseTimeout)
    }

    @TestCase
    public func testUseURIToConfigureRedeliveryPolicy(): Unit {
        let brokerURL = "tcp://localhost?broker.persistent=false&broker.useJmx=false&jms.redeliveryPolicy.maximumRedeliveries=2&jms.redeliveryPolicy.backOffMultiplier=3&jms.redeliveryPolicy.collisionAvoidanceFactor=0.16&jms.redeliveryPolicy.initialRedeliveryDelay=2000&jms.redeliveryPolicy.maximumRedeliveryDelay=1&jms.redeliveryPolicy.redeliveryDelay=20&jms.redeliveryPolicy.useCollisionAvoidance=true&jms.redeliveryPolicy.useExponentialBackOff=true"
        let connectionFactory = ActiveMQConnectionFactory(brokerURL)
        var connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()

        @Assert(connectionFactory.redeliveryPolicy.isSome())
        if (let Some(redeliveryPolicy) <- connectionFactory.redeliveryPolicy) {
            @Assert( 2, redeliveryPolicy.maximumRedeliveries)
            @Assert( Float64(3), redeliveryPolicy.backOffMultiplier)
            @Assert( Float64(0.16), redeliveryPolicy.collisionAvoidanceFactor)
            @Assert( 2000, redeliveryPolicy.initialRedeliveryDelay)
            @Assert( 1, redeliveryPolicy.maximumRedeliveryDelay)
            @Assert( 20, redeliveryPolicy.redeliveryDelay)
            @Assert( true, redeliveryPolicy.useCollisionAvoidance)
            @Assert( true, redeliveryPolicy.useExponentialBackOff)
        }

        @Assert(connection.getRedeliveryPolicy().isSome())
        if (let Some(redeliveryPolicy) <- connection.getRedeliveryPolicy()) {
            @Assert( 2, redeliveryPolicy.maximumRedeliveries)
            @Assert( Float64(3), redeliveryPolicy.backOffMultiplier)
            @Assert( Float64(0.16), redeliveryPolicy.collisionAvoidanceFactor)
            @Assert( 2000, redeliveryPolicy.initialRedeliveryDelay)
            @Assert( 1, redeliveryPolicy.maximumRedeliveryDelay)
            @Assert( 20, redeliveryPolicy.redeliveryDelay)
            @Assert( true, redeliveryPolicy.useCollisionAvoidance)
            @Assert( true, redeliveryPolicy.useExponentialBackOff)
        }
    }

    @TestCase
    public func testUseURIToConfigurePrefetchPolicy(): Unit {
        let brokerURL = "tcp://localhost?jms.prefetchPolicy.queuePrefetch=500&jms.prefetchPolicy.queueBrowserPrefetch=200&jms.prefetchPolicy.topicPrefetch=10&jms.prefetchPolicy.durableTopicPrefetch=50&jms.prefetchPolicy.optimizeDurableTopicPrefetch=1&jms.prefetchPolicy.maximumPendingMessageLimit=20"
        let connectionFactory = ActiveMQConnectionFactory(brokerURL)
        var connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()

        let prefetchPolicy = connectionFactory.prefetchPolicy
        @Assert( 500, prefetchPolicy.queuePrefetch)
        @Assert( 200, prefetchPolicy.queueBrowserPrefetch)
        @Assert( 10, prefetchPolicy.topicPrefetch)
        @Assert( 50, prefetchPolicy.durableTopicPrefetch)
        @Assert( 1, prefetchPolicy.optimizeDurableTopicPrefetch)
        @Assert( 20, prefetchPolicy.maximumPendingMessageLimit)

        let prefetchPolicy2 = connection.prefetchPolicy
        @Assert( 500, prefetchPolicy2.queuePrefetch)
        @Assert( 200, prefetchPolicy2.queueBrowserPrefetch)
        @Assert( 10, prefetchPolicy2.topicPrefetch)
        @Assert( 50, prefetchPolicy2.durableTopicPrefetch)
        @Assert( 1, prefetchPolicy2.optimizeDurableTopicPrefetch)
        @Assert( 20, prefetchPolicy2.maximumPendingMessageLimit)
    }

    @TestCase
    public func testGetBrokerName(): Unit {
        let connectionFactory = ActiveMQConnectionFactory("tcp://localhost?broker.persistent=false&broker.useJmx=false")
        var connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()
        connection.start()

        let brokerName = connection.brokerName
        logger.info("Got broker name: ${brokerName}")

        @Assert(brokerName.isSome())
    }

    @TestCase
    public func testSetExceptionListener(): Unit {
        let connectionFactory = ActiveMQConnectionFactory("tcp://localhost?broker.persistent=false&broker.useJmx=false")
        connectionFactory.exceptionListener = Option<ExceptionListener>.Some(ExListener())
        var connection = (connectionFactory.createConnection() as ActiveMQConnection).getOrThrow()

        @Assert(connection.exceptionListener.isSome())
    }
}

public class ExListener <: ExceptionListener {
    public func onException(exception: CJMSException): Unit {
    }
}
