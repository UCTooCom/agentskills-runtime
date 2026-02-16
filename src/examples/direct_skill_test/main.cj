/*
 * Copyright (c) 2026 UCToo Team. All rights reserved.
 *
 * Direct test client for skill execution - no LLM required
 * This client directly tests the MCP server tools
 */

package magic.examples.direct_skill_test

import magic.core.skill.{Skill, SkillManager}
import magic.skill.application.{SkillLoadingService, SkillRegistry}
import magic.skill.domain.models.SkillManifest
import magic.skill.BaseSkill
import magic.examples.find_skills_skill.src.FindSkillsSkillFactory
import magic.examples.uctoo_api_skill.src.UctooAPISkillFactory
import std.collection.{HashMap, ArrayList}
import std.fs.{exists, Path}
import stdx.encoding.json.{JsonValue, JsonString, JsonObject, JsonArray}
import magic.log.LogUtils
import std.core.StringBuilder

class DirectSkillTestClient {
    private let _skillManager: SkillManagerImpl
    private let _skillRegistry: SkillRegistry
    private let _skillLoadingService: SkillLoadingService

    init() {
        _skillManager = SkillManagerImpl()
        _skillRegistry = SkillRegistry()
        _skillLoadingService = SkillLoadingService()
        _initializeSkillRegistry()
        _loadInstalledSkills()
    }

    private func _initializeSkillRegistry(): Unit {
        LogUtils.info("[DirectSkillTestClient] Initializing skill registry")
        _skillRegistry.registerFactory("find-skills", FindSkillsSkillFactory())
        _skillRegistry.registerFactory("uctoo-api-skill", UctooAPISkillFactory())
        LogUtils.info("[DirectSkillTestClient] Skill registry initialized")
    }

    private func _loadInstalledSkills(): Unit {
        LogUtils.info("[DirectSkillTestClient] Loading installed skills")

        let skillPaths = [
            "./skills",
            "./src/examples/find_skills_skill",
            "./src/examples/uctoo_api_skill"
        ]

        for (skillPath in skillPaths) {
            if (exists(skillPath)) {
                let skillFile = "${skillPath}/SKILL.md"
                if (exists(skillFile)) {
                    LogUtils.info("[DirectSkillTestClient] Loading skill from: ${skillFile}")
                    let manifestOpt = _skillLoadingService.loadSkillFromPath(skillFile)
                    if (manifestOpt.isSome()) {
                        _registerSkill(manifestOpt.getOrThrow())
                    }
                }
            }
        }

        let skillCount = _skillManager.availableSkills.size
        LogUtils.info("[DirectSkillTestClient] Loaded ${skillCount.toString()} skills")
    }

    private func _registerSkill(manifest: SkillManifest): Unit {
        LogUtils.info("[DirectSkillTestClient] Registering skill: ${manifest.name}")

        let skillOpt = _skillRegistry.createSkill(manifest)
        if (skillOpt.isSome()) {
            _skillManager.addSkill(skillOpt.getOrThrow())
            LogUtils.info("[DirectSkillTestClient] Successfully registered skill: ${manifest.name}")
        } else {
            let defaultSkill = BaseSkill(
                name: manifest.name,
                description: manifest.description,
                license: manifest.license,
                compatibility: manifest.compatibility,
                metadata: manifest.metadata,
                allowedTools: manifest.allowedTools,
                instructions: manifest.instructions,
                skillPath: manifest.skillPath
            )
            _skillManager.addSkill(defaultSkill)
            LogUtils.info("[DirectSkillTestClient] Registered skill with default implementation: ${manifest.name}")
        }
    }

    public func listAvailableSkills(): String {
        let skills = _skillManager.availableSkills
        let skillCount = skills.size
        let response = StringBuilder()
        response.append("{\n")
        response.append("  \"status\": \"success\",\n")
        response.append("  \"count\": ${skillCount.toString()},\n")
        response.append("  \"skills\": [\n")

        var first = true
        for ((name, skill) in skills) {
            if (!first) {
                response.append(",\n")
            }
            first = false
            response.append("    {\n")
            response.append("      \"name\": \"${name}\",\n")
            response.append("      \"description\": \"${escapeJson(skill.description)}\"\n")
            response.append("    }")
        }

        response.append("\n  ]\n")
        response.append("}")
        return response.toString()
    }

