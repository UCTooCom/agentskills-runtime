/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

package commonmark4cj.commonmark

/**
 * Parses input text to a tree of nodes.
 *
 * Start with the {@link #builder} method, configure the parser and build it. Example:
 *
 * Parser parser = Parser.builder().build()
 * document:Node  = parser.parse("input text")
 *
 */
public class Parser {
    private let blockParserFactories: ArrayList<BlockParserFactory>
    private let delimiterProcessors: ArrayList<DelimiterProcessor>
    private let inlineParserFactory: InlineParserFactory
    private let postProcessors: ArrayList<PostProcessor>
    private let inlineContentParserFactories: ArrayList<InlineContentParserFactory>
    private let linkProcessors: ArrayList<LinkProcessor>
    private let linkMarkers: HashSet<Rune>
    private let inlineParserContext: InlineParserContext

    Parser(builder: ParserBuilder) {
        this.blockParserFactories = DocumentParser.calculateBlockParserFactories(
            builder.blockParserFactories,
            builder.getEnabledBlockTypes()
        )
        this.inlineParserFactory = builder.getInlineParserFactory()
        this.postProcessors = builder.postProcessors
        this.delimiterProcessors = builder.delimiterProcessors

        this.inlineContentParserFactories = builder.inlineContentParserFactories
        this.linkProcessors = builder.linkProcessors
        this.linkMarkers = builder.linkMarkers

        // Try to construct an inline parser.
        // Invalid configuration might result in an exception,
        // which we want to detect as soon as possible.
        var context = InlineParserContextImpl(inlineContentParserFactories, delimiterProcessors, HashMap<String, LinkReferenceDefinition>(), linkProcessors, linkMarkers)
        context.calc()
        this.inlineParserContext = context
        this.inlineParserFactory.create(context)
    }

    /**
     * Create a new builder for configuring a {@link Parser}.
     *
     * @return a builder
     */
    public static func builder(): ParserBuilder {
        return ParserBuilder()
    }

    /**
     * Parse the specified input text into a tree of nodes.
     *
     * This method is thread-safe (a new parser state is used for each invocation).
     *
     * @param input the text to parse - must not be null
     * @return the root node
     */
    public func parse(input: String): Node {
        let documentParser: DocumentParser = createDocumentParser()
        let document: Node = documentParser.parse(input)
        return postProcess(document)
    }

    /**
     * Parse the specified reader into a tree of nodes. The caller is responsible for closing the reader.
     *
     * Parser parser = Parser.builder().build()
     * try (reader = StringReader(File.openRead("file.md")) {
     *     let document:Node = parser.parseReader(reader)
     *     // ...
     * }
     *
     * Note that if you have a file with a byte order mark (BOM), you need to skip it before handing the reader to this
     * library. There's existing classes that do that, e.g. see {@code BOMInputStream} in Commons IO.
     *
     * This method is thread-safe (a new parser state is used for each invocation).
     *
     * @param input the reader to parse - must not be null
     * @return the root node
     * @throws IOException when reading throws an exception
     */
    public func parseReader(input: StringReader<InputStream>): Node {
        let documentParser: DocumentParser = createDocumentParser()
        let document: Node = documentParser.parse(input)
        return postProcess(document)
    }

    private func createDocumentParser(): DocumentParser {
        return DocumentParser(blockParserFactories, inlineParserFactory, delimiterProcessors, inlineParserContext)
    }

    private func postProcess(document: Node): Node {
        var doc: Node = document
        for (postProcessor in postProcessors) {
            doc = postProcessor.process(doc)
        }
        return doc
    }
}

/**
 * Builder for configuring a {@link Parser}.
 */
public class ParserBuilder {
    let blockParserFactories: ArrayList<BlockParserFactory> = ArrayList<BlockParserFactory>()
    let delimiterProcessors: ArrayList<DelimiterProcessor> = ArrayList<DelimiterProcessor>()
    let postProcessors: ArrayList<PostProcessor> = ArrayList<PostProcessor>()
    var _enabledBlockTypes: HashSet<NodeType> = DocumentParser.getDefaultBlockParserTypes()
    var _inlineParserFactory: ?InlineParserFactory = None

    let inlineContentParserFactories: ArrayList<InlineContentParserFactory> = ArrayList()
    let linkProcessors: ArrayList<LinkProcessor> = ArrayList()
    let linkMarkers: HashSet<Rune> = HashSet()

    /**
     * @return the configured {@link Parser}
     */
    public func build(): Parser {
        return Parser(this)
    }

    public func getEnabledBlockTypes(): HashSet<NodeType> {
        return _enabledBlockTypes
    }

    /**
     * @param extensions extensions to use on this parser
     * @return {@code this}
     */
    public func extensions<T>(extensions: Iterable<T>): ParserBuilder where T <: Extension {
        for (extension in extensions) {
            if (let Some(parserExtension) <- (extension as ParserExtension)) {
                parserExtension.ext(this)
            }
        }
        return this
    }

