/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.skill.parallel.{LoadPolicy, SkillPriority, SkillParallelDeclarationParser, SkillType, SyncScope, ConflictPolicy, DistributionMetadata}
import std.collection.{ArrayList, HashMap}

public func testParseLoadPolicy(): Unit {
    println("=== Test parseLoadPolicy ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("load_policy", "always_on")
    let result1 = SkillParallelDeclarationParser.parseLoadPolicy(metadata1)
    println("1. load_policy=always_on => ${result1}")
    if (result1 == LoadPolicy.AlwaysOn) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected AlwaysOn")
    }

    let metadata2 = HashMap<String, String>()
    metadata2.add("load_policy", "conditional")
    let result2 = SkillParallelDeclarationParser.parseLoadPolicy(metadata2)
    println("2. load_policy=conditional => ${result2}")
    if (result2 == LoadPolicy.Conditional) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Conditional")
    }

    let metadata3 = HashMap<String, String>()
    let result3 = SkillParallelDeclarationParser.parseLoadPolicy(metadata3)
    println("3. no load_policy => ${result3}")
    if (result3 == LoadPolicy.OnDemand) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected OnDemand")
    }

    let metadata4 = HashMap<String, String>()
    metadata4.add("load_policy", "invalid_value")
    let result4 = SkillParallelDeclarationParser.parseLoadPolicy(metadata4)
    println("4. load_policy=invalid_value => ${result4}")
    if (result4 == LoadPolicy.OnDemand) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected OnDemand for invalid value")
    }
}

public func testParsePriority(): Unit {
    println("=== Test parsePriority ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("priority", "high")
    let result1 = SkillParallelDeclarationParser.parsePriority(metadata1)
    println("1. priority=high => ${result1}")
    if (result1 == SkillPriority.High) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected High")
    }

    let metadata2 = HashMap<String, String>()
    metadata2.add("priority", "low")
    let result2 = SkillParallelDeclarationParser.parsePriority(metadata2)
    println("2. priority=low => ${result2}")
    if (result2 == SkillPriority.Low) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Low")
    }

    let metadata3 = HashMap<String, String>()
    let result3 = SkillParallelDeclarationParser.parsePriority(metadata3)
    println("3. no priority => ${result3}")
    if (result3 == SkillPriority.Medium) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Medium")
    }
}

public func testParseConflictsWith(): Unit {
    println("=== Test parseConflictsWith ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("conflicts_with", "sdd,cangjie-coder")
    let result1 = SkillParallelDeclarationParser.parseConflictsWith(metadata1)
    println("1. conflicts_with=sdd,cangjie-coder => size=${result1.size}")
    if (result1.size == 2 && result1[0] == "sdd" && result1[1] == "cangjie-coder") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected [sdd, cangjie-coder]")
    }

    let metadata2 = HashMap<String, String>()
    metadata2.add("conflicts_with", "single-skill")
    let result2 = SkillParallelDeclarationParser.parseConflictsWith(metadata2)
    println("2. conflicts_with=single-skill => size=${result2.size}")
    if (result2.size == 1 && result2[0] == "single-skill") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected [single-skill]")
    }

    let metadata3 = HashMap<String, String>()
    let result3 = SkillParallelDeclarationParser.parseConflictsWith(metadata3)
    println("3. no conflicts_with => size=${result3.size}")
    if (result3.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty list")
    }

    let metadata4 = HashMap<String, String>()
    metadata4.add("conflicts_with", "a, ,b,")
    let result4 = SkillParallelDeclarationParser.parseConflictsWith(metadata4)
    println("4. conflicts_with=a, ,b, => size=${result4.size}")
    if (result4.size == 2 && result4[0] == "a" && result4[1] == "b") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected [a, b] after trimming empty entries")
    }
}

public func testParseContextBudgetTokens(): Unit {
    println("=== Test parseContextBudgetTokens ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("context_budget_tokens", "3000")
    let result1 = SkillParallelDeclarationParser.parseContextBudgetTokens(metadata1)
    println("1. context_budget_tokens=3000 => ${result1}")
    if (result1 == 3000) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 3000")
    }

    let metadata2 = HashMap<String, String>()
    let result2 = SkillParallelDeclarationParser.parseContextBudgetTokens(metadata2)
    println("2. no context_budget_tokens => ${result2}")
    if (result2 == 2000) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 2000")
    }
}

public func testParseDependsOn(): Unit {
    println("=== Test parseDependsOn ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("depends_on", "base-skill,core-skill")
    let result1 = SkillParallelDeclarationParser.parseDependsOn(metadata1)
    println("1. depends_on=base-skill,core-skill => size=${result1.size}")
    if (result1.size == 2 && result1[0] == "base-skill" && result1[1] == "core-skill") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected [base-skill, core-skill]")
    }

    let metadata2 = HashMap<String, String>()
    let result2 = SkillParallelDeclarationParser.parseDependsOn(metadata2)
    println("2. no depends_on => size=${result2.size}")
    if (result2.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty list")
    }
}

