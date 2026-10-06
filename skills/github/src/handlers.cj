/*
 * V4 CRUD RPC handler 框架（github）
 * 独立进程插件，通过 ctx.invoke("host.db", ...) 访问宿主数据库
 *
 * 多表支持：4 张表共用本文件，表名作为运行时参数传入 handler。
 * 路由（遵循 uctoo V4 API 规范，basePath /api/v1/uctoo/{表名}）：
 *   GET  /:limit/:page               分页列表
 *   GET  /:id                        单条查询
 *   POST /add                        创建
 *   POST /edit                       更新（含批量 ids / 恢复 deleted_at='0'）
 *   POST /del                        删除（含批量 ids / 硬删 force=1）
 *   POST /empty-recycle-bin          清空回收站（物理删除 deleted_at NOT NULL）
 *
 * 列表键名遵守 API 规范 §8.2：表名 + s（复数）
 *
 * ⚠️ 自动生成内容请勿手工修改：重新生成会覆盖 AutoCreateCode 保护区。
 *    二次开发写在保护区结束标记之后。
 */
package skill_github

import ystyle::cordis_plugin.{PluginContext, PluginRuntime}
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

//#region AutoCreateCode

public class GithubHandlers {
    /// 插件上下文（register 时注入），handler 内经 ctx.invoke 访问宿主服务
    private static var ctx: ?PluginContext = None

    /// 本插件支持的全部表（分多次生成时自动累积合并）
    private static let TABLES: Array<String> = [
        // table: issue_comment
        "issue_comment",
        // table: milestone
        "milestone",
        // table: label
        "label",
        // table: pull_request
        "pull_request",
        // table: pr_review
        "pr_review",
        // table: branch_protection
        "branch_protection",
        // table: repository
        "repository",
        // table: branch
        "branch",
        // table: commit
        "commit",
        // table: repository_file
        "repository_file",
    ]

    public static func register(ctx: PluginContext): Unit {
        GithubHandlers.ctx = ctx
        // 注册通用服务 handler：宿主 invoke 转发时 service="github"
        // 内部根据 ExternalRequest 的 method + path 分发到具体 CRUD handler
        ctx.registerHandler("github", { method, args => GithubHandlers.dispatch(method, args) })
    }

    /**
     * 路由分发：根据 HTTP method + path 分发到具体 CRUD handler
     * args[0] 是 ExternalRequest { method, path, queryParams, body, userId, permissions, ... }
     *
     * 多表：遍历 TABLES，用表名作为路径段匹配（/api/v1/uctoo/{表名}/...）。
     */
    private static func dispatch(httpMethod: String, args: Array<JsonValue>): JsonValue {
        if (args.size == 0) {
            return GithubHandlers.errResult(1, "missing args")
        }
        // 解析 ExternalRequest
        let extReq = args[0]
        match (extReq) {
            case JsonValue.Map(fields) =>
                let path = GithubHandlers.extractString(fields, "path")
                let reqMethod = GithubHandlers.extractString(fields, "method")
                // 遍历 TABLES 按表名匹配路径段
                for (table in GithubHandlers.TABLES) {
                    if (path.contains("/${table}/")) {
                        if (reqMethod == "GET") {
                            // /api/v1/uctoo/{table}/:limit/:page → list
                            // /api/v1/uctoo/{table}/:id → get（单条）
                            let parts = path.split("/")
                            var tableIdx: Int64 = -1
                            for (i in 0..parts.size) {
                                if (parts[i] == table) {
                                    tableIdx = i
                                    break
                                }
                            }
                            if (tableIdx >= 0 && tableIdx + 1 < parts.size) {
                                let remaining = parts.size - tableIdx - 1
                                if (remaining >= 2) {
                                    return GithubHandlers.handleList(table, fields, args)
                                } else {
                                    return GithubHandlers.handleGet(table, fields, args)
                                }
                            }
                            return GithubHandlers.handleList(table, fields, args)
                        } else if (reqMethod == "POST") {
                            if (path.contains("/${table}/add")) {
                                return GithubHandlers.handleAdd(table, fields, args)
                            } else if (path.contains("/${table}/edit")) {
                                return GithubHandlers.handleEdit(table, fields, args)
                            } else if (path.contains("/${table}/del")) {
                                return GithubHandlers.handleDel(table, fields, args)
                            } else if (path.contains("/${table}/empty-recycle-bin")) {
                                return GithubHandlers.handleEmptyRecycleBin(table, fields, args)
                            }
                        }
                    }
                }
                return GithubHandlers.errResult(1, "no route matched: ${reqMethod} ${path}")
            case _ => return GithubHandlers.errResult(1, "invalid args format")
        }
        return GithubHandlers.errResult(1, "dispatch fallback")
    }

