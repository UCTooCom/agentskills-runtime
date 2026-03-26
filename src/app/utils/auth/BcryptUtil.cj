/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.utils.auth

import blowfish.Bcrypt
import magic.log.LogUtils

/**
 * BcryptUtil - 密码加密工具类
 * 
 * 提供密码加密和验证功能
 * 基于 blowfish-cj 项目的 bcrypt 实现
 * 与 backend 项目中的 bcryptjs 保持兼容
 */
public class BcryptUtil {
    /// 默认的 cost 因子（与 backend 项目保持一致）
    private let saltRounds: Int32
    
    /**
     * 构造函数
     * @param saltRounds cost 因子，默认为 10
     */
    public init(saltRounds!: Int32 = 10) {
        this.saltRounds = saltRounds
    }
    
    /**
     * 生成密码哈希
     * 
     * 使用 bcrypt 算法生成密码哈希，与 backend 项目中的 bcryptjs 兼容
     * 
     * @param password 原始密码
     * @return bcrypt 格式的哈希字符串（$2a$cost$salt$hash）
     */
    public func hashPassword(password: String): String {
        Bcrypt.hash(password, cost: Int64(saltRounds))
    }
    
    /**
     * 验证密码
     * 
     * 验证密码是否与存储的 bcrypt 哈希匹配
     * 支持 bcrypt 的 2a、2b、2y 版本
     * 
     * @param password 原始密码
     * @param hash 存储的 bcrypt 哈希值
     * @return 验证成功返回 true，失败返回 false
     */
    public func comparePassword(password: String, hash: String): Bool {
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
    public func needsRehash(hash: String, newCost: Int32): Bool {
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
    private func extractCost(hash: String): Int32 {
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
    private func parseCost(str: String): Int32 {
        var result: Int32 = 0
        for (i in 0..str.size) {
            let byte = str[i]
            // '0' 的 ASCII 码是 48, '9' 是 57
            if (byte >= 48 && byte <= 57) {
                result = result * 10 + (Int32(byte) - 48)
            }
        }
        
        result
    }
    
    /**
     * 验证哈希格式
     * 
     * 检查给定的字符串是否是有效的 bcrypt 哈希格式
     * 
     * @param hash 要验证的哈希字符串
     * @return 是有效的 bcrypt 哈希返回 true
     */
    public static func isValidHash(hash: String): Bool {
        // bcrypt 哈希格式: $2a$10$...（至少 60 个字符）
        if (hash.size < 60) {
            return false
        }
        
        // 检查前缀
        if (!hash.startsWith("$2a$") && 
            !hash.startsWith("$2b$") && 
            !hash.startsWith("$2y$")) {
            return false
        }
        
        true
    }
    
    /**
     * 获取当前配置的 cost 因子
     * 
     * @return cost 因子
     */
    public func getSaltRounds(): Int32 {
        saltRounds
    }
}
