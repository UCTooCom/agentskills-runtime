/*
 * unit_test.cj —— 不依赖数据库的纯函数单元测试。
 * 覆盖占位符转换、bytea 编解码、日期时间解析等可独立验证的逻辑。
 */

package pgsql

import std.database.sql.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testPlaceholderConversion() {
    // 基本占位符转换。
    let (sql1, n1) = convertPlaceholders("INSERT INTO t VALUES (?, ?, ?)")
    @Expect(sql1, "INSERT INTO t VALUES (\$1, \$2, \$3)")
    @Expect(n1, 3)

    // 单引号字符串内的 ? 不应被替换。
    let (sql2, n2) = convertPlaceholders("SELECT '?'::text, ? FROM t WHERE name = ?")
    @Expect(sql2, "SELECT '?'::text, \$1 FROM t WHERE name = \$2")
    @Expect(n2, 2)

    // 行注释内的 ? 不应被替换。
    let (sql3, n3) = convertPlaceholders("SELECT ? -- comment with ?\nFROM t")
    @Expect(sql3, "SELECT \$1 -- comment with ?\nFROM t")
    @Expect(n3, 1)

    // 块注释内的 ? 不应被替换。
    let (sql4, n4) = convertPlaceholders("SELECT /* ? ignored */ ?")
    @Expect(sql4, "SELECT /* ? ignored */ \$1")
    @Expect(n4, 1)
}

@Test
func testByteaEncodeDecode() {
    let data: Array<Byte> = [0x00, 0xDE, 0xAD, 0xBE, 0xEF, 0xFF]
    let encoded = encodeBytea(data)
    // 验证 \x 十六进制编码内容。
    @Expect(encoded, "\\x00deadbeefff")
    // 解码应还原原始字节。
    let decoded = decodeBytea(encoded)
    @Expect(decoded.size, data.size)
    var same = true
    for (i in 0..data.size) {
        if (decoded[i] != data[i]) {
            same = false
        }
    }
    @Expect(same, true)
}

@Test
func testParsePgDateTime() {
    // timestamp 解析后再格式化应保持一致。
    let ts = parsePgDateTime("2023-06-15 14:30:45", OID_TIMESTAMP)
    @Expect(ts.format("yyyy-MM-dd HH:mm:ss"), "2023-06-15 14:30:45")

    // date 解析。
    let d = parsePgDateTime("2024-01-02", OID_DATE)
    @Expect(d.format("yyyy-MM-dd"), "2024-01-02")

    // 带微秒的 timestamp。
    let ts2 = parsePgDateTime("2023-06-15 14:30:45.123456", OID_TIMESTAMP)
    @Expect(ts2.format("yyyy-MM-dd HH:mm:ss"), "2023-06-15 14:30:45")
}

@Test
func testCangjieTypeName() {
    @Expect(cangjieTypeName(OID_INT4), "Int32")
    @Expect(cangjieTypeName(OID_INT8), "Int64")
    @Expect(cangjieTypeName(OID_TEXT), "String")
    @Expect(cangjieTypeName(OID_BOOL), "Bool")
    @Expect(cangjieTypeName(OID_BYTEA), "Array<Byte>")
    @Expect(cangjieTypeName(OID_NUMERIC), "Decimal")
    @Expect(cangjieTypeName(OID_TIMESTAMP), "DateTime")
}

@Test
func testDriverRegistration() {
    registerDriver()
    let drv = DriverManager.getDriver("postgres")
    @Expect(drv.isSome(), true)
    @Expect(drv.getOrThrow().name, "postgres")
    @Expect(drv.getOrThrow().version, DRIVER_VERSION)
    @Expect(drv.getOrThrow().preferredPooling, true)
}
