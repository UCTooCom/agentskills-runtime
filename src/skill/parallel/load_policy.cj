/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public enum LoadPolicy {
    | AlwaysOn
    | OnDemand
    | Conditional

    public operator func ==(other: LoadPolicy): Bool {
        match (this) {
            case AlwaysOn => match (other) {
                case AlwaysOn => true
                case _ => false
            }
            case OnDemand => match (other) {
                case OnDemand => true
                case _ => false
            }
            case Conditional => match (other) {
                case Conditional => true
                case _ => false
            }
        }
    }

    public operator func !=(other: LoadPolicy): Bool {
        !(this == other)
    }
}

extend LoadPolicy <: ToString {
    public func toString(): String {
        match (this) {
            case AlwaysOn => "AlwaysOn"
            case OnDemand => "OnDemand"
            case Conditional => "Conditional"
        }
    }
}