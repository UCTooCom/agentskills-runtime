/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

public class TextContentRenderer <: Renderer {
    let stripNewlines: Bool
    let nodeRendererFactories: ArrayList<TextContentNodeRendererFactory>

    init(builder: TextContentRendererBuilder) {
        this.stripNewlines = builder.stripNewlines

        this.nodeRendererFactories = ArrayList<TextContentNodeRendererFactory>(builder.nodeRendererFactories.size + 1)
        this.nodeRendererFactories.add(all: builder.nodeRendererFactories)
        // Add as last. This means clients can override the rendering of core nodes if they want.
        this.nodeRendererFactories.add(
            {context: TextContentNodeRendererContext => CoreTextContentNodeRenderer(context)})
    }

    /**
     * Create a new builder for configuring an {@link TextContentRenderer}.
     *
     * @return a builder
     */
    public static func builder(): TextContentRendererBuilder {
        return TextContentRendererBuilder()
    }

    public override func render(node: Node, output: StringBuilder): Unit {
        let context: RendererContext = RendererContext(TextContentWriter(output), this)
        // The first node renderer for a node type "wins".
        for (i in nodeRendererFactories.size - 1..=0 : -1) {
            let nodeRendererFactory: TextContentNodeRendererFactory = nodeRendererFactories[i]
            let nodeRenderer: NodeRenderer = nodeRendererFactory(context)
            context.nodeRendererMap.add(nodeRenderer)
        }
        context.render(node)
    }

    public override func render(node: Node): String {
        let sb: StringBuilder = StringBuilder()
        render(node, sb)
        return sb.toString()
    }
}

/**
 * Builder for configuring an {@link TextContentRenderer}. See methods for default configuration.
 */
public class TextContentRendererBuilder {
    var stripNewlines: Bool = false
    let nodeRendererFactories: ArrayList<TextContentNodeRendererFactory> = ArrayList<TextContentNodeRendererFactory>()

    /**
     * @return the configured {@link TextContentRenderer}
     */
    public func build(): TextContentRenderer {
        return TextContentRenderer(this)
    }

    /**
     * Set the value of flag for stripping new lines.
     *
     * @param stripNewlines true for stripping new lines and render text as "single line",
     *                      false for keeping all line breaks
     * @return {@code this}
     */
    public func setStripNewlines(stripNewlines: Bool): TextContentRendererBuilder {
        this.stripNewlines = stripNewlines
        return this
    }

    /**
     * Add a factory for instantiating a node renderer (done when rendering). This allows to override the rendering
     * of node types or define rendering for custom node types.
     * <p>
     * If multiple node renderers for the same node type are created, the one from the factory that was added first
     * "wins". (This is how the rendering for core node types can be overridden; the default rendering comes last.)
     *
     * @param nodeRendererFactory the factory for creating a node renderer
     * @return {@code this}
     */
    public func nodeRendererFactory(nodeRendererFactory: TextContentNodeRendererFactory): TextContentRendererBuilder {
        this.nodeRendererFactories.add(nodeRendererFactory)
        return this
    }

    /**
     * @param extensions extensions to use on this text content renderer
     * @return {@code this}
     */
    public func extensions(extensions: Iterable<Extension>): TextContentRendererBuilder {
        for (extension in extensions) {
            if (extension is TextContentRendererExtension) {
                let htmlRendererExtension: TextContentRendererExtension = (extension as TextContentRendererExtension).
                    getOrThrow()
                htmlRendererExtension.ext(this)
            }
        }
        return this
    }
}

/**
 * Extension for {@link TextContentRenderer}.
 */
public interface TextContentRendererExtension <: Extension {
    func ext(rendererBuilder: TextContentRendererBuilder): Unit
}

class RendererContext <: TextContentNodeRendererContext {
    let textContentWriter: TextContentWriter
    let nodeRendererMap: NodeRendererMap = NodeRendererMap()
    let renderer: TextContentRenderer

    init(textContentWriter: TextContentWriter, renderer: TextContentRenderer) {
        this.textContentWriter = textContentWriter
        this.renderer = renderer
    }

    public override func stripNewlines(): Bool {
        return renderer.stripNewlines
    }

    public override func getWriter(): TextContentWriter {
        return textContentWriter
    }

    public override func render(node: Node): Unit {
        nodeRendererMap.render(node)
    }
}

/**
 * The node renderer that renders all the core nodes (comes last in the order of node renderers).
 */
