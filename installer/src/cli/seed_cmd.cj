package uc_installer.cli

// ============================================================================
// `seed apply` / `seed verify` 子命令（任务 T049）。
//
// 对应 REQ-RNI-081；AC-197~200。
//
// `seed apply` 串起导入五步（research-seed-identity.md §3.3）：
//   P0 解析主体标识（rbac.cj：A1~A6 + RBAC 补种）
//   P1 结构与非身份数据导入
//   P2 身份重绑定（字符串级，零 UPDATE）
//   P3 孤儿与脱敏占位符处置
//   P4 校验（verify.cj：表数 / 悬空 == 0 / 菜单非空）
//
// 与 `db export` 共用 `resolveRepoRoot` / `buildConn`（db_export.cj），
// 保证「源码目录」与「连接构建」两处口径一致（AC-187/198）。
//
// 报告红线：主 agent 的随机口令**只在本次报告里展示一次**（AC-204），
// 且不写入任何文件；失败项必带 fix（AC-164）。
// ============================================================================

import uc_installer.services.seed.{loadExportPolicy, applySeed, verifySeed}

/// `seed apply`：导入 seed 并校验。
public func runSeedApply(parsed: CliArgs): Report {
    let report = Report()
    report.command = "seed apply"
    let repoRoot = resolveRepoRoot(parsed)

    // ---- 策略（与导出同一份 export-policy.json）----
    let lp = loadExportPolicy(repoRoot)
    if (!lp.ok()) {
        for (e in lp.errors) {
            report.diagnostics.add(e)
        }
        addCheck(report, "P-policy", STATUS_FAIL,
            "导出策略加载失败：${lp.errors.size} 条",
            "export-policy.json 与 sanitize-policy.json 均合法",
            "修复 sql/seed/export-policy.json 与 sql/seed/sanitize-policy.json", EXIT_GENERIC)
        return report
    }
    let policy = match (lp.exportPolicy) {
        case Some(p) => p
        case None => return report   // 不可达：lp.ok() 已保证
    }

    // ---- 连接 ----
    let conn = match (buildConn(parsed, repoRoot)) {
        case Some(c) => c
        case None =>
            addCheck(report, "P-connect", STATUS_FAIL,
                "无法构建数据库连接（既无 .env 的 DATABASE_URL，也未提供 --user/--password）",
                "提供 --user/--password，或确保源码目录 .env 含 DATABASE_URL",
                "ucInstaller.exe seed apply --user <u> --password <p> --source-dir <dir>", EXIT_GENERIC)
            return report
    }
    addCheck(report, "P-connect", STATUS_PASS,
        "已连接 ${conn.host}:${conn.port}/${conn.database}", "", "", EXIT_OK)

    // ---- P0~P3 导入 ----
    let sqlPath = repoRoot.join("sql/uctooDB.sql")
    let res = applySeed(conn, policy, sqlPath)

    for (l in res.principals) {
        report.diagnostics.add("主体解析 ${l}")
    }
    for (l in res.reboundLines()) {
        report.diagnostics.add("重绑定 ${l}")
    }
    for (o in res.orphans) {
        report.diagnostics.add("孤儿 ${o}")
    }
    for (s in res.skippedTables) {
        report.diagnostics.add("跳过 ${s}")
    }
    for (t in res.reusedTables) {
        report.diagnostics.add("复用 ${t}（已有数据，本轮未重复写入）")
    }
    for (n in res.notes) {
        report.diagnostics.add(n)
    }
    for (e in res.errors) {
        report.diagnostics.add(e)
    }

    // P0
    if (res.setup.ok()) {
        addCheck(report, "P0-identity", STATUS_PASS,
            "身份二元组就绪：超管 ${res.setup.superAdminId} / 主 agent 账号 ${res.setup.agentUserId} / 实体 ${res.setup.agentId}",
            "", "", EXIT_OK)
        if (!res.setup.agentPassword.isEmpty()) {
            // AC-204：随机口令一次性展示（不落任何文件）
            addCheck(report, "P0-agent-password", STATUS_PASS,
                "主 agent 账号 ${res.setup.agentUsername} 的随机初始口令（仅本次展示，不落库、不可用于登录）：${res.setup.agentPassword}",
                "", "", EXIT_OK)
        }
    } else {
        addCheck(report, "P0-identity", STATUS_FAIL,
            "身份二元组未就绪：${res.setup.errors.size} 条错误",
            "超管已由 create-admin 建立，且主 agent 账号/实体/绑定齐备",
            "先完成安装流程的 create-admin，再执行 seed apply", EXIT_GENERIC)
        return report
    }

    // P1 / P2 / P3
    addCheck(report, "P1-structure", STATUS_PASS,
        "结构语句 ${res.ddlStatements} 条（扫描 ${res.statementCount} 条顶层语句 / ${res.insertCount} 条 INSERT）",
        "", "", EXIT_OK)
    addCheck(report, "P2-rebind", STATUS_PASS,
        "身份重绑定 ${res.reboundCells} 个单元格；写入 ${res.insertStatements} 条 INSERT / ${res.rowsInserted} 行",
        "", "", EXIT_OK)
    addCheck(report, "P3-placeholder", STATUS_PASS,
        "脱敏占位符原样保留 ${res.keptPlaceholders} 处（{{secret}}/{{env}} 绝不解析）",
        "", "", EXIT_OK)

    if (!res.ok()) {
        addCheck(report, "P2-import", STATUS_FAIL,
            "导入失败：${res.errors.size} 条错误（已回滚，库中不残留本轮数据）",
            "身份引用全部解析成功且写入无冲突",
            "按 diagnostics 修复（孤儿加 orphanOverrides 或改 orphanDefault）后重跑", EXIT_GENERIC)
        return report
    }

    // ---- P4 校验 ----
    let manifestPath = repoRoot.join("sql/seed/seed-manifest.json")
    let vr = verifySeed(conn, policy, manifestPath)
    for (d in vr.danglingDetails) {
        report.diagnostics.add("悬空 ${d}")
    }
    for (n in vr.notes) {
        report.diagnostics.add(n)
    }
    for (e in vr.errors) {
        report.diagnostics.add(e)
    }
    if (vr.ok()) {
        addCheck(report, "P4-verify", STATUS_PASS,
            "表 ${vr.tableCount} 张 / 悬空引用 0 / 超管菜单 ${vr.menuCount} 项",
            "", "", EXIT_OK)
    } else {
        addCheck(report, "P4-verify", STATUS_FAIL,
            "导入后校验未通过：${vr.errors.size} 条（表 ${vr.tableCount} / 悬空 ${vr.danglingRefs} / 菜单 ${vr.menuCount}）",
            "表总数一致 · 悬空身份引用 == 0 · 超管菜单树非空",
            "按 diagnostics 修正后重跑 seed apply（导入是幂等的）", EXIT_GENERIC)
    }
    return report
}

