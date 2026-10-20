package uc_installer.cmd

// ============================================================================
// `install` / `rollback` / `uninstall` 三个子命令的 CLI 入口。
//
// 在此之前，安装主流程**只有 HTTP 一条通道** —— `core/orchestrator.cj`（S0~S8）
// 与 `services/devkit/*` 的唯一调用方是 `http/handlers/{runtime,devkit}.cj`，
// `main.cj` 里这三个子命令全部落到 `notImplemented`（exit 6）。这与 design §4.2.4
// 「CLI 为基础、HTTP 只做封装」正好相反，也让无浏览器的服务器/CI 环境无法安装。
// 本文件补齐 CLI 通道，HTTP handler 保持不变（两者共用 core/services 同一份实现）。
//
// ===================== 三条不打折的判据 =====================
//
// **① R-23 前置断言**：`devSourceDir` 与 `releaseDir` 互不嵌套，违反即不进入安装。
// **② 不冒充成功**：闸口未过即停止并报 `stoppedAt / stopReason / stopFix`（AC-121/164）。
// **③ AC-128**：自退役**不停止已启动的 runtime**，保留全部产物 —— 由 `selfRetire` 保证。
// ============================================================================

import std.fs.{Path, exists, rename, remove, Directory, FileInfo}
import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import std.core.StringBuilder
import uc_installer.cli.{CliArgs, Report, STATUS_PASS, STATUS_FAIL, STATUS_SKIP,
    STATUS_MANUAL, EXIT_OK, EXIT_ARGS, EXIT_GENERIC}
import uc_installer.core.{AppContext, assertDirsNotNested, resume, stepTable,
    retirePrecondition, selfRetire, verifyReleaseAt, STEP_PENDING}

/// `ucInstaller.exe install [--force] [--auto-exit] [--with-devkit]`
public func runInstall(parsed: CliArgs): Report {
    let report = Report()
    report.command = "install"

    if (parsed.rollback) {
        report.diagnostics.add(
            "--rollback 是开关不是子命令，已忽略；回滚请执行：ucInstaller.exe rollback")
    }

    let ctx = buildContext(parsed)

    // ---- R-23：DevKit 源码目录与发行目录互不嵌套 ----
    if (!assertDirsNotNested(ctx.paths.releaseDir, ctx.paths.devSourceDir)) {
        addCheck(report, "R23-dirs", STATUS_FAIL,
            "devSourceDir=${ctx.paths.devSourceDir} 与 releaseDir=${ctx.paths.releaseDir} 互为父子",
            "两目录互不嵌套（初始化动作绝不能打到发行目录上）",
            "用 --source-dir 另指定一个与 release/ 无关的源码目录后重跑", EXIT_GENERIC)
        return report
    }

    // ---- S0~S8 编排（断点续装；--force 时忽略已完成状态重跑）----
    let r = resume(ctx, parsed.force)

    for (id in r.executed) {
        addStepWith(report, id, STATUS_PASS, "已执行", EXIT_OK)
    }
    for (id in r.skipped) {
        addStepWith(report, id, STATUS_SKIP, "已完成，跳过（AC-123：不重复执行）", EXIT_OK)
    }

    if (!r.ok) {
        addCheck(report, r.stoppedAt, STATUS_FAIL, r.stopReason,
            "该步骤闸口通过并成功执行", r.stopFix, EXIT_GENERIC)
        report.remediation.add("按上面 fix 处理后重跑：ucInstaller.exe install（已完成步骤不会重复执行）")
        return report
    }

    // ---- release 骨架复核（缺了就一定起不来的那几个文件）----
    if (!verifyReleaseAt(ctx.paths.releaseDir)) {
        addCheck(report, "S-release", STATUS_FAIL,
            "release/ 骨架校验未通过（缺 agentskills-runtime.exe / VERSION / start.bat / stop.bat 之一）",
            "四件骨架齐全",
            "重跑 ucInstaller.exe install；若离线介质缺失，用 --offline 并确认 media/ 下已有发布包",
            EXIT_GENERIC)
        return report
    }
    addCheck(report, "S-release", STATUS_PASS,
        "release/ 骨架校验通过（${ctx.paths.releaseDir}）", "", "", EXIT_OK)

    // ---- --with-devkit：安装完成后触发 I1~I9 初始化 ----
    if (parsed.withDevkit) {
        let initOk = runInitInto(ctx, report, true)
        if (!initOk) {
            report.diagnostics.add("开发环境初始化存在未完成项，见 items 中 I 系列条目")
        }
    }

    // ---- 自退役（AC-126~128）----
    let v = retirePrecondition(ctx)
    if (!v.retirable) {
        report.diagnostics.add("暂不自退役：${v.reason}")
    } else {
        let rc = selfRetire(ctx, parsed.autoExit)
        addCheck(report, "S-retire", if (rc == 0) { STATUS_PASS } else { STATUS_FAIL },
            if (parsed.autoExit) { "已退役并退出（runtime 继续运行，产物全部保留，AC-128）" }
            else { "全部步骤已完成；未指定 --auto-exit，安装器保持运行" },
            "退役退出码 0", "", if (rc == 0) { EXIT_OK } else { EXIT_GENERIC })
    }
    return report
}

