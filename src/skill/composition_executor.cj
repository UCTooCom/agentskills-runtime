/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}
import magic.core.skill.Skill
import magic.log.LogUtils

public enum CompositionExecutionStatus {
    | Pending
    | Running
    | Completed
    | Failed
    | Skipped
}

public func compositionStatusToString(s: CompositionExecutionStatus): String {
    match (s) {
        case CompositionExecutionStatus.Pending => "pending"
        case CompositionExecutionStatus.Running => "running"
        case CompositionExecutionStatus.Completed => "completed"
        case CompositionExecutionStatus.Failed => "failed"
        case CompositionExecutionStatus.Skipped => "skipped"
    }
}

public func isCompositionStatus(status: CompositionExecutionStatus, target: CompositionExecutionStatus): Bool {
    match (status) {
        case CompositionExecutionStatus.Pending => match (target) {
            case CompositionExecutionStatus.Pending => true
            case _ => false
        }
        case CompositionExecutionStatus.Running => match (target) {
            case CompositionExecutionStatus.Running => true
            case _ => false
        }
        case CompositionExecutionStatus.Completed => match (target) {
            case CompositionExecutionStatus.Completed => true
            case _ => false
        }
        case CompositionExecutionStatus.Failed => match (target) {
            case CompositionExecutionStatus.Failed => true
            case _ => false
        }
        case CompositionExecutionStatus.Skipped => match (target) {
            case CompositionExecutionStatus.Skipped => true
            case _ => false
        }
    }
}

public class StepExecutionResult {
    public var stepName: String = ""
    public var status: CompositionExecutionStatus = CompositionExecutionStatus.Pending
    public var output: Option<SkillOutput> = None<SkillOutput>
    public var errorMessage: String = ""
    public var durationMs: Int64 = 0
    public var fromCache: Bool = false

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("step_name", JsonString(this.stepName))
        map.add("status", JsonString(compositionStatusToString(this.status)))
        map.add("error_message", JsonString(this.errorMessage))
        map.add("duration_ms", JsonInt(this.durationMs))
        map.add("from_cache", JsonBool(this.fromCache))
        if (let Some(out) <- this.output) {
            map.add("output", out.toJsonValue())
        }
        return JsonObject(map)
    }

}

public class CompositionResult {
    public var compositionName: String = ""
    public var status: CompositionExecutionStatus = CompositionExecutionStatus.Pending
    public var stepResults: HashMap<String, StepExecutionResult> = HashMap<String, StepExecutionResult>()
    public var finalOutput: Option<SkillOutput> = None<SkillOutput>
    public var totalDurationMs: Int64 = 0
    public var cacheHits: Int64 = 0

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("composition_name", JsonString(this.compositionName))
        map.add("status", JsonString(compositionStatusToString(this.status)))
        var stepResultsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.stepResults) {
            stepResultsMap.add(k, v.toJsonValue())
        }
        map.add("step_results", JsonObject(stepResultsMap))
        if (let Some(out) <- this.finalOutput) {
            map.add("final_output", out.toJsonValue())
        }
        map.add("total_duration_ms", JsonInt(this.totalDurationMs))
        map.add("cache_hits", JsonInt(this.cacheHits))
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }
}

public class CompositionExecutor {
    private let _skillManager: CompositeSkillToolManager
    private let _inputMapper: InputMapper
    private var _cache: HashMap<String, SkillOutput>

    public init(skillManager!: CompositeSkillToolManager) {
        _skillManager = skillManager
        _inputMapper = InputMapper()
        _cache = HashMap<String, SkillOutput>()
    }

