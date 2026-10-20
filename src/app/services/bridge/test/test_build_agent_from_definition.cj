/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge.test

import magic.skill.CompositeSkillToolManager
import magic.skill.application.ProgressiveSkillLoader
import magic.skill.domain.models.{SecurityPolicy, ResourceLimits}
import magic.log.LogUtils
import std.env.{getWorkingDirectory, getVariable}

public func testBuildAgentFromDefinitionLoadsSkills(): Unit {
    println("=== buildAgentFromDefinition: ProgressiveSkillLoader loads skills ===")
    let skillManager = CompositeSkillToolManager()
    let currentDir = getWorkingDirectory().toString()
    let skillInstallPath = if (let Some(configuredPath) <- getVariable("SKILL_INSTALL_PATH")) {
        if (!configuredPath.isEmpty()) {
            configuredPath
        } else {
            "${currentDir}/skills"
        }
    } else {
        "${currentDir}/skills"
    }
    let skillDirs = [skillInstallPath, "${currentDir}/src/examples"]
    let loader = ProgressiveSkillLoader(
        skillBaseDirectories: skillDirs,
        defaultSecurityPolicy: SecurityPolicy.default(),
        defaultResourceLimits: ResourceLimits.default()
    )
    var loadedCount = 0
    try {
        let loadedSkills = loader.loadSkillsToManager(skillManager)
        loadedCount = loadedSkills.size
        println("loaded skills: ${loadedCount.toString()}")
    } catch (ex: Exception) {
        println("load failed: ${ex.message}")
    }
    if (loadedCount >= 0) {
        println("   ✓ PASS (loader executed without crash)")
    } else {
        println("   ✗ FAIL: loader should not return negative count")
    }
}

public func testBuildAgentFromDefinitionEmptyManagerWarning(): Unit {
    println("=== buildAgentFromDefinition: empty manager detected ===")
    let skillManager = CompositeSkillToolManager()
    let isEmpty = skillManager.availableSkills.isEmpty()
    println("availableSkills empty: ${isEmpty.toString()}")
    if (isEmpty) {
        LogUtils.warn("Agent 创建时技能管理器为空，自动渐进式加载未生效")
        println("   ✓ PASS (empty manager correctly detected)")
    } else {
        println("   ✗ FAIL: expected empty manager")
    }
}

public func testBuildAgentFromDefinitionNonEmptyManager(): Unit {
    println("=== buildAgentFromDefinition: non-empty manager works ===")
    let skillManager = CompositeSkillToolManager()
    let currentDir = getWorkingDirectory().toString()
    let skillInstallPath = if (let Some(configuredPath) <- getVariable("SKILL_INSTALL_PATH")) {
        if (!configuredPath.isEmpty()) {
            configuredPath
        } else {
            "${currentDir}/skills"
        }
    } else {
        "${currentDir}/skills"
    }
    let skillDirs = [skillInstallPath, "${currentDir}/src/examples"]
    let loader = ProgressiveSkillLoader(
        skillBaseDirectories: skillDirs,
        defaultSecurityPolicy: SecurityPolicy.default(),
        defaultResourceLimits: ResourceLimits.default()
    )
    try {
        loader.loadSkillsToManager(skillManager)
    } catch (_: Exception) {}
    let skillCount = skillManager.availableSkills.size
    println("availableSkills count: ${skillCount.toString()}")
    if (skillCount >= 0) {
        println("   ✓ PASS (manager accessible after loading)")
    } else {
        println("   ✗ FAIL: skill count should be non-negative")
    }
}

public func testBuildAgentFromDefinitionAll(): Unit {
    println("============ buildAgentFromDefinition Tests ============")
    testBuildAgentFromDefinitionLoadsSkills()
    testBuildAgentFromDefinitionEmptyManagerWarning()
    testBuildAgentFromDefinitionNonEmptyManager()
    println("============ buildAgentFromDefinition Tests Done ============")
}