class CoreTextContentNodeRenderer <: AbstractVisitor & NodeRenderer {
    protected let context: TextContentNodeRendererContext
    private let textContent: TextContentWriter

    private var listHolder: ?ListHolder = None

    public init(context: TextContentNodeRendererContext) {
        this.context = context
        this.textContent = context.getWriter()
    }

    public override func getNodeTypes(): HashSet<NodeType> {
        return HashSet<NodeType>(
            [
                DocumentType,
                HeadingType,
                ParagraphType,
                BlockQuoteType,
                BulletListType,
                FencedCodeBlockType,
                HtmlBlockType,
                ThematicBreakType,
                IndentedCodeBlockType,
                LinkType,
                ListItemType,
                OrderedListType,
                ImageType,
                EmphasisType,
                StrongEmphasisType,
                TextType,
                CodeType,
                HtmlInlineType,
                SoftLineBreakType,
                HardLineBreakType
            ]
        )
    }

    public override func render(node: Node): Unit {
        node.accept(this)
    }

    public override func visit(document: Document): Unit {
        // No rendering itself
        visitChildren(document)
    }

    public override func visit(blockQuote: BlockQuote): Unit {
        textContent.write("«")
        visitChildren(blockQuote)
        textContent.write("»")

        writeEndOfLineIfNeeded(blockQuote, None)
    }

    public override func visit(bulletList: BulletList): Unit {
        if (listHolder.isSome()) {
            writeEndOfLine()
        }
        listHolder = BulletListHolder(listHolder, bulletList)
        visitChildren(bulletList)
        writeEndOfLineIfNeeded(bulletList, None)
        if (listHolder().getParent().isSome()) {
            listHolder = listHolder().getParent()
        } else {
            listHolder = None
        }
    }

    public override func visit(code: Code): Unit {
        textContent.write("\"")
        textContent.write(code.getLiteral())
        textContent.write("\"")
    }

    public override func visit(fencedCodeBlock: FencedCodeBlock): Unit {
        if (context.stripNewlines()) {
            textContent.writeStripped(fencedCodeBlock.getLiteral())
            writeEndOfLineIfNeeded(fencedCodeBlock, None)
        } else {
            textContent.write(fencedCodeBlock.getLiteral())
        }
    }

    public override func visit(hardLineBreak: HardLineBreak): Unit {
        writeEndOfLineIfNeeded(hardLineBreak, None)
    }

    public override func visit(heading: Heading): Unit {
        visitChildren(heading)
        writeEndOfLineIfNeeded(heading, r':')
    }

    public override func visit(thematicBreak: ThematicBreak): Unit {
        if (!context.stripNewlines()) {
            textContent.write("***")
        }
        writeEndOfLineIfNeeded(thematicBreak, None)
    }

    public override func visit(htmlInline: HtmlInline): Unit {
        writeText(htmlInline.getLiteral())
    }

    public override func visit(htmlBlock: HtmlBlock): Unit {
        writeText(htmlBlock.getLiteral())
    }

    public override func visit(image: Image): Unit {
        writeLink(image, image.getTitle(), image.getDestination())
    }

    public override func visit(indentedCodeBlock: IndentedCodeBlock): Unit {
        if (context.stripNewlines()) {
            textContent.writeStripped(indentedCodeBlock.getLiteral())
            writeEndOfLineIfNeeded(indentedCodeBlock, None)
        } else {
            textContent.write(indentedCodeBlock.getLiteral())
        }
    }

    public override func visit(link: Link): Unit {
        writeLink(link, link.getTitle(), link.getDestination())
    }

    public override func visit(listItem: ListItem): Unit {
        match(listHolder) {
            case Some(orderedListHolder: OrderedListHolder) =>
                let indent: String = if (context.stripNewlines()) {
                    ""
                } else {
                    orderedListHolder.getIndent()
                }
                textContent.write("${indent}${orderedListHolder.getCounter()}${orderedListHolder.getDelimiter()} ")
                visitChildren(listItem)
                writeEndOfLineIfNeeded(listItem, None)
                orderedListHolder.increaseCounter()
                
            case _ => 
                match(listHolder) {
                    case Some(bulletListHolder: BulletListHolder) =>
                        if (!context.stripNewlines()) {
                            textContent.write("${bulletListHolder.getIndent()}${bulletListHolder.getMarker()} ")
                        }
                        visitChildren(listItem)
                        writeEndOfLineIfNeeded(listItem, None)
                    case _ => ()
                }
        }
        
    }

