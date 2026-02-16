/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.examples.find_skills_skill.src

import magic.skill.application.SkillFactory
import magic.core.skill.Skill
import magic.skill.domain.models.SkillManifest
import magic.skill.domain.models.{SecurityPolicy, ResourceLimits}
import std.collection.HashMap

/**
 * Factory for creating FindSkillsSkill instances.
 * This factory is registered with the SkillRegistry to enable
 * progressive loading of FindSkillsSkill from SKILL.md files.
 */
public class FindSkillsSkillFactory <: SkillFactory {
    /**
     * The skill name that this factory can create
     */
    private static let SKILL_NAME = "find-skills"

    /**
     * Create a FindSkillsSkill instance from the manifest
     */
    public func createSkill(manifest: SkillManifest): Option<Skill> {
        if (manifest.name != SKILL_NAME) {
            return None
        }

        let skill = FindSkillsSkill(manifest)
        return Some(skill)
    }

    /**
     * Check if this factory can create a skill with the given name
     */
    public func canCreate(skillName: String): Bool {
        return skillName == SKILL_NAME
    }

    /**
     * Get the security policy for the skill
     */
    public func getSecurityPolicy(skillName: String): Option<SecurityPolicy> {
        return Some(SecurityPolicy.default())
    }

    /**
     * Get the resource limits for the skill
     */
    public func getResourceLimits(skillName: String): Option<ResourceLimits> {
        return Some(ResourceLimits.default())
    }
}
