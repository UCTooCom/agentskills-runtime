package uc_installer.services.seed

// ============================================================================
// Seed 导入器（任务 T046，design.md §4.10.5(2)(3)、§4.10.6(5)、
// research-seed-identity.md §3.3 的 P1 / P2）。
//
// 对应 REQ-RNI-081~084 / 102；AC-197~207、253~255。
//
// 流水线（P0 由 rbac.cj 提供）：
//   P1 结构与非身份数据导入：引号感知扫描（复用 T040），DDL 逐条执行
//   P2 身份重绑定：**字符串级**替换，零 UPDATE
//        {{principal:<ref>}} → 目标环境 uctoo_user.id
//        {{agent:<ref>}}     → 目标环境 agents.id
//        {{secret:…}} / {{env:…}}  **绝不解析、绝不猜值**，原样入库（AC-254）
//        {{ts:epoch}}       → 1970-01-01 00:00:00+00（确定性纪元值，见 TS_EPOCH_LITERAL）；
//                                    软删除标记列（deleted_at）例外——落成 SQL NULL，避免种子行被当成已删除。
//        裸 uuid 落在身份列 → 孤儿，按 orphanDefault 处置（默认 fail）
//
// 为什么是字符串级替换而不是导入后 UPDATE：一次扫描完成，不产生几百次 UPDATE；
// 失败时库里不留"插进去了但没重绑定"的半截数据（AC-205）。
//
// 红线：
//   - 安装器/运行时生成的表（uctoo_user / user_has_roles / user_has_group / agents）
//     与同步派生表（db_connection / db_info）**不导入数据行**——agent_skills 现已改为
//     bootstrap 档（完整保留种子数据），会正常导入数据行。
//     前者的归属由 rbac.cj 按 A1~A6 建立，塞进去会造成重复账号（AC-215/216）；
//   - 重复执行幂等：已有数据的表整体跳过并报告「复用」（AC-197）；
//   - 全流程包在一个事务里，任一步失败即 ROLLBACK（AC-205）。
// ============================================================================

import std.fs.{Path, exists}
import std.collection.{ArrayList, HashMap}
import std.core.StringBuilder
import std.database.sql.Connection
import uc_installer.services.DbConn

/// 占位符形态（两套正交命名空间，design §4.10.6(5)）。
let PH_PRINCIPAL = "{{principal:"
let PH_AGENT = "{{agent:"
let PH_SECRET = "{{secret:"
let PH_ENV = "{{env:"
let PH_TS = "{{ts:"
let PH_SUFFIX = "}}"

/// `{{ts:epoch}}` 的落地值：Unix 纪元。
///
/// 导出期把具体时间戳**归一**成固定哨兵（sanitizer R2），目的是让同库两次导出的字节完全一致；
/// 因此导入期必须还原成一个**确定性**的值，而不能用 CURRENT_TIMESTAMP —— 后者会让每次安装
/// 产出的种子数据都不同，破坏"种子可复现"这个前提。
/// "epoch" 的字面含义即 Unix 纪元，故取 1970-01-01 00:00:00+00。
///
/// 例外：软删除标记列（deleted_at）不落成纪元值，而是在 rewriteRow 中特判为 SQL NULL，
/// 否则种子行会被列表默认视图（WHERE deleted_at IS NULL）误判为「已删除」而整体隐藏。
let TS_EPOCH_LITERAL = "1970-01-01 00:00:00+00"

// ===================== 数据模型 =====================

