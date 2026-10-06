/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import magic.core.message.*
import magic.core.model.*
import std.collection.{ArrayList, HashMap}
import ystyle::cordis_host.PluginInstance
import ystyle::jsonrpc.Result
import jsonvalue.JsonValue

/**
 * PluginAdapterContract — L3 插件适配器契约的宿主侧实现（T022 / T023）。
 *
 * 契约文档：docs/ref/llm-adapter-contract.md（四个方法 describe/chat/chatStream/probe
 * + 分帧流式协议 + 密钥获取边界）。本文件是**宿主侧**的调用方实现。
 *
 * 与模式 A 的分工：
 * - 模式 A（AdapterFactory 直通）：协议现成，宿主直接复用 OpenAIChatModel 等；
 * - 模式 B（本文件）：协议私有，宿主只做「跨进程调用 + 熔断 + 回退」，
 *   协议实现与密钥使用都在插件侧（插件经 host.secret 按引用名代取，进程内无明文）。
 *
 * 关键设计：
 * - 插件实例通过**函数槽 + 组合根注入**获得（setInstanceResolver），不反向 import
 *   magic.plugin —— 否则会形成 plugin → channel → plugin 的包循环。
 * - 所有 RPC 失败都**上抛原始错误原文**（T017/T023 要求），不做二次包装；
 * - 熔断语义在宿主侧：连续失败计数由 ChannelProbe 统一管，本类只负责单次调用成败上报。
 */
public class PluginAdapterBridge {
    private static let INSTANCE = PluginAdapterBridge()

    /**
     * 插件名 → 实例解析函数槽。
     * 由组合根（main.cj 插件系统启动段）注入：{ name => CordisHostManager.getInstance(name) }。
     * 未注入时所有模式 B 通道不可用（选路时跳过），不影响模式 A。
     */
    private var instanceResolver: Option<(String) -> Option<PluginInstance>> = None<(String) -> Option<PluginInstance>>

    /** 单次调用超时（T023：超时熔断，防止插件卡死拖垮宿主） */
    private var callTimeout: Duration = Duration.second * 60

    public static func shared(): PluginAdapterBridge {
        INSTANCE
    }

    /**
     * 注入实例解析器（组合根在插件系统启动后调用）。
     */
    public func setInstanceResolver(resolver: (String) -> Option<PluginInstance>): Unit {
        this.instanceResolver = Some(resolver)
    }

    public func setCallTimeout(d: Duration): Unit {
        this.callTimeout = d
    }

    /**
     * 从 protocol 解析插件名：`plugin:<name>` → `<name>`。
     * 非模式 B 返回空串。
     */
    public static func pluginNameOf(protocol: String): String {
        if (protocol.startsWith("plugin:")) {
            return protocol[7..protocol.size]
        }
        return ""
    }

    public static func isPluginProtocol(protocol: String): Bool {
        protocol.startsWith("plugin:")
    }

    /**
     * 取插件实例；不可用时返回 None（调用方应把该通道视为不可用并走回退链）。
     */
    public func instance(pluginName: String): Option<PluginInstance> {
        match (this.instanceResolver) {
            case Some(resolver) => resolver(pluginName)
            case None => None<PluginInstance>
        }
    }

    /**
     * 模式 B 是否可用：实例存在且未 closed。
     */
    public func isAvailable(pluginName: String): Bool {
        match (this.instance(pluginName)) {
            case Some(inst) => !inst.client.isClosed()
            case None => false
        }
    }

    /**
     * 调 adapter.<method>（统一入口）。
     *
     * @param pluginName 插件名（llm_channel.protocol 的 plugin: 之后部分）
     * @param method    describe / chat / chatStream / probe
     * @param params    JsonValue.Map 形态的参数
     * @return 成功返回 result 字段；失败抛异常并带**原始错误原文**
     */
    public func invoke(pluginName: String, method: String, params: JsonValue): JsonValue {
        let instOpt = this.instance(pluginName)
        if (instOpt.isNone()) {
            throw Exception("插件 ${pluginName} 未就绪（不可用），该通道应走回退链")
        }
        let inst = instOpt.getOrThrow()
        let client = inst.client
        if (client.isClosed()) {
            throw Exception("插件 ${pluginName} 连接已关闭，该通道应走回退链")
        }
        let invokeParams = HashMap<String, JsonValue>()
        invokeParams["service"] = JsonValue.String(pluginName)
        invokeParams["method"] = JsonValue.String(method)
        let args = ArrayList<JsonValue>(1, { _ => params })
        invokeParams["args"] = JsonValue.Array(args)

        let r = client.call<JsonValue, JsonValue>(
            "invoke",
            params: Some(JsonValue.from(invokeParams)),
            timeout: this.callTimeout
        )
        match (r) {
            case Ok(result) => result
            case Err(error) =>
                // 保留原文：timeout / unreachable / 插件自定义错误都直接上抛
                throw Exception("adapter.${method} 调用失败：${error}")
        }
    }

