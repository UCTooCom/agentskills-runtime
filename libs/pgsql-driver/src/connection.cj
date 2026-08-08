/*
 * connection.cj —— 数据库连接与认证，是协议状态机的核心。
 *
 * 职责：
 *   - 建立 TCP 连接并发送 StartupMessage；
 *   - 完成认证（SCRAM-SHA-256 / MD5 / 明文 / trust）；
 *   - 收集 ParameterStatus、BackendKeyData，等待 ReadyForQuery；
 *   - 为预处理语句提供扩展查询协议（Parse/Bind/Describe/Execute/Sync）；
 *   - 为事务控制提供简单查询协议（Query）。
 *
 * 注意：与多数数据库驱动一致，单个连接对象不是线程安全的，不应被多个线程并发使用；
 * 并发请使用连接池（std 的 PooledDatasource）为每个线程分配独立连接。
 */

package pgsql

import std.collection.*
import std.convert.*
import std.database.sql.*
import std.net.*

// 协议版本号 3.0：高 16 位主版本 3，低 16 位次版本 0。
const PROTOCOL_VERSION_3: Int32 = 196608

/**
 * PostgreSQL 连接实现。
 */
public class PgConnection <: Connection {
    private let host: String
    private let port: UInt16
    private let user: String
    private let password: String
    private let database: String
    private let options: HashMap<String, String>

    private var sock: ?TcpSocket = None
    private var connState: ConnectionState = ConnectionState.Closed
    // ReadyForQuery 报告的事务状态：'I' 空闲、'T' 事务中、'E' 失败事务块。
    private var txStatus: Byte = b'I'
    // 服务器运行时参数（server_version、client_encoding 等）。
    private let serverParams: HashMap<String, String> = HashMap<String, String>()
    private var backendPid: Int32 = 0
    private var backendKey: Array<Byte> = Array<Byte>()
    // SCRAM 认证过程中的客户端状态。
    private var scram: ?ScramClient = None
    // 预处理语句命名计数器。
    private var stmtCounter: Int64 = 0
    // 是否已存在未结束的事务（用于禁止并行事务）。
    private var inTransactionObject: Bool = false

    public init(host: String, port: UInt16, user: String, password: String, database: String,
        options: HashMap<String, String>) {
        this.host = host
        this.port = port
        this.user = user
        this.password = password
        this.database = database
        this.options = options
    }

    /** 当前连接状态。 */
    public prop state: ConnectionState {
        get() {
            connState
        }
    }

    // 若调用方要求强制加密（required / verify_ca / verify_full），明确报错。
    private func checkSslUnsupported(): Unit {
        if (let Some(mode) <- options.get(SqlOption.SSLMode)) {
            if (mode == SqlOption.SSLModeRequired || mode == SqlOption.SSLModeVerifyCA ||
                mode == SqlOption.SSLModeVerifyFull) {
                throw SqlException("SSL/TLS connections are not supported by this driver yet; requested ssl mode '${mode}'")
            }
        }
    }

    // 取已连接套接字，未连接则抛异常。
    private func socket(): TcpSocket {
        match (sock) {
            case Some(s) => return s
            case None => throw SqlException("connection is not established")
        }
    }

    /**
     * 建立连接：TCP 连接 → StartupMessage → 认证 → 等待就绪。
     */
    public func open(): Unit {
        // 本驱动尚未实现 TLS：若调用方明确要求加密连接，必须显式报错而非静默明文连接。
        checkSslUnsupported()
        connState = ConnectionState.Connecting
        try {
            let s = TcpSocket(host, port)
            // 应用连接超时（毫秒），如已配置。
            if (let Some(ms) <- options.get(SqlOption.ConnectionTimeout)) {
                s.connect(timeout: Duration.millisecond * Int64.parse(ms))
            } else {
                s.connect()
            }
            // 读写超时（如已配置），覆盖后续所有报文交互。
            if (let Some(ms) <- options.get(SqlOption.QueryTimeout)) {
                s.readTimeout = Duration.millisecond * Int64.parse(ms)
            }
            sock = s
            sendStartup()
            authenticate()
            // 认证完成后，读取 ParameterStatus / BackendKeyData，直到 ReadyForQuery。
            let msgs = collectUntilReady()
            for ((t, r) in msgs) {
                if (t == MSG_BACKEND_KEY_DATA) {
                    backendPid = r.readInt32()
                    backendKey = r.readRemaining()
                }
            }
            connState = ConnectionState.Connected
        } catch (e: Exception) {
            connState = ConnectionState.Broken
            closeSocketQuietly()
            // 透传 SqlException，其它异常包装为 SqlException。
            match (e) {
                case se: SqlException => throw se
                case _ => throw SqlException("failed to connect to ${host}:${port}: ${e.message}")
            }
        }
    }

