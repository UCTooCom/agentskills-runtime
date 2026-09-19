/*
 * V4 CRUD RPC handler 框架（codelabs）
 * 独立进程插件，通过 ctx.invoke("host.db", ...) 访问宿主数据库
 *
 * 路由（遵循 uctoo V4 API 规范，basePath /api/v1/uctoo/codelabs）：
 *   GET  /:limit/:page               分页列表
 *   GET  /:id                        单条查询
 *   POST /add                        创建
 *   POST /edit                       更新（含批量 ids / 恢复 deleted_at='0'）
 *   POST /del                        删除（含批量 ids / 硬删 force=1）
 *   POST /empty-recycle-bin          清空回收站（物理删除 deleted_at NOT NULL 的行）
 *
 * 列表键名遵守 API 规范 §8.2：表名 + s（复数） → "codelabss"
 */
package skill_codelabs

import ystyle::cordis_plugin.{PluginContext, PluginRuntime}
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

public class CodelabsHandlers {
    /// 插件上下文（register 时注入），handler 内经 ctx.invoke 访问宿主服务
    private static var ctx: ?PluginContext = None

    /// codelabs 表可写字段白名单（防止插件越权写入未授权列）
    /// 不包含 id（数据库 DEFAULT gen_random_uuid 自增）、created_at/updated_at（数据库自维护）
    private static let WRITABLE_COLUMNS: Array<String> = [
        "command", "arguments", "data_structure", "template_code",
        "config_data", "algorithm", "result", "input", "output",
        "remark", "template_file", "data_source", "creator",
        "deleted_at"
    ]

    public static func register(ctx: PluginContext): Unit {
        CodelabsHandlers.ctx = ctx
        // 注册通用服务 handler：宿主 invoke 转发时 service="codelabs"
        // 内部根据 ExternalRequest 的 method + path 分发到具体 CRUD handler
        ctx.registerHandler("codelabs", { method, args => CodelabsHandlers.dispatch(method, args) })
    }

    /**
     * 路由分发：根据 HTTP method + path 分发到具体 CRUD handler
     * args[0] 是 ExternalRequest { method, path, queryParams, body, userId, permissions, ... }
     */
    private static func dispatch(httpMethod: String, args: Array<JsonValue>): JsonValue {
        if (args.size == 0) {
            return CodelabsHandlers.errResult(1, "missing args")
        }
        // 解析 ExternalRequest
        let extReq = args[0]
        match (extReq) {
            case JsonValue.Map(fields) =>
                let path = CodelabsHandlers.extractString(fields, "path")
                let reqMethod = CodelabsHandlers.extractString(fields, "method")
                // 路由匹配
                if (reqMethod == "GET" && path.contains("/codelabs/")) {
                    // /api/v1/uctoo/codelabs/:limit/:page → list
                    // /api/v1/uctoo/codelabs/:id → get（单条）
                    let parts = path.split("/")
                    var codelabsIdx: Int64 = -1
                    for (i in 0..parts.size) {
                        if (parts[i] == "codelabs") {
                            codelabsIdx = i
                            break
                        }
                    }
                    if (codelabsIdx >= 0 && codelabsIdx + 1 < parts.size) {
                        let remaining = parts.size - codelabsIdx - 1
                        if (remaining >= 2) {
                            // :limit/:page → list
                            return CodelabsHandlers.handleList(fields, args)
                        } else {
                            // :id → get
                            return CodelabsHandlers.handleGet(fields, args)
                        }
                    }
                    return CodelabsHandlers.handleList(fields, args)
                } else if (reqMethod == "POST") {
                    if (path.contains("/codelabs/add")) {
                        return CodelabsHandlers.handleAdd(fields, args)
                    } else if (path.contains("/codelabs/edit")) {
                        return CodelabsHandlers.handleEdit(fields, args)
                    } else if (path.contains("/codelabs/del")) {
                        return CodelabsHandlers.handleDel(fields, args)
                    } else if (path.contains("/codelabs/empty-recycle-bin")) {
                        return CodelabsHandlers.handleEmptyRecycleBin(fields, args)
                    }
                }
                return CodelabsHandlers.errResult(1, "no route matched: ${reqMethod} ${path}")
            case _ => return CodelabsHandlers.errResult(1, "invalid args format")
        }
        return CodelabsHandlers.errResult(1, "dispatch fallback")
    }

