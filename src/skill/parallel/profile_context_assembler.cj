/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.Skill
import magic.log.LogUtils
import std.collection.ArrayList

/**
 * TG26/T102：profile 技能组装器。
 *
 * 多 profile 技能（人格/身份/记忆类，`skill_type: profile`）被组装为**单一**
 * `<profile_context>` 块，与 capability 技能（`skill_content` 块）隔离，
 * 从而让 profile 层拥有独立预算，不挤占 capability 注入预算（T103）。
 *
 * 预算启发式：以「字符数 / 4」近似 token 数；当 `budgetTokens > 0` 且累计估算
 * 超出时，低优先级追加的 profile 被丢弃并告警（降级而非静默覆盖）。
 */
public class ProfileContextAssembler {

    public init() {}

    public func assemble(profiles: Array<Skill>, budgetTokens!: Int64 = 0): String {
        if (profiles.size == 0) {
            return ""
        }

        let kept = ArrayList<Skill>()
        if (budgetTokens > 0) {
            var estimatedTokens: Int64 = 0
            for (p in profiles) {
                let est = _estimateTokens(p)
                if (estimatedTokens + est > budgetTokens) {
                    LogUtils.warn("ProfileContextAssembler: profile '${p.name}' dropped: exceeds budget ${budgetTokens} tokens")
                    break
                }
                kept.add(p)
                estimatedTokens += est
            }
        } else {
            for (p in profiles) {
                kept.add(p)
            }
        }

        if (kept.size == 0) {
            return ""
        }

        let parts = ArrayList<String>()
        for (p in kept) {
            let content = _renderProfile(p)
            if (!content.isEmpty()) {
                parts.add(content)
            }
        }
        if (parts.size == 0) {
            return ""
        }

        let sb = StringBuilder()
        sb.append("<profile_context>\n")
        sb.append(parts[0])
        for (i in 1..parts.size) {
            sb.append("\n\n")
            sb.append(parts[i])
        }
        sb.append("\n</profile_context>")
        return sb.toString()
    }

    private func _estimateTokens(skill: Skill): Int64 {
        // 启发式：字符数 / 4 近似 token 数；至少计 1，避免空串被彻底忽略
        return (skill.instructions.size / 4) + 1
    }

    private func _renderProfile(skill: Skill): String {
        if (skill.instructions.isEmpty()) {
            return ""
        }
        let sb = StringBuilder()
        sb.append("<profile name=\"${skill.name}\">\n")
        sb.append(skill.instructions)
        sb.append("\n</profile>")
        return sb.toString()
    }
}
