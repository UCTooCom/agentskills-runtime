/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray, JsonBool}
import magic.log.LogUtils

public class CrossLanguageStep {
    public var name: String = ""
    public var language: String = ""
    public var skillName: String = ""
    public var dependsOn: ArrayList<String> = ArrayList<String>()
    public var inputMapping: HashMap<String, String> = HashMap<String, String>()
    public var outputKey: String = ""

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("language", JsonString(this.language))
        map.add("skill_name", JsonString(this.skillName))
        var depsArr = ArrayList<JsonValue>()
        for (d in this.dependsOn) { depsArr.add(JsonString(d)) }
        map.add("depends_on", JsonArray(depsArr))
        var mappingMap = HashMap<String, JsonValue>()
        for ((k, v) in this.inputMapping) { mappingMap.add(k, JsonString(v)) }
        map.add("input_mapping", JsonObject(mappingMap))
        map.add("output_key", JsonString(this.outputKey))
        JsonObject(map)
    }
}

public class CrossLanguageRequest {
    public var languages: ArrayList<String> = ArrayList<String>()
    public var task: String = ""
    public var input: Option<JsonValue> = None<JsonValue>
    public var steps: ArrayList<CrossLanguageStep> = ArrayList<CrossLanguageStep>()
    public var background: Bool = false

    public init() {}
}

public class CrossLanguageResult {
    public var languages: ArrayList<String> = ArrayList<String>()
    public var compositionName: String = ""
    public var status: String = "pending"
    public var stepResults: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    public var finalOutput: Option<JsonValue> = None<JsonValue>
    public var crossLanguageData: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    public var startedAt: Option<DateTime> = None<DateTime>
    public var completedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        var langsArr = ArrayList<JsonValue>()
        for (l in this.languages) { langsArr.add(JsonString(l)) }
        map.add("languages", JsonArray(langsArr))
        map.add("composition_name", JsonString(this.compositionName))
        map.add("status", JsonString(this.status))
        var resultsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.stepResults) { resultsMap.add(k, v) }
        map.add("step_results", JsonObject(resultsMap))
        if (let Some(output) <- this.finalOutput) {
            map.add("final_output", output)
        }
        var dataMap = HashMap<String, JsonValue>()
        for ((k, v) in this.crossLanguageData) { dataMap.add(k, v) }
        map.add("cross_language_data", JsonObject(dataMap))
        if (let Some(sa) <- this.startedAt) {
            map.add("started_at", JsonString(sa.toString()))
        }
        if (let Some(ca) <- this.completedAt) {
            map.add("completed_at", JsonString(ca.toString()))
        }
        JsonObject(map)
    }
}

public class CrossLanguageOrchestrator {
    private let _languageOrchestrator: LanguageOrchestrator
    private let _executeComposition: (String, Option<JsonValue>, Option<String>) -> Option<JsonValue>
    private var _stepOutputs: HashMap<String, JsonValue>
    private var _completedSteps: HashMap<String, Bool>

    public init(languageOrchestrator!: LanguageOrchestrator, executeComposition!: (String, Option<JsonValue>, Option<String>) -> Option<JsonValue>) {
        _languageOrchestrator = languageOrchestrator
        _executeComposition = executeComposition
        _stepOutputs = HashMap<String, JsonValue>()
        _completedSteps = HashMap<String, Bool>()
    }

