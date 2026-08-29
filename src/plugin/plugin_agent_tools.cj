/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import magic.core.tool.{Tool, ToolParameter, ToolResponse}
import magic.jsonable.{JsonUtils, TypeSchema}

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

/**
 * PluginAgentTools - 插件管理器静态注入点（PS-T010）
 *
 * 工具注册发生在 PluginHostManager 创建之前（main.cj 工具装配先于插件系统启动），
 * 采用 GetSkillContentTool.setSkillManager 同款延迟注入模式：
 * 工具构造时不持有依赖，invoke 时经静态查找获取 PluginHostManager。
 */
public class PluginAgentTools {
    private static var _manager: Option<PluginHostManager> = None<PluginHostManager>

    public static func setPluginManager(manager: PluginHostManager): Unit {
        _manager = Some(manager)
    }

    public static func pluginManager(): Option<PluginHostManager> {
        _manager
    }
}

/**
 * PluginToolBase - 插件自引用工具基类
 *
 * 不复用 magic.tool.AbsTool 的原因（包依赖约束）：
 * magic.plugin 依赖 magic.skill（SkillBridge），而 magic.skill 已依赖 magic.tool
 * （composite_skill_tool_manager 等）；若 magic.plugin 再依赖 magic.tool 会形成
 * 包循环。故在本包内复刻 AbsTool 的 schema 序列化实现，仅依赖
 * magic.core.tool / magic.jsonable（二者均不依赖 magic.plugin，无环）。
 */
public abstract class PluginToolBase <: Tool {
    protected var _extra = HashMap<String, String>()

    override public prop extra: HashMap<String, String> {
        get() { _extra }
    }

    public func toJsonValue(): JsonValue {
        let properties = JsonObject()
        let required = ArrayList<String>()
        for (param in this.parameters) {
            let paramTypeSchema = param.typeSchema.toJsonValue().asObject()
            if (!param.description.isEmpty()) {
                paramTypeSchema.put("description", JsonString(param.description))
            }
            properties.put(param.name, paramTypeSchema)
            required.add(param.name)
        }
        return JsonUtils.buildJsonObject([
            ("name", JsonString(name)),
            ("description", JsonString(description)),
            ("parameters", JsonUtils.buildJsonObject([
                ("type", JsonString("object")),
                ("properties", properties),
                ("required", JsonUtils.buildJsonArray(required.toArray()))]))
        ])
    }

    /// 从工具参数提取字符串值（缺失/非字符串返回空串；get_skill_content_tool 同款）
    static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }

    /// 统一成功响应（JSON 信封，Agent 易解析）
    static func buildOk(fields: Array<(String, String)>): ToolResponse {
        let obj = JsonObject()
        for ((k, v) in fields) {
            obj.put(k, JsonString(v))
        }
        return ToolResponse(obj.toString(), isError: false)
    }

    /// 统一错误响应
    static func buildError(message: String): ToolResponse {
        let obj = JsonObject()
        obj.put("error", JsonString(message))
        return ToolResponse(obj.toString(), isError: true)
    }

    /// 取已注入的 PluginHostManager（未注入时返回 None）
    static func managerOrNull(): Option<PluginHostManager> {
        PluginAgentTools.pluginManager()
    }
}

/**
 * PluginInspectTool - 检视插件系统状态（plugin_inspect）
 *
 * 无参：全量插件列表（名 + 状态）；指定 plugin_name：单插件详情（含技能目录）。
 */
public class PluginInspectTool <: PluginToolBase {
    public static let NAME = "plugin_inspect"

    public static let DESC = """
    Inspect the plugin system: list all registered plugins with their states,
    or get details of one plugin (dependencies, services, skills) by name.
    Call without plugin_name for an overview of the plugin system.
    """

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { PluginInspectTool.NAME }
    }

    public prop description: String {
        get() { PluginInspectTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter(
                    "plugin_name",
                    "Optional plugin name to inspect in detail. If not specified, lists all plugins.",
                    TypeSchema.Str)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "plugin_name": "hello"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        if (PluginToolBase.managerOrNull().isNone()) {
            return PluginToolBase.buildError("PluginHostManager not initialized")
        }
        let manager = PluginToolBase.managerOrNull().getOrThrow()
        let pluginName = PluginToolBase.extractString(args, "plugin_name")
        let report = if (pluginName.isEmpty()) {
            manager.inspect()
        } else {
            manager.inspect(name: Some(pluginName))
        }
        if (report.startsWith("plugin not found")) {
            return PluginToolBase.buildError(report)
        }
        let obj = JsonObject()
        obj.put("report", JsonString(report))
        return ToolResponse(obj.toString(), isError: false)
    }
}

/**
 * PluginActivateTool - 激活指定插件（plugin_activate）
 *
 * 含依赖校验：依赖缺失时返回明确错误（PluginError.message）。
 */
public class PluginActivateTool <: PluginToolBase {
    public static let NAME = "plugin_activate"

    public static let DESC = """
    Activate a plugin by name. Validates dependencies before activation.
    The plugin must be registered and in Pending state (or already Active, which is a no-op).
    """

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { PluginActivateTool.NAME }
    }

    public prop description: String {
        get() { PluginActivateTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("plugin_name", "The name of the plugin to activate", TypeSchema.Str)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "plugin_name": "hello"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        if (PluginToolBase.managerOrNull().isNone()) {
            return PluginToolBase.buildError("PluginHostManager not initialized")
        }
        let manager = PluginToolBase.managerOrNull().getOrThrow()
        let pluginName = PluginToolBase.extractString(args, "plugin_name")
        if (pluginName.isEmpty()) {
            return PluginToolBase.buildError("Parameter 'plugin_name' is required")
        }
        match (manager.activate(pluginName)) {
            case Ok(_) =>
                return PluginToolBase.buildOk([
                    ("plugin", pluginName),
                    ("action", "activated")
                ])
            case Err(e) =>
                return PluginToolBase.buildError(e.message())
            case _ =>
                return PluginToolBase.buildError("unexpected result for activate '${pluginName}'")
        }
    }
}

/**
 * PluginDeactivateTool - 停用指定插件（plugin_deactivate）
 *
 * 完整卸载：onDeactivate -> onUnload -> 清理栈逆序 -> 订阅清理 -> 注册表回滚。
 */
public class PluginDeactivateTool <: PluginToolBase {
    public static let NAME = "plugin_deactivate"

    public static let DESC = """
    Deactivate a plugin by name. Performs a full unload: lifecycle hooks,
    reverse-order cleanup of registered resources, event unsubscription,
    and registry rollback. Other plugins are not affected.
    """

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { PluginDeactivateTool.NAME }
    }

    public prop description: String {
        get() { PluginDeactivateTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("plugin_name", "The name of the plugin to deactivate", TypeSchema.Str)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "plugin_name": "hello"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        if (PluginToolBase.managerOrNull().isNone()) {
            return PluginToolBase.buildError("PluginHostManager not initialized")
        }
        let manager = PluginToolBase.managerOrNull().getOrThrow()
        let pluginName = PluginToolBase.extractString(args, "plugin_name")
        if (pluginName.isEmpty()) {
            return PluginToolBase.buildError("Parameter 'plugin_name' is required")
        }
        match (manager.deactivate(pluginName)) {
            case Ok(_) =>
                return PluginToolBase.buildOk([
                    ("plugin", pluginName),
                    ("action", "deactivated")
                ])
            case Err(e) =>
                return PluginToolBase.buildError(e.message())
            case _ =>
                return PluginToolBase.buildError("unexpected result for deactivate '${pluginName}'")
        }
    }
}
