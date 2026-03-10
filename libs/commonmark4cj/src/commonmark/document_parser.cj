/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

package commonmark4cj.commonmark

class DocumentParser <: ParserState {
    private static var CORE_FACTORY_TYPES: HashSet<NodeType> = HashSet<NodeType>(
        [
            BlockQuoteType,
            HeadingType,
            FencedCodeBlockType,
            HtmlBlockType,
            ThematicBreakType,
            ListBlockType,
            IndentedCodeBlockType
        ]
    )

    private static var NODES_TO_CORE_FACTORIES: HashMap<NodeType, BlockParserFactory> = HashMap<NodeType, BlockParserFactory>(
        [
            (BlockQuoteType, BlockQuoteParserFactory()),
            (HeadingType, HeadingParserFactory()),
            (FencedCodeBlockType, FencedCodeBlockParserFactory()),
            (HtmlBlockType, HtmlBlockParserFactory()),
            (ThematicBreakType, ThematicBreakParserFactory()),
            (ListBlockType, ListBlockParserFactory()),
            (IndentedCodeBlockType, IndentedCodeBlockParserFactory())
        ]
    )

    private var line: String = ""

    /**
     * current index (offset) in input line (0-based)
     */
    private var index: Int64 = 0

    /**
     * current column of input line (tab causes column to go to next 4-space tab stop) (0-based)
     */
    private var column: Int64 = 0

    /**
     * if the current column is within a tab character (partially consumed tab)
     */
    private var columnIsInTab: Bool = false

    private var nextNonSpace: Int64 = 0
    private var nextNonSpaceColumn: Int64 = 0
    private var indent: Int64 = 0
    private var blank: Bool = false

    private var blockParserFactories: ArrayList<BlockParserFactory>
    private var inlineParserFactory: InlineParserFactory
    private var delimiterProcessors: ArrayList<DelimiterProcessor>
    private var documentBlockParser: DocumentBlockParser
    private var definitions: HashMap<String, LinkReferenceDefinition> = HashMap<String, LinkReferenceDefinition>()

    private var activeBlockParsers: ArrayList<AbstractBlockParser> = ArrayList<AbstractBlockParser>()
    // LinkedHashSet to have a deterministic order
    private var allBlockParsers: ArrayList<AbstractBlockParser> = ArrayList<AbstractBlockParser>()
    // private var allBlockParsers: HashSet<AbstractBlockParser> = HashSet<AbstractBlockParser>()
    private let inlineParserContext: InlineParserContext

    public init(
        blockParserFactories: ArrayList<BlockParserFactory>,
        inlineParserFactory: InlineParserFactory,
        delimiterProcessors: ArrayList<DelimiterProcessor>,
        inlineParserContext: InlineParserContext
    ) {
        this.blockParserFactories = blockParserFactories
        this.inlineParserFactory = inlineParserFactory
        this.delimiterProcessors = delimiterProcessors

        this.documentBlockParser = DocumentBlockParser()
        this.inlineParserContext = inlineParserContext
        activateBlockParser(this.documentBlockParser)
    }

    public static func getDefaultBlockParserTypes(): HashSet<NodeType> {
        return CORE_FACTORY_TYPES
    }

    public static func calculateBlockParserFactories(
        customBlockParserFactories: ArrayList<BlockParserFactory>,
        enabledBlockTypes: HashSet<NodeType>
    ): ArrayList<BlockParserFactory> {
        var list: ArrayList<BlockParserFactory> = ArrayList<BlockParserFactory>()
        // By having the custom factories come first, extensions are able to change behavior of core syntax.
        list.add(all: customBlockParserFactories)
        for (blockType in enabledBlockTypes) {
            list.add(NODES_TO_CORE_FACTORIES.get(blockType).getOrThrow())
        }
        return list
    }

    /**
     * The main parsing function. Returns a parsed document AST.
     */
    public func parse(inputStr: String): Document {
        input = inputStr.replace("\0", "\u{FFFD}")
        lineStart = 0
        lineBreak = Parsing.findLineBreak(input, lineStart)

        while (lineBreak != -1) {
            var line = input[lineStart..lineBreak]

            // 预处理lineStart/lineBreak 便于getNextLine
            if (lineBreak + 1 < input.size && input[lineBreak] == b'\r' && input[lineBreak + 1] == b'\n') {
                lineStart = lineBreak + 2
            } else {
                lineStart = lineBreak + 1
            }
            lineBreak = Parsing.findLineBreak(input, lineStart)

            incorporateLine(line)
        }
        if (input.size > 0 && (lineStart == 0 || lineStart < input.size)) {
            var line = input[lineStart..input.size]
            incorporateLine(line)
        }

        return finalizeAndProcess()
    }

