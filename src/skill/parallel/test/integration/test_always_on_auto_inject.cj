/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.integration
import magic.skill.parallel.{SkillAutoInjector, SkillInjectionStatus, AutoInjectConfig}
import std.collection.{HashMap, ArrayList}

import magic.core.skill.Skill
import magic.skill.{BaseSkill, CompositeSkillToolManager}

func toSkillList(skills: Array<BaseSkill>): ArrayList<Skill> {
    let result = ArrayList<Skill>()
    for (s in skills) {
        result.add(s)
    }
    return result
}

public func testAlwaysOnAutoInjectIntegration(): Unit {
    println("=== Integration: AlwaysOn skill auto-injected on init ===")
    let metadata = HashMap<String, String>()
    metadata.add("load_policy", "always_on")
    metadata.add("priority", "high")
    let skill = BaseSkill(
        name: "integration-always-on",
        description: "Integration test always on skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Complete instructions for always on integration test skill.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([skill]))
    let injector = SkillAutoInjector.create(manager)

    let result = injector.injectOnInitialization("integration-session-1")
    println("status: ${result.status}")
    println("context contains <skill_content>: ${result.injectedContext.contains("<skill_content")}")
    println("context contains instructions: ${result.injectedContext.contains("Complete instructions for always on")}")

    if (result.status == SkillInjectionStatus.Success &&
        result.injectedContext.contains("<skill_content") &&
        result.injectedContext.contains("Complete instructions for always on")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL")
    }
}