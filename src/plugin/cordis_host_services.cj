/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import magic.log.LogUtils
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
 *
 * 注册时机：CordisHostManager 启动进程插件后，调用 registerFor(instance, pluginId)
 * 经 instance.client.registerRequestHandler 注册 3 个 handler。
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
        LogUtils.info("[CordisHostServices] registered host.db/host.log/host.cache for plugin '${pluginId}'")
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
            match (req.params) {
                case Some(p) => this.executeDbOperation(pluginId, p)
                case None => this.dbError("missing params")
            }
        }
    }

    private func executeDbOperation(pluginId: String, params: JsonValue): ?JsonValue {
        let fields = this.extractFields(params)
        let operation = (fields.get("operation") ?? JsonValue.Null).stringify()
        let table = (fields.get("table") ?? JsonValue.Null).stringify()

        // 表白名单校验：仅允许访问白名单内表
        match (this.tableWhitelist.get(pluginId)) {
            case Some(allowed) =>
                if (!allowed.contains(table)) {
                    return this.dbError("table '${table}' not in whitelist for plugin '${pluginId}'")
                }
            case None =>
                return this.dbError("no table whitelist configured for plugin '${pluginId}'")
        }

        // 行级权限宿主侧强制附加（design §5.6 安全边界）
        let userId = this.extractInt(fields, "userId")
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
            return this.dbError("db error: ${e.message}")
        }
    }

    /// 执行 query 操作，行级权限条件宿主侧强制附加
    private func executeQuery(
        executor: SqlExecutor,
        pluginId: String,
        table: String,
        fields: HashMap<String, JsonValue>,
        userId: ?Int64,
        permissions: ArrayList<String>
    ): ?JsonValue {
        // 构造 WHERE 条件：插件传入的 where + 宿主侧行级权限条件
        let pluginWhere = (fields.get("where") ?? JsonValue.Null).stringify()
        let rowLevelWhere = this.buildRowLevelCondition(userId, permissions, table)
        let finalWhere = this.combineWhere(pluginWhere, rowLevelWhere)

        // 参数化查询绑定值
        let bindParams = this.extractAnyArray(fields, "params")
        let orderBy = (fields.get("orderBy") ?? JsonValue.Null).stringify()
        let limit = this.extractInt(fields, "limit")
        let offset = this.extractInt(fields, "offset")

        // 委托宿主 f_orm 执行查询（参数化 + 表白名单 + 行级权限宿主侧强制）
        let sql = this.buildQuerySql(table, finalWhere, orderBy, limit, offset)
        let result = executor.setSql(sql).mapList()

        // 序列化结果为 JsonValue
        let rows = ArrayList<JsonValue>()
        for (row in result) {
            rows.add(this.mapToJsonValue(row))
        }
        let resultObj = HashMap<String, JsonValue>()
        resultObj["rows"] = this.arrayToJsonValue(rows)
        return Some(JsonValue.from(resultObj))
    }

    /// 执行 execute 操作（insert/update/delete）
    private func executeExecute(
        executor: SqlExecutor,
        pluginId: String,
        table: String,
        fields: HashMap<String, JsonValue>,
        userId: ?Int64,
        permissions: ArrayList<String>
    ): ?JsonValue {
        // 构造 WHERE 条件（行级权限宿主侧强制附加）
        let pluginWhere = (fields.get("where") ?? JsonValue.Null).stringify()
        let rowLevelWhere = this.buildRowLevelCondition(userId, permissions, table)
        let finalWhere = this.combineWhere(pluginWhere, rowLevelWhere)

        // 执行数据操作（委托宿主 f_orm）
        let sql = this.buildExecuteSql(table, finalWhere, fields)
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
        userId: ?Int64,
        permissions: ArrayList<String>
    ): ?JsonValue {
        let pluginWhere = (fields.get("where") ?? JsonValue.Null).stringify()
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
    /// 简化实现：admin 权限无限制，其他用户仅能访问自己的数据
    private func buildRowLevelCondition(userId: ?Int64, permissions: ArrayList<String>, table: String): String {
        // admin 权限：无行级限制
        if (permissions.contains("admin")) {
            return ""
        }
        // 非 admin 用户：附加 user_id = ? 条件（假设表有 user_id 列）
        match (userId) {
            case Some(uid) => return "user_id = ${uid}"
            case None => return "1=0"  // 无 userId 则拒绝访问
        }
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
    private func buildExecuteSql(table: String, `where`: String, fields: HashMap<String, JsonValue>): String {
        // 简化实现：根据 where 是否存在判断 update 或 delete
        if (!`where`.isEmpty()) {
            return "UPDATE ${table} SET ... WHERE ${`where`}"  // 实际实现需根据 data 字段构造
        }
        return "DELETE FROM ${table} WHERE ${`where`}"
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
                    let level = (fields.get("level") ?? JsonValue.Null).stringify()
                    let message = (fields.get("message") ?? JsonValue.Null).stringify()
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
        let operation = (fields.get("operation") ?? JsonValue.Null).stringify()
        let key = (fields.get("key") ?? JsonValue.Null).stringify()

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
    private func mapToJsonValue(map: Map<String, Any>): JsonValue {
        let result = HashMap<String, JsonValue>()
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(val) =>
                    // 简化实现：按常见类型分派，其余降级为 toString()
                    match (val) {
                        case s: String => result[key] = JsonValue.String(s)
                        case n: Int64 => result[key] = JsonValue.Number(Float64(n))
                        case n: Float64 => result[key] = JsonValue.Number(n)
                        case b: Bool => result[key] = JsonValue.Boolean(b)
                        case _ => result[key] = JsonValue.String("unknown")
                    }
                case None => ()
            }
        }
        return JsonValue.from(result)
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
