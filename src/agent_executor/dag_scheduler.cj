/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_executor

import std.collection.{ArrayList, HashMap, HashSet}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool}
import magic.skill.CompositeSkillToolManager
import magic.context_verify.{AgentResultValidator, ValidationRetryHandler, ContextPasser, IncrementalResultPusher, AgentContext, OutputValidationRule, AgentValidationSummary, DegradationResult, ValidationStatus}
import magic.interaction.VerificationEvidenceCollector
import magic.log.LogUtils

public enum DagPlanStatus {
    | Draft
    | Scheduled
    | Running
    | Paused
    | Completed
    | Failed
    | RollingBack
}

public enum DagStepStatus {
    | Pending
    | Ready
    | Running
    | Completed
    | Failed
    | Skipped
}

public class StepResult {
    public var stepName: String = ""
    public var status: DagStepStatus = DagStepStatus.Pending
    public var output: Option<JsonValue> = None<JsonValue>
    public var errorMessage: String = ""
    public var durationMs: Int64 = 0
    public var startedAt: Option<DateTime> = None<DateTime>
    public var completedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("step_name", JsonString(this.stepName))
        map.add("status", JsonString(dagStepStatusToString(this.status)))
        if (let Some(out) <- this.output) {
            map.add("output", out)
        }
        map.add("error_message", JsonString(this.errorMessage))
        map.add("duration_ms", JsonInt(this.durationMs))
        if (let Some(sa) <- this.startedAt) {
            map.add("started_at", JsonString(sa.toString()))
        }
        if (let Some(ca) <- this.completedAt) {
            map.add("completed_at", JsonString(ca.toString()))
        }
        return JsonObject(map)
    }

    public static func dagStepStatusToString(s: DagStepStatus): String {
        match (s) {
            case DagStepStatus.Pending => "pending"
            case DagStepStatus.Ready => "ready"
            case DagStepStatus.Running => "running"
            case DagStepStatus.Completed => "completed"
            case DagStepStatus.Failed => "failed"
            case DagStepStatus.Skipped => "skipped"
        }
    }

    public static func dagPlanStatusToString(s: DagPlanStatus): String {
        match (s) {
            case DagPlanStatus.Draft => "draft"
            case DagPlanStatus.Scheduled => "scheduled"
            case DagPlanStatus.Running => "running"
            case DagPlanStatus.Paused => "paused"
            case DagPlanStatus.Completed => "completed"
            case DagPlanStatus.Failed => "failed"
            case DagPlanStatus.RollingBack => "rolling_back"
        }
    }
}

public class DagScheduleResult {
    public var planName: String = ""
    public var status: DagPlanStatus = DagPlanStatus.Draft
    public var stepResults: HashMap<String, StepResult> = HashMap<String, StepResult>()
    public var totalDurationMs: Int64 = 0
    public var completedSteps: Int64 = 0
    public var failedSteps: Int64 = 0

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("plan_name", JsonString(this.planName))
        map.add("status", JsonString(StepResult.dagPlanStatusToString(this.status)))
        var resultsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.stepResults) {
            resultsMap.add(k, v.toJsonValue())
        }
        map.add("step_results", JsonObject(resultsMap))
        map.add("total_duration_ms", JsonInt(this.totalDurationMs))
        map.add("completed_steps", JsonInt(this.completedSteps))
        map.add("failed_steps", JsonInt(this.failedSteps))
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }
}

open public class DagScheduler {
    private let _skillManager: CompositeSkillToolManager
    private var _stepStatuses: HashMap<String, DagStepStatus>
    private var _stepResults: HashMap<String, StepResult>
    private var _stepOutputs: HashMap<String, JsonValue>
    private var _validator: Option<AgentResultValidator>
    private var _retryHandler: Option<ValidationRetryHandler>
    private var _contextPasser: Option<ContextPasser>
    private var _incrementalPusher: Option<IncrementalResultPusher>
    private var _stepValidationRules: HashMap<String, ArrayList<OutputValidationRule>>

