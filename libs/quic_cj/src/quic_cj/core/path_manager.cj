package quic_cj.core

import quic_cj.wire.{Frame, PathChallengeFrame, PathResponseFrame, PingFrame}
import quic_cj.util.RTTStats

/// 无效路径 ID。
public let INVALID_PATH_ID: Int64 = -1

/// 同时跟踪的最大路径数。
public let MAX_PATHS: Int64 = 3

/// 路径最后包到达后超过此时间（以纳秒为单位）可被驱逐（5 秒）。
public let PATH_TIMEOUT_NS: Int64 = 5000000000

/// Path 表示连接的一端到另一端的一条路径。
/// 每条路径由唯一的远程地址标识。
public class Path {
    public var id: Int64 = 0
    public var remoteAddr: String = ""
    public var lastPacketTimeNs: Int64 = 0
    public var pathChallenge: Array<Byte> = []
    public var validated: Bool = false
    public var receivedNonProbing: Bool = false

    public init(id: Int64, remoteAddr: String, lastPacketTimeNs: Int64) {
        this.id = id
        this.remoteAddr = remoteAddr
        this.lastPacketTimeNs = lastPacketTimeNs
    }
}

/// PathManager 管理 QUIC 连接的路径。
/// 处理路径探测、验证和切换（连接迁移）。
public class PathManager {
    private var migrationDisabled: Bool = false

    /// 设置是否禁用连接迁移。
    public func setMigrationDisabled(disabled: Bool): Unit { migrationDisabled = disabled }

    /// 检查迁移是否被禁用。
    public func isMigrationDisabled(): Bool { migrationDisabled }

    private var paths: Array<Path> = []
    private var nextPathId: Int64 = 0
    private var currentAddr: String = ""

    public init(initialAddr: String) {
        currentAddr = initialAddr
    }

    /// 处理收到的包，确定是否需要发送 PATH_CHALLENGE 或 PATH_RESPONSE。
    /// 返回要发送的帧和是否应切换路径。
    public func handlePacket(
        remoteAddr: String,
        timeNs: Int64,
        challenge: PathChallengeFrame,
        hasChallenge: Bool,
        isNonProbing: Bool,
    ): (Array<Frame>, Bool, Bool) {
        // 如果迁移被禁用且来自新地址，只回复 CHALLENGE（如果存在）但不切换
        if (migrationDisabled && remoteAddr != currentAddr) {
            if (hasChallenge) {
                let prf = PathResponseFrame()
                prf.data = challenge.data
                var frames: Array<Frame> = []
                frames = appendFrameArray(frames, prf)
                return (frames, false, true)
            }
            return ([], false, true)
        }
        // 查找已有路径
        let (existingPath, existingIdx) = findPathByAddr(remoteAddr)
        var shouldSwitch: Bool = false

        if (existingIdx >= 0) {
            existingPath.lastPacketTimeNs = timeNs
            if (isNonProbing) { existingPath.receivedNonProbing = true }
            shouldSwitch = existingPath.validated && existingPath.receivedNonProbing
            // 将路径移到列表末尾（最近使用的）
            moveToEnd(existingIdx)
            if (!hasChallenge) { return ([], shouldSwitch, true) }
        }

        // 检查路径数量限制
        if (paths.size >= MAX_PATHS) {
            let oldest = paths[0]
            if (oldest.lastPacketTimeNs + PATH_TIMEOUT_NS > timeNs) {
                return ([], false, false)
            }
            paths = paths[1..]
        }

        var frames: Array<Frame> = []

        if (existingIdx < 0) {
            // 新路径——发送 PATH_CHALLENGE
            var challengeData: Array<Byte> = Array<Byte>(8, repeat: 0u8)
            // 使用简单的随机数生成器
            var i: Int64 = 0
            while (i < 8) {
                challengeData[i] = UInt8((timeNs >> (i * 8)) & 0xff)
                i += 1
            }
            let newPath = Path(nextPathId, remoteAddr, timeNs)
            newPath.pathChallenge = challengeData
            newPath.receivedNonProbing = isNonProbing
            nextPathId += 1
            paths = appendPaths(paths, newPath)

            let pcf = PathChallengeFrame()
            pcf.data = challengeData
            frames = appendFrameArray(frames, pcf)
        }

        // 如果收到的包包含 PATH_CHALLENGE，回复 PATH_RESPONSE
        if (hasChallenge) {
            let prf = PathResponseFrame()
            prf.data = challenge.data
            frames = appendFrameArray(frames, prf)
        }

        (frames, shouldSwitch, true)
    }

