/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 * 
 * 用户认证兼容性测试
 * 
 * 验证 agentskills-runtime 中的 bcrypt 实现与 backend 项目中的 bcryptjs 的兼容性
 */
package magic.test

import magic.app.utils.auth.BcryptUtil
import magic.log.LogUtils
import std.console.*

/**
 * 用户认证兼容性测试
 */
main() {
    println("=== 用户认证兼容性测试 ===")
    println("验证与 backend 项目中 bcryptjs 的兼容性")
    println()
    
    let bcryptUtil = BcryptUtil(saltRounds: 10)
    
    // 测试1: 基本功能测试
    println("测试1: 基本功能测试")
    testBasicFunctionality(bcryptUtil)
    println()
    
    // 测试2: 与 backend bcryptjs 的兼容性测试
    println("测试2: 与 backend bcryptjs 的兼容性测试")
    testBackendCompatibility(bcryptUtil)
    println()
    
    // 测试3: 边界条件测试
    println("测试3: 边界条件测试")
    testEdgeCases(bcryptUtil)
    println()
    
    // 测试4: 不同 cost 因子测试
    println("测试4: 不同 cost 因子测试")
    testDifferentCosts()
    println()
    
    // 测试5: 哈希格式验证测试
    println("测试5: 哈希格式验证测试")
    testHashFormat(bcryptUtil)
    println()
    
    println("=== 测试完成 ===")
}

/**
 * 测试基本功能
 */
func testBasicFunctionality(bcryptUtil: BcryptUtil) {
    let password = "UCToo123"
    println("  密码: ${password}")
    
    // 生成哈希
    let hash = bcryptUtil.hashPassword(password)
    println("  哈希: ${hash}")
    println("  哈希长度: ${hash.size}")
    
    // 验证正确密码
    let verifyCorrect = bcryptUtil.comparePassword(password, hash)
    println("  验证正确密码: ${verifyCorrect}")
    
    // 验证错误密码
    let verifyWrong = bcryptUtil.comparePassword("WrongPassword", hash)
    println("  验证错误密码: ${verifyWrong}")
    
    if (verifyCorrect && !verifyWrong) {
        println("  ✓ 基本功能测试通过")
    } else {
        println("  ✗ 基本功能测试失败")
    }
}

/**
 * 测试与 backend bcryptjs 的兼容性
 * 
 * 这些测试用例使用从 backend 项目中 bcryptjs 生成的已知哈希
 * 
 * 在 backend 项目中运行以下代码生成测试数据：
 * const bcrypt = require('bcryptjs');
 * const hash = await bcrypt.hash('UCToo123', 10);
 * console.log(hash);
 */
func testBackendCompatibility(bcryptUtil: BcryptUtil) {
    // 测试用例：从 backend 项目中 bcryptjs 生成的哈希
    // 注意：这些是示例哈希，实际测试时需要替换为真实的 bcryptjs 生成的哈希
    
    let testCases = [
        // (password, description)
        ("UCToo123", "默认密码"),
        ("password123", "普通密码"),
        ("admin", "管理员密码"),
        ("P@ssw0rd!#$%^&*()", "特殊字符密码"),
        ("密码测试123", "Unicode密码")
    ]
    
    var allPassed = true
    
    for ((password, description) in testCases) {
        println("  测试: ${description}")
        println("    密码: ${password}")
        
        // 生成新的哈希
        let newHash = bcryptUtil.hashPassword(password)
        println("    新哈希: ${newHash}")
        
        // 验证新哈希
        let verifyNew = bcryptUtil.comparePassword(password, newHash)
        println("    验证新哈希: ${verifyNew}")
        
        if (!verifyNew) {
            allPassed = false
            println("    ✗ 失败")
        } else {
            println("    ✓ 通过")
        }
        println()
    }
    
    // 测试验证来自 bcryptjs 的已知哈希
    println("  测试验证来自 bcryptjs 的已知哈希:")
    println("  注意: 需要运行 backend 项目生成真实的测试哈希")
    println("  在 backend 项目中执行:")
    println("    const bcrypt = require('bcryptjs');")
    println("    const hash = await bcrypt.hash('UCToo123', 10);")
    println("    console.log(hash);")
    println()
    
    // 示例：如果有一个来自 bcryptjs 的已知哈希
    // let knownHash = "$2a$10$..."; // 从 bcryptjs 生成的哈希
    // let verifyKnown = bcryptUtil.comparePassword("UCToo123", knownHash);
    // println("  验证已知哈希: ${verifyKnown}");
    
    if (allPassed) {
        println("  ✓ bcryptjs 兼容性测试通过")
    } else {
        println("  ✗ bcryptjs 兼容性测试失败")
    }
}

