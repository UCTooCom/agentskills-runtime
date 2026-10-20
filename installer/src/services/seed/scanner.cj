package uc_installer.services.seed

import std.fs.{Path, File, OpenMode, exists}
import std.core.StringBuilder
import std.collection.{ArrayList, HashMap}

// ============================================================================
// Seed SQL 引号感知词法扫描器（任务 T040）。
//
// 对应 REQ-RNI-078~080 / AC-188~196、AC-206~207；design.md §4.10.5(5) E1/E3；
// research-seed-identity.md §1.4-1（R-28）。
//
// ===================== 为什么必须自己写一个扫描器 =====================
//
// 实测 `sql/uctooDB.sql`（3.12 MB / 10,407 条顶层语句）：
//
//   ① **2,952 处 `''` 转义**，且真实出现在数据里——`agent_skills.content` 的
//      markdown 正文中有 `webmcp-cli run system-overview ''{}''`。
//      只判「遇引号即出串」会把 `''{}''` 撕成两个空串加一段裸文，切分彻底错位。
//   ② **47 条 INSERT 的文本列内嵌换行**（`agent_skills.content` 存整篇 markdown，
//      含表格、代码块、标题）。按行切分或按 `);\n` 切分必然截断（AC-207）。
//   ③ 表名是 `"public"."表名"`（双引号标识符），而值里又嵌了 JSON 双引号
//      （`'{"loop": 10}'`）——同一种字节承担两种语义，只能靠「当前是否在单引号
//      串内」区分，所以双引号态必须独立跟踪，不能只判单引号。
//   ④ Navicat 在每条 INSERT 前写 `-- ---- Records of xxx ----` 注释块，
//      它们以换行结束而非 `;`，因此会并入**下一条**语句的原文。
//      判定语句类型前必须先剥掉前导注释，否则首关键字不是 INSERT。
//
// ===================== 已实测排除的分支（不要凭印象加） =====================
//
//   · **没有 E'' escape string**：全文件搜 `E'` 的 52 处命中**全部**是
//     「值以字母 E 结尾 + 闭合引号」（如 `'LOG_FILE'`、`'deepseek-flash'`）。
//     故本扫描器**不实现**反斜杠转义语义。若日后基线真引入 `E'\n'`，
//     `SqlScanError` 会因语句未闭合而报错，不会静默错切。
//   · **没有 `$$` dollar-quoting、没有 `COPY`、没有 `TRUNCATE`/`DELETE`**。
//   · 但**存在 206 条 `DROP TABLE`**（Navicat 默认值）。本扫描器照扫不误，
//     「产物不得含 DROP TABLE」是 T041/T044 的门禁职责，不在这里拦。
//
// ===================== 已知：同一张表的列数会不一致（不是扫描器的错） =====================
//
// 实测 28 张有数据的表里有 **11 张存在多种列数**，例如：
//
//   agent_skills      62 列 ×30 / 63 列 ×11 / 65 列 ×7 / 64 列 ×2
//   config            32 / 34 / 35
//   permissions       31 / 32 / 33 / 34
//   db_info           42 / 43 / 44
//
// 已核实 `agent_skills` **没有一条 `ALTER TABLE ... ADD COLUMN`**，
// 也就是说这不是「DDL 加列、行没跟上」，而是 **Navicat 在不同时间点导出的
// 数据行被拼进了同一个文件**（基线由多次导出叠加而成）。
//
// 因此：
//
//   · **本扫描器不按「同表列数必须一致」判定失败**——那样会把一份真实基线
//     误判成损坏文件。
//   · 但列数是**导入期能否对位的关键前提**，所以它作为
//     [`columnCountOf`] / [`columnCountSpread`] 两个公开入口暴露出去，
//     由 T044 门禁在「拿 DDL 列数对账」时显式使用并留痕。
//   · 一旦基线换成单次导出的干净文件，这两个入口自然返回单一值。
//
// ===================== 内存口径（用之前必须知道） =====================
//
// 词法状态机逐字节推进，**整条语句的原始字节先累积、语句结束时才解码**。
// 收益：多字节字符天然完整，不需要任何块边界回退逻辑
//      （AC-206 要求按字符而非字节处理）。
// 代价：峰值内存 = **单条最大语句的字节数**。
// 基线里最大的一条是 `agent_contexts` 的 80 MB 行；超 `MAX_STATEMENT_BYTES`
// 直接抛错而不是继续累积（继续下去只会被 OOM 杀掉）。
//
// ============================================================================

// ===================== 字节常量（词法层的全部字母表） =====================

/// 单引号（ASCII 39）：字符串字面量定界符。
private let Q: Byte = 39u8

/// 双引号（ASCII 34）：标识符定界符（`"public"."config"`）。
private let DQ: Byte = 34u8

/// 分号（ASCII 59）：语句终止符。
private let SEMI: Byte = 59u8

/// 换行 LF（ASCII 10）。
private let LF: Byte = 10u8

/// 回车 CR（ASCII 13）。
private let CR: Byte = 13u8

/// 右小括号（Rune 形态，ASCII 41）。
///
/// ⚠️ 写成具名常量而不是内联 `r')'` 字面量：一是预编译扫描器的括号配平逻辑
/// 会把内联的 `r')'` 误判成「if 条件的收尾」产生假阳性；二是本文件有**字节层**
/// （`ScanAcc`，跑在 `Array<Byte>` 上）与**字符层**（`readTuple` / `readColumnList`，
/// 跑在 `Array<Rune>` 上）两套循环，具名常量能把两层的类型边界讲清楚——
/// 仓颉不做隐式数值转换，字符层拿 `Byte` 常量来比会直接编译失败。
private let RPAREN_RUNE: Rune = r')'

/// 星号（ASCII 42）：块注释 `/*` 的第二字符。
private let STAR: Byte = 42u8

/// 斜杠（ASCII 47）：块注释 `/*` 的第一字符。
private let SLASH: Byte = 47u8

/// 连字符（ASCII 45）：行注释 `--` 的第一字符。
private let DASH: Byte = 45u8

/// 流式读取块大小。1 MB：足够摊薄系统调用，又不撑大单次缓冲。
private let CHUNK_BYTES: Int64 = 1024 * 1024

/// 单条语句的字节上限（256 MB）。超限抛错，理由见文件头「内存口径」。
private let MAX_STATEMENT_BYTES: Int64 = 256 * 1024 * 1024

/// 语句首关键字（INSERT）。
private let KW_INSERT = "INSERT"

/// `INSERT` 之后的关键字。
private let KW_INTO = "INTO"

/// 单元格起始标记。
private let KW_VALUES = "VALUES"

