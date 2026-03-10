/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

package commonmark4cj.commonmark

public abstract class AbstractBlockParser <: BlockParser {
    public open func isContainer(): Bool {
        return false
    }

    public open func canHaveLazyContinuationLines(): Bool {
        return false
    }

    public open func canContain(_: Block): Bool {
        return false
    }

    public open func addLine(_: String): Unit {}

    public open func closeBlock(): Unit {}

    public open func parseInlines(_: InlineParser): Unit {}
}

public abstract class AbstractBlockParserFactory <: BlockParserFactory {}

/* BlockContinue */
public open class BlockContinue {
    protected init() {}

    public static func none(): Option<BlockContinue> {
        return None
    }

    public static func atIndex(newIndex: Int64): BlockContinue {
        return BlockContinueImpl(newIndex, -1, false)
    }

    public static func atColumn(newColumn: Int64): BlockContinue {
        return BlockContinueImpl(-1, newColumn, false)
    }

    public static func finished(): BlockContinue {
        return BlockContinueImpl(-1, -1, true)
    }
}

/**
 * Parser for a specific block node.
 *
 * Implementations should subclass {@link AbstractBlockParser} instead of implementing this directly.
 */
public interface BlockParser {
    /**
     * Return true if the block that is parsed is a container (contains other blocks), or false if it's a leaf.
     */
    func isContainer(): Bool

    /**
     * Return true if the block can have lazy continuation lines.
     *
     * Lazy continuation lines are lines that were rejected by this {@link #tryContinue(ParserState)} but didn't match
     * any other block parsers either.
     *
     * If true is returned here, those lines will get added via {@link #addLine(CharSequence)}. For false, the block is
     * closed instead.
     */
    func canHaveLazyContinuationLines(): Bool

    func canContain(childBlock: Block): Bool

    func getBlock(): Block

    func tryContinue(parserState: ParserState): Option<BlockContinue>

    func addLine(line: String): Unit

    func closeBlock(): Unit

    func parseInlines(inlineParser: InlineParser): Unit
}

/**
 * Parser factory for a block node for determining when a block starts.
 *
 * Implementations should subclass {@link BlockParserFactory} instead of implementing this directly.
 */
public interface BlockParserFactory {
    func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart>
}

/**
 * Result object for starting parsing of a block, see static methods for constructors.
 */
public abstract class BlockStart {
    protected init() {
    }

    public static func none(): Option<BlockStart> {
        return None
    }

    public static func of4Cj(blockParsers: Array<AbstractBlockParser>): BlockStart {
        return BlockStartImpl(blockParsers)
    }

    public func atIndex(newIndex: Int64): BlockStart

    public func atColumn(newColumn: Int64): BlockStart

    public func replaceActiveBlockParser(): BlockStart
}

/**
 * Open block parser that was last matched during the continue phase. This is different from the currently active
 * block parser, as an unmatched block is only closed when a new block is started.
 * This interface is not intended to be implemented by clients.
 */
public interface MatchedBlockParser {
    func getMatchedBlockParser(): AbstractBlockParser

    /**
     * Returns the current content of the paragraph if the matched block is a paragraph. The content can be multiple
     * lines separated by {@code '\n'}.
     *
     * @return paragraph content or {@code null}
     */
    func getParagraphContent(): ?String
}

/**
 * State of the parser that is used in block parsers.
 * This interface is not intended to be implemented by clients.
 */
public interface ParserState {

    /**
     * @return the current line
     */
    func getLine(): String
    func getNextLine(): String

    /**
     * @return the current index within the line (0-based)
     */
    func getIndex(): Int64

    /**
     * @return the index of the next non-space character starting from {@link #getIndex()} (may be the same) (0-based)
     */
    func getNextNonSpaceIndex(): Int64

    /**
     * The column is the position within the line after tab characters have been processed as 4-space tab stops.
     * If the line doesn't contain any tabs, it's the same as the {@link #getIndex()}. If the line starts with a tab,
     * followed by text, then the column for the first character of the text is 4 (the index is 1).
     *
     * @return the current column within the line (0-based)
     */
    func getColumn(): Int64

    /**
     * @return the indentation in columns (either by spaces or tab stop of 4), starting from {@link #getColumn()}
     */
    func getIndent(): Int64

    /**
     * @return true if the current line is blank starting from the index
     */
    func isBlank(): Bool

    /**
     * @return the deepest open block parser
     */
    func getActiveBlockParser(): AbstractBlockParser
}

class BlockContent {
    private var sb: StringBuilder

    private var lineCount: Int64 = 0

    public init() {
        sb = StringBuilder()
    }

    public init(content: String) {
        sb = StringBuilder(content)
    }

    public func add(line: String): Unit {
        if (lineCount != 0) {
            sb.append('\n')
        }
        sb.append(line)
        lineCount++
    }

    public func getString(): String {
        return sb.toString()
    }

    public func reset(): Unit {
        sb.reset()
    }
}

public class BlockContinueImpl <: BlockContinue {
    private var newIndex: Int64
    private var newColumn: Int64
    private var finalize: Bool

