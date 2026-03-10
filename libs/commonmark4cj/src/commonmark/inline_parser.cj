/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

package commonmark4cj.commonmark

/**
 * Parser for inline content (text, links, emphasized text, etc).
 */
public interface InlineParser {

    /**
     * @param input the content to parse as inline
     * @param node the node to append resulting nodes to (as children)
     */
    func parse(input: String, node: Node): Unit
}

/**
 * Context for inline parsing.
 */
public interface InlineParserContext {

    /**
     * @return custom delimiter processors that have been configured with {@link Parser.Builder#customDelimiterProcessor(DelimiterProcessor)}
     */
    func getCustomDelimiterProcessors(): ArrayList<DelimiterProcessor>

    /**
     * Look up a {@link LinkReferenceDefinition} for a given label.
     *
     * @param label the link label to look up
     * @return the definition if one exists, {@code null} otherwise
     */
    func getLinkReferenceDefinition(label: String): ?LinkReferenceDefinition

    /**
     * @return custom inline content parsers that have been configured with
     * {@link Parser.Builder#customInlineContentParserFactory(InlineContentParserFactory)}
     */
    func getCustomInlineContentParserFactories(): ArrayList<InlineContentParserFactory>

    /**
     * @return custom link processors that have been configured with {@link Parser.Builder#linkProcessor}.
     */
    func getCustomLinkProcessors(): ArrayList<LinkProcessor>

    /**
     * @return custom link markers that have been configured with {@link Parser.Builder#linkMarker}.
     */
    func getCustomLinkMarkers(): HashSet<Rune>
}

public interface InlineParserFactory {
    func create(inlineParserContext: InlineParserContext): InlineParser
}

class InlineParserContextImpl <: InlineParserContext {
    private var delimiterProcessors: ArrayList<DelimiterProcessor>
    var linkReferenceDefinitions: HashMap<String, LinkReferenceDefinition>
    private let inlineContentParserFactories: ArrayList<InlineContentParserFactory>
    private let linkProcessors: ArrayList<LinkProcessor>
    private let linkMarkers: HashSet<Rune>

    public init(
        inlineContentParserFactories: ArrayList<InlineContentParserFactory>,
        delimiterProcessors: ArrayList<DelimiterProcessor>,
        linkReferenceDefinitions: HashMap<String, LinkReferenceDefinition>,
        linkProcessors: ArrayList<LinkProcessor>,
        linkMarkers: HashSet<Rune>
    ) {
        this.inlineContentParserFactories = inlineContentParserFactories
        this.delimiterProcessors = delimiterProcessors
        this.linkReferenceDefinitions = linkReferenceDefinitions
        this.linkProcessors = linkProcessors
        this.linkMarkers = linkMarkers
    }

    public override func getCustomDelimiterProcessors(): ArrayList<DelimiterProcessor> {
        return delimiterProcessors
    }

    public override func getLinkReferenceDefinition(label: String): ?LinkReferenceDefinition {
        return linkReferenceDefinitions.get(Escaping.normalizeLabelContent(label))
    }

    public func getCustomInlineContentParserFactories(): ArrayList<InlineContentParserFactory> {
        return inlineContentParserFactories
    }

    public func getCustomLinkProcessors(): ArrayList<LinkProcessor> {
        return linkProcessors
    }

    public func getCustomLinkMarkers(): HashSet<Rune> {
        return linkMarkers
    }

    var ctxCalc: ?InlineParserContextCalc = None
    func calc(): Unit {
        if (ctxCalc.isNone()) {
            ctxCalc = InlineParserContextCalc(this)
        }
    }
}

public class InlineParserV1Factory <: InlineParserFactory {
    public override func create(inlineParserContext: InlineParserContext): InlineParser {
        return InlineParserImpl(inlineParserContext)
    }
}

class InlineParserImpl <: InlineParser {
    private static let HTMLCOMMENT: String = "<!---->|<!--(?:-?[^>-])(?:-?[^-])*-->"
    private static let PROCESSINGINSTRUCTION: String = "[<][?].*?[?][>]"
    private static let DECLARATION: String = "<![A-Z]+\\s+[^>]*>"
    private static let CDATA: String = "<!\\[CDATA\\[[\\s\\S]*?\\]\\]>"
    private static let HTMLTAG: String = "(?:" + Parsing.OPENTAG + "|" + Parsing.CLOSETAG + "|" + HTMLCOMMENT + "|" +
        PROCESSINGINSTRUCTION + "|" + DECLARATION + "|" + CDATA + ")"

