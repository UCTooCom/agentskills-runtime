/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.core.skill.Skill
import magic.skill.BaseSkill
import magic.skill.parallel.{BudgetManager, SkillParallelConfig, BudgetAllocationResult, ContentLevel, LoadPolicy}
import std.collection.HashMap

public func testBudgetWithinLimit(): Unit {
    println("=== Test BudgetManager within limit ===")
    let metadata1 = HashMap<String, String>()
    metadata1.add("context_budget_tokens", "1000")
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
    let config = SkillParallelConfig()
    let manager = BudgetManager(config: config)
    let result = manager.allocateWithDegrade([skill1], 2000)
    println("allocated: ${result.allocated.size}, degraded: ${result.degraded.size}, evicted: ${result.evicted.size}")
    if (result.allocated.size == 1 && result.degraded.size == 0 && result.evicted.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 1 allocated, 0 degraded, 0 evicted")
    }
}

public func testBudgetExceedDegrade(): Unit {
    println("=== Test BudgetManager exceed => degrade ===")
    let metadata1 = HashMap<String, String>()
    metadata1.add("context_budget_tokens", "2000")
    metadata1.add("priority", "high")
    let skill1 = BaseSkill(
        name: "high-priority-skill",
        description: "High priority skill with a long description",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata1,
        allowedTools: None<String>,
        instructions: "Instructions.",
        skillPath: ""
    )
    let metadata2 = HashMap<String, String>()
    metadata2.add("context_budget_tokens", "2000")
    metadata2.add("priority", "low")
    let skill2 = BaseSkill(
        name: "low-priority-skill",
        description: "Low priority skill with a long description",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata2,
        allowedTools: None<String>,
        instructions: "Instructions.",
        skillPath: ""
    )
    let config = SkillParallelConfig()
    let manager = BudgetManager(config: config)
    let result = manager.allocateWithDegrade([skill1, skill2], 2500)
    println("allocated: ${result.allocated.size}, degraded: ${result.degraded.size}, evicted: ${result.evicted.size}")
    if (result.usedTokens <= 2500) {
        println("   ✓ PASS (usedTokens: ${result.usedTokens} <= 2500)")
    } else {
        println("   ✗ FAIL: usedTokens ${result.usedTokens} exceeds budget 2500")
    }
}

public func testDegradeToFrontmatter(): Unit {
    println("=== Test degradeToFrontmatter ===")
    let metadata = HashMap<String, String>()
    let skill = BaseSkill(
        name: "test-skill",
        description: "Test skill description",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Full instructions here.",
        skillPath: ""
    )
    let config = SkillParallelConfig()
    let manager = BudgetManager(config: config)
    let degraded = manager.degradeToFrontmatter(skill)
    println("name: ${degraded.name}, instructions empty: ${degraded.instructions.isEmpty()}")
    if (degraded.name == "test-skill" && degraded.instructions.isEmpty() && degraded.description == "Test skill description") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: degraded skill should have empty instructions but keep name/description")
    }
}

public func testEmptySkills(): Unit {
    println("=== Test BudgetManager empty skills ===")
    let config = SkillParallelConfig()
    let manager = BudgetManager(config: config)
    let result = manager.allocateWithDegrade([], 1000)
    if (result.allocated.size == 0 && result.usedTokens == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty result for empty skills")
    }
}

public func runAllBudgetManagerTests(): Unit {
    println("========================================")
    println("BudgetManager Tests")
    println("========================================")
    testBudgetWithinLimit()
    println("")
    testBudgetExceedDegrade()
    println("")
    testDegradeToFrontmatter()
    println("")
    testEmptySkills()
    println("")
    println("========================================")
    println("All BudgetManager tests completed.")
    println("========================================")
}