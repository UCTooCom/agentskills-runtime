/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.Skill
import magic.skill.BaseSkill
import magic.log.LogUtils
import std.collection.{ArrayList, HashMap}

public class BudgetManager {
    private let _config: SkillParallelConfig

    public init(config!: SkillParallelConfig) {
        _config = config
    }

    public prop config: SkillParallelConfig {
        get() { _config }
    }

    public func allocateWithDegrade(skills: Array<Skill>, totalBudget: Int64): BudgetAllocationResult {
        if (skills.size == 0) {
            return BudgetAllocationResult(totalBudget: totalBudget)
        }

        let sortedSkills = sortSkillsByPriority(skills)

        let allocated = ArrayList<String>()
        let degraded = ArrayList<String>()
        let evicted = ArrayList<String>()
        let contentLevels = HashMap<String, ContentLevel>()
        var usedTokens: Int64 = 0

        for (skill in sortedSkills) {
            let fullTokens = getSkillContextBudget(skill)
            let frontmatterTokens = estimateFrontmatterTokens(skill)

            if (usedTokens + fullTokens <= totalBudget) {
                allocated.add(skill.name)
                contentLevels.add(skill.name, ContentLevel.Full)
                usedTokens += fullTokens
            } else if (usedTokens + frontmatterTokens <= totalBudget) {
                degraded.add(skill.name)
                contentLevels.add(skill.name, ContentLevel.Frontmatter)
                usedTokens += frontmatterTokens
                LogUtils.info("BudgetManager: degraded skill '${skill.name}' to frontmatter (tokens: ${frontmatterTokens})")
            } else {
                evicted.add(skill.name)
                LogUtils.warn("BudgetManager: evicted skill '${skill.name}' due to budget exceeded")
            }
        }

        return BudgetAllocationResult(
            allocated: allocated.toArray(),
            evicted: evicted.toArray(),
            usedTokens: usedTokens,
            totalBudget: totalBudget,
            degraded: degraded.toArray(),
            contentLevels: contentLevels
        )
    }

    public func degradeToFrontmatter(skill: Skill): Skill {
        return BaseSkill(
            name: skill.name,
            description: skill.description,
            license: skill.license,
            compatibility: skill.compatibility,
            metadata: skill.metadata,
            allowedTools: skill.allowedTools,
            instructions: "",
            skillPath: skill.skillPath
        )
    }

    public func calculateFullTokens(skills: Array<Skill>): Int64 {
        var total: Int64 = 0
        for (skill in skills) {
            total += getSkillContextBudget(skill)
        }
        return total
    }

    public func calculateFrontmatterTokens(skills: Array<Skill>): Int64 {
        var total: Int64 = 0
        for (skill in skills) {
            total += estimateFrontmatterTokens(skill)
        }
        return total
    }

    private func getSkillContextBudget(skill: Skill): Int64 {
        return SkillParallelDeclarationParser.parseContextBudgetTokens(skill.metadata)
    }

    private func estimateFrontmatterTokens(skill: Skill): Int64 {
        let charCount = skill.name.size + skill.description.size
        return Int64(charCount) / 4
    }

    private func sortSkillsByPriority(skills: Array<Skill>): Array<Skill> {
        let sorted = ArrayList<Skill>()
        for (s in skills) {
            sorted.add(s)
        }
        let n = sorted.size
        for (i in 0..n - 1) {
            for (j in 0..n - 1 - i) {
                if (compareSkillPriority(sorted[j], sorted[j + 1]) < 0) {
                    let tmp = sorted[j]
                    sorted[j] = sorted[j + 1]
                    sorted[j + 1] = tmp
                }
            }
        }
        return sorted.toArray()
    }

    private func compareSkillPriority(a: Skill, b: Skill): Int64 {
        let policyA = SkillParallelDeclarationParser.parseLoadPolicy(a.metadata)
        let policyB = SkillParallelDeclarationParser.parseLoadPolicy(b.metadata)
        if (policyA == LoadPolicy.AlwaysOn && policyB != LoadPolicy.AlwaysOn) {
            return 1
        }
        if (policyA != LoadPolicy.AlwaysOn && policyB == LoadPolicy.AlwaysOn) {
            return -1
        }
        let prioA = SkillParallelDeclarationParser.parsePriority(a.metadata)
        let prioB = SkillParallelDeclarationParser.parsePriority(b.metadata)
        return prioA.compare(prioB)
    }
}