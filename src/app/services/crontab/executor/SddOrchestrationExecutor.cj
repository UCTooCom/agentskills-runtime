/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */

/**
 * SddOrchestrationExecutor（SDD 六步编排 / 异步化 / scheme = `sdd`）
 *
 * ## 为什么改走 crontab executor
 *
 * `POST /api/v1/uctoo/sdd/run-stage` 原先是**同步**的：一次子 agent chat 可能耗时
 * 数分钟，HTTP 长连接既容易被网关/客户端掐断，也无法表达"六步连跑"。
 * 参考 `LrtPluginExecutor` 的路子，把编排拆成"调度行 + 执行器"：
 *   HTTP 只负责建行 + 注册进引擎 + 立即触发一次，随即返回；
 *   真正的阶段执行在调度线程里跑，每 tick 推进一步。
 *
 * ## 职责边界
 *
 * - **每 tick 只推进一步**，然后返回；下一步由下一次 tick 继续（自续跑）。
 * - **跑完/失败都自己停表**：引擎摘除（经 `SddScheduleBridge` 函数槽）+ 库里置
 *   status=2，两步缺一不可（只摘引擎，进程重启后会复活；只改库，本进程仍会继续触发）。
 * - **失败不降级**：子 agent 缺失或执行失败时，置 status=failed 并停表，返回失败结果，
 *   不静默跳过该阶段、也不由主 agent 自己补写（T-15 红线）。
 *
 * ## 重叠防护
 *
 * 建行时写 `concurrentable = false`，`SchedulerEngine.triggerTask` 会用内存态
 * `runningTasks` 跳过重叠 tick（`SchedulerEngine.cj:226`）。进程重启该内存态清空，
 * 不存在陈旧锁。故本类被重复调用是安全的。
 *
 * ## parameters 契约（JSON 字符串）
 *
 * 必填：
 *   `feature_name` 工程唯一键（也可从 URI 路径段取，parameters 优先）
 * 可选：
 *   `stage`       指定阶段（给了就只跑这一步然后停表；不给则自动推进下一步）
 *   `question`    交给子 agent 的上下文包（Isolated 模式下全部上下文靠它）
 *   `task_id` / `parent_task_id` / `output_dir` / `user_id`
 *   `auto`        是否自动推进（默认 true；为 false 时跑完当前步即停表）
 *   `agent_id`    主 agent 定义 id —— **code 步必需**：该步由主 agent 加载编程技能
 *                 后按 SOP 执行（不派生编码子 agent），缺它时 code 步显式失败
 *   `language`    cangjie / web / app —— code 步据此选编程技能
 *                 （cangjie-coder / web-coder / app-coder，过渡期路由 fullstack-codegen / frontend-dev）
 *
 * ## 产物落盘与上下文交接（已落地）
 *
 * 每步跑完由 `SddOrchestrationService.persistArtifact` 落盘 + 登记
 * `long_running_task_artifact`（append-only，`verification_status=pending`）；
 * 下一步的 question 由框架经 `readStageArtifact` **显式读出上游产物**拼进去，
 * 不再让子 agent 各自猜前序文件名。产物按 Rune 截断（中文多字节安全）。
 *
 * 仍待补齐：产物内容的**契约校验**（T-21，回填 passed/failed）与成本账本（T-22）。
 */

package magic.app.services.crontab.executor

import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonKind}
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.app.services.bridge.{SddOrchestrationService, SddScheduleBridge, SddEventBridge}
import magic.app.services.uctoo.{SddProjectsService, CrontabService}

/**
 * `sdd://` 调度行 parameters 的解析结果。
 *
 * 放在文件顶层而非类内：本工程无类内嵌套类型的先例，且仓颉对嵌套类型的支持
 * 不该靠猜——用顶层 struct 是确定的写法。
 */
