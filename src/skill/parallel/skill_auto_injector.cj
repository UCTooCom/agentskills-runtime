/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.{Skill, SkillInjectionChecker, SkillManager}
import magic.log.LogUtils
import std.collection.{ArrayList, HashMap}

public class SkillAutoInjector <: SkillInjectionChecker {
    private let _contextInjector: SkillContextInjector
    private let _taskMatcher: TaskMatcher
    private let _budgetManager: BudgetManager
    private let _decisionRecorder: InjectDecisionRecorder
    private let _config: AutoInjectConfig
    private let _contentRenderer: SkillContentRenderer
    private var _injectedCache: HashMap<String, String>

    public init(
        contextInjector!: SkillContextInjector,
        taskMatcher!: TaskMatcher,
        budgetManager!: BudgetManager,
        decisionRecorder!: InjectDecisionRecorder,
        config!: AutoInjectConfig
    ) {
        _contextInjector = contextInjector
        _taskMatcher = taskMatcher
        _budgetManager = budgetManager
        _decisionRecorder = decisionRecorder
        _config = config
        _contentRenderer = SkillContentRenderer()
        _injectedCache = HashMap<String, String>()
    }

    public prop contextInjector: SkillContextInjector {
        get() { _contextInjector }
    }

    public prop config: AutoInjectConfig {
        get() { _config }
    }

    public func injectOnInitialization(sessionId: String): SkillInjectionResult {
        if (!_config.autoInjectEnabled) {
            return SkillInjectionResult()
        }

        let injectResult = _contextInjector.injectAlwaysOnSkills(sessionId)
        if (injectResult.status == SkillInjectionStatus.Failed) {
            return injectResult
        }

        if (injectResult.activeSkills.size == 0) {
            return injectResult
        }

        let activeSkillInstances = ArrayList<Skill>()
        for (name in injectResult.activeSkills) {
            let skillOpt = _contextInjector.skillManager.getSkill(name)
            if (skillOpt.isSome()) {
                activeSkillInstances.add(skillOpt.getOrThrow())
            }
        }

        let budgetResult = _budgetManager.allocateWithDegrade(
            activeSkillInstances.toArray(),
            _contextInjector.config.totalBudgetTokens
        )

        let fullSkills = ArrayList<Skill>()
        let degradedSkills = ArrayList<Skill>()
        for (skill in activeSkillInstances) {
            let levelOpt = budgetResult.contentLevels.get(skill.name)
            if (levelOpt.isSome()) {
                if (levelOpt.getOrThrow() == ContentLevel.Full) {
                    fullSkills.add(skill)
                } else {
                    degradedSkills.add(_budgetManager.degradeToFrontmatter(skill))
                }
            } else {
                fullSkills.add(skill)
            }
        }

        let renderedFull = _contentRenderer.renderMultipleSkills(fullSkills.toArray())
        let renderedDegraded = _contentRenderer.renderMultipleSkills(degradedSkills.toArray())
        let renderedContext = if (renderedFull.isEmpty()) {
            renderedDegraded
        } else if (renderedDegraded.isEmpty()) {
            renderedFull
        } else {
            renderedFull + "\n\n" + renderedDegraded
        }

        for (name in injectResult.activeSkills) {
            let cacheKey = "${sessionId}:${name}"
            _injectedCache.add(cacheKey, name)
        }

        for (name in budgetResult.allocated) {
            _decisionRecorder.logInjectionDecision(
                name, SkillLoadDecision.Loaded, "always_on_auto_inject",
                sessionId, InjectSource.AutoInit, ContentLevel.Full
            )
        }
        for (name in budgetResult.degraded) {
            _decisionRecorder.logInjectionDecision(
                name, SkillLoadDecision.Loaded, "budget_degraded",
                sessionId, InjectSource.AutoInit, ContentLevel.Frontmatter
            )
        }
        for (name in budgetResult.evicted) {
            _decisionRecorder.logInjectionDecision(
                name, SkillLoadDecision.Evicted, "budget_exceeded",
                sessionId, InjectSource.AutoInit, ContentLevel.Frontmatter
            )
        }

        return SkillInjectionResult(
            status: injectResult.status,
            injectedContext: renderedContext,
            activeSkills: injectResult.activeSkills
        )
    }

