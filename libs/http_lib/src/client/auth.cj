package http_lib.client
/**
 * HTTP 认证方案支持。
 * 目前支持 Basic 和 Bearer Token 两种认证方案。
 */

import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import std.sync.Mutex
import http_lib.connection.secureRandom
import http_lib.core.{HttpHeaders, HttpMethod}
import jinguissl_core.crypto.digest.{md5, sha256, bytesToHexLower}
import http_lib.utils.{base64EncodeString, base64DecodeBytes}

/**
 * 构建 HTTP Basic 认证头值（RFC 7617）。
 *
 * 生成 "Basic <base64(usr:pswd)>" 格式的 Authorization 头值。
 *
 * @param username 用户名
 * @param password 密码
 * @return Authorization 头值（不含 "Authorization: " 前缀）
 *
 * 使用示例:
 *   let auth = buildBasicAuthHeader("admin", "secret")
 *   headers.set("Authorization", auth)
 */
public func buildBasicAuthHeader(username: String, password: String): String {
    let credentials = "${username}:${password}"
    let encoded = base64EncodeString(credentials)
    "Basic ${encoded}"
}

/**
 * 解析 HTTP Basic 认证头的凭据（RFC 7617）。
 *
 * 从 "Basic <base64>" 格式的 Authorization 头值中提取用户名和密码。
 *
 * @param header Authorization 头值（如 "Basic YWRtaW46c2VjcmV0"）
 * @return (username, password)，如果解析失败则返回 None
 *
 * 使用示例:
 *   match (parseBasicAuthHeader(authHeader)) {
 *       case Some((user, pass)) => ...
 *       case None => ...
 *   }
 */
public func parseBasicAuthHeader(header: String): ?(String, String) {
    let runes = header.toRuneArray()
    let basicRunes = "Basic ".toRuneArray()
    if (runes.size < basicRunes.size) { return None }
    var isMatch = true
    var i: Int64 = 0
    while (i < basicRunes.size) {
        let r = runes[i]
        let b = basicRunes[i]
        if (r != b && r != r' ' && b != r' ') {
            if (UInt32(r) != UInt32(b) && UInt32(r) != UInt32(b) + 32) {
                isMatch = false
                break
            }
        }
        i += 1
    }
    if (!isMatch) { return None }
    let base64Part = String(runes[basicRunes.size..runes.size])
    try {
        let decoded = String.fromUtf8(base64DecodeBytes(base64Part))
        let colonIdx = decoded.indexOf(":")
        match (colonIdx) {
            case Some(idx) =>
                let username = decoded[..idx]
                let password = decoded[idx + 1..decoded.size]
                Some((username, password))
            case None => None
        }
    } catch (_: Exception) { None }
}

/**
 * HTTP 摘要认证（RFC 7616）。
 *
 * 使用 JinguiSSL 加密原语 for MD5 and SHA-256 hashing.
 */

/**
 * 计算数据的 MD5 哈希并返回小写十六进制字符串。
 * 使用 JinguiSSL 的 crypto MD5 实现。
 */
public func md5Hex(data: Array<UInt8>): String {
    let digest = md5(data)
    bytesToHexLower(digest)
}

/**
 * 计算数据的 SHA-256 哈希并返回小写十六进制字符串。
 * 支持 RFC 7616 SHA-256 digest 认证。
 */
public func sha256Hex(data: Array<UInt8>): String {
    let digest = sha256(data)
    bytesToHexLower(digest)
}

/**
 * 解析 WWW-Authenticate: Digest 质询头。
 * 返回参数映射（realm、nonce、qop、opaque、algorithm）。
 */
public func parseDigestChallenge(header: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    let runes = header.toRuneArray()
    var i: Int64 = 0
    // 查找 "Digest " 前缀
    let digestRunes = "Digest ".toRuneArray()
    if (runes.size < digestRunes.size) { return result }
    var isMatch = true
    var j: Int64 = 0
    while (j < digestRunes.size) {
        let r = UInt32(runes[j])
        let dr = UInt32(digestRunes[j])
        if (r != dr && r != dr + 32) { isMatch = false; break }
        j += 1
    }
    if (!isMatch) { return result }
    i = digestRunes.size

    var currentKey = ArrayList<Rune>()
    var currentValue = ArrayList<Rune>()
    var inValue = false
    var inQuote = false

    while (i < runes.size) {
        let r = runes[i]
        if (r == r'"') {
            inQuote = !inQuote
        } else if (r == r'=' && !inQuote && !inValue) {
            inValue = true
        } else if (r == r',' && !inQuote) {
            let key = String(currentKey.toArray()).trimAscii()
            let value = String(currentValue.toArray()).trimAscii()
            if (key.size > 0) {
                result[key] = value
            }
            currentKey = ArrayList<Rune>()
            currentValue = ArrayList<Rune>()
            inValue = false
        } else {
            if (inValue) { currentValue.add(r) } else { currentKey.add(r) }
        }
        i += 1
    }
    if (currentKey.size > 0) {
        let key = String(currentKey.toArray()).trimAscii()
        let value = String(currentValue.toArray()).trimAscii()
        if (key.size > 0) { result[key] = value }
    }
    result
}

