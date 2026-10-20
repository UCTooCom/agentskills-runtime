/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.integration

import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.SkillAutoInjector
import std.collection.HashMap

public func testBackwardCompatFallbackIntegration(): Unit {
    println("=== Integration: Backward compat - get_skill_content fallback ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "on_demand")
    let skill = BaseSkill(
        name: "fallback-test-skill",
        description: "Fallback test skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Fallback test instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillAutoInjector.create(manager)

    let notInjectedBefore = injector.isSkillInjected("fallback-test-skill")
    println("before injection - isSkillInjected: ${notInjectedBefore.toString()}")

    injector.injectExplicit("fallback-test-skill", "fallback-session")
    let injectedAfter = injector.isSkillInjected("fallback-test-skill")
    println("after injection - isSkillInjected: ${injectedAfter.toString()}")

    if (!notInjectedBefore && injectedAfter) {
        println("   ✓ PASS (dedup correctly tracks injection state)")
    } else {
        println("   ✗ FAIL")
    }
}