    public init(skillManager!: CompositeSkillToolManager) {
        _skillManager = skillManager
        _stepStatuses = HashMap<String, DagStepStatus>()
        _stepResults = HashMap<String, StepResult>()
        _stepOutputs = HashMap<String, JsonValue>()
        _validator = None<AgentResultValidator>
        _retryHandler = None<ValidationRetryHandler>
        _contextPasser = None<ContextPasser>
        _incrementalPusher = None<IncrementalResultPusher>
        _stepValidationRules = HashMap<String, ArrayList<OutputValidationRule>>()
    }

    public func setValidator(validator!: AgentResultValidator): Unit {
        _validator = Some(validator)
    }

    public func setRetryHandler(retryHandler!: ValidationRetryHandler): Unit {
        _retryHandler = Some(retryHandler)
    }

    public func setContextPasser(contextPasser!: ContextPasser): Unit {
        _contextPasser = Some(contextPasser)
    }

    public func setIncrementalPusher(incrementalPusher!: IncrementalResultPusher): Unit {
        _incrementalPusher = Some(incrementalPusher)
    }

    public func setStepValidationRules(stepName: String, rules: ArrayList<OutputValidationRule>): Unit {
        _stepValidationRules.add(stepName, rules)
    }

    public func schedule(config: DagConfig, input: JsonValue): Option<DagScheduleResult> {
        let result = DagScheduleResult()
        result.planName = config.name
        result.status = DagPlanStatus.Running

        let startTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()

        let sortedSteps = topologicalSort(config.steps)
        if (sortedSteps.isEmpty() && !config.steps.isEmpty()) {
            LogUtils.error("[DagScheduler] Topological sort failed for plan: ${config.name}")
            result.status = DagPlanStatus.Failed
            result.totalDurationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - startTime
            return Some(result)
        }

        for (step in config.steps) {
            _stepStatuses.add(step.name, DagStepStatus.Pending)
        }

        var hasFailure = false
        for (step in sortedSteps) {
            if (hasFailure) {
                _stepStatuses.add(step.name, DagStepStatus.Skipped)
                let stepResult = StepResult()
                stepResult.stepName = step.name
                stepResult.status = DagStepStatus.Skipped
                result.stepResults.add(step.name, stepResult)
                continue
            }

            let stepResult = executeStep(step, input)
            result.stepResults.add(step.name, stepResult)
            _stepStatuses.add(step.name, stepResult.status)

            if (let Some(out) <- stepResult.output) {
                _stepOutputs.add(step.name, out)
            }

            var isCompleted = false
            var isFailed = false
            match (stepResult.status) {
                case DagStepStatus.Completed => isCompleted = true
                case DagStepStatus.Failed => isFailed = true
                case DagStepStatus.Skipped => isCompleted = false
                case DagStepStatus.Pending => isCompleted = false
                case DagStepStatus.Ready => isCompleted = false
                case DagStepStatus.Running => isCompleted = false
            }

            if (isCompleted) {
                result.completedSteps = result.completedSteps + 1
            }
            if (isFailed) {
                result.failedSteps = result.failedSteps + 1
                hasFailure = true
                LogUtils.error("[DagScheduler] Step '${step.name}' failed: ${stepResult.errorMessage}")
            }
        }

        if (hasFailure) {
            result.status = DagPlanStatus.Failed
        } else {
            result.status = DagPlanStatus.Completed
        }

        result.totalDurationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - startTime
        return Some(result)
    }

