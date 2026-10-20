/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.Skill
import magic.log.LogUtils
import std.collection.{ArrayList, HashMap, HashSet}

/**
 * 互斥技能过滤器（阶段5）。
 *
 * 依据技能 metadata 的 `conflicts_with` 构建互斥关系图，按以下规则裁决：
 * 1. 优先级高者存活（SkillPriority.compare > 0 表示前者优先级更高）；
 * 2. 优先级相同时，loadOrder 中靠前者存活（先到先得）；
 * 3. 双向声明不一致时记录告警，仍按声明的方向处理；
 * 4. 声明冲突但目标技能不在候选集内时跳过并告警。
 *
 * 注意：本过滤器为单次裁决，不做级联淘汰（与 design.md 阶段5 一致）。
 */
public class ConflictFilter {
    public init() {}

    public func filter(skills: Array<Skill>, loadOrder: Array<String>): ConflictFilterResult {
        let result = ConflictFilterResult()

        let priorityOf = HashMap<String, SkillPriority>()
        let conflictMap = HashMap<String, ArrayList<String>>()
        let orderIndex = HashMap<String, Int64>()
        var idx: Int64 = 0
        for (skill in skills) {
            priorityOf.add(skill.name, SkillParallelDeclarationParser.parsePriority(skill.metadata))
            conflictMap.add(skill.name, SkillParallelDeclarationParser.parseConflictsWith(skill.metadata))
            orderIndex.add(skill.name, idx)
            idx = idx + 1
        }

        let evicted = HashSet<String>()
        let processed = HashSet<String>()

        for ((a, bList) in conflictMap) {
            for (b in bList) {
                // 仅处理实际存在于候选集中的技能
                if (!priorityOf.contains(b)) {
                    LogUtils.warn("ConflictFilter: skill '${a}' conflicts_with '${b}' but '${b}' is not in the candidate set, skipped")
                    continue
                }

                let keyAB = "${a}|${b}"
                let keyBA = "${b}|${a}"
                if (processed.contains(keyAB) || processed.contains(keyBA)) {
                    continue
                }
                processed.add(keyAB)
                processed.add(keyBA)
                result.conflictPairs.add((a, b))

                // 双向声明一致性检查
                let bConflicts = conflictMap.get(b)
                let symmetric = if (bConflicts.isSome()) {
                    bConflicts.getOrThrow().contains(a)
                } else {
                    false
                }
                if (!symmetric) {
                    LogUtils.warn("ConflictFilter: one-sided conflict: '${a}' declares conflict with '${b}' but '${b}' does not declare '${a}'")
                }

                // 裁决胜者：优先级高者存活；同级按 loadOrder 先到先得
                let pa = priorityOf.get(a).getOrThrow()
                let pb = priorityOf.get(b).getOrThrow()
                let loser: String
                let cmp = pa.compare(pb)
                if (cmp > 0) {
                    loser = b
                } else if (cmp < 0) {
                    loser = a
                } else {
                    let ia = orderIndex.get(a).getOrThrow()
                    let ib = orderIndex.get(b).getOrThrow()
                    loser = if (ia <= ib) { b } else { a }
                }

                if (!evicted.contains(loser)) {
                    evicted.add(loser)
                    result.evicted.add(loser)
                }
            }
        }

        for (skill in skills) {
            if (!evicted.contains(skill.name)) {
                result.survived.add(skill.name)
            }
        }

        return result
    }
}
