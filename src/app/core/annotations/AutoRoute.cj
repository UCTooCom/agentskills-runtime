/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.annotations

import std.reflect.Annotation

/**
 * AutoRoute - 自动路由注册注解
 * 
 * 用于标记需要自动注册的路由类
 * 
 * 使用示例：
 * ```cangjie
 * @AutoRoute[
 *     tableName: "entity",
 *     routePath: "/api/v1/uctoo/entity",
 *     priority: 100,
 *     enabled: true
 * ]
 * public class EntityRoute {
 *     // ...
 * }
 * ```
 */
@Annotation
public class AutoRoute {
    /// 表名（用于日志和调试）
    public let tableName: String
    
    /// 路由路径前缀
    public let routePath: String
    
    /// 注册优先级（数字越小优先级越高）
    public let priority: Int32
    
    /// 是否启用
    public let enabled: Bool
    
    public const init(
        tableName: String,
        routePath: String,
        priority: Int32,
        enabled: Bool
    ) {
        this.tableName = tableName
        this.routePath = routePath
        this.priority = priority
        this.enabled = enabled
    }
}