    private static let ASCII_PUNCTUATION: String = ##"!"#\$%&'\(\)\*\+,\-\./:;<=>\?@\[\\\]\^_`\{\|\}~"##
    private static let PUNCTUATION: Regex = Regex("^[${ASCII_PUNCTUATION}]")

    private static let HTML_TAG: Regex = Regex("^" + HTMLTAG, IgnoreCase)

    // private static let ESCAPABLE: Regex = Regex("^" + Escaping.ESCAPABLE)

    private static let ENTITY_HERE: Regex = Regex("^" + Escaping.ENTITY, IgnoreCase)

    private static let TICKS: Regex = Regex("`+")

    private static let TICKS_HERE: Regex = Regex("^`+")

    private static let EMAIL_AUTOLINK: Regex = Regex(
        "^<([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>")

    private static let AUTOLINK: Regex = Regex("^<[a-zA-Z][a-zA-Z0-9.+-]{1,31}:[^<>\u{0001}-\u{0020}]*>")

    private static let SPNL: Regex = Regex("^ *(?:\n *)?")

    private static let UNICODE_WHITESPACE_CHAR: Regex = Regex("^[\t\r\n\f ]")

    private static let WHITESPACE: Regex = Regex("\\s+")

    private static let FINAL_SPACE: Regex = Regex(" *$")

    private var specialCharacters: BitSet
    private var delimiterCharacters: BitSet
    private var delimiterProcessors: HashMap<Rune, DelimiterProcessor>
    private var context: InlineParserContext

    private var input: String = ""
    private var index: Int64 = 0

    /**
     * Top delimiter (emphasis, strong emphasis or custom emphasis). (Brackets are on a separate stack, different
     * from the algorithm described in the spec.)
     */
    private var lastDelimiter: ?Delimiter = None

    /**
     * Top opening bracket (<code>[</code> or <code>![)</code>).
     */
    private var lastBracket: ?Bracket = None

    public init(inlineParserContext: InlineParserContext) {
        this.delimiterProcessors = calculateDelimiterProcessors(inlineParserContext.getCustomDelimiterProcessors())
        this.delimiterCharacters = calculateDelimiterCharacters(
            HashSet<Rune>(this.delimiterProcessors.keys().toArray()))
        this.specialCharacters = calculateSpecialCharacters(delimiterCharacters)

        this.context = inlineParserContext
    }

    private static func calculateDelimiterCharacters(characters: HashSet<Rune>): BitSet {
        var bitSet: BitSet = BitSet(characters.size)
        for (i in characters) {
            bitSet.set(Int64(UInt32(i)))
        }
        return bitSet
    }

    private static func calculateSpecialCharacters(delimiterCharacters: BitSet): BitSet {
        var bitSet: BitSet = BitSet(8)
        bitSet.or(delimiterCharacters)
        bitSet.set(Int64(UInt32(r'\n')))
        bitSet.set(Int64(UInt32(r'`')))
        bitSet.set(Int64(UInt32(r'[')))
        bitSet.set(Int64(UInt32(r']')))
        bitSet.set(Int64(UInt32(r'\\')))
        bitSet.set(Int64(UInt32(r'!')))
        bitSet.set(Int64(UInt32(r'<')))
        bitSet.set(Int64(UInt32(r'&')))
        return bitSet
    }

    private static func calculateDelimiterProcessors(delimiterProcessors: ArrayList<DelimiterProcessor>): HashMap<Rune,
        DelimiterProcessor> {
        var map: HashMap<Rune, DelimiterProcessor> = HashMap<Rune, DelimiterProcessor>()
        addDelimiterProcessors(
            ArrayList<DelimiterProcessor>([AsteriskDelimiterProcessor(), UnderscoreDelimiterProcessor()]), map)
        addDelimiterProcessors(delimiterProcessors, map)
        return map
    }