    /**
     * Describe the list of markdown features the parser will recognize and parse.
     *
     * By default, CommonMark will recognize and parse the following set of "block" elements:
     *
     * {@link Heading} ({@code #})
     * {@link HtmlBlock} ({@code <html></html>})
     * {@link ThematicBreak} (Horizontal Rule) ({@code ---})
     * {@link FencedCodeBlock} ({@code ```})
     * {@link IndentedCodeBlock}
     * {@link BlockQuote} ({@code >})
     * {@link ListBlock} (Ordered / Unordered ArrayList) ({@code 1. / *})
     *
     * To parse only a subset of the features listed above, pass a list of each feature's associated {@link Block} class.
     *
     * E.g., to only parse headings and lists:
     *
     *  Parser.builder().enabledBlockTypes(new HashSet<>(Arrays.asList(Heading.class, ListBlock.class)))
     *
     * @param enabledBlockTypes A list of block nodes the parser will parse.
     * If this list is empty, the parser will not recognize any CommonMark core features.
     * @return {@code this}
     */
    public func enabledBlockTypes(enabledBlockTypes: HashSet<NodeType>): ParserBuilder {
        this._enabledBlockTypes = enabledBlockTypes
        return this
    }

    /**
     * Adds a custom block parser factory.
     *
     * Note that custom factories are applied before the built-in factories. This is so that
     * extensions can change how some syntax is parsed that would otherwise be handled by built-in factories.
     * "With great power comes great responsibility."
     *
     * @param blockParserFactory a block parser factory implementation
     * @return {@code this}
     */
    public func customBlockParserFactory(blockParserFactory: BlockParserFactory): ParserBuilder {
        blockParserFactories.add(blockParserFactory)
        return this
    }

    /**
     * Adds a custom delimiter processor.
     *
     * Note that multiple delimiter processors with the same characters can be added, as long as they have a
     * different minimum length. In that case, the processor with the shortest matching length is used. Adding more
     * than one delimiter processor with the same character and minimum length is invalid.
     *
     * @param delimiterProcessor a delimiter processor implementation
     * @return {@code this}
     */
    public func customDelimiterProcessor(delimiterProcessor: DelimiterProcessor): ParserBuilder {
        delimiterProcessors.add(delimiterProcessor)
        return this
    }

    public func postProcessor(postProcessor: PostProcessor): ParserBuilder {
        postProcessors.add(postProcessor)
        return this
    }

    /**
     * Overrides the parser used for inline markdown processing.
     *
     * Provide an implementation of InlineParserFactory which provides a custom inline parser
     * to modify how the following are parsed:
     * bold (**)
     * italic (*)
     * strikethrough (~~)
     * backtick quote (`)
     * link ([title](http://))
     * image (![alt](http://))
     *
     * Note that if this method is not called or the inline parser factory is set to null, then the default
     * implementation will be used.
     *
     * @param inlineParserFactory an inline parser factory implementation
     * @return {@code this}
     */
    public func inlineParserFactory(inlineParserFactory: InlineParserFactory): ParserBuilder {
        this._inlineParserFactory = inlineParserFactory
        return this
    }

    public func getInlineParserFactory(): InlineParserFactory {
        return _inlineParserFactory ?? DefaultInlineParserFactory()
    }

    /**
     * Add a factory for a custom inline content parser, for extending inline parsing or overriding built-in parsing.
     * <p>
     * Note that parsers are triggered based on a special character as specified by
     * {@link InlineContentParserFactory#getTriggerCharacters()}. It is possible to register multiple parsers for the same
     * character, or even for some built-in special character such as {@code `}. The custom parsers are tried first
     * in order in which they are registered, and then the built-in ones.
     */
    public func customInlineContentParserFactory(inlineContentParserFactory: InlineContentParserFactory): This{
        inlineContentParserFactories.add(inlineContentParserFactory)
        return this
    }
    
    /**
     * Add a custom link/image processor for inline parsing.
     * <p>
     * Multiple link processors can be added, and will be tried in order in which they were added. If no link
     * processor applies, the normal behavior applies. That means these can override built-in link parsing.
     *
     * @param linkProcessor a link processor implementation
     * @return {@code this}
     */
    public func linkProcessor(linkProcessor: LinkProcessor): This{
        linkProcessors.add(linkProcessor)
        return this
    }
    
    /**
     * Add a custom link marker for link processing. A link marker is a character like {@code !} which, if it
     * appears before the {@code [} of a link, changes the meaning of the link.
     * <p>
     * If a link marker followed by a valid link is parsed, the {@link org.commonmark.parser.beta.LinkInfo}
     * that is passed to {@link LinkProcessor} will have its {@link LinkInfo#marker()} set. A link processor should
     * check the {@link Text#getLiteral()} and then do any processing, and will probably want to use {@link LinkResult#includeMarker()}.
     *
     * @param linkMarker a link marker character
     * @return {@code this}
     */
    public func linkMarker(linkMarker: Rune): This{
        linkMarkers.add(linkMarker)
        return this
    }
}

class DefaultInlineParserFactory <: InlineParserFactory {
    public override func create(inlineParserContext: InlineParserContext): InlineParser {
        return InlineParserImplV2(inlineParserContext)
    }
}

/**
 * Extension for {@link Parser}.
 */
public interface ParserExtension <: Extension {
    func ext(parserBuilder: ParserBuilder): Unit
}

public interface PostProcessor {
    /**
     * @param node the node to post-process
     * @return the result of post-processing, may be a modified {@code node} argument
     */
    func process(node: Node): Node
}
