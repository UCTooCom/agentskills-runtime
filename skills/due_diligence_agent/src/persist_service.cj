/*
 * 6 张表幂等读写封装（due_diligence_agent）
 * 经 ctx.invoke("host.db", ...) 访问宿主数据库
 * 幂等策略：先查后写（命中 UPDATE / 未命中 INSERT）
 *
 * 编码依据：skills/codelabs/src/handlers.cj（host.db execute/query 参数范式）
 *   - execute 参数：operation/subOp/where/data/userId/permissions
 *   - query 参数：operation/table/where/orderBy/limit/offset/userId/permissions
 *   - "$raw:" 前缀让 host.db 生成原始 SQL 函数（不加引号）
 */
package skill_due_diligence_agent

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*
import std.collection.{HashMap, ArrayList}

public class PersistService {
    private static var ctx: ?PluginContext = None

    /// 6 张表名常量
    public static let TABLE_TASK: String = "due_diligence_task"
    public static let TABLE_ENTERPRISE: String = "due_diligence_enterprise"
    public static let TABLE_EQUITY: String = "due_diligence_equity"
    public static let TABLE_RISK: String = "due_diligence_risk"
    public static let TABLE_REPORT: String = "due_diligence_report"
    public static let TABLE_MCP_LOG: String = "due_diligence_mcp_call_log"

    /// 初始化插件上下文（仓颉中 init 是构造器关键字，不能作普通函数名，故命名为 initialize）
    public static func initialize(ctx: PluginContext): Unit {
        PersistService.ctx = ctx
    }

    // ── 通用查询 ────────────────────────────────────────────────────

