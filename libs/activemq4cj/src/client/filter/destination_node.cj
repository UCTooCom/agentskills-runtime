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

public interface DestinationNode<T> <: Equatable<DestinationNode<T>> & Hashable where T <: Equatable<T> & Hashable {
    func appendMatchingValues(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, startIndex: Int64): Unit

    func appendMatchingWildcards(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, startIndex: Int64): Unit

    func appendDescendantValues(answer: Set<DestinationMapEntry<T>>): Unit

    func getDesendentValues(): Collection<DestinationMapEntry<T>>

    func getChild(path: String): ?DestinationNode<T>

    func getValues(): Collection<DestinationMapEntry<T>>

    func getChildren(): Collection<DestinationNode<T>>

    func removeDesendentValues(): Collection<DestinationMapEntry<T>>

    func removeValues(): Collection<DestinationMapEntry<T>>
}

public class DestinationMapNode<T> <: DestinationNode<T> & Equatable<DestinationMapNode<T>> where T <: Equatable<T> & Hashable {
    private var parent: ?DestinationMapNode<T> = None
    private let values: LinkedList<DestinationMapEntry<T>> = LinkedList<DestinationMapEntry<T>>()
    private let childNodes = HashMap<String, DestinationNode<T>>()
    private var path: String = "Root"
    private var pathLength: Int32 = 0

    public init(parent: ?DestinationMapNode<T>) {
        this.parent = parent
        if (let Some(parent) <- parent) {
            this.pathLength = parent.pathLength + 1
        } else {
            pathLength = 0
        }
    }

    /**
     * 获取子节点，不存在返回None
     */
    public func getChild(path: String): ?DestinationNode<T> {
        return childNodes.get(path)
    }

    public func getChildren(): Collection<DestinationNode<T>> {
        return childNodes.values()
    }

    public func getChildCount(): Int64 {
        return childNodes.size
    }

    public func getChildOrCreate(path: String): DestinationMapNode<T> {
        var answer: ?DestinationMapNode<T> = None
        if (let Some(childNode) <- getChild(path)) {
            if (let Some(child) <- (childNode as DestinationMapNode<T>)) {
                answer = child
                return child
            }
        }
        let childNode = DestinationMapNode(this)
        childNode.path = path
        childNodes.add(path, childNode)
        return childNode
    }

    public override func appendDescendantValues(answer: Set<DestinationMapEntry<T>>): Unit {
        // 添加子节点的values, 然后递归子节点
        answer.add(all: this.getValues())
        for (child in childNodes.values()) {
            child.appendDescendantValues(answer)
        }
    }

    public override func getValues(): Collection<DestinationMapEntry<T>> {
        return this.values
    }

    public func add(paths: Array<String>, idx: Int64, value: DestinationMapEntry<T>): Unit {
        if (idx >= paths.size) {
            values.addLast(value)
        } else {
            getChildOrCreate(paths[idx]).add(paths, idx + 1, value)
        }
    }

    public override func appendMatchingWildcards(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, idx: Int64): Unit {
        if (Int32(idx - 1) > pathLength) {
            return
        }
        var wildCardNode = getChild(ANY_CHILD)
        if (let Some(wildCardNode) <- wildCardNode) {
            wildCardNode.appendMatchingValues(answer, paths, idx + 1)
        }
        wildCardNode = getChild(ANY_DESCENDENT)
        if (let Some(wildCardNode) <- wildCardNode) {
            // for a wildcard Node match, add all values of the descendant node
            answer.add(all: wildCardNode.getValues())
            // and all descendants for paths like ">.>"
            answer.add(all: wildCardNode.getDesendentValues())
        }
    }

    public override func appendMatchingValues(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, idx: Int64): Unit {
        appendMatchingValues(answer, paths, idx, true)
    }

