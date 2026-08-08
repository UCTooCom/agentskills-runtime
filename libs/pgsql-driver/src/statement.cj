/*
 * statement.cj —— 预处理语句（扩展查询协议）。
 *
 * 构造时即向服务器 Parse + Describe，获得参数与结果列的元信息；
 * 每次 query/update 执行 Bind + Execute + Sync。
 * 占位符遵循 std 约定使用 `?`，内部转换为 PostgreSQL 的 `$1,$2,...`。
 */

package pgsql

import std.collection.*
import std.convert.*
import std.database.sql.*

// 单个参数槽位的状态。
enum ParamValue {
    | Unset                // 尚未赋值
    | NullValue            // 显式 SQL NULL
    | BoundValue(BoundParam) // 已编码的绑定参数（文本或二进制）
}

/**
 * 预处理语句实现。绑定到创建它的 [PgConnection]。
 */
public class PgStatement <: Statement {
    private let conn: PgConnection
    private let stmtName: String
    private let paramOids: Array<Int32>
    private let resultCols: Array<ColumnInfo>
    private let resultOids: Array<Int32>
    private var params: Array<ParamValue>
    private var closed: Bool = false
    private let stmtOptions: HashMap<String, String> = HashMap<String, String>()

    /**
     * 解析 SQL 并完成服务端 Parse/Describe。
     *
     * @param conn 所属连接。
     * @param sql 含 `?` 占位符的 SQL。
     */
    public init(conn: PgConnection, sql: String) {
        this.conn = conn
        this.stmtName = conn.nextStatementName()
        // 将 `?` 占位符转换为 `$1,$2,...`。
        let (converted, _) = convertPlaceholders(sql)
        let (pOids, cols, cOids) = conn.parseAndDescribe(stmtName, converted)
        this.paramOids = pOids
        this.resultCols = cols
        this.resultOids = cOids
        this.params = Array<ParamValue>(pOids.size, repeat: Unset)
    }

    /** 占位参数的列信息（名称形如 `$1`）。 */
    public prop parameterColumnInfos: Array<ColumnInfo> {
        get() {
            let arr = Array<ColumnInfo>(paramOids.size, {i => PgColumnInfo("\$${i + 1}", paramOids[i], 0, -1)})
            return arr
        }
    }

    /**
     * 设置第 index 个参数（0 基）为指定原生类型的值。
     */
    public func set<T>(index: Int64, value: T): Unit {
        checkParamIndex(index)
        params[index] = BoundValue(encodeParam<T>(value))
    }

    /** 将第 index 个参数设置为 SQL NULL。 */
    public func setNull(index: Int64): Unit {
        checkParamIndex(index)
        params[index] = NullValue
    }

    /** 设置语句选项（当前仅记录，不影响执行）。 */
    public func setOption(key: String, value: String): Unit {
        stmtOptions[key] = value
    }

    /**
     * 执行查询语句，返回结果集。
     */
    public func query(): QueryResult {
        ensureOpen()
        let resolved = resolveParams()
        let (rows, _) = conn.bindAndExecute(stmtName, resolved)
        resetParams()
        return PgQueryResult(resultCols, resultOids, rows)
    }

    /**
     * 执行更新语句，返回受影响行数等信息。
     */
    public func update(): UpdateResult {
        ensureOpen()
        let resolved = resolveParams()
        let (_, tag) = conn.bindAndExecute(stmtName, resolved)
        resetParams()
        return parseCommandTag(tag)
    }

    // std.database.sql 接口仍声明了基于已废弃 SqlDbType 的重载（无默认实现，必须提供）。
    // 本驱动不支持该已废弃形态，请改用原生类型的 set<T> + query()/update()。
    @Deprecated["not supported; use set<T> with query()"]
    public func query(_: Array<SqlDbType>): QueryResult {
        throw SqlException("SqlDbType-based query() is not supported; use set<T> then query()")
    }

    @Deprecated["not supported; use set<T> with update()"]
    public func update(_: Array<SqlDbType>): UpdateResult {
        throw SqlException("SqlDbType-based update() is not supported; use set<T> then update()")
    }

