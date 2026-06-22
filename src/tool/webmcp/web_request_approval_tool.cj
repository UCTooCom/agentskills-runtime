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

public class WebRequestApprovalTool <: Tool {
    public static let NAME = "web_request_approval"

    public static let DESC = """
    Request user approval for an action through the WebMCP frontend.
    Displays an approval dialog to the user and waits for their response.
    Returns the user's decision (approved/rejected) and optional comment.
    """

    public init() {}

    public prop name: String {
        get() { WebRequestApprovalTool.NAME }
    }

    public prop description: String {
        get() { WebRequestApprovalTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("action", "Description of the action requiring approval", TypeSchema.Str),
                ToolParameter("details", "Additional details about the action", TypeSchema.Str),
                ToolParameter("timeout", "Timeout in seconds to wait for approval (default: 60)", TypeSchema.Int)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                "{\"action\": \"Delete file\", \"details\": \"Will delete /tmp/old_data.csv\"}",
                "{\"action\": \"Execute command\", \"details\": \"npm run build\", \"timeout\": 120}"
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
        let action = WebRequestApprovalTool.extractString(args, "action")
        if (action.isEmpty()) {
            throw ToolException("Parameter 'action' is required")
        }
        let details = WebRequestApprovalTool.extractString(args, "details")
        let timeout = WebRequestApprovalTool.extractInt(args, "timeout", 60)
        LogUtils.info("[WebRequestApprovalTool] Requesting approval for: ${action}")

        // 构建参数
        let argsMap = HashMap<String, JsonValue>()
        argsMap.add("action", JsonString(action))
        argsMap.add("details", JsonString(details))
        argsMap.add("timeout", JsonString(timeout.toString()))

        // 通过 WebMCPToolHelper 统一执行 SSE 推送 + 阻塞等待（审批超时 120 秒）
        WebMCPToolHelper.executeToolCall("web_request_approval", argsMap, 120000, "")
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
