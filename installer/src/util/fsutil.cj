package uc_installer.util

import std.fs.{Path, exists, Directory}

/// 确保目录存在（幂等；已存在时什么都不做）。
///
/// 放在 util 而非 core，是为了让 services 层（media / ssl）能直接复用而不必
/// 反向 import core——core 的 orchestrator 依赖 services，若 core.ensureDir 留在
/// core 就会形成 core <-> services 循环依赖，cjpm 直接拒绝构建。
public func ensureDir(path: Path): Unit {
    if (!exists(path)) {
        Directory.create(path, recursive: true)
    }
}
