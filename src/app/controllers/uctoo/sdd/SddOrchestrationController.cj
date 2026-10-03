/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.sdd

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.uctoo.{SddProjectsService, CrontabService}
import magic.app.models.uctoo.SddProjectsPO
import magic.app.services.bridge.{SddOrchestrationService, SddStageResult, SddScheduleBridge}
import magic.app.services.crontab.SchedulerEngine
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonNull}
import magic.log.LogUtils

/**
 * SDD 六步编排的宿主侧薄路由控制器（T-09）。
 *
 * ## 为什么是"薄"
 * 六步编排的真派生落在宿主侧 `SddOrchestrationService`（tasks.md v8 架构决策：
 * 插件进程没有 `host.agent.invoke` RPC，跑不了子 agent）。这里只做三件事：
 *   登录校验 → 参数解析 → 转发给编排服务/语义化服务方法。
 * 不含任何业务规则（阶段白名单由 `SddOrchestrationService.STAGES` 一处定义，
 * 不在控制器里复制一份，避免"一侧放行、一侧拒绝"）。
 *
 * ## ADR-001
 * `sdd_projects` 不暴露通用 CRUD（add/edit/del 已注释），只留语义入口：
 *   POST /start      → upsertProject（幂等取/建）
 *   POST /run-stage  → 真派生子 agent + 推进阶段
 *   GET  /status     → 只读查询（不写）
 */
public class SddOrchestrationController {
    private let projectsService: SddProjectsService
    private let orchestration: SddOrchestrationService

    public init() {
        this.projectsService = SddProjectsService()
        this.orchestration = SddOrchestrationService.withHostDispatcher()
    }

    // ── POST /api/v1/uctoo/sdd/start ──────────────────────────────

    /**
     * 按 feature_name 幂等取/建 SDD 工程。
     *
     * 请求体：`{feature_name, title?, task_id?, enable_research?, payload?}`
     */
    public func start(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let obj = SddOrchestrationController.bodyObj(req)
            let featureName = SddOrchestrationController.strField(obj, "feature_name")
            if (featureName.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 feature_name 参数\"}")
                return
            }

