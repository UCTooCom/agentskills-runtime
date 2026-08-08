/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap, HashSet}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonBool}
import magic.core.skill.Skill
import magic.log.LogUtils

public class SkillDependencyInfo {
    public var skillName: String = ""
    public var dependencies: ArrayList<String> = ArrayList<String>()
    public var isResolved: Bool = false
    public var missingDependencies: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("skill_name", JsonString(this.skillName))
        let depsArr = JsonArray()
        for (d in this.dependencies) {
            depsArr.add(JsonString(d))
        }
        map.add("dependencies", depsArr)
        map.add("is_resolved", JsonBool(this.isResolved))
        let missingArr = JsonArray()
        for (m in this.missingDependencies) {
            missingArr.add(JsonString(m))
        }
        map.add("missing_dependencies", missingArr)
        return JsonObject(map)
    }
}

public class DependencyResolutionResult {
    public var loadOrder: ArrayList<String> = ArrayList<String>()
    public var dependencyInfos: HashMap<String, SkillDependencyInfo> = HashMap<String, SkillDependencyInfo>()
    public var hasCycles: Bool = false
    public var cyclePath: ArrayList<String> = ArrayList<String>()
    public var missingSkills: ArrayList<String> = ArrayList<String>()
    public var allResolved: Bool = true

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        let orderArr = JsonArray()
        for (name in this.loadOrder) {
            orderArr.add(JsonString(name))
        }
        map.add("load_order", orderArr)
        var infosMap = HashMap<String, JsonValue>()
        for ((k, v) in this.dependencyInfos) {
            infosMap.add(k, v.toJsonValue())
        }
        map.add("dependency_infos", JsonObject(infosMap))
        map.add("has_cycles", JsonBool(this.hasCycles))
        let cycleArr = JsonArray()
        for (c in this.cyclePath) {
            cycleArr.add(JsonString(c))
        }
        map.add("cycle_path", cycleArr)
        let missingArr = JsonArray()
        for (m in this.missingSkills) {
            missingArr.add(JsonString(m))
        }
        map.add("missing_skills", missingArr)
        map.add("all_resolved", JsonBool(this.allResolved))
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }
}

public class SkillDependencyResolver {
    private let _skillManager: CompositeSkillToolManager

    public init(skillManager!: CompositeSkillToolManager) {
        _skillManager = skillManager
    }

    public func resolve(skills: ArrayList<Skill>): DependencyResolutionResult {
        let result = DependencyResolutionResult()

        let depInfos = HashMap<String, SkillDependencyInfo>()
        let depGraph = HashMap<String, ArrayList<String>>()

        for (skill in skills) {
            let info = extractDependencies(skill)
            depInfos.add(skill.name, info)
            depGraph.add(skill.name, info.dependencies)
            result.dependencyInfos.add(skill.name, info)
        }

        let cycleResult = detectCycles(depGraph)
        if (cycleResult.isSome()) {
            result.hasCycles = true
            result.allResolved = false
            let cycle = cycleResult.getOrThrow()
            for (c in cycle) {
                result.cyclePath.add(c)
            }
            LogUtils.error("[SkillDependencyResolver] Circular dependency detected: ${result.cyclePath.toString()}")
            return result
        }

        for ((skillName, info) in depInfos) {
            for (dep in info.dependencies) {
                if (_skillManager.getSkill(dep).isNone() && !depInfos.contains(dep)) {
                    info.isResolved = false
                    info.missingDependencies.add(dep)
                    if (!result.missingSkills.contains(dep)) {
                        result.missingSkills.add(dep)
                    }
                    result.allResolved = false
                }
            }
        }

        let sorted = topologicalSort(depGraph)
        for (name in sorted) {
            result.loadOrder.add(name)
        }

        return result
    }

    public func resolveSkill(skillName: String): DependencyResolutionResult {
        let skills = ArrayList<Skill>()
        collectSkillsRecursive(skillName, skills, HashSet<String>())
        return resolve(skills)
    }

    public func resolveAll(): DependencyResolutionResult {
        let skills = ArrayList<Skill>()
        for ((_, skill) in _skillManager.availableSkills) {
            skills.add(skill)
        }
        return resolve(skills)
    }

    public func getLoadOrder(skillNames: ArrayList<String>): ArrayList<String> {
        let skills = ArrayList<Skill>()
        let visited = HashSet<String>()
        for (name in skillNames) {
            if (let Some(skill) <- _skillManager.getSkill(name)) {
                collectSkillsRecursive(name, skills, visited)
            }
        }

        let result = resolve(skills)
        return result.loadOrder
    }

