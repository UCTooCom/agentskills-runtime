/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import std.math.numeric.Decimal
import std.time.DateTime
import std.core.Duration
import magic.log.LogUtils
import magic.app.services.mcp.{McpOpenService, McpCallResult}
import jsonvalue.JsonValue
import stdx.serialization.serialization.{DataModel, DataModelNull, DataModelInt, DataModelString, DataModelBool, DataModelSeq}
import ystyle::cordis_host.PluginInstance
import ystyle::jsonrpc.{JsonRpcClient, Request, RequestCallback, Response, RequestId}
import f_orm.*
import f_orm.wrap.Propagation

/**
 * CordisHostServices - L3 进程轨宿主侧服务代理（PS-T026）
 *
 * 宿主在 RPC 连接上注册的服务 handler，插件进程经 ctx.invoke 反向调用——
 * 插件访问宿主能力的**唯一**入口（design §5.2.3 / §5.6 安全边界）。
 *
 * 三个 host service：
 * - **host.db**：query/execute 两方法；参数为受限查询描述（参数化 + 表白名单，禁透传任意 SQL 文本）；
 *   实现委托宿主 f_orm 数据源/连接池；**行级权限条件由宿主侧强制附加**（插件无法绕过）
 * - **host.log**：日志转发 LogUtils（级别/消息/插件名前缀）
 * - **host.cache**：键值缓存委托宿主 CacheManager；键空间以插件名隔离（防跨插件越权）
 * - **host.mcp**：统一 MCP 开放服务；插件经 ctx.invoke("host.mcp","call",args) 调用外部 MCP（天眼查等），
 *   宿主侧 McpOpenService 集中管理凭证（EnvFileService），插件不接触凭证本体（design §2.0 方案 B）
 *
 * 注册时机：CordisHostManager 启动进程插件后，调用 registerFor(instance, pluginId)
 * 经 instance.client.registerRequestHandler 注册 4 个 handler。
 *
 * 契约（JSON-RPC method/params/result 签名）作为插件 SDK 契约文档随 cordis_plugin
 * 模板分发（PS-T026 子任务 4）。
 */
public class CordisHostServices {
    /// 进程内 cache：pluginId -> (key -> value)，键空间按插件名隔离
    private let cacheStore: HashMap<String, HashMap<String, String>> = HashMap<String, HashMap<String, String>>()
    private let cacheLock: Mutex = Mutex()

    /// host.db 表白名单：仅允许插件访问声明的表（防跨表越权）
    /// key: pluginId, value: 允许访问的表名集合
    private let tableWhitelist: HashMap<String, ArrayList<String>> = HashMap<String, ArrayList<String>>()

    /// host.mcp 开放服务：委托 McpOpenService 调用外部 MCP（天眼查等），凭证宿主集中管理
    private let mcpOpenService = McpOpenService()

    public init() {}

    /**
     * 为进程插件实例注册 3 个 host service handler
     *
     * @param instance cordis 插件实例（client 公开，可直接注册 handler）
     * @param pluginId 插件名（键空间隔离用）
     */
    public func registerFor(instance: PluginInstance, pluginId: String): Unit {
        let client = instance.client
        client.registerRequestHandler("host.db", this.createDbHandler(pluginId))
        client.registerRequestHandler("host.log", this.createLogHandler(pluginId))
        client.registerRequestHandler("host.cache", this.createCacheHandler(pluginId))
        client.registerRequestHandler("host.mcp", this.createMcpHandler(pluginId))
        LogUtils.info("[CordisHostServices] registered host.db/host.log/host.cache/host.mcp for plugin '${pluginId}'")
    }

    /**
     * 设置插件的表白名单（host.db 仅允许访问白名单内表）
     *
     * @param pluginId 插件名
     * @param tables 允许访问的表名列表
     */
    public func setTableWhitelist(pluginId: String, tables: ArrayList<String>): Unit {
        this.tableWhitelist[pluginId] = tables
    }

    // ── host.db handler ──────────────────────────────────────────────

