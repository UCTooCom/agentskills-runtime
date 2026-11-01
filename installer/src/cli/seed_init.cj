package uc_installer.cli

// ============================================================================
// `seed-init` 子命令（PcClientInstallProvisioning 任务 T-01，design.md §3.2）。
//
// 首次运行自助建号：安装期只备空壳（install --no-data），首次运行时由用户
// 自助建立管理员账号并拉起整库种子。
//
// 流程（修正版，规避 applySeed 内部早退与 role_has_permission 污染）：
//   1. 解析 --email/--username/--name，口令从 stdin 读取（绝不落盘/进参数）；
//   2. 确保目标库（uctoo）存在（不存在则连 maintenance 库建库）；
//   3. 若 uctoo_user 尚未建/为空，RAW 导入 sql/uctooDB.sql（占位符替换）；
//   4. 建立（或复用）超管账号（显式 uuid + bcrypt 哈希口令）+ 绑定超管角色；
//   5. 调用 applySeed 完成 P0~P4 校验/身份重绑定（主 agent 账号/实体/绑定等）。
//
// 退出码：0=成功 / 2=参数错误 / 3=环境（库/连接） / 1=通用失败 / 6=待人工。
// ============================================================================

import pgsql.{PgDatasource, registerDriver}
import std.database.sql.{Connection, Statement, QueryResult}
import std.collection.{ArrayList, HashMap}
import std.fs.{Path, exists}
import std.core.StringBuilder
import std.convert.Parsable

import uc_installer.services.{DbConn, hashPassword, readFileText}
import uc_installer.services.seed.{loadExportPolicy, applySeed, ImportReport, IdentitySetup}

/// 超管角色 id（与 rbac.cj RBAC_SUPER_ADMIN_ROLE_ID 同值）。
let SEED_INIT_SUPER_ADMIN_ROLE = "2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d"
/// 确定性纪元字面量（与 importer.cj TS_EPOCH_LITERAL 同值）。
let SEED_INIT_TS_EPOCH = "1970-01-01 00:00:00+00"
let SEED_INIT_PH_PRINCIPAL = "{{principal:super_admin}}"
let SEED_INIT_PH_TS = "{{ts:epoch}}"

