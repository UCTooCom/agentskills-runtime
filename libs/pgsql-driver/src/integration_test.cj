/*
 * integration_test.cj —— 针对真实 PostgreSQL 的集成测试。
 *
 * 需要本地 5433 端口上运行的 PostgreSQL（见 README）：
 *   docker run -d --name cj_pg_test -e POSTGRES_PASSWORD=secret \
 *     -e POSTGRES_USER=testuser -e POSTGRES_DB=testdb \
 *     -e POSTGRES_HOST_AUTH_METHOD=scram-sha-256 -p 5433:5432 postgres:18
 *
 * 覆盖：SCRAM 认证、DDL/CRUD、各数据类型、NULL、RETURNING、列信息、
 * 事务/保存点、错误处理、语句复用、连接池。
 */

package pgsql

import std.collection.*
import std.database.sql.*
import std.math.numeric.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

// 测试数据库连接串。
const TEST_CONN_STR = "postgres://testuser:secret@localhost:5433/testdb"

// 打开一个可用连接。
func openTestConn(): Connection {
    registerDriver()
    let drv = DriverManager.getDriver("postgres").getOrThrow()
    let ds = drv.open(TEST_CONN_STR, [])
    return ds.connect()
}

// 执行一条无参 DDL/命令语句。
func exec(conn: Connection, sql: String): Unit {
    let stmt = conn.prepareStatement(sql)
    stmt.update()
    stmt.close()
}

// ===== 连接与认证 =====

@Test
func testConnectAndAuth() {
    let conn = openTestConn()
    @Expect(conn.state == ConnectionState.Connected, true)
    let md = conn.getMetaData()
    @Expect(md.contains("server_version"), true)
    conn.close()
    @Expect(conn.isClosed(), true)
}

@Test
func testSelectConstants() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement("SELECT 1::int4, 'hello'::text, true")
    let qr = stmt.query()
    @Expect(qr.next(), true)
    @Expect(qr.get<Int32>(0), 1)
    @Expect(qr.get<String>(1), "hello")
    @Expect(qr.get<Bool>(2), true)
    @Expect(qr.next(), false)
    stmt.close()
    conn.close()
}

// ===== CRUD =====

@Test
func testCrudLifecycle() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_crud")
    exec(conn, "CREATE TABLE cj_crud (id int4 PRIMARY KEY, name text, age int4)")

    // INSERT（带参数）。
    let ins = conn.prepareStatement("INSERT INTO cj_crud (id, name, age) VALUES (?, ?, ?)")
    ins.set<Int32>(0, 1)
    ins.set<String>(1, "li lei")
    ins.set<Int32>(2, 12)
    let r1 = ins.update()
    @Expect(r1.rowCount, 1)
    ins.set<Int32>(0, 2)
    ins.set<String>(1, "han meimei")
    ins.set<Int32>(2, 13)
    ins.update()
    ins.close()

    // SELECT 计数。
    let sel = conn.prepareStatement("SELECT count(*)::int8 FROM cj_crud")
    let qr = sel.query()
    @Expect(qr.next(), true)
    @Expect(qr.get<Int64>(0), 2)
    sel.close()

    // SELECT 带条件。
    let byName = conn.prepareStatement("SELECT id, age FROM cj_crud WHERE name = ?")
    byName.set<String>(0, "li lei")
    let qr2 = byName.query()
    @Expect(qr2.next(), true)
    @Expect(qr2.get<Int32>(0), 1)
    @Expect(qr2.get<Int32>(1), 12)
    @Expect(qr2.next(), false)
    byName.close()

    // UPDATE。
    let upd = conn.prepareStatement("UPDATE cj_crud SET age = ? WHERE name = ?")
    upd.set<Int32>(0, 15)
    upd.set<String>(1, "li lei")
    @Expect(upd.update().rowCount, 1)
    upd.close()

    // DELETE。
    let del = conn.prepareStatement("DELETE FROM cj_crud WHERE id = ?")
    del.set<Int32>(0, 2)
    @Expect(del.update().rowCount, 1)
    del.close()

    exec(conn, "DROP TABLE cj_crud")
    conn.close()
}

