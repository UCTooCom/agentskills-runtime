/*
 * adapter.* 四个契约方法的实现（Tokendance 专用网关）
 *
 * 契约：docs/ref/llm-adapter-contract.md
 *   adapter.describe —— 能力位 + 模型清单
 *   adapter.chat     —— 非流式对话
 *   adapter.probe    —— 三枪探测（chat / stream / tools），只报事实不做熔断判断
 *   adapter.chatStream —— 分帧流式（本期宿主侧未开放流帧工厂，插件侧实现齐备待接通）
 *
 * ── 三条不可违反的约定 ────────────────────────────────────────────
 * 1. **失败不抛 JSON-RPC error**，返回 result.ok=false + error 字段。
 *    契约 §3.2 明确要求：这样宿主才能把原始错误原文透传给用户/Agent（T017）。
 *    抛异常会被 cordis 包成 "INVOKE-ERROR: ..." 字符串，丢失结构与原文。
 * 2. **日志只走 stderr**。stdout 是 JSON-RPC 协议通道（NewlineFraming 逐行解析），
 *    写任何非协议内容都会让宿主侧解析错位。
 * 3. **密钥不落盘不打日志**。经 ctx.invoke("host.secret","get",{ref}) 按引用名代取，
 *    用完即弃；本进程的环境变量里本来就没有明文（插件不继承宿主环境）。
 */
package skill_llm_channel_tokendance

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*
import std.collection.{ArrayList, HashMap}

/**
 * TokendanceAdapter —— adapter.* 契约实现。
 */
public class TokendanceAdapter {
    /// 协议版本（宿主见到不认识的版本应拒绝启用，契约 §3.1）
    public static let PROTOCOL_VERSION = "1"

    /// 通道 code（llm_channel.code = "tokendance"），secret_ref 解析时也用它
    public static let CHANNEL_CODE = "tokendance"

    /// 密钥引用名：宿主从 .env 的这个键取值后交给本进程
    public static let SECRET_REF = "env:TOKENDANCE_API_KEY"

    /// 默认网关地址（adapter.chat 参数里没给 base_url 时用这个）
    public static let DEFAULT_BASE_URL = "https://tokendance.space/gateway/v1"

    /// 声明的模型清单（describe 返回；探测与 chat 的默认 model）
    public static let MODELS: Array<String> = [
        "tokendance-chat", "tokendance-embedding"
    ]

    /// 可用能力位（与 llm_channel.capabilities 列取值一致）
    public static let CAPABILITIES: Array<String> = [
        "chat", "stream", "tools", "embedding"
    ]

    /// 探测用的固定短 prompt——要短且确定，避免探测本身消耗大
    private static let PROBE_PROMPT = "ping"

    /// 插件上下文（register 时注入），用于 host.secret 代取
    private static var ctx: Option<PluginContext> = None<PluginContext>

    public static func register(ctx: PluginContext): Unit {
        TokendanceAdapter.ctx = Some(ctx)
        // 注册 API 见 plugin_runtime.cj:52
        // registerHandler(key, (String, Array<JsonValue>) -> JsonValue)
        // key 即宿主 invoke 时传的 service 名 —— PluginAdapterBridge 用插件名当 service，
        // 所以 key 必须等于插件名 llm_channel_tokendance。
        ctx.registerHandler(
            "llm_channel_tokendance",
            { method, args => TokendanceAdapter.dispatch(method, args) }
        )
    }

    // ── 分发 ─────────────────────────────────────────────────────────

    private static func dispatch(method: String, args: Array<JsonValue>): JsonValue {
        let params: JsonValue = if (args.isEmpty()) { JsonValue.Null } else { args[0] }
        match (method) {
            case "adapter.describe" => TokendanceAdapter.describe(params)
            case "adapter.chat" => TokendanceAdapter.chat(params)
            case "adapter.chatStream" => TokendanceAdapter.chatStream(params)
            case "adapter.probe" => TokendanceAdapter.probe(params)
            case _ => TokendanceAdapter.fail("unknown_method", "未知方法 ${method}；本适配器支持 adapter.describe/chat/chatStream/probe")
        }
    }

