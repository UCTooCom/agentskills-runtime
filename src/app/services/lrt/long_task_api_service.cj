/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */

/**
 * 长程任务用户 API 服务(Ch9.1)
 *
 * 承载 tasks.md §9.1 的 7 个用户 API 的业务逻辑。放在宿主侧而不是插件侧的理由：
 *
 * 1. **建任务 + 建调度是宿主职责**。`agent_tasks` 与 `crontab` 都是宿主表,
 *    调度引擎(`SchedulerEngine`)也在宿主进程内。让插件去写宿主表要走 `host.db`,
 *    而 `crontab.status=1` 这种"漏设就静默不触发"的高危字段,
 *    离调度引擎越近越不容易写错。
 * 2. **进度/检查点查询是纯宿主数据**。`agent_tasks.payload`、`agent_contexts`
 *    都在宿主库里,绕一圈到插件再回来没有收益。
 * 3. **规划/执行/干预/验核/演化仍在插件**。这五件事是真正的长程任务业务,
 *    宿主只做转发(经 `LrtPluginClient`),保持进程隔离的意义。
 *
 * 因此本服务的形态是：**宿主自有逻辑(add/progress/tree/checkpoints)×
 * 插件转发(intervene/verify/evolve)**。
 */

package magic.app.services.lrt

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull, JsonKind}
import magic.log.LogUtils
import magic.app.models.uctoo.{AgentTasksPO, CrontabPO, CrontabLogPO}
import magic.app.services.uctoo.{AgentTasksService, CrontabService, CrontabLogService}
import magic.app.services.bridge.CheckpointManager
import magic.app.core.response.APIResult
import f_util.UUID

/**
 * 长程任务用户 API 服务
 *
 * 所有方法返回 `APIResult<T>`(`success` / `data` / `reason` 三字段),
 * 与宿主其它 service 一致,便于控制器层统一处理。
 */
public class LongTaskApiService {
    private let tasksService = AgentTasksService()
    private let crontabService = CrontabService()
    private let crontabLogService = CrontabLogService()
    private let checkpointManager = CheckpointManager()

    public init() {}

    // ── 9.1.1 提交长程任务（POST /long_running_task/add）──────────────

