/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import magic.core.tool.{Tool, ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonNull}
import std.collection.{HashMap, ArrayList}
import magic.log.LogUtils

/**
 * 前端工具适配器
 * 将前端通过 WebSocket 注册的工具转换为后端 Tool 接口实现
 */
public class FrontendToolAdapter <: Tool {
    private let _name: String
    private let _title: String
    private let _description: String
    private let _route: String
    private let _inputSchema: JsonObject
    private let _extra: HashMap<String, String>

    public init(
        name: String,
        title: ?String,
        description: ?String,
        route: ?String,
        inputSchema: ?JsonObject
    ) {
        this._name = name
        if (title.isNone() || title.getOrThrow().isEmpty()) {
            this._title = name
        } else {
            this._title = title.getOrThrow()
        }
        this._description = if (description.isSome()) { description.getOrThrow() } else { "" }
        this._route = if (route.isSome()) { route.getOrThrow() } else { "" }
        this._inputSchema = if (inputSchema.isSome()) { inputSchema.getOrThrow() } else { JsonObject() }
        this._extra = HashMap<String, String>()

        if (!this._route.isEmpty()) {
            _extra.add("route", this._route)
        }
        _extra.add("source", "frontend")
    }

    override public prop name: String {
        get() { _name }
    }

    override public prop description: String {
        get() {
            if (!_description.isEmpty()) {
                return _description
            }
            let desc = StringBuilder()
            desc.append("前端页面工具: ${_title}")
            if (!_route.isEmpty()) {
                desc.append(" (页面: ${_route})")
            }
            return desc.toString()
        }
    }

    override public prop parameters: Array<ToolParameter> {
        get() {
            _parseInputSchema(_inputSchema)
        }
    }

    override public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    override public prop examples: Array<String> {
        get() { [] }
    }

    override public prop extra: HashMap<String, String> {
        get() { _extra }
    }

    private func _parseInputSchema(inputSchema: JsonObject): Array<ToolParameter> {
        let params = ArrayList<ToolParameter>()
        let propertiesOpt = inputSchema.get("properties")

        if (propertiesOpt.isSome()) {
            let propValue = propertiesOpt.getOrThrow()
            if (propValue is JsonObject) {
                let properties = propValue.asObject()
                for ((key, value) in properties.getFields()) {
                    if (value is JsonObject) {
                        let paramObj = value.asObject()
                        let descriptionOpt = paramObj.get("description")
                        var paramDesc = ""
                        if (descriptionOpt.isSome()) {
                            let descVal = descriptionOpt.getOrThrow()
                            if (descVal is JsonString) {
                                paramDesc = descVal.asString().getValue()
                            }
                        }

                        let param = ToolParameter(key, paramDesc, TypeSchema.Str)
                        params.add(param)
                    }
                }
            }
        }

        if (params.size == 0) {
            params.add(ToolParameter("args", "JSON格式的请求参数", TypeSchema.Str))
        }

        return params.toArray()
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        LogUtils.info("Frontend tool invoked: ${_name} with args: ${args}")

        let resultBuilder = StringBuilder()
        resultBuilder.append("前端工具调用请求已发送: ${_name}")
        if (!_route.isEmpty()) {
            resultBuilder.append("\n目标页面: ${_route}")
        }
        resultBuilder.append("\n参数: ")

        var first = true
        for ((key, value) in args) {
            if (!first) {
                resultBuilder.append(", ")
            }
            resultBuilder.append("${key}=${value.toString()}")
            first = false
        }

        let responseContent = resultBuilder.toString()
        return ToolResponse(responseContent, isError: false)
    }

    public func toJsonValue(): JsonValue {
        let obj = JsonObject()
        obj.put("name", JsonString(_name))
        obj.put("description", JsonString(this.description))
        obj.put("route", JsonString(_route))
        obj.put("source", JsonString("frontend"))
        return obj
    }
}