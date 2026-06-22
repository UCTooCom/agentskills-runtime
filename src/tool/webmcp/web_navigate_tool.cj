/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import magic.core.tool.{Tool, ToolException, ToolParameter, ToolResponse}
import magic.jsonable.{TypeSchema, JsonUtils}
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}

public class WebNavigateTool <: Tool {
    public static let NAME = "web_navigate"

    public static let DESC = """
    Navigate the frontend to a specified page or URL.
    Sends a navigation command to the WebMCP frontend client.
    Returns the navigation result from the frontend.
    """

    /// 动态描述（可由 WebMCPController 注入菜单数据后更新）
    /// 初始为默认描述，注入菜单后追加可用页面列表
    private var _dynamicDescription: String = WebNavigateTool.DESC

    public init() {}

    public prop name: String {
        get() { WebNavigateTool.NAME }
    }

    public prop description: String {
        get() { _dynamicDescription }
    }

    /**
     * 更新工具的动态描述
     * 由 WebMCPController 在会话建立时调用，注入当前用户可访问的页面菜单信息
     * @param menuInfo 菜单信息字符串（已格式化的页面路径列表）
     */
    public func updateDynamicDescription(menuInfo: String): Unit {
        if (menuInfo.isEmpty()) {
            _dynamicDescription = WebNavigateTool.DESC
        } else {
            _dynamicDescription = "${WebNavigateTool.DESC}\n\n【当前用户可访问的页面】\n${menuInfo}"
        }
        LogUtils.info("[WebNavigateTool] Dynamic description updated, length=${_dynamicDescription.size.toString()}")
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("url", "The URL or route path to navigate to", TypeSchema.Str),
                ToolParameter("title", "Optional title for the navigation", TypeSchema.Str)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                "{\"url\": \"/dashboard\"}",
                "{\"url\": \"https://example.com\", \"title\": \"Example\"}"
            ]
        }
    }

    public prop extra: HashMap<String, String> {
        get() {
            HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true"),
                ("category", "webmcp")
            ])
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let url = WebNavigateTool.extractString(args, "url")
        if (url.isEmpty()) {
            throw ToolException("Parameter 'url' is required")
        }
        let title = WebNavigateTool.extractString(args, "title")
        LogUtils.info("[WebNavigateTool] Navigating to: ${url}")

        // 构建参数
        let argsMap = HashMap<String, JsonValue>()
        argsMap.add("url", JsonString(url))
        if (!title.isEmpty()) {
            argsMap.add("title", JsonString(title))
        }

        // 通过 WebMCPToolHelper 统一执行 SSE 推送 + 阻塞等待
        WebMCPToolHelper.executeToolCall("web_navigate", argsMap, 30000, "")
    }

    public func toJsonValue(): JsonValue {
        let properties = JsonObject()
        let required = ArrayList<String>()
        for (param in this.parameters) {
            properties.put(param.name, param.typeSchema.toJsonValue())
            required.add(param.name)
        }
        JsonUtils.buildJsonObject([
            ("name", JsonString(name)),
            ("description", JsonString(description)),
            ("parameters", JsonUtils.buildJsonObject([
                ("type", JsonString("object")),
                ("properties", properties),
                ("required", JsonUtils.buildJsonArray(required.toArray()))]))
        ])
    }

    public static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(v) <- args.get(key)) {
            match (v) {
                case s: JsonString => s.getValue()
                case _ => v.toString()
            }
        } else {
            ""
        }
    }
}
