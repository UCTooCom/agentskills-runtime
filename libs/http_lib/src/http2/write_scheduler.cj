/**
 * HTTP/2 写入调度器。
 *
 * 提供轮叫（Round-Robin）和优先级（Priority）两种调度策略。
 * 注意：RFC 9113 已弃用 PRIORITY 帧。此调度器与优先级树配合使用，
 * 新代码应考虑使用 RFC 9218 可扩展优先级方案。
 * 在多个活跃流之间公平分配发送带宽，
 * 控制帧（PING、SETTINGS、GOAWAY 等）始终优先于数据帧。
 */
package http_lib.http2
import std.collection.{ArrayDeque, ArrayList, HashMap}

/**
 * HTTP/2 帧写入请求（供调度器使用）。
 * FrameWriteRequest 模式。
 */
public class Http2FrameWriteRequest {
/**
 * HTTP/2 帧写入请求（供调度器使用）。
 * 包含流 ID、帧数据、控制帧标记和流量控制字节数。
 */
    public let streamId: UInt32
    public let frameData: Array<UInt8>
    public let isControl: Bool      // PING、SETTINGS、GOAWAY、RST_STREAM、WINDOW_UPDATE 返回 true
    public let flowControlBytes: Int64

    public init(streamId: UInt32, frameData: Array<UInt8>, isControl!: Bool = false, flowControlBytes!: Int64 = 0) {
        this.streamId = streamId
        this.frameData = frameData
        this.isControl = isControl
        this.flowControlBytes = flowControlBytes
/**
 * 轮询写入调度器。
 * 简单公平调度——每个流轮流写入一个帧。
 * 控制帧始终优先于数据帧。
 * 队列操作使用 ArrayDeque 实现 O(1) 头/尾操作。
 */
    }
}

/**
 * 轮询写入调度器.
 * 简单公平调度 —— 每个流轮流写入。
 * 控制帧（PING、SETTINGS、GOAWAY 等）始终优先。

 *
 * 队列操作使用 ArrayDeque 实现 O(1) 头/尾操作。
 */
    /**
     * 打开新流的写入队列。
     */
public class RoundRobinWriteScheduler {
    private var controlQueue: ArrayDeque<Http2FrameWriteRequest>
    private var streamQueues: HashMap<UInt32, ArrayDeque<Http2FrameWriteRequest>>
    private var streamOrder: ArrayList<UInt32>
    private var nextStreamIndex: Int64
    /**
     * 关闭流的写入队列并清理。
     */

    public init() {
        this.controlQueue = ArrayDeque<Http2FrameWriteRequest>()
        this.streamQueues = HashMap<UInt32, ArrayDeque<Http2FrameWriteRequest>>()
        this.streamOrder = ArrayList<UInt32>()
    /**
     * 将写入请求推入调度队列。
     * 控制帧进入独立的高优先级队列，数据帧按流分组。
     */
        this.nextStreamIndex = 0
    }

    public func openStream(streamId: UInt32): Unit {
    /**
     * 从调度队列取出下一个应写入的帧。
     * 控制帧始终优先；数据帧在流之间轮转调度。
     */
        if (!streamQueues.contains(streamId)) {
            streamQueues[streamId] = ArrayDeque<Http2FrameWriteRequest>()
            streamOrder.add(streamId)
        }
   }

   public func closeStream(streamId: UInt32): Unit {
       streamQueues.remove(streamId)
       var i: Int64 = 0
       while (i < streamOrder.size) {
           if (streamOrder[i] == streamId) { streamOrder.remove(i..i + 1); break }
           i += 1
       }
   }

    public func cleanup(): Unit {
        // RoundRobinWriteScheduler 的 closeStream 已直接移除流，
        // 无需额外清理操作。
    }

   public func push(wr: Http2FrameWriteRequest): Unit {
        if (wr.isControl) {
            controlQueue.addLast(wr)
/**
 * 优先级写入调度器。
 * 使用 PriorityTree 按权重对流写入进行排序和调度。
 * 权重较高的流获得比例更高的写入机会。
 * 控制帧始终优先于数据帧。
 */
            return
        }
        match (streamQueues.get(wr.streamId)) {
            case Some(queue) => queue.addLast(wr)
            case None =>
                let queue = ArrayDeque<Http2FrameWriteRequest>()
                queue.addLast(wr)
                streamQueues[wr.streamId] = queue
                streamOrder.add(wr.streamId)
        }
    /**
     * 打开新流的写入队列，可选指定优先级权重和依赖关系。
     */
    }

    public func pop(): ?Http2FrameWriteRequest {
        // 控制帧始终优先（ArrayDeque 实现 O(1)）
        if (controlQueue.size > 0) {
            return controlQueue.removeFirst()
        }

        if (streamOrder.size == 0) { return None }
    /**
     * 关闭流并清理相关优先级信息和写入队列。
     */

        var attempts: Int64 = 0
        while (attempts < streamOrder.size) {
            if (nextStreamIndex >= streamOrder.size) { nextStreamIndex = 0 }
            let sid = streamOrder[nextStreamIndex]
            nextStreamIndex += 1
    /**
     * 调整流的优先级（权重、依赖关系、排他标志）。
     */
            attempts += 1

            match (streamQueues.get(sid)) {
                case Some(queue) =>
                    if (queue.size > 0) {
                        return queue.removeFirst()
                    }
                case None => ()
            }
    /**
     * 推入写入请求。控制帧始终优先于数据帧。
     */
        }
        None
    }
}

