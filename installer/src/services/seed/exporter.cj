package uc_installer.services.seed

// ============================================================================
// 分层导出器（任务 T041，design.md §4.10.5(4)(5) E0~E3）。
//
// 对应 REQ-RNI-092~094 / 098；AC-220~223、240~242。
//
// 职责：连接活的 `uctoo` 库，按导出策略把表分成几档，产出
// `sql/uctooDB.sql`：
//   - T-A 结构：全部表的 `CREATE TABLE IF NOT EXISTS` + COMMENT + PK/UK/索引
//   - T-B 引导数据：带行级谓词（如 `config` 仅 `env_key IS NULL`）
//   - T-C 示例数据：限行数
//   - T-D / T-D′ / T-E / T-F：只导结构、不导数据行
//
// 两条硬性质：
//   - **白名单优先、默认拒绝**：未在策略显式批准的表一律 `StructureOnly`（只结构）。
//   - **确定性**：数据行 `ORDER BY` 主键（或 sample 的 orderBy），时间戳只落文件头，
//     使两次导出 diff 为空，产物可进 git。
// ============================================================================

import pgsql.{PgDatasource, registerDriver}
import std.database.sql.{Connection, Statement, QueryResult}
import std.collection.{ArrayList, HashMap}
import std.core.StringBuilder
import std.fs.{Path, File, OpenMode}
import std.time.DateTime
import uc_installer.services.DbConn

// ===================== 内部数据模型 =====================

/// 列定义（来自 information_schema 自省）。
private struct ColumnDef {
    let name: String
    /// 已映射成可落盘的类型串，如 `varchar(255)` / `integer` / `timestamptz`。
    let sqlType: String
    let nullable: Bool
    /// 列默认表达式（`column_default` 的原文，已是合法 SQL 文本）；None = 无 DEFAULT。
    let defaultExpr: Option<String>
    /// 列注释（可能为空串）。
    let comment: String

    init(name!: String, sqlType!: String, nullable!: Bool, defaultExpr!: Option<String>, comment!: String) {
        this.name = name
        this.sqlType = sqlType
        this.nullable = nullable
        this.defaultExpr = defaultExpr
        this.comment = comment
    }
}

/// 一个索引（唯一或非唯一）的定义。
private struct IndexDef {
    let name: String
    let columns: ArrayList<String>

    init(name!: String, columns!: ArrayList<String>) {
        this.name = name
        this.columns = columns
    }
}

/// 单表自省结果。
private struct TableSchema {
    let name: String
    let columns: ArrayList<ColumnDef>
    let pkColumns: ArrayList<String>
    let uniqueIndexes: ArrayList<IndexDef>
    let indexes: ArrayList<IndexDef>
    let comment: String

    init(name!: String, columns!: ArrayList<ColumnDef>, pkColumns!: ArrayList<String>,
         uniqueIndexes!: ArrayList<IndexDef>, indexes!: ArrayList<IndexDef>, comment!: String) {
        this.name = name
        this.columns = columns
        this.pkColumns = pkColumns
        this.uniqueIndexes = uniqueIndexes
        this.indexes = indexes
        this.comment = comment
    }
}

/// 单表导出统计（供报告）。
public struct ExportTableStat {
    public let table: String
    public let tier: String
    public let kind: String
    public let columns: Int64
    public let rows: Int64
    public let bytes: Int64
    /// 被孤儿策略丢弃的行数（orphanDefault=drop）。
    public let dropped: Int64
    /// 被身份匿名化替换的单元格数（Replaced）。
    public let anonymized: Int64
    /// 被脱敏器命中（R1/R2/R3，非 None）的单元格数。
    public let sanitized: Int64

    public init(table!: String, tier!: String, kind!: String, columns!: Int64, rows!: Int64,
                bytes!: Int64, dropped!: Int64, anonymized!: Int64, sanitized!: Int64) {
        this.table = table
        this.tier = tier
        this.kind = kind
        this.columns = columns
        this.rows = rows
        this.bytes = bytes
        this.dropped = dropped
        this.anonymized = anonymized
        this.sanitized = sanitized
    }
}

/// 导出总报告（供 E6 报告与 T045 CLI 汇总）。
public struct ExportReport {
    public let generatedAt: String
    public let structureTables: Int64
    public let dataTables: Int64
    public let insertCount: Int64
    public let rowCount: Int64
    public let bytes: Int64
    public let perTable: ArrayList<ExportTableStat>

