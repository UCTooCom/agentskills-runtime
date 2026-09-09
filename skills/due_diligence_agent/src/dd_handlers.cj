/*
 * V4 CRUD RPC handler 框架（due_diligence_agent）
 * 独立进程插件，通过 ctx.invoke("host.db", ...) 访问宿主数据库
 * 通过 ctx.invoke("host.mcp", "call", ...) 调用宿主统一 MCP 开放服务
 *
 * 路由（遵循 uctoo V4 API 规范）：
 *   6 张表各有标准 CRUD：
 *     GET  /:table/:limit/:page          分页列表
 *     GET  /:table/:id                   单条查询
 *     POST /:table/add                   创建
 *     POST /:table/edit                  更新
 *     POST /:table/del                   删除
 *     POST /:table/empty-recycle-bin     清空回收站
 *   自定义路由：
 *     POST /due_diligence/dd-fetch       采集聚合（经 host.mcp 调 ≥3 工具）
 *     POST /due_diligence/dd-save        幂等落库
 *
 * 列表键名遵守 API 规范 §8.2：表名 + s（复数）
 *
 * 编码依据：skills/codelabs/src/handlers.cj（dispatch 路由分发 + host.db 调用 + 白名单字段范式）
 */
package skill_due_diligence_agent

import ystyle::cordis_plugin.{PluginContext, PluginRuntime}
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

public class DdHandlers {
    private static var ctx: ?PluginContext = None

    /// 支持的 6 张表
    private static let TABLES: Array<String> = [
        "due_diligence_task",
        "due_diligence_enterprise",
        "due_diligence_equity",
        "due_diligence_risk",
        "due_diligence_report",
        "due_diligence_mcp_call_log"
    ]

    public static func register(ctx: PluginContext): Unit {
        DdHandlers.ctx = ctx
        PersistService.initialize(ctx)
        ctx.registerHandler("due_diligence_agent", { method, args => DdHandlers.dispatch(method, args) })
    }

