/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model.enums

public enum CompressionLevel <: Equal<CompressionLevel> {
    | NO_COMPRESSION
    | FASTEST
    | FASTER
    | FAST
    | MEDIUM_FAST
    | NORMAL
    | HIGHER
    | MAXIMUM
    | PRE_ULTRA
    | ULTRA
    

    public func getLevel(): Int32 {
        return match(this) {
            case NO_COMPRESSION => 0
            case FASTEST => 1
            case FASTER => 2
            case FAST => 3
            case MEDIUM_FAST => 4
            case NORMAL => 5
            case HIGHER => 6
            case MAXIMUM => 7
            case PRE_ULTRA => 8
            case ULTRA  => 9
        }
    }

    public operator func ==(that: CompressionLevel): Bool {
        that.getLevel() == this.getLevel()
    }
}