    public init(generatedAt!: String, structureTables!: Int64, dataTables!: Int64,
                insertCount!: Int64, rowCount!: Int64, bytes!: Int64,
                perTable!: ArrayList<ExportTableStat>) {
        this.generatedAt = generatedAt
        this.structureTables = structureTables
        this.dataTables = dataTables
        this.insertCount = insertCount
        this.rowCount = rowCount
        this.bytes = bytes
        this.perTable = perTable
    }
}

/// 导出结果：成功带报告，失败带原因（不抛异常，便于一次性改完）。
public struct ExportResult {
    public let report: Option<ExportReport>
    public let errors: ArrayList<String>

    public init(report!: Option<ExportReport>, errors!: ArrayList<String>) {
        this.report = report
        this.errors = errors
    }
}

/// `exportTableData` 的内部返回：除计数外，携带"孤儿 fail 致命错误"信号，
/// 让 `exportSeed` 能在整表循环里中断并把错误带回（不靠异常跨越多层）。
private struct TableExportOutcome {
    let inserts: Int64
    let rows: Int64
    let dropped: Int64
    let anonymized: Int64
    let sanitized: Int64
    let fatal: Bool
    let fatalMsg: String

    init(inserts!: Int64, rows!: Int64, dropped!: Int64, anonymized!: Int64,
         sanitized!: Int64, fatal!: Bool, fatalMsg!: String) {
        this.inserts = inserts
        this.rows = rows
        this.dropped = dropped
        this.anonymized = anonymized
        this.sanitized = sanitized
        this.fatal = fatal
        this.fatalMsg = fatalMsg
    }
}

// ===================== 公共入口 =====================

/// 连接 `conn` 指向的活库，按 `repoRoot` 下的策略文件，把分层 seed 写到 `outPath`。
///
/// 这是 T041 的对外入口；T045 的 `db export` 会在它之上再叠加
/// seed-manifest.json 与临时库重放验真（E6/E7）。
public func exportSeed(conn: DbConn, repoRoot: Path, outPath: Path): ExportResult {
    let errors = ArrayList<String>()
    let lp = loadExportPolicy(repoRoot)
    if (!lp.ok()) {
        for (e in lp.errors) {
            errors.add(e)
        }
        return ExportResult(report: None<ExportReport>, errors: errors)
    }
    let policy = match (lp.exportPolicy) {
        case Some(p) => p
        case None => return ExportResult(report: None<ExportReport>, errors: errors)
    }
    // 脱敏策略（lp.ok() 已保证其为 Some；此处再次 match 以覆盖类型）。
    let sp = match (lp.sanitizePolicy) {
        case Some(s) => s
        case None => return ExportResult(report: None<ExportReport>, errors: errors)
    }

    registerDriver()
    let ds = PgDatasource(conn.host, conn.port, conn.user, conn.password, conn.database,
        HashMap<String, String>())
    let c = ds.connect()
    // E4 身份解析：把策略声明的主体/孤儿覆盖解析成"源 uuid → 占位符"映射（design §4.10.5(2)/(3)）。
    let ctx = resolveIdentities(c, policy)
    try {
        let out = StringBuilder()
        out.append("-- uctoo seed export\n")
        out.append("-- generated-at: ")
        out.append(DateTime.now().format("yyyy-MM-dd HH:mm:ss"))
        out.append("\n")
        out.append("-- default-tier: structure-only (whitelist, default-deny)\n")
        out.append("-- policy: ")
        out.append(EXPORT_POLICY_REL)
        out.append("\n\n")

        let tables = introspectTables(c)
        var structureTables: Int64 = 0
        var dataTables: Int64 = 0
        var insertCount: Int64 = 0
        var rowCount: Int64 = 0
        let perTable = ArrayList<ExportTableStat>()

        for (table in tables) {
            let before = out.toString().size
            let schema = introspectTable(c, table)
            let ddl = buildTableDDL(schema)
            out.append(ddl)
            structureTables += 1

            let tier = policy.tierOf(table)
            var kind = "structure"
            var rows: Int64 = 0
            var dropped: Int64 = 0
            var anonymized: Int64 = 0
            var sanitized: Int64 = 0
            // R4 整表降级（design §4.10.6(3)）：命中 r4.tables 的表只导结构、不导数据行。
            if (policy.allowsRows(table) && !sp.droppedByR4(table)) {
                let oc = exportTableData(c, policy, sp, ctx, schema, out)
                // 孤儿策略 fail：整表未完成即判定导出失败，不写盘（finally 负责关连接）。
                if (oc.fatal) {
                    errors.add(oc.fatalMsg)
                    return ExportResult(report: None<ExportReport>, errors: errors)
                }
                insertCount += oc.inserts
                rows = oc.rows
                dropped = oc.dropped
                anonymized = oc.anonymized
                sanitized = oc.sanitized
                if (oc.rows > 0) {
                    dataTables += 1
                    kind = match (tier) {
                        case ExportTier.Bootstrap => "bootstrap"
                        case ExportTier.Sample => "sample"
                        case _ => "data"
                    }
                }
            } else if (sp.droppedByR4(table)) {
                kind = "structure (r4-degraded)"
            }
            rowCount += rows
            let tbytes = out.toString().size - before
            perTable.add(ExportTableStat(
                table: table,
                tier: exportTierCode(tier),
                kind: kind,
                columns: schema.columns.size,
                rows: rows,
                bytes: tbytes,
                dropped: dropped,
                anonymized: anonymized,
                sanitized: sanitized))
        }

        let f = File(outPath, OpenMode.Write)
        f.write(out.toString().toArray())
        f.close()

        let rep = ExportReport(
            generatedAt: DateTime.now().format("yyyy-MM-dd HH:mm:ss"),
            structureTables: structureTables,
            dataTables: dataTables,
            insertCount: insertCount,
            rowCount: rowCount,
            bytes: out.toString().size,
            perTable: perTable)
        return ExportResult(report: Some(rep), errors: errors)
    } catch (e: Exception) {
        errors.add("seed 导出异常：${e.message}")
        return ExportResult(report: None<ExportReport>, errors: errors)
    } finally {
        // 异常路径也必须关闭，否则句柄泄漏（Windows 上还会锁住文件）；
        // 关闭异常不掩盖主流程的返回/异常（scanner.cj 同款写法）。
        try {
            c.close()
        } catch (_: Exception) {
            ()
        }
    }
}

