/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import magic.core.tool.{Tool, ToolException, ToolParameter, ToolResponse}
import magic.jsonable.{TypeSchema, JsonUtils}
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}

public class WebNotifyTool <: Tool {
    public static let NAME = "web_notify"

    public static let DESC = """
    Send a notification message to the WebMCP frontend client.
    Displays the message as a toast/notification in the frontend UI.
    Returns confirmation of the notification delivery.
    """

    public init() {}

    public prop name: String {
        get() { WebNotifyTool.NAME }
    }

    public prop description: String {
        get() { WebNotifyTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("message", "The notification message to display", TypeSchema.Str),
                ToolParameter("type", "Notification type: info, success, warning, error (default: info)", TypeSchema.Str),
                ToolParameter("duration", "Display duration in milliseconds (default: 3000)", TypeSchema.Int)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                "{\"message\": \"Task completed successfully\", \"type\": \"success\"}",
                "{\"message\": \"Warning: low memory\", \"type\": \"warning\", \"duration\": 5000}"
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
        let message = WebNotifyTool.extractString(args, "message")
        if (message.isEmpty()) {
            throw ToolException("Parameter 'message' is required")
        }
        let notifyType = WebNotifyTool.extractString(args, "type")
        let duration = WebNotifyTool.extractInt(args, "duration", 3000)
        LogUtils.info("[WebNotifyTool] Sending notification: [${notifyType}] ${message}")

        // 构建参数
        let argsMap = HashMap<String, JsonValue>()
        argsMap.add("message", JsonString(message))
        argsMap.add("type", JsonString(notifyType))
        argsMap.add("duration", JsonString(duration.toString()))

        // 通过 WebMCPToolHelper 统一执行 SSE 推送 + 阻塞等待
        WebMCPToolHelper.executeToolCall("web_notify", argsMap, 30000, "")
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

    public static func extractInt(args: HashMap<String, JsonValue>, key: String, defaultValue: Int64): Int64 {
        if (let Some(v) <- args.get(key)) {
            try {
                Int64.parse(v.toString())
            } catch (e: Exception) {
                defaultValue
            }
        } else {
            defaultValue
        }
    }
}
