package uc_installer.services

import std.fs.{Path, File, OpenMode, FileInfo, exists}
import std.collection.{HashMap, ArrayList}
import std.convert.Parsable
import std.core.StringBuilder

// ===================== .env 解析 =====================

/// 解析后的数据库连接参数。
public struct DbConn {
    public let host: String
    public let port: UInt16
    public let database: String
    public let user: String
    public let password: String
    public init(host: String, port: UInt16, database: String, user: String, password: String) {
        this.host = host
        this.database = database
        this.port = port
        this.user = user
        this.password = password
    }
}

/// 读取 .env 文件为键值对（忽略注释与空行，剥离成对引号）。
public func readEnv(path: Path): Option<HashMap<String, String>> {
    if (!exists(path)) {
        return None<HashMap<String, String>>
    }
    try {
        let info = FileInfo(path)
        let buf = Array<Byte>(info.size, repeat: 0)
        let f = File(path, OpenMode.Read)
        f.read(buf)
        f.close()
        let text = String.fromUtf8(buf)
        return Some(parseEnvLines(text))
    } catch (_: Exception) {
        return None<HashMap<String, String>>
    }
}

func parseEnvLines(text: String): HashMap<String, String> {
    let m = HashMap<String, String>()
    let lines = splitPreservingEol(text)
    for (raw in lines) {
        let trim = raw.trimAscii()
        if (trim.isEmpty() || trim.startsWith("#")) {
            continue
        }
        match (trim.indexOf('=')) {
            case Some(idx) =>
                let k = trim[0..idx].trimAscii()
                let v = stripQuotes(trim[idx + 1..].trimAscii())
                if (!k.isEmpty()) {
                    m.add(k, v)
                }
            case None => ()
        }
    }
    return m
}

/// 从环境表取数据库连接串：优先 DATABASE_URL，其次 orm_connectionUrl。
public func readDbConnectionUrl(env: HashMap<String, String>): Option<String> {
    match (env.get("DATABASE_URL")) {
        case Some(u) => if (!u.isEmpty()) { return Some(u) }
        case None => ()
    }
    match (env.get("orm_connectionUrl")) {
        case Some(u) => if (!u.isEmpty()) { return Some(u) }
        case None => ()
    }
    return None<String>
}

/// 解析 postgres://user:pass@host:port/db 连接串。
public func parseDatabaseUrl(url: String): Option<DbConn> {
    var rest = url
    match (rest.indexOf("://")) {
        case Some(i) => rest = rest[i + 3..]
        case None => ()
    }
    match (rest.indexOf('@')) {
        case Some(at) =>
            let userinfo = rest[0..at]
            let hostpart = rest[at + 1..]
            var user = ""
            var password = ""
            match (userinfo.indexOf(':')) {
                case Some(ci) =>
                    user = userinfo[0..ci]
                    password = userinfo[ci + 1..]
                case None => user = userinfo
            }
            var hp = hostpart
            match (hp.indexOf('?')) {
                case Some(qi) => hp = hp[0..qi]
                case None => ()
            }
            var host = hp
            var db = "uctoo"
            match (hp.indexOf('/')) {
                case Some(si) =>
                    host = hp[0..si]
                    let dbpart = hp[si + 1..]
                    if (!dbpart.isEmpty()) { db = dbpart }
                case None => ()
            }
            var port: UInt16 = 5432
            match (host.indexOf(':')) {
                case Some(pi) =>
                    let hostOnly = host[0..pi]
                    let portStr = host[pi + 1..]
                    host = hostOnly
                    port = parsePort(portStr, 5432)
                case None => ()
            }
            if (host.isEmpty()) {
                return None<DbConn>
            }
            return Some(DbConn(host, port, db, user, password))
        case None => return None<DbConn>
    }
}

func parsePort(s: String, fallback: UInt16): UInt16 {
    try {
        return UInt16.parse(s)
    } catch (_: Exception) {
        return fallback
    }
}

// ===================== .env 行级 in-place 更新 =====================

public enum UpsertEnvOutcome {
    | Updated(String)
    | InvalidKey
}

/// 行级 in-place 更新 .env：命中则保留前导缩进改写，未命中追加到末尾；保留 \r\n/\n 原样。
/// key 不匹配 ^[\w.]+$ 返回 InvalidKey（AC-095）。
public func upsertEnv(content: String, key: String, value: String): UpsertEnvOutcome {
    if (!isValidEnvKey(key)) {
        return UpsertEnvOutcome.InvalidKey
    }
    let lines = splitPreservingEol(content)
    var matched = false
    var i = 0
    while (i < lines.size) {
        let raw = lines[i]
        let trim = raw.trimAscii()
        if (trim.startsWith("#") || trim.isEmpty()) {
            i = i + 1
            continue
        }
        match (trim.indexOf('=')) {
            case Some(eqIdx) =>
                let k = trim[0..eqIdx].trimAscii()
                if (k == key) {
                    let indent = leadingWhitespace(raw)
                    lines[i] = indent + key + "=" + renderEnvValue(value)
                    matched = true
                    break
                }
            case None => ()
        }
        i = i + 1
    }
    if (!matched) {
        lines.add(key + "=" + renderEnvValue(value))
    }
    let sb = StringBuilder()
    for (line in lines) {
        sb.append(line)
    }
    return UpsertEnvOutcome.Updated(sb.toString())
}

/// 按 \r\n / \n 切分并保留行尾（绝不统一化）。
func splitPreservingEol(content: String): ArrayList<String> {
    let buf = content.toArray()
    let out = ArrayList<String>()
    var start = 0
    let n = buf.size
    var i = 0
    while (i < n) {
        let c = buf[i]
        if (c == 10u8) {
            out.add(String.fromUtf8(buf[start..i + 1]))
            i = i + 1
            start = i
        } else if (c == 13u8) {
            if (i + 1 < n && buf[i + 1] == 10u8) {
                out.add(String.fromUtf8(buf[start..i + 2]))
                i = i + 2
                start = i
            } else {
                out.add(String.fromUtf8(buf[start..i + 1]))
                i = i + 1
                start = i
            }
        } else {
            i = i + 1
        }
    }
    if (start < n) {
        out.add(String.fromUtf8(buf[start..n]))
    }
    return out
}

func leadingWhitespace(s: String): String {
    let buf = s.toArray()
    var i = 0
    while (i < buf.size) {
        let c = buf[i]
        if (c == 32u8 || c == 9u8) {
            i = i + 1
        } else {
            break
        }
    }
    return String.fromUtf8(buf[0..i])
}

func renderEnvValue(v: String): String {
    if (v.contains("#") || v.contains(" ")) {
        return "\"" + v + "\""
    }
    return v
}

func stripQuotes(v: String): String {
    if (v.size >= 2) {
        if ((v.startsWith("\"") && v.endsWith("\"")) || (v.startsWith("'") && v.endsWith("'"))) {
            return v[1..v.size - 1]
        }
    }
    return v
}

func isValidEnvKey(key: String): Bool {
    if (key.isEmpty()) {
        return false
    }
    let buf = key.toArray()
    for (c in buf) {
        if (!isWordChar(c)) {
            return false
        }
    }
    return true
}

func isWordChar(c: Byte): Bool {
    let isLower = c >= 97u8 && c <= 122u8
    let isUpper = c >= 65u8 && c <= 90u8
    let isDigit = c >= 48u8 && c <= 57u8
    let isUnderscore = c == 95u8
    let isDot = c == 46u8
    return isLower || isUpper || isDigit || isUnderscore || isDot
}
