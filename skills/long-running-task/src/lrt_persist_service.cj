/*
 * 长程任务 2 表 + agent_tasks 幂等读写封装（long-running-task）
 * 经 ctx.invoke("host.db", ...) 访问宿主数据库
 * 幂等策略：先查后写（命中 UPDATE / 未命中 INSERT）
 *
 * 编码依据：skills/due_diligence_agent/src/persist_service.cj（PersistService 模式）
 *   - execute 参数：operation/subOp/where/data/userId/permissions
 *   - query 参数：operation/table/where/orderBy/limit/offset/userId/permissions
 *   - "$raw:" 前缀让 host.db 生成原始 SQL 函数（不加引号）
 */
package skill_long_running_task

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*
import std.collection.{HashMap, ArrayList}

public class LrtPersistService {
    private static var ctx: ?PluginContext = None

    /// 表名常量
    public static let TABLE_ARTIFACT: String = "long_running_task_artifact"
    public static let TABLE_EVOLUTION: String = "long_running_task_evolution"
    public static let TABLE_AGENT_TASKS: String = "agent_tasks"
    /// 检查点存放表（由宿主 CheckpointManager 落库，本插件只读）
    public static let TABLE_AGENT_CONTEXTS: String = "agent_contexts"
    /// 评估指标表（spec 6.4：验核结果上报，供自优化消费）
    public static let TABLE_AGENT_LOOP_METRICS: String = "agent_loop_metrics"
    /// 调优配置表（spec 6.5：自进化环节3 增量优化落配置，供宿主调优服务消费）
    public static let TABLE_AGENT_LOOP_TUNING_CONFIGS: String = "agent_loop_tuning_configs"

    /// 初始化插件上下文（仓颉中 init 是构造器关键字，不能作普通函数名，故命名为 initialize）
    public static func initialize(ctx: PluginContext): Unit {
        LrtPersistService.ctx = ctx
    }

    /// 对外暴露当前插件上下文（降级链等需要直接调用 host.* 的组件共用）。
    /// `ctx` 本身保持私有：调用方必须显式处理"未初始化"这一路，不能拿到裸变量后到处用。
    public static func currentCtx(): ?PluginContext {
        return LrtPersistService.ctx
    }

    // ── 通用查询 ────────────────────────────────────────────────────

