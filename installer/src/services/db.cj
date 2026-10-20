package uc_installer.services

import pgsql.{PgDatasource, registerDriver}
import std.database.sql.{Connection, Statement, QueryResult}
import std.collection.HashMap

/// 写入 uctoo_user 后回读的管理员记录。
public struct AdminRow {
    public let id: Int64
    public let name: String
    public let username: String
    public let email: String
    public init(id: Int64, name: String, username: String, email: String) {
        this.id = id
        this.name = name
        this.username = username
        this.email = email
    }
}

/// 直连 PostgreSQL 的管理员仓储（design.md §4.7）。
public class AdminRepo {
    private let ds: PgDatasource

    public init(host: String, port: UInt16, db: String, user: String, pwd: String) {
        registerDriver()
        ds = PgDatasource(host, port, user, pwd, db, HashMap<String, String>())
    }

    /// 便捷构造：从解析后的连接参数构建（envfile_service.parseDatabaseUrl）。
    public init(conn: DbConn) {
        registerDriver()
        ds = PgDatasource(conn.host, conn.port, conn.user, conn.password, conn.database, HashMap<String, String>())
    }

    /// 在连接生命周期内执行动作；无论成功失败均释放连接（spec §5.8.3 异常 3）。
    public func withConn<T>(f: (Connection) -> T): T {
        let c = ds.connect()
        try {
            f(c)
        } finally {
            c.close()
        }
    }

    public func existsByEmail(email: String): Bool {
        return withConn({ conn =>
            let stmt = conn.prepareStatement("SELECT 1 FROM uctoo_user WHERE email = ?")
            stmt.set<String>(0, email)
            let rs = stmt.query()
            rs.next()
        })
    }

    public func existsByUsername(username: String): Bool {
        return withConn({ conn =>
            let stmt = conn.prepareStatement("SELECT 1 FROM uctoo_user WHERE username = ?")
            stmt.set<String>(0, username)
            let rs = stmt.query()
            rs.next()
        })
    }

    /// 探测数据库连接是否可用（供 config 的 test-config 使用）。
    public func ping(): Bool {
        try {
            return withConn({ conn =>
                let stmt = conn.prepareStatement("SELECT 1")
                stmt.query()
                true
            })
        } catch (_: Exception) {
            return false
        }
    }

    /// 写入管理员并取回 RETURNING 的 id/name/username/email（PG lastInsertId 恒 0，必须 RETURNING）。
    public func insertAdmin(name: String, username: String, email: String, plainPassword: String): ?AdminRow {
        let hashed = hashPassword(plainPassword)
        return withConn({ conn =>
            let sql = "INSERT INTO uctoo_user (name, username, email, password, auth_provider, status, created_at, updated_at, last_login_time) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) RETURNING id, name, username, email"
            let stmt = conn.prepareStatement(sql)
            stmt.set<String>(0, name)
            stmt.set<String>(1, username)
            stmt.set<String>(2, email)
            stmt.set<String>(3, hashed)
            stmt.set<Int64>(4, 0)
            stmt.set<Int64>(5, 1)
            let rs = stmt.query()
            if (rs.next()) {
                let id = match (rs.getOrNull<Int64>(0)) { case Some(v) => v; case None => 0 }
                let nm = match (rs.getOrNull<String>(1)) { case Some(v) => v; case None => name }
                let un = match (rs.getOrNull<String>(2)) { case Some(v) => v; case None => username }
                let em = match (rs.getOrNull<String>(3)) { case Some(v) => v; case None => email }
                Some(AdminRow(id, nm, un, em))
            } else {
                None<AdminRow>
            }
        })
    }

    /// 写后回读自校验（AC-118/119）：用 id 取 password 列，verify 明文。
    public func verifyStoredPassword(adminId: Int64, plain: String): Bool {
        let stored = withConn({ conn =>
            let stmt = conn.prepareStatement("SELECT password FROM uctoo_user WHERE id = ?")
            stmt.set<Int64>(0, adminId)
            let rs = stmt.query()
            if (rs.next()) {
                match (rs.getOrNull<String>(0)) { case Some(v) => v; case None => "" }
            } else {
                ""
            }
        })
        if (stored.isEmpty()) {
            return false
        }
        return verifyPassword(plain, stored)
    }
}