    public func execute(composition: CompositionDefinition, input: JsonValue): Option<CompositionResult> {
        let result = CompositionResult()
        result.compositionName = composition.name
        result.status = CompositionExecutionStatus.Running

        let startTime = getCurrentTimeMs()

        let sortedSteps = topologicalSort(composition.steps)
        if (sortedSteps.isEmpty()) {
            if (composition.steps.isEmpty()) {
                LogUtils.warn("[CompositionExecutor] No steps in composition: ${composition.name}")
                result.status = CompositionExecutionStatus.Completed
                result.totalDurationMs = getCurrentTimeMs() - startTime
                return Some(result)
            }
            LogUtils.error("[CompositionExecutor] Topological sort failed, possible cycle in: ${composition.name}")
            result.status = CompositionExecutionStatus.Failed
            result.totalDurationMs = getCurrentTimeMs() - startTime
            return Some(result)
        }

        let stepOutputs = HashMap<String, SkillOutput>()
        var hasFailure = false

        for (step in sortedSteps) {
            if (hasFailure) {
                let stepResult = StepExecutionResult()
                stepResult.stepName = step.name
                stepResult.status = CompositionExecutionStatus.Skipped
                result.stepResults.add(step.name, stepResult)
                continue
            }

            let stepResult = executeStep(step, stepOutputs, input)
            result.stepResults.add(step.name, stepResult)

            if (isCompositionStatus(stepResult.status, CompositionExecutionStatus.Failed)) {
                hasFailure = true
                LogUtils.error("[CompositionExecutor] Step '${step.name}' failed: ${stepResult.errorMessage}")
            }

            if (let Some(out) <- stepResult.output) {
                stepOutputs.add(step.name, out)
            }
        }

        if (hasFailure) {
            result.status = CompositionExecutionStatus.Failed
        } else {
            result.status = CompositionExecutionStatus.Completed
            result.finalOutput = buildFinalOutput(composition, stepOutputs)
        }

        result.totalDurationMs = getCurrentTimeMs() - startTime
        result.cacheHits = countCacheHits(result)

        return Some(result)
    }

    public func executeStep(step: CompositionStep, stepOutputs: HashMap<String, SkillOutput>, globalInput: JsonValue): StepExecutionResult {
        let result = StepExecutionResult()
        result.stepName = step.name

        let stepStartTime = getCurrentTimeMs()

        var isConditionalStep = false
        match (step.stepType) {
            case StepType.Conditional => isConditionalStep = true
            case StepType.Sequential => isConditionalStep = false
            case StepType.Parallel => isConditionalStep = false
        }

        if (isConditionalStep) {
            if (let Some(condition) <- step.condition) {
                if (!evaluateCondition(condition, stepOutputs, globalInput)) {
                    result.status = CompositionExecutionStatus.Skipped
                    result.durationMs = getCurrentTimeMs() - stepStartTime
                    LogUtils.info("[CompositionExecutor] Step '${step.name}' skipped (condition not met)")
                    return result
                }
            }
        }

        let cacheKey = buildCacheKey(step, stepOutputs, globalInput)
        if (let Some(cachedOutput) <- _cache.get(cacheKey)) {
            result.status = CompositionExecutionStatus.Completed
            result.output = Some(cachedOutput)
            result.fromCache = true
            result.durationMs = getCurrentTimeMs() - stepStartTime
            LogUtils.info("[CompositionExecutor] Step '${step.name}' served from cache")
            return result
        }

        let skillInput = _inputMapper.mapStepOutputs(stepOutputs, step.inputMapping)
        if (globalInput is JsonObject) {
            let globalObj = (globalInput as JsonObject).getOrThrow()
            let fields = globalObj.getFields()
            for ((k, v) in fields) {
                skillInput.put(k, v)
            }
        }

        let skillOpt = _skillManager.getSkill(step.skillName)
        if (skillOpt.isNone()) {
            result.status = CompositionExecutionStatus.Failed
            result.errorMessage = "Skill not found: ${step.skillName}"
            result.durationMs = getCurrentTimeMs() - stepStartTime
            return result
        }

        let skill = skillOpt.getOrThrow()
        var retryCount = step.retryCount
        var lastError = ""
        var executionSuccess = false

        while (retryCount >= 0 && !executionSuccess) {
            try {
                let rawOutput = skill.execute(skillInput.data)
                let output = SkillOutput.fromRaw(rawOutput)
                result.status = CompositionExecutionStatus.Completed
                result.output = Some(output)
                _cache.add(cacheKey, output)
                executionSuccess = true
            } catch (ex: Exception) {
                lastError = ex.message
                if (retryCount > 0) {
                    LogUtils.warn("[CompositionExecutor] Step '${step.name}' failed, retrying... (${retryCount.toString()} retries left)")
                }
                retryCount = retryCount - 1
            }
        }

        if (!executionSuccess) {
            result.status = CompositionExecutionStatus.Failed
            result.errorMessage = lastError
        }

        result.durationMs = getCurrentTimeMs() - stepStartTime
        return result
    }

