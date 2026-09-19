/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.long_running_task

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.APIResult
import magic.app.services.lrt.LongTaskApiService
import std.collection.{ArrayList, HashMap}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * 长程任务用户 API 控制器(spec §9.1,7 个端点)
 *
 * 路由前缀：`/api/v1/uctoo/long_running_task`
 *
 * | 方法 | 路径                        | 用途                     |
 * |------|-----------------------------|--------------------------|
 * | POST | `/add`                      | 提交长程任务(status=1,立即触发首回合) |
 * | POST | `/intervene`                | 人工干预(暂停/恢复/改目标/补充约束) |
 * | GET  | `/tree/:rootId`             | 查询任务树                |
 * | GET  | `/progress/:taskId`         | 查询进度(estimated_remaining_ms 可空) |
 * | GET  | `/checkpoints/:taskId`      | 查询检查点列表            |
 * | POST | `/verify/:taskId`           | 触发验证                  |
 * | POST | `/evolve/:agentId`          | 触发 Agent 自进化          |
 *
 * 控制器只做三件事：取参数 → 调 `LongTaskApiService` → 序列化响应。
 * 所有业务语义(任务树、进度、状态机)都在 service 与插件侧,避免双份实现。
 */
public class LongRunningTaskController {
    private let service = LongTaskApiService()

    public init() {}

    // ── 9.1.1 POST /add ────────────────────────────────────────────

    /**
     * 提交长程任务。
     *
     * 请求体：`{goal, agentId, priority?, cron?, constraints?}`
     * 响应体：`{taskId, agentId, crontabId, status, firstRoundTriggered}`
     */
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let bodyOpt = LongRunningTaskController.parseObj(req.body)
            if (bodyOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                return
            }
            let body = bodyOpt.getOrThrow()