    // ── CRUD handlers ───────────────────────────────────────────────

    /**
     * 创建：POST /api/v1/uctoo/codelabs/add
     * body: { command, arguments, data_structure, ... }
     * 行级权限：creator = userId（宿主侧 host.db 会附加行级 WHERE，但 INSERT 时需要插件显式设置 creator）
     */
    private static func handleAdd(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[codelabs] handleAdd entered")
        let ctxOpt = CodelabsHandlers.ctx
        match (ctxOpt) {
            case None => return CodelabsHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                // 1. 提取 body（POST 请求体）
                let body = CodelabsHandlers.extractBody(fields)
                match (body) {
                    case None => return CodelabsHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        // 2. 构造 INSERT data，只允许白名单字段
                        let dataMap = HashMap<String, JsonValue>()
                        for (col in CodelabsHandlers.WRITABLE_COLUMNS) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        // 3. 设置 creator = userId（行级权限要求）
                        let userId = CodelabsHandlers.extractString(fields, "userId")
                        if (!userId.isEmpty()) {
                            dataMap["creator"] = JsonValue.String(userId)
                        }
                        // command 是 NOT NULL 字段，必须存在
                        match (dataMap.get("command")) {
                            case None => return CodelabsHandlers.errResult(40002, "command 字段不能为空")
                            case Some(_) => ()
                        }
                        // 4. 调用 host.db execute insert
                        let execParam = HashMap<String, JsonValue>()
                        execParam["operation"] = JsonValue.String("execute")
                        execParam["subOp"] = JsonValue.String("insert")
                        execParam["table"] = JsonValue.String("codelabs")
                        execParam["data"] = JsonValue.from(dataMap)
                        // 行级权限参数
                        let permArr = ArrayList<JsonValue>()
                        match (fields.get("permissions")) {
                            case Some(JsonValue.Array(arr)) =>
                                for (p in arr) { permArr.add(p) }
                            case _ => ()
                        }
                        execParam["permissions"] = JsonValue.Array(permArr)
                        if (!userId.isEmpty()) {
                            execParam["userId"] = JsonValue.String(userId)
                        }
                        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                        execArgs[0] = JsonValue.from(execParam)
                        let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                        eprintln("[codelabs] host.db insert result: ${execResult.stringify()}")
                        // 5. 查询刚创建的记录（通过 creator + command 查询）
                        // 由于 INSERT 没有 RETURNING 支持（f_orm 限制），用后续 query 回读
                        let queryParam = HashMap<String, JsonValue>()
                        queryParam["operation"] = JsonValue.String("query")
                        queryParam["table"] = JsonValue.String("codelabs")
                        queryParam["where"] = JsonValue.String("command = '${CodelabsHandlers.extractStringFromMap(dataMap, "command")}' AND deleted_at IS NULL")
                        queryParam["orderBy"] = JsonValue.String("created_at DESC")
                        queryParam["limit"] = JsonValue.Number(1.0)
                        if (!userId.isEmpty()) {
                            queryParam["userId"] = JsonValue.String(userId)
                        }
                        queryParam["permissions"] = JsonValue.Array(permArr)
                        let queryArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                        queryArgs[0] = JsonValue.from(queryParam)
                        let queryResult = ctx.invoke<JsonValue, JsonValue>("host.db", "query", queryArgs)
                        // 6. 返回创建的记录
                        match (queryResult) {
                            case JsonValue.Map(qFields) =>
                                match (qFields.get("rows")) {
                                    case Some(JsonValue.Array(rows)) =>
                                        if (rows.size > 0) {
                                            return rows[0]
                                        }
                                    case _ => ()
                                }
                            case _ => ()
                        }
                        // 兜底：返回成功（无法回读新记录）
                        return CodelabsHandlers.okResult("add")
                }
        }
    }

