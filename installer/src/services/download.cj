package uc_installer.services

import std.fs.{Path, exists, FileInfo, File, OpenMode}
import pgsql.{sha256, toHex}
import uc_installer.platform.{runCapped, succeeded}
import uc_installer.util.Log

public enum DownloadResult {
    | Ok(Path)
    | Failed(String)
}

/// 下载（断点续传）或本地拷贝（--sdk-path）。
/// - localPath 非空：直接从本地源二进制拷贝（不损坏）。
/// - 否则 curl -C - -L --fail -o 下载，失败可重试续传。
public func fetchResumable(url: String, dest: Path, localPath: Option<Path>): DownloadResult {
    match (localPath) {
        case Some(p) =>
            if (!exists(p)) {
                return DownloadResult.Failed("本地源文件不存在: ${p.toString()}")
            }
            if (copyFileBinary(p, dest)) {
                Log.get().info("已从本地源拷贝: ${p.toString()}")
                return DownloadResult.Ok(dest)
            }
            return DownloadResult.Failed("复制本地源文件失败")
        case None => ()
    }
    Log.get().info("开始下载（断点续传）: ${url}")
    let r = runCapped("curl",
        ["-C", "-", "-L", "--fail", "-o", dest.toString(), url],
        cap: Duration.second * 600)
    if (succeeded(r)) {
        return DownloadResult.Ok(dest)
    }
    return DownloadResult.Failed("下载失败（退出码 ${r.exitCode}）：可重试以断点续传")
}

/// 校验文件 SHA256 是否与期望值一致（忽略大小写）。
public func verifySha256(path: Path, expected: String): Bool {
    if (!exists(path)) {
        return false
    }
    try {
        let info = FileInfo(path)
        let buf = Array<Byte>(info.size, repeat: 0)
        let f = File(path, OpenMode.Read)
        f.read(buf)
        f.close()
        let digest = sha256(buf)
        let hex = toHex(digest)
        return hex.toAsciiLower() == expected.toAsciiLower()
    } catch (_: Exception) {
        return false
    }
}
