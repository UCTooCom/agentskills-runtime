package uc_installer.util

// ArrayList 属 std.collection，必须显式 import（仓颉容器类型不默认可见）。
import std.collection.ArrayList

/// 脱敏：屏蔽口令/密钥/令牌，保证安装器自身绝不输出明文凭据（§8.1 落地）。
/// 策略：
///   1) 已知令牌前缀（sk-/ghp_/fc-/postgres:///jdbc:/eyJ/$2a$/$2b$/-----BEGIN）整段打码；
///   2) key=value 形态下，敏感 key 的值打码（key 命中 secret/password/token/key/credential 等）。
///
/// 注意：按空白切分后再逐 token 处理，避免按行粗暴替换；key 部分强制 ASCII 校验，
/// 杜绝误伤正常文本中的 '='。
public func redactLine(line: String): String {
    let tokens = splitSpaces(line)
    let out = ArrayList<String>()
    for (t in tokens) {
        out.add(redactToken(t))
    }
    return joinWith(out, " ")
}

private func redactToken(token: String): String {
    if (token.startsWith("sk-") || token.startsWith("ghp_") || token.startsWith("fc-")
        || token.startsWith("postgres://") || token.startsWith("jdbc:") || token.startsWith("eyJ")
        || token.startsWith("$2a$") || token.startsWith("$2b$")
        || token.startsWith("-----BEGIN") || token.startsWith("-----begin")) {
        return "***"
    }
    let (eq, key) = splitKey(token)
    if (eq > 0 && isSensitiveKey(key)) {
        return "${key}=***"
    }
    return token
}

/// 定位 token 里 '=' 的位置并返回 (Rune 下标, 前缀 key 原串)。
///
/// 注意：下标是在 Rune 空间计算的，**不能**直接拿去切 String —— 仓颉
/// `String[0..n]` 按**字节**切，含非 ASCII key（如中文）时两者错位，
/// 会切出乱码甚至越界。故 key 一律用 StringBuilder 按 Rune 重建。
private func splitKey(token: String): (Int64, String) {
    let runes = token.toRuneArray()
    var i = 0
    while (i < runes.size) {
        if (runes[i] == r'=') {
            if (i > 0) {
                var j = 0
                var ok = true
                while (j < i) {
                    if (!isKeyChar(runes[j])) {
                        ok = false
                        break
                    }
                    j += 1
                }
                if (ok) {
                    return (i, prefixOf(runes, i))
                }
            }
            return (-1, "")
        }
        i += 1
    }
    return (-1, "")
}

/// 取 runes 前 n 个字符拼成 String（Rune 逐个 append，避免字节切片）。
private func prefixOf(runes: Array<Rune>, n: Int64): String {
    let sb = StringBuilder()
    var i = 0
    while (i < n) {
        sb.append(runes[i])
        i += 1
    }
    return sb.toString()
}

private func isSensitiveKey(key: String): Bool {
    let k = key.toAsciiLower()
    return k.contains("secret") || k.contains("password") || k.contains("pwd")
        || k.contains("token") || k.contains("key") || k.contains("credential")
        || k.contains("apikey") || k.contains("api_key") || k.contains("passwd")
        || k.contains("private")
}

private func isKeyChar(c: Rune): Bool {
    return (c >= r'a' && c <= r'z') || (c >= r'A' && c <= r'Z') || (c >= r'0' && c <= r'9')
        || c == r'_' || c == r'.'
}

private func splitSpaces(s: String): ArrayList<String> {
    let res = ArrayList<String>()
    let runes = s.toRuneArray()
    let n = runes.size
    // cur 会在切分时被重建（第 87 行赋值），故必须是 var；写成 let 会报 cannot assign to immutable value。
    var cur = StringBuilder()
    var has = false
    var i = 0
    while (i < n) {
        if (runes[i] == r' ' || runes[i] == r'\t' || runes[i] == r'\n' || runes[i] == r'\r') {
            if (has) {
                res.add(cur.toString())
                cur = StringBuilder()
                has = false
            }
        } else {
            cur.append(runes[i])
            has = true
        }
        i += 1
    }
    if (has) {
        res.add(cur.toString())
    }
    return res
}

private func joinWith(arr: ArrayList<String>, sep: String): String {
    let sb = StringBuilder()
    var i = 0
    while (i < arr.size) {
        if (i > 0) {
            sb.append(sep)
        }
        sb.append(arr[i])
        i += 1
    }
    return sb.toString()
}