    /**
     * 更新：POST /api/v1/uctoo/codelabs/edit
     * body 单条: { id, ...updateFields }
     * body 批量: { ids: "uuid1,uuid2,...", ...updateFields }
     * body 恢复: { id 或 ids, deleted_at: "0" }  // deleted_at='0' → 软恢复（SET deleted_at=NULL）
     */
    private static func handleEdit(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[codelabs] handleEdit entered")
        let ctxOpt = CodelabsHandlers.ctx
        match (ctxOpt) {
            case None => return CodelabsHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = CodelabsHandlers.extractBody(fields)
                match (body) {
                    case None => return CodelabsHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = CodelabsHandlers.extractString(fields, "userId")
                        let permArr = ArrayList<JsonValue>()
                        match (fields.get("permissions")) {
                            case Some(JsonValue.Array(arr)) =>
                                for (p in arr) { permArr.add(p) }
                            case _ => ()
                        }
                        // 判断是批量（ids）还是单条（id）
                        let idsVal = bodyMap.get("ids")
                        let idVal = bodyMap.get("id")
                        // 判断是否是恢复操作（deleted_at='0'）
                        let deletedAtVal = bodyMap.get("deleted_at")
                        let isRestore = match (deletedAtVal) {
                            case Some(JsonValue.String(s)) => s == "0"
                            case _ => false
                        }
                        if (isRestore) {
                            // 恢复操作：SET deleted_at=NULL WHERE id IN (...)
                            return CodelabsHandlers.doRestore(ctx, bodyMap, userId, permArr)
                        }
                        // 构造 UPDATE data，只允许白名单字段
                        let dataMap = HashMap<String, JsonValue>()
                        for (col in CodelabsHandlers.WRITABLE_COLUMNS) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        // updated_at 由数据库触发器维护，不显式设置
                        if (dataMap.size == 0) {
                            return CodelabsHandlers.errResult(40002, "没有可更新的字段")
                        }
                        // 构造 WHERE 条件
                        var whereClause = ""
                        match (idsVal) {
                            case Some(JsonValue.String(idsStr)) =>
                                // 批量更新：WHERE id IN ('uuid1','uuid2',...)
                                let idList = CodelabsHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return CodelabsHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (${CodelabsHelpers_joinQuoted(idList)})"
                            case _ =>
                                // 单条更新
                                match (idVal) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return CodelabsHandlers.errResult(40002, "缺少 id 或 ids 参数")
                                }
                        }
                        // 调用 host.db execute update
                        let execParam = HashMap<String, JsonValue>()
                        execParam["operation"] = JsonValue.String("execute")
                        execParam["subOp"] = JsonValue.String("update")
                        execParam["table"] = JsonValue.String("codelabs")
                        execParam["where"] = JsonValue.String(whereClause)
                        execParam["data"] = JsonValue.from(dataMap)
                        execParam["permissions"] = JsonValue.Array(permArr)
                        if (!userId.isEmpty()) {
                            execParam["userId"] = JsonValue.String(userId)
                        }
                        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                        execArgs[0] = JsonValue.from(execParam)
                        let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                        eprintln("[codelabs] host.db update result: ${execResult.stringify()}")
                        // 返回更新后的记录（单条）
                        match (idVal) {
                            case Some(JsonValue.String(idStr)) =>
                                let getResult = CodelabsHandlers.queryById(ctx, idStr, userId, permArr)
                                return getResult
                            case _ => ()
                        }
                        // 批量更新：返回成功
                        return CodelabsHandlers.okResult("edit")
                }
        }
    }

    /**
     * 删除：POST /api/v1/uctoo/codelabs/del
     * body 单条: { id }
     * body 批量: { ids: "uuid1,uuid2,..." }
     * body 硬删: { id 或 ids, force: 1 }  // force=1 → 物理删除
     * 软删：SET deleted_at = CURRENT_TIMESTAMP WHERE id IN (...)
     */
    private static func handleDel(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[codelabs] handleDel entered")
        let ctxOpt = CodelabsHandlers.ctx
        match (ctxOpt) {
            case None => return CodelabsHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = CodelabsHandlers.extractBody(fields)
                match (body) {
                    case None => return CodelabsHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = CodelabsHandlers.extractString(fields, "userId")
                        let permArr = ArrayList<JsonValue>()
                        match (fields.get("permissions")) {
                            case Some(JsonValue.Array(arr)) =>
                                for (p in arr) { permArr.add(p) }
                            case _ => ()
                        }
                        // 解析 id / ids
                        let idVal = bodyMap.get("id")
                        let idsVal = bodyMap.get("ids")
                        var whereClause = ""
                        var isBatch = false
                        match (idsVal) {
                            case Some(JsonValue.String(idsStr)) =>
                                let idList = CodelabsHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return CodelabsHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (${CodelabsHelpers_joinQuoted(idList)})"
                                isBatch = true
                            case _ =>
                                match (idVal) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return CodelabsHandlers.errResult(40002, "缺少 id 或 ids 参数")
                                }
                        }
                        // 判断是否硬删（force=1）
                        let forceVal = bodyMap.get("force")
                        let isHardDelete = match (forceVal) {
                            case Some(JsonValue.Number(n)) => n == 1.0
                            case Some(JsonValue.String(s)) => s == "1" || s == "true"
                            case _ => false
                        }
                        // 调用 host.db execute
                        let execParam = HashMap<String, JsonValue>()
                        execParam["operation"] = JsonValue.String("execute")
                        execParam["table"] = JsonValue.String("codelabs")
                        execParam["where"] = JsonValue.String(whereClause)
                        execParam["permissions"] = JsonValue.Array(permArr)
                        if (!userId.isEmpty()) {
                            execParam["userId"] = JsonValue.String(userId)
                        }
                        if (isHardDelete) {
                            // 物理删除
                            execParam["subOp"] = JsonValue.String("delete")
                        } else {
                            // 软删除：SET deleted_at = CURRENT_TIMESTAMP
                            // "$raw:" 前缀让 host.db 生成原始 SQL 函数（不加引号）
                            let dataMap = HashMap<String, JsonValue>()
                            dataMap["deleted_at"] = JsonValue.String("$raw:CURRENT_TIMESTAMP")
                            execParam["subOp"] = JsonValue.String("update")
                            execParam["data"] = JsonValue.from(dataMap)
                        }
                        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                        execArgs[0] = JsonValue.from(execParam)
                        let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                        eprintln("[codelabs] host.db delete result: ${execResult.stringify()}")
                        return CodelabsHandlers.okResult("del")
                }
        }
    }

    /**
     * 单条查询：GET /api/v1/uctoo/codelabs/:id
     * 返回完整的 codelabs 记录（含已软删除的，由行级权限控制）
     */
    private static func handleGet(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[codelabs] handleGet entered")
        let ctxOpt = CodelabsHandlers.ctx
        match (ctxOpt) {
            case None => return CodelabsHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                // 1. 从 path 提取 id
                // path 格式: /api/v1/uctoo/codelabs/:id
                let path = CodelabsHandlers.extractString(fields, "path")
                let parts = path.split("/")
                var idStr = ""
                var codelabsIdx: Int64 = -1
                for (i in 0..parts.size) {
                    if (parts[i] == "codelabs") {
                        codelabsIdx = i
                        break
                    }
                }
                if (codelabsIdx >= 0 && codelabsIdx + 1 < parts.size) {
                    idStr = parts[codelabsIdx + 1]
                }
                if (idStr.isEmpty()) {
                    return CodelabsHandlers.errResult(40002, "缺少 ID 参数")
                }
                // 2. 查询
                let userId = CodelabsHandlers.extractString(fields, "userId")
                let permArr = ArrayList<JsonValue>()
                match (fields.get("permissions")) {
                    case Some(JsonValue.Array(arr)) =>
                        for (p in arr) { permArr.add(p) }
                    case _ => ()
                }
                let getResult = CodelabsHandlers.queryById(ctx, idStr, userId, permArr)
                // 3. 未找到返回 404
                match (getResult) {
                    case JsonValue.Null => return CodelabsHandlers.errResult(40401, "未找到该codelabs")
                    case _ => return getResult
                }
        }
    }

    /**
     * 清空回收站：POST /api/v1/uctoo/codelabs/empty-recycle-bin
     * 物理删除所有 deleted_at NOT NULL 的记录
     */
    private static func handleEmptyRecycleBin(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[codelabs] handleEmptyRecycleBin entered")
        let ctxOpt = CodelabsHandlers.ctx
        match (ctxOpt) {
            case None => return CodelabsHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let userId = CodelabsHandlers.extractString(fields, "userId")
                let permArr = ArrayList<JsonValue>()
                match (fields.get("permissions")) {
                    case Some(JsonValue.Array(arr)) =>
                        for (p in arr) { permArr.add(p) }
                    case _ => ()
                }
                // 物理删除所有已软删除的记录
                let execParam = HashMap<String, JsonValue>()
                execParam["operation"] = JsonValue.String("execute")
                execParam["subOp"] = JsonValue.String("delete")
                execParam["table"] = JsonValue.String("codelabs")
                execParam["where"] = JsonValue.String("deleted_at IS NOT NULL")
                execParam["permissions"] = JsonValue.Array(permArr)
                if (!userId.isEmpty()) {
                    execParam["userId"] = JsonValue.String(userId)
                }
                let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                execArgs[0] = JsonValue.from(execParam)
                let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                eprintln("[codelabs] host.db empty-recycle-bin result: ${execResult.stringify()}")
                return CodelabsHandlers.okResult("empty-recycle-bin")
        }
    }

    /**
     * 列表查询：经 ctx.invoke("host.db", "query", ...) 查询数据库
     * V4 列表格式: { currentPage, totalCount, totalPage, codelabss: [...] }
     * 列表键名 = 表名 + s（复数）→ "codelabss"（API 规范 §8.2）
     */
    private static func handleList(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[codelabs] handleList entered, args.size=${args.size}")
        // 1. 从 ExternalRequest 中解析分页参数
        // path 格式: /api/v1/uctoo/codelabs/:limit/:page
        let path = CodelabsHandlers.extractString(fields, "path")
        let parts = path.split("/")
        var limit: Int64 = 10
        var page: Int64 = 1
        // 找到 "codelabs" 后的 :limit/:page
        var codelabsIdx: Int64 = -1
        for (i in 0..parts.size) {
            if (parts[i] == "codelabs") {
                codelabsIdx = i
                break
            }
        }
        if (codelabsIdx >= 0) {
            // :limit
            if (codelabsIdx + 1 < parts.size) {
                let limitStr = parts[codelabsIdx + 1]
                match (Int64.tryParse(limitStr)) {
                    case Some(v) => limit = v
                    case None => ()
                }
            }
            // :page
            if (codelabsIdx + 2 < parts.size) {
                let pageStr = parts[codelabsIdx + 2]
                match (Int64.tryParse(pageStr)) {
                    case Some(v) => page = v
                    case None => ()
                }
            }
        }

        // 2. 通过 ctx.invoke("host.db", "query", ...) 查询数据库
        let ctxOpt = CodelabsHandlers.ctx
        eprintln("[codelabs] ctxOpt is ${if (ctxOpt.isNone()) { "None" } else { "Some" }}")
        match (ctxOpt) {
            case None => return CodelabsHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                // 从 ExternalRequest 中提取 userId 和 permissions（行级权限）
                let userId = fields.get("userId")
                let permissions = fields.get("permissions")

                // 解析 filter 查询参数 → WHERE 子句
                // 普通模式: filter={"deleted_at":null} → deleted_at IS NULL
                // 回收站:   filter={"deleted_at":{"not":null}} → deleted_at IS NOT NULL
                let whereClause = CodelabsHandlers.buildWhereFromFilter(fields)

                // 构造 host.db query 参数
                let queryParam = HashMap<String, JsonValue>()
                queryParam["operation"] = JsonValue.String("query")
                queryParam["table"] = JsonValue.String("codelabs")
                queryParam["where"] = JsonValue.String(whereClause)
                queryParam["orderBy"] = JsonValue.String("created_at DESC")
                queryParam["limit"] = JsonValue.Number(Float64(limit))
                queryParam["offset"] = JsonValue.Number(Float64((page - 1) * limit))
                // 传入行级权限参数
                match (userId) {
                    case Some(v) => queryParam["userId"] = v
                    case None => ()
                }
                match (permissions) {
                    case Some(v) => queryParam["permissions"] = v
                    case None => ()
                }
                let queryArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                queryArgs[0] = JsonValue.from(queryParam)

                // 调用宿主数据库服务
                let queryResult = ctx.invoke<JsonValue, JsonValue>("host.db", "query", queryArgs)
                eprintln("[codelabs] host.db query result: ${queryResult.stringify()}")
                // queryResult 格式: { "rows": [...] }

                // 3. 查询总数（使用相同的 where 条件）
                let countParam = HashMap<String, JsonValue>()
                countParam["operation"] = JsonValue.String("count")
                countParam["table"] = JsonValue.String("codelabs")
                countParam["where"] = JsonValue.String(whereClause)
                // 传入行级权限参数
                match (userId) {
                    case Some(v) => countParam["userId"] = v
                    case None => ()
                }
                match (permissions) {
                    case Some(v) => countParam["permissions"] = v
                    case None => ()
                }
                let countArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                countArgs[0] = JsonValue.from(countParam)
                let countResult = ctx.invoke<JsonValue, JsonValue>("host.db", "count", countArgs)
                eprintln("[codelabs] host.db count result: ${countResult.stringify()}")
                // countResult 格式: { "count": N }

                // 4. 构造 V4 列表格式响应
                let response = HashMap<String, JsonValue>()
                response["currentPage"] = JsonValue.Number(Float64(page))

                // 解析总数
                var totalCount: Int64 = 0
                match (countResult) {
                    case JsonValue.Map(countFields) =>
                        match (countFields.get("count")) {
                            case Some(JsonValue.Number(n)) => totalCount = Int64(n)
                            case _ => ()
                        }
                    case _ => ()
                }
                response["totalCount"] = JsonValue.Number(Float64(totalCount))

                // 计算总页数
                var totalPage: Int64 = 0
                if (limit > 0) {
                    totalPage = (totalCount + limit - 1) / limit
                }
                response["totalPage"] = JsonValue.Number(Float64(totalPage))

                // 解析查询结果行
                let rows = match (queryResult) {
                    case JsonValue.Map(queryFields) =>
                        match (queryFields.get("rows")) {
                            case Some(JsonValue.Array(arr)) => arr
                            case _ => ArrayList<JsonValue>()
                        }
                    case _ => ArrayList<JsonValue>()
                }
                response["codelabss"] = JsonValue.Array(rows)

                return JsonValue.from(response)
        }
    }

    // ── 内部辅助方法 ─────────────────────────────────────────────────

    /**
     * 执行恢复操作：SET deleted_at=NULL WHERE id IN (...)
     */
    private static func doRestore(
        ctx: PluginContext,
        bodyMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        // 构造 WHERE
        var whereClause = ""
        let idsVal = bodyMap.get("ids")
        let idVal = bodyMap.get("id")
        match (idsVal) {
            case Some(JsonValue.String(idsStr)) =>
                let idList = CodelabsHelpers_parseIdList(idsStr)
                if (idList.size == 0) {
                    return CodelabsHandlers.errResult(40002, "ids 参数为空")
                }
                whereClause = "id IN (${CodelabsHelpers_joinQuoted(idList)})"
            case _ =>
                match (idVal) {
                    case Some(JsonValue.String(idStr)) =>
                        whereClause = "id = '${idStr}'"
                    case _ =>
                        return CodelabsHandlers.errResult(40002, "缺少 id 或 ids 参数")
                }
        }
        // 恢复：deleted_at = NULL
        let dataMap = HashMap<String, JsonValue>()
        dataMap["deleted_at"] = JsonValue.Null
        let execParam = HashMap<String, JsonValue>()
        execParam["operation"] = JsonValue.String("execute")
        execParam["subOp"] = JsonValue.String("update")
        execParam["table"] = JsonValue.String("codelabs")
        execParam["where"] = JsonValue.String(whereClause)
        execParam["data"] = JsonValue.from(dataMap)
        execParam["permissions"] = JsonValue.Array(permArr)
        if (!userId.isEmpty()) {
            execParam["userId"] = JsonValue.String(userId)
        }
        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
        execArgs[0] = JsonValue.from(execParam)
        let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
        eprintln("[codelabs] host.db restore result: ${execResult.stringify()}")
        return CodelabsHandlers.okResult("restore")
    }

    /**
     * 按 id 查询单条记录
     * 返回 JsonValue（记录对象）或 JsonValue.Null（未找到）
     */
    private static func queryById(
        ctx: PluginContext,
        idStr: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let queryParam = HashMap<String, JsonValue>()
        queryParam["operation"] = JsonValue.String("query")
        queryParam["table"] = JsonValue.String("codelabs")
        queryParam["where"] = JsonValue.String("id = '${idStr}'")
        queryParam["limit"] = JsonValue.Number(1.0)
        if (!userId.isEmpty()) {
            queryParam["userId"] = JsonValue.String(userId)
        }
        queryParam["permissions"] = JsonValue.Array(permArr)
        let queryArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
        queryArgs[0] = JsonValue.from(queryParam)
        let queryResult = ctx.invoke<JsonValue, JsonValue>("host.db", "query", queryArgs)
        match (queryResult) {
            case JsonValue.Map(qFields) =>
                match (qFields.get("rows")) {
                    case Some(JsonValue.Array(rows)) =>
                        if (rows.size > 0) {
                            return rows[0]
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return JsonValue.Null
    }

    /**
     * 从 ExternalRequest 提取 body（POST 请求体 JSON）
     * body 字段是 JsonValue（parseBody 解析结果）
     */
    private static func extractBody(fields: HashMap<String, JsonValue>): ?HashMap<String, JsonValue> {
        match (fields.get("body")) {
            case Some(JsonValue.Map(bodyMap)) => return Some(bodyMap)
            case _ => return None
        }
    }

    /**
     * 从 ExternalRequest 的 queryParams 中解析 filter 参数，构建 WHERE 子句。
     *
     * Web 前端发送的 filter 参数（URL 编码的 JSON）：
     * - 普通模式: filter={"deleted_at":null}          → deleted_at IS NULL
     * - 回收站:   filter={"deleted_at":{"not":null}} → deleted_at IS NOT NULL
     *
     * 约定：queryParams.filter 是 URL 编码字符串，需要先 URL 解码再 JSON 解析。
     * 为简化实现，网关 parseQueryParams 未做 URL 解码，这里兼容 %22 等编码。
     */
    private static func buildWhereFromFilter(fields: HashMap<String, JsonValue>): String {
        // 1. 从 queryParams 中提取 filter 参数
        var filterStr = ""
        match (fields.get("queryParams")) {
            case Some(JsonValue.Map(qp)) =>
                match (qp.get("filter")) {
                    case Some(JsonValue.String(s)) => filterStr = s
                    case _ => ()
                }
            case _ => ()
        }
        eprintln("[codelabs] buildWhereFromFilter: raw filter='${filterStr}'")
        // 2. URL 解码（兼容 %22 → " 等编码）
        if (!filterStr.isEmpty()) {
            filterStr = filterStr.replace("%7B", "{")
                .replace("%7D", "}")
                .replace("%22", "\"")
                .replace("%3A", ":")
                .replace("%2C", ",")
                .replace("+", " ")
        }
        // 3. 缺省：普通模式（deleted_at IS NULL）
        if (filterStr.isEmpty()) {
            return "deleted_at IS NULL"
        }
        // 4. JSON 解析 filter
        try {
            let filterJson = JsonValue.parse(filterStr)
            match (filterJson) {
                case JsonValue.Map(filterMap) =>
                    // 检查 deleted_at 字段
                    match (filterMap.get("deleted_at")) {
                        case Some(JsonValue.Null) =>
                            // {"deleted_at":null} → deleted_at IS NULL
                            return "deleted_at IS NULL"
                        case Some(JsonValue.Map(daMap)) =>
                            // {"deleted_at":{"not":null}} → deleted_at IS NOT NULL
                            match (daMap.get("not")) {
                                case Some(JsonValue.Null) => return "deleted_at IS NOT NULL"
                                case _ => ()
                            }
                            // 其他操作符暂不支持，降级为 deleted_at IS NULL
                            return "deleted_at IS NULL"
                        case _ => ()
                    }
                case _ => ()
            }
        } catch (e: Exception) {
            eprintln("[codelabs] buildWhereFromFilter: JSON parse error: ${e.message}")
        }
        // 5. 兜底：普通模式
        return "deleted_at IS NULL"
    }

    /**
     * 从 HashMap<String, JsonValue> 提取纯字符串值
     */
    private static func extractStringFromMap(map: HashMap<String, JsonValue>, key: String): String {
        match (map.get(key)) {
            case Some(JsonValue.String(s)) => return s
            case _ => return ""
        }
    }

    // ── 工具方法 ─────────────────────────────────────────────────────

    private static func okResult(op: String): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["errno"] = JsonValue.Number(0.0)
        m["errmsg"] = JsonValue.String("ok")
        m["op"] = JsonValue.String(op)
        return JsonValue.from(m)
    }

    private static func errResult(errno: Int64, errmsg: String): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["errno"] = JsonValue.Number(Float64(errno))
        m["errmsg"] = JsonValue.String(errmsg)
        return JsonValue.from(m)
    }

    private static func extractString(fields: HashMap<String, JsonValue>, key: String): String {
        match (fields.get(key)) {
            case Some(JsonValue.String(s)) => s
            case _ => ""
        }
    }
}

