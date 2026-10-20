/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.{Skill, SkillManager}
import magic.skill.SkillDependencyResolver
import magic.log.LogUtils
import std.collection.{ArrayList, HashMap, HashSet}

public class SkillContextInjector {
    private let _skillManager: SkillManager
    private let _dependencyResolver: SkillDependencyResolver
    private let _contentRenderer: SkillContentRenderer
    private let _catalogRenderer: SkillCatalogRenderer
    private let _conflictFilter: ConflictFilter
    private let _profileAssembler: ProfileContextAssembler
    private let _config: SkillParallelConfig
    private var _activeSkills: ArrayList<String>

    public init(
        skillManager!: SkillManager,
        config!: SkillParallelConfig = SkillParallelConfig.default()
    ) {
        _skillManager = skillManager
        _dependencyResolver = SkillDependencyResolver(skillManager: skillManager)
        _contentRenderer = SkillContentRenderer()
        _catalogRenderer = SkillCatalogRenderer()
        _conflictFilter = ConflictFilter()
        _profileAssembler = ProfileContextAssembler()
        _config = config
        _activeSkills = ArrayList<String>()
    }

    public prop activeSkills: ArrayList<String> {
        get() { _activeSkills }
    }

    public prop skillManager: SkillManager {
        get() { _skillManager }
    }

    public prop config: SkillParallelConfig {
        get() { _config }
    }

    public func injectAlwaysOnSkills(sessionId: String): SkillInjectionResult {
        let alwaysOnSkills = ArrayList<Skill>()
        for ((_, skill) in _skillManager.availableSkills) {
            let policy = SkillParallelDeclarationParser.parseLoadPolicy(skill.metadata)
            if (policy == LoadPolicy.AlwaysOn) {
                alwaysOnSkills.add(skill)
            }
        }

        if (alwaysOnSkills.size == 0) {
            return SkillInjectionResult(
                status: SkillInjectionStatus.Success,
                injectedContext: "",
                activeSkills: _activeSkills
            )
        }

        let resolveResult = _dependencyResolver.resolve(alwaysOnSkills)

        if (resolveResult.hasCycles) {
            let cyclePathStr = String.join(resolveResult.cyclePath.toArray(), delimiter: " → ")
            LogUtils.warn("SkillContextInjector: Circular dependency detected: ${cyclePathStr}")
            return SkillInjectionResult(
                status: SkillInjectionStatus.Failed,
                errorMessage: Some("Circular dependency detected: ${cyclePathStr}")
            )
        }

        if (resolveResult.missingSkills.size > 0) {
            let missingStr = String.join(resolveResult.missingSkills.toArray(), delimiter: ", ")
            LogUtils.warn("SkillContextInjector: Missing dependencies: ${missingStr}")
        }

        let activeSkillNames = ArrayList<String>()
        for (name in resolveResult.loadOrder) {
            if (!resolveResult.missingSkills.contains(name)) {
                activeSkillNames.add(name)
            }
        }

        var activeSkillInstances = ArrayList<Skill>()
        for (name in activeSkillNames) {
            let skillOpt = _skillManager.getSkill(name)
            if (skillOpt.isSome()) {
                activeSkillInstances.add(skillOpt.getOrThrow())
            }
        }

        // 阶段5：互斥过滤（开关由 config.enableConflictFilter 控制）
        if (config.enableConflictFilter) {
            activeSkillInstances = _applyConflictFilter(activeSkillInstances, resolveResult.loadOrder)
        }

        // TG21/T085：按 skill_type 分流——profile 走独立 <profile_context> 层，capability 走常规路径
        let profileSkills = ArrayList<Skill>()
        let capabilitySkills = ArrayList<Skill>()
        _separateProfileSkills(activeSkillInstances, profileSkills, capabilitySkills)
        var rendered = _contentRenderer.renderMultipleSkills(capabilitySkills.toArray())
        let profileBlock = _profileAssembler.assemble(profileSkills.toArray(), budgetTokens: _config.profileBudgetTokens)
        if (!profileBlock.isEmpty()) {
            let sb = StringBuilder()
            if (!rendered.isEmpty()) {
                sb.append(rendered)
                sb.append("\n\n")
            }
            sb.append(profileBlock)
            rendered = sb.toString()
        }

        _activeSkills = ArrayList<String>()
        for (s in activeSkillInstances) {
            _activeSkills.add(s.name)
        }

        let status = if (resolveResult.missingSkills.size > 0) {
            SkillInjectionStatus.Partial
        } else {
            SkillInjectionStatus.Success
        }

        return SkillInjectionResult(
            status: status,
            injectedContext: rendered,
            activeSkills: _activeSkills
        )
    }