public struct SddParams {
    public let featureName: String
    public let stage: String
    public let question: String
    public let taskId: String
    public let parentTaskId: String
    public let outputDir: String
    public let userId: String
    public let auto: Bool
    /// 主 agent 定义 id：code 等直执行步用它加载主 agent（缺则显式失败）
    public let agentId: String
    /// 语言标签 cangjie/web/app：code 步选编程技能用
    public let language: String
    /// SSE 会话 ID（T-12）：进度事件推给聊天区用；为空则只走 WebSocket 广播
    public let sessionId: String
    /// 事件归属的 agent 标识（WebSocket 广播按它归档）
    public let notifyAgentId: String

    public init(
        featureName: String,
        stage: String,
        question: String,
        taskId: String,
        parentTaskId: String,
        outputDir: String,
        userId: String,
        auto: Bool,
        agentId: String,
        language: String,
        sessionId: String,
        notifyAgentId: String
    ) {
        this.featureName = featureName
        this.stage = stage
        this.question = question
        this.taskId = taskId
        this.parentTaskId = parentTaskId
        this.outputDir = outputDir
        this.userId = userId
        this.auto = auto
        this.agentId = agentId
        this.language = language
        this.sessionId = sessionId
        this.notifyAgentId = notifyAgentId
    }
}

public class SddOrchestrationExecutor <: CrontabExecutor {
    /**
     * URI scheme。与 `ExecutorRegistry.parseScheme` 的 `sdd://` 分支、
     * `SddOrchestrationService.startPipeline` 写入的 task URI **必须一致**，
     * 改一处要同步三处。
     */
    public prop scheme: String {
        get() { "sdd" }
    }

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        let uriFeature = ExecutorRegistry.parsePath(context.taskUri)
        let p = SddOrchestrationExecutor.parseParameters(context.parameters)

        let featureName = if (p.featureName.isEmpty()) { uriFeature } else { p.featureName }
        if (featureName.isEmpty()) {
            let msg = "sdd 编排缺少 feature_name: uri=${context.taskUri}, parameters=${context.parameters}"
            LogUtils.error("SddOrchestrationExecutor", msg)
            return ExecutionResult.failureResult(msg, SddOrchestrationExecutor.calcDuration(startTime), -1)
        }

        // 1) 决定本 tick 跑哪一步
        let target = if (p.stage.isEmpty()) {
            SddOrchestrationExecutor.nextStage(featureName)
        } else {
            p.stage
        }
        if (target.isEmpty()) {
            // 六步已走完（或工程已是 done）：停表并收尾
            let summary = "SDD 编排已无待执行阶段，停表: feature='${featureName}'"
            LogUtils.info("SddOrchestrationExecutor", summary)
            SddOrchestrationExecutor.stopSchedule(context.crontabId, featureName)
            return ExecutionResult.successResult(
                summary, SddOrchestrationExecutor.calcDuration(startTime), summary
            )
        }
        if (!SddOrchestrationExecutor.isKnownStage(target)) {
            let msg = "sdd 未知阶段 '${target}': feature='${featureName}'"
            LogUtils.error("SddOrchestrationExecutor", msg)
            SddOrchestrationExecutor.stopSchedule(context.crontabId, featureName)
            return ExecutionResult.failureResult(msg, SddOrchestrationExecutor.calcDuration(startTime), -1)
        }

        // 2) 执行该阶段：派生步（research/spec/design/task/test）走真派生子 agent；
        //    直执行步（code）走"主 agent + 编程技能 + SOP"（见 SERVICE 的 HOST_DIRECT_STAGES）
        let orchestration = SddOrchestrationService.withHostDispatcher()
        let question = SddOrchestrationExecutor.buildQuestion(
            p.question, featureName, target, p.outputDir, orchestration
        )
        let r = orchestration.runStage(
            target,
            featureName,
            question,
            p.userId,
            p.taskId,
            p.parentTaskId,
            p.outputDir,
            agentId: p.agentId,
            language: p.language,
            sessionId: p.sessionId,
            notifyAgentId: p.notifyAgentId
        )