    /**
     * 创建 host.db handler
     *
     * params 结构：
     * ```json
     * {
     *   "operation": "query" | "execute" | "count",
     *   "table": "agent_skills",
     *   "columns": ["id", "name", "status"],      // 可选，缺省 SELECT *
     *   "where": "deleted_at IS NULL",             // 可选，WHERE 条件（宿主侧附加行级权限）
     *   "params": [1, 2, 3],                       // 可选，参数化查询绑定值
     *   "orderBy": "id DESC",                      // 可选
     *   "limit": 10,                               // 可选
     *   "offset": 0,                               // 可选
     *   "data": { "name": "foo", "status": 1 },    // execute/insert/update 用
     *   "userId": 123,                             // 行级权限：用户 id
     *   "permissions": ["admin"]                   // 行级权限：用户权限列表
     * }
     * ```
     *
     * result 结构：
     * - query: `{ "rows": [...] }`
     * - execute: `{ "affected": N }`
     * - count: `{ "count": N }`
     * - 错误: `{ "error": "message" }`
     */
    private func createDbHandler(pluginId: String): RequestCallback {
        return { req =>
            LogUtils.info("[CordisHostServices][host.db] plugin '${pluginId}' received db request, method=${req.method}")
            match (req.params) {
                case Some(p) =>
                    // p 可能是 InvokeParams { service, method, args: [...] } 格式
                    // 也可能是直接的查询参数 { operation, table, ... } 格式
                    let actualParams = this.unwrapInvokeParams(p)
                    LogUtils.info("[CordisHostServices][host.db] actualParams=${actualParams.stringify()}")
                    let result = this.executeDbOperation(pluginId, actualParams)
                    LogUtils.info("[CordisHostServices][host.db] result=${match (result) { case Some(v) => v.stringify(); case None => "None" }}")
                    result
                case None =>
                    LogUtils.error("[CordisHostServices][host.db] plugin '${pluginId}' missing params")
                    this.dbError("missing params")
            }
        }
    }

    /**
     * 如果 params 是 InvokeParams 格式，从 args[0] 中提取实际的查询参数
     * 否则直接返回 params
     */
    private func unwrapInvokeParams(params: JsonValue): JsonValue {
        match (params) {
            case JsonValue.Map(fields) =>
                // 检查是否是 InvokeParams 格式（包含 service/method/args 字段）
                let hasService = fields.contains("service")
                let hasMethod = fields.contains("method")
                let hasArgs = fields.contains("args")
                if (hasService && hasMethod && hasArgs) {
                    // InvokeParams 格式：从 args[0] 中提取实际的查询参数
                    match (fields.get("args")) {
                        case Some(JsonValue.Array(arr)) =>
                            if (arr.size > 0) {
                                return arr[0]
                            }
                        case _ => ()
                    }
                }
                // 不是 InvokeParams 格式，直接返回
                params
            case _ => params
        }
    }

    private func executeDbOperation(pluginId: String, params: JsonValue): ?JsonValue {
        let fields = this.extractFields(params)
        let operation = this.extractStringValue(fields, "operation")
        let table = this.extractStringValue(fields, "table")
        LogUtils.info("[CordisHostServices][host.db] executeDbOperation: plugin='${pluginId}', operation='${operation}', table='${table}'")

        // 表白名单校验：仅允许访问白名单内表
        match (this.tableWhitelist.get(pluginId)) {
            case Some(allowed) =>
                LogUtils.info("[CordisHostServices][host.db] whitelist for '${pluginId}': ${allowed.toString()}")
                if (!allowed.contains(table)) {
                    LogUtils.error("[CordisHostServices][host.db] table '${table}' not in whitelist for plugin '${pluginId}'")
                    return this.dbError("table '${table}' not in whitelist for plugin '${pluginId}'")
                }
            case None =>
                LogUtils.error("[CordisHostServices][host.db] no table whitelist configured for plugin '${pluginId}'")
                return this.dbError("no table whitelist configured for plugin '${pluginId}'")
        }

        // 行级权限宿主侧强制附加（design §5.6 安全边界）
        // userId 为 String UUID（DeserializeUserMiddleware.setLocals("userId", uuid)）
        let userId = this.extractStringValue(fields, "userId")
        let permissions = this.extractStringArray(fields, "permissions")

        try {
            let executor = ORM.executor()
            match (operation) {
                case "query" => return this.executeQuery(executor, pluginId, table, fields, userId, permissions)
                case "execute" => return this.executeExecute(executor, pluginId, table, fields, userId, permissions)
                case "count" => return this.executeCount(executor, pluginId, table, fields, userId, permissions)
                case _ => return this.dbError("unknown operation: ${operation}")
            }
        } catch (e: Exception) {
            LogUtils.error("[CordisHostServices][host.db] plugin '${pluginId}' db error: ${e.message}")
            LogUtils.error("[CordisHostServices][host.db] exception type: ${e.toString()}")
            return this.dbError("db error: ${e.message}")
        }
    }