            let r = this.projectsService.upsertProject(
                featureName,
                SddOrchestrationController.strField(obj, "title"),
                SddOrchestrationController.strField(obj, "task_id"),
                SddOrchestrationController.boolField(obj, "enable_research", false),
                SddOrchestrationController.strField(obj, "payload"),
                userId
            )
            if (!r.success) {
                SddOrchestrationController.writeFail(res, r.reason)
                return
            }
            match (r.data) {
                case Some(po) => SddOrchestrationController.writeData(res, SddOrchestrationController.projectJson(po))
                case None => SddOrchestrationController.writeData(res, JsonNull())
            }
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestrationController] start error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── POST /api/v1/uctoo/sdd/run-stage ──────────────────────────

    /**
     * 执行单个 SDD 阶段：真派生子 agent + 推进工程阶段。
     *
     * 请求体：`{stage, feature_name, question?, task_id?, parent_task_id?, output_dir?, agent_id?, language?, allow_missing_upstream?}`
     *
     * `question` **可选**：不传时由编排服务按异步路径同款的 `buildStageQuestion` 自动
     * 拼装（读上游阶段产物 + 产物目录引导），不要求调用方手工粘上下文。
     * 传了则作为补充说明拼在自动拼装的上下文之前。
     *
     * `stage` 非空即"指定阶段执行"（跳步）：会先过 `checkUpstream`——
     * 上游产物缺件时**直接拦下**并返回可操作的修复提示（把 output_dir 指到已落盘
     * 阶段文档的目录），除非显式 `allow_missing_upstream=true`。
     *
     * `stage=code` 时**不派生子 agent**：由主 agent 加载编程技能后按 SOP 执行，
     * 因此 `agent_id`（主 agent 定义 id）对该步是**必需**的，缺失时编排服务显式失败。
     *
     * 子 agent 缺失时编排服务**立即失败并返回 success=false**，此处不做任何降级。
     */
    public func runStage(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let obj = SddOrchestrationController.bodyObj(req)
            let stage = SddOrchestrationController.strField(obj, "stage")
            let featureName = SddOrchestrationController.strField(obj, "feature_name")
            let question = SddOrchestrationController.strField(obj, "question")
            let allowMissing = SddOrchestrationController.boolField(obj, "allow_missing_upstream", false)
            let outputDir = SddOrchestrationController.strField(obj, "output_dir")

            if (stage.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 stage 参数\"}")
                return
            }
            if (featureName.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 feature_name 参数\"}")
                return
            }
            // 阶段白名单只认 SddOrchestrationService.STAGES 一处定义
            if (!SddOrchestrationController.isKnownStage(stage)) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"未知阶段 '${stage}'\"}")
                return
            }

            // 指定阶段 = 跳步：先校验上游产物齐不齐（缺件拦下，给可操作修复提示）
            let chk = this.orchestration.checkUpstream(stage, featureName, outputDir, allowMissing: allowMissing)
            if (!chk.success) {
                let why = match (chk.reason) {
                    case Some(v) => v
                    case None => "unknown"
                }
                res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"${why}\"}")
                return
            }

            // 上下文统一由编排服务拼（question 可空）：与异步 crontab 路径同口径
            let built = this.orchestration.buildStageQuestion(question, featureName, stage, outputDir)

            let result = this.orchestration.runStage(
                stage,
                featureName,
                built,
                userId,
                SddOrchestrationController.strField(obj, "task_id"),
                SddOrchestrationController.strField(obj, "parent_task_id"),
                SddOrchestrationController.strField(obj, "output_dir"),
                agentId: SddOrchestrationController.strField(obj, "agent_id"),
                language: SddOrchestrationController.strField(obj, "language"),
                sessionId: SddOrchestrationController.strField(obj, "session_id"),
                notifyAgentId: SddOrchestrationController.strField(obj, "notify_agent_id")
            )
            SddOrchestrationController.writeData(res, SddOrchestrationController.stageResultJson(result))
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestrationController] runStage error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── POST /api/v1/uctoo/sdd/run（异步六步编排）───────────────────

    /**
     * 异步启动六步编排：建 `sdd://<feature_name>` 调度行 → 注册进引擎 → 立即触发一次，随即返回。
     *
     * 与 `run-stage` 的区别：`run-stage` **同步**跑单步（子 agent chat 多久就等多久，
     * 适合单步探针/联调）；`run` **异步**跑整条流水线（每 tick 推进一步，
     * 见 `SddOrchestrationExecutor`），HTTP 不阻塞。
     *
     * 请求体：`{feature_name, question, task_id?, parent_task_id?, output_dir?, auto?, agent_id?, language?, stage?, allow_missing_upstream?}`
     * 响应体：`{crontab_id, feature_name, async}` —— 进度另用 `status` 查询。
     *
     * `agent_id` / `language` 会原样写进调度行 parameters：跑到 code 步时要用
     * （主 agent 直执行，不派生编码子 agent），没传会导致该步失败并提示。
     *
     * `stage`（可选）= **指定阶段执行**：前面几步已确认时传 `"code"` 就只跑编码这一步，
     * 跑完停在当前闸口等人工决策，不再自动往下推。不给 stage 则按
     * `sdd_projects.current_stage` 自动推进下一步。
     * 给了 stage 会先过上游产物校验；确知上游缺件仍要跳步，传 `allow_missing_upstream=true`。
     */
    public func run(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let obj = SddOrchestrationController.bodyObj(req)
            let featureName = SddOrchestrationController.strField(obj, "feature_name")
            let question = SddOrchestrationController.strField(obj, "question")
            if (featureName.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 feature_name 参数\"}")
                return
            }
            if (question.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 question 参数（子 agent 的全部上下文靠它传递）\"}")
                return
            }

            let r = this.orchestration.startPipeline(
                featureName,
                question,
                userId,
                SddOrchestrationController.strField(obj, "task_id"),
                SddOrchestrationController.strField(obj, "parent_task_id"),
                SddOrchestrationController.strField(obj, "output_dir"),
                SddOrchestrationController.boolField(obj, "auto", true),
                agentId: SddOrchestrationController.strField(obj, "agent_id"),
                language: SddOrchestrationController.strField(obj, "language"),
                sessionId: SddOrchestrationController.strField(obj, "session_id"),
                notifyAgentId: SddOrchestrationController.strField(obj, "notify_agent_id"),
                startStage: SddOrchestrationController.strField(obj, "stage"),
                allowMissingUpstream: SddOrchestrationController.boolField(obj, "allow_missing_upstream", false)
            )
            if (!r.success) {
                SddOrchestrationController.writeFail(res, r.reason)
                return
            }
            let crontabId = match (r.data) {
                case Some(v) => v
                case None => ""
            }

            // 立即触发首 tick：否则要等到下一个分钟边界才启动。
            // concurrentable=false + 引擎内存态 runningTasks 保证与 cron tick 不重叠。
            if (!crontabId.isEmpty()) {
                spawn {
                    try {
                        match (SchedulerEngine.instance) {
                            case Some(engine) => engine.executeTask(crontabId)
                            case None =>
                                LogUtils.warn("[SddOrchestrationController] 调度引擎未初始化，本次不立即触发: crontabId=${crontabId}")
                        }
                    } catch (e: Exception) {
                        LogUtils.error("[SddOrchestrationController] 立即触发异常: crontabId=${crontabId}, ${e.message}")
                    }
                }
            }

            let out = JsonObject()
            out.put("crontab_id", JsonString(crontabId))
            out.put("feature_name", JsonString(featureName))
            out.put("async", JsonBool(true))
            SddOrchestrationController.writeData(res, out)
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestrationController] run error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── POST /api/v1/uctoo/sdd/review ──────────────────────────────

    /**
     * 闸口决策回执（T-11 / REQ-SDD-008）：confirm / revise / abandon。
     *
     * 请求体：`{feature_name, stage, decision, comment?, task_id?, crontab_id?}`
     *   - `decision=revise` 时 `task_id` 应传**新的** task id：重做用新上下文，
     *     避免子 agent 读到上一轮 `agent_contexts` 里的消息（上下文串味）。
     *   - `decision=confirm` 时给 `crontab_id` 可立即恢复被闸口停掉的调度行。
     *
     * 三种语义见 `SddOrchestrationService.applyGateDecision`；未知决策值直接 400，不猜。
     */
    public func review(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }
            let userId = userIdOpt.getOrThrow()

            let obj = SddOrchestrationController.bodyObj(req)
            let featureName = SddOrchestrationController.strField(obj, "feature_name")
            let stage = SddOrchestrationController.strField(obj, "stage")
            let decision = SddOrchestrationController.strField(obj, "decision")
            let comment = SddOrchestrationController.strField(obj, "comment")
            let taskId = SddOrchestrationController.strField(obj, "task_id")
            let crontabId = SddOrchestrationController.strField(obj, "crontab_id")

            if (featureName.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 feature_name 参数\"}")
                return
            }
            if (stage.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 stage 参数\"}")
                return
            }
            if (decision.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 decision 参数（confirm / revise / abandon）\"}")
                return
            }
            if (!SddOrchestrationController.isKnownStage(stage)) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"未知阶段 '${stage}'\"}")
                return
            }

            let r = this.orchestration.applyGateDecision(
                featureName, stage, decision, userId, comment, newTaskId: taskId
            )
            if (!r.success) {
                SddOrchestrationController.writeFail(res, r.reason)
                return
            }

            // confirm 且给了调度行：恢复被闸口停掉的表（置 1 + 重新注册 + 立即触发）
            var resumed = false
            if (decision == "confirm" && !crontabId.isEmpty()) {
                resumed = SddOrchestrationController.resumeSchedule(crontabId)
            }

            let out = JsonObject()
            out.put("feature_name", JsonString(featureName))
            out.put("stage", JsonString(stage))
            out.put("decision", JsonString(decision))
            out.put("gate", JsonString(SddOrchestrationService.gateForStage(stage)))
            out.put("resumed", JsonBool(resumed))
            out.put("message", JsonString(match (r.data) {
                case Some(v) => v
                case None => ""
            }))
            SddOrchestrationController.writeData(res, out)
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestrationController] review error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 恢复被闸口停掉的调度行：库里置 1 → 重新注册进引擎 → 立即触发一次。
     *
     * 三步缺一不可（与 `SddOrchestrationExecutor.stopSchedule` 对称）：
     * 只改库不注册，本进程引擎不知道这行；只注册不改库，重启后仍是禁用态。
     */
    private static func resumeSchedule(crontabId: String): Bool {
        try {
            let svc = CrontabService()
            match (svc.getById(crontabId).data) {
                case Some(po) =>
                    po.status = 1
                    let u = svc.update(crontabId, po)
                    if (!u.success) {
                        LogUtils.warn("[SddOrchestrationController] 恢复调度失败（库置 1 未成功）: crontabId=${crontabId}")
                        return false
                    }
                    if (!SddScheduleBridge.reloadCrontab(crontabId)) {
                        LogUtils.warn("[SddOrchestrationController] 恢复调度：重新注册引擎未成功: crontabId=${crontabId}")
                    }
                    spawn {
                        try {
                            match (SchedulerEngine.instance) {
                                case Some(engine) => engine.executeTask(crontabId)
                                case None =>
                                    LogUtils.warn("[SddOrchestrationController] 调度引擎未初始化，本次不立即触发: crontabId=${crontabId}")
                            }
                        } catch (e: Exception) {
                            LogUtils.error("[SddOrchestrationController] 恢复调度触发异常: ${e.message}")
                        }
                    }
                    true
                case None =>
                    LogUtils.warn("[SddOrchestrationController] 恢复调度：未找到 crontab 行: crontabId=${crontabId}")
                    false
            }
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestrationController] 恢复调度异常: crontabId=${crontabId}, ${e.message}")
            false
        }
    }

    // ── GET /api/v1/uctoo/sdd/status/:featureName ─────────────────

    /**
     * 只读查询工程进度（current_stage / status / round）。
     *
     * feature_name 可从 path、query 或 body 取，三处任一命中即可。
     */
    public func status(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = this.requireUser(req, res)
            if (userIdOpt.isNone()) {
                return
            }

            var featureName = SddOrchestrationController.queryOf(req, "feature_name")
            if (let Some(p) <- req.pathParam("featureName")) {
                if (!p.isEmpty()) {
                    featureName = p
                }
            }
            if (featureName.isEmpty()) {
                featureName = SddOrchestrationController.strField(SddOrchestrationController.bodyObj(req), "feature_name")
            }
            if (featureName.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少 feature_name 参数\"}")
                return
            }

            match (this.projectsService.getByFeatureName(featureName)) {
                case Some(po) => SddOrchestrationController.writeData(res, SddOrchestrationController.projectJson(po))
                case None =>
                    let out = JsonObject()
                    out.put("found", JsonBool(false))
                    out.put("feature_name", JsonString(featureName))
                    SddOrchestrationController.writeData(res, out)
            }
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestrationController] status error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    // ── 内部辅助 ───────────────────────────────────────────────────

    /** 取登录用户；未登录时直接写 401 并返回 None。 */
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

    private static func isKnownStage(stage: String): Bool {
        for (s in SddOrchestrationService.STAGES) {
            if (s == stage) {
                return true
            }
        }
        return false
    }

    /** 统一成功包络：`{"success":true,"data":...}` */
    private static func writeData(res: HttpResponse, data: JsonValue): Unit {
        let out = JsonObject()
        out.put("success", JsonBool(true))
        out.put("data", data)
        res.status(200).json(out.toString())
    }

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

    private static func stageResultJson(r: SddStageResult): JsonObject {
        let o = JsonObject()
        o.put("stage", JsonString(r.stage))
        o.put("agent_name", JsonString(r.agentName))
        o.put("success", JsonBool(r.success))
        o.put("output", JsonString(r.output))
        o.put("error", JsonString(r.error))
        o.put("duration_ms", JsonInt(r.durationMs))
        // 产物相对路径（空串=未落盘/未登记），单步探针据此核对落盘是否生效
        o.put("artifact_path", JsonString(r.artifactPath))
        o
    }

    private static func projectJson(po: SddProjectsPO): JsonObject {
        let o = JsonObject()
        o.put("id", JsonString(po.id))
        o.put("feature_name", JsonString(po.featureName))
        o.put("current_stage", JsonString(po.currentStage))
        o.put("status", JsonString(po.status))
        o.put("round", JsonInt(Int64(po.round)))
        o.put("enable_research", JsonBool(po.enableResearch))
        o.put("payload", JsonString(po.payload))
        let titleV: JsonValue = match (po.title) {
            case Some(v) => JsonString(v)
            case None => JsonNull()
        }
        o.put("title", titleV)
        let taskV: JsonValue = match (po.taskId) {
            case Some(v) => JsonString(v)
            case None => JsonNull()
        }
        o.put("task_id", taskV)
        let ownerV: JsonValue = match (po.ownerUserId) {
            case Some(v) => JsonString(v)
            case None => JsonNull()
        }
        o.put("owner_user_id", ownerV)
        o.put("found", JsonBool(true))
        o
    }

    /** body 解析失败的宽容版：status 等接口允许不带 body（参数走 path/query）。 */
    private static func bodyObj(req: HttpRequest): JsonObject {
        let body = req.body
        if (body.isEmpty()) {
            return JsonObject()
        }
        try {
            let parsed = JsonValue.fromStr(body)
            if (parsed is JsonObject) {
                return parsed.asObject()
            }
            return JsonObject()
        } catch (_: Exception) {
            return JsonObject()
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

    /** 取布尔字段；缺失或类型不符时返回 def。 */
    private static func boolField(obj: JsonObject, key: String, def: Bool): Bool {
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonBool) {
                    v.asBool().getValue()
                } else if (v is JsonString) {
                    v.asString().getValue() == "true"
                } else {
                    def
                }
            case None => def
        }
    }

    private static func queryOf(req: HttpRequest, key: String): String {
        match (req.queryParam(key)) {
            case Some(v) => v
            case None => ""
        }
    }
}
