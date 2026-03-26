/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.registry

import magic.app.core.router.Router

/**
 * RouteEntry - 路由注册项
 * 
 * 存储单个路由的注册信息
 */
public struct RouteEntry {
    /// 表名（用于日志和调试）
    public let tableName: String
    
    /// 路由路径前缀
    public let routePath: String
    
    /// 注册优先级（数字越小优先级越高）
    public let priority: Int32
    
    /// 是否启用
    public let enabled: Bool
    
    /// 注册函数
    public let registerFunc: (Router) -> Router
    
    public init(
        tableName: String,
        routePath: String,
        priority: Int32,
        enabled: Bool,
        registerFunc: (Router) -> Router
    ) {
        this.tableName = tableName
        this.routePath = routePath
        this.priority = priority
        this.enabled = enabled
        this.registerFunc = registerFunc
    }
}
