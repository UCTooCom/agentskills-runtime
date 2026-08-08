/*
 * scram.cj —— SCRAM-SHA-256 客户端状态机（RFC 5802 / RFC 7677）。
 *
 * 这是现代 PostgreSQL 的默认口令认证方式。不含通道绑定（对应机制名
 * SCRAM-SHA-256，GS2 头为 "n,,"），认证消息流：
 *   client-first  →  server-first  →  client-final  →  server-final(验签)
 */

package pgsql

import std.convert.*
import std.database.sql.*
import std.random.*

/**
 * SCRAM-SHA-256 客户端。
 *
 * 典型用法：
 * ```
 * let c = ScramClient(password)
 * let first = c.clientFirstMessage()          // 作为 SASLInitialResponse 的载荷
 * let finalMsg = c.processServerFirst(serverFirst)  // 作为 SASLResponse 的载荷
 * c.verifyServerFinal(serverFinal)            // 校验 AuthenticationSASLFinal
 * ```
 */
public class ScramClient {
    private let password: String
    private var clientNonce: String = ""
    private var clientFirstBare: String = ""
    private var serverSignature: Array<Byte> = Array<Byte>()

    public init(password: String) {
        this.password = password
    }

    // 生成 SCRAM 机制名。
    public prop mechanism: String {
        get() {
            "SCRAM-SHA-256"
        }
    }

    // 生成 18 字节随机数并 Base64 编码，得到 24 字符的客户端 nonce。
    // Base64 字母表不含逗号，符合 SCRAM 对 nonce 可打印字符的约束。
    private func generateNonce(): String {
        let rng = Random()
        let raw = Array<Byte>(18, repeat: 0)
        for (i in 0..18) {
            raw[i] = rng.nextUInt8()
        }
        return base64Encode(raw)
    }

    /**
     * 生成 client-first-message。
     *
     * 格式：`n,,n=,r=<clientNonce>`。GS2 头为 "n,,"（无通道绑定、无 authzid），
     * 用户名留空——PostgreSQL 忽略 SCRAM 中的用户名，改用启动报文中的用户名。
     *
     * @return client-first-message，整体作为 SASLInitialResponse 的初始响应载荷。
     */
    public func clientFirstMessage(): String {
        clientNonce = generateNonce()
        clientFirstBare = "n=,r=${clientNonce}"
        return "n,,${clientFirstBare}"
    }

    // 从 "k=v" 形式的片段中取出指定键的值，找不到则抛协议错误。
    private func fieldValue(parts: Array<String>, key: String): String {
        for (p in parts) {
            if (p.startsWith(key)) {
                return p[key.size..]
            }
        }
        throw SqlException("SCRAM protocol error: missing field '${key}' in server message")
    }

    /**
     * 处理 server-first-message 并生成 client-final-message。
     *
     * server-first 形如 `r=<nonce>,s=<salt-b64>,i=<iterations>`。
     * 计算 SaltedPassword、ClientProof，并预先算出 ServerSignature 以便后续验签。
     *
     * @param serverFirst 服务器首条挑战消息（去掉报文头的纯文本）。
     * @return client-final-message，作为 SASLResponse 的载荷。
     */
    public func processServerFirst(serverFirst: String): String {
        let parts = serverFirst.split(",")
        let serverNonce = fieldValue(parts, "r=")
        let saltB64 = fieldValue(parts, "s=")
        let iterStr = fieldValue(parts, "i=")

        // 服务器 nonce 必须以客户端 nonce 为前缀，否则可能遭到中间人篡改。
        if (!serverNonce.startsWith(clientNonce)) {
            throw SqlException("SCRAM protocol error: server nonce does not extend client nonce")
        }
        let iterations = Int64.parse(iterStr)
        let salt = base64Decode(saltB64)
        let pwdBytes = password.toArray()

        // SaltedPassword = Hi(password, salt, i)
        let saltedPassword = pbkdf2HmacSha256(pwdBytes, salt, iterations, 32)
        // ClientKey = HMAC(SaltedPassword, "Client Key")
        let clientKey = hmacSha256(saltedPassword, "Client Key".toArray())
        // StoredKey = H(ClientKey)
        let storedKey = sha256(clientKey)
        // ServerKey = HMAC(SaltedPassword, "Server Key")
        let serverKey = hmacSha256(saltedPassword, "Server Key".toArray())

        // client-final-message-without-proof：c=biws（即 base64("n,,")），r=<serverNonce>
        let channelBinding = base64Encode("n,,".toArray())
        let clientFinalWithoutProof = "c=${channelBinding},r=${serverNonce}"

        // AuthMessage = client-first-bare , server-first , client-final-without-proof
        let authMessage = "${clientFirstBare},${serverFirst},${clientFinalWithoutProof}"
        let authBytes = authMessage.toArray()

        // ClientSignature = HMAC(StoredKey, AuthMessage)；ClientProof = ClientKey XOR ClientSignature
        let clientSignature = hmacSha256(storedKey, authBytes)
        let clientProof = Array<Byte>(clientKey.size, repeat: 0)
        for (i in 0..clientKey.size) {
            clientProof[i] = clientKey[i] ^ clientSignature[i]
        }

        // 预计算 ServerSignature = HMAC(ServerKey, AuthMessage) 供验签。
        serverSignature = hmacSha256(serverKey, authBytes)

        return "${clientFinalWithoutProof},p=${base64Encode(clientProof)}"
    }

    /**
     * 校验 server-final-message 中的服务器签名。
     *
     * server-final 形如 `v=<ServerSignature-b64>`。签名不匹配说明服务器无法证明其
     * 持有正确口令验证因子（可能是伪造服务器），应判定认证失败。
     *
     * @param serverFinal 服务器最终消息（去掉报文头的纯文本）。
     */
    public func verifyServerFinal(serverFinal: String): Unit {
        let parts = serverFinal.split(",")
        // 出现 e=... 字段表示服务器报告 SASL 错误。
        for (p in parts) {
            if (p.startsWith("e=")) {
                throw SqlException("SCRAM authentication failed: ${p[2..]}")
            }
        }
        let sigB64 = fieldValue(parts, "v=")
        let received = base64Decode(sigB64)
        if (received.size != serverSignature.size) {
            throw SqlException("SCRAM authentication failed: server signature length mismatch")
        }
        for (i in 0..received.size) {
            if (received[i] != serverSignature[i]) {
                throw SqlException("SCRAM authentication failed: server signature mismatch")
            }
        }
    }
}