    // 发送 StartupMessage：协议版本 + 一组运行时参数 + 结束 0 字节。
    private func sendStartup(): Unit {
        let w = MessageWriter()
        w.putInt32(PROTOCOL_VERSION_3)
        w.putCString("user").putCString(user)
        if (!database.isEmpty()) {
            w.putCString("database").putCString(database)
        }
        // 统一使用 UTF-8，与值编解码假设一致。
        w.putCString("client_encoding").putCString("UTF8")
        w.putCString("application_name").putCString("cangjie-postgres-driver")
        w.putByte(0x00) // 参数列表结束符
        socket().write(w.buildUntyped())
    }

    // 认证消息循环：处理一系列 Authentication* 报文，直至 AuthenticationOk。
    private func authenticate(): Unit {
        while (true) {
            let (t, r) = readBackendMessage(socket())
            if (t == MSG_ERROR_RESPONSE) {
                throw parseError(r).toException()
            }
            if (t != MSG_AUTHENTICATION) {
                throw SqlException("unexpected message '${Rune(t)}' during authentication")
            }
            let authType = r.readInt32()
            if (authType == 0) {
                return // AuthenticationOk
            } else if (authType == 3) {
                // 明文口令。
                sendPasswordMessage(password)
            } else if (authType == 5) {
                // MD5：salt 为随后的 4 字节。
                let salt = r.readBytes(4)
                sendPasswordMessage(md5Password(user, password, salt))
            } else if (authType == 10) {
                // SASL：读取机制列表，选择 SCRAM-SHA-256。
                startScram(r)
            } else if (authType == 11) {
                // SASLContinue：服务器首条挑战。
                scramContinue(r)
            } else if (authType == 12) {
                // SASLFinal：服务器签名，验签。
                getScram().verifyServerFinal(String.fromUtf8(r.readRemaining()))
            } else {
                throw SqlException("unsupported authentication method (code ${authType}); only SCRAM-SHA-256, MD5 and cleartext are supported")
            }
        }
    }

    // 发送 PasswordMessage（同时用于明文与 MD5 口令）。
    private func sendPasswordMessage(secret: String): Unit {
        socket().write(MessageWriter().putCString(secret).build(MSG_PASSWORD))
    }

    // 计算 MD5 口令：'md5' + hex(md5(hex(md5(password+user)) + salt))。
    private func md5Password(user: String, password: String, salt: Array<Byte>): String {
        let inner = toHex(md5(concatBytes(password.toArray(), user.toArray())))
        let outer = toHex(md5(concatBytes(inner.toArray(), salt)))
        return "md5${outer}"
    }

    // 选择 SCRAM 机制并发送 SASLInitialResponse。
    private func startScram(r: MessageReader): Unit {
        // 读取以 0 字节结束的机制名列表，确认服务器支持 SCRAM-SHA-256。
        var supportsScram = false
        while (r.hasMore()) {
            let mech = r.readCString()
            if (mech.isEmpty()) {
                break
            }
            if (mech == "SCRAM-SHA-256") {
                supportsScram = true
            }
        }
        if (!supportsScram) {
            throw SqlException("server does not offer SCRAM-SHA-256 SASL mechanism")
        }
        let client = ScramClient(password)
        scram = client
        let clientFirst = client.clientFirstMessage()
        let firstBytes = clientFirst.toArray()
        // SASLInitialResponse：机制名 + 初始响应长度 + 初始响应。
        let w = MessageWriter()
        w.putCString(client.mechanism)
        w.putInt32(Int32(firstBytes.size))
        w.putBytes(firstBytes)
        socket().write(w.build(MSG_PASSWORD))
    }

    // 处理 SASLContinue 并发送 SASLResponse（client-final-message）。
    private func scramContinue(r: MessageReader): Unit {
        let serverFirst = String.fromUtf8(r.readRemaining())
        let clientFinal = getScram().processServerFirst(serverFirst)
        socket().write(MessageWriter().putBytes(clientFinal.toArray()).build(MSG_PASSWORD))
    }

    // 取 SCRAM 客户端，缺失则为协议错误。
    private func getScram(): ScramClient {
        match (scram) {
            case Some(c) => return c
            case None => throw SqlException("SCRAM state error: received SASL message before initialization")
        }
    }