/// `ucInstaller.exe rollback [--force]`
///
/// 把 `previous/` 下**最新**的一份备份换回 `release/`；当前 release 先挪进 `.trash/`。
/// 没有备份即如实报告「无可回滚版本」，不假装成功。
public func runRollback(parsed: CliArgs): Report {
    let report = Report()
    report.command = "rollback"

    let ctx = buildContext(parsed)
    let latest = latestSnapshot(ctx.paths.previousDir)

    let target = match (latest) {
        case Some(p) => p
        case None =>
            addCheck(report, "R-previous", STATUS_MANUAL,
                "previous/ 下没有任何可回滚的备份（${ctx.paths.previousDir}）",
                "至少一份 previous/release-<时间戳> 备份",
                "无备份可回滚；如需重装请执行 ucInstaller.exe install", EXIT_GENERIC)
            return report
    }

    // 当前 release 先挪进 .trash（不直接删，便于人工找回）
    if (exists(ctx.paths.releaseDir)) {
        let ts = timestampName()
        let aside = ctx.paths.trashDir.join("release-rolledback-${ts}")
        try {
            Directory.create(ctx.paths.trashDir, recursive: true)
            rename(ctx.paths.releaseDir, to: aside, overwrite: true)
            report.diagnostics.add("当前 release 已移入 .trash/：${aside.toString()}")
        } catch (e: Exception) {
            addCheck(report, "R-stash", STATUS_FAIL,
                "无法把当前 release 移入 .trash/：${e.message}（文件被占用？）",
                "release/ 可移动",
                "关闭占用 release/ 下文件的程序（含正在运行的 runtime）后重跑", EXIT_GENERIC)
            return report
        }
    }

    try {
        rename(target, to: ctx.paths.releaseDir, overwrite: true)
    } catch (e: Exception) {
        addCheck(report, "R-restore", STATUS_FAIL,
            "回滚失败：${e.message}", "把备份换回 release/",
            "关闭占用 release/ 的程序后重跑；必要时手工把 ${target.toString()} 改名为 release/",
            EXIT_GENERIC)
        return report
    }

    let ok = verifyReleaseAt(ctx.paths.releaseDir)
    addCheck(report, "R-restore", if (ok) { STATUS_PASS } else { STATUS_FAIL },
        if (ok) { "已回滚到 ${target.toString()}，骨架校验通过" }
        else { "已换回 ${target.toString()}，但骨架校验未通过（备份本身可能不完整）" },
        "四件骨架齐全",
        if (ok) { "重新启动 runtime 前确认配置：ucInstaller.exe --json check-environment" }
        else { "该备份不可用，改回滚到更早的备份，或执行 ucInstaller.exe install 重装" },
        if (ok) { EXIT_OK } else { EXIT_GENERIC })

    if (ok) {
        // 回滚后把步骤状态复位，避免下次 install 认为"已完成"而跳过（AC-123 的反面）。
        for (s in stepTable()) {
            ctx.state.markStep(s.id, STEP_PENDING, None<String>, HashMap<String, String>())
        }
        report.diagnostics.add("已把 ${stepTable().size} 个步骤状态复位为 pending，下次 install 会重跑")
    }
    return report
}

