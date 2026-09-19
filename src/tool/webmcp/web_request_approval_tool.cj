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

    // ── v15 修复问题 C 的请求路径闭环 ──
    // 宿主 SkillManagementService 在初始化时注入一个「决策点有效性查询」回调（函数类型，
    // 工具侧不直接引用 DecisionPointRegistry，避免 tool.webmcp → skill.application 的循环依赖）。
    // 回调签名：(skillName: String, decisionPointId: String) -> Bool
    //   true  = 该决策点有效，可正常推送选项卡片；
    //   false = 失效或未知（spec 5.15.3 异常场景 3：校验失败未登记的决策点不生效），
    //           工具应剥离 options 降级为普通 yes/no 审批，不让非法/失效选项卡片推到前端。
    // 未注入时（decisionPointChecker == None）行为完全不变：仍按调用方显式传入的 options 推送。
    public static var decisionPointChecker: ?((String, String) -> Bool) = None

    public static func setDecisionPointChecker(checker: (String, String) -> Bool): Unit {
        decisionPointChecker = checker
    }

    // ── Ch13.4：审批结果落库回调 ──────────────────────────────────────
    // spec 5.15 业务规则 5 要求「人类选择后，选项 id 必须写入 agent_approvals.selected_option」，
    // 但本工具不能自己 import DAO（会造成 tool → app 的反向依赖）。故沿用上决策点校验的同一套路：
    // 工具产出 `ApprovalDecisionRecord` 快照，由宿主在组合根注入落库实现。
    // 返回值定为 Bool（`-> Unit` 会让宿主 lambda 产生 Bool→Unit 的返回值适配问题，
    // 且会让「落库是否成功」这一信息在工具侧丢失）；工具侧据此决定是否告警。
    // 未注入（approvalRecorder == None）时行为完全不变：只发不问，不产生任何副作用。
    public static var approvalRecorder: ?((ApprovalDecisionRecord) -> Bool) = None

    public static func setApprovalRecorder(recorder: (ApprovalDecisionRecord) -> Bool): Unit {
        approvalRecorder = recorder
    }

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
                ToolParameter("timeout", "Timeout in seconds to wait for approval (default: 60)", TypeSchema.Int),
                // ── Ch13.2（design 2.6.3）：人在回路「AI 提供可选方案」──
                // 三个参数**全部可选**：不传时行为与改造前完全一致（纯 yes/no 审批），
                // 保证既有技能零改动、向后兼容。
                ToolParameter("options", "Optional JSON array of choices, each {id,label,description,tradeoff}. When provided the frontend renders a choice card instead of a yes/no dialog", TypeSchema.Str),
                ToolParameter("default", "Option id to adopt automatically when the user does not respond in time (requires options)", TypeSchema.Str),
                ToolParameter("recommended", "Option id to highlight as the recommended choice (requires options)", TypeSchema.Str),
                // ── v15 修复问题 C：决策点失效闭环（请求路径）──
                // 调用方可声明它正在服务的决策点（skillName + decisionPointId）。工具据此查询
                // 决策点注册表：若已失效（spec 5.15.3 异常场景 3），自动剥离 options 降级为普通审批。
                ToolParameter("skillName", "Name of the skill that owns this decision point (used to verify the decision point is still valid)", TypeSchema.Str),
                ToolParameter("decisionPointId", "Id of the decision point being surfaced (must match a validated decision point in the skill's frontmatter). When invalid/disabled, options are dropped and a plain approval is shown", TypeSchema.Str)
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
                "{\"action\": \"Execute command\", \"details\": \"npm run build\", \"timeout\": 120}",
                // Ch13.2：带可选方案的决策点（前端渲染选项卡片，推荐项高亮；超时自动采用 default）
                "{\"action\": \"选择数据源\", \"details\": \"投研报告需要确定行情数据来源\", \"options\": \"[{\\\"id\\\":\\\"tushare\\\",\\\"label\\\":\\\"Tushare\\\",\\\"description\\\":\\\"免费额度充足，日线完整\\\",\\\"tradeoff\\\":\\\"分钟级数据缺失\\\"},{\\\"id\\\":\\\"wind\\\",\\\"label\\\":\\\"Wind\\\",\\\"description\\\":\\\"全量数据，质量高\\\",\\\"tradeoff\\\":\\\"需付费授权\\\"}]\", \"default\": \"tushare\", \"recommended\": \"tushare\"}"
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

        // ── Ch13.2：可选方案（options）。不传则完全走原路径，行为与改造前一致 ──
        let options = WebRequestApprovalTool.extractString(args, "options")
        let defaultOption = WebRequestApprovalTool.extractString(args, "default")
        let recommended = WebRequestApprovalTool.extractString(args, "recommended")

        // ── v15 修复问题 C：决策点有效性闭环（请求路径）──
        // 若调用方声明了 decisionPointId，且宿主注入了有效性查询回调，则校验该决策点是否仍有效。
        // 失效（spec 5.15.3 异常场景 3：选项 id 非法等导致校验失败、未登记）⇒ 剥离 options，
        // 降级为普通 yes/no 审批，不让非法/失效选项卡片推到前端。
        let skillName = WebRequestApprovalTool.extractString(args, "skillName")
        let decisionPointId = WebRequestApprovalTool.extractString(args, "decisionPointId")
        var effectiveOptions = options
        if (!decisionPointId.isEmpty() && WebRequestApprovalTool.decisionPointChecker.isSome()) {
            let valid = WebRequestApprovalTool.decisionPointChecker.getOrThrow()(skillName, decisionPointId)
            if (!valid) {
                LogUtils.warn("[WebRequestApprovalTool] 决策点 '${decisionPointId}' 失效/已禁用（skill='${skillName}'），降级为普通审批，不推送选项卡片")
                effectiveOptions = ""
            }
        }

        LogUtils.info("[WebRequestApprovalTool] Requesting approval for: ${action}")

        // 构建参数
        let argsMap = HashMap<String, JsonValue>()
        argsMap.add("action", JsonString(action))
        argsMap.add("details", JsonString(details))
        argsMap.add("timeout", JsonString(timeout.toString()))

        // 仅当显式提供 options 时才下发选项字段，避免给老前端塞无意义的空数组/空串
        if (!effectiveOptions.isEmpty()) {
            argsMap.add("options", JsonString(effectiveOptions))
            if (!defaultOption.isEmpty()) {
                argsMap.add("default", JsonString(defaultOption))
            }
            if (!recommended.isEmpty()) {
                argsMap.add("recommended", JsonString(recommended))
            }
        }

        // 通过 WebMCPToolHelper 统一执行 SSE 推送 + 阻塞等待（审批超时 120 秒）
        let waitMs: Int64 = 120000
        let resp = WebMCPToolHelper.executeToolCall("web_request_approval", argsMap, waitMs, "")

        // ── Ch13.4：把「人在回路」的结果落成可追溯的记录 ────────────────
        // 前端 ApprovalOptionsCard.vue 回传形如
        //   {"selected_option":"tushare","action":"<动作标题>","timed_out":false}
        // 无 options 的普通审批路径回传 selected_option = "yes" / "no"。
        // 声明为 var：未收到选择且决策点带 default 时，下面会用 default 顶替（见 !hasSelection 分支）
        var selected = WebRequestApprovalTool.readJsonString(resp.content, "selected_option")
        let frontendTimedOut = WebRequestApprovalTool.readJsonBool(resp.content, "timed_out", false)

        let hasSelection = !selected.isEmpty()
        var status = ""
        var timedOut = false
        var autoDefaulted = false
        var substitutedDefault = false
        var effectiveContent = resp.content

        if (!hasSelection) {
            // 未收到有效选择：前端断开 / 120s 超时 / 被判忙（另有审批在等待）/ 回传非 JSON。
            // spec 5.15.3 异常场景 2 + Ch13.4 异常项：决策点声明了 default 时**自动采用 default 继续**，
            // 不让长程任务因为「没人点按钮」而挂死或整轮失败。
            if (!effectiveOptions.isEmpty() && !defaultOption.isEmpty()) {
                selected = defaultOption
                status = "timeout"
                timedOut = true
                autoDefaulted = true
                substitutedDefault = true
                effectiveContent = "{\"selected_option\":\"${defaultOption}\",\"action\":\"auto_default\",\"timed_out\":true}"
                // 具名事件不在此处打点：autoDefaulted 的**所有**分支（含前端代兜底）统一在链尾 emit 一次，
                // 避免同一事件在两条路径上打出两遍、统计翻倍。
            } else {
                // 无兜底方案：保持原有「未获得批准」语义（普通审批谈不上 default）
                status = "timeout"
                timedOut = true
            }
        } else if (frontendTimedOut) {
            // 前端已按 default 兜底回传（用户在时限内未操作）
            status = "timeout"
            timedOut = true
            autoDefaulted = true
        } else if (selected == "no" || selected == "deny" || selected == "reject" || selected == "rejected") {
            status = "rejected"
        } else {
            status = "approved"
        }

        // 具名事件（spec 5.15.1 规则 3 / design.md:1658）：「决策点超时或通道不可用 → 自动采用 default」
        // 的唯一落点，覆盖后端兜底与前端代兜底两条路径。
        // 形态取「组件名: 事件名 k=v …」，与 `web_human_agent.cj:132` 的同名事件保持一致——
        // 只写自由文本 warn 时 grep 不到稳定 token，超时兜底次数无从统计（review 偏差 #12）。
        // 日志级别用 warn：兜底让任务继续，但确实发生了"没人做选择"，属于需要关注的事件。
        if (autoDefaulted) {
            LogUtils.warn("WebRequestApprovalTool: decision_timeout_default_applied decision_point=${decisionPointId} default=${defaultOption} selected=${selected} timeout_ms=${waitMs.toString()}")
        }

        // 产出快照交给宿主落库；未注入回调时完全无副作用 —— 保持向后兼容。
        try {
            if (WebRequestApprovalTool.approvalRecorder.isSome()) {
                let record = ApprovalDecisionRecord()
                record.action = action
                record.details = details
                record.skillName = skillName
                record.decisionPointId = decisionPointId
                record.options = effectiveOptions
                record.defaultOption = defaultOption
                record.recommended = recommended
                record.selectedOption = selected
                record.userResponse = effectiveContent
                record.status = status
                record.timedOut = timedOut
                record.autoDefaulted = autoDefaulted
                record.timeoutMs = waitMs
                let recorded = WebRequestApprovalTool.approvalRecorder.getOrThrow()(record)
                if (!recorded) {
                    // 不抛异常、不改写返回值：用户的**选择本身**才是最重要的，落库失败只告警。
                    LogUtils.warn("[WebRequestApprovalTool] 审批决策未写入 agent_approvals（decision_point='${decisionPointId}' selected='${selected}'），已忽略")
                }
            }
        } catch (recordErr: Exception) {
            // 落库失败绝不能吞掉用户的选择结果：只记日志，主流程照常返回
            LogUtils.error("[WebRequestApprovalTool] 审批结果落库失败（已忽略，不影响主流程）: ${recordErr.message}")
        }

        // 自动采用了 default 时，把「错误 / 空响应」改写为成功，任务才能继续往下走
        if (substitutedDefault) {
            return ToolResponse(effectiveContent, isError: false)
        }
        return resp
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

    /**
     * 从一段文本中按 JSON 对象读取字符串字段。
     * 缺失 / 类型不符 / 文本不是合法 JSON 一律返回空串（由调用方按「未选中」处理）。
     *
     * 依据：`stdx.encoding.json.class.jsonvalue.fromstr`（`JsonValue.fromStr` 语法错误抛 JsonException），
     * 字段读取沿用工程既有写法 `app/controllers/aip/AipDescriptionController.cj:99` 的 `as String` + Option 解构。
     */
    private static func readJsonString(text: String, key: String): String {
        if (text.isEmpty()) {
            return ""
        }
        try {
            let jsonValue = JsonValue.fromStr(text)
            if (jsonValue is JsonObject) {
                let obj = jsonValue.asObject()
                let val = obj.get(key)
                if (val.isSome()) {
                    let v = val.getOrThrow()
                    let s = v as String
                    if (let Some(str) <- s) {
                        return str
                    }
                }
            }
        } catch (e: Exception) {
            // 老前端可能回传纯文本而非 JSON —— 不是错误，按未选中处理
            LogUtils.debug("[WebRequestApprovalTool] 回传内容非 JSON 对象，按未选中处理: ${e.message}")
        }
        return ""
    }

    /** 同 readJsonString，读取布尔字段；缺失或类型不符返回缺省值 */
    private static func readJsonBool(text: String, key: String, defaultValue: Bool): Bool {
        if (text.isEmpty()) {
            return defaultValue
        }
        try {
            let jsonValue = JsonValue.fromStr(text)
            if (jsonValue is JsonObject) {
                let obj = jsonValue.asObject()
                let val = obj.get(key)
                if (val.isSome()) {
                    let v = val.getOrThrow()
                    let b = v as Bool
                    if (let Some(bv) <- b) {
                        return bv
                    }
                }
            }
        } catch (e: Exception) {
            LogUtils.debug("[WebRequestApprovalTool] 回传内容非 JSON 对象，布尔字段取缺省值: ${e.message}")
        }
        return defaultValue
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