    public init(newIndex: Int64, newColumn: Int64, finalize: Bool) {
        this.newIndex = newIndex
        this.newColumn = newColumn
        this.finalize = finalize
    }

    public func getNewIndex(): Int64 {
        return newIndex
    }

    public func getNewColumn(): Int64 {
        return newColumn
    }

    public func isFinalize(): Bool {
        return finalize
    }
}

class BlockQuoteParser <: AbstractBlockParser {
    private var block: BlockQuote = BlockQuote()

    public func isContainer(): Bool {
        return true
    }

    public func canContain(_: Block): Bool {
        return true
    }

    public func getBlock(): BlockQuote {
        return block
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        var nextNonSpace: Int64 = state.getNextNonSpaceIndex()
        if (isMarker(state, nextNonSpace)) {
            var newColumn: Int64 = state.getColumn() + state.getIndent() + 1
            // optional following space or tab
            if (Parsing.isSpaceOrTab(state.getLine(), nextNonSpace + 1)) {
                newColumn++
            }
            return BlockContinue.atColumn(newColumn)
        } else {
            return BlockContinue.none()
        }
    }

    public static func isMarker(state: ParserState, index: Int64): Bool {
        var line = state.getLine()
        return state.getIndent() < Parsing.CODE_BLOCK_INDENT && index < line.size && line[index] == b'>'
    }
}

public class BlockQuoteParserFactory <: BlockParserFactory {
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart> {
        var nextNonSpace: Int64 = state.getNextNonSpaceIndex()
        if (BlockQuoteParser.isMarker(state, nextNonSpace)) {
            var newColumn: Int64 = state.getColumn() + state.getIndent() + 1
            // optional following space or tab
            if (Parsing.isSpaceOrTab(state.getLine(), nextNonSpace + 1)) {
                newColumn++
            }
            return (BlockStart.of4Cj(BlockQuoteParser()) as BlockStartImpl).getOrThrow().atColumn(newColumn)
        } else {
            return BlockStart.none()
        }
    }
}

class BlockStartImpl <: BlockStart {
    private var blockParsers: Array<AbstractBlockParser>
    private var newIndex: Int64 = -1
    private var newColumn: Int64 = -1
    private var replaceActiveBlockParserFlg: Bool = false

    public init(blockParsers: Array<AbstractBlockParser>) {
        this.blockParsers = blockParsers
    }

    @Frozen
    public func getBlockParsers(): Array<AbstractBlockParser> {
        return blockParsers
    }

    public func getNewIndex(): Int64 {
        return newIndex
    }

    public func getNewColumn(): Int64 {
        return newColumn
    }

    public func isReplaceActiveBlockParser(): Bool {
        return replaceActiveBlockParserFlg
    }

    public func atIndex(newIndex: Int64): BlockStart {
        this.newIndex = newIndex
        return this
    }

    public func atColumn(newColumn: Int64): BlockStart {
        this.newColumn = newColumn
        return this
    }

    public func replaceActiveBlockParser(): BlockStart {
        this.replaceActiveBlockParserFlg = true
        return this
    }
}

class DocumentBlockParser <: AbstractBlockParser {
    private var document: Document = Document()

    public func isContainer(): Bool {
        return true
    }

    public func canContain(_: Block): Bool {
        return true
    }

    public func getBlock(): Document {
        return document
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        return BlockContinue.atIndex(state.getIndex())
    }

    public func addLine(_: String): Unit {}
}

class FencedCodeBlockParser <: AbstractBlockParser {
    public var block: FencedCodeBlock = FencedCodeBlock()

    private var firstLine: ?String = None
    private var otherLines: StringBuilder = StringBuilder(STRINGBUILDER_CAPACITY)

