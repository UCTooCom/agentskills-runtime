/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.utils

import blowfish.Bcrypt

/**
 * 密码工具类
 * 
 * 提供密码哈希和验证功能，与 backend 项目中的 bcryptjs 保持兼容
 */
public class PasswordUtils {
    /**
     * 默认的 cost 因子（与 backend 项目保持一致）
     */
    private static let DEFAULT_COST: Int64 = 10
    
    /**
     * 生成密码哈希
     * 
     * @param password 原始密码
     * @return bcrypt 格式的哈希字符串
     */
    public static func hashPassword(password: String): String {
        Bcrypt.hash(password, cost: DEFAULT_COST)
    }
    
    /**
     * 生成密码哈希（指定 cost）
     * 
     * @param password 原始密码
     * @param cost 成本因子（4-31），默认为 10
     * @return bcrypt 格式的哈希字符串
     */
    public static func hashPassword(password: String, cost: Int64): String {
        let validCost = if (cost < 4) { 4i64 } else if (cost > 31) { 31i64 } else { cost }
        Bcrypt.hash(password, cost: validCost)
    }
    
    /**
     * 验证密码
     * 
     * @param password 原始密码
     * @param hash 存储的 bcrypt 哈希
     * @return 验证成功返回 true，失败返回 false
     */
    public static func verifyPassword(password: String, hash: String): Bool {
        Bcrypt.verify(password, hash)
    }
    
    /**
     * 检查是否需要重新哈希
     * 
     * 当 cost 因子改变时，可以检查是否需要重新哈希密码
     * 
     * @param hash 存储的 bcrypt 哈希
     * @param newCost 新的成本因子
     * @return 需要重新哈希返回 true
     */
    public static func needsRehash(hash: String, newCost: Int64): Bool {
        try {
            // 解析哈希中的 cost 值
            let currentCost = extractCost(hash)
            currentCost != newCost
        } catch (e: Exception) {
            true
        }
    }
    
    /**
     * 从 bcrypt 哈希中提取 cost 值
     * 
     * @param hash bcrypt 哈希字符串
     * @return cost 值
     */
    private static func extractCost(hash: String): Int64 {
        // bcrypt 格式: $2a$10$...
        // 使用 split 方法分割
        let parts = hash.split("$", removeEmpty: true)
        if (parts.size >= 2) {
            return parseCost(parts[1])
        }
        10  // 默认值
    }
    
    /**
     * 解析 cost 值
     */
    private static func parseCost(str: String): Int64 {
        var result: Int64 = 0
        for (i in 0..str.size) {
            let byte = str[i]
            // '0' 的 ASCII 码是 48, '9' 是 57
            if (byte >= 48 && byte <= 57) {
                result = result * 10 + (Int64(byte) - 48)
            }
        }
        result
    }
}

/**
 * 密码验证结果
 */
public class PasswordVerifyResult {
    /// 验证是否成功
    public let success: Bool
    
    /// 是否需要重新哈希
    public let needsRehash: Bool
    
    public init(success: Bool, needsRehash!: Bool = false) {
        this.success = success
        this.needsRehash = needsRehash
    }
}
