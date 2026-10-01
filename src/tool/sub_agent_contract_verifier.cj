/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt}
import std.collection.ArrayList
import std.core.StringBuilder
import std.unicode.UnicodeStringExtension

/**
 * 派单结果契约校验器（REQ-SDD-012-A，design §2.10.2 / tasks.md T-21）。
 *
 * ## 为什么要有它
 * 此前是"子 agent 交回什么就信什么"——一篇缺章节、满是 TODO 占位符的文档
 * 也会被视为本阶段产物往下传。校验器把这一步变成**按契约自动拦截**：
 * 残次品在自动层被拦下并携结构化错误重派，两次不过才转人工闸口。
 *
 * ## 硬性约束（spec §4.1-3）
 * - **纯字符串 / JSON 处理**，不得发起网络或模型调用，单次校验 ≤1s；
 * - 规则来源是数据（`agents.capabilities` 里的 `output_contract`），
 *   改规则即时生效，**不需要改代码**；
 * - 拿不到规则时降级为「仅非空 + 最小长度」并标 `contract_absent`，
 *   **不静默判定通过**——降级本身要可观测。
 *
 * ## 为什么落在 magic.tool
 * 校验器只依赖 std 与 stdx，不依赖任何宿主服务；宿主侧派发实现单向 import 本包。
 * 与 T-15 的「真派生不落 magic.tool」是同一条铁律的两面：
 * 有宿主依赖的东西不进 magic.tool，没宿主依赖的纯逻辑就放这里。
 */
public struct ContractVerdict {
    /// 是否通过
    public let passed: Bool
    /**
     * 契约类型：json / markdown / text / contract_absent（无规则时的降级标记）。
     * 落 `sub_agent_invocations.contract_type`，用于事后统计"哪类契约最容易挂"。
     */
    public let contractType: String
    /// 结构化错误（JSON 数组文本），如 ["missing section: xxx"]；通过时为空串
    public let errors: String

    public init(passed: Bool, contractType: String, errors: String) {
        this.passed = passed
        this.contractType = contractType
        this.errors = errors
    }
}

public class SubAgentContractVerifier {
    /// 降级路径（无契约规则）时的最小字符数：低于此值判失败，防"回了个空壳"也算过
    public static let DEFAULT_MIN_CHARS: Int64 = 200

    /// 无契约规则时的 contract_type 标记值
    public static let CONTRACT_ABSENT = "contract_absent"

    /**
     * 校验入口。
     *
     * @param output       子 agent 回传内容
     * @param capabilities agents 表的 capabilities 文本（JSON 或含 output_contract 片段的 YAML 文本）
     */
    public static func verify(output: String, capabilities: String): ContractVerdict {
        let trimmed = output.trim()
        if (trimmed.isEmpty()) {
            return ContractVerdict(false, "text", SubAgentContractVerifier.errJson(ArrayList<String>(["empty output"])))
        }
        match (SubAgentContractVerifier.parseContract(capabilities)) {
            case Some(contract) => SubAgentContractVerifier.verifyWithContract(trimmed, contract)
            case None => SubAgentContractVerifier.verifyNonEmpty(trimmed, SubAgentContractVerifier.DEFAULT_MIN_CHARS)
        }
    }

    /**
     * 从 capabilities 文本里取出 output_contract 规则对象。
     *
     * capabilities 在库里是文本字段，实际形态随同步链路可能有两种：
     *   ① 完整 JSON 对象（含 output_contract 键）——直接解析；
     *   ② YAML 数组文本（声明文件 frontmatter 原样带过来的）——退化为子串定位提取，
     *      避免为了取规则去改表结构（§6.7 限量：既有表不再加列）。
     */
    public static func parseContract(capabilities: String): Option<JsonObject> {
        if (capabilities.isEmpty()) {
            return None<JsonObject>
        }
        try {
            let obj = JsonValue.fromStr(capabilities).asObject()
            match (obj.get("output_contract")) {
                case Some(sub) => return Some(sub.asObject())
                case None => ()
            }
            // 顶层就是契约本身（形如 {"kind": "markdown", ...}）
            if (obj.get("kind").isSome() || obj.get("required_sections").isSome()) {
                return Some(obj)
            }
        } catch (_: Exception) {
            // 不是合法 JSON：走子串提取
        }
        return SubAgentContractVerifier.extractContractBlock(capabilities)
    }

    /**
     * 子串定位提取 `output_contract` 之后的第一个 **非嵌套** JSON 对象。
     *
     * 只做一级花括号配平即可：规则本身是扁平结构（数组用方括号，不含花括号），
     * 嵌套场景会解析失败并回落 contract_absent——宁可降级也不猜。
     *
     * 注：仓颉 String 是 UTF-8，`indexOf` 返回**字节**下标、`s[a..b]` 按字节切。
     * 这里切的边界全是 ASCII 花括号，故字节切片安全（切中文才会出问题）。
     */
    private static func extractContractBlock(text: String): Option<JsonObject> {
        match (text.indexOf("output_contract")) {
            case Some(k) => SubAgentContractVerifier.cutBlock(text, k)
            case None => None<JsonObject>
        }
    }

    /// 从 keyIdx 之后找第一个 `{`，再找它之后第一个 `}`，切片后解析
    private static func cutBlock(text: String, keyIdx: Int64): Option<JsonObject> {
        match (text.indexOf("{", keyIdx)) {
            case Some(open) => SubAgentContractVerifier.cutBlockClose(text, open)
            case None => None<JsonObject>
        }
    }

    private static func cutBlockClose(text: String, open: Int64): Option<JsonObject> {
        match (text.indexOf("}", open)) {
            case Some(close) =>
                let raw = if (close > open) { text[open..(close + 1)] } else { "" }
                SubAgentContractVerifier.parseObject(raw)
            case None => None<JsonObject>
        }
    }