/// 导入结果（AC-201：结构化报告，逐项可见）。
public class ImportReport {
    public var sqlPath: String = ""
    /// 扫描到的顶层语句数 / INSERT 语句数（与扫描器对账）。
    public var statementCount: Int64 = 0
    public var insertCount: Int64 = 0
    /// 已执行的结构语句数（DDL / COMMENT / 约束）。
    public var ddlStatements: Int64 = 0
    /// 已执行的 INSERT 语句数 / 写入行数。
    public var insertStatements: Int64 = 0
    public var rowsInserted: Int64 = 0
    /// 被身份重绑定的单元格数。
    public var reboundCells: Int64 = 0
    /// 原样保留的脱敏占位符（{{secret}} / {{env}}）个数（AC-254）。
    public var keptPlaceholders: Int64 = 0
    /// 由 `{{ts:epoch}}` 还原出的时间戳单元格数（导出期归一 · 导入期还原为确定性纪元值）。
    public var timestampCells: Int64 = 0
    /// 被孤儿策略丢弃的行数。
    public var droppedRows: Int64 = 0
    /// 跳过的表（安装器/运行时生成或同步派生）。
    public var skippedTables: ArrayList<String> = ArrayList<String>()
    /// 已有数据、本轮复用的表（AC-197）。
    public var reusedTables: ArrayList<String> = ArrayList<String>()
    /// 「表.列」重绑定计数（保持首次出现顺序）。
    public var reboundKeys: ArrayList<String> = ArrayList<String>()
    public var reboundCounts: HashMap<String, Int64> = HashMap<String, Int64>()
    /// 孤儿逐条记录（无论哪种策略都必须可见）。
    public var orphans: ArrayList<String> = ArrayList<String>()
    /// 主体解析结果逐条（AC-201：各主体解析结果与其标识来源）。
    public var principals: ArrayList<String> = ArrayList<String>()
    /// 非致命提示（如"约束已存在"）。
    public var notes: ArrayList<String> = ArrayList<String>()
    public var errors: ArrayList<String> = ArrayList<String>()
    /// P0 建号结果（含主 agent 随机口令，供 CLI 一次性展示）。
    public var setup: IdentitySetup = IdentitySetup()

    public func ok(): Bool {
        return errors.isEmpty()
    }

    /// 「表.列 = N」的逐行文本（供报告）。
    public func reboundLines(): ArrayList<String> {
        let out = ArrayList<String>()
        for (k in reboundKeys) {
            let n = match (reboundCounts.get(k)) {
                case Some(v) => v
                case None => 0
            }
            out.add("${k} = ${n}")
        }
        return out
    }
}

/// 占位符解析表：`ref → 目标环境 uuid`。
class RefTable {
    /// `{{principal:<ref>}}` → uctoo_user.id
    let principalByRef: HashMap<String, String> = HashMap<String, String>()
    /// `{{agent:<ref>}}` → agents.id
    let agentByRef: HashMap<String, String> = HashMap<String, String>()
}

/// 导入期收集器：承载扫描回调的全部状态。
///
/// 用 class 而非局部 `var`：仓颉禁止「捕获局部 var 的闭包逃逸」，而
/// `scanSqlFile` 的两个回调正是作为参数传出去的（先例 scanner.cj:1160）。
class ImportSink {
    let rep: ImportReport
    let db: Connection
    let policy: ExportPolicy
    let refs: RefTable
    let dryRun: Bool
    /// 表名 → 列序（information_schema 自省结果，首次用到时缓存）。
    let colCache: HashMap<String, ArrayList<String>> = HashMap<String, ArrayList<String>>()
    /// 表名 → 是否已有数据（幂等复用判据）。
    let hasRowsCache: HashMap<String, Bool> = HashMap<String, Bool>()
    /// 已判定跳过的表（避免在报告里重复出现）。
    let skipped: ArrayList<String> = ArrayList<String>()
    /// 出现致命错误后立即停止后续写入（等待回滚）。
    var fatal: Bool = false
    /// 进度日志节流：累计执行语句数达到该阈值才再印一条 stderr 心跳（eprintln 默认 flush）。
    var lastLog: Int64 = 0

    init(rep: ImportReport, db: Connection, policy: ExportPolicy, refs: RefTable, dryRun: Bool) {
        this.rep = rep
        this.db = db
        this.policy = policy
        this.refs = refs
        this.dryRun = dryRun
    }
}

// ===================== 对外入口 =====================

