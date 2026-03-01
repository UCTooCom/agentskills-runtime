/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import std.collection.HashMap
import std.sync.Mutex
import std.time.DateTime
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

public class TokenInfo {
    public let accessToken: String
    public let refreshToken: String
    public let userId: String
    public let username: String
    public let createdAt: Int64
    public let expiresAt: Int64
    
    public init(accessToken: String, refreshToken: String, userId: String, username: String, expiresAt: Int64) {
        this.accessToken = accessToken
        this.refreshToken = refreshToken
        this.userId = userId
        this.username = username
        this.createdAt = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        this.expiresAt = expiresAt
    }
    
    public func isExpired(): Bool {
        let now = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        return now >= expiresAt
    }
    
    public func isValid(): Bool {
        return !accessToken.isEmpty() && !isExpired()
    }
}

public class TokenManager {
    private static let instance: TokenManager = TokenManager()
    private let _tokens: HashMap<String, TokenInfo>
    private let _mutex: Mutex
    
    private init() {
        _tokens = HashMap<String, TokenInfo>()
        _mutex = Mutex()
    }
    
    public static func getInstance(): TokenManager {
        instance
    }
    
    public func setToken(sessionId: String, tokenInfo: TokenInfo): Unit {
        _mutex.lock()
        _tokens.add(sessionId, tokenInfo)
        _mutex.unlock()
        LogUtils.info("[TokenManager] Token set for session: ${sessionId}, user: ${tokenInfo.username}")
    }
    
    public func getToken(sessionId: String): ?TokenInfo {
        _mutex.lock()
        let result = _tokens.get(sessionId)
        _mutex.unlock()
        return result
    }
    
    public func removeToken(sessionId: String): Unit {
        _mutex.lock()
        _tokens.remove(sessionId)
        _mutex.unlock()
        LogUtils.info("[TokenManager] Token removed for session: ${sessionId}")
    }
    
    public func hasValidToken(sessionId: String): Bool {
        _mutex.lock()
        let tokenOpt = _tokens.get(sessionId)
        _mutex.unlock()
        
        match (tokenOpt) {
            case Some(token) => return token.isValid()
            case None => return false
        }
    }
    
    public func getAccessToken(sessionId: String): ?String {
        _mutex.lock()
        let tokenOpt = _tokens.get(sessionId)
        _mutex.unlock()
        
        match (tokenOpt) {
            case Some(token) => 
                if (token.isValid()) {
                    return Some(token.accessToken)
                } else {
                    LogUtils.info("[TokenManager] Token expired for session: ${sessionId}")
                    return None
                }
            case None => return None
        }
    }
    
    public func parseLoginResponse(responseJson: JsonObject): ?TokenInfo {
        try {
            var accessToken = ""
            var refreshToken = ""
            var userId = ""
            var username = ""
            var expiresAt: Int64 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() + 86400000
            
            if (let Some(tokenValue) <- responseJson.get("access_token")) {
                accessToken = match (tokenValue) {
                    case s: JsonString => s.getValue()
                    case _ => tokenValue.toString()
                }
            }
            
            if (let Some(tokenValue) <- responseJson.get("refresh_token")) {
                refreshToken = match (tokenValue) {
                    case s: JsonString => s.getValue()
                    case _ => tokenValue.toString()
                }
            }
            
            if (let Some(userValue) <- responseJson.get("user")) {
                match (userValue) {
                    case userObj: JsonObject =>
                        if (let Some(idValue) <- userObj.get("id")) {
                            userId = match (idValue) {
                                case s: JsonString => s.getValue()
                                case _ => idValue.toString()
                            }
                        }
                        if (let Some(nameValue) <- userObj.get("username")) {
                            username = match (nameValue) {
                                case s: JsonString => s.getValue()
                                case _ => nameValue.toString()
                            }
                        }
                    case _ => ()
                }
            }
            
            if (accessToken.isEmpty()) {
                LogUtils.info("[TokenManager] No access_token found in response")
                return None
            }
            
            LogUtils.info("[TokenManager] Parsed login response - user: ${username}, token length: ${accessToken.size}")
            return Some(TokenInfo(accessToken, refreshToken, userId, username, expiresAt))
        } catch (ex: Exception) {
            LogUtils.error("[TokenManager] Error parsing login response: ${ex.message}")
            return None
        }
    }
    
    public func isLoginEndpoint(url: String): Bool {
        return url.contains("/auth/login") || url.contains("/auth/signin")
    }
}

public class SessionContext {
    private static let instance: SessionContext = SessionContext()
    private var _currentSessionId: Option<String> = None
    private let _mutex: Mutex
    
    private init() {
        _mutex = Mutex()
    }
    
    public static func getInstance(): SessionContext {
        instance
    }
    
    public func setCurrentSession(sessionId: String): Unit {
        _mutex.lock()
        _currentSessionId = Some(sessionId)
        _mutex.unlock()
        LogUtils.info("[SessionContext] Set current session: ${sessionId}")
    }
    
    public func clearCurrentSession(): Unit {
        _mutex.lock()
        _currentSessionId = None
        _mutex.unlock()
        LogUtils.info("[SessionContext] Cleared current session")
    }
    
    public func getCurrentSessionId(): ?String {
        _mutex.lock()
        let result = _currentSessionId
        _mutex.unlock()
        return result
    }
    
    public func getAccessToken(): ?String {
        _mutex.lock()
        let sessionIdOpt = _currentSessionId
        _mutex.unlock()
        
        match (sessionIdOpt) {
            case Some(sessionId) =>
                let tokenManager = TokenManager.getInstance()
                return tokenManager.getAccessToken(sessionId)
            case None => 
                LogUtils.info("[SessionContext] No current session, cannot get token")
                return None
        }
    }
}