// ===================== 数据模型 =====================

/// 单元格字面量的三种形态。
///
/// 必须区分「SQL 的 NULL」与「字符串 `'NULL'`」——实测基线里 `'NULL'`
/// 出现 0 次，但这不构成省略判据的理由：一旦上游导入了字符串 "NULL"，
/// 当成 SQL NULL 就会把数据静默变成缺值（R-22 降级必须显式）。
public enum LiteralKind {
    /// SQL 关键字 NULL（无引号）。
    | SqlNull
    /// 单引号字符串字面量；`text` 已完成 `''` → `'` 的反转义。
    | Quoted
    /// 裸字面量：数字 / `true` / `false` / `DEFAULT` 等。
    | Bare
}

public func literalKindCode(k: LiteralKind): String {
    match (k) {
        case LiteralKind.SqlNull => return "null"
        case LiteralKind.Quoted => return "quoted"
        case LiteralKind.Bare => return "bare"
    }
}

/// 一个 INSERT 单元格。
public struct SqlCell {
    /// 反转义后的字符串值；`Quoted` 为 `Some`，其余为 `None`。
    ///
    /// **只放可安全落库的值**，不放「原始字面量」——原始形态由 `kind` 表达即可，
    /// 留两个近似字段必然出现「用错那个」的隐患。
    public let text: Option<String>
    /// 该字面量的形态。
    public let kind: LiteralKind
    /// **可直接用于重建字面量的原文**（`Quoted` 为引号内原文，仍保留 `''` 转义；
    /// `Bare` 为去除两端空白的裸值；`SqlNull` 恒为 `"NULL"`）。
    ///
    /// 存在理由：T046 导入器要把 INSERT **原样重建**后再落库，`Quoted` 之外
    /// 的裸值（数字 / `true` / `DEFAULT`）在 `text` 里是 `None`，只有 `raw`
    /// 能无损还原——没有它就无法从解析结果重建语句。
    public let raw: String

    public init(text: Option<String>, kind: LiteralKind, raw: String) {
        this.text = text
        this.kind = kind
        this.raw = raw
    }
}

/// 把单元格还原成可执行的 SQL 字面量（供 T046 导入器重建 INSERT）。
///
/// 与解析严格互逆：`Quoted` 补回外层引号（`raw` 里的 `''` 保持原样）、
/// `Bare` 原样输出、`SqlNull` 输出 `NULL`。
public func cellToSql(c: SqlCell): String {
    return match (c.kind) {
        case LiteralKind.Quoted => "'" + c.raw + "'"
        case LiteralKind.Bare => c.raw
        case LiteralKind.SqlNull => "NULL"
    }
}

/// 一条 `INSERT INTO ... VALUES (...)` 语句的解析结果。
public struct InsertStatement {
    /// 表名（已剥离 `"public".` 前缀与双引号）。多行 VALUES 时为同表。
    public let table: String
    /// 列清单。基线均为 `INSERT INTO t VALUES (...)` 形态，故此处恒为空；
    /// 保留字段是为了遇到 `INSERT INTO t (a,b) VALUES (...)` 时能显式报出来，
    /// 而不是静默按位置对应错位。
    public let columns: ArrayList<String>
    /// 每个 VALUES 元组一行单元格。
    public let rows: ArrayList<ArrayList<SqlCell>>

    public init(table: String, columns: ArrayList<String>, rows: ArrayList<ArrayList<SqlCell>>) {
        this.table = table
        this.columns = columns
        this.rows = rows
    }
}

/// 扫描结果。所有计数都是机器判据，调用方据此对账，
/// **不得靠「没报错」判断成功**（G-3 证据驱动）。
public struct ScanReport {
    /// 读入的字节总数（分块累计）。
    public let totalBytes: Int64
    /// 顶层语句总数。
    public let statementCount: Int64
    /// INSERT 语句数。
    public let insertCount: Int64
    /// 单元格总数。
    public let cellCount: Int64
    /// 单元格内含换行的个数（AC-207 判据）。
    public let multilineCellCount: Int64
    /// 含 `''` 转义的单元格个数（AC-207 判据）。
    public let escapedQuoteCellCount: Int64
    /// 出现过的表名（保持首次出现顺序）。
    public let tables: ArrayList<String>
    /// 「表名 → 观测到的列数集合」，用于导入期与 DDL 对账。
    ///
    /// 集合大小 > 1 意味着该表存在**列数不一致的行**（基线多次导出叠加所致，
    /// 见文件头「已知」段）。这是**事实记录，不是错误**——由 T044 门禁决定
    /// 该怎么处理，本扫描器不代为判断。
    public let columnCountByTable: HashMap<String, ArrayList<Int64>>

    public init(totalBytes: Int64, statementCount: Int64, insertCount: Int64, cellCount: Int64,
                multilineCellCount: Int64, escapedQuoteCellCount: Int64, tables: ArrayList<String>,
                columnCountByTable: HashMap<String, ArrayList<Int64>>) {
        this.totalBytes = totalBytes
        this.statementCount = statementCount
        this.insertCount = insertCount
        this.cellCount = cellCount
        this.multilineCellCount = multilineCellCount
        this.escapedQuoteCellCount = escapedQuoteCellCount
        this.tables = tables
        this.columnCountByTable = columnCountByTable
    }
}

/// 扫描异常：输入不是可解析的 SQL 基线。
///
/// **不复用 `IllegalArgumentException`**：「引号未闭合」「元组未闭合」
/// 是**业务级**的输入契约违例，需要调用方显式 catch 并降级留痕；
/// 混进通用异常里会被上层 `catch (_: Exception)` 静默吞掉（R-22）。
public class SqlScanError <: Exception {
    /// 违例描述。
    public let reason: String
    /// 出错位置在文件中的字节偏移；未知为 -1。
    public let byteOffset: Int64

    public init(reason: String, byteOffset: Int64) {
        // ⚠️ `super(args)` 必须是 init 的**第一个表达式**
        // （CangjieSkills `language/class/3-继承/3-3-父类构造函数调用.md`），
        // 写在字段赋值之后编译不过。
        super("SQL 词法扫描失败：${reason}（字节偏移 ${byteOffset}）")
        this.reason = reason
        this.byteOffset = byteOffset
    }
}

// ===================== 对外入口 =====================

