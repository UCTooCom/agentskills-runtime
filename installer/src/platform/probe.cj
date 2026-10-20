package uc_installer.platform

import std.collection.{ArrayList, HashMap}

/// 探测手段（如实记录于 `probe.method`，禁止冒充更高级手段成功）。
public enum ProbeMethod {
    | Version
    | Port
    | Process
    | None
}

public func probeMethodCode(m: ProbeMethod): String {
    match (m) {
        case ProbeMethod.Version => return "version"
        case ProbeMethod.Port => return "port"
        case ProbeMethod.Process => return "process"
        case ProbeMethod.None => return "none"
    }
}

/// 单依赖探测结果。
public struct ProbeResult {
    public let name: String
    public var reachable: Bool
    public var method: ProbeMethod
    public var version: String
    public var detail: String
    public init(name: String, reachable: Bool, method: ProbeMethod, version: String, detail: String) {
        this.name = name
        this.reachable = reachable
        this.method = method
        this.version = version
        this.detail = detail
    }
}

/// 单依赖三级降级探测：版本命令 → 端口 → 进程。
///
/// - name: 依赖名（node / psql / redis-cli / openssl）
/// - versionCmd / versionArgs: 版本探测命令（一级）
/// - port: 关联端口（二级，0 表示无）
/// - image: 关联进程镜像名（三级，空表示无）
///
/// 关键：探测手段降级必须在 `method` 中体现，不得把"端口探测成功"冒充"版本命令探测成功"。
///
/// **本文件为什么在 `platform` 而不是 `core`**：`core` 已经 import 了 `cli`（`ctx.cj`
/// 要用 `CliArgs`），而 CLI 子命令与 HTTP handler 都要复用探测能力——若探测留在 `core`，
/// `cli` 反向 import `core` 即成环（仓颉拒绝构建）。放在最底层 `platform`（它不依赖
/// 任何 `uc_installer.*` 包），两条消费通道都够得着。
public func probeDependency(name: String, versionCmd: String, versionArgs: Array<String>,
                          port: Int64, image: String): ProbeResult {
    // 一级：版本命令
    let r = runCapped(versionCmd, versionArgs, cap: Duration.second * 5)
    if (!r.timedOut && r.exitCode == 0) {
        return ProbeResult(name, true, ProbeMethod.Version, decodeOutput(r.stdout).trimAscii(), "version command")
    }
    // 二级：端口
    if (port > 0 && isLocalPortReachable(port)) {
        return ProbeResult(name, true, ProbeMethod.Port, "", "port ${port} reachable")
    }
    // 三级：进程
    if (!image.isEmpty()) {
        let pids = findPidsByImage(image)
        if (!pids.isEmpty()) {
            return ProbeResult(name, true, ProbeMethod.Process, "", "process ${image} pid=${pids[0]}")
        }
    }
    return ProbeResult(name, false, ProbeMethod.None, "", "all probes failed")
}