    /** 关闭语句，释放服务端预处理资源。 */
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        conn.closePreparedStatement(stmtName)
    }

    /** 语句是否已关闭。 */
    public func isClosed(): Bool {
        return closed
    }

    // 将参数槽位解析为可发送的绑定参数数组，遇到未赋值参数即报错。
    private func resolveParams(): Array<BoundParam> {
        let out = Array<BoundParam>(params.size, repeat: BoundParam(0, None))
        for (i in 0..params.size) {
            match (params[i]) {
                case Unset => throw SqlException("no value specified for parameter ${i + 1}")
                case NullValue => out[i] = BoundParam(0, None)
                case BoundValue(bp) => out[i] = bp
            }
        }
        return out
    }

    // 执行后清空参数，要求每次执行前重新赋值（与 std 样例语义一致）。
    private func resetParams(): Unit {
        for (i in 0..params.size) {
            params[i] = Unset
        }
    }

    private func checkParamIndex(index: Int64): Unit {
        if (index < 0 || index >= params.size) {
            throw SqlException("parameter index ${index} out of range [0, ${params.size})")
        }
    }

    private func ensureOpen(): Unit {
        if (closed) {
            throw SqlException("statement is closed")
        }
    }
}

/**
 * 解析 CommandComplete 命令标签，提取受影响行数与最后插入 id。
 *
 * 标签形如 "INSERT 0 5"、"UPDATE 3"、"DELETE 2"、"SELECT 10"。
 */
func parseCommandTag(tag: String): PgUpdateResult {
    let parts = tag.split(" ", removeEmpty: true)
    var rowCount: Int64 = 0
    if (parts.size > 0) {
        // 最后一个数字段即受影响行数。
        rowCount = tryParseInt(parts[parts.size - 1])
    }
    // PostgreSQL 不再返回 OID，lastInsertId 恒为 0；自增主键请用 RETURNING。
    return PgUpdateResult(rowCount, 0)
}

// 尝试将字符串解析为 Int64，失败返回 0。
func tryParseInt(s: String): Int64 {
    try {
        return Int64.parse(s)
    } catch (_: Exception) {
        return 0
    }
}

/**
 * 将 `?` 占位符转换为 PostgreSQL 的 `$1,$2,...`。
 *
 * 会跳过单引号字符串、双引号标识符、行注释（--）与块注释（/* */）中的 `?`。
 *
 * @param sql 原始 SQL。
 * @return (转换后 SQL, 参数个数)。
 */
func convertPlaceholders(sql: String): (String, Int64) {
    // 在字节层处理：所有结构性字符（' " - / * ? 换行）均为单字节 ASCII，
    // 与 UTF-8 多字节序列（高位字节 >= 0x80）不会冲突，故无需逐 Rune 解析。
    let chars = sql.toArray()
    let out = ArrayList<Byte>()
    var paramIndex: Int64 = 0
    var i = 0
    let n = chars.size
    while (i < n) {
        let c = chars[i]
        if (c == b'\'') {
            // 单引号字符串：直到配对的单引号（'' 为转义）。
            out.add(c)
            i += 1
            while (i < n) {
                out.add(chars[i])
                if (chars[i] == b'\'') {
                    i += 1
                    break
                }
                i += 1
            }
        } else if (c == b'"') {
            // 双引号标识符。
            out.add(c)
            i += 1
            while (i < n) {
                out.add(chars[i])
                if (chars[i] == b'"') {
                    i += 1
                    break
                }
                i += 1
            }
        } else if (c == b'-' && i + 1 < n && chars[i + 1] == b'-') {
            // 行注释：直到行尾。
            while (i < n && chars[i] != b'\n') {
                out.add(chars[i])
                i += 1
            }
        } else if (c == b'/' && i + 1 < n && chars[i + 1] == b'*') {
            // 块注释：直到 */。
            out.add(chars[i])
            out.add(chars[i + 1])
            i += 2
            while (i < n) {
                if (chars[i] == b'*' && i + 1 < n && chars[i + 1] == b'/') {
                    out.add(chars[i])
                    out.add(chars[i + 1])
                    i += 2
                    break
                }
                out.add(chars[i])
                i += 1
            }
        } else if (c == b'?') {
            // 占位符：替换为 $n。
            paramIndex += 1
            out.add(all: "\$${paramIndex}".toArray())
            i += 1
        } else {
            out.add(c)
            i += 1
        }
    }
    return (String.fromUtf8(out.toArray()), paramIndex)
}