    /// 切换到 Preferred Address（服务端建议的替代地址）。
    public func initiatePreferredAddressMigration(preferredAddr: String, timeNs: Int64): Array<Frame> {
        if (migrationDisabled) { return [] }
        if (preferredAddr == currentAddr) { return [] }
        var frames: Array<Frame> = []
        var challengeData: Array<Byte> = Array<Byte>(8, repeat: 0u8)
        var i: Int64 = 0
        while (i < 8) {
            challengeData[i] = UInt8((timeNs >> (i * 8)) & 0xff)
            i += 1
        }
        let newPath = Path(nextPathId, preferredAddr, timeNs)
        newPath.pathChallenge = challengeData
        nextPathId += 1
        paths = appendPaths(paths, newPath)
        let pcf = PathChallengeFrame()
        pcf.data = challengeData
        frames = appendFrameArray(frames, pcf)
        frames
    }

    /// 处理 PATH_RESPONSE 帧以验证路径。
    /// 返回已验证路径的远程地址；如果未找到匹配路径则返回空字符串。
    public func handlePathResponseFrame(data: Array<Byte>): String {
        var i: Int64 = 0
        while (i < paths.size) {
            if (arraysEqual(paths[i].pathChallenge, data)) {
                paths[i].validated = true
                return paths[i].remoteAddr
            }
            i += 1
        }
        ""
    }

    /// 切换到指定地址的路径，退役所有其他路径。
    public func switchToPath(remoteAddr: String): Unit {
        currentAddr = remoteAddr
        paths = []
    }

    /// 返回当前地址。
    public func getCurrentAddr(): String { currentAddr }

    /// 返回当前路径。
    public func getCurrentPath(): Option<Path> {
        var i: Int64 = 0
        while (i < paths.size) {
            if (paths[i].remoteAddr == currentAddr) { return Some(paths[i]) }
            i += 1
        }
        None
    }

    /// 返回路径数量。
    public func pathCount(): Int64 { paths.size }

    private func findPathByAddr(addr: String): (Path, Int64) {
        var i: Int64 = 0
        while (i < paths.size) {
            if (paths[i].remoteAddr == addr) { return (paths[i], i) }
            i += 1
        }
        (Path(0, "", 0), -1)
    }

    private func moveToEnd(idx: Int64): Unit {
        let p = paths[idx]
        var i: Int64 = idx
        while (i < paths.size - 1) {
            paths[i] = paths[i + 1]
            i += 1
        }
        paths[paths.size - 1] = p
    }
}


/// PathEvent 描述连接路径变更事件的类型。
public enum PathEvent {
    | PathValidated    /// 新路径已验证（PATH_RESPONSE 已到达）
    | PathMigrated     /// 活动路径已切换到新地址
    | PathFailed       /// 路径超时或验证失败
}
internal func appendPaths(arr: Array<Path>, p: Path): Array<Path> {
    let n = arr.size
    var out = Array<Path>(n + 1, repeat: Path(0, "", 0))
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = p
    out
}

internal func appendFrameArray(arr: Array<Frame>, f: Frame): Array<Frame> {
    let n = arr.size
    var out = Array<Frame>(n + 1, repeat: Frame())
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = f
    out
}

internal func arraysEqual(a: Array<Byte>, b: Array<Byte>): Bool {
    if (a.size != b.size) { return false }
    var i: Int64 = 0
    while (i < a.size) {
        if (a[i] != b[i]) { return false }
        i += 1
    }
    true
}

/// 创建 PathManager。
public func newPathManager(initialAddr: String): PathManager { PathManager(initialAddr) }