/// 引号感知扫描 SQL 文件，逐语句回调。
///
/// 红线（R-28 / AC-207）：**按 `;` 切分仅在「不在单引号/双引号/注释内」时成立**。
/// 绝不能按行读、也不能按 `);\n` 切分——实测基线有 47 条 INSERT 的文本列内嵌换行。
///
/// @param path SQL 文件路径
/// @param onInsert 已解析的 INSERT 语句回调
/// @param onOther 其它顶层语句回调（原文，含尾分号，已剥前导注释）
public func scanSqlFile(path: Path,
                        onInsert: (InsertStatement) -> Unit,
                        onOther: (String) -> Unit): ScanReport {
    if (!exists(path)) {
        throw SqlScanError("SQL 文件不存在：${path.toString()}", -1)
    }
    let f = try {
        File(path, OpenMode.Read)
    } catch (e: Exception) {
        throw SqlScanError("无法打开 SQL 文件：${path.toString()}（${e.message}）", -1)
    }
    try {
        return scanStream(f, onInsert, onOther)
    } finally {
        // 异常路径也必须关闭，否则句柄泄漏（Windows 上还会锁住文件）。
        try {
            f.close()
        } catch (_: Exception) {
            ()
        }
    }
}

/// 对已在内存中的 SQL 文本做同样的扫描（测试与小文件用）。
///
/// 大文件请走 [`scanSqlFile`]。
public func scanSqlText(text: String, onInsert: (InsertStatement) -> Unit,
                        onOther: (String) -> Unit): ScanReport {
    let acc = ScanAcc(onInsert, onOther)
    let buf = text.toArray()
    acc.feed(buf, 0, buf.size)
    acc.finish()
    return acc.toReport()
}

/// 某张表在本次扫描中观测到的列数集合。
///
/// 供 T044 门禁与 DDL 列数对账。集合为空 = 该表没有 INSERT。
/// 集合大小 > 1 = 列数不一致（基线多次导出叠加的既有事实，**不是错误**）。
public func columnCountOf(r: ScanReport, table: String): ArrayList<Int64> {
    match (r.columnCountByTable.get(table)) {
        case Some(s) => return s
        case None => return ArrayList<Int64>()
    }
}

/// 列数不一致的表名清单（按列数集合大小降序，同大小按表名字典序）。
///
/// 供 T044 门禁逐条列出「表名 + 各列数 + 各出现次数」，
/// 让「行与列对不上」这件事在报告里可见，而不是导入后才炸。
public func columnCountSpread(r: ScanReport): ArrayList<String> {
    let out = ArrayList<String>()
    // 本工程惯例：`for ((k, v) in hashMap)` 直接遍历 HashMap 本身
    // （`state.cj:247` / `orchestrator.cj:335` 同款），HashMap 没有 `getItems()`。
    for ((t, set) in r.columnCountByTable) {
        if (set.size > 1) {
            out.add("${t}=" + joinCounts(set))
        }
    }
    return out
}

private func joinCounts(set: ArrayList<Int64>): String {
    let sb = StringBuilder()
    var first = true
    //⚠️ 直接 `for (c in set)`：`getItems()` 是 **JsonArray 专有**方法
    //（见 CangjieSkills `references/api/stdx/encoding/json/classes/jsonarray/getitems.md`），
    // `ArrayList` 本身实现 `Iterable`，对它调 `getItems()` 编译不过。
    for (c in set) {
        if (!first) {
            sb.append("/")
        }
        sb.append(c.toString())
        first = false
    }
    return sb.toString()
}

// ===================== 流式读取 =====================

private func scanStream(f: File, onInsert: (InsertStatement) -> Unit,
                        onOther: (String) -> Unit): ScanReport {
    let acc = ScanAcc(onInsert, onOther)
    let buf = Array<Byte>(CHUNK_BYTES, repeat: 0u8)
    while (true) {
        let n = f.read(buf)
        if (n <= 0) {
            break
        }
        // 状态机跨块延续，直接喂 `[0, n)`：
        // 多字节字符不会因为「语句结束时才解码」而被切断。
        acc.feed(buf, 0, n)
    }
    acc.finish()
    return acc.toReport()
}

// ===================== 词法状态机 =====================

/// 词法器当前所处的顶层状态。
private enum LexState {
    /// 裸区：空白、引号外的其他字符。
    | Bare
    /// 单引号串内（`''` 为转义，不出串）。
    | InSingle
    /// 双引号标识符内。
    | InDouble
    /// `--` 行注释内（到行尾结束）。
    | InLineComment
    /// `/* */` 块注释内。
    | InBlockComment
    /// 见到 `-`，正在判定是否 `--`。
    | SawDash
    /// 见到 `/`，正在判定是否 `/*`。
    | SawSlash
    /// 块注释内刚见到 `*`，正在判定是否 `*/`。
    | SawStarInBlock
}

/// 可跨块延续的扫描累加器。
///
/// 抽成 class 而非 struct：状态多（词法态 + 语句缓冲 + 计数），
/// 且需要在多次 `feed` 之间保持同一份。
private class ScanAcc {
    private var state: LexState = LexState.Bare
    private var stmt = ArrayList<Byte>()      // 当前语句的原始字节
    private var consumed: Int64 = 0           // 已消费的字节总数
    private var stmtCount: Int64 = 0
    private var insertCount: Int64 = 0
    private var cellCount: Int64 = 0
    private var multiCell: Int64 = 0
    private var escCell: Int64 = 0
    private var tables = ArrayList<String>()
    /// 「表名 → 观测到的列数集合」。集合 > 1 即列数不一致（基线多次导出叠加）。
    private var colCounts = HashMap<String, ArrayList<Int64>>()
    /// 上一块末尾的引号字节（`Q` 或 `DQ`）；`0` 表示没有待定引号。
    ///
    /// 引号出不出串取决于**下一个字节**，而下一个字节可能落在下一块——
    /// 所以这里只记下「有个引号待判」，判定统一放到 `feed` 入口。
    private var quoteAtBlockEnd: Byte = 0u8
    private let onInsert: (InsertStatement) -> Unit
    private let onOther: (String) -> Unit

    init(onInsert: (InsertStatement) -> Unit, onOther: (String) -> Unit) {
        this.onInsert = onInsert
        this.onOther = onOther
    }