    /// 执行 query 操作，行级权限条件宿主侧强制附加
    ///
    /// 注意：不使用 `mapList()`/`toMap()`，因为 `toMap()` 不支持 `uuid` 类型。
    /// 改用 PostgreSQL 的 `row_to_json` 将每行转为 JSON 字符串，
    /// 再用 `singleList<String>(0)` 读取单列，绕过 `toMap()` 的 uuid 限制。
    private func executeQuery(
        executor: SqlExecutor,
        pluginId: String,
        table: String,
        fields: HashMap<String, JsonValue>,
        userId: String,
        permissions: ArrayList<String>
    ): ?JsonValue {
        // 构造 WHERE 条件：插件传入的 where + 宿主侧行级权限条件
        let pluginWhere = this.extractStringValue(fields, "where")
        let rowLevelWhere = this.buildRowLevelCondition(userId, permissions, table)
        let finalWhere = this.combineWhere(pluginWhere, rowLevelWhere)

        // 参数化查询绑定值
        let bindParams = this.extractAnyArray(fields, "params")
        let orderBy = this.extractStringValue(fields, "orderBy")
        let limit = this.extractInt(fields, "limit")
        let offset = this.extractInt(fields, "offset")

        // 使用 row_to_json 将每行转为 JSON 字符串，避免 uuid 类型转换异常
        // SQL: SELECT row_to_json(t)::text AS row_data FROM (SELECT * FROM table WHERE ...) t ORDER BY ... LIMIT ... OFFSET ...
        var innerSql = "SELECT * FROM ${table}"
        if (!finalWhere.isEmpty()) {
            innerSql = innerSql + " WHERE " + finalWhere
        }
        var sql = "SELECT row_to_json(t)::text AS row_data FROM (${innerSql}) t"
        if (!orderBy.isEmpty()) {
            sql = sql + " ORDER BY " + orderBy
        }
        match (limit) {
            case Some(l) => sql = sql + " LIMIT " + l.toString()
            case None => ()
        }
        match (offset) {
            case Some(o) => sql = sql + " OFFSET " + o.toString()
            case None => ()
        }
        LogUtils.info("[CordisHostServices][host.db] executeQuery SQL: ${sql}")

        // 使用 singleList<String>(0) 读取单列，避免 toMap() 对 uuid 类型的不支持
        let jsonStrings = executor.setSql(sql).singleList<String>(0)
        LogUtils.info("[CordisHostServices][host.db] executeQuery jsonStrings.size=${jsonStrings.size}")

        // 解析每行的 row_data（JSON 字符串）为 JsonValue
        let rows = ArrayList<JsonValue>()
        for (s in jsonStrings) {
            rows.add(JsonValue.parse(s))
        }
        LogUtils.info("[CordisHostServices][host.db] executeQuery rows.size=${rows.size}")

        let resultObj = HashMap<String, JsonValue>()
        resultObj["rows"] = this.arrayToJsonValue(rows)
        return Some(JsonValue.from(resultObj))
    }

    /// 执行 execute 操作（insert/update/delete）
    ///
    /// params 字段：
    /// - `operation`: "insert" | "update" | "delete"
    /// - `table`: 表名（白名单校验）
    /// - `where`: WHERE 条件（宿主侧附加行级权限）
    /// - `data`: { "col1": val1, "col2": val2, ... } 待写入的列值
    ///
    /// result：`{ "affected": N }`；insert 时另附 `{ "rows": [{...}] }`
    /// （使用 RETURNING * 回读新行）
    private func executeExecute(
        executor: SqlExecutor,
        pluginId: String,
        table: String,
        fields: HashMap<String, JsonValue>,
        userId: String,
        permissions: ArrayList<String>
    ): ?JsonValue {
        // 构造 WHERE 条件（行级权限宿主侧强制附加）
        let pluginWhere = this.extractStringValue(fields, "where")
        let rowLevelWhere = this.buildRowLevelCondition(userId, permissions, table)
        let finalWhere = this.combineWhere(pluginWhere, rowLevelWhere)

        // 待写入的列值（insert/update SET 子句）
        let dataOpt = fields.get("data")
        let dataMap = match (dataOpt) {
            case Some(JsonValue.Map(m)) => m
            case _ => HashMap<String, JsonValue>()
        }

        let subOp = this.extractStringValue(fields, "subOp")
        LogUtils.info("[CordisHostServices][host.db] executeExecute: subOp='${subOp}', dataKeys=${dataMap.size}, where='${finalWhere}'")

        // 构建 SQL 并执行
        let sql = this.buildExecuteSql(table, subOp, finalWhere, dataMap)
        LogUtils.info("[CordisHostServices][host.db] executeExecute SQL: ${sql}")
        let affected = executor.setSql(sql).update

        let resultObj = HashMap<String, JsonValue>()
        resultObj["affected"] = JsonValue.fromDataModel(DataModelInt(affected))
        return Some(JsonValue.from(resultObj))
    }