    public func parse(input: StringReader<InputStream>): Document { // throws IOException
        var bufferedReader: StringReader<InputStream> = input
        while (true) {
            if (let Some(line) <- bufferedReader.readln()) {
                incorporateLine(line)
            } else {
                break
            }
        }

        return finalizeAndProcess()
    }

    public func getLine(): String {
        return line
    }

    private var input: String = "" // 所有行的内容
    private var lineStart: Int = -1
    private var lineBreak: Int = -1
    public func getNextLine(): String {
        if (lineStart <= lineBreak) {
            input[lineStart..lineBreak]
        } else {
            ""
        }
    }

    public func getIndex(): Int64 {
        return index
    }

    public func getNextNonSpaceIndex(): Int64 {
        return nextNonSpace
    }

    public func getColumn(): Int64 {
        return column
    }

    public func getIndent(): Int64 {
        return indent
    }

    public func isBlank(): Bool {
        return blank
    }

    public func getActiveBlockParser(): AbstractBlockParser {
        return activeBlockParsers[activeBlockParsers.size - 1]
    }

    /**
     * Analyze a line of text and update the document appropriately. We parse markdown text by calling this on each
     * line of input, then finalizing the document.
     */
    private func incorporateLine(ln: String): Unit {
        line = ln
        index = 0
        column = 0
        columnIsInTab = false

        // For each containing block, try to parse the associated line start.
        // Bail out on failure: container will poInt64 to the last matching block.
        // Set all_matched to false if not all containers match.
        // The document will always match, can be skipped
        var matches: Int64 = 1
        let activeBlockParsersSize: Int64 = activeBlockParsers.size
        if (activeBlockParsersSize > 1) {
            for (index in 1..activeBlockParsersSize) {
                let blockParser = activeBlockParsers[index]
                findNextNonSpace()

                var result: ?BlockContinue = blockParser.tryContinue(this)
                if (result.isSome() && result() is BlockContinueImpl) {
                    var blockContinueImpl: BlockContinueImpl = (result() as BlockContinueImpl).getOrThrow()
                    if (blockContinueImpl.isFinalize()) {
                        finalize(blockParser)
                        return
                    } else {
                        if (blockContinueImpl.getNewIndex() != -1) {
                            setNewIndex(blockContinueImpl.getNewIndex())
                        } else if (blockContinueImpl.getNewColumn() != -1) {
                            setNewColumn(blockContinueImpl.getNewColumn())
                        }
                        matches++
                    }
                } else {
                    break
                }
            }
        }

        var matchesEnd: Int64 = activeBlockParsers.size - 1
        var unmatchedBlockParser = activeBlockParsers
        var lastMatchedBlockParser: AbstractBlockParser = activeBlockParsers[matches - 1]
        var blockParser: AbstractBlockParser = lastMatchedBlockParser
        var allClosed: Bool = matches > activeBlockParsers.size

        // Unless last matched container is a code block, try container starts,
        // adding children to the last matched container:
        var tryBlockBool: Bool = blockParser.getBlock() is Paragraph || blockParser.isContainer()
        while (tryBlockBool) {
            findNextNonSpace()
            if (isBlank() || (indent < Parsing.CODE_BLOCK_INDENT && Parsing.isLetter(line, nextNonSpace))) {
                setNewIndex(nextNonSpace)
                break
            }
            var blockStartOption: ?BlockStart = findBlockStart(blockParser)
            if (blockStartOption.isNone()) {
                setNewIndex(nextNonSpace)
                break
            }

            if (!allClosed) {
                finalizeBlocks(unmatchedBlockParser, matches, matchesEnd)
                allClosed = true
            }
            var blockStartImpl = (blockStartOption.getOrThrow() as BlockStartImpl).getOrThrow()
            if (blockStartImpl.getNewIndex() != -1) {
                setNewIndex(blockStartImpl.getNewIndex())
            } else if (blockStartImpl.getNewColumn() != -1) {
                setNewColumn(blockStartImpl.getNewColumn())
            }
            if (blockStartImpl.isReplaceActiveBlockParser()) {
                prepareActiveBlockParserForReplacement()
            }

            for (newBlockParser in blockStartImpl.getBlockParsers()) {
                blockParser = addChild(newBlockParser)
                tryBlockBool = newBlockParser.isContainer()
            }
        }

        // What remains at the offset is a text line. Add the text to the
        // appropriate block.

        // First check for a lazy paragraph continuation:
        if (!allClosed && !isBlank() && getActiveBlockParser().canHaveLazyContinuationLines()) {
            // lazy paragraph continuation
            addLine()
        } else {

            // finalize any blocks not matched
            if (!allClosed) {
                finalizeBlocks(unmatchedBlockParser, matches, matchesEnd)
            }

            if (!blockParser.isContainer()) {
                addLine()
            } else if (!isBlank()) {
                // create paragraph container for line
                addChild(ParagraphParser())
                addLine()
            }
        }
    }

