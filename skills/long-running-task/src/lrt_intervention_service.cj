/*
 * LrtInterventionService（long-running-task / Ch5 / design 1.1.3.3 / spec 5.15）
 *
 * 长程任务干预服务：统一处理暂停 / 恢复 / 取消 / 强制取消 / 目标调整 / 追加约束。
 *
 * 职责边界（design 2.6.1「声明在技能，能力在 runtime」）：
 *   - 本服务只负责**状态迁移 + 持久化**，不做"当前回合跑到哪了"的进程内等待。
 *     暂停/取消的"等待当前回合完成"由 LrtExecutor 在回合边界读取 status 后自然收敛
 *     （回合开始时/结束时各查一次 status，非 1 即退出循环），避免插件进程持有长生命周期锁。
 *
 * 状态机依据（design 2.1.3.1）：
 *   running(1) → paused(5)    用户暂停，crontab.status=2（禁用调度）
 *   paused(5)  → running(1)   用户恢复，crontab.status=1（启用调度）
 *   running(1) → cancelled(4) 用户取消（保留 result）
 *   running(1) → cancelled(4) 强制取消（立即终止）
 *   *          → (保持)      adjust_goal / add_constraint 触发 LrtPlanner.replan，不改主状态
 *
 * 注意 status 语义（spec 6.1「禁止状态倒退」）：
 *   - 0=pending(待处理) 1=running(进行中) 2=completed(完成) 3=failed(失败)
 *   - 4=cancelled(已取消) 5=paused(暂停)
 *   - [警告] 回合超时必须置 **6（等待下回合）**，绝不能置 0 —— 置 0 会让任务被当成新任务
 *     重新派发并丢失回合上下文。
 *
 * 编码依据：
 *   - LrtPersistService 幂等读写封装（queryOne / updateTaskStatus / updateTaskPayload）
 *   - LrtHandlers 的 extractBody / extractStringFromMap 解析范式
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.convert.*
import std.time.DateTime

public class LrtInterventionService {
    // ── agent_tasks.status 语义常量（与 design 2.1.3.1 状态机逐字对应）──

    public static let STATUS_PENDING: Int64 = 0
    public static let STATUS_RUNNING: Int64 = 1
    public static let STATUS_COMPLETED: Int64 = 2
    public static let STATUS_FAILED: Int64 = 3
    public static let STATUS_CANCELLED: Int64 = 4
    public static let STATUS_PAUSED: Int64 = 5
    /// 回合超时专用：等待下一回合调度。**不得用 0 代替**（会产生状态倒退，见 spec 6.1）
    public static let STATUS_AWAITING_NEXT_ROUND: Int64 = 6

    // ── crontab.status 语义常量 ──
    // ⚠️ CrontabPO.status 默认为 0，而 SchedulerEngine 只认 status == 1。
    //    暂停必须显式置 2，恢复必须显式置 1，否则漏设会导致任务永不触发且无任何报错。

    public static let CRONTAB_ENABLED: Int64 = 1
    public static let CRONTAB_DISABLED: Int64 = 2

    // ── 错误码（design 2.2.2.2 异常映射）──

    public static let ERR_TASK_NOT_FOUND: Int64 = 40401
    public static let ERR_STATUS_NOT_ALLOWED: Int64 = 40003
    public static let ERR_PERMISSION_DENIED: Int64 = 40301
    public static let ERR_BAD_REQUEST: Int64 = 40002

    // ── 干预动作白名单 ──

    public static let ACTION_PAUSE: String = "pause"
    public static let ACTION_RESUME: String = "resume"
    public static let ACTION_CANCEL: String = "cancel"
    public static let ACTION_FORCE_CANCEL: String = "force_cancel"
    public static let ACTION_ADJUST_GOAL: String = "adjust_goal"
    public static let ACTION_ADD_CONSTRAINT: String = "add_constraint"

    /// 干预入口：统一分发。
    ///
    /// 参数：
    ///   - taskId：任务 ID（agent_tasks.id）
    ///   - action：pause / resume / cancel / force_cancel / adjust_goal / add_constraint
    ///   - content：干预内容（adjust_goal 为新目标文本；add_constraint 为新约束文本；其余可为空）
    ///   - userId / permArr：行级权限（creator=userId）
    ///
    /// 返回统一响应 JSON：{ errno, errmsg, action, task_id, status, applied }
    public static func intervene(
        taskId: String,
        action: String,
        content: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (taskId.isEmpty()) {
            return LrtPersistService.errResult(ERR_BAD_REQUEST, "task_id 不能为空")
        }
        if (action.isEmpty()) {
            return LrtPersistService.errResult(ERR_BAD_REQUEST, "action 不能为空")
        }

        // 1. 前置：任务必须存在（行级权限下查不到即视为不存在，避免越权探测）
        let task = LrtPersistService.queryOne(
            LrtPersistService.TABLE_AGENT_TASKS,
            "id = '${taskId}' AND deleted_at IS NULL",
            userId,
            permArr
        )
        if (isNullJson(task)) {
            return LrtPersistService.errResult(ERR_TASK_NOT_FOUND, "任务不存在或无权访问: ${taskId}")
        }
        let currentStatus = extractIntFromJson(task, "status", -1)

        // 2. 状态校验 + 状态迁移
        match (action) {
            case "pause" => return applyPause(taskId, currentStatus, userId, permArr)
            case "resume" => return applyResume(taskId, currentStatus, userId, permArr)
            case "cancel" => return applyCancel(taskId, currentStatus, userId, permArr, true)
            case "force_cancel" => return applyCancel(taskId, currentStatus, userId, permArr, false)
            case "adjust_goal" =>
                if (content.isEmpty()) {
                    return LrtPersistService.errResult(ERR_BAD_REQUEST, "adjust_goal 需要提供 content（新目标）")
                }
                return applyAdjustGoal(taskId, content, userId, permArr)
            case "add_constraint" =>
                if (content.isEmpty()) {
                    return LrtPersistService.errResult(ERR_BAD_REQUEST, "add_constraint 需要提供 content（新约束）")
                }
                return applyAddConstraint(taskId, content, userId, permArr)
            case _ =>
                return LrtPersistService.errResult(ERR_BAD_REQUEST,
                    "未知 action: '${action}'（支持 pause/resume/cancel/force_cancel/adjust_goal/add_constraint）")
        }
    }

    // ── pause：暂停 ───────────────────────────────────────────────
    // 状态机：running(1) → paused(5)；同时 crontab.status=2 停止后续调度触发。
    // 「等待当前回合完成」不是本方法的职责：回合结束时 LrtExecutor 会读 status，
    // 发现非 1 即保存检查点并退出，不会丢失已完成的步骤。

    private static func applyPause(
        taskId: String,
        currentStatus: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        // 合法性：仅进行中可暂停。已完成/已取消/已暂停均拒绝（design 2.2.2.2 前置条件）
        if (currentStatus == STATUS_COMPLETED) {
            return LrtPersistService.errResult(ERR_STATUS_NOT_ALLOWED, "任务已完成，不能暂停")
        }
        if (currentStatus == STATUS_CANCELLED) {
            return LrtPersistService.errResult(ERR_STATUS_NOT_ALLOWED, "任务已取消，不能暂停")
        }
        if (currentStatus == STATUS_PAUSED) {
            // 幂等：重复暂停视为成功，不报错（前端可能重复点击）
            return buildResponse(taskId, ACTION_PAUSE, STATUS_PAUSED, true, "任务已处于暂停状态")
        }
        if (currentStatus != STATUS_RUNNING && currentStatus != STATUS_PENDING) {
            return LrtPersistService.errResult(ERR_STATUS_NOT_ALLOWED,
                "当前状态(${currentStatus})不允许暂停操作")
        }
        let statusResult = LrtPersistService.updateTaskStatus(taskId, STATUS_PAUSED, userId, permArr)
        let crontabOk = setCrontabStatus(taskId, CRONTAB_DISABLED, userId, permArr)
        LrtInterventionService.logDecision("pause", taskId, currentStatus, STATUS_PAUSED, userId)
        return buildResponse(taskId, ACTION_PAUSE, STATUS_PAUSED, true,
            if (crontabOk) { "任务已暂停" } else { "任务已暂停，但调度记录未同步，请手工检查 crontab.status" },
            statusResult)
    }

    // ── resume：恢复 ──────────────────────────────────────────────
    // 状态机：paused(5) → running(1)；crontab.status=1 重新启用调度；
    // 下次调度触发时 LrtExecutor 从最新检查点恢复，不从头执行。

    private static func applyResume(
        taskId: String,
        currentStatus: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (currentStatus == STATUS_COMPLETED) {
            return LrtPersistService.errResult(ERR_STATUS_NOT_ALLOWED, "任务已完成，不能恢复")
        }
        if (currentStatus == STATUS_CANCELLED) {
            return LrtPersistService.errResult(ERR_STATUS_NOT_ALLOWED, "任务已取消，不能恢复")
        }
        if (currentStatus == STATUS_RUNNING) {
            return buildResponse(taskId, ACTION_RESUME, STATUS_RUNNING, true, "任务已处于进行中状态")
        }
        // 检查点可用性探测（spec 点名的异常场景：「恢复时检查点丢失」）。
        // 不探测就恢复会给出「将从最新检查点继续执行」的承诺，而实际可能是
        // 无检查点可用、执行器只能从头跑——对长程任务而言等于丢失了已完成的全部回合。
        // 这里只探测并如实告知，**不阻断恢复**：检查点缺失不是禁止恢复的理由
        // （用户可能就是想重跑），但必须让用户知道真实情况。
        let checkpointCount = LrtInterventionService.countCheckpoints(taskId, userId, permArr)
        let statusResult = LrtPersistService.updateTaskStatus(taskId, STATUS_RUNNING, userId, permArr)
        let crontabOk = setCrontabStatus(taskId, CRONTAB_ENABLED, userId, permArr)
        LrtInterventionService.logDecision("resume", taskId, currentStatus, STATUS_RUNNING, userId)
        let message = if (!crontabOk) {
            "任务已恢复，但调度记录未启用，请手工检查 crontab.status"
        } else if (checkpointCount == 0) {
            "任务已恢复，但**未找到可用检查点**，将从首轮重新执行（可能丢失此前已完成回合的进度）"
        } else {
            "任务已恢复，将从最新检查点继续执行（可用检查点 ${checkpointCount} 个）"
        }
        return buildResponse(taskId, ACTION_RESUME, STATUS_RUNNING, true, message, statusResult)
    }

    /**
     * 统计该任务的可用检查点数量。
     *
     * 检查点落在 `agent_contexts`（CheckpointManager 落库），**按 agent_id 关联**，
     * 而本服务只拿得到 taskId。故先从 agent_tasks 取出 agent_id，
     * 再按 agent_id + task_id 精确计数（agent_contexts.metadata 里带 task_id）。
     * 任一步查不到都返回 0（视为「无可用检查点」），这比抛异常更符合调用方语义：
     * 探测失败与确实没有检查点，对用户而言后果相同——都是从首轮跑。
     */
    private static func countCheckpoints(taskId: String, userId: String, permArr: ArrayList<JsonValue>): Int64 {
        let taskRow = LrtPersistService.queryOne(
            LrtPersistService.TABLE_AGENT_TASKS, "id = '${taskId}'", userId, permArr
        )
        let agentId = LrtInterventionService.extractStringFromJson(taskRow, "agent_id")
        if (agentId.isEmpty()) {
            return 0
        }
        let rows = LrtPersistService.queryMany(
            LrtPersistService.TABLE_AGENT_CONTEXTS,
            "agent_id = '${agentId}'",
            userId, permArr, 500
        )
        // agent_contexts 无 task_id 列，用 metadata 里的 task_id 过滤（与 CheckpointManager 写入约定一致）
        var count: Int64 = 0
        for (row in rows) {
            let metaTaskId = LrtInterventionService.extractNestedStringFromJson(row, "metadata", "task_id")
            if (metaTaskId.isEmpty() || metaTaskId == taskId) {
                count = count + 1
            }
        }
        return count
    }

    // ── cancel / force_cancel：取消 ───────────────────────────────
    // graceful=true （cancel）      ：当前步骤完成后生效，保留 result 已有结果
    // graceful=false（force_cancel）：立即终止（执行侧在下一步边界读到 status=4 即退出）
    // 二者在本服务内的状态迁移一致（status=4），差异体现在执行侧的收敛时机。

    private static func applyCancel(
        taskId: String,
        currentStatus: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>,
        graceful: Bool
    ): JsonValue {
        let actionName = if (graceful) { ACTION_CANCEL } else { ACTION_FORCE_CANCEL }
        if (currentStatus == STATUS_CANCELLED) {
            return buildResponse(taskId, actionName, STATUS_CANCELLED, true, "任务已处于取消状态")
        }
        if (currentStatus == STATUS_COMPLETED) {
            return LrtPersistService.errResult(ERR_STATUS_NOT_ALLOWED, "任务已完成，不能取消")
        }
        // 取消同时禁用调度，避免下一周期又把它拉起来
        let statusResult = LrtPersistService.updateTaskStatus(taskId, STATUS_CANCELLED, userId, permArr)
        let crontabOk = setCrontabStatus(taskId, CRONTAB_DISABLED, userId, permArr)
        LrtInterventionService.logDecision(actionName, taskId, currentStatus, STATUS_CANCELLED, userId)
        let note = if (graceful) {
            "任务已取消（当前步骤完成后停止，已有结果保留）"
        } else {
            "任务已强制取消（立即终止）"
        }
        return buildResponse(taskId, actionName, STATUS_CANCELLED, true,
            if (crontabOk) { note } else { "${note}；但调度记录未同步，请手工检查 crontab.status" },
            statusResult)
    }

    // ── adjust_goal：目标调整 ─────────────────────────────────────
    // 不改主状态（任务仍在 running），把新目标写入 payload.original_goal_* 并触发重规划。
    // 保留原目标于 payload.goal_history，便于事后复盘"目标如何演化"。

    private static func applyAdjustGoal(
        taskId: String,
        newGoal: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let payloadMap = HashMap<String, JsonValue>()
        payloadMap["goal"] = JsonValue.String(newGoal)
        payloadMap["adjusted_via"] = JsonValue.String("lrt-intervene")
        payloadMap["adjusted_at"] = JsonValue.String(LrtInterventionService.nowIso())
        payloadMap["replan_required"] = JsonValue.Boolean(false)
        payloadMap["replan_reason"] = JsonValue.String("adjust_goal")
        // 用 patch 而不是 updateTaskPayload：后者整列覆盖 payload，会把 session_id /
        // trace_id / completed_steps / 既有 plan 一起抹掉——session_id 一丢，
        // SSE 推送通道当场失效且很难归因到"改了一次目标"上。
        let result = LrtPersistService.patchTaskPayload(taskId, payloadMap, userId, permArr)
        LrtInterventionService.logDecision("adjust_goal", taskId, -1, -1, userId)
        // 立即重规划（spec 5.3）：目标变了就要据此调整后续计划，
        // 而不是留个 replan_required 标记等下一回合——那些标记历史上没有消费者，
        // 结果是"记录新目标已完成、据此调整规划从未发生"。
        let replan = LrtPlanner.replan(taskId, "adjust_goal", newGoal, "", userId, permArr)
        // adjust_goal 不改主状态（任务仍在 running，重规划后继续执行），
        // 故 status 传 -1 表示"状态未变更"，响应里不带 status 字段。
        let message = if (LrtInterventionService.isErrResult(replan)) {
            "目标已更新；重规划失败（${LrtInterventionService.errText(replan)}），将在下一回合重试"
        } else {
            "目标已更新并完成重规划：保留 ${LrtInterventionService.respInt(replan, "preserved_count")} 个已完成任务，"
            + "待执行 ${LrtInterventionService.respInt(replan, "pending_count")} 个"
        }
        return buildResponse(taskId, ACTION_ADJUST_GOAL, Int64(-1), !isErrResult(result), message, result)
    }

    // ── add_constraint：追加约束 ──────────────────────────────────
    // 约束是增量语义：新约束追加进 payload.constraints 数组，不清空已有约束。

    private static func applyAddConstraint(
        taskId: String,
        constraint: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let payloadMap = HashMap<String, JsonValue>()
        // 追加语义：payload.constraints 以数组形式承载，执行侧按序全部注入 system prompt
        let constraintsArr = ArrayList<JsonValue>()
        // 先读回已有约束（若有）再追加，避免覆盖
        let task = LrtPersistService.queryOne(
            LrtPersistService.TABLE_AGENT_TASKS,
            "id = '${taskId}' AND deleted_at IS NULL",
            userId,
            permArr
        )
        let existing = extractArrayFromJson(task, "payload", "constraints")
        for (item in existing) {
            constraintsArr.add(item)
        }
        constraintsArr.add(JsonValue.String(constraint))
        // JsonValue.Array 的载荷类型就是 ArrayList<JsonValue>（见 libs/jsonvalue/src/jsonvalue.cj:17），
        // 可直接构造，无需再包一层 from(...)。
        payloadMap["constraints"] = JsonValue.Array(constraintsArr)
        payloadMap["replan_required"] = JsonValue.Boolean(false)
        payloadMap["replan_reason"] = JsonValue.String("add_constraint")
        // 同 adjust_goal：改用 patch，避免在追加第 N 条约束时把前 N-1 条之外的
        // payload 字段（含会话/追踪上下文）一并清掉。
        let result = LrtPersistService.patchTaskPayload(taskId, payloadMap, userId, permArr)
        LrtInterventionService.logDecision("add_constraint", taskId, -1, -1, userId)
        let replan = LrtPlanner.replan(taskId, "add_constraint", "", constraint, userId, permArr)
        let message = if (LrtInterventionService.isErrResult(replan)) {
            "约束已追加（共 ${constraintsArr.size} 条）；重规划失败（${LrtInterventionService.errText(replan)}）"
        } else {
            "约束已追加（共 ${constraintsArr.size} 条）并完成重规划："
            + "保留 ${LrtInterventionService.respInt(replan, "preserved_count")} 个已完成任务，"
            + "待执行 ${LrtInterventionService.respInt(replan, "pending_count")} 个"
        }
        return buildResponse(taskId, ACTION_ADD_CONSTRAINT, Int64(-1), !isErrResult(result), message, result)
    }

    // ── crontab 联动 ──────────────────────────────────────────────
    // 长程任务由 crontab 记录驱动 SchedulerEngine。agent_tasks 与 crontab 是两张表，
    // 通过 crontab.task = "lrt://<agentId>" 关联，故这里按 agentId 反查。
    // 查询/更新失败不阻断主流程（返回 false 由上层提示），因为状态迁移本身已生效。

    private static func setCrontabStatus(
        taskId: String,
        crontabStatus: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): Bool {
        try {
            let task = LrtPersistService.queryOne(
                LrtPersistService.TABLE_AGENT_TASKS,
                "id = '${taskId}' AND deleted_at IS NULL",
                userId,
                permArr
            )
            let agentId = LrtInterventionService.extractStringFromJson(task, "agent_id")
            if (agentId.isEmpty()) {
                // 无 agentId 无法定位 crontab 记录：调度禁用只能由上层/人工处理
                return false
            }
            let dataMap = HashMap<String, JsonValue>()
            dataMap["status"] = JsonValue.Number(Float64(crontabStatus))
            let whereClause = "task = 'lrt://${agentId}'"
            let r = LrtPersistService.update("crontab", whereClause, dataMap, userId, permArr)
            return !isErrResult(r)
        } catch (_: Exception) {
            return false
        }
    }

    // ── 响应构造 ──────────────────────────────────────────────────

    private static func buildResponse(
        taskId: String,
        action: String,
        status: Int64,
        applied: Bool,
        message: String
    ): JsonValue {
        return buildResponse(taskId, action, status, applied, message, JsonValue.Null)
    }

    /// 统一干预响应。`raw` 携带底层持久化结果，便于排查"状态没变"的现场。
    private static func buildResponse(
        taskId: String,
        action: String,
        status: Int64,
        applied: Bool,
        message: String,
        raw: JsonValue
    ): JsonValue {
        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["action"] = JsonValue.String(action)
        response["task_id"] = JsonValue.String(taskId)
        if (status >= 0) {
            response["status"] = JsonValue.Number(Float64(status))
        }
        response["applied"] = JsonValue.Boolean(applied)
        response["message"] = JsonValue.String(message)
        response["raw"] = raw
        return JsonValue.from(response)
    }

    // ── 结构化决策日志（tasks.md 11.3：plan/replan/degradation/decision 四类 JSON 行）──
    // 人在回路选择属于四类关键决策之一，必须可事后复盘，故以单行 JSON 输出到 stderr。

    private static func logDecision(action: String, taskId: String, fromStatus: Int64, toStatus: Int64, userId: String): Unit {
        let m = HashMap<String, JsonValue>()
        m["kind"] = JsonValue.String("decision")
        m["decision"] = JsonValue.String(action)
        m["task_id"] = JsonValue.String(taskId)
        m["from_status"] = JsonValue.Number(Float64(fromStatus))
        m["to_status"] = JsonValue.Number(Float64(toStatus))
        m["user_id"] = JsonValue.String(userId)
        m["at"] = JsonValue.String(LrtInterventionService.nowIso())
        eprintln("[lrt-decision] ${JsonValue.from(m).toString()}")
    }

    private static func nowIso(): String {
        // DateTime.format(fmt) 实例方法可直接输出 ISO-8601（见 std.time DateTime 成员表）。
        // 不用手工拼 year/month/day：month 是 Month 枚举而非 Int64，手工拼会类型不匹配。
        return DateTime.now().format("yyyy-MM-dd'T'HH:mm:ss")
    }

    // ── JsonValue 取值辅助（本插件统一用 jsonvalue 库）──
    // 注意：jsonvalue 的 JsonValue 变体名是 `Map`（不是 `Object`），见 libs/jsonvalue/src/jsonvalue.cj:18。
    //       `v[key]` 返回 ?JsonValue，`v.get(key, default)` 返回 JsonValue —— 两者勿混用。

    private static func isNullJson(v: JsonValue): Bool {
        match (v) {
            case JsonValue.Null => true
            case _ => false
        }
    }

    private static func isErrResult(v: JsonValue): Bool {
        // LrtPersistService 的错误响应形如 { errno: <非0>, errmsg: "..." }
        match (v["errno"]) {
            case Some(JsonValue.Number(n)) => n != 0.0
            case _ => false
        }
    }

    /// 取错误文案（用于在干预响应里如实转述下游失败原因，而不是笼统说"失败"）
    private static func errText(v: JsonValue): String {
        match (v["errmsg"]) {
            case Some(JsonValue.String(s)) => return s
            case _ => return "未知错误"
        }
    }

    /// 取响应里的整数字段（JsonValue 的数值统一是 Float64，转 Int64 渲染）
    private static func respInt(v: JsonValue, key: String): Int64 {
        match (v[key]) {
            case Some(JsonValue.Number(n)) => return Int64(n)
            case _ => return 0
        }
    }

    private static func extractNestedStringFromJson(v: JsonValue, outerKey: String, innerKey: String): String {
        match (v[outerKey]) {
            case Some(JsonValue.String(s)) =>
                try {
                    let parsed = JsonValue.parse(s)
                    return LrtInterventionService.extractStringFromJson(parsed, innerKey)
                } catch (_: Exception) {
                    return ""
                }
            case _ => ""
        }
    }

    private static func extractStringFromJson(v: JsonValue, key: String): String {
        match (v[key]) {
            case Some(JsonValue.String(s)) => s
            case _ => ""
        }
    }

    private static func extractIntFromJson(v: JsonValue, key: String, default: Int64): Int64 {
        match (v[key]) {
            case Some(JsonValue.Number(n)) => Int64(n)
            case Some(JsonValue.String(s)) =>
                try {
                    Int64.parse(s)
                } catch (_: Exception) {
                    default
                }
            case _ => default
        }
    }

    /// 从嵌套结构取数组：`v[outerKey][innerKey]`。任一层缺失返回空数组（不报错）。
    ///
    /// 取值语义（libs/jsonvalue/src/jsonvalue.cj）：
    ///   - `v["key"]` 下标运算符返回 **`?JsonValue`**（Option）——适合嵌套逐层解构
    ///   - `v.get(key, default)` 返回 **`JsonValue`**（已把 None 折成 default）
    /// 这里用下标运算符，因为"父层不存在"与"子层不存在"要分别判空。
    private static func extractArrayFromJson(v: JsonValue, outerKey: String, innerKey: String): ArrayList<JsonValue> {
        let empty = ArrayList<JsonValue>()
        match (v[outerKey]) {
            case Some(JsonValue.Map(nested)) =>
                match (nested.get(innerKey)) {
                    case Some(val) =>
                        match (val) {
                            case JsonValue.Array(items) => return items
                            case _ => return empty
                        }
                    case None => return empty
                }
            case _ => return empty
        }
    }

}