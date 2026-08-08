/*
 * datasource.cj —— 数据源与连接字符串解析。
 *
 * 解析形如 `postgres://user:password@host:port/database?k=v&...` 的连接串，
 * 并允许通过 opts 数组与 setOption 覆盖或补充连接参数（键见 std 的 SqlOption）。
 */

package pgsql

import std.collection.*
import std.convert.*
import std.database.sql.*

/**
 * PostgreSQL 数据源。保存解析后的连接参数，可重复 [connect] 产生新连接。
 */
public class PgDatasource <: Datasource {
    private var host: String
    private var port: UInt16
    private var user: String
    private var password: String
    private var database: String
    private let options: HashMap<String, String>
    private var closed: Bool = false

    public init(host: String, port: UInt16, user: String, password: String, database: String,
        options: HashMap<String, String>) {
        this.host = host
        this.port = port
        this.user = user
        this.password = password
        this.database = database
        this.options = options
    }

    /**
     * 设置连接选项；识别到的标准键会同步更新对应的连接参数。
     *
     * @param key 选项名（见 [SqlOption]）。
     * @param value 选项值。
     */
    public func setOption(key: String, value: String): Unit {
        options[key] = value
        // 标准键同时更新解析后的连接字段。
        if (key == SqlOption.Host) {
            host = value
        } else if (key == SqlOption.Username) {
            user = value
        } else if (key == SqlOption.Password) {
            password = value
        } else if (key == SqlOption.Database) {
            database = value
        }
    }

    /**
     * 建立并返回一个新连接。
     *
     * @throws SqlException 当连接或认证失败时。
     */
    public func connect(): Connection {
        if (closed) {
            throw SqlException("datasource is closed")
        }
        let conn = PgConnection(host, port, user, password, database, options)
        conn.open()
        return conn
    }

    /** 关闭数据源（阻止后续 connect）。底层连接由各自的 close 负责。 */
    public func close(): Unit {
        closed = true
    }

    /** 数据源是否已关闭。 */
    public func isClosed(): Bool {
        return closed
    }
}

/**
 * 解析连接字符串与选项，构造 [PgDatasource]。
 *
 * @param connectionString 形如 `postgres://user:pwd@host:port/db?k=v` 的连接串。
 * @param opts 额外的 (键, 值) 选项数组，覆盖连接串中的同名项。
 * @return 解析得到的数据源。
 */
public func parseDatasource(connectionString: String, opts: Array<(String, String)>): PgDatasource {
    var host = "localhost"
    var port: UInt16 = 5432
    var user = ""
    var password = ""
    var database = ""
    let options = HashMap<String, String>()

    // 1) 去掉 scheme（"://" 之前的部分）。
    var rest = connectionString
    if (let Some(idx) <- connectionString.indexOf("://")) {
        rest = connectionString[idx + 3..]
    }

    // 2) 切出查询串（"?" 之后）。
    if (let Some(qIdx) <- rest.indexOf("?")) {
        let query = rest[qIdx + 1..]
        rest = rest[0..qIdx]
        for (pair in query.split("&", removeEmpty: true)) {
            if (let Some(eq) <- pair.indexOf("=")) {
                options[pair[0..eq]] = pair[eq + 1..]
            }
        }
    }

    // 3) 切出 userinfo（第一个 "@" 之前）。
    if (let Some(atIdx) <- rest.indexOf("@")) {
        let userInfo = rest[0..atIdx]
        rest = rest[atIdx + 1..]
        if (let Some(colon) <- userInfo.indexOf(":")) {
            user = userInfo[0..colon]
            password = userInfo[colon + 1..]
        } else {
            user = userInfo
        }
    }

    // 4) 切出数据库名（第一个 "/" 之后），其余为 host[:port]。
    var hostPort = rest
    if (let Some(slash) <- rest.indexOf("/")) {
        hostPort = rest[0..slash]
        database = rest[slash + 1..]
    }

    // 5) 解析 host 与 port。
    if (!hostPort.isEmpty()) {
        if (let Some(colon) <- hostPort.indexOf(":")) {
            host = hostPort[0..colon]
            port = UInt16.parse(hostPort[colon + 1..])
        } else {
            host = hostPort
        }
    }

    // 6) 合并 opts 数组（优先级高于连接串）。
    for ((k, v) in opts) {
        options[k] = v
    }

    // 7) 标准选项键覆盖连接字段。
    if (let Some(v) <- options.get(SqlOption.Host)) {
        host = v
    }
    if (let Some(v) <- options.get(SqlOption.Username)) {
        user = v
    }
    if (let Some(v) <- options.get(SqlOption.Password)) {
        password = v
    }
    if (let Some(v) <- options.get(SqlOption.Database)) {
        database = v
    }

    // 数据库名缺省时回退为用户名（与 PostgreSQL 约定一致）。
    if (database.isEmpty()) {
        database = user
    }

    return PgDatasource(host, port, user, password, database, options)
}
