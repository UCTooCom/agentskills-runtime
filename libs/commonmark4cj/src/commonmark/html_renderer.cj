/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

/**
 * Renders a tree of nodes to HTML.
 * <p>
 * Start with the {@link #builder} method to configure the renderer. Example:
 * <pre><code>
 * HtmlRenderer renderer = HtmlRenderer.builder().escapeHtml(true).build()
 * renderer.render(node)
 * </code></pre>
 */
public class HtmlRenderer <: Renderer {
    let softbreak: String
    let escapeHtml: Bool
    let percentEncodeUrls: Bool
    let attributeProviderFactories: ArrayList<AttributeProviderFactory>
    let nodeRendererFactories: ArrayList<HtmlNodeRendererFactory>

    HtmlRenderer(builder: HtmlRendererBuilder) {
        this.softbreak = builder._softbreak
        this.escapeHtml = builder._escapeHtml
        this.percentEncodeUrls = builder._percentEncodeUrls
        this.attributeProviderFactories = ArrayList<AttributeProviderFactory>(builder.attributeProviderFactories)

        this.nodeRendererFactories = ArrayList<HtmlNodeRendererFactory>(builder.nodeRendererFactories.size + 1)
        this.nodeRendererFactories.add(all: builder.nodeRendererFactories)
        // Add as last. This means clients can override the rendering of core nodes if they want.
        this.nodeRendererFactories.add({context: HtmlNodeRendererContext => CoreHtmlNodeRenderer(context)})
    }

    /**
     * Create a new builder for configuring an {@link HtmlRenderer}.
     *
     * @return a builder
     */
    public static func builder(): HtmlRendererBuilder {
        return HtmlRendererBuilder()
    }

