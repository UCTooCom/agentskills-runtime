/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public enum ContentLevel {
    | Full
    | Frontmatter

    public operator func ==(other: ContentLevel): Bool {
        match (this) {
            case Full => match (other) {
                case Full => true
                case _ => false
            }
            case Frontmatter => match (other) {
                case Frontmatter => true
                case _ => false
            }
        }
    }

    public operator func !=(other: ContentLevel): Bool {
        !(this == other)
    }
}

extend ContentLevel <: ToString {
    public func toString(): String {
        match (this) {
            case Full => "Full"
            case Frontmatter => "Frontmatter"
        }
    }
}