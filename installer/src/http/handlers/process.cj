package uc_installer.http.handlers

import uc_installer.core.{AppContext, RuntimePidRecord, readRuntimePidFile, writeRuntimePidFile, removeRuntimePidFile}
import http_lib.router.Handler
import http_lib.message.{HttpResponse}
import uc_installer.platform.{verifyProcessImage, isPidAlive, terminateProcess, killProcessTree, launchRuntime}
import uc_installer.util.{jstr, jint, jbool, jobj, jarr, jsonOk, jsonOkCode, jsonErr}
import http_lib.core.HttpStatus
import std.time.DateTime
import std.fs.{exists, Path}

/// runtime 可执行文件名（与 PID 文件 image 字段保持一致，R-06 校验锚点）。
let RUNTIME_IMAGE: String = "agentskills-runtime.exe"

/// `POST /setup/start-runtime` 处理器（T025 / design.md §4.2.3 #9）。
///
/// 未安装（缺 release/bin/agentskills-runtime.exe）→ 500；成功启动写 PID 文件并返回
/// `{code:200, message, pid, path}`。所有 launch 经由 platform.launchRuntime（R-04）。
public func startRuntimeHandler(ctx: AppContext): Handler {
    return { _ => doStart(ctx) }
}

/// `POST /setup/stop-runtime` 处理器（T025 / design.md §4.2.3 #10）。
///
/// 仅按 PID 精确终止 + 镜像名校验：未运行/镜像不匹配时清理 PID 文件并报“未运行”，
/// 不误杀 PID 复用进程（AC-011/106）。逐级升级：温和 terminate → 强制 terminate → taskkill /PID /T /F。
public func stopRuntimeHandler(ctx: AppContext): Handler {
    return { _ => doStop(ctx) }
}

/// `POST /setup/restart-runtime` 处理器（T025 / design.md §4.2.3 #11）。
///
/// 先精确停止，再启动；`<installRoot>/start-runtime.bat` 存在时优先执行该脚本。
public func restartRuntimeHandler(ctx: AppContext): Handler {
    return { _ => doRestart(ctx) }
}

private func doStart(ctx: AppContext): HttpResponse {
    let releaseDir = ctx.paths.releaseDir
    let exe = releaseDir.join("bin").join(RUNTIME_IMAGE)
    if (!exists(exe)) {
        return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500,
            "runtime 尚未安装：缺少可执行文件 ${exe.toString()}", jobj())
    }
    match (launchRuntime(exe, releaseDir)) {
        case None => return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "启动 runtime 失败", jobj())
        case Some(pid) =>
            let verified = verifyProcessImage(pid, RUNTIME_IMAGE)
            let startedAt = DateTime.now().format("yyyy-MM-dd'T'HH:mm:ss")
            writeRuntimePidFile(ctx.paths.installRoot,
                RuntimePidRecord(pid: pid, image: RUNTIME_IMAGE, exe: exe.toString(), startedAt: startedAt))
            let data = jobj()
            data.put("pid", jint(pid))
            data.put("path", jstr(exe.toString()))
            data.put("verified", jbool(verified))
            return jsonOkCode(200, "runtime 已启动", data)
    }
}

private func doStop(ctx: AppContext): HttpResponse {
    let installRoot = ctx.paths.installRoot
    match (readRuntimePidFile(installRoot)) {
        case None => return jsonOk("runtime 当前未运行", jobj())
        case Some(rec) =>
            // 镜像名双重校验：PID 可能被复用，绝不直接杀（AC-011/106）
            if (!verifyProcessImage(rec.pid, rec.image)) {
                removeRuntimePidFile(installRoot)
                return jsonOk("runtime 当前未运行（已清理过期 PID 文件）", jobj())
            }
            // ① 温和终止
            terminateProcess(rec.pid, false)
            var i = 0
            while (i < 10) {
                sleep(Duration.second)
                if (!isPidAlive(rec.pid)) { break }
                i = i + 1
            }
            // ② 仍存活 → 强制终止，再等 5s
            if (isPidAlive(rec.pid)) {
                terminateProcess(rec.pid, true)
                i = 0
                while (i < 5) {
                    sleep(Duration.second)
                    if (!isPidAlive(rec.pid)) { break }
                    i = i + 1
                }
            }
            // ③ 仍存活 → taskkill /PID /T /F（仅 /PID，符合 R-06）
            if (isPidAlive(rec.pid)) {
                killProcessTree(rec.pid)
                sleep(Duration.second)
            }
            if (isPidAlive(rec.pid)) {
                removeRuntimePidFile(installRoot)
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500,
                    "runtime 停止失败，请手动终止 PID ${rec.pid}：taskkill /PID ${rec.pid} /T /F", jobj())
            }
            removeRuntimePidFile(installRoot)
            return jsonOk("runtime 已停止", jobj())
    }
}

private func doRestart(ctx: AppContext): HttpResponse {
    let installRoot = ctx.paths.installRoot
    doStop(ctx)
    // 优先 start-runtime.bat
    let bat = installRoot.join("start-runtime.bat")
    if (exists(bat)) {
        match (launchRuntime(bat, installRoot)) {
            case None => return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "通过 start-runtime.bat 重启失败", jobj())
            case Some(pid) =>
                let verified = verifyProcessImage(pid, RUNTIME_IMAGE)
                let startedAt = DateTime.now().format("yyyy-MM-dd'T'HH:mm:ss")
                writeRuntimePidFile(installRoot,
                    RuntimePidRecord(pid: pid, image: RUNTIME_IMAGE, exe: bat.toString(), startedAt: startedAt))
                let data = jobj()
                data.put("pid", jint(pid))
                data.put("path", jstr(bat.toString()))
                data.put("verified", jbool(verified))
                return jsonOkCode(200, "runtime 已通过 start-runtime.bat 重启", data)
        }
    }
    return doStart(ctx)
}