    /// 处理一段字节。`buf` 可以是整块或切片，状态机只认 `[from, to)`。
    ///
    /// ⚠️ 多字节字符**可能跨块被切断**。但本扫描器**在字节层做词法判断**
    ///（引号/分号/注释符全是 ASCII，单字节），且**整条语句的字节累积完成后才解码**，
    /// 所以切断的多字节字符永远不会被单独解码，不存在乱码风险。
    func feed(buf: Array<Byte>, from: Int64, to: Int64): Unit {
        var i = from
        // 上一块若以引号收尾，出不出串要由本块首字节决定 —— 统一在这里结算，
        // 避免在 InSingle/InDouble 的推进函数里各写一半（那两处看不到对方）。
        if (i < to && quoteAtBlockEnd != 0u8) {
            let closing = quoteAtBlockEnd
            quoteAtBlockEnd = 0u8
            if (buf[i] == closing) {
                // 两个相邻引号 = 转义：上一个引号已在上一块入缓冲，这个补上，串继续。
                push(closing)
                i += 1
            } else {
                // 上一个引号是串尾：回到裸区，让主循环按裸区规则处理本块首字节。
                state = LexState.Bare
            }
        }
        while (i < to) {
            let b = buf[i]
            match (state) {
                case LexState.Bare => bareStep(b)
                case LexState.InSingle => singleStep(buf, i, to)
                case LexState.InDouble => doubleStep(buf, i, to)
                case LexState.InLineComment => lineCommentStep(b)
                case LexState.InBlockComment => blockCommentStep(b)
                case LexState.SawDash => sawDashStep(b)
                case LexState.SawSlash => sawSlashStep(b)
                case LexState.SawStarInBlock => starInBlockStep(b)
            }
            i += 1
        }
        consumed += to - from
    }

    /// 收尾：结算最后一条未以 `;` 结束的语句，并校验引号已闭合。
    func finish(): Unit {
        match (state) {
            case LexState.InSingle => throw SqlScanError(
                "文件结束时单引号串未闭合（基线被截断或含未支持语法）", consumed)
            case LexState.InDouble => throw SqlScanError(
                "文件结束时双引号标识符未闭合", consumed)
            case LexState.SawStarInBlock => throw SqlScanError(
                "文件结束时块注释未闭合", consumed)
            case _ => ()
        }
        if (!stmt.isEmpty()) {
            emitStatement()
        }
    }

    func toReport(): ScanReport {
        return ScanReport(consumed, stmtCount, insertCount, cellCount,
            multiCell, escCell, tables, colCounts)
    }

    // ---------------- 各状态的推进 ----------------

    private func bareStep(b: Byte): Unit {
        if (b == SEMI) {
            push(b)
            emitStatement()
            state = LexState.Bare
            return
        }
        if (b == Q) {
            state = LexState.InSingle
            push(b)
            return
        }
        if (b == DQ) {
            state = LexState.InDouble
            push(b)
            return
        }
        if (b == DASH) {
            state = LexState.SawDash
            push(b)
            return
        }
        if (b == SLASH) {
            state = LexState.SawSlash
            push(b)
            return
        }
        push(b)
    }

    /// `-` 后的第二字符：`-` 才是行注释，否则 `-` 本身是裸字符。
    private func sawDashStep(b: Byte): Unit {
        state = if (b == DASH) { LexState.InLineComment } else { LexState.Bare }
        push(b)
    }

    /// `/` 后的第二字符：`*` 才是块注释，否则 `/` 本身是裸字符。
    private func sawSlashStep(b: Byte): Unit {
        state = if (b == STAR) { LexState.InBlockComment } else { LexState.Bare }
        push(b)
    }

    /// 单引号串内推进。关键分支：`''` 是转义，**不出串**（实测 2,952 处）。
    ///
    /// 若收尾引号落在块末，**不做出串判定**，只置 `quoteAtBlockEnd`，
    /// 交由下一次 `feed` 入口统一结算（见那里的注释）。
    private func singleStep(buf: Array<Byte>, i: Int64, to: Int64): Unit {
        let b = buf[i]
        if (b != Q) {
            push(b)
            return
        }
        push(b)
        if (i + 1 < to) {
            // 下一字节在本块内：引号⇒转义，非引号⇒串尾。
            if (buf[i + 1] != Q) {
                state = LexState.Bare
            }
            return
        }
        quoteAtBlockEnd = Q
    }

    /// 双引号标识符内推进。`""` 是转义（同理）。
    private func doubleStep(buf: Array<Byte>, i: Int64, to: Int64): Unit {
        let b = buf[i]
        if (b != DQ) {
            push(b)
            return
        }
        push(b)
        if (i + 1 < to) {
            if (buf[i + 1] != DQ) {
                state = LexState.Bare
            }
            return
        }
        quoteAtBlockEnd = DQ
    }

    /// 行注释内推进：只认换行（兼容 `\r\n` 与裸 `\r`）。
    private func lineCommentStep(b: Byte): Unit {
        push(b)
        if (b == LF || b == CR) {
            state = LexState.Bare
        }
    }

    /// 块注释内推进：`*` 交给下一状态判定是否 `*/`。
    private func blockCommentStep(b: Byte): Unit {
        push(b)
        if (b == STAR) {
            state = LexState.SawStarInBlock
        }
    }

    /// 块注释内 `*` 之后：`/` 则闭合，否则留在块注释内。
    private func starInBlockStep(b: Byte): Unit {
        push(b)
        state = if (b == SLASH) { LexState.Bare } else { LexState.InBlockComment }
    }

    // ---------------- 语句缓冲 ----------------

    private func push(b: Byte): Unit {
        if (stmt.size >= MAX_STATEMENT_BYTES) {
            throw SqlScanError(
                "单条语句超过 ${MAX_STATEMENT_BYTES} 字节上限，请改为按表分片处理", consumed)
        }
        stmt.add(b)
    }

    /// 结算当前语句缓冲。
    ///
    /// ⚠️ **纯空白 + 注释不算一条语句**：Navicat 在文件末尾常留一行
    /// `-- 注释;` 之类残片（没有 `;` 结尾，靠 `finish()` 兜底结算）。
    /// 若把它计入 `statementCount` 并回调 `onOther`，会让「语句总数」这个
    /// 对账口径多出与业务无关的条目——所以这里先剥前导噪声，剥完为空就丢弃。
    private func emitStatement(): Unit {
        if (stmt.isEmpty()) {
            return
        }
        let text = decodeStmt(stmt.toArray())
        stmt = ArrayList<Byte>()
        let body = stripLeadingNoise(text)
        if (body.isEmpty()) {
            // 纯注释 / 空白残片：静默丢弃，不计数、不回调。
            return
        }
        stmtCount += 1
        match (classifyBody(body)) {
            // 注意：必须把「已剥掉前导空白/注释」的 body 交给 parseInsert，
            // 而非原始 text。ScanAcc 在每条语句缓冲头部会累计上一条语句末尾的
            // 换行（`;\n` 之后、`INSERT` 之前的空白同样进缓冲），使得 text 实际
            // 以空白（甚至 `--` 注释）开头。parseInsert 假定 text 以 INSERT 起手，
            // 若首字节是空白，首个 skipWord 为空操作，于是第二个 skipWord 会把
            // `INTO` 误读成表名，随后 `VALUES` 判定失败（E5 门禁崩溃的根因）。
            // classifyBody 已经 stripLeadingNoise 并确认 body 以 INSERT 起手，
            // 直接传 body 即可正确解析。
            case Some(tbl) => emitInsert(body, tbl)
            case None => onOther(text)
        }
    }

