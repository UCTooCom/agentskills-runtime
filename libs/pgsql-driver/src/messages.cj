/*
 * messages.cj —— 报文类型常量、报文分帧读取与 Error/Notice 字段解析。
 *
 * 依据 54.7 节，除启动阶段的少量报文外，所有报文都形如：
 *     类型字节(1) | 长度 Int32(含自身) | 报文体
 * 因此可在不依赖报文体内部结构的情况下完成分帧。
 */

package pgsql

import std.database.sql.*
import std.net.*

// ===== 后端（B）报文类型标识 =====
public const MSG_AUTHENTICATION: Byte = b'R'
public const MSG_BACKEND_KEY_DATA: Byte = b'K'
public const MSG_PARAMETER_STATUS: Byte = b'S'
public const MSG_READY_FOR_QUERY: Byte = b'Z'
public const MSG_ROW_DESCRIPTION: Byte = b'T'
public const MSG_DATA_ROW: Byte = b'D'
public const MSG_COMMAND_COMPLETE: Byte = b'C'
public const MSG_ERROR_RESPONSE: Byte = b'E'
public const MSG_NOTICE_RESPONSE: Byte = b'N'
public const MSG_NOTIFICATION_RESPONSE: Byte = b'A'
public const MSG_PARSE_COMPLETE: Byte = b'1'
public const MSG_BIND_COMPLETE: Byte = b'2'
public const MSG_CLOSE_COMPLETE: Byte = b'3'
public const MSG_NO_DATA: Byte = b'n'
public const MSG_PARAMETER_DESCRIPTION: Byte = b't'
public const MSG_PORTAL_SUSPENDED: Byte = b's'
public const MSG_EMPTY_QUERY_RESPONSE: Byte = b'I'

// ===== 前端（F）报文类型标识 =====
public const MSG_QUERY: Byte = b'Q'
public const MSG_PARSE: Byte = b'P'
public const MSG_BIND: Byte = b'B'
public const MSG_DESCRIBE: Byte = b'D'
public const MSG_EXECUTE: Byte = b'E'
public const MSG_SYNC: Byte = b'S'
public const MSG_TERMINATE: Byte = b'X'
public const MSG_CLOSE: Byte = b'C'
public const MSG_FLUSH: Byte = b'H'
// 口令/SASL/GSS 响应共用同一类型字节，按上下文区分。
public const MSG_PASSWORD: Byte = b'p'

/**
 * 从流式套接字读满 n 个字节。
 *
 * 套接字单次 `read` 可能返回部分数据，这里循环直到读满，
 * 读到 EOF（返回 <= 0）则认为连接已被服务器关闭。
 *
 * @param sock 已连接的套接字。
 * @param n 期望读取的字节数。
 * @return 长度为 n 的字节数组。
 */
public func readFull(sock: StreamingSocket, n: Int64): Array<Byte> {
    let out = Array<Byte>(n, repeat: 0)
    var off = 0
    while (off < n) {
        // 每轮只申请剩余所需大小的缓冲，避免越过本报文边界读取后续报文。
        let tmp = Array<Byte>(n - off, repeat: 0)
        let got = sock.read(tmp)
        if (got <= 0) {
            throw SqlException("connection closed by server while expecting ${n - off} more bytes")
        }
        for (i in 0..got) {
            out[off + i] = tmp[i]
        }
        off += got
    }
    return out
}

/**
 * 读取一条带类型标识的后端报文，返回类型字节与其报文体读取器。
 *
 * @param sock 已连接的套接字。
 * @return (类型字节, 报文体 MessageReader)。
 */
public func readBackendMessage(sock: StreamingSocket): (Byte, MessageReader) {
    // 报文头：1 字节类型 + 4 字节长度（含长度自身）。
    let header = readFull(sock, 5)
    let msgType = header[0]
    let len = (Int64(header[1]) << 24) | (Int64(header[2]) << 16) | (Int64(header[3]) << 8) | Int64(header[4])
    let bodyLen = len - 4
    if (bodyLen < 0) {
        throw SqlException("protocol error: invalid message length ${len}")
    }
    let body = if (bodyLen == 0) {
        Array<Byte>()
    } else {
        readFull(sock, bodyLen)
    }
    return (msgType, MessageReader(body))
}

/**
 * Error/Notice 报文解析结果。
 *
 * 字段含义见 54.8 节。仅保留常用字段，未识别的字段类型按协议要求被静默忽略。
 */
public struct PgError {
    public var severity: String = ""    // S / V：ERROR、FATAL、WARNING 等
    public var code: String = ""        // C：5 字符 SQLSTATE
    public var message: String = ""     // M：主错误信息
    public var detail: String = ""      // D：细节
    public var hint: String = ""        // H：提示
    public var position: String = ""    // P：错误游标位置
    public var context: String = ""     // W：上下文
    public var schema: String = ""      // s：模式名
    public var table: String = ""       // t：表名
    public var column: String = ""      // c：列名
    public var dataType: String = ""    // d：数据类型名
    public var constraint: String = ""  // n：约束名

    public init() {}

    /**
     * 拼装为人类可读的异常信息，附带可用的次要字段。
     */
    public func describe(): String {
        let sb = StringBuilder()
        if (!severity.isEmpty()) {
            sb.append(severity)
            sb.append(": ")
        }
        sb.append(message)
        if (!code.isEmpty()) {
            sb.append(" (SQLSTATE ")
            sb.append(code)
            sb.append(")")
        }
        if (!detail.isEmpty()) {
            sb.append("\nDETAIL: ")
            sb.append(detail)
        }
        if (!hint.isEmpty()) {
            sb.append("\nHINT: ")
            sb.append(hint)
        }
        return sb.toString()
    }

    /**
     * 转换为 std 的 [SqlException]，保留 SQLSTATE。
     */
    public func toException(): SqlException {
        return SqlException(describe(), code, 0)
    }
}

/**
 * 解析 ErrorResponse / NoticeResponse 报文体：一连串 `字段类型字节 + C字符串`，
 * 以单个 0 字节作为结束。
 *
 * @param reader 指向报文体起始处的读取器。
 * @return 解析后的 [PgError]。
 */
public func parseError(reader: MessageReader): PgError {
    var err = PgError()
    while (reader.hasMore()) {
        let fieldType = reader.readByte()
        if (fieldType == 0x00) {
            break // 终止符
        }
        let value = reader.readCString()
        match (fieldType) {
            case b'S' => err.severity = value
            case b'V' => err.severity = value // 非本地化严重级别，覆盖 S
            case b'C' => err.code = value
            case b'M' => err.message = value
            case b'D' => err.detail = value
            case b'H' => err.hint = value
            case b'P' => err.position = value
            case b'W' => err.context = value
            case b's' => err.schema = value
            case b't' => err.table = value
            case b'c' => err.column = value
            case b'd' => err.dataType = value
            case b'n' => err.constraint = value
            case _ => () // 未知字段：静默忽略
        }
    }
    return err
}
