/*
 * LrtAntiRegressionRegistry（long-running-task / Ch7.2）
 * 防回退注册表：把"错误行为示例（严禁复现）+ 正确行为示例"结构化固化，
 * 并在自进化环节 5 把防回退约束注入 SKILL.md 的显式约束区。
 *
 * ── 为什么是文件态而不是新增第三张表 ────────────────────────────────────
 * design §2.8.4 已把新增表收敛到 2 张（artifact / evolution），
 * 且 §1 的 DDL 已人工执行通过。注册表是**技能自带的知识资产**，
 * 随技能版本的发布而演进，语义上属于技能包的一部分而不是业务运行数据——
 * 它和 SKILL.md 同源，理应与 SKILL.md 一样落在技能目录里。
 * 因此：<skillRoot>/anti_regression/REGISTRY.json。
 * 落库那一层由 LrtSelfEvolution 负责（anti_regression 文本写 evolution 表留痕），
 * 本类只管"注册表 + 约束注入"这两件事，职责不交叉。
 *
 * ── SKILL.md 注入为什么要用标记块 + 幂等替换 ────────────────────────────
 * 直接追加会在每次自进化后无限增长；直接整体重写会抹掉人工编辑的内容。
 * 因此约定 SKILL.md 中存在一对标记：
 *   <!-- BEGIN: AUTO-CONSTRAINTS --> … <!-- END: AUTO-CONSTRAINTS -->
 * 只有标记之间的内容由本类托管。缺失任一端标记时**报错而不是猜**，
 * 因为把约束插到错误位置比不插更糟——模型会读到一段上下文不明的约束。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.fs.{File, Path, Directory, OpenMode, exists}
import std.io.StringReader

public class LrtAntiRegressionRegistry {
    public static let BEGIN_MARKER: String = "<!-- BEGIN: AUTO-CONSTRAINTS -->"
    public static let END_MARKER: String = "<!-- END: AUTO-CONSTRAINTS -->"

    /// 注册表文件相对技能根的位置
    public static let REGISTRY_REL: String = "anti_regression/REGISTRY.json"

    /**
     * 登记一条防回退条目。
     *
     * 幂等键取 (issueCode, errorBehavior)：同一个问题在同一份错误行为下
     * 重复登记没有信息量，只会让约束区变长到没人愿意读。
     * 命中已有条目时**覆盖**轮次/级别/修复版本（问题再次出现说明上次的修复没生效，
     * 最新的一轮才是有效信息），而不是追加一行。
     */
    public static func register(
        agentId: String,
        round: Int64,
        issueCode: String,
        level: String,
        errorBehavior: String,
        correctBehavior: String,
        fixVersion: String
    ): JsonValue {
        let root = LrtScriptRunner.skillRoot()
        if (root.isEmpty()) {
            return LrtPersistService.errResult(50002,
                "无法确定技能根目录：请设置环境变量 LRT_SKILL_ROOT 指向技能根目录")
        }
        let registry = LrtAntiRegressionRegistry.readRegistry()
        let entries = LrtAntiRegressionRegistry.entriesOf(registry)

        let entry = HashMap<String, JsonValue>()
        entry["issue_id"] = JsonValue.String("AR-${round}-${LrtAntiRegressionRegistry.nextSeq(entries)}")
        entry["agent_id"] = JsonValue.String(agentId)
        entry["round"] = JsonValue.Number(Float64(round))
        entry["issue_code"] = JsonValue.String(issueCode)
        entry["level"] = JsonValue.String(level)
        entry["error_behavior"] = JsonValue.String(errorBehavior)
        entry["correct_behavior"] = JsonValue.String(correctBehavior)
        entry["fix_version"] = JsonValue.String(fixVersion)

        // 幂等覆盖
        var replaced = false
        var idx: Int64 = 0
        while (idx < entries.size) {
            let old = entries[idx]
            if (LrtAntiRegressionRegistry.strOf(old, "issue_code") == issueCode &&
                LrtAntiRegressionRegistry.strOf(old, "error_behavior") == errorBehavior) {
                entries[idx] = JsonValue.from(entry)
                replaced = true
            }
            idx = idx + 1
        }
        if (!replaced) {
            entries.add(JsonValue.from(entry))
        }

        let saveResult = LrtAntiRegressionRegistry.writeRegistry(root, entries)
        match (saveResult) {
            case JsonValue.Map(f) =>
                match (f.get("errno")) {
                    case Some(JsonValue.Number(n)) =>
                        if (Int64(n) != 0) {
                            return saveResult
                        }
                    case _ => ()
                }
            case _ => ()
        }

        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["entry"] = JsonValue.from(entry)
        response["total"] = JsonValue.Number(Float64(entries.size))
        response["replaced"] = JsonValue.Boolean(replaced)
        response["registry"] = JsonValue.String(LrtAntiRegressionRegistry.registryPath(root))
        return JsonValue.from(response)
    }

    /// 列出最近登记的条目（按登记顺序，取最后 limit 条）
    public static func list(limit: Int64): JsonValue {
        let entries = LrtAntiRegressionRegistry.entriesOf(LrtAntiRegressionRegistry.readRegistry())
        let picked = ArrayList<JsonValue>()
        let start = if (entries.size > limit) { entries.size - limit } else { 0 }
        var i = start
        while (i < entries.size) {
            picked.add(entries[i])
            i = i + 1
        }
        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["total"] = JsonValue.Number(Float64(entries.size))
        response["entries"] = JsonValue.from(picked)
        return JsonValue.from(response)
    }

    /**
     * 把注册表渲染成 SKILL.md 显式约束区的 Markdown 片段。
     *
     * 按严重度排序输出（P0 在前）：模型读 SKILL.md 时注意力是衰减的，
     * 把最不该犯的错误放在最前面，比按登记顺序排队有用得多。
     */
    public static func renderConstraintsMarkdown(): String {
        let entries = LrtAntiRegressionRegistry.entriesOf(LrtAntiRegressionRegistry.readRegistry())
        if (entries.size == 0) {
            return "<!-- 暂无已登记的防回退约束 -->"
        }
        let levels = ArrayList<String>()
        levels.add("P0")
        levels.add("P1")
        levels.add("P2")
        levels.add("P3")

        let sb = StringBuilder()
        for (level in levels) {
            for (e in entries) {
                if (LrtAntiRegressionRegistry.strOf(e, "level") != level) {
                    continue
                }
                let sb2 = StringBuilder()
                sb2.append("- **[${LrtAntiRegressionRegistry.strOf(e, "level")}] ${LrtAntiRegressionRegistry.strOf(e, "issue_code")}**（登记于 round ${LrtAntiRegressionRegistry.strOf(e, "round")}）\n")
                sb2.append("  - 错误行为（严禁复现）：${LrtAntiRegressionRegistry.strOf(e, "error_behavior")}\n")
                sb2.append("  - 正确行为：${LrtAntiRegressionRegistry.strOf(e, "correct_behavior")}\n")
                sb.append(sb2.toString())
            }
        }
        return sb.toString()
    }

    /**
     * 环节 5：把约束注入 SKILL.md 的标记块。返回被替换的字节数等信息。
     *
     * 幂等：同一份 Markdown 重复注入不会产生重复内容（标记块内的内容整体替换）。
     * 标记缺失时返回 50003 并**不改动文件**——写坏 SKILL.md 会让技能整体不可用。
     */
    public static func injectIntoS(): JsonValue {
        let root = LrtScriptRunner.skillRoot()
        if (root.isEmpty()) {
            return LrtPersistService.errResult(50002,
                "无法确定技能根目录：请设置环境变量 LRT_SKILL_ROOT 指向技能根目录")
        }
        let skillMd = "${root}/SKILL.md"
        if (!exists(skillMd)) {
            return LrtPersistService.errResult(50003, "SKILL.md 不存在: ${skillMd}")
        }
        let content = LrtAntiRegressionRegistry.readText(skillMd)
        if (content.isEmpty()) {
            return LrtPersistService.errResult(50003, "SKILL.md 读取为空: ${skillMd}")
        }
        let beginIdx = content.indexOf(LrtAntiRegressionRegistry.BEGIN_MARKER)
        let endIdx = content.indexOf(LrtAntiRegressionRegistry.END_MARKER)
        match (beginIdx) {
            case Some(b) =>
                match (endIdx) {
                    case Some(e) =>
                        if (e < b) {
                            return LrtPersistService.errResult(50003,
                                "SKILL.md 的结束标记出现在开始标记之前，未改动文件")
                        }
                        let head = content[0..b + LrtAntiRegressionRegistry.BEGIN_MARKER.size]
                        let tail = content[e..content.size]
                        let block = "\n" + LrtAntiRegressionRegistry.renderConstraintsMarkdown() + "\n"
                        let next = head + block + tail
                        LrtAntiRegressionRegistry.writeText(skillMd, next)
                        let response = HashMap<String, JsonValue>()
                        response["errno"] = JsonValue.Number(0.0)
                        response["errmsg"] = JsonValue.String("ok")
                        response["skill_md"] = JsonValue.String(skillMd)
                        response["size_before"] = JsonValue.Number(Float64(content.size))
                        response["size_after"] = JsonValue.Number(Float64(next.size))
                        return JsonValue.from(response)
                    case None =>
                        return LrtPersistService.errResult(50003,
                            "SKILL.md 缺少结束标记 ${LrtAntiRegressionRegistry.END_MARKER}，未改动文件")
                }
            case None =>
                return LrtPersistService.errResult(50003,
                    "SKILL.md 缺少开始标记 ${LrtAntiRegressionRegistry.BEGIN_MARKER}，未改动文件")
        }
    }

    /// 注册表绝对路径（供日志/排障）
    public static func registryPath(root: String): String {
        "${root}/${LrtAntiRegressionRegistry.REGISTRY_REL}"
    }

    // ── 内部 ────────────────────────────────────────────────────────

    private static func nextSeq(entries: ArrayList<JsonValue>): Int64 {
        Int64(entries.size) + 1
    }

    private static func readRegistry(): JsonValue {
        let root = LrtScriptRunner.skillRoot()
        if (root.isEmpty()) {
            return LrtAntiRegressionRegistry.emptyRegistry()
        }
        let path = LrtAntiRegressionRegistry.registryPath(root)
        if (!exists(path)) {
            return LrtAntiRegressionRegistry.emptyRegistry()
        }
        let text = LrtAntiRegressionRegistry.readText(path)
        if (text.isEmpty()) {
            return LrtAntiRegressionRegistry.emptyRegistry()
        }
        try {
            return JsonValue.parse(text)
        } catch (e: Exception) {
            eprintln("[lrt-antiregression] REGISTRY.json 解析失败（按空注册表处理）: ${e.message}")
            return LrtAntiRegressionRegistry.emptyRegistry()
        }
    }

    private static func emptyRegistry(): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["version"] = JsonValue.Number(1.0)
        m["entries"] = JsonValue.from(ArrayList<JsonValue>())
        return JsonValue.from(m)
    }

    private static func entriesOf(registry: JsonValue): ArrayList<JsonValue> {
        match (registry.get("entries", JsonValue.Null)) {
            case JsonValue.Array(items) => return items
            case _ => return ArrayList<JsonValue>()
        }
    }

    private static func writeRegistry(root: String, entries: ArrayList<JsonValue>): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["version"] = JsonValue.Number(1.0)
        m["entries"] = JsonValue.from(entries)
        let path = LrtAntiRegressionRegistry.registryPath(root)
        try {
            let parent = Path(path).parent
            try {
                Directory.create(parent.toString(), recursive: true)
            } catch (e: Exception) {
                // 目录已存在属正常情况，忽略
            }
            File.writeTo(path, JsonValue.from(m).stringify().toArray())
            return JsonValue.Null
        } catch (e: Exception) {
            return LrtPersistService.errResult(50004, "写入 ${path} 失败: ${e.message}")
        }
    }

    private static func readText(path: String): String {
        try {
            let file = File(path, OpenMode.Read)
            let reader = StringReader(file)
            let content = reader.readToEnd()
            file.close()
            return content
        } catch (e: Exception) {
            eprintln("[lrt-antiregression] 读取失败 ${path}: ${e.message}")
            return ""
        }
    }

    private static func writeText(path: String, content: String): Unit {
        try {
            File.writeTo(path, content.toArray())
        } catch (e: Exception) {
            eprintln("[lrt-antiregression] 写入失败 ${path}: ${e.message}")
        }
    }

    private static func strOf(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => return s
            case _ => return ""
        }
    }

    /// 数值字段按整数渲染（round 存的是 Float64，直接插值会得到 "1.0"）
    private static func intStrOf(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.Number(n) => return Int64(n).toString()
            case _ => return "0"
        }
    }
}