/// 把 `sqlPath` 指向的 seed 导入目标库（P0~P2）。
///
/// `dryRun = true` 时只做解析与重写，不写库（供人工审阅重绑定账）。
public func applySeed(conn: DbConn, policy: ExportPolicy, sqlPath: Path,
                      dryRun!: Bool = false): ImportReport {
    let rep = ImportReport()
    rep.sqlPath = sqlPath.toString()
    if (!exists(sqlPath)) {
        rep.errors.add("seed SQL 不存在：${sqlPath.toString()}")
        return rep
    }

    // ---- P0 解析主体标识（rbac.cj）----
    let setup = ensureSeedIdentities(conn, policy)
    rep.setup = setup
    for (s in setup.steps) {
        rep.principals.add("${s.code}(${s.action}) ${s.detail}")
    }
    for (e in setup.errors) {
        rep.errors.add(e)
    }
    if (!setup.ok()) {
        return rep
    }

    let dbOpt = try {
        Some(openSeedConn(conn))
    } catch (e: Exception) {
        rep.errors.add("无法连接数据库 ${conn.database}：${e.message}")
        None<Connection>
    }
    let db = match (dbOpt) {
        case Some(c) => c
        case None => return rep
    }
    try {
        runImport(db, policy, sqlPath, setup, rep, dryRun)
    } finally {
        try {
            db.close()
        } catch (_: Exception) {
            ()
        }
    }
    return rep
}

// ===================== 导入流水线 =====================

func runImport(db: Connection, policy: ExportPolicy, sqlPath: Path,
               setup: IdentitySetup, rep: ImportReport, dryRun: Bool): Unit {
    let refs = RefTable()
    buildRefTable(db, policy, setup, refs, rep)
    if (!rep.errors.isEmpty()) {
        return
    }

    let sink = ImportSink(rep, db, policy, refs, dryRun)

    // 事务：任一步失败即回滚，库中不留半截数据（AC-205）。
    if (!dryRun) {
        let begErr = seedExec(db, "BEGIN")
        if (!begErr.isEmpty()) {
            rep.notes.add("无法开启事务（退化为逐语句执行，失败时不回滚）：${begErr}")
        }
    }

    var scanErr = ""
    try {
        // 回调必须是「不捕获局部 var」的形态：这里只捕获 sink（let 绑定），
        // 参数不加括号（先例 guards.cj:177）。
        let onIns = { ins: InsertStatement => importInsert(sink, ins) }
        let onOth = { s: String => importOther(sink, s) }
        let scan = scanSqlFile(sqlPath, onIns, onOth)
        rep.statementCount = scan.statementCount
        rep.insertCount = scan.insertCount
    } catch (e: SqlScanError) {
        scanErr = e.message
    } catch (e2: Exception) {
        scanErr = e2.message
    }

    if (!scanErr.isEmpty()) {
        rep.errors.add("SQL 扫描失败：${scanErr}")
    }
    if (scanErr.isEmpty() && rep.errors.isEmpty()) {
        if (!dryRun) {
            let cmErr = seedExec(db, "COMMIT")
            if (!cmErr.isEmpty()) {
                rep.errors.add("提交事务失败：${cmErr}")
            }
        }
        return
    }
    if (!dryRun) {
        let rbErr = seedExec(db, "ROLLBACK")
        if (!rbErr.isEmpty()) {
            rep.notes.add("回滚失败（请人工检查库中是否残留本轮数据）：${rbErr}")
        }
    }
}

/// P0 续：把策略声明的主体解析成「ref → 目标 uuid」。
func buildRefTable(db: Connection, policy: ExportPolicy, setup: IdentitySetup,
                   refs: RefTable, rep: ImportReport): Unit {
    for (p in policy.principals) {
        var id = ""
        if (p.ref == "super_admin" || p.kind == "super_admin") {
            id = setup.superAdminId
        } else if (!p.username.isEmpty()) {
            id = seedQuery(db,
                "SELECT id::text FROM \"${policy.principalTable}\" " +
                "WHERE username = ? AND deleted_at IS NULL LIMIT 1", p1: p.username)
            if (id.isEmpty()) {
                rep.errors.add("主体 ${p.ref}（username=${p.username}）在目标库中不存在；" +
                    "导入不得为使其通过而创建账号（AC-216）")
            }
        } else {
            rep.errors.add("主体 ${p.ref} 既不是 super_admin 也未声明 username，无法解析")
        }
        if (!id.isEmpty()) {
            refs.principalByRef.add(p.ref, id)
            rep.principals.add("{{principal:${p.ref}}} → ${id}")
        }
    }
    // agent 命名空间：当前只有 main（design §4.10.5(3)）。
    refs.agentByRef.add("main", setup.agentId)
    rep.principals.add("{{agent:main}} → ${setup.agentId}")
}