// ===================== 自省（E1） =====================

/// 枚举 public 模式下的全部基表，按表名排序（确定性）。
private func introspectTables(conn: Connection): ArrayList<String> {
    let out = ArrayList<String>()
    let stmt = conn.prepareStatement(
        "SELECT table_name FROM information_schema.tables " +
        "WHERE table_schema = 'public' AND table_type = 'BASE TABLE' " +
        "ORDER BY table_name")
    let rs = stmt.query()
    while (rs.next()) {
        match (rs.getOrNull<String>(0)) {
            case Some(n) => out.add(n)
            case None => ()
        }
    }
    return out
}

/// 自省单表：列（含类型映射、注释）、主键、唯一/非唯一索引、表注释。
private func introspectTable(conn: Connection, table: String): TableSchema {
    let comments = introspectColumnComments(conn, table)
    let cols = introspectColumns(conn, table, comments)
    let pk = introspectPk(conn, table)
    let uniq = introspectIndexes(conn, table, true)
    let idx = introspectIndexes(conn, table, false)
    let cmt = introspectTableComment(conn, table)
    return TableSchema(name: table, columns: cols, pkColumns: pk,
        uniqueIndexes: uniq, indexes: idx, comment: cmt)
}

/// 读列定义，并把 information_schema 的类型映射成可落盘类型串。
private func introspectColumns(conn: Connection, table: String,
                               comments: HashMap<String, String>): ArrayList<ColumnDef> {
    let out = ArrayList<ColumnDef>()
    let stmt = conn.prepareStatement(
        "SELECT column_name, data_type, character_maximum_length, numeric_precision, " +
        "numeric_scale, is_nullable, column_default, udt_name " +
        "FROM information_schema.columns " +
        "WHERE table_schema = 'public' AND table_name = ? ORDER BY ordinal_position")
    stmt.set<String>(0, table)
    let rs = stmt.query()
    while (rs.next()) {
        let name = match (rs.getOrNull<String>(0)) { case Some(n) => n; case None => "" }
        let dt = match (rs.getOrNull<String>(1)) { case Some(d) => d; case None => "text" }
        let charMax = rs.getOrNull<Int64>(2)
        let numPrec = rs.getOrNull<Int64>(3)
        let numScale = rs.getOrNull<Int64>(4)
        let isn = match (rs.getOrNull<String>(5)) { case Some(s) => s; case None => "YES" }
        let def = rs.getOrNull<String>(6)
        let udtName = match (rs.getOrNull<String>(7)) { case Some(u) => u; case None => "" }
        let nullable = (isn != "NO")
        let comment = match (comments.get(name)) { case Some(cm) => cm; case None => "" }
        out.add(ColumnDef(
            name: name,
            sqlType: mapType(dt, charMax, numPrec, numScale, udtName),
            nullable: nullable,
            defaultExpr: def,
            comment: comment))
    }
    return out
}