@Test
func testInsertReturning() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_ret")
    exec(conn, "CREATE TABLE cj_ret (id serial PRIMARY KEY, name text)")
    let stmt = conn.prepareStatement("INSERT INTO cj_ret (name) VALUES (?) RETURNING id, name")
    stmt.set<String>(0, "alice")
    let qr = stmt.query()
    @Expect(qr.next(), true)
    @Expect(qr.get<Int32>(0), 1)
    @Expect(qr.get<String>(1), "alice")
    stmt.close()
    exec(conn, "DROP TABLE cj_ret")
    conn.close()
}

// ===== 数据类型 =====

@Test
func testNumericTypes() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement(
        "SELECT ?::int2, ?::int4, ?::int8, ?::float4, ?::float8, ?::numeric")
    stmt.set<Int16>(0, 32000)
    stmt.set<Int32>(1, 2000000000)
    stmt.set<Int64>(2, 9000000000000000000)
    stmt.set<Float32>(3, 3.5f32)
    stmt.set<Float64>(4, 2.718281828)
    stmt.set<Decimal>(5, Decimal.parse("123.456"))
    let qr = stmt.query()
    @Expect(qr.next(), true)
    @Expect(qr.get<Int16>(0), 32000)
    @Expect(qr.get<Int32>(1), 2000000000)
    @Expect(qr.get<Int64>(2), 9000000000000000000)
    @Expect(qr.get<Float32>(3), 3.5f32)
    @Expect(qr.get<Float64>(4), 2.718281828)
    @Expect(qr.get<Decimal>(5).toString(), "123.456")
    stmt.close()
    conn.close()
}

@Test
func testBoolAndText() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement("SELECT ?::bool, ?::bool, ?::varchar")
    stmt.set<Bool>(0, true)
    stmt.set<Bool>(1, false)
    stmt.set<String>(2, "héllo 世界")
    let qr = stmt.query()
    @Expect(qr.next(), true)
    @Expect(qr.get<Bool>(0), true)
    @Expect(qr.get<Bool>(1), false)
    @Expect(qr.get<String>(2), "héllo 世界")
    stmt.close()
    conn.close()
}

@Test
func testByteaRoundTrip() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_bin")
    exec(conn, "CREATE TABLE cj_bin (id int4, data bytea)")
    let payload: Array<Byte> = [0x00, 0x01, 0xDE, 0xAD, 0xBE, 0xEF, 0xFF]
    let ins = conn.prepareStatement("INSERT INTO cj_bin VALUES (?, ?)")
    ins.set<Int32>(0, 1)
    ins.set<Array<Byte>>(1, payload)
    ins.update()
    ins.close()

    let sel = conn.prepareStatement("SELECT data FROM cj_bin WHERE id = ?")
    sel.set<Int32>(0, 1)
    let qr = sel.query()
    @Expect(qr.next(), true)
    let got = qr.get<Array<Byte>>(0)
    @Expect(got.size, payload.size)
    var same = true
    for (i in 0..payload.size) {
        if (got[i] != payload[i]) {
            same = false
        }
    }
    @Expect(same, true)
    sel.close()
    exec(conn, "DROP TABLE cj_bin")
    conn.close()
}

@Test
func testTimestampRoundTrip() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_ts")
    exec(conn, "CREATE TABLE cj_ts (id int4, ts timestamp, d date)")
    let dt = DateTime.of(year: 2023, month: 6, dayOfMonth: 15, hour: 14, minute: 30, second: 45)
    let day = DateTime.of(year: 2024, month: 1, dayOfMonth: 2)
    let ins = conn.prepareStatement("INSERT INTO cj_ts VALUES (?, ?, ?)")
    ins.set<Int32>(0, 1)
    ins.set<DateTime>(1, dt)
    ins.set<DateTime>(2, day)
    ins.update()
    ins.close()

    let sel = conn.prepareStatement("SELECT ts, d FROM cj_ts WHERE id = ?")
    sel.set<Int32>(0, 1)
    let qr = sel.query()
    @Expect(qr.next(), true)
    let gotTs = qr.get<DateTime>(0)
    let gotDay = qr.get<DateTime>(1)
    @Expect(gotTs.format("yyyy-MM-dd HH:mm:ss"), "2023-06-15 14:30:45")
    @Expect(gotDay.format("yyyy-MM-dd"), "2024-01-02")
    sel.close()
    exec(conn, "DROP TABLE cj_ts")
    conn.close()
}