public func testParseCompatibleWith(): Unit {
    println("=== Test parseCompatibleWith ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("compatible_with", "sdd,cangjie-coder")
    let result1 = SkillParallelDeclarationParser.parseCompatibleWith(metadata1)
    println("1. compatible_with=sdd,cangjie-coder => size=${result1.size}")
    if (result1.size == 2 && result1[0] == "sdd" && result1[1] == "cangjie-coder") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected [sdd, cangjie-coder]")
    }

    let metadata2 = HashMap<String, String>()
    let result2 = SkillParallelDeclarationParser.parseCompatibleWith(metadata2)
    println("2. no compatible_with => size=${result2.size}")
    if (result2.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty list")
    }
}

public func testSkillPriorityCompare(): Unit {
    println("=== Test SkillPriority.compare ===")

    println("1. High.compare(High) => ${SkillPriority.High.compare(SkillPriority.High)}")
    if (SkillPriority.High.compare(SkillPriority.High) == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 0")
    }

    println("2. High.compare(Medium) => ${SkillPriority.High.compare(SkillPriority.Medium)}")
    if (SkillPriority.High.compare(SkillPriority.Medium) > 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected > 0")
    }

    println("3. Low.compare(High) => ${SkillPriority.Low.compare(SkillPriority.High)}")
    if (SkillPriority.Low.compare(SkillPriority.High) < 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected < 0")
    }
}

public func testParseSkillType(): Unit {
    println("=== Test parseSkillType (TG21/T084) ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("skill_type", "profile")
    let result1 = SkillParallelDeclarationParser.parseSkillType(metadata1)
    println("1. skill_type=profile => ${result1}")
    if (result1 == SkillType.Profile) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Profile")
    }

    let metadata2 = HashMap<String, String>()
    metadata2.add("skill_type", "capability")
    let result2 = SkillParallelDeclarationParser.parseSkillType(metadata2)
    println("2. skill_type=capability => ${result2}")
    if (result2 == SkillType.Capability) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Capability")
    }

    let metadata3 = HashMap<String, String>()
    let result3 = SkillParallelDeclarationParser.parseSkillType(metadata3)
    println("3. no skill_type => ${result3}")
    if (result3 == SkillType.Capability) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Capability default")
    }

    let metadata4 = HashMap<String, String>()
    metadata4.add("skill_type", "invalid_value")
    let result4 = SkillParallelDeclarationParser.parseSkillType(metadata4)
    println("4. skill_type=invalid_value => ${result4}")
    if (result4 == SkillType.Capability) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Capability for invalid value")
    }
}

public func testParseDistributionMetadata(): Unit {
    println("=== Test parseDistributionMetadata (TG22/T090) ===")

    let metadata1 = HashMap<String, String>()
    metadata1.add("sync_scope", "user_owned")
    metadata1.add("authoritative", "true")
    metadata1.add("conflict_policy", "merge")
    metadata1.add("version", "3")
    metadata1.add("etag", "abc123")
    let result1 = SkillParallelDeclarationParser.parseDistributionMetadata(metadata1)
    println("1. full metadata => scope=${result1.syncScope}, authoritative=${result1.authoritative}, policy=${result1.conflictPolicy}, version=${result1.version}, etag=${result1.etag}")
    if (result1.syncScope == SyncScope.UserOwned
        && result1.authoritative == true
        && result1.conflictPolicy == ConflictPolicy.Merge
        && result1.version == 3
        && result1.etag == "abc123") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: metadata mismatch")
    }

    let metadata2 = HashMap<String, String>()
    let result2 = SkillParallelDeclarationParser.parseDistributionMetadata(metadata2)
    println("2. empty metadata => scope=${result2.syncScope}, policy=${result2.conflictPolicy}, version=${result2.version}")
    if (result2.syncScope == SyncScope.NodeLocal
        && result2.conflictPolicy == ConflictPolicy.LastWriteWins
        && result2.version == 1) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected node_local / last_write_wins / version 1 defaults")
    }
}

public func runAllTests(): Unit {
    println("========================================")
    println("SkillParallelDeclarationParser Tests")
    println("========================================")
    testParseLoadPolicy()
    println("")
    testParsePriority()
    println("")
    testParseConflictsWith()
    println("")
    testParseContextBudgetTokens()
    println("")
    testParseDependsOn()
    println("")
    testParseCompatibleWith()
    println("")
    testSkillPriorityCompare()
    println("")
    testParseSkillType()
    println("")
    testParseDistributionMetadata()
    println("")
    println("========================================")
    println("All tests completed.")
    println("========================================")
}