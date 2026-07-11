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
public class ActiveMQDestinationTest {
    @TestCase
    public func testCreateDestination(): Unit {
        var dest = ActiveMQDestination.createDestination("testQueue", ActiveMQDestination.QUEUE_TYPE)
        @Assert(dest.isQueue())
        @Assert(dest.name, "testQueue")

        dest = ActiveMQDestination.createDestination("queue://testQueue", ActiveMQDestination.TOPIC_TYPE)
        @Assert(dest.isQueue())
        @Assert(dest.name, "testQueue")

        dest = ActiveMQDestination.createDestination("testTopic", ActiveMQDestination.TOPIC_TYPE)
        @Assert(dest.isTopic())
        @Assert(dest.name, "testTopic")

        dest = ActiveMQDestination.createDestination("topic://testTopic", ActiveMQDestination.QUEUE_TYPE)
        @Assert(dest.isTopic())
        @Assert(dest.name, "testTopic")

        dest = ActiveMQDestination.createDestination("testTempQueue", ActiveMQDestination.TEMP_QUEUE_TYPE)
        @Assert(dest.isTemporary() && dest.isQueue())
        @Assert(dest.name, "testTempQueue")

        dest = ActiveMQDestination.createDestination("temp-queue://testTempQueue", ActiveMQDestination.QUEUE_TYPE)
        @Assert(dest.isTemporary() && dest.isQueue())
        @Assert(dest.name, "testTempQueue")

        dest = ActiveMQDestination.createDestination("testTempTopic", ActiveMQDestination.TEMP_TOPIC_TYPE)
        @Assert(dest.isTemporary() && dest.isTopic())
        @Assert(dest.name, "testTempTopic")

        dest = ActiveMQDestination.createDestination("temp-topic://testTempTopic", ActiveMQDestination.QUEUE_TYPE)
        @Assert(dest.isTemporary() && dest.isTopic())
        @Assert(dest.name, "testTempTopic")

        try {
            var queue = ActiveMQQueue("")
        } catch (ex: IllegalArgumentException) {
            @Assert(true)
        }

        dest = ActiveMQQueue("foo.bar.a,foo.bar.b")
        @Assert(dest.isComposite())
        @Assert(dest.getCompositeDestinations().isSome())
        if (let Some(compositeDestinations) <- dest.getCompositeDestinations()) {
            @Assert(compositeDestinations.size, 2)
            @Assert(compositeDestinations[0].isQueue() && compositeDestinations[0].name == "foo.bar.a")
            @Assert(compositeDestinations[1].isQueue() && compositeDestinations[1].name == "foo.bar.b")
        }
        @Assert(dest.getDestinationPaths(), Some(["foo","bar","a,foo","bar","b"]))
    }

    @TestCase
    public func testSetCompositeDestinations(): Unit {
        var q = ActiveMQQueue("A")
        @Assert(q.isComposite(), false)
        @Assert(q.getDestinationPaths(), Some(["A"]))
        q.setCompositeDestinations([ActiveMQQueue("testQueue"), ActiveMQTopic("testTopic")])
        @Assert(q.isComposite(), true)
        @Assert(q.name, "testQueue,topic://testTopic")
        @Assert(q.getDestinationPaths(), Some(["testQueue,topic://testTopic"]))

        q.setCompositeDestinations([])
        @Assert(q.isComposite(), true)
        @Assert(q.name, "")
        @Assert(q.getDestinationPaths(), [])
    }

    @TestCase
    public func testOptions(): Unit {
        var q = ActiveMQQueue("TEST?k1=v1&k2=v2")
        var options = q.options
        @Assert(options.isSome())
        if (let Some(options) <- options) {
            @Assert(Some("v1"), options.get("k1"))
            @Assert(Some("v2"), options.get("k2"))
        }
    }

    @TestCase
    public func testTransform(): Unit {
        var queue = ActiveMQQueue("TEST")
        @Assert(queue, ActiveMQDestination.transform(queue))

        @Assert(ActiveMQDestination.transform(CombyDest("TEST")) is ActiveMQQueue)
    }
}

class CombyDest <: Queue {
    private var queueName: String

    public init(queueName: String) {
        this.queueName = queueName
    }

    public func getQueueName(): String {
        return queueName
    }

    public func toString(): String {
        return "${queueName}"
    }
}