    private static func parseObject(raw: String): Option<JsonObject> {
        if (raw.isEmpty()) {
            return None<JsonObject>
        }
        try {
            return Some(JsonValue.fromStr(raw).asObject())
        } catch (_: Exception) {
            return None<JsonObject>
        }
    }

    /**
     * 按契约规则校验。
     *
     * 规则字段（全部可选）：
     *   kind                   = markdown | json | text（默认 text）
     *   required_sections      = 必须出现的章节标题/子串数组
     *   forbidden_placeholders = 禁止出现的占位符数组（TODO / TBD / 待补充 等）
     *   min_chars              = 最小字符数
     *   schema                 = json 类契约的必填键数组
     */
    public static func verifyWithContract(output: String, contract: JsonObject): ContractVerdict {
        let kind = SubAgentContractVerifier.objStr(contract, "kind")
        let errors = ArrayList<String>()

        if (kind == "json") {
            match (SubAgentContractVerifier.tryParseJson(output)) {
                case Some(p) =>
                    for (key in SubAgentContractVerifier.strArray(contract, "schema")) {
                        if (p.get(key).isNone()) {
                            errors.add("missing key: ${key}")
                        }
                    }
                case None => errors.add("output is not valid JSON")
            }
        } else {
            for (sec in SubAgentContractVerifier.strArray(contract, "required_sections")) {
                if (!output.contains(sec)) {
                    errors.add("missing section: ${sec}")
                }
            }
        }

        for (ph in SubAgentContractVerifier.strArray(contract, "forbidden_placeholders")) {
            if (output.contains(ph)) {
                errors.add("forbidden placeholder: ${ph}")
            }
        }

        let minChars = SubAgentContractVerifier.objInt(contract, "min_chars")
        let n = SubAgentContractVerifier.runeCount(output)
        if (minChars > 0 && n < minChars) {
            errors.add("too short: ${n} < ${minChars}")
        }

        let contractType = if (kind.isEmpty()) { "text" } else { kind }
        if (errors.size == 0) {
            return ContractVerdict(true, contractType, "")
        }
        ContractVerdict(false, contractType, SubAgentContractVerifier.errJson(errors))
    }

    /**
     * 降级校验：仅非空 + 最小长度。
     *
     * contract_type 记 contract_absent，便于事后一眼看出"这个子 agent 还没配契约"。
     */
    public static func verifyNonEmpty(output: String, minChars: Int64): ContractVerdict {
        if (output.isEmpty()) {
            return ContractVerdict(false, SubAgentContractVerifier.CONTRACT_ABSENT,
                SubAgentContractVerifier.errJson(ArrayList<String>(["empty output"])))
        }
        let n = SubAgentContractVerifier.runeCount(output)
        if (n < minChars) {
            return ContractVerdict(false, SubAgentContractVerifier.CONTRACT_ABSENT,
                SubAgentContractVerifier.errJson(ArrayList<String>(["too short: ${n} < ${minChars}"])))
        }
        ContractVerdict(true, SubAgentContractVerifier.CONTRACT_ABSENT, "")
    }

    // ── 内部工具 ──────────────────────────────────────────────────

    /// 取 JSON 对象的字符串值（先例：`v is JsonString` + `(v as JsonString).getOrThrow().getValue()`）
    private static func objStr(obj: JsonObject, key: String): String {
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonString) {
                    return (v as JsonString).getOrThrow().getValue()
                }
                ""
            case None => ""
        }
    }

    /// 取 JSON 对象的整数值；缺失或非数值返回 0（0 = 不启用该规则）
    private static func objInt(obj: JsonObject, key: String): Int64 {
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonInt) {
                    return (v as JsonInt).getOrThrow().getValue()
                }
                0
            case None => 0
        }
    }

    /**
     * 取字符串数组：同时接受 JSON 数组与逗号分隔字符串两种写法。
     *
     * 后者是给 YAML 原样落库的场景留的口子——声明文件里写成
     * 一行逗号分隔的章节名也能生效。
     */
    private static func strArray(obj: JsonObject, key: String): ArrayList<String> {
        let out = ArrayList<String>()
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonArray) {
                    let arr = (v as JsonArray).getOrThrow()
                    for (item in arr.getItems()) {
                        if (item is JsonString) {
                            out.add((item as JsonString).getOrThrow().getValue())
                        }
                    }
                    return out
                }
                let single = SubAgentContractVerifier.objStr(obj, key)
                if (!single.isEmpty()) {
                    for (p in single.split(",")) {
                        let t = p.trim()
                        if (!t.isEmpty()) {
                            out.add(t)
                        }
                    }
                }
            case None => ()
        }
        out
    }

    private static func tryParseJson(s: String): Option<JsonObject> {
        try {
            return Some(JsonValue.fromStr(s).asObject())
        } catch (_: Exception) {
            return None<JsonObject>
        }
    }

    /**
     * 按 Rune 计字符数。
     *
     * 仓颉 String 是 UTF-8，`.size` 是**字节数**——中文产物会被算成 3 倍，
     * 用它判 min_chars 会系统性误判。产物全是中文，必须按 Rune 数
     * （同口径见 char_delta_splitter.cj:9-17）。
     */
    private static func runeCount(s: String): Int64 {
        s.toRuneArray().size
    }

    /// 错误列表序列化为 JSON 数组文本（JsonString 已负责转义与引号）
    private static func errJson(errs: ArrayList<String>): String {
        let sb = StringBuilder()
        sb.append("[")
        var first = true
        for (e in errs) {
            if (!first) {
                sb.append(", ")
            }
            sb.append(JsonString(e).toString())
            first = false
        }
        sb.append("]")
        sb.toString()
    }
}