/// 读主键列（按列序）。
private func introspectPk(conn: Connection, table: String): ArrayList<String> {
    let out = ArrayList<String>()
    let stmt = conn.prepareStatement(
        "SELECT a.attname FROM pg_index i " +
        "JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey) " +
        "WHERE i.indrelid = (?::regclass) AND i.indisprimary ORDER BY a.attnum")
    stmt.set<String>(0, table)
    let rs = stmt.query()
    while (rs.next()) {
        match (rs.getOrNull<String>(0)) {
            case Some(n) => out.add(n)
            case None => ()
        }
    }
    return out
}

/// 读索引：唯一（`uniqueWanted=true`）或非唯一。
///
/// 不把 `i.indisunique = ?` 当参数传——用字面量 `AND i.indisunique` / `AND NOT i.indisunique`
/// 规避布尔参数绑定的歧义，两个分支只在那一个词上不同。
private func introspectIndexes(conn: Connection, table: String, uniqueWanted: Bool): ArrayList<IndexDef> {
    // 直接从 pg_index + 索引自身的 pg_class 读取，不再 JOIN pg_constraint：
    // 旧逻辑用 `JOIN pg_constraint con ON con.conindid = i.indexrelid` 过滤非唯一索引，
    // 而普通（非唯一）索引没有任何 pg_constraint 行，导致整个 `schema.indexes` 永远为空、
    // 生成的 DDL 把全部普通 CREATE INDEX 漏掉。唯一索引也改读索引 relname，
    // 行为与「约束名」一致且额外覆盖「无约束的裸 CREATE UNIQUE INDEX」。
    let sql = if (uniqueWanted) {
        "SELECT c2.relname, k.attname FROM pg_index i " +
        "JOIN pg_class c2 ON c2.oid = i.indexrelid " +
        "JOIN pg_attribute k ON k.attrelid = i.indrelid AND k.attnum = ANY(i.indkey) " +
        "WHERE i.indrelid = (?::regclass) AND i.indisunique AND NOT i.indisprimary " +
        "ORDER BY c2.relname, k.attnum"
    } else {
        "SELECT c2.relname, k.attname FROM pg_index i " +
        "JOIN pg_class c2 ON c2.oid = i.indexrelid " +
        "JOIN pg_attribute k ON k.attrelid = i.indrelid AND k.attnum = ANY(i.indkey) " +
        "WHERE i.indrelid = (?::regclass) AND NOT i.indisunique AND NOT i.indisprimary " +
        "ORDER BY c2.relname, k.attnum"
    }
    let stmt = conn.prepareStatement(sql)
    stmt.set<String>(0, table)
    let rs = stmt.query()
    let groups = HashMap<String, ArrayList<String>>()
    while (rs.next()) {
        match (rs.getOrNull<String>(0)) {
            case Some(cname) => match (rs.getOrNull<String>(1)) {
                case Some(c) =>
                    match (groups.get(cname)) {
                        case Some(list) => list.add(c)
                        case None =>
                            let list = ArrayList<String>()
                            list.add(c)
                            groups.add(cname, list)
                    }
                case None => ()
            }
            case None => ()
        }
    }
    let out = ArrayList<IndexDef>()
    for ((name, cols) in groups) {
        out.add(IndexDef(name: name, columns: cols))
    }
    return out
}

/// 读表注释。
private func introspectTableComment(conn: Connection, table: String): String {
    let stmt = conn.prepareStatement(
        "SELECT obj_description((?::regclass)::oid, 'pg_class')")
    stmt.set<String>(0, table)
    let rs = stmt.query()
    if (rs.next()) {
        return match (rs.getOrNull<String>(0)) { case Some(s) => s; case None => "" }
    }
    return ""
}