    public override func visit(orderedList: OrderedList): Unit {
        if (listHolder.isSome()) {
            writeEndOfLine()
        }
        listHolder = OrderedListHolder(listHolder, orderedList)
        visitChildren(orderedList)
        writeEndOfLineIfNeeded(orderedList, None)
        if (listHolder().getParent().isSome()) {
            listHolder = listHolder().getParent()
        } else {
            listHolder = None
        }
    }

    public override func visit(paragraph: Paragraph): Unit {
        visitChildren(paragraph)
        // Add "end of line" only if its "root paragraph.
        if (paragraph.getParent().isNone() || paragraph.getParent()() is Document) {
            writeEndOfLineIfNeeded(paragraph, None)
        }
    }

    public override func visit(softLineBreak: SoftLineBreak): Unit {
        writeEndOfLineIfNeeded(softLineBreak, None)
    }

    public override func visit(text: Text): Unit {
        writeText(text.getLiteral())
    }

    protected override func visitChildren(parent: Node): Unit {
        var node: ?Node = parent.getFirstChild()
        while (let Some(v) <- node) {
            node = v.getNext()
            context.render(v)
        }
    }

    private func writeText(text: String): Unit {
        if (context.stripNewlines()) {
            textContent.writeStripped(text)
        } else {
            textContent.write(text)
        }
    }

    private func writeLink(node: Node, title: ?String, destination: ?String): Unit {
        let hasChild: Bool = node.getFirstChild().isSome()
        let hasTitle: Bool = title.isSome() && title != destination
        let hasDestination: Bool = destination.isSome() && destination() != EMPTY_STRING

        if (hasChild) {
            textContent.write("\"")
            visitChildren(node)
            textContent.write("\"")
            if (hasTitle || hasDestination) {
                textContent.whitespace()
                textContent.write("(")
            }
        }

        if (hasTitle) {
            textContent.write(title())
            if (hasDestination) {
                textContent.colon()
                textContent.whitespace()
            }
        }

        if (hasDestination) {
            textContent.write(destination())
        }

        if (hasChild && (hasTitle || hasDestination)) {
            textContent.write(")")
        }
    }

    private func writeEndOfLineIfNeeded(node: Node, c: ?Rune): Unit {
        if (context.stripNewlines()) {
            if (let Some(v) <- c?.toString()) {
                textContent.write(v)
            }
            if (node.getNext().isSome()) {
                textContent.whitespace()
            }
        } else {
            if (node.getNext().isSome()) {
                textContent.line()
            }
        }
    }

    private func writeEndOfLine(): Unit {
        if (context.stripNewlines()) {
            textContent.whitespace()
        } else {
            textContent.line()
        }
    }
}

public interface TextContentNodeRendererContext {
    /**
     * @return true for stripping new lines and render text as "single line",
     * false for keeping all line breaks.
     */
    func stripNewlines(): Bool

    /**
     * @return the writer to use
     */
    func getWriter(): TextContentWriter

    /**
     * Render the specified node and its children using the configured renderers. This should be used to render child
     * nodes; be careful not to pass the node that is being rendered, that would result in an endless loop.
     *
     * @param node the node to render
     */
    func render(node: Node): Unit
}

/**
 * Factory for instantiating new node renderers when rendering is done.
 * Create a new node renderer for the specified rendering context.
 *
 * @param context the context for rendering (normally passed on to the node renderer)
 * @return a node renderer
 */
public type TextContentNodeRendererFactory = (context: TextContentNodeRendererContext) -> NodeRenderer

public class TextContentWriter {
    let buffer: StringBuilder

    private var lastChar: Byte = 0 // 只关注[\x0 :\n]所以用Byte类型

    public TextContentWriter(out: StringBuilder) {
        buffer = out
    }

    public func whitespace(): Unit {
        if (lastChar != 0 && lastChar != b' ') {
            append(" ")
        }
    }

    public func colon(): Unit {
        if (lastChar != 0 && lastChar != b':') {
            append(":")
        }
    }

    public func line(): Unit {
        if (lastChar != 0 && lastChar != b'\n') {
            append("\n")
        }
    }

    public func writeStripped(str: String): Unit {
        if (str.size > 0) {
            append(Regex("[\\r\\n\\s]+").replaceAll(str, " "))
        }
    }

    public func write(s: String): Unit {
        append(s)
    }

    private func append(str: String): Unit {
        if (str.size > 0) {
            buffer.append(str)
            lastChar = str[str.size - 1]
        }
    }
}
