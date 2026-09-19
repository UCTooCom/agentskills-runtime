/*
 * LrtDegradation（long-running-task / Ch4.2 / tasks.md #244）
 * 降级策略链：cli_execute → builtin_tool → llm → template
 *
 * ── 为什么要有这个东西 ────────────────────────────────────────────────────
 * spec 5.5 的原则是「遇挫不停」：任何失败先重试 1 次，重试仍失败才**换方案**，
 * 全部方案都失败时要在 answer 里如实报告尝试了几次、每次为什么失败。
 * 此前 plugin.yaml 里声明了 `degradationChain`，但没有任何代码消费它——
 * 声明不存在就等于没有，本文件把它补成真实行为。
 *
 * ── 四个环节各自对应什么真实能力（不臆造）────────────────────────────────
 * 1. cli_execute ：经 LrtScriptRunner 用子进程重跑 `verify_artifact.py` 对失败产物做一次重验。
 *                  瞬时故障（磁盘抖动/文件正在被写）在这一步就被捞回来。
 *                  它不是"换个花样再跑一遍"，而是**换执行通道**：主流程是宿主 Agent 产出，
 *                  这里是插件自己拉起进程直接验证。
 * 2. builtin_tool：经 ctx.invoke("host.cache", "get", ...) 取本任务上一轮的好快照顶上。
 *                  宿主已开放的 5 个 host service 里挑最贴近的一个，不外挂新依赖。
 * 3. llm        ：经 D 层 `llm_fallback.py` 让模型按验收条件产出兜底内容。
 *                  模型不可用时脚本自身降级，本环返回失败，不假装成功。
 * 4. template   ：确定性兜底——把未完成的验收条件列清楚，**明确标注这是待办占位**。
 *
 * ── 最重要的一条纪律 ──────────────────────────────────────────────────────
 * 降级是为了"不停"，不是为了"假装成功"。每一步产出都必须带 `degraded: true` 与
 * `applied` 环名，让下游和人一眼看出"这一步不是按原计划跑通的"。
 * template 兜底尤其不能写成"已完成"——它产出的是待办清单，不是业务成果。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}

/// 降级链环节
public enum LrtDegradationLink <: Equatable<LrtDegradationLink> {
    | CliExecute
    | BuiltinTool
    | Llm
    | Template

    public operator func ==(right: LrtDegradationLink): Bool {
        match ((this, right)) {
            case (LrtDegradationLink.CliExecute, LrtDegradationLink.CliExecute) => true
            case (LrtDegradationLink.BuiltinTool, LrtDegradationLink.BuiltinTool) => true
            case (LrtDegradationLink.Llm, LrtDegradationLink.Llm) => true
            case (LrtDegradationLink.Template, LrtDegradationLink.Template) => true
            case _ => false
        }
    }

    public operator func !=(right: LrtDegradationLink): Bool {
        return !(this == right)
    }
}

public func linkName(l: LrtDegradationLink): String {
    match (l) {
        case LrtDegradationLink.CliExecute => "cli_execute"
        case LrtDegradationLink.BuiltinTool => "builtin_tool"
        case LrtDegradationLink.Llm => "llm"
        case LrtDegradationLink.Template => "template"
    }
}

public func parseLink(s: String): ?LrtDegradationLink {
    match (s.trimAscii().toAsciiLower()) {
        case "cli_execute" => Some(LrtDegradationLink.CliExecute)
        case "builtin_tool" => Some(LrtDegradationLink.BuiltinTool)
        case "llm" => Some(LrtDegradationLink.Llm)
        case "template" => Some(LrtDegradationLink.Template)
        case _ => None
    }
}

public class LrtDegradation {
    /// 默认链：与 COMPOSITION.yaml execute-rounds.degradation_chain 保持一致
    public static func defaultChain(): ArrayList<LrtDegradationLink> {
        let chain = ArrayList<LrtDegradationLink>()
        chain.add(LrtDegradationLink.CliExecute)
        chain.add(LrtDegradationLink.BuiltinTool)
        chain.add(LrtDegradationLink.Llm)
        chain.add(LrtDegradationLink.Template)
        return chain
    }

    /**
     * 按链依次尝试，返回结构化结果。
     *
     * 返回形如：
     *   { errno, errmsg, degraded: Bool, applied: string|null, output: string,
     *     attempts: [ { link, ok, reason } ] }
     *
     * `applied` 为 null 表示全链均未成功 —— 调用方必须据此把任务推进到"需要人看一眼"，
     * **不能因为调用了降级就当成跑通了**。
     */
    public static func run(
        taskId: String,
        round: Int64,
        failureContext: String,
        acceptance: ArrayList<String>,
        userId: String,
        permArr: ArrayList<JsonValue>,
        traceId: String
    ): JsonValue {
        let attempts = ArrayList<JsonValue>()
        var applied: ?LrtDegradationLink = None
        var output = ""

        for (link in LrtDegradation.defaultChain()) {
            // 已有环节成功就不再往后试：降级不是"全都跑一遍取最好的"，
            // 而是"第一个能救回来的方案就用它"，并记录清楚用的是哪个。
            match (applied) {
                case Some(_) => continue
                case None => ()
            }
            let (ok, out, reason) = LrtDegradation.tryLink(
                link, taskId, round, failureContext, acceptance, userId, permArr
            )
            let rec = HashMap<String, JsonValue>()
            rec["link"] = JsonValue.String(linkName(link))
            rec["ok"] = JsonValue.Boolean(ok)
            rec["reason"] = JsonValue.String(reason)
            rec["trace_id"] = JsonValue.String(traceId)
            attempts.add(JsonValue.from(rec))
            if (ok) {
                applied = Some(link)
                output = out
            }
        }

        let resp = HashMap<String, JsonValue>()
        match (applied) {
            case Some(l) =>
                resp["errno"] = JsonValue.Number(0.0)
                resp["errmsg"] = JsonValue.String("经降级环节 '${linkName(l)}' 完成（产出已标记 degraded）")
                resp["degraded"] = JsonValue.Boolean(true)
                resp["applied"] = JsonValue.String(linkName(l))
                resp["output"] = JsonValue.String(output)
            case None =>
                resp["errno"] = JsonValue.Number(50002.0)
                resp["errmsg"] = JsonValue.String("降级链四个环节均未成功，需转入人工")
                resp["degraded"] = JsonValue.Boolean(false)
                resp["applied"] = JsonValue.Null
                resp["output"] = JsonValue.String("")
        }
        resp["attempts"] = JsonValue.from(attempts)
        return JsonValue.from(resp)
    }

    // ── 单环节实现 ────────────────────────────────────────────────────

    private static func tryLink(
        link: LrtDegradationLink,
        taskId: String,
        round: Int64,
        failureContext: String,
        acceptance: ArrayList<String>,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): (Bool, String, String) {
        match (link) {
            case LrtDegradationLink.CliExecute =>
                return LrtDegradation.tryCliExecute(taskId, round, failureContext)
            case LrtDegradationLink.BuiltinTool =>
                return LrtDegradation.tryBuiltinTool(taskId, round, userId, permArr)
            case LrtDegradationLink.Llm =>
                return LrtDegradation.tryLlm(taskId, round, failureContext, acceptance)
            case LrtDegradationLink.Template =>
                return LrtDegradation.tryTemplate(round, acceptance)
        }
    }

    /// cli_execute：用子进程重跑一次产物验核脚本，捞回瞬时故障
    private static func tryCliExecute(taskId: String, round: Int64, failureContext: String): (Bool, String, String) {
        let args = ArrayList<String>()
        args.add("--task_id")
        args.add(taskId)
        args.add("--use_llm")
        args.add("0")
        if (!failureContext.isEmpty()) {
            args.add("--context")
            args.add(failureContext)
        }
        let r = LrtScriptRunner.runScriptJson("verify_artifact.py", args)
        match (r) {
            case JsonValue.Null =>
                return (false, "", "cli_execute 执行失败或无 JSON 输出（verify_artifact.py 未产出可解析结果）")
            case JsonValue.Map(f) =>
                match (f.get("passed")) {
                    // 重验通过 → 说明是可恢复的瞬时故障，降级成功
                    case Some(JsonValue.Boolean(b)) =>
                        if (b) {
                            return (true, "[degraded by cli_execute] round ${round} 重验通过\n${r.stringify()}", "")
                        }
                        return (false, "", "cli_execute 重验仍未通过")
                    case _ => return (false, "", "cli_execute 返回结果无 passed 字段")
                }
            case _ => return (false, "", "cli_execute 返回非对象结构")
        }
    }

    /// builtin_tool：取本任务上一轮缓存快照顶上
    private static func tryBuiltinTool(
        taskId: String,
        round: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): (Bool, String, String) {
        match (LrtPersistService.currentCtx()) {
            case None => return (false, "", "builtin_tool 不可用：插件上下文未初始化")
            case Some(ctx) =>
                let args = HashMap<String, JsonValue>()
                args["key"] = JsonValue.String("lrt:${taskId}:last-good-round")
                args["userId"] = JsonValue.String(userId)
                args["permissions"] = JsonValue.from(permArr)
                let res = ctx.invoke("host.cache", "get", JsonValue.from(args))
                match (res) {
                    case JsonValue.Null => return (false, "", "builtin_tool 无可用快照（host.cache 返回空）")
                    case JsonValue.Map(f) =>
                        match (f.get("value")) {
                            case Some(JsonValue.String(s)) =>
                                if (s.trimAscii().isEmpty()) {
                                    return (false, "", "builtin_tool 快照为空内容")
                                }
                                return (true, "[degraded by builtin_tool] round ${round} 沿用上一轮快照\n${s}", "")
                            case _ => return (false, "", "builtin_tool 快照格式不符（期待字符串）")
                        }
                    case _ => return (false, "", "builtin_tool 返回非对象结构")
                }
        }
    }

    /// llm：经 D 层 llm_fallback.py 让模型按验收条件产出兜底内容
    private static func tryLlm(
        taskId: String,
        round: Int64,
        failureContext: String,
        acceptance: ArrayList<String>
    ): (Bool, String, String) {
        if (acceptance.isEmpty()) {
            return (false, "", "llm 降级缺少验收条件作为依据")
        }
        let criteria = StringBuilder()
        for (c in acceptance) {
            criteria.append(c)
            criteria.append("\n")
        }
        let args = ArrayList<String>()
        args.add("--task_id")
        args.add(taskId)
        args.add("--round")
        args.add(round.toString())
        args.add("--failure")
        args.add(failureContext)
        args.add("--criteria")
        args.add(criteria.toString())
        let r = LrtScriptRunner.runScriptJson("llm_fallback.py", args)
        match (r) {
            case JsonValue.Null => return (false, "", "llm 降级失败：llm_fallback.py 执行失败或无 JSON 输出")
            case JsonValue.Map(f) =>
                match (f.get("ok")) {
                    case Some(JsonValue.Boolean(b)) =>
                        if (!b) {
                            return (false, "", "llm 降级未产出内容")
                        }
                        let content = LrtDegradation.strOf(r, "content")
                        if (content.trimAscii().isEmpty()) {
                            return (false, "", "llm 降级产出为空内容")
                        }
                        return (true, "[degraded by llm] round ${round}\n${content}", "")
                    case _ => return (false, "", "llm 降级返回缺少 ok 字段")
                }
            case _ => return (false, "", "llm 降级返回非对象结构")
        }
    }

    /// template：确定性兜底。**产出待办清单，绝不写成"已完成"**
    private static func tryTemplate(round: Int64, acceptance: ArrayList<String>): (Bool, String, String) {
        if (acceptance.isEmpty()) {
            return (false, "", "template 降级缺少验收条件，无法生成待办清单")
        }
        let sb = StringBuilder()
        sb.append("[degraded by template] round ${round}\n")
        sb.append("本轮未能真正执行，以下是待后续补齐的验收条件：\n")
        for (c in acceptance) {
            sb.append("  - ")
            sb.append(c)
            sb.append("\n")
        }
        return (true, sb.toString(), "")
    }

    private static func strOf(v: JsonValue, key: String): String {
        match (v.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => return s
            case _ => return ""
        }
    }
}