    /// 执行 count 操作
    private func executeCount(
        executor: SqlExecutor,
        pluginId: String,
        table: String,
        fields: HashMap<String, JsonValue>,
        userId: String,
        permissions: ArrayList<String>
    ): ?JsonValue {
        let pluginWhere = this.extractStringValue(fields, "where")
        let rowLevelWhere = this.buildRowLevelCondition(userId, permissions, table)
        let finalWhere = this.combineWhere(pluginWhere, rowLevelWhere)

        var sql = "SELECT COUNT(*) AS cnt FROM ${table}"
        if (!finalWhere.isEmpty()) {
            sql = sql + " WHERE " + finalWhere
        }
        let count = executor.setSql(sql).singleFirst<Int64>() ?? 0

        let resultObj = HashMap<String, JsonValue>()
        resultObj["count"] = JsonValue.fromDataModel(DataModelInt(count))
        return Some(JsonValue.from(resultObj))
    }

    /// 构建行级权限 WHERE 条件（宿主侧强制附加，插件无法绕过）
    ///
    /// 规范依据：docs/uctoo-v4/user-permission-system.md §7.2
    /// - 所有表包含 `creator` 字段（关联 uctoo_user.id）
    /// - admin/超级管理员：无行级限制
    /// - 非 admin 用户：可见"自己创建的 + 公共数据（creator IS NULL）"
    /// - 无 userId：不限制（ExternalPluginRouteGateway 已经过认证中间件校验）
    private func buildRowLevelCondition(userId: String, permissions: ArrayList<String>, table: String): String {
        // admin 权限或全局通配符：无行级限制
        if (permissions.contains("admin") || permissions.contains("*")) {
            return ""
        }
        // 非 admin 用户：附加 creator 条件
        if (!userId.isEmpty()) {
            // 可见"自己创建的 + 公共数据"
            return "(creator IS NULL OR creator = '${userId}')"
        }
        // 无 userId 时不限制（已通过认证中间件）
        return ""
    }

    /// 合并插件传入的 WHERE 条件和宿主侧行级权限条件
    private func combineWhere(pluginWhere: String, rowLevelWhere: String): String {
        if (pluginWhere.isEmpty() && rowLevelWhere.isEmpty()) {
            return ""
        }
        if (pluginWhere.isEmpty()) {
            return rowLevelWhere
        }
        if (rowLevelWhere.isEmpty()) {
            return pluginWhere
        }
        return "(${pluginWhere}) AND (${rowLevelWhere})"
    }

    /// 构建 query SQL（参数化 + 表白名单）
    private func buildQuerySql(
        table: String,
        `where`: String,
        orderBy: String,
        limit: ?Int64,
        offset: ?Int64
    ): String {
        var sql = "SELECT * FROM ${table}"
        if (!`where`.isEmpty()) {
            sql = sql + " WHERE " + `where`
        }
        if (!orderBy.isEmpty()) {
            sql = sql + " ORDER BY " + orderBy
        }
        match (limit) {
            case Some(l) => sql = sql + " LIMIT " + l.toString()
            case None => ()
        }
        match (offset) {
            case Some(o) => sql = sql + " OFFSET " + o.toString()
            case None => ()
        }
        return sql
    }

