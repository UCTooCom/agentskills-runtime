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
}