// ===== NULL 处理 =====

@Test
func testNullHandling() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_null")
    exec(conn, "CREATE TABLE cj_null (id int4, name text)")
    let ins = conn.prepareStatement("INSERT INTO cj_null VALUES (?, ?)")
    ins.set<Int32>(0, 1)
    ins.setNull(1)
    ins.update()
    ins.close()

    let sel = conn.prepareStatement("SELECT id, name FROM cj_null WHERE id = ?")
    sel.set<Int32>(0, 1)
    let qr = sel.query()
    @Expect(qr.next(), true)
    // getOrNull 对 NULL 返回 None。
    @Expect(qr.getOrNull<String>(1).isNone(), true)
    // 非 NULL 列正常返回。
    @Expect(qr.getOrNull<Int32>(0) ?? -1, 1)
    sel.close()
    exec(conn, "DROP TABLE cj_null")
    conn.close()
}

@Test
func testGetNullThrows() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement("SELECT NULL::text")
    let qr = stmt.query()
    @Expect(qr.next(), true)
    // 对 NULL 列调用 get<T> 应抛出 SqlException。
    var threw = false
    try {
        qr.get<String>(0)
    } catch (e: SqlException) {
        threw = true
    }
    @Expect(threw, true)
    stmt.close()
    conn.close()
}

// ===== 列信息 =====

@Test
func testColumnInfo() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement("SELECT 1::int4 AS num, 'x'::varchar(20) AS label")
    let qr = stmt.query()
    let cols = qr.columnInfos
    @Expect(cols.size, 2)
    @Expect(cols[0].name, "num")
    @Expect(cols[0].typeName, "Int32")
    @Expect(cols[1].name, "label")
    @Expect(cols[1].typeName, "String")
    stmt.close()
    conn.close()
}

// ===== 多行遍历 =====

@Test
func testMultipleRows() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement("SELECT g FROM generate_series(1, 5) AS g")
    let qr = stmt.query()
    var sum = 0
    var count = 0
    while (qr.next()) {
        sum += Int64(qr.get<Int32>(0))
        count += 1
    }
    @Expect(count, 5)
    @Expect(sum, 15)
    stmt.close()
    conn.close()
}

// ===== 事务 =====

@Test
func testTransactionCommit() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_tx")
    exec(conn, "CREATE TABLE cj_tx (id int4)")
    let tx = conn.createTransaction()
    tx.begin()
    let ins = conn.prepareStatement("INSERT INTO cj_tx VALUES (?)")
    ins.set<Int32>(0, 100)
    ins.update()
    ins.close()
    tx.commit()

    @Expect(countRows(conn, "cj_tx"), 1)
    exec(conn, "DROP TABLE cj_tx")
    conn.close()
}

@Test
func testTransactionRollback() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_txr")
    exec(conn, "CREATE TABLE cj_txr (id int4)")
    let tx = conn.createTransaction()
    tx.begin()
    let ins = conn.prepareStatement("INSERT INTO cj_txr VALUES (?)")
    ins.set<Int32>(0, 100)
    ins.update()
    ins.close()
    tx.rollback()

    // 回滚后数据应不存在。
    @Expect(countRows(conn, "cj_txr"), 0)
    exec(conn, "DROP TABLE cj_txr")
    conn.close()
}