    public func appendMatchingValues(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, startIndex: Int64,
        deep: Bool): Unit {
        var node: ?DestinationNode<T> = this
        var couldMatchAny: Bool = true
        let size = paths.size
        for (i in startIndex..size) {
            if (let Some(current) <- node) {
                let path = paths[i]
                if (deep && path == ANY_DESCENDENT) {
                    answer.add(all: current.getDesendentValues());
                    couldMatchAny = false
                    break;
                }

                current.appendMatchingWildcards(answer, paths, i)

                if (path == ANY_CHILD) {
                    node = AnyChildDestinationNode(current)
                } else {
                    node = current.getChild(path)
                }
            } else {
                break
            }
        }
        if (let Some(node) <- node) {
            answer.add(all: node.getValues())
            if (couldMatchAny) {
                // lets allow FOO.BAR to match the FOO.BAR.> entry in the map
                let child = node.getChild(ANY_DESCENDENT)
                if (let Some(child) <- child) {
                    answer.add(all: child.getValues())
                }
            }
        }
    }

    public func getDesendentValues(): HashSet<DestinationMapEntry<T>> {
        let answer = HashSet<DestinationMapEntry<T>>()
        appendDescendantValues(answer)
        return answer
    }

    public func removeDesendentValues(): Collection<DestinationMapEntry<T>> {
        let answer = HashSet<DestinationMapEntry<T>>()
        removeDesendentValues(answer)
        return answer
    }

    public func removeDesendentValues(answer: Set<DestinationMapEntry<T>>): Unit {
        let candidates = LinkedList<DestinationNode<T>>()
        Collections.addAll(childNodes.values(), candidates)

        for (node in candidates) {
            // remove all the values from the child
            node.removeValues()
            answer.add(all: node.removeDesendentValues())
        }
    }

    public func remove(paths: Array<String>, idx: Int64, value: DestinationMapEntry<T>): Unit {
        if (idx >= paths.size) {
            values.removeIf({e: DestinationMapEntry<T> => e == value})
            pruneIfEmpty()
        } else {
            let index = idx + 1
            getChildOrCreate(paths[idx]).remove(paths, index, value)
        }
    }

    public func removeAll(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, startIndex: Int64) {
        var node: ?DestinationNode<T> = this
        let size = paths.size
        for (i in startIndex..size) {
            if (let Some(current) <- node) {
                let path = paths[i]
                if (path == ANY_DESCENDENT) {
                    answer.add(all: current.removeDesendentValues())
                    break
                }

                current.appendMatchingWildcards(answer, paths, i)
                if (path == ANY_CHILD) {
                    node = AnyChildDestinationNode(current)
                } else {
                    node = current.getChild(path)
                }
            }
        }
        if (let Some(node) <- node) {
            answer.add(all: node.removeValues())
        }
    }

    public func removeValues(): Collection<DestinationMapEntry<T>> {
        let v = LinkedList<DestinationMapEntry<T>>(values)
        values.clear()
        pruneIfEmpty()
        return v
    }

    protected func pruneIfEmpty(): Unit {
        if (let Some(parent) <- parent) {
            if (childNodes.isEmpty() && values.isEmpty()) {
                parent.removeChild(this)
            }
        }
    }

    protected func removeChild(node: DestinationMapNode<T>): Unit {
        childNodes.remove(node.path)
        pruneIfEmpty()
    }

    public func checkEquals(other: DestinationMapNode<T>): Bool {
        if (this.parent != other.parent) {
            return false
        }
        if (this.values != other.values) {
            return false
        }
        if (this.childNodes != other.childNodes) {
            return false
        }
        if (this.path != other.path) {
            return false
        }
        if (this.pathLength != other.pathLength) {
            return false
        }
        return true
    }

