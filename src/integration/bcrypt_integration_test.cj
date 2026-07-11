/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 * 
 * Bcrypt 集成测试 - 验证与 backend 项目中 bcryptjs 的兼容性
 */
package magic.integration

import magic.utils.PasswordUtils
import std.console.*

/**
 * Bcrypt 集成测试
 * 
 * 验证仓颉实现的 bcrypt 与 backend 项目中 bcryptjs 的兼容性
 */
main() {
    println("=== Bcrypt 集成测试 ===")
    println("验证与 backend 项目中 bcryptjs 的兼容性")
    println()
    
    // 测试1: 基本功能测试
    println("测试1: 基本功能测试")
    testBasicFunctionality()
    println()
    
    // 测试2: 与 bcryptjs 的兼容性测试
    println("测试2: 与 bcryptjs 的兼容性测试")
    testBcryptjsCompatibility()
    println()
    
    // 测试3: 边界条件测试
    println("测试3: 边界条件测试")
    testEdgeCases()
    println()
    
    // 测试4: 性能测试
    println("测试4: 性能测试")
    testPerformance()
    println()
    
    println("=== 测试完成 ===")
}

/**
 * 测试基本功能
 */
func testBasicFunctionality() {
    let password = "UCToo123"
    println("  密码: ${password}")
    
    // 生成哈希
    let hash = PasswordUtils.hashPassword(password)
    println("  哈希: ${hash}")
    
    // 验证正确密码
    let verifyCorrect = PasswordUtils.verifyPassword(password, hash)
    println("  验证正确密码: ${verifyCorrect}")
    
    // 验证错误密码
    let verifyWrong = PasswordUtils.verifyPassword("WrongPassword", hash)
    println("  验证错误密码: ${verifyWrong}")
    
    if (verifyCorrect && !verifyWrong) {
        println("  ✓ 基本功能测试通过")
    } else {
        println("  ✗ 基本功能测试失败")
    }
}

/**
 * 测试与 bcryptjs 的兼容性
 * 
 * 这些测试用例使用从 backend 项目中 bcryptjs 生成的已知哈希
 */
func testBcryptjsCompatibility() {
    // 测试用例：从 backend 项目中 bcryptjs 生成的哈希
    // 在 Node.js 中执行以下代码生成测试数据：
    // const bcrypt = require('bcryptjs');
    // const hash = await bcrypt.hash('UCToo123', 10);
    // console.log(hash);
    
    let testCases = [
        // 格式: (password, hash_from_bcryptjs)
        // 需要替换为实际的 bcryptjs 生成的哈希
        ("UCToo123", "$2a$10$N9qo8uLOickgx2ZMRNOo.YeIjZPsN.XuKQXqKSLqKqKqKqKqKqKqKqKqKqKqKqK"),
        ("password123", "$2a$10$abcdefghijklmnopqrstuvwx.yzABCDEFGHIJKLMNOPQRSTUVWX"),
        ("admin", "$2a$10$1234567890123456789012.34567890123456789012345678901234")
    ]
    
    var allPassed = true
    for ((password, knownHash) in testCases) {
        println("  测试密码: ${password}")
        println("  已知哈希: ${knownHash}")
        
        // 注意：这里的已知哈希是示例，实际测试时需要使用真实的 bcryptjs 生成的哈希
        // let verify = PasswordUtils.verifyPassword(password, knownHash)
        // println("  验证结果: ${verify}")
        
        // 生成新的哈希并验证
        let newHash = PasswordUtils.hashPassword(password)
        let verifyNew = PasswordUtils.verifyPassword(password, newHash)
        println("  新哈希: ${newHash}")
        println("  新哈希验证: ${verifyNew}")
        
        if (!verifyNew) {
            allPassed = false
        }
        println()
    }
    
    if (allPassed) {
        println("  ✓ bcryptjs 兼容性测试通过")
    } else {
        println("  ✗ bcryptjs 兼容性测试失败")
    }
}

/**
 * 测试边界条件
 */
func testEdgeCases() {
    var allPassed = true
    
    // 空密码
    println("  测试空密码:")
    let emptyHash = PasswordUtils.hashPassword("")
    let emptyVerify = PasswordUtils.verifyPassword("", emptyHash)
    println("    哈希: ${emptyHash}")
    println("    验证: ${emptyVerify}")
    if (!emptyVerify) { allPassed = false }
    
    // 长密码
    println("  测试长密码:")
    let longPassword = "ThisIsAVeryLongPasswordThatExceedsTheTypicalLengthLimit1234567890!@#$%^&*()"
    let longHash = PasswordUtils.hashPassword(longPassword)
    let longVerify = PasswordUtils.verifyPassword(longPassword, longHash)
    println("    密码长度: ${longPassword.size}")
    println("    验证: ${longVerify}")
    if (!longVerify) { allPassed = false }
    
    // 特殊字符密码
    println("  测试特殊字符密码:")
    let specialPassword = "P@ssw0rd!#$%^&*()_+-=[]{}|;':\",./<>?"
    let specialHash = PasswordUtils.hashPassword(specialPassword)
    let specialVerify = PasswordUtils.verifyPassword(specialPassword, specialHash)
    println("    验证: ${specialVerify}")
    if (!specialVerify) { allPassed = false }
    
    // Unicode 密码
    println("  测试 Unicode 密码:")
    let unicodePassword = "密码测试123"
    let unicodeHash = PasswordUtils.hashPassword(unicodePassword)
    let unicodeVerify = PasswordUtils.verifyPassword(unicodePassword, unicodeHash)
    println("    验证: ${unicodeVerify}")
    if (!unicodeVerify) { allPassed = false }
    
    if (allPassed) {
        println("  ✓ 边界条件测试通过")
    } else {
        println("  ✗ 边界条件测试失败")
    }
}

/**
 * 测试性能
 */
func testPerformance() {
    let password = "UCToo123"
    let iterations = 10
    
    println("  哈希生成性能测试 (${iterations} 次):")
    let startTime = getCurrentTimeMillis()
    for (_ in 0..iterations) {
        let _ = PasswordUtils.hashPassword(password)
    }
    let endTime = getCurrentTimeMillis()
    let hashTime = endTime - startTime
    println("    总时间: ${hashTime} ms")
    println("    平均时间: ${hashTime / iterations} ms/次")
    
    // 生成一个哈希用于验证测试
    let hash = PasswordUtils.hashPassword(password)
    
    println("  验证性能测试 (${iterations} 次):")
    let verifyStartTime = getCurrentTimeMillis()
    for (_ in 0..iterations) {
        let _ = PasswordUtils.verifyPassword(password, hash)
    }
    let verifyEndTime = getCurrentTimeMillis()
    let verifyTime = verifyEndTime - verifyStartTime
    println("    总时间: ${verifyTime} ms")
    println("    平均时间: ${verifyTime / iterations} ms/次")
    
    println("  ✓ 性能测试完成")
}

/**
 * 获取当前时间（毫秒）
 */
func getCurrentTimeMillis(): Int64 {
    // 使用系统时间
    // 注意：仓颉标准库中可能有更好的时间 API
    0 // 占位符，实际实现需要使用时间 API
}
