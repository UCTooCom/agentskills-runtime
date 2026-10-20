/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.core.skill.Skill
import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.{SkillContextInjector, SkillInjectionStatus, SkillParallelConfig, LoadPolicy}
import std.collection.{ArrayList, HashMap}

public func testInjectNoAlwaysOnSkills(): Unit {
    println("=== Test injectAlwaysOnSkills (no always_on skills) ===")
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
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillContextInjector(skillManager: manager)
    let result = injector.injectAlwaysOnSkills("session-1")
    println("status: ${result.status}, activeSkills size: ${result.activeSkills.size}")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with 0 active skills")
    }
}

public func testInjectSingleAlwaysOnSkill(): Unit {
    println("=== Test injectAlwaysOnSkills (single always_on skill) ===")
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
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillContextInjector(skillManager: manager)
    let result = injector.injectAlwaysOnSkills("session-1")
    println("status: ${result.status}, activeSkills: ${result.activeSkills.size}")
    println("injectedContext contains skill_content: ${result.injectedContext.contains("<skill_content")}")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size == 1 && result.injectedContext.contains("<skill_content")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with 1 active skill and skill_content in context")
    }
}

public func testInjectMultipleAlwaysOnSkills(): Unit {
    println("=== Test injectAlwaysOnSkills (multiple always_on skills) ===")
    let metadata1 = HashMap<String, String>()
    metadata1.add("load_policy", "always_on")
    let skill1 = BaseSkill(
        name: "skill-a",
        description: "Skill A",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata1,
        allowedTools: None<String>,
        instructions: "Instructions A.",
        skillPath: ""
    )
    let metadata2 = HashMap<String, String>()
    metadata2.add("load_policy", "always_on")
    let skill2 = BaseSkill(
        name: "skill-b",
        description: "Skill B",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata2,
        allowedTools: None<String>,
        instructions: "Instructions B.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill1, skill2]))
    let injector = SkillContextInjector(skillManager: manager)
    let result = injector.injectAlwaysOnSkills("session-1")
    println("status: ${result.status}, activeSkills: ${result.activeSkills.size}")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size == 2) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with 2 active skills")
    }
}

public func testInjectExplicitSkill(): Unit {
    println("=== Test injectSkills (explicit) ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "on_demand")
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
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillContextInjector(skillManager: manager)
    let result = injector.injectSkills(["explicit-skill"], "session-1")
    println("status: ${result.status}, activeSkills: ${result.activeSkills.size}")
    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size == 1) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with 1 active skill")
    }
}

public func testRenderCatalogAfterInjection(): Unit {
    println("=== Test renderCatalog after injection ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "catalog-skill",
        description: "Catalog test skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Catalog instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillContextInjector(skillManager: manager)
    injector.injectAlwaysOnSkills("session-1")
    let catalog = injector.renderCatalog()
    println("catalog:\n${catalog}")
    if (catalog.contains("`catalog-skill`") && catalog.contains("<available_skills>")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: catalog should contain skill name and available_skills tag")
    }
}

public func testInjectProfileAndCapabilitySplit(): Unit {
    println("=== Test injectAlwaysOnSkills (profile + capability split) ===")
    let profileMeta = HashMap<String, String>()
    profileMeta.add("load_policy", "always_on")
    profileMeta.add("skill_type", "profile")
    let profileSkill = BaseSkill(
        name: "profile-skill",
        description: "Profile skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: profileMeta,
        allowedTools: None<String>,
        instructions: "I am the agent's identity profile.",
        skillPath: ""
    )
    let capMeta = HashMap<String, String>()
    capMeta.add("load_policy", "always_on")
    let capSkill = BaseSkill(
        name: "capability-skill",
        description: "Capability skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: capMeta,
        allowedTools: None<String>,
        instructions: "Capability instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([profileSkill, capSkill]))
    let injector = SkillContextInjector(skillManager: manager)
    let result = injector.injectAlwaysOnSkills("session-1")
    let hasProfileLayer = result.injectedContext.contains("<profile_context>") && result.injectedContext.contains("profile-skill")
    let hasCapabilityLayer = result.injectedContext.contains("<skill_content") && result.injectedContext.contains("capability-skill")
    println("hasProfileLayer=${hasProfileLayer}, hasCapabilityLayer=${hasCapabilityLayer}, activeSkills=${result.activeSkills.size}")
    if (result.status == SkillInjectionStatus.Success
        && hasProfileLayer
        && hasCapabilityLayer
        && result.activeSkills.contains("profile-skill")
        && result.activeSkills.contains("capability-skill")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: profile should route to <profile_context>, capability to <skill_content>")
    }
}

public func runAllInjectorTests(): Unit {
    println("========================================")
    println("SkillContextInjector Tests")
    println("========================================")
    testInjectNoAlwaysOnSkills()
    println("")
    testInjectSingleAlwaysOnSkill()
    println("")
    testInjectMultipleAlwaysOnSkills()
    println("")
    testInjectExplicitSkill()
    println("")
    testRenderCatalogAfterInjection()
    println("")
    testInjectProfileAndCapabilitySplit()
    println("")
    println("========================================")
    println("All injector tests completed.")
    println("========================================")
}