    /**
     * adapter.describe —— 拉取插件声明的能力位与模型清单。
     */
    public func describe(pluginName: String, channel: String): JsonValue {
        let p = HashMap<String, JsonValue>()
        p["channel"] = JsonValue.String(channel)
        this.invoke(pluginName, "adapter.describe", JsonValue.Map(p))
    }

    /**
     * adapter.chat —— 非流式对话。成功返回 result；业务失败（ok=false）也原样返回，
     * 由上层解析 error 字段（T017：原始错误原文必须透传）。
     */
    public func chat(pluginName: String, params: JsonValue): JsonValue {
        this.invoke(pluginName, "adapter.chat", params)
    }

    /**
     * adapter.probe —— 三枪探测（插件侧实现，宿主只收事实）。
     */
    public func probe(pluginName: String, params: JsonValue): JsonValue {
        this.invoke(pluginName, "adapter.probe", params)
    }

    /**
     * adapter.probe 的文本变体：直接返回插件 result 的 JSON 文本。
     *
     * 为什么不返回 jsonvalue.JsonValue 让调用方转：cordis 的 JsonValue 与宿主的
     * stdx JsonValue 是**两个不同包的不同类型**，跨包转换要么手写转换器
     * （必漏字段、难维护），要么绕 stringify 文本。统一在这里 stringify，
     * 调用方用宿主自己的 JsonValue.fromStr 解析，职责边界清晰。
     *
     * @param paramsJson 已序列化好的参数 JSON 文本（调用方用宿主 JsonValue 拼好再 stringify）
     */
    public func probeText(pluginName: String, paramsJson: String): String {
        let parsed = JsonValue.parse(paramsJson)
        let result = this.invoke(pluginName, "adapter.probe", parsed)
        result.stringify()
    }

    /**
     * adapter.describe 的文本变体（同 probeText 的理由）。
     */
    public func describeText(pluginName: String, paramsJson: String): String {
        let parsed = JsonValue.parse(paramsJson)
        let result = this.invoke(pluginName, "adapter.describe", parsed)
        result.stringify()
    }
}

/**
 * PluginChatModel —— 把插件适配器包装成宿主 ChatModel，让上层执行器零感知（T023）。
 *
 * 走模式 B 的通道由本类承接；create/asyncCreate 委托给插件进程。
 * 插件不可用 / 调用失败 → 抛异常，由上层（Agent 执行器 / 回退链）处理，宿主不崩（T023 验收）。
 */
public class PluginChatModel <: ChatModel {
    private let channel: ChannelSnapshot
    private let modelId: String
    private let pluginName: String
    private var _maxTokens: Option<Int64> = None<Int64>
    private var _contextLength: Int64 = 32768

    public init(channel: ChannelSnapshot, modelId: String) {
        this.channel = channel
        this.modelId = modelId
        this.pluginName = PluginAdapterBridge.pluginNameOf(channel.protocol)
    }

    override public prop provider: String {
        get() { this.channel.code }
    }

    override public prop name: String {
        get() { this.modelId }
    }

    override public prop contextLength: Int64 {
        get() { this._contextLength }
    }

    override public mut prop maxTokens: Option<Int64> {
        get() { this._maxTokens }
        set(v) { this._maxTokens = v }
    }

    /**
     * 非流式对话：序列化 ChatRequest → adapter.chat → 解析 ChatResponse。
     */
    override public func create(chatReq: ChatRequest): ChatResponse {
        let bridge = PluginAdapterBridge.shared()
        if (!bridge.isAvailable(this.pluginName)) {
            throw Exception("插件 ${this.pluginName} 不可用，通道 ${this.channel.code} 应走回退链")
        }
        let params = PluginChatCodec.encodeParams(this.channel.code, this.modelId, chatReq, this._maxTokens)
        let result = bridge.chat(this.pluginName, params)
        PluginChatCodec.decodeResponse(result, this.modelId)
    }