    public func scheduleWithValidation(config: DagConfig, input: JsonValue, sessionId: Option<String>): Option<DagScheduleResult> {
        let result = DagScheduleResult()
        result.planName = config.name
        result.status = DagPlanStatus.Running

        let startTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()

        let sortedSteps = topologicalSort(config.steps)
        if (sortedSteps.isEmpty() && !config.steps.isEmpty()) {
            LogUtils.error("[DagScheduler] Topological sort failed for plan: ${config.name}")
            result.status = DagPlanStatus.Failed
            result.totalDurationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - startTime
            return Some(result)
        }

        for (step in config.steps) {
            _stepStatuses.add(step.name, DagStepStatus.Pending)
        }

        var rootContext: Option<AgentContext> = None<AgentContext>
        if (let Some(cp) <- _contextPasser) {
            rootContext = Some(cp.createContext(config.name, input, HashMap<String, String>()))
        }

        var hasFailure = false
        for (step in sortedSteps) {
            if (hasFailure) {
                _stepStatuses.add(step.name, DagStepStatus.Skipped)
                let stepResult = StepResult()
                stepResult.stepName = step.name
                stepResult.status = DagStepStatus.Skipped
                result.stepResults.add(step.name, stepResult)
                continue
            }

            if (let Some(cp) <- _contextPasser) {
                if (let Some(rc) <- rootContext) {
                    let childCtx = cp.createChildContext(rc, input)
                    if (let Some(rt) <- _stepStatuses.get(step.name)) {
                        var isPending = false
                        match (rt) {
                            case DagStepStatus.Pending => isPending = true
                            case _ => isPending = false
                        }
                        if (isPending) {
                            cp.passContext("dag_scheduler", step.targetRef, childCtx)
                        }
                    }
                }
            }

            let stepResult = executeStepWithValidation(step, input, sessionId)
            result.stepResults.add(step.name, stepResult)
            _stepStatuses.add(step.name, stepResult.status)

            if (let Some(out) <- stepResult.output) {
                _stepOutputs.add(step.name, out)
            }

            var isCompleted = false
            var isFailed = false
            match (stepResult.status) {
                case DagStepStatus.Completed => isCompleted = true
                case DagStepStatus.Failed => isFailed = true
                case DagStepStatus.Skipped => isCompleted = false
                case DagStepStatus.Pending => isCompleted = false
                case DagStepStatus.Ready => isCompleted = false
                case DagStepStatus.Running => isCompleted = false
            }

            if (isCompleted) {
                result.completedSteps = result.completedSteps + 1
            }
            if (isFailed) {
                result.failedSteps = result.failedSteps + 1
                hasFailure = true
                LogUtils.error("[DagScheduler] Step '${step.name}' failed: ${stepResult.errorMessage}")
            }

            if (let Some(pusher) <- _incrementalPusher) {
                if (let Some(sid) <- sessionId) {
                    pusher.pushIncrementalResult(sid, step.name, StepResult.dagStepStatusToString(stepResult.status), stepResult.output, stepResult.durationMs)
                }
            }
        }

        if (hasFailure) {
            result.status = DagPlanStatus.Failed
        } else {
            result.status = DagPlanStatus.Completed
        }

        result.totalDurationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - startTime
        return Some(result)
    }

    public func getReadySteps(config: DagConfig): ArrayList<StepConfig> {
        let ready = ArrayList<StepConfig>()
        for (step in config.steps) {
            let statusOpt = _stepStatuses.get(step.name)
            if (statusOpt.isNone()) {
                continue
            }
            let status = statusOpt.getOrThrow()
            var isPending = false
            match (status) {
                case DagStepStatus.Pending => isPending = true
                case DagStepStatus.Ready => isPending = false
                case DagStepStatus.Running => isPending = false
                case DagStepStatus.Completed => isPending = false
                case DagStepStatus.Failed => isPending = false
                case DagStepStatus.Skipped => isPending = false
            }
            if (!isPending) {
                continue
            }

            var allDepsCompleted = true
            for (dep in step.dependsOn) {
                let depStatusOpt = _stepStatuses.get(dep)
                if (depStatusOpt.isNone()) {
                    allDepsCompleted = false
                    break
                }
                let depStatus = depStatusOpt.getOrThrow()
                var depIsCompleted = false
                match (depStatus) {
                    case DagStepStatus.Completed => depIsCompleted = true
                    case DagStepStatus.Pending => depIsCompleted = false
                    case DagStepStatus.Ready => depIsCompleted = false
                    case DagStepStatus.Running => depIsCompleted = false
                    case DagStepStatus.Failed => depIsCompleted = false
                    case DagStepStatus.Skipped => depIsCompleted = false
                }
                if (!depIsCompleted) {
                    allDepsCompleted = false
                }
            }
            if (allDepsCompleted) {
                ready.add(step)
            }
        }
        return ready
    }

