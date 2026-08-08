/*
 * value.cj —— 仓颉类型与 PostgreSQL 文本格式之间的值编解码，以及列信息实现。
 *
 * 本驱动统一采用文本格式（format code = 0）传输参数与结果：
 *   - 参数：Parse 时不预先指定参数类型（OID 0），由服务器按上下文推断；
 *     Bind 时以文本形式发送每个参数。
 *   - 结果：Bind 时请求文本格式，DataRow 中各列均为文本字节，按列 OID/请求类型解析。
 * 文本格式无需逐类型实现二进制布局，覆盖面广且实现稳健。
 */

package pgsql

import std.binary.*
import std.convert.*
import std.database.sql.*
import std.math.numeric.*
import std.time.*

/**
 * 列信息实现，数据来自 RowDescription 报文。
 */
public class PgColumnInfo <: ColumnInfo {
    private let nameVal: String
    private let oid: Int32
    private let typeSize: Int16
    private let typeModifier: Int32

    public init(name: String, oid: Int32, typeSize: Int16, typeModifier: Int32) {
        this.nameVal = name
        this.oid = oid
        this.typeSize = typeSize
        this.typeModifier = typeModifier
    }

    /** 该列对应的 PostgreSQL 类型 OID。 */
    public prop typeOid: Int32 {
        get() {
            oid
        }
    }

    /** 列名或别名。 */
    public prop name: String {
        get() {
            nameVal
        }
    }

    /**
     * 列类型名称：若仓颉有对应类型则返回其类型名（如 "Int32"、"String"），
     * 否则返回形如 "pg_oid_<n>" 的驱动自定义名。
     */
    public prop typeName: String {
        get() {
            cangjieTypeName(oid)
        }
    }

    /**
     * 列值大小：
     *   - numeric：最大精度（来自类型修饰符）；
     *   - 字符类型：以字符为单位的最大长度；
     *   - 定长类型：字节宽度；
     *   - 不适用时返回 0。
     */
    public prop length: Int64 {
        get() {
            if (oid == OID_NUMERIC && typeModifier != -1) {
                // numeric 的 typmod-4 高 16 位为精度。
                return Int64(((typeModifier - 4) >> 16) & 0xFFFF)
            }
            if ((oid == OID_VARCHAR || oid == OID_BPCHAR) && typeModifier != -1) {
                return Int64(typeModifier - 4)
            }
            if (typeSize > 0) {
                return Int64(typeSize)
            }
            return 0
        }
    }

    /** 小数位数：numeric 类型从类型修饰符解析，其余为 0。 */
    public prop scale: Int64 {
        get() {
            if (oid == OID_NUMERIC && typeModifier != -1) {
                return Int64((typeModifier - 4) & 0xFFFF)
            }
            return 0
        }
    }

    /**
     * 最大显示宽度：定长类型用其字节宽度，变长/无上限返回 Int64.Max。
     */
    public prop displaySize: Int64 {
        get() {
            let len = length
            if (len > 0) {
                return len
            }
            return Int64.Max
        }
    }

    /**
     * 是否允许 NULL。RowDescription 不携带非空约束信息，故统一返回 true。
     */
    public prop nullable: Bool {
        get() {
            true
        }
    }
}

/**
 * 返回 OID 对应的仓颉类型名，供 [ColumnInfo.typeName] 使用。
 */
public func cangjieTypeName(oid: Int32): String {
    // 用 == 比较 const OID（match 会把 const 标识符当作变量绑定，故不可用于此）。
    if (oid == OID_BOOL) {
        return "Bool"
    } else if (oid == OID_INT2) {
        return "Int16"
    } else if (oid == OID_INT4) {
        return "Int32"
    } else if (oid == OID_INT8) {
        return "Int64"
    } else if (oid == OID_FLOAT4) {
        return "Float32"
    } else if (oid == OID_FLOAT8) {
        return "Float64"
    } else if (oid == OID_TEXT || oid == OID_VARCHAR || oid == OID_BPCHAR || oid == OID_NAME ||
        oid == OID_CHAR || oid == OID_JSON || oid == OID_JSONB || oid == OID_UUID) {
        return "String"
    } else if (oid == OID_BYTEA) {
        return "Array<Byte>"
    } else if (oid == OID_NUMERIC) {
        return "Decimal"
    } else if (oid == OID_DATE || oid == OID_TIME || oid == OID_TIMETZ ||
        oid == OID_TIMESTAMP || oid == OID_TIMESTAMPTZ) {
        return "DateTime"
    } else if (oid == OID_INTERVAL) {
        return "Duration"
    }
    return "pg_oid_${oid}"
}