    /**
     * 读取后端报文直至 ReadyForQuery，返回期间出现的「数据类」报文列表。
     *
     * 内部消化 ParameterStatus、NoticeResponse、NotificationResponse；
     * 遇到 ErrorResponse 时暂存，待读到 ReadyForQuery 后再抛出（确保连接回到可用状态）。
     */
    func collectUntilReady(): ArrayList<(Byte, MessageReader)> {
        let out = ArrayList<(Byte, MessageReader)>()
        var pendingError: ?PgError = None
        while (true) {
            let (t, r) = readBackendMessage(socket())
            if (t == MSG_READY_FOR_QUERY) {
                txStatus = r.readByte()
                break
            } else if (t == MSG_ERROR_RESPONSE) {
                pendingError = parseError(r)
            } else if (t == MSG_NOTICE_RESPONSE) {
                () // 通知信息：此处忽略（生产中可接入日志）
            } else if (t == MSG_PARAMETER_STATUS) {
                let k = r.readCString()
                let v = r.readCString()
                serverParams[k] = v
            } else if (t == MSG_NOTIFICATION_RESPONSE) {
                () // LISTEN/NOTIFY 通知：此处忽略
            } else {
                out.add((t, r))
            }
        }
        if (let Some(e) <- pendingError) {
            throw e.toException()
        }
        return out
    }

    /**
     * 通过简单查询协议执行一条不带参数的语句（用于事务控制等）。
     *
     * @throws SqlException 当服务器返回错误时。
     */
    func executeSimple(sql: String): Unit {
        ensureUsable()
        socket().write(MessageWriter().putCString(sql).build(MSG_QUERY))
        // 简单查询的所有响应都被消化；出错会在 collectUntilReady 中抛出。
        collectUntilReady()
    }

    /**
     * 解析并描述一条预处理语句，返回参数 OID 与结果列信息。
     *
     * @param name 服务端语句名。
     * @param sql 含 `$1,$2,...` 占位符的 SQL。
     * @return (参数 OID 列表, 结果列信息列表, 结果列 OID 列表)。
     */
    func parseAndDescribe(name: String, sql: String): (Array<Int32>, Array<ColumnInfo>, Array<Int32>) {
        ensureUsable()
        // Parse：语句名 + SQL + 0 个预指定参数类型（由服务器推断）。
        socket().write(MessageWriter().putCString(name).putCString(sql).putInt16(0).build(MSG_PARSE))
        // Describe：'S' 描述语句。
        socket().write(MessageWriter().putByte(b'S').putCString(name).build(MSG_DESCRIBE))
        socket().write(MessageWriter().build(MSG_SYNC))

        var paramOids = Array<Int32>()
        let cols = ArrayList<ColumnInfo>()
        let colOids = ArrayList<Int32>()
        for ((t, r) in collectUntilReady()) {
            if (t == MSG_PARAMETER_DESCRIPTION) {
                let n = r.readUInt16()
                paramOids = Array<Int32>(n, repeat: 0)
                for (i in 0..n) {
                    paramOids[i] = r.readInt32()
                }
            } else if (t == MSG_ROW_DESCRIPTION) {
                parseRowDescription(r, cols, colOids)
            }
            // ParseComplete / NoData 无需处理。
        }
        return (paramOids, cols.toArray(), colOids.toArray())
    }

    // 解析 RowDescription，将列信息与列 OID 分别填入两个列表。
    private func parseRowDescription(r: MessageReader, cols: ArrayList<ColumnInfo>, colOids: ArrayList<Int32>): Unit {
        let n = r.readUInt16()
        for (_ in 0..n) {
            let fieldName = r.readCString()
            r.readInt32()           // 表 OID
            r.readUInt16()          // 列属性号
            let typeOid = r.readInt32()
            let typeSize = r.readInt16()
            let typeMod = r.readInt32()
            r.readUInt16()          // 格式码
            cols.add(PgColumnInfo(fieldName, typeOid, typeSize, typeMod))
            colOids.add(typeOid)
        }
    }

    /**
     * 绑定参数并执行已解析的语句，返回结果行与命令标签。
     *
     * @param name 服务端语句名。
     * @param params 各参数文本，None 表示 SQL NULL。
     * @return (结果行集合, CommandComplete 命令标签)。
     */
    func bindAndExecute(name: String, params: Array<BoundParam>): (ArrayList<Array<?String>>, String) {
        ensureUsable()
        // Bind：未命名 portal + 语句名 + 逐参数格式码 + 参数值 + 全文本结果格式。
        let w = MessageWriter()
        w.putCString("")              // 目标 portal（未命名）
        w.putCString(name)            // 源语句名
        // 每个参数各带一个格式码（文本/二进制），数量与参数个数一致。
        w.putInt16(Int16(params.size))
        for (p in params) {
            w.putInt16(p.formatCode)
        }
        w.putInt16(Int16(params.size))
        for (p in params) {
            match (p.value) {
                case None => w.putInt32(-1) // SQL NULL
                case Some(b) =>
                    w.putInt32(Int32(b.size))
                    w.putBytes(b)
            }
        }
        w.putInt16(1).putInt16(0)     // 1 个结果格式码 = 文本，应用于所有列
        socket().write(w.build(MSG_BIND))
        // Execute：未命名 portal，行数无上限（0）。
        socket().write(MessageWriter().putCString("").putInt32(0).build(MSG_EXECUTE))
        socket().write(MessageWriter().build(MSG_SYNC))

        let rows = ArrayList<Array<?String>>()
        var tag = ""
        for ((t, r) in collectUntilReady()) {
            if (t == MSG_DATA_ROW) {
                rows.add(parseDataRow(r))
            } else if (t == MSG_COMMAND_COMPLETE) {
                tag = r.readCString()
            }
            // BindComplete / EmptyQueryResponse / PortalSuspended 无需处理。
        }
        return (rows, tag)
    }

