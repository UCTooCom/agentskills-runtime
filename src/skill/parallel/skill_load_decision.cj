/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public enum SkillLoadDecision {
    | Loaded
    | Skipped
    | Evicted
    | Rejected

    public operator func ==(other: SkillLoadDecision): Bool {
        match (this) {
            case Loaded => match (other) {
                case Loaded => true
                case _ => false
            }
            case Skipped => match (other) {
                case Skipped => true
                case _ => false
            }
            case Evicted => match (other) {
                case Evicted => true
                case _ => false
            }
            case Rejected => match (other) {
                case Rejected => true
                case _ => false
            }
        }
    }

    public operator func !=(other: SkillLoadDecision): Bool {
        !(this == other)
    }
}

extend SkillLoadDecision <: ToString {
    public func toString(): String {
        match (this) {
            case Loaded => "Loaded"
            case Skipped => "Skipped"
            case Evicted => "Evicted"
            case Rejected => "Rejected"
        }
    }
}