    /**
     * 获取表的可写字段白名单（防止插件越权写入 id/created_at/updated_at）
     *
     * 不包含 id（数据库 DEFAULT gen_random_uuid）、created_at/updated_at（数据库自维护）。
     * TODO: plugingen 进程模式未连 DB，无法自动读取 db_info，
     *       请按各表实际字段补全下面的白名单。
     */
    private static func getWritableColumns(table: String): Array<String> {
        if (table == "issue_comment") {
            return ["creator", "deleted_at"]
        }
        if (table == "milestone") {
            return ["creator", "deleted_at"]
        }
        if (table == "label") {
            return ["creator", "deleted_at"]
        }
        if (table == "pull_request") {
            return ["creator", "deleted_at"]
        }
        if (table == "pr_review") {
            return ["creator", "deleted_at"]
        }
        if (table == "branch_protection") {
            return ["creator", "deleted_at"]
        }
        if (table == "repository") {
            return ["creator", "deleted_at"]
        }
        if (table == "branch") {
            return ["creator", "deleted_at"]
        }
        if (table == "commit") {
            return ["creator", "deleted_at"]
        }
        if (table == "repository_file") {
            return ["creator", "deleted_at"]
        }
        return Array<String>(0, { _ => "" })
    }

    /**
     * 创建：POST /api/v1/uctoo/{表名}/add
     * body: { ...业务字段 }
     * 行级权限：creator = userId（宿主侧 host.db 会附加行级 WHERE，但 INSERT 时需要插件显式设置 creator）
     */
    private static func handleAdd(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[github] handleAdd ${table} entered")
        let ctxOpt = GithubHandlers.ctx
        match (ctxOpt) {
            case None => return GithubHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                // 1. 提取 body（POST 请求体）
                let body = GithubHandlers.extractBody(fields)
                match (body) {
                    case None => return GithubHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        // 2. 构造 INSERT data，只允许白名单字段
                        let dataMap = HashMap<String, JsonValue>()
                        for (col in GithubHandlers.getWritableColumns(table)) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        // 3. 设置 creator = userId（行级权限要求）
                        let userId = GithubHandlers.extractString(fields, "userId")
                        if (!userId.isEmpty()) {
                            dataMap["creator"] = JsonValue.String(userId)
                        }
                        // 4. 调用 host.db execute insert
                        let execParam = HashMap<String, JsonValue>()
                        execParam["operation"] = JsonValue.String("execute")
                        execParam["subOp"] = JsonValue.String("insert")
                        execParam["table"] = JsonValue.String(table)
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
                        eprintln("[github] host.db insert result: ${execResult.stringify()}")
                        // 5. 返回成功（INSERT 无 RETURNING，不回读新记录）
                        return GithubHandlers.okResult("add")
                }
        }
    }