    // 解析 DataRow，返回各列文本（None 表示 NULL）。
    private func parseDataRow(r: MessageReader): Array<?String> {
        let n = r.readUInt16()
        let row = Array<?String>(n, repeat: None)
        for (i in 0..n) {
            let len = r.readInt32()
            if (len < 0) {
                row[i] = None
            } else {
                row[i] = Some(String.fromUtf8(r.readBytes(Int64(len))))
            }
        }
        return row
    }

    /**
     * 关闭服务端预处理语句并同步。
     *
     * @param name 服务端语句名。
     */
    func closePreparedStatement(name: String): Unit {
        if (connState != ConnectionState.Connected) {
            return
        }
        try {
            socket().write(MessageWriter().putByte(b'S').putCString(name).build(MSG_CLOSE))
            socket().write(MessageWriter().build(MSG_SYNC))
            collectUntilReady()
        } catch (_: Exception) {
            // 关闭语句失败不应影响调用方流程。
        }
    }

    /** 申请下一个唯一的服务端语句名。 */
    func nextStatementName(): String {
        stmtCounter += 1
        return "cj_stmt_${stmtCounter}"
    }

    /** 标记/查询是否已存在事务对象（禁止并行事务）。 */
    func beginTransactionObject(): Unit {
        if (inTransactionObject) {
            throw SqlException("a transaction is already active on this connection; parallel transactions are not supported")
        }
        inTransactionObject = true
    }

    func endTransactionObject(): Unit {
        inTransactionObject = false
    }

    // 执行前的可用性校验。
    private func ensureUsable(): Unit {
        if (connState != ConnectionState.Connected) {
            throw SqlException("connection is not in a usable state (state: ${stateName()})")
        }
    }

    private func stateName(): String {
        if (connState == ConnectionState.Connected) {
            return "Connected"
        } else if (connState == ConnectionState.Closed) {
            return "Closed"
        } else if (connState == ConnectionState.Connecting) {
            return "Connecting"
        }
        return "Broken"
    }

    /**
     * 通过传入 SQL 创建预处理语句对象。
     */
    public func prepareStatement(sql: String): Statement {
        ensureUsable()
        return PgStatement(this, sql)
    }

    /**
     * 创建事务对象。
     *
     * @throws SqlException 当已处于事务对象状态时。
     */
    public func createTransaction(): Transaction {
        ensureUsable()
        return PgTransaction(this)
    }

    /**
     * 返回数据源元数据（服务器运行时参数快照）。
     */
    public func getMetaData(): Map<String, String> {
        let m = HashMap<String, String>()
        for ((k, v) in serverParams) {
            m[k] = v
        }
        return m
    }

    /** 关闭连接：发送 Terminate 并关闭底层套接字。 */
    public func close(): Unit {
        if (connState == ConnectionState.Closed) {
            return
        }
        try {
            if (let Some(s) <- sock) {
                s.write(MessageWriter().build(MSG_TERMINATE))
            }
        } catch (_: Exception) {
            // 终止报文发送失败可忽略，继续关闭套接字。
        }
        closeSocketQuietly()
        connState = ConnectionState.Closed
    }

    /** 连接是否已关闭。 */
    public func isClosed(): Bool {
        return connState == ConnectionState.Closed || connState == ConnectionState.Broken
    }

    // 安静地关闭套接字。
    private func closeSocketQuietly(): Unit {
        match (sock) {
            case Some(s) =>
                try {
                    s.close()
                } catch (_: Exception) {}
                sock = None
            case None => ()
        }
    }
}

// 拼接两个字节数组。
func concatBytes(a: Array<Byte>, b: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(a.size + b.size, repeat: 0)
    for (i in 0..a.size) {
        out[i] = a[i]
    }
    for (i in 0..b.size) {
        out[a.size + i] = b[i]
    }
    return out
}