    /**
     * 路由分发：根据 HTTP method + path 分发到具体 handler
     */
    private static func dispatch(httpMethod: String, args: Array<JsonValue>): JsonValue {
        if (args.size == 0) {
            return DdHandlers.errResult(1, "missing args")
        }
        let extReq = args[0]
        match (extReq) {
            case JsonValue.Map(fields) =>
                let path = DdHandlers.extractString(fields, "path")
                let reqMethod = DdHandlers.extractString(fields, "method")

                // 自定义路由优先匹配
                if (reqMethod == "POST" && path.contains("/due_diligence/dd-fetch")) {
                    return DdHandlers.handleDdFetch(fields, args)
                }
                if (reqMethod == "POST" && path.contains("/due_diligence/dd-save")) {
                    return DdHandlers.handleDdSave(fields, args)
                }

                // 6 张表 CRUD 路由匹配
                for (table in DdHandlers.TABLES) {
                    if (path.contains("/${table}/")) {
                        if (reqMethod == "GET") {
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
                                    return DdHandlers.handleList(table, fields, args)
                                } else {
                                    return DdHandlers.handleGet(table, fields, args)
                                }
                            }
                            return DdHandlers.handleList(table, fields, args)
                        } else if (reqMethod == "POST") {
                            if (path.contains("/${table}/add")) {
                                return DdHandlers.handleAdd(table, fields, args)
                            } else if (path.contains("/${table}/edit")) {
                                return DdHandlers.handleEdit(table, fields, args)
                            } else if (path.contains("/${table}/del")) {
                                return DdHandlers.handleDel(table, fields, args)
                            } else if (path.contains("/${table}/empty-recycle-bin")) {
                                return DdHandlers.handleEmptyRecycleBin(table, fields, args)
                            }
                        }
                    }
                }
                return DdHandlers.errResult(1, "no route matched: ${reqMethod} ${path}")
            case _ => return DdHandlers.errResult(1, "invalid args format")
        }
        return DdHandlers.errResult(1, "dispatch fallback")
    }

    // ── 通用 CRUD handlers ──────────────────────────────────────────

    private static func handleAdd(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleAdd ${table} entered")
        let ctxOpt = DdHandlers.ctx
        match (ctxOpt) {
            case None => return DdHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = DdHandlers.extractBody(fields)
                match (body) {
                    case None => return DdHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let dataMap = HashMap<String, JsonValue>()
                        let writableCols = DdHandlers.getWritableColumns(table)
                        for (col in writableCols) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        let userId = DdHandlers.extractString(fields, "userId")
                        if (!userId.isEmpty()) {
                            dataMap["creator"] = JsonValue.String(userId)
                        }
                        let permArr = DdHandlers.extractPermissions(fields)
                        return PersistService.insert(table, dataMap, userId, permArr)
                }
        }
    }

    private static func handleEdit(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleEdit ${table} entered")
        let ctxOpt = DdHandlers.ctx
        match (ctxOpt) {
            case None => return DdHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = DdHandlers.extractBody(fields)
                match (body) {
                    case None => return DdHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = DdHandlers.extractString(fields, "userId")
                        let permArr = DdHandlers.extractPermissions(fields)
                        let deletedAtVal = bodyMap.get("deleted_at")
                        let isRestore = match (deletedAtVal) {
                            case Some(JsonValue.String(s)) => s == "0"
                            case _ => false
                        }
                        if (isRestore) {
                            return DdHandlers.doRestore(table, bodyMap, userId, permArr)
                        }
                        let dataMap = HashMap<String, JsonValue>()
                        let writableCols = DdHandlers.getWritableColumns(table)
                        for (col in writableCols) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        if (dataMap.size == 0) {
                            return DdHandlers.errResult(40002, "没有可更新的字段")
                        }
                        var whereClause = ""
                        match (bodyMap.get("ids")) {
                            case Some(JsonValue.String(idsStr)) =>
                                let idList = DdHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return DdHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (${DdHelpers_joinQuoted(idList)})"
                            case _ =>
                                match (bodyMap.get("id")) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return DdHandlers.errResult(40002, "缺少 id 或 ids 参数")
                                }
                        }
                        return PersistService.update(table, whereClause, dataMap, userId, permArr)
                }
        }
    }

    private static func handleDel(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleDel ${table} entered")
        let ctxOpt = DdHandlers.ctx
        match (ctxOpt) {
            case None => return DdHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = DdHandlers.extractBody(fields)
                match (body) {
                    case None => return DdHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = DdHandlers.extractString(fields, "userId")
                        let permArr = DdHandlers.extractPermissions(fields)
                        var whereClause = ""
                        match (bodyMap.get("ids")) {
                            case Some(JsonValue.String(idsStr)) =>
                                let idList = DdHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return DdHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (${DdHelpers_joinQuoted(idList)})"
                            case _ =>
                                match (bodyMap.get("id")) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return DdHandlers.errResult(40002, "缺少 id 或 ids 参数")
                                }
                        }
                        let forceVal = bodyMap.get("force")
                        let isHardDelete = match (forceVal) {
                            case Some(JsonValue.Number(n)) => n == 1.0
                            case Some(JsonValue.String(s)) => s == "1" || s == "true"
                            case _ => false
                        }
                        if (isHardDelete) {
                            return PersistService.hardDelete(table, whereClause, userId, permArr)
                        } else {
                            let dataMap = HashMap<String, JsonValue>()
                            dataMap["deleted_at"] = JsonValue.String("$raw:CURRENT_TIMESTAMP")
                            return PersistService.update(table, whereClause, dataMap, userId, permArr)
                        }
                }
        }
    }

    private static func handleGet(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleGet ${table} entered")
        let path = DdHandlers.extractString(fields, "path")
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
            return DdHandlers.errResult(40002, "缺少 ID 参数")
        }
        let userId = DdHandlers.extractString(fields, "userId")
        let permArr = DdHandlers.extractPermissions(fields)
        let result = PersistService.queryOne(table, "id = '${idStr}'", userId, permArr)
        match (result) {
            case JsonValue.Null => return DdHandlers.errResult(40401, "未找到记录")
            case _ => return result
        }
    }

    private static func handleList(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleList ${table} entered")
        let path = DdHandlers.extractString(fields, "path")
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
                match (Int64.tryParse(parts[tableIdx + 1])) {
                    case Some(v) => limit = v
                    case None => ()
                }
            }
            if (tableIdx + 2 < parts.size) {
                match (Int64.tryParse(parts[tableIdx + 2])) {
                    case Some(v) => page = v
                    case None => ()
                }
            }
        }
        let ctxOpt = DdHandlers.ctx
        match (ctxOpt) {
            case None => return DdHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let userId = fields.get("userId")
                let permissions = fields.get("permissions")
                let whereClause = DdHandlers.buildWhereFromFilter(fields)
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
                let queryResult = ctx.invoke("host.db", "query", queryArgs)

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
                let countResult = ctx.invoke("host.db", "count", countArgs)

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

    private static func handleEmptyRecycleBin(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleEmptyRecycleBin ${table} entered")
        let ctxOpt = DdHandlers.ctx
        match (ctxOpt) {
            case None => return DdHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let userId = DdHandlers.extractString(fields, "userId")
                let permArr = DdHandlers.extractPermissions(fields)
                let execParam = HashMap<String, JsonValue>()
                execParam["operation"] = JsonValue.String("execute")
                execParam["subOp"] = JsonValue.String("delete")
                execParam["table"] = JsonValue.String(table)
                execParam["where"] = JsonValue.String("deleted_at IS NOT NULL")
                if (permArr.size > 0) {
                    execParam["permissions"] = JsonValue.Array(permArr)
                }
                if (!userId.isEmpty()) {
                    execParam["userId"] = JsonValue.String(userId)
                }
                let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                execArgs[0] = JsonValue.from(execParam)
                let execResult = ctx.invoke("host.db", "execute", execArgs)
                eprintln("[dd] empty-recycle-bin ${table} result: ${execResult.stringify()}")
                return DdHandlers.okResult("empty-recycle-bin")
        }
    }

    // ── dd-fetch：经 host.mcp 采集聚合 ──────────────────────────────
    // 调用 ≥2 类 ≥3 个天眼查 MCP 工具，每次记录 mcp_call_log，汇总结构化结果

    private static func handleDdFetch(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleDdFetch entered")
        let ctxOpt = DdHandlers.ctx
        match (ctxOpt) {
            case None => return DdHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = DdHandlers.extractBody(fields)
                match (body) {
                    case None => return DdHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let enterpriseName = DdHandlers.extractStringFromMap(bodyMap, "enterprise_name")
                        let creditCode = DdHandlers.extractStringFromMap(bodyMap, "credit_code")
                        let mcpAlias = DdHandlers.extractStringFromMap(bodyMap, "mcp_alias")
                        let taskId = DdHandlers.extractStringFromMap(bodyMap, "task_id")
                        let userId = DdHandlers.extractString(fields, "userId")
                        let permArr = DdHandlers.extractPermissions(fields)

                        if (enterpriseName.isEmpty() && creditCode.isEmpty()) {
                            return DdHandlers.errResult(40002, "企业名称和统一社会信用代码不能同时为空")
                        }
                        let effectiveAlias = if (mcpAlias.isEmpty()) { "tianyancha" } else { mcpAlias }

                        // 调用 ≥3 个 MCP 工具采集数据（经 call_tool 代理调用业务工具）
                        // 天眼查 MCP 默认只公开17个工具，162个业务能力需通过 call_tool 代理
                        let bizTools = ["get_company_registration_info", "get_shareholder_info", "get_judicial_case"]
                        let fetchResults = HashMap<String, JsonValue>()
                        let mcpLogEntries = ArrayList<JsonValue>()
                        for (i in 0..bizTools.size) {
                            let bizTool = bizTools[i]
                            let toolArgs = DdHandlers.buildToolArgs(enterpriseName, creditCode, bizTool)
                            eprintln("[dd] calling host.mcp: alias=${effectiveAlias}, call_tool→${bizTool}")
                            let mcpResult = DdHandlers.callMcp(ctx, effectiveAlias, "call_tool", toolArgs)
                            // 解析返回 {data, meta:{tool, durationMs, status, errorMessage}}
                            var durationMs: Int64 = 0
                            var statusStr = "success"
                            var errorMsg = ""
                            match (mcpResult) {
                                case JsonValue.Map(mcpMap) =>
                                    match (mcpMap.get("data")) {
                                        case Some(dataVal) => fetchResults[bizTool] = dataVal
                                        case None => fetchResults[bizTool] = JsonValue.Null
                                    }
                                    match (mcpMap.get("meta")) {
                                        case Some(JsonValue.Map(metaMap)) =>
                                            match (metaMap.get("durationMs")) {
                                                case Some(JsonValue.Number(d)) => durationMs = Int64(d)
                                                case _ => ()
                                            }
                                            match (metaMap.get("status")) {
                                                case Some(JsonValue.String(s)) => statusStr = s
                                                case _ => ()
                                            }
                                            match (metaMap.get("errorMessage")) {
                                                case Some(JsonValue.String(s)) => errorMsg = s
                                                case _ => ()
                                            }
                                        case _ => ()
                                    }
                                case _ =>
                                    fetchResults[bizTool] = JsonValue.Null
                                    statusStr = "failed"
                                    errorMsg = "MCP call returned unexpected format"
                            }
                            // 落 mcp_call_log
                            PersistService.logMcpCall(taskId, bizTool, toolArgs, durationMs, statusStr, errorMsg, userId, permArr)
                            // 记录日志摘要
                            let logEntry = HashMap<String, JsonValue>()
                            logEntry["tool_name"] = JsonValue.String(bizTool)
                            logEntry["duration_ms"] = JsonValue.Number(Float64(durationMs))
                            logEntry["result_status"] = JsonValue.String(statusStr)
                            if (!errorMsg.isEmpty()) {
                                logEntry["error_message"] = JsonValue.String(errorMsg)
                            }
                            mcpLogEntries.add(JsonValue.from(logEntry))
                        }
                        // 汇总返回
                        let response = HashMap<String, JsonValue>()
                        response["enterprise_name"] = JsonValue.String(enterpriseName)
                        response["credit_code"] = JsonValue.String(creditCode)
                        response["mcp_alias"] = JsonValue.String(effectiveAlias)
                        response["fetch_results"] = JsonValue.from(fetchResults)
                        response["mcp_call_log"] = JsonValue.Array(mcpLogEntries)
                        response["tools_called"] = JsonValue.Number(Float64(bizTools.size))
                        return JsonValue.from(response)
                }
        }
    }

    // ── dd-save：幂等落库 ───────────────────────────────────────────
    // 经 PersistService 幂等 upsert 企业/股权/风险/报告

    private static func handleDdSave(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[dd] handleDdSave entered")
        let body = DdHandlers.extractBody(fields)
        match (body) {
            case None => return DdHandlers.errResult(40001, "提交数据格式错误")
            case Some(bodyMap) =>
                let userId = DdHandlers.extractString(fields, "userId")
                let permArr = DdHandlers.extractPermissions(fields)
                let counts = HashMap<String, JsonValue>()
                // 1. upsert 企业
                match (bodyMap.get("enterprise")) {
                    case Some(JsonValue.Map(entMap)) =>
                        let dataMap = DdHandlers.jsonMapToHashMap(entMap)
                        PersistService.upsertEnterprise(dataMap, userId, permArr)
                        counts["enterprise"] = JsonValue.Number(1.0)
                    case _ => counts["enterprise"] = JsonValue.Number(0.0)
                }
                // 2. upsert 股权（数组）
                var equityCount: Int64 = 0
                match (bodyMap.get("equity")) {
                    case Some(JsonValue.Array(equityArr)) =>
                        for (item in equityArr) {
                            match (item) {
                                case JsonValue.Map(eqMap) =>
                                    let dataMap = DdHandlers.jsonMapToHashMap(eqMap)
                                    PersistService.upsertEquity(dataMap, userId, permArr)
                                    equityCount += 1
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
                counts["equity"] = JsonValue.Number(Float64(equityCount))
                // 3. upsert 风险（数组）
                var riskCount: Int64 = 0
                match (bodyMap.get("risks")) {
                    case Some(JsonValue.Array(riskArr)) =>
                        for (item in riskArr) {
                            match (item) {
                                case JsonValue.Map(riskMap) =>
                                    let dataMap = DdHandlers.jsonMapToHashMap(riskMap)
                                    PersistService.upsertRisk(dataMap, userId, permArr)
                                    riskCount += 1
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
                counts["risk"] = JsonValue.Number(Float64(riskCount))
                // 4. upsert 报告
                match (bodyMap.get("report")) {
                    case Some(JsonValue.Map(reportMap)) =>
                        let dataMap = DdHandlers.jsonMapToHashMap(reportMap)
                        PersistService.upsertReport(dataMap, userId, permArr)
                        counts["report"] = JsonValue.Number(1.0)
                    case _ => counts["report"] = JsonValue.Number(0.0)
                }
                let response = HashMap<String, JsonValue>()
                response["errno"] = JsonValue.Number(0.0)
                response["errmsg"] = JsonValue.String("ok")
                response["saved_counts"] = JsonValue.from(counts)
                return JsonValue.from(response)
        }
    }

    // ── 内部辅助方法 ────────────────────────────────────────────────

    /// 调用 host.mcp
    private static func callMcp(ctx: PluginContext, mcpAlias: String, tool: String, arguments: String): JsonValue {
        let mcpParam = HashMap<String, JsonValue>()
        mcpParam["mcpAlias"] = JsonValue.String(mcpAlias)
        mcpParam["tool"] = JsonValue.String(tool)
        try {
            let argJson = JsonValue.parse(arguments)
            mcpParam["arguments"] = argJson
        } catch (e: Exception) {
            mcpParam["arguments"] = JsonValue.String(arguments)
        }
        let mcpArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
        mcpArgs[0] = JsonValue.from(mcpParam)
        // 纯赋值形式消歧：invoke 有非泛型与泛型两个重载，带期望类型（let result: JsonValue
        // 或直接 return）时两个重载都匹配而报 ambiguous match；无期望类型时泛型重载的 R
        // 无法从实参推断，唯一候选为非泛型重载（与 codelabs 插件调用惯例一致）。
        let result = ctx.invoke("host.mcp", "call", mcpArgs)
        return result
    }

    /// 构造 call_tool 代理入参 JSON（天眼查 MCP 业务工具需经 call_tool 代理调用）
    /// 官方文档：call_tool 参数为 company_name + tool_name + page/page_size
    private static func buildToolArgs(enterpriseName: String, creditCode: String, bizTool: String): String {
        let companyKey = if (!creditCode.isEmpty()) { creditCode } else { enterpriseName }
        return "{\"company_name\": \"${companyKey}\", \"tool_name\": \"${bizTool}\", \"page\": 1, \"page_size\": 20}"
    }

    /// 获取表的可写字段白名单
    private static func getWritableColumns(table: String): Array<String> {
        if (table == "due_diligence_task") {
            return ["task_name", "enterprise_list", "scene_type", "task_status", "total_count", "success_count", "fail_count", "creator", "deleted_at"]
        }
        if (table == "due_diligence_enterprise") {
            return ["enterprise_name", "credit_code", "legal_representative", "registered_capital", "established_date", "registration_status", "business_scope", "data_source", "fetched_at", "scene_type", "task_id", "creator", "deleted_at"]
        }
        if (table == "due_diligence_equity") {
            return ["enterprise_id", "shareholder_name", "shareholding_ratio", "penetration_level", "shareholding_path", "is_beneficial_owner", "creator", "deleted_at"]
        }
        if (table == "due_diligence_risk") {
            return ["enterprise_id", "risk_type", "risk_level", "level_basis", "risk_description", "risk_date", "source_tool", "creator", "deleted_at"]
        }
        if (table == "due_diligence_report") {
            return ["enterprise_id", "title", "report_content", "report_format", "generated_at", "disclaimer", "scene_type", "creator", "deleted_at"]
        }
        if (table == "due_diligence_mcp_call_log") {
            return ["task_id", "tool_name", "tool_arg", "duration_ms", "result_status", "error_message", "creator", "deleted_at"]
        }
        return Array<String>(0, { _ => "" })
    }

    /// 恢复操作：SET deleted_at=NULL
    private static func doRestore(
        table: String,
        bodyMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        var whereClause = ""
        match (bodyMap.get("ids")) {
            case Some(JsonValue.String(idsStr)) =>
                let idList = DdHelpers_parseIdList(idsStr)
                if (idList.size == 0) {
                    return DdHandlers.errResult(40002, "ids 参数为空")
                }
                whereClause = "id IN (${DdHelpers_joinQuoted(idList)})"
            case _ =>
                match (bodyMap.get("id")) {
                    case Some(JsonValue.String(idStr)) =>
                        whereClause = "id = '${idStr}'"
                    case _ =>
                        return DdHandlers.errResult(40002, "缺少 id 或 ids 参数")
                }
        }
        let dataMap = HashMap<String, JsonValue>()
        dataMap["deleted_at"] = JsonValue.Null
        return PersistService.update(table, whereClause, dataMap, userId, permArr)
    }

    /// 从 ExternalRequest 提取 body
    private static func extractBody(fields: HashMap<String, JsonValue>): ?HashMap<String, JsonValue> {
        match (fields.get("body")) {
            case Some(JsonValue.Map(bodyMap)) => return Some(bodyMap)
            case _ => return None
        }
    }

    /// 从 ExternalRequest 提取 permissions
    private static func extractPermissions(fields: HashMap<String, JsonValue>): ArrayList<JsonValue> {
        let permArr = ArrayList<JsonValue>()
        match (fields.get("permissions")) {
            case Some(JsonValue.Array(arr)) =>
                for (p in arr) { permArr.add(p) }
            case _ => ()
        }
        return permArr
    }

    /// 从 filter 参数构建 WHERE 子句
    private static func buildWhereFromFilter(fields: HashMap<String, JsonValue>): String {
        var filterStr = ""
        match (fields.get("queryParams")) {
            case Some(JsonValue.Map(qp)) =>
                match (qp.get("filter")) {
                    case Some(JsonValue.String(s)) => filterStr = s
                    case _ => ()
                }
            case _ => ()
        }
        if (!filterStr.isEmpty()) {
            filterStr = filterStr.replace("%7B", "{")
                .replace("%7D", "}")
                .replace("%22", "\"")
                .replace("%3A", ":")
                .replace("%2C", ",")
                .replace("+", " ")
        }
        if (filterStr.isEmpty()) {
            return "deleted_at IS NULL"
        }
        try {
            let filterJson = JsonValue.parse(filterStr)
            match (filterJson) {
                case JsonValue.Map(filterMap) =>
                    match (filterMap.get("deleted_at")) {
                        case Some(JsonValue.Null) => return "deleted_at IS NULL"
                        case Some(JsonValue.Map(daMap)) =>
                            match (daMap.get("not")) {
                                case Some(JsonValue.Null) => return "deleted_at IS NOT NULL"
                                case _ => ()
                            }
                            return "deleted_at IS NULL"
                        case _ => ()
                    }
                case _ => ()
            }
        } catch (e: Exception) {
            eprintln("[dd] buildWhereFromFilter: JSON parse error: ${e.message}")
        }
        return "deleted_at IS NULL"
    }

    /// JsonValue.Map → HashMap<String, JsonValue>
    private static func jsonMapToHashMap(jsonMap: HashMap<String, JsonValue>): HashMap<String, JsonValue> {
        let result = HashMap<String, JsonValue>()
        for (kv in jsonMap) {
            result[kv[0]] = kv[1]
        }
        return result
    }

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

// ── 顶层辅助函数 ──────────────────────────────────────────────────

public func DdHelpers_parseIdList(idsStr: String): ArrayList<String> {
    let idList = ArrayList<String>()
    if (idsStr.isEmpty()) {
        return idList
    }
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

public func DdHelpers_joinQuoted(idList: ArrayList<String>): String {
    let sb = StringBuilder()
    var first = true
    for (id in idList) {
        if (!first) {
            sb.append(",")
        }
        let escaped = id.replace("'", "''")
        sb.append("'")
        sb.append(escaped)
        sb.append("'")
        first = false
    }
    return sb.toString()
}