    private func decodeStmt(bytes: Array<Byte>): String {
        try {
            return String.fromUtf8(bytes)
        } catch (e: Exception) {
            // 非法 UTF-8：宁可显式报错，也不用 unchecked 静默产生乱码
            // ——乱码一旦进占位符替换流程，就是错数据落库。
            throw SqlScanError("语句不是合法 UTF-8：${e.message}", consumed)
        }
    }

    /// 解析 INSERT 并回调，同时累加计数。
    private func emitInsert(text: String, table: String): Unit {
        let st = parseInsert(text, table)
        insertCount += 1
        for (row in st.rows) {
            cellCount += row.size
            for (c in row) {
                noteCell(c)
            }
        }
        if (!tables.contains(table)) {
            tables.add(table)
        }
        // 记录该表观测到的列数。**同一表出现多种列数是基线的既有事实**
        // （多次导出叠加，见文件头「已知」段），此处只如实记录，不判失败。
        match (colCounts.get(table)) {
            case Some(set) =>
                for (row in st.rows) {
                    let c = row.size
                    if (!set.contains(c)) {
                        set.add(c)
                    }
                }
            case None =>
                let set = ArrayList<Int64>()
                for (row in st.rows) {
                    let c = row.size
                    if (!set.contains(c)) {
                        set.add(c)
                    }
                }
                colCounts.add(table, set)
        }
        onInsert(st)
    }

    private func noteCell(c: SqlCell): Unit {
        match (c.text) {
            case Some(v) =>
                if (v.contains("\n")) {
                    multiCell += 1
                }
                if (v.contains("'")) {
                    // 反转义后仍带 `'` ⇒ 原文里必然是 `''`，即发生了转义。
                    escCell += 1
                }
            case None => ()
        }
    }
}

// ===================== 语句解析 =====================

/// 剥掉语句开头的空白与注释，返回首个实义字符起的子串。
///
/// Navicat 会在每条 INSERT 前写 `-- ---- Records of xxx ----`，
/// 它们以换行结束而非 `;`，所以会并入下一条语句（R-28 的第四个坑）。
private func stripLeadingNoise(text: String): String {
    let runes = text.toRuneArray()
    let n = runes.size
    var i: Int64 = 0
    while (i < n) {
        let c = runes[i]
        if (isSpaceRune(c)) {
            i += 1
            continue
        }
        if (c == r'-') {
            if (i + 1 < n && runes[i + 1] == r'-') {
                i = skipLineRest(runes, i)
                continue
            }
            break
        }
        if (c == r'/') {
            if (i + 1 < n && runes[i + 1] == r'*') {
                i = skipBlockComment(runes, i)
                continue
            }
            break
        }
        break
    }
    if (i >= n) {
        return ""
    }
    return sliceRunes(runes, i, n)
}

private func isSpaceRune(c: Rune): Bool {
    return (c == r' ' || c == r'\t' || c == r'\n' || c == r'\r')
}

private func skipLineRest(runes: Array<Rune>, from: Int64): Int64 {
    var i = from
    let n = runes.size
    while (i < n) {
        if (runes[i] == r'\n') {
            return i + 1
        }
        i += 1
    }
    return n
}

private func skipBlockComment(runes: Array<Rune>, from: Int64): Int64 {
    var i = from + 2
    let n = runes.size
    while (i + 1 < n) {
        if (runes[i] == r'*' && runes[i + 1] == r'/') {
            return i + 2
        }
        i += 1
    }
    return n
}

private func sliceRunes(runes: Array<Rune>, from: Int64, to: Int64): String {
    let sb = StringBuilder()
    var i = from
    while (i < to) {
        sb.append(runes[i])
        i += 1
    }
    return sb.toString()
}

/// 判定语句类型。入参 `body` 是**已剥掉前导注释与空白**的语句首部
/// （`parseInsertTable` 内部自带原文用于报错信息，故无需再传原文）。
///
/// 返回 `Some(表名)` 表示是 INSERT，否则 `None`。
private func classifyBody(body: String): Option<String> {
    if (body.isEmpty()) {
        return None<String>
    }
    if (!startsWithKeyword(body, KW_INSERT)) {
        return None<String>
    }
    return parseInsertTable(body)
}

/// 大小写不敏感地判断 `text` 是否以关键字 `kw` 开头，且其后不是标识符字符。
///
/// ⚠️ **逐字节比较，不用 `text[0..kw.size]` 切片**：
/// `String[Range<Int64>]` 在「起止点不是字符边界」时会抛 `IllegalArgumentException`
/// （CangjieSkills `references/api/std/core/structs/string/operator-indexer.md`），
/// 而本函数的入参是**整条 SQL 语句**——Navicat 注释、`--` 残片都可能让它以非 ASCII
/// 开头，那种情况下切片必炸。改用 `String[Int64]: Byte` 取单字节，天然无边界问题。
///
/// 关键字全为 ASCII（`KW_INSERT`/`KW_INTO`/`KW_VALUES`），所以
/// 「字节长度 == 字符数」，末尾的标识符判定用字节下标即可。
private func startsWithKeyword(text: String, kw: String): Bool {
    let n = kw.size
    if (text.size < n) {
        return false
    }
    var i: Int64 = 0
    while (i < n) {
        if (upperAsciiByte(text[i]) != kw[i]) {
            return false
        }
        i += 1
    }
    if (text.size == n) {
        return true
    }
    return !isIdentByte(text[n])
}

/// ASCII 字母转大写；非 ASCII 字节（>= 0x80）原样返回。
private func upperAsciiByte(b: Byte): Byte {
    if (b >= 97u8 && b <= 122u8) {
        return b - 32u8
    }
    return b
}

/// 字节是否可能落在标识符字符上。
///
/// `>= 0x80` 的字节按 UTF-8 续字节处理，一律算「非标识符」——
/// 关键字后面紧跟多字节字符本来就该判定为「关键字结束」。
private func isIdentByte(b: Byte): Bool {
    return ((b >= 97u8 && b <= 122u8) || (b >= 65u8 && b <= 90u8) ||
        (b >= 48u8 && b <= 57u8) || b == 95u8)
}

private func isIdentRune(c: Rune): Bool {
    return ((c >= r'a' && c <= r'z') || (c >= r'A' && c <= r'Z') ||
        (c >= r'0' && c <= r'9') || c == r'_')
}

