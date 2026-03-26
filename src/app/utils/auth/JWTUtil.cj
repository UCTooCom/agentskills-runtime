/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.utils.auth

import std.time.DateTime
import std.collection.HashMap
import jwt4cj.{JWT, Algorithm, JWTVerifier, DecodedJWT}
import magic.log.LogUtils

/**
 * JWT工具类
 * 
 * 提供JWT Token的生成和验证功能
 * 使用jwt4cj库实现标准的JWT功能,与backend项目保持一致
 */
public class JWTUtil {
    private let secretKey: String
    private let accessTokenValidity: Int64  // 秒
    private let refreshTokenValidity: Int64  // 秒
    
    public init(secretKey: String, accessTokenValidity: Int64, refreshTokenValidity: Int64) {
        this.secretKey = secretKey
        this.accessTokenValidity = accessTokenValidity
        this.refreshTokenValidity = refreshTokenValidity
    }
    
    /**
     * 生成access_token
     * @param userId 用户ID
     * @param sessionId 会话ID
     * @return access_token字符串
     */
    public func generateAccessToken(userId: String, sessionId: String): String {
        try {
            // 计算过期时间 - 使用Duration.second
            let now = DateTime.now()
            let expiresAt = now + Duration.second * accessTokenValidity
            
            // 使用jwt4cj生成JWT token
            // Payload结构: { user: userId, session: sessionId }
            let token = JWT.create()
                .withClaim("user", userId)
                .withClaim("session", sessionId)
                .withIssuedAt(now)
                .withExpiresAt(expiresAt)
                .sign(Algorithm.HMAC256(secretKey))
            
            token
        } catch (e: Exception) {
            LogUtils.error("generateAccessToken failed: ${e.message}")
            ""
        }
    }
    
    /**
     * 生成refresh_token
     * @param userId 用户ID
     * @param sessionId 会话ID
     * @return refresh_token字符串
     */
    public func generateRefreshToken(userId: String, sessionId: String): String {
        try {
            // 计算过期时间
            let now = DateTime.now()
            let expiresAt = now + Duration.second * refreshTokenValidity
            
            // 使用jwt4cj生成JWT token
            let token = JWT.create()
                .withClaim("user", userId)
                .withClaim("session", sessionId)
                .withIssuedAt(now)
                .withExpiresAt(expiresAt)
                .sign(Algorithm.HMAC256(secretKey))
            
            token
        } catch (e: Exception) {
            LogUtils.error("generateRefreshToken failed: ${e.message}")
            ""
        }
    }
    
    /**
     * 验证Token
     * @param token Token字符串
     * @return 验证成功返回JWTPayload，失败返回None
     */
    public func verifyToken(token: String): Option<JWTPayload> {
        try {
            // 使用jwt4cj验证token
            let verifier = JWT.require(Algorithm.HMAC256(secretKey))
                .build()
            
            let decoded: DecodedJWT = verifier.verify(token)
            
            // 提取payload数据
            let userId = decoded.getClaim("user").asString()
            let sessionId = decoded.getClaim("session").asString()
            let issuedAt = decoded.getIssuedAt()
            let expiresAt = decoded.getExpiresAt()
            
            // 转换时间戳
            let timestamp = dateTimeToTimestamp(issuedAt)
            let expiry = dateTimeToTimestamp(expiresAt)
            
            let result = JWTPayload(userId, sessionId, timestamp, expiry)
            Some<JWTPayload>(result)
        } catch (e: Exception) {
            LogUtils.error("verifyToken failed: ${e.message}")
            None<JWTPayload>
        }
    }
    
    /**
     * 从Token中提取用户ID
     * @param token Token字符串
     * @return 用户ID
     */
    public func getUserIdFromToken(token: String): ?String {
        if (let Some(payload) <- verifyToken(token)) {
            Some<String>(payload.userId)
        } else {
            None<String>
        }
    }
    
    /**
     * 从Token中提取会话ID
     * @param token Token字符串
     * @return 会话ID
     */
    public func getSessionIdFromToken(token: String): ?String {
        if (let Some(payload) <- verifyToken(token)) {
            Some<String>(payload.sessionId)
        } else {
            None<String>
        }
    }
    
    // ==================== 辅助方法 ====================
    
    /**
     * DateTime转时间戳(秒)
     */
    private func dateTimeToTimestamp(dt: DateTime): Int64 {
        // 获取Unix时间戳(秒) - 使用ofEpoch的反向计算
        let epoch = DateTime.ofEpoch(second: 0, nanosecond: 0)
        let duration = dt - epoch
        // Duration转秒数
        duration.toSeconds()
    }
}

/**
 * JWT Payload数据结构
 */
public class JWTPayload {
    public let userId: String
    public let sessionId: String
    public let timestamp: Int64
    public let expiry: Int64
    
    public init(userId: String, sessionId: String, timestamp: Int64, expiry: Int64) {
        this.userId = userId
        this.sessionId = sessionId
        this.timestamp = timestamp
        this.expiry = expiry
    }
}