    public init(fenceChar: Rune, fenceLength: Int64, fenceIndent: Int64) {
        block.setFenceChar(fenceChar)
        block.setFenceLength(fenceLength)
        block.setFenceIndent(fenceIndent)
    }

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        var nextNonSpace: Int64 = state.getNextNonSpaceIndex()
        var newIndex = state.getIndex()
        var line = state.getLine()
        var closing: Bool = state.getIndent() < Parsing.CODE_BLOCK_INDENT && isClosing(line, nextNonSpace)
        if (closing) {
            // closing fence - we're at end of line, so we can finalize now
            return BlockContinue.finished()
        } else {
            // skip optional spaces of fence indent
            var i: Int64 = block.getFenceIndent()
            var length: Int64 = line.size
            while (i > 0 && newIndex < length && line[newIndex] == b' ') {
                newIndex++
                i--
            }
        }
        return BlockContinue.atIndex(newIndex)
    }

    public func addLine(line: String): Unit {
        if (firstLine.isNone()) {
            firstLine = line
        } else {
            otherLines.append(line)
            otherLines.append('\n')
        }
    }

    public func closeBlock(): Unit {
        // first line becomes info string
        block.setInfo(Escaping.unescapeString(firstLine().trimAscii()))
        block.setLiteral(otherLines.toString())
    }

    // spec: A code fence is a sequence of at least three consecutive backtick characters (`) or tildes (~). (Tildes and
    // backticks cannot be mixed.)
    public static func checkOpener(line: String, index: Int64, indent: Int64): Option<FencedCodeBlockParser> {
        var backticks: Int64 = 0
        var tildes: Int64 = 0
        var length: Int64 = line.size
        var i: Int64 = index
        while(i < length) {
            match(line[i]) {
                case '`' => backticks++
                case '~' => tildes++
                case _ => break
            }
            i++
        }

        if (backticks >= 3 && tildes == 0) {
            // spec: If the info string comes after a backtick fence, it may not contain any backtick characters.
            if (Parsing.find(b'`', line, index + backticks) != -1) {
                return None
            }
            return FencedCodeBlockParser(r'`', backticks, indent)
        } else if (tildes >= 3 && backticks == 0) {
            // spec: Info strings for tilde code blocks can contain backticks and tildes
            return FencedCodeBlockParser(r'~', tildes, indent)
        } else {
            return None
        }
    }

    // spec: The content of the code block consists of all subsequent lines, until a closing code fence of the same type
    // as the code block began with (backticks or tildes), and with at least as many backticks or tildes as the opening
    // code fence.
    private func isClosing(line: String, index: Int64): Bool {
        var fenceChar: Byte = UInt8(UInt32(block.getFenceChar()))
        var fenceLength: Int64 = block.getFenceLength()
        var fences: Int64 = Parsing.skip(fenceChar, line, index, line.size) - index
        if (fences < fenceLength) {
            return false
        }
        // spec: The closing code fence [...] may be followed only by spaces, which are ignored.
        var after: Int64 = Parsing.skipSpaceTab(line, index + fences, line.size)
        return after == line.size
    }
}

public class FencedCodeBlockParserFactory <: BlockParserFactory {
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart> {
        var indent: Int64 = state.getIndent()
        if (indent >= Parsing.CODE_BLOCK_INDENT) {
            return BlockStart.none()
        }

        var nextNonSpace: Int64 = state.getNextNonSpaceIndex()
        var blockParser: ?FencedCodeBlockParser = FencedCodeBlockParser.checkOpener(state.getLine(), nextNonSpace,
            indent)
        match (blockParser) {
            case Some(value) => return BlockStart.of4Cj(value).atIndex(nextNonSpace + value.block.getFenceLength())
            case _ => return BlockStart.none()
        }
    }
}

class HeadingParser <: AbstractBlockParser {
    private var block: Heading = Heading()
    private var content: String

    public init(level: Int64, content: String) {
        block.setLevel(level)
        this.content = content
    }

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(_: ParserState): Option<BlockContinue> {
        // In both ATX and Setext headings, once we have the heading markup, there's nothing more to parse.
        return BlockContinue.none()
    }

    public func parseInlines(inlineParser: InlineParser): Unit {
        inlineParser.parse(content, block)
    }

    // spec: An ATX heading consists of a string of characters, parsed as inline content, between an opening sequence of
    // 1–6 unescaped # characters and an optional closing sequence of any number of unescaped # characters. The opening
    // sequence of # characters must be followed by a space or by the end of line. The optional closing sequence of #s
    // must be preceded by a space and may be followed by spaces only.
    public static func getAtxHeading(line: String, index: Int64): Option<HeadingParser> {
        var level: Int64 = Parsing.skip(b'#', line, index, line.size) - index

        if (level == 0 || level > 6) {
            return None
        }

        var start: Int64 = index + level
        if (start >= line.size) {
            // End of line after markers is an empty heading
            return HeadingParser(level, EMPTY_STRING)
        }

        var next = line[start]
        if (!(next == b' ' || next == b'\t')) {
            return None
        }

        var beforeSpace: Int64 = Parsing.skipSpaceTabBackwards(line, line.size - 1, start)
        var beforeHash: Int64 = Parsing.skipBackwards(b'#', line, beforeSpace, start)
        var beforeTrailer: Int64 = Parsing.skipSpaceTabBackwards(line, beforeHash, start)
        var lines: String
        if (beforeTrailer != beforeHash) {
            lines = line[start..beforeTrailer + 1]
            return HeadingParser(level, lines)
        } else {
            lines = line[start..beforeSpace + 1]
            return HeadingParser(level, lines)
        }
    }

    // spec: A setext heading underline is a sequence of = characters or a sequence of - characters, with no more than
    // 3 spaces indentation and any number of trailing spaces.
    public static func getSetextHeadingLevel(line: String, index: Int64): Int64 {
        match (line[index]) {
            case '=' => if (isSetextHeadingRest(line, index + 1, b'=')) {
                return 1
            }
            case '-' => if (isSetextHeadingRest(line, index + 1, b'-')) {
                return 2
            }
            case _ => return 0
        }
        return 0
    }
    private static func isSetextHeadingRest(line: String, index: Int64, marker: Byte): Bool {
        var afterMarker: Int64 = Parsing.skip(marker, line, index, line.size)
        var afterSpace: Int64 = Parsing.skipSpaceTab(line, afterMarker, line.size)
        return afterSpace >= line.size
    }
}

