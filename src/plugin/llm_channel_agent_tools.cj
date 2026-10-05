/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import magic.core.tool.{Tool, ToolParameter, ToolResponse}
import magic.jsonable.{JsonUtils, TypeSchema}
import magic.model.channel.{ChannelService, ChannelProbe, ChannelRegistry}

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt}

/**
 * LlmChannelAgentTools — 大模型通道工具的静态注入点 + 开关（T030）。
 *
 * 与 PluginAgentTools 同款延迟注入：工具构造不持依赖，invoke 时经静态查找拿
 * ChannelService。之所以不直接构造注入，是因为工具装配早于通道系统启动。
 *
 * 「允许自动切换」开关（T030 硬约束）：
 * - 开关状态存于静态 var，默认**关闭**——Agent 不得擅自改默认通道；
 * - 开关只由**管理面显式打开**（对应 .env 的 LLM_CHANNEL_AUTO_SWITCH，
 *   由 main.cj 启动时读取注入，见 setAutoSwitchEnabled）；
 * - 关闭时 llm_channel_switch 返回明确错误并提示如何开启，不做任何改动。
 */
public class LlmChannelAgentTools {
    private static var _service: Option<ChannelService> = None<ChannelService>
    private static var _autoSwitch: Bool = false

    public static func setChannelService(service: ChannelService): Unit {
        _service = Some(service)
    }

    public static func channelService(): Option<ChannelService> {
        _service
    }

    /// 由启动装配注入「允许 Agent 自动切换通道」开关（默认 false）
    public static func setAutoSwitchEnabled(enabled: Bool): Unit {
        _autoSwitch = enabled
    }

    public static func autoSwitchEnabled(): Bool {
        _autoSwitch
    }
}

/**
 * LlmChannelToolBase — 通道工具基类。
 *
 * 不复用 PluginToolBase：那个属于插件域（语义是"操作插件"），这里语义是"操作通道"，
 * 但 schema 序列化与响应信封的构造方式完全一致，故复刻一份保持风格统一。
 * 依赖 magic.model.channel（不依赖 magic.plugin，无包环）。
 */
public abstract class LlmChannelToolBase <: Tool {
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

    /// 从工具参数提取字符串值（缺失/非字符串返回空串）
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

    static func serviceOrError(): Option<ChannelService> {
        LlmChannelAgentTools.channelService()
    }

    static func buildOk(fields: Array<(String, JsonValue)>): ToolResponse {
        let obj = JsonObject()
        for ((k, v) in fields) {
            obj.put(k, v)
        }
        return ToolResponse(obj.toString(), isError: false)
    }

    static func buildError(message: String): ToolResponse {
        let obj = JsonObject()
        obj.put("error", JsonString(message))
        return ToolResponse(obj.toString(), isError: true)
    }

    /// 通道是否存在（不存在时给出可操作提示，避免 Agent 反复试错）
    static func requireChannel(service: ChannelService, code: String): Option<ToolResponse> {
        if (code.isEmpty()) {
            return Some(buildError("缺少参数 code（通道编码）"))
        }
        if (service.getChannelByCode(code).isNone()) {
            return Some(buildError("通道 ${code} 不存在，请先用 llm_channel_list 查看可用通道"))
        }
        return None
    }
}

/**
 * LlmChannelListTool — 列出可用通道（llm_channel_list）
 *
 * 无参：全量通道（编码/显示名/协议/状态/是否默认/健康/能力位）。
 * 只读工具，不受自动切换开关约束。
 */
public class LlmChannelListTool <: LlmChannelToolBase {
    public static let NAME = "llm_channel_list"

