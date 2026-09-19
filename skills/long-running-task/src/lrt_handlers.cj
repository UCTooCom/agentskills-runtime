/*
 * V4 CRUD RPC handler 框架（long-running-task）
 * 独立进程插件，通过 ctx.invoke("host.db", ...) 访问宿主数据库
 * 通过 ctx.invoke("host.mcp", "call", ...) 调用宿主统一 MCP 开放服务
 *
 * 路由（遵循 uctoo V4 API 规范）：
 *   2 张表各有标准 CRUD：
 *     GET  /:table/:limit/:page          分页列表
 *     GET  /:table/:id                   单条查询
 *     POST /:table/add                   创建
 *     POST /:table/edit                  更新
 *     POST /:table/del                   删除
 *     POST /:table/empty-recycle-bin     清空回收站
 *   自定义路由：
 *     POST /long_running_task/lrt-plan      创建根任务（AI 自主规划入口）
 *     POST /long_running_task/lrt-execute   触发执行回合（标记 running）
 *     POST /long_running_task/lrt-intervene 暂停/恢复/取消/调整目标
 *     POST /long_running_task/lrt-verify    产物校验记录
 *     POST /long_running_task/lrt-evolve    自进化闭环记录
 *
 * 列表键名遵守 API 规范 §8.2：表名 + s（复数）
 *
 * 编码依据：skills/due_diligence_agent/src/dd_handlers.cj（dispatch 路由分发 + host.db 调用范式）
 */
package skill_long_running_task

import ystyle::cordis_plugin.{PluginContext, PluginRuntime}
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

public class LrtHandlers {
    private static var ctx: ?PluginContext = None

    /// 支持的 2 张表
    private static let TABLES: Array<String> = [
        "long_running_task_artifact",
        "long_running_task_evolution"
    ]

    public static func register(ctx: PluginContext): Unit {
        LrtHandlers.ctx = ctx
        LrtPersistService.initialize(ctx)
        // 事件上报通道（spec §9.2）：与持久化共用同一个 ctx。
        // 在这里初始化而不是 main.cj：保持"ctx 注入点只有一个"的既有约定。
        LrtEventEmitter.initialize(ctx)
        ctx.registerHandler("long-running-task", { method, args => LrtHandlers.dispatch(method, args) })
    }

