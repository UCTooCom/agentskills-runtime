/*
 * pgsql.cj —— 包入口。
 *
 * 本包是一个用纯仓颉实现的生产级 PostgreSQL 驱动，实现 std.database.sql 接口。
 * 典型用法：
 * ```
 * import std.database.sql.*
 * import pgsql.*
 *
 * let drv = DriverManager.getDriver("postgres") ?? return
 * let ds = drv.open("postgres://user:pwd@localhost:5432/mydb", [])
 * let conn = ds.connect()
 * let stmt = conn.prepareStatement("select id, name from t where id = ?")
 * stmt.set<Int32>(0, 1)
 * let qr = stmt.query()
 * while (qr.next()) {
 *     println("${qr.get<Int32>(0)} ${qr.get<String>(1)}")
 * }
 * ```
 */

package pgsql

