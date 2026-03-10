/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

package commonmark4cj.commonmark

public abstract class Node <: Context & ToString & Equatable<Node> & Hashable {
    protected var parent: ?Node = None
    protected var firstChild: ?Node = None
    protected var lastChild: ?Node = None
    protected var prev: ?Node = None
    protected var next: ?Node = None

    public open func accept(visitor: Visitor): Unit

    public open func getNext(): ?Node {
        return next
    }

    public open func getPrevious(): ?Node {
        return prev
    }

    public open func getFirstChild(): ?Node {
        return firstChild
    }

    public open func getLastChild(): ?Node {
        return lastChild
    }

    public open func getParent(): ?Node {
        return parent
    }

    protected open func setParent(parent: ?Node): Unit {
        this.parent = parent
    }

    protected open func setPrevious(prev: ?Node): Unit {
        this.prev = prev
    }

    protected open func setNext(next: ?Node): Unit {
        this.next = next
    }

    protected open func setFirstChild(firstChild: ?Node): Unit {
        this.firstChild = firstChild
    }

    protected open func setLastChild(lastChild: ?Node): Unit {
        this.lastChild = lastChild
    }

    public open func appendChild(child: Node): Unit {
        child.unlink()
        child.setParent(this)
        if (this.lastChild.isSome()) {
            this.lastChild.getOrThrow().next = child
            child.prev = this.lastChild
            this.lastChild = child
        } else {
            this.firstChild = child
            this.lastChild = child
        }
    }

    public open func prependChild(child: Node): Unit {
        child.unlink()
        child.setParent(this)
        if (this.firstChild.isSome()) {
            this.firstChild.getOrThrow().prev = child
            child.next = this.firstChild
            this.firstChild = child
        } else {
            this.firstChild = child
            this.lastChild = child
        }
    }

    public open func unlink(): Unit {
        if (this.prev.isSome()) {
            this.prev.getOrThrow().next = this.next
        } else if (this.parent.isSome()) {
            this.parent.getOrThrow().firstChild = this.next
        }
        if (this.next.isSome()) {
            this.next.getOrThrow().prev = this.prev
        } else if (this.parent.isSome()) {
            this.parent.getOrThrow().lastChild = this.prev
        }
        this.parent = Option<Node>.None
        this.next = Option<Node>.None
        this.prev = Option<Node>.None
    }

    public open func insertAfter(sibling: Node): Unit {
        sibling.unlink()
        sibling.next = this.next
        if (sibling.next.isSome()) {
            sibling.next.getOrThrow().prev = sibling
        }
        sibling.prev = this
        this.next = sibling
        sibling.parent = this.parent
        if (sibling.next.isNone()) {
            sibling.parent.getOrThrow().lastChild = sibling
        }
    }

    public open func insertBefore(sibling: Node): Unit {
        sibling.unlink()
        sibling.prev = this.prev
        if (sibling.prev.isSome()) {
            sibling.prev.getOrThrow().next = sibling
        }
        sibling.next = this
        this.prev = sibling
        sibling.parent = this.parent
        if (sibling.prev.isNone()) {
            sibling.parent.getOrThrow().firstChild = sibling
        }
    }

    public open func toString(): String {
        return "${getNodeType()}{${toStringAttributes()}}"
    }

    protected open func toStringAttributes(): String {
        return ""
    }

    public operator func ==(other: Node): Bool {
        return refEq(this, other)
    }

    public operator func !=(other: Node): Bool {
        return !refEq(this, other)
    }

    public open func hashCode(): Int {
        return "${this}${getParent()}${getPrevious()}${getNext()}${getFirstChild()}${getLastChild()}".hashCode()
    }
}

public open class Text <: Node & Equatable<Text> {
    private var literal: String

    public init(literal: String) {
        this.literal = literal
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getLiteral(): String {
        return literal
    }

    public open func setLiteral(literal: String): Unit {
        this.literal = literal
    }

    protected func toStringAttributes(): String {
        return "literal=${literal}"
    }

    public operator func ==(other: Text): Bool {
        refEq(this, other)
    }

    public operator func !=(other: Text): Bool {
        !(refEq(this, other))
    }

    public open func getNodeType(): NodeType {
        return TextType
    }
}

public open class HtmlInline <: Node {
    private var literal: String

    public init(literal: String) {
        this.literal = literal
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getLiteral(): String {
        return literal
    }

    public open func setLiteral(literal: String): Unit {
        this.literal = literal
    }

    public open func getNodeType(): NodeType {
        return HtmlInlineType
    }
}

public abstract class CustomNode <: Node {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }
}

public open class Image <: Node {
    private var destination: String
    private var title: ?String