/// `seed verify`：只跑 P4 三条判据（不改库）。
public func runSeedVerify(parsed: CliArgs): Report {
    let report = Report()
    report.command = "seed verify"
    let repoRoot = resolveRepoRoot(parsed)

    let lp = loadExportPolicy(repoRoot)
    if (!lp.ok()) {
        for (e in lp.errors) {
            report.diagnostics.add(e)
        }
        addCheck(report, "V-policy", STATUS_FAIL,
            "导出策略加载失败：${lp.errors.size} 条",
            "export-policy.json 合法",
            "修复 sql/seed/export-policy.json", EXIT_GENERIC)
        return report
    }
    let policy = match (lp.exportPolicy) {
        case Some(p) => p
        case None => return report
    }
    let conn = match (buildConn(parsed, repoRoot)) {
        case Some(c) => c
        case None =>
            addCheck(report, "V-connect", STATUS_FAIL,
                "无法构建数据库连接",
                "提供 --user/--password，或确保源码目录 .env 含 DATABASE_URL",
                "ucInstaller.exe seed verify --user <u> --password <p> --source-dir <dir>", EXIT_GENERIC)
            return report
    }
    let manifestPath = repoRoot.join("sql/seed/seed-manifest.json")
    let vr = verifySeed(conn, policy, manifestPath)
    for (d in vr.danglingDetails) {
        report.diagnostics.add("悬空 ${d}")
    }
    for (n in vr.notes) {
        report.diagnostics.add(n)
    }
    for (e in vr.errors) {
        report.diagnostics.add(e)
    }
    if (vr.ok()) {
        addCheck(report, "V-tables", STATUS_PASS,
            "public 表 ${vr.tableCount} 张（manifest 声明 ${vr.expectedTableCount}）", "", "", EXIT_OK)
        addCheck(report, "V-dangling", STATUS_PASS, "悬空身份引用 0（判据 == 0）", "", "", EXIT_OK)
        addCheck(report, "V-menu", STATUS_PASS,
            "超管 ${vr.superAdminId} 可见菜单 ${vr.menuCount} 项（非空）", "", "", EXIT_OK)
    } else {
        addCheck(report, "V-verify", STATUS_FAIL,
            "校验未通过：${vr.errors.size} 条（表 ${vr.tableCount} / 悬空 ${vr.danglingRefs} / 菜单 ${vr.menuCount}）",
            "表总数一致 · 悬空身份引用 == 0 · 超管菜单树非空",
            "按 diagnostics 修正后重跑 seed apply", EXIT_GENERIC)
    }
    return report
}

/// 报告项辅助：统一走 addItem（内部维护 ok / exitCode）。
func addCheck(report: Report, id: String, status: String, actual: String, expected: String,
              fix: String, code: Int64): Unit {
    let it = ReportItem()
    it.id = id
    it.status = status
    it.actual = actual
    it.expected = expected
    it.fix = fix
    it.code = code
    addItem(report, it)
}