    // ── adapter.describe ─────────────────────────────────────────────

    /**
     * 拉取能力位与模型清单。
     *
     * 纯静态声明——不依赖密钥也不出网，所以永远成功。
     * 真能不能用由 probe 三枪说话，describe 只回答"我声明支持什么"。
     */
    public static func describe(params: JsonValue): JsonValue {
        let caps = ArrayList<JsonValue>()
        for (c in TokendanceAdapter.CAPABILITIES) {
            caps.add(JsonValue.String(c))
        }
        let models = ArrayList<JsonValue>()
        for (m in TokendanceAdapter.MODELS) {
            let mi = HashMap<String, JsonValue>()
            mi["model_id"] = JsonValue.String(m)
            mi["display_name"] = JsonValue.String(m)
            models.add(JsonValue.Map(mi))
        }
        let m = HashMap<String, JsonValue>()
        m["ok"] = JsonValue.Boolean(true)
        m["protocol_version"] = JsonValue.String(TokendanceAdapter.PROTOCOL_VERSION)
        m["capabilities"] = JsonValue.Array(caps)
        m["default_model"] = JsonValue.String(TokendanceAdapter.MODELS[0])
        m["models"] = JsonValue.Array(models)
        m["context_length"] = JsonValue.Number(32768.0)
        m["channel"] = JsonValue.String(TokendanceAdapter.CHANNEL_CODE)
        JsonValue.Map(m)
    }

    // ── adapter.chat ─────────────────────────────────────────────────

    /**
     * 非流式对话。
     *
     * 出网前先取密钥；取不到直接 fail（原文带上宿主给的错误），
     * 不要发一个注定 401 的请求——浪费一次往返还污染健康统计。
     */
    public static func chat(params: JsonValue): JsonValue {
        let (hasKey, keyOrErr) = TokendanceAdapter.fetchSecret()
        if (!hasKey) {
            return TokendanceAdapter.fail("secret_unavailable", keyOrErr)
        }
        let apiKey = keyOrErr
        let url = "${TokendanceAdapter.baseUrlOf(params)}/chat/completions"
        let headers = TokendanceAdapter.authHeaders(apiKey)
        let body = TokendanceAdapter.buildChatBody(params, false)
        try {
            let (code, resp) = AdapterHttp.postJson(url, headers, body)
            if (code != 200) {
                // 非 200：把响应体片段作为原文带回，宿主前端直接显示
                return TokendanceAdapter.fail(
                    "http_${code}",
                    "gateway 返回 HTTP ${code}：${TokendanceAdapter.snippet(resp)}"
                )
            }
            return TokendanceAdapter.parseChatResponse(resp, params)
        } catch (e: Exception) {
            return TokendanceAdapter.fail("transport_error", e.message)
        }
    }

    // ── adapter.chatStream ───────────────────────────────────────────

    /**
     * 分帧流式（NDJSON）。
     *
     * ⚠️ 当前宿主侧不可达：PluginChatModel.asyncCreate 明确抛
     *    `plugin_stream_unsupported`（core 侧 AsyncChatChunk 构造函数是包级 protected，
     *    magic.model.channel 跨包造不出帧）。
     *    本实现**故意保留**：等 core 开放帧工厂后，宿主只需放开 asyncCreate，
     *    插件侧零改动即可打通。现在调用会返回明确的 ok=false + 原因，
     *    而不是假装成功返回空流。
     */
    public static func chatStream(params: JsonValue): JsonValue {
        TokendanceAdapter.fail(
            "stream_not_enabled",
            "流式通道在宿主侧尚未启用（PluginChatModel.asyncCreate 抛 plugin_stream_unsupported，" +
            "原因：core 侧未开放流帧工厂）。请改用 adapter.chat，或等宿主放开后重试。"
        )
    }

    // ── adapter.probe（三枪）─────────────────────────────────────────