    public operator func ==(other: DestinationNode<T>): Bool {
        if (!(other is DestinationMapNode<T>)) {
            return false
        }
        if (let Some(other) <- (other as DestinationMapNode<T>)) {
            if (!this.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DestinationNode<T>): Bool {
        if (!(other is DestinationMapNode<T>)) {
            return true
        }
        if (let Some(other) <- (other as DestinationMapNode<T>)) {
            if (!this.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public operator func ==(other: DestinationMapNode<T>): Bool {
        if (!this.checkEquals(other)) {
            return false
        }
        return true
    }

    public operator func !=(other: DestinationMapNode<T>): Bool {
        if (!this.checkEquals(other)) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        let prime = 53
        var hashCode = prime * parent.hashCode()
        hashCode += prime * path.hashCode()
        hashCode += prime * pathLength.hashCode()
        return hashCode
    }
}

public open class AnyChildDestinationNode<T> <: DestinationNode<T> where T <: Equatable<T> & Hashable {
    private var node: DestinationNode<T>

    public init(node: DestinationNode<T>) {
        this.node = node
    }

    public func appendMatchingValues(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, startIndex: Int64) {
        for (child in getChildNodes()) {
            child.appendMatchingValues(answer, paths, startIndex)
        }
    }

    public func appendMatchingWildcards(answer: Set<DestinationMapEntry<T>>, paths: Array<String>, startIndex: Int64): Unit {
        for (child in getChildNodes()) {
            child.appendMatchingWildcards(answer, paths, startIndex)
        }
    }

    public func appendDescendantValues(answer: Set<DestinationMapEntry<T>>): Unit {
        for (child in getChildNodes()) {
            child.appendDescendantValues(answer)
        }
    }

    public func getChild(path: String): ?DestinationNode<T> {
        let list = LinkedList<DestinationNode<T>>()
        for (child in getChildNodes()) {
            if (let Some(answer) <- child.getChild(path)) {
                list.addLast(answer)
            }
        }
        if (!list.isEmpty()) {
            return CustomAnyChildDestinationNode<T>(this, list)
        }
        return None
    }

    public func getDesendentValues(): Collection<DestinationMapEntry<T>> {
        let answer = LinkedList<DestinationMapEntry<T>>()
        for (child in getChildNodes()) {
            Collections.addAll<DestinationMapEntry<T>>(child.getDesendentValues(), answer)
        }
        return answer
    }

    public func getValues(): Collection<DestinationMapEntry<T>> {
        let answer = LinkedList<DestinationMapEntry<T>>()
        for (child in getChildNodes()) {
            Collections.addAll<DestinationMapEntry<T>>(child.getValues(), answer)
        }
        return answer
    }

    public override func getChildren(): Collection<DestinationNode<T>> {
        let answer = LinkedList<DestinationNode<T>>()
        for (child in getChildNodes()) {
            Collections.addAll<DestinationNode<T>>(child.getChildren(), answer)
        }
        return answer
    }

    public func removeDesendentValues(): Collection<DestinationMapEntry<T>> {
        let answer = LinkedList<DestinationMapEntry<T>>()
        for (child in getChildNodes()) {
            Collections.addAll<DestinationMapEntry<T>>(child.removeDesendentValues(), answer)
        }
        return answer
    }

    public func removeValues(): Collection<DestinationMapEntry<T>> {
        let answer = LinkedList<DestinationMapEntry<T>>()
        for (child in getChildNodes()) {
            Collections.addAll<DestinationMapEntry<T>>(child.removeValues(), answer)
        }
        return answer
    }

    protected open func getChildNodes(): Collection<DestinationNode<T>> {
        return node.getChildren()
    }

    public open operator func ==(other: DestinationNode<T>): Bool {
        if (!(other is AnyChildDestinationNode<T>)) {
            return false
        }
        if (let Some(other) <- (other as AnyChildDestinationNode<T>)) {
            if (this.node != other.node) {
                return false
            }
        }
        return true
    }

    public open operator func !=(other: DestinationNode<T>): Bool {
        if (!(other is AnyChildDestinationNode<T>)) {
            return true
        }
        if (let Some(other) <- (other as AnyChildDestinationNode<T>)) {
            if (this.node != other.node) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public open func hashCode(): Int64 {
        let prime = 53
        return prime * node.hashCode()
    }
}

public class CustomAnyChildDestinationNode<T> <: AnyChildDestinationNode<T> where T <: Equatable<T> & Hashable {
    private let childNodes: LinkedList<DestinationNode<T>>

    public init(node: DestinationNode<T>, childNodes: LinkedList<DestinationNode<T>>) {
        super(node)
        this.childNodes = childNodes
    }

    protected func getChildNodes(): Collection<DestinationNode<T>> {
        return childNodes
    }

    public operator func ==(other: DestinationNode<T>): Bool {
        if (!(other is CustomAnyChildDestinationNode<T>)) {
            return false
        }
        if (let Some(other) <- (other as CustomAnyChildDestinationNode<T>)) {
            if (this.childNodes != other.childNodes) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DestinationNode<T>): Bool {
        if (!(other is CustomAnyChildDestinationNode<T>)) {
            return true
        }
        if (let Some(other) <- (other as CustomAnyChildDestinationNode<T>)) {
            if (this.childNodes != other.childNodes) {
                return false
            }
        }
        return false
    }
}