    private static func addDelimiterProcessors(
        delimiterProcessors: ArrayList<DelimiterProcessor>,
        hashMap: HashMap<Rune, DelimiterProcessor>
    ): Unit {
        for (delimiterProcessor in delimiterProcessors) {
            let opening: Rune = delimiterProcessor.getOpeningCharacter()
            let closing: Rune = delimiterProcessor.getClosingCharacter()
            if (opening == closing) {
                let old: Option<DelimiterProcessor> = hashMap.get(opening)
                if (old.isSome() && old().getOpeningCharacter() == old().getClosingCharacter()) {
                    var s: StaggeredDelimiterProcessor
                    match (old) {
                        case Some(v: StaggeredDelimiterProcessor) => s = v
                        case _ =>
                            s = StaggeredDelimiterProcessor(opening)
                            s.add(old())
                    }
                    s.add(delimiterProcessor)
                    hashMap.add(opening, s)
                } else {
                    addDelimiterProcessorForChar(opening, delimiterProcessor, hashMap)
                }
            } else {
                addDelimiterProcessorForChar(opening, delimiterProcessor, hashMap)
                addDelimiterProcessorForChar(closing, delimiterProcessor, hashMap)
            }
        }
    }

    private static func addDelimiterProcessorForChar(
        delimiterChar: Rune,
        toAdd: DelimiterProcessor,
        delimiterProcessors: HashMap<Rune, DelimiterProcessor>
    ): Unit {
        let existing: ?DelimiterProcessor = delimiterProcessors.add(delimiterChar, toAdd)
        if (existing.isSome()) {
            throw IllegalArgumentException("Delimiter processor conflict with delimiter char '${delimiterChar}'")
        }
    }

    /**
     * Parse content in block into inline children, using reference map to resolve references.
     */
    public override func parse(content: String, block: Node): Unit {
        let c: String = content.trimAscii()
        reset(c)
        var previous: ?Node = None
        while (true) {
            let node: ?Node = parseInline(previous)
            previous = node
            if (node.isSome()) {
                block.appendChild(node())
            } else {
                break
            }
        }

        processDelimiters(Option<Delimiter>.None)
        mergeChildTextNodes(block)
    }

    func reset(content: String): Unit {
        this.input = content
        this.index = 0
        this.lastDelimiter = None
        this.lastBracket = None
    }

    private func text(text: String): Text {
        return Text(text)
    }

    /**
     * Parse the next inline element in subject, advancing input index.
     * On success, return the new inline node.
     * On failure, return null.
     */
    private func parseInline(previous: ?Node): ?Node {
        let c: Rune = peek()
        if (c == r'\0') {
            return Option<Node>.None
        }

        var node: ?Node = Option<Node>.None
        match (c) {
            case r'\n' => return parseNewline(previous)
            case r'\\' => return parseBackslash()
            case r'`' => node = parseBackticks()
            case r'[' => return parseOpenBracket()
            case r'!' => return parseBang()
            case r']' => return parseCloseBracket()
            case r'<' =>
                node = parseAutolink()
                if (node.isNone()) {
                    node = parseHtmlInline()
                }
            case r'&' => node = parseEntity()
            case _ =>
                let isDelimiter: Bool = delimiterCharacters.get(Int64(UInt32(c)))
                if (isDelimiter) {
                    let delimiterProcessor: DelimiterProcessor = delimiterProcessors.get(c)()
                    node = parseDelimiters(delimiterProcessor, c)
                } else {
                    node = parseString()
                }
        }
        if (node.isSome()) {
            return node
        } else {
            index++
            // When we get here, it's only for a single special character that turned out to not have a special meaning.
            // So we shouldn't have a single surrogate here, hence it should be ok to turn it into a String.
            let literal: String = String(c)
            return text(literal)
        }
    }

    /**
     * If RE matches at current index in the input, advance index and return the match otherwise return null.
     */
    private func matchs(re: Regex): ?String {
        let size: Int64 = input.size
        if (index >= size) {
            return Option<String>.None
        }
        var m: ?MatchData = re.find(input[index..])
        match (m) {
            case Some(d) =>
                index += d.matchPosition().end
                return d.matchString()
            case None => return Option<String>.None
        }
    }

    /**
     * Returns the char at the current input index, or {@code '\0'} in case there are no more characters.
     */
    private func peek(): Rune {
        try {
            if (index < input.size) {
                return Rune.fromUtf8(unsafe { input.rawData() }, index)[0]
            }
        } catch (_) {
            // just in case
        }
        return r'\0'
    }