/// seed-init 入口。
public func runSeedInit(parsed: CliArgs): Report {
    let report = Report()
    report.command = "seed-init"

    // ---- 1. 参数 + 口令 ----
    let username = parsed.username.trimAscii()
    let email = parsed.email.trimAscii()
    let name = if (parsed.name.trimAscii().isEmpty()) { username } else { parsed.name.trimAscii() }
    if (username.isEmpty() || email.isEmpty()) {
        return failureReport("seed-init", "args",
            "seed-init 需要 --username 与 --email（--name 可选，缺省用 username）",
            "ucInstaller.exe --username <登录名> --email <邮箱> --name <显示名> --no-serve --progress=ndjson seed-init",
            "补充缺失参数后重试", EXIT_ARGS)
    }
    let password = readStdinPassword()
    if (password.isEmpty()) {
        return failureReport("seed-init", "password",
            "未从 stdin 读到口令（须通过标准输入提供，避免命令行泄露）",
            "echo <口令> | ucInstaller.exe --username ... --email ... seed-init",
            "通过标准输入提供管理员口令后重试", EXIT_ARGS)
    }

    // ---- 2. 连接参数 ----
    let repoRoot = resolveRepoRoot(parsed)
    let connOpt = buildConn(parsed, repoRoot)
    let conn = match (connOpt) {
        case Some(c) => c
        case None =>
            return failureReport("seed-init", "E1-connect",
                "无法构建数据库连接（既无 release/.env 的 DATABASE_URL，也未提供 --user/--password）",
                "应有可连接的数据库凭据（DATABASE_URL 或 --user/--password）",
                "提供 --user/--password，或确保 release/.env 含 DATABASE_URL", EXIT_ENV)
    }
    stepOk(report, "resolve-conn", "已解析目标库连接（${conn.host}:${conn.port}/${conn.database}）")

    // ---- 3. 确保库存在 ----
    if (!ensureDatabase(conn)) {
        return failureReport("seed-init", "create-db",
            "无法确保目标库 ${conn.database} 存在（检查 PG 是否已启动、账号是否可连 maintenance 库或具备 CREATEDB）",
            "目标库应可创建或已存在",
            "确认 PostgreSQL 已启动且连接账号具备建库权限", EXIT_ENV)
    }
    stepOk(report, "ensure-db", "目标库 ${conn.database} 已就绪")

    // ---- 4. 连接 uctoo，按需 RAW 导入 + 建超管 ----
    let dbOpt = openDb(conn)
    let db = match (dbOpt) {
        case Some(c) => c
        case None =>
            return failureReport("seed-init", "open-uctoo",
                "无法连接目标库 ${conn.database}", "目标库应可连接",
                "检查 PG 可连接性", EXIT_ENV)
    }
    try {
        if (!tableHasRows(db, "uctoo_user")) {
            let adminId = localSeedQuery(db, "SELECT gen_random_uuid()::text")
            if (adminId.isEmpty()) {
                return failureReport("seed-init", "gen-uuid",
                    "无法生成超管 uuid（gen_random_uuid 不可用）",
                    "gen_random_uuid 应可用（pgcrypto / PG >= 13）",
                    "确认 PostgreSQL 已加载 pgcrypto / 版本 >= 13", EXIT_ENV)
            }
            if (!rawImportSchema(db, report, repoRoot, adminId)) {
                return report  // rawImportSchema 已追加失败项
            }
            stepOk(report, "raw-import", "已 RAW 导入 sql/uctooDB.sql（占位符已替换）")
            ensureSuperAdmin(db, report, adminId, name, username, email, password)
            if (!report.ok) {
                return report
            }
        } else {
            stepOk(report, "raw-import", "uctoo_user 已存在，跳过 RAW 导入（幂等）")
            ensureSuperAdmin(db, report, "", name, username, email, password)
            if (!report.ok) {
                return report
            }
        }
    } finally {
        try { db.close() } catch (_: Exception) { () }
    }

    // ---- 5. applySeed 校验/补种（P0~P4）----
    let lp = loadExportPolicy(repoRoot)
    if (!lp.ok()) {
        for (e in lp.errors) { report.diagnostics.add(e) }
        // failureReport 返回的是**全新** Report，不带此前累积的 diagnostics，
        // 这里必须搬过去，否则报告里写着「见 diagnostics」而输出恒为空。
        let fr = failureReport("seed-init", "policy",
            "导出策略加载失败：${lp.errors.size} 条",
            "导出策略文件应可解析且通过校验",
            "修复 sql/seed/export-policy.json 与 sql/seed/sanitize-policy.json", EXIT_GENERIC)
        for (d in report.diagnostics) { fr.diagnostics.add(d) }
        return fr
    }
    let policy = match (lp.exportPolicy) { case Some(p) => p; case None => return report }
    let sqlPath = repoRoot.join("sql/uctooDB.sql")
    let imp: ImportReport = applySeed(conn, policy, sqlPath)
    for (e in imp.errors) { report.diagnostics.add("applySeed.error: ${e}") }
    for (n in imp.notes) { report.diagnostics.add("applySeed.note: ${n}") }
    let setup: IdentitySetup = imp.setup
    for (s in setup.steps) { report.diagnostics.add("identity.${s.code}: ${s.action} - ${s.detail}") }
    if (!imp.errors.isEmpty()) {
        // 同上：把已收集的 applySeed 错误/说明搬进新报告，否则「见 diagnostics」为空。
        let fr = failureReport("seed-init", "apply-seed",
            "applySeed 校验/补种失败：${imp.errors.size} 条错误",
            "applySeed 应校验通过且补种完成",
            "见 diagnostics", EXIT_GENERIC)
        for (d in report.diagnostics) { fr.diagnostics.add(d) }
        return fr
    }
    stepOk(report, "apply-seed", "applySeed 校验/补种通过（P0~P4，含主 agent 账号/实体/绑定）")
    reconcile(report)
    return report
}

// ===================== 步骤辅助（本包内，避免跨文件 private 依赖）=====================

func stepOk(r: Report, id: String, actual: String): Unit {
    let it = ReportItem()
    it.id = id
    it.status = STATUS_PASS
    it.actual = actual
    addStep(r, it)
}

func stepFail(r: Report, id: String, actual: String, expected: String, code: Int64): Unit {
    let it = ReportItem()
    it.id = id
    it.status = STATUS_FAIL
    it.actual = actual
    it.expected = expected
    it.code = code
    addItem(r, it)
}

/// 从 stdin 读取单行口令（prelude 的 readln 返回 String，行尾换行已 trim；EOF 返回空串）。
func readStdinPassword(): String {
    let s = readln()
    return s.trimAscii()
}