/// `ucInstaller.exe uninstall [--force]`
///
/// 卸载是**破坏性动作**：未给 `--force` 时只报告将要删除什么，不落任何删除。
/// 即便给了 `--force`，也**不删** logs/、.env、media/ 与 previous/ ——
/// 日志与配置是排障依据，离线介质体积大且可复用，备份更是唯一的回滚来源。
public func runUninstall(parsed: CliArgs): Report {
    let report = Report()
    report.command = "uninstall"

    let ctx = buildContext(parsed)
    let planned = ArrayList<String>()
    for (p in [ctx.paths.releaseDir, ctx.paths.stagingDir, ctx.paths.trashDir]) {
        if (exists(p)) {
            planned.add(p.toString())
        }
    }
    for (p in [ctx.paths.stateFile, ctx.paths.gcFile, ctx.paths.portFile,
               ctx.paths.configFile]) {
        if (exists(p)) {
            planned.add(p.toString())
        }
    }

    if (!parsed.force) {
        addCheck(report, "U-plan", STATUS_MANUAL,
            "未指定 --force，未做任何删除。待删除 ${planned.size} 项：${joinPaths(planned)}",
            "确认范围后显式加 --force",
            "ucInstaller.exe uninstall --force（logs/ · .env · media/ · previous/ 一律保留）",
            EXIT_GENERIC)
        report.diagnostics.add("卸载不会停止正在运行的 runtime；请先自行停止或重启后删除")
        return report
    }

    var removed = 0
    var failed = 0
    for (text in planned) {
        let p = Path(text)
        try {
            if (isDirPath(p)) {
                remove(p, recursive: true)
            } else {
                remove(p)
            }
            removed += 1
            addStepWith(report, "U-${removed}", STATUS_PASS, "已删除 ${text}", EXIT_OK)
        } catch (e: Exception) {
            failed += 1
            addStepWith(report, "U-fail-${failed}", STATUS_FAIL,
                "删除失败 ${text}：${e.message}", EXIT_GENERIC)
        }
    }

    if (failed > 0) {
        report.diagnostics.add("${failed} 项删除失败（多为文件被占用）；关闭占用程序后重跑 uninstall --force")
    }
    addCheck(report, "U-summary", if (failed == 0) { STATUS_PASS } else { STATUS_FAIL },
        "已删除 ${removed} 项，失败 ${failed} 项",
        "全部待删项删除成功",
        if (failed == 0) { "卸载完成；如需重新安装请执行 ucInstaller.exe install" }
        else { "关闭占用程序后重跑：ucInstaller.exe uninstall --force" },
        if (failed == 0) { EXIT_OK } else { EXIT_GENERIC })
    return report
}

// ===================== 内部 =====================

/// `previous/` 下的最新备份（目录名 `release-<ISO 时间戳>`，字典序即时序）。
func latestSnapshot(previousDir: Path): Option<Path> {
    if (!exists(previousDir)) {
        return None<Path>
    }
    var best: Option<Path> = None<Path>
    try {
        for (info in Directory.readFrom(previousDir)) {
            if (!info.path.fileName.startsWith("release-")) {
                continue
            }
            match (best) {
                case Some(b) =>
                    if (info.path.fileName > b.fileName) {
                        best = Some(info.path)
                    }
                case None => best = Some(info.path)
            }
        }
    } catch (_: Exception) {
        return None<Path>
    }
    return best
}

/// 目录还是文件（用于决定 `remove` 是否带 `recursive`）。
func isDirPath(p: Path): Bool {
    try {
        let fi = FileInfo(p)
        return fi.isDirectory()
    } catch (_: Exception) {
        return false
    }
}

func timestampName(): String {
    return DateTime.now().toString().replace(":", "-").replace(" ", "_")
}

func joinPaths(paths: ArrayList<String>): String {
    let sb = StringBuilder()
    var i = 0
    while (i < paths.size) {
        if (i > 0) {
            sb.append(" · ")
        }
        sb.append(paths[i])
        i += 1
    }
    if (sb.size == 0) {
        return "（无）"
    }
    return sb.toString()
}
