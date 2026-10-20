/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

/**
 * 技能类型判别式（TG21/T083）。
 *
 * - `Profile`：常驻人格/身份/记忆类技能，注入到独立的 `<profile_context>` 层，
 *   不注册为工具，按 profile 预算独立核算；
 * - `Capability`：常规能力型技能，走原有注入路径。
 *
 * 仓颉 enum 不原生支持 `==`/`!=`，需显式重载（参照 load_policy.cj / skill_priority.cj 范式）。
 */
public enum SkillType {
    | Profile
    | Capability

    public operator func ==(other: SkillType): Bool {
        match (this) {
            case Profile => match (other) {
                case Profile => true
                case _ => false
            }
            case Capability => match (other) {
                case Capability => true
                case _ => false
            }
        }
    }

    public operator func !=(other: SkillType): Bool {
        !(this == other)
    }
}

extend SkillType <: ToString {
    public func toString(): String {
        match (this) {
            case Profile => "profile"
            case Capability => "capability"
        }
    }
}