// ── 顶层辅助函数（解析 id 列表、拼接 SQL）─────────────────────────

/**
 * 解析 ids 字符串为 ArrayList<String>
 * 支持格式：
 * - JSON 数组字符串: '["uuid1","uuid2"]'
 * - 逗号分隔: 'uuid1,uuid2'
 */
public func CodelabsHelpers_parseIdList(idsStr: String): ArrayList<String> {
    let idList = ArrayList<String>()
    if (idsStr.isEmpty()) {
        return idList
    }
    // 尝试 JSON 数组解析
    try {
        let jsonValue = JsonValue.parse(idsStr)
        match (jsonValue) {
            case JsonValue.Array(arr) =>
                for (item in arr) {
                    match (item) {
                        case JsonValue.String(s) =>
                            if (!s.isEmpty()) { idList.add(s) }
                        case _ => ()
                    }
                }
                return idList
            case _ => ()
        }
    } catch (e: Exception) {
        // 非 JSON，尝试逗号分隔
        let parts = idsStr.split(",")
        for (p in parts) {
            let trimmed = p.trimAscii()
            if (!trimmed.isEmpty() && trimmed != "[" && trimmed != "]" && trimmed != "{" && trimmed != "}") {
                idList.add(trimmed)
            }
        }
    }
    return idList
}

/**
 * 将 ArrayList<String> 拼接为 SQL IN 子句格式
 * 示例: ["uuid1", "uuid2"] → "'uuid1','uuid2'"
 */
public func CodelabsHelpers_joinQuoted(idList: ArrayList<String>): String {
    let sb = StringBuilder()
    var first = true
    for (id in idList) {
        if (!first) {
            sb.append(",")
        }
        // 转义单引号
        let escaped = id.replace("'", "''")
        sb.append("'")
        sb.append(escaped)
        sb.append("'")
        first = false
    }
    return sb.toString()
}
