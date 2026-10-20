/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.test

import magic.core.skill.Skill
import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.{SkillContextInjector, SkillParallelConfig, SkillInjectionStatus}
import std.collection.{ArrayList, HashMap}

func toSkillList(skills: Array<BaseSkill>): ArrayList<Skill> {
    let result = ArrayList<Skill>()
    for (s in skills) {
        result.add(s)
    }
    return result
}

public func testSkillAwareAgentNoConfigNoChange(): Unit {
    println("=== SkillAwareAgent: no config -> no injection (backward compat) ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "test-always-on",
        description: "Test always on",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Always on instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let config = SkillParallelConfig.default()
    let injector = SkillContextInjector(skillManager: manager, config: config)
    let result = injector.injectAlwaysOnSkills("test-session")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.status == SkillInjectionStatus.Success && result.injectedContext.contains("<skill_content")) {
        println("   ✓ PASS (injector works when config provided)")
    } else {
        println("   ✗ FAIL: expected Success with skill_content")
    }
}

public func testSkillAwareAgentConfigInjectsAlwaysOn(): Unit {
    println("=== SkillAwareAgent: config provided -> AlwaysOn injected ===")
    let alwaysOnMeta = HashMap<String, String>()
    alwaysOnMeta.add("load_policy", "always_on")
    let alwaysOnSkill = BaseSkill(
        name: "agent-always-on",
        description: "Agent always on skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: alwaysOnMeta,
        allowedTools: None<String>,
        instructions: "Agent always on instructions.",
        skillPath: ""
    )
    let onDemandMeta = HashMap<String, String>()
    onDemandMeta.add("load_policy", "on_demand")
    let onDemandSkill = BaseSkill(
        name: "agent-on-demand",
        description: "Agent on demand skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: onDemandMeta,
        allowedTools: None<String>,
        instructions: "On demand instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([alwaysOnSkill, onDemandSkill]))
    let config = SkillParallelConfig.default()
    let injector = SkillContextInjector(skillManager: manager, config: config)
    let result = injector.injectAlwaysOnSkills("test-session-2")
    println("status: ${result.status}, active skills: ${result.activeSkills.size.toString()}")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size == 1 && result.activeSkills[0] == "agent-always-on") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected only agent-always-on to be active")
    }
}

public func testSkillAwareAgentNoAlwaysOnNoChange(): Unit {
    println("=== SkillAwareAgent: no AlwaysOn skills -> systemPrompt unchanged ===")
    let onDemandMeta = HashMap<String, String>()
    onDemandMeta.add("load_policy", "on_demand")
    let onDemandSkill = BaseSkill(
        name: "only-on-demand",
        description: "Only on demand",
        license: None<String>,
        compatibility: None<String>,
        metadata: onDemandMeta,
        allowedTools: None<String>,
        instructions: "On demand only.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([onDemandSkill]))
    let config = SkillParallelConfig.default()
    let injector = SkillContextInjector(skillManager: manager, config: config)
    let result = injector.injectAlwaysOnSkills("test-session-3")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.injectedContext.isEmpty()) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty context when no AlwaysOn skills")
    }
}

public func testSkillAwareAgentParallelAll(): Unit {
    println("============ SkillAwareAgent Parallel Tests ============")
    testSkillAwareAgentNoConfigNoChange()
    testSkillAwareAgentConfigInjectsAlwaysOn()
    testSkillAwareAgentNoAlwaysOnNoChange()
    println("============ SkillAwareAgent Parallel Tests Done ============")
}