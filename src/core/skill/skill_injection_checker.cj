/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.core.skill

public interface SkillInjectionChecker {
    func isSkillInjected(skillName: String): Bool
}