/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.skill.parallel.AutoInjectConfig

public func testAutoInjectConfigDefault(): Unit {
    println("=== Test AutoInjectConfig.default ===")
    let config = AutoInjectConfig.default()
    println("autoInjectEnabled: ${config.autoInjectEnabled}")
    println("taskMatchThreshold: ${config.taskMatchThreshold}")
    println("maxAutoInjectSkills: ${config.maxAutoInjectSkills}")
    if (config.autoInjectEnabled && config.taskMatchThreshold == 0.6 && config.maxAutoInjectSkills == 5) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: default values incorrect")
    }
}

public func testAutoInjectConfigCustom(): Unit {
    println("=== Test AutoInjectConfig custom ===")
    let config = AutoInjectConfig(
        autoInjectEnabled: false,
        taskMatchThreshold: 0.8,
        maxAutoInjectSkills: 3
    )
    if (!config.autoInjectEnabled && config.taskMatchThreshold == 0.8 && config.maxAutoInjectSkills == 3) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: custom values incorrect")
    }
}

public func testAutoInjectConfigThresholdBoundary(): Unit {
    println("=== Test AutoInjectConfig threshold boundary ===")
    let config1 = AutoInjectConfig(taskMatchThreshold: 0.0)
    let config2 = AutoInjectConfig(taskMatchThreshold: 1.0)
    if (config1.taskMatchThreshold == 0.0 && config2.taskMatchThreshold == 1.0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: boundary values incorrect")
    }
}

public func runAllAutoInjectConfigTests(): Unit {
    println("========================================")
    println("AutoInjectConfig Tests")
    println("========================================")
    testAutoInjectConfigDefault()
    println("")
    testAutoInjectConfigCustom()
    println("")
    testAutoInjectConfigThresholdBoundary()
    println("")
    println("========================================")
    println("All AutoInjectConfig tests completed.")
    println("========================================")
}