public class HeadingParserFactory <: BlockParserFactory {
    public func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart> {
        if (state.getIndent() >= Parsing.CODE_BLOCK_INDENT) {
            return BlockStart.none()
        }

        var line: String = state.getLine()
        var nextNonSpace: Int64 = state.getNextNonSpaceIndex()
        var atxHeading: Option<HeadingParser> = HeadingParser.getAtxHeading(line, nextNonSpace)
        if (atxHeading.isSome()) {
            return BlockStart.of4Cj([atxHeading.getOrThrow()]).atIndex(line.size)
        }

        var setextHeadingLevel: Int64 = HeadingParser.getSetextHeadingLevel(line, nextNonSpace)
        if (setextHeadingLevel > 0) {
            var paragraph: ?String = matchedBlockParser.getParagraphContent()
            if (paragraph.isSome()) {
                var content: String = paragraph()
                return BlockStart.of4Cj(HeadingParser(setextHeadingLevel, content)).atIndex(line.size).
                    replaceActiveBlockParser()
            }
        }

        return BlockStart.none()
    }
}

class HtmlBlockParser <: AbstractBlockParser {
    public static var BLOCK_PATTERNS: Array<Array<Regex>> = [
        [Regex(""), Regex("")], // not used (no type 0)
        [
            Regex("^<(?:script|pre|style)(?:\\s|>|$)", IgnoreCase),
            Regex("</(?:script|pre|style)>", IgnoreCase)
        ],
        [
            Regex("^<!--"),
            Regex("-->")
        ],
        [
            Regex("^<[?]"),
            Regex("\\?>")
        ],
        [
            Regex("^<![A-Z]"),
            Regex(">")
        ],
        [
            Regex("^<!\\[CDATA\\["),
            Regex("\\]\\]>")
        ],
        [
            Regex(
                "^</?(?:" + "address|article|aside|" + "base|basefont|blockquote|body|" + "caption|center|col|colgroup|" +
                    "dd|details|dialog|dir|div|dl|dt|" + "fieldset|figcaption|figure|footer|form|frame|frameset|" +
                    "h1|h2|h3|h4|h5|h6|head|header|hr|html|" + "iframe|" + "legend|li|link|" + "main|menu|menuitem|" +
                    "nav|noframes|" + "ol|optgroup|option|" + "p|param|" + "section|source|summary|" +
                    "table|tbody|td|tfoot|th|thead|title|tr|track|" + "ul" + ")(?:\\s|[/]?[>]|$)",
                IgnoreCase
            ),
            Regex("") // terminated by blank line
        ],
        [
            Regex("^(?:" + Parsing.OPENTAG + "|" + Parsing.CLOSETAG + ")\\s*$", IgnoreCase),
            Regex("") // terminated by blank line
        ]
    ]

    private var block: HtmlBlock = HtmlBlock()
    private var closingPattern: ?Regex

    private var finished: Bool = false
    private var content: BlockContent = BlockContent()

    public init(closingPattern: Regex) {
        if (closingPattern.string().isEmpty()) {
            this.closingPattern = None
        } else {
            this.closingPattern = closingPattern
        }
    }

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        if (finished) {
            return BlockContinue.none()
        }

        // Blank line ends type 6 and type 7 blocks
        if (state.isBlank() && closingPattern.isNone()) {
            return BlockContinue.none()
        } else {
            return BlockContinue.atIndex(state.getIndex())
        }
    }

    public func addLine(line: String): Unit {
        content.add(line)

        if (closingPattern.isSome() && closingPattern.getOrThrow().matches(line)) {
            finished = true
        }
    }

    public func closeBlock(): Unit {
        block.setLiteral(content.getString())
        content.reset()
    }
}

public class HtmlBlockParserFactory <: BlockParserFactory {
    public func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart> {
        var nextNonSpace: Int64 = state.getNextNonSpaceIndex()
        var line = state.getLine()

        if (state.getIndent() < 4 && line[nextNonSpace] == b'<') {
            for (blockType in 1..8) {
                // Type 7 can not interrupt a paragraph
                if (blockType == 7 && matchedBlockParser.getMatchedBlockParser().getBlock() is Paragraph) {
                    continue
                }
                var opener: Regex = HtmlBlockParser.BLOCK_PATTERNS[blockType][0]
                var closer: Regex = HtmlBlockParser.BLOCK_PATTERNS[blockType][1]
                var matches: Bool = opener.matches(line[nextNonSpace..line.size])
                if (matches) {
                    return BlockStart.of4Cj(HtmlBlockParser(closer)).atIndex(state.getIndex())
                }
            }
        }
        return BlockStart.none();
    }
}