    /**
     * 三枪探测：chat / stream / tools。
     *
     * 职责边界（契约 §3.4）：**只报事实**，不做熔断判断。
     * 连续失败计数、degraded 降级、自动归位都由宿主 ChannelProbe 统一做。
     *
     * 三枪互相独立：一枪失败不影响另两枪（工具调用能力缺失很常见，
     * 不该让 chat 也被判死）。
     */
    public static func probe(params: JsonValue): JsonValue {
        let model = TokendanceAdapter.modelOf(params)
        let (hasKey, keyOrErr) = TokendanceAdapter.fetchSecret()
        var chatOk = false
        var chatDetail = keyOrErr
        var streamOk = false
        var streamDetail = keyOrErr
        var toolsOk = false
        var toolsDetail = keyOrErr
        if (hasKey) {
            let apiKey = keyOrErr
            let (c1, d1) = TokendanceAdapter.probeChat(apiKey, model)
            chatOk = c1
            chatDetail = d1
            let (c2, d2) = TokendanceAdapter.probeStream(apiKey, model)
            streamOk = c2
            streamDetail = d2
            let (c3, d3) = TokendanceAdapter.probeTools(apiKey, model)
            toolsOk = c3
            toolsDetail = d3
        }

        // capabilities 按实测结论收敛：只报真的通过的
        // （describe 声明的是「意图」，这里是「事实」，宿主健康统计用后者）
        var caps = ArrayList<JsonValue>()
        if (chatOk) {
            caps.add(JsonValue.String("chat"))
        }
        if (streamOk) {
            caps.add(JsonValue.String("stream"))
        }
        if (toolsOk) {
            caps.add(JsonValue.String("tools"))
        }
        if (model.contains("embedding")) {
            caps.add(JsonValue.String("embedding"))
        }

        let m = HashMap<String, JsonValue>()
        m["ok"] = JsonValue.Boolean(chatOk)
        m["chat"] = JsonValue.Boolean(chatOk)
        m["chat_detail"] = JsonValue.String(chatDetail)
        m["stream"] = JsonValue.Boolean(streamOk)
        m["stream_detail"] = JsonValue.String(streamDetail)
        m["tools"] = JsonValue.Boolean(toolsOk)
        m["tools_detail"] = JsonValue.String(toolsDetail)
        m["capabilities"] = JsonValue.String(TokendanceAdapter.toJsonArrayText(caps))
        m["model"] = JsonValue.String(model)
        m["protocol_version"] = JsonValue.String(TokendanceAdapter.PROTOCOL_VERSION)
        JsonValue.Map(m)
    }

    /** 第一枪：最小 chat 请求 */
    private static func probeChat(apiKey: String, model: String): (Bool, String) {
        let url = "${TokendanceAdapter.DEFAULT_BASE_URL}/chat/completions"
        let body = TokendanceAdapter.probeBody(model, false, false)
        try {
            let (code, resp) = AdapterHttp.postJson(url, TokendanceAdapter.authHeaders(apiKey), body)
            if (code == 200) {
                // 200 但内容结构不对也算失败——不然会把「能连上但答非所问」判成健康
                match (TokendanceAdapter.readContent(resp)) {
                    case Some(c) => return (true, "200 ok，内容长度 ${c.size}")
                    case None => return (false, "200 但响应缺少 choices[].message.content：${TokendanceAdapter.snippet(resp)}")
                }
            }
            (false, "HTTP ${code}：${TokendanceAdapter.snippet(resp)}")
        } catch (e: Exception) {
            (false, e.message)
        }
    }