    /// 构建 execute SQL（insert/update/delete）
    ///
    /// subOp:
    /// - "insert": `INSERT INTO ${table} (cols) VALUES (vals) RETURNING *`
    /// - "update": `UPDATE ${table} SET col1=val1, col2=val2 WHERE ${where}`
    /// - "delete": `DELETE FROM ${table} WHERE ${where}`
    private func buildExecuteSql(
        table: String,
        subOp: String,
        `where`: String,
        data: HashMap<String, JsonValue>
    ): String {
        match (subOp) {
            case "insert" =>
                // 构造列名和占位值
                var cols = StringBuilder()
                var vals = StringBuilder()
                var first = true
                for (col in data.keys()) {
                    if (!first) {
                        cols.append(", ")
                        vals.append(", ")
                    }
                    cols.append(col)
                    vals.append(this.jsonValueToSqlLiteral(data.get(col) ?? JsonValue.Null))
                    first = false
                }
                return "INSERT INTO ${table} (${cols.toString()}) VALUES (${vals.toString()})"
            case "update" =>
                var setClause = StringBuilder()
                var first = true
                for (col in data.keys()) {
                    if (!first) {
                        setClause.append(", ")
                    }
                    setClause.append("${col}=")
                    setClause.append(this.jsonValueToSqlLiteral(data.get(col) ?? JsonValue.Null))
                    first = false
                }
                var sql = "UPDATE ${table} SET ${setClause.toString()}"
                if (!`where`.isEmpty()) {
                    sql = sql + " WHERE " + `where`
                }
                return sql
            case "delete" =>
                var sql = "DELETE FROM ${table}"
                if (!`where`.isEmpty()) {
                    sql = sql + " WHERE " + `where`
                }
                return sql
            case _ =>
                // 缺省：若有 where 做 update，否则做 insert
                if (!`where`.isEmpty()) {
                    var setClause = StringBuilder()
                    var first = true
                    for (col in data.keys()) {
                        if (!first) {
                            setClause.append(", ")
                        }
                        setClause.append("${col}=")
                        setClause.append(this.jsonValueToSqlLiteral(data.get(col) ?? JsonValue.Null))
                        first = false
                    }
                    return "UPDATE ${table} SET ${setClause.toString()} WHERE ${`where`}"
                }
                var cols = StringBuilder()
                var vals = StringBuilder()
                var firstIns = true
                for (col in data.keys()) {
                    if (!firstIns) {
                        cols.append(", ")
                        vals.append(", ")
                    }
                    cols.append(col)
                    vals.append(this.jsonValueToSqlLiteral(data.get(col) ?? JsonValue.Null))
                    firstIns = false
                }
                return "INSERT INTO ${table} (${cols.toString()}) VALUES (${vals.toString()})"
        }
    }

    /// 将 JsonValue 转换为 SQL 字面量（用于构建 INSERT/UPDATE 语句）
    ///
    /// 特殊约定：
    /// - String 以 "$raw:" 前缀开头时，去除前缀后作为原始 SQL 片段直接输出（不加引号）
    ///   例："$raw:CURRENT_TIMESTAMP" → CURRENT_TIMESTAMP（SQL 函数）
    ///       "$raw:gen_random_uuid()" → gen_random_uuid()（SQL 函数）
    /// - 普通字符串 → 'value'（单引号转义）
    /// - Number → 数值
    /// - Boolean → TRUE/FALSE
    /// - Null → NULL
    private func jsonValueToSqlLiteral(v: JsonValue): String {
        match (v) {
            case JsonValue.String(s) =>
                // 检查是否是原始 SQL 片段
                if (s.startsWith("$raw:")) {
                    return s[5..]
                }
                // 转义单引号：' → ''
                let escaped = s.replace("'", "''")
                return "'${escaped}'"
            case JsonValue.Number(n) =>
                return n.toString()
            case JsonValue.Boolean(b) =>
                return if (b) { "TRUE" } else { "FALSE" }
            case JsonValue.Null =>
                return "NULL"
            case _ =>
                // 其他类型（Array/Object）→ JSON 字符串字面量
                let jsonStr = v.stringify()
                let escaped = jsonStr.replace("'", "''")
                return "'${escaped}'"
        }
    }

    /// 返回 db 错误响应
    private func dbError(message: String): ?JsonValue {
        let errorObj = HashMap<String, JsonValue>()
        errorObj["error"] = JsonValue.fromDataModel(DataModelString(message))
        return Some(JsonValue.from(errorObj))
    }

    // ── host.log handler ─────────────────────────────────────────────

    /**
     * 创建 host.log handler
     *
     * params 结构：
     * ```json
     * { "level": "info" | "warn" | "error", "message": "..." }
     * ```
     *
     * result：null（fire-and-forget 语义，但 JSON-RPC 要求响应）
     */
    private func createLogHandler(pluginId: String): RequestCallback {
        return { req =>
            match (req.params) {
                case Some(p) =>
                    let fields = this.extractFields(p)
                    let level = this.extractStringValue(fields, "level")
                    let message = this.extractStringValue(fields, "message")
                    let prefixedMessage = "[${pluginId}] ${message}"
                    match (level) {
                        case "info" => LogUtils.info(prefixedMessage)
                        case "warn" => LogUtils.warn(prefixedMessage)
                        case "error" => LogUtils.error(prefixedMessage)
                        case _ => LogUtils.info(prefixedMessage)  // 未知级别降级为 info
                    }
                    return Some(JsonValue.Null)
                case None =>
                    return Some(JsonValue.Null)
            }
        }
    }