class IndentedCodeBlockParser <: AbstractBlockParser {
    private var block: IndentedCodeBlock = IndentedCodeBlock()
    private var lines: ArrayList<String> = ArrayList<String>()

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        if (state.getIndent() >= Parsing.CODE_BLOCK_INDENT) {
            return BlockContinue.atColumn(state.getColumn() + Parsing.CODE_BLOCK_INDENT)
        } else if (state.isBlank()) {
            return BlockContinue.atIndex(state.getNextNonSpaceIndex())
        } else {
            return BlockContinue.none()
        }
    }

    public func addLine(line: String): Unit {
        lines.add(line)
    }

    public func closeBlock(): Unit {
        var lastNonBlank: Int64 = lines.size - 1
        while (lastNonBlank >= 0) {
            if (!Parsing.isBlank(lines[lastNonBlank])) {
                break
            }
            lastNonBlank--
        }

        var sb: StringBuilder = StringBuilder()
        for (i in 0..lastNonBlank + 1) {
            sb.append(lines[i])
            sb.append('\n')
        }

        var literal: String = sb.toString()
        block.setLiteral(literal)
    }
}

public class IndentedCodeBlockParserFactory <: BlockParserFactory {
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart> {
        // An indented code block cannot interrupt a paragraph.
        if (state.getIndent() >= Parsing.CODE_BLOCK_INDENT && !state.isBlank() &&
            !(state.getActiveBlockParser().getBlock() is Paragraph)) {
            return BlockStart.of4Cj(IndentedCodeBlockParser()).atColumn(state.getColumn() + Parsing.CODE_BLOCK_INDENT)
        } else {
            return BlockStart.none()
        }
    }
}

public enum State {
    // Looking for the start of a definition, i.e. `[`
    | START_DEFINITION
    // Parsing the label, i.e. `foo` within `[foo]`
    | LABEL
    // Parsing the destination, i.e. `/url` in `[foo]: /url`
    | DESTINATION
    // Looking for the start of a title, i.e. the first `"` in `[foo]: /url "title"`
    | START_TITLE
    // Parsing the content of the title, i.e. `title` in `[foo]: /url "title"`
    | TITLE

    // End state, no matter what kind of lines we add, they won't be references
    | PARAGRAPH
}

/**
 * Parser for link reference definitions at the beginning of a paragraph.
 */
public class LinkReferenceDefinitionParser {
    private var state: State = State.START_DEFINITION

    private var paragraph: StringBuilder = StringBuilder(STRINGBUILDER_CAPACITY)
    private var definitions: ArrayList<LinkReferenceDefinition> = ArrayList<LinkReferenceDefinition>()

    private var label: StringBuilder = StringBuilder()
    private var normalizedLabel: String = ""
    private var destination: String = ""
    private var titleDelimiter: Rune = NULL_CHAR
    private var title: StringBuilder = StringBuilder()
    private var referenceValid: Bool = false

    public func parse(line: String): Unit {
        if (paragraph.size != 0) {
            paragraph.append("\n")
        }
        paragraph.append(line)

        var i: Int64 = 0
        while (i < line.size) {
            match (state) {
                case PARAGRAPH =>
                    // We're in a paragraph now. Link reference definitions can only appear at the beginning, so once
                    // we're in a paragraph, there's no going back.
                    return
                case START_DEFINITION => i = startDefinition(line, i)
                case LABEL => i = labelFunc(line, i)
                case DESTINATION => i = destinationFunc(line, i)
                case START_TITLE => i = startTitle(line, i)
                case TITLE => i = titleFunc(line, i)
            }
            // -1 is returned if parsing failed, which means we fall back to treating text as a paragraph.
            if (i == -1) {
                state = State.PARAGRAPH
                return
            }
        }
    }

    func getParagraphContent(): StringBuilder {
        return paragraph
    }

    func getDefinitions(): ArrayList<LinkReferenceDefinition> {
        finishReference()
        return definitions
    }

    public func getState(): State {
        return state
    }

    private func startDefinition(line: String, i: Int64): Int64 {
        var index = Parsing.skipSpaceTab(line, i, line.size)
        if (index >= line.size || line[index] != b'[') {
            return -1
        }

        state = State.LABEL

        var labelStart: Int64 = index + 1
        if (labelStart >= line.size) {
            label.append('\n')
        }

        return labelStart
    }

    private func labelFunc(line: String, i: Int64): Int64 {
        var afterLabel: Int64 = LinkScanner.scanLinkLabelContent(line, i)
        if (afterLabel == -1) {
            return -1
        }

        label.append(line[i..afterLabel])

        if (afterLabel >= line.size) {
            // label might continue on next line
            label.append('\n')
            return afterLabel
        } else if (line[afterLabel] == b']') {
            var colon: Int64 = afterLabel + 1
            // end of label
            if (colon >= line.size || line[colon] != b':') {
                return -1
            }

            // spec: A link label can have at most 999 characters inside the square brackets.
            if (label.size > 999) {
                return -1
            }
            var normalizedLabel: String = Escaping.normalizeLabelContent(label.toString())
            if (normalizedLabel.isEmpty()) {
                return -1
            }
            this.normalizedLabel = normalizedLabel
            state = State.DESTINATION

            return Parsing.skipSpaceTab(line, colon + 1, line.size)
        } else {
            return -1
        }
    }