/**
 * 已编码的绑定参数：格式码（0 文本 / 1 二进制）与字节值（None 表示 SQL NULL）。
 */
public struct BoundParam {
    public let formatCode: Int16
    public let value: ?Array<Byte>

    public init(formatCode: Int16, value: ?Array<Byte>) {
        this.formatCode = formatCode
        this.value = value
    }
}

/**
 * 将 set\<T> 传入的仓颉值编码为绑定参数。
 *
 * 浮点数采用二进制格式（精确的 IEEE 754 大端字节），因为仓颉 Float 的文本表示
 * 会丢失精度而无法可逆往返；其余类型采用文本格式。
 *
 * @param value 仓颉值。
 * @return 已编码的绑定参数。
 */
public func encodeParam<T>(value: T): BoundParam {
    match (value) {
        case v: Float32 =>
            // float4：4 字节大端 IEEE 754。
            let b = Array<Byte>(4, repeat: 0)
            v.writeBigEndian(b)
            return BoundParam(1, b)
        case v: Float64 =>
            // float8：8 字节大端 IEEE 754。
            let b = Array<Byte>(8, repeat: 0)
            v.writeBigEndian(b)
            return BoundParam(1, b)
        case _ =>
            // 其余类型走文本格式。
            return BoundParam(0, encodeParamText<T>(value).toArray())
    }
}

/**
 * 将 set\<T> 传入的仓颉值编码为 PostgreSQL 文本表示。
 *
 * @param value 仓颉值。
 * @return 文本表示，用于 Bind 报文。
 * @throws SqlException 当遇到不支持的参数类型时。
 */
public func encodeParamText<T>(value: T): String {
    match (value) {
        case v: String => v
        case v: Bool => if (v) {
            "true"
        } else {
            "false"
        }
        case v: Int8 => "${v}"
        case v: Int16 => "${v}"
        case v: Int32 => "${v}"
        case v: Int64 => "${v}"
        case v: UInt8 => "${v}"
        case v: UInt16 => "${v}"
        case v: UInt32 => "${v}"
        case v: UInt64 => "${v}"
        case v: Float32 => "${v}"
        case v: Float64 => "${v}"
        case v: Array<Byte> => encodeBytea(v)
        case v: DateTime => v.format("yyyy-MM-dd HH:mm:ss")
        case v: Decimal => v.toString()
        case _ => throw SqlException("unsupported parameter type for set<T>; supported: String, Bool, Int8/16/32/64, UInt8/16/32/64, Float32/64, Array<Byte>, DateTime, Decimal")
    }
}

// decodeColumn 使用的类型探针常量：仅用于 `as T` 的运行时类型判定，其数值本身被丢弃。
// 提升为模块级常量后，分配型探针（bytea/decimal/datetime）只在包加载时构造一次。
let probeI8: Int8 = 0
let probeI16: Int16 = 0
let probeI32: Int32 = 0
let probeI64: Int64 = 0
let probeU8: UInt8 = 0
let probeU16: UInt16 = 0
let probeU32: UInt32 = 0
let probeU64: UInt64 = 0
let probeF32: Float32 = 0.0
let probeF64: Float64 = 0.0
let probeBool: Bool = false
let probeBytes: Array<Byte> = Array<Byte>()
let probeDecimal: Decimal = Decimal(0)
let probeDateTime: DateTime = DateTime.ofEpoch(second: 0, nanosecond: 0)