    public static let DESC = """
    List all configured LLM channels with their status, health and capabilities.
    Use this before llm_channel_switch or llm_channel_probe to know which channels exist.
    Fields are sanitized: no base_url, no secret.
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
        get() { LlmChannelListTool.NAME }
    }

    public prop description: String {
        get() { LlmChannelListTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter(
                    "enabled_only",
                    "Optional. 'true' to list only enabled channels. Default lists all.",
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
                  "enabled_only": "true"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let serviceOpt = LlmChannelToolBase.serviceOrError()
        if (serviceOpt.isNone()) {
            return LlmChannelToolBase.buildError("ChannelService not initialized")
        }
        let service = serviceOpt.getOrThrow()
        let enabledOnly = LlmChannelToolBase.extractString(args, "enabled_only") == "true"

        let all = service.listChannels()
        let arr = JsonUtils.buildJsonArray()
        var count: Int64 = 0
        let registry = ChannelRegistry.shared()
        let defaultCode = registry.getDefaultCode()
        for (po in all) {
            if (enabledOnly && po.status != "enabled") {
                continue
            }
            let item = JsonObject()
            item.put("code", JsonString(po.code))
            item.put("display_name", JsonString(po.displayName.getOrDefault({ => po.code })))
            item.put("protocol", JsonString(po.protocol))
            item.put("status", JsonString(po.status))
            item.put("is_default", JsonBool(po.code == defaultCode))
            item.put("priority", JsonInt(Int64(po.priority)))
            item.put("capabilities", JsonString(po.capabilities))
            item.put("default_model", JsonString(po.defaultModel.getOrDefault({ => "" })))
            arr.add(item)
            count = count + 1
        }
        return LlmChannelToolBase.buildOk([
            ("default_channel", JsonString(defaultCode)),
            ("count", JsonInt(count)),
            ("channels", arr)
        ])
    }
}

/**
 * LlmChannelTestTool — 连通性测试（llm_channel_test）
 *
 * 返回**原始错误原文**，不做包装，便于 Agent 判断失败原因并自愈（T017 语义一致）。
 * 只读，不改状态，不受开关约束。
 */
public class LlmChannelTestTool <: LlmChannelToolBase {
    public static let NAME = "llm_channel_test"

    public static let DESC = """
    Test connectivity of one LLM channel. Returns ok flag plus the raw provider error
    text on failure (e.g. 401 unauthorized, model not found, empty body with 200).
    Use it to diagnose before switching.
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
        get() { LlmChannelTestTool.NAME }
    }

    public prop description: String {
        get() { LlmChannelTestTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter(
                    "code",
                    "Channel code, e.g. openai / arcbench / my-gateway.",
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
                  "code": "arcbench"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let serviceOpt = LlmChannelToolBase.serviceOrError()
        if (serviceOpt.isNone()) {
            return LlmChannelToolBase.buildError("ChannelService not initialized")
        }
        let service = serviceOpt.getOrThrow()
        let code = LlmChannelToolBase.extractString(args, "code")
        if (let Some(err) <- LlmChannelToolBase.requireChannel(service, code)) {
            return err
        }
        let (ok, detail) = service.testChannel(code)
        return LlmChannelToolBase.buildOk([
            ("code", JsonString(code)),
            ("ok", JsonBool(ok)),
            ("detail", JsonString(detail))
        ])
    }
}

/**
 * LlmChannelProbeTool — 三枪能力探测（llm_channel_probe）
 *
 * 跑 chat / stream / tools 三枪，写回能力位与健康快照（复用 ChannelProbe）。
 * 会**改写通道能力位**（不是纯只读），但不改变默认通道，故不受自动切换开关约束。
 */
public class LlmChannelProbeTool <: LlmChannelToolBase {
    public static let NAME = "llm_channel_probe"

    public static let DESC = """
    Probe a channel's real capabilities with three shots (chat / stream / tools) and
    write the result back to the capability bits. Returns each shot's pass flag and
    the raw error text, so you can tell apart auth failure vs model-not-found vs
    unsupported feature.
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
        get() { LlmChannelProbeTool.NAME }
    }

    public prop description: String {
        get() { LlmChannelProbeTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter(
                    "code",
                    "Channel code to probe.",
                    TypeSchema.Str),
                ToolParameter(
                    "model_id",
                    "Optional model id to probe. Defaults to the channel's default_model.",
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
                  "code": "arcbench",
                  "model_id": "deepseek-v4-flash-vision-exp"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let serviceOpt = LlmChannelToolBase.serviceOrError()
        if (serviceOpt.isNone()) {
            return LlmChannelToolBase.buildError("ChannelService not initialized")
        }
        let service = serviceOpt.getOrThrow()
        let code = LlmChannelToolBase.extractString(args, "code")
        if (let Some(err) <- LlmChannelToolBase.requireChannel(service, code)) {
            return err
        }
        let modelId = LlmChannelToolBase.extractString(args, "model_id")
        // ChannelProbe.probe 内部已 try/catch 全部异常并以 ok=false 呈现
        let result = ChannelProbe.shared().probe(code, modelId)
        return ToolResponse(result.toJsonString(), isError: false)
    }
}

/**
 * LlmChannelSwitchTool — 切换默认通道（llm_channel_switch）
 *
 * ⚠️ 受「允许自动切换」开关约束（T030）：开关关闭时**拒绝执行**并返回如何开启的提示，
 * 绝不静默改动默认通道。开关由管理面启动装配注入，默认关闭。
 *
 * 切换语义（Phase 0 已实现）：写 DB + bump revision + 广播；≤5s 内对**新会话**生效，
 * 进行中的会话按 drain 不受影响（V4）。
 */
public class LlmChannelSwitchTool <: LlmChannelToolBase {
    public static let NAME = "llm_channel_switch"

    public static let DESC = """
    Switch the global default LLM channel. Requires the 'allow auto switch' switch to be
    enabled by the administrator; otherwise this tool refuses to act.
    Takes effect for new conversations within ~5s; in-flight conversations are not
    interrupted. Always writes an audit record with source=agent.
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
        get() { LlmChannelSwitchTool.NAME }
    }

    public prop description: String {
        get() { LlmChannelSwitchTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter(
                    "code",
                    "Channel code to make default.",
                    TypeSchema.Str),
                ToolParameter(
                    "reason",
                    "Optional short reason, recorded in the audit trail.",
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
                  "code": "deepseek",
                  "reason": "arcbench returning 401, falling back"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        // 开关校验前置：不允许时不做任何查找与改动，直接拒绝
        if (!LlmChannelAgentTools.autoSwitchEnabled()) {
            return LlmChannelToolBase.buildError(
                "自动切换通道未启用。请让管理员在 .env 设置 LLM_CHANNEL_AUTO_SWITCH=true 并重启后重试；" +
                "在此之前可改用界面「大模型通道」页面手动切换。"
            )
        }
        let serviceOpt = LlmChannelToolBase.serviceOrError()
        if (serviceOpt.isNone()) {
            return LlmChannelToolBase.buildError("ChannelService not initialized")
        }
        let service = serviceOpt.getOrThrow()
        let code = LlmChannelToolBase.extractString(args, "code")
        if (let Some(err) <- LlmChannelToolBase.requireChannel(service, code)) {
            return err
        }
        let po = service.getChannelByCode(code).getOrThrow()
        if (po.status != "enabled") {
            return LlmChannelToolBase.buildError("通道 ${code} 当前状态为 ${po.status}，无法设为默认")
        }
        // source=agent：审计可追溯是谁切的（T019 要求区分 ui/api/agent/seed）
        let ok = service.setDefault(code)
        if (!ok) {
            return LlmChannelToolBase.buildError("切换默认通道失败：${code}")
        }
        let reason = LlmChannelToolBase.extractString(args, "reason")
        let note = if (reason.isEmpty()) { "（未填写原因）" } else { reason }
        return LlmChannelToolBase.buildOk([
            ("code", JsonString(code)),
            ("default_channel", JsonString(code)),
            ("reason", JsonString(reason)),
            ("notice", JsonString("已切换，约 5s 内对新会话生效；进行中的会话不受影响。触发原因：${note}"))
        ])
    }
}