    /**
     * 提交长程任务目标
     *
     * 做的事(顺序有讲究)：
     * 1. 建根任务(`agent_tasks`,`parent_task_id=NULL`,`status=0` pending)
     *    ： 先建任务是因为 crontab 的 `parameters` 里要带 `taskId`。
     *    `status=0` 与插件侧建根任务一致；进入 running(1) 发生在插件首回合。
     * 2. 建调度记录(`crontab`,`task=lrt://<agentId>`,
     *    `parameters={"taskId":<id>,"userId":<uid>}`)。
     * 3. **回调插件 `lrt-plan`** 做 AI 自主规划(把 goal 解析成任务树草稿)。
     * 4. **立即触发首回合**(spec 4.1 规则 5)：不等下一个 CRON 周期。
     *
     * @param goal 用户目标原文(必填)
     * @param agentId 执行该任务的 Agent(必填;决定 `lrt://` 的路径段)
     * @param priority 优先级(缺省 5;数值越小越优先,与 `AgentTasksPO.priority` 语义一致)
     * @param cron CRON 表达式(缺省 5 分钟轮询间隔,每 5 分钟唤起一回合)
     * @param constraints 附加约束(缺省空;写入 payload.constraints,供重规划使用)
     * @param userId 提交人
     */
    public func submitTask(
        goal: String,
        agentId: String,
        priority: ?Int32,
        cron: ?String,
        constraints: ArrayList<String>,
        userId: String,
        sessionId: String,
        traceId: String
    ): APIResult<JsonObject> {
        if (goal.trimAscii().isEmpty()) {
            return fail("goal 不能为空")
        }
        if (agentId.trimAscii().isEmpty()) {
            return fail("agentId 不能为空")
        }

        try {
            // ── 1) 建根任务 ───────────────────────────────────────
            let taskPO = AgentTasksPO()
            // 预置 ID：insertAgentTasks 若自行生成主键会覆盖此值，这里只是兜底。
            taskPO.id = LongTaskApiService.generateId()
            taskPO.agentId = agentId
            taskPO.parentTaskId = None<String>
            // status=0（pending）。设计 2.1.3.1：0=pending / 1=running / 2=completed。
            // 【为什么必须是 0】插件侧建根任务同样是 0（`lrt_persist_service.cj` createRootTask），
            // 两条入口的初始状态必须一致，否则按 `status=0` 过滤"待处理"的消费者
            // （任务列表 / 看板 / 兜底扫描）会漏掉经宿主 API 创建的任务。（review 偏差 #1）
            // 0→1 的迁移发生在插件首回合 `LrtExecutor.runTask` 的 `updateTaskStatus(taskId, 1)`——
            // 语义是"已被调度器唤起、真的开始跑了"，而不是"用户点了提交"。
            taskPO.status = Some(0)
            taskPO.priority = Some(match (priority) { case Some(p) => p; case None => 5 })
            taskPO.payload = Some(LongTaskApiService.buildInitialPayload(goal, constraints, sessionId, traceId).toString())
            taskPO.creator = Some(userId)
            taskPO.createdAt = DateTime.now()
            taskPO.updatedAt = DateTime.now()

            let createResult = tasksService.create(taskPO, userId)
            if (!createResult.success) {
                LogUtils.error("[LongTaskApiService] 创建根任务失败: ${reasonOf(createResult.reason)}")
                return fail("创建根任务失败: ${reasonOf(createResult.reason)}")
            }
            // 用 create 回填的真实 ID（库可能自行生成主键，不能沿用本地预置值）
            let taskId = match (createResult.data) {
                case Some(t) => t.id
                case None => taskPO.id
            }

            // ── 2) 建调度记录 ─────────────────────────────────────
            let crontabPO = CrontabPO()
            // 预置 ID：insertXxx 若自行生成主键会覆盖此值（见 CrontabService.create
            // 的 `entity.id = id`），故这里只是"库不生成主键"时的兜底。
            crontabPO.id = LongTaskApiService.generateId()
            crontabPO.name = "lrt-${taskId}"
            crontabPO.groupName = "1"
            // taskUri 形如 lrt://<agentId>；SchedulerEngine 按 scheme 选 LrtPluginExecutor，
            // 再由 parsePath 取出 agentId、由 parameters 里的 taskId 驱动 L3 插件执行。
            // 【为什么不再用 agent_execution://】宿主 AgentExecutionExecutor 在收敛退出时
            // 会**无条件** updateTaskStatus(..., Some(2))，与 spec 5.6.1 规则 7
            // 「未经用户确认不得交付」冲突（插件侧两段式被宿主 CRON 链路旁路）。
            // 长程任务因此改走 lrt://，宿主只触发、不写 status。（2026-09-15 定夺）
            crontabPO.task = "lrt://${agentId}"
            crontabPO.cron = match (cron) { case Some(c) => c; case None => "0 */5 * * * ?" }
            crontabPO.tactics = ""
            crontabPO.remark = "长程任务调度（taskId=${taskId}）"
            crontabPO.creator = Some(userId)
            crontabPO.createdAt = DateTime.now()
            crontabPO.updatedAt = DateTime.now()
            // 【关键】必须显式写 status=1。
            // CrontabPO.status 默认值是 0，而 SchedulerEngine 只在 `task.status == 1`
            // 时才把任务注册进 ticktock（SchedulerEngine.cj:169）。写 0 的后果是
            // **任务永不触发、且没有任何报错**——排查成本极高，故在此写死并加注释。
            crontabPO.status = 1
            crontabPO.concurrentable = Some(false) // 禁止重叠触发（调度层 runningTasks + 插件层 executing 双保险）
            crontabPO.once = Some(false)          // 反复唤起，直到任务收敛为终态
            crontabPO.priority = Some(match (priority) { case Some(p) => p; case None => 5 })
            // parameters 是宿主传给执行器的字符串；LrtPluginExecutor 从中取
            // taskId（定位 agent_tasks）与 userId（插件侧行级权限）。
            // 真正的任务上下文由插件按 taskId 从 agent_tasks.payload 取，故这里保持精简。
            let paramObj = JsonObject()
            paramObj.put("taskId", JsonString(taskId))
            paramObj.put("userId", JsonString(userId))
            crontabPO.parameters = Some(paramObj.toString())

            let crontabResult = crontabService.create(crontabPO, userId)
            if (!crontabResult.success) {
                // 调度建失败要回滚任务，否则留下一个"存在但永不执行"的僵尸任务
                LogUtils.error("[LongTaskApiService] 创建调度失败，回滚任务: ${reasonOf(crontabResult.reason)}")
                let _ = tasksService.delete(taskId, true)
                return fail("创建调度失败: ${reasonOf(crontabResult.reason)}")
            }
            // 用 create 回填的真实 ID（库可能自行生成主键，不能沿用本地预置值）
            let crontabId = match (crontabResult.data) {
                case Some(c) => c.id
                case None => crontabPO.id
            }

            // ── 3) 回调插件做 AI 自主规划 ─────────────────────────
            // 规划失败**不阻断**提交：任务与调度已就绪，规划可重试（干预 adjust_goal 会重新触发）。
            // 若此处直接失败，用户会以为"任务没提交成功"，但库里其实已经有记录了，反而更乱。
            match (LrtPluginClient.plan(taskId, goal, userId, ArrayList<String>())) {
                case Ok(planJson) =>
                    LogUtils.info("[LongTaskApiService] 插件规划完成: taskId=${taskId}")
                    LongTaskApiService.mergePlanIntoPayload(this.tasksService, taskId, JsonValue.fromStr(planJson.stringify()))
                case Err(e) =>
                    LogUtils.warn("[LongTaskApiService] 插件规划失败（不阻断提交）: ${e}")
                case _ =>
                    LogUtils.warn("[LongTaskApiService] 插件规划无结果（不阻断提交）")
            }

            // ── 4) 立即触发首回合 ─────────────────────────────────
            // spec 4.1 规则 5：提交后立刻跑第一回合，不等 CRON。
            // spawn 异步：提交接口必须快速返回 taskId，不能等一整个回合跑完。
            let firstTaskId = taskId
            let firstUserId = userId
            spawn { =>
                match (LrtPluginClient.execute(firstTaskId, firstUserId, ArrayList<String>())) {
                    case Ok(_) => LogUtils.info("[LongTaskApiService] 首回合已触发: taskId=${firstTaskId}")
                    case Err(e) => LogUtils.warn("[LongTaskApiService] 首回合触发失败: ${e}")
                    case _ => LogUtils.warn("[LongTaskApiService] 首回合无结果: taskId=${firstTaskId}")
                }
            }

            // ── 5) 组装响应 ───────────────────────────────────────
            let resp = JsonObject()
            resp.put("taskId", JsonString(taskId))
            resp.put("agentId", JsonString(agentId))
            resp.put("crontabId", JsonString(crontabId))
            resp.put("status", JsonInt(1))
            resp.put("firstRoundTriggered", JsonBool(true))
            ok(resp)
        } catch (e: Exception) {
            LogUtils.error("[LongTaskApiService] submitTask 异常: ${e.message}")
            fail("提交失败: ${e.message}")
        }
    }

