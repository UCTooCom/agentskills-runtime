/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import std.collection.{HashMap, ArrayList}
import std.sync.Mutex
import stdx.encoding.json.JsonObject
import magic.log.LogUtils

/**
 * 前端工具定义
 *
 * 存储前端通过 MCP 协议注册的工具元数据。
 */
public class FrontendToolDefinition {
    /// 工具名称（唯一标识）
    public let name: String

    /// 工具标题（展示名称）
    public let title: String

    /// 工具描述
    public let description: String

    /// 输入参数 schema（JSON Schema 格式）
    public let inputSchema: JsonObject

    /// 前端工具的目标页面路由
    public let route: String

    /// 工具注解（可选，包含 route 等额外信息）
    public let annotations: ?JsonObject

    public init(
        name: String,
        title: String,
        description: String,
        inputSchema: JsonObject,
        route: String,
        annotations: ?JsonObject
    ) {
        this.name = name
        this.title = title
        this.description = description
        this.inputSchema = inputSchema
        this.route = route
        this.annotations = annotations
    }
}

/**
 * 前端工具注册表
 *
 * 存储前端通过 MCP 协议注册的工具元数据，供 system prompt 注入和 Agent ToolManager 同步使用。
 *
 * 包路径：magic.tool.webmcp（基础设施层，不依赖 magic.app.services.webmcp）
 */
public class FrontendToolRegistry {
    /// name → toolDef 映射
    private var _tools = HashMap<String, FrontendToolDefinition>()

    /// 保护并发访问
    private let _mutex = Mutex()

    public init() {}

    /**
     * 注册前端工具（覆盖同名工具）
     * @param toolDef 工具定义
     */
    public func register(toolDef: FrontendToolDefinition): Unit {
        synchronized(_mutex) {
            _tools.add(toolDef.name, toolDef)
        }
        LogUtils.debug("[FrontendToolRegistry] Registered tool: ${toolDef.name}, total=${_tools.size.toString()}")
    }

    /**
     * 注销前端工具
     * @param name 工具名称
     */
    public func unregister(name: String): Unit {
        synchronized(_mutex) {
            _tools.remove(name)
        }
        LogUtils.debug("[FrontendToolRegistry] Unregistered tool: ${name}, total=${_tools.size.toString()}")
    }

    /**
     * 获取所有已注册的前端工具
     * @return 工具定义列表
     */
    public func getAllTools(): ArrayList<FrontendToolDefinition> {
        synchronized(_mutex) {
            let result = ArrayList<FrontendToolDefinition>()
            for ((_, toolDef) in _tools) {
                result.add(toolDef)
            }
            return result
        }
    }

    /**
     * 获取指定名称的前端工具
     * @param name 工具名称
     * @return 工具定义（存在时），None 表示不存在
     */
    public func getTool(name: String): ?FrontendToolDefinition {
        synchronized(_mutex) {
            _tools.get(name)
        }
    }

    /**
     * 检查工具是否已注册
     * @param name 工具名称
     * @return true 表示已注册
     */
    public func contains(name: String): Bool {
        synchronized(_mutex) {
            _tools.contains(name)
        }
    }
}
