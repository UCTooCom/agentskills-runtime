/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.skill.parallel.SkillParallelConfig

public func testDeriveFromModelWindow(): Unit {
    println("=== Test deriveFromModelWindow (TG28/T109-T110) ===")

    let config = SkillParallelConfig.default()
    println("default totalBudgetTokens=${config.totalBudgetTokens}")

    // 1. 窗口 8192*? 取 15%：100000 * 0.15 = 15000
    let window1: Int64 = 100000
    let derived1 = config.deriveFromModelWindow(window1)
    println("1. window=100000, ratio=0.15 => ${derived1}")
    if (derived1 == 15000) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 15000")
    }

    // 2. 自定义 ratio=0.2：100000 * 0.2 = 20000
    let derived2 = config.deriveFromModelWindow(window1, ratio: 0.2)
    println("2. window=100000, ratio=0.2 => ${derived2}")
    if (derived2 == 20000) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 20000")
    }

    // 3. 窗口为 0 时回退到已配置值
    let window3: Int64 = 0
    let derived3 = config.deriveFromModelWindow(window3)
    println("3. window=0 => ${derived3} (fallback to ${config.totalBudgetTokens})")
    if (derived3 == config.totalBudgetTokens) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected fallback to configured budget")
    }

    // 4. applyDerivedBudget 写回
    let config2 = SkillParallelConfig.default()
    config2.applyDerivedBudget(window1)
    println("4. applyDerivedBudget(window=100000) => totalBudgetTokens=${config2.totalBudgetTokens}")
    if (config2.totalBudgetTokens == 15000) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 15000 after apply")
    }
}

public func runAllConfigTests(): Unit {
    println("========================================")
    println("SkillParallelConfig Tests (TG28)")
    println("========================================")
    testDeriveFromModelWindow()
    println("")
    println("========================================")
    println("Config tests completed.")
    println("========================================")
}
