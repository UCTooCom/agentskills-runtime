/*
 * sign.cj — 元宝搜索（腾讯云 wsa · SearchPro）TC3-HMAC-SHA256 签名
 *
 * 与脚本轨 scripts/sign.ts / sign.py 算法完全一致：五步密钥派生 + 规范请求串。
 *
 * 安全约束（spec §4.3、design G7）：
 *   - 密钥只从 .env 读取，禁止硬编码、禁止写入任何产物 / 日志 / 异常；
 *   - 派生中间值仅存在于函数栈内。
 */
package skill_yuanbao_policy

import std.collection.HashMap
import std.fs.File
import std.time.DateTime
import stdx.crypto.digest.*
import stdx.encoding.hex.*

public class YbSign {
    public static let HOST: String = "wsa.tencentcloudapi.com"
    public static let ENDPOINT: String = "https://wsa.tencentcloudapi.com/"
    public static let SERVICE: String = "wsa"
    public static let ACTION: String = "SearchPro"
    public static let API_VERSION: String = "2025-05-08"
    public static let ALGORITHM: String = "TC3-HMAC-SHA256"

    /// .env 候选路径：插件进程的工作目录由宿主决定，逐个尝试直到读到密钥
    public static let ENV_CANDIDATES: Array<String> = [
        ".env",
        "../.env",
        "../../.env",
        "../../../.env",
        "../../../../.env",
        "../../../../../.env",
    ]

    /// 读取 .env 并解析为键值对（行格式 KEY=VALUE）
    public static func loadEnv(): HashMap<String, String> {
        let env = HashMap<String, String>()
        for (p in YbSign.ENV_CANDIDATES) {
            let text = YbSign.tryReadText(p)
            if (let Some(t) <- text) {
                YbSign.parseInto(env, t)
                if (env.get("QCLOUD_COS_SECRET_ID").isSome()) {
                    break
                }
            }
        }
        return env
    }

    /// 取云 API 凭据；缺失返回空串（由调用方决定告警，不抛异常）
    public static func credential(): (String, String) {
        let env = YbSign.loadEnv()
        let id = env.get("QCLOUD_COS_SECRET_ID").getOrDefault({ => "" })
        let key = env.get("QCLOUD_COS_SECRET_KEY").getOrDefault({ => "" })
        return (id, key)
    }

    public static func sha256Hex(s: String): String {
        let d = SHA256()
        d.write(s.toArray())
        return toHexString(d.finish())
    }

    public static func hmacRaw(key: Array<Byte>, msg: String): Array<Byte> {
        let m = HMAC(key, HashType.SHA256)
        m.write(msg.toArray())
        return m.finish()
    }

    public static func hmacHex(key: Array<Byte>, msg: String): String {
        return toHexString(YbSign.hmacRaw(key, msg))
    }

    /// 构造签名请求头（TC3-HMAC-SHA256 五步派生）
    public static func buildHeaders(body: String, secretId: String, secretKey: String, ts: Int64): HashMap<String, String> {
        let date = DateTime.nowUTC().format("yyyy-MM-dd")
        let canonicalHeaders = "content-type:application/json\nhost:${YbSign.HOST}\n"
        let signedHeaders = "content-type;host"
        let canonicalRequest = "POST\n/\n\n${canonicalHeaders}\n${signedHeaders}\n${YbSign.sha256Hex(body)}"
        let credentialScope = "${date}/${YbSign.SERVICE}/tc3_request"
        let stringToSign = "${YbSign.ALGORITHM}\n${ts}\n${credentialScope}\n${YbSign.sha256Hex(canonicalRequest)}"

        let secretDate = YbSign.hmacRaw(("TC3" + secretKey).toArray(), date)
        let secretService = YbSign.hmacRaw(secretDate, YbSign.SERVICE)
        let secretSigning = YbSign.hmacRaw(secretService, "tc3_request")
        let signature = YbSign.hmacHex(secretSigning, stringToSign)

        let authorization =
            "${YbSign.ALGORITHM} Credential=${secretId}/${credentialScope}, " +
            "SignedHeaders=${signedHeaders}, Signature=${signature}"

        let headers = HashMap<String, String>()
        headers.add("Authorization", authorization)
        headers.add("Content-Type", "application/json")
        headers.add("Host", YbSign.HOST)
        headers.add("X-TC-Action", YbSign.ACTION)
        headers.add("X-TC-Version", YbSign.API_VERSION)
        headers.add("X-TC-Timestamp", ts.toString())
        return headers
    }

    /// 当前 Unix 秒（工程先例：DateTime.now() - DateTime.UnixEpoch）
    public static func nowSeconds(): Int64 {
        return (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() / 1000
    }

    private static func parseInto(env: HashMap<String, String>, text: String): Unit {
        for (line in text.lines()) {
            let parts = line.split("=", 1)
            if (parts.size < 2) {
                continue
            }
            let key = parts[0].trimAscii()
            let value = YbSign.unquote(parts[1].trimAscii())
            if (key.size == 0) {
                continue
            }
            env.add(key, value)
        }
    }

    private static func unquote(v: String): String {
        if (v.size >= 2 && v[0] == v[v.size - 1]) {
            return v[1..v.size - 1]
        }
        return v
    }

    private static func tryReadText(path: String): Option<String> {
        try {
            return Some(String.fromUtf8(File.readFrom(path)))
        } catch (_: Exception) {
            return None
        }
    }
}
