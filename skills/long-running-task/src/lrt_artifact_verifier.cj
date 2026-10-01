/*
 * LrtArtifactVerifier（long-running-task / Ch0.2 / §5.10 / §1.1.3.5）
 * 文件态产物校验器：每步产出后校验文件存在且非空、日期匹配、内容校验。
 *
 * 设计定位（P 层 / L3 插件）：
 *   - design §1.1.3.5 将其列为插件内组件；§5.10 规定「任务完成判定不能因目录有旧文件就误判，
 *     必须检查日期匹配 + 内容为本次生成」。
 *   - 长程任务完成由插件 D-P-H-E 收敛（LrtExecutor 依据 long_running_task_artifact.verification_status）
 *     驱动，而非宿主 AgentExecutionExecutor.isSopCompleted 的魔法字符串；故本类在插件内实现文件态校验，
 *     作为 LrtVerifier 的确定性快检闸门（不依赖 LLM），命中即通过，未命中则交由 D 层 verify_artifact.py 深度验核。
 *
 * 编码依据：src/skill/infrastructure/loaders/skill_md_loader.cj:24-32（File + StringReader + readToEnd 范式）
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.fs.{File, OpenMode, exists}
import std.io.{StringReader, readToEnd, InputStream}
import std.convert.*

public class LrtArtifactVerifier {
    /// 文件态校验：返回 (通过?, 原因)
    /// - artifactPath：产物绝对/相对路径
    /// - expectedDate：预期日期串（如 2026-08-10）；非空时要求**路径或内容**包含该日期，
    ///   忽略旧日期文件（spec 5.10.1 规则 5 的验收条件写的就是「output/brief/2026-08-11.md 不算完成」，
    ///   即按**路径**判日期；但产出正文里写明目标日期的写法同样合法，故二者取「或」）
    /// - contentHint：预期内容线索（如关键数值）；非空时要求文件内容包含该线索
    public static func verifyFileState(
        artifactPath: String,
        expectedDate: String,
        contentHint: String
    ): (Bool, String) {
        if (artifactPath.isEmpty()) {
            return (false, "artifact_path 为空")
        }
        if (!exists(artifactPath)) {
            return (false, "文件不存在: ${artifactPath}")
        }
        // 读取内容（用于非空 + 日期 + 内容校验）
        var content = ""
        try {
            let file = File(artifactPath, OpenMode.Read)
            if (!file.canRead()) {
                return (false, "文件不可读: ${artifactPath}")
            }
            let reader = StringReader(file)
            content = reader.readToEnd()
            reader.close()
            file.close()
        } catch (e: Exception) {
            return (false, "文件读取失败: ${e.message}")
        }
        if (content.size <= 0) {
            return (false, "文件内容为空: ${artifactPath}")
        }
        // 日期匹配（若提供预期日期）：路径或内容命中其一即算匹配，二者都不含则判为旧日期产物。
        // 只说「内容」会把 output/brief/2026-08-10.md 这种「日期在文件名里」的合法产物误杀——
        // 而 spec 5.10.1 规则 5 的验收条件恰恰是文件名口径，故路径优先纳入判定。
        if (!expectedDate.isEmpty() && !artifactPath.contains(expectedDate) && !content.contains(expectedDate)) {
            return (false, "日期不匹配：期望 '${expectedDate}'（路径与内容均未命中），文件可能为旧日期产物")
        }
        // 内容校验（若提供内容线索）：必须包含本次执行数据
        if (!contentHint.isEmpty() && !content.contains(contentHint)) {
            return (false, "内容校验未通过：缺少预期数据 '${contentHint}'")
        }
        return (true, "文件态校验通过")
    }

    /**
     * **answer 前终检**（spec 5.14 / Ch6.1）
     *
     * 生成最终 answer 之前，必须确认清单里的关键产出物**确实都存在**；
     * 缺一个就不能宣称任务完成。返回值把缺什么列清楚，交给调用方决定
     * 是"补跑对应步骤"还是"置 status=6 交人工"——本类只负责判定，不负责补跑
     * （补跑需要执行编排能力，属于 LrtExecutor 的职责）。
     *
     * 为什么清单由调用方给出而不是本类自己扫目录：
     * 只有任务自己知道"哪些产出算关键"，扫目录会把中间产物和临时文件也算进去，
     * 结果是永远检查不完。清单为空时返回 `all_present=true` 并标注 `skipped=true`，
     * 而不是报错——没有声明关键产出的任务不该被终检卡死。
     *
     * @param requiredArtifacts 关键产出物路径清单
     * @param contentHint       内容线索（透传给 verifyFileState 做内容校验）
     */
    public static func finalCheck(
        requiredArtifacts: ArrayList<String>,
        contentHint: String
    ): JsonValue {
        let missing = ArrayList<JsonValue>()
        var checked: Int64 = 0
        for (p in requiredArtifacts) {
            if (p.isEmpty()) {
                continue
            }
            checked = checked + 1
            let (ok, reason) = LrtArtifactVerifier.verifyFileState(p, "", contentHint)
            if (!ok) {
                let item = HashMap<String, JsonValue>()
                item["artifact_path"] = JsonValue.String(p)
                item["reason"] = JsonValue.String(reason)
                missing.add(JsonValue.from(item))
            }
        }
        let skipped = checked == 0
        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["skipped"] = JsonValue.Boolean(skipped)
        response["checked"] = JsonValue.Number(Float64(checked))
        response["missing_count"] = JsonValue.Number(Float64(missing.size))
        response["all_present"] = JsonValue.Boolean(missing.size == 0)
        response["missing"] = JsonValue.from(missing)
        return JsonValue.from(response)
    }

    /**
     * **§6.1 校验失败处理：补执行 → 复验 → 仍失败则触发降级策略链**（tasks.md 743）
     *
     * 三段式：`verify` →（失败）`remediate` → `re-verify` →（补跑耗尽）`degrade`
     *
     * ── 为什么补跑/降级能力用**回调注入**而不是本类直接调 LrtExecutor ──
     * 补跑需要执行编排能力，而 Verifier 是纯判定组件；直接反向依赖会形成
     * Verifier ↔ Executor 的循环依赖。回调形式让「谁能补跑、怎么降级」由调用方
     * 决定，本类只负责「验几次、什么时候该放弃、放弃后交给谁」这三件事。
     * （与 DecisionPointRegistry 经回调注入 web_request_approval 同一套路）
     *
     * ── 为什么补跑次数可控而不是无限重试 ──
     * 长程任务的每一步都可能很贵（一次 LLM 调用或一个子任务）。无限补跑会把
     * 预算烧在同一处失败上，`maxRemediations` 就是把「再试一次」的代价显式化。
     *
     * @param maxRemediations 最多补跑次数；**0 = 不补跑**，校验失败即直接降级
     * @param remediate       补执行回调，入参为上一次的失败原因，返回补跑是否成功
     * @param degrade         降级回调，入参为最终失败原因，返回降级结果（原样透传进返回值）
     */
    public static func verifyWithRemediation(
        artifactPath: String,
        expectedDate: String,
        contentHint: String,
        maxRemediations: Int64,
        remediate: (String) -> Bool,
        degrade: (String) -> JsonValue
    ): JsonValue {
        let attempts = ArrayList<JsonValue>()
        var verifyCount: Int64 = 0
        var remediations: Int64 = 0
        var lastReason = ""
        var passed = false
        var degraded = false
        var degradationResult = JsonValue.Null

        while (true) {
            let (ok, reason) = LrtArtifactVerifier.verifyFileState(artifactPath, expectedDate, contentHint)
            verifyCount = verifyCount + 1
            if (ok) {
                passed = true
                lastReason = reason
                break
            }
            lastReason = reason
            if (remediations >= maxRemediations) {
                // 补跑机会已耗尽 → 交降级链，不在原地继续重试消耗预算
                degraded = true
                degradationResult = degrade(reason)
                break
            }
            remediations = remediations + 1
            let fixed = remediate(reason)
            let flag = if (fixed) { "成功" } else { "未成功" }
            attempts.add(JsonValue.String("第 ${remediations} 次补执行${flag}：${reason}"))
        }

        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["passed"] = JsonValue.Boolean(passed)
        response["reason"] = JsonValue.String(lastReason)
        response["verify_count"] = JsonValue.Number(Float64(verifyCount))
        response["remediations"] = JsonValue.Number(Float64(remediations))
        response["degraded"] = JsonValue.Boolean(degraded)
        response["degradation"] = degradationResult
        response["attempts"] = JsonValue.from(attempts)
        return JsonValue.from(response)
    }

    /**
     * 不带补跑能力的便捷版：等价于「只校验一次，失败即降级」。
     *
     * 存在意义：让不具备补执行能力的调用方（或明确不希望补跑的场景）无需自己拼
     * 一个恒 false 的 remediate 回调。行为与「verifyFileState 失败后直接降级」一致。
     *
     * 注：**刻意不写成 verifyWithRemediation 的重载**——两个版本仅靠第 4 个参数
     * （Int64 vs 函数类型）区分，重载解析容易踩歧义；独立命名零风险。
     */
    public static func verifyThenDegrade(
        artifactPath: String,
        expectedDate: String,
        contentHint: String,
        degrade: (String) -> JsonValue
    ): JsonValue {
        LrtArtifactVerifier.verifyWithRemediation(
            artifactPath, expectedDate, contentHint, 0,
            { reason: String => false }, degrade
        )
    }
}
