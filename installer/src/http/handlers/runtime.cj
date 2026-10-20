package uc_installer.http.handlers

import http_lib.router.Handler
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.HttpStatus
import uc_installer.core.AppContext
import uc_installer.util.{jstr, jbool, jobj, jsonOkCode, jsonErr}
import uc_installer.services.{findReleaseTar, verifyTar, extractTar, verifySha256Sums}
import uc_installer.services.readFileText
import uc_installer.core.{verifyRelease, snapshotExisting}
import std.fs.exists

/// `GET /setup/check-runtime` 处理器（T022 / design.md §4.2.3 #12）。
///
/// **裸对象、无 `code` 信封**：`{installed,path,runtimeDir,releaseDir,version,hasEnv,message}`。
public func checkRuntimeHandler(ctx: AppContext): Handler {
    return { _ => doCheckRuntime(ctx) }
}

/// `POST /setup/install-runtime` 处理器（T022 / design.md §4.2.3 #13）。
///
/// 幂等；本地介质优先：在 mediaDir 找 release tar → 校验 → 解压到 installRoot（tar 顶层应为 release/）
/// → verifyRelease 复核落地完整。已存在 release 先快照到 previous 以便回滚。
public func installRuntimeHandler(ctx: AppContext): Handler {
    return { req => doInstallRuntime(ctx, req) }
}

private func doCheckRuntime(ctx: AppContext): HttpResponse {
    let releaseDir = ctx.paths.releaseDir
    let exe = releaseDir.join("bin").join("agentskills-runtime.exe")
    let installed = exists(exe)
    let version = if (exists(releaseDir.join("VERSION"))) {
        readFileText(releaseDir.join("VERSION")).trimAscii()
    } else {
        ""
    }
    let hasEnv = exists(releaseDir.join(".env"))
    let o = jobj()
    o.put("installed", jbool(installed))
    o.put("path", jstr(exe.toString()))
    o.put("runtimeDir", jstr(ctx.paths.installRoot.toString()))
    o.put("releaseDir", jstr(releaseDir.toString()))
    o.put("version", jstr(version))
    o.put("hasEnv", jbool(hasEnv))
    o.put("message", jstr(if (installed) { "runtime 已安装" } else { "runtime 尚未安装" }))
    return HttpResponse.json(HttpStatus.OK, o.toJsonString())
}

private func doInstallRuntime(ctx: AppContext, req: HttpRequest): HttpResponse {
    let mediaDir = ctx.paths.mediaDir
    if (!exists(mediaDir)) {
        return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "未找到离线介质目录", jobj())
    }
    match (findReleaseTar(mediaDir)) {
        case None => return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500,
            "未找到安装介质（release/*.tar.gz），请确认离线介质已就位", jobj())
        case Some(tar) =>
            if (!verifyTar(tar)) {
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "安装介质校验失败（非 gzip 压缩包）", jobj())
            }
            // 已存在 release 先快照（原子回滚备用）
            snapshotExisting(ctx.paths)
            if (!extractTar(tar, ctx.paths.installRoot)) {
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "解压安装介质失败", jobj())
            }
            if (!verifySha256Sums(ctx.paths.releaseDir)) {
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "发行包 SHA256SUMS 校验失败（介质可能被篡改或不完整）", jobj())
            }
            if (!verifyRelease(ctx.paths)) {
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500,
                    "release 落地不完整（缺少 agentskills-runtime.exe）", jobj())
            }
            let data = jobj()
            data.put("source", jstr("local"))
            data.put("path", jstr(ctx.paths.releaseDir.toString()))
            return jsonOkCode(200, "runtime 安装完成", data)
    }
}