    public func completeStep(stepName: String, output: JsonValue): Unit {
        _stepStatuses.add(stepName, DagStepStatus.Completed)
        _stepOutputs.add(stepName, output)
        LogUtils.info("[DagScheduler] Step '${stepName}' completed")
    }

    public func failStep(stepName: String, error: String): Unit {
        _stepStatuses.add(stepName, DagStepStatus.Failed)
        LogUtils.error("[DagScheduler] Step '${stepName}' failed: ${error}")
    }

    public func getStepStatus(stepName: String): Option<DagStepStatus> {
        return _stepStatuses.get(stepName)
    }

    public func getStepOutput(stepName: String): Option<JsonValue> {
        return _stepOutputs.get(stepName)
    }

    public func reset(): Unit {
        _stepStatuses.clear()
        _stepResults.clear()
        _stepOutputs.clear()
        _stepValidationRules.clear()
    }

    private func executeStepWithValidation(step: StepConfig, globalInput: JsonValue, sessionId: Option<String>): StepResult {
        let result = executeStep(step, globalInput)

        if (!isStepCompleted(result.status)) {
            return result
        }

        if (_validator.isNone()) {
            return result
        }

        let validator = _validator.getOrThrow()
        var rulesOpt = _stepValidationRules.get(step.name)
        let rules = if (rulesOpt.isSome()) {
            rulesOpt.getOrThrow()
        } else {
            ArrayList<OutputValidationRule>()
        }

        if (rules.isEmpty()) {
            return result
        }

        let statusStr = StepResult.dagStepStatusToString(result.status)
        let summary = validator.validateFromStep(statusStr, result.output, result.errorMessage, rules)

        if (let Some(pusher) <- _incrementalPusher) {
            if (let Some(sid) <- sessionId) {
                pusher.pushValidationResult(sid, step.name, summary)
            }
        }

        if (isValidationValid(summary.overallStatus)) {
            return result
        }

        if (isValidationInvalid(summary.overallStatus)) {
            if (_retryHandler.isSome()) {
                let retryHandler = _retryHandler.getOrThrow()
                var attemptCount: Int64 = 1

                while (retryHandler.shouldRetry(summary, attemptCount)) {
                    LogUtils.info("[DagScheduler] Retrying step '${step.name}' (attempt ${attemptCount.toString()})")
                    let retryResult = executeStep(step, globalInput)
                    let retryStatusStr = StepResult.dagStepStatusToString(retryResult.status)
                    let retrySummary = validator.validateFromStep(retryStatusStr, retryResult.output, retryResult.errorMessage, rules)

                    if (let Some(pusher) <- _incrementalPusher) {
                        if (let Some(sid) <- sessionId) {
                            pusher.pushValidationResult(sid, step.name, retrySummary)
                        }
                    }

                    if (isValidationValid(retrySummary.overallStatus)) {
                        return retryResult
                    }
                    if (!isValidationInvalid(retrySummary.overallStatus)) {
                        return retryResult
                    }

                    attemptCount = attemptCount + 1
                }

                LogUtils.warn("[DagScheduler] Step '${step.name}' validation retries exhausted, executing degradation")
                var context: AgentContext
                if (let Some(cp) <- _contextPasser) {
                    context = cp.createContext(step.name, globalInput, HashMap<String, String>())
                } else {
                    context = AgentContext(taskId: step.name, input: globalInput)
                }
                let degradationResult = retryHandler.executeDegradation(step.name, context)
                return degradationResultToStepResult(degradationResult)
            }

            let failResult = StepResult()
            failResult.stepName = step.name
            failResult.status = DagStepStatus.Failed
            failResult.errorMessage = "Validation failed and no retry handler configured"
            failResult.completedAt = Some(DateTime.now())
            return failResult
        }

        return result
    }

