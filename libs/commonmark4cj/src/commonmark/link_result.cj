/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * What to do with a link/image processed by {@link LinkProcessor}.
 */
public interface LinkResult {
    /**
     * Link not handled by processor.
     */
    static func none(): ?LinkResult {
        return None
    }

    /**
     * Wrap the link text in a node. This is the normal behavior for links, e.g. for this:
     * <pre><code>
     * [my *text*](destination)
     * </code></pre>
     * The text is {@code my *text*}, a text node and emphasis. The text is wrapped in a
     * {@link org.commonmark.node.Link} node, which means the text is added as child nodes to it.
     *
     * @param node     the node to which the link text nodes will be added as child nodes
     * @param position the position to continue parsing from
     */
    static func wrapTextIn(node: Node, position: SourcePosition): LinkResult {
        return LinkResultImpl(LinkResultImplType.WRAP, node, position)
    }

    /**
     * Replace the link with a node. E.g. for this:
     * <pre><code>
     * [^foo]
     * </code></pre>
     * The processor could decide to create a {@code FootnoteReference} node instead which replaces the link.
     *
     * @param node     the node to replace the link with
     * @param position the position to continue parsing from
     */
    static func replaceWith(node: Node, position: SourcePosition): LinkResult {
        return LinkResultImpl(LinkResultImplType.REPLACE, node, position)
    }

    /**
     * If a {@link LinkInfo#marker()} is present, include it in processing (i.e. treat it the same way as the brackets).
     */
    func includeMarker(): LinkResult
}

public class LinkResultImpl <: LinkResult {
    // @Override
    public func includeMarker(): LinkResult {
        _includeMarker = true
        return this
    }

    private let typ: LinkResultImplType
    private let node: Node
    private let position: SourcePosition

    private var _includeMarker: Bool = false

    public LinkResultImpl(typ: LinkResultImplType, node: Node, position: SourcePosition) {
        this.typ = typ
        this.node = node
        this.position = position
    }

    public func getType(): LinkResultImplType {
        return typ
    }

    public func getNode(): Node {
        return node
    }

    public func getPosition(): SourcePosition {
        return position
    }

    public func isIncludeMarker(): Bool {
        return _includeMarker
    }
}

public enum LinkResultImplType {
    WRAP | REPLACE
}
