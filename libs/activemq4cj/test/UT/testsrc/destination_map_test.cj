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
public class DestinationMapTest {
    private let map: DestinationMap<String> = DestinationMap<String>()
    private let map2: DestinationMap<ActiveMQDestination> = DestinationMap<ActiveMQDestination>()
    private let d1: ActiveMQDestination = ActiveMQTopic("TEST.D1")
    private let d2: ActiveMQDestination = ActiveMQTopic("TEST.BAR.D2")
    private let d3: ActiveMQDestination = ActiveMQTopic("TEST.BAR.D3")

    private let compositeDestination1: ActiveMQDestination = ActiveMQTopic("TEST.D1,TEST.BAR.D2")
    private let compositeDestination2: ActiveMQDestination = ActiveMQTopic("TEST.D1,TEST.BAR.D3")

    protected let v1 = "value1"
    protected let v2 = "value2"
    protected let v3 = "value3"
    protected let v4 = "value4"
    protected let v5 = "value5"
    protected let v6 = "value6"

    @TestCase
    public func testLongDestinationPath(): Unit {
        let d4 = ActiveMQTopic("1.2.3.4.5.6.7.8.9.10.11.12.13.14.15.16.17.18")
        let map = DestinationMap<ActiveMQDestination>()
        map.put(d4, DestinationMapEntry<ActiveMQDestination>(d4))
    }

    @TestCase
    public func testVeryLongestinationPaths(): Unit {
        for (i in 0..100) {
            var name = "1"
            for (j in 2..i + 1) {
                name = name + "." + j.toString()
            }
            // println("Checking: " + name)
            let d1 = createDestination(name)
            let map = DestinationMap<ActiveMQDestination>()
            map.put(d1, DestinationMapEntry<ActiveMQDestination>(d1))
        }
    }

    @TestCase
    public func testtestTempDestinations(): Unit {
        let id = IdGenerator().generateId()
        let map = DestinationMap<String>()
        let value = "value"
        let count = 1000
        for (i in 0..count) {
            let queue = ActiveMQTempQueue(id, i)
            map.put(queue, DestinationMapEntry<String>(value))
        }
        for (i in 0..count) {
            let queue = ActiveMQTempQueue(id, i)
            map.remove(queue, DestinationMapEntry<String>(value))
            let set = map.get(queue)
            @Assert(set.isEmpty())
        }
    }

    @TestCase
    public func testCompositeDestinations(): Unit {
        let d1 = createDestination("TEST.BAR.D2")
        let d2 = createDestination("TEST.BAR.D3")
        map2.put(d1, DestinationMapEntry<ActiveMQDestination>(d1))
        map2.put(d2, DestinationMapEntry<ActiveMQDestination>(d2))
        map.get(createDestination("TEST.BAR.D2,TEST.BAR.D3"))
    }

    @TestCase
    public func testSimpleDestinations(): Unit {
        map.put(d1, DestinationMapEntry<String>(v1))
        map.put(d2, DestinationMapEntry<String>(v2))
        map.put(d3, DestinationMapEntry<String>(v3))

        assertMapValue(d1, v1)
        assertMapValue(d2, v2)
        assertMapValue(d3, v3)
    }

    @TestCase
    public func testQueueAndTopicWithSameName(): Unit {
        let q1 = ActiveMQQueue("foo")
        let t1 = ActiveMQTopic("foo")

        map.put(q1, DestinationMapEntry<String>(v1))
        map.put(t1, DestinationMapEntry<String>(v2))

        assertMapValue(q1, v1)
        assertMapValue(t1, v2)
    }

    @TestCase
    public func testSimpleDestinationsWithMultipleValues(): Unit {
        map.reset()
        map.put(d1, DestinationMapEntry<String>(v1))
        map.put(d2, DestinationMapEntry<String>(v2))
        map.put(d2, DestinationMapEntry<String>(v3))

        assertMapValue(d1, v1)
        assertMapValue("TEST.BAR.D2", v2, v3)
        assertMapValue(d3, None)
    }

    @TestCase
    public func testSimpleAndCompositeDestinations(): Unit {
        map.reset()
        map.put(d1, DestinationMapEntry<String>(v1))
        map.put(compositeDestination1, DestinationMapEntry<String>(v2))
        map.put(compositeDestination2, DestinationMapEntry<String>(v3))

        assertMapValue("TEST.D1", v1, v2, v3)
        assertMapValue(d2, v2)
        assertMapValue(d3, v3)
        assertMapValue(compositeDestination1.toString(), v1, v2, v3)
        assertMapValue(compositeDestination2.toString(), v1, v2, v3)

        map.remove(compositeDestination1, DestinationMapEntry<String>(v2))
        map.remove(compositeDestination2, DestinationMapEntry<String>(v3))

        assertMapValue("TEST.D1", v1)
    }