/// 读列注释：列名 → 注释。
private func introspectColumnComments(conn: Connection, table: String): HashMap<String, String> {
    let out = HashMap<String, String>()
    let stmt = conn.prepareStatement(
        "SELECT a.attname, col_description(a.attrelid, a.attnum) FROM pg_attribute a " +
        "WHERE a.attrelid = (?::regclass) AND a.attnum > 0 AND NOT a.attisdropped")
    stmt.set<String>(0, table)
    let rs = stmt.query()
    while (rs.next()) {
        let cn = match (rs.getOrNull<String>(0)) { case Some(s) => s; case None => "" }
        let cm = match (rs.getOrNull<String>(1)) { case Some(s) => s; case None => "" }
        if (!cn.isEmpty() && !cm.isEmpty()) {
            out.add(cn, cm)
        }
    }
    return out
}

// ===================== 类型映射 =====================

/// 把 information_schema 的 `data_type` 映射成可落盘的 PostgreSQL 类型串。
///
/// `udtName` 仅数组列需要：information_schema 中数组列的 data_type 恒为 'ARRAY'，
/// 真实元素类型藏在 udt_name（如 _text / _varchar / _jsonb），须据此还原成 "元素类型[]"。
private func mapType(dataType: String, charMax: Option<Int64>, numPrec: Option<Int64>,
                    numScale: Option<Int64>, udtName: String): String {
    match (dataType) {
        case "character varying" =>
            return match (charMax) { case Some(n) => "varchar(${n})"; case None => "text" }
        case "character" =>
            return match (charMax) { case Some(n) => "char(${n})"; case None => "char" }
        case "text" => return "text"
        case "integer" => return "integer"
        case "bigint" => return "bigint"
        case "smallint" => return "smallint"
        case "numeric" =>
            return match (numPrec) {
                case Some(p) => "numeric(${p},${numScaleOrDefault(numScale)})"
                case None => "numeric"
            }
        case "real" => return "real"
        case "double precision" => return "double precision"
        case "boolean" => return "boolean"
        case "timestamp without time zone" => return "timestamp"
        case "timestamp with time zone" => return "timestamptz"
        case "date" => return "date"
        case "time without time zone" => return "time"
        case "json" => return "json"
        case "jsonb" => return "jsonb"
        case "uuid" => return "uuid"
        case "bytea" => return "bytea"
        case "ARRAY" => return mapArrayType(udtName)
        case _ => return dataType
    }
}

/// 数组列元素类型：information_schema 的 udt_name 形如 _int4 / _varchar / _jsonb（带前导下划线），
/// 去掉下划线后用 friendly 类型名拼出 "元素类型[]"，保证可重放。
private func mapArrayType(udtName: String): String {
    let base = if (udtName.startsWith("_")) { udtName[1..] } else { udtName }
    if (base.isEmpty()) { return "text[]" }  // 兜底，避免裸 "[]"
    match (base) {
        case "int2" => return "smallint[]"
        case "int4" => return "integer[]"
        case "int8" => return "bigint[]"
        case "float4" => return "real[]"
        case "float8" => return "double precision[]"
        case "numeric" => return "numeric[]"
        case "text" => return "text[]"
        case "varchar" => return "varchar[]"
        case "bpchar" => return "char[]"
        case "bool" => return "boolean[]"
        case "uuid" => return "uuid[]"
        case "json" => return "json[]"
        case "jsonb" => return "jsonb[]"
        case "bytea" => return "bytea[]"
        case "date" => return "date[]"
        case "time" => return "time[]"
        case "timestamp" => return "timestamp[]"
        case "timestamptz" => return "timestamptz[]"
        case _ => return "${base}[]"
    }
}

private func numScaleOrDefault(o: Option<Int64>): Int64 {
    match (o) {
        case Some(v) => v
        case None => 0
    }
}

// ===================== DDL 生成 =====================