/**
 * 计算 Digest 认证响应值（RFC 7616）。
 */
public func computeDigestResponse(
    username: String,
    password: String,
    realm: String,
    nonce: String,
    method: String,
    uri: String,
    qop!: ?String = None,
    nc!: ?String = None,
    cnonce!: ?String = None,
    algorithm!: String = "MD5"
): String {
    // 基于算法选择哈希函数
    let hashFn = if (algorithm == "SHA-256" || algorithm == "SHA-256-sess") {
        sha256Hex
    } else {
        md5Hex  // 默认使用 MD5 以保证向后兼容
    }
    // HA1 = H(用户名:域:密码)
    let ha1Input = "${username}:${realm}:${password}"
    let ha1 = if (algorithm == "SHA-256-sess") {
        // HA1 = SHA-256(HA1:nonce:cnonce) 用于 sess 变体
        let initialHA1 = hashFn(unsafe { ha1Input.rawData() })
        let cnonceVal = match (cnonce) { case Some(cn) => cn case None => generateCnonce() }
        hashFn(unsafe { "${initialHA1}:${nonce}:${cnonceVal}".rawData() })
    } else {
        hashFn(unsafe { ha1Input.rawData() })
    }

    // HA2 = H(方法:URI)
    let ha2Input = "${method}:${uri}"
    let ha2 = hashFn(unsafe { ha2Input.rawData() })

    match (qop) {
        case Some(q) =>
            let ncVal = match (nc) { case Some(n) => n case None => "00000001" }
            let cnonceVal = match (cnonce) { case Some(cn) => cn case None => generateCnonce() }
            // response = H(HA1:随机数:计数:客户端随机数:qop:HA2)
            let respInput = "${ha1}:${nonce}:${ncVal}:${cnonceVal}:${q}:${ha2}"
            hashFn(unsafe { respInput.rawData() })
        case None =>
            // response = H(HA1:随机数:HA2)
            let respInput = "${ha1}:${nonce}:${ha2}"
            hashFn(unsafe { respInput.rawData() })
    }
}

// ---- Digest 认证 Nonce 计数跟踪（RFC 7616） ----

/**
 * 线程安全的 nonce 计数器存储。
 * 映射 nonce 值 -> 请求计数以确保正确的 nc 值。
 */
private var nonceCounters: HashMap<String, Int64> = HashMap<String, Int64>()
private var ncMu: Mutex = Mutex()

/**
 * 获取给定 nonce 值的下一个 nonce 计数。
 * 线程安全：使用 ncMu 进行同步。
 * 返回按 RFC 7616 格式化为 8 位十六进制的计数。
 */
private func getNextNc(nonce: String): String {
    synchronized(ncMu) {
        let current = match (nonceCounters.get(nonce)) {
            case Some(c) => c
            case None => Int64(0)
        }
        nonceCounters[nonce] = current + 1
        formatNc(current + 1)
    }
}

/**
 * 将整数格式化为 8 位十六进制字符串用于 Digest nc。
 */
private func formatNc(count: Int64): String {
    let hexChars = "0123456789abcdef".toRuneArray()
    var runes = ArrayList<Rune>()
    var remaining = count
    var i: Int64 = 0
    while (i < 8) {
        let idx = Int64(remaining & 0xf)
        runes.add(hexChars[idx])
        remaining = remaining >> 4
        i += 1
    }
    let reversed = ArrayList<Rune>()
    var ri = runes.size - 1
    while (ri >= 0) { reversed.add(runes[ri]); ri -= 1 }
    String(reversed.toArray())
}

/**
 * 构建 Authorization: Digest 头部值。
 */
public func buildDigestAuthHeader(
    username: String,
    password: String,
    realm: String,
    nonce: String,
    method: String,
    uri: String,
    opaque!: ?String = None,
    qop!: ?String = None,
    algorithm!: ?String = None
): String {
    let nc = getNextNc(nonce)
    let cnonce = generateCnonce()
    let algo = match (algorithm) { case Some(a) => a case None => "MD5" }
    let response = computeDigestResponse(username, password, realm, nonce, method, uri,
        qop: qop, nc: nc, cnonce: cnonce, algorithm: algo)

    var header = "Digest username=\"${username}\", realm=\"${realm}\", nonce=\"${nonce}\", uri=\"${uri}\", response=\"${response}\""
    match (qop) {
        case Some(q) => header += ", qop=${q}, nc=${nc}, cnonce=\"${cnonce}\""
        case None => ()
    }
    match (opaque) {
        case Some(o) => header += ", opaque=\"${o}\""
        case None => ()
    }
    match (algorithm) {
        case Some(a) => header += ", algorithm=${a}"
        case None => ()
    }
    header
}

private var cnonceCounter: Int64 = 0
private var cnonceMu: Mutex = Mutex()

private func generateCnonce(): String {
    let randomBytes = secureRandom(16)
    bytesToHexLower(randomBytes)
}