    // ── 9.1.2 用户干预（POST /long_running_task/intervene）───────────

    /**
     * 用户干预(转发到插件 `lrt-intervene`)
     *
     * 状态机与状态迁移全部在插件的 `LrtInterventionService` 里,
     * 宿主**不做**二次状态校验：否则同一套状态机会在两侧各写一遍,
     * 一旦规则调整就会出现"A 侧允许、B 侧拒绝"的诡异行为。
     *
     * @param action pause / resume / cancel / force_cancel / adjust_goal / add_constraint
     */
    public func intervene(taskId: String, action: String, content: String, userId: String): APIResult<JsonValue> {
        if (taskId.trimAscii().isEmpty()) {
            return APIResult<JsonValue>(false, "taskId 不能为空")
        }
        if (action.trimAscii().isEmpty()) {
            return APIResult<JsonValue>(false, "action 不能为空")
        }
        match (LrtPluginClient.intervene(taskId, action, content, userId, ArrayList<String>())) {
            case Ok(v) => ok(JsonValue.fromStr(v.stringify()))
            case Err(e) => APIResult<JsonValue>(false, "干预失败: ${e}")
            case _ => APIResult<JsonValue>(false, "干预无结果")
        }
    }

    // ── 9.1.3 任务树（GET /long_running_task/tree/:rootId）───────────

    /**
     * 查询任务树
     *
     * 直接用 `AgentTasksService.getTaskTree`(Ch9.3 实现,层内批量查询避免 N+1),
     * 本方法只负责把 `TaskTreeNode` 转成 JSON。
     */
    public func getTaskTreeJson(rootTaskId: String, userId: String): APIResult<JsonArray> {
        if (rootTaskId.trimAscii().isEmpty()) {
            return APIResult<JsonArray>(false, "rootId 不能为空")
        }
        try {
            let nodes = tasksService.getTaskTree(rootTaskId, userId)
            let arr = JsonArray()
            for (n in nodes) {
                arr.add(n.toJson())
            }
            if (arr.size() == 0) {
                return APIResult<JsonArray>(false, "任务不存在或无权访问: ${rootTaskId}")
            }
            ok(arr)
        } catch (e: Exception) {
            LogUtils.error("[LongTaskApiService] getTaskTreeJson 异常: ${e.message}")
            APIResult<JsonArray>(false, "查询任务树失败: ${e.message}")
        }
    }

    // ── 9.1.4 任务进度（GET /long_running_task/progress/:taskId）─────

    /**
     * 查询任务进度
     *
     * 数据源是 **`agent_tasks.payload`**(design 收敛后进度不再独立成表;
     * tasks 9.1 明确要求)。payload 里约定这些键：
     * ```
     * {
     *   "goal": "...",
     *   "completed_steps": 3,
     *   "total_steps": 8,
     *   "current_step": "step-4-analyze",
     *   "intermediate_result": "...",     // 中间结果预览
     *   "started_at_ms": 1726000000000,   // 首回合开始时刻(估算剩余时间用)
     *   "constraints": ["..."],
     *   "plan": { ... },
     *   "created_via": "lrt-plan"
     * }
     * ```
     *
     * `estimated_remaining_ms` 的算法与"无基线返回 null"的约束见
     * `estimateRemainingMs` 的注释。
     */
    public func getProgress(taskId: String, userId: String): APIResult<JsonObject> {
        if (taskId.trimAscii().isEmpty()) {
            return APIResult<JsonObject>(false, "taskId 不能为空")
        }
        try {
            let taskOpt = tasksService.getById(taskId)
            if (!taskOpt.success) {
                return APIResult<JsonObject>(false, "任务不存在或无权访问: ${taskId}")
            }
            let task = match (taskOpt.data) {
                case Some(t) => t
                case None => return APIResult<JsonObject>(false, "任务不存在: ${taskId}")
            }

            let out = JsonObject()
            out.put("taskId", JsonString(task.id))
            out.put("agentId", JsonString(task.agentId))
            match (task.status) {
                case Some(s) => out.put("status", JsonInt(Int64(s)))
                case None => out.put("status", JsonNull())
            }

            // 解析 payload（缺失/损坏时降级为空对象，不报错——
            // 进度查询是只读观测接口，不该因为 payload 脏数据而整体失败）
            let payloadObj = LongTaskApiService.parsePayload(task.payload)

            out.put("completedSteps", LongTaskApiService.intField(payloadObj, "completed_steps"))
            out.put("totalSteps", LongTaskApiService.intField(payloadObj, "total_steps"))
            out.put("currentStep", LongTaskApiService.strField(payloadObj, "current_step"))
            out.put("intermediateResult", LongTaskApiService.strField(payloadObj, "intermediate_result"))
            // 目标达成度：终态时由验核报告写入 payload.goal_achievement
            out.put("goalAchievement", LongTaskApiService.numField(payloadObj, "goal_achievement"))
            // 预估剩余时间
            out.put("estimatedRemainingMs", LongTaskApiService.estimateRemainingMs(payloadObj, task))
            // 进度百分比：completed/total 推导；total 缺失时为 null（不猜）
            out.put("progressPercent", LongTaskApiService.computePercent(payloadObj))

            ok(out)
        } catch (e: Exception) {
            LogUtils.error("[LongTaskApiService] getProgress 异常: ${e.message}")
            APIResult<JsonObject>(false, "查询进度失败: ${e.message}")
        }
    }

