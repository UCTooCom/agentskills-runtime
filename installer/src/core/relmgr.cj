package uc_installer.core

import std.fs.{Path, exists, rename, Directory}
import std.time.DateTime
import uc_installer.util.ensureDir

/// release 目录里"缺了 runtime 就一定起不来"的骨架文件。
///
/// 判据刻意保守：只校验无法由运维手工补齐的骨架，
/// 不校验版本号/依赖 DLL 等可后期补的内容，避免误判触发安装回滚。
private func requiredReleaseFiles(): Array<String> {
    return [
        "agentskills-runtime.exe",
        "VERSION",
        "start.bat",
        "stop.bat"
    ]
}

/// 针对任意 release 目录做骨架校验（staging 落地前后都用它）。
public func verifyReleaseAt(releaseDir: Path): Bool {
    if (!exists(releaseDir)) {
        return false
    }
    for (name in requiredReleaseFiles()) {
        if (!exists(releaseDir.join(name))) {
            return false
        }
    }
    return true
}

/// 校验 release 目录是否构成一个可启动的 runtime。
public func verifyRelease(paths: InstallPaths): Bool {
    return verifyReleaseAt(paths.releaseDir)
}

/// 安装前把既有 release 挪进 previous/ 备份，返回是否发生了实际挪动。
///
/// 首次安装（无既有 release）返回 false —— 属正常路径，不是错误。
/// 挪动失败（文件被占用等）同样返回 false，由调用方决定是否中止；
/// **绝不**在此处强杀占用进程（AC-011：只登记 GC 延迟替换，不主动 taskkill）。
public func snapshotExisting(paths: InstallPaths): Bool {
    if (!exists(paths.releaseDir)) {
        return false
    }
    ensureDir(paths.previousDir)
    let ts = DateTime.now().toString().replace(":", "-").replace(" ", "_")
    let dest = paths.previousDir.join("release-${ts}")
    try {
        rename(paths.releaseDir, to: dest, overwrite: true)
        return true
    } catch (_: Exception) {
        return false
    }
}

/// 准备一个唯一命名的 staging 目录（同名已存在则复用，保证幂等）。
public func prepareStaging(paths: InstallPaths): Path {
    ensureDir(paths.stagingDir)
    let root = paths.stagingDir.join(stagingDirName())
    if (!exists(root)) {
        Directory.create(root, recursive: true)
    }
    return root
}

/// staging 目录名：时间戳 + 进程内自增序号，避免同秒并发重名。
private var stagingSeq: Int64 = 0

func stagingDirName(): String {
    stagingSeq = stagingSeq + 1
    let ts = DateTime.now().toString().replace(":", "-").replace(" ", "_")
    return "s-${ts}-${stagingSeq}"
}