/// 连接目标库；失败返回 None。
func openDb(conn: DbConn): Option<Connection> {
    try {
        registerDriver()
        let ds = PgDatasource(conn.host, conn.port, conn.user, conn.password, conn.database,
            HashMap<String, String>())
        return Some(ds.connect())
    } catch (e: Exception) {
        return None<Connection>
    }
}

/// 确保目标库存在：先直连，失败再连 maintenance 库（postgres）建库。
func ensureDatabase(conn: DbConn): Bool {
    // 先试着直连目标库
    try {
        let ds = PgDatasource(conn.host, conn.port, conn.user, conn.password, conn.database,
            HashMap<String, String>())
        let c = ds.connect()
        try { c.close() } catch (_: Exception) { () }
        return true
    } catch (_: Exception) { () }
    // 再连 maintenance 库建库
    try {
        let mds = PgDatasource(conn.host, conn.port, conn.user, conn.password, "postgres",
            HashMap<String, String>())
        let c = mds.connect()
        try {
            var stmt: Option<Statement> = None<Statement>
            try {
                let s = c.prepareStatement("CREATE DATABASE \"" + conn.database + "\"")
                stmt = Some(s)
                s.update()
            } catch (_: Exception) { () }  // 已存在则忽略
            finally {
                match (stmt) {
                    case Some(s) => try { s.close() } catch (_: Exception) { () }
                    case None => ()
                }
            }
            return true
        } finally {
            try { c.close() } catch (_: Exception) { () }
        }
    } catch (e: Exception) {
        return false
    }
}

/// uctoo_user 是否已有数据行（表不存在 → 查询异常 → 视为空 → false）。
func tableHasRows(db: Connection, table: String): Bool {
    let n = localSeedQueryInt(db, "SELECT count(*) FROM \"" + table + "\"")
    return n > 0
}

/// RAW 导入 sql/uctooDB.sql：替换主体/纪元占位符后逐语句执行。
/// 占位符语义与 importer.cj 的 rewriteRow 保持一致：
///   {{principal:super_admin}} → adminId；{{ts:epoch}} → 确定性纪元字面量。
/// {{secret:}} / {{env:}} 原样保留（与 applySeed 行为一致）。
func rawImportSchema(db: Connection, report: Report, repoRoot: Path, adminId: String): Bool {
    let sqlPath = repoRoot.join("sql/uctooDB.sql")
    if (!exists(sqlPath)) {
        stepFail(report, "raw-import", "找不到种子 SQL：${sqlPath.toString()}",
            "确认 release 包含 sql/uctooDB.sql", EXIT_GENERIC)
        return false
    }
    let text = readFileText(sqlPath)
    let replaced = text.replace(SEED_INIT_PH_PRINCIPAL, adminId)
        .replace(SEED_INIT_PH_TS, SEED_INIT_TS_EPOCH)
    let stmts = splitSqlStatements(replaced)
    var fatal = false
    var executed = 0
    for (s in stmts) {
        let err = localSeedExec(db, s)
        if (!err.isEmpty()) {
            // 幂等容忍：已存在 / 重复键 视为提示，不阻断（CREATE IF NOT EXISTS + 重跑场景）。
            let benign = err.contains("already exists") || err.contains("duplicate") ||
                err.contains("23505") || err.contains("42P07") || err.contains("42710")
            if (!benign) {
                fatal = true
                if (report.diagnostics.size < 12) {
                    report.diagnostics.add("RAW 导入语句失败：${trimTo(s, 140)} :: ${trimTo(err, 220)}")
                }
            }
        } else {
            executed += 1
        }
    }
    if (fatal) {
        stepFail(report, "raw-import", "RAW 导入 sql/uctooDB.sql 遇到致命错误，已中止（已执行 ${executed} 条）",
            "见 diagnostics（多为表结构/权限/编码问题）", EXIT_GENERIC)
        return false
    }

    // 安全网（R5 兜底）：rawImportSchema 把 `{{ts:epoch}}` 全局还原成非空纪元字面量，
    // 若种子里某表的 deleted_at 列带了 `{{ts:epoch}}`（旧版导出/未治理的种子会有），
    // 该列会被落成 1970 纪元值 → 被列表默认视图（WHERE deleted_at IS NULL）当成
    // 「已软删除」整体隐藏。这里统一把等于纪元哨兵的 deleted_at 清零。
    // 注：本步在 raw 导入成功后才执行；个别表异常不阻断安装（仅记诊断）。
    let cleanupSql = "DO $$\n" +
        "DECLARE r RECORD;\n" +
        "BEGIN\n" +
        "  FOR r IN SELECT table_name FROM information_schema.columns\n" +
        "           WHERE table_schema='public' AND column_name='deleted_at' LOOP\n" +
        "    EXECUTE format('UPDATE %I SET deleted_at = NULL " +
        "WHERE deleted_at IS NOT DISTINCT FROM %L::timestamptz', r.table_name, '1970-01-01 00:00:00+00');\n" +
        "  END LOOP;\n" +
        "END $$;"
    let cleanupErr = localSeedExec(db, cleanupSql)
    if (!cleanupErr.isEmpty()) {
        report.diagnostics.add("deleted_at 安全网未完全执行（非致命）：${trimTo(cleanupErr, 200)}")
    } else {
        stepOk(report, "deleted_at-cleanup", "deleted_at 安全网：已清零残留纪元哨兵值")
    }
    return true
}