/// 从 `INSERT INTO <表名> ...` 中取出表名，剥掉 `"schema".` 前缀与双引号。
///
/// 形如 `INSERT INTO "public"."agent_executors" VALUES (...)` ⇒ `agent_executors`。
private func parseInsertTable(body: String): Option<String> {
    let runes = body.toRuneArray()
    // 跳过 INSERT 与其后的 INTO
    var i = skipWord(runes, 0)
    i = skipSpaces(runes, i)
    if (!matchWordAt(runes, i, KW_INTO)) {
        throw SqlScanError("INSERT 语句缺少 INTO：${preview(body)}", -1)
    }
    i = skipWord(runes, i)
    i = skipSpaces(runes, i)
    let qn = readQualifiedName(runes, i)
    if (qn.name.isEmpty()) {
        throw SqlScanError("INSERT 语句无法解析表名：${preview(body)}", -1)
    }
    return Some(qn.name)
}

/// 一个限定名的解析结果。
private struct QualifiedName {
    /// 剥掉 schema 与双引号后的表名。
    let name: String
    /// 解析结束后的下标。
    let end: Int64

    init(name: String, end: Int64) {
        this.name = name
        this.end = end
    }
}

/// 读 `schema.table`（最多两段），返回表名本体与结束下标。
private func readQualifiedName(runes: Array<Rune>, from: Int64): QualifiedName {
    var i = from
    var last = ""
    var seg: Int64 = 0
    while (seg < 2 && i < runes.size) {
        let part = readNameToken(runes, i)
        if (part.text.isEmpty()) {
            break
        }
        last = part.text
        i = part.end
        if (i < runes.size && runes[i] == r'.') {
            i += 1
            seg += 1
            continue
        }
        break
    }
    return QualifiedName(last, i)
}

/// 一段标识符的解析结果。
private struct NameToken {
    /// 已剥掉双引号的标识符文本。
    let text: String
    /// 结束下标（不含）。
    let end: Int64

    init(text: String, end: Int64) {
        this.text = text
        this.end = end
    }
}

/// 读一段标识符（可带双引号）。
private func readNameToken(runes: Array<Rune>, from: Int64): NameToken {
    let n = runes.size
    if (from >= n) {
        return NameToken("", from)
    }
    if (runes[from] == r'"') {
        var j = from + 1
        let sb = StringBuilder()
        while (j < n) {
            if (runes[j] == r'"') {
                if (j + 1 < n && runes[j + 1] == r'"') {
                    sb.append(r'"')
                    j += 2
                    continue
                }
                return NameToken(sb.toString(), j + 1)
            }
            sb.append(runes[j])
            j += 1
        }
        throw SqlScanError("双引号标识符未闭合", -1)
    }
    let sb = StringBuilder()
    var j = from
    while (j < n && isIdentRune(runes[j])) {
        sb.append(runes[j])
        j += 1
    }
    return NameToken(sb.toString(), j)
}

private func skipSpaces(runes: Array<Rune>, from: Int64): Int64 {
    var i = from
    let n = runes.size
    while (i < n && isSpaceRune(runes[i])) {
        i += 1
    }
    return i
}

private func skipWord(runes: Array<Rune>, from: Int64): Int64 {
    var i = from
    let n = runes.size
    while (i < n && isIdentRune(runes[i])) {
        i += 1
    }
    return i
}

/// 判断 `runes` 在 `at` 处是否（区分大小写地）等于关键字 `kw`。
private func matchWordAt(runes: Array<Rune>, at: Int64, kw: String): Bool {
    let kwRunes = kw.toRuneArray()
    let n = runes.size
    if (at + kwRunes.size > n) {
        return false
    }
    var k: Int64 = 0
    while (k < kwRunes.size) {
        if (runes[at + k] != kwRunes[k]) {
            return false
        }
        k += 1
    }
    return true
}

/// 截取语句前 80 字符用于报错信息（压掉换行，避免污染日志）。
private func preview(text: String): String {
    let flat = text.replace("\n", " ").replace("\r", " ").trimAscii()
    let runes = flat.toRuneArray()
    if (runes.size <= 80) {
        return flat
    }
    return sliceRunes(runes, 0, 80) + "…"
}

/// 一段解析结果 + 结束下标。用 struct 承载，**不用全局游标**
/// （全局可变游标在重入场景下会互相污染）。
private struct TupleRead {
    /// 该元组的单元格。
    let cells: ArrayList<SqlCell>
    /// 结束下标（指向 `)` 之后）。
    let next: Int64

    init(cells: ArrayList<SqlCell>, next: Int64) {
        this.cells = cells
        this.next = next
    }
}

/// 一段列清单解析结果 + 结束下标。
private struct ColumnRead {
    /// 列名清单。
    let names: ArrayList<String>
    /// 结束下标（指向 `)` 之后）。
    let next: Int64

    init(names: ArrayList<String>, next: Int64) {
        this.names = names
        this.next = next
    }
}

/// 把一条 INSERT 语句解析成表名 + 各行单元格。
private func parseInsert(text: String, table: String): InsertStatement {
    let runes = text.toRuneArray()
    // 跳过 INSERT INTO <表名>
    var i = skipWord(runes, 0)
    i = skipSpaces(runes, i)
    i = skipWord(runes, i)
    i = skipSpaces(runes, i)
    let qn = readQualifiedName(runes, i)
    i = skipSpaces(runes, qn.end)
    // 可选列清单 `INSERT INTO t (a,b) VALUES ...`
    var columns = ArrayList<String>()
    if (i < runes.size && runes[i] == r'(') {
        let cr = readColumnList(runes, i)
        columns = cr.names
        i = skipSpaces(runes, cr.next)
    }
    if (!matchWordAt(runes, i, KW_VALUES)) {
        throw SqlScanError("INSERT 语句缺少 VALUES：${preview(text)}", -1)
    }
    i = skipWord(runes, i)
    let rows = readValueRows(runes, i, text)
    return InsertStatement(table, columns, rows)
}

/// 读 `VALUES` 之后的所有元组。
private func readValueRows(runes: Array<Rune>, from: Int64, text: String): ArrayList<ArrayList<SqlCell>> {
    let rows = ArrayList<ArrayList<SqlCell>>()
    let n = runes.size
    var i = skipSpaces(runes, from)
    while (i < n && runes[i] == r'(') {
        let tr = readTuple(runes, i, text)
        rows.add(tr.cells)
        i = skipSpaces(runes, tr.next)
        // 元组之间是逗号
        if (i < n && runes[i] == r',') {
            i = skipSpaces(runes, i + 1)
            continue
        }
        break
    }
    if (rows.isEmpty()) {
        throw SqlScanError("INSERT 语句没有可解析的 VALUES 元组：${preview(text)}", -1)
    }
    return rows
}

