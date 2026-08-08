package quic_cj.core

import quic_cj.protocol.PACKETS_PER_CONNECTION_ID
import quic_cj.wire.{Frame, NewConnectionIDFrame, RetireConnectionIDFrame}

internal class NewConnIdEntry {
    public var seq: UInt64 = 0
    public var connId: Array<Byte> = []
    public var resetToken: Array<Byte> = []

    public init(seq: UInt64, connId: Array<Byte>, resetToken: Array<Byte>) {
        this.seq = seq
        this.connId = connId
        this.resetToken = resetToken
    }
}

public class ConnIDManager {
    private var queue: Array<NewConnIdEntry> = []
    private var activeSeq: UInt64 = 0
    private var highestRetired: UInt64 = 0
    private var activeConnId: Array<Byte> = []
    private var activeResetToken: Array<Byte> = []
    private var packetsSinceChange: UInt32 = 0
    private var packetsPerConnId: UInt32 = UInt32(PACKETS_PER_CONNECTION_ID)
    private var handshakeComplete: Bool = false
    private var closed: Bool = false

    private var addResetToken: (Array<Byte>) -> Unit = { id => () }
    private var removeResetToken: (Array<Byte>) -> Unit = { id => () }
    private var queueControlFrame: (Frame) -> Unit = { f => () }

    public init(initialConnId: Array<Byte>) {
        activeConnId = initialConnId
    }

    public func setCallbacks(
        addReset: (Array<Byte>) -> Unit,
        removeReset: (Array<Byte>) -> Unit,
        queueFrame: (Frame) -> Unit,
    ): Unit {
        addResetToken = addReset
        removeResetToken = removeReset
        queueControlFrame = queueFrame
    }

    public func add(frame: NewConnectionIDFrame): Bool {
        if (activeConnId.size == 0) { return false }
        let seqU: UInt64 = UInt64(frame.seq)
        if (seqU < maxU64(activeSeq, 0u64) || seqU < highestRetired) {
            let retire = RetireConnectionIDFrame()
            retire.seq = frame.seq
            queueControlFrame(retire)
            return true
        }
        if (seqU == activeSeq) { return true }
        addConnectionEntry(seqU, frame.connectionId, frame.statelessResetToken)
        true
    }

    public func addFromPreferredAddress(connId: Array<Byte>, resetToken: Array<Byte>): Bool {
        addConnectionEntry(1u64, connId, resetToken)
        true
    }

    public func setStatelessResetToken(token: Array<Byte>): Unit {
        if (closed) { return }
        activeResetToken = token
        addResetToken(token)
    }

    public func changeInitialConnId(newConnId: Array<Byte>): Unit {
        activeConnId = newConnId
    }

    public func sentPacket(): Unit { packetsSinceChange += 1 }

    public func get(): Array<Byte> {
        if (closed) { return activeConnId }
        if (shouldUpdateConnId()) { updateConnId() }
        activeConnId
    }

    public func getConnIdForPath(pathId: Int64): Option<Array<Byte>> {
        if (activeConnId.size == 0) { return Some([]) }
        if (queue.size == 0) { return None }
        let entry = queue[0]
        queue = queue[1..]
        addResetToken(entry.resetToken)
        Some(entry.connId)
    }

    public func retireConnIdForPath(): Unit {}

    public func setHandshakeComplete(): Unit { handshakeComplete = true }

    public func isActiveResetToken(token: Array<Byte>): Bool {
        arraySeqEqual(activeResetToken, token)
    }

    public func close(): Unit {
        if (closed) { return }
        closed = true
        if (activeResetToken.size > 0) { removeResetToken(activeResetToken) }
    }

    private func addConnection(frame: NewConnectionIDFrame): Bool {
        addConnectionEntry(UInt64(frame.seq), frame.connectionId, frame.statelessResetToken)
    }

    private func addConnectionEntry(seq: UInt64, connId: Array<Byte>, resetToken: Array<Byte>): Bool {
        queue = insertConnIdSorted(queue, NewConnIdEntry(seq, connId, resetToken))
        true
    }

    private func updateConnId(): Unit {
        if (queue.size == 0) { return }
        let front = queue[0]
        queue = queue[1..]

        let retire = RetireConnectionIDFrame()
        retire.seq = Int64(activeSeq)
        queueControlFrame(retire)

        activeSeq = front.seq
        activeConnId = front.connId
        activeResetToken = front.resetToken
        packetsSinceChange = 0
        addResetToken(front.resetToken)
    }

    private func shouldUpdateConnId(): Bool {
        if (!handshakeComplete) { return false }
        if (queue.size > 0 && activeSeq == 0u64) { return true }
        2 * queue.size >= 2 && packetsSinceChange >= packetsPerConnId
    }
}

internal func insertConnIdSorted(arr: Array<NewConnIdEntry>, entry: NewConnIdEntry): Array<NewConnIdEntry> {
    let n = arr.size
    if (n == 0 || arr[n - 1].seq < entry.seq) {
        var out = Array<NewConnIdEntry>(n + 1, repeat: NewConnIdEntry(0, [], []))
        var i: Int64 = 0
        while (i < n) { out[i] = arr[i]; i += 1 }
        out[n] = entry
        return out
    }
    var j: Int64 = 0
    while (j < n) {
        if (arr[j].seq == entry.seq) { return arr }
        if (arr[j].seq > entry.seq) {
            var out = Array<NewConnIdEntry>(n + 1, repeat: NewConnIdEntry(0, [], []))
            var i: Int64 = 0
            while (i < j) { out[i] = arr[i]; i += 1 }
            out[j] = entry
            i = j
            while (i < n) { out[i + 1] = arr[i]; i += 1 }
            return out
        }
        j += 1
    }
    arr
}

internal func maxU64(a: UInt64, b: UInt64): UInt64 { if (a > b) { a } else { b } }

internal func arraySeqEqual(a: Array<Byte>, b: Array<Byte>): Bool {
    if (a.size != b.size) { return false }
    var i: Int64 = 0
    while (i < a.size) {
        if (a[i] != b[i]) { return false }
        i += 1
    }
    true
}

public func newConnIDManager(initialConnId: Array<Byte>): ConnIDManager {
    ConnIDManager(initialConnId)
}