    /** 第二枪：流式请求，判断「能否收到 SSE 首帧 + 是否有结束标记」 */
    private static func probeStream(apiKey: String, model: String): (Bool, String) {
        let url = "${TokendanceAdapter.DEFAULT_BASE_URL}/chat/completions"
        let body = TokendanceAdapter.probeBody(model, true, false)
        // 用可变容器而不是裸 var 累加：闭包里改外层 var 的捕获语义在
        // 不同仓颉版本下行为不稳（有的版本按值捕获），装箱最保险。
        let gotFrame = ArrayList<Int64>()
        let gotDone = ArrayList<Int64>()
        try {
            let (code, stderr) = AdapterHttp.postStream(
                url,
                TokendanceAdapter.authHeaders(apiKey),
                body,
                { line =>
                    if (!line.startsWith("data:") && !line.startsWith("data: ")) {
                        // 非 SSE 帧（空行/注释/错误文本）不计入
                    } else if (gotFrame.isEmpty()) {
                        gotFrame.add(1)
                    }
                    if (line.contains("[DONE]")) {
                        if (gotDone.isEmpty()) {
                            gotDone.add(1)
                        }
                    }
                }
            )
            if (code != 200) {
                return (false, "HTTP ${code}：${TokendanceAdapter.snippet(stderr)}")
            }
            if (!gotFrame.isEmpty() && !gotDone.isEmpty()) {
                return (true, "收到 SSE 首帧与 [DONE] 结束标记")
            }
            if (!gotFrame.isEmpty()) {
                // 有首帧无 done：流会被宿主按「不完整」处理，判失败但保留已收内容
                return (false, "收到首帧但缺少 [DONE] 结束标记（流不完整）")
            }
            (false, "未收到任何 SSE 帧（data: 前缀）")
        } catch (e: Exception) {
            (false, e.message)
        }
    }

    /** 第三枪：带 tools 的请求，判断工具调用能力 */
    private static func probeTools(apiKey: String, model: String): (Bool, String) {
        let url = "${TokendanceAdapter.DEFAULT_BASE_URL}/chat/completions"
        let body = TokendanceAdapter.probeBody(model, false, true)
        try {
            let (code, resp) = AdapterHttp.postJson(url, TokendanceAdapter.authHeaders(apiKey), body)
            if (code != 200) {
                return (false, "HTTP ${code}：${TokendanceAdapter.snippet(resp)}")
            }
            match (TokendanceAdapter.readToolCalls(resp)) {
                case Some(n) => (true, "返回 ${n} 个 tool_call")
                case None => (false, "200 但未返回 tool_calls（模型未跟进 tool 声明）：${TokendanceAdapter.snippet(resp)}")
            }
        } catch (e: Exception) {
            (false, e.message)
        }
    }

    // ── 参数解析 ─────────────────────────────────────────────────────

    private static func baseUrlOf(params: JsonValue): String {
        // 用 jsonvalue 的 asString()（返回 Option）而不是 `as` 强转：
        // `as` 是不安全强转，类型不符会抛异常而不是给 None。
        if (let Some(v) <- params["base_url"]) {
            if (let Some(s) <- v.asString()) {
                if (!s.isEmpty()) {
                    return s.removeSuffix("/")
                }
            }
        }
        return TokendanceAdapter.DEFAULT_BASE_URL
    }

    private static func modelOf(params: JsonValue): String {
        if (let Some(v) <- params["model"]) {
            if (let Some(s) <- v.asString()) {
                if (!s.isEmpty()) {
                    return s
                }
            }
        }
        return TokendanceAdapter.MODELS[0]
    }

    private static func authHeaders(apiKey: String): HashMap<String, String> {
        let h = HashMap<String, String>()
        h["Content-Type"] = "application/json"
        h["Authorization"] = "Bearer ${apiKey}"
        h
    }

    // ── 请求体构造 ───────────────────────────────────────────────────

    /** 正式对话请求体：透传宿主传来的 messages / temperature / max_tokens / tools */
    private static func buildChatBody(params: JsonValue, stream: Bool): String {
        let m = HashMap<String, JsonValue>()
        m["model"] = JsonValue.String(TokendanceAdapter.modelOf(params))
        m["messages"] = params.get("messages", JsonValue.Array(ArrayList<JsonValue>()))
        if (let Some(t) <- params["temperature"]) {
            m["temperature"] = t
        }
        if (let Some(mt) <- params["max_tokens"]) {
            m["max_tokens"] = mt
        }
        if (let Some(tools) <- params["tools"]) {
            m["tools"] = tools
        }
        if (let Some(tc) <- params["tool_choice"]) {
            m["tool_choice"] = tc
        }
        m["stream"] = JsonValue.Boolean(stream)
        JsonValue.Map(m).stringify()
    }