    /**
     * Parse zero or more space characters, including at most one newline.
     */
    private func spnl(): Unit {
        matchs(SPNL)
    }

    /**
     * Parse a newline. If it was preceded by two spaces, return a hard line break otherwise a soft line break.
     */
    private func parseNewline(previousOption: ?Node): Node {
        index++ // assume we're at a \n

        // Check previous text for trailing spaces.
        // The "endsWith" is an optimization to avoid an RE match in the common case.
        if (previousOption.isSome()) {
            var previous = previousOption()
            if (previous is Text && (previous as Text)().getLiteral().endsWith(" ")) {
                let text: Text = (previous as Text)()
                var literal: String = text.getLiteral()
                var matcher: ?MatchData = FINAL_SPACE.find(literal)
                var spaces: Int64 = 0
                match (matcher) {
                    case Some(s) => spaces = s.matchPosition().end - s.matchPosition().start
                    case None => spaces = 0
                }

                if (spaces > 0) {
                    let literalArr: Array<Rune> = literal.toRuneArray()
                    text.setLiteral(String(literalArr[..(literalArr.size - spaces)]))
                }
                if (spaces >= 2) {
                    return HardLineBreak()
                } else {
                    return SoftLineBreak()
                }
            }
        }
        return SoftLineBreak()
    }

    static let ESCAPABLE_SET: HashSet<Byte> = ##"!"#$%&'()*+,./:;<=>?@[\]^_`{|}~-"##.toArray() |> collectHashSet
    /**
     * Parse a backslash-escaped special character, adding either the escaped  character, a hard line break
     * (if the backslash is followed by a newline), or a literal backslash to the block's children.
     */
    private func parseBackslash(): Node {
        index++
        let inputArr: String = input
        var nodes: Node
        if (peek() == r'\n') {
            nodes = HardLineBreak()
            index++
        } else if (index < inputArr.size && ESCAPABLE_SET.contains(inputArr[index])) {
            nodes = text(inputArr[index..(index + 1)])
            index++
        } else {
            nodes = text("\\")
        }
        return nodes
    }

    /**
     * Attempt to parse backticks, returning either a backtick code span or a literal sequence of backticks.
     */
    private func parseBackticks(): ?Node {
        let tick: String = if (let Some(v) <- matchs(TICKS_HERE)) {
            v
        } else {
            return None
        }
        let afterOpenTicks: Int64 = index
        while (let Some(matched) <- matchs(TICKS)) {
            if (matched == tick) {
                var content = input[afterOpenTicks..(index - tick.size)]
                content = content.replace("\n", " ")
                // spec: If the resulting string both begins and ends with a space character, but does not consist
                // entirely of space characters, a single space character is removed from the front and back.
                if (content.size >= 3 && content[0] == b' ' && content[content.size - 1] == b' ' && Parsing
                    .hasNonSpace(content)) {
                    content = content[1..(content.size - 1)]
                }

                let nodes: Code = Code(content)
                return nodes
            }
        }
        // If we got here, we didn't match a closing backtick sequence.
        index = afterOpenTicks
        return text(tick)
    }

    /**
     * Attempt to parse delimiters like emphasis, strong emphasis or custom delimiters.
     */
    private func parseDelimiters(delimiterProcessor: DelimiterProcessor, delimiterChar: Rune): ?Node {
        let res: ?DelimiterData = scanDelimiters(delimiterProcessor, delimiterChar)
        if (res.isNone()) {
            return Option<Node>.None
        }
        let length: Int64 = res().count
        let startIndex: Int64 = index

        index += length
        let node: Text = text(input[startIndex..index])

        // Add entry to stack for this opener
        lastDelimiter = Delimiter(node, delimiterChar, res().canOpen, res().canClose, lastDelimiter)
        lastDelimiter().length = length
        lastDelimiter().originalLength = length
        if (lastDelimiter().previous.isSome()) {
            lastDelimiter().previous().next = lastDelimiter
        }

        return node
    }

    /**
     * Add open bracket to delimiter stack and add a text node to block's children.
     */
    private func parseOpenBracket(): Node {
        let startIndex: Int64 = index
        index++

        let nodes: Text = text("[")

        // Add entry to stack for this opener
        addBracket(Bracket.link(nodes, startIndex, lastBracket, lastDelimiter))

        return nodes
    }

