package uc_installer.services

import std.fs.{Path, exists, FileInfo, File, OpenMode, rename, remove}

/// 读整个文件为文本；文件不存在或读失败返回空串。
///
/// 调用方靠 `isNonEmptyFile` / 长度判断有效性，故此处不抛异常。
public func readFileText(path: Path): String {
    if (!exists(path)) {
        return ""
    }
    try {
        let info = FileInfo(path)
        let buf = Array<Byte>(info.size, repeat: 0)
        let f = File(path, OpenMode.Read)
        f.read(buf)
        f.close()
        return String.fromUtf8(buf)
    } catch (_: Exception) {
        return ""
    }
}

/// 原子写文本：先写同目录 `.tmp` 再 rename 覆盖，避免半截文件。
///
/// 关键约束（AC-011 关联）：tmp 必须与目标同目录，否则跨卷 rename 会失败。
public func writeFileAtomic(path: Path, content: String): Bool {
    try {
        let tmp = Path(path.toString() + ".tmp")
        let f = File(tmp, OpenMode.Write)
        f.write(content.toArray())
        f.close()
        rename(tmp, to: path, overwrite: true)
        return true
    } catch (_: Exception) {
        return false
    }
}

/// 二进制拷贝（下载/解包落地共用）。
public func copyFileBinary(src: Path, dest: Path): Bool {
    if (!exists(src)) {
        return false
    }
    try {
        let info = FileInfo(src)
        let buf = Array<Byte>(info.size, repeat: 0)
        let rf = File(src, OpenMode.Read)
        rf.read(buf)
        rf.close()
        let wf = File(dest, OpenMode.Write)
        wf.write(buf)
        wf.close()
        return true
    } catch (_: Exception) {
        return false
    }
}

/// 文件存在且非空。
public func isNonEmptyFile(path: Path): Bool {
    if (!exists(path)) {
        return false
    }
    try {
        return FileInfo(path).size > 0
    } catch (_: Exception) {
        return false
    }
}

/// 删除文件；不存在视为成功（幂等）。
public func removeFileIfExists(path: Path): Unit {
    if (!exists(path)) {
        return
    }
    remove(path)
}