    private func degradationResultToStepResult(dr: DegradationResult): StepResult {
        let result = StepResult()
        result.stepName = dr.stepName
        result.output = dr.output
        result.errorMessage = dr.errorMessage
        result.completedAt = Some(DateTime.now())
        match (dr.statusStr) {
            case "completed" => result.status = DagStepStatus.Completed
            case "skipped" => result.status = DagStepStatus.Skipped
            case "failed" => result.status = DagStepStatus.Failed
            case "pending" => result.status = DagStepStatus.Pending
            case _ => result.status = DagStepStatus.Failed
        }
        return result
    }

    private func isValidationValid(status: ValidationStatus): Bool {
        match (status) {
            case ValidationStatus.Valid => true
            case _ => false
        }
    }

    private func isValidationInvalid(status: ValidationStatus): Bool {
        match (status) {
            case ValidationStatus.Invalid => true
            case _ => false
        }
    }

    private func isStepCompleted(status: DagStepStatus): Bool {
        match (status) {
            case DagStepStatus.Completed => true
            case _ => false
        }
    }

    private func executeStep(step: StepConfig, globalInput: JsonValue): StepResult {
        let result = StepResult()
        result.stepName = step.name
        result.startedAt = Some(DateTime.now())

        let stepStartTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()

        if (step.condition.isSome()) {
            let conditionMet = evaluateCondition(step.condition.getOrThrow())
            if (!conditionMet) {
                result.status = DagStepStatus.Skipped
                result.durationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - stepStartTime
                result.completedAt = Some(DateTime.now())
                LogUtils.info("[DagScheduler] Step '${step.name}' skipped (condition not met)")
                return result
            }
        }

        var stepTypeIsSkill = false
        var stepTypeIsCondition = false
        match (step.stepType) {
            case DagStepType.Skill => stepTypeIsSkill = true
            case DagStepType.Agent => stepTypeIsSkill = false
            case DagStepType.Condition => stepTypeIsCondition = true
            case DagStepType.Subplan => stepTypeIsSkill = false
        }

        if (stepTypeIsCondition) {
            result.status = DagStepStatus.Completed
            result.output = Some(JsonString("condition_evaluated"))
            result.durationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - stepStartTime
            result.completedAt = Some(DateTime.now())
            return result
        }

        if (stepTypeIsSkill) {
            let skillOpt = _skillManager.getSkill(step.targetRef)
            if (skillOpt.isNone()) {
                result.status = DagStepStatus.Failed
                result.errorMessage = "Skill not found: ${step.targetRef}"
                result.durationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - stepStartTime
                result.completedAt = Some(DateTime.now())
                return result
            }

            let skill = skillOpt.getOrThrow()
            var skillInput = HashMap<String, JsonValue>()
            if (globalInput is JsonObject) {
                let fields = (globalInput as JsonObject).getOrThrow().getFields()
                for ((k, v) in fields) {
                    skillInput.add(k, v)
                }
            }
            for ((k, v) in step.inputMapping) {
                if (v.startsWith("${") && v.endsWith("}")) {
                    let expr = v[2..v.size - 1]
                    let parts = expr.split(".")
                    if (parts.size >= 2) {
                        let refStep = parts[0]
                        if (let Some(stepOutput) <- _stepOutputs.get(refStep)) {
                            skillInput.add(k, stepOutput)
                        }
                    }
                } else {
                    skillInput.add(k, JsonString(v))
                }
            }

            var retryCount = step.retryCount
            var lastError = ""
            var executionSuccess = false

            while (retryCount >= 0 && !executionSuccess) {
                try {
                    let rawOutput = skill.execute(skillInput)
                    result.status = DagStepStatus.Completed
                    result.output = Some(JsonString(rawOutput))
                    executionSuccess = true
                } catch (ex: Exception) {
                    lastError = ex.message
                    retryCount = retryCount - 1
                    if (retryCount >= 0) {
                        LogUtils.warn("[DagScheduler] Step '${step.name}' failed, retrying... (${retryCount.toString()} retries left)")
                    }
                }
            }

            if (!executionSuccess) {
                result.status = DagStepStatus.Failed
                result.errorMessage = lastError
            }
        } else {
            result.status = DagStepStatus.Completed
            result.output = Some(JsonString("agent_execution_dispatched:${step.targetRef}"))
            LogUtils.info("[DagScheduler] Step '${step.name}' dispatched to agent: ${step.targetRef}")
        }

        result.durationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - stepStartTime
        result.completedAt = Some(DateTime.now())
        return result
    }

