package quic_cj.core
import quic_cj.wire.Frame

/// ConnIdChangeCallback 是传输层连接 ID 变更回调。
public class ConnRunnerCallbacks {
    private var addConnId: (Array<Byte>) -> Unit
    private var removeConnId: (Array<Byte>) -> Unit

    public init() {
        this.addConnId = { id => () }
        this.removeConnId = { id => () }
    }

    public func setAddConnId(cb: (Array<Byte>) -> Unit): Unit { addConnId = cb }
    public func setRemoveConnId(cb: (Array<Byte>) -> Unit): Unit { removeConnId = cb }
    public func addConnectionId(id: Array<Byte>): Unit { addConnId(id) }
    public func removeConnectionId(id: Array<Byte>): Unit { removeConnId(id) }
}

internal class ConnIdToRetire {
    public var timeNs: Int64 = 0
    public var connId: Array<Byte> = []
    public init(timeNs: Int64, connId: Array<Byte>) {
        this.timeNs = timeNs
        this.connId = connId
    }
}

public class ConnIDGenerator {
    private var highestSeq: UInt64 = 0
    private var activeSeqs: Array<UInt64> = []
    private var activeIds: Array<Array<Byte>> = []
    private var connIDsToRetire: Array<ConnIdToRetire> = []
    private var initialClientDestConnID: Array<Byte> = []
    private var callbacks: ConnRunnerCallbacks = ConnRunnerCallbacks()
    private var queueControlFrame: (Frame) -> Unit

    public init(initialConnId: Array<Byte>, initialClientDest: Array<Byte>) {
        this.queueControlFrame = { f => () }
        activeSeqs = [0u64]
        activeIds = [initialConnId]
        initialClientDestConnID = initialClientDest
    }

    public func setCallbacks(cb: ConnRunnerCallbacks): Unit { callbacks = cb }
    public func setQueueControlFrame(cb: (Frame) -> Unit): Unit { queueControlFrame = cb }

    public func setMaxActiveConnIDs(limit: UInt64): Unit {
        var i: UInt64 = UInt64(activeSeqs.size)
        while (i < min(limit, 8u64)) {
            issueNewConnID()
            i += 1u64
        }
    }

    public func retire(seq: UInt64, expiryNs: Int64): Bool {
        var found: Bool = false
        var connIdToRet: Array<Byte> = []
        var j: Int64 = 0
        var i: Int64 = 0
        while (i < activeSeqs.size) {
            if (activeSeqs[i] != seq) {
                activeSeqs[j] = activeSeqs[i]
                activeIds[j] = activeIds[i]
                j += 1
            } else {
                found = true
                connIdToRet = activeIds[i]
            }
            i += 1
        }
        if (j < activeSeqs.size) {
            activeSeqs = activeSeqs[..j]
            activeIds = activeIds[..j]
        }
        if (!found) { return true }
        queueConnIdForRetiring(connIdToRet, expiryNs)
        if (seq == 0u64) { return true }
        issueNewConnID()
        true
    }

    public func setHandshakeComplete(expiryNs: Int64): Unit {
        if (initialClientDestConnID.size > 0) {
            queueConnIdForRetiring(initialClientDestConnID, expiryNs)
            initialClientDestConnID = []
        }
    }

    public func removeRetiredConnIDs(nowNs: Int64): Unit {
        while (connIDsToRetire.size > 0 && connIDsToRetire[0].timeNs <= nowNs) {
            callbacks.removeConnectionId(connIDsToRetire[0].connId)
            connIDsToRetire = connIDsToRetire[1..]
        }
    }

    public func removeAll(): Unit {
        var i: Int64 = 0
        while (i < activeIds.size) {
            callbacks.removeConnectionId(activeIds[i])
            i += 1
        }
        i = 0
        while (i < connIDsToRetire.size) {
            callbacks.removeConnectionId(connIDsToRetire[i].connId)
            i += 1
        }
    }

    public func getActiveConnIds(): Array<Array<Byte>> {
        var result: Array<Array<Byte>> = []
        var i: Int64 = 0
        while (i < activeIds.size) {
            result = appendConnIdArray(result, activeIds[i])
            i += 1
        }
        result
    }

    private func issueNewConnID(): Unit {
        let seq = highestSeq + 1u64
        var connId: Array<Byte> = Array<Byte>(8, repeat: 0u8)
        var b: Int64 = 0
        while (b < 8) {
            connId[b] = UInt8((UInt64(b) * 2654435761u64 + seq) & 0xffu64)
            b += 1
        }
        activeSeqs = appendUint64Arr(activeSeqs, seq)
        activeIds = appendConnIdArray(activeIds, connId)
        highestSeq = seq
    }

    private func queueConnIdForRetiring(connId: Array<Byte>, expiryNs: Int64): Unit {
        connIDsToRetire = appendRetireEntry(connIDsToRetire, ConnIdToRetire(expiryNs, connId))
    }
}

internal func appendUint64Arr(arr: Array<UInt64>, val: UInt64): Array<UInt64> {
    let n = arr.size
    var out = Array<UInt64>(n + 1, repeat: 0u64)
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = val
    out
}

internal func appendConnIdArray(arr: Array<Array<Byte>>, item: Array<Byte>): Array<Array<Byte>> {
    let n = arr.size
    var out = Array<Array<Byte>>(n + 1, repeat: [])
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = item
    out
}

internal func appendRetireEntry(arr: Array<ConnIdToRetire>, item: ConnIdToRetire): Array<ConnIdToRetire> {
    let n = arr.size
    var out = Array<ConnIdToRetire>(n + 1, repeat: ConnIdToRetire(0, []))
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = item
    out
}

public func newConnIDGenerator(initialConnId: Array<Byte>): ConnIDGenerator {
    ConnIDGenerator(initialConnId, [])
}