    @TestCase
    public func testLookupOneStepWildcardDestinations() {
        map.reset()
        map.put(d1, DestinationMapEntry<String>(v1))
        map.put(d2, DestinationMapEntry<String>(v2))
        map.put(d3, DestinationMapEntry<String>(v3))

        assertMapValue("TEST.D1", v1)
        assertMapValue("TEST.*", v1)
        assertMapValue("*.D1", v1)
        assertMapValue("*.*", v1)

        assertMapValue("TEST.BAR.D2", v2)
        assertMapValue("TEST.*.D2", v2)
        assertMapValue("*.BAR.D2", v2)
        assertMapValue("*.*.D2", v2)

        assertMapValue("TEST.BAR.D3", v3)
        assertMapValue("TEST.*.D3", v3)
        assertMapValue("*.BAR.D3", v3)
        assertMapValue("*.*.D3", v3)

        assertMapValue("TEST.BAR.D4", None)

        assertMapValue("TEST.BAR.*", v2, v3)
    }

    @TestCase
    public func testLookupMultiStepWildcardDestinations(): Unit {
        map.reset()
        map.put(d1, DestinationMapEntry<String>(v1))
        map.put(d2, DestinationMapEntry<String>(v2))
        map.put(d3, DestinationMapEntry<String>(v3))

        assertMapValue(">", v1, v2, v3)
        assertMapValue("TEST.>", v1, v2, v3)
        assertMapValue("*.>", v1, v2, v3)
        assertMapValue("TEST.*.>", v1, v2, v3)
        assertMapValue("TEST.*.*.>", v2, v3)

        assertMapValue("FOO.>", None)
    }

    @TestCase
    public func testStoreWildcardWithOneStepPath(): Unit {
        map.reset()
        put("TEST.*", v1)
        put("TEST.D1", v2)
        put("TEST.BAR.*", v2)
        put("TEST.BAR.D3", v3)

        assertMapValue("FOO", None)
        assertMapValue("TEST.FOO", v1)
        assertMapValue("TEST.D1", v1, v2)

        assertMapValue("TEST.FOO.FOO", None)
        assertMapValue("TEST.BAR.FOO", v2)
        assertMapValue("TEST.BAR.D3", v2, v3)

        assertMapValue("TEST.*", v1, v2)
        assertMapValue("*.D1", v1, v2)
        assertMapValue("*.*", v1, v2)
        assertMapValue("TEST.*.*", v2, v3)
        assertMapValue("TEST.BAR.*", v2, v3)
        assertMapValue("*.*.*", v2, v3)
        assertMapValue("*.BAR.*", v2, v3)
        assertMapValue("*.BAR.D3", v2, v3)
        assertMapValue("*.*.D3", v2, v3)
    }

    @TestCase
    public func testStoreWildcardInMiddleOfPath(): Unit {
        map.reset()
        put("TEST.*", v1)
        put("TEST.D1", v2)
        put("TEST.BAR.*", v2)
        put("TEST.XYZ.D3", v3)
        put("TEST.XYZ.D4", v4)
        put("TEST.BAR.D3", v5)
        put("TEST.*.D2", v6)

        assertMapValue("TEST.*.D3", v2, v3, v5)
        assertMapValue("TEST.*.D4", v2, v4)

        assertMapValue("TEST.*", v1, v2)
        assertMapValue("TEST.*.*", v2, v3, v4, v5, v6)
        assertMapValue("TEST.*.>", v1, v2, v3, v4, v5, v6)
        assertMapValue("TEST.>", v1, v2, v3, v4, v5, v6)
        assertMapValue("TEST.>.>", v1, v2, v3, v4, v5, v6)
        assertMapValue("*.*.D3", v2, v3, v5)
        assertMapValue("TEST.BAR.*", v2, v5, v6)

        assertMapValue("TEST.BAR.D2", v2, v6)
        assertMapValue("TEST.*.D2", v2, v6)
        assertMapValue("TEST.BAR.*", v2, v5, v6)
    }

    @TestCase
    public func testDoubleWildcardDoesNotMatchLongerPattern(): Unit {
        map.reset()
        put("TEST.*", v1)
        put("TEST.BAR.D3", v2)

        assertMapValue("*.*.D3", v2)
    }