    /** 探测请求体：固定短 prompt，结论要可复现 */
    private static func probeBody(model: String, stream: Bool, withTools: Bool): String {
        let msg = HashMap<String, JsonValue>()
        msg["role"] = JsonValue.String("user")
        msg["content"] = JsonValue.String(TokendanceAdapter.PROBE_PROMPT)
        let msgs = ArrayList<JsonValue>()
        msgs.add(JsonValue.Map(msg))

        let m = HashMap<String, JsonValue>()
        m["model"] = JsonValue.String(model)
        m["messages"] = JsonValue.Array(msgs)
        m["max_tokens"] = JsonValue.Number(16.0)
        m["stream"] = JsonValue.Boolean(stream)
        if (withTools) {
            m["tools"] = TokendanceAdapter.probeToolsDecl()
            // 强制走工具，才能确定「模型是否支持 tool_calls」而不是「模型是否想调工具」
            m["tool_choice"] = JsonValue.String("required")
        }
        JsonValue.Map(m).stringify()
    }

    /** 探测用的最小工具声明（形状同 OpenAI） */
    private static func probeToolsDecl(): JsonValue {
        let cityProp = HashMap<String, JsonValue>()
        cityProp["type"] = JsonValue.String("string")
        let props = HashMap<String, JsonValue>()
        props["city"] = JsonValue.Map(cityProp)

        let params = HashMap<String, JsonValue>()
        params["type"] = JsonValue.String("object")
        params["properties"] = JsonValue.Map(props)
        let required = ArrayList<JsonValue>()
        required.add(JsonValue.String("city"))
        params["required"] = JsonValue.Array(required)

        let funcMap = HashMap<String, JsonValue>()
        funcMap["name"] = JsonValue.String("get_weather")
        funcMap["description"] = JsonValue.String("Get weather of a city")
        funcMap["parameters"] = JsonValue.Map(params)

        let tool = HashMap<String, JsonValue>()
        tool["type"] = JsonValue.String("function")
        tool["function"] = JsonValue.Map(funcMap)

        let tools = ArrayList<JsonValue>()
        tools.add(JsonValue.Map(tool))
        JsonValue.Array(tools)
    }

    // ── 响应解析 ─────────────────────────────────────────────────────

    private static func parseChatResponse(resp: String, params: JsonValue): JsonValue {
        let parsedOpt = TokendanceAdapter.tryParse(resp)
        if (parsedOpt.isNone()) {
            return TokendanceAdapter.fail(
                "invalid_json",
                "响应不是合法 JSON；原文片段 ${TokendanceAdapter.snippet(resp)}"
            )
        }
        let parsed = parsedOpt.getOrThrow()
        let content = match (TokendanceAdapter.readContent(resp)) {
            case Some(c) => c
            case None => ""
        }
        // tool_calls 为空时给空数组而不是省略：契约要求调用方无需判空
        let toolCalls = TokendanceAdapter.readToolCallsRaw(parsed)
        let m = HashMap<String, JsonValue>()
        m["ok"] = JsonValue.Boolean(true)
        m["content"] = JsonValue.String(content)
        m["tool_calls"] = toolCalls
        m["model"] = JsonValue.String(TokendanceAdapter.modelOf(params))
        m["usage"] = TokendanceAdapter.readUsage(parsed)
        JsonValue.Map(m)
    }

    /// 安全解析：非法 JSON 返回 None（JsonValue.parse 内部会抛）
    private static func tryParse(text: String): Option<JsonValue> {
        try {
            return Some(JsonValue.parse(text))
        } catch (_: Exception) {
            return None<JsonValue>
        }
    }