    // ── 9.1.5 检查点列表（GET /long_running_task/checkpoints/:taskId）─

    /**
     * 查询任务的检查点列表
     *
     * 注意 `CheckpointManager` 的检查点是**按 agentId 索引**的
     * (见 `listCheckpoints(agentId, page, pageSize)`),不是按 taskId。
     * 因此这里先从 taskId 查出任务的 agentId,再按 agentId 取检查点。
     *
     * 这个间接是有意保持的：`agent_contexts.agent_id` 上有索引而 `task_id` 没有,
     * 若为了"按 taskId 直查"去加索引,等于把检查点存储的语义从
     * "Agent 的上下文快照"改成"任务的分片",会影响其它复用该表的场景。
     */
    public func listCheckpoints(taskId: String, page: Int64, pageSize: Int64, userId: String): APIResult<JsonObject> {
        if (taskId.trimAscii().isEmpty()) {
            return APIResult<JsonObject>(false, "taskId 不能为空")
        }
        try {
            let taskOpt = tasksService.getById(taskId)
            if (!taskOpt.success) {
                return APIResult<JsonObject>(false, "任务不存在或无权访问: ${taskId}")
            }
            let agentId = match (taskOpt.data) {
                case Some(t) => t.agentId
                case None => return APIResult<JsonObject>(false, "任务不存在: ${taskId}")
            }

            let (items, total) = checkpointManager.listCheckpoints(agentId, page, pageSize)
            let arr = JsonArray()
            for (po in items) {
                let item = JsonObject()
                item.put("id", JsonString(po.id))
                item.put("agentId", JsonString(po.agentId))
                item.put("createdAt", JsonString(po.createdAt.toString()))
                // 只回元信息，不回整段 messages（可能很大；需要正文时按 id 单独取）
                item.put("contextSize", JsonInt(LongTaskApiService.optSize(po.messages)))
                arr.add(item)
            }

            let out = JsonObject()
            out.put("taskId", JsonString(taskId))
            out.put("agentId", JsonString(agentId))
            out.put("total", JsonInt(total))
            out.put("list", arr)
            ok(out)
        } catch (e: Exception) {
            LogUtils.error("[LongTaskApiService] listCheckpoints 异常: ${e.message}")
            APIResult<JsonObject>(false, "查询检查点失败: ${e.message}")
        }
    }

    // ── 9.1.6 触发验核（POST /long_running_task/verify/:taskId）──────

    /// 触发自主验核（转发到插件 `lrt-verify`）
    public func triggerVerify(taskId: String, userId: String): APIResult<JsonValue> {
        if (taskId.trimAscii().isEmpty()) {
            return APIResult<JsonValue>(false, "taskId 不能为空")
        }
        match (LrtPluginClient.verify(taskId, userId, ArrayList<String>())) {
            case Ok(v) => ok(JsonValue.fromStr(v.stringify()))
            case Err(e) => APIResult<JsonValue>(false, "验核失败: ${e}")
            case _ => APIResult<JsonValue>(false, "验核无结果")
        }
    }

    // ── 9.1.7 触发自进化（POST /long_running_task/evolve/:agentId）───

    /// 触发自进化闭环（转发到插件 `lrt-evolve`）
    public func triggerEvolve(agentId: String, userId: String): APIResult<JsonValue> {
        if (agentId.trimAscii().isEmpty()) {
            return APIResult<JsonValue>(false, "agentId 不能为空")
        }
        match (LrtPluginClient.evolve(agentId, userId, ArrayList<String>())) {
            case Ok(v) => ok(JsonValue.fromStr(v.stringify()))
            case Err(e) => APIResult<JsonValue>(false, "自进化失败: ${e}")
            case _ => APIResult<JsonValue>(false, "自进化无结果")
        }
    }

    // ── 9.1.8 交付确认（POST /long_running_task/deliver/:taskId）────

