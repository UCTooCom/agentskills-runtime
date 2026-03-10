/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

public abstract class Block <: Node {
    public open func getParent(): ?Node {
        let parent: ?Node = super.getParent()
        return match (parent) {
            case Some(v: Block) => v
            case _ => None
        }
    }

    protected open func setParent(parent: Node): Unit {
        if (!(parent is Block)) {
            throw IllegalArgumentException("Parent of block must also be block (can not be inline)")
        }
        super.setParent(parent)
    }
}

public open class BlockQuote <: Block {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return BlockQuoteType
    }
}

public open class HtmlBlock <: Block {
    private var literal: String = EMPTY_STRING

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
        return HtmlBlockType
    }
}

public abstract class CustomBlock <: Block {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }
}

public open class ThematicBreak <: Block {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return ThematicBreakType
    }
}

public open class Document <: Block {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return DocumentType
    }
}

public open class Paragraph <: Block {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return ParagraphType
    }
}

public open class IndentedCodeBlock <: Block {
    private var literal: String = EMPTY_STRING

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
        return IndentedCodeBlockType
    }
}

public open class FencedCodeBlock <: Block {
    private var fenceChar: Rune = NULL_CHAR
    private var fenceLength: Int64 = 0
    private var fenceIndent: Int64 = 0

    private var info: String = EMPTY_STRING
    private var literal: String = EMPTY_STRING

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getFenceChar(): Rune {
        return fenceChar
    }

    public open func setFenceChar(fenceChar: Rune): Unit {
        this.fenceChar = fenceChar
    }

    public open func getFenceLength(): Int64 {
        return fenceLength
    }

    public open func setFenceLength(fenceLength: Int64): Unit {
        this.fenceLength = fenceLength
    }

    public open func getFenceIndent(): Int64 {
        return fenceIndent
    }

    public open func setFenceIndent(fenceIndent: Int64): Unit {
        this.fenceIndent = fenceIndent
    }

    public open func getInfo(): String {
        return info
    }

    public open func setInfo(info: String): Unit {
        this.info = info
    }

    public open func getLiteral(): String {
        return literal
    }

    public open func setLiteral(literal: String): Unit {
        this.literal = literal
    }

    public open func getNodeType(): NodeType {
        return FencedCodeBlockType
    }
}

public open class ListItem <: Block {
    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getNodeType(): NodeType {
        return ListItemType
    }
}

public open class Heading <: Block {
    private var level: Int64 = 0

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getLevel(): Int64 {
        return level
    }

    public open func setLevel(level: Int64): Unit {
        this.level = level
    }

    public open func getNodeType(): NodeType {
        return HeadingType
    }
}

public abstract class ListBlock <: Block {
    private var tight: Bool = false

    public open func isTight(): Bool {
        return tight
    }

    public open func setTight(tight: Bool) {
        this.tight = tight
    }
}

public open class BulletList <: ListBlock {
    private var bulletMarker: Rune

    public init(bulletMarker: Rune) {
        this.bulletMarker = bulletMarker
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getBulletMarker(): Rune {
        return bulletMarker
    }

    public open func setBulletMarker(bulletMarker: Rune): Unit {
        this.bulletMarker = bulletMarker
    }

    public open func getNodeType(): NodeType {
        return BulletListType
    }
}

public open class OrderedList <: ListBlock {
    private var startNumber: Int64
    private var delimiter: Rune

    public init(startNumber: Int64, delimiter: Rune) {
        this.startNumber = startNumber
        this.delimiter = delimiter
    }

    public open func accept(visitor: Visitor): Unit {
        visitor.visit(this)
    }

    public open func getStartNumber(): Int64 {
        return startNumber
    }

    public open func setStartNumber(startNumber: Int64): Unit {
        this.startNumber = startNumber
    }

    public open func getDelimiter(): Rune {
        return delimiter
    }

    public open func setDelimiter(delimiter: Rune): Unit {
        this.delimiter = delimiter
    }

    public open func getNodeType(): NodeType {
        return OrderedListType
    }
}