    public func injectSkills(skillNames: Array<String>, sessionId: String): SkillInjectionResult {
        let requestedSkills = ArrayList<Skill>()
        for (name in skillNames) {
            if (_activeSkills.contains(name)) {
                continue
            }
            let skillOpt = _skillManager.getSkill(name)
            if (skillOpt.isSome()) {
                requestedSkills.add(skillOpt.getOrThrow())
            } else {
                LogUtils.warn("SkillContextInjector: Skill not found: ${name}")
            }
        }

        for ((_, skill) in _skillManager.availableSkills) {
            let policy = SkillParallelDeclarationParser.parseLoadPolicy(skill.metadata)
            if (policy == LoadPolicy.AlwaysOn && !_activeSkills.contains(skill.name)) {
                let alreadyIncluded = false
                for (s in requestedSkills) {
                    if (s.name == skill.name) {
                        break
                    }
                }
                requestedSkills.add(skill)
            }
        }

        if (requestedSkills.size == 0) {
            return SkillInjectionResult(
                status: SkillInjectionStatus.Success,
                injectedContext: "",
                activeSkills: _activeSkills
            )
        }

        let resolveResult = _dependencyResolver.resolve(requestedSkills)

        if (resolveResult.hasCycles) {
            let cyclePathStr = String.join(resolveResult.cyclePath.toArray(), delimiter: " → ")
            return SkillInjectionResult(
                status: SkillInjectionStatus.Failed,
                errorMessage: Some("Circular dependency detected: ${cyclePathStr}")
            )
        }

        let activeSkillNames = ArrayList<String>()
        for (name in _activeSkills) {
            activeSkillNames.add(name)
        }
        for (name in resolveResult.loadOrder) {
            if (!activeSkillNames.contains(name) && !resolveResult.missingSkills.contains(name)) {
                activeSkillNames.add(name)
            }
        }

        var activeSkillInstances = ArrayList<Skill>()
        for (name in activeSkillNames) {
            let skillOpt = _skillManager.getSkill(name)
            if (skillOpt.isSome()) {
                activeSkillInstances.add(skillOpt.getOrThrow())
            }
        }

        // 阶段5：互斥过滤（开关由 config.enableConflictFilter 控制）
        if (config.enableConflictFilter) {
            activeSkillInstances = _applyConflictFilter(activeSkillInstances, resolveResult.loadOrder)
        }

        // TG21/T085：按 skill_type 分流——profile 走独立 <profile_context> 层，capability 走常规路径
        let profileSkills = ArrayList<Skill>()
        let capabilitySkills = ArrayList<Skill>()
        _separateProfileSkills(activeSkillInstances, profileSkills, capabilitySkills)
        var rendered = _contentRenderer.renderMultipleSkills(capabilitySkills.toArray())
        let profileBlock = _profileAssembler.assemble(profileSkills.toArray(), budgetTokens: _config.profileBudgetTokens)
        if (!profileBlock.isEmpty()) {
            let sb = StringBuilder()
            if (!rendered.isEmpty()) {
                sb.append(rendered)
                sb.append("\n\n")
            }
            sb.append(profileBlock)
            rendered = sb.toString()
        }

        _activeSkills = ArrayList<String>()
        for (s in activeSkillInstances) {
            _activeSkills.add(s.name)
        }

        let status = if (resolveResult.missingSkills.size > 0) {
            SkillInjectionStatus.Partial
        } else {
            SkillInjectionStatus.Success
        }

        return SkillInjectionResult(
            status: status,
            injectedContext: rendered,
            activeSkills: _activeSkills
        )
    }

    private func _applyConflictFilter(skills: ArrayList<Skill>, loadOrder: ArrayList<String>): ArrayList<Skill> {
        if (!config.enableConflictFilter) {
            return skills
        }
        let filterResult = _conflictFilter.filter(skills.toArray(), loadOrder.toArray())
        for (ev in filterResult.evicted) {
            LogUtils.warn("SkillContextInjector: conflict evicted skill: ${ev}")
        }
        let survivedSet = HashSet<String>()
        for (s in filterResult.survived) {
            survivedSet.add(s)
        }
        let filtered = ArrayList<Skill>()
        for (s in skills) {
            if (survivedSet.contains(s.name)) {
                filtered.add(s)
            }
        }
        return filtered
    }

    private func _separateProfileSkills(
        skills: ArrayList<Skill>,
        profileOut: ArrayList<Skill>,
        capabilityOut: ArrayList<Skill>
    ): Unit {
        for (s in skills) {
            if (SkillParallelDeclarationParser.parseSkillType(s.metadata) == SkillType.Profile) {
                profileOut.add(s)
            } else {
                capabilityOut.add(s)
            }
        }
    }

    public func renderCatalog(): String {
        let activeSkillInstances = ArrayList<Skill>()
        for (name in _activeSkills) {
            let skillOpt = _skillManager.getSkill(name)
            if (skillOpt.isSome()) {
                activeSkillInstances.add(skillOpt.getOrThrow())
            }
        }
        return _catalogRenderer.renderCatalog(activeSkillInstances.toArray())
    }
}