/// 在事务内**带保存点**地执行一条语句：失败即回滚到保存点，事务保持可用。
///
/// 为什么必须有这一层（2026-10-24 实测事故，改动前请务必读完）：
/// `runImport` 会先 `BEGIN` 开事务，而 `importOther` 对「约束/索引已存在」这类
/// **可容忍**的失败只记一条 note 就继续。但 PostgreSQL 的规则是：
/// **事务内任意一条语句失败后，整个事务立即进入 aborted 状态**，此后任何语句都返回
/// `current transaction is aborted, commands ignored until end of transaction block`
/// （SQLSTATE 25P02）。
///
/// 于是第一条因对象已存在而失败的 DDL（42P07）就把**后面所有语句全部毒化**：
/// 首个 INSERT 以 25P02 报错 ⇒ applySeed 报「1 条错误」⇒ seed-init 退出码 1
/// ⇒ PC 客户端首次运行设置页建号失败。而真正的元凶只躺在一条 note 里，极难定位。
///
/// 修法：每条语句套一个 SAVEPOINT，失败即 ROLLBACK TO SAVEPOINT，事务保持可用。
/// 若 SAVEPOINT 本身不可用（BEGIN 失败、退化为自动提交），则退回原文执行。
func execWithSavepoint(db: Connection, sql: String, sp: String): String {
    let spErr = seedExec(db, "SAVEPOINT ${sp}")
    if (!spErr.isEmpty()) {
        return seedExec(db, sql)
    }
    let err = seedExec(db, sql)
    if (err.isEmpty()) {
        seedExec(db, "RELEASE SAVEPOINT ${sp}")
        return ""
    }
    let rbErr = seedExec(db, "ROLLBACK TO SAVEPOINT ${sp}")
    if (!rbErr.isEmpty()) {
        // 连回滚都失败 ⇒ 事务已不可救，如实回传原始错误交由上层决策
        return err
    }
    seedExec(db, "RELEASE SAVEPOINT ${sp}")
    return err
}

/// 非 INSERT 语句（DDL / COMMENT / 约束 / 索引）：原文执行。
///
/// ⚠️ 必须走 `execWithSavepoint` 而不是裸 `seedExec`：本函数运行在 `runImport`
/// 开启的事务里，而它对「已存在」这类失败是**记 note 继续**的，裸执行会让
/// 一条失败把整个事务毒化（详见 execWithSavepoint 的注释）。
func importOther(sink: ImportSink, text: String): Unit {
    if (sink.fatal) {
        return
    }
    if (text.trimAscii().isEmpty()) {
        return
    }
    if (sink.dryRun) {
        sink.rep.ddlStatements += 1
        return
    }
    let err = execWithSavepoint(sink.db, text, "sp_seed_ddl")
    if (err.isEmpty()) {
        sink.rep.ddlStatements += 1
        logSeedProgress(sink)
        return
    }
    // 重复导入时约束/索引已存在属正常：记为提示，不判失败（否则幂等性不成立）。
    sink.rep.notes.add("结构语句未执行（多半已存在）：${trimTo(text, 80)} :: ${trimTo(err, 120)}")
}

