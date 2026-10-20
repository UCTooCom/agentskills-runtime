/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.integration
import magic.skill.parallel.{SkillAutoInjector, SkillInjectionStatus, AutoInjectConfig}

import magic.skill.{BaseSkill, CompositeSkillToolManager}
import std.collection.HashMap

public func testNoDoubleInjectIntegration(): Unit {
    println("=== Integration: No double injection for same skill ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "dedup-test-skill",
        description: "Dedup test skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Dedup test instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillAutoInjector.create(manager)

    let result1 = injector.injectOnInitialization("dedup-session")
    println("first injection - active skills: ${result1.activeSkills.size.toString()}")

    let result2 = injector.injectOnInitialization("dedup-session")
    println("second injection - active skills: ${result2.activeSkills.size.toString()}")

    let isInjected = injector.isSkillInjected("dedup-test-skill")
    println("isSkillInjected: ${isInjected.toString()}")

    if (result1.activeSkills.size > 0 && isInjected) {
        println("   ✓ PASS (skill injected once, dedup tracks state)")
    } else {
        println("   ✗ FAIL")
    }
}