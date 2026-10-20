package uc_installer.core

import std.fs.Path

/// 安装目录布局的不可变解析结果。
///
/// 所有路径相对 `installRoot` 派生，集中在此处解析，避免散落各处拼接字符串。
public struct InstallPaths {
    public let installRoot: Path
    public let releaseDir: Path
    public let stateFile: Path
    public let portFile: Path
    public let assetsDir: Path
    public let configFile: Path
    public let stagingDir: Path
    public let previousDir: Path
    public let trashDir: Path
    public let gcFile: Path
    public let devSourceDir: Path
    public let mediaDir: Path

    public init(installRoot: Path, releaseDir: Path, stateFile: Path, portFile: Path,
                assetsDir: Path, configFile: Path, stagingDir: Path, previousDir: Path,
                trashDir: Path, gcFile: Path, devSourceDir: Path, mediaDir: Path) {
        this.installRoot = installRoot
        this.releaseDir = releaseDir
        this.stateFile = stateFile
        this.portFile = portFile
        this.assetsDir = assetsDir
        this.configFile = configFile
        this.stagingDir = stagingDir
        this.previousDir = previousDir
        this.trashDir = trashDir
        this.gcFile = gcFile
        this.devSourceDir = devSourceDir
        this.mediaDir = mediaDir
    }
}

/// 判定 child 是否落在 parent 之内（含相等）。
///
/// 用于 DevKit 目录互不嵌套校验（R-23 / AC-175/186/187）：`devSourceDir` 与 `releaseDir`
/// 不能互为父子。统一尾斜杠后做前缀判断。
public func isNested(child: Path, parent: Path): Bool {
    let c = child.toString()
    let p = parent.toString()
    if (c == p) {
        return true
    }
    let cs = if (c.endsWith("/") || c.endsWith("\\")) { c } else { c + "/" }
    let ps = if (p.endsWith("/") || p.endsWith("\\")) { p } else { p + "/" }
    return cs.startsWith(ps)
}

/// 断言 devSourceDir 与 releaseDir 互不嵌套；违反返回 false（调用方应拒绝进入 DevKit）。
public func assertDirsNotNested(releaseDir: Path, devSourceDir: Path): Bool {
    if (isNested(devSourceDir, releaseDir) || isNested(releaseDir, devSourceDir)) {
        return false
    }
    return true
}

/// 依据 installRoot 解析标准布局。
///
/// - installRoot: 运行时根目录（通常为 agentskills-runtime 工程根）
/// - devSourceDir: 开发者源码目录（DevKit 初始化目标）；可为空路径表示暂不启用 DevKit
/// - mediaDir: 离线介质根目录
public func resolve(installRoot: Path, devSourceDir: Path, mediaDir: Path): InstallPaths {
    let releaseDir = installRoot.join("release")
    let stateFile = installRoot.join(".install-state.json")
    let portFile = installRoot.join(".installer-port")
    let assetsDir = installRoot.join("assets")
    let configFile = installRoot.join(".install-config.json")
    let stagingDir = installRoot.join(".staging")
    let previousDir = installRoot.join("previous")
    let trashDir = installRoot.join(".trash")
    let gcFile = installRoot.join(".installer-gc.json")
    return InstallPaths(installRoot, releaseDir, stateFile, portFile, assetsDir, configFile,
                        stagingDir, previousDir, trashDir, gcFile, devSourceDir, mediaDir)
}