    /// 读 choices[0].message.content（入参是响应文本，内部安全解析）
    private static func readContent(resp: String): Option<String> {
        let parsedOpt = TokendanceAdapter.tryParse(resp)
        if (parsedOpt.isNone()) {
            return None<String>
        }
        let parsed = parsedOpt.getOrThrow()
        let choices = match (parsed["choices"]) {
            case Some(JsonValue.Array(a)) => a
            case _ => return None<String>
        }
        if (choices.isEmpty()) {
            return None<String>
        }
        let message = match (choices[0]["message"]) {
            case Some(m) => m
            case None => return None<String>
        }
        match (message["content"]) {
            case Some(JsonValue.String(s)) => Some(s)
            // 部分网关 reasoning 模型首个 chunk 的 content 是 null，
            // 属正常——空串比 None 更符合契约「无内容时给空串」
            case Some(JsonValue.Null) => Some("")
            case _ => None<String>
        }
    }

    /// tool_calls 条数（探测用：只关心有没有）
    private static func readToolCalls(resp: String): Option<Int64> {
        let parsedOpt = TokendanceAdapter.tryParse(resp)
        if (parsedOpt.isNone()) {
            return None<Int64>
        }
        let parsed = parsedOpt.getOrThrow()
        let choices = match (parsed["choices"]) {
            case Some(JsonValue.Array(a)) => a
            case _ => return None<Int64>
        }
        if (choices.isEmpty()) {
            return None<Int64>
        }
        match (choices[0]["message"]) {
            case Some(msg) => match (msg["tool_calls"]) {
                case Some(JsonValue.Array(a)) => Some(a.size)
                case _ => None<Int64>
            }
            case None => None<Int64>
        }
    }

    /// tool_calls 原样透传（arguments 保持字符串化 JSON，符合契约 §3.2）
    private static func readToolCallsRaw(parsed: JsonValue): JsonValue {
        let choices = match (parsed["choices"]) {
            case Some(JsonValue.Array(a)) => a
            case _ => return JsonValue.Array(ArrayList<JsonValue>())
        }
        if (choices.isEmpty()) {
            return JsonValue.Array(ArrayList<JsonValue>())
        }
        match (choices[0]["message"]) {
            case Some(msg) => msg.get("tool_calls", JsonValue.Array(ArrayList<JsonValue>()))
            case None => JsonValue.Array(ArrayList<JsonValue>())
        }
    }

    private static func readUsage(parsed: JsonValue): JsonValue {
        if (let Some(u) <- parsed["usage"]) {
            return u
        }
        // 网关没回 usage 时给全 0 结构而不是省略：
        // 上层做成本统计时不必判空，且"没统计"与"统计为 0"可区分。
        let empty = HashMap<String, JsonValue>()
        empty["prompt_tokens"] = JsonValue.Number(0.0)
        empty["completion_tokens"] = JsonValue.Number(0.0)
        empty["total_tokens"] = JsonValue.Number(0.0)
        JsonValue.Map(empty)
    }

    // ── 密钥（host.secret 代取）──────────────────────────────────────

    /**
     * 经宿主按引用名取密钥。
     *
     * V5 安全边界：插件进程不继承宿主环境变量，命令行也不带密文，
     * 所以只能把引用名交给宿主代取（宿主每次 get 写审计）。
     * 取到的明文只用在这一次的 HTTP header 里，**不写日志、不落盘**。
     *
     * 用 `(Bool, String)` 而不是 Result：Result 在宿主侧是 f_base 包的类型，
     * 插件是独立 cjpm 工程、不在宿主编译图里，引用不了（也不该引用）。
     *
     * @return (true, apiKey) / (false, 原始错误文本)
     */
    private static func fetchSecret(): (Bool, String) {
        let ctxOpt = TokendanceAdapter.ctx
        match (ctxOpt) {
            case None => return (false, "插件上下文未初始化，无法向宿主索取密钥（host.secret）")
            case Some(ctx) =>
                let p = HashMap<String, JsonValue>()
                p["ref"] = JsonValue.String(TokendanceAdapter.SECRET_REF)
                let args = ArrayList<JsonValue>()
                args.add(JsonValue.Map(p))
                try {
                    let r = ctx.invoke("host.secret", "get", args.toArray())
                    let ok = match (r["ok"]) {
                        case Some(JsonValue.Boolean(b)) => b
                        case _ => false
                    }
                    if (!ok) {
                        let err = match (r["error"]) {
                            case Some(JsonValue.String(s)) => s
                            case Some(other) => other.stringify()
                            case None => "宿主未返回错误详情"
                        }
                        return (false, "取密钥失败（${TokendanceAdapter.SECRET_REF}）：${err}")
                    }
                    match (r["value"]) {
                        case Some(JsonValue.String(v)) =>
                            if (!v.isEmpty()) {
                                return (true, v)
                            }
                            return (false, "取密钥失败（${TokendanceAdapter.SECRET_REF}）：宿主返回空值")
                        case _ => return (false, "取密钥失败（${TokendanceAdapter.SECRET_REF}）：宿主返回空值")
                    }
                } catch (e: Exception) {
                    return (false, "调用 host.secret 异常：${e.message}")
                }
        }
    }

