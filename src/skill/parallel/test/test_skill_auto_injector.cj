/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.{SkillAutoInjector, AutoInjectConfig, SkillInjectionStatus, SkillContextInjector, TaskMatcher, BudgetManager, SkillParallelConfig, InjectDecisionRecorder}
import std.collection.HashMap

func createAutoInjector(skills: Array<BaseSkill>): SkillAutoInjector {
    createAutoInjector(skills, AutoInjectConfig())
}

func createAutoInjector(skills: Array<BaseSkill>, config: AutoInjectConfig): SkillAutoInjector {
    let manager = CompositeSkillToolManager(toSkillList(skills))
    let contextInjector = SkillContextInjector(skillManager: manager)
    let taskMatcher = TaskMatcher(config: config)
    let budgetManager = BudgetManager(config: SkillParallelConfig())
    let decisionRecorder = InjectDecisionRecorder()
    return SkillAutoInjector(
        contextInjector: contextInjector,
        taskMatcher: taskMatcher,
        budgetManager: budgetManager,
        decisionRecorder: decisionRecorder,
        config: config
    )
}

public func testInjectOnInitWithAlwaysOn(): Unit {
    println("=== Test SkillAutoInjector injectOnInitialization (with always_on) ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "always-on-skill",
        description: "Always on skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Always on instructions.",
        skillPath: ""
    )
    let injector = createAutoInjector([skill])
    let result = injector.injectOnInitialization("session-1")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.status == SkillInjectionStatus.Success && result.injectedContext.contains("<skill_content")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with skill_content in context")
    }
}

public func testInjectOnInitNoAlwaysOn(): Unit {
    println("=== Test SkillAutoInjector injectOnInitialization (no always_on) ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "on_demand")
    let skill = BaseSkill(
        name: "on-demand-skill",
        description: "On demand skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Instructions.",
        skillPath: ""
    )
    let injector = createAutoInjector([skill])
    let result = injector.injectOnInitialization("session-1")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with 0 active skills")
    }
}

public func testInjectOnUserMessageMatch(): Unit {
    println("=== Test SkillAutoInjector injectOnUserMessage (match) ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "on_demand")
    let skill = BaseSkill(
        name: "cangjie-coder",
        description: "write cangjie code for development",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Cangjie coding instructions.",
        skillPath: ""
    )
    let config = AutoInjectConfig(taskMatchThreshold: 0.3)
    let injector = createAutoInjector([skill], config)
    let result = injector.injectOnUserMessage("write cangjie code", "session-1")
    println("status: ${result.status}, activeSkills: ${result.activeSkills.size}")
    if (result.activeSkills.size > 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected matched skill to be injected")
    }
}

public func testInjectOnUserMessageNoMatch(): Unit {
    println("=== Test SkillAutoInjector injectOnUserMessage (no match) ===")
    let metadata = HashMap<String, String>()
    let skill = BaseSkill(
        name: "music-skill",
        description: "play piano music",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Music instructions.",
        skillPath: ""
    )
    let config = AutoInjectConfig(taskMatchThreshold: 0.6)
    let injector = createAutoInjector([skill], config)
    let result = injector.injectOnUserMessage("write cangjie code", "session-1")
    if (result.activeSkills.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected no match")
    }
}

public func testInjectExplicit(): Unit {
    println("=== Test SkillAutoInjector injectExplicit ===")
    let metadata = HashMap<String, String>()
    let skill = BaseSkill(
        name: "explicit-skill",
        description: "Explicit skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Explicit instructions.",
        skillPath: ""
    )
    let injector = createAutoInjector([skill])
    let result = injector.injectExplicit("explicit-skill", "session-1")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size > 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected explicit skill to be injected")
    }
}

public func testInjectExplicitNotFound(): Unit {
    println("=== Test SkillAutoInjector injectExplicit (not found) ===")
    let injector = createAutoInjector([])
    let result = injector.injectExplicit("nonexistent-skill", "session-1")
    if (result.status == SkillInjectionStatus.Failed) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Failed for nonexistent skill")
    }
}

public func testDedupCheck(): Unit {
    println("=== Test SkillAutoInjector dedup check ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "dedup-skill",
        description: "Dedup skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Dedup instructions.",
        skillPath: ""
    )
    let injector = createAutoInjector([skill])
    injector.injectOnInitialization("session-1")
    let isInjected = injector.isAlreadyInjected("dedup-skill", "session-1")
    println("isAlreadyInjected: ${isInjected}")
    if (isInjected) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected dedup-skill to be already injected")
    }
}

public func testDedupDisabled(): Unit {
    println("=== Test SkillAutoInjector dedup disabled ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "dedup-skill",
        description: "Dedup skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Dedup instructions.",
        skillPath: ""
    )
    let config = AutoInjectConfig(dedupOnReinject: false)
    let injector = createAutoInjector([skill], config)
    injector.injectOnInitialization("session-1")
    let isInjected = injector.isAlreadyInjected("dedup-skill", "session-1")
    if (!isInjected) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected dedup to be disabled")
    }
}

public func testAutoInjectDisabled(): Unit {
    println("=== Test SkillAutoInjector autoInjectEnabled=false ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "always-on-skill",
        description: "Always on skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Always on instructions.",
        skillPath: ""
    )
    let config = AutoInjectConfig(autoInjectEnabled: false)
    let injector = createAutoInjector([skill], config)
    let result = injector.injectOnInitialization("session-1")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected no injection when disabled")
    }
}

public func runAllSkillAutoInjectorTests(): Unit {
    println("========================================")
    println("SkillAutoInjector Tests")
    println("========================================")
    testInjectOnInitWithAlwaysOn()
    println("")
    testInjectOnInitNoAlwaysOn()
    println("")
    testInjectOnUserMessageMatch()
    println("")
    testInjectOnUserMessageNoMatch()
    println("")
    testInjectExplicit()
    println("")
    testInjectExplicitNotFound()
    println("")
    testDedupCheck()
    println("")
    testDedupDisabled()
    println("")
    testAutoInjectDisabled()
    println("")
    println("========================================")
    println("All SkillAutoInjector tests completed.")
    println("========================================")
}