/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core

import std.deriving.*

@Derive[Equatable]
public enum PermissionLevel {
    | READ
    | WRITE
    | AUTHORIZE

    public func value(): Int32 {
        match (this) {
            case READ => 1
            case WRITE => 2
            case AUTHORIZE => 3
        }
    }

    public func toString(): String {
        match (this) {
            case READ => "READ"
            case WRITE => "WRITE"
            case AUTHORIZE => "AUTHORIZE"
        }
    }

    public static func fromInt32(v: Int32): Option<PermissionLevel> {
        match (v) {
            case 1 => Some(READ)
            case 2 => Some(WRITE)
            case 3 => Some(AUTHORIZE)
            case _ => None
        }
    }

    public static func fromInt32OrDefault(v: Int32): PermissionLevel {
        match (v) {
            case 1 => READ
            case 2 => WRITE
            case 3 => AUTHORIZE
            case _ => READ
        }
    }
}

public func hasPermission(userPermission: PermissionLevel, required: PermissionLevel): Bool {
    return userPermission.value() >= required.value()
}