/// 读一个 `(...)` 元组。
private func readTuple(runes: Array<Rune>, open: Int64, text: String): TupleRead {
    let cells = ArrayList<SqlCell>()
    let n = runes.size
    var i = open + 1
    var depth: Int64 = 0
    var inStr = false
    var sb = StringBuilder()      // 引号外的裸字面量累积
    var qs = StringBuilder()      // 引号内的字符串内容（含引号本身）
    var started = false
    while (i < n) {
        let c = runes[i]
        if (inStr) {
            qs.append(c)
            if (c == r'\'') {
                if (i + 1 < n && runes[i + 1] == r'\'') {
                    // `''` 转义：把第二个引号也吃掉，绝不在这里出串
                    qs.append(r'\'')
                    i += 2
                    continue
                }
                inStr = false
                addQuotedCell(cells, qs)
                qs = StringBuilder()
                started = false
            }
            i += 1
            continue
        }
        if (c == r'\'') {
            inStr = true
            started = true
            qs.append(c)
            i += 1
            continue
        }
        if (c == r'(') {
            depth += 1
            started = true
            sb.append(c)
            i += 1
            continue
        }
        if (c == RPAREN_RUNE) {
            if (depth > 0) {
                depth -= 1
                started = true
                sb.append(c)
                i += 1
                continue
            }
            addBareCell(cells, sb, started)
            return TupleRead(cells, i + 1)
        }
        if (c == r',' && depth == 0) {
            addBareCell(cells, sb, started)
            sb = StringBuilder()
            started = false
            i += 1
            continue
        }
        started = true
        sb.append(c)
        i += 1
    }
    throw SqlScanError("INSERT 元组未闭合：${preview(text)}", -1)
}

/// 收尾一个引号单元格：剥掉外层引号并把 `''` 反转义为 `'`。
private func addQuotedCell(cells: ArrayList<SqlCell>, qs: StringBuilder): Unit {
    let runes = qs.toString().toRuneArray()
    // 去掉首个与末个引号
    if (runes.size < 2) {
        // 形态异常（只有一个引号）：如实记为空串，不静默丢弃。
        cells.add(SqlCell(Some(""), LiteralKind.Quoted, ""))
        return
    }
    let inner = sliceRunes(runes, 1, runes.size - 1)
    cells.add(SqlCell(Some(inner.replace("''", "'")), LiteralKind.Quoted, inner))
}

/// 收尾一个非引号单元格：区分 SQL NULL、空位与裸值。
private func addBareCell(cells: ArrayList<SqlCell>, sb: StringBuilder, started: Bool): Unit {
    let raw = sb.toString().trimAscii()
    if (!started || raw.isEmpty()) {
        // 连续逗号产生的空位：如实记为 NULL，不静默丢列（否则列数对不上）
        cells.add(SqlCell(None<String>, LiteralKind.SqlNull, "NULL"))
        return
    }
    if (raw.toAsciiUpper() == "NULL") {
        cells.add(SqlCell(None<String>, LiteralKind.SqlNull, "NULL"))
        return
    }
    cells.add(SqlCell(None<String>, LiteralKind.Bare, raw))
}

/// 读可选的列清单 `(a, b, c)`。
private func readColumnList(runes: Array<Rune>, open: Int64): ColumnRead {
    let cols = ArrayList<String>()
    let n = runes.size
    var i = open + 1
    var sb = StringBuilder()
    var inStr = false
    while (i < n) {
        let c = runes[i]
        if (inStr) {
            if (c == r'"') {
                if (i + 1 < n && runes[i + 1] == r'"') {
                    sb.append(r'"')
                    i += 2
                    continue
                }
                inStr = false
                cols.add(sb.toString())
                sb = StringBuilder()
                i += 1
                continue
            }
            sb.append(c)
            i += 1
            continue
        }
        if (c == r'"') {
            inStr = true
            i += 1
            continue
        }
        if (c == RPAREN_RUNE) {
            return ColumnRead(cols, i + 1)
        }
        i += 1
    }
    throw SqlScanError("INSERT 列清单未闭合", -1)
}

// ===================== 自检（T040 验收用例） =====================

/// 自检用的收集器。
///
/// 把回调**预绑定成成员函数**再交给 `scanSqlText`，避免在 lambda 里给外层
/// `var` 赋值——那是仓颉明令禁止的「捕获 var 的闭包逃逸」。
///
/// ⚠️ 回调体里**不写 `this.xxx`**：仓颉规定「`this` 不能被 Lambda 或嵌套函数
/// 捕获」（`struct` 文档 §mut-函数中-this-的限制），访问实例成员也算捕获。
/// 所以回调一律转调顶层函数 `sinkAbsorb(sink, st)` / `sinkCountOther(sink)`，
/// 收集器只作为普通参数传出去。
private class ScanSink {
    /// 按出现顺序记录表名。
    let tables = ArrayList<String>()
    /// 每张表第一条 INSERT 的单元格（验收样例每表只 1 条）。
    let firstRow = HashMap<String, ArrayList<SqlCell>>()
    /// 非 INSERT 语句计数。
    var otherCount: Int64 = 0
}

/// 记录一条 INSERT（顶层函数，避免 lambda 捕获 `this`）。
private func sinkAbsorb(sink: ScanSink, st: InsertStatement): Unit {
    if (!sink.tables.contains(st.table)) {
        sink.tables.add(st.table)
    }
    match (sink.firstRow.get(st.table)) {
        case Some(_) => ()
        case None =>
            if (!st.rows.isEmpty()) {
                sink.firstRow.add(st.table, st.rows[0])
            }
    }
}

/// 记录一条非 INSERT 语句。
private func sinkCountOther(sink: ScanSink): Unit {
    sink.otherCount += 1
}

/// 取某张表首行的单元格；未采集到返回空列表（调用方按越界处理）。
private func cellsOf(sink: ScanSink, table: String): ArrayList<SqlCell> {
    match (sink.firstRow.get(table)) {
        case Some(cells) => return cells
        case None => return ArrayList<SqlCell>()
    }
}