/// 生成 `CREATE TABLE IF NOT EXISTS` + COMMENT + PK/UK/索引。
///
/// 禁 `DROP TABLE` / `TRUNCATE` / `DELETE`（旧基线 206 条 DROP 是 Navicat 默认值，不继承）。
private func buildTableDDL(schema: TableSchema): String {
    let sb = StringBuilder()
    sb.append("CREATE TABLE IF NOT EXISTS \"")
    sb.append(schema.name)
    sb.append("\" (\n")
    var first = true
    for (col in schema.columns) {
        if (!first) {
            sb.append(",\n")
        }
        first = false
        sb.append("  \"")
        sb.append(col.name)
        sb.append("\" ")
        sb.append(col.sqlType)
        if (!col.nullable) {
            sb.append(" NOT NULL")
        }
        match (col.defaultExpr) {
            case Some(d) =>
                sb.append(" DEFAULT ")
                sb.append(d)
            case None => ()
        }
    }
    if (!schema.pkColumns.isEmpty()) {
        sb.append(",\n  PRIMARY KEY (")
        sb.append(joinQuoted(schema.pkColumns))
        sb.append(")")
    }
    sb.append("\n);\n")

    if (!schema.comment.isEmpty()) {
        sb.append("COMMENT ON TABLE \"")
        sb.append(schema.name)
        sb.append("\" IS ")
        sb.append(quoteSqlString(schema.comment))
        sb.append(";\n")
    }
    for (col in schema.columns) {
        if (!col.comment.isEmpty()) {
            sb.append("COMMENT ON COLUMN \"")
            sb.append(schema.name)
            sb.append("\".\"")
            sb.append(col.name)
            sb.append("\" IS ")
            sb.append(quoteSqlString(col.comment))
            sb.append(";\n")
        }
    }
    // 同名索引去重闸：同一索引名（无论唯一/非唯一）只落盘一次，
    // 防止 introspect 异常重复或跨列表撞名导致重复 CREATE INDEX。
    let emittedIdx = HashMap<String, Int64>()
    for (idx in schema.uniqueIndexes) {
        if (emittedIdx.contains(idx.name)) {
            continue
        }
        emittedIdx.add(idx.name, 1)
        sb.append("CREATE UNIQUE INDEX \"")
        sb.append(idx.name)
        sb.append("\" ON \"")
        sb.append(schema.name)
        sb.append("\" (")
        sb.append(joinQuoted(idx.columns))
        sb.append(");\n")
    }
    for (idx in schema.indexes) {
        if (emittedIdx.contains(idx.name)) {
            continue
        }
        emittedIdx.add(idx.name, 1)
        sb.append("CREATE INDEX \"")
        sb.append(idx.name)
        sb.append("\" ON \"")
        sb.append(schema.name)
        sb.append("\" (")
        sb.append(joinQuoted(idx.columns))
        sb.append(");\n")
    }
    sb.append("\n")
    return sb.toString()
}

/// 把字符串列表拼成 `"a", "b", "c"` 形态（用于主键 / 索引列清单）。
private func joinQuoted(list: ArrayList<String>): String {
    let sb = StringBuilder()
    var first = true
    for (x in list) {
        if (!first) {
            sb.append(", ")
        }
        first = false
        sb.append("\"")
        sb.append(x)
        sb.append("\"")
    }
    return sb.toString()
}

// ===================== 数据导出（E3） =====================