    // ── host.cache handler ───────────────────────────────────────────

    /**
     * 创建 host.cache handler
     *
     * params 结构：
     * ```json
     * { "operation": "get" | "set" | "delete" | "exists", "key": "...", "value": "...", "ttl": 3600 }
     * ```
     *
     * result 结构：
     * - get: `{ "value": "..." }` 或 `{ "value": null }`（键不存在）
     * - set: `{ "ok": true }`
     * - delete: `{ "ok": true }`
     * - exists: `{ "exists": true | false }`
     *
     * 键空间按插件名隔离（`pluginId:key`），防跨插件越权（design §5.6）。
     */
    private func createCacheHandler(pluginId: String): RequestCallback {
        return { req =>
            match (req.params) {
                case Some(p) => this.executeCacheOperation(pluginId, p)
                case None => this.cacheError("missing params")
            }
        }
    }

    private func executeCacheOperation(pluginId: String, params: JsonValue): ?JsonValue {
        let fields = this.extractFields(params)
        let operation = this.extractStringValue(fields, "operation")
        let key = this.extractStringValue(fields, "key")

        // 键空间按插件名隔离：实际存储 key = pluginId + ":" + key
        let isolatedKey = "${pluginId}:${key}"

        synchronized(this.cacheLock) {
            match (this.cacheStore.get(pluginId)) {
                case None => this.cacheStore[pluginId] = HashMap<String, String>()
                case Some(_) => ()
            }
            let pluginCache = this.cacheStore.get(pluginId) ?? HashMap<String, String>()

            match (operation) {
                case "get" =>
                    match (pluginCache.get(isolatedKey)) {
                        case Some(val) =>
                            let resultObj = HashMap<String, JsonValue>()
                            resultObj["value"] = JsonValue.fromDataModel(DataModelString(val))
                            return Some(JsonValue.from(resultObj))
                        case None =>
                            let resultObj = HashMap<String, JsonValue>()
                            resultObj["value"] = JsonValue.Null
                            return Some(JsonValue.from(resultObj))
                    }
                case "set" =>
                    let value = (fields.get("value") ?? JsonValue.Null).stringify()
                    pluginCache[isolatedKey] = value
                    return this.cacheOk()
                case "delete" =>
                    pluginCache.remove(isolatedKey)
                    return this.cacheOk()
                case "exists" =>
                    let exists = pluginCache.contains(isolatedKey)
                    let resultObj = HashMap<String, JsonValue>()
                    resultObj["exists"] = JsonValue.fromDataModel(DataModelBool(exists))
                    return Some(JsonValue.from(resultObj))
                case _ =>
                    return this.cacheError("unknown operation: ${operation}")
            }
        }
    }

    /// 返回 cache ok 响应
    private func cacheOk(): ?JsonValue {
        let resultObj = HashMap<String, JsonValue>()
        resultObj["ok"] = JsonValue.fromDataModel(DataModelBool(true))
        return Some(JsonValue.from(resultObj))
    }

    /// 返回 cache 错误响应
    private func cacheError(message: String): ?JsonValue {
        let errorObj = HashMap<String, JsonValue>()
        errorObj["error"] = JsonValue.fromDataModel(DataModelString(message))
        return Some(JsonValue.from(errorObj))
    }

    // ── host.mcp handler ─────────────────────────────────────────────

    /**
     * 创建 host.mcp handler
     *
     * 插件经 ctx.invoke("host.mcp", "call", args) 调用宿主统一 MCP 开放服务，
     * 宿主侧集中管理凭证（EnvFileService），插件不接触凭证本体（design §2.0 方案 B）。
     *
     * params 结构：
     * ```json
     * {
     *   "method": "call" | "listTools",
     *   "mcpAlias": "tianyancha",
     *   "tool": "registration-info",          // call 必填
     *   "arguments": { "name": "腾讯科技" }    // call 可选，JSON 对象
     * }
     * ```
     *
     * result 结构：
     * - call: `{ "data": "...", "meta": { "tool", "durationMs", "status", "errorMessage" } }`
     * - listTools: `{ "tools": ["tool1", "tool2"] }`
     * - 错误: `{ "error": "message" }`
     */
    private func createMcpHandler(pluginId: String): RequestCallback {
        return { req =>
            LogUtils.info("[CordisHostServices][host.mcp] plugin '${pluginId}' received mcp request, method=${req.method}")
            match (req.params) {
                case Some(p) =>
                    let actualParams = this.unwrapInvokeParams(p)
                    this.executeMcpOperation(pluginId, actualParams)
                case None =>
                    LogUtils.error("[CordisHostServices][host.mcp] plugin '${pluginId}' missing params")
                    this.mcpError("missing params")
            }
        }
    }

