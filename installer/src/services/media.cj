package uc_installer.services

import std.fs.{Path, exists, Directory, File, OpenMode}
// InputStream 必须显式导入：File 的 read()/close() 来自 InputStream 接口扩展，
// 只 import std.fs 会导致 read/close 不可见（主工程 package_release/main.cj 同款坑）。
import std.io.InputStream
// 与打包侧保持一致：SHA256 标准实现位于扩展标准库 stdx，并用其增量接口流式哈希。
// runtime DLL 由 installer/package.ps1 的 "Copying stdx DLLs" 步骤整目录拷贝进产物目录，
// 故新增 stdx.crypto.digest 不需要额外的 DLL 搬运。
import stdx.crypto.digest.*
import stdx.encoding.hex.*
import uc_installer.platform.{runCapped, succeeded}
import uc_installer.util.ensureDir
import uc_installer.util.Log

/// 在媒体目录中查找发布包 tarball（*.tar / *.tar.gz / *.tgz），返回首个匹配。
public func findReleaseTar(mediaDir: Path): Option<Path> {
    if (!exists(mediaDir)) {
        return None<Path>
    }
    try {
        for (info in Directory.readFrom(mediaDir)) {
            let name = info.path.fileName
            if (name.endsWith(".tar.gz") || name.endsWith(".tgz") || name.endsWith(".tar")) {
                return Some(info.path)
            }
        }
    } catch (_: Exception) {
        return None<Path>
    }
    return None<Path>
}

/// 校验 gzip 魔数（1f 8b）。
public func verifyTar(path: Path): Bool {
    if (!exists(path)) {
        return false
    }
    try {
        let f = File(path, OpenMode.Read)
        let head = Array<Byte>(2, repeat: 0)
        let n = f.read(head)
        f.close()
        if (n < 2) {
            return false
        }
        return head[0] == 0x1fu8 && head[1] == 0x8bu8
    } catch (_: Exception) {
        return false
    }
}

/// 用系统 tar 解压（-xf -C），cap 120s。
public func extractTar(tarPath: Path, destDir: Path): Bool {
    ensureDir(destDir)
    let r = runCapped("tar", ["-xf", tarPath.toString(), "-C", destDir.toString()],
        cap: Duration.second * 120)
    return succeeded(r)
}

let SHA256_VERIFY_CHUNK_BYTES = 1024 * 1024

/// 恒定内存占用地流式计算文件 SHA256，返回小写十六进制串；读不到返回 None。
///
/// 分块读法与主工程 src/scripts/package_release/main.cj 的 hashFileSha256Hex 一致
/// （参照 src/app/services/tool/CrudGenService.cj:191 readStreamToEnd 的同款写法）。
func hashFileSha256Hex(filePath: Path, chunkSize: Int64): Option<String> {
    try {
        let file = File(filePath.toString(), OpenMode.Read)
        let sha = SHA256()
        let buffer = Array<Byte>(chunkSize, { _ => 0 })
        while (true) {
            let bytesRead = file.read(buffer)
            if (bytesRead <= 0) {
                break
            }
            sha.write(buffer[0..bytesRead])
        }
        file.close()
        return Some(toHexString(sha.finish()))
    } catch (e: Exception) {
        return None
    }
}

/// OQ-D3: 解压后逐条复核 SHA256SUMS，任一不匹配即返回 false（安装失败）。
/// 与 package_release 同用 stdx.crypto.digest.SHA256 的流式实现，故清单哈希与
/// 运行时计算逐字节一致。清单缺失视为完整性无法保证，同样拒绝。
///
/// 内存说明：清单覆盖发行包全部 1400+ 个文件（含 libcangjie-lsp.dll 这类 200MB 级
/// 产物），旧实现用 File.readFrom 整文件入堆会在这些文件上 Out of memory，
/// 故这里与打包侧同为 1MiB 分块流式。
public func verifySha256Sums(releaseDir: Path): Bool {
    let sumPath = Path("${releaseDir}/SHA256SUMS")
    if (!exists(sumPath)) {
        Log.get().error("SHA256SUMS 缺失，拒绝安装以确保完整性: ${sumPath.toString()}")
        return false
    }
    let content = String.fromUtf8(File.readFrom(sumPath))
    var checked = 0
    var failed = 0
    for (line in content.split("\n")) {
        let lineNoCr = line.replace("\r", "")
        if (lineNoCr.size == 0 || lineNoCr.startsWith("#")) {
            continue
        }
        let idx = lineNoCr.indexOf(" ")
        if (idx.isNone()) {
            continue
        }
        let expectedHex = lineNoCr[0..idx.getOrThrow()].toAsciiLower()
        var relPath = lineNoCr[idx.getOrThrow()..]
        while (relPath.size > 0 && (relPath.startsWith(" ") || relPath.startsWith("\t"))) {
            relPath = relPath[1..]
        }
        if (relPath.startsWith("*")) {
            relPath = relPath[1..]
        }
        let filePath = Path("${releaseDir}/${relPath}")
        if (!exists(filePath)) {
            Log.get().error("SHA256SUMS 条目缺失文件: ${relPath}")
            failed++
            continue
        }
        var actual = ""
        if (let Some(h) <- hashFileSha256Hex(filePath, SHA256_VERIFY_CHUNK_BYTES)) {
            actual = h.toAsciiLower()
        } else {
            Log.get().error("SHA256 校验异常: ${relPath}: 无法读取/hash 文件")
            failed++
            continue
        }
        if (actual != expectedHex) {
            Log.get().error("SHA256 不匹配: ${relPath} (期望 ${expectedHex}, 实际 ${actual})")
            failed++
        } else {
            checked++
        }
    }
    if (failed > 0) {
        Log.get().error("SHA256SUMS 校验失败：通过 ${checked}，失败 ${failed}")
        return false
    }
    Log.get().info("SHA256SUMS 校验通过：${checked} 个文件")
    return true
}