    /**
     * 更新：POST /api/v1/uctoo/{表名}/edit
     * body 单条: { id, ...updateFields }
     * body 批量: { ids: "uuid1,uuid2,...", ...updateFields }
     * body 恢复: { id 或 ids, deleted_at: "0" }  // deleted_at='0' → 软恢复（SET deleted_at=NULL）
     */
    private static func handleEdit(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[github] handleEdit entered")
        let ctxOpt = GithubHandlers.ctx
        match (ctxOpt) {
            case None => return GithubHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = GithubHandlers.extractBody(fields)
                match (body) {
                    case None => return GithubHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = GithubHandlers.extractString(fields, "userId")
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
                            return GithubHandlers.doRestore(table, ctx, bodyMap, userId, permArr)
                        }
                        // 构造 UPDATE data，只允许白名单字段
                        let dataMap = HashMap<String, JsonValue>()
                        for (col in GithubHandlers.getWritableColumns(table)) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        // updated_at 由数据库触发器维护，不显式设置
                        if (dataMap.size == 0) {
                            return GithubHandlers.errResult(40002, "没有可更新的字段")
                        }
                        // 构造 WHERE 条件
                        var whereClause = ""
                        match (idsVal) {
                            case Some(JsonValue.String(idsStr)) =>
                                // 批量更新：WHERE id IN ('uuid1','uuid2',...)
                                let idList = GithubHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return GithubHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (GithubHelpers_joinQuoted(idList)})"
                            case _ =>
                                // 单条更新
                                match (idVal) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return GithubHandlers.errResult(40002, "缺少 id 或 ids 参数")
                                }
                        }
                        // 调用 host.db execute update
                        let execParam = HashMap<String, JsonValue>()
                        execParam["operation"] = JsonValue.String("execute")
                        execParam["subOp"] = JsonValue.String("update")
                        execParam["table"] = JsonValue.String(table)
                        execParam["where"] = JsonValue.String(whereClause)
                        execParam["data"] = JsonValue.from(dataMap)
                        execParam["permissions"] = JsonValue.Array(permArr)
                        if (!userId.isEmpty()) {
                            execParam["userId"] = JsonValue.String(userId)
                        }
                        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                        execArgs[0] = JsonValue.from(execParam)
                        let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                        eprintln("[github] host.db update result: ${execResult.stringify()}")
                        // 返回更新后的记录（单条）
                        match (idVal) {
                            case Some(JsonValue.String(idStr)) =>
                                let getResult = GithubHandlers.queryById(table, ctx, idStr, userId, permArr)
                                return getResult
                            case _ => ()
                        }
                        // 批量更新：返回成功
                        return GithubHandlers.okResult("edit")
                }
        }
    }

    /**
     * 删除：POST /api/v1/uctoo/{表名}/del
     * body 单条: { id }
     * body 批量: { ids: "uuid1,uuid2,..." }
     * body 硬删: { id 或 ids, force: 1 }  // force=1 → 物理删除
     * 软删：SET deleted_at = $raw:CURRENT_TIMESTAMP WHERE id IN (...)
     */
    private static func handleDel(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[github] handleDel entered")
        let ctxOpt = GithubHandlers.ctx
        match (ctxOpt) {
            case None => return GithubHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = GithubHandlers.extractBody(fields)
                match (body) {
                    case None => return GithubHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = GithubHandlers.extractString(fields, "userId")
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
                        match (idsVal) {
                            case Some(JsonValue.String(idsStr)) =>
                                let idList = GithubHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return GithubHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (GithubHelpers_joinQuoted(idList)})"
                            case _ =>
                                match (idVal) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return GithubHandlers.errResult(40002, "缺少 id 或 ids 参数")
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
                        execParam["table"] = JsonValue.String(table)
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
                        eprintln("[github] host.db delete result: ${execResult.stringify()}")
                        return GithubHandlers.okResult("del")
                }
        }
    }

    /**
     * 单条查询：GET /api/v1/uctoo/{表名}/:id
     * 返回完整的 github 记录（含已软删除的，由行级权限控制）
     */
    private static func handleGet(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[github] handleGet entered")
        let ctxOpt = GithubHandlers.ctx
        match (ctxOpt) {
            case None => return GithubHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                // 1. 从 path 提取 id
                let path = GithubHandlers.extractString(fields, "path")
                let parts = path.split("/")
                var idStr = ""
                var tableIdx: Int64 = -1
                for (i in 0..parts.size) {
                    if (parts[i] == table) {
                        tableIdx = i
                        break
                    }
                }
                if (tableIdx >= 0 && tableIdx + 1 < parts.size) {
                    idStr = parts[tableIdx + 1]
                }
                if (idStr.isEmpty()) {
                    return GithubHandlers.errResult(40002, "缺少 ID 参数")
                }
                // 2. 查询
                let userId = GithubHandlers.extractString(fields, "userId")
                let permArr = ArrayList<JsonValue>()
                match (fields.get("permissions")) {
                    case Some(JsonValue.Array(arr)) =>
                        for (p in arr) { permArr.add(p) }
                    case _ => ()
                }
                let getResult = GithubHandlers.queryById(table, ctx, idStr, userId, permArr)
                // 3. 未找到返回 404
                match (getResult) {
                    case JsonValue.Null => return GithubHandlers.errResult(40401, "未找到该记录（表 ${table}）")
                    case _ => return getResult
                }
        }
    }

    /**
     * 列表查询：经 ctx.invoke("host.db", "query", ...) 查询数据库
     * V4 列表格式: { currentPage, totalCount, totalPage, githubs: [...] }
     * 列表键名 = 表名 + s（复数）→ "githubs"（API 规范 §8.2）
     */
    private static func handleList(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[github] handleList entered, args.size=${args.size}")
        // 1. 从 ExternalRequest 中解析分页参数
        let path = GithubHandlers.extractString(fields, "path")
        let parts = path.split("/")
        var limit: Int64 = 10
        var page: Int64 = 1
        var tableIdx: Int64 = -1
        for (i in 0..parts.size) {
            if (parts[i] == table) {
                tableIdx = i
                break
            }
        }
        if (tableIdx >= 0) {
            if (tableIdx + 1 < parts.size) {
                let limitStr = parts[tableIdx + 1]
                match (Int64.tryParse(limitStr)) {
                    case Some(v) => limit = v
                    case None => ()
                }
            }
            if (tableIdx + 2 < parts.size) {
                let pageStr = parts[tableIdx + 2]
                match (Int64.tryParse(pageStr)) {
                    case Some(v) => page = v
                    case None => ()
                }
            }
        }
        // 2. 通过 ctx.invoke("host.db", "query", ...) 查询数据库
        let ctxOpt = GithubHandlers.ctx
        eprintln("[github] ctxOpt is " + (if (ctxOpt.isNone()) { "None" } else { "Some" }))
        match (ctxOpt) {
            case None => return GithubHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let userId = fields.get("userId")
                let permissions = fields.get("permissions")
                // 解析 filter 查询参数 → WHERE 子句
                let whereClause = GithubHandlers.buildWhereFromFilter(fields)
                // 构造 host.db query 参数
                let queryParam = HashMap<String, JsonValue>()
                queryParam["operation"] = JsonValue.String("query")
                queryParam["table"] = JsonValue.String(table)
                queryParam["where"] = JsonValue.String(whereClause)
                queryParam["orderBy"] = JsonValue.String("created_at DESC")
                queryParam["limit"] = JsonValue.Number(Float64(limit))
                queryParam["offset"] = JsonValue.Number(Float64((page - 1) * limit))
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
                let queryResult = ctx.invoke<JsonValue, JsonValue>("host.db", "query", queryArgs)
                eprintln("[github] host.db query result: ${queryResult.stringify()}")
                // 3. 查询总数（使用相同的 where 条件）
                let countParam = HashMap<String, JsonValue>()
                countParam["operation"] = JsonValue.String("count")
                countParam["table"] = JsonValue.String(table)
                countParam["where"] = JsonValue.String(whereClause)
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
                eprintln("[github] host.db count result: ${countResult.stringify()}")
                // 4. 构造 V4 列表格式响应
                let response = HashMap<String, JsonValue>()
                response["currentPage"] = JsonValue.Number(Float64(page))
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
                var totalPage: Int64 = 0
                if (limit > 0) {
                    totalPage = (totalCount + limit - 1) / limit
                }
                response["totalPage"] = JsonValue.Number(Float64(totalPage))
                let rows = match (queryResult) {
                    case JsonValue.Map(queryFields) =>
                        match (queryFields.get("rows")) {
                            case Some(JsonValue.Array(arr)) => arr
                            case _ => ArrayList<JsonValue>()
                        }
                    case _ => ArrayList<JsonValue>()
                }
                response["${table}s"] = JsonValue.Array(rows)
                return JsonValue.from(response)
        }
    }

    /**
     * 清空回收站：POST /api/v1/uctoo/{表名}/empty-recycle-bin
     * 物理删除所有 deleted_at NOT NULL 的记录
     */
    private static func handleEmptyRecycleBin(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[github] handleEmptyRecycleBin entered")
        let ctxOpt = GithubHandlers.ctx
        match (ctxOpt) {
            case None => return GithubHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let userId = GithubHandlers.extractString(fields, "userId")
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
                execParam["table"] = JsonValue.String(table)
                execParam["where"] = JsonValue.String("deleted_at IS NOT NULL")
                execParam["permissions"] = JsonValue.Array(permArr)
                if (!userId.isEmpty()) {
                    execParam["userId"] = JsonValue.String(userId)
                }
                let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                execArgs[0] = JsonValue.from(execParam)
                let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                eprintln("[github] host.db empty-recycle-bin result: ${execResult.stringify()}")
                return GithubHandlers.okResult("empty-recycle-bin")
        }
    }

    /**
     * 执行恢复操作：SET deleted_at=NULL WHERE id IN (...)
     */
    private static func doRestore(
        table: String,
        ctx: PluginContext,
        bodyMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        var whereClause = ""
        let idsVal = bodyMap.get("ids")
        let idVal = bodyMap.get("id")
        match (idsVal) {
            case Some(JsonValue.String(idsStr)) =>
                let idList = GithubHelpers_parseIdList(idsStr)
                if (idList.size == 0) {
                    return GithubHandlers.errResult(40002, "ids 参数为空")
                }
                whereClause = "id IN (GithubHelpers_joinQuoted(idList)})"
            case _ =>
                match (idVal) {
                    case Some(JsonValue.String(idStr)) =>
                        whereClause = "id = '${idStr}'"
                    case _ =>
                        return GithubHandlers.errResult(40002, "缺少 id 或 ids 参数")
                }
        }
        // 恢复：deleted_at = NULL
        let dataMap = HashMap<String, JsonValue>()
        dataMap["deleted_at"] = JsonValue.Null
        let execParam = HashMap<String, JsonValue>()
        execParam["operation"] = JsonValue.String("execute")
        execParam["subOp"] = JsonValue.String("update")
        execParam["table"] = JsonValue.String(table)
        execParam["where"] = JsonValue.String(whereClause)
        execParam["data"] = JsonValue.from(dataMap)
        execParam["permissions"] = JsonValue.Array(permArr)
        if (!userId.isEmpty()) {
            execParam["userId"] = JsonValue.String(userId)
        }
        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
        execArgs[0] = JsonValue.from(execParam)
        let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
        eprintln("[github] host.db restore result: ${execResult.stringify()}")
        return GithubHandlers.okResult("restore")
    }

    /**
     * 按 id 查询单条记录
     * 返回 JsonValue（记录对象）或 JsonValue.Null（未找到）
     */
    private static func queryById(
        table: String,
        ctx: PluginContext,
        idStr: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let queryParam = HashMap<String, JsonValue>()
        queryParam["operation"] = JsonValue.String("query")
        queryParam["table"] = JsonValue.String(table)
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
     * 从 ExternalRequest 的 queryParams 中解析 filter 参数，构建 WHERE 子句。
     *
     * Web 前端发送的 filter 参数（URL 编码的 JSON）：
     * - 普通模式: filter={"deleted_at":null}          → deleted_at IS NULL
     * - 回收站:   filter={"deleted_at":{"not":null}} → deleted_at IS NOT NULL
     *
     * 约定：queryParams.filter 是 URL 编码字符串，需要先 URL 解码再 JSON 解析。
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
        eprintln("[github] buildWhereFromFilter: raw filter='${filterStr}'")
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
            eprintln("[github] buildWhereFromFilter: JSON parse error: ${e.message}")
        }
        // 5. 兜底：普通模式
        return "deleted_at IS NULL"
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

    /// 从 HashMap<String, JsonValue> 提取纯字符串值
    private static func extractStringFromMap(map: HashMap<String, JsonValue>, key: String): String {
        match (map.get(key)) {
            case Some(JsonValue.String(s)) => return s
            case _ => return ""
        }
    }

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

/// 解析 ids 字符串为 ArrayList<String>
/// 支持格式：
/// - JSON 数组字符串: '["uuid1","uuid2"]'
/// - 逗号分隔: 'uuid1,uuid2'
public func GithubHelpers_parseIdList(idsStr: String): ArrayList<String> {
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

/// 将 ArrayList<String> 拼接为 SQL IN 子句格式
/// 示例: ["uuid1", "uuid2"] → "'uuid1','uuid2'"
public func GithubHelpers_joinQuoted(idList: ArrayList<String>): String {
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

//#endregion AutoCreateCode

// ── 二次开发区 ────────────────────────────────────────────────
// 重新生成时以上 AutoCreateCode 区间会被覆盖，本区域的手写代码保留。
// 自定义 handler 请写在此处，并在 dispatch 中按需接入。