/// 流式逐行导出某表数据（仅 bootstrap / sample 档会走到这里）。
///
/// 在 E3 逐单元格落盘之前插入两步（design §4.10.5 E4 / E4.5）：
///   - E4 身份匿名化：`anonymizeCell` 把身份列里的真实 uuid 替换为 `{{principal:..}}` / `{{agent:..}}`；
///     孤儿按 `orphanDefault` 处置——`fail` 让整表导出失败（致命），`drop` 跳过整行（计入 dropped）。
///   - E4.5 脱敏：`sanitizeCell` 把凭据/环境标识替换为 `{{secret:..}}` / `{{env:..}}`，
///     并据 `SanitizeOutcome.sensitive` 回填 `config.is_sensitive = true`。
///
/// 引号感知：字符串走 `quoteSqlString`，绝不按行切分或按 `);` 切分。
/// 返回 `TableExportOutcome`；`fatal` 为真表示出现孤儿 fail，调用方应中断整次导出。
private func exportTableData(conn: Connection, policy: ExportPolicy, sp: SanitizePolicy,
                            ctx: IdentityContext, schema: TableSchema,
                            out: StringBuilder): TableExportOutcome {
    let cols = schema.columns
    if (cols.isEmpty()) {
        return TableExportOutcome(inserts: 0, rows: 0, dropped: 0, anonymized: 0,
            sanitized: 0, fatal: false, fatalMsg: "")
    }

    // 投影列清单（确定性顺序 = 列定义顺序）
    let colList = StringBuilder()
    var first = true
    for (col in cols) {
        if (!first) {
            colList.append(", ")
        }
        first = false
        colList.append("\"")
        colList.append(col.name)
        colList.append("\"")
    }

    // SELECT
    let sel = StringBuilder()
    sel.append("SELECT ")
    sel.append(colList.toString())
    sel.append(" FROM \"")
    sel.append(schema.name)
    sel.append("\"")
    match (policy.bootstrapRowPredicates.get(schema.name)) {
        case Some(pred) =>
            sel.append(" WHERE ")
            sel.append(pred)
        case None => ()
    }
    sel.append(" ORDER BY ")
    sel.append(orderByExpr(policy, schema))
    match (findSample(policy, schema.name)) {
        case Some(s) =>
            sel.append(" LIMIT ")
            sel.append(s.maxRows.toString())
        case None => ()
    }

    let stmt = conn.prepareStatement(sel.toString())
    let rs = stmt.query()

    var inserts: Int64 = 0
    var rows: Int64 = 0
    var dropped: Int64 = 0
    var anonymized: Int64 = 0
    var sanitized: Int64 = 0
    var fatal: Bool = false
    var fatalMsg: String = ""

    while (rs.next()) {
        // 先把整行读进 rawRow（列名 → 原始值）；NULL 列不进 map（调用约定：NULL 不进匿名化）。
        let rawRow = HashMap<String, String>()
        for (i in 0..cols.size) {
            match (rs.getOrNull<String>(i)) {
                case Some(v) => rawRow.add(cols[i].name, v)
                case None => ()
            }
        }

        // E4 第一遍：身份匿名化（就地产生 anonRow）。
        let anonRow = HashMap<String, String>()
        var skipRow: Bool = false
        for ((cn, v) in rawRow) {
            let anon = anonymizeCell(ctx, cn, v)
            match (anon.status) {
                case AnonymizeStatus.OrphanFail =>
                    fatal = true
                    fatalMsg = "身份匿名化失败：${schema.name}.${cn} 含未声明孤儿 uuid（${v}）；" +
                        "orphanDefault=fail 禁止导出，请加 orphanOverrides 或改 drop"
                    anonRow.add(cn, v)
                case AnonymizeStatus.DropRow =>
                    skipRow = true
                    anonRow.add(cn, v)
                case AnonymizeStatus.Replaced =>
                    anonymized += 1
                    anonRow.add(cn, anon.value)
                case AnonymizeStatus.Unchanged =>
                    anonRow.add(cn, anon.value)
            }
        }
        if (fatal) {
            break
        }
        if (skipRow) {
            dropped += 1
            continue
        }

        // E4.5 第二遍：脱敏 + 标记 config.is_sensitive 回填。
        var markSensitive: Bool = false
        let sanByIndex = ArrayList<SanitizeOutcome>()
        for (i in 0..cols.size) {
            let col = cols[i]
            match (rs.getOrNull<String>(i)) {
                case Some(_) =>
                    let anonVal = match (anonRow.get(col.name)) {
                        case Some(x) => x
                        case None => ""
                    }
                    let san = sanitizeCell(sp, schema.name, col.name, anonVal, anonRow)
                    if (san.sensitive) {
                        markSensitive = true
                    }
                    // 枚举不支持 `==`/`!=`（无 Equatable 实现），一律用 match 判等。
                    let ruleHit = match (san.rule) {
                        case SanitizeRule.None => false
                        case _ => true
                    }
                    if (ruleHit) {
                        sanitized += 1
                    }
                    sanByIndex.add(san)
                case None =>
                    sanByIndex.add(SanitizeOutcome("", SanitizeRule.None, false, ""))
            }
        }

        // 第三遍：序列化落盘（含 is_sensitive 回填）。
        let sqlVals = ArrayList<String>()
        for (i in 0..cols.size) {
            let col = cols[i]
            match (rs.getOrNull<String>(i)) {
                case Some(_) =>
                    // config 表：本行被 R1 命中 → 强制 is_sensitive 列为 TRUE（design E4.5 回填）。
                    if (markSensitive && schema.name == sp.backfillTable && col.name == sp.backfillColumn) {
                        sqlVals.add("TRUE")
                    } else {
                        let san = sanByIndex[i]
                        sqlVals.add(classifyValue(col, san.value))
                    }
                case None => sqlVals.add("NULL")
            }
        }

        let rowSb = StringBuilder()
        rowSb.append("INSERT INTO \"")
        rowSb.append(schema.name)
        rowSb.append("\" (")
        rowSb.append(colList.toString())
        rowSb.append(") VALUES (")
        for (i in 0..sqlVals.size) {
            if (i > 0) {
                rowSb.append(", ")
            }
            rowSb.append(sqlVals[i])
        }
        rowSb.append(");\n")
        out.append(rowSb.toString())
        inserts += 1
        rows += 1
    }

    return TableExportOutcome(inserts: inserts, rows: rows, dropped: dropped,
        anonymized: anonymized, sanitized: sanitized, fatal: fatal, fatalMsg: fatalMsg)
}