    /// 按条件查询单条记录，返回 JsonValue（记录对象）或 JsonValue.Null
    public static func queryOne(
        table: String,
        whereClause: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let ctxOpt = PersistService.ctx
        match (ctxOpt) {
            case None => return JsonValue.Null
            case Some(ctx) =>
                let queryParam = HashMap<String, JsonValue>()
                queryParam["operation"] = JsonValue.String("query")
                queryParam["table"] = JsonValue.String(table)
                queryParam["where"] = JsonValue.String(whereClause)
                queryParam["limit"] = JsonValue.Number(1.0)
                if (!userId.isEmpty()) {
                    queryParam["userId"] = JsonValue.String(userId)
                }
                if (permArr.size > 0) {
                    queryParam["permissions"] = JsonValue.Array(permArr)
                }
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
    }

    /// 按条件查询多条记录
    public static func queryMany(
        table: String,
        whereClause: String,
        userId: String,
        permArr: ArrayList<JsonValue>,
        limit: Int64
    ): Array<JsonValue> {
        let ctxOpt = PersistService.ctx
        match (ctxOpt) {
            case None => return Array<JsonValue>(0, { _ => JsonValue.Null })
            case Some(ctx) =>
                let queryParam = HashMap<String, JsonValue>()
                queryParam["operation"] = JsonValue.String("query")
                queryParam["table"] = JsonValue.String(table)
                queryParam["where"] = JsonValue.String(whereClause)
                queryParam["orderBy"] = JsonValue.String("created_at DESC")
                queryParam["limit"] = JsonValue.Number(Float64(limit))
                if (!userId.isEmpty()) {
                    queryParam["userId"] = JsonValue.String(userId)
                }
                if (permArr.size > 0) {
                    queryParam["permissions"] = JsonValue.Array(permArr)
                }
                let queryArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                queryArgs[0] = JsonValue.from(queryParam)
                let queryResult = ctx.invoke<JsonValue, JsonValue>("host.db", "query", queryArgs)
                match (queryResult) {
                    case JsonValue.Map(qFields) =>
                        match (qFields.get("rows")) {
                            case Some(JsonValue.Array(rows)) => return rows.toArray()
                            case _ => return Array<JsonValue>(0, { _ => JsonValue.Null })
                        }
                    case _ => return Array<JsonValue>(0, { _ => JsonValue.Null })
                }
        }
    }

    // ── 通用 INSERT ─────────────────────────────────────────────────

    public static func insert(
        table: String,
        dataMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let ctxOpt = PersistService.ctx
        match (ctxOpt) {
            case None => return PersistService.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                if (!userId.isEmpty()) {
                    dataMap["creator"] = JsonValue.String(userId)
                }
                let execParam = HashMap<String, JsonValue>()
                execParam["operation"] = JsonValue.String("execute")
                execParam["subOp"] = JsonValue.String("insert")
                execParam["table"] = JsonValue.String(table)
                execParam["data"] = JsonValue.from(dataMap)
                if (permArr.size > 0) {
                    execParam["permissions"] = JsonValue.Array(permArr)
                }
                if (!userId.isEmpty()) {
                    execParam["userId"] = JsonValue.String(userId)
                }
                let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                execArgs[0] = JsonValue.from(execParam)
                let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                eprintln("[persist] insert ${table} result: ${execResult.stringify()}")
                return execResult
        }
    }

    // ── 通用 UPDATE ─────────────────────────────────────────────────

    public static func update(
        table: String,
        whereClause: String,
        dataMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let ctxOpt = PersistService.ctx
        match (ctxOpt) {
            case None => return PersistService.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let execParam = HashMap<String, JsonValue>()
                execParam["operation"] = JsonValue.String("execute")
                execParam["subOp"] = JsonValue.String("update")
                execParam["table"] = JsonValue.String(table)
                execParam["where"] = JsonValue.String(whereClause)
                execParam["data"] = JsonValue.from(dataMap)
                if (permArr.size > 0) {
                    execParam["permissions"] = JsonValue.Array(permArr)
                }
                if (!userId.isEmpty()) {
                    execParam["userId"] = JsonValue.String(userId)
                }
                let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                execArgs[0] = JsonValue.from(execParam)
                let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                eprintln("[persist] update ${table} result: ${execResult.stringify()}")
                return execResult
        }
    }

    // ── 通用 DELETE（物理删除）────────────────────────────────────

    public static func hardDelete(
        table: String,
        whereClause: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let ctxOpt = PersistService.ctx
        match (ctxOpt) {
            case None => return PersistService.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let execParam = HashMap<String, JsonValue>()
                execParam["operation"] = JsonValue.String("execute")
                execParam["subOp"] = JsonValue.String("delete")
                execParam["table"] = JsonValue.String(table)
                execParam["where"] = JsonValue.String(whereClause)
                if (permArr.size > 0) {
                    execParam["permissions"] = JsonValue.Array(permArr)
                }
                if (!userId.isEmpty()) {
                    execParam["userId"] = JsonValue.String(userId)
                }
                let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                execArgs[0] = JsonValue.from(execParam)
                let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                eprintln("[persist] hardDelete ${table} result: ${execResult.stringify()}")
                return execResult
        }
    }

    // ── 幂等 upsert：企业表 ────────────────────────────────────────
    // 判重：credit_code + enterprise_name（credit_code 可空时仅用 enterprise_name）

    public static func upsertEnterprise(
        dataMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let creditCode = PersistService.extractStringFromMap(dataMap, "credit_code")
        let entName = PersistService.extractStringFromMap(dataMap, "enterprise_name")
        var whereClause = ""
        if (!creditCode.isEmpty()) {
            whereClause = "credit_code = '${creditCode}' AND deleted_at IS NULL"
        } else {
            whereClause = "enterprise_name = '${entName}' AND deleted_at IS NULL"
        }
        let existing = PersistService.queryOne(PersistService.TABLE_ENTERPRISE, whereClause, userId, permArr)
        match (existing) {
            case JsonValue.Map(existingMap) =>
                match (existingMap.get("id")) {
                    case Some(JsonValue.String(existingId)) =>
                        let updateData = HashMap<String, JsonValue>()
                        for (kv in dataMap) {
                            updateData[kv[0]] = kv[1]
                        }
                        return PersistService.update(PersistService.TABLE_ENTERPRISE, "id = '${existingId}'", updateData, userId, permArr)
                    case _ => ()
                }
            case _ => ()
        }
        return PersistService.insert(PersistService.TABLE_ENTERPRISE, dataMap, userId, permArr)
    }

    // ── 幂等 upsert：股权表 ────────────────────────────────────────
    // 判重：enterprise_id + shareholder_name + penetration_level

    public static func upsertEquity(
        dataMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let entId = PersistService.extractStringFromMap(dataMap, "enterprise_id")
        let shareholder = PersistService.extractStringFromMap(dataMap, "shareholder_name")
        let levelStr = match (dataMap.get("penetration_level")) {
            case Some(JsonValue.Number(n)) => Int64(n).toString()
            case _ => "0"
        }
        let whereClause = "enterprise_id = '${entId}' AND shareholder_name = '${shareholder}' AND penetration_level = ${levelStr} AND deleted_at IS NULL"
        let existing = PersistService.queryOne(PersistService.TABLE_EQUITY, whereClause, userId, permArr)
        match (existing) {
            case JsonValue.Map(existingMap) =>
                match (existingMap.get("id")) {
                    case Some(JsonValue.String(existingId)) =>
                        return PersistService.update(PersistService.TABLE_EQUITY, "id = '${existingId}'", dataMap, userId, permArr)
                    case _ => ()
                }
            case _ => ()
        }
        return PersistService.insert(PersistService.TABLE_EQUITY, dataMap, userId, permArr)
    }

    // ── 幂等 upsert：风险表 ────────────────────────────────────────
    // 判重：enterprise_id + risk_type + risk_description

    public static func upsertRisk(
        dataMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let entId = PersistService.extractStringFromMap(dataMap, "enterprise_id")
        let riskType = PersistService.extractStringFromMap(dataMap, "risk_type")
        let riskDesc = PersistService.extractStringFromMap(dataMap, "risk_description")
        let whereClause = "enterprise_id = '${entId}' AND risk_type = '${riskType}' AND risk_description = '${riskDesc}' AND deleted_at IS NULL"
        let existing = PersistService.queryOne(PersistService.TABLE_RISK, whereClause, userId, permArr)
        match (existing) {
            case JsonValue.Map(existingMap) =>
                match (existingMap.get("id")) {
                    case Some(JsonValue.String(existingId)) =>
                        return PersistService.update(PersistService.TABLE_RISK, "id = '${existingId}'", dataMap, userId, permArr)
                    case _ => ()
                }
            case _ => ()
        }
        return PersistService.insert(PersistService.TABLE_RISK, dataMap, userId, permArr)
    }

    // ── 幂等 upsert：报告表 ────────────────────────────────────────
    // 判重：enterprise_id + report_format

    public static func upsertReport(
        dataMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let entId = PersistService.extractStringFromMap(dataMap, "enterprise_id")
        let reportFormat = PersistService.extractStringFromMap(dataMap, "report_format")
        let whereClause = "enterprise_id = '${entId}' AND report_format = '${reportFormat}' AND deleted_at IS NULL"
        let existing = PersistService.queryOne(PersistService.TABLE_REPORT, whereClause, userId, permArr)
        match (existing) {
            case JsonValue.Map(existingMap) =>
                match (existingMap.get("id")) {
                    case Some(JsonValue.String(existingId)) =>
                        let updateData = HashMap<String, JsonValue>()
                        for (kv in dataMap) {
                            updateData[kv[0]] = kv[1]
                        }
                        updateData["generated_at"] = JsonValue.String("$raw:CURRENT_TIMESTAMP")
                        return PersistService.update(PersistService.TABLE_REPORT, "id = '${existingId}'", updateData, userId, permArr)
                    case _ => ()
                }
            case _ => ()
        }
        return PersistService.insert(PersistService.TABLE_REPORT, dataMap, userId, permArr)
    }

    // ── MCP 调用日志落库（只插入，不判重）─────────────────────────

    public static func logMcpCall(
        taskId: String,
        toolName: String,
        toolArg: String,
        durationMs: Int64,
        resultStatus: String,
        errorMessage: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        if (!taskId.isEmpty()) {
            dataMap["task_id"] = JsonValue.String(taskId)
        }
        dataMap["tool_name"] = JsonValue.String(toolName)
        if (!toolArg.isEmpty()) {
            dataMap["tool_arg"] = JsonValue.String(toolArg)
        }
        dataMap["duration_ms"] = JsonValue.Number(Float64(durationMs))
        dataMap["result_status"] = JsonValue.String(resultStatus)
        if (!errorMessage.isEmpty()) {
            dataMap["error_message"] = JsonValue.String(errorMessage)
        }
        return PersistService.insert(PersistService.TABLE_MCP_LOG, dataMap, userId, permArr)
    }

    // ── 辅助方法 ────────────────────────────────────────────────────

    private static func extractStringFromMap(map: HashMap<String, JsonValue>, key: String): String {
        match (map.get(key)) {
            case Some(JsonValue.String(s)) => return s
            case _ => return ""
        }
    }

    private static func errResult(errno: Int64, errmsg: String): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["errno"] = JsonValue.Number(Float64(errno))
        m["errmsg"] = JsonValue.String(errmsg)
        return JsonValue.from(m)
    }
}