/**
 * 将 PostgreSQL 文本格式的列值解码为 get\<T> 请求的类型 T。
 *
 * 优化策略：先用「廉价且不抛异常」的类型探针（`sentinel as T`）判定请求类型 T，
 * 命中后只对该类型解析一次。相比旧版「逐类型解析→失败抛异常→捕获→重试下一类型」，
 * 这里不再把异常用于控制流——一次 get\<T> 最多只发生一次解析，且仅在数据确实非法时抛异常。
 * （例如 get\<DateTime> 旧版会先后触发约 11 次抛/捕异常，新版为若干次廉价类型判定 + 1 次解析。）
 *
 * `as T` 为精确类型匹配（无隐式数值拓宽），故各分支顺序只影响命中速度、不影响正确性。
 *
 * @param raw 列值文本。
 * @param oid 列类型 OID（用于日期时间格式判定）。
 * @return 类型 T 的解码结果。
 * @throws SqlException 当数据无法解析为该类型，或请求类型不受支持时。
 */
public func decodeColumn<T>(raw: String, oid: Int32): T {
    try {
        // 无匹配值的 match：依次判断各类型探针，命中后对该类型仅解析一次。
        // String 最常见，置于首位；各探针互斥（as T 精确匹配），故顺序只影响命中速度。
        return match {
            case (raw as T).isSome() => (raw as T).getOrThrow()
            case (probeI32 as T).isSome() => (Int32.parse(raw) as T).getOrThrow()
            case (probeI64 as T).isSome() => (Int64.parse(raw) as T).getOrThrow()
            case (probeBool as T).isSome() => (boolFromPg(raw) as T).getOrThrow()
            case (probeF64 as T).isSome() => (Float64.parse(raw) as T).getOrThrow()
            case (probeF32 as T).isSome() => (Float32.parse(raw) as T).getOrThrow()
            case (probeI16 as T).isSome() => (Int16.parse(raw) as T).getOrThrow()
            case (probeI8 as T).isSome() => (Int8.parse(raw) as T).getOrThrow()
            case (probeU64 as T).isSome() => (UInt64.parse(raw) as T).getOrThrow()
            case (probeU32 as T).isSome() => (UInt32.parse(raw) as T).getOrThrow()
            case (probeU16 as T).isSome() => (UInt16.parse(raw) as T).getOrThrow()
            case (probeU8 as T).isSome() => (UInt8.parse(raw) as T).getOrThrow()
            case (probeDecimal as T).isSome() => (Decimal.parse(raw) as T).getOrThrow()
            case (probeBytes as T).isSome() => (decodeBytea(raw) as T).getOrThrow()
            case (probeDateTime as T).isSome() => (parsePgDateTime(raw, oid) as T).getOrThrow()
            case _ => throw SqlException("unsupported requested type for get<T> (column oid=${oid}, value '${raw}')")
        }
    } catch (e: SqlException) {
        throw e
    } catch (e: Exception) {
        // 类型已确定，但文本无法解析为该类型（数据非法）。
        throw SqlException("failed to decode column value '${raw}' (oid=${oid}): ${e.message}")
    }
}

// 将 PostgreSQL 布尔文本（t/f/true/false/1/0）转为 Bool。
private func boolFromPg(raw: String): Bool {
    match (raw) {
        case "t" | "true" | "TRUE" | "1" | "yes" | "on" => true
        case "f" | "false" | "FALSE" | "0" | "no" | "off" => false
        case _ => throw SqlException("invalid boolean text '${raw}'")
    }
}

// 将字节数组编码为 PostgreSQL bytea 的十六进制输入格式：\xDEADBEEF。
public func encodeBytea(data: Array<Byte>): String {
    return "\\x" + toHex(data)
}

// 解码 PostgreSQL bytea 的十六进制输出格式：\xDEADBEEF → 原始字节。
public func decodeBytea(text: String): Array<Byte> {
    if (!text.startsWith("\\x")) {
        throw SqlException("not a hex-format bytea value")
    }
    let hex = text[2..].toArray()
    if (hex.size % 2 != 0) {
        throw SqlException("invalid bytea hex length")
    }
    let out = Array<Byte>(hex.size / 2, repeat: 0)
    for (i in 0..out.size) {
        out[i] = UInt8((hexNibble(hex[i * 2]) << 4) | hexNibble(hex[i * 2 + 1]))
    }
    return out
}

