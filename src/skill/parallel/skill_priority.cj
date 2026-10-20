/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public enum SkillPriority {
    | High
    | Medium
    | Low

    public operator func ==(other: SkillPriority): Bool {
        match (this) {
            case High => match (other) {
                case High => true
                case _ => false
            }
            case Medium => match (other) {
                case Medium => true
                case _ => false
            }
            case Low => match (other) {
                case Low => true
                case _ => false
            }
        }
    }

    public operator func !=(other: SkillPriority): Bool {
        !(this == other)
    }

    public func compare(other: SkillPriority): Int64 {
        return match (this) {
            case High => match (other) {
                case High => 0
                case Medium => 1
                case Low => 1
            }
            case Medium => match (other) {
                case High => -1
                case Medium => 0
                case Low => 1
            }
            case Low => match (other) {
                case High => -1
                case Medium => -1
                case Low => 0
            }
        }
    }
}

extend SkillPriority <: ToString {
    public func toString(): String {
        match (this) {
            case High => "High"
            case Medium => "Medium"
            case Low => "Low"
        }
    }
}