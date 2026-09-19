/*
 * LrtVerifier（long-running-task / Ch6）
 * 产物结构化验核：调 D 层 verify_artifact.py，落库 long_running_task_artifact。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.env.getVariable
import std.time.DateTime

public class LrtVerifier {
    /// 校验单个产物并落库；返回验核结果 JSON
    ///
    /// agentId 用于验核指标上报（spec 5.6.1 规则 6：验核结果上报到 agent_loop_metrics）。
    /// 为空时跳过指标上报，不阻断验核本身。
    ///
    /// expectedDate 为命名参数（缺省空）：非空时优先使用；为空时**回落到从 goal 抽取**
    /// 的首个 `YYYY-MM-DD`。见 `extractExpectedDate` 的说明——主路径必须默认带日期校验，
    /// 否则 5.10.1 规则 5「旧日期文件不算完成」在本插件里等于没实现（review 偏差 #6）。
    public static func verify(
        artifactPath: String,
        artifactType: String,
        taskId: String,
        agentId: String,
        userId: String,
        permArr: ArrayList<JsonValue>,
        goal: String,
        expectedDate!: String = ""
    ): JsonValue {
        let verifyStartMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        if (artifactPath.isEmpty()) {
            return LrtPersistService.errResult(40002, "artifact_path 不能为空")
        }
        // 确定性文件态快检（§5.10）：存在 + 非空 + 日期/内容匹配；不通过则直接判 failed，避免无谓拉起 LLM
        // 预期日期取「显式入参 > goal 抽取」两级：显式入参供调用方精确指定，
        // 缺省走抽取是为了让**所有既有调用点**（executor / handlers）无需改动即获得日期防护。
        let effectiveDate = if (!expectedDate.isEmpty()) { expectedDate } else { LrtVerifier.extractExpectedDate(goal) }
        let (fileOk, fileReason) = LrtArtifactVerifier.verifyFileState(artifactPath, effectiveDate, goal)
        if (!fileOk) {
            // 快检失败也要走同一份报告结构：否则失败产物在产物表里缺 goalAchievement
            // 等键，前端与自进化读到的是"半份报告"，走过的分支越关键越容易出问题。
            let failJson = HashMap<String, JsonValue>()
            failJson["passed"] = JsonValue.Boolean(false)
            failJson["summary"] = JsonValue.String(fileReason)
            failJson["file_state"] = JsonValue.Boolean(false)
            let failReport = LrtVerifier.buildReport(artifactPath, artifactType, false, JsonValue.from(failJson), goal)
            LrtPersistService.logArtifact(taskId, artifactPath, artifactType, "failed", failReport, userId, permArr)
            LrtVerifier.reportMetrics(taskId, agentId, false, verifyStartMs, userId, permArr)
            let response = HashMap<String, JsonValue>()
            response["errno"] = JsonValue.Number(0.0)
            response["errmsg"] = JsonValue.String("ok")
            response["status"] = JsonValue.String("failed")
            response["verification"] = failReport
            return JsonValue.from(response)
        }
        let args = ArrayList<String>()
        args.add("--artifact_path")
        args.add(artifactPath)
        args.add("--artifact_type")
        args.add(if (artifactType.isEmpty()) { "artifact" } else { artifactType })
        if (!taskId.isEmpty()) {
            args.add("--task_id")
            args.add(taskId)
        }
        if (!goal.isEmpty()) {
            args.add("--goal")
            args.add(goal)
        }
        let useLlm = LrtVerifier.getEnv("LRT_USE_LLM")
        args.add("--use_llm")
        args.add(if (useLlm == "1") { "1" } else { "0" })

        let result = LrtScriptRunner.runScriptJson("verify_artifact.py", args)
        match (result) {
            case JsonValue.Null =>
                return LrtPersistService.errResult(50001, "verify_artifact.py 执行失败或无 JSON 输出")
            case _ =>
                // verify_artifact.py 的输出是**两层结构**：
                //   {"ok":true, "status":"passed|failed", "output":"...", "summary":"..."}
                //   同时脚本会把完整验核详情写入 output 指向的报告文件。
                // 顶层只有 status/summary，**没有** `passed` 布尔键——若只读顶层
                // `passed` 会恒得 null → 判 false → 所有产物被误标 failed（静默且致命）。
                // 故这里以 `status` 字符串为准，并兼容脚本将来改回 `passed` 布尔键。
                let passed = LrtVerifier.resolvePassed(result)
                let status = if (passed) { "passed" } else { "failed" }
                let report = LrtVerifier.buildReport(artifactPath, artifactType, passed, result, goal)
                LrtPersistService.logArtifact(taskId, artifactPath, artifactType, status, report, userId, permArr)
                LrtVerifier.reportMetrics(taskId, agentId, passed, verifyStartMs, userId, permArr)
                let response = HashMap<String, JsonValue>()
                response["errno"] = JsonValue.Number(0.0)
                response["errmsg"] = JsonValue.String("ok")
                response["status"] = JsonValue.String(status)
                response["verification"] = report
                return JsonValue.from(response)
        }
    }

    /**
     * 把 D 层脚本输出整理成**五项固定的验核报告结构**（spec 5.13 / Ch6.2）：
     *   goalAchievement  Float64  本产物对目标的达成度（单产物口径：通过 1.0 / 未通过 0.0）
     *   artifacts        Array    产物清单（path / type / status）
     *   testResults      Array    逐项检查结果（name / passed / detail）
     *   knownIssues      Array    已知问题（失败项的 detail 摘要）
     *   suggestions      Array    改进建议
     *
     * 五项**一律存在**：缺项时给空数组而不是省掉键。理由是消费方（前端、老板验收、
     * 自进化）都按这五个键取值，键缺失会让它们各自 fallback，最后变成"谁也读不到
     * 一致数据"。原始脚本输出保留在 `raw` 里，供排障时追溯，不参与契约。
     *
     * `summary` 也始终保留：lrt_executor 的 buildEvolutionContext 依赖它拼自进化上下文。
     */
    public static func buildReport(
        artifactPath: String,
        artifactType: String,
        passed: Bool,
        scriptResult: JsonValue,
        goal: String
    ): JsonValue {
        let status = if (passed) { "passed" } else { "failed" }
        let summary = LrtVerifier.strAt(scriptResult, "summary")

        let artifacts = ArrayList<JsonValue>()
        let one = HashMap<String, JsonValue>()
        one["path"] = JsonValue.String(artifactPath)
        one["type"] = JsonValue.String(if (artifactType.isEmpty()) { "artifact" } else { artifactType })
        one["status"] = JsonValue.String(status)
        artifacts.add(JsonValue.from(one))

        // 检查结果：脚本给了 checks 就直接用，否则按结论合成一条，保证结构齐备
        let testResults = ArrayList<JsonValue>()
        match (scriptResult.get("checks", JsonValue.Null)) {
            case JsonValue.Array(items) =>
                for (it in items) {
                    testResults.add(it)
                }
            case _ =>
                let synth = HashMap<String, JsonValue>()
                synth["name"] = JsonValue.String("verification")
                synth["passed"] = JsonValue.Boolean(passed)
                synth["detail"] = JsonValue.String(if (summary.isEmpty()) { "无明细" } else { summary })
                testResults.add(JsonValue.from(synth))
        }

        let knownIssues = ArrayList<JsonValue>()
        let suggestions = ArrayList<JsonValue>()
        if (!passed) {
            let issue = HashMap<String, JsonValue>()
            issue["artifact"] = JsonValue.String(artifactPath)
            issue["detail"] = JsonValue.String(if (summary.isEmpty()) { "产物未通过验核（无明细）" } else { summary })
            knownIssues.add(JsonValue.from(issue))

            let sug = HashMap<String, JsonValue>()
            sug["target"] = JsonValue.String(artifactPath)
            sug["action"] = JsonValue.String(
                "重跑产出该产物的步骤；若再次失败，按 ${if (goal.isEmpty()) { "目标成功标准" } else { goal }} 核对产出内容与日期是否匹配"
            )
            suggestions.add(JsonValue.from(sug))
        }

        let report = HashMap<String, JsonValue>()
        report["summary"] = JsonValue.String(if (summary.isEmpty()) { "无摘要" } else { summary })
        report["goalAchievement"] = JsonValue.Number(if (passed) { 1.0 } else { 0.0 })
        report["artifacts"] = JsonValue.from(artifacts)
        report["testResults"] = JsonValue.from(testResults)
        report["knownIssues"] = JsonValue.from(knownIssues)
        report["suggestions"] = JsonValue.from(suggestions)
        report["checked_at"] = JsonValue.String("${DateTime.now()}")
        report["raw"] = scriptResult
        return JsonValue.from(report)
    }

    /**
     * 从目标原文里抽取第一个 `YYYY-MM-DD` 形态的日期（spec 5.10.1 规则 5 的"用户要求日期"）。
     *
     * 为什么从 goal 抽、而不是要求每个入口显式传：
     * 日期要求本来就写在用户目标原文里（"生成 2026-08-10 的简报"）。让调用方逐个透传，
     * 等于把防护责任推给每个入口——漏一处就静默退化成"没有日期校验"，
     * 这正是 review 偏差 #6 的成因（唯一调用点传了空串，防护等于没开）。
     * 抽取让**主路径默认生效**；`expectedDate` 命名参数保留给需要精确覆盖的调用方。
     *
     * 兼容三种常见写法：`2026-08-10` / `2026/08/10` / `2026年08月10日`
     * （先把分隔符统一成 `-`，再按 10 字节窗口扫描）。
     * 抽不到（goal 里没有日期）返回空串——此时 `verifyFileState` 跳过日期校验，
     * 而不是拿一个空日期把所有产物判失败。
     *
     * 按 **UTF-8 字节**扫描是安全的：目标形态全是 ASCII，而 UTF-8 多字节序列的任一字节都 ≥ 0x80，
     * 不可能被误判成 `0-9` 或 `-`，故不会在多字节字符内部产生假命中。
     */
    private static func extractExpectedDate(goal: String): String {
        if (goal.size < 10) {
            return ""
        }
        let norm = goal.replace("/", "-").replace("年", "-").replace("月", "-").replace("日", "-")
        let n = norm.size
        var i = 0
        while (i + 10 <= n) {
            if (LrtVerifier.isDateAt(norm, i)) {
                return norm[i..i + 10]
            }
            i = i + 1
        }
        return ""
    }

    /// 判定 `s[start .. start+10)` 是否为 `YYYY-MM-DD`（第 4、7 字节为 `-`，其余为数字）
    private static func isDateAt(s: String, start: Int64): Bool {
        var k = 0
        while (k < 10) {
            let c = s[start + k]
            let hit = if (k == 4 || k == 7) {
                c == b'-'
            } else {
                c >= b'0' && c <= b'9'
            }
            if (!hit) {
                return false
            }
            k = k + 1
        }
        return true
    }

    private static func strAt(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => return s
            case _ => return ""
        }
    }

    /**
     * 判定验核是否通过。兼容三种脚本输出形态，优先取最明确的那个：
     *   1. 顶层 `status == "passed"`（verify_artifact.py 当前形态）
     *   2. 顶层 `passed: true`（布尔键，早期/未来形态）
     *   3. 嵌套在 `verification` 对象里的 `passed`（若脚本改为嵌套输出）
     * 三者都没有 → 判 false（宁可误报失败去人工看，也不能把失败当通过放行）。
     */
    private static func resolvePassed(result: JsonValue): Bool {
        // 1) status 字符串
        match (result.get("status", JsonValue.Null)) {
            case JsonValue.String(s) =>
                if (s == "passed") {
                    return true
                }
                if (s == "failed") {
                    return false
                }
            case _ => ()
        }
        // 2) 顶层 passed 布尔
        match (result.get("passed", JsonValue.Null)) {
            case JsonValue.Boolean(b) => return b
            case _ => ()
        }
        // 3) 嵌套 verification.passed
        match (result.get("verification", JsonValue.Null)) {
            case JsonValue.Map(m) =>
                match (m.get("passed")) {
                    case Some(JsonValue.Boolean(b)) => return b
                    case _ => ()
                }
            case _ => ()
        }
        return false
    }

    /**
     * 验核指标上报（spec 5.6.1 规则 6 / Ch6.2）。
     *
     * agentId 为空时跳过：调用方不一定有 agentId（如外部直接调 lrt-verify 路由），
     * 指标上报是 best-effort，不该因为缺 agentId 就让验核失败。
     */
    private static func reportMetrics(
        taskId: String,
        agentId: String,
        passed: Bool,
        verifyStartMs: Int64,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): Unit {
        if (agentId.isEmpty()) {
            return
        }
        let durationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - verifyStartMs
        let successRate = if (passed) { 1.0 } else { 0.0 }
        LrtPersistService.logMetrics(
            agentId, "session", successRate, durationMs, 0, 0, 0, userId, permArr
        )
    }

    private static func getEnv(name: String): String {
        match (getVariable(name)) {
            case Some(s) => s
            case None => ""
        }
    }
}