/// 单条 INSERT：跳过生成表 → 幂等复用 → 逐单元格重绑定 → 落库。
func importInsert(sink: ImportSink, ins: InsertStatement): Unit {
    if (sink.fatal) {
        return
    }
    let rep = sink.rep
    if (isGeneratedTable(sink.policy, ins.table)) {
        if (!sink.skipped.contains(ins.table)) {
            sink.skipped.add(ins.table)
            rep.skippedTables.add("${ins.table}（安装器/运行时生成或同步派生，导入侧不写数据行）")
        }
        return
    }
    if (tableHasRows(sink, ins.table)) {
        if (!rep.reusedTables.contains(ins.table)) {
            rep.reusedTables.add(ins.table)
        }
        return
    }

    let schemaCols = columnsOf(sink, ins.table)
    let rows = ArrayList<ArrayList<SqlCell>>()
    for (row in ins.rows) {
        match (rewriteRow(sink, ins, schemaCols, row)) {
            case Some(r) => rows.add(r)
            case None => rep.droppedRows += 1
        }
    }
    if (!rep.errors.isEmpty()) {
        sink.fatal = true
        return
    }
    if (rows.size == 0) {
        return
    }
    rep.insertStatements += 1
    rep.rowsInserted += rows.size
    logSeedProgress(sink)
    if (sink.dryRun) {
        return
    }
    let sql = buildInsertSql(ins.table, ins.columns, rows)
    let err = seedExec(sink.db, sql)
    if (!err.isEmpty()) {
        rep.errors.add("写入表 ${ins.table} 失败：${trimTo(err, 200)}（语句：${trimTo(sql, 120)}）")
        sink.fatal = true
    }
}

/// 节流式 stderr 进度心跳：每累计 100 条已执行语句打印一次。
///
/// 走 `eprintln`（默认 flush:true，不进 stdout 事件流），让宿主/日志在**长导入过程中**
/// 也能看到真实进展，而不是只有最后回放的 step 事件。若导入再次卡住，这里的时间戳
/// 能直接定位卡在哪一段（与 progress.cj 的「step 事件回放」限制互补）。
func logSeedProgress(sink: ImportSink): Unit {
    let total = sink.rep.ddlStatements + sink.rep.insertStatements
    if (total - sink.lastLog >= 100) {
        sink.lastLog = total
        eprintln("seed-import 进度：已执行 ${total} 条语句" +
            "（DDL ${sink.rep.ddlStatements} / INSERT ${sink.rep.insertStatements}，" +
            "已写 ${sink.rep.rowsInserted} 行）")
    }
}

/// 逐单元格重写。返回 None 表示该行被孤儿策略丢弃。
func rewriteRow(sink: ImportSink, ins: InsertStatement, schemaCols: ArrayList<String>,
                row: ArrayList<SqlCell>): Option<ArrayList<SqlCell>> {
    let out = ArrayList<SqlCell>()
    for (i in 0..row.size) {
        let cell = row[i]
        let col = columnNameAt(ins, schemaCols, i)
        let text = match (cell.text) {
            case Some(v) => v
            case None => ""
        }
        let isQuoted = match (cell.kind) {
            case LiteralKind.Quoted => true
            case _ => false
        }
        if (isQuoted && !text.isEmpty()) {
            // ① 身份占位符：解析为目标环境 uuid
            if (text.startsWith(PH_PRINCIPAL) && text.endsWith(PH_SUFFIX)) {
                let ref = innerRef(text, PH_PRINCIPAL)
                let id = match (sink.refs.principalByRef.get(ref)) {
                    case Some(v) => v
                    case None => ""
                }
                if (id.isEmpty()) {
                    sink.rep.errors.add("未解析的身份占位符 ${text}（${ins.table}.${col}）：" +
                        "主体 ${ref} 不在解析表中（AC-202：有未解析引用即不得报成功）")
                    return None<ArrayList<SqlCell>>
                }
                out.add(SqlCell(Some(id), LiteralKind.Quoted, id))
                countRebind(sink, ins.table, col)
                continue
            }
            if (text.startsWith(PH_AGENT) && text.endsWith(PH_SUFFIX)) {
                let ref = innerRef(text, PH_AGENT)
                let id = match (sink.refs.agentByRef.get(ref)) {
                    case Some(v) => v
                    case None => ""
                }
                if (id.isEmpty()) {
                    sink.rep.errors.add("未解析的智能体占位符 ${text}（${ins.table}.${col}）：" +
                        "agent 命名空间只有 main（解析到 agents.id，不是 uctoo_user.id）")
                    return None<ArrayList<SqlCell>>
                }
                out.add(SqlCell(Some(id), LiteralKind.Quoted, id))
                countRebind(sink, ins.table, col)
                continue
            }
            // ② 脱敏占位符：铁律——绝不解析、绝不猜值（AC-254）
            if (text.startsWith(PH_SECRET) || text.startsWith(PH_ENV)) {
                sink.rep.keptPlaceholders += 1
                out.add(cell)
                continue
            }
            // ②′ 时间戳哨兵：导出期归一为 `{{ts:epoch}}`，导入期还原为**确定性**纪元值。
            //     不猜测"原来是什么时间"，只把哨兵落成合法的 timestamptz 字面量。
            if (text.startsWith(PH_TS)) {
                let kind = innerRef(text, PH_TS)
                if (kind != "epoch") {
                    sink.rep.errors.add("未知的时间戳占位符 ${text}（${ins.table}.${col}）：" +
                        "当前只识别 {{ts:epoch}}")
                    return None<ArrayList<SqlCell>>
                }
                // 软删除标记列（deleted_at）特判：种子行必须是「活动态」，落成 SQL NULL，
                // 绝不写成 epoch 0 字面量——否则会被列表默认视图（WHERE deleted_at IS NULL）
                // 当成「已软删除」而整体隐藏，导致种子数据在 CRUD 界面不可见。
                if (isSoftDeleteColumn(col)) {
                    out.add(SqlCell(None<String>, LiteralKind.SqlNull, "NULL"))
                    continue
                }
                sink.rep.timestampCells += 1
                out.add(SqlCell(Some(TS_EPOCH_LITERAL), LiteralKind.Quoted, TS_EPOCH_LITERAL))
                continue
            }
            // ③ 身份列上的裸 uuid → 孤儿
            if (isIdentityColumn(sink.policy, col) && looksLikeUuid(text)) {
                let (act, val) = orphanDecision(sink, ins.table, col, text)
                if (act == "replace") {
                    out.add(SqlCell(Some(val), LiteralKind.Quoted, val))
                    countRebind(sink, ins.table, col)
                    continue
                }
                // drop / fail：两者都不写本行（fail 时 errors 非空，调用方会中止）
                return None<ArrayList<SqlCell>>
            }
        }
        out.add(cell)
    }
    return Some(out)
}