    public func orchestrate(request: CrossLanguageRequest): CrossLanguageResult {
        LogUtils.info("[CrossLanguageOrchestrator] Orchestrating cross-language: languages=${request.languages.size.toString()}, steps=${request.steps.size.toString()}")

        let result = CrossLanguageResult()
        result.languages = request.languages
        result.startedAt = Some(DateTime.now())

        _stepOutputs = HashMap<String, JsonValue>()
        _completedSteps = HashMap<String, Bool>()

        if (request.steps.size == 0) {
            result.status = "error"
            result.completedAt = Some(DateTime.now())
            LogUtils.error("[CrossLanguageOrchestrator] No steps defined")
            return result
        }

        let validationErrors = validateCrossLanguageData(request)
        if (validationErrors.size > 0) {
            result.status = "validation_error"
            result.completedAt = Some(DateTime.now())
            LogUtils.error("[CrossLanguageOrchestrator] Validation errors: ${validationErrors.size.toString()}")
            return result
        }

        var maxIterations = request.steps.size * 2
        var iteration = 0
        while (iteration < maxIterations) {
            iteration = iteration + 1
            var allCompleted = true
            var progressMade = false

            for (step in request.steps) {
                if (let Some(done) <- _completedSteps.get(step.name)) {
                    if (done) { continue }
                }
                allCompleted = false

                if (!areDependenciesMet(step)) {
                    continue
                }

                LogUtils.info("[CrossLanguageOrchestrator] Executing step: ${step.name} (${step.language})")
                let stepInput = resolveStepInput(step, request.input)
                let modelOverride = resolveModelOverride(step.language)

                let output = _executeComposition(step.skillName, Some(stepInput), modelOverride)

                if (let Some(o) <- output) {
                    _stepOutputs.add(step.name, o)
                    _completedSteps.add(step.name, true)
                    result.stepResults.add(step.name, o)

                    if (step.outputKey.size > 0) {
                        result.crossLanguageData.add(step.outputKey, o)
                    }

                    progressMade = true
                    LogUtils.info("[CrossLanguageOrchestrator] Step completed: ${step.name}")
                } else {
                    _completedSteps.add(step.name, false)
                    result.stepResults.add(step.name, JsonString("FAILED"))
                    LogUtils.error("[CrossLanguageOrchestrator] Step failed: ${step.name}")
                    progressMade = true
                }
            }

            if (allCompleted) { break }
            if (!progressMade) {
                LogUtils.error("[CrossLanguageOrchestrator] No progress made, possible circular dependency")
                break
            }
        }

        result.status = if (allStepsCompleted(request)) { "completed" } else { "partial" }
        result.compositionName = "cross_language_${request.languages.size.toString()}_steps"
        result.completedAt = Some(DateTime.now())

        if (result.stepResults.size > 0) {
            var resultsArr = ArrayList<JsonValue>()
            for ((_, v) in result.stepResults) { resultsArr.add(v) }
            result.finalOutput = Some(JsonArray(resultsArr))
        }

        LogUtils.info("[CrossLanguageOrchestrator] Orchestration ${result.status}")
        result
    }

    public func validateCrossLanguageData(request: CrossLanguageRequest): ArrayList<String> {
        let errors = ArrayList<String>()
        let stepNames = HashMap<String, Bool>()
        for (step in request.steps) {
            stepNames.add(step.name, true)
        }
        for (step in request.steps) {
            for (dep in step.dependsOn) {
                if (!stepNames.contains(dep)) {
                    errors.add("Step '${step.name}' depends on '${dep}' which does not exist")
                }
            }
            if (step.skillName.size == 0) {
                errors.add("Step '${step.name}' has no skill name defined")
            }
            if (step.language.size == 0) {
                errors.add("Step '${step.name}' has no language defined")
            }
        }
        errors
    }

    private func areDependenciesMet(step: CrossLanguageStep): Bool {
        for (dep in step.dependsOn) {
            if (let Some(done) <- _completedSteps.get(dep)) {
                if (!done) { return false }
            } else {
                return false
            }
        }
        true
    }

    private func resolveStepInput(step: CrossLanguageStep, defaultInput: Option<JsonValue>): JsonValue {
        if (step.inputMapping.size == 0) {
            if (let Some(input) <- defaultInput) { return input }
            return JsonObject()
        }

        var map = HashMap<String, JsonValue>()
        for ((targetKey, sourceRef) in step.inputMapping) {
            if (sourceRef.startsWith("${") && sourceRef.endsWith("}")) {
                let ref = sourceRef[2..(sourceRef.size - 1)]
                if (let Some(dotIdx) <- ref.indexOf(".")) {
                    let stepName = ref[0..dotIdx]
                    let outputKey = ref[(dotIdx + 1)..ref.size]
                    if (let Some(stepOutput) <- _stepOutputs.get(stepName)) {
                        if (stepOutput is JsonObject) {
                            if (let Some(val) <- stepOutput.asObject().get(outputKey)) {
                                map.add(targetKey, val)
                            }
                        }
                    }
                }
            } else {
                map.add(targetKey, JsonString(sourceRef))
            }
        }

        if (map.size == 0) {
            if (let Some(input) <- defaultInput) { return input }
        }
        JsonObject(map)
    }

    private func resolveModelOverride(language: String): Option<String> {
        let mapping = _languageOrchestrator.getMapping(language)
        if (mapping.isSome()) {
            let m = mapping.getOrThrow()
            if (m.defaultModel.size > 0) { return Some(m.defaultModel) }
        }
        None<String>
    }

    private func allStepsCompleted(request: CrossLanguageRequest): Bool {
        for (step in request.steps) {
            if (let Some(done) <- _completedSteps.get(step.name)) {
                if (!done) { return false }
            } else {
                return false
            }
        }
        true
    }
}