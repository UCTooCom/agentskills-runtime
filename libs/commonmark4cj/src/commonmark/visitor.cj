/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

/**
 * Node visitor.
 * Implementations should subclass {@link AbstractVisitor} instead of implementing this directly.
 */
public interface Visitor {
    func visit(blockQuote: BlockQuote): Unit

    func visit(bulletList: BulletList): Unit

    func visit(code: Code): Unit

    func visit(document: Document): Unit

    func visit(emphasis: Emphasis): Unit

    func visit(fencedCodeBlock: FencedCodeBlock): Unit

    func visit(hardLineBreak: HardLineBreak): Unit

    func visit(heading: Heading): Unit

    func visit(thematicBreak: ThematicBreak): Unit

    func visit(htmlInline: HtmlInline): Unit

    func visit(htmlBlock: HtmlBlock): Unit

    func visit(image: Image): Unit

    func visit(indentedCodeBlock: IndentedCodeBlock): Unit

    func visit(link: Link): Unit

    func visit(listItem: ListItem): Unit

    func visit(orderedList: OrderedList): Unit

    func visit(paragraph: Paragraph): Unit

    func visit(softLineBreak: SoftLineBreak): Unit

    func visit(strongEmphasis: StrongEmphasis): Unit

    func visit(text: Text): Unit

    func visit(linkReferenceDefinition: LinkReferenceDefinition): Unit

    func visit(customBlock: CustomBlock): Unit

    func visit(customNode: CustomNode): Unit
}

/**
 * Abstract visitor that visits all children by default.
 * Can be used to only process certain nodes.
 * If you override a method and want visiting to descend into children, call {@link #visitChildren}.
 */
public abstract class AbstractVisitor <: Visitor {
    public open func visit(blockQuote: BlockQuote): Unit {
        visitChildren(blockQuote)
    }

    public open func visit(bulletList: BulletList): Unit {
        visitChildren(bulletList)
    }

    public open func visit(code: Code): Unit {
        visitChildren(code)
    }

    public open func visit(document: Document): Unit {
        visitChildren(document)
    }

    public open func visit(emphasis: Emphasis): Unit {
        visitChildren(emphasis)
    }

    public open func visit(fencedCodeBlock: FencedCodeBlock): Unit {
        visitChildren(fencedCodeBlock)
    }

    public open func visit(hardLineBreak: HardLineBreak): Unit {
        visitChildren(hardLineBreak)
    }

    public open func visit(heading: Heading): Unit {
        visitChildren(heading)
    }

    public open func visit(thematicBreak: ThematicBreak): Unit {
        visitChildren(thematicBreak)
    }

    public open func visit(htmlInline: HtmlInline): Unit {
        visitChildren(htmlInline)
    }

    public open func visit(htmlBlock: HtmlBlock): Unit {
        visitChildren(htmlBlock)
    }

    public open func visit(image: Image): Unit {
        visitChildren(image)
    }

    public open func visit(indentedCodeBlock: IndentedCodeBlock): Unit {
        visitChildren(indentedCodeBlock)
    }

    public open func visit(link: Link): Unit {
        visitChildren(link)
    }

    public open func visit(listItem: ListItem): Unit {
        visitChildren(listItem)
    }

    public open func visit(orderedList: OrderedList): Unit {
        visitChildren(orderedList)
    }

    public open func visit(paragraph: Paragraph): Unit {
        visitChildren(paragraph)
    }

    public open func visit(softLineBreak: SoftLineBreak): Unit {
        visitChildren(softLineBreak)
    }

    public open func visit(strongEmphasis: StrongEmphasis): Unit {
        visitChildren(strongEmphasis)
    }

    public open func visit(text: Text): Unit {
        visitChildren(text)
    }

    public open func visit(linkReferenceDefinition: LinkReferenceDefinition): Unit {
        visitChildren(linkReferenceDefinition)
    }

    public open func visit(customBlock: CustomBlock): Unit {
        visitChildren(customBlock)
    }

    public open func visit(customNode: CustomNode): Unit {
        visitChildren(customNode)
    }

    /**
     * Visit the child nodes.
     *
     * @param parent the parent node whose children should be visited
     */
    protected open func visitChildren(parent: Node): Unit {
        var node: ?Node = parent.getFirstChild()
        while (let Some(v) <- node) {
            // A subclass of this visitor might modify the node, 
            // resulting in getNext returning a different node or no node after visiting it. 
            // So get the next node before visiting.
            node = v.getNext()
            v.accept(this)
        }
    }
}