/// 软删除标记列判定：种子数据不应携带「已删除」语义，导入期须落成 SQL NULL。
private func isSoftDeleteColumn(col: String): Bool {
    let c = col.toAsciiLower()
    return c == "deleted_at" || c == "deletedat"
}

/// 孤儿处置三选一（默认 fail）。
///
/// 返回 `(处置, 值)`：处置 ∈ `replace` / `drop` / `fail`。
func orphanDecision(sink: ImportSink, table: String, col: String, uuid: String): (String, String) {
    // ① 清单显式覆盖：按 uuid + 可选「表.列」作用域命中
    for (ov in sink.policy.orphanOverrides) {
        if (ov.uuid != uuid) {
            continue
        }
        if (!ov.scope.isEmpty() && ov.scope != "${table}.${col}") {
            continue
        }
        let id = match (sink.refs.principalByRef.get(ov.to)) {
            case Some(v) => v
            case None => ""
        }
        if (!id.isEmpty()) {
            sink.rep.orphans.add("${table}.${col} = ${uuid} → {{principal:${ov.to}}}（${ov.reason}）")
            return ("replace", id)
        }
    }
    let hit = "${table}.${col} = ${uuid}"
    let isDrop = match (sink.policy.orphanDefault) {
        case OrphanPolicy.Drop => true
        case _ => false
    }
    let isMap = match (sink.policy.orphanDefault) {
        case OrphanPolicy.MapTo => true
        case _ => false
    }
    if (isDrop) {
        sink.rep.orphans.add("${hit} → 整行丢弃（orphanDefault=drop）")
        return ("drop", "")
    }
    if (isMap) {
        let id = match (sink.refs.principalByRef.get("super_admin")) {
            case Some(v) => v
            case None => ""
        }
        if (!id.isEmpty()) {
            sink.rep.orphans.add("${hit} → 归位超管（orphanDefault=map-to）")
            return ("replace", id)
        }
    }
    sink.rep.errors.add("孤儿身份引用 ${hit}：orphanDefault=fail，导入失败" +
        "（加 orphanOverrides 或把 orphanDefault 改为 drop / map-to 后重跑）")
    sink.rep.orphans.add("${hit} → fail")
    return ("fail", "")
}

