/**
 * HTTP/2 优先级树实现（RFC 7540 §5.3）。
 *
 * 注意：RFC 9113 已弃用 PRIORITY 帧和优先级树管理。
 * 本实现保留用于兼容旧版服务器，但新部署不应依赖优先级流控制。
 */
package http_lib.http2

import std.collection.{ArrayList, HashMap}
/**
 * HTTP/2 优先级树中的单个节点。
 * 包含流 ID、权重（1-256）、父节点引用、排他标志和子节点列表。
 */

/**
 * HTTP/2。
 */

/**
 * A single node in the HTTP/2 优先级树.
 */
public class PriorityNode {
    public let streamId: UInt32
    public var weight: UInt8      // 1-256（默认 16）
    public var parent: ?UInt32    // 父流 ID（0 表示根节点）
    public var exclusive: Bool
    public var children: ArrayList<UInt32>

    public init(streamId: UInt32, weight!: UInt8 = 16, parent!: ?UInt32 = None, exclusive!: Bool = false) {
        this.streamId = streamId
        this.weight = if (weight < 1) { 1 } else { weight }
        this.parent = parent
        this.exclusive = exclusive
        this.children = ArrayList<UInt32>()
    }
}

/**
 * HTTP/2 优先级树 scheduler.
 *
 * 管理流的依赖树，根据 RFC 9113 Section 5.3 优先级规则
 * 提供公平调度。
 */
public class PriorityTree {
    private var nodes: HashMap<UInt32, PriorityNode>
    // 根节点是隐式的（流 0）

    public init() {
        this.nodes = HashMap<UInt32, PriorityNode>()
    }

    /**
     * Add or update a stream in the 优先级树.
     */
    public func addStream(streamId: UInt32, weight!: UInt8 = 16, parent!: ?UInt32 = None, exclusive!: Bool = false): Unit {
        // 按 RFC 9113 Section 5.3.1：流不得依赖自身
        match (parent) {
            case Some(p) =>
                if (p == streamId) { return }
            case None =>
                // parent=None 快速路径：无需建立依赖关系，只需创建/更新节点
                match (nodes.get(streamId)) {
                    case Some(existing) =>
                        existing.weight = if (weight < 1) { 1 } else { weight }
                        if (existing.parent.isSome()) {
                            reparent(streamId, existing.parent.getOrThrow(), false)
                        }
                    case None =>
                        nodes[streamId] = PriorityNode(streamId, weight: weight, parent: None, exclusive: false)
                }
                return
        }
        match (nodes.get(streamId)) {
            case Some(existing) =>
                // 更新现有节点
                existing.weight = if (weight < 1) { 1 } else { weight }
                if (parent.isSome()) {
                    reparent(streamId, parent.getOrThrow(), exclusive)
                }
            case None =>
                let node = PriorityNode(streamId, weight: weight, parent: parent, exclusive: exclusive)
                nodes[streamId] = node
                match (parent) {
                    case Some(p) =>
                        if (p != 0) {
                            match (nodes.get(p)) {
                                case Some(parentNode) =>
                                    if (exclusive) {
                                        // 将父节点现有子节点移至该流下
                                        for (child in parentNode.children) {
                                            match (nodes.get(child)) {
                                                case Some(childNode) => childNode.parent = Some(streamId)
                                                case None => ()
    /**
     * 向优先级树添加或更新流。
     * 若流已存在则更新权重和依赖关系；若为新流则创建节点。
     * 排他模式下，父节点的所有现有子节点被重分配给新流。
     */
                                            }
                                        }
                                        node.children = parentNode.children
                                        parentNode.children = ArrayList<UInt32>()
                                    }
                                    parentNode.children.add(streamId)
                                case None => ()
                            }
                        }
                    case None => ()
                }
        }
    }

    /**
     * Remove a stream from the 优先级树.
     */
    public func removeStream(streamId: UInt32): Unit {
    /**
     * 从优先级树移除流。
     * 将被移除流的子节点重新指定给被移除流的父节点，
     * 防止孤儿节点产生。
     */
        match (nodes.get(streamId)) {
            case Some(node) =>
                // 将子节点重新指定给被移除流的父节点
                let parentId = node.parent
                for (childId in node.children) {
                    match (nodes.get(childId)) {
                        case Some(child) =>
                            child.parent = parentId
                            match (parentId) {
                                case Some(pid) =>
                                    match (nodes.get(pid)) {
                                        case Some(pNode) => pNode.children.add(childId)
                                        case None => ()
                                    }
                                case None => ()
    /**
     * 处理 PRIORITY 帧的流依赖更新。
     * 按 RFC 9113 §5.3.1 处理依赖变更，包含循环检测。
     */
                            }
                        case None => ()
                    }
                }
                // 从父节点子列表中移除
                match (parentId) {
                    case Some(pid) =>
                        match (nodes.get(pid)) {
                            case Some(pNode) => removeFromList(pNode.children, streamId)
    /**
     * 获取基于优先级顺序应写入的下一个流。
     * 使用加权调度：得分 = weight / (writeCount + 1)，最高分获胜。
     * 权重更高的流获得更多带宽。
     */
                            case None => ()
                        }
                    case None => ()
                }
                nodes.remove(streamId)
            case None => ()
        }
    }

    /**
     * 处理 PRIORITY 帧的流依赖更新。
     */
    public func processPriority(streamId: UInt32, exclusive: Bool, streamDep: UInt32, weight: UInt8): Unit {
        addStream(streamId, weight: weight, parent: Some(streamDep), exclusive: exclusive)
    }