    private func findNextNonSpace(): Unit {
        var i: Int64 = index
        var colsNum: Int64 = column

        blank = true
        var length: Int64 = line.size
        while (i < length) {
            var c = line[i]
            if (c == b' ') {
                i++
                colsNum++
                continue
            } else if (c == b'\t') {
                i++
                colsNum += (4 - (colsNum % 4))
                continue
            }
            blank = false
            break
        }

        nextNonSpace = i
        nextNonSpaceColumn = colsNum
        indent = nextNonSpaceColumn - column
    }

    private func setNewIndex(newIndex: Int64): Unit {
        if (newIndex >= nextNonSpace) {
            // We can start from here, no need to calculate tab stops again
            index = nextNonSpace
            column = nextNonSpaceColumn
        }
        var length: Int64 = line.size
        while (index < newIndex && index != length) {
            advance()
        }
        // If we're going to an index as opposed to a column, we're never within a tab
        columnIsInTab = false
    }

    private func setNewColumn(newColumnNum: Int64): Unit {
        if (newColumnNum >= nextNonSpaceColumn) {
            // We can start from here, no need to calculate tab stops again
            index = nextNonSpace
            column = nextNonSpaceColumn
        }
        var length: Int64 = line.size
        while (column < newColumnNum && index != length) {
            advance()
        }
        if (column > newColumnNum) {
            // Last character was a tab and we overshot our target
            index--
            column = newColumnNum
            columnIsInTab = true
        } else {
            columnIsInTab = false
        }
    }

    /**
     * append contents
     */
    private func addLine(): Unit {
        var content: String
        if (columnIsInTab) {
            var afterTab: Int64 = index + 1
            var rest = line[afterTab..line.size]
            var spaces: Int64 = Parsing.columnsToNextTabStop(column)
            var sb: StringBuilder = StringBuilder(spaces + rest.size)
            sb.append(" " * spaces)
            sb.append(rest)
            content = sb.toString()
        } else {
            content = line[index..line.size]
        }
        getActiveBlockParser().addLine(content)
    }

    private func advance(): Unit {
        var lineChar = line[index]
        if (lineChar == b'\t') {
            index++
            column = Parsing.columnsToNextTabStop(column) + column
        } else {
            index++
            column++
        }
    }

    private func findBlockStart(blockParser: AbstractBlockParser): Option<BlockStart> {
        var matchedBlockParser: MatchedBlockParser = MatchedBlockParserImpl(blockParser)
        for (blockParserFactory in blockParserFactories) {
            var result: ?BlockStart = blockParserFactory.tryStart(this, matchedBlockParser)
            if (result.isSome() && result.getOrThrow() is BlockStartImpl) {
                return result
            }
        }
        return None
    }

    /**
     * Finalize a block. Close it and do any necessary postprocessing, e.g. creating string_content from strings,
     * setting the 'tight' or 'loose' status of a list, and parsing the beginnings of paragraphs for reference
     * definitions.
     */
    private func finalize(blockParser: AbstractBlockParser): Unit {
        if (refEq(getActiveBlockParser(), blockParser)) {
            deactivateBlockParser()
        }

        if (blockParser is ParagraphParser) {
            addDefinitionsFrom((blockParser as ParagraphParser).getOrThrow())
        }

        blockParser.closeBlock()
    }