// ===================== 小工具 =====================

/// 安装器/运行时生成表与同步派生表不写数据行。
func isGeneratedTable(policy: ExportPolicy, table: String): Bool {
    if (policy.installerGenerated.contains(table)) {
        return true
    }
    if (policy.syncDerived.contains(table)) {
        return true
    }
    return false
}

/// 身份列判定：列名属于策略声明的 principal 或 agent 列集合。
func isIdentityColumn(policy: ExportPolicy, col: String): Bool {
    if (col.isEmpty()) {
        return false
    }
    if (policy.principalColumns.contains(col)) {
        return true
    }
    if (policy.agentColumns.contains(col)) {
        return true
    }
    return false
}

/// 取第 i 个单元格对应的列名：优先用语句自带的列清单，否则按 DDL 列序（ordinal）。
func columnNameAt(ins: InsertStatement, schemaCols: ArrayList<String>, i: Int64): String {
    if (ins.columns.size > 0) {
        return if (i < ins.columns.size) { ins.columns[i] } else { "" }
    }
    return if (i < schemaCols.size) { schemaCols[i] } else { "" }
}

/// 表列序缓存（information_schema，按 ordinal_position）。
func columnsOf(sink: ImportSink, table: String): ArrayList<String> {
    match (sink.colCache.get(table)) {
        case Some(c) => return c
        case None => ()
    }
    let cols = seedQueryList(sink.db,
        "SELECT column_name FROM information_schema.columns " +
        "WHERE table_schema = 'public' AND table_name = ? ORDER BY ordinal_position",
        p1: table)
    sink.colCache.add(table, cols)
    return cols
}

/// 幂等判据：表里已有数据 → 本轮跳过并报告「复用」（AC-197）。
func tableHasRows(sink: ImportSink, table: String): Bool {
    match (sink.hasRowsCache.get(table)) {
        case Some(b) => return b
        case None => ()
    }
    let n = seedQueryInt(sink.db, "SELECT count(*) FROM \"public\".\"${table}\"")
    let b = n > 0
    sink.hasRowsCache.add(table, b)
    return b
}

/// 记录一次重绑定（按「表.列」计数）。
func countRebind(sink: ImportSink, table: String, col: String): Unit {
    let key = "${table}.${col}"
    sink.rep.reboundCells += 1
    match (sink.rep.reboundCounts.get(key)) {
        case Some(n) => sink.rep.reboundCounts.add(key, n + 1)
        case None =>
            sink.rep.reboundCounts.add(key, 1)
            sink.rep.reboundKeys.add(key)
    }
}

/// 从占位符文本里取出 `<ref>`。
func innerRef(text: String, prefix: String): String {
    return text.replace(prefix, "").replace(PH_SUFFIX, "")
}

/// 用重写后的单元格重建 INSERT（与 scanner 的 `cellToSql` 严格互逆）。
func buildInsertSql(table: String, cols: ArrayList<String>,
                    rows: ArrayList<ArrayList<SqlCell>>): String {
    let sb = StringBuilder()
    sb.append("INSERT INTO \"public\".\"")
    sb.append(table)
    sb.append("\"")
    if (cols.size > 0) {
        sb.append(" (")
        for (i in 0..cols.size) {
            if (i > 0) {
                sb.append(", ")
            }
            sb.append("\"")
            sb.append(cols[i])
            sb.append("\"")
        }
        sb.append(")")
    }
    sb.append(" VALUES ")
    for (r in 0..rows.size) {
        if (r > 0) {
            sb.append(", ")
        }
        sb.append("(")
        let row = rows[r]
        for (i in 0..row.size) {
            if (i > 0) {
                sb.append(", ")
            }
            sb.append(cellToSql(row[i]))
        }
        sb.append(")")
    }
    return sb.toString()
}

/// 截断到 n 个字符（按字符而非字节，避免把中文切成半个）。
func trimTo(s: String, n: Int64): String {
    let r = s.toRuneArray()
    if (r.size <= n) {
        return s
    }
    let sb = StringBuilder()
    var i = 0
    while (i < n) {
        sb.append(r[i])
        i += 1
    }
    sb.append("…")
    return sb.toString()
}