    /**
     * 获取基于优先级顺序应写入的下一个流。
     * 使用加权调度：权重更高的流获得更多带宽。
     * 得分 = weight / (writeCount + 1) — 最高分获胜。
     *
     * 返回最高优先级的流 ID，如果没有流则返回 None。
     */
    public func nextWritableStream(readyStreams: ArrayList<UInt32>): ?UInt32 {
        if (readyStreams.size == 0) { return None }
        if (readyStreams.size == 1) { return readyStreams[0] }

        var bestStream: ?UInt32 = None
        var bestScore: Float64 = -1.0

        for (sid in readyStreams) {
            let weight = getWeight(sid)
            let wc = getWriteCount(sid)
            let score = Float64(weight) / Float64(wc + 1)
            if (score > bestScore) {
                bestScore = score
                bestStream = Some(sid)
            }
        }

        match (bestStream) {
            case Some(bs) =>
                incrementWriteCount(bs)
                Some(bs)
            case None => readyStreams[0]
        }
    }

    /**
     * 跟踪每个流的写入计数以实现加权轮询。
     * 设置上限以防止导致 weight/writeCount 收敛到 0 的无限增长。
     * 当任何计数器超过 WRITE_COUNT_MAX 时，所有计数器被重置以保持
     * 有意义的分数差异化（RFC 9113 第 5.3 节）。
     */
    private let WRITE_COUNT_MAX: Int64 = 1000
    private var writeCounts: HashMap<UInt32, Int64> = HashMap<UInt32, Int64>()

    private func getWriteCount(streamId: UInt32): Int64 {
        match (writeCounts.get(streamId)) {
            case Some(c) => c
            case None => 0
        }
    }

    private func incrementWriteCount(streamId: UInt32): Unit {
        let current = getWriteCount(streamId)
        let newCount = current + 1
        // 如果任何计数器超过最大值，重置所有计数器以防止
        // 所有流的 weight/writeCount 比率收敛到 0
        if (newCount > WRITE_COUNT_MAX) {
            writeCounts.clear()
            writeCounts[streamId] = 1
        } else {
            writeCounts[streamId] = newCount
        }
    }

    /**
     * 重置写入计数器（定期调用以允许公平重新分配）。
     */
    public func resetWriteCounters(): Unit {
        writeCounts.clear()
    }

    /**
     * 获取流的权重（默认为 16）。
     */
    public func getWeight(streamId: UInt32): UInt8 {
        match (nodes.get(streamId)) {
            case Some(node) => node.weight
            case None => 16
        }
    }

    /**
     * 检查流是否有子节点。
     */
    public func hasChildren(streamId: UInt32): Bool {
        match (nodes.get(streamId)) {
            case Some(node) => node.children.size > 0
            case None => false
        }
    }

    /**
     * 按优先级顺序获取所有叶子流（无子节点的流）。
     */
    public func leafStreams(): ArrayList<UInt32> {
        let result = ArrayList<UInt32>()
        for ((id, node) in nodes) {
            if (node.children.size == 0) {
                result.add(id)
            }
        }
        result
    }

    /**
     * 清除树中的所有节点。
     */
    public func clear(): Unit {
        nodes.clear()
    }

    // ---- 内部 ----

    /**
     * 检查 streamId 是否通过树依赖于 newParent（用于循环检测）。
     * 如果 newParent 是 streamId 的后代则会创建循环，返回 true。
     */
    private func wouldCreateCycle(streamId: UInt32, newParent: UInt32): Bool {
        if (newParent == 0 || newParent == streamId) { return true }
        var current = newParent
        while (true) {
            match (nodes.get(current)) {
                case Some(node) =>
                    match (node.parent) {
                        case Some(pid) =>
                            if (pid == streamId) { return true }
                            current = pid
                        case None => return false
                    }
                case None => return false
            }
        }
        false
    }

    private func reparent(streamId: UInt32, newParent: UInt32, exclusive: Bool): Unit {
        // 按 RFC 9113 Section 5.3.1：流不得依赖自身
        if (streamId == newParent) { return }
        // 检查循环：newParent 不得是 streamId 的后代
        if (wouldCreateCycle(streamId, newParent)) { return }
        match (nodes.get(streamId)) {
            case Some(node) =>
                // 从旧父节点的子节点中移除
                match (node.parent) {
                    case Some(oldPid) =>
                        match (nodes.get(oldPid)) {
                            case Some(oldP) => removeFromList(oldP.children, streamId)
                            case None => ()
                        }
                    case None => ()
                }
                node.parent = Some(newParent)
                // 添加到新父节点
                match (nodes.get(newParent)) {
                    case Some(np) =>
                        if (exclusive) {
                            for (child in np.children) {
                                match (nodes.get(child)) {
                                    case Some(cNode) => cNode.parent = Some(streamId)
                                    case None => ()
                                }
                            }
                            node.children = np.children
                            np.children = ArrayList<UInt32>()
                        }
                        np.children.add(streamId)
                    case None => ()
                }
            case None => ()
        }
    }

    private func removeFromList(list: ArrayList<UInt32>, id: UInt32): Unit {
        var i: Int64 = 0
        while (i < list.size) {
            if (list[i] == id) {
                list.remove(i..i + 1)
                return
            }
            i += 1
        }
    }
}
