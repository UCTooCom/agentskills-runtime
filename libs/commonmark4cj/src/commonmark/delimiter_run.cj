/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark
/**
 * A delimiter run is one or more of the same delimiter character.
 */
public interface DelimiterRun {

    /**
     * @return whether this can open a delimiter
     */
    func canOpen(): Bool

    /**
     * @return whether this can close a delimiter
     */
    func canClose(): Bool

    /**
     * @return the number of characters in this delimiter run (that are left for processing)
     */
    func getLength(): Int64

    /**
     * @return the number of characters originally in this delimiter run at the start of processing, this is the same
     * as {{@link #length()}}
     */
    func getOriginalLength(): Int64
}

/**
 * Delimiter (emphasis, strong emphasis or custom emphasis).
 */
public class Delimiter <: DelimiterRun & Equatable<Delimiter> {
    public let node: Text
    public let delimiterChar: Rune

    /**
     * Can open emphasis, see spec.
     */
    public let canOpenBool: Bool

    /**
     * Can close emphasis, see spec.
     */
    public let canCloseBool: Bool

    public var previous: ?Delimiter = None
    public var next: ?Delimiter = None

    public var length: Int64 = 1
    public var originalLength: Int64 = 1

    public init(node: Text, delimiterChar: Rune, canOpen: Bool, canClose: Bool, previous: ?Delimiter) {
        this.node = node
        this.delimiterChar = delimiterChar
        this.canOpenBool = canOpen
        this.canCloseBool = canClose
        this.previous = previous
    }

    public func canOpen(): Bool {
        return canOpenBool
    }

    public func canClose(): Bool {
        return canCloseBool
    }

    public func getLength(): Int64 {
        return length
    }

    public func getOriginalLength(): Int64 {
        return originalLength
    }

    public operator func ==(other: Delimiter): Bool {
        return refEq(this, other)
    }

    public operator func !=(other: Delimiter): Bool {
        return !refEq(this, other)
    }
}
