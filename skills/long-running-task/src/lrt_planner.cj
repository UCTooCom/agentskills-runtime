/*
 * LrtPlanner（long-running-task / Ch3）
 * AI 自主规划入口：调 D 层 parse_goal.py 抽取结构化目标，回写 agent_tasks.payload。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}

public class LrtPlanner {
    /// 解析目标并持久化到 agent_tasks.payload.plan
    public static func plan(
        goal: String,
        taskId: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (goal.isEmpty()) {
            return LrtPersistService.errResult(40002, "goal 不能为空")
        }
        let args = ArrayList<String>()
        args.add("--goal")
        args.add(goal)
        if (!taskId.isEmpty()) {
            args.add("--task_id")
            args.add(taskId)
        }
        let result = LrtScriptRunner.runScriptJson("parse_goal.py", args)
        match (result) {
            case JsonValue.Null =>
                return LrtPersistService.errResult(50001, "parse_goal.py 执行失败或无 JSON 输出")
            case _ =>
                // parse_goal.py 的输出是**两层结构**：
                //   {"ok":true, "output":"output/parsed/goal.json", "goal":{goal, success_criteria, ...}}
                // 业务内容（success_criteria / constraints / sub_goals）在 `goal` 里。
                // 若把整包写进 payload.goal，下游按「取 goal.success_criteria」读会全部落空。
                let parsed = LrtPlanner.unwrapGoal(result)
                // 任务树分解 + 技能发现 + 能力缺口检测（spec 5.2 / 5.4 / §3.1 / §3.3）
                let enriched = LrtPlanner.enrichPlan(parsed, taskId, userId, permArr)
                if (!taskId.isEmpty()) {
                    let payloadMap = HashMap<String, JsonValue>()
                    payloadMap["goal"] = JsonValue.String(goal)
                    payloadMap["plan"] = enriched
                    payloadMap["planned_via"] = JsonValue.String("lrt-plan")
                    LrtPersistService.patchTaskPayload(taskId, payloadMap, userId, permArr)
                }
                let response = HashMap<String, JsonValue>()
                response["errno"] = JsonValue.Number(0.0)
                response["errmsg"] = JsonValue.String("ok")
                response["goal"] = enriched
                return JsonValue.from(response)
        }
    }

    /**
     * **动态重规划**（spec 5.3 / Ch3.2）
     *
     * 触发源：子任务失败、环境变更、用户 adjust_goal、用户 add_constraint、
     * 评审反馈要求改进。核心约束是**已完成子任务不得重跑**——
     * 已经产出的东西再跑一遍既浪费一轮预算，也可能把好结果覆盖成坏结果。
     *
     * 已完成清单 `payload.completed_subgoals` 是唯一的判定依据：
     * 它由"谁标记完成"的一方（当前是 executor/人工干预）写入，本方法只读不用**猜**。
     * 该键不存在时按"全部未完成"处理，行为退化为"完全重规划"，并在返回值里如实标注。
     *
     * @param reason            重规划原因（goal_adjusted / constraint_added / subtask_failed / review_feedback …）
     * @param newGoal           新目标；为空表示沿用原目标
     * @param addedConstraints  追加约束，逗号分隔；为空表示无追加
     */
    public static func replan(
        taskId: String,
        reason: String,
        newGoal: String,
        addedConstraints: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (taskId.isEmpty()) {
            return LrtPersistService.errResult(40002, "task_id 不能为空")
        }

        let row = LrtPersistService.queryOne(
            LrtPersistService.TABLE_AGENT_TASKS, "id = '${taskId}'", userId, permArr
        )
        let payload = LrtPlanner.payloadOf(row)
        let oldPlan = payload.get("plan", JsonValue.Null)
        let originalGoal = LrtPlanner.firstString(payload, ["goal"], "")

        // 1) 已完成子任务清单（保留语义的核心）
        let completed = LrtPlanner.completedSet(payload)

        // 2) 目标/约束有变 → 重新走一次 D 层解析，拿到新版本的子目标序列
        let effectiveGoal = if (newGoal.isEmpty()) { originalGoal } else { newGoal }
        var regenerated = false
        var basePlan = oldPlan
        if (!newGoal.isEmpty() || !addedConstraints.isEmpty()) {
            let args = ArrayList<String>()
            args.add("--goal")
            args.add(effectiveGoal)
            args.add("--task_id")
            args.add(taskId)
            if (!addedConstraints.isEmpty()) {
                args.add("--constraints")
                args.add(addedConstraints)
            }
            let fresh = LrtScriptRunner.runScriptJson("parse_goal.py", args)
            match (fresh) {
                case JsonValue.Null =>
                    // 解析失败不能把已有规划清掉：沿用旧方案，并在返回值里报出来
                    eprintln("[lrt-planner] replan 重新解析目标失败，沿用既有 plan")
                case _ =>
                    basePlan = LrtPlanner.unwrapGoal(fresh)
                    regenerated = true
            }
        }

        // 3) 给子目标打 status：已完成的保留 completed，其余为 pending
        let revisedPlan = LrtPlanner.markStatus(basePlan, completed)
        let withConstraints = LrtPlanner.appendConstraints(revisedPlan, addedConstraints)

        // 4) 回写 payload：新 plan + 重规划留痕（§11.3 的 decision 类日志在数据层的对应物）
        let patch = HashMap<String, JsonValue>()
        patch["plan"] = withConstraints
        patch["planned_via"] = JsonValue.String("lrt-replan")
        if (!newGoal.isEmpty()) {
            patch["goal"] = JsonValue.String(newGoal)
        }
        let history = LrtPlanner.replanHistory(payload)
        let entry = HashMap<String, JsonValue>()
        entry["reason"] = JsonValue.String(if (reason.isEmpty()) { "unspecified" } else { reason })
        entry["regenerated"] = JsonValue.Boolean(regenerated)
        entry["preserved_count"] = JsonValue.Number(Float64(completed.size))
        history.add(JsonValue.from(entry))
        patch["replan_history"] = JsonValue.from(history)
        LrtPersistService.patchTaskPayload(taskId, patch, userId, permArr)

        let pending = LrtPlanner.countPending(withConstraints)
        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["task_id"] = JsonValue.String(taskId)
        response["reason"] = JsonValue.String(reason)
        response["regenerated"] = JsonValue.Boolean(regenerated)
        response["preserved_count"] = JsonValue.Number(Float64(completed.size))
        response["pending_count"] = JsonValue.Number(Float64(pending))
        response["plan"] = withConstraints
        return JsonValue.from(response)
    }

    /**
     * 取出 parse_goal.py 输出里承载业务字段的那一层。
     *
     * 优先内层 `goal` 对象（脚本当前的包装结构）；该键缺失或不是对象时原样返回，
     * 以便脚本改成「直接输出业务字段」后本方法无需再改。
     */
    private static func unwrapGoal(result: JsonValue): JsonValue {
        let inner = result.get("goal", JsonValue.Null)
        match (inner) {
            case JsonValue.Map(_) => return inner
            case _ => return result
        }
    }

    // ── replan 辅助 ─────────────────────────────────────────────────

    /**
     * 取任务行的 payload。
     *
     * `payload` 在 host.db 的返回里可能是**对象**也可能是 **JSON 文本**，
     * 取决于驱动序列化方式。两种都认——至少要做到不会因为驱动差异让
     * "已完成子任务"读成空，那会导致每次重规划都把做过的事重做一遍。
     */
    private static func payloadOf(row: JsonValue): JsonValue {
        let raw = match (row) {
            case JsonValue.Map(fields) =>
                match (fields.get("payload")) {
                    case Some(v) => v
                    case None => JsonValue.Null
                }
            case _ => JsonValue.Null
        }
        match (raw) {
            case JsonValue.Map(_) => return raw
            case JsonValue.String(s) =>
                try {
                    return JsonValue.parse(s)
                } catch (e: Exception) {
                    return JsonValue.Null
                }
            case _ => return JsonValue.Null
        }
    }

    /// payload 里第一条非空字符串（按 key 顺序）
    private static func firstString(payload: JsonValue, keys: Array<String>, fallback: String): String {
        for (k in keys) {
            match (payload.get(k, JsonValue.Null)) {
                case JsonValue.String(s) =>
                    if (!s.isEmpty()) {
                        return s
                    }
                case _ => ()
            }
        }
        return fallback
    }

    /// 已完成子任务名集合
    private static func completedSet(payload: JsonValue): ArrayList<String> {
        let result = ArrayList<String>()
        match (payload.get("completed_subgoals", JsonValue.Null)) {
            case JsonValue.Array(items) =>
                for (it in items) {
                    match (it) {
                        case JsonValue.String(s) =>
                            if (!s.isEmpty()) {
                                result.add(s)
                            }
                        case _ => ()
                    }
                }
            case _ => ()
        }
        return result
    }

    /**
     * 给 plan 的 sub_goals 逐条标 status。
     * 元素是字符串时直接比对文本；是对象时比对 name/title 字段。
     * 标不出 status 的（空列表/结构不明）也不报错——契约由消费方负责，
     * 这里只保证"能标的都标了"。
     */
    private static func markStatus(plan: JsonValue, completed: ArrayList<String>): JsonValue {
        match (plan) {
            case JsonValue.Map(p) =>
                let copy = HashMap<String, JsonValue>()
                for (k in p.keys()) {
                    match (p.get(k)) {
                        case Some(v) => copy[k] = v
                        case None => ()
                    }
                }
                match (p.get("sub_goals")) {
                    case Some(JsonValue.Array(items)) =>
                        let marked = ArrayList<JsonValue>()
                        for (it in items) {
                            marked.add(LrtPlanner.markOne(it, completed))
                        }
                        copy["sub_goals"] = JsonValue.from(marked)
                    case _ => ()
                }
                return JsonValue.from(copy)
            case _ => return plan
        }
    }

    private static func markOne(item: JsonValue, completed: ArrayList<String>): JsonValue {
        match (item) {
            case JsonValue.String(s) =>
                let map = HashMap<String, JsonValue>()
                map["name"] = JsonValue.String(s)
                map["status"] = JsonValue.String(if (LrtPlanner.isCompleted(s, completed)) { "completed" } else { "pending" })
                return JsonValue.from(map)
            case JsonValue.Map(m) =>
                let copy = HashMap<String, JsonValue>()
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(v) => copy[k] = v
                        case None => ()
                    }
                }
                let name = LrtPlanner.pickName(m)
                if (name.isEmpty()) {
                    // 识别不出名称就无法判定完成与否；已有显式 status 时尊重原值
                    if (!copy.contains("status")) {
                        copy["status"] = JsonValue.String("pending")
                    }
                } else {
                    copy["status"] = JsonValue.String(if (LrtPlanner.isCompleted(name, completed)) { "completed" } else { "pending" })
                }
                return JsonValue.from(copy)
            case _ => return item
        }
    }

    private static func pickName(m: HashMap<String, JsonValue>): String {
        for (k in ["name", "title", "sub_goal"]) {
            match (m.get(k)) {
                case Some(JsonValue.String(s)) =>
                    if (!s.isEmpty()) {
                        return s
                    }
                case _ => ()
            }
        }
        return ""
    }

    private static func isCompleted(name: String, completed: ArrayList<String>): Bool {
        for (c in completed) {
            if (c == name) {
                return true
            }
        }
        return false
    }

    /// 追加约束（逗号分隔）到 plan.constraints，已有的不重复
    private static func appendConstraints(plan: JsonValue, addedConstraints: String): JsonValue {
        if (addedConstraints.isEmpty()) {
            return plan
        }
        let items = addedConstraints.split(",")
        if (items.size == 0) {
            return plan
        }
        match (plan) {
            case JsonValue.Map(p) =>
                let merged = ArrayList<JsonValue>()
                match (p.get("constraints")) {
                    case Some(JsonValue.Array(existing)) =>
                        for (e in existing) {
                            merged.add(e)
                        }
                    case _ => ()
                }
                let existingTexts = ArrayList<String>()
                for (m in merged) {
                    match (m) {
                        case JsonValue.String(s) => existingTexts.add(s)
                        case _ => ()
                    }
                }
                for (it in items) {
                    let v = it.trimAscii()
                    if (v.isEmpty()) {
                        continue
                    }
                    var dup = false
                    for (t in existingTexts) {
                        if (t == v) {
                            dup = true
                        }
                    }
                    if (!dup) {
                        merged.add(JsonValue.String(v))
                    }
                }
                let copy = HashMap<String, JsonValue>()
                for (k in p.keys()) {
                    match (p.get(k)) {
                        case Some(vv) => copy[k] = vv
                        case None => ()
                    }
                }
                copy["constraints"] = JsonValue.from(merged)
                return JsonValue.from(copy)
            case _ => return plan
        }
    }

    private static func replanHistory(payload: JsonValue): ArrayList<JsonValue> {
        match (payload.get("replan_history", JsonValue.Null)) {
            case JsonValue.Array(items) => return items
            case _ => return ArrayList<JsonValue>()
        }
    }

    private static func countPending(plan: JsonValue): Int64 {
        var n: Int64 = 0
        match (plan.get("sub_goals", JsonValue.Null)) {
            case JsonValue.Array(items) =>
                for (it in items) {
                    match (it) {
                        case JsonValue.Map(m) =>
                            match (m.get("status")) {
                                case Some(JsonValue.String(s)) =>
                                    if (s != "completed") {
                                        n = n + 1
                                    }
                                case _ => n = n + 1
                            }
                        case _ => n = n + 1
                    }
                }
            case _ => ()
        }
        return n
    }

    // ── 任务树分解 + 技能发现 + 能力缺口检测（§3.1 / §3.3）────────────

    /**
     * 把 parse_goal.py 的结构化目标 enriched 成可执行的规划：
     *   - 任务树（task_tree / sub_tasks）：将 sub_goals 展开为带 parent_task_id 层级结构的子任务，
     *     并（在 taskId 已知时）经 LrtPersistService.createChildTask 真实写入 agent_tasks
     *   - skill_available：经 host.db 读取已安装技能清单（agent_skills.name）
     *   - skill_sequence：每个子任务按关键词匹配到的已装技能序列
     *   - skill_gaps：无匹配已装技能的子任务（需 skill-creator / cangjie-coder 动态补齐）
     *
     * 设计纪律：**发现与执行分离**。本方法只做分解与"应该用什么技能"的判定，
     * 真正的技能创建/代码生成由 D 层 extend_capability.py 在 COMPOSITION 的
     * extend-capability 步骤落地（避免插件进程越权拉起子进程）。
     */
    private static func enrichPlan(
        parsed: JsonValue,
        taskId: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        let base = LrtPlanner.toMutableMap(parsed)

        // 1) 技能发现：经 host.db 读取已安装技能清单（agent_skills.name）
        let skillAvailable = LrtPlanner.discoverSkills(userId, permArr)
        let availJson = ArrayList<JsonValue>()
        for (s in skillAvailable) {
            availJson.add(JsonValue.String(s))
        }
        base["skill_available"] = JsonValue.from(availJson)

        // 2) 任务树分解：sub_goals → 带 parent_task_id / task_id / status 的子任务树
        let subGoals = LrtPlanner.subGoalList(parsed)
        let tree = ArrayList<JsonValue>()
        var order: Int64 = 0
        for (sg in subGoals) {
            order = order + 1
            var childId = ""
            if (!taskId.isEmpty()) {
                let created = LrtPersistService.createChildTask(taskId, sg, order, userId, permArr)
                childId = LrtPlanner.extractId(created)
            }
            let node = HashMap<String, JsonValue>()
            node["name"] = JsonValue.String(sg)
            node["order"] = JsonValue.Number(Float64(order))
            node["parent_task_id"] = if (taskId.isEmpty()) { JsonValue.Null } else { JsonValue.String(taskId) }
            node["task_id"] = if (childId.isEmpty()) { JsonValue.Null } else { JsonValue.String(childId) }
            node["status"] = JsonValue.String("pending")
            // 技能选择：按关键词匹配已安装技能（best-effort 启发式）
            let skills = LrtPlanner.resolveSkillFor(sg, skillAvailable)
            node["skills"] = JsonValue.from(skills)
            node["acceptance_criteria"] = JsonValue.String("完成「${sg}」并产出可见、可校验的结果")
            tree.add(JsonValue.from(node))
        }
        if (tree.size > 0) {
            base["sub_tasks"] = JsonValue.from(tree)
            base["task_tree"] = JsonValue.from(tree)
        }

        // 3) 技能序列：按子任务顺序汇总所需技能，并标记能力缺口
        let skillSeq = ArrayList<JsonValue>()
        for (node in tree) {
            match (node) {
                case JsonValue.Map(m) =>
                    let name = LrtPlanner.firstStringOf(node, ["name"], "")
                    var skills = ArrayList<JsonValue>()
                    match (m.get("skills")) {
                        case Some(JsonValue.Array(s)) => skills = s
                        case _ => ()
                    }
                    let entry = HashMap<String, JsonValue>()
                    entry["sub_goal"] = JsonValue.String(name)
                    entry["skills"] = JsonValue.from(skills)
                    if (skills.size == 0) {
                        entry["gap"] = JsonValue.Boolean(true)
                    }
                    skillSeq.add(JsonValue.from(entry))
                case _ => ()
            }
        }
        base["skill_sequence"] = JsonValue.from(skillSeq)

        // 4) 能力缺口：列出无匹配已装技能的子任务（需动态补齐技能）
        let gaps = ArrayList<JsonValue>()
        for (entry in skillSeq) {
            match (entry) {
                case JsonValue.Map(m) =>
                    match (m.get("gap")) {
                        case Some(JsonValue.Boolean(true)) =>
                            match (m.get("sub_goal")) {
                                case Some(JsonValue.String(s)) =>
                                    let g = HashMap<String, JsonValue>()
                                    g["sub_goal"] = JsonValue.String(s)
                                    g["suggested_action"] = JsonValue.String(
                                        "invoke skill-creator or cangjie-coder to build a new skill")
                                    gaps.add(JsonValue.from(g))
                                case _ => ()
                            }
                        case _ => ()
                    }
                case _ => ()
            }
        }
        base["skill_gaps"] = JsonValue.from(gaps)

        // 5) 质量闸门编排（spec 5.7 / §3.3）：为每个能力缺口强制追加
        //    code-gen → verify → fix_if_fail 三段子任务，形成质量闸门闭环。
        //    D 层 extend_capability.py 读取此结构并执行：
        //      - code_gen_subtask: 调 skill-creator / cangjie-coder 生成技能或代码
        //      - verify_subtask:   调 code-gen-verifier 验证产出质量
        //      - fix_subtask:      验证失败时调 cangjie-coder 修复，再验证
        //    插件进程不越权拉子进程（§3.3 纪律），只编排结构交 D 层执行。
        let qualityGates = ArrayList<JsonValue>()
        for (gap in gaps) {
            match (gap) {
                case JsonValue.Map(gm) =>
                    let subGoal = match (gm.get("sub_goal")) {
                        case Some(JsonValue.String(s)) => s
                        case _ => ""
                    }
                    if (subGoal.isEmpty()) {
                        continue
                    }
                    let gate = HashMap<String, JsonValue>()
                    gate["sub_goal"] = JsonValue.String(subGoal)

                    let codeGen = HashMap<String, JsonValue>()
                    codeGen["name"] = JsonValue.String("为「${subGoal}」创建技能或编写代码")
                    codeGen["skill"] = JsonValue.String("skill-creator")
                    codeGen["fallback_skill"] = JsonValue.String("cangjie-coder")
                    gate["code_gen_subtask"] = JsonValue.from(codeGen)

                    let verify = HashMap<String, JsonValue>()
                    verify["name"] = JsonValue.String("验证「${subGoal}」产出通过质量闸门")
                    verify["skill"] = JsonValue.String("code-gen-verifier")
                    verify["checks"] = JsonValue.from([
                        JsonValue.String("语法正确"),
                        JsonValue.String("编译通过"),
                        JsonValue.String("单测通过")
                    ])
                    gate["verify_subtask"] = JsonValue.from(verify)

                    let fix = HashMap<String, JsonValue>()
                    fix["name"] = JsonValue.String("修复「${subGoal}」的验证失败项")
                    fix["skill"] = JsonValue.String("cangjie-coder")
                    fix["condition"] = JsonValue.String("verify_subtask.failed")
                    gate["fix_subtask"] = JsonValue.from(fix)

                    qualityGates.add(JsonValue.from(gate))
                case _ => ()
            }
        }
        if (qualityGates.size > 0) {
            base["quality_gates"] = JsonValue.from(qualityGates)
        }

        return JsonValue.from(base)
    }

    /// 经 host.db 读取已安装技能清单（agent_skills 表的 name 列）
    private static func discoverSkills(userId: String, permArr: ArrayList<JsonValue>): ArrayList<String> {
        let rows = LrtPersistService.queryMany("agent_skills", "deleted_at IS NULL", userId, permArr, 200)
        let skills = ArrayList<String>()
        for (row in rows) {
            match (row) {
                case JsonValue.Map(m) =>
                    match (m.get("name")) {
                        case Some(JsonValue.String(s)) =>
                            if (!s.isEmpty()) {
                                var seen = false
                                for (ex in skills) {
                                    if (ex == s) {
                                        seen = true
                                    }
                                }
                                if (!seen) {
                                    skills.add(s)
                                }
                            }
                        case _ => ()
                    }
                case _ => ()
            }
        }
        return skills
    }

    /// 按关键词启发式把子目标匹配到已安装技能；匹配不到则留空（视为能力缺口）
    private static func resolveSkillFor(subGoal: String, available: ArrayList<String>): ArrayList<JsonValue> {
        let out = ArrayList<JsonValue>()
        for (s in available) {
            if (s.isEmpty()) {
                continue
            }
            if (subGoal.contains(s)) {
                out.add(JsonValue.String(s))
                continue
            }
            let key = LrtPlanner.intentKeyword(s)
            if (!key.isEmpty() && subGoal.contains(key)) {
                out.add(JsonValue.String(s))
            }
        }
        // 去重（按字符串值）
        let dedup = ArrayList<JsonValue>()
        for (v in out) {
            let sv = match (v) {
                case JsonValue.String(x) => x
                case _ => ""
            }
            var seen = false
            for (d in dedup) {
                match (d) {
                    case JsonValue.String(dx) => if (dx == sv) { seen = true }
                    case _ => ()
                }
            }
            if (!seen && !sv.isEmpty()) {
                dedup.add(v)
            }
        }
        return dedup
    }

    /// 技能意图关键词别名（best-effort 启发式）
    private static func intentKeyword(skill: String): String {
        if (skill.contains("cangjie") || skill.contains("coder")) {
            return "代码"
        }
        if (skill.contains("crud")) {
            return "表"
        }
        if (skill.contains("skill-creator") || skill.contains("skill_creator")) {
            return "技能"
        }
        return ""
    }

    /// 从 parse_goal 的输出里取出 sub_goals 列表（字符串或已标注对象都兼容）
    private static func subGoalList(parsed: JsonValue): ArrayList<String> {
        let out = ArrayList<String>()
        match (parsed) {
            case JsonValue.Map(m) =>
                match (m.get("sub_goals")) {
                    case Some(JsonValue.Array(items)) =>
                        for (it in items) {
                            match (it) {
                                case JsonValue.String(s) =>
                                    if (!s.isEmpty()) {
                                        out.add(s)
                                    }
                                case JsonValue.Map(_) =>
                                    let n = LrtPlanner.firstStringOf(it, ["name", "title", "sub_goal"], "")
                                    if (!n.isEmpty()) {
                                        out.add(n)
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return out
    }

    /// 把 JsonValue.Map 转成可写的 HashMap
    private static func toMutableMap(v: JsonValue): HashMap<String, JsonValue> {
        let m = HashMap<String, JsonValue>()
        match (v) {
            case JsonValue.Map(fields) =>
                for (k in fields.keys()) {
                    match (fields.get(k)) {
                        case Some(val) => m[k] = val
                        case _ => ()
                    }
                }
            case _ => ()
        }
        return m
    }

    /// 从 insert 结果（{ "rows": [{ "id": ... }] }）提取新记录 id
    private static func extractId(created: JsonValue): String {
        match (created) {
            case JsonValue.Map(m) =>
                match (m.get("rows")) {
                    case Some(JsonValue.Array(rows)) =>
                        if (rows.size > 0) {
                            match (rows[0]) {
                                case JsonValue.Map(r) =>
                                    match (r.get("id")) {
                                        case Some(JsonValue.String(s)) => return s
                                        case _ => ()
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return ""
    }

    /// 从 JsonValue 按 key 顺序取第一条非空字符串
    private static func firstStringOf(v: JsonValue, keys: Array<String>, fallback: String): String {
        for (k in keys) {
            match (v) {
                case JsonValue.Map(m) =>
                    match (m.get(k)) {
                        case Some(JsonValue.String(s)) =>
                            if (!s.isEmpty()) {
                                return s
                            }
                        case _ => ()
                    }
                case _ => ()
            }
        }
        return fallback
    }
}
