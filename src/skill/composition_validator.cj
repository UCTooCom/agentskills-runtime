/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonBool}
import magic.core.skill.Skill
import magic.log.LogUtils

public class ValidationResult {
    public var valid: Bool = true
    public var errors: ArrayList<String> = ArrayList<String>()
    public var warnings: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func addError(error: String): Unit {
        errors.add(error)
        valid = false
    }

    public func addWarning(warning: String): Unit {
        warnings.add(warning)
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("valid", JsonBool(this.valid))
        let errorsArr = JsonArray()
        for (e in this.errors) {
            errorsArr.add(JsonString(e))
        }
        map.add("errors", errorsArr)
        let warningsArr = JsonArray()
        for (w in this.warnings) {
            warningsArr.add(JsonString(w))
        }
        map.add("warnings", warningsArr)
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }

    public func merge(other: ValidationResult): Unit {
        if (!other.valid) {
            this.valid = false
        }
        for (e in other.errors) {
            this.errors.add(e)
        }
        for (w in other.warnings) {
            this.warnings.add(w)
        }
    }
}

public class CompositionValidator {
    private let _skillManager: CompositeSkillToolManager
    private let _dependencyResolver: SkillDependencyResolver

    public init(skillManager!: CompositeSkillToolManager) {
        _skillManager = skillManager
        _dependencyResolver = SkillDependencyResolver(skillManager: skillManager)
    }

    public func validate(composition: CompositionDefinition): ValidationResult {
        let result = ValidationResult()

        let nameResult = validateName(composition)
        result.merge(nameResult)

        let stepsResult = validateSteps(composition)
        result.merge(stepsResult)

        let depsResult = validateDependencies(composition)
        result.merge(depsResult)

        let skillsResult = validateSkillAvailability(composition)
        result.merge(skillsResult)

        let mappingResult = validateInputMappings(composition)
        result.merge(mappingResult)

        return result
    }

    public func validateName(composition: CompositionDefinition): ValidationResult {
        let result = ValidationResult()

        if (composition.name.isEmpty()) {
            result.addError("Composition name is required")
        }

        if (composition.name.size > 100) {
            result.addError("Composition name exceeds 100 characters")
        }

        return result
    }

    public func validateSteps(composition: CompositionDefinition): ValidationResult {
        let result = ValidationResult()

        if (composition.steps.isEmpty()) {
            result.addError("At least one step is required")
            return result
        }

        if (composition.steps.size > 20) {
            result.addWarning("Composition has more than 20 steps, which may impact performance")
        }

        let stepNames = HashMap<String, Bool>()
        for (step in composition.steps) {
            if (step.name.isEmpty()) {
                result.addError("Step name is required")
            }

            if (stepNames.contains(step.name)) {
                result.addError("Duplicate step name: ${step.name}")
            }
            stepNames.add(step.name, true)

            if (step.skillName.isEmpty()) {
                result.addError("Step '${step.name}': skill_name is required")
            }

            for (dep in step.dependsOn) {
                if (!stepNames.contains(dep) && !hasStepNamed(composition.steps, dep)) {
                    result.addError("Step '${step.name}' depends on unknown step: ${dep}")
                }
            }

            if (step.retryCount < 0) {
                result.addError("Step '${step.name}': retry_count cannot be negative")
            }

            if (let Some(timeout) <- step.timeout) {
                if (timeout <= 0) {
                    result.addError("Step '${step.name}': timeout must be positive")
                }
            }
        }

        return result
    }

    public func validateDependencies(composition: CompositionDefinition): ValidationResult {
        let result = ValidationResult()

        let depGraph = HashMap<String, ArrayList<String>>()
        for (step in composition.steps) {
            depGraph.add(step.name, step.dependsOn)
        }

        let cycleResult = _dependencyResolver.detectCycles(depGraph)
        if (cycleResult.isSome()) {
            let cycle = cycleResult.getOrThrow()
            var cycleStr = ""
            for (i in 0..cycle.size) {
                if (i > 0) {
                    cycleStr = cycleStr + " -> "
                }
                cycleStr = cycleStr + cycle[i]
            }
            result.addError("Circular dependency detected: ${cycleStr}")
        }

        let sortedSteps = topologicalSortSteps(composition.steps)
        if (sortedSteps.size != composition.steps.size && composition.steps.size > 0) {
            result.addError("Dependency graph has unresolvable cycles")
        }

        return result
    }

    public func validateSkillAvailability(composition: CompositionDefinition): ValidationResult {
        let result = ValidationResult()

        for (step in composition.steps) {
            if (!step.skillName.isEmpty()) {
                let skillOpt = _skillManager.getSkill(step.skillName)
                if (skillOpt.isNone()) {
                    result.addError("Step '${step.name}': skill '${step.skillName}' is not installed")
                }
            }
        }

        return result
    }

    public func validateInputMappings(composition: CompositionDefinition): ValidationResult {
        let result = ValidationResult()
        let stepNames = HashMap<String, Bool>()
        for (step in composition.steps) {
            stepNames.add(step.name, true)
        }

        for (step in composition.steps) {
            for ((targetKey, expression) in step.inputMapping) {
                if (expression.startsWith("${") && expression.endsWith("}")) {
                    let expr = expression[2..expression.size - 1]
                    let parts = expr.split(".")
                    if (parts.size < 2) {
                        result.addWarning("Step '${step.name}': input mapping '${expression}' may have invalid format")
                    }

                    if (parts.size >= 1) {
                        let refStepName = parts[0]
                        if (!stepNames.contains(refStepName) && !refStepName.isEmpty()) {
                            result.addError("Step '${step.name}': input mapping references unknown step '${refStepName}'")
                        }
                    }
                }
            }
        }

        return result
    }

    private func hasStepNamed(steps: ArrayList<CompositionStep>, name: String): Bool {
        for (step in steps) {
            if (step.name == name) {
                return true
            }
        }
        return false
    }

    private func topologicalSortSteps(steps: ArrayList<CompositionStep>): ArrayList<String> {
        let result = ArrayList<String>()
        let inDegree = HashMap<String, Int64>()
        let adjacency = HashMap<String, ArrayList<String>>()

        for (step in steps) {
            inDegree.add(step.name, 0)
            adjacency.add(step.name, ArrayList<String>())
        }

        for (step in steps) {
            for (dep in step.dependsOn) {
                if (adjacency.contains(dep)) {
                    if (let Some(neighbors) <- adjacency.get(dep)) {
                        neighbors.add(step.name)
                    }
                    if (let Some(deg) <- inDegree.get(step.name)) {
                        inDegree.add(step.name, deg + 1)
                    }
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
            result.add(current)

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

        return result
    }
}