    public func injectOnUserMessage(taskDescription: String, sessionId: String): SkillInjectionResult {
        if (!_config.autoInjectEnabled || taskDescription.isEmpty()) {
            return SkillInjectionResult()
        }

        let availableSkills = _contextInjector.skillManager.availableSkills.values().toArray()
        let matchResults = _taskMatcher.matchSkills(taskDescription, availableSkills)

        if (matchResults.size == 0) {
            return SkillInjectionResult()
        }

        let matchedNames = ArrayList<String>()
        for (result in matchResults) {
            if (!_contextInjector.activeSkills.contains(result.skillName)) {
                matchedNames.add(result.skillName)
            }
        }

        if (matchedNames.size == 0) {
            return SkillInjectionResult()
        }

        let injectResult = _contextInjector.injectSkills(matchedNames.toArray(), sessionId)
        if (injectResult.status == SkillInjectionStatus.Failed) {
            return injectResult
        }

        for (name in matchedNames) {
            let cacheKey = "${sessionId}:${name}"
            _injectedCache.add(cacheKey, name)
            _decisionRecorder.logInjectionDecision(
                name, SkillLoadDecision.Loaded, "task_match_auto_inject",
                sessionId, InjectSource.AutoTaskMatch, ContentLevel.Full
            )
        }

        return injectResult
    }

    public func injectExplicit(skillName: String, sessionId: String): SkillInjectionResult {
        if (!_config.autoInjectEnabled) {
            return SkillInjectionResult()
        }

        let skillOpt = _contextInjector.skillManager.getSkill(skillName)
        if (skillOpt.isNone()) {
            LogUtils.warn("SkillAutoInjector: skill not found: ${skillName}")
            return SkillInjectionResult(
                status: SkillInjectionStatus.Failed,
                errorMessage: Some("Skill not found: ${skillName}")
            )
        }

        let injectResult = _contextInjector.injectSkills([skillName], sessionId)
        if (injectResult.status == SkillInjectionStatus.Failed) {
            return injectResult
        }

        let cacheKey = "${sessionId}:${skillName}"
        _injectedCache.add(cacheKey, skillName)
        _decisionRecorder.logInjectionDecision(
            skillName, SkillLoadDecision.Loaded, "explicit_auto_inject",
            sessionId, InjectSource.AutoInit, ContentLevel.Full
        )

        return injectResult
    }

    public static func create(skillManager: SkillManager): SkillAutoInjector {
        create(skillManager, AutoInjectConfig.default())
    }

    public static func create(skillManager: SkillManager, config: AutoInjectConfig): SkillAutoInjector {
        let parallelConfig = SkillParallelConfig.default()
        let contextInjector = SkillContextInjector(skillManager: skillManager, config: parallelConfig)
        let taskMatcher = TaskMatcher(config: config)
        let budgetManager = BudgetManager(config: parallelConfig)
        let decisionRecorder = InjectDecisionRecorder()
        return SkillAutoInjector(
            contextInjector: contextInjector,
            taskMatcher: taskMatcher,
            budgetManager: budgetManager,
            decisionRecorder: decisionRecorder,
            config: config
        )
    }

    public func isAlreadyInjected(skillName: String, sessionId: String): Bool {
        if (!_config.dedupOnReinject) {
            return false
        }
        let cacheKey = "${sessionId}:${skillName}"
        return _injectedCache.contains(cacheKey)
    }

    public func isSkillInjected(skillName: String): Bool {
        if (!_config.dedupOnReinject) {
            return false
        }
        for ((key, _) in _injectedCache) {
            if (key.endsWith(":${skillName}")) {
                return true
            }
        }
        return false
    }

    public func getInjectedCache(skillName: String, sessionId: String): Option<String> {
        let cacheKey = "${sessionId}:${skillName}"
        return _injectedCache.get(cacheKey)
    }
}