    /**
     * 流式对话（T023）：**本期不支持，抛异常由上层降级到同步 create**。
     *
     * 为什么不实现（避免留半成品）：
     * 1. 契约（帧格式 / meta-first / done-last / 单行 / 未知帧忽略 / stderr 不参与协议）
     *    已在 docs/ref/llm-adapter-contract.md §3.3 完整定义，不返工；
     * 2. cordis stdio JSON-RPC 是请求-响应模型，多帧流必须靠 notification 推送，
     *    而 AsyncChatChunk 的构造函数是 **protected（包级可见）**——
     *    magic.model.ollama / magic.model.openai 能各自在包内造帧，
     *    但 magic.model.channel 跨包造不出来；
     * 3. 要打通需要改 magic.core.model 公共基础设施（加 public 帧工厂或
     *    open 的流构造入口），按项目红线「公共基础设施只减不增」不在本任务范围。
     *
     * 降级路径：上层捕获本异常 → 改调 create() → 用户仍能拿到完整回复，
     * 只是没有逐字增量。功能正确，体验降级，行为可预期。
     *
     * 解除条件：T024 插件侧落地 + core 侧开放帧工厂后，仅替换本方法体即可。
     */
    override public func asyncCreate(chatReq: ChatRequest): AsyncChatResponse {
        throw ModelException(
            "plugin_stream_unsupported: L3 插件通道 ${this.channel.code} 暂不支持流式" +
            "（宿主 core 侧未开放流帧工厂），调用方应降级到 create()"
        )
    }
}

/**
 * PluginChatCodec —— 插件契约的请求/响应编解码（T022/T023）。
 *
 * 请求：ChatRequest → { channel, model, messages[], temperature, max_tokens, tools }
 * 响应：result{ ok, content, tool_calls[], usage, model } → ChatResponse
 */
public class PluginChatCodec {
    /**
     * ChatRequest → adapter.chat 参数。
     *
     * @param maxTokens 由 ChatModel.maxTokens 控制（ChatRequest 自身不携带），
     *                  所以显式从模型层传入，避免插件侧自己决定上限。
     */
    public static func encodeParams(
        channelCode: String,
        modelId: String,
        request: ChatRequest,
        maxTokens: Option<Int64>
    ): JsonValue {
        let p = HashMap<String, JsonValue>()
        p["channel"] = JsonValue.String(channelCode)
        p["model"] = JsonValue.String(modelId)

        // messageList → [{role, content}]
        let msgs = ArrayList<JsonValue>()
        for (m in request.messageList) {
            let item = HashMap<String, JsonValue>()
            item["role"] = JsonValue.String(m.role.toString())
            item["content"] = JsonValue.String(m.content)
            msgs.add(JsonValue.Map(item))
        }
        p["messages"] = JsonValue.Array(msgs)

        match (request.temperature) {
            case Some(t) => p["temperature"] = JsonValue.Number(t)
            case None => ()
        }
        match (maxTokens) {
            case Some(mt) => p["max_tokens"] = JsonValue.Number(Float64(mt))
            case None => ()
        }
        JsonValue.Map(p)
    }

    /**
     * adapter.chat 的 result → ChatResponse。
     *
     * 失败（ok=false）时抛异常并带上原始 error 文本——T017 要求错误可辨，
     * 不能统一成"调用失败"。
     */
    public static func decodeResponse(result: JsonValue, fallbackModel: String): ChatResponse {
        match (result) {
            case JsonValue.Map(m) =>
                let ok = match (m.get("ok")) {
                    case Some(JsonValue.Boolean(b)) => b
                    case _ => true
                }
                if (!ok) {
                    let err = match (m.get("error")) {
                        case Some(JsonValue.String(s)) => s
                        case _ => "插件返回 ok=false 但未带 error 字段"
                    }
                    throw Exception("adapter.chat 业务失败：${err}")
                }
                let content = match (m.get("content")) {
                    case Some(JsonValue.String(s)) => s
                    case _ => ""
                }
                let model = match (m.get("model")) {
                    case Some(JsonValue.String(s)) => s
                    case _ => fallbackModel
                }
                ChatResponse(model, Message.assistant(content))
            case _ =>
                throw Exception("adapter.chat 返回格式非法（期望 JSON 对象）")
        }
    }
}
