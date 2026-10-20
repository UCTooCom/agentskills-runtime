/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import std.collection.ArrayList

public enum SkillInjectionStatus {
    | Success
    | Partial
    | Failed

    public operator func ==(other: SkillInjectionStatus): Bool {
        match (this) {
            case Success => match (other) {
                case Success => true
                case _ => false
            }
            case Partial => match (other) {
                case Partial => true
                case _ => false
            }
            case Failed => match (other) {
                case Failed => true
                case _ => false
            }
        }
    }

    public operator func !=(other: SkillInjectionStatus): Bool {
        !(this == other)
    }
}

extend SkillInjectionStatus <: ToString {
    public func toString(): String {
        match (this) {
            case Success => "Success"
            case Partial => "Partial"
            case Failed => "Failed"
        }
    }
}

public class SkillInjectionResult {
    public var status: SkillInjectionStatus
    public var injectedContext: String
    public var activeSkills: ArrayList<String>
    public var decisions: ArrayList<String>
    public var errorMessage: Option<String>

    public init(
        status!: SkillInjectionStatus = SkillInjectionStatus.Success,
        injectedContext!: String = "",
        activeSkills!: ArrayList<String> = ArrayList<String>(),
        decisions!: ArrayList<String> = ArrayList<String>(),
        errorMessage!: Option<String> = None<String>
    ) {
        this.status = status
        this.injectedContext = injectedContext
        this.activeSkills = activeSkills
        this.decisions = decisions
        this.errorMessage = errorMessage
    }
}