    private func destinationFunc(line: String, i: Int64): Int64 {
        var index = Parsing.skipSpaceTab(line, i, line.size)
        var afterDestination: Int64 = LinkScanner.scanLinkDestination(line, i)
        if (afterDestination == -1) {
            return -1
        }

        if (line[index] == b'<') {
            destination = line[i + 1..afterDestination - 1]
        } else {
            destination = line[i..afterDestination]
        }

        var afterSpace: Int64 = Parsing.skipSpaceTab(line, afterDestination, line.size)
        if (afterSpace >= line.size) {
            // Destination was at end of line, so this is a valid reference for sure (and maybe a title).
            // If not at end of line, wait for title to be valid first.
            referenceValid = true
            paragraph.reset(capacity: STRINGBUILDER_CAPACITY)
        } else if (afterSpace == afterDestination) {
            // spec: The title must be separated from the link destination by whitespace
            return -1
        }

        state = State.START_TITLE
        return afterSpace
    }

    private func startTitle(line: String, i: Int64): Int64 {
        var index = Parsing.skipSpaceTab(line, i, line.size)
        if (index >= line.size) {
            state = State.START_DEFINITION
            return index
        }

        titleDelimiter = r'\0'
        var c: Byte = line[i]
        if (c == b'"' || c == b'\'') {
            titleDelimiter = Rune(c)
        } else if (c == b'(') {
            titleDelimiter = ')'
        }

        if (titleDelimiter != r'\0') {
            state = State.TITLE
            title = StringBuilder()
            index++
            if (index == line.size) {
                title.append('\n')
            }
        } else {
            finishReference()
            // There might be another reference instead, try that for the same character.
            state = State.START_DEFINITION
        }
        return index
    }

    private func titleFunc(line: String, i: Int64): Int64 {
        var afterTitle: Int64 = LinkScanner.scanLinkTitleContent(line, i, UInt8(UInt32(titleDelimiter)))
        if (afterTitle == -1) {
            // Invalid title, stop
            return -1
        }

        title.append(line[i..afterTitle])

        if (afterTitle >= line.size) {
            // Title still going, continue on next line
            title.append('\n')
            return afterTitle
        }

        var afterTitleDelimiter: Int64 = afterTitle + 1
        var afterSpace: Int64 = Parsing.skipSpaceTab(line, afterTitleDelimiter, line.size)
        if (afterSpace != line.size) {
            // spec: No further non-whitespace characters may occur on the line.
            return -1
        }
        referenceValid = true
        finishReference()
        paragraph.reset(capacity: STRINGBUILDER_CAPACITY)

        // See if there's another definition.
        state = State.START_DEFINITION
        return afterSpace
    }

    private func finishReference(): Unit {
        if (!referenceValid) {
            return
        }

        var d: String = Escaping.unescapeString(destination)
        let t: ?String = if (title.size == 0) {
            None
        } else {
            Escaping.unescapeString(title.toString())
        }
        definitions.add(LinkReferenceDefinition(normalizedLabel, d, t))

        label.reset()
        referenceValid = false
        normalizedLabel = ""
        destination = ""
        title.reset()
    }
}

class ListBlockParser <: AbstractBlockParser {
    private var block: ListBlock

    private var hadBlankLine: Bool = false
    private var linesAfterBlank: Int64 = -1

    public init(block: ListBlock) {
        this.block = block
    }

    public func isContainer(): Bool {
        return true
    }