    public func extractDependencies(skill: Skill): SkillDependencyInfo {
        let info = SkillDependencyInfo()
        info.skillName = skill.name

        let depsStr = skill.metadata.get("dependencies")
        if (depsStr.isSome()) {
            let depList = depsStr.getOrThrow().split(",")
            for (dep in depList) {
                let trimmed = dep.trimAscii()
                if (!trimmed.isEmpty()) {
                    info.dependencies.add(trimmed)
                }
            }
        }

        let allowedTools = skill.allowedTools
        if (allowedTools.isSome()) {
            let tools = allowedTools.getOrThrow().split(" ")
            for (tool in tools) {
                let trimmed = tool.trimAscii()
                if (!trimmed.isEmpty() && trimmed != skill.name) {
                    if (!info.dependencies.contains(trimmed)) {
                        info.dependencies.add(trimmed)
                    }
                }
            }
        }

        info.isResolved = true
        for (dep in info.dependencies) {
            if (_skillManager.getSkill(dep).isNone()) {
                info.isResolved = false
                info.missingDependencies.add(dep)
            }
        }

        return info
    }

    public func detectCycles(depGraph: HashMap<String, ArrayList<String>>): Option<ArrayList<String>> {
        let visited = HashMap<String, Int64>()

        for ((node, _) in depGraph) {
            visited.add(node, 0)
        }

        for ((node, _) in depGraph) {
            let stateOpt = visited.get(node)
            if (stateOpt.isSome() && stateOpt.getOrThrow() == 0) {
                let cycleResult = dfsCycle(node, depGraph, visited, ArrayList<String>())
                if (cycleResult.isSome()) {
                    return cycleResult
                }
            }
        }
        return None
    }

    private func collectSkillsRecursive(skillName: String, collected: ArrayList<Skill>, visited: HashSet<String>): Unit {
        if (visited.contains(skillName)) {
            return
        }
        visited.add(skillName)

        if (let Some(skill) <- _skillManager.getSkill(skillName)) {
            collected.add(skill)

            let info = extractDependencies(skill)
            for (dep in info.dependencies) {
                collectSkillsRecursive(dep, collected, visited)
            }
        }
    }

    private func topologicalSort(depGraph: HashMap<String, ArrayList<String>>): ArrayList<String> {
        let result = ArrayList<String>()
        let inDegree = HashMap<String, Int64>()
        let adjacency = HashMap<String, ArrayList<String>>()

        for ((node, _) in depGraph) {
            inDegree.add(node, 0)
            adjacency.add(node, ArrayList<String>())
        }

        for ((node, deps) in depGraph) {
            for (dep in deps) {
                if (depGraph.contains(dep)) {
                    if (let Some(neighbors) <- adjacency.get(dep)) {
                        neighbors.add(node)
                    }
                    if (let Some(deg) <- inDegree.get(node)) {
                        inDegree.add(node, deg + 1)
                    }
                }
            }
        }

        let queue = ArrayList<String>()
        for ((node, _) in depGraph) {
            if (let Some(deg) <- inDegree.get(node)) {
                if (deg == 0) {
                    queue.add(node)
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

    private func dfsCycle(
        node: String,
        depGraph: HashMap<String, ArrayList<String>>,
        visited: HashMap<String, Int64>,
        path: ArrayList<String>
    ): Option<ArrayList<String>> {
        visited.add(node, 1)
        path.add(node)

        if (let Some(deps) <- depGraph.get(node)) {
            for (dep in deps) {
                let stateOpt = visited.get(dep)
                if (stateOpt.isSome()) {
                    let state = stateOpt.getOrThrow()
                    if (state == 1) {
                        let cycle = ArrayList<String>()
                        var found = false
                        for (p in path) {
                            if (p == dep) {
                                found = true
                            }
                            if (found) {
                                cycle.add(p)
                            }
                        }
                        cycle.add(dep)
                        return Some(cycle)
                    }
                    if (state == 0) {
                        let result = dfsCycle(dep, depGraph, visited, path)
                        if (result.isSome()) {
                            return result
                        }
                    }
                } else {
                    if (depGraph.contains(dep)) {
                        visited.add(dep, 0)
                        let result = dfsCycle(dep, depGraph, visited, path)
                        if (result.isSome()) {
                            return result
                        }
                    }
                }
            }
        }

        visited.add(node, 2)
        if (path.size > 0) {
            path.remove(at: path.size - 1)
        }
        return None
    }
}