    /**
     * 用户在验核报告上「确认交付 / 放弃」(转发到插件 `lrt-deliver`)
     *
     * spec 5.6.1 规则 5 要求产物必须经用户确认后才落地 —— **任务进入 completed 的那一刻只能由用户触发**。
     * 所以「置 status=2」不写在执行器里(它只标记 awaiting_review 并推 review_required)，
     * 而写在这条路径上，由插件侧 `confirmDelivery` 完成迁移。
     *
     * 宿主这里只做参数/动作白名单校验，**不做二次状态校验**：状态机已在插件侧，
     * 宿主再写一遍就会出现「A 侧允许、B 侧拒绝」的双规则问题。
     *
     * @param action confirm(确认交付→status=2) / abandon(放弃→status=4)
     */
    public func deliverTask(taskId: String, action: String, userId: String): APIResult<JsonValue> {
        if (taskId.trimAscii().isEmpty()) {
            return APIResult<JsonValue>(false, "taskId 不能为空")
        }
        let effectiveAction = action.trimAscii()
        if (effectiveAction != "confirm" && effectiveAction != "abandon") {
            return APIResult<JsonValue>(false, "action 须为 confirm 或 abandon")
        }
        match (LrtPluginClient.deliver(taskId, effectiveAction, userId, ArrayList<String>())) {
            case Ok(v) => ok(JsonValue.fromStr(v.stringify()))
            case Err(e) => APIResult<JsonValue>(false, "交付确认失败: ${e}")
            case _ => APIResult<JsonValue>(false, "交付确认无结果")
        }
    }

    // ── 9.1.9 评审改进（POST /long_running_task/review/:taskId）─────

    /**
     * 用户对验核结果「要求改进 / 放弃」(转发到插件 `lrt-review`)
     *
     * 闭环的最后一段：验核报告推给用户 → 用户给反馈 → 插件据此 `LrtPlanner.replan` → 继续执行。
     * 缺掉这一步，长程任务就没有「人要求改」的回路，只能从头再来或硬着头皮交付。
     *
     * @param action   improve(要求改进→触发 replan) / abandon(放弃→status=4)
     * @param feedback 用户的改进要求，作为 addedConstraints 传入 replan
     * @param goal     用户重述的目标；为空表示沿用原目标，只追加反馈约束
     */
    public func reviewTask(
        taskId: String,
        action: String,
        feedback: String,
        goal: String,
        userId: String
    ): APIResult<JsonValue> {
        if (taskId.trimAscii().isEmpty()) {
            return APIResult<JsonValue>(false, "taskId 不能为空")
        }
        let effectiveAction = action.trimAscii()
        if (effectiveAction != "improve" && effectiveAction != "abandon") {
            return APIResult<JsonValue>(false, "action 须为 improve 或 abandon")
        }
        // 要求改进却什么都没说：与其让插件拿到空约束重规划出一模一样的方案(空转一轮)，
        // 不如在这里就明确拒绝，让用户补上「到底要改什么」。
        if (effectiveAction == "improve"
            && feedback.trimAscii().isEmpty()
            && goal.trimAscii().isEmpty()) {
            return APIResult<JsonValue>(false, "improve 时 feedback 与 goal 不可同时为空")
        }
        match (LrtPluginClient.review(taskId, effectiveAction, feedback, goal, userId, ArrayList<String>())) {
            case Ok(v) => ok(JsonValue.fromStr(v.stringify()))
            case Err(e) => APIResult<JsonValue>(false, "评审改进失败: ${e}")
            case _ => APIResult<JsonValue>(false, "评审改进无结果")
        }
    }

    // ── 9.3.3 执行轨迹检索 ──────────────────────────────────────────