        if (!r.success) {
            // 失败：标 failed + 停表。禁静默降级（T-15 红线）
            let msg = "SDD 阶段失败（已停表，不降级）: feature='${featureName}', stage='${target}', "
                + "agent='${r.agentName}', error=${r.error}"
            LogUtils.error("SddOrchestrationExecutor", msg)
            SddOrchestrationExecutor.markStatus(featureName, target, "failed", p.userId)
            SddOrchestrationExecutor.stopSchedule(context.crontabId, featureName)
            return ExecutionResult.failureResult(msg, r.durationMs, 1)
        }

        // 3) 成功：推进阶段；走到最后一步或单步/非自动模式则停表
        let isLast = SddOrchestrationExecutor.isLastStage(featureName, target)
        if (isLast) {
            SddOrchestrationExecutor.markStatus(featureName, "done", "completed", p.userId)
            let summary = "SDD 编排全部阶段完成: feature='${featureName}', 末阶段='${target}', "
                + "agent='${r.agentName}', durationMs=${r.durationMs}"
            LogUtils.info("SddOrchestrationExecutor", summary)
            SddEventBridge().pushGoalAchieved(featureName, p.sessionId, p.notifyAgentId)
            SddOrchestrationExecutor.stopSchedule(context.crontabId, featureName)
            return ExecutionResult.successResult(r.output, r.durationMs, summary)
        }

        let summary = "SDD 阶段完成: feature='${featureName}', stage='${target}', "
            + "agent='${r.agentName}', durationMs=${r.durationMs}"
        if (!p.stage.isEmpty() || !p.auto) {
            // 显式单步（给了 stage）或 auto=false：跑完这一步停在**闸口**等人决策
            // （confirm / revise / abandon，见 /api/v1/uctoo/sdd/review）。
            // 状态置 awaiting_review 而非 running——前端据此显示"待评审"而不是"进行中"。
            SddOrchestrationExecutor.markStatus(featureName, target, "awaiting_review", p.userId)
            SddEventBridge().pushReviewRequired(
                featureName, p.sessionId, p.notifyAgentId, target,
                SddOrchestrationService.gateForStage(target)
            )
            SddOrchestrationExecutor.stopSchedule(context.crontabId, featureName)
            let s2 = summary + "（已停在闸口 " + SddOrchestrationService.gateForStage(target) + "，等待人工决策）"
            LogUtils.info("SddOrchestrationExecutor", s2)
            return ExecutionResult.successResult(r.output, r.durationMs, s2)
        }

