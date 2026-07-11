/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 * 
 * bcrypt 交叉验证测试
 * 
 * 验证 blowfish-cj 是否能正确验证 bcryptjs 生成的哈希
 */
package magic.test

import blowfish.Bcrypt
import magic.app.utils.auth.BcryptUtil
import magic.log.LogUtils
import std.console.*

/**
 * bcrypt 交叉验证测试
 */
main() {
    println("=== bcrypt 交叉验证测试 ===")
    println("验证 blowfish-cj 是否能正确验证 bcryptjs 生成的哈希")
    println()
    
    let bcryptUtil = BcryptUtil(saltRounds: 10)
    
    // 测试用例：从 bcryptjs 生成的哈希
    let testCases = [
        // (password, hash, description)
        (
            "UCToo123", 
            "\$2b\$10\$5Kb4jSyNwYYYKIfFxYcDfu2RN7sUt5imN4DtVUVAk4FCMuwNvW.li",
            "默认密码"
        ),
        (
            "password123", 
            "\$2b\$10\$nH.1JDsnrwcWw5gm.Ps30Ocp9g4PmXSvoh6BhqsYLbjAOnS137iaW",
            "普通密码"
        ),
        (
            "admin", 
            "\$2b\$10\$tzNH8Ajp7iY3jDELGbf1PeTFNPAJEdF1qMleKQDOPgkty3XKE.cUG",
            "管理员密码"
        ),
        (
            "P@ssw0rd!#\$%^&*()", 
            "\$2b\$10\$EJXTEOkmmLySQ9ZhNve5q.fkcOmySWtGDkL.yw/ZnR1iSJbpSxO3.",
            "特殊字符密码"
        ),
        (
            "密码测试123", 
            "\$2b\$10\$IPpUxAJU39XAfTSNfM.j7OJz3/dTbWGokghn1ul2cXzexSawC4BGu",
            "Unicode密码"
        )
    ]
    
    println("1. 验证 bcryptjs 生成的哈希:")
    println()
    
    var allPassed = true
    for ((password, hash, description) in testCases) {
        println("  测试: ${description}")
        println("    密码: ${password}")
        println("    哈希: ${hash}")
        
        // 使用 blowfish-cj 验证
        let verify = bcryptUtil.comparePassword(password, hash)
        println("    验证结果: ${verify}")
        
        if (!verify) {
            allPassed = false
            println("    ✗ 失败")
        } else {
            println("    ✓ 通过")
        }
        println()
    }
    
    println("2. 测试生成新哈希并验证:")
    println()
    
    for ((password, _, description) in testCases) {
        println("  测试: ${description}")
        
        // 使用 blowfish-cj 生成新哈希
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
    
    println("3. 测试不同 cost 因子:")
    println()
    
    let costTestCases = [
        ("UCToo123", "\$2b\$04\$cYXkUIKx4DFz/AaTzfvahutR3fdw.9D6YMABz5SEhJ.GozcPWWzwu", "Cost=4"),
        ("UCToo123", "\$2b\$10\$f8wfHUglRPk/CgItpOF0JeXz7Z4pfNo4IDIip9wjX3jz5WDklXEAG", "Cost=10"),
        ("UCToo123", "\$2b\$12\$2qEHucNWm9EVCvr5G7KinOESTlWknzBex2NZx.3WviID7C2r4.x2W", "Cost=12")
    ]
    
    for ((password, hash, description) in costTestCases) {
        println("  ${description}:")
        println("    哈希: ${hash}")
        
        let verify = bcryptUtil.comparePassword(password, hash)
        println("    验证结果: ${verify}")
        
        if (!verify) {
            allPassed = false
            println("    ✗ 失败")
        } else {
            println("    ✓ 通过")
        }
        println()
    }
    
    println("4. 测试边界条件:")
    println()
    
    // 空密码
    let emptyHash = "\$2b\$10\$9hsHZ2u1Ti8ETtSEa8I4guLEMEsS1SMhC4U6gljTyKnffHBICZ2v2"
    println("  空密码:")
    println("    哈希: ${emptyHash}")
    let emptyVerify = bcryptUtil.comparePassword("", emptyHash)
    println("    验证结果: ${emptyVerify}")
    if (!emptyVerify) { allPassed = false }
    println()
    
    // 长密码
    let longPassword = "ThisIsAVeryLongPasswordThatExceedsTheTypicalLengthLimit1234567890!@#\$%^&*()"
    let longHash = bcryptUtil.hashPassword(longPassword)
    let longVerify = bcryptUtil.comparePassword(longPassword, longHash)
    println("  长密码 (${longPassword.size} 字符):")
    println("    验证结果: ${longVerify}")
    if (!longVerify) { allPassed = false }
    println()
    
    println("=== 测试结果 ===")
    if (allPassed) {
        println("✓ 所有测试通过")
        println("blowfish-cj 与 bcryptjs 完全兼容")
    } else {
        println("✗ 部分测试失败")
        println("需要检查 bcrypt 实现的差异")
    }
}