            let goal = LongRunningTaskController.strField(body, "goal")
            if (goal.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 goal 参数\"}")
                return
            }

            // agentId 允许从 query 兜底：方便前端在 URL 上直接带 agent
            var agentId = LongRunningTaskController.strField(body, "agentId")
            if (agentId.isEmpty()) {
                agentId = LongRunningTaskController.queryOf(req, "agentId")
            }
            if (agentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 agentId 参数\"}")
                return
            }

            // priority：缺省不传，交给 service 用 5
            let priority = LongRunningTaskController.intField(body, "priority")

            // cron：缺省不传，交给 service 用 "0 */5 * * * ?"
            let cronRaw = LongRunningTaskController.strField(body, "cron")
            let cron: ?String = if (cronRaw.isEmpty()) { None<String> } else { Some<String>(cronRaw) }

            let constraints = LongRunningTaskController.strArrayField(body, "constraints")

            // 事件上报上下文：前端可传 sessionId（走 SSE 实时看进度）；
            // 不传则空串——插件侧只走 WebSocket 广播，是定义好的降级路径。
            let sessionId = LongRunningTaskController.strField(body, "sessionId")
            let traceId = LongRunningTaskController.strField(body, "traceId")

            let result = service.submitTask(goal, agentId, priority, cron, constraints, userId, sessionId, traceId)
            this.respondObject(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] add error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.2 POST /intervene/:taskId ──────────────────────────────

    /**
     * 人工干预。
     *
     * 请求体：`{action, content?}`;action ∈ `pause|resume|change_goal|add_constraint`
     * 响应体：插件返回的干预结果(含受影响的任务子树信息)。
     */
    public func intervene(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            // 任务 ID 既支持 path 参数（/intervene/:taskId），也支持 body（便于批量脚本）
            var taskId = LongRunningTaskController.queryOf(req, "taskId")
            if (let Some(p) <- req.pathParam("taskId")) {
                if (!p.isEmpty()) {
                    taskId = p
                }
            }

            let body = LongRunningTaskController.bodyObj(req)

            if (taskId.isEmpty()) {
                taskId = LongRunningTaskController.strField(body, "taskId")
            }
            if (taskId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }

            let action = LongRunningTaskController.strField(body, "action")
            if (action.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 action 参数\"}")
                return
            }
            if (!LongRunningTaskController.isValidAction(action)) {
                res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"action 不合法，应为 pause|resume|change_goal|add_constraint\"}")
                return
            }

            let content = LongRunningTaskController.strField(body, "content")

            let result = service.intervene(taskId, action, content, userId)
            this.respondValue(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] intervene error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.3 GET /tree/:rootId ────────────────────────────────────

    /**
     * 查询任务树。
     *
     * 响应体：根节点数组(根不存在时为空数组);单根任务返回单元素数组,
     * 便于前端统一按数组渲染。
     */
    public func getTree(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let rootIdOpt = req.pathParam("rootId")
            if (rootIdOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 rootId 参数\"}")
                return
            }
            let rootId = rootIdOpt.getOrThrow()
            if (rootId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 rootId 参数\"}")
                return
            }

            let result = service.getTaskTreeJson(rootId, userId)
            this.respondArray(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] getTree error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.4 GET /progress/:taskId ────────────────────────────────

    /**
     * 查询任务进度。
     *
     * 响应体字段(spec §9.1)：`completedSteps` / `totalSteps` / `currentStep` /
     * `intermediateResult` / `goalAchievement` / `estimatedRemainingMs` /
     * `progressPercent`。
     *
     * 注意 `estimatedRemainingMs` 在缺乏基线时输出 `null` 而非 `0`
     * ： `0` 会被前端误读成"已完成",语义上必须区分。
     */
    public func getProgress(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let taskIdOpt = req.pathParam("taskId")
            if (taskIdOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }
            let taskId = taskIdOpt.getOrThrow()
            if (taskId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }

            let result = service.getProgress(taskId, userId)
            this.respondObject(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] getProgress error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.5 GET /checkpoints/:taskId ────────────────────────────

    /**
     * 查询检查点列表。
     *
     * 说明：检查点在库里按 **agentId** 归集(`CheckpointManager.listCheckpoints`),
     * 这里先由 taskId 反查 agentId 再查。同一 Agent 跑多个任务时会看到共享的
     * 检查点集,返回值里带 `taskId`/`agentId` 两个字段以便前端区分。
     *
     * 分页参数：`?page=1&pageSize=10`
     */
    public func getCheckpoints(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let taskIdOpt = req.pathParam("taskId")
            if (taskIdOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }
            let taskId = taskIdOpt.getOrThrow()
            if (taskId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }

            let page = LongRunningTaskController.intOf(req, "page", 1)
            let pageSize = LongRunningTaskController.intOf(req, "pageSize", 10)

            let result = service.listCheckpoints(taskId, page, pageSize, userId)
            this.respondObject(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] getCheckpoints error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.6 POST /verify/:taskId ─────────────────────────────────

    /** 触发验证：把任务当前产出交给插件的 `lrt-verify` 做目标达成判定。 */
    public func verify(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            var taskId = LongRunningTaskController.queryOf(req, "taskId")
            if (let Some(p) <- req.pathParam("taskId")) {
                if (!p.isEmpty()) {
                    taskId = p
                }
            }
            if (taskId.isEmpty()) {
                taskId = LongRunningTaskController.strField(LongRunningTaskController.bodyObj(req), "taskId")
            }
            if (taskId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }

            let result = service.triggerVerify(taskId, userId)
            this.respondValue(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] verify error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.7 POST /evolve/:agentId ────────────────────────────────

    /** 触发 Agent 自进化：由插件的 `lrt-evolve` 基于历史执行记录生成改进建议。 */
    public func evolve(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            var agentId = LongRunningTaskController.queryOf(req, "agentId")
            if (let Some(p) <- req.pathParam("agentId")) {
                if (!p.isEmpty()) {
                    agentId = p
                }
            }
            if (agentId.isEmpty()) {
                agentId = LongRunningTaskController.strField(LongRunningTaskController.bodyObj(req), "agentId")
            }
            if (agentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 agentId 参数\"}")
                return
            }

            let result = service.triggerEvolve(agentId, userId)
            this.respondValue(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] evolve error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.8 POST /deliver/:taskId（Ch6.3 交付确认）───────────────

    /**
     * 用户确认交付(或放弃任务)。forward 到插件 `lrt-deliver`。
     *
     * 这是 spec 5.6.1 规则 5 在宿主侧的唯一 HTTP 出口：任务进入 completed(status=2)
     * 必须**由用户这一请求触发**，执行器不得自说自话宣称完成。
     *
     * 请求体：`{action}`；action ∈ `confirm`(确认交付) | `abandon`(放弃)
     * 响应体：插件返回的结果(含最终 task_id / action)。
     *
     * 只做参数存在性校验，动作白名单交给 `LongTaskApiService.deliverTask`
     * ——同一套规则不写在两处，避免"一侧放行、一侧拒绝"。
     */
    public func deliver(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            var taskId = LongRunningTaskController.queryOf(req, "taskId")
            if (let Some(p) <- req.pathParam("taskId")) {
                if (!p.isEmpty()) {
                    taskId = p
                }
            }
            let body = LongRunningTaskController.bodyObj(req)
            if (taskId.isEmpty()) {
                taskId = LongRunningTaskController.strField(body, "taskId")
            }
            if (taskId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }

            var action = LongRunningTaskController.strField(body, "action")
            if (action.isEmpty()) {
                action = LongRunningTaskController.queryOf(req, "action")
            }
            if (action.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 action 参数\"}")
                return
            }

            let result = service.deliverTask(taskId, action, userId)
            this.respondValue(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] deliver error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.1.9 POST /review/:taskId（Ch6.3 评审改进）────────────────

    /**
     * 用户对验核结果提出改进要求(或放弃任务)。forward 到插件 `lrt-review`。
     *
     * 闭环的最后一段：验核报告 → 用户反馈 → 插件 `LrtPlanner.replan` → 继续执行 → 再验核。
     * 缺了它，长程任务就没有「人要求改」的回路。
     *
     * 请求体：`{action, feedback?, goal?}`；action ∈ `improve` | `abandon`
     *   - improve：feedback 作为新增约束、goal 为空时沿用原目标；
     *   - abandon：放弃任务。
     */
    public func review(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            var taskId = LongRunningTaskController.queryOf(req, "taskId")
            if (let Some(p) <- req.pathParam("taskId")) {
                if (!p.isEmpty()) {
                    taskId = p
                }
            }
            let body = LongRunningTaskController.bodyObj(req)
            if (taskId.isEmpty()) {
                taskId = LongRunningTaskController.strField(body, "taskId")
            }
            if (taskId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 taskId 参数\"}")
                return
            }

            var action = LongRunningTaskController.strField(body, "action")
            if (action.isEmpty()) {
                action = LongRunningTaskController.queryOf(req, "action")
            }
            if (action.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 action 参数\"}")
                return
            }

            let feedback = LongRunningTaskController.strField(body, "feedback")
            let goal = LongRunningTaskController.strField(body, "goal")

            let result = service.reviewTask(taskId, action, feedback, goal, userId)
            this.respondValue(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] review error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 9.3 补充：统一轨迹查询 ─────────────────────────────────────

    /**
     * 查询执行轨迹(回合日志 + 检查点合并成时间线)。
     *
     * 参数(query 或 body)：`taskId?`、`agentId?`、`traceId?`、`page?`、`pageSize?`
     * ： `taskId` 与 `agentId` 至少提供一个。
     */
    public func getTrace(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let body = LongRunningTaskController.bodyObj(req)

            var taskId = LongRunningTaskController.queryOf(req, "taskId")
            if (taskId.isEmpty()) {
                taskId = LongRunningTaskController.strField(body, "taskId")
            }
            var agentId = LongRunningTaskController.queryOf(req, "agentId")
            if (agentId.isEmpty()) {
                agentId = LongRunningTaskController.strField(body, "agentId")
            }
            let traceId = LongRunningTaskController.queryOf(req, "traceId")

            if (taskId.isEmpty() && agentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"taskId 与 agentId 至少提供一个\"}")
                return
            }

            let page = LongRunningTaskController.intOf(req, "page", 1)
            let pageSize = LongRunningTaskController.intOf(req, "pageSize", 20)

            let result = service.getTrace(taskId, agentId, traceId, page, pageSize, userId)
            this.respondObject(res, result)
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskController] getTrace error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 内部辅助 ───────────────────────────────────────────────────

    /**
     * 取登录用户;未登录时直接写 401 并返回 None。
     *
     * 返回 Option 而不是抛异常：调用方 `if (isNone()) return` 即可,
     * 避免每个 handler 里再包一层 try 来区分"未登录"与"真异常"。
     */
    private func requireUser(req: HttpRequest, res: HttpResponse): ?String {
        let userId = req.getLocals("userId")
        if (userId.isNone()) {
            res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
            return None<String>
        }
        let asStr = userId.getOrThrow() as String
        if (let Some(s) <- asStr) {
            if (s.isEmpty()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return None<String>
            }
            return Some<String>(s)
        }
        res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
        return None<String>
    }

    /**
     * 统一输出包络。
     *
     * 响应固定为 `{"success":bool,"data":...,"reason":...}`,与既有 CRUD
     * 控制器(直出实体 JSON)不同：长程任务的返回值是聚合结构而非单实体,
     * 统一包络前端更好处理。
     *
     * `APIResult<T>` 里的 T 只有 `JsonObject` / `JsonArray` / `JsonValue`
     * 三种(service 侧签名保证),所以不做泛型收敛,直接用三个具名重载
     * ： 泛型版要在 `Any` 上做类型判断,而 `Any` 上的 `is` 之后仍拿不到
     * 静态类型,等于白判一层。
     */
    private func respondObject(res: HttpResponse, result: APIResult<JsonObject>): Unit {
        if (!result.success) {
            LongRunningTaskController.writeFail(res, result.reason)
            return
        }
        let out = JsonObject()
        out.put("success", JsonBool(true))
        match (result.data) {
            case Some(d) => out.put("data", d)
            case None => out.put("data", JsonNull())
        }
        res.status(200).json(out.toString())
    }

    private func respondArray(res: HttpResponse, result: APIResult<JsonArray>): Unit {
        if (!result.success) {
            LongRunningTaskController.writeFail(res, result.reason)
            return
        }
        let out = JsonObject()
        out.put("success", JsonBool(true))
        match (result.data) {
            case Some(d) => out.put("data", d)
            case None => out.put("data", JsonArray())
        }
        res.status(200).json(out.toString())
    }

    private func respondValue(res: HttpResponse, result: APIResult<JsonValue>): Unit {
        if (!result.success) {
            LongRunningTaskController.writeFail(res, result.reason)
            return
        }
        let out = JsonObject()
        out.put("success", JsonBool(true))
        match (result.data) {
            case Some(d) => out.put("data", d)
            case None => out.put("data", JsonNull())
        }
        res.status(200).json(out.toString())
    }

    /** 失败包络：`{"success":false,"reason":"..."}` */
    private static func writeFail(res: HttpResponse, reason: ?String): Unit {
        let text = match (reason) {
            case Some(r) => r
            case None => "处理失败"
        }
        let err = JsonObject()
        err.put("success", JsonBool(false))
        err.put("reason", JsonString(text))
        res.status(400).json(err.toString())
    }

    /** 解析请求体为 JsonObject;空体或非法 JSON 返回 None。 */
    private static func parseObj(body: String): ?JsonObject {
        if (body.isEmpty()) {
            return None<JsonObject>
        }
        try {
            let parsed = JsonValue.fromStr(body)
            if (parsed is JsonObject) {
                return Some<JsonObject>(parsed.asObject())
            }
            return None<JsonObject>
        } catch (e: Exception) {
            return None<JsonObject>
        }
    }

    /** body 解析失败的宽容版：干预/验证等接口允许不带 body(参数走 path/query)。 */
    private static func bodyObj(req: HttpRequest): JsonObject {
        match (LongRunningTaskController.parseObj(req.body)) {
            case Some(o) => o
            case None => JsonObject()
        }
    }

    private static func strField(obj: JsonObject, key: String): String {
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonString) {
                    v.asString().getValue()
                } else {
                    ""
                }
            case None => ""
        }
    }

    /** 取整数字段;缺失或类型不符时返回 None(交给下游用默认值)。 */
    private static func intField(obj: JsonObject, key: String): ?Int32 {
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonInt) {
                    Some<Int32>(Int32(v.asInt().getValue()))
                } else if (v is JsonFloat) {
                    Some<Int32>(Int32(v.asFloat().getValue()))
                } else {
                    None<Int32>
                }
            case None => None<Int32>
        }
    }

    private static func strArrayField(obj: JsonObject, key: String): ArrayList<String> {
        let out = ArrayList<String>()
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonArray) {
                    for (item in v.asArray().getItems()) {
                        if (item is JsonString) {
                            let s = item.asString().getValue()
                            if (!s.isEmpty()) {
                                out.add(s)
                            }
                        }
                    }
                } else if (v is JsonString) {
                    // 容忍前端传单个字符串或逗号分隔串
                    for (part in v.asString().getValue().split(",")) {
                        let t = part.trimAscii()
                        if (!t.isEmpty()) {
                            out.add(t)
                        }
                    }
                }
            case None => ()
        }
        out
    }

    private static func queryOf(req: HttpRequest, key: String): String {
        match (req.queryParam(key)) {
            case Some(v) => v
            case None => ""
        }
    }

    /**
     * 读 query 参数并转 Int64(分页);缺失/非法/非正数时返回默认值。
     *
     * 单独开一个方法而不复用 `intField`：query 参数始终是字符串,
     * 走 `Int64.parse` 比先造 JsonObject 再取字段直接。
     */
    private static func intOf(req: HttpRequest, key: String, default: Int64): Int64 {
        let raw = LongRunningTaskController.queryOf(req, key)
        if (raw.isEmpty()) {
            return default
        }
        try {
            let v = Int64.parse(raw)
            if (v <= 0) { default } else { v }
        } catch (e: Exception) {
            default
        }
    }

    private static func isValidAction(action: String): Bool {
        action == "pause" || action == "resume" || action == "change_goal" || action == "add_constraint"
    }
}

//#endregion AutoCreateCode
