/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.integration
import magic.skill.parallel.{SkillAutoInjector, SkillInjectionStatus, AutoInjectConfig}

import magic.skill.{BaseSkill, CompositeSkillToolManager}
import std.collection.HashMap

public func testExplicitAutoInjectIntegration(): Unit {
    println("=== Integration: Explicit /skill-name auto-inject ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "on_demand")
    let skill = BaseSkill(
        name: "explicit-test-skill",
        description: "Skill for explicit injection test",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Explicit test skill complete instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillAutoInjector.create(manager)

    let result = injector.injectExplicit("explicit-test-skill", "integration-session-3")
    println("status: ${result.status}")
    println("context contains skill name: ${result.injectedContext.contains("explicit-test-skill")}")

    if (result.status == SkillInjectionStatus.Success && result.injectedContext.contains("explicit-test-skill")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected explicit injection to work")
    }
}