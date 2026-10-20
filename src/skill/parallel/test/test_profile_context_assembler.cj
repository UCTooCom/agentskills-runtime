/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.core.skill.Skill
import magic.skill.BaseSkill
import magic.skill.parallel.ProfileContextAssembler
import std.collection.HashMap

private func buildProfileSkill(name: String): Skill {
    let m = HashMap<String, String>()
    m.add("skill_type", "profile")
    return BaseSkill(
        name: name,
        description: name,
        license: None<String>,
        compatibility: None<String>,
        metadata: m,
        allowedTools: None<String>,
        instructions: "Profile instructions for ${name}.",
        skillPath: ""
    )
}

private func countOccurrences(haystack: String, needle: String): Int64 {
    return haystack.split(needle).size - 1
}

public func testProfileContextAssemblerThreeProfiles(): Unit {
    println("=== Test ProfileContextAssembler (3 profiles -> 1 block) ===")
    let profiles: Array<Skill> = [buildProfileSkill("p1"), buildProfileSkill("p2"), buildProfileSkill("p3")]
    let block = ProfileContextAssembler().assemble(profiles)
    let hasWrapper = block.contains("<profile_context>") && block.contains("</profile_context>")
    let count = countOccurrences(block, "<profile name=\"")
    println("wrapper=${hasWrapper}, profileEntryCount=${count}")
    if (hasWrapper && count == 3) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 1 <profile_context> wrapper containing 3 <profile> entries")
    }
}

public func testProfileContextAssemblerEmpty(): Unit {
    println("=== Test ProfileContextAssembler (empty) ===")
    let block = ProfileContextAssembler().assemble([])
    if (block.isEmpty()) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty block for no profiles")
    }
}

public func testProfileContextAssemblerBudgetOverflow(): Unit {
    println("=== Test ProfileContextAssembler (budget overflow drops extras) ===")
    let profiles: Array<Skill> = [buildProfileSkill("p1"), buildProfileSkill("p2"), buildProfileSkill("p3")]
    // 极小预算：只够第一个 profile 估算通过
    let block = ProfileContextAssembler().assemble(profiles, budgetTokens: 50)
    let count = countOccurrences(block, "<profile name=\"")
    println("profileEntryCount under tiny budget=${count}")
    if (count >= 1 && count < 3) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected partial inclusion under tight budget")
    }
}

public func runAllProfileAssemblerTests(): Unit {
    testProfileContextAssemblerThreeProfiles()
    println("")
    testProfileContextAssemblerEmpty()
    println("")
    testProfileContextAssemblerBudgetOverflow()
    println("")
}