    public func canContain(childBlock: Block): Bool {
        if (childBlock is ListItem) {
            // Another list item is added to this list block. If the previous line was blank, that means this list block
            // is "loose" (not tight).
            //
            // spec: A list is loose if any of its constituent list items are separated by blank lines
            if (hadBlankLine && linesAfterBlank == 1) {
                block.setTight(false)
                hadBlankLine = false
            }
            return true
        } else {
            return false
        }
    }

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        if (state.isBlank()) {
            hadBlankLine = true
            linesAfterBlank = 0
        } else if (hadBlankLine) {
            linesAfterBlank++
        }
        // List blocks themselves don't have any markers, only list items. So try to stay in the list.
        // If there is a block start other than list item, canContain makes sure that this list is closed.
        return BlockContinue.atIndex(state.getIndex())
    }

    /**
     * Parse a list marker and return data on the marker or null.
     */
    public static func parseList(
        line: String,
        markerIndex: Int64,
        markerColumn: Int64,
        inParagraph: Bool
    ): Option<ListData> {
        var listMarker: ?ListMarkerData = parseListMarker(line, markerIndex)
        if (listMarker.isNone()) {
            return None
        }
        var listBlock: ListBlock = listMarker.getOrThrow().listBlock

        var indexAfterMarker: Int64 = listMarker.getOrThrow().indexAfterMarker
        var markerLength: Int64 = indexAfterMarker - markerIndex
        // marker doesn't include tabs, so counting them as columns directly is ok
        var columnAfterMarker: Int64 = markerColumn + markerLength
        // the column within the line where the content starts
        var contentColumn: Int64 = columnAfterMarker

        // See at which column the content starts if there is content
        var hasContent: Bool = false
        var length: Int64 = line.size
        for (i in indexAfterMarker..length) {
            var c = line[i]
            if (c == b'\t') {
                contentColumn += Parsing.columnsToNextTabStop(contentColumn)
            } else if (c == b' ') {
                contentColumn++
            } else {
                hasContent = true
                break
            }
        }

        if (inParagraph) {
            // If the list item is ordered, the start number must be 1 to interrupt a paragraph.
            if (listBlock is OrderedList && (listBlock as OrderedList).getOrThrow().getStartNumber() != 1) {
                return None
            }
            // Empty list item can not interrupt a paragraph.
            if (!hasContent) {
                return None
            }
        }

        if (!hasContent || (contentColumn - columnAfterMarker) > Parsing.CODE_BLOCK_INDENT) {
            // If this line is blank or has a code block, default to 1 space after marker
            contentColumn = columnAfterMarker + 1
        }

        return ListData(listBlock, contentColumn)
    }

    private static func parseListMarker(line: String, index: Int64): Option<ListMarkerData> {
        var c = line[index]
        // spec: A bullet list marker is a -, +, or * character.
        if (c == b'-' || c == b'+' || c == b'*') {
            if (isSpaceTabOrEnd(line, index + 1)) {
                var bulletList: BulletList = BulletList(Rune(c))
                // bulletList.setBulletMarker(c)
                return ListMarkerData(bulletList, index + 1)
            } else {
                return None
            }
        } else {
            return parseOrderedList(line, index)
        }
    }

    // spec: An ordered list marker is a sequence of 1–9 arabic digits (0-9), followed by either a `.` character or a
    // `)` character.
    private static func parseOrderedList(line: String, index: Int64): Option<ListMarkerData> {
        var digits: Int64 = 0
        var length: Int64 = line.size
        for (i in index..length) {
            var c: Byte = line[i]
            match (c) {
                case '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
                    digits++
                    if (digits > 9) {
                        return None
                    }
                case '.' | ')' => if (digits >= 1 && isSpaceTabOrEnd(line, i + 1)) {
                    var number: String = line[index..i]
                    var orderedList: OrderedList = OrderedList(Int64.parse(number), Rune(c))
                    return ListMarkerData(orderedList, i + 1)
                } else {
                    return None
                }
                case _ => return None
            }
        }
        return None
    }

    private static func isSpaceTabOrEnd(line: String, index: Int64): Bool {
        if (index < line.size) {
            match (line[index]) {
                case ' ' | '\t' => return true
                case _ => return false
            }
        } else {
            return true
        }
    }

    /**
     * Returns true if the two list items are of the same type,
     * with the same delimiter and bullet character. This is used
     * in agglomerating list items into lists.
     */
    public static func listsMatch(a: ListBlock, b: ListBlock): Bool {
        if (a is BulletList && b is BulletList) {
            return equals(
                (a as BulletList).getOrThrow().getBulletMarker(),
                (b as BulletList).getOrThrow().getBulletMarker()
            )
        } else if (a is OrderedList && b is OrderedList) {
            return equals((a as OrderedList).getOrThrow().getDelimiter(), (b as OrderedList).getOrThrow().getDelimiter()
            )
        }
        return false
    }

    private static func equals(a: Option<Rune>, b: Option<Rune>): Bool {
        if (a == None) {
            return b == None
        } else {
            return a == b
        }
    }
}

public class ListBlockParserFactory <: BlockParserFactory {
    public func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart> {
        var matched: AbstractBlockParser = matchedBlockParser.getMatchedBlockParser()

        if (state.getIndent() >= Parsing.CODE_BLOCK_INDENT) {
            return BlockStart.none()
        }
        var markerIndex: Int64 = state.getNextNonSpaceIndex()
        var markerColumn: Int64 = state.getColumn() + state.getIndent()
        var inParagraph: Bool = matchedBlockParser.getParagraphContent().isSome()
        var listData: ?ListData = ListBlockParser.parseList(state.getLine(), markerIndex, markerColumn, inParagraph)
        if (listData.isNone()) {
            return BlockStart.none()
        }

        var newColumn: Int64 = listData.getOrThrow().contentColumn
        var listItemParser: ListItemParser = ListItemParser(newColumn - state.getColumn())

        // prepend the list block if needed
        if (!(matched is ListBlockParser) ||
            !(ListBlockParser.listsMatch((matched.getBlock() as ListBlock).getOrThrow(), listData.getOrThrow().listBlock
        ))) {
            var listBlockParser: ListBlockParser = ListBlockParser(listData.getOrThrow().listBlock)
            // We start out with assuming a list is tight. If we find a blank line, we set it to loose later.
            listData.getOrThrow().listBlock.setTight(true)

            var listBlock: Array<AbstractBlockParser> = [listBlockParser, listItemParser]
            return BlockStart.of4Cj(listBlock).atColumn(newColumn)
        } else {
            var listBlock: Array<AbstractBlockParser> = [listItemParser]
            return BlockStart.of4Cj(listBlock).atColumn(newColumn)
        }
    }
}