/**
    /**
     * 弹出下一个应写入的帧。
     * 使用加权公平队列算法选择最佳流：得分 = weight / (writeCount + 1)。
     * 包含周期性计数器归一化防止精度损失和溢出。
     */
 * 优先级写入调度器.
 * 使用 PriorityTree 按权重对流写入进行排序。
 * 权重较高的流获得比例更高的写入机会。

 *
 * 队列操作使用 ArrayDeque 实现 O(1) 头/尾操作。
 */
public class PriorityWriteScheduler {
    private var controlQueue: ArrayDeque<Http2FrameWriteRequest>
    private var streamQueues: HashMap<UInt32, ArrayDeque<Http2FrameWriteRequest>>
    private var priorityTree: PriorityTree
    private var writeCounters: HashMap<UInt32, Int64>

    public init() {
        this.controlQueue = ArrayDeque<Http2FrameWriteRequest>()
        this.streamQueues = HashMap<UInt32, ArrayDeque<Http2FrameWriteRequest>>()
        this.priorityTree = PriorityTree()
        this.writeCounters = HashMap<UInt32, Int64>()
    }

    public func openStream(streamId: UInt32, weight!: UInt8 = 16, parent!: ?UInt32 = None): Unit {
        if (!streamQueues.contains(streamId)) {
            streamQueues[streamId] = ArrayDeque<Http2FrameWriteRequest>()
        }
        priorityTree.addStream(streamId, weight: weight, parent: parent)
        writeCounters[streamId] = 0
    }

    public func closeStream(streamId: UInt32): Unit {
        streamQueues.remove(streamId)
        priorityTree.removeStream(streamId)
        writeCounters.remove(streamId)
    }

    public func adjustStream(streamId: UInt32, exclusive: Bool, streamDep: UInt32, weight: UInt8): Unit {
        priorityTree.processPriority(streamId, exclusive, streamDep, weight)
        if (!writeCounters.contains(streamId)) {
            writeCounters[streamId] = 0
        }
    }

    public func push(wr: Http2FrameWriteRequest): Unit {
        if (wr.isControl) {
            controlQueue.addLast(wr)
            return
        }
        match (streamQueues.get(wr.streamId)) {
            case Some(queue) => queue.addLast(wr)
            case None =>
                let queue = ArrayDeque<Http2FrameWriteRequest>()
                queue.addLast(wr)
                streamQueues[wr.streamId] = queue
        }
    }

    public func pop(): ?Http2FrameWriteRequest {
        // 控制帧始终优先（ArrayDeque 实现 O(1)）
        if (controlQueue.size > 0) {
            return controlQueue.removeFirst()
        }

        var bestStreamId: UInt32 = 0
        var bestScore: Float64 = -1.0
        var maxCounter: Int64 = 0
        var activeStreamCount: Int64 = 0

        for ((sid, queue) in streamQueues) {
            if (queue.size > 0) { activeStreamCount += 1 }
            let writeCount = match (writeCounters.get(sid)) {
                case Some(c) => c
                case None => Int64(0)
            }
            if (writeCount > maxCounter) { maxCounter = writeCount }
        }

        if (activeStreamCount == 0) { return None }

        for ((sid, queue) in streamQueues) {
            if (queue.size == 0) { continue }
            let weight = priorityTree.getWeight(sid)
            let writeCount = match (writeCounters.get(sid)) {
                case Some(c) => c
                case None => Int64(0)
            }
            // 加权公平队列：得分 = 权重 / (writeCount + 1)
            let baseScore = Float64(weight) / Float64(writeCount + 1)
            // 抗饥饿：若流的未选中次数远超其权重期望的间隔，给予饥渴补分
            // 正常服务间隔 = activeStreamCount * (256 / max(1, weight))
            let normalInterval = activeStreamCount * (256 / Int64(max(1, weight)))
            let behind = maxCounter - writeCount
            var starvationBonus: Float64 = 0.0
            if (behind > normalInterval * 3) {
                // 严重落后时，饥渴补分随落后程度线性增长
                starvationBonus = Float64(behind - normalInterval * 3) / Float64(normalInterval * 3)
            }
            let score = baseScore + starvationBonus
            if (score > bestScore) {
                bestScore = score
                bestStreamId = sid
            }
        }

        if (bestStreamId == 0) { return None }

        // 周期性计数器归一化：当任何计数器超过 1M 时，所有计数器减半
        // 以防止 Float64 精度损失和 Int64 溢出
        if (maxCounter > 1000000) {
            for ((sid, c) in writeCounters) {
                writeCounters[sid] = c / 2
            }
        }

        match (streamQueues.get(bestStreamId)) {
            case Some(queue) =>
                if (queue.size > 0) {
                    let wrOpt = queue.removeFirst()
                    match (writeCounters.get(bestStreamId)) {
                        case Some(c) => writeCounters[bestStreamId] = c + 1
                        case None => writeCounters[bestStreamId] = 1
                    }
                    return wrOpt
                }
            case None => ()
        }
        None
    }

    /**
     * 清理不再存在于 streamQueues 中的流的 writeCounters 陈旧条目。
     * 定期调用（例如流关闭后）以防止内存泄漏。
     */
    public func cleanup(): Unit {
        let stale = ArrayList<UInt32>()
        for ((sid, _) in writeCounters) {
            if (!streamQueues.contains(sid)) {
                stale.add(sid)
            }
        }
        for (sid in stale) {
            writeCounters.remove(sid)
        }
    }

    public func resetCounters(): Unit {
        writeCounters.clear()
    }
}