    /**
     * 路由分发：根据 HTTP method + path 分发到具体 handler
     */
    private static func dispatch(httpMethod: String, args: Array<JsonValue>): JsonValue {
        if (args.size == 0) {
            return LrtHandlers.errResult(1, "missing args")
        }
        let extReq = args[0]
        match (extReq) {
            case JsonValue.Map(fields) =>
                let path = LrtHandlers.extractString(fields, "path")
                let reqMethod = LrtHandlers.extractString(fields, "method")

                // 自定义路由优先匹配
                if (reqMethod == "POST" && path.contains("/long_running_task/lrt-plan")) {
                    return LrtHandlers.handleLrtPlan(fields, args)
                }
                if (reqMethod == "POST" && path.contains("/long_running_task/lrt-execute")) {
                    return LrtHandlers.handleLrtExecute(fields, args)
                }
                if (reqMethod == "POST" && path.contains("/long_running_task/lrt-intervene")) {
                    return LrtHandlers.handleLrtIntervene(fields, args)
                }
                if (reqMethod == "POST" && path.contains("/long_running_task/lrt-verify")) {
                    return LrtHandlers.handleLrtVerify(fields, args)
                }
                if (reqMethod == "POST" && path.contains("/long_running_task/lrt-evolve")) {
                    return LrtHandlers.handleLrtEvolve(fields, args)
                }
                if (reqMethod == "POST" && path.contains("/long_running_task/lrt-deliver")) {
                    return LrtHandlers.handleLrtDeliver(fields, args)
                }
                if (reqMethod == "POST" && path.contains("/long_running_task/lrt-review")) {
                    return LrtHandlers.handleLrtReview(fields, args)
                }

                // 2 张表 CRUD 路由匹配
                for (table in LrtHandlers.TABLES) {
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
                                    return LrtHandlers.handleList(table, fields, args)
                                } else {
                                    return LrtHandlers.handleGet(table, fields, args)
                                }
                            }
                            return LrtHandlers.handleList(table, fields, args)
                        } else if (reqMethod == "POST") {
                            if (path.contains("/${table}/add")) {
                                return LrtHandlers.handleAdd(table, fields, args)
                            } else if (path.contains("/${table}/edit")) {
                                return LrtHandlers.handleEdit(table, fields, args)
                            } else if (path.contains("/${table}/del")) {
                                return LrtHandlers.handleDel(table, fields, args)
                            } else if (path.contains("/${table}/empty-recycle-bin")) {
                                return LrtHandlers.handleEmptyRecycleBin(table, fields, args)
                            }
                        }
                    }
                }
                return LrtHandlers.errResult(1, "no route matched: ${reqMethod} ${path}")
            case _ => return LrtHandlers.errResult(1, "invalid args format")
        }
        return LrtHandlers.errResult(1, "dispatch fallback")
    }

    // ── 通用 CRUD handlers（复用 PersistService，逻辑与 dd_handlers 一致）─────

    private static func handleAdd(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleAdd ${table} entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let dataMap = HashMap<String, JsonValue>()
                        let writableCols = LrtHandlers.getWritableColumns(table)
                        for (col in writableCols) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        let userId = LrtHandlers.extractString(fields, "userId")
                        if (!userId.isEmpty()) {
                            dataMap["creator"] = JsonValue.String(userId)
                        }
                        let permArr = LrtHandlers.extractPermissions(fields)
                        return LrtPersistService.insert(table, dataMap, userId, permArr)
                }
        }
    }

    private static func handleEdit(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleEdit ${table} entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        let dataMap = HashMap<String, JsonValue>()
                        let writableCols = LrtHandlers.getWritableColumns(table)
                        for (col in writableCols) {
                            match (bodyMap.get(col)) {
                                case Some(v) => dataMap[col] = v
                                case None => ()
                            }
                        }
                        if (dataMap.size == 0) {
                            return LrtHandlers.errResult(40002, "没有可更新的字段")
                        }
                        var whereClause = ""
                        match (bodyMap.get("ids")) {
                            case Some(JsonValue.String(idsStr)) =>
                                let idList = LrtHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return LrtHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (${LrtHelpers_joinQuoted(idList)})"
                            case _ =>
                                match (bodyMap.get("id")) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return LrtHandlers.errResult(40002, "缺少 id 或 ids 参数")
                                }
                        }
                        return LrtPersistService.update(table, whereClause, dataMap, userId, permArr)
                }
        }
    }

    private static func handleDel(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleDel ${table} entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        var whereClause = ""
                        match (bodyMap.get("ids")) {
                            case Some(JsonValue.String(idsStr)) =>
                                let idList = LrtHelpers_parseIdList(idsStr)
                                if (idList.size == 0) {
                                    return LrtHandlers.errResult(40002, "ids 参数为空")
                                }
                                whereClause = "id IN (${LrtHelpers_joinQuoted(idList)})"
                            case _ =>
                                match (bodyMap.get("id")) {
                                    case Some(JsonValue.String(idStr)) =>
                                        whereClause = "id = '${idStr}'"
                                    case _ =>
                                        return LrtHandlers.errResult(40002, "缺少 id 或 ids 参数")
                                }
                        }
                        let forceVal = bodyMap.get("force")
                        let isHardDelete = match (forceVal) {
                            case Some(JsonValue.Number(n)) => n == 1.0
                            case Some(JsonValue.String(s)) => s == "1" || s == "true"
                            case _ => false
                        }
                        if (isHardDelete) {
                            return LrtPersistService.hardDelete(table, whereClause, userId, permArr)
                        } else {
                            let dataMap = HashMap<String, JsonValue>()
                            dataMap["deleted_at"] = JsonValue.String("$raw:CURRENT_TIMESTAMP")
                            return LrtPersistService.update(table, whereClause, dataMap, userId, permArr)
                        }
                }
        }
    }

    private static func handleGet(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleGet ${table} entered")
        let path = LrtHandlers.extractString(fields, "path")
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
            return LrtHandlers.errResult(40002, "缺少 ID 参数")
        }
        let userId = LrtHandlers.extractString(fields, "userId")
        let permArr = LrtHandlers.extractPermissions(fields)
        let result = LrtPersistService.queryOne(table, "id = '${idStr}'", userId, permArr)
        match (result) {
            case JsonValue.Null => return LrtHandlers.errResult(40401, "未找到记录")
            case _ => return result
        }
    }

    private static func handleList(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleList ${table} entered")
        let path = LrtHandlers.extractString(fields, "path")
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
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let userId = fields.get("userId")
                let permissions = fields.get("permissions")
                let whereClause = LrtHandlers.buildWhereFromFilter(fields)
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
                    case Some(JsonValue.Array(arr)) =>
                        if (arr.size > 0) { queryParam["permissions"] = JsonValue.Array(arr) }
                    case Some(v) => queryParam["permissions"] = v
                    case None => ()
                }
                let queryArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                queryArgs[0] = JsonValue.from(queryParam)
                // 显式 <JsonValue, JsonValue> 消歧（原因见 lrt_composition_runner.cj 同处注释）：
                // 不写类型实参时两个同形重载报 ambiguous match。
                let queryResult = ctx.invoke<JsonValue, JsonValue>("host.db", "query", queryArgs)

                let countParam = HashMap<String, JsonValue>()
                countParam["operation"] = JsonValue.String("count")
                countParam["table"] = JsonValue.String(table)
                countParam["where"] = JsonValue.String(whereClause)
                match (userId) {
                    case Some(v) => countParam["userId"] = v
                    case None => ()
                }
                match (permissions) {
                    case Some(JsonValue.Array(arr)) =>
                        if (arr.size > 0) { countParam["permissions"] = JsonValue.Array(arr) }
                    case Some(v) => countParam["permissions"] = v
                    case None => ()
                }
                let countArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                countArgs[0] = JsonValue.from(countParam)
                let countResult = ctx.invoke<JsonValue, JsonValue>("host.db", "count", countArgs)

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
        eprintln("[lrt] handleEmptyRecycleBin ${table} entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let userId = LrtHandlers.extractString(fields, "userId")
                let permArr = LrtHandlers.extractPermissions(fields)
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
                let execResult = ctx.invoke<JsonValue, JsonValue>("host.db", "execute", execArgs)
                eprintln("[lrt] empty-recycle-bin ${table} result: ${execResult.stringify()}")
                return LrtHandlers.okResult("empty-recycle-bin")
        }
    }

    // ── 自定义路由：lrt-plan（创建根任务 + AI 自主规划入口）────────────
    // body: { goal, payload? } —— 创建 agent_tasks 根记录（parent_task_id=NULL, status=0）

    private static func handleLrtPlan(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleLrtPlan entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let goal = LrtHandlers.extractStringFromMap(bodyMap, "goal")
                        if (goal.isEmpty()) {
                            return LrtHandlers.errResult(40002, "goal 不能为空")
                        }
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        // 1) 先创建根任务（parent_task_id=NULL, status=0），拿到 task_id
                        let payloadMap = HashMap<String, JsonValue>()
                        payloadMap["goal"] = JsonValue.String(goal)
                        payloadMap["created_via"] = JsonValue.String("lrt-plan")
                        let created = LrtPersistService.createRootTask(goal, payloadMap, userId, permArr)
                        let rootTaskId = LrtHandlers.extractCreatedId(created)
                        // 2) AI 自主解析目标 + 任务树分解 + 技能发现，并将 plan 持久化到 agent_tasks.payload
                        //    （taskId 非空时 plan() 内部会经 createChildTask 写入子任务树）
                        let planResult = LrtPlanner.plan(goal, rootTaskId, userId, permArr)
                        let response = HashMap<String, JsonValue>()
                        response["errno"] = JsonValue.Number(0.0)
                        response["errmsg"] = JsonValue.String("ok")
                        response["task_id"] = JsonValue.String(rootTaskId)
                        response["task"] = created
                        response["plan"] = match (planResult.get("goal", JsonValue.Null)) {
                            case v => v
                        }
                        return JsonValue.from(response)
                }
        }
    }

    // ── 自定义路由：lrt-execute（触发执行回合）────────────────────────
    // body: { task_id } —— 标记 agent_tasks.status=1（running），由宿主调度引擎驱动回合

    private static func handleLrtExecute(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleLrtExecute entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let taskId = LrtHandlers.extractStringFromMap(bodyMap, "task_id")
                        if (taskId.isEmpty()) {
                            return LrtHandlers.errResult(40002, "task_id 不能为空")
                        }
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        // 1) 加载任务目标与 agent 标识（供执行回合使用）
                        let task = LrtPersistService.queryOne(
                            LrtPersistService.TABLE_AGENT_TASKS, "id = '${taskId}' AND deleted_at IS NULL", userId, permArr
                        )
                        let goal = LrtHandlers.extractGoalFromTask(task)
                        var agentId = LrtHandlers.extractStringFromTask(task, "agent_id")
                        if (agentId.isEmpty()) {
                            agentId = "long-running-task"
                        }
                        // 2) 标记 running，启动 D-P-H-E 收敛循环（异步 spawn，避免阻塞 JSON-RPC）
                        LrtPersistService.updateTaskStatus(taskId, 1, userId, permArr)
                        // Ch4.1：这里曾经是硬编码 30——改 plugin.yaml 完全不起作用。
                        // 现在统一从 plugin.yaml 的 config.maxRounds 读（LRT_MAX_ROUNDS 可覆盖），
                        // 使"宿主侧 AgentExecutionExecutor.maxRounds"与"插件侧收敛上限"同源。
                        let maxRounds: Int64 = LrtConfig.maxRounds()
                        let execPerm = ArrayList<JsonValue>()
                        for (p in permArr) { execPerm.add(p) }
                        let execTaskId = taskId
                        let execAgentId = agentId
                        let execGoal = goal
                        let execUserId = userId
                        spawn { =>
                            // §4.2：改为驱动整条 COMPOSITION（script 步跑 Python、plugin 步分发到本插件处理函数）。
                            // execute-rounds 步内部仍落到 LrtExecutor.runTask（验核收敛循环），不递归。
                            let r = LrtExecutor.runComposition(execTaskId, execAgentId, execGoal, execUserId, execPerm, maxRounds, "")
                            eprintln("[lrt] lrt-execute async composition outcome=${r.stringify()}")
                        }
                        let response = HashMap<String, JsonValue>()
                        response["errno"] = JsonValue.Number(0.0)
                        response["errmsg"] = JsonValue.String("ok")
                        response["task_id"] = JsonValue.String(taskId)
                        response["status"] = JsonValue.Number(1.0)
                        response["async"] = JsonValue.String("convergence loop started")
                        return JsonValue.from(response)
                }
        }
    }

    // ── 自定义路由：lrt-intervene（Ch5 / design 1.1.3.3）────────────────
    // body: { task_id, action, content?, goal? }
    //   pause          → agent_tasks.status=5（暂停）+ crontab.status=2（禁用调度）
    //   resume         → agent_tasks.status=1（从检查点继续）+ crontab.status=1（启用调度）
    //   cancel         → agent_tasks.status=4（当前步骤完成后生效，保留 result）
    //   force_cancel   → agent_tasks.status=4（立即终止）
    //   adjust_goal    → 更新 payload.goal + 置 replan_required，触发 LrtPlanner.replan
    //   add_constraint → 追加 payload.constraints + 置 replan_required，触发重规划
    //
    // 状态校验与状态迁移全部收敛在 LrtInterventionService（Ch5 实现），本 handler 只做
    // 参数提取与响应包装，避免同一套状态机在 handler/service 两处各写一遍。

    private static func handleLrtIntervene(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let taskId = LrtHandlers.extractStringFromMap(bodyMap, "task_id")
                        let action = LrtHandlers.extractStringFromMap(bodyMap, "action")
                        if (taskId.isEmpty()) {
                            return LrtHandlers.errResult(40002, "task_id 不能为空")
                        }
                        if (action.isEmpty()) {
                            return LrtHandlers.errResult(40002, "action 不能为空")
                        }
                        // content 优先取显式 content 字段；兼容旧调用方使用 goal 字段表意
                        var content = LrtHandlers.extractStringFromMap(bodyMap, "content")
                        if (content.isEmpty()) {
                            content = LrtHandlers.extractStringFromMap(bodyMap, "goal")
                        }
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        return LrtInterventionService.intervene(taskId, action, content, userId, permArr)
                }
        }
    }

    // ── 自定义路由：lrt-verify（产物校验记录）─────────────────────────
    // body: { task_id, artifact_path, artifact_type, verification_status, verification_result }

    private static func handleLrtVerify(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleLrtVerify entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let taskId = LrtHandlers.extractStringFromMap(bodyMap, "task_id")
                        let artifactPath = LrtHandlers.extractStringFromMap(bodyMap, "artifact_path")
                        if (artifactPath.isEmpty()) {
                            return LrtHandlers.errResult(40002, "artifact_path 不能为空")
                        }
                        let artifactType = LrtHandlers.extractStringFromMap(bodyMap, "artifact_type")
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        // 自主验核：从任务 payload 取目标，调 D 层 verify_artifact.py，验核结果自落库
                        let task = LrtPersistService.queryOne(
                            LrtPersistService.TABLE_AGENT_TASKS, "id = '${taskId}' AND deleted_at IS NULL", userId, permArr
                        )
                        let goal = LrtHandlers.extractGoalFromTask(task)
                        var agentId = LrtHandlers.extractStringFromTask(task, "agent_id")
                        if (agentId.isEmpty()) {
                            agentId = "long-running-task"
                        }
                        let result = LrtVerifier.verify(artifactPath, artifactType, taskId, agentId, userId, permArr, goal)
                        let response = HashMap<String, JsonValue>()
                        response["errno"] = JsonValue.Number(0.0)
                        response["errmsg"] = JsonValue.String("ok")
                        response["verification"] = result
                        return JsonValue.from(response)
                }
        }
    }

    // ── 自定义路由：lrt-evolve（触发自进化闭环）───────────────────────
    // body: { agent_id, round, context?, root_cause?, skill? } —— 以线索调 D 层 evolve.py 生成根因/优化/防回退并落库

    private static func handleLrtEvolve(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleLrtEvolve entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let agentId = LrtHandlers.extractStringFromMap(bodyMap, "agent_id")
                        let roundStr = LrtHandlers.extractStringFromMap(bodyMap, "round")
                        var round: Int64 = 0
                        match (Int64.tryParse(roundStr)) {
                            case Some(v) => round = v
                            case None => ()
                        }
                        // 自进化闭环：以 context/root_cause 为线索，调 D 层 evolve.py 生成根因/优化/防回退并落库
                        let context = LrtHandlers.extractStringFromMap(bodyMap, "context")
                        let ctxHint = if (context.isEmpty()) {
                            LrtHandlers.extractStringFromMap(bodyMap, "root_cause")
                        } else {
                            context
                        }
                        let skill = LrtHandlers.extractStringFromMap(bodyMap, "skill")
                        let skillName = if (skill.isEmpty()) { "long-running-task" } else { skill }
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        let result = LrtSelfEvolution.evolve(agentId, round, ctxHint, skillName, userId, permArr)
                        let response = HashMap<String, JsonValue>()
                        response["errno"] = JsonValue.Number(0.0)
                        response["errmsg"] = JsonValue.String("ok")
                        response["evolution"] = result
                        return JsonValue.from(response)
                }
        }
    }

    // ── 自定义路由：lrt-deliver（spec 5.6.1 规则 5 / Ch6.3 产物交付确认）──
    // body: { task_id, action } where action = "confirm" | "abandon"
    //   confirm → 用户确认交付，置 status=2（completed）
    //   abandon → 用户放弃任务，置 status=4（cancelled）
    // 前置：任务须处于 awaiting_review=true 状态（由 LrtExecutor 在 outcome=completed 时设置）

    private static func handleLrtDeliver(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleLrtDeliver entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let taskId = LrtHandlers.extractStringFromMap(bodyMap, "task_id")
                        let action = LrtHandlers.extractStringFromMap(bodyMap, "action")
                        if (taskId.isEmpty()) {
                            return LrtHandlers.errResult(40002, "task_id 不能为空")
                        }
                        if (action.isEmpty()) {
                            return LrtHandlers.errResult(40002, "action 不能为空")
                        }
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        if (action == "confirm") {
                            let result = LrtPersistService.confirmDelivery(taskId, userId, permArr)
                            let reviewPatch = HashMap<String, JsonValue>()
                            reviewPatch["awaiting_review"] = JsonValue.Boolean(false)
                            reviewPatch["delivered_at"] = JsonValue.String("$raw:CURRENT_TIMESTAMP")
                            LrtPersistService.patchTaskPayload(taskId, reviewPatch, userId, permArr)
                            let response = HashMap<String, JsonValue>()
                            response["errno"] = JsonValue.Number(0.0)
                            response["errmsg"] = JsonValue.String("ok")
                            response["task_id"] = JsonValue.String(taskId)
                            response["action"] = JsonValue.String("confirmed")
                            response["result"] = result
                            return JsonValue.from(response)
                        } else if (action == "abandon") {
                            let result = LrtPersistService.abandonTask(taskId, userId, permArr)
                            let reviewPatch = HashMap<String, JsonValue>()
                            reviewPatch["awaiting_review"] = JsonValue.Boolean(false)
                            LrtPersistService.patchTaskPayload(taskId, reviewPatch, userId, permArr)
                            let response = HashMap<String, JsonValue>()
                            response["errno"] = JsonValue.Number(0.0)
                            response["errmsg"] = JsonValue.String("ok")
                            response["task_id"] = JsonValue.String(taskId)
                            response["action"] = JsonValue.String("abandoned")
                            response["result"] = result
                            return JsonValue.from(response)
                        } else {
                            return LrtHandlers.errResult(40002, "action 须为 confirm 或 abandon")
                        }
                }
        }
    }

    // ── 自定义路由：lrt-review（spec 5.6.1 规则 4 / Ch6.3 迭代改进闭环）──
    // body: { task_id, action, feedback?, goal? } where action = "improve" | "abandon"
    //   improve → 用户要求改进，触发 LrtPlanner.replan(reason=review_feedback) 调整规划
    //   abandon → 用户放弃任务，置 status=4
    // feedback 作为 addedConstraints 传入 replan（逗号分隔的改进要求）

    private static func handleLrtReview(fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {
        eprintln("[lrt] handleLrtReview entered")
        let ctxOpt = LrtHandlers.ctx
        match (ctxOpt) {
            case None => return LrtHandlers.errResult(1, "plugin context not initialized")
            case Some(ctx) =>
                let body = LrtHandlers.extractBody(fields)
                match (body) {
                    case None => return LrtHandlers.errResult(40001, "提交数据格式错误")
                    case Some(bodyMap) =>
                        let taskId = LrtHandlers.extractStringFromMap(bodyMap, "task_id")
                        let action = LrtHandlers.extractStringFromMap(bodyMap, "action")
                        if (taskId.isEmpty()) {
                            return LrtHandlers.errResult(40002, "task_id 不能为空")
                        }
                        if (action.isEmpty()) {
                            return LrtHandlers.errResult(40002, "action 不能为空")
                        }
                        let userId = LrtHandlers.extractString(fields, "userId")
                        let permArr = LrtHandlers.extractPermissions(fields)
                        if (action == "improve") {
                            let feedback = LrtHandlers.extractStringFromMap(bodyMap, "feedback")
                            let newGoal = LrtHandlers.extractStringFromMap(bodyMap, "goal")
                            let reviewPatch = HashMap<String, JsonValue>()
                            reviewPatch["awaiting_review"] = JsonValue.Boolean(false)
                            reviewPatch["review_feedback"] = JsonValue.String(feedback)
                            LrtPersistService.patchTaskPayload(taskId, reviewPatch, userId, permArr)
                            let replanResult = LrtPlanner.replan(
                                taskId, "review_feedback", newGoal, feedback, userId, permArr
                            )
                            let response = HashMap<String, JsonValue>()
                            response["errno"] = JsonValue.Number(0.0)
                            response["errmsg"] = JsonValue.String("ok")
                            response["task_id"] = JsonValue.String(taskId)
                            response["action"] = JsonValue.String("improve")
                            response["replan"] = replanResult
                            return JsonValue.from(response)
                        } else if (action == "abandon") {
                            let result = LrtPersistService.abandonTask(taskId, userId, permArr)
                            let reviewPatch = HashMap<String, JsonValue>()
                            reviewPatch["awaiting_review"] = JsonValue.Boolean(false)
                            LrtPersistService.patchTaskPayload(taskId, reviewPatch, userId, permArr)
                            let response = HashMap<String, JsonValue>()
                            response["errno"] = JsonValue.Number(0.0)
                            response["errmsg"] = JsonValue.String("ok")
                            response["task_id"] = JsonValue.String(taskId)
                            response["action"] = JsonValue.String("abandoned")
                            response["result"] = result
                            return JsonValue.from(response)
                        } else {
                            return LrtHandlers.errResult(40002, "action 须为 improve 或 abandon")
                        }
                }
        }
    }

    // ── 内部辅助方法 ────────────────────────────────────────────────

    /// 获取表的可写字段白名单
    private static func getWritableColumns(table: String): Array<String> {
        if (table == "long_running_task_artifact") {
            return ["task_id", "artifact_path", "artifact_type", "verification_status", "verification_result", "creator", "deleted_at"]
        }
        if (table == "long_running_task_evolution") {
            return ["agent_id", "round", "root_cause", "optimization_plan", "anti_regression", "skill_md_updates", "creator", "deleted_at"]
        }
        return Array<String>(0, { _ => "" })
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
            eprintln("[lrt] buildWhereFromFilter: JSON parse error: ${e.message}")
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

    /// 从 host.db 的 insert 返回（{ "rows": [{ "id": ... }] }）提取新记录 id
    private static func extractCreatedId(created: JsonValue): String {
        match (created) {
            case JsonValue.Map(m) =>
                match (m.get("rows")) {
                    case Some(JsonValue.Array(rows)) =>
                        if (rows.size > 0) {
                            match (rows[0]) {
                                case JsonValue.Map(r) =>
                                    match (r.get("id")) {
                                        case Some(JsonValue.String(s)) => return s
                                        case _ => ()
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return ""
    }

    /// 从 agent_tasks 记录抽取 payload.goal（jsonb 可能以 Map 或 String 形式返回）
    private static func extractGoalFromTask(task: JsonValue): String {
        match (task) {
            case JsonValue.Map(m) =>
                match (m.get("payload")) {
                    case Some(JsonValue.Map(pm)) =>
                        match (pm.get("goal")) {
                            case Some(JsonValue.String(s)) => return s
                            case _ => ()
                        }
                    case Some(JsonValue.String(ps)) =>
                        try {
                            let parsed = JsonValue.parse(ps)
                            match (parsed) {
                                case JsonValue.Map(pm) =>
                                    match (pm.get("goal")) {
                                        case Some(JsonValue.String(s)) => return s
                                        case _ => ()
                                    }
                                case _ => ()
                            }
                        } catch (e: Exception) {
                            eprintln("[lrt] extractGoalFromTask: payload 解析失败: ${e.message}")
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return ""
    }

    /// 从 agent_tasks 记录顶层抽取字符串字段
    private static func extractStringFromTask(task: JsonValue, key: String): String {
        match (task) {
            case JsonValue.Map(m) =>
                match (m.get(key)) {
                    case Some(JsonValue.String(s)) => return s
                    case _ => ()
                }
            case _ => ()
        }
        return ""
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

public func LrtHelpers_parseIdList(idsStr: String): ArrayList<String> {
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

public func LrtHelpers_joinQuoted(idList: ArrayList<String>): String {
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