    /// 按条件查询单条记录，返回 JsonValue（记录对象）或 JsonValue.Null
    public static func queryOne(
        table: String,
        whereClause: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let ctxOpt = LrtPersistService.ctx
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
        let ctxOpt = LrtPersistService.ctx
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
        let ctxOpt = LrtPersistService.ctx
        match (ctxOpt) {
            case None => return LrtPersistService.errResult(1, "plugin context not initialized")
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
                eprintln("[lrt-persist] insert ${table} result: ${execResult.stringify()}")
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
        let ctxOpt = LrtPersistService.ctx
        match (ctxOpt) {
            case None => return LrtPersistService.errResult(1, "plugin context not initialized")
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
                eprintln("[lrt-persist] update ${table} result: ${execResult.stringify()}")
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
        let ctxOpt = LrtPersistService.ctx
        match (ctxOpt) {
            case None => return LrtPersistService.errResult(1, "plugin context not initialized")
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
                eprintln("[lrt-persist] hardDelete ${table} result: ${execResult.stringify()}")
                return execResult
        }
    }

    // ── agent_tasks：创建根任务（lrt-plan 调用）────────────────────
    // payload 含原始目标；parent_task_id=NULL 表示根任务；status=0（待处理）

    public static func createRootTask(
        goal: String,
        payloadMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        if (payloadMap.size > 0) {
            dataMap["payload"] = JsonValue.from(payloadMap)
        } else {
            let goalMap = HashMap<String, JsonValue>()
            goalMap["goal"] = JsonValue.String(goal)
            dataMap["payload"] = JsonValue.from(goalMap)
        }
        dataMap["parent_task_id"] = JsonValue.Null
        dataMap["status"] = JsonValue.Number(0.0)
        dataMap["priority"] = JsonValue.Number(5.0)
        return LrtPersistService.insert(LrtPersistService.TABLE_AGENT_TASKS, dataMap, userId, permArr)
    }

    // ── agent_tasks：创建子任务（lrt-plan 任务树分解调用）────────────
    // parent_task_id 指向根任务；status=0（待处理）；payload 含 sub_goal 与顺序
    // 注：子任务一经写入即成为 agent_tasks 树的真实节点，执行器可据 parent_task_id
    // 构建任务树（§9.3 getTaskTree 已支持按 parent_task_id 递归）。

    public static func createChildTask(
        parentTaskId: String,
        subGoal: String,
        order: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        dataMap["parent_task_id"] = JsonValue.String(parentTaskId)
        dataMap["status"] = JsonValue.Number(0.0)
        dataMap["priority"] = JsonValue.Number(5.0)
        let payloadMap = HashMap<String, JsonValue>()
        payloadMap["sub_goal"] = JsonValue.String(subGoal)
        payloadMap["order"] = JsonValue.Number(Float64(order))
        dataMap["payload"] = JsonValue.from(payloadMap)
        return LrtPersistService.insert(LrtPersistService.TABLE_AGENT_TASKS, dataMap, userId, permArr)
    }

    // ── agent_tasks：更新任务状态（lrt-intervene / lrt-execute 调用）──

    public static func updateTaskStatus(
        taskId: String,
        status: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
        ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        dataMap["status"] = JsonValue.Number(Float64(status))
        let whereClause = "id = '${taskId}'"
        return LrtPersistService.update(LrtPersistService.TABLE_AGENT_TASKS, whereClause, dataMap, userId, permArr)
    }

    // ── agent_tasks：更新任务 payload（lrt-intervene adjust_goal 调用）──

    public static func updateTaskPayload(
        taskId: String,
        payloadMap: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        dataMap["payload"] = JsonValue.from(payloadMap)
        let whereClause = "id = '${taskId}'"
        return LrtPersistService.update(LrtPersistService.TABLE_AGENT_TASKS, whereClause, dataMap, userId, permArr)
    }

    // ── agent_tasks：进度字段增量写入（LrtExecutor 每步调用，Ch9.3）──

    /**
     * **增量**更新 payload 里的进度字段（读-改-写）
     *
     * 为什么不直接用 `updateTaskPayload`：那个方法把 `payload` 整列替换掉。
     * 执行器每步只想改 `completed_steps` / `current_step` 几个键，若整列覆盖，
     * 就必须在调用方手里攒出完整 payload（含 goal / plan / constraints），
     * 一旦漏了某个键就静默丢数据。
     *
     * 这里的做法是：先 `queryOne` 取出当前 payload，把 `patch` 里的键覆盖上去，
     * 再整列写回。代价是每步多一次 SELECT——但长程任务的步骤节拍是分钟级，
     * 这点开销换"不会误删 payload 字段"是划算的。
     *
     * 边界：payload 为空或解析失败时，以 `patch` 为基底重建（而不是报错），
     * 因为进度写入失败比"payload 缺几个历史字段"更影响可用性。
     */
    public static func patchTaskPayload(
        taskId: String,
        patch: HashMap<String, JsonValue>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let merged = HashMap<String, JsonValue>()
        // 1) 先装入既有 payload
        let current = LrtPersistService.queryOne(
            LrtPersistService.TABLE_AGENT_TASKS,
            "id = '${taskId}'",
            userId, permArr
        )
        match (current) {
            case JsonValue.Map(row) =>
                match (row.get("payload")) {
                    case Some(JsonValue.Map(existing)) =>
                        for (key in existing.keys()) {
                            match (existing.get(key)) {
                                case Some(v) => merged[key] = v
                                case None => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }
        // 2) 覆盖本次要改的键
        for (key in patch.keys()) {
            match (patch.get(key)) {
                case Some(v) => merged[key] = v
                case None => ()
            }
        }
        // 3) 整列写回
        LrtPersistService.updateTaskPayload(taskId, merged, userId, permArr)
    }

    // ── long_running_task_artifact：记录产物（lrt-verify / 每步产出调用）──

    public static func logArtifact(
        taskId: String,
        artifactPath: String,
        artifactType: String,
        verificationStatus: String,
        verificationResult: JsonValue,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        if (!taskId.isEmpty()) {
            dataMap["task_id"] = JsonValue.String(taskId)
        }
        dataMap["artifact_path"] = JsonValue.String(artifactPath)
        dataMap["artifact_type"] = JsonValue.String(artifactType)
        dataMap["verification_status"] = JsonValue.String(verificationStatus)
        dataMap["verification_result"] = verificationResult

        // 幂等（spec 5.13）：同一 task 下的同一产物会被反复验核——
        // 执行器每轮重扫未校验产物，重试/崩溃恢复也会重放。
        // 裸 insert 会让产物表按轮次成倍膨胀，且 countArtifacts 的统计口径失真
        // （同一产物被算成 N 个，progress 百分比随之虚高）。
        // 幂等键取 (task_id, artifact_path)：同一任务下的同一路径视为同一条记录。
        let whereClause = "task_id = '${LrtPersistService.escapeSqlLiteral(taskId)}'"
            + " AND artifact_path = '${LrtPersistService.escapeSqlLiteral(artifactPath)}'"
        match (LrtPersistService.queryOne(LrtPersistService.TABLE_ARTIFACT, whereClause, userId, permArr)) {
            case JsonValue.Map(_) =>
                // 已有记录 → 更新验核结论，保留原主键与创建时间
                return LrtPersistService.update(LrtPersistService.TABLE_ARTIFACT, whereClause, dataMap, userId, permArr)
            case _ =>
                return LrtPersistService.insert(LrtPersistService.TABLE_ARTIFACT, dataMap, userId, permArr)
        }
    }

    // ── long_running_task_evolution：记录自进化闭环（lrt-evolve 调用）──

    public static func logEvolution(
        agentId: String,
        round: Int64,
        rootCause: String,
        optimizationPlan: String,
        antiRegression: String,
        skillMdUpdates: JsonValue,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        if (!agentId.isEmpty()) {
            dataMap["agent_id"] = JsonValue.String(agentId)
        }
        dataMap["round"] = JsonValue.Number(Float64(round))
        dataMap["root_cause"] = JsonValue.String(rootCause)
        dataMap["optimization_plan"] = JsonValue.String(optimizationPlan)
        dataMap["anti_regression"] = JsonValue.String(antiRegression)
        dataMap["skill_md_updates"] = skillMdUpdates

        // 幂等（spec 5.13）：执行器的每轮失败都会触发一次 evolve，
        // 而「同一 agent 的同一轮」在重试/恢复后可能被重复调用。
        // 幂等键取 (agent_id, round)：同一 Agent 的同一轮次只应有一条进化记录，
        // 否则 evolution 表里同轮多条相互矛盾的根因会让复盘无法进行。
        let whereClause = "agent_id = '${LrtPersistService.escapeSqlLiteral(agentId)}'"
            + " AND round = ${round}"
        match (LrtPersistService.queryOne(LrtPersistService.TABLE_EVOLUTION, whereClause, userId, permArr)) {
            case JsonValue.Map(_) =>
                return LrtPersistService.update(LrtPersistService.TABLE_EVOLUTION, whereClause, dataMap, userId, permArr)
            case _ =>
                return LrtPersistService.insert(LrtPersistService.TABLE_EVOLUTION, dataMap, userId, permArr)
        }
    }

    /**
     * 转义 SQL 字面量里的单引号。
     *
     * 为何必须有：本插件的 where 子句是字符串拼接（沿用 host.db 的调用约定，无参数化接口）。
     * `artifact_path` 来自文件名/用户输入，含 `'` 时会把 SQL 拼坏——轻则查询报错，
     * 重则条件被截断成恒真（例如 path 为 `x' OR '1'='1`）。
     * PostgreSQL 约定用两个单引号转义单引号。
     */
    private static func escapeSqlLiteral(s: String): String {
        return s.replace("'", "''")
    }

    // ── agent_loop_metrics：验核指标上报（spec 5.6.1 规则 6 / Ch6.2）──
    //
    // spec 要求验核结果上报到 agent_loop_metrics，含成功率/Token消耗/耗时/工具调用次数/副作用数量。
    // 宿主侧 EvaluationExecutor 采集的是 Agent 整轮指标；插件进程拿不到宿主对象（L3 进程隔离），
    // 改为直接写同一张表——数据同源，只是写入方从宿主 EvaluationExecutor 换成插件。
    // total_tokens / tool_call_count / side_effect_count 在验核场景下无精确值（验核不调 LLM/工具），
    // 传 0 而非 null：下游聚合查询按 SUM/N 跑，null 会让整列聚合变 null，0 不会污染统计。

    public static func logMetrics(
        agentId: String,
        evaluationType: String,
        successRate: Float64,
        avgDurationMs: Int64,
        totalTokens: Int64,
        toolCallCount: Int64,
        sideEffectCount: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        if (!agentId.isEmpty()) {
            dataMap["agent_id"] = JsonValue.String(agentId)
        }
        dataMap["evaluation_type"] = JsonValue.String(if (evaluationType.isEmpty()) { "session" } else { evaluationType })
        dataMap["success_rate"] = JsonValue.Number(successRate)
        dataMap["avg_duration_ms"] = JsonValue.Number(Float64(avgDurationMs))
        dataMap["total_tokens"] = JsonValue.Number(Float64(totalTokens))
        dataMap["tool_call_count"] = JsonValue.Number(Float64(toolCallCount))
        dataMap["side_effect_count"] = JsonValue.Number(Float64(sideEffectCount))
        return LrtPersistService.insert(LrtPersistService.TABLE_AGENT_LOOP_METRICS, dataMap, userId, permArr)
    }

    // ── agent_tasks：交付确认 / 放弃（spec 5.6.1 规则 5 / Ch6.3）──

    /**
     * 用户确认交付：置 status=2（completed）。
     *
     * spec 5.6.1 规则 5 要求「用户确认交付后产物落地文件系统并经 sync 同步到数据库」。
     * 产物在验核时已确认存在于文件系统（LrtArtifactVerifier.verifyFileState 检查过），
     * sync 同步由宿主侧 SyncManager 负责（插件进程不可达），本方法只做状态迁移。
     */
    public static func confirmDelivery(
        taskId: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        return LrtPersistService.updateTaskStatus(taskId, 2, userId, permArr)
    }

    /// 用户放弃任务：置 status=4（cancelled）
    public static func abandonTask(
        taskId: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        return LrtPersistService.updateTaskStatus(taskId, 4, userId, permArr)
    }

    // ── agent_loop_tuning_configs：调优配置写入（spec 5.11 环节3 / spec 6.5）──
    //
    // 自进化环节3「增量优化」的落地动作：把 optimization_plan 解析为调优配置写入此表，
    // 宿主侧调优服务读取 is_enabled=true 的记录并应用。幂等键 (agent_id, strategy_type)：
    // 同一 Agent 的同一策略类型只保留一条有效记录，避免多条矛盾配置让调优服务无所适从。

    public static func logTuningConfig(
        agentId: String,
        strategyType: String,
        config: JsonValue,
        isEnabled: Bool,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let dataMap = HashMap<String, JsonValue>()
        if (!agentId.isEmpty()) {
            dataMap["agent_id"] = JsonValue.String(agentId)
        }
        dataMap["strategy_type"] = JsonValue.String(if (strategyType.isEmpty()) { "prompt_optimization" } else { strategyType })
        dataMap["config"] = config
        dataMap["is_enabled"] = JsonValue.Boolean(isEnabled)
        let whereClause = "agent_id = '${LrtPersistService.escapeSqlLiteral(agentId)}'"
            + " AND strategy_type = '${LrtPersistService.escapeSqlLiteral(strategyType)}'"
        match (LrtPersistService.queryOne(LrtPersistService.TABLE_AGENT_LOOP_TUNING_CONFIGS, whereClause, userId, permArr)) {
            case JsonValue.Map(_) =>
                return LrtPersistService.update(LrtPersistService.TABLE_AGENT_LOOP_TUNING_CONFIGS, whereClause, dataMap, userId, permArr)
            case _ =>
                return LrtPersistService.insert(LrtPersistService.TABLE_AGENT_LOOP_TUNING_CONFIGS, dataMap, userId, permArr)
        }
    }

    // ── 辅助方法 ────────────────────────────────────────────────────

    private static func extractStringFromMap(map: HashMap<String, JsonValue>, key: String): String {
        match (map.get(key)) {
            case Some(JsonValue.String(s)) => return s
            case _ => return ""
        }
    }

    public static func errResult(errno: Int64, errmsg: String): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["errno"] = JsonValue.Number(Float64(errno))
        m["errmsg"] = JsonValue.String(errmsg)
        return JsonValue.from(m)
    }
}