    /**
     * 按 trace_id / task_id 检索执行轨迹(spec 5.18 规则 5)
     *
     * 轨迹数据分布在两处,本方法把它们归并成一条时间线：
     * - `crontab_log`：每个回合的调度日志(含 triggerType/结果/耗时)
     * - `agent_contexts`：每个回合的消息快照(含工具调用与中间思考)
     *
     * 之所以不在库里建一张"轨迹表"：轨迹是**既有数据的视图**,
     * 落第二份存储会引入"两边不一致"的问题,而查询本身(按 taskId/agentId
     * 过滤 + 时间排序)在当前数据量下成本可接受。
     *
     * 注意：轨迹是**回合级**的。回合与人/时间而不是与 taskId 直接关联,
     * 故这里先由 taskId 解出 agentId 与 crontabId,再分别取两类记录。
     *
     * @param taskId 任务 ID(可空：为空时退化为按 agentId 查)
     * @param agentId Agent ID(可空)
     * @param traceId 追踪 ID(可空;为空时不按 trace 过滤)
     */
    public func getTrace(
        taskId: String,
        agentId: String,
        traceId: String,
        page: Int64,
        pageSize: Int64,
        userId: String
    ): APIResult<JsonObject> {
        if (taskId.isEmpty() && agentId.isEmpty()) {
            return APIResult<JsonObject>(false, "taskId 与 agentId 至少提供一个")
        }
        try {
            var effectiveAgentId = agentId
            let effectiveTaskId = taskId

            // 只给了 taskId：补出 agentId（crontab_log / agent_contexts 都按 agentId 关联）
            if (effectiveAgentId.isEmpty() && !taskId.isEmpty()) {
                let taskOpt = tasksService.getById(taskId)
                if (taskOpt.success) {
                    match (taskOpt.data) {
                        case Some(t) => effectiveAgentId = t.agentId
                        case None => ()
                    }
                }
            }

            let out = JsonObject()
            out.put("taskId", JsonString(effectiveTaskId))
            out.put("agentId", JsonString(effectiveAgentId))
            if (!traceId.isEmpty()) {
                out.put("traceId", JsonString(traceId))
            }

            // 1) 回合级调度日志。crontab_log 按 crontabId 索引，故先找出该任务的调度记录。
            let logsArr = JsonArray()
            let crontabIds = LongTaskApiService.findCrontabIdsByTask(this.crontabService, effectiveTaskId, effectiveAgentId)
            for (cid in crontabIds) {
                let (items, _) = crontabLogService.getLogsByCrontabId(cid, page, pageSize)
                for (po in items) {
                    let item = JsonObject()
                    item.put("crontabId", JsonString(po.crontabId))
                    match (po.triggerType) {
                        case Some(t) => item.put("triggerType", JsonString(t))
                        case None => item.put("triggerType", JsonNull())
                    }
                    match (po.executorType) {
                        case Some(t) => item.put("executorType", JsonString(t))
                        case None => item.put("executorType", JsonNull())
                    }
                    item.put("status", JsonInt(Int64(po.status)))
                    item.put("usedTimeMs", JsonInt(Int64(po.usedTime)))
                    item.put("errorMessage", JsonString(po.errorMessage))
                    item.put("createdAt", JsonString(po.createdAt.toString()))
                    logsArr.add(item)
                }
            }
            out.put("rounds", logsArr)

            // 2) 回合级上下文快照（含工具调用与关键决策）
            let ctxArr = JsonArray()
            let (ctxItems, ctxTotal) = checkpointManager.listCheckpoints(effectiveAgentId, page, pageSize)
            for (po in ctxItems) {
                let item = JsonObject()
                item.put("id", JsonString(po.id))
                item.put("agentId", JsonString(po.agentId))
                item.put("createdAt", JsonString(po.createdAt.toString()))
                item.put("messagesSize", JsonInt(LongTaskApiService.optSize(po.messages)))
                match (po.metadata) {
                    case Some(m) => item.put("metadata", JsonString(m))
                    case None => item.put("metadata", JsonNull())
                }
                ctxArr.add(item)
            }
            out.put("checkpoints", ctxArr)
            out.put("checkpointTotal", JsonInt(ctxTotal))

            ok(out)
        } catch (e: Exception) {
            LogUtils.error("[LongTaskApiService] getTrace 异常: ${e.message}")
            APIResult<JsonObject>(false, "检索轨迹失败: ${e.message}")
        }
    }

    /**
     * 找出某任务关联的 crontab 记录 ID
     *
     * 关联方式：`crontab.parameters` 里写了 `{"taskId": "<id>"}`(见 submitTask 第 2 步)。
     * 这里用 LIKE 粗筛(parameters 是文本列,无法按 JSON 精确索引),
     * 再在内存里做一次精确 JSON 校验,避免 `taskId=abc` 误匹配 `taskId=abcd`。
     */
    private static func findCrontabIdsByTask(
        crontabService: CrontabService,
        taskId: String,
        agentId: String
    ): ArrayList<String> {
        let out = ArrayList<String>()
        try {
            // 注意：getListWithFilter 的分页参数是 Int32（与其它 CRUD 服务不同）
            // 1) 有 taskId：按 taskId 精确匹配
            if (!taskId.isEmpty()) {
                let (items, _) = crontabService.getListWithFilter(Int32(1), Int32(100), "created_at DESC", "")
                for (po in items) {
                    match (po.parameters) {
                        case Some(p) =>
                            if (LongTaskApiService.parametersHasTaskId(p, taskId)) {
                                out.add(po.id)
                            }
                        case None => ()
                    }
                }
                if (out.size > 0) {
                    return out
                }
            }
            // 2) 退路：按 lrt://<agentId> 匹配 task URI
            if (!agentId.isEmpty()) {
                let (items, _) = crontabService.getListWithFilter(Int32(1), Int32(100), "created_at DESC", "")
                for (po in items) {
                    if (po.task == "lrt://${agentId}") {
                        out.add(po.id)
                    }
                }
            }
        } catch (e: Exception) {
            LogUtils.warn("[LongTaskApiService] findCrontabIdsByTask 失败: ${e.message}")
        }
        out
    }

    /// 判断 parameters 文本里是否真的含该 taskId（JSON 精确比对，避免前缀误匹配）
    private static func parametersHasTaskId(parameters: String, taskId: String): Bool {
        try {
            let parsed = JsonValue.fromStr(parameters)
            if (!(parsed is JsonObject)) {
                return false
            }
            let v = parsed.asObject().get("taskId")
            if (v.isNone()) {
                return false
            }
            let jv = v.getOrThrow()
            match (jv.kind()) {
                case JsonKind.JsString => jv.asString().getValue() == taskId
                case _ => false
            }
        } catch (_: Exception) {
            false
        }
    }

    // ── 内部工具 ────────────────────────────────────────────────────

    /// 成功结果（`APIResult` 没有 3 参构造器，需先建后填 data）
    private static func ok<T>(data: T): APIResult<T> {
        let r = APIResult<T>()
        r.success = true
        r.data = Some(data)
        r
    }

    /// 失败结果
    private static func fail<T>(reason: String): APIResult<T> {
        APIResult<T>(false, reason)
    }

    /// 安全取 reason 文本（None 时给空串，避免拼出 "None"）
    private static func reasonOf(reason: ?String): String {
        match (reason) {
            case Some(r) => r
            case None => ""
        }
    }

