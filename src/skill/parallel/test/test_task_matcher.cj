/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.core.skill.Skill
import magic.skill.BaseSkill
import magic.skill.parallel.{TaskMatcher, AutoInjectConfig, TaskMatchResult, TaskMatchStrategy}
import std.collection.HashMap

public func testMatchHighScore(): Unit {
    println("=== Test TaskMatcher high match ===")
    let metadata = HashMap<String, String>()
    let skill: Skill = BaseSkill(
        name: "cangjie-coder",
        description: "write cangjie code for development",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Cangjie coding skill.",
        skillPath: ""
    )
    let config = AutoInjectConfig(taskMatchThreshold: 0.3)
    let matcher = TaskMatcher(config: config)
    let results = matcher.matchSkills("write cangjie code", [skill])
    println("results size: ${results.size}")
    if (results.size > 0 && results[0].skillName == "cangjie-coder") {
        println("   ✓ PASS (score: ${results[0].matchScore})")
    } else {
        println("   ✗ FAIL: expected cangjie-coder match")
    }
}

public func testMatchNoMatch(): Unit {
    println("=== Test TaskMatcher no match ===")
    let metadata = HashMap<String, String>()
    let skill: Skill = BaseSkill(
        name: "music-skill",
        description: "play piano music",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Music skill.",
        skillPath: ""
    )
    let config = AutoInjectConfig(taskMatchThreshold: 0.6)
    let matcher = TaskMatcher(config: config)
    let results = matcher.matchSkills("write cangjie code", [skill])
    println("results size: ${results.size}")
    if (results.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected no match")
    }
}

public func testMatchEmptyInput(): Unit {
    println("=== Test TaskMatcher empty input ===")
    let metadata = HashMap<String, String>()
    let skill: Skill = BaseSkill(
        name: "some-skill",
        description: "some description",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Some skill.",
        skillPath: ""
    )
    let config = AutoInjectConfig()
    let matcher = TaskMatcher(config: config)
    let results1 = matcher.matchSkills("", [skill])
    let results2 = matcher.matchSkills("test", [])
    if (results1.size == 0 && results2.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty results for empty input")
    }
}

public func testMatchDisabled(): Unit {
    println("=== Test TaskMatcher autoInjectEnabled=false ===")
    let metadata = HashMap<String, String>()
    let skill: Skill = BaseSkill(
        name: "test-skill",
        description: "test description",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Test skill.",
        skillPath: ""
    )
    let config = AutoInjectConfig(autoInjectEnabled: false)
    let matcher = TaskMatcher(config: config)
    let results = matcher.matchSkills("test", [skill])
    if (results.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected no results when disabled")
    }
}

public func testJaccardCoefficient(): Unit {
    println("=== Test Jaccard coefficient ===")
    let config = AutoInjectConfig()
    let matcher = TaskMatcher(config: config)
    let score1 = matcher.matchByKeyword("hello world", "hello world")
    println("identical texts score: ${score1}")
    if (score1 == 1.0) {
        println("   ✓ PASS (identical => 1.0)")
    } else {
        println("   ✗ FAIL: expected 1.0 for identical texts")
    }

    let score2 = matcher.matchByKeyword("hello world", "foo bar")
    println("disjoint texts score: ${score2}")
    if (score2 == 0.0) {
        println("   ✓ PASS (disjoint => 0.0)")
    } else {
        println("   ✗ FAIL: expected 0.0 for disjoint texts")
    }
}

public func testMatchChineseHighScore(): Unit {
    println("=== Test TaskMatcher Chinese high match (T091/D1) ===")
    let metadata = HashMap<String, String>()
    let skill: Skill = BaseSkill(
        name: "cangjie-coder",
        description: "用于编写仓颉代码的技能",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Cangjie coding skill.",
        skillPath: ""
    )
    let config = AutoInjectConfig(taskMatchThreshold: 0.3)
    let matcher = TaskMatcher(config: config)
    let results = matcher.matchSkills("编写仓颉代码", [skill])
    if (results.size > 0) {
        println("results size: ${results.size}, top score: ${results[0].matchScore}")
    } else {
        println("results size: 0")
    }
    if (results.size > 0 && results[0].skillName == "cangjie-coder") {
        println("   ✓ PASS (D1 fixed: Chinese task now matches, score: ${results[0].matchScore})")
    } else {
        println("   ✗ FAIL: expected cangjie-coder to match Chinese task")
    }
}

public func testMatchChineseNoMatch(): Unit {
    println("=== Test TaskMatcher Chinese unrelated no match ===")
    let metadata = HashMap<String, String>()
    let skill: Skill = BaseSkill(
        name: "cangjie-coder",
        description: "用于编写仓颉代码的技能",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Cangjie coding skill.",
        skillPath: ""
    )
    let config = AutoInjectConfig(taskMatchThreshold: 0.6)
    let matcher = TaskMatcher(config: config)
    let results = matcher.matchSkills("播放钢琴音乐", [skill])
    println("results size: ${results.size}")
    if (results.size == 0) {
        println("   ✓ PASS (unrelated Chinese task correctly not injected)")
    } else {
        println("   ✗ FAIL: expected no match for unrelated Chinese task")
    }
}

public func testMatchChineseEnglishMixed(): Unit {
    println("=== Test TaskMatcher Chinese-English mixed match (T091/D1) ===")
    let metadata = HashMap<String, String>()
    let skill: Skill = BaseSkill(
        name: "cangjie-login",
        description: "使用 Cangjie 语言编写用户登录模块",
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "Login module.",
        skillPath: ""
    )
    let config = AutoInjectConfig(taskMatchThreshold: 0.1)
    let matcher = TaskMatcher(config: config)
    let results = matcher.matchSkills("用 Cangjie 实现用户登录功能", [skill])
    if (results.size > 0) {
        println("results size: ${results.size}, top score: ${results[0].matchScore}")
    } else {
        println("results size: 0")
    }
    if (results.size > 0 && results[0].skillName == "cangjie-login") {
        println("   ✓ PASS (D1 fixed: mixed CN/EN task matches, score: ${results[0].matchScore})")
    } else {
        println("   ✗ FAIL: expected cangjie-login to match mixed task")
    }
}

public func runAllTaskMatcherTests(): Unit {
    println("========================================")
    println("TaskMatcher Tests")
    println("========================================")
    testMatchHighScore()
    println("")
    testMatchNoMatch()
    println("")
    testMatchEmptyInput()
    println("")
    testMatchDisabled()
    println("")
    testJaccardCoefficient()
    println("")
    testMatchChineseHighScore()
    println("")
    testMatchChineseNoMatch()
    println("")
    testMatchChineseEnglishMixed()
    println("")
    println("========================================")
    println("All TaskMatcher tests completed.")
    println("========================================")
}