    public override func render(node: Node, output: StringBuilder): Unit {
        let context: HtmlRendererContextImpl = HtmlRendererContextImpl(HtmlWriter(output), this)
        for (attributeProviderFactory in attributeProviderFactories) {
            context.attributeProviders.add(attributeProviderFactory(context))
        }
        // The first node renderer for a node type "wins".
        for (i in nodeRendererFactories.size - 1..=0 : -1) {
            let nodeRendererFactory: HtmlNodeRendererFactory = nodeRendererFactories[i]
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
 * Builder for configuring an {@link HtmlRenderer}. See methods for default configuration.
 */
public class HtmlRendererBuilder {
    var _softbreak: String = "\n"
    var _escapeHtml: Bool = false
    var _percentEncodeUrls: Bool = false
    let attributeProviderFactories: ArrayList<AttributeProviderFactory> = ArrayList<AttributeProviderFactory>()
    let nodeRendererFactories: ArrayList<HtmlNodeRendererFactory> = ArrayList<HtmlNodeRendererFactory>()

    /**
     * @return the configured {@link HtmlRenderer}
     */
    public func build(): HtmlRenderer {
        return HtmlRenderer(this)
    }

    /**
     * The HTML to use for rendering a softbreak, defaults to {@code "\n"} (meaning the rendered result doesn't have
     * a line break).
     * <p>
     * HashSet it to {@code "<br>"} (or {@code "<br />"} to make them hard breaks.
     * <p>
     * HashSet it to {@code " "} to ignore line wrapping in the source.
     *
     * @param softbreak HTML for softbreak
     * @return {@code this}
     */
    public func softbreak(softbreak: String): HtmlRendererBuilder {
        this._softbreak = softbreak
        return this
    }

    /**
     * Whether {@link HtmlInline} and {@link HtmlBlock} should be escaped, defaults to {@code false}.
     * <p>
     * Note that {@link HtmlInline} is only a tag itself, not the text between an opening tag and a closing tag. So
     * markup in the text will be parsed as normal and is not affected by this option.
     *
     * @param escapeHtml true for escaping, false for preserving raw HTML
     * @return {@code this}
     */
    public func escapeHtml(escapeHtml: Bool): HtmlRendererBuilder {
        this._escapeHtml = escapeHtml
        return this
    }

    /**
     * Whether URLs of link or images should be percent-encoded, defaults to {@code false}.
     * <p>
     * If enabled, the following is done:
     * <ul>
     * <li>Existing percent-encoded parts are preserved (e.g. "%20" is kept as "%20")</li>
     * <li>Reserved characters such as "/" are preserved, except for "[" and "]" (see encodeURI in JS)</li>
     * <li>Unreserved characters such as "a" are preserved</li>
     * <li>Other characters such umlauts are percent-encoded</li>
     * </ul>
     *
     * @param percentEncodeUrls true to percent-encode, false for leaving as-is
     * @return {@code this}
     */
    public func percentEncodeUrls(percentEncodeUrls: Bool): HtmlRendererBuilder {
        this._percentEncodeUrls = percentEncodeUrls
        return this
    }

    /**
     * Add a factory for an attribute provider for adding/changing HTML attributes to the rendered tags.
     *
     * @param attributeProviderFactory the attribute provider factory to add
     * @return {@code this}
     */
    public func attributeProviderFactory(attributeProviderFactory: AttributeProviderFactory): HtmlRendererBuilder {
        this.attributeProviderFactories.add(attributeProviderFactory)
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
    public func nodeRendererFactory(nodeRendererFactory: HtmlNodeRendererFactory): HtmlRendererBuilder {
        this.nodeRendererFactories.add(nodeRendererFactory)
        return this
    }

    /**
     * @param extensions extensions to use on this HTML renderer
     * @return {@code this}
     */
    public func extensions(extensions: Iterable<Extension>): HtmlRendererBuilder {
        for (extension in extensions) {
            if (extension is HtmlRendererExtension) {
                let htmlRendererExtension: HtmlRendererExtension = (extension as HtmlRendererExtension)()
                htmlRendererExtension.ext(this)
            }
        }
        return this
    }
}

/**
 * Extension for {@link HtmlRenderer}.
 */
public interface HtmlRendererExtension <: Extension {
    func ext(rendererBuilder: HtmlRendererBuilder): Unit
}

class HtmlRendererContextImpl <: HtmlNodeRendererContext & AttributeProviderContext {
    let htmlWriter: HtmlWriter
    let attributeProviders: ArrayList<AttributeProvider>
    let nodeRendererMap: NodeRendererMap = NodeRendererMap()
    let htmlRenderer: HtmlRenderer

    init(htmlWriter: HtmlWriter, htmlRenderer: HtmlRenderer) {
        this.htmlWriter = htmlWriter
        this.htmlRenderer = htmlRenderer
        this.attributeProviders = ArrayList<AttributeProvider>(htmlRenderer.attributeProviderFactories.size)
    }

    public override func shouldEscapeHtml(): Bool {
        return htmlRenderer.escapeHtml
    }

    public override func encodeUrl(url: String): String {
        if (htmlRenderer.percentEncodeUrls) {
            return Escaping.percentEncodeUrl(url)
        } else {
            return url
        }
    }

    public override func extendAttributes(
        node: Node,
        tagName: String,
        attributes: HashMap<String, String>
    ): HashMap<String, String> {
        let attrs: HashMap<String, String> = attributes.clone()
        setCustomAttributes(node, tagName, attrs)
        return attrs
    }

    public override func getWriter(): HtmlWriter {
        return htmlWriter
    }

    public override func getSoftbreak(): String {
        return htmlRenderer.softbreak
    }

    public override func render(node: Node): Unit {
        nodeRendererMap.render(node)
    }

    private func setCustomAttributes(node: Node, tagName: String, attrs: HashMap<String, String>): Unit {
        for (attributeProvider in attributeProviders) {
            attributeProvider.setAttributes(node, tagName, attrs)
        }
    }
}

public class HtmlWriter {
    private static let NO_ATTRIBUTES: HashMap<String, String> = EMPTY_MAP

    private let buffer: StringBuilder
    private var lastChar: Byte = 0 // 只关注[\x0\n]所以用Byte类型
    public init(out: StringBuilder) {
        this.buffer = out
    }

    public func raw(s: String): Unit {
        append(s)
    }

    public func text(text: String): Unit {
        append(Escaping.escapeHtml(text))
    }

    public func tag(name: String): Unit {
        tag(name, NO_ATTRIBUTES)
    }

    public func tag(name: String, attrs: HashMap<String, String>): Unit {
        tag(name, attrs, false)
    }

    public func tag(name: String, attrs: ?HashMap<String, String>, voidElement: Bool): Unit {
        append("<")
        append(name)
        if (attrs.isSome() && attrs().size > 0) {
            for ((k, v) in attrs()) {
                append(" ")
                append(Escaping.escapeHtml(k))
                append("=\"")
                append(Escaping.escapeHtml(v))
                append("\"")
            }
        }
        if (voidElement) {
            append(" /")
        }
        append(">")
    }

    public func line(): Unit {
        if (lastChar != 0 && lastChar != b'\n') {
            append("\n")
        }
    }

    protected func append(s: String): Unit {
        buffer.append(s)
        let length = s.size
        if (length != 0) {
            lastChar = s[length - 1]
        }
    }
}

/**
 * Extension point for adding/changing attributes on HTML tags for a node.
 */
public interface AttributeProvider {

    /**
     * HashSet the attributes for a HTML tag of the specified node by modifying the provided map.
     * <p>
     * This allows to change or even remove default attributes. With great power comes great responsibility.
     * <p>
     * The attribute key and values will be escaped (preserving character entities), so don't escape them here,
     * otherwise they will be double-escaped.
     * <p>
     * This method may be called multiple times for the same node, if the node is rendered using multiple nested
     * tags (e.g. code blocks).
     *
     * @param node the node to set attributes for
     * @param tagName the HTML tag name that these attributes are for (e.g. {@code h1}, {@code pre}, {@code code}).
     * @param attributes the attributes, with any default attributes already set in the map
     */
    func setAttributes(node: Node, tagName: String, attributes: HashMap<String, String>): Unit
}

/**
 * The context for attribute providers.
 * <p>Note: There are currently no methods here, this is for future extensibility.</p>
 * <p><em>This interface is not intended to be implemented by clients.</em></p>
 */
public interface AttributeProviderContext {}

/**
 * Factory for instantiating new attribute providers when rendering is done.
 * Create a new attribute provider.
 *
 * @param context for this attribute provider
 * @return an AttributeProvider
 */
public type AttributeProviderFactory = (context: AttributeProviderContext) -> AttributeProvider

/**
 * The node renderer that renders all the core nodes (comes last in the order of node renderers).
 */
class CoreHtmlNodeRenderer <: AbstractVisitor & NodeRenderer {
    protected let context: HtmlNodeRendererContext
    private let html: HtmlWriter

    public init(context: HtmlNodeRendererContext) {
        this.context = context
        this.html = context.getWriter()
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

    public override func visit(heading: Heading): Unit {
        let htag: String = "h${heading.getLevel()}"
        html.line()
        html.tag(htag, getAttrs(heading, htag))
        visitChildren(heading)
        html.tag("/${htag}")
        html.line()
    }

    public override func visit(paragraph: Paragraph): Unit {
        let inTightList: Bool = isInTightList(paragraph)
        if (!inTightList) {
            html.line()
            html.tag("p", getAttrs(paragraph, "p"))
        }
        visitChildren(paragraph)
        if (!inTightList) {
            html.tag("/p")
            html.line()
        }
    }

    public override func visit(blockQuote: BlockQuote): Unit {
        html.line()
        html.tag("blockquote", getAttrs(blockQuote, "blockquote"))
        html.line()
        visitChildren(blockQuote)
        html.line()
        html.tag("/blockquote")
        html.line()
    }

    public override func visit(bulletList: BulletList): Unit {
        renderListBlock(bulletList, "ul", getAttrs(bulletList, "ul"))
    }

    public override func visit(fencedCodeBlock: FencedCodeBlock): Unit {
        let literal: String = fencedCodeBlock.getLiteral()
        let attributes: HashMap<String, String> = HashMap<String, String>()
        let info: String = fencedCodeBlock.getInfo()
        if (info.size > 0) {
            let language: String = if (let Some(space) <- info.indexOf(" ")) {
                info[..space]
            } else {
                info
            }
            attributes.add("class", "language-${language}")
        }
        renderCodeBlock(literal, fencedCodeBlock, attributes)
    }

    public override func visit(htmlBlock: HtmlBlock): Unit {
        html.line()
        if (context.shouldEscapeHtml()) {
            html.tag("p", getAttrs(htmlBlock, "p"))
            html.text(htmlBlock.getLiteral())
            html.tag("/p")
        } else {
            html.raw(htmlBlock.getLiteral())
        }
        html.line()
    }

    public override func visit(thematicBreak: ThematicBreak): Unit {
        html.line()
        html.tag("hr", getAttrs(thematicBreak, "hr"), true)
        html.line()
    }

    public override func visit(indentedCodeBlock: IndentedCodeBlock): Unit {
        renderCodeBlock(indentedCodeBlock.getLiteral(), indentedCodeBlock, EMPTY_MAP)
    }

    public override func visit(link: Link): Unit {
        let attrs: HashMap<String, String> = HashMap<String, String>()
        let url: String = context.encodeUrl(link.getDestination())
        attrs.add("href", url)
        if (let Some(v) <- link.getTitle()) {
            attrs.add("title", v)
        }
        html.tag("a", getAttrs(link, "a", attrs))
        visitChildren(link)
        html.tag("/a")
    }

    public override func visit(listItem: ListItem): Unit {
        html.tag("li", getAttrs(listItem, "li"))
        visitChildren(listItem)
        html.tag("/li")
        html.line()
    }

    public override func visit(orderedList: OrderedList): Unit {
        let start: Int = orderedList.getStartNumber()
        let attrs: HashMap<String, String> = HashMap<String, String>()
        if (start != 1) {
            attrs.add("start", start.toString())
        }
        renderListBlock(orderedList, "ol", getAttrs(orderedList, "ol", attrs))
    }

    public override func visit(image: Image): Unit {
        let url: String = context.encodeUrl(image.getDestination())

        let altTextVisitor: AltTextVisitor = AltTextVisitor()
        image.accept(altTextVisitor)
        let altText: String = altTextVisitor.getAltText()

        let attrs: HashMap<String, String> = HashMap<String, String>()
        attrs.add("src", url)
        attrs.add("alt", altText)
        if (let Some(v) <- image.getTitle()) {
            attrs.add("title", v)
        }

        html.tag("img", getAttrs(image, "img", attrs), true)
    }

    public override func visit(emphasis: Emphasis): Unit {
        html.tag("em", getAttrs(emphasis, "em"))
        visitChildren(emphasis)
        html.tag("/em")
    }

    public override func visit(strongEmphasis: StrongEmphasis): Unit {
        html.tag("strong", getAttrs(strongEmphasis, "strong"))
        visitChildren(strongEmphasis)
        html.tag("/strong")
    }

    public override func visit(text: Text): Unit {
        html.text(text.getLiteral())
    }

    public override func visit(code: Code): Unit {
        html.tag("code", getAttrs(code, "code"))
        html.text(code.getLiteral())
        html.tag("/code")
    }

    public override func visit(htmlInline: HtmlInline): Unit {
        if (context.shouldEscapeHtml()) {
            html.text(htmlInline.getLiteral())
        } else {
            html.raw(htmlInline.getLiteral())
        }
    }

    public override func visit(_: SoftLineBreak): Unit {
        html.raw(context.getSoftbreak())
    }

    public override func visit(hardLineBreak: HardLineBreak): Unit {
        html.tag("br", getAttrs(hardLineBreak, "br"), true)
        html.line()
    }

    protected override func visitChildren(parent: Node): Unit {
        var node: ?Node = parent.getFirstChild()
        while (let Some(v) <- node) {
            node = v.getNext()
            context.render(v)
        }
    }

    private func renderCodeBlock(literal: String, node: Node, attributes: HashMap<String, String>): Unit {
        html.line()
        html.tag("pre", getAttrs(node, "pre"))
        html.tag("code", getAttrs(node, "code", attributes))
        html.text(literal)
        html.tag("/code")
        html.tag("/pre")
        html.line()
    }

    private func renderListBlock(listBlock: ListBlock, tagName: String, attributes: HashMap<String, String>): Unit {
        html.line()
        html.tag(tagName, attributes)
        html.line()
        visitChildren(listBlock)
        html.line()
        html.tag("/${tagName}")
        html.line()
    }

    private func isInTightList(paragraph: Paragraph): Bool {
        if (let Some(parent) <- paragraph.getParent()) {
            match(parent.getParent()) {
                case Some(list: ListBlock) => return list.isTight()
                case _ => ()
            }
            
        }
        return false
    }

    private func getAttrs(node: Node, tagName: String): HashMap<String, String> {
        return getAttrs(node, tagName, EMPTY_MAP)
    }

    private func getAttrs(node: Node, tagName: String, defaultAttributes: HashMap<String, String>): HashMap<String, String> {
        return context.extendAttributes(node, tagName, defaultAttributes)
    }
}

class AltTextVisitor <: AbstractVisitor {
    private let sb: StringBuilder = StringBuilder()

    func getAltText(): String {
        return sb.toString()
    }

    public override func visit(text: Text): Unit {
        sb.append(text.getLiteral())
    }

    public override func visit(_: SoftLineBreak): Unit {
        sb.append('\n')
    }

    public override func visit(_: HardLineBreak): Unit {
        sb.append('\n')
    }
}

public interface HtmlNodeRendererContext {

    /**
     * @param url to be encoded
     * @return an encoded URL (depending on the configuration)
     */
    func encodeUrl(url: String): String

    /**
     * Let extensions modify the HTML tag attributes.
     *
     * @param node the node for which the attributes are applied
     * @param tagName the HTML tag name that these attributes are for (e.g. {@code h1}, {@code pre}, {@code code}).
     * @param attributes the attributes that were calculated by the renderer
     * @return the extended attributes with added/updated/removed entries
     */
    func extendAttributes(node: Node, tagName: String, attributes: HashMap<String, String>): HashMap<String, String>

    /**
     * @return the HTML writer to use
     */
    func getWriter(): HtmlWriter

    /**
     * @return HTML that should be rendered for a soft line break
     */
    func getSoftbreak(): String

    /**
     * Render the specified node and its children using the configured renderers. This should be used to render child
     * nodes; be careful not to pass the node that is being rendered, that would result in an endless loop.
     *
     * @param node the node to render
     */
    func render(node: Node): Unit

    /**
     * @return whether HTML blocks and tags should be escaped or not
     */
    func shouldEscapeHtml(): Bool
}

/**
 * Factory for instantiating new node renderers when rendering is done.
 * Create a new node renderer for the specified rendering context.
 *
 * @param context the context for rendering (normally passed on to the node renderer)
 * @return a node renderer
 */
public type HtmlNodeRendererFactory = (context: HtmlNodeRendererContext) -> NodeRenderer