    /// Option<String> 的字符数（None → 0）
    private static func optSize(v: ?String): Int64 {
        match (v) {
            case Some(s) => Int64(s.size)
            case None => 0
        }
    }

    /**
     * 构造初始 payload(goal + constraints + 进度零值 + 事件上报用的上下文)
     *
     * `session_id` / `trace_id` 写进 payload 而不是表字段：`agent_tasks` 没有这两列,
     * 且它们是"某次提交的上下文"而非任务本身属性。**插件进程要靠它们上报事件**：
     * 插件侧 `LrtExecutor` 从 payload 里读这两个值再经 `host.event` 发出,
     * 空值时有定义好的降级(sessionId 空 → 只走 WebSocket)。
     */
    private static func buildInitialPayload(
        goal: String,
        constraints: ArrayList<String>,
        sessionId: String,
        traceId: String
    ): JsonObject {
        let payload = JsonObject()
        payload.put("goal", JsonString(goal))
        payload.put("completed_steps", JsonInt(0))
        payload.put("total_steps", JsonInt(0))
        payload.put("current_step", JsonString(""))
        payload.put("intermediate_result", JsonString(""))
        payload.put("started_at_ms", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))
        payload.put("session_id", JsonString(sessionId))
        payload.put("trace_id", JsonString(traceId))
        let consArr = JsonArray()
        for (c in constraints) {
            consArr.add(JsonString(c))
        }
        payload.put("constraints", consArr)
        payload.put("created_via", JsonString("long_running_task/add"))
        payload
    }

    /// 把插件的规划结果合并进 payload.plan（读-改-写，只动 plan 与 total_steps 两个键）
    private static func mergePlanIntoPayload(
        tasksService: AgentTasksService,
        taskId: String,
        planJson: JsonValue
    ): Unit {
        try {
            let taskOpt = tasksService.getById(taskId)
            if (!taskOpt.success) {
                return
            }
            let task = match (taskOpt.data) {
                case Some(t) => t
                case None => return
            }
            let payloadObj = LongTaskApiService.parsePayload(task.payload)
            payloadObj.put("plan", planJson)
            // 规划完成后同步总步数，让 progress 一开始就有分母
            let planStepCount = LongTaskApiService.countPlanSteps(planJson)
            if (planStepCount > 0) {
                payloadObj.put("total_steps", JsonInt(planStepCount))
            }

            let patch = AgentTasksPO()
            patch.payload = Some(payloadObj.toString())
            patch.updatedAt = DateTime.now()
            let r = tasksService.update(taskId, patch)
            if (!r.success) {
                LogUtils.warn("[LongTaskApiService] 回写 plan 失败: ${reasonOf(r.reason)}")
            }
        } catch (e: Exception) {
            LogUtils.warn("[LongTaskApiService] mergePlanIntoPayload 异常: ${e.message}")
        }
    }

    /**
     * 从规划 JSON 里数"有多少个步骤"
     *
     * 规划结果的形状由插件 `LrtPlanner` 决定,宿主**不硬编码它的 schema**,
     * 而是按已知的几种可能形状探测(steps / tasks / subtasks 数组)。
     * 探测不到就返回 0,progress 的 totalSteps 保持 0 → 百分比返回 null,
     * 而不是编一个假分母。
     */
    private static func countPlanSteps(planJson: JsonValue): Int64 {
        if (!(planJson is JsonObject)) {
            return 0
        }
        let fields = planJson.asObject()
        for (key in ["steps", "tasks", "subtasks"]) {
            let child = fields.get(key)
            if (child.isSome()) {
                let v = child.getOrThrow()
                if (v is JsonArray) {
                    return v.asArray().size()
                }
            }
        }
        // 嵌套在 plan 字段里的情况
        let inner = fields.get("plan")
        if (inner.isSome()) {
            return LongTaskApiService.countPlanSteps(inner.getOrThrow())
        }
        0
    }

    /// 解析 payload 字符串为 JsonObject；缺失/非对象/解析失败一律返回空对象
    private static func parsePayload(payload: ?String): JsonObject {
        match (payload) {
            case None => JsonObject()
            case Some(s) =>
                if (s.trimAscii().isEmpty()) {
                    return JsonObject()
                }
                try {
                    let parsed = JsonValue.fromStr(s)
                    if (parsed is JsonObject) {
                        parsed.asObject()
                    } else {
                        JsonObject()
                    }
                } catch (_: Exception) {
                    LogUtils.warn("[LongTaskApiService] payload JSON 解析失败，按空对象处理")
                    JsonObject()
                }
        }
    }

    /**
     * 取整数键(缺失/类型不符返回 null)
     *
     * 注意 stdx 把 `JsInt` 与 `JsFloat` 分成两种 kind,所以 JSON 里写成 `3`
     * 与 `3.0` 会落到不同分支,这里都要接住。
     */
    private static func intField(obj: JsonObject, key: String): JsonValue {
        let v = obj.get(key)
        if (v.isNone()) {
            return JsonNull()
        }
        let jv = v.getOrThrow()
        match (jv.kind()) {
            case JsonKind.JsInt => JsonInt(jv.asInt().getValue())
            case JsonKind.JsFloat => JsonInt(Int64(jv.asFloat().getValue()))
            // 有些写入路径存的是字符串形式的数字
            case JsonKind.JsString =>
                match (LongTaskApiService.tryParseInt(jv.asString().getValue())) {
                    case Some(v2) => JsonInt(v2)
                    case None => JsonNull()
                }
            case _ => JsonNull()
        }
    }

    /// 取浮点键（同样要同时接住 JsInt 与 JsFloat）
    private static func numField(obj: JsonObject, key: String): JsonValue {
        let v = obj.get(key)
        if (v.isNone()) {
            return JsonNull()
        }
        let jv = v.getOrThrow()
        match (jv.kind()) {
            case JsonKind.JsFloat => JsonFloat(jv.asFloat().getValue())
            case JsonKind.JsInt => JsonFloat(Float64(jv.asInt().getValue()))
            case JsonKind.JsString =>
                match (LongTaskApiService.tryParseFloat(jv.asString().getValue())) {
                    case Some(v2) => JsonFloat(v2)
                    case None => JsonNull()
                }
            case _ => JsonNull()
        }
    }

    /// 取字符串键（缺失返回空串而非 null——前端拼接字符串时 null 会变成 "null"）
    private static func strField(obj: JsonObject, key: String): JsonValue {
        let v = obj.get(key)
        if (v.isNone()) {
            return JsonString("")
        }
        let jv = v.getOrThrow()
        match (jv.kind()) {
            case JsonKind.JsString => JsonString(jv.asString().getValue())
            case _ => JsonString(jv.toString())
        }
    }

    /// 从 JsonObject 里读整数（缺失/类型不符归 0）
    private static func readInt(obj: JsonObject, key: String): Int64 {
        let v = obj.get(key)
        if (v.isNone()) {
            return 0
        }
        let jv = v.getOrThrow()
        match (jv.kind()) {
            case JsonKind.JsInt => jv.asInt().getValue()
            case JsonKind.JsFloat => Int64(jv.asFloat().getValue())
            case JsonKind.JsString =>
                match (LongTaskApiService.tryParseInt(jv.asString().getValue())) {
                    case Some(v2) => v2
                    case None => 0
                }
            case _ => 0
        }
    }

    /**
     * 预估剩余时间(tasks 9.1 明确要求：**无基线时返回 null,而不是 0**)
     *
     * 为什么不能填 0：前端把 0 解读为"马上完成",会误导用户;
     * `null` 才表达"还估不出来",前端可以显示"-"。
     *
     * 算法：`elapsed / completed * (total - completed)`
     * - 已完成步数 = 0 → **无基线**,返回 null(除零,且确实没有速率可外推)
     * - 总步数 = 0 → **无分母**,返回 null(规划还没出结果)
     * - 任务已是终态(2/3/4)→ 返回 0(已完成,剩余时间确实是 0,这里是准确的 0)
     *
     * 关于 `agent_loop_metrics.avg_duration_ms`：该表按 **agent** 聚合,不是按"步"。
     * 若要拿它做"每步耗时"的基线,需要先有"这个 agent 平均一次任务多少毫秒、
     * 任务平均多少步"两个量,再相除：这两个量当前都没有可靠来源。
     * 用 `avg_duration_ms × total_steps` 会在"一条任务多步"时把估算放大几十倍。
     * 因此这里**不使用**该表做估算,仅在 completed==0 且 total>0 时返回 null;
     * 待 `agent_loop_metrics` 补上 per-step 记录后再接入(已在 tasks.md 记为后续项)。
     */
    private static func estimateRemainingMs(payload: JsonObject, task: AgentTasksPO): JsonValue {
        // 终态：剩余时间确实是 0，报 0 是准确值而非误导
        match (task.status) {
            case Some(s) =>
                if (s == 2 || s == 3 || s == 4) {
                    return JsonInt(0)
                }
            case None => ()
        }

        let completed = LongTaskApiService.readInt(payload, "completed_steps")
        let total = LongTaskApiService.readInt(payload, "total_steps")

        if (completed > 0 && total > completed) {
            let startedMs = LongTaskApiService.readInt(payload, "started_at_ms")
            if (startedMs > 0) {
                let elapsed = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - startedMs
                if (elapsed > 0) {
                    let perStep = Float64(elapsed) / Float64(completed)
                    let remaining = perStep * Float64(total - completed)
                    return JsonInt(Int64(remaining))
                }
            }
            // 有完成步数但拿不到起始时刻：无法外推 → null
            return JsonNull()
        }

        // completed == 0（无速率可外推）或 total == 0（无分母）或 completed >= total
        JsonNull()
    }

    /// 进度百分比：total<=0 时返回 null（不编造分母）
    private static func computePercent(payload: JsonObject): JsonValue {
        let completed = LongTaskApiService.readInt(payload, "completed_steps")
        let total = LongTaskApiService.readInt(payload, "total_steps")
        if (total <= 0) {
            return JsonNull()
        }
        JsonFloat(Float64(completed) / Float64(total) * 100.0)
    }

    private static func tryParseInt(s: String): ?Int64 {
        try {
            Some(Int64.parse(s.trimAscii()))
        } catch (_: Exception) {
            None
        }
    }

    private static func tryParseFloat(s: String): ?Float64 {
        try {
            Some(Float64.parse(s.trimAscii()))
        } catch (_: Exception) {
            None
        }
    }

    /// 生成主键（36 位 UUID，与表结构 char(36) 对齐）
    private static func generateId(): String {
        UUID.random().toString()
    }
}