    @TestCase
    public func testWildcardAtEndOfPathAndAtBeginningOfSearch(): Unit {
        map.reset()
        put("TEST.*", v1)

        assertMapValue("*.D1", v1)
    }

    @TestCase
    public func testAnyPathWildcardInMap(): Unit {
        map.reset()
        put("TEST.FOO.>", v1)

        assertMapValue("TEST.FOO.BAR.WHANOT.A.B.C", v1)
        assertMapValue("TEST.FOO.BAR.WHANOT", v1)
        assertMapValue("TEST.FOO.BAR", v1)

        assertMapValue("TEST.*.*", v1)
        assertMapValue("TEST.BAR", None)

        assertMapValue("TEST.FOO", v1)
    }

    @TestCase
    public func testSimpleAddRemove(): Unit {
        map.reset()
        put("TEST.D1", v2)

        @Assert(1, map.getTopicRootChildCount())

        assertMapValue("TEST.D1", v2)

        remove("TEST.D1", v2)

        @Assert(0, map.getTopicRootChildCount())
        assertMapValue("TEST.D1", None)
    }

    @TestCase
    public func testMQTTMappedWildcards(): Unit {
        map.reset()
        put("TopicA", v1)
        put(".TopicA", v2)
        put("TopicA.", v3)
        put(".", v4)
        put("..TopicA", v5)
        put("..", v6)

        // test wildcard patterns "#", "+", "+/#", "/+", "+/", "+/+", "+/+/", "+/+/+"
        assertMapValue(">", v1, v2, v3, v4, v5, v6)
        assertMapValue("*", v1)
        assertMapValue("*.>", v1, v2, v3, v4, v5, v6)
        assertMapValue(".*", v2, v4)
        assertMapValue("*.", v3, v4)
        assertMapValue("*.*", v2, v3, v4)
        assertMapValue("*.*.", v6)
        assertMapValue("*.*.*", v5, v6)
    }

    @TestCase
    public func testStoreAndLookupAllWildcards(): Unit {
        map.reset()
        loadSample2()

        assertSample2()

        // lets remove everything and add it back
        remove("TEST.FOO", v1)

        assertMapValue("TEST.FOO", v2, v3, v4)
        assertMapValue("TEST.*", v2, v3, v4, v6)
        assertMapValue("*.*", v2, v3, v4, v6)

        remove("TEST.XYZ", v6)

        assertMapValue("TEST.*", v2, v3, v4)
        assertMapValue("*.*", v2, v3, v4)

        remove("TEST.*", v2)

        assertMapValue("TEST.*", v3, v4)
        assertMapValue("*.*", v3, v4)

        remove(">", v4)

        assertMapValue("TEST.*", v3)
        assertMapValue("*.*", v3)

        remove("TEST.>", v3)
        remove("TEST.FOO.BAR", v5)

        assertMapValue("FOO", None)
        assertMapValue("TEST.FOO", None)
        assertMapValue("TEST.D1", None)

        assertMapValue("TEST.FOO.FOO", None)
        assertMapValue("TEST.BAR.FOO", None)
        assertMapValue("TEST.FOO.BAR", None)
        assertMapValue("TEST.BAR.D3", None)

        assertMapValue("TEST.*", None)
        assertMapValue("*.*", None)
        assertMapValue("*.D1", None)
        assertMapValue("TEST.*.*", None)
        assertMapValue("TEST.BAR.*", None)

        loadSample2()

        assertSample2()

        remove(">", v4)
        remove("TEST.*", v2)

        assertMapValue("FOO", None)
        assertMapValue("TEST.FOO", v1, v3)
        assertMapValue("TEST.D1", v3)

        assertMapValue("TEST.FOO.FOO", v3)
        assertMapValue("TEST.BAR.FOO", v3)
        assertMapValue("TEST.FOO.BAR", v3, v5)
        assertMapValue("TEST.BAR.D3", v3)

        assertMapValue("TEST.*", v1, v3, v6)
        assertMapValue("*.*", v1, v3, v6)
        assertMapValue("*.D1", v3)
        assertMapValue("TEST.*.*", v3, v5)
        assertMapValue("TEST.BAR.*", v3)
    }

    @TestCase
    public func testAddAndRemove(): Unit {
        map.reset()
        put("FOO.A", v1)
        assertMapValue("FOO.>", v1)

        put("FOO.B", v2)
        assertMapValue("FOO.>", v1, v2)

        map.removeAll(createDestination("FOO.A"))

        assertMapValue("FOO.>", v2)
    }

