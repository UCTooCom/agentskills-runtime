/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.examples.uctoo_api_mcp_server.src

import magic.core.skill.{Skill, SkillManager}
import magic.skill.application.{SkillLoadingService, SkillRegistry}
import magic.examples.find_skills_skill.src.FindSkillsSkillFactory
import magic.examples.uctoo_api_skill.src.UctooAPISkillFactory
import magic.skill.domain.models.SkillManifest
import magic.skill.BaseSkill
import std.collection.{HashMap, ArrayList}
import std.fs.{exists, Path}
import magic.log.LogUtils

/**
 * Adapter for skill execution in the MCP server context.
 * Manages skill loading, registration, and execution.
 */
public class SkillExecutionAdapter {
    private static var _instance: Option<SkillExecutionAdapter> = None
    private let _skillManager: SkillManagerImpl
    private let _skillRegistry: SkillRegistry
    private let _skillLoadingService: SkillLoadingService

    private init() {
        _skillManager = SkillManagerImpl()
        _skillRegistry = SkillRegistry()
        _skillLoadingService = SkillLoadingService()

        _initializeSkillRegistry()
        _loadInstalledSkills()
    }

    /**
     * Get the singleton instance of SkillExecutionAdapter
     */
    public static func getInstance(): SkillExecutionAdapter {
        if (_instance.isNone()) {
            _instance = Some(SkillExecutionAdapter())
        }
        return _instance.getOrThrow()
    }

    /**
     * Get the skill manager
     */
    public static func getSkillManager(): SkillManager {
        return getInstance()._skillManager
    }

    /**
     * Initialize the skill registry with known skill factories
     */
    private func _initializeSkillRegistry(): Unit {
        LogUtils.info("[SkillExecutionAdapter] Initializing skill registry")

        _skillRegistry.registerFactory("find-skills", FindSkillsSkillFactory())
        _skillRegistry.registerFactory("uctoo-api-skill", UctooAPISkillFactory())

        LogUtils.info("[SkillExecutionAdapter] Skill registry initialized")
    }

    /**
     * Load installed skills from the skills directory
     */
    private func _loadInstalledSkills(): Unit {
        LogUtils.info("[SkillExecutionAdapter] Loading installed skills")

        let skillPaths = [
            "./skills",
            "../skills",
            "../../skills"
        ]

        for (skillPath in skillPaths) {
            if (exists(skillPath)) {
                LogUtils.info("[SkillExecutionAdapter] Loading skills from: ${skillPath}")
                let manifests = _skillLoadingService.loadSkillsFromDirectory(skillPath)
                for (manifest in manifests) {
                    _registerSkill(manifest)
                }
            }
        }

        let exampleSkillPath = "./src/examples/find_skills_skill"
        if (exists("${exampleSkillPath}/SKILL.md")) {
            LogUtils.info("[SkillExecutionAdapter] Loading find-skills skill from examples")
            let manifestOpt = _skillLoadingService.loadSkillFromPath("${exampleSkillPath}/SKILL.md")
            if (manifestOpt.isSome()) {
                _registerSkill(manifestOpt.getOrThrow())
            }
        }

        LogUtils.info("[SkillExecutionAdapter] Loaded ${_skillManager.availableSkills.size} skills")
    }

    /**
     * Register a skill from its manifest
     */
    private func _registerSkill(manifest: SkillManifest): Unit {
        LogUtils.info("[SkillExecutionAdapter] Registering skill: ${manifest.name}")

        let skillOpt = _skillRegistry.createSkill(manifest)
        if (skillOpt.isSome()) {
            _skillManager.addSkill(skillOpt.getOrThrow())
            LogUtils.info("[SkillExecutionAdapter] Successfully registered skill: ${manifest.name}")
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
            LogUtils.info("[SkillExecutionAdapter] Registered skill with default implementation: ${manifest.name}")
        }
    }
}

/**
 * Implementation of SkillManager interface
 */
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