/// T040 验收：构造含 `'` 转义、`\n`、`,`、`)`,`;` 的样例，校验切分正确。
///
/// 为什么不写 `_test.cj`：`installer` 是 `output-type = "executable"` 且
/// `package-configuration = {}`，**没有 test target**，仓颉测试框架跑不起来。
/// 所以做成自检函数，由 CLI 的 `seed verify` 调用——顺带满足 M13 的
/// 「所有检查类能力提供 `--json`」要求（G-8）。
///
/// 覆盖的正是四个最容易写错的分支：
///   ① `''` 转义不撕裂字符串；
///   ② 字符串内的 `\n` 不截断语句；
///   ③ 字符串内的 `,` / `)` / `;` 不参与结构切分；
///   ④ 前导 `-- Records of x` 注释被剥离后才判定 INSERT。
///
/// @return 全部通过返回空列表；否则逐条列出「用例名 / 期望 / 实际」。
public func scanSelfCheck(): ArrayList<String> {
    let fails = ArrayList<String>()
    let sample =
        "-- ----------------------------\n" +
        "-- Records of t\n" +
        "-- ----------------------------\n" +
        "INSERT INTO \"public\".\"t\" VALUES " +
        "('a''b', 'line1\nline2', 'has,comma', 'has)paren', 'has;semi', NULL, '中文', 42, true);\n" +
        "CREATE TABLE \"public\".\"x\" (\"a\" text);\n" +
        "INSERT INTO \"public\".\"u\" VALUES ('p;r', 'q,r', 's)t'); -- 尾注释里的 ; 不算\n"
    // ⚠️ 这里有两处仓颉闭包限制 dictates 的写法，都不是随意的：
    //
    //   ① **不能用局部 `var` + lambda 赋值**：仓颉规定「捕获局部 `var` 的闭包
    //      不能逃逸（不能赋给变量、返回、作为参数传递），只能立即调用」。
    //      本例的 lambda 要传给 `scanSqlText`，用 `var` 必然编译失败 ⇒ 改用
    //      `class` 收集器（引用类型），把要改的状态放进它的字段。
    //   ② **lambda 里不能写 `this`**：仓颉规定「`this` 不能被 Lambda 或嵌套函数
    //      捕获」，访问实例成员同样算捕获。所以回调体一律转调顶层函数，
    //      把 `sink` 作为**普通参数**显式传出去，绝不出现 `this`。
    let sink = ScanSink()
    // `try` 的两个分支必须同类型，所以 catch 里返回 `None<ScanReport>` 而不是
    // 直接 `return fails`（return 分支的类型是 Never，与 ScanReport 不统一）。
    // 写法对齐 `platform/net.cj:194` 的 Option 包裹惯例。
    let maybeReport = try {
        Some(scanSqlText(sample,
            { st: InsertStatement => sinkAbsorb(sink, st) },
            // 参数名不用 `_`：本仓 lambda 先例要么 `{ _ => }`（无类型标注），
            // 要么 `{ a: T => }`（有类型标注），`_` 与类型标注混用没有先例，
            // 保守起见给个占位名。
            { _other: String => sinkCountOther(sink) }))
    } catch (e: SqlScanError) {
        fails.add("scanSelfCheck/不应抛错: ${e.reason}")
        None<ScanReport>
    }
    let r = match (maybeReport) {
        case Some(v) => v
        case None => return fails
    }
    let tables = sink.tables
    let cellsT = cellsOf(sink, "t")
    let cellsU = cellsOf(sink, "u")
    let otherCount = sink.otherCount.toString()

    // ① 语句数：3 条真语句；尾部纯注释残片**不计入**。
    expectEq(fails, "语句数", "3", r.statementCount.toString())
    // ② INSERT 数 2；其它（CREATE TABLE）1。
    expectEq(fails, "INSERT 语句数", "2", r.insertCount.toString())
    expectEq(fails, "非 INSERT 语句数", "1", otherCount)
    // ③ 表名解析：剥掉 "public". 前缀。
    expectEq(fails, "表名1", "t", joinStrings(tables, 0))
    expectEq(fails, "表名2", "u", joinStrings(tables, 1))
    // ④ 单元格切分：9 个，含 NULL / 数字 / 中文 / 四个「含结构字符」的串。
    expectEq(fails, "t 列数", "9", cellsT.size.toString())
    // ⑤ `''` 反转义 ⇒ a'b
    expectEq(fails, "转义还原", "a'b", cellTextOf(cellsT, 0))
    // ⑥ 内嵌换行完整保留
    expectEq(fails, "内嵌换行", "line1\nline2", cellTextOf(cellsT, 1))
    // ⑦ 串内 `,` 不切分
    expectEq(fails, "串内逗号", "has,comma", cellTextOf(cellsT, 2))
    // ⑧ 串内 `)` 不切分
    expectEq(fails, "串内右括号", "has)paren", cellTextOf(cellsT, 3))
    // ⑨ 串内 `;` 不切分
    expectEq(fails, "串内分号", "has;semi", cellTextOf(cellsT, 4))
    // ⑩ 第 6 格是 SQL NULL（不是字符串 "NULL"）
    expectEq(fails, "SQL NULL", "null", literalKindCode(cellKindOf(cellsT, 5)))
    // ⑪ 中文按字符完整保留（AC-206）
    expectEq(fails, "中文", "中文", cellTextOf(cellsT, 6))
    // ⑫ 裸字面量（数字）不进 text，只留 Bare 形态
    expectEq(fails, "裸字面量形态", "bare", literalKindCode(cellKindOf(cellsT, 7)))
    // ⑬ 第二条：3 列，串内 `;` `,` `)` 均不切分
    expectEq(fails, "u 列数", "3", cellsU.size.toString())
    expectEq(fails, "u 串内分号", "p;r", cellTextOf(cellsU, 0))
    expectEq(fails, "u 串内逗号", "q,r", cellTextOf(cellsU, 1))
    expectEq(fails, "u 串内右括号", "s)t", cellTextOf(cellsU, 2))
    return fails
}

private func expectEq(fails: ArrayList<String>, name: String, expect: String, actual: String): Unit {
    if (expect != actual) {
        fails.add("scanSelfCheck/${name}: 期望 ${expect}，实际 ${actual}")
    }
}

/// 取列表第 `at` 项；越界返回可读的标记而不是抛异常——
/// 自检里越界本身就是失败信息的一部分，不该被异常吞掉。
private func joinStrings(items: ArrayList<String>, at: Int64): String {
    if (at < 0 || at >= items.size) {
        return "<越界>"
    }
    return items[at]
}

private func cellTextOf(cells: ArrayList<SqlCell>, at: Int64): String {
    if (at < 0 || at >= cells.size) {
        return "<越界>"
    }
    match (cells[at].text) {
        case Some(t) => return t
        case None => return "<无 text>"
    }
}

private func cellKindOf(cells: ArrayList<SqlCell>, at: Int64): LiteralKind {
    if (at < 0 || at >= cells.size) {
        return LiteralKind.SqlNull
    }
    return cells[at].kind
}