/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * The result of a single inline parser. Use the static methods to create instances.
 * <p>
 * <em>This interface is not intended to be implemented by clients.</em>
 */
public interface ParsedInline {
    static func none(): ParsedInline {
        return NoneParsedInline.NON
    }

    static func of(node: Node, position: SourcePosition): ParsedInline {
        return ParsedInlineImpl(node, position)
    }
}

public class ParsedInlineImpl <: ParsedInline {
    private let node: Node
    private let position: SourcePosition

    public ParsedInlineImpl(node: Node, position: SourcePosition) {
        this.node = node
        this.position = position
    }

    public func getNode(): Node {
        return node
    }

    public func getPosition(): SourcePosition {
        return position
    }
}

class NoneParsedInline <: ParsedInline {
    static let NON = NoneParsedInline()
}
