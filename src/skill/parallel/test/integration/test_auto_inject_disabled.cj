/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.integration

import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.{SkillAutoInjector, AutoInjectConfig}
import std.collection.HashMap

public func testAutoInjectDisabledIntegration(): Unit {
    println("=== Integration: autoInjectEnabled=false fallback to original ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    let skill = BaseSkill(
        name: "disabled-test-skill",
        description: "Disabled test skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Disabled test instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let config = AutoInjectConfig(autoInjectEnabled: false)
    let injector = SkillAutoInjector.create(manager, config)

    let initResult = injector.injectOnInitialization("disabled-session")
    println("init context empty: ${initResult.injectedContext.isEmpty()}")

    let taskResult = injector.injectOnUserMessage("test task", "disabled-session")
    println("task context empty: ${taskResult.injectedContext.isEmpty()}")

    let explicitResult = injector.injectExplicit("disabled-test-skill", "disabled-session")
    println("explicit context empty: ${explicitResult.injectedContext.isEmpty()}")

    if (initResult.injectedContext.isEmpty() && taskResult.injectedContext.isEmpty() && explicitResult.injectedContext.isEmpty()) {
        println("   ✓ PASS (all injection methods return empty when disabled)")
    } else {
        println("   ✗ FAIL: expected all injection methods to return empty")
    }
}