    private func evaluateCondition(condition: String): Bool {
        if (condition == "true") {
            return true
        }
        if (condition == "false") {
            return false
        }

        if (condition.startsWith("${") && condition.endsWith("}")) {
            let expr = condition[2..condition.size - 1]
            let parts = expr.split(".")
            if (parts.size >= 2) {
                let stepName = parts[0]
                if (let Some(output) <- _stepOutputs.get(stepName)) {
                    if (parts.size >= 3 && parts[1] == "status") {
                        let field = parts[2]
                        if (field == "completed") {
                            let statusOpt = _stepStatuses.get(stepName)
                            if (statusOpt.isSome()) {
                                var isCompleted = false
                                match (statusOpt.getOrThrow()) {
                                    case DagStepStatus.Completed => isCompleted = true
                                    case DagStepStatus.Pending => isCompleted = false
                                    case DagStepStatus.Ready => isCompleted = false
                                    case DagStepStatus.Running => isCompleted = false
                                    case DagStepStatus.Failed => isCompleted = false
                                    case DagStepStatus.Skipped => isCompleted = false
                                }
                                return isCompleted
                            }
                        }
                    }
                    return true
                }
            }
        }

        LogUtils.warn("[DagScheduler] Cannot evaluate condition: ${condition}")
        return false
    }

    private func topologicalSort(steps: ArrayList<StepConfig>): ArrayList<StepConfig> {
        let result = ArrayList<StepConfig>()
        let stepMap = HashMap<String, StepConfig>()
        let inDegree = HashMap<String, Int64>()
        let adjacency = HashMap<String, ArrayList<String>>()

        for (step in steps) {
            stepMap.add(step.name, step)
            inDegree.add(step.name, 0)
            adjacency.add(step.name, ArrayList<String>())
        }

        for (step in steps) {
            for (dep in step.dependsOn) {
                if (let Some(deps) <- adjacency.get(dep)) {
                    deps.add(step.name)
                }
                if (let Some(deg) <- inDegree.get(step.name)) {
                    inDegree.add(step.name, deg + 1)
                }
            }
        }

        let queue = ArrayList<String>()
        for (step in steps) {
            if (let Some(deg) <- inDegree.get(step.name)) {
                if (deg == 0) {
                    queue.add(step.name)
                }
            }
        }

        var idx = 0
        while (idx < queue.size) {
            let current = queue[idx]
            idx = idx + 1
            if (let Some(step) <- stepMap.get(current)) {
                result.add(step)
            }
            if (let Some(neighbors) <- adjacency.get(current)) {
                for (neighbor in neighbors) {
                    if (let Some(deg) <- inDegree.get(neighbor)) {
                        let newDeg = deg - 1
                        inDegree.add(neighbor, newDeg)
                        if (newDeg == 0) {
                            queue.add(neighbor)
                        }
                    }
                }
            }
        }

        if (result.size != steps.size) {
            return ArrayList<StepConfig>()
        }
        return result
    }
}