    public init(destination: String, title: ?String) {
        this.destination = destination
        this.title = title
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getDestination(): String {
        return destination
    }

    public open func setDestination(destination: String): Unit {
        this.destination = destination
    }

    public open func getTitle(): ?String {
        return title
    }

    public open func setTitle(title: String): Unit {
        this.title = title
    }

    protected open func toStringAttributes(): String {
        return "destination=${destination}, title=${title}"
    }

    public open func getNodeType(): NodeType {
        return ImageType
    }
}

public open class Code <: Node {
    private var literal: String

    public init(literal: String) {
        this.literal = literal
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getLiteral(): String {
        return literal
    }

    public open func setLiteral(literal: String): Unit {
        this.literal = literal
    }

    public open func getNodeType(): NodeType {
        return CodeType
    }
}

public open class HardLineBreak <: Node {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return HardLineBreakType
    }
}

public open class SoftLineBreak <: Node {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return SoftLineBreakType
    }
}

public open class LinkReferenceDefinition <: Node {
    private var label: ?String = None
    private var destination: String = EMPTY_STRING
    private var title: ?String = None

    public init() {}

    public init(label: String, destination: String, title: ?String) {
        this.label = label
        this.destination = destination
        this.title = title
    }

    public open func getLabel(): ?String {
        return label
    }

    public open func setLabel(label: String): Unit {
        this.label = label
    }

    public open func getDestination(): String {
        return destination
    }

    public open func setDestination(destination: String): Unit {
        this.destination = destination
    }

    public open func getTitle(): ?String {
        return title
    }

    public open func setTitle(title: String): Unit {
        this.title = title
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return LinkReferenceDefinitionType
    }
}

public open class Link <: Node {
    private var destination: String
    private var title: ?String

    public init(destination: String, title: ?String) {
        this.destination = destination
        this.title = title
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getDestination(): String {
        return destination
    }

    public open func setDestination(destination: String): Unit {
        this.destination = destination
    }

    public open func getTitle(): ?String {
        return title
    }

    public open func setTitle(title: String): Unit {
        this.title = title
    }

    protected open func toStringAttributes(): String {
        return "destination=${destination}, title=${title}"
    }

    public open func getNodeType(): NodeType {
        return LinkType
    }
}

/**
 * A node that uses delimiters in the source form bold.
 */
public interface Delimited {
    func getOpeningDelimiter(): ?String

    func getClosingDelimiter(): ?String
}

public open class StrongEmphasis <: Node & Delimited {
    private var delimiter: ?String = None

    public init() {}

    public StrongEmphasis(delimiter: String) {
        this.delimiter = delimiter
    }

    public open func setDelimiter(delimiter: String): Unit {
        this.delimiter = delimiter
    }

    public open func getOpeningDelimiter(): ?String {
        return delimiter
    }

    public open func getClosingDelimiter(): ?String {
        return delimiter
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return StrongEmphasisType
    }
}

public open class Emphasis <: Node & Delimited {
    private var delimiter: ?String = None

    public init() {}

    public init(delimiter: String) {
        this.delimiter = delimiter
    }

    public open func setDelimiter(delimiter: String): Unit {
        this.delimiter = delimiter
    }

    public open func getOpeningDelimiter(): ?String {
        return delimiter
    }

    public open func getClosingDelimiter(): ?String {
        return delimiter
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return EmphasisType
    }
}

public abstract class Context {
    private var _custom: Any = -1
    public mut prop custom: Any {
        get() {
            _custom
        }
        set(v) {
            this._custom = v
        }
    }
    public func getNodeType(): NodeType

    private var sourceSpans: ?ArrayList<SourceSpan> = None
    /**
     * @return the source spans of this node if included by the parser, an empty list otherwise
     */
    public func getSourceSpans(): ArrayList<SourceSpan> {
        return sourceSpans ?? ArrayList()
    }

    /**
     * Replace the current source spans with the provided list.
     *
     * @param sourceSpans the new source spans to set
     */
    public func setSourceSpans(sourceSpans: ArrayList<SourceSpan>): Unit {
        if (sourceSpans.isEmpty()) {
            this.sourceSpans = None
        } else {
            this.sourceSpans = ArrayList(sourceSpans)
        }
    }

    /**
     * Add a source span to the end of the list.
     *
     * @param sourceSpan the source span to add
     */
    public func addSourceSpan(sourceSpan: SourceSpan): Unit {
        if (sourceSpans == None) {
            this.sourceSpans = ArrayList()
        }
        this.sourceSpans?.add(sourceSpan)
    }
}