    /**
     * If next character is [, and ! delimiter to delimiter stack and add a text node to block's children.
     * Otherwise just add a text node.
     */
    private func parseBang(): Node {
        let startIndex: Int64 = index
        index++
        if (peek() == r'[') {
            index++

            let nodes: Text = text("![")

            // Add entry to stack for this opener
            addBracket(Bracket.image(nodes, startIndex + 1, lastBracket, lastDelimiter))

            return nodes
        } else {
            return text("!")
        }
    }

    /*
     * Try to match close bracket against an opening in the delimiter stack. Return either a link or image, or a
     * plain [ character. If there is a matching delimiter, remove it from the delimiter stack.
     */
    private func parseCloseBracket(): Node {
        index++
        let startIndex: Int64 = index

        // Get previous `[` or `![`
        let opener: ?Bracket = lastBracket
        if (opener.isNone()) {
            // No matching opener, just return a literal.
            return text("]")
        }

        if (!opener().allowed) {
            // Matching opener but it's not allowed, just return a literal.
            removeLastBracket()
            return text("]")
        }

        // Check to see if we have a link/image

        var dest: ?String = None
        var titleStr: ?String = None
        var isImageOrLink: Bool = false

        // Maybe a inline link like `[foo](/uri "titleStr")`
        if (peek() == r'(') {
            index++
            let newIndex: Int64 = index
            spnl()
            dest = parseLinkDestination()
            if (dest.isSome()) {
                spnl()
                // titleStr needs a whitespace before
                if (WHITESPACE.matches(input[newIndex..index])) {
                    titleStr = parseLinkTitle()
                    spnl()
                }
                if (peek() == r')') {
                    index++
                    isImageOrLink = true
                } else {
                    index = startIndex
                }
            }
        }

        // Maybe a reference link like `[foo][bar]`, `[foo][]` or `[foo]`
        if (!isImageOrLink) {

            // See if there's a link label like `[bar]` or `[]`
            let beforeLabel: Int64 = index
            parseLinkLabel()
            let labelLength: Int64 = index - beforeLabel
            var ref: ?String = None
            let inputArr: String = input
            if (labelLength > 2) {
                ref = inputArr[beforeLabel..(beforeLabel + labelLength)]
            } else if (!opener().bracketAfter) {
                // If the second label is empty `[foo][]` or missing `[foo]`, then the first label is the reference.
                // But it can only be a reference when there's no (unescaped) bracket in it.
                // If there is, we don't even need to try to look up the reference. This is an optimization.
                ref = inputArr[opener().index..startIndex]
            }

            if (ref.isSome()) {
                let label: String = Escaping.normalizeReference(ref())
                let definition: ?LinkReferenceDefinition = context.getLinkReferenceDefinition(label)
                if (definition.isSome()) {
                    dest = definition().getDestination()
                    titleStr = definition().getTitle()
                    isImageOrLink = true
                }
            }
        }

        if (isImageOrLink) {
            // If we got here, open is a potential opener
            let linkOrImage: Node = if (opener().images) {
                Image(dest(), titleStr)
            } else {
                Link(dest(), titleStr)
            }

            var node: ?Node = opener().node.getNext()
            while (let Some(v) <- node) {
                node = v.getNext()
                linkOrImage.appendChild(v)
            }

            // Process delimiters such as emphasis inside link/image
            processDelimiters(opener().previousDelimiter)
            mergeChildTextNodes(linkOrImage)
            // We don't need the corresponding text node anymore, we turned it into a link/image node
            opener().node.unlink()
            removeLastBracket()

            // Links within links are not allowed. We found this link, so there can be no other link around it.
            if (!opener().images) {
                var bracket: ?Bracket = lastBracket
                while (bracket.isSome()) {
                    if (!bracket().images) {
                        // Disallow link opener. It will still get matched, but will not result in a link.
                        bracket().allowed = false
                    }
                    bracket = bracket().previous
                }
            }

            return linkOrImage
        } else { // no link or image
            index = startIndex
            removeLastBracket()

            return text("]")
        }
    }

    private func addBracket(bracket: Bracket): Unit {
        if (lastBracket.isSome()) {
            lastBracket().bracketAfter = true
        }
        lastBracket = bracket
    }