    public func executeSkill(skillId: String, parameters: String): String {
        LogUtils.info("[DirectSkillTestClient] Executing skill: ${skillId} with parameters: ${parameters}")

        let skillOpt = _skillManager.getSkill(skillId)
        if (skillOpt.isNone()) {
            return "{\"status\": \"error\", \"error\": \"Skill not found: ${skillId}\"}"
        }

        let skill = skillOpt.getOrThrow()
        let args = HashMap<String, JsonValue>()

        if (!parameters.isEmpty()) {
            try {
                let paramsJson = JsonValue.fromStr(parameters)
                match (paramsJson.kind) {
                    case JsonObject =>
                        let paramsObj = paramsJson.asObject()
                        for ((key, value) in paramsObj.getFields()) {
                            args.add(key, value)
                        }
                    case _ =>
                        args.add("query", JsonString(parameters))
                }
            } catch (jsonEx: Exception) {
                args.add("query", JsonString(parameters))
            }
        }

        try {
            let output = skill.execute(args)
            let response = StringBuilder()
            response.append("{\n")
            response.append("  \"status\": \"success\",\n")
            response.append("  \"skillId\": \"${skillId}\",\n")
            response.append("  \"output\": ${escapeJson(output)}\n")
            response.append("}")
            return response.toString()
        } catch (ex: Exception) {
            return "{\"status\": \"error\", \"error\": \"${escapeJson(ex.message)}\"}"
        }
    }

    private func escapeJson(str: String): String {
        return str.replace("\\", "\\\\")
                  .replace("\"", "\\\"")
                  .replace("\n", "\\n")
                  .replace("\r", "\\r")
                  .replace("\t", "\\t")
    }
}

class SkillManagerImpl <: SkillManager {
    private let _availableSkills: HashMap<String, Skill>
    private let _enabledSkills: ArrayList<String>

    init() {
        _availableSkills = HashMap<String, Skill>()
        _enabledSkills = ArrayList<String>()
    }

    public prop availableSkills: HashMap<String, Skill> {
        get() { _availableSkills }
    }

    public prop enabledSkills: Array<String> {
        get() { _enabledSkills.toArray() }
    }

    public func addSkill(skill: Skill): Unit {
        _availableSkills.add(skill.name, skill)
        _enabledSkills.add(skill.name)
    }

    public func delSkill(skill: Skill): Unit {
        _availableSkills.remove(skill.name)
        _enabledSkills.removeIf({ item => item == skill.name })
    }

    public func removeSkill(skillName: String): Unit {
        _availableSkills.remove(skillName)
        _enabledSkills.removeIf({ item => item == skillName })
    }

    public func enableSkill(skillName: String): Unit {
        if (_availableSkills.contains(skillName) && !_enabledSkills.contains(skillName)) {
            _enabledSkills.add(skillName)
        }
    }

    public func disableSkill(skillName: String): Unit {
        _enabledSkills.removeIf({ item => item == skillName })
    }

    public func getSkill(skillName: String): Option<Skill> {
        return _availableSkills.get(skillName)
    }

    public func isSkillEnabled(skillName: String): Bool {
        return _enabledSkills.contains(skillName)
    }
}

main() {
    println("========================================")
    println("直接技能测试客户端（无需大模型）")
    println("========================================")
    println("")

    let client = DirectSkillTestClient()

    println("测试 1: 列出所有可用技能")
    println("----------------------------------------")
    let result1 = client.listAvailableSkills()
    println("结果:")
    println(result1)
    println("")

    println("测试 2: 执行 find-skills 技能搜索 'react testing'")
    println("----------------------------------------")
    let result2 = client.executeSkill("find-skills", "{\"query\": \"react testing\"}")
    println("结果:")
    println(result2)
    println("")

    println("测试 3: 执行 find-skills 技能搜索 'pdf'")
    println("----------------------------------------")
    let result3 = client.executeSkill("find-skills", "{\"query\": \"pdf\"}")
    println("结果:")
    println(result3)
    println("")

    println("测试 4: 执行 find-skills 技能搜索 'deployment'")
    println("----------------------------------------")
    let result4 = client.executeSkill("find-skills", "{\"query\": \"deployment\"}")
    println("结果:")
    println(result4)
    println("")

    println("测试 5: 测试不存在的技能")
    println("----------------------------------------")
    let result5 = client.executeSkill("non-existent-skill", "{}")
    println("结果:")
    println(result5)
    println("")

    println("========================================")
    println("测试完成!")
    println("========================================")
}