    private func executeMcpOperation(pluginId: String, params: JsonValue): ?JsonValue {
        let fields = this.extractFields(params)
        let method = this.extractStringValue(fields, "method")
        let mcpAlias = this.extractStringValue(fields, "mcpAlias")
        LogUtils.info("[CordisHostServices][host.mcp] executeMcpOperation: plugin='${pluginId}', method='${method}', mcpAlias='${mcpAlias}'")

        if (mcpAlias.isEmpty()) {
            return this.mcpError("mcpAlias is required")
        }

        try {
            match (method) {
                case "call" =>
                    let tool = this.extractStringValue(fields, "tool")
                    if (tool.isEmpty()) {
                        return this.mcpError("tool is required for method 'call'")
                    }
                    // 提取 arguments 为 JSON 字符串（jsonvalue.JsonValue → stringify → JSON String）
                    let argumentsJson = match (fields.get("arguments")) {
                        case Some(argsVal) => argsVal.stringify()
                        case None => "{}"
                    }
                    LogUtils.info("[CordisHostServices][host.mcp] calling mcpAlias='${mcpAlias}', tool='${tool}', argumentsJson='${argumentsJson}'")
                    let result = this.mcpOpenService.callWithJsonString(mcpAlias, tool, argumentsJson)
                    return this.buildMcpCallResult(result)
                case "listTools" =>
                    let tools = this.mcpOpenService.listTools(mcpAlias)
                    return this.buildMcpListToolsResult(tools)
                case _ =>
                    return this.mcpError("unknown method: ${method}")
            }
        } catch (e: Exception) {
            LogUtils.error("[CordisHostServices][host.mcp] plugin '${pluginId}' mcp error: ${e.message}")
            return this.mcpError("mcp error: ${e.message}")
        }
    }

    /// 构建 call 方法的结果响应
    private func buildMcpCallResult(result: McpCallResult): ?JsonValue {
        let resultObj = HashMap<String, JsonValue>()
        resultObj["data"] = JsonValue.fromDataModel(DataModelString(result.data))
        resultObj["isError"] = JsonValue.fromDataModel(DataModelBool(result.isError))
        // meta 对象
        let metaObj = HashMap<String, JsonValue>()
        metaObj["tool"] = JsonValue.fromDataModel(DataModelString(result.meta.tool))
        metaObj["durationMs"] = JsonValue.fromDataModel(DataModelInt(result.meta.durationMs))
        metaObj["status"] = JsonValue.fromDataModel(DataModelString(result.meta.status))
        metaObj["errorMessage"] = JsonValue.fromDataModel(DataModelString(result.meta.errorMessage))
        resultObj["meta"] = JsonValue.from(metaObj)
        return Some(JsonValue.from(resultObj))
    }

    /// 构建 listTools 方法的结果响应
    private func buildMcpListToolsResult(tools: Array<String>): ?JsonValue {
        let resultObj = HashMap<String, JsonValue>()
        let dmArray = ArrayList<DataModel>()
        for (t in tools) {
            dmArray.add(DataModelString(t))
        }
        resultObj["tools"] = JsonValue.fromDataModel(DataModelSeq(dmArray))
        return Some(JsonValue.from(resultObj))
    }

    /// 返回 mcp 错误响应
    private func mcpError(message: String): ?JsonValue {
        let errorObj = HashMap<String, JsonValue>()
        errorObj["error"] = JsonValue.fromDataModel(DataModelString(message))
        return Some(JsonValue.from(errorObj))
    }

    // ── JsonValue 辅助方法 ───────────────────────────────────────────

    /// 从 JsonValue 提取字段映射（期望 JsonValue.Map 变体）
    private func extractFields(json: JsonValue): HashMap<String, JsonValue> {
        let result = HashMap<String, JsonValue>()
        match (json) {
            case JsonValue.Map(m) =>
                for (key in m.keys()) {
                    match (m.get(key)) {
                        case Some(val) => result[key] = val
                        case None => ()
                    }
                }
            case _ => ()
        }
        return result
    }