    /**
     * 只问「密钥配没配」，**不取明文**。
     *
     * 给自检端点用：V5 安全边界要求插件尽量少接触明文，
     * 「宿主有没有这个引用」用 host.secret 的 has 方法就够。
     *
     * @return (是否已配置, 说明文本)
     */
    public static func probeSecretPresence(): (Bool, String) {
        let ctxOpt = TokendanceAdapter.ctx
        match (ctxOpt) {
            case None => return (false, "插件上下文未初始化")
            case Some(ctx) =>
                let p = HashMap<String, JsonValue>()
                p["ref"] = JsonValue.String(TokendanceAdapter.SECRET_REF)
                let args = ArrayList<JsonValue>()
                args.add(JsonValue.Map(p))
                try {
                    let r = ctx.invoke("host.secret", "has", args.toArray())
                    let ok = match (r["ok"]) {
                        case Some(JsonValue.Boolean(b)) => b
                        case _ => false
                    }
                    if (!ok) {
                        let err = match (r["error"]) {
                            case Some(JsonValue.String(s)) => s
                            case Some(other) => other.stringify()
                            case None => "宿主未返回错误详情"
                        }
                        return (false, err)
                    }
                    let has = match (r["has"]) {
                        case Some(JsonValue.Boolean(b)) => b
                        case _ => false
                    }
                    if (has) {
                        return (true, "宿主已配置 ${TokendanceAdapter.SECRET_REF}")
                    }
                    (false, "宿主未配置 ${TokendanceAdapter.SECRET_REF}（或值为空）")
                } catch (e: Exception) {
                    (false, "调用 host.secret 异常：${e.message}")
                }
        }
    }

    /// 模型清单的 JSON 数组文本（自检端点展示用）
    public static func modelListText(): String {
        let arr = ArrayList<JsonValue>()
        for (m in TokendanceAdapter.MODELS) {
            arr.add(JsonValue.String(m))
        }
        JsonValue.Array(arr).stringify()
    }

    // ── 结果构造 ─────────────────────────────────────────────────────

    /**
     * 统一的失败结果。
     *
     * 刻意**不抛异常**：契约 §3.2 要求失败走 ok=false + error，
     * 这样宿主能把 error 原文透传到界面（探测定时器面板直接显示）。
     */
    private static func fail(code: String, message: String): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["ok"] = JsonValue.Boolean(false)
        m["error"] = JsonValue.String(message)
        m["error_code"] = JsonValue.String(code)
        JsonValue.Map(m)
    }

    /// ArrayList<JsonValue> → JSON 数组文本（llm_channel.capabilities 列存的是字符串）
    private static func toJsonArrayText(items: ArrayList<JsonValue>): String {
        JsonValue.Array(items).stringify()
    }

    /**
     * 响应体截断：探测面板只有一行放得下，长响应要截但要留够识别信息。
     *
     * 按 **Rune** 截而不是字节：仓颉 String 的 `s[0..n]` 是字节切分，
     * 中文响应会被切成半个 UTF-8 序列（乱码），而错误原文恰恰最可能是中文。
     */
    private static func snippet(text: String): String {
        let t = text.trimAscii()
        let runes = t.toRuneArray()
        if (runes.size <= 500) {
            return t
        }
        "${String(runes[0..500])}…(共 ${runes.size} 字符)"
    }
}