class ListData {
    var listBlock: ListBlock
    var contentColumn: Int64

    init(listBlock: ListBlock, contentColumn: Int64) {
        this.listBlock = listBlock
        this.contentColumn = contentColumn
    }
}

class ListMarkerData {
    var listBlock: ListBlock
    var indexAfterMarker: Int64

    init(listBlock: ListBlock, indexAfterMarker: Int64) {
        this.listBlock = listBlock
        this.indexAfterMarker = indexAfterMarker
    }
}

class ListItemParser <: AbstractBlockParser {
    private var block: ListItem = ListItem()

    /**
     * Minimum number of columns that the content has to be indented (relative to the containing block) to be part of
     * this list item.
     */
    private var contentIndent: Int64

    private var hadBlankLine: Bool = false

    public init(contentIndent: Int64) {
        this.contentIndent = contentIndent
    }

    public func isContainer(): Bool {
        return true
    }

    public func canContain(_: Block): Bool {
        if (hadBlankLine) {
            // We saw a blank line in this list item, that means the list block is loose.
            //
            // spec: if any of its constituent list items directly contain two block-level elements with a blank line
            // between them
            if (let Some(parent) <- block.getParent()) {
                if (parent is ListBlock) {
                    (parent as ListBlock).getOrThrow().setTight(false)
                }
            }
        }
        return true
    }

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        if (state.isBlank()) {
            if (block.getFirstChild().isNone()) {
                // Blank line after empty list item
                return BlockContinue.none()
            } else {
                var activeBlock: Block = state.getActiveBlockParser().getBlock()
                // If the active block is a code block, blank lines in it should not affect if the list is tight.
                hadBlankLine = activeBlock is Paragraph || activeBlock is ListItem
                return BlockContinue.atIndex(state.getNextNonSpaceIndex())
            }
        }

        if (state.getIndent() >= contentIndent) {
            return BlockContinue.atColumn(state.getColumn() + contentIndent)
        } else {
            return BlockContinue.none()
        }
    }
}

class ParagraphParser <: AbstractBlockParser {
    private var block: Paragraph = Paragraph()
    private var linkReferenceDefinitionParser: LinkReferenceDefinitionParser = LinkReferenceDefinitionParser()

    public func canHaveLazyContinuationLines(): Bool {
        return true
    }

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(state: ParserState): Option<BlockContinue> {
        if (!state.isBlank()) {
            return BlockContinue.atIndex(state.getIndex())
        } else {
            return BlockContinue.none()
        }
    }

    public func addLine(line: String): Unit {
        linkReferenceDefinitionParser.parse(line)
    }

    public func closeBlock(): Unit {
        if (linkReferenceDefinitionParser.getParagraphContent().size == 0) {
            block.unlink()
        }
    }

    public func parseInlines(inlineParser: InlineParser): Unit {
        var content: String = linkReferenceDefinitionParser.getParagraphContent().toString()
        if (content.size > 0) {
            inlineParser.parse(content, block)
        }
    }

    public func getContentString(): StringBuilder {
        return linkReferenceDefinitionParser.getParagraphContent()
    }

    @Frozen
    public func getDefinitions(): ArrayList<LinkReferenceDefinition> {
        return linkReferenceDefinitionParser.getDefinitions()
    }
}

class ThematicBreakParser <: AbstractBlockParser {
    private var block: ThematicBreak = ThematicBreak()

    public func getBlock(): Block {
        return block
    }

    public func tryContinue(_: ParserState): Option<BlockContinue> {
        // a horizontal rule can never container > 1 line, so fail to match
        return BlockContinue.none()
    }

    // spec: A line consisting of 0-3 spaces of indentation, followed by a sequence of three or more matching -, _, or *
    // characters, each followed optionally by any number of spaces, forms a thematic break.
    public static func isThematicBreak(line: String, index: Int64): Bool {
        var dashes: Int64 = 0
        var underscores: Int64 = 0
        var asterisks: Int64 = 0
        var length: Int64 = line.size
        for (i in index..length) {
            match (line[i]) {
                case '-' => dashes++
                case '_' => underscores++
                case '*' => asterisks++
                case ' ' | '\t' =>
                    // Allowed, even between markers
                    continue
                case _ => return false
            }
        }

        return ((dashes >= 3 && underscores == 0 && asterisks == 0) || (underscores >= 3 && dashes == 0 && asterisks == 0) ||
            (asterisks >= 3 && dashes == 0 && underscores == 0))
    }
}

public class ThematicBreakParserFactory <: BlockParserFactory {
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart> {
        if (state.getIndent() >= 4) {
            return BlockStart.none()
        }
        var nextNonSpace: Int64 = state.getNextNonSpaceIndex()
        var line = state.getLine()
        if (ThematicBreakParser.isThematicBreak(line, nextNonSpace)) {
            return BlockStart.of4Cj(ThematicBreakParser()).atIndex(line.size)
        } else {
            return BlockStart.none()
        }
    }
}
