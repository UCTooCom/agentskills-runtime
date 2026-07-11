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
package activemq4cj.client.filter

protected let ANY_DESCENDENT: String = ">"
protected let ANY_CHILD: String = "*"

public open class DestinationMap<T> where T <: Equatable<T> & Hashable {
    public let monitor = Monitor()

    private var queueRootNode: DestinationMapNode<T> = DestinationMapNode(None)
    private var tempQueueRootNode: DestinationMapNode<T> = DestinationMapNode(None)
    private var topicRootNode: DestinationMapNode<T> = DestinationMapNode(None)
    private var tempTopicRootNode: DestinationMapNode<T> = DestinationMapNode(None)

    public func get(key: ActiveMQDestination): Set<DestinationMapEntry<T>> {
        synchronized(monitor) {
            return unsynchronizedGet(key)
        }
    }

    public func unsynchronizedGet(key: ActiveMQDestination): Set<DestinationMapEntry<T>> {
        if (key.isComposite()) {
            if (let Some(destinations) <- key.getCompositeDestinations()) {
                let answer: Set<DestinationMapEntry<T>> = HashSet(destinations.size)
                for (i in 0..destinations.size) {
                    let childDestination: ActiveMQDestination = destinations[i]
                    let value = unsynchronizedGet(childDestination)
                    answer.add(all: value)
                }
                return answer
            }
        }
        return findWildcardMatches(key)
    }

    public func put(key: ActiveMQDestination, value: DestinationMapEntry<T>): Unit {
        synchronized(monitor) {
            unsynchronizedPut(key, value)
        }
    }

    public func unsynchronizedPut(key: ActiveMQDestination, value: DestinationMapEntry<T>): Unit {
        if (key.isComposite()) {
            let destinations: ?Array<ActiveMQDestination> = key.getCompositeDestinations()
            if (let Some(destinations) <- destinations) {
                for (i in 0..destinations.size) {
                    let childDestination: ActiveMQDestination = destinations[i]
                    put(childDestination, value)
                }
            }
            return
        }
        let paths = key.getDestinationPaths()
        getRootNode(key).add(paths, 0, value)
    }

    protected func getRootNode(key: ActiveMQDestination): DestinationMapNode<T> {
        if (key.isTemporary()) {
            if (key.isQueue()) {
                return tempQueueRootNode
            } else {
                return tempTopicRootNode
            }
        } else {
            if (key.isQueue()) {
                return queueRootNode
            } else {
                return topicRootNode
            }
        }
    }

    protected func findWildcardMatches(key: ActiveMQDestination): Set<DestinationMapEntry<T>> {
        return findWildcardMatches(key, true)
    }

    protected func findWildcardMatches(key: ActiveMQDestination, deep: Bool): Set<DestinationMapEntry<T>> {
        let paths = key.getDestinationPaths()
        let answer = HashSet<DestinationMapEntry<T>>()
        getRootNode(key).appendMatchingValues(answer, paths, 0, deep)
        return answer
    }

    public func removeAll(key: ActiveMQDestination): Set<DestinationMapEntry<T>> {
        let rc = HashSet<DestinationMapEntry<T>>()
        if (key.isComposite()) {
            if (let Some(destinations) <- key.getCompositeDestinations()) {
                for (destination in destinations) {
                    rc.add(all: removeAll(destination))
                }
                return rc
            }
        }
        let paths: Array<String> = key.getDestinationPaths()
        getRootNode(key).removeAll(rc, paths, 0)
        return rc
    }

    public func chooseValue(destination: ActiveMQDestination): ?T {
        let set = get(destination)
        if (set.isEmpty()) {
            return Option<T>.None
        }
        //TODO 使用DestinationFilter过滤不匹配项
        let array: Array<DestinationMapEntry<T>> = set.toArray()
        array.sort(stable: true)
        return array[0].getValue()
    }

    public func remove(key: ActiveMQDestination, value: DestinationMapEntry<T>): Unit {
        synchronized(monitor) {
            unsynchronizedRemove(key, value)
        }
    }

    public func unsynchronizedRemove(key: ActiveMQDestination, value: DestinationMapEntry<T>): Unit {
        if (key.isComposite()) {
            let destinations: ?Array<ActiveMQDestination> = key.getCompositeDestinations()
            if (let Some(destinations) <- destinations) {
                for (childDestination in destinations) {
                    remove(childDestination, value)
                }
            }
            return
        }
        let paths: Array<String> = key.getDestinationPaths()
        getRootNode(key).remove(paths, 0, value)
    }

    public func getTopicRootChildCount(): Int64 {
        return topicRootNode.getChildCount()
    }

    public func getQueueRootChildCount(): Int64 {
        return queueRootNode.getChildCount()
    }

    public func getQueueRootNode(): DestinationMapNode<T> {
        return queueRootNode
    }

    public func getTopicRootNode(): DestinationMapNode<T> {
        return topicRootNode
    }

    public func getTempQueueRootNode(): DestinationMapNode<T> {
        return tempQueueRootNode
    }

    public func getTempTopicRootNode(): DestinationMapNode<T> {
        return tempTopicRootNode
    }

    public func reset(): Unit {
        queueRootNode = DestinationMapNode(None)
        tempQueueRootNode = DestinationMapNode(None)
        topicRootNode = DestinationMapNode(None)
        tempTopicRootNode = DestinationMapNode(None)
    }
}