/// 确定性排序键：sample 档用其声明的 orderBy；否则主键；否则首列；否则常量 1。
private func orderByExpr(policy: ExportPolicy, schema: TableSchema): String {
    match (findSample(policy, schema.name)) {
        case Some(s) => return s.orderBy
        case None =>
            if (!schema.pkColumns.isEmpty()) {
                return joinQuoted(schema.pkColumns)
            }
            if (!schema.columns.isEmpty()) {
                return "\"" + schema.columns[0].name + "\""
            }
            return "1"
    }
}

/// 在样本策略里找指定表的条目。
private func findSample(policy: ExportPolicy, table: String): Option<SamplePolicy> {
    for (s in policy.samples) {
        if (s.table == table) {
            return Some(s)
        }
    }
    return None<SamplePolicy>
}

/// 把一列的运行时文本值序列化成 SQL 字面量。
///
/// - NULL 已在调用方判过，这里拿到的 `raw` 必有值；
/// - 数值类型原样输出（已是合法数值文本）；
/// - 布尔按文本形态归一为 `TRUE` / `FALSE`；
/// - 其余（文本/uuid/json/时间戳等）走 `quoteSqlString` 引号转义。
private func classifyValue(col: ColumnDef, raw: String): String {
    if (col.sqlType == "boolean") {
        let low = raw.toAsciiLower()
        if (low == "t" || low == "true" || low == "1") {
            return "TRUE"
        }
        if (low == "f" || low == "false" || low == "0") {
            return "FALSE"
        }
        return quoteSqlString(raw)
    }
    if (isNumericType(col.sqlType)) {
        return raw
    }
    return quoteSqlString(raw)
}

private func isNumericType(sqlType: String): Bool {
    return sqlType == "integer" || sqlType == "bigint" || sqlType == "smallint" ||
        sqlType == "numeric" || sqlType == "real" || sqlType == "double precision" ||
        sqlType == "money"
}

/// 引号感知字符串字面量。
/// 统一输出**标准 SQL 普通 `'...'`**（单引号以 `''` 转义），**绝不输出** PostgreSQL `E'...'` 转义串。
///
/// 背景 / 为什么放弃 `E'...'`：
///   E5 门禁扫描器（`scanner.cj`）与导入器（`importer.cj`）不识别 `E'...'` 的反斜杠转义语义，
///   其 `parseInsert` 会把含 `E'` 的 INSERT 误判为「缺少 VALUES」——这正是 `db export` 自检
///   崩溃、且导入器无法解析自家导出物的根因。改为普通 `'...'` 后，导出物与 Navicat / pg_dump
///   基线风格完全一致，且可被自家扫描器与导入器正确解析。
///   反斜杠 / 换行 / 制表等字符在 `standard_conforming_strings = on`（PostgreSQL 默认）的普通串内
///   即为字面量，无需转义；本项目运行库为该默认配置。
private func quoteSqlString(s: String): String {
    let sb = StringBuilder()
    sb.append("'")
    for (r in s.toRuneArray()) {
        if (r == r"'") {
            sb.append("''")   // 标准 SQL：单引号以 '' 转义
        } else {
            sb.append(r)      // 其余（含反斜杠 / 换行 / 制表 / 双引号）原样保留为字面量
        }
    }
    sb.append("'")
    return sb.toString()
}
