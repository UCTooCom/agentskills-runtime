package quic_cj.core

import quic_cj.wire.{Frame, PathChallengeFrame, PathResponseFrame}

/// TrHandle 是 Transport 的不透明句柄，用于避免循环导入。
public class TrHandle {
    public var id: Int64 = 0

    public init(id: Int64) {
        this.id = id
    }
}

/// PathProbeState 跟踪正在探测的路径状态。
public class PathProbeState {
    public var id: Int64 = 0
    public var pathChallenges: Array<Array<Byte>> = []
    public var isValidated: Bool = false
    public var probeSent: Bool = false
    public var validated: Bool = false
    public var tr: TrHandle = TrHandle(0)
    public var enablePath: () -> Unit = { => }

    public init(id: Int64, tr: TrHandle, enablePath: () -> Unit) {
        this.id = id
        this.tr = tr
        this.enablePath = enablePath
    }
}

/// PathManagerOutgoing 管理出站路径探测和切换。
public class PathManagerOutgoing {
    private var activePath: Int64 = 0
    private var nextPathId: Int64 = 1
    private var pathsToProbe: Array<Int64> = []
    private var paths: Array<PathProbeState> = []
    private var pathToSwitchTo: PathProbeState = PathProbeState(0, TrHandle(0), { => })
    private var hasPendingSwitch: Bool = false
    private var getConnId: (Int64) -> Option<Array<Byte>>
    private var retireConnId: (Int64) -> Unit
    private var scheduleSending: () -> Unit

    public init(
        getConnId: (Int64) -> Option<Array<Byte>>,
        retireConnId: (Int64) -> Unit,
        scheduleSending: () -> Unit,
    ) {
        this.getConnId = getConnId
        this.retireConnId = retireConnId
        this.scheduleSending = scheduleSending
        this.activePath = 0
        this.nextPathId = 1
    }

    /// AddPath 添加一条待探测的路径。
    public func addPath(id: Int64, enablePath: () -> Unit): PathProbeState {
        var i: Int64 = 0
        while (i < paths.size) {
            if (paths[i].id == id) {
                paths[i].validated = false
                return paths[i]
            }
            i += 1
        }

        let tr = TrHandle(id)
        let p = PathProbeState(id, tr, enablePath)
        paths = appendPathProbeState(paths, p)
        p
    }

    /// EnqueueProbe 将一条路径加入探测队列。
    public func enqueueProbe(id: Int64): Unit {
        pathsToProbe = appendInt64(pathsToProbe, id)
        scheduleSending()
    }

    /// RemovePath 根据 ID 移除一条路径。
    public func removePath(id: Int64): (Bool, String) {
        let (ok, msg) = removePathImpl(id)
        if (ok) { scheduleSending() }
        (ok, msg)
    }

    private func removePathImpl(id: Int64): (Bool, String) {
        if (id == activePath) { return (false, "cannot close active path") }

        var found: Bool = false
        var newPaths: Array<PathProbeState> = []
        newPaths = []
        var i: Int64 = 0
        while (i < paths.size) {
            if (paths[i].id == id) {
                if (paths[i].pathChallenges.size > 0) {
                    retireConnId(id)
                }
                found = true
            } else {
                newPaths = appendPathProbeState(newPaths, paths[i])
            }
            i += 1
        }
        paths = newPaths
        if (!found) { return (true, "") }
        (true, "")
    }

    /// SwitchToPath 将活跃路径切换到指定路径。
    public func switchToPath(id: Int64): (Bool, String) {
        var i: Int64 = 0
        while (i < paths.size) {
            if (paths[i].id == id) {
                if (!paths[i].isValidated) {
                    return (false, "path not yet validated")
                }
                pathToSwitchTo = paths[i]
                hasPendingSwitch = true
                activePath = id
                return (true, "")
            }
            i += 1
        }
        (false, "path does not exist")
    }

    /// NewPath 创建一条用于外部探测的新路径。
    public func newPath(initialRttMs: Int64, enablePath: () -> Unit): Path {
        let newId = nextPathId
        nextPathId += 1
        let p = Path(newId, "", 0)
        p.validated = false
        p
    }

    /// NextPathToProbe 返回下一条要发送 PATH_CHALLENGE 的路径。
    public func nextPathToProbe(): Option<(Array<Byte>, Frame, TrHandle)> {
        if (pathsToProbe.size == 0) { return None }

        let pId = pathsToProbe[0]
        pathsToProbe = pathsToProbe[1..]

        var idx: Int64 = -1
        var i: Int64 = 0
        while (i < paths.size) {
            if (paths[i].id == pId) {
                idx = i
                break
            }
            i += 1
        }
        if (idx < 0) { return None }

        let p = paths[idx]
        if (let Some(connId) <- getConnId(pId)) {
            var challenge: Array<Byte> = Array<Byte>(8, repeat: 0u8)
            var j: Int64 = 0
            while (j < 8) {
                challenge[j] = UInt8(j * 37 + pId)
                j += 1
            }
            p.pathChallenges = appendBytesArray(p.pathChallenges, challenge)
            p.enablePath()

            let pathChallengeFrame = PathChallengeFrame()
            pathChallengeFrame.data = challenge
            let frame: Frame = pathChallengeFrame

            Some((connId, frame, p.tr))
        } else { return None }
    }

    /// HandlePathResponseFrame 处理接收到的 PATH_RESPONSE 帧。
    public func handlePathResponseFrame(f: PathResponseFrame): Unit {
        var i: Int64 = 0
        while (i < paths.size) {
            let p = paths[i]
            var j: Int64 = 0
            while (j < p.pathChallenges.size) {
                if (bytesEqual(p.pathChallenges[j], f.data)) {
                    if (!p.isValidated) {
                        p.isValidated = true
                        p.pathChallenges = []
                        p.validated = true
                    }
                    return
                }
                j += 1
            }
            i += 1
        }
    }

    /// ShouldSwitchPath 检查是否应切换到新路径。
    public func shouldSwitchPath(): Option<TrHandle> {
        if (!hasPendingSwitch) { return None }
        let trId = pathToSwitchTo.tr.id
        hasPendingSwitch = false
        Some(TrHandle(trId))
    }
}

// --- 辅助数组函数 ---

internal func appendPathProbeState(arr: Array<PathProbeState>, item: PathProbeState): Array<PathProbeState> {
    let n = arr.size
    var out = Array<PathProbeState>(n + 1, repeat: PathProbeState(0, TrHandle(0), { => }))
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = item
    out
}

internal func appendInt64(arr: Array<Int64>, val: Int64): Array<Int64> {
    let n = arr.size
    var out = Array<Int64>(n + 1, repeat: 0)
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = val
    out
}

internal func appendBytesArray(arr: Array<Array<Byte>>, item: Array<Byte>): Array<Array<Byte>> {
    let n = arr.size
    var out = Array<Array<Byte>>(n + 1, repeat: [])
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = item
    out
}

internal func bytesEqual(a: Array<Byte>, b: Array<Byte>): Bool {
    if (a.size != b.size) { return false }
    var i: Int64 = 0
    while (i < a.size) {
        if (a[i] != b[i]) { return false }
        i += 1
    }
    true
}
