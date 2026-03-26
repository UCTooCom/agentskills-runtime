/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.registry

import std.collection.ArrayList
import magic.app.core.router.Router
import magic.app.core.log.{Logger, LoggerFactory}

/**
 * RouteRegistry - 路由注册表
 * 
 * 存储所有需要自动注册的路由信息
 */
public class RouteRegistry {
    private var entries: ArrayList<RouteEntry> = ArrayList<RouteEntry>()
    private let logger: Logger
    
    public init() {
        this.logger = LoggerFactory.getInstance().getLogger("RouteRegistry")
    }
    
    /// 添加路由注册项
    public func add(entry: RouteEntry): Unit {
        entries.add(entry)
    }
    
    /// 获取所有注册项（按优先级排序）
    public func getEntries(): ArrayList<RouteEntry> {
        // 按优先级排序
        let sorted = ArrayList<RouteEntry>()
        for (e in entries) {
            if (e.enabled) {
                sorted.add(e)
            }
        }
        // 简单冒泡排序
        let size = sorted.size
        for (i in 0..size) {
            for (j in 0..(size - i - 1)) {
                if (sorted[j].priority > sorted[j + 1].priority) {
                    let temp = sorted[j]
                    sorted[j] = sorted[j + 1]
                    sorted[j + 1] = temp
                }
            }
        }
        sorted
    }
    
    /// 注册所有路由
    public func registerAll(router: Router): Unit {
        let sortedEntries = getEntries()
        for (entry in sortedEntries) {
            try {
                entry.registerFunc(router)
                logger.info("✓ Route registered: ${entry.tableName} -> ${entry.routePath}")
            } catch (e: Exception) {
                logger.error("✗ Failed to register route: ${entry.tableName} - ${e.message}")
            }
        }
    }
}