    private func addDefinitionsFrom(paragraphParser: ParagraphParser): Unit {
        for (definition in paragraphParser.getDefinitions()) {
            // Add nodes into document before paragraph.
            paragraphParser.getBlock().insertBefore(definition)

            var label: String = definition.getLabel().getOrThrow()
            // spec: When there are multiple matching link reference definitions, the first is used
            if (!definitions.contains(label)) {
                definitions.add(label, definition)
            }
        }
    }

    /**
     * Walk through a block & children recursively, parsing string content into inline content where appropriate.
     */
    private func processInlines(): Unit {
        var context = InlineParserContextImpl(
            inlineParserContext.getCustomInlineContentParserFactories(),
            delimiterProcessors,
            definitions,
            inlineParserContext.getCustomLinkProcessors(),
            inlineParserContext.getCustomLinkMarkers()
        )
        if (let Some(ctx) <- (this.inlineParserContext as InlineParserContextImpl)) {
            ctx.calc()
            context.ctxCalc = ctx.ctxCalc
        }
        var inlineParser: InlineParser = inlineParserFactory.create(context)

        for (blockParser in allBlockParsers) {
            blockParser.parseInlines(inlineParser)
        }
    }

    /**
     * Add block of type tag as a child of the tip. If the tip can't  accept children, close and finalize it and try
     * its parent, and so on til we find a block that can accept children.
     */
    private func addChild(blockParser: AbstractBlockParser): AbstractBlockParser {
        while (!getActiveBlockParser().canContain(blockParser.getBlock())) {
            finalize(getActiveBlockParser())
        }

        getActiveBlockParser().getBlock().appendChild(blockParser.getBlock())
        activateBlockParser(blockParser)

        return blockParser
    }

    private func activateBlockParser(blockParser: AbstractBlockParser): Unit {
        activeBlockParsers.add(blockParser)
        allBlockParsers.add(blockParser)
    }

    private func deactivateBlockParser(): Unit {
        activeBlockParsers.remove(at: activeBlockParsers.size - 1)
    }

    private func prepareActiveBlockParserForReplacement(): Unit {
        let oldParser: AbstractBlockParser = getActiveBlockParser()
        deactivateBlockParser()
        for (i in 0..allBlockParsers.size) {
            if (refEq(allBlockParsers[i], oldParser)) {
                allBlockParsers.remove(at: i)
            }
        }

        if (oldParser is ParagraphParser) {
            var paragraphParser: ParagraphParser = (oldParser as ParagraphParser).getOrThrow()
            addDefinitionsFrom(paragraphParser)
        }

        oldParser.getBlock().unlink()
    }

    /**
     * blocks Finalize
     */
    private func finalizeBlocks(blockParsers: ArrayList<AbstractBlockParser>): Unit {
        // for (Int64 i = blockParsers.size() - 1; i >= 0; i--) {
        for (i in blockParsers.size - 1..=0 : -1) {
            var blockParser: AbstractBlockParser = blockParsers[i]
            finalize(blockParser)
        }
    }

    private func finalizeBlocks(blockParsers: ArrayList<AbstractBlockParser>, start: Int64, end: Int64): Unit {
        for (i in end..=start : -1) {
            var blockParser: AbstractBlockParser = blockParsers[i]
            finalize(blockParser)
        }
    }

    private func finalizeAndProcess(): Document {
        finalizeBlocks(this.activeBlockParsers)
        this.processInlines()
        return this.documentBlockParser.getBlock()
    }
}

class MatchedBlockParserImpl <: MatchedBlockParser {
    private var matchedBlockParser: AbstractBlockParser

    public MatchedBlockParserImpl(matchedBlockParser: AbstractBlockParser) {
        this.matchedBlockParser = matchedBlockParser
    }

    public func getMatchedBlockParser(): AbstractBlockParser {
        return matchedBlockParser
    }

    public func getParagraphContent(): ?String {
        if (matchedBlockParser is ParagraphParser) {
            var paragraphParser: ParagraphParser = (matchedBlockParser as ParagraphParser).getOrThrow()
            var content: String = paragraphParser.getContentString().toString()
            if (content.size == 0) {
                return None
            }

            return content
        }
        return None
    }
}
