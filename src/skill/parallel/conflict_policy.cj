/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

/**
 * 多端冲突解决策略（TG22/T088）。
 *
 * - `LastWriteWins`：以最后写入为准（默认；注意 TG29 明确禁止对 MEMORY 静默以 LWW 覆盖）；
 * - `Merge`：按字段/事件合并；
 * - `Manual`：冲突时交由人工裁决，不自动覆盖。
 *
 * 仓颉 enum 不原生支持 `==`/`!=`，需显式重载（参照 load_policy.cj 范式）。
 */
public enum ConflictPolicy {
    | LastWriteWins
    | Merge
    | Manual

    public operator func ==(other: ConflictPolicy): Bool {
        match (this) {
            case LastWriteWins => match (other) {
                case LastWriteWins => true
                case _ => false
            }
            case Merge => match (other) {
                case Merge => true
                case _ => false
            }
            case Manual => match (other) {
                case Manual => true
                case _ => false
            }
        }
    }

    public operator func !=(other: ConflictPolicy): Bool {
        !(this == other)
    }
}

extend ConflictPolicy <: ToString {
    public func toString(): String {
        match (this) {
            case LastWriteWins => "last_write_wins"
            case Merge => "merge"
            case Manual => "manual"
        }
    }
}
