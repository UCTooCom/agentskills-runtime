/*
 * LrtSelfEvolutionLoop（long-running-task / Ch7.3）
 * 自进化**五环节闭环**（spec 5.11）：
 *   环节 1 实测驱动 → 环节 2 根因分析 → 环节 3 增量优化 → 环节 4 防回退 → 环节 5 显式约束注入
 *
 * ── 命名偏差说明 ────────────────────────────────────────────────────────
 * tasks.md 7.3 期望 `LrtSelfEvolutionLoop.run`；本文件类名保持 `LrtSelfEvolution`、
 * 入口保持 `evolve`，原因是它已在 lrt_handlers / lrt_executor / 测试用例多处引用，
 * 改名带来的收益（名字对齐）小于风险（跨文件符号失配）。**闭环本身按五环节实现**，
 * 这一点在本文件 `evolve` 的实现里逐环节标注。
 *
 * ── 环节 1 为什么不能用"猜"出来的上下文 ────────────────────────────────
 * 自进化的可信度完全取决于输入是不是**实测证据**。早期版本把失败产物的摘要拼成
 * context 就交给 LLM 做根因分析，等于让模型猜。现在改为先查 `agent_loop_metrics`
 * （成功率/耗时/工具调用）+ `crontab_log`（错误日志）+ 产物验核结果，再交给分级器。
 * 三者都查不到时会明确产出一条 `no_evidence` P3 问题，而不是假装无事发生。
 *
 * ── 环节 3 的能力边界（重要，避免误解）─────────────────────────────────
 * 「增量优化」产出的是**改动方案**（optimization_plan），本类不自动改任何代码/配置。
 * 让一个进程在无人值守时直接修改仓库源码，风险远大于收益；方案落库后由人或受控
 * 车间的 codified pipeline 执行。这一点在 tasks.md 7.3 环节 3 同步标注为"仅出方案"。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.time.DateTime

public class LrtSelfEvolution {
    /**
     * 执行一轮自进化闭环并落库。
     *
     * @param taskId 可选。给了就一并采集该任务的产物验核分布（证据质量更高）。
     */
    public static func evolve(
        agentId: String,
        round: Int64,
        context: String,
        skill: String,
        userId: String,
        permArr: ArrayList<JsonValue>,
        // 仓颉里只有**命名参数**（`!` 后缀）才能声明默认值，`taskId: String = ""` 会在
        // 参数列表处直接报 "expected ',' or ')'"。这里改成命名参数：调用方可直接省略，
        // 需要传值时必须按名传 `taskId: x`（见 lrt_executor.cj 的调用点）。
        taskId!: String = ""
    ): JsonValue {
        if (agentId.isEmpty()) {
            return LrtPersistService.errResult(40002, "agent_id 不能为空")
        }

        // ── 环节 1 实测驱动：先取证据，再谈根因 ──────────────────────
        let evidence = LrtSelfEvolution.collectEvidence(taskId, agentId, round, userId, permArr)

        // ── 环节 2 根因分析：D 层 evolve.py + 规则分级器 ─────────────
        let args = ArrayList<String>()
        args.add("--agent_id")
        args.add(agentId)
        args.add("--round")
        args.add(round.toString())
        if (!context.isEmpty()) {
            args.add("--context")
            args.add(context)
        }
        if (!skill.isEmpty()) {
            args.add("--skill")
            args.add(skill)
        }
        let result = LrtScriptRunner.runScriptJson("evolve.py", args)
        match (result) {
            case JsonValue.Null =>
                // 即使脚本失败，**已采集的证据与分级结论也不该丢**：这是舍报错也要保住的信息
                let degraded = LrtSelfEvolution.buildResponse(result, evidence, "", "", JsonValue.Null,
                    JsonValue.Null, ArrayList<JsonValue>(), JsonValue.Null, JsonValue.Null)
                let failMap = LrtSelfEvolution.asMap(degraded)
                failMap["errno"] = JsonValue.Number(50001.0)
                failMap["errmsg"] = JsonValue.String("evolve.py 执行失败或无 JSON 输出（证据与分级仍已产出）")
                return JsonValue.from(failMap)
            case _ =>
                // evolve.py 的输出是**两层结构**：
                //   {"ok":true, "output":"...", "evolution":{root_cause, optimization_plan,
                //                                            anti_regression, skill_md_updates, ...}}
                // 三个业务字段在 `evolution` 里，不在顶层。直接取顶层会恒得空串，
                // 且因为 extractString 对缺失键返回 ""（而非报错），这个 bug 完全静默——
                // 自进化表会被写入一堆空根因。故这里先下沉一层，并在缺失时回退顶层
                // （兼容将来脚本去掉包装层的情况）。
                let body = LrtSelfEvolution.unwrapEvolution(result)
                let rootCause = LrtSelfEvolution.extractString(body, "root_cause")
                let optimizationPlan = LrtSelfEvolution.extractString(body, "optimization_plan")
                let antiRegression = LrtSelfEvolution.extractString(body, "anti_regression")
                let skillMdUpdates = match (body.get("skill_md_updates", JsonValue.Null)) {
                    case v => v
                }
                let classification = LrtIssueClassifier.classify(evidence)
                let issues = LrtSelfEvolution.issuesOf(classification)

                // ── 环节 3 增量优化：将 optimization_plan 落地为调优配置 ──
                //    从「只出方案」升级为「出方案 + 写 agent_loop_tuning_configs」，
                //    宿主侧调优服务读取 is_enabled=true 的记录并应用。
                //    不直接改仓库源码：让进程在无人值守时改源码风险远大于收益。
                let optimizationApplied = LrtSelfEvolution.applyOptimization(
                    agentId, round, optimizationPlan, userId, permArr
                )

                // ── 环节 4 防回退：P0/P1 进注册表（P2/P3 只做建议，不污染约束区）──
                let registered = ArrayList<JsonValue>()
                for (issue in issues) {
                    let level = LrtSelfEvolution.strOf(issue, "level")
                    if (!LrtSelfEvolution.shouldRegister(level)) {
                        continue
                    }
                    let regResult = LrtAntiRegressionRegistry.register(
                        agentId, round,
                        LrtSelfEvolution.strOf(issue, "code"),
                        level,
                        LrtSelfEvolution.strOf(issue, "summary"),
                        LrtSelfEvolution.strOf(issue, "suggestion"),
                        "1.0.0"
                    )
                    registered.add(regResult)
                }

                // ── 环节 5 显式约束注入：SKILL.md 标记块幂等替换 ────────
                let injection = LrtAntiRegressionRegistry.injectIntoS()

                // 环节 5 落库：anti_regression 文本记录脚本产出 + 分级结论 + 注入结果，
                // 便于只查 SQL 也能复盘这一轮发生了什么
                let persisted = LrtPersistService.logEvolution(
                    agentId, round, rootCause, optimizationPlan,
                    LrtSelfEvolution.composeAntiRegressionText(antiRegression, issues, injection),
                    skillMdUpdates, userId, permArr
                )
                return LrtSelfEvolution.buildResponse(result, evidence, rootCause, optimizationPlan,
                    optimizationApplied, classification, registered, injection, persisted)
        }
    }

    // ── 环节 1：证据采集 ────────────────────────────────────────────

    /**
     * 采集实测证据。三个来源，任一失败都降级为"该来源无数据"而不是整体报错：
     *   1. 产物验核分布（long_running_task_artifact，需 taskId）
     *   2. 运行指标（agent_loop_metrics，按 agent_id 取最新一条）
     *   3. 错误日志（crontab_log 最近 N 条非空错误）
     */
    private static func collectEvidence(
        taskId: String,
        agentId: String,
        round: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["agent_id"] = JsonValue.String(agentId)
        m["round"] = JsonValue.Number(Float64(round))
        m["max_round_duration_ms"] = JsonValue.Number(Float64(LrtConfig.maxRoundDurationMs()))

        var total: Int64 = 0
        var passed: Int64 = 0
        var failed: Int64 = 0
        if (!taskId.isEmpty()) {
            let rows = LrtPersistService.queryMany(
                LrtPersistService.TABLE_ARTIFACT,
                "task_id = '${taskId}' AND deleted_at IS NULL", userId, permArr, 1000
            )
            total = Int64(rows.size)
            for (r in rows) {
                let status = LrtSelfEvolution.strOf(r, "verification_status")
                if (status == "passed") {
                    passed = passed + 1
                } else if (status == "failed") {
                    failed = failed + 1
                } else {
                    ()
                }
            }
        }
        m["artifact_total"] = JsonValue.Number(Float64(total))
        m["artifact_passed"] = JsonValue.Number(Float64(passed))
        m["artifact_failed"] = JsonValue.Number(Float64(failed))

        // 指标表可能没有本 agent 的记录（首次运行），按"无数据"处理（success_rate 缺席 → 规则跳过）
        let metricsRow = LrtPersistService.queryOne(
            "agent_loop_metrics", "agent_id = '${agentId}' AND deleted_at IS NULL", userId, permArr
        )
        match (metricsRow) {
            case JsonValue.Map(row) =>
                for (key in row.keys()) {
                    match (row.get(key)) {
                        case Some(JsonValue.Number(n)) => m[key] = JsonValue.Number(n)
                        case Some(JsonValue.String(s)) => m[key] = JsonValue.String(s)
                        case Some(v) => m[key] = v
                        case None => ()
                    }
                }
            case _ => ()
        }

        // crontab_log 没有 task 维度，取最近的错误条目作为环境证据
        let logRows = LrtPersistService.queryMany(
            "crontab_log", "error_message IS NOT NULL AND error_message != '' AND deleted_at IS NULL",
            userId, permArr, 20
        )
        let messages = ArrayList<JsonValue>()
        for (lr in logRows) {
            let msg = LrtSelfEvolution.strOf(lr, "error_message")
            if (!msg.isEmpty()) {
                messages.add(JsonValue.String(msg))
            }
        }
        m["error_messages"] = JsonValue.from(messages)

        m["repeated"] = JsonValue.Boolean(
            LrtSelfEvolution.detectRepeated(agentId, round, userId, permArr)
        )
        return JsonValue.from(m)
    }

    /**
     * 判断"同一问题是否在更早的轮次已经出现过"。
     *
     * 这里用**保守启发式**：只要本 agent 在更早轮次留下过非空 root_cause，就判重复。
     * 它会产生假阳性（两轮根因不同但都非空），但假阳性只让问题级别从 P2 升到 P1，
     * 代价是"多看一眼"；假阴性则会让真正反复失败的问题被当成新伤一路试下去。
     * 后续若 evolution 表增加 issue_code 列，可改成按 code 精确匹配。
     */
    private static func detectRepeated(agentId: String, round: Int64, userId: String, permArr: ArrayList<JsonValue>): Bool {
        if (round <= 1) {
            return false
        }
        let rows = LrtPersistService.queryMany(
            LrtPersistService.TABLE_EVOLUTION,
            "agent_id = '${agentId}' AND deleted_at IS NULL", userId, permArr, 20
        )
        for (r in rows) {
            // 注意：`r` 是 JsonValue（不是 HashMap）。jsonvalue 库里 JsonValue.get 是
            // **两参** `get(key, default)` 且返回 JsonValue（缺失已折成 default）；
            // 单参 `get(key)` 只有 HashMap 才有，返回 ?JsonValue 才能配 `Some(...)`。
            // 这里混用会直接报 "missing argument for parameter list '(Struct-String, Enum-JsonValue)'"。
            match (r.get("round", JsonValue.Null)) {
                case JsonValue.Number(n) =>
                    if (Int64(n) < round) {
                        match (r.get("root_cause", JsonValue.Null)) {
                            case JsonValue.String(s) =>
                                if (!s.isEmpty()) {
                                    return true
                                }
                            case _ => ()
                        }
                    }
                case _ => ()
            }
        }
        return false
    }

    // ── 环节 3：增量优化落地 ────────────────────────────────────────

    /**
     * 将 optimization_plan 落地为调优配置（spec 5.11 环节3 / spec 6.5）。
     *
     * 从「只出方案文本」升级为「出方案 + 写 agent_loop_tuning_configs 表」：
     *   1. 解析方案文本判断策略类型（prompt/tool/execution）
     *   2. 构建结构化 config JSON（含方案文本、轮次、时间戳）
     *   3. 写入 agent_loop_tuning_configs（幂等：同 agent + 同 strategy_type 只保留一条）
     *   4. 宿主侧调优服务读取 is_enabled=true 的记录并应用
     *
     * 不直接改仓库源码：让进程在无人值守时改源码风险远大于收益。
     * 方案为空时返回 Null（无方案可应用，不报错）。
     */
    private static func applyOptimization(
        agentId: String,
        round: Int64,
        optimizationPlan: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (optimizationPlan.isEmpty()) {
            return JsonValue.Null
        }
        let strategyType = LrtSelfEvolution.inferStrategyType(optimizationPlan)
        let config = HashMap<String, JsonValue>()
        config["plan"] = JsonValue.String(optimizationPlan)
        config["round"] = JsonValue.Number(Float64(round))
        config["applied_at"] = JsonValue.String("${DateTime.now()}")
        return LrtPersistService.logTuningConfig(
            agentId, strategyType, JsonValue.from(config), true, userId, permArr
        )
    }

    /// 根据方案文本关键词推断策略类型（spec 6.5 strategy_type 取值）
    private static func inferStrategyType(plan: String): String {
        if (plan.contains("tool") || plan.contains("工具")) {
            return "tool_selection_optimization"
        }
        if (plan.contains("execution") || plan.contains("path") || plan.contains("执行路径")) {
            return "execution_path_optimization"
        }
        return "prompt_optimization"
    }

    // ── 响应组装 ────────────────────────────────────────────────────

    private static func buildResponse(
        evolution: JsonValue,
        evidence: JsonValue,
        rootCause: String,
        optimizationPlan: String,
        optimizationApplied: JsonValue,
        classification: JsonValue,
        registered: ArrayList<JsonValue>,
        injection: JsonValue,
        persisted: JsonValue
    ): JsonValue {
        let stages = HashMap<String, JsonValue>()
        stages["1_evidence"] = evidence
        stages["2_classification"] = classification
        stages["3_optimization_plan"] = JsonValue.String(optimizationPlan)
        stages["3_optimization_applied"] = optimizationApplied
        stages["4_anti_regression_registered"] = JsonValue.from(registered)
        stages["5_constraint_injection"] = injection

        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["root_cause"] = JsonValue.String(rootCause)
        response["optimization_plan"] = JsonValue.String(optimizationPlan)
        response["stages"] = JsonValue.from(stages)
        response["evolution"] = evolution
        response["persisted"] = persisted
        return JsonValue.from(response)
    }

    /// 写进 evolution 表的 anti_regression 文本：脚本产出 + 分级结论 + 注入结果
    private static func composeAntiRegressionText(
        scriptText: String,
        issues: ArrayList<JsonValue>,
        injection: JsonValue
    ): String {
        let sb = StringBuilder()
        if (!scriptText.isEmpty()) {
            sb.append(scriptText)
            sb.append("\n\n")
        }
        for (issue in issues) {
            sb.append("[${LrtSelfEvolution.strOf(issue, "level")}] ${LrtSelfEvolution.strOf(issue, "summary")}"
                + " → ${LrtSelfEvolution.strOf(issue, "suggestion")}\n")
        }
        match (injection) {
            case JsonValue.Map(f) =>
                match (f.get("errno")) {
                    case Some(JsonValue.Number(n)) =>
                        if (Int64(n) != 0) {
                            sb.append("\n（约束注入失败：${LrtSelfEvolution.strOf(injection, "errmsg")}）")
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return sb.toString()
    }

    // ── 内部 ────────────────────────────────────────────────────────

    private static func issuesOf(classification: JsonValue): ArrayList<JsonValue> {
        match (classification.get("issues", JsonValue.Null)) {
            case JsonValue.Array(items) => return items
            case _ => return ArrayList<JsonValue>()
        }
    }

    private static func shouldRegister(level: String): Bool {
        level == "P0" || level == "P1"
    }

    private static func asMap(json: JsonValue): HashMap<String, JsonValue> {
        match (json) {
            case JsonValue.Map(m) => return m
            case _ => return HashMap<String, JsonValue>()
        }
    }

    private static func strOf(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => return s
            case _ => return ""
        }
    }

    /**
     * 取出 evolve.py 输出里承载业务字段的那一层。
     *
     * 优先 `evolution`（脚本当前的包装结构）；该键不存在或不是对象时原样返回输入，
     * 以便脚本改成「直接输出业务字段」后本方法无需再改。
     */
    private static func unwrapEvolution(result: JsonValue): JsonValue {
        let inner = result.get("evolution", JsonValue.Null)
        match (inner) {
            case JsonValue.Map(_) => return inner
            case _ => return result
        }
    }

    private static func extractString(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => s
            case _ => ""
        }
    }
}