    @TestCase
    public func testRemoveWildcard(): Unit {
        map.reset()
        put("FOO.A", v1)
        put("FOO.>", v2)

        map.removeAll(createDestination("FOO.>"))

        assertMapValue("FOO.A", None)

        put("FOO.A", v1)
        put("FOO.>", v2)

        map.remove(createDestination("FOO.>"), DestinationMapEntry<String>(v2))

        assertMapValue("FOO.A", v1)
    }

    protected func loadSample2(): Unit {
        put("TEST.FOO", v1)
        put("TEST.*", v2)
        put("TEST.>", v3)
        put(">", v4)
        put("TEST.FOO.BAR", v5)
        put("TEST.XYZ", v6)
    }

    protected func assertSample2(): Unit {
        assertMapValue("FOO", v4)
        assertMapValue("TEST.FOO", v1, v2, v3, v4)
        assertMapValue("TEST.D1", v2, v3, v4)

        assertMapValue("TEST.FOO.FOO", v3, v4)
        assertMapValue("TEST.BAR.FOO", v3, v4)
        assertMapValue("TEST.FOO.BAR", v3, v4, v5)
        assertMapValue("TEST.BAR.D3", v3, v4)

        assertMapValue("TEST.*", v1, v2, v3, v4, v6)
        assertMapValue("*.*", v1, v2, v3, v4, v6)
        assertMapValue("*.D1", v2, v3, v4)
        assertMapValue("TEST.*.*", v3, v4, v5)
        assertMapValue("TEST.BAR.*", v3, v4)
    }

    protected func put(name: String, value: String): Unit {
        map.put(createDestination(name), DestinationMapEntry<String>(value))
    }

    protected func remove(name: String, value: String) {
        let destination = createDestination(name)
        map.remove(destination, DestinationMapEntry<String>(value))
    }

    protected func assertMapValue(destinationName: String, expected1: String, expected2: String, expected3: String) {
        let destination = createDestination(destinationName)
        let list = ArrayList<String>()
        list.add(expected1)
        list.add(expected2)
        list.add(expected3)
        assertMapValue(destination, list)
    }

    protected func assertMapValue(destinationName: String, expected1: String, expected2: String, expected3: String,
        expected4: String) {
        let destination = createDestination(destinationName)
        let list = ArrayList<String>()
        list.add(expected1)
        list.add(expected2)
        list.add(expected3)
        list.add(expected4)
        assertMapValue(destination, list)
    }

    protected func assertMapValue(destinationName: String, expected1: String, expected2: String, expected3: String,
        expected4: String, expected5: String) {
        let destination = createDestination(destinationName)
        let list = ArrayList<String>()
        list.add(expected1)
        list.add(expected2)
        list.add(expected3)
        list.add(expected4)
        list.add(expected5)
        assertMapValue(destination, list)
    }

    protected func assertMapValue(destinationName: String, expected1: String, expected2: String, expected3: String,
        expected4: String, expected5: String, expected6: String) {
        let destination = createDestination(destinationName)
        let list = ArrayList<String>()
        list.add(expected1)
        list.add(expected2)
        list.add(expected3)
        list.add(expected4)
        list.add(expected5)
        list.add(expected6)
        assertMapValue(destination, list)
    }

    protected func assertMapValue(destinationName: String, expected1: String, expected2: String) {
        let destination = createDestination(destinationName)
        let list = ArrayList<String>()
        list.add(expected1)
        list.add(expected2)
        assertMapValue(destination, list)
    }

    protected func assertMapValue(destination: ActiveMQDestination, expected: ArrayList<String>): Unit {
        let actualSet = map.get(destination)
        expected.sort(stable: true)
        let actualArray = actualSet.toArray()
        let valueList = ArrayList<String>(actualArray.size)
        for (entry in actualArray) {
            valueList.add(entry.getValue())
        }
        valueList.sort(stable: true)
        @Assert(valueList == expected)
    }

    protected func assertMapValue(destinationName: String, expected: ?String): Unit {
        let destination = createDestination(destinationName)
        assertMapValue(destination, expected)
    }

    protected func assertMapValue(destination: ActiveMQDestination, expected: ?String): Unit {
        let actual: ?String = map.chooseValue(destination)
        @Assert(actual == expected)
    }

    protected func createDestination(name: String): ActiveMQDestination {
        return ActiveMQTopic(name)
    }
}
