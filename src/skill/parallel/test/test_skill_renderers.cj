/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.core.skill.Skill
import magic.skill.BaseSkill
import magic.skill.parallel.{SkillContentRenderer, SkillCatalogRenderer}
import std.collection.HashMap

public func testRenderSingleSkill(): Unit {
    println("=== Test renderSkillContent (single) ===")
    let metadata = HashMap<String, String>()
    let skill = BaseSkill(
        name: "cangjie-coder",
        description: "Cangjie code writer",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Use this skill to write Cangjie code.",
        skillPath: ""
    )
    let renderer = SkillContentRenderer()
    let result = renderer.renderSkillContent(skill)
    println("Result:\n${result}")
    if (result.startsWith("<skill_content name=\"cangjie-coder\">") && result.endsWith("</skill_content>") && result.contains("<skill_instructions>")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: XML format incorrect")
    }
}

public func testRenderEmptyInstructions(): Unit {
    println("=== Test renderSkillContent (empty instructions) ===")
    let metadata = HashMap<String, String>()
    let skill = BaseSkill(
        name: "empty-skill",
        description: "Empty skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "",
        skillPath: ""
    )
    let renderer = SkillContentRenderer()
    let result = renderer.renderSkillContent(skill)
    println("Result: \"${result}\"")
    if (result.isEmpty()) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty string")
    }
}

public func testRenderMultipleSkills(): Unit {
    println("=== Test renderMultipleSkills ===")
    let metadata = HashMap<String, String>()
    let skill1 = BaseSkill(
        name: "skill-a",
        description: "Skill A",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Instructions for A.",
        skillPath: ""
    )
    let skill2 = BaseSkill(
        name: "skill-b",
        description: "Skill B",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Instructions for B.",
        skillPath: ""
    )
    let renderer = SkillContentRenderer()
    let result = renderer.renderMultipleSkills([skill1, skill2])
    println("Result:\n${result}")
    if (result.contains("<skill_content name=\"skill-a\">") && result.contains("<skill_content name=\"skill-b\">") && result.contains("\n\n")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: multi-skill render incorrect")
    }
}

public func testRenderEmptyCatalog(): Unit {
    println("=== Test renderCatalog (empty) ===")
    let renderer = SkillCatalogRenderer()
    let result = renderer.renderCatalog([])
    println("Result:\n${result}")
    if (result.startsWith("<available_skills>") && result.endsWith("</available_skills>")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: empty catalog format incorrect")
    }
}

public func testRenderCatalogWithSkills(): Unit {
    println("=== Test renderCatalog (with skills) ===")
    let metadata = HashMap<String, String>()
    let skill1 = BaseSkill(
        name: "sdd",
        description: "Spec-driven development",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "SDD instructions.",
        skillPath: ""
    )
    let skill2 = BaseSkill(
        name: "cangjie-coder",
        description: "Cangjie code writer",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Cangjie instructions.",
        skillPath: ""
    )
    let renderer = SkillCatalogRenderer()
    let result = renderer.renderCatalog([skill1, skill2])
    println("Result:\n${result}")
    if (result.contains("`sdd`") && result.contains("`cangjie-coder`") && result.contains("Spec-driven development") && result.contains("Cangjie code writer")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: catalog content incorrect")
    }
}

public func runAllRendererTests(): Unit {
    println("========================================")
    println("SkillRenderer Tests")
    println("========================================")
    testRenderSingleSkill()
    println("")
    testRenderEmptyInstructions()
    println("")
    testRenderMultipleSkills()
    println("")
    testRenderEmptyCatalog()
    println("")
    testRenderCatalogWithSkills()
    println("")
    println("========================================")
    println("All renderer tests completed.")
    println("========================================")
}