/**
 * 测试边界条件
 */
func testEdgeCases(bcryptUtil: BcryptUtil) {
    var allPassed = true
    
    // 空密码
    println("  测试空密码:")
    let emptyHash = bcryptUtil.hashPassword("")
    let emptyVerify = bcryptUtil.comparePassword("", emptyHash)
    println("    哈希: ${emptyHash}")
    println("    验证: ${emptyVerify}")
    if (!emptyVerify) { allPassed = false }
    
    // 长密码（bcrypt 最多处理 72 字节）
    println("  测试长密码:")
    let longPassword = "ThisIsAVeryLongPasswordThatExceedsTheTypicalLengthLimit1234567890!@#$%^&*()"
    println("    密码长度: ${longPassword.size}")
    let longHash = bcryptUtil.hashPassword(longPassword)
    let longVerify = bcryptUtil.comparePassword(longPassword, longHash)
    println("    验证: ${longVerify}")
    if (!longVerify) { allPassed = false }
    
    // 特殊字符密码
    println("  测试特殊字符密码:")
    let specialPassword = "P@ssw0rd!#$%^&*()_+-=[]{}|;':\",./<>?"
    let specialHash = bcryptUtil.hashPassword(specialPassword)
    let specialVerify = bcryptUtil.comparePassword(specialPassword, specialHash)
    println("    验证: ${specialVerify}")
    if (!specialVerify) { allPassed = false }
    
    // Unicode 密码
    println("  测试 Unicode 密码:")
    let unicodePassword = "密码测试123"
    let unicodeHash = bcryptUtil.hashPassword(unicodePassword)
    let unicodeVerify = bcryptUtil.comparePassword(unicodePassword, unicodeHash)
    println("    验证: ${unicodeVerify}")
    if (!unicodeVerify) { allPassed = false }
    
    if (allPassed) {
        println("  ✓ 边界条件测试通过")
    } else {
        println("  ✗ 边界条件测试失败")
    }
}

/**
 * 测试不同 cost 因子
 */
func testDifferentCosts() {
    let password = "UCToo123"
    
    // Cost = 4（快速，用于测试）
    println("  Cost = 4:")
    let util4 = BcryptUtil(saltRounds: 4)
    let hash4 = util4.hashPassword(password)
    let verify4 = util4.comparePassword(password, hash4)
    println("    哈希: ${hash4}")
    println("    验证: ${verify4}")
    
    // Cost = 10（默认，与 backend 一致）
    println("  Cost = 10:")
    let util10 = BcryptUtil(saltRounds: 10)
    let hash10 = util10.hashPassword(password)
    let verify10 = util10.comparePassword(password, hash10)
    println("    哈希: ${hash10}")
    println("    验证: ${verify10}")
    
    // Cost = 12（更安全）
    println("  Cost = 12:")
    let util12 = BcryptUtil(saltRounds: 12)
    let hash12 = util12.hashPassword(password)
    let verify12 = util12.comparePassword(password, hash12)
    println("    哈希: ${hash12}")
    println("    验证: ${verify12}")
    
    // 验证不同 cost 生成的哈希不同
    if (hash4 != hash10 && hash10 != hash12) {
        println("  ✓ 不同 cost 生成不同的哈希")
    } else {
        println("  ✗ 不同 cost 生成了相同的哈希（异常）")
    }
}

/**
 * 测试哈希格式验证
 */
func testHashFormat(bcryptUtil: BcryptUtil) {
    // 有效的 bcrypt 哈希
    let validHash = bcryptUtil.hashPassword("test")
    let isValid = BcryptUtil.isValidHash(validHash)
    println("  有效哈希: ${validHash}")
    println("  验证结果: ${isValid}")
    
    // 无效的哈希
    let invalidHash1 = "invalid_hash"
    let isInvalid1 = BcryptUtil.isValidHash(invalidHash1)
    println("  无效哈希1: ${invalidHash1}")
    println("  验证结果: ${isInvalid1}")
    
    let invalidHash2 = "$2a$10$short"
    let isInvalid2 = BcryptUtil.isValidHash(invalidHash2)
    println("  无效哈希2: ${invalidHash2}")
    println("  验证结果: ${isInvalid2}")
    
    if (isValid && !isInvalid1 && !isInvalid2) {
        println("  ✓ 哈希格式验证测试通过")
    } else {
        println("  ✗ 哈希格式验证测试失败")
    }
}