/// 建立（或复用）超管账号 + 绑定超管角色。
/// adminId 为空时（uctoo_user 已存在路径）改为查询既有账号 id。
func ensureSuperAdmin(db: Connection, report: Report, adminId: String, name: String,
                     username: String, email: String, password: String): Unit {
    // 已存在同名且绑定超管角色 → 复用
    let existing = localSeedQuery(db,
        "SELECT u.id::text FROM uctoo_user u " +
        "JOIN user_has_roles r ON r.user_id = u.id AND r.deleted_at IS NULL " +
        "WHERE r.role_id = ?::uuid AND u.username = ? AND u.deleted_at IS NULL LIMIT 1",
        p1: SEED_INIT_SUPER_ADMIN_ROLE, p2: username)
    if (!existing.isEmpty()) {
        stepOk(report, "super-admin", "超管账号 ${username} 已存在，复用（id=${existing}）")
        return
    }
    // 用户名已存在但未绑超管角色：拒绝覆盖既有账号
    let dupUser = localSeedQuery(db,
        "SELECT id::text FROM uctoo_user WHERE username = ? AND deleted_at IS NULL LIMIT 1", p1: username)
    if (!dupUser.isEmpty()) {
        stepFail(report, "super-admin",
            "用户名 ${username} 已存在但未绑定超管角色，拒绝覆盖既有账号",
            "换一个 --username，或手动为 ${dupUser} 绑定超管角色后重跑", EXIT_MANUAL)
        return
    }
    let useId = if (adminId.isEmpty()) { localSeedQuery(db, "SELECT gen_random_uuid()::text") } else { adminId }
    if (useId.isEmpty()) {
        stepFail(report, "super-admin", "无法生成超管 uuid", "确认 gen_random_uuid 可用", EXIT_ENV)
        return
    }
    let hashed = hashPassword(password)
    let err = localSeedExec(db,
        "INSERT INTO uctoo_user (id, name, username, email, password, user_type, auth_provider, " +
        "status, created_at, updated_at, last_login_time) " +
        "VALUES (?::uuid, ?, ?, ?, ?, 'human', 0, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        p1: useId, p2: name, p3: username, p4: email, p5: hashed)
    if (!err.isEmpty()) {
        stepFail(report, "super-admin", "写入超管账号失败：${err}",
            "核对 uctoo_user 表结构是否与安装器假定一致", EXIT_GENERIC)
        return
    }
    // 绑定超管角色（SELECT-first，幂等）
    let bound = localSeedQuery(db,
        "SELECT id::text FROM user_has_roles WHERE user_id = ?::uuid AND role_id = ?::uuid " +
        "AND deleted_at IS NULL LIMIT 1", p1: useId, p2: SEED_INIT_SUPER_ADMIN_ROLE)
    if (bound.isEmpty()) {
        let berr = localSeedExec(db,
            "INSERT INTO user_has_roles (user_id, role_id, status, creator, created_at, updated_at) " +
            "VALUES (?::uuid, ?::uuid, 1, ?::uuid, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",  // status=1：启用（hasWildcardPermission 要求 user_has_roles.status=1）
            p1: useId, p2: SEED_INIT_SUPER_ADMIN_ROLE, p3: useId)
        if (!berr.isEmpty()) {
            stepFail(report, "super-admin", "绑定超管角色失败：${berr}",
                "核对 user_has_roles 表结构", EXIT_GENERIC)
            return
        }
    }
    stepOk(report, "super-admin", "已建立超管账号 ${username}（id=${useId}）+ 绑定超管角色")
}

// ===================== 本地 SQL 小工具（rbac.cj 的同名函数为包私有，本包不可见）=====================

func localSeedQuery(db: Connection, sql: String, p1!: String = "", p2!: String = "",
                    p3!: String = "", p4!: String = ""): String {
    var stmt: Option<Statement> = None<Statement>
    var rs: Option<QueryResult> = None<QueryResult>
    try {
        let s = db.prepareStatement(sql)
        stmt = Some(s)
        localBind(s, p1, p2, p3, p4)
        let r = s.query()
        rs = Some(r)
        if (r.next()) {
            return match (r.getOrNull<String>(0)) {
                case Some(v) => v
                case None => ""
            }
        }
        return ""
    } catch (_: Exception) {
        return ""
    } finally {
        match (rs) {
            case Some(r) => try { r.close() } catch (_: Exception) { () }
            case None => ()
        }
        match (stmt) {
            case Some(s) => try { s.close() } catch (_: Exception) { () }
            case None => ()
        }
    }
}

func localSeedQueryInt(db: Connection, sql: String, p1!: String = "", p2!: String = ""): Int64 {
    let s = localSeedQuery(db, sql, p1: p1, p2: p2)
    try {
        return Int64.parse(s)
    } catch (_: Exception) {
        return 0
    }
}

func localSeedExec(db: Connection, sql: String, p1!: String = "", p2!: String = "",
                   p3!: String = "", p4!: String = "", p5!: String = ""): String {
    var stmt: Option<Statement> = None<Statement>
    try {
        let s = db.prepareStatement(sql)
        stmt = Some(s)
        localBind(s, p1, p2, p3, p4, p5: p5)
        s.update()
        return ""
    } catch (e: Exception) {
        return e.message
    } finally {
        match (stmt) {
            case Some(s) => try { s.close() } catch (_: Exception) { () }
            case None => ()
        }
    }
}

/// 按非空参数顺序绑定（与 rbac.cj seedBindParams 同语义；本场景值均非空，零值跳过是安全的）。
func localBind(stmt: Statement, p1: String, p2: String, p3: String, p4: String, p5!: String = ""): Unit {
    var idx = 0
    if (!p1.isEmpty()) { stmt.set<String>(idx, p1); idx += 1 }
    if (!p2.isEmpty()) { stmt.set<String>(idx, p2); idx += 1 }
    if (!p3.isEmpty()) { stmt.set<String>(idx, p3); idx += 1 }
    if (!p4.isEmpty()) { stmt.set<String>(idx, p4); idx += 1 }
    if (!p5.isEmpty()) { stmt.set<String>(idx, p5); idx += 1 }
}

/// 截断到 n 个字符（Rune 维度），用于诊断输出。
func trimTo(s: String, n: Int64): String {
    let r = s.toRuneArray()
    if (r.size <= n) { return s }
    var sb = StringBuilder()
    var i = 0
    while (i < n) { sb.append(r[i]); i += 1 }
    return sb.toString() + "..."
}

/// 引号 / 注释感知地按顶层 `;` 切分 SQL（移植自 db_export.cj 的 splitStatements，改名以避免同包重名）。
func splitSqlStatements(text: String): ArrayList<String> {
    let out = ArrayList<String>()
    let buf = text.toRuneArray()
    let n = buf.size
    var i = 0
    var cur = StringBuilder()
    var inSingle = false
    var inDouble = false
    var inLineComment = false
    var inBlockComment = false
    while (i < n) {
        let c = buf[i]
        if (inLineComment) {
            if (c == r'\n') { inLineComment = false }
            i += 1
            continue
        }
        if (inBlockComment) {
            if (c == r'*' && i + 1 < n && buf[i + 1] == r'/') {
                inBlockComment = false
                i += 2
                continue
            }
            i += 1
            continue
        }
        if (c == r'\'') { inSingle = !inSingle; cur.append(c); i += 1; continue }
        if (c == r'"') { inDouble = !inDouble; cur.append(c); i += 1; continue }
        if (!inSingle && !inDouble) {
            if (c == r'-' && i + 1 < n && buf[i + 1] == r'-') { inLineComment = true; i += 2; continue }
            if (c == r'/' && i + 1 < n && buf[i + 1] == r'*') { inBlockComment = true; i += 2; continue }
            if (c == r';') {
                let stmt = cur.toString().trimAscii()
                if (!stmt.isEmpty()) { out.add(stmt) }
                cur = StringBuilder()
                i += 1
                continue
            }
        }
        cur.append(c)
        i += 1
    }
    let last = cur.toString().trimAscii()
    if (!last.isEmpty()) { out.add(last) }
    return out
}
