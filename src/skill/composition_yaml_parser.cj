/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.File
import stdx.encoding.json.{JsonValue, JsonObject}
import yaml4cj.yaml.decode
import magic.log.LogUtils

public class CompositionYamlParser {
    public init() {}

    public func parseFromFile(filePath: String): Option<CompositionDefinition> {
        try {
            let bytes = File.readFrom(filePath)
            let content = String.fromUtf8(bytes)
            return parseFromString(content)
        } catch (e: Exception) {
            LogUtils.error("[CompositionYamlParser] Failed to read file: ${filePath}, error: ${e.message}")
            return None
        }
    }

    public func parseFromString(content: String): Option<CompositionDefinition> {
        try {
            let yamlBytes = content.toArray()
            let parsedYaml = decode(yamlBytes)

            if (parsedYaml is JsonObject) {
                let jsonObj = (parsedYaml as JsonObject).getOrThrow()
                return CompositionDefinition.fromJsonValue(jsonObj)
            }
            return None
        } catch (e: Exception) {
            LogUtils.error("[CompositionYamlParser] Failed to parse YAML content: ${e.message}")
            return None
        }
    }

    public func validate(definition: CompositionDefinition): CompositionValidationResult {
        let result = CompositionValidationResult()

        if (definition.name.isEmpty()) {
            result.valid = false
            result.errors.add("Composition name is required")
        }

        if (definition.steps.isEmpty()) {
            result.valid = false
            result.errors.add("At least one step is required")
        }

        let stepNames = HashSet<String>()
        for (step in definition.steps) {
            if (step.name.isEmpty()) {
                result.valid = false
                result.errors.add("Step name is required")
            }
            if (step.skillName.isEmpty()) {
                result.valid = false
                result.errors.add("Step '${step.name}': skill_name is required")
            }
            if (stepNames.contains(step.name)) {
                result.valid = false
                result.errors.add("Duplicate step name: ${step.name}")
            }
            stepNames.add(step.name)

            for (dep in step.dependsOn) {
                if (!stepNames.contains(dep) && !hasStepNamed(definition.steps, dep)) {
                    result.valid = false
                    result.errors.add("Step '${step.name}' depends on unknown step: ${dep}")
                }
            }
        }

        let cycleResult = detectCycles(definition.steps)
        if (cycleResult) {
            result.valid = false
            result.errors.add("Circular dependency detected in steps")
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

    private func detectCycles(steps: ArrayList<CompositionStep>): Bool {
        let visited = HashMap<String, Int64>()
        let adjacency = HashMap<String, ArrayList<String>>()

        for (step in steps) {
            adjacency.add(step.name, step.dependsOn)
            visited.add(step.name, 0)
        }

        for (step in steps) {
            let stateOpt = visited.get(step.name)
            if (stateOpt.isSome() && stateOpt.getOrThrow() == 0) {
                if (dfsCycle(step.name, adjacency, visited)) {
                    return true
                }
            }
        }
        return false
    }

    private func dfsCycle(node: String, adjacency: HashMap<String, ArrayList<String>>, visited: HashMap<String, Int64>): Bool {
        visited.add(node, 1)
        if (let Some(deps) <- adjacency.get(node)) {
            for (dep in deps) {
                let stateOpt = visited.get(dep)
                if (stateOpt.isSome()) {
                    let state = stateOpt.getOrThrow()
                    if (state == 1) {
                        return true
                    }
                    if (state == 0) {
                        if (dfsCycle(dep, adjacency, visited)) {
                            return true
                        }
                    }
                }
            }
        }
        visited.add(node, 2)
        return false
    }
}

public class CompositionValidationResult {
    public var valid: Bool = true
    public var errors: ArrayList<String> = ArrayList<String>()
    public var warnings: ArrayList<String> = ArrayList<String>()

    public init() {}
}
