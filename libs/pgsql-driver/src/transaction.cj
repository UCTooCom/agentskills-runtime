/*
 * transaction.cj —— 数据库事务，基于简单查询协议发送事务控制语句。
 *
 * 通过 BEGIN / COMMIT / ROLLBACK / SAVEPOINT / RELEASE 等 SQL 实现，
 * 支持设置隔离级别、读写模式与延迟模式，并支持保存点。
 */

package pgsql

import std.collection.*
import std.database.sql.*

/**
 * 事务实现。由 [PgConnection.createTransaction] 创建，创建即占用连接的事务名额，
 * 不支持在同一连接上并行多个事务。
 */
public class PgTransaction <: Transaction {
    private let conn: PgConnection
    private var accessModeVal: TransactionAccessMode = TransactionAccessMode.Unspecified
    private var deferrableModeVal: TransactionDeferrableMode = TransactionDeferrableMode.Unspecified
    private var isoLevelVal: TransactionIsoLevel = TransactionIsoLevel.Unspecified
    private var started: Bool = false
    private var finished: Bool = false

    public init(conn: PgConnection) {
        this.conn = conn
        // 占用连接的事务名额；若已有活动事务则抛异常。
        conn.beginTransactionObject()
    }

    /** 事务访问模式（只读 / 读写）。 */
    public mut prop accessMode: TransactionAccessMode {
        get() {
            accessModeVal
        }
        set(v) {
            accessModeVal = v
        }
    }

    /** 事务延迟模式。 */
    public mut prop deferrableMode: TransactionDeferrableMode {
        get() {
            deferrableModeVal
        }
        set(v) {
            deferrableModeVal = v
        }
    }

    /** 事务隔离级别。 */
    public mut prop isoLevel: TransactionIsoLevel {
        get() {
            isoLevelVal
        }
        set(v) {
            isoLevelVal = v
        }
    }

    /**
     * 开始事务，按当前隔离级别 / 访问模式 / 延迟模式拼装 BEGIN 语句。
     */
    public func begin(): Unit {
        if (started) {
            throw SqlException("transaction already started")
        }
        if (finished) {
            throw SqlException("transaction already finished")
        }
        let sb = StringBuilder()
        sb.append("BEGIN")
        if (let Some(level) <- isoLevelClause()) {
            sb.append(" ISOLATION LEVEL ")
            sb.append(level)
        }
        if (let Some(mode) <- accessModeClause()) {
            sb.append(" ")
            sb.append(mode)
        }
        if (let Some(defer) <- deferrableClause()) {
            sb.append(" ")
            sb.append(defer)
        }
        conn.executeSimple(sb.toString())
        started = true
    }

    /** 提交事务。 */
    public func commit(): Unit {
        ensureActive()
        conn.executeSimple("COMMIT")
        finish()
    }

    /** 回滚整个事务。 */
    public func rollback(): Unit {
        ensureActive()
        conn.executeSimple("ROLLBACK")
        finish()
    }

    /** 回滚到指定保存点（不结束事务）。 */
    public func rollback(savePointName: String): Unit {
        ensureActive()
        conn.executeSimple("ROLLBACK TO SAVEPOINT ${quoteIdent(savePointName)}")
    }

    /** 在事务中创建保存点。 */
    public func save(savePointName: String): Unit {
        ensureActive()
        conn.executeSimple("SAVEPOINT ${quoteIdent(savePointName)}")
    }

    /** 销毁先前定义的保存点。 */
    public func release(savePointName: String): Unit {
        ensureActive()
        conn.executeSimple("RELEASE SAVEPOINT ${quoteIdent(savePointName)}")
    }

    // 提交/回滚后归还事务名额并标记结束。
    private func finish(): Unit {
        finished = true
        started = false
        conn.endTransactionObject()
    }

    // 保存点等操作要求事务已开始且未结束。
    private func ensureActive(): Unit {
        if (!started) {
            throw SqlException("transaction has not been started; call begin() first")
        }
        if (finished) {
            throw SqlException("transaction has already been committed or rolled back")
        }
    }

    // 将隔离级别映射为 SQL 子句，Unspecified / 不支持的级别返回 None（采用服务器默认）。
    private func isoLevelClause(): ?String {
        if (isoLevelVal == TransactionIsoLevel.ReadUncommitted) {
            return "READ UNCOMMITTED"
        } else if (isoLevelVal == TransactionIsoLevel.ReadCommitted) {
            return "READ COMMITTED"
        } else if (isoLevelVal == TransactionIsoLevel.RepeatableRead ||
            isoLevelVal == TransactionIsoLevel.Snapshot) {
            // PostgreSQL 的快照隔离等价于 REPEATABLE READ。
            return "REPEATABLE READ"
        } else if (isoLevelVal == TransactionIsoLevel.Serializable ||
            isoLevelVal == TransactionIsoLevel.Linearizable) {
            return "SERIALIZABLE"
        }
        return None
    }

    private func accessModeClause(): ?String {
        if (accessModeVal == TransactionAccessMode.ReadOnly) {
            return "READ ONLY"
        } else if (accessModeVal == TransactionAccessMode.ReadWrite) {
            return "READ WRITE"
        }
        return None
    }

    private func deferrableClause(): ?String {
        if (deferrableModeVal == TransactionDeferrableMode.Deferrable) {
            return "DEFERRABLE"
        } else if (deferrableModeVal == TransactionDeferrableMode.NotDeferrable) {
            return "NOT DEFERRABLE"
        }
        return None
    }
}

/**
 * 将标识符用双引号安全包裹（内部双引号翻倍转义），用于保存点名等。
 */
func quoteIdent(name: String): String {
    // 在字节层处理以保持 UTF-8 正确性：仅把双引号字节翻倍，其余字节原样保留。
    let out = ArrayList<Byte>()
    out.add(b'"')
    for (b in name.toArray()) {
        if (b == b'"') {
            out.add(b'"')
            out.add(b'"')
        } else {
            out.add(b)
        }
    }
    out.add(b'"')
    return String.fromUtf8(out.toArray())
}