    private func removeLastBracket(): Unit {
        lastBracket = lastBracket().previous
    }

    /**
     * Attempt to parse link destination, returning the string or null if no match.
     */
    private func parseLinkDestination(): ?String {
        let afterDest: Int64 = LinkScanner.scanLinkDestination(input, index)
        if (afterDest == -1) {
            return None
        }

        var dest: ?String = None
        let inputArr: String = input
        if (peek() == r'<') {
            // chop off surrounding <..>:
            dest = inputArr[(index + 1)..(afterDest - 1)]
        } else {
            dest = inputArr[index..afterDest]
        }

        index = afterDest
        return Escaping.unescapeString(dest())
    }

    /**
     * Attempt to parse link titleStr (sans quotes), returning the string or null if no match.
     */
    private func parseLinkTitle(): ?String {
        let afterTitle: Int64 = LinkScanner.scanLinkTitle(input, index)
        if (afterTitle == -1) {
            return None
        }

        // chop off ', " or parens
        let titleStr: String = input[(index + 1)..(afterTitle - 1)]
        index = afterTitle
        return Escaping.unescapeString(titleStr)
    }

    /**
     * Attempt to parse a link label, returning number of characters parsed.
     */
    func parseLinkLabel(): Int64 {
        let inputArr: String = input
        if (index >= inputArr.size || inputArr[index] != b'[') {
            return 0
        }

        let startContent: Int64 = index + 1
        let endContent: Int64 = LinkScanner.scanLinkLabelContent(input, startContent)
        // spec: A link label can have at most 999 characters inside the square brackets.
        let contentLength: Int64 = endContent - startContent
        if (endContent == -1 || contentLength > 999) {
            return 0
        }
        if (endContent >= inputArr.size || inputArr[endContent] != b']') {
            return 0
        }
        index = endContent + 1
        return contentLength + 2
    }

    /**
     * Attempt to parse an autolink (URL or email in pointy brackets).
     */
    private func parseAutolink(): ?Node {
        if (let Some(m) <- matchs(EMAIL_AUTOLINK)) {
            let dest: String = m[1..(m.size - 1)]
            let node: Link = Link("mailto:${dest}", None)
            node.appendChild(Text(dest))
            return node
        } else if (let Some(m) <- matchs(AUTOLINK)) {
            let dest: String = m[1..(m.size - 1)]
            let node: Link = Link(dest, None)
            node.appendChild(Text(dest))
            return node
        } else {
            return None
        }
    }

    /**
     * Attempt to parse inline HTML.
     */
    private func parseHtmlInline(): ?Node {
        let m: ?String = matchs(HTML_TAG)
        if (m.isSome()) {
            var node: HtmlInline = HtmlInline(m())
            return node
        } else {
            return Option<Node>.None
        }
    }

    /**
     * Attempt to parse a HTML style entity.
     */
    private func parseEntity(): ?Node {
        var m: ?String = Option<String>.None
        m = matchs(ENTITY_HERE)
        if (m.isSome()) {
            return text(Html5Entities.entityToString(m()))
        } else {
            return Option<Node>.None
        }
    }

    /**
     * Parse a run of ordinary characters, or a single character with a special meaning in markdown, as a plain string.
     */
    private func parseString(): ?Node {
        let begin: Int64 = index
        while (index != input.size) {
            var i = Int64(input[index])
            if (specialCharacters.get(i)) {
                break
            }
            index++
        }
        if (begin != index) {
            return text(input[begin..index])
        } else {
            return Option<Node>.None
        }
    }

