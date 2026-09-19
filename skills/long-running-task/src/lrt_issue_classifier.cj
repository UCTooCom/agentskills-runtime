/*
 * LrtIssueClassifier（long-running-task / Ch7.1）
 * 把自进化的**实测证据**翻译成 P0-P3 分级问题列表（spec 5.11.3）。
 *
 * ── 为什么这一层必须是规则驱动，而不是让 LLM 直接分级 ──────────────────
 * 分级是下游所有动作的闸门：P0/P1 要进防回退注册表，P0 还要阻断回合继续跑。
 * 同一份证据每次跑出来的级别必须一致，否则长程任务的行为不可复现，
 * 自进化也就失去了"用证据替代猜测"的意义——分级层若再引入随机性，
 * 等于把猜测请回来了。LLM 的角色放在下游（润色修复建议文本），不参与定级。
 *
 * ── 输入：evidence（由 LrtSelfEvolution 环节 1 实测采集得到）────────────
 *   {
 *     "agent_id":  String,
 *     "round":     Int64,
 *     "artifact_total" / "artifact_passed" / "artifact_failed": Int64,
 *     "error_messages": [String],          // 来自 crontab_log.error_message 等
 *     "metrics": { "success_rate":Float64, "avg_duration_ms":Int64,
 *                  "tool_call_count":Int64, "total_tokens":Int64 },
 *     "max_round_duration_ms": Int64,      // 取自 plugin.yaml config
 *     "repeated":  Bool                    // 同签名问题是否上一轮已出现过
 *   }
 * 全部字段缺失都按"无该证据"处理：宁可少判一个问题，也不臆造证据。
 *
 * ── 输出 ────────────────────────────────────────────────────────────────
 *   { "errno":0, "errmsg":"ok",
 *     "highest_level":"P1",
 *     "counts":{"P0":n,"P1":n,"P2":n,"P3":n},
 *     "issues":[{ "code","level","category","summary","root_cause","suggestion" }] }
 *   issues 已按 P0→P3 排序，调用方取 [0] 即最严重的那条。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}

public class LrtIssueClassifier {
    public static let P0: String = "P0"
    public static let P1: String = "P1"
    public static let P2: String = "P2"
    public static let P3: String = "P3"

    /// 默认回合时长上限，与 plugin.yaml 的 config.maxRoundDurationMs 一致。
    /// evidence 没带该字段时用此值——取不到配置不该让分级整体失效。
    public static let DEFAULT_MAX_ROUND_DURATION_MS: Int64 = 1800000

    /**
     * 主入口：分级。
     *
     * 所有规则都跑一遍（而非命中即返回）：自进化要的是一张完整问题清单，
     * 只看最严重那一条会让"成功率高但耗时失控"这类慢性问题永远排不上修复日程。
     */
    public static func classify(evidence: JsonValue): JsonValue {
        let issues = ArrayList<JsonValue>()

        LrtIssueClassifier.ruleEnvBlocker(evidence, issues)
        LrtIssueClassifier.ruleNoOutput(evidence, issues)
        LrtIssueClassifier.rulePartialFailure(evidence, issues)
        LrtIssueClassifier.ruleSuccessRate(evidence, issues)
        LrtIssueClassifier.ruleRoundTooLong(evidence, issues)
        LrtIssueClassifier.ruleToolCallStorm(evidence, issues)
        if (issues.size == 0) {
            LrtIssueClassifier.ruleNoSignal(evidence, issues)
        }

        let order = ArrayList<String>()
        order.add(LrtIssueClassifier.P0)
        order.add(LrtIssueClassifier.P1)
        order.add(LrtIssueClassifier.P2)
        order.add(LrtIssueClassifier.P3)

        let sorted = ArrayList<JsonValue>()
        let counts = HashMap<String, JsonValue>()
        var highest = LrtIssueClassifier.P3
        var highestFound = false
        for (level in order) {
            var n: Int64 = 0
            for (issue in issues) {
                if (LrtIssueClassifier.strOf(issue, "level") == level) {
                    sorted.add(issue)
                    n = n + 1
                }
            }
            counts[level] = JsonValue.Number(Float64(n))
            if (n > 0 && !highestFound) {
                highest = level
                highestFound = true
            }
        }

        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["highest_level"] = JsonValue.String(highest)
        response["counts"] = JsonValue.from(counts)
        response["issues"] = JsonValue.from(sorted)
        return JsonValue.from(response)
    }

    /**
     * 级别序号，数值越小越严重（P0=0 … P3=3）。未知级别按 P2 处理——
     * 宁可当"中等"去修，也不要当作 P3 优化建议晾着。
     */
    public static func levelRank(level: String): Int64 {
        match (level) {
            case "P0" => return 0
            case "P1" => return 1
            case "P2" => return 2
            case _ => return 3
        }
    }

    /// 两个级别中更严重的那个
    public static func higherLevel(a: String, b: String): String {
        if (LrtIssueClassifier.levelRank(a) <= LrtIssueClassifier.levelRank(b)) {
            return a
        }
        return b
    }

    /// 是否需要阻断回合继续跑（P0 = 任务完全阻断无法继续）
    public static func shouldBlock(level: String): Bool {
        LrtIssueClassifier.levelRank(level) == 0
    }

    // ── 分级规则 ────────────────────────────────────────────────────
    // 每条规则只读 evidence 的确定字段，产出 0 或 1 条 issue。

    /**
     * R1 环境/依赖类致命错误 → P0。
     * 这类错误重试一百次也一样：连不上就是连不上，在坏环境下改批处理逻辑没有意义。
     * 判据是错误文本里的环境关键字，而不是"失败次数"——避免把普通业务失败误判成 P0。
     */
    private static func ruleEnvBlocker(evidence: JsonValue, out: ArrayList<JsonValue>): Unit {
        let messages = LrtIssueClassifier.stringArray(evidence, "error_messages")
        for (msg in messages) {
            let lower = msg.toAsciiLower()
            for (kw in LrtIssueClassifier.blockerKeywords()) {
                if (lower.contains(kw)) {
                    LrtIssueClassifier.appendIssue(out, "env_blocker", LrtIssueClassifier.P0, "environment",
                        "执行环境阻断：日志出现「${kw}」",
                        "依赖或环境不可用（连接/权限/磁盘/命令缺失），非任务逻辑本身的问题",
                        "先修复环境依赖再重跑本回合，不要在同一环境下反复重试")
                    return
                }
            }
        }
    }

    /**
     * R2 零产出 → P0。
     * 一个产物都没通过，任务等于原地踏步；继续排期下一轮只会在同一个坑里再摔一次。
     */
    private static func ruleNoOutput(evidence: JsonValue, out: ArrayList<JsonValue>): Unit {
        let total = LrtIssueClassifier.intOf(evidence, "artifact_total")
        let passed = LrtIssueClassifier.intOf(evidence, "artifact_passed")
        if (total > 0 && passed == 0) {
            LrtIssueClassifier.appendIssue(out, "no_output", LrtIssueClassifier.P0, "execution",
                "本轮 ${total} 个产物全部未通过验核",
                "产出链路整体失效：可能是命令/脚本不可用，也可能是产物路径约定与实际落盘位置不一致",
                "抽查 1 个失败产物的 verification_result.summary，确认根因后再决定改代码还是改约定")
        }
    }

    /**
     * R3 部分产物失败 → P2，重复出现升级 P1。
     * 有产出说明链路是通的，属于"能跑但跑不对"，因此不是阻断级；
     * 但同一问题连续两轮出现说明上一轮的修复没生效，必须提级引起注意。
     */
    private static func rulePartialFailure(evidence: JsonValue, out: ArrayList<JsonValue>): Unit {
        let passed = LrtIssueClassifier.intOf(evidence, "artifact_passed")
        let failed = LrtIssueClassifier.intOf(evidence, "artifact_failed")
        if (failed > 0 && passed > 0) {
            var level = LrtIssueClassifier.P2
            if (LrtIssueClassifier.boolOf(evidence, "repeated")) {
                level = LrtIssueClassifier.P1
            }
            LrtIssueClassifier.appendIssue(out, "partial_failure", level, "verification",
                "${passed} 个产物通过、${failed} 个未通过",
                "产出链路可用，但部分产物的内容/日期/完整性不满足目标要求",
                "取失败产物的 summary 逐条比对 acceptance_criteria，先改判定条件与产出约定的偏差")
        }
    }

    /**
     * R4 成功率低于阈值：核心功能产量不足 → P1/P2。
     * 阈值取 0.5 / 0.8 两档：<0.5 说明核心能力基本不可用，<0.8 说明勉强可用但质量不稳。
     */
    private static func ruleSuccessRate(evidence: JsonValue, out: ArrayList<JsonValue>): Unit {
        let metrics = LrtIssueClassifier.metricsOf(evidence)
        let rate = LrtIssueClassifier.dblOf(metrics, "success_rate")
        if (rate < 0.0) {
            return
        }
        if (rate < 0.5) {
            LrtIssueClassifier.appendIssue(out, "low_success_rate", LrtIssueClassifier.P1, "metrics",
                "实测成功率 ${rate} 低于 0.5",
                "核心链路成功率过低，多半是工具调用失败或反馈环路错配",
                "按 tool_call_count 与 metrics_detail 定位是哪一类调用在失败，先补这一个")
        } else if (rate < 0.8) {
            LrtIssueClassifier.appendIssue(out, "unstable_success_rate", LrtIssueClassifier.P2, "metrics",
                "实测成功率 ${rate}，处于 0.5~0.8 的不稳定区间",
                "能力可用但存在失败分支未收敛",
                "统计失败分支的分布，优先收敛占比最高的那一类")
        } else {
            ()
        }
    }

    /**
     * R5 回合耗时逼近上限 → P2。
     * 不达 P1 是因为"慢"本身不阻断任务，但它会让回合超时、检查点回滚，
     * 长程任务最终卡死往往就是从这个信号开始的。
     */
    private static func ruleRoundTooLong(evidence: JsonValue, out: ArrayList<JsonValue>): Unit {
        let metrics = LrtIssueClassifier.metricsOf(evidence)
        let avg = LrtIssueClassifier.intOf(metrics, "avg_duration_ms")
        if (avg <= 0) {
            return
        }
        var limit = LrtIssueClassifier.intOf(evidence, "max_round_duration_ms")
        if (limit <= 0) {
            limit = LrtIssueClassifier.DEFAULT_MAX_ROUND_DURATION_MS
        }
        if (avg * 100 > limit * 80) {
            LrtIssueClassifier.appendIssue(out, "round_too_long", LrtIssueClassifier.P2, "performance",
                "平均回合耗时 ${avg}ms 已达上限 ${limit}ms 的 80%",
                "单回合承担的步数过多或存在串行等待，再增长会触发回合超时",
                "拆分回合内的串行步骤，或把 I/O 等待改成并行；必要时上调 maxRoundDurationMs")
        }
    }

    /**
     * R6 工具调用风暴 → P2。
     * 工具调用次数失控通常意味着在两条反馈之间反复横跳（改了又改回来），
     * 是"缺乏停止条件"的典型症状。
     */
    private static func ruleToolCallStorm(evidence: JsonValue, out: ArrayList<JsonValue>): Unit {
        let metrics = LrtIssueClassifier.metricsOf(evidence)
        let calls = LrtIssueClassifier.intOf(metrics, "tool_call_count")
        if (calls > 60) {
            LrtIssueClassifier.appendIssue(out, "tool_call_storm", LrtIssueClassifier.P2, "metrics",
                "单轮工具调用 ${calls} 次，超过 60 次阈值",
                "反馈环路缺少终止条件，Agent 在多个方案之间反复切换",
                "给失败路径设显式重试上限，并在达到上限后强制降级而不是继续尝试")
        }
    }

    /**
     * R7 无信号 → P3。
     * 抓不到日志也抓不到指标时，不要假装"一切正常"。
     * 给一条 P3 明确写出"证据不足"，比给一张空清单更有价值——
     * 空清单会被下游当成"没问题"，而真实情况是**不知道有没有问题**。
     */
    private static func ruleNoSignal(evidence: JsonValue, out: ArrayList<JsonValue>): Unit {
        LrtIssueClassifier.appendIssue(out, "no_evidence", LrtIssueClassifier.P3, "observability",
            "未采集到足够的日志/指标证据",
            "Agent 未上报 metrics，或 crontab_log 没有本轮记录",
            "补强埋点：确认回合结束时写入 crontab_log 与 agent_loop_metrics 后再重启自进化")
    }

    // ── 内部 ────────────────────────────────────────────────────────

    private static func appendIssue(
        out: ArrayList<JsonValue>,
        code: String,
        level: String,
        category: String,
        summary: String,
        rootCause: String,
        suggestion: String
    ): Unit {
        let m = HashMap<String, JsonValue>()
        m["code"] = JsonValue.String(code)
        m["level"] = JsonValue.String(level)
        m["category"] = JsonValue.String(category)
        m["summary"] = JsonValue.String(summary)
        m["root_cause"] = JsonValue.String(rootCause)
        m["suggestion"] = JsonValue.String(suggestion)
        out.add(JsonValue.from(m))
    }

    /// 环境阻断关键词。用函数而不是静态数组：何时起初不合.collections expect，取决于语言版本，这里取最稳的写法。
    private static func blockerKeywords(): ArrayList<String> {
        let kws = ArrayList<String>()
        kws.add("connection refused")
        kws.add("could not connect")
        kws.add("permission denied")
        kws.add("out of memory")
        kws.add("no space left")
        kws.add("command not found")
        kws.add("authentication failed")
        kws.add("no such file or directory")
        kws.add("timeout")
        return kws
    }

    private static func metricsOf(evidence: JsonValue): JsonValue {
        match (evidence.get("metrics", JsonValue.Null)) {
            case JsonValue.Map(_) => return evidence.get("metrics", JsonValue.Null)
            case _ => return JsonValue.Null
        }
    }

    private static func intOf(json: JsonValue, key: String): Int64 {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.Number(n) => return Int64(n)
            case _ => return 0
        }
    }

    private static func dblOf(json: JsonValue, key: String): Float64 {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.Number(n) => return n
            case _ => return -1.0
        }
    }

    private static func boolOf(json: JsonValue, key: String): Bool {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.Boolean(b) => return b
            case _ => return false
        }
    }

    private static func strOf(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => return s
            case _ => return ""
        }
    }

    private static func stringArray(json: JsonValue, key: String): ArrayList<String> {
        let result = ArrayList<String>()
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.Array(items) =>
                for (it in items) {
                    match (it) {
                        case JsonValue.String(s) => result.add(s)
                        case _ => ()
                    }
                }
            case _ => ()
        }
        return result
    }
}