// 单个十六进制字符 → 0..15。
private func hexNibble(c: Byte): Int64 {
    if (c >= b'0' && c <= b'9') {
        return Int64(c - b'0')
    } else if (c >= b'a' && c <= b'f') {
        return Int64(c - b'a') + 10
    } else if (c >= b'A' && c <= b'F') {
        return Int64(c - b'A') + 10
    }
    throw SqlException("invalid hex digit in bytea")
}

/**
 * 将 PostgreSQL 日期/时间文本解析为仓颉 DateTime。
 *
 * 支持的输入形态：
 *   - date：       "YYYY-MM-DD"
 *   - time/timetz："HH:MM:SS[.ffffff][+TZ]"（以 1970-01-01 为占位日期）
 *   - timestamp：  "YYYY-MM-DD HH:MM:SS[.ffffff]"
 *   - timestamptz："YYYY-MM-DD HH:MM:SS[.ffffff][+TZ]"，按偏移归一到对应时区。
 */
public func parsePgDateTime(raw: String, oid: Int32): DateTime {
    if (oid == OID_TIME || oid == OID_TIMETZ) {
        // 仅时间：补一个占位日期再解析。
        return parseDateAndTime("1970-01-01", raw)
    }
    if (oid == OID_DATE) {
        return parseDateAndTime(raw, "00:00:00")
    }
    // timestamp / timestamptz：以空格分隔日期与时间。
    let sp = raw.indexOf(" ")
    match (sp) {
        case Some(idx) => return parseDateAndTime(raw[0..idx], raw[idx + 1..])
        case None => return parseDateAndTime(raw, "00:00:00")
    }
}

// 解析 "YYYY-MM-DD" 与 "HH:MM:SS[.frac][±HH[:MM]]" 两部分，构造 DateTime。
private func parseDateAndTime(datePart: String, timePartRaw: String): DateTime {
    let d = datePart.split("-")
    if (d.size != 3) {
        throw SqlException("invalid date part '${datePart}'")
    }
    let year = Int64.parse(d[0])
    let month = Int64.parse(d[1])
    let day = Int64.parse(d[2])

    // 拆出时区偏移（+/-），剩余为时分秒（含可选小数秒）。
    var timePart = timePartRaw
    var tz = TimeZone.Local
    var hasTz = false
    var tzSign = 1
    var tzIndex = -1
    // 从第 1 个字符起查找符号，避免把负年份误判为时区。
    for (i in 1..timePart.size) {
        let ch = timePart[i]
        if (ch == b'+' || ch == b'-') {
            tzIndex = i
            if (ch == b'-') {
                tzSign = -1
            }
            break
        }
    }
    if (tzIndex >= 0) {
        let tzStr = timePart[tzIndex + 1..]
        timePart = timePart[0..tzIndex]
        let tzc = tzStr.split(":")
        var tzHour = Int64.parse(tzc[0])
        var tzMin = 0
        if (tzc.size > 1) {
            tzMin = Int64.parse(tzc[1])
        }
        let offsetSeconds = tzSign * (tzHour * 3600 + tzMin * 60)
        tz = TimeZone("pg", Duration.second * offsetSeconds)
        hasTz = true
    }

    // 解析时分秒与小数秒（最多取 9 位作为纳秒）。
    let t = timePart.split(":")
    let hour = Int64.parse(t[0])
    let minute = if (t.size > 1) {
        Int64.parse(t[1])
    } else {
        0
    }
    var second = 0
    var nanos = 0
    if (t.size > 2) {
        let secParts = t[2].split(".")
        second = Int64.parse(secParts[0])
        if (secParts.size > 1) {
            var frac = secParts[1]
            // 右侧补零到 9 位得到纳秒。
            while (frac.size < 9) {
                frac = frac + "0"
            }
            nanos = Int64.parse(frac[0..9])
        }
    }

    let zone = if (hasTz) {
        tz
    } else {
        TimeZone.Local
    }
    return DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: minute,
        second: second, nanosecond: nanos, timeZone: zone)
}