    public func clearCache(): Unit {
        _cache.clear()
    }

    public func getCacheSize(): Int64 {
        var count: Int64 = 0
        for (_ in _cache) {
            count = count + 1
        }
        return count
    }

    private func topologicalSort(steps: ArrayList<CompositionStep>): ArrayList<CompositionStep> {
        let result = ArrayList<CompositionStep>()
        let stepMap = HashMap<String, CompositionStep>()
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
            return ArrayList<CompositionStep>()
        }

        return result
    }

    private func evaluateCondition(condition: String, stepOutputs: HashMap<String, SkillOutput>, globalInput: JsonValue): Bool {
        if (condition.startsWith("${") && condition.endsWith("}")) {
            let expr = condition[2..condition.size - 1]
            let parts = expr.split(".")
            if (parts.size >= 2) {
                let stepName = parts[0]
                if (let Some(output) <- stepOutputs.get(stepName)) {
                    if (parts.size >= 3 && parts[1] == "output") {
                        let field = parts[2]
                        if (field == "hasErrors") {
                            return !output.hasErrors()
                        }
                        if (field == "rawOutput") {
                            return !output.rawOutput.isEmpty()
                        }
                    }
                    if (let Some(value) <- _inputMapper.resolveExpression(expr, output)) {
                        if (value is JsonBool) {
                            return (value as JsonBool).getOrThrow().getValue()
                        }
                        return true
                    }
                }
            }
        }

        if (condition == "true") {
            return true
        }
        if (condition == "false") {
            return false
        }

        LogUtils.warn("[CompositionExecutor] Cannot evaluate condition: ${condition}")
        return false
    }

    private func buildCacheKey(step: CompositionStep, stepOutputs: HashMap<String, SkillOutput>, globalInput: JsonValue): String {
        var key = step.skillName + ":" + step.name
        if (globalInput is JsonObject) {
            key = key + ":" + globalInput.toString()
        }
        for ((depName, _) in stepOutputs) {
            key = key + ":" + depName
        }
        return key
    }

    private func buildFinalOutput(composition: CompositionDefinition, stepOutputs: HashMap<String, SkillOutput>): Option<SkillOutput> {
        if (stepOutputs.isEmpty()) {
            return None
        }

        let output = SkillOutput()
        for ((stepName, stepOutput) in stepOutputs) {
            output.data.add(stepName, stepOutput.toJsonValue())
            for (f in stepOutput.files) {
                output.files.add(f)
            }
            for (e in stepOutput.errors) {
                output.errors.add(e)
            }
            for ((mk, mv) in stepOutput.metrics) {
                output.metrics.add("${stepName}_${mk}", mv)
            }
            if (!stepOutput.rawOutput.isEmpty()) {
                output.rawOutput = output.rawOutput + "\n--- ${stepName} ---\n" + stepOutput.rawOutput
            }
        }

        if (!composition.outputs.isEmpty()) {
            let mappedOutput = _inputMapper.map(output, composition.outputs)
            if (mappedOutput is JsonObject) {
                let fields = (mappedOutput as JsonObject).getOrThrow().getFields()
                for ((k, v) in fields) {
                    output.data.add(k, v)
                }
            }
        }

        return Some(output)
    }

    private func countCacheHits(result: CompositionResult): Int64 {
        var count: Int64 = 0
        for ((_, stepResult) in result.stepResults) {
            if (stepResult.fromCache) {
                count = count + 1
            }
        }
        return count
    }

    private func getCurrentTimeMs(): Int64 {
        return (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }
}