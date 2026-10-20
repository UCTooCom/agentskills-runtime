package uc_installer.services

import std.fs.{Path, exists}
import std.env.getVariable
import uc_installer.platform.{runCapped, succeeded}
import uc_installer.util.ensureDir

public enum SslResult {
    | Ok
    | Failed(String)
}

/// 探测 openssl 是否可用（cap 5s，stdin Discard）。
public func probeOpenSSL(): Bool {
    let r = runCapped("openssl", ["version"], cap: Duration.second * 5)
    return succeeded(r)
}

/// 生成自签名证书：调用方须先确保 sslDir 存在（本函数内部也会 ensureDir）。
/// 成功判据：退出码 0 且 server.crt / server.key 存在非空且 crt 含 BEGIN CERTIFICATE，
/// 否则清理残骸并返回 Failed（AC-012/097/007）。
public func generateSelfSigned(domain: String, sslDir: Path): SslResult {
    if (!probeOpenSSL()) {
        return SslResult.Failed("openssl 不可用：请安装 OpenSSL 并确保其在 PATH 中后重试")
    }
    ensureDir(sslDir)
    let key = sslDir.join("server.key")
    let crt = sslDir.join("server.crt")
    let r = runCapped("openssl",
        ["req", "-x509", "-newkey", "rsa:2048", "-keyout", key.toString(), "-out", crt.toString(),
         "-days", "365", "-nodes", "-subj", "/CN=${domain}"],
        cap: Duration.second * 60)
    if (r.timedOut || r.exitCode != 0 || !isValidPem(crt) || !isNonEmptyFile(key)) {
        removeFileIfExists(crt)
        removeFileIfExists(key)
        return SslResult.Failed("openssl 执行失败或产物不完整")
    }
    restrictKey(key)
    return SslResult.Ok
}

/// 把证书内容写入 <releaseDir>/ssl/server.crt 与 server.key；写入前备份原内容，失败回滚（AC-099/100）。
public func saveSsl(releaseDir: Path, crtContent: String, keyContent: String): SslResult {
    let sslDir = releaseDir.join("ssl")
    ensureDir(sslDir)
    let crt = sslDir.join("server.crt")
    let key = sslDir.join("server.key")
    // 备份原内容（内存），失败回滚；成功则不残留 .bak 文件。
    let crtOrig = readFileTextOrNone(crt)
    let keyOrig = readFileTextOrNone(key)
    if (!writeFileAtomic(crt, crtContent)) {
        restoreText(crt, crtOrig)
        return SslResult.Failed("写入 server.crt 失败")
    }
    if (!writeFileAtomic(key, keyContent)) {
        restoreText(key, keyOrig)
        restoreText(crt, crtOrig)
        return SslResult.Failed("写入 server.key 失败")
    }
    return SslResult.Ok
}

private func readFileTextOrNone(p: Path): Option<String> {
    if (!exists(p)) {
        return None<String>
    }
    return Some(readFileText(p))
}

private func restoreText(p: Path, orig: Option<String>): Unit {
    match (orig) {
        case Some(s) => writeFileAtomic(p, s)
        case None => removeFileIfExists(p)
    }
}

private func isValidPem(p: Path): Bool {
    if (!exists(p)) {
        return false
    }
    return readFileText(p).contains("BEGIN CERTIFICATE")
}

/// 最佳努力：Windows 下用 icacls 移除继承并仅授予当前用户读取（AC-015）；失败不阻断主流程。
private func restrictKey(key: Path): Unit {
    let user = match (getVariable("USERNAME")) {
        case Some(u) => u
        case None => ""
    }
    if (user.isEmpty()) {
        return
    }
    // 失败不阻断主流程（丢弃返回值）
    let _ = runCapped("icacls", [key.toString(), "/inheritance:r", "/grant:r", "${user}:R"],
        cap: Duration.second * 5)
}