        SddOrchestrationExecutor.markStatus(featureName, target, "running", p.userId)
        LogUtils.info("SddOrchestrationExecutor", summary + "（自动推进，等待下一 tick）")
        return ExecutionResult.successResult(r.output, r.durationMs, summary)
    }

    public func validate(taskUri: String): Bool {
        // 路径段是 feature_name（比 uuid 长），放宽到 128
        let path = ExecutorRegistry.parsePath(taskUri)
        path.size > 0 && path.size <= 128
    }

    // ── 阶段推进 ─────────────────────────────────────────────────

    /**
     * 下一个待执行阶段：读 `sdd_projects.current_stage`，取其后的第一个阶段。
     *
     * `enable_research = false` 时跳过 research（COMPOSITION 的 condition 信号）。
     * 工程不存在或已是 done → 返回空串（调用方据此停表）。
     */
    private static func nextStage(featureName: String): String {
        let stages = SddOrchestrationService.STAGES
        var skipResearch = false
        var current = ""
        try {
            match (SddProjectsService().getByFeatureName(featureName)) {
                case Some(po) =>
                    current = po.currentStage
                    skipResearch = !po.enableResearch
                case None =>
                    LogUtils.warn(
                        "SddOrchestrationExecutor",
                        "sdd_projects 不存在，无法自动推进: feature='${featureName}'（请先调用 start 建工程）"
                    )
                    return ""
            }
        } catch (e: Exception) {
            LogUtils.error("SddOrchestrationExecutor", "读取工程失败: feature='${featureName}', ${e.message}")
            return ""
        }

        if (current == "done") {
            return ""
        }
        // current 为 init/空 → 从头开始
        var started = current.isEmpty() || current == "init"
        for (s in stages) {
            if (started) {
                if (skipResearch && s == "research") {
                    continue
                }
                return s
            }
            if (s == current) {
                started = true
            }
        }
        return ""
    }

    private static func isLastStage(featureName: String, stage: String): Bool {
        let tail = SddOrchestrationExecutor.nextStageAfter(stage)
        if (tail.isEmpty()) {
            return true
        }
        // tail 存在但被 enable_research 跳过（只剩 research 待跑）也算走完
        var skipResearch = false
        try {
            match (SddProjectsService().getByFeatureName(featureName)) {
                case Some(po) => skipResearch = !po.enableResearch
                case None => ()
            }
        } catch (_: Exception) {}
        if (skipResearch && tail == "research") {
            return true
        }
        false
    }

    private static func nextStageAfter(stage: String): String {
        let stages = SddOrchestrationService.STAGES
        var hit = false
        for (s in stages) {
            if (hit) {
                return s
            }
            if (s == stage) {
                hit = true
            }
        }
        ""
    }

    private static func isKnownStage(stage: String): Bool {
        for (s in SddOrchestrationService.STAGES) {
            if (s == stage) {
                return true
            }
        }
        false
    }

    /**
     * 拼本阶段的上下文包。
     *
     * 上游产物由框架**显式读取**后拼进 question（经 `readStageArtifact`），
     * 不再让子 agent 各自去 output_dir 猜前序文件名——这是六步间确定性交接的落点。
     * 产物按 Rune 截断（中文多字节安全），避免撑爆子 agent 上下文窗口。
     */
    private static func buildQuestion(
        base: String,
        featureName: String,
        stage: String,
        outputDir: String,
        orchestration: SddOrchestrationService
    ): String {
        let idx = SddOrchestrationExecutor.stageIndex(stage)
        let head = if (base.isEmpty()) {
            "请执行 SDD 六步编排中的本阶段工作。"
        } else {
            base
        }
        var tail = "\n\n[SDD 编排] 当前阶段：${stage}（第 ${idx}/6 步）；工程：${featureName}。"
        if (!outputDir.isEmpty()) {
            tail = tail + " 产物目录：${outputDir}。"
        } else {
            tail = tail + " 产物目录：specs/${featureName}/ 下（runtime 工作目录）。"
        }
        tail = tail + " 请把本阶段产物写入该目录。"

        // 上游产物：显式读取，读不到就明确说"没有"，避免子 agent 瞎猜
        var upstreamBlock = ""
        let upstream = SddOrchestrationService.previousStage(stage)
        if (!upstream.isEmpty()) {
            let upOpt = orchestration.readStageArtifact(featureName, upstream, outputDir)
            if (let Some(body) <- upOpt) {
                upstreamBlock = "\n\n[上游阶段产物 ${upstream}]\n${body}"
            } else {
                upstreamBlock = "\n\n[上游阶段产物 ${upstream}] 未找到（上游可能未产出，请按本阶段模板自行补齐前提）"
            }
        }
        head + tail + upstreamBlock
    }

    private static func stageIndex(stage: String): Int32 {
        var i: Int32 = 0
        for (s in SddOrchestrationService.STAGES) {
            i = i + 1
            if (s == stage) {
                return i
            }
        }
        0
    }

    /** 推进/标记工程状态。只走语义方法，不用通用 update（ADR-001）。 */
    private static func markStatus(featureName: String, stage: String, status: String, userId: String): Unit {
        try {
            let r = SddProjectsService().advanceStage(featureName, stage, status, userId)
            if (!r.success) {
                let why = match (r.reason) {
                    case Some(v) => v
                    case None => "unknown"
                }
                LogUtils.warn(
                    "SddOrchestrationExecutor",
                    "推进阶段失败: feature='${featureName}', stage='${stage}', status='${status}': ${why}"
                )
            }
        } catch (e: Exception) {
            LogUtils.error("SddOrchestrationExecutor", "推进阶段异常: feature='${featureName}', ${e.message}")
        }
    }

    // ── 停表 ─────────────────────────────────────────────────────

    /// 停表：引擎摘除（经函数槽）+ 库里置 status=2（禁用）。两步缺一不可。
    private static func stopSchedule(crontabId: String, featureName: String): Unit {
        if (crontabId.isEmpty()) {
            return
        }
        let engineStopped = SddScheduleBridge.stopCrontab(crontabId)
        var dbStopped = false
        try {
            let svc = CrontabService()
            match (svc.getById(crontabId).data) {
                case Some(po) =>
                    if (po.status != 2) {
                        po.status = 2
                        dbStopped = svc.update(crontabId, po).success
                        if (!dbStopped) {
                            LogUtils.warn(
                                "SddOrchestrationExecutor",
                                "停表：更新 crontab.status=2 失败: crontabId=${crontabId}"
                            )
                        }
                    } else {
                        dbStopped = true
                    }
                case None =>
                    LogUtils.warn(
                        "SddOrchestrationExecutor",
                        "停表：未找到 crontab 行: crontabId=${crontabId}, feature='${featureName}'"
                    )
            }
        } catch (e: Exception) {
            LogUtils.warn(
                "SddOrchestrationExecutor",
                "停表异常（忽略）: crontabId=${crontabId}, error=${e.message}"
            )
        }
        LogUtils.info(
            "SddOrchestrationExecutor",
            "停表完成: feature='${featureName}', crontabId=${crontabId}, engineStopped=${engineStopped}, dbDisabled=${dbStopped}"
        )
    }

    // ── parameters 解析 ──────────────────────────────────────────

    /// 解析失败一律回落空串/默认值，由调用方判空并给出明确错误——不抛异常。
    private static func parseParameters(parameters: String): SddParams {
        var featureName = ""
        var stage = ""
        var question = ""
        var taskId = ""
        var parentTaskId = ""
        var outputDir = ""
        var userId = ""
        var auto = true
        var agentId = ""
        var language = ""
        var sessionId = ""
        var notifyAgentId = ""
        if (!parameters.isEmpty()) {
            try {
                let parsed = JsonValue.fromStr(parameters)
                if (parsed is JsonObject) {
                    let obj = parsed.asObject()
                    featureName = stringField(obj, "feature_name")
                    stage = stringField(obj, "stage")
                    question = stringField(obj, "question")
                    taskId = stringField(obj, "task_id")
                    parentTaskId = stringField(obj, "parent_task_id")
                    outputDir = stringField(obj, "output_dir")
                    userId = stringField(obj, "user_id")
                    auto = boolField(obj, "auto", true)
                    agentId = stringField(obj, "agent_id")
                    language = stringField(obj, "language")
                    sessionId = stringField(obj, "session_id")
                    notifyAgentId = stringField(obj, "notify_agent_id")
                }
            } catch (_: Exception) {
                // 保持默认：parameters 是宿主自己写的，解析失败说明数据被人工改坏，
                // 此时"当作没有附加参数"比抛异常更符合调度器对执行器的期待。
            }
        }
        SddParams(featureName, stage, question, taskId, parentTaskId, outputDir, userId, auto,
            agentId, language, sessionId, notifyAgentId)
    }

    private static func stringField(obj: JsonObject, key: String): String {
        let v = obj.get(key)
        if (v.isNone()) {
            return ""
        }
        let jv = v.getOrThrow()
        match (jv.kind()) {
            case JsonKind.JsString => jv.asString().getValue()
            case _ => ""
        }
    }

    private static func boolField(obj: JsonObject, key: String, def: Bool): Bool {
        let v = obj.get(key)
        if (v.isNone()) {
            return def
        }
        let jv = v.getOrThrow()
        match (jv.kind()) {
            case JsonKind.JsBool => jv.asBool().getValue()
            case JsonKind.JsString => jv.asString().getValue() == "true"
            case _ => def
        }
    }

    private static func calcDuration(startTime: DateTime): Int64 {
        try {
            (DateTime.now() - startTime).toMilliseconds()
        } catch (_: Exception) {
            0
        }
    }
}
