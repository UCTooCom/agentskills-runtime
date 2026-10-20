package uc_installer.cmd

// ============================================================================
// `devkit install` / `devkit verify` / `devkit init` 的 CLI 入口。
//
// 与 HTTP 端点 `POST /setup/devkit/install`、`GET /setup/devkit/verify` 共用
// `services/devkit/*` 的同一份实现，本文件只做「结果 → §4.11.1 报告」的翻译。
//
// 三条从 handler 原样继承的判据（不允许在 CLI 通道放宽）：
//   ① **只装被点名的组件**（AC-131）：ids 为空直接参数错误，绝不退化成"全装"；
//   ② **探测不到 ≠ 通过**（AC-144）：磁盘探不到时留痕 degraded，不阻断但如实写；
//   ③ **不伪造成功**（AC-132）：每项 actual 必须是探测到的真实值。
// ============================================================================

import std.fs.Path
import std.collection.ArrayList
import uc_installer.cli.{CliArgs, Report, STATUS_PASS, STATUS_FAIL, STATUS_SKIP,
    STATUS_MANUAL, STATUS_DEGRADED, EXIT_OK, EXIT_ARGS, EXIT_GENERIC}
import uc_installer.core.AppContext
import uc_installer.services.{DbConn, readEnv, readDbConnectionUrl, parseDatabaseUrl}
import uc_installer.services.devkit.{DevkitFacts, InitContext, InstallOutcome,
    collectSourceFacts, devkitRegistry, devkitComponentById, devkitDepsClosure,
    installDevkitComponent, installOutcomeCode, isInstallSuccess, verifyDevkit,
    runInitSteps, initStatusCode, diskGate, diskProbeFailed, requiredMbFor}

/// `ucInstaller.exe devkit install DK-3 [DK-5 ...]`
///
/// ids 取自子命令第三个及之后的 token；为空即 EXIT_ARGS（与 HTTP 的 400 同义）。
public func runDevkitInstall(parsed: CliArgs): Report {
    let report = Report()
    report.command = "devkit install"

    let ids = devkitIdsOf(parsed)
    if (ids.isEmpty()) {
        addCheck(report, "args.ids", STATUS_FAIL,
            "未指定组件标识", "至少一个 DK-1~DK-8 的标识",
            "ucInstaller.exe devkit install DK-3（可空格分隔多个；空列表不会被当作全装）",
            EXIT_ARGS)
        return report
    }

    let ctx = buildContext(parsed)
    let dir = ctx.paths.devSourceDir

    // ---- 磁盘闸口（AC-144）：与 HTTP 通道同一份 `diskGate` ----
    if (diskProbeFailed(dir)) {
        // 先记下标再加项：`addCheck` 不设 degraded，取回引用后补标记
        // （`ReportItem` 是 class，索引取回的是引用，改它即生效 —— 同 `cli/env_check.cj`）。
        let at = report.items.size
        addCheck(report, "disk", STATUS_DEGRADED,
            "无法探测目标磁盘剩余空间（wmic 无输出或目录所在卷不可解析）",
            "磁盘空间闸口应生效",
            "手工执行 wmic logicaldisk get DeviceID,FreeSpace 确认空间充足；本次未做容量校验",
            EXIT_OK)
        report.items[at].degraded = true
    }
    match (diskGate(dir, ids)) {
        case Some(msg) =>
            addCheck(report, "disk", STATUS_FAIL, msg,
                "剩余空间 >= 所选组件所需 ${requiredMbFor(ids)} MB",
                "清理目标盘或改用空间充足的目录（--source-dir）后重跑", EXIT_GENERIC)
            return report
        case None => ()
    }

    // ---- 依赖闭包展开（只勾 DK-5 也要能真正装成，顺序按注册表）----
    let ordered = expandWithDeps(ids)

    for (id in ordered) {
        let res = installDevkitComponent(id, dir, parsed.force)
        let ok = isInstallSuccess(res.outcome)
        let status = if (ok) { STATUS_PASS } else { STATUS_FAIL }
        let code = if (ok) { EXIT_OK } else { EXIT_GENERIC }
        addCheck(report, id, status,
            if (res.actual.isEmpty()) { res.message } else { res.actual },
            componentExpected(id, dir),
            if (ok) { "" } else { res.message }, code)

        // 依赖未满足 / 目录被拒 / 未实现：后续组件只会同样失败，如实中断并留痕
        if (!ok && stopsPipeline(res.outcome)) {
            report.diagnostics.add("在 ${id}（${installOutcomeCode(res.outcome)}）中断后续安装：${res.message}")
            break
        }
    }

    // ---- 安装后立即触发初始化 I1~I9（勾了 DK-3 / DK-7 才真正执行）----
    let initOk = runInitInto(ctx, report, parsed.withDevkit)
    if (!initOk) {
        report.diagnostics.add("开发环境初始化存在未完成项，见 items 中 I 系列条目")
    }
    return report
}

