/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

public class Bracket {
    public let node: Text
    public let index: Int64
    public let images: Bool

    /**
     * Previous bracket.
     */
    public let previous: ?Bracket

    /**
     * Previous delimiter (emphasis, etc) before this bracket.
     */
    public let previousDelimiter: ?Delimiter

    /**
     * Whether this bracket is allowed to form a link/image (also known as "active").
     */
    public var allowed: Bool = true

    /**
     * Whether there is an unescaped bracket (opening or closing) anywhere after this opening bracket.
     */
    public var bracketAfter: Bool = false

    public static func link(node: Text, index: Int64, previous: ?Bracket, previousDelimiter: ?Delimiter): Bracket {
        return Bracket(node, index, previous, previousDelimiter, false)
    }

    public static func image(node: Text, index: Int64, previous: ?Bracket, previousDelimiter: ?Delimiter): Bracket {
        return Bracket(node, index, previous, previousDelimiter, true)
    }

    private init(node: Text, index: Int64, previous: ?Bracket, previousDelimiter: ?Delimiter, image: Bool) {
        this.node = node
        this.index = index
        this.images = image
        this.previous = previous
        this.previousDelimiter = previousDelimiter
    }
}