    /**
     * Scan a sequence of characters with code delimiterChar, and return information about the number of delimiters
     * and whether they are positioned such that they can open and/or close emphasis or strong emphasis.
     *
     * @return information about delimiter run, or {@code null}
     */
    private func scanDelimiters(delimiterProcessor: DelimiterProcessor, delimiterChar: Rune): ?DelimiterData {
        let startIndex: Int64 = index

        var delimiterCount: Int64 = 0
        while (peek() == delimiterChar) {
            delimiterCount++
            index += Rune.utf8Size(delimiterChar)
        }

        if (delimiterCount < delimiterProcessor.getMinLength()) {
            index = startIndex
            return Option<DelimiterData>.None
        }
        let before: String = if (startIndex == 0) {
            "\n"
        } else {
            let (c, _) = Rune.getPreviousFromUtf8(unsafe { input.rawData() }, startIndex)
            c.toString()
        }

        let charAfter: Rune = peek()
        let after: String = if (charAfter == r'\0') {
            "\n"
        } else {
            String(charAfter)
        }

        // We could be more lazy here, in most cases we don't need to do every match case.
        let beforeIsPunctuation: Bool = PUNCTUATION.matches(before)
        let beforeIsWhitespace: Bool = UNICODE_WHITESPACE_CHAR.matches(before)
        let afterIsPunctuation: Bool = PUNCTUATION.matches(after)
        let afterIsWhitespace: Bool = UNICODE_WHITESPACE_CHAR.matches(after)

        let leftFlanking: Bool = !afterIsWhitespace && (!afterIsPunctuation || beforeIsWhitespace || beforeIsPunctuation)
        let rightFlanking: Bool = !beforeIsWhitespace && (!beforeIsPunctuation || afterIsWhitespace || afterIsPunctuation)
        var isCanOpen: Bool
        var isCanClose: Bool
        if (delimiterChar == r'_') {
            isCanOpen = leftFlanking && (!rightFlanking || beforeIsPunctuation)
            isCanClose = rightFlanking && (!leftFlanking || afterIsPunctuation)
        } else {
            isCanOpen = leftFlanking && delimiterChar == delimiterProcessor.getOpeningCharacter()
            isCanClose = rightFlanking && delimiterChar == delimiterProcessor.getClosingCharacter()
        }

        index = startIndex
        return DelimiterData(delimiterCount, isCanOpen, isCanClose)
    }

    private func processDelimiters(stackBottom: ?Delimiter): Unit {
        var openersBottom: HashMap<Rune, ?Delimiter> = HashMap<Rune, ?Delimiter>()

        // find first closer above stackBottom:
        var closer: ?Delimiter = lastDelimiter
        while (closer.isSome() && closer().previous != stackBottom) {
            closer = closer().previous
        }
        // move forward, looking for closers, and handling each
        while (closer.isSome()) {
            let delimiterChar: Rune = closer().delimiterChar

            var delimiterProcessor: ?DelimiterProcessor = delimiterProcessors.get(delimiterChar)
            if (!(closer().canClose()) || delimiterProcessor.isNone()) {
                closer = closer().next
                continue
            }

            let openingDelimiterChar: Rune = delimiterProcessor().getOpeningCharacter()

            // Found delimiter closer. Now look back for first matching opener.
            var useDelims: Int64 = 0
            var openerFound: Bool = false
            var potentialOpenerFound: Bool = false
            var opener: ?Delimiter = closer().previous
            while (opener.isSome() && opener != stackBottom && opener != (openersBottom.get(delimiterChar) ?? None)) {
                if (opener().canOpen() && (opener().delimiterChar == openingDelimiterChar)) {
                    potentialOpenerFound = true
                    useDelims = delimiterProcessor().getDelimiterUse(opener(), closer())
                    if (useDelims > 0) {
                        openerFound = true
                        break
                    }
                }
                opener = opener().previous
            }

            if (!openerFound) {
                if (!potentialOpenerFound) {
                    /*
                     Set lower bound for future searches for openers.
                     Only do this when we didn't even have a potential opener
                     (one that matches the character and can open).
                     If an opener was rejected because of the number of delimiters
                     (e.g. because of the "multiple of 3" rule),
                     we want to consider it next time because the number
                     of delimiters can change as we continue processing.
                     */
                    openersBottom.add(delimiterChar, closer().previous)
                    if (closer.isSome() && !closer().canOpen()) {
                        // We can remove a closer that can't be an opener,
                        // once we've seen there's no matching opener:
                        removeDelimiterKeepNode(closer())
                    }
                }
                closer = closer().next
                continue
            }

            var openerNode: Text = opener().node
            var closerNode: Text = closer().node

            // Remove number of used delimiters from stack and inline nodes.
            opener().length -= useDelims
            closer().length -= useDelims
            let openerNodeGetLiteralArr: String = openerNode.getLiteral()
            let closerNodeGetLiteralArr: String = closerNode.getLiteral()
            openerNode.setLiteral((openerNodeGetLiteralArr[0..(openerNodeGetLiteralArr.size - useDelims)]))
            closerNode.setLiteral(closerNodeGetLiteralArr[0..(closerNodeGetLiteralArr.size - useDelims)])

            removeDelimitersBetween(opener(), closer())
            // The delimiter processor can re-parent the nodes between opener and closer,
            // so make sure they're contiguous already. Exclusive because we want to keep opener/closer themselves.
            mergeTextNodesBetweenExclusive(openerNode, closerNode)
            delimiterProcessor().process(openerNode, closerNode, useDelims)

            // No delimiter characters left to process, so we can remove delimiter and the now empty node.
            if (opener().length == 0) {
                removeDelimiterAndNode(opener())
            }

            if (let Some(v) <- closer && v.length == 0) {
                closer = v.next
                removeDelimiterAndNode(v)
            }
        }

        // remove all delimiters
        while (lastDelimiter.isSome() && lastDelimiter != stackBottom) {
            removeDelimiterKeepNode(lastDelimiter())
        }
    }

