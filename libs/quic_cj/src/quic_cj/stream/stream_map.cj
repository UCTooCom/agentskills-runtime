package quic_cj.stream

import quic_cj.protocol.{StreamId, StreamType, Perspective}

/// StreamMap 使用固定大小数组管理所有活跃的流。
public class StreamMap {
    private var streams: Array<Stream> = Array<Stream>(0, repeat: Stream(0, StreamType.Bidi, Perspective.Client))
    private var streamCount: Int64 = 0
    private var maxCapacity: Int64 = 0
    private let INITIAL_CAPACITY: Int64 = 4
    private let MAX_STREAMS: Int64 = 256

    public init() {}

    /// 返回现有流或打开一个新流。
    public func getOrOpenStream(id: StreamId): Stream {
        // 先搜索已有流
        var i: Int64 = 0
        while (i < streamCount) {
            if (streams[i].getStreamId() == id) { return streams[i] }
            i += 1
        }
        // 未找到，创建新流
        if (streamCount >= streams.size) { grow() }
        let stype = if (id % 4 >= 2) { StreamType.Uni } else { StreamType.Bidi }
        let pers = if (id % 2 == 0) { Perspective.Client } else { Perspective.Server }
        let stream = Stream(id, stype, pers)
        if (streamCount < MAX_STREAMS) {
            streams[streamCount] = stream
            streamCount += 1
        }
        stream
    }

    /// 扩容，避免预分配大量未使用的 Stream 对象
    private func grow(): Unit {
        let newCap = if (maxCapacity == 0) { INITIAL_CAPACITY } else { min(maxCapacity * 2, MAX_STREAMS) }
        if (newCap <= maxCapacity) { return }
        let newArr = Array<Stream>(newCap, repeat: Stream(0, StreamType.Bidi, Perspective.Client))
        var i: Int64 = 0
        while (i < streamCount) {
            newArr[i] = streams[i]
            i += 1
        }
        streams = newArr
        maxCapacity = newCap
    }

    /// 按顺序接收下一个流。
    public func acceptStream(): Stream {
        if (streamCount > 0) { return streams[0] }
        Stream(0, StreamType.Bidi, Perspective.Client)
    }

    /// 根据 ID 移除流。
    public func removeStream(id: StreamId): Unit {
        var i: Int64 = 0
        while (i < streamCount) {
            if (streams[i].getStreamId() == id) {
                var j: Int64 = i
                while (j < streamCount - 1) {
                    streams[j] = streams[j + 1]; j += 1
                }
                streamCount -= 1
                return
            }
            i += 1
        }
    }

    public func len(): Int64 { streamCount }
}