/// `ucInstaller.exe devkit verify`
public func runDevkitVerify(parsed: CliArgs): Report {
    let report = Report()
    report.command = "devkit verify"

    let ctx = buildContext(parsed)
    let dir = ctx.paths.devSourceDir
    let facts = collectFacts(ctx, dir)
    let checks = verifyDevkit(dir, facts)
    if (checks.isEmpty()) {
        addCheck(report, "devkit", STATUS_FAIL,
            "自检未产出任何条目（源码目录 ${dir} 可能不存在）",
            "DK-1~DK-8 逐项自检",
            "先执行 ucInstaller.exe devkit install DK-3", EXIT_GENERIC)
        return report
    }
    for (c in checks) {
        let status = if (c.passed) { STATUS_PASS } else { STATUS_FAIL }
        let code = if (c.passed) { EXIT_OK } else { EXIT_GENERIC }
        addCheck(report, c.id, status, c.actual, c.expected, if (c.passed) { "" } else { c.fix }, code)
    }
    return report
}

/// `ucInstaller.exe devkit init`（只跑 I1~I9，不装组件）
public func runDevkitInit(parsed: CliArgs): Report {
    let report = Report()
    report.command = "devkit init"
    let ctx = buildContext(parsed)
    let ok = runInitInto(ctx, report, parsed.withDevkit)
    if (!ok) {
        report.diagnostics.add("I 系列存在未完成项，见 items 中 I 系列条目")
    }
    return report
}

// ===================== 共享：I1~I9 =====================

/// 执行 I1~I9 并把结果并入报告。返回是否全部通过。
///
/// 抽成共享函数是为了让 `install --with-devkit` 与 `devkit install` / `devkit init`
/// 走同一条路径 —— 三处各写一遍必然漂移。
public func runInitInto(ctx: AppContext, report: Report, withFrontend: Bool): Bool {
    let dir = ctx.paths.devSourceDir
    let ic = InitContext(dir, ctx.paths.releaseDir.join(".env"), dir.join(".env"),
        withFrontend, dbConnOf(ctx))
    let results = runInitSteps(ic)
    if (results.isEmpty()) {
        addCheck(report, "I0", STATUS_MANUAL,
            "初始化未产出任何条目", "I1~I9 逐项结果",
            "确认 --source-dir 指向开发者源码树后重跑", EXIT_GENERIC)
        return false
    }
    var allOk = true
    for (r in results) {
        let status = initStatusCode(r.status)
        if (status == STATUS_FAIL || status == STATUS_MANUAL) {
            allOk = false
        }
        let code = if (status == STATUS_PASS || status == STATUS_SKIP) { EXIT_OK } else { EXIT_GENERIC }
        let actual = if (r.actual.isEmpty()) { "（无实际输出）" } else { r.actual }
        addCheck(report, r.id, status, actual + "（cwd=${r.cwd}）", r.expected, r.fix, code)
    }
    return allOk
}

// ===================== 内部 =====================

/// 从子命令 token 里取组件标识（`devkit install` 之后的全部 token）。
func devkitIdsOf(parsed: CliArgs): ArrayList<String> {
    let out = ArrayList<String>()
    var i = 2
    while (i < parsed.command.size) {
        out.add(parsed.command[i])
        i += 1
    }
    return out
}

/// 把 ids 展开为「含依赖闭包、按注册表顺序」的安装序列。
func expandWithDeps(ids: ArrayList<String>): ArrayList<String> {
    let closure = ArrayList<String>()
    for (id in ids) {
        for (d in devkitDepsClosure(id)) {
            if (!closure.contains(d)) {
                closure.add(d)
            }
        }
    }
    let ordered = ArrayList<String>()
    for (c in devkitRegistry()) {
        if (closure.contains(c.id)) {
            ordered.add(c.id)
        }
    }
    return ordered
}

/// 安装成功后的自检判据（AC-132：必须给 expected，不拿空判据充数）。
func componentExpected(id: String, dir: Path): String {
    match (devkitComponentById(id)) {
        case Some(c) => return c.expected
        case None => return "组件标识须为 DK-1~DK-8"
    }
}

/// 采自检事实：源码树事实 + 数据库连接（与 HTTP 通道同口径）。
func collectFacts(ctx: AppContext, dir: Path): DevkitFacts {
    let f = collectSourceFacts(dir)
    f.db = dbConnOf(ctx)
    return f
}

/// 从 `release/.env` 的 DATABASE_URL 构建开发库连接；拿不到返回 None。
///
/// 只做「读 env → 取 URL → 解析」三步组合，判定逻辑全在 `services` 里，
/// 不在本包重写第二份。
func dbConnOf(ctx: AppContext): Option<DbConn> {
    let envPath = ctx.paths.releaseDir.join(".env")
    match (readEnv(envPath)) {
        case Some(env) => match (readDbConnectionUrl(env)) {
            case Some(url) => match (parseDatabaseUrl(url)) {
                case Some(c) => return Some(DbConn(c.host, c.port, c.database, c.user, c.password))
                case None => return None<DbConn>
            }
            case None => return None<DbConn>
        }
        case None => return None<DbConn>
    }
}

/// 哪些失败类型应当中断后续安装：git 缺失 / 目录被拒 / 依赖缺失 / 未实现。
/// 网络不可达**不**中断 —— 后续组件未必依赖 DK-3。
func stopsPipeline(o: InstallOutcome): Bool {
    return match (o) {
        case InstallOutcome.Ok => false
        case InstallOutcome.NetworkUnreachable(_) => false
        case InstallOutcome.GitMissing => true
        case InstallOutcome.DirRejected(_) => true
        case InstallOutcome.DepMissing(_) => true
        case InstallOutcome.Failed(_) => true
    }
}