@Test
func testSavepoints() {
    let conn = openTestConn()
    exec(conn, "DROP TABLE IF EXISTS cj_sp")
    exec(conn, "CREATE TABLE cj_sp (id int4)")
    let tx = conn.createTransaction()
    tx.begin()
    insertId(conn, "cj_sp", 1)
    tx.save("s1")
    insertId(conn, "cj_sp", 2)
    // 回滚到保存点 s1，撤销 id=2 的插入。
    tx.rollback("s1")
    insertId(conn, "cj_sp", 3)
    tx.commit()

    // 应只剩 id=1 与 id=3。
    @Expect(countRows(conn, "cj_sp"), 2)
    exec(conn, "DROP TABLE cj_sp")
    conn.close()
}

@Test
func testTransactionIsolationLevel() {
    let conn = openTestConn()
    let tx = conn.createTransaction()
    tx.isoLevel = TransactionIsoLevel.Serializable
    tx.accessMode = TransactionAccessMode.ReadWrite
    tx.begin()
    // 在可串行化事务中执行只读查询应正常工作。
    let stmt = conn.prepareStatement("SELECT 1::int4")
    let qr = stmt.query()
    @Expect(qr.next(), true)
    @Expect(qr.get<Int32>(0), 1)
    stmt.close()
    tx.commit()
    conn.close()
}

// ===== 错误处理 =====

@Test
func testSyntaxErrorThrows() {
    let conn = openTestConn()
    var sqlState = ""
    try {
        conn.prepareStatement("SELECT * FROM a_table_that_does_not_exist_xyz")
    } catch (e: SqlException) {
        sqlState = e.sqlState
    }
    // 42P01 = undefined_table。
    @Expect(sqlState, "42P01")
    // 连接在错误后应仍可用。
    let stmt = conn.prepareStatement("SELECT 1::int4")
    let qr = stmt.query()
    @Expect(qr.next(), true)
    stmt.close()
    conn.close()
}

@Test
func testUnsetParameterThrows() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement("SELECT ?::int4")
    var threw = false
    try {
        stmt.query()
    } catch (e: SqlException) {
        threw = true
    }
    @Expect(threw, true)
    stmt.close()
    conn.close()
}

// ===== 语句复用 =====

@Test
func testStatementReuse() {
    let conn = openTestConn()
    let stmt = conn.prepareStatement("SELECT ?::int4 * 2")
    stmt.set<Int32>(0, 5)
    let qr1 = stmt.query()
    @Expect(qr1.next(), true)
    @Expect(qr1.get<Int32>(0), 10)

    // 重新赋值后再次执行。
    stmt.set<Int32>(0, 21)
    let qr2 = stmt.query()
    @Expect(qr2.next(), true)
    @Expect(qr2.get<Int32>(0), 42)
    stmt.close()
    conn.close()
}

// ===== 连接池 =====

@Test
func testPooledDatasource() {
    registerDriver()
    let drv = DriverManager.getDriver("postgres").getOrThrow()
    let ds = drv.open(TEST_CONN_STR, [])
    let pooled = PooledDatasource(ds)
    pooled.maxSize = 4

    // 获取连接、查询、归还，重复多次以验证池可复用。
    for (_ in 0..3) {
        let conn = pooled.connect()
        let stmt = conn.prepareStatement("SELECT 7::int4")
        let qr = stmt.query()
        @Expect(qr.next(), true)
        @Expect(qr.get<Int32>(0), 7)
        stmt.close()
        conn.close()
    }
    pooled.close()
}

// 统计表中行数。
func countRows(conn: Connection, table: String): Int64 {
    let stmt = conn.prepareStatement("SELECT count(*)::int8 FROM ${table}")
    let qr = stmt.query()
    qr.next()
    let n = qr.get<Int64>(0)
    stmt.close()
    return n
}

// 向单列 int 表插入一行。
func insertId(conn: Connection, table: String, id: Int32): Unit {
    let stmt = conn.prepareStatement("INSERT INTO ${table} VALUES (?)")
    stmt.set<Int32>(0, id)
    stmt.update()
    stmt.close()
}