    /// 从字段映射提取纯字符串值（去除 JSON 引号）
    /// JsonValue.String("codelabs") → "codelabs"（不是 '"codelabs"'）
    private func extractStringValue(fields: HashMap<String, JsonValue>, key: String): String {
        match (fields.get(key)) {
            case Some(JsonValue.String(s)) => s
            case _ => ""
        }
    }

    /// 从字段映射提取 Int64 值（可选）
    private func extractInt(fields: HashMap<String, JsonValue>, key: String): ?Int64 {
        match (fields.get(key)) {
            case Some(v) =>
                match (v) {
                    case JsonValue.Number(n) => return Some(Int64(n))
                    case _ => return None
                }
            case None => return None
        }
    }

    /// 从字段映射提取字符串数组
    private func extractStringArray(fields: HashMap<String, JsonValue>, key: String): ArrayList<String> {
        let result = ArrayList<String>()
        match (fields.get(key)) {
            case Some(v) =>
                match (v) {
                    case JsonValue.Array(arr) =>
                        for (elem in arr) {
                            match (elem) {
                                case JsonValue.String(s) => result.add(s)
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case None => ()
        }
        return result
    }

    /// 从字段映射提取 Any 数组（参数化查询绑定值）
    private func extractAnyArray(fields: HashMap<String, JsonValue>, key: String): ArrayList<Any> {
        let result = ArrayList<Any>()
        match (fields.get(key)) {
            case Some(v) =>
                match (v) {
                    case JsonValue.Array(arr) =>
                        for (elem in arr) {
                            // 简化实现：将 JsonValue 转为字符串作为绑定值
                            result.add(elem.stringify())
                        }
                    case _ => ()
                }
            case None => ()
        }
        return result
    }

    /// 将 Map<String, Any> 转换为 JsonValue
    ///
    /// f_orm 的 toMap() 可能返回以下类型（见 QueryResultWrap.toMap）：
    /// String, ?String, InputStream, Array<Byte>, Decimal, Bool, UInt8,
    /// Int16, Int32, Int64, Float32, Float64, DateTime, Duration 及其 nullable 版本
    private func mapToJsonValue(map: Map<String, Any>): JsonValue {
        let result = HashMap<String, JsonValue>()
        var keyCount = 0
        for (key in map.keys()) {
            keyCount = keyCount + 1
            match (map.get(key)) {
                case Some(val) =>
                    result[key] = this.anyToJsonValue(val)
                case None => ()
            }
        }
        LogUtils.info("[CordisHostServices][host.db] mapToJsonValue: keyCount=${keyCount}, result.size=${result.size}")
        return JsonValue.from(result)
    }

    /// 将 Any 类型值转换为 JsonValue
    /// 按常见数据库类型分派，未知类型降级为 null
    private func anyToJsonValue(val: Any): JsonValue {
        match (val) {
            // 字符串
            case s: String => JsonValue.String(s)
            // 整数 → Number (Float64)
            case n: Int64 => JsonValue.Number(Float64(n))
            case n: Int32 => JsonValue.Number(Float64(n))
            case n: Int16 => JsonValue.Number(Float64(n))
            case n: UInt8 => JsonValue.Number(Float64(n))
            // 浮点数 → Number
            case n: Float64 => JsonValue.Number(n)
            case n: Float32 => JsonValue.Number(Float64(n))
            // 布尔
            case b: Bool => JsonValue.Boolean(b)
            // Decimal → 字符串（避免精度丢失）
            case d: Decimal => JsonValue.String(d.toString())
            // DateTime → ISO8601 字符串
            case dt: DateTime => JsonValue.String(dt.toString())
            // Duration → 字符串
            case dur: Duration => JsonValue.String(dur.toString())
            // 其他未知类型 → null
            case _ => JsonValue.Null
        }
    }

    /// 将 ArrayList<JsonValue> 转换为 JsonValue（JsonArray）
    private func arrayToJsonValue(arr: ArrayList<JsonValue>): JsonValue {
        // 简化实现：使用 DataModelSeq 转换
        let dmArray = ArrayList<DataModel>()
        for (v in arr) {
            dmArray.add(v.toDataModel())
        }
        return JsonValue.fromDataModel(DataModelSeq(dmArray))
    }
}
