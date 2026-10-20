/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public enum InjectSource {
    | AutoInit
    | AutoTaskMatch
    | AutoDependency
    | AgentToolCall

    public operator func ==(other: InjectSource): Bool {
        match (this) {
            case AutoInit => match (other) {
                case AutoInit => true
                case _ => false
            }
            case AutoTaskMatch => match (other) {
                case AutoTaskMatch => true
                case _ => false
            }
            case AutoDependency => match (other) {
                case AutoDependency => true
                case _ => false
            }
            case AgentToolCall => match (other) {
                case AgentToolCall => true
                case _ => false
            }
        }
    }

    public operator func !=(other: InjectSource): Bool {
        !(this == other)
    }
}

extend InjectSource <: ToString {
    public func toString(): String {
        match (this) {
            case AutoInit => "AutoInit"
            case AutoTaskMatch => "AutoTaskMatch"
            case AutoDependency => "AutoDependency"
            case AgentToolCall => "AgentToolCall"
        }
    }
}