    private func removeDelimitersBetween(opener: Delimiter, closer: Delimiter): Unit {
        var delimiter: ?Delimiter = closer.previous
        while (let Some(v) <- delimiter && v != opener) {
            delimiter = v.previous
            removeDelimiterKeepNode(v)
        }
    }

    /**
     * Remove the delimiter and the corresponding text node. For used delimiters, e.g. `*` in `*foo*`.
     */
    private func removeDelimiterAndNode(delim: Delimiter): Unit {
        var node: Text = delim.node
        node.unlink()
        removeDelimiter(delim)
    }

    /**
     * Remove the delimiter but keep the corresponding node as text. For unused delimiters such as `_` in `foo_bar`.
     */
    private func removeDelimiterKeepNode(delim: Delimiter): Unit {
        removeDelimiter(delim)
    }

    private func removeDelimiter(delim: Delimiter): Unit {
        if (delim.previous.isSome()) {
            delim.previous().next = delim.next
        }
        if (delim.next.isNone()) {
            // top of stack
            lastDelimiter = delim.previous
        } else {
            delim.next().previous = delim.previous
        }
    }

    private func mergeTextNodesBetweenExclusive(fromNode: Node, toNode: Node): Unit {
        // No nodes between them
        if (fromNode == toNode || fromNode.getNext() == toNode) {
            return
        }

        mergeTextNodesInclusive(fromNode.getNext(), toNode.getPrevious())
    }

    private func mergeChildTextNodes(node: Node): Unit {
        // No children or just one child node, no need for merging
        if (node.getFirstChild() == node.getLastChild()) {
            return
        }

        mergeTextNodesInclusive(node.getFirstChild(), node.getLastChild())
    }

    private func mergeTextNodesInclusive(fromNode: ?Node, toNode: ?Node): Unit {
        var first: ?Text = None
        var last: ?Text = None
        var length: Int64 = 0

        var node: ?Node = fromNode
        while (node.isSome()) {
            match (node) {
                case Some(text: Text) =>
                    if (first.isNone()) {
                        first = text
                    }
                    length += text.getLiteral().size
                    last = text
                case _ =>
                    mergeIfNeeded(first, last, length)
                    first = Option<Text>.None
                    last = Option<Text>.None
                    length = 0
            }

            if (node == toNode) {
                break
            }
            node = node().getNext()
        }

        mergeIfNeeded(first, last, length)
    }

    private func mergeIfNeeded(first: ?Text, last: ?Text, textLength: Int64): Unit {
        if (first.isSome() && last.isSome() && first != last) {
            var sb: StringBuilder = StringBuilder(textLength)
            sb.append(first().getLiteral())
            var node: ?Node = first().getNext()
            let stop: ?Node = last().getNext()
            while (node != stop) {
                match(node) {
                    case Some(v: Text) =>
                        sb.append(v.getLiteral())
                        var unlink: Node = v
                        node = v.getNext()
                        unlink.unlink()
                    case _ => ()
                }
            }
            let literal: String = sb.toString()
            first().setLiteral(literal)
        }
    }
}

class DelimiterData {
    let count: Int64
    let canClose: Bool
    let canOpen: Bool

    init(count: Int64, canOpen: Bool, canClose: Bool) {
        this.count = count
        this.canOpen = canOpen
        this.canClose = canClose
    }
}
