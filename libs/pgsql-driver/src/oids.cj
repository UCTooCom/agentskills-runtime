/*
 * oids.cj —— PostgreSQL 内置数据类型的对象标识符（OID）常量。
 *
 * RowDescription / ParameterDescription 报文用 OID 标识列与参数的数据类型，
 * 值编解码（value.cj）据此在 PostgreSQL 文本格式与仓颉类型之间转换。
 * 这里只收录驱动实际需要识别的常用类型，取值见 PostgreSQL 源码 pg_type.dat。
 */

package pgsql

// 布尔型 bool。
public const OID_BOOL: Int32 = 16
// 变长二进制 bytea。
public const OID_BYTEA: Int32 = 17
// 单字节内部字符 "char"。
public const OID_CHAR: Int32 = 18
// 对象名 name。
public const OID_NAME: Int32 = 19
// 8 字节整数 int8 / bigint。
public const OID_INT8: Int32 = 20
// 2 字节整数 int2 / smallint。
public const OID_INT2: Int32 = 21
// 4 字节整数 int4 / integer。
public const OID_INT4: Int32 = 23
// 变长文本 text。
public const OID_TEXT: Int32 = 25
// 对象标识符 oid。
public const OID_OID: Int32 = 26
// JSON 文本。
public const OID_JSON: Int32 = 114
// 单精度浮点 float4 / real。
public const OID_FLOAT4: Int32 = 700
// 双精度浮点 float8 / double precision。
public const OID_FLOAT8: Int32 = 701
// 定长字符 bpchar / char(n)。
public const OID_BPCHAR: Int32 = 1042
// 变长字符 varchar。
public const OID_VARCHAR: Int32 = 1043
// 日期 date。
public const OID_DATE: Int32 = 1082
// 时间 time（不含时区）。
public const OID_TIME: Int32 = 1083
// 时间戳 timestamp（不含时区）。
public const OID_TIMESTAMP: Int32 = 1114
// 带时区时间戳 timestamptz。
public const OID_TIMESTAMPTZ: Int32 = 1184
// 时间间隔 interval。
public const OID_INTERVAL: Int32 = 1186
// 带时区时间 timetz。
public const OID_TIMETZ: Int32 = 1266
// 高精度数 numeric / decimal。
public const OID_NUMERIC: Int32 = 1700
// UUID。
public const OID_UUID: Int32 = 2950
// 二进制 JSON。
public const OID_JSONB: Int32 = 3802
