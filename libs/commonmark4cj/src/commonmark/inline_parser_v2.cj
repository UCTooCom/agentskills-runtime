/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

class DelimiterDataV2 {
    let characters: ArrayList<Text>
    let delimiterNodeOld: Text
    let canClose: Bool
    let canOpen: Bool

    init(delimiterNodeOld: Text, characters: ArrayList<Text>, canOpen: Bool, canClose: Bool) {
        this.delimiterNodeOld = delimiterNodeOld
        this.characters = characters
        this.canOpen = canOpen
        this.canClose = canClose
    }
}

/**
 * A destination and optional title for a link or image.
 */
class DestinationTitle {
    let destination: String
    let title: ?String

    public DestinationTitle(destination: String, title: ?String) {
        this.destination = destination
        this.title = title
    }
}

class InlineParserImplV2 <: InlineParser & InlineParserState {
    private var specialCharacters: BitSet
    private var delimiterProcessors: HashMap<Rune, DelimiterProcessor>
    private var context: InlineParserContext
    private let inlineContentParserFactories: ArrayList<InlineContentParserFactory>
    private let linkProcessors: ArrayList<LinkProcessor>
    private let linkMarkers: BitSet

    private var inlineParsers: HashMap<Rune, ArrayList<(InlineContentParserFactory, InlineContentParser)>> = HashMap()
    private var _scanner: Scanner = unsafe { zeroValue() }
    private var includeSourceSpans: Bool = false
    private var trailingSpaces: Int = 0

    /**
     * Top delimiter (emphasis, strong emphasis or custom emphasis). (Brackets are on a separate stack, different
     * from the algorithm described in the spec.)
     */
    private var lastDelimiter: ?Delimiter = None

    /**
     * Top opening bracket (<code>[</code> or <code>![)</code>).
     */
    private var lastBracket: ?BracketV2 = None

    public init(context: InlineParserContext) {
        let ctx = (context as InlineParserContextImpl).getOrThrow()
        ctx.calc()
        let calc = ctx.ctxCalc.getOrThrow()
        this.context = context
        this.inlineContentParserFactories = calc.inlineContentParserFactories
        this.delimiterProcessors = calc.delimiterProcessors
        this.linkProcessors = calc.linkProcessors
        this.linkMarkers = calc.linkMarkers
        this.specialCharacters = calc.specialCharacters
    }

    @Frozen
    private func createInlineContentParsers(): Unit {
        if (inlineParsers.size == 0) {
            for (factory in inlineContentParserFactories) {
                var parser = factory.create()
                for (c in factory.getTriggerCharacters()) {
                    let arr = inlineParsers.get(c) ??
                        {
                        =>
                        let arr = ArrayList<(InlineContentParserFactory, InlineContentParser)>()
                        inlineParsers.add(c, arr)
                        arr
                    }()
                    arr.add((factory, parser))
                }
            }
        } else {
            for ((_, arr) in inlineParsers) {
                for (i in 0..arr.size) {
                    let (f, p) = arr[i]
                    arr[i] = (f, f.create())
                }
            }
        }
    }

    public func scanner(): Scanner {
        return _scanner
    }

    /**
     * Parse content in block into inline children, appending them to the block node.
     */
    @Frozen
    public override func parse(lines: String, node: Node): Unit {
        let sls = SourceLines.empty()
        for (l in lines.trimAscii().lines()) {
            sls.addLine(SourceLine.of(l, None))
        }
        parse(sls, node)
    }

    @Frozen
    public func parse(lines: SourceLines, block: Node): Unit {
        reset(lines)
        while (true) {
            let nodes = parseInline()
            if (nodes.size == 0) {
                break
            }
            for (node in nodes) {
                block.appendChild(node)
            }
        }

        processDelimiters(Option<Delimiter>.None)
        mergeChildTextNodes(block)
    }

    func reset(lines: SourceLines): Unit {
        this._scanner = Scanner.of(lines)
        this.includeSourceSpans = !lines.getSourceSpans().isEmpty()
        this.trailingSpaces = 0
        this.lastDelimiter = None
        this.lastBracket = None
        this.createInlineContentParsers()
    }

    private func text(sourceLines: SourceLines): Text {
        let text = Text(sourceLines.getContent())
        text.setSourceSpans(sourceLines.getSourceSpans())
        return text
    }

    /**
     * Parse the next inline element in subject, advancing input index.
     * On success, return the new inline node.
     * On failure, return null.
     */
    @Frozen
    private func parseInline(): Array<Node> {
        let c: Rune = _scanner.peek()

        match (c) {
            case '[' => return [parseOpenBracket()]
            case ']' => return [parseCloseBracket()]
            case '\n' => return [parseLineBreak()]
            case '\0' => return []
            case _ => ()
        }

        if (linkMarkers.get(Int64(UInt32(c)))) {
            var markerPosition = _scanner.position()
            var nodes = parseLinkMarker()
            if (nodes.size > 0) {
                return nodes
            }
            // Reset and try other things (e.g. inline parsers below)
            _scanner.setPosition(markerPosition)
        }

        // No inline parser, delimiter or other special handling.
        if (!specialCharacters.get(Int64(UInt32(c)))) {
            return [parseText()]
        }
        let inlineParsers = this.inlineParsers.get(c)
        if (let Some(inlineParsers) <- inlineParsers) {
            let position: SourcePosition = _scanner.position()
            for ((_, inlineParser) in inlineParsers) {
                let parsedInline = inlineParser.tryParse(this)
                if (let Some(parsedInlineImpl) <- (parsedInline as ParsedInlineImpl)) {
                    let node = parsedInlineImpl.getNode()
                    _scanner.setPosition(parsedInlineImpl.getPosition())
                    if (includeSourceSpans && node.getSourceSpans().isEmpty()) {
                        node.setSourceSpans(_scanner.getSource(position, _scanner.position()).getSourceSpans())
                    }
                    return [node]
                } else {
                    // Reset position
                    _scanner.setPosition(position)
                }
            }
        }

        let delimiterProcessor = delimiterProcessors.get(c)
        if (let Some(delimiterProcessor) <- delimiterProcessor) {
            let nodes = parseDelimiters(delimiterProcessor, c)
            if (nodes.size > 0) {
                return nodes
            }
        }

        // If we get here, even for a special/delimiter character, we will just treat it as text.
        return [parseText()]
    }

    /**
     * Attempt to parse delimiters like emphasis, strong emphasis or custom delimiters.
     */
    @Frozen
    private func parseDelimiters(delimiterProcessor: DelimiterProcessor, delimiterChar: Rune): Array<Node> {
        let res: DelimiterDataV2 = scanDelimiters(delimiterProcessor, delimiterChar) ?? return []

        // Add entry to stack for this opener
        let delimiter = Delimiter(res.delimiterNodeOld, delimiterChar, res.canOpen, res.canClose, lastDelimiter)
        delimiter.length = res.characters.size
        delimiter.originalLength = res.characters.size
        lastDelimiter = delimiter
        if (let Some(prev) <- delimiter.previous) {
            prev.next = lastDelimiter
        }

        // return res.characters
        return [res.delimiterNodeOld] // 使用旧版delemitorNode
    }

    /**
     * Add open bracket to delimiter stack and add a text node to block's children.
     */
    private func parseOpenBracket(): Node {
        let start = _scanner.position()
        _scanner.next()
        let contentPosition = _scanner.position()

        let node: Text = text(_scanner.getSource(start, contentPosition))

        // Add entry to stack for this opener
        addBracket(BracketV2.link(node, start, contentPosition, lastBracket, lastDelimiter))

        return node
    }

    /**
     * If next character is {@code [}, add a bracket to the stack.
     * Otherwise, return null.
     */
    @Frozen
    private func parseLinkMarker(): Array<Node> {
        var markerPosition = _scanner.position()
        _scanner.next()
        var bracketPosition = _scanner.position()
        if (_scanner.next('[')) {
            var contentPosition = _scanner.position()
            var bangNode = text(_scanner.getSource(markerPosition, bracketPosition))
            var bracketNode = text(_scanner.getSource(bracketPosition, contentPosition))

            // Add entry to stack for this opener
            addBracket(
                BracketV2.withMarker(bangNode, markerPosition, bracketNode, bracketPosition, contentPosition,
                    lastBracket, lastDelimiter))
            return [bangNode, bracketNode]
        } else {
            return []
        }
    }

    /*
     * Try to match close bracket against an opening in the delimiter stack. Return either a link or image, or a
     * plain [ character. If there is a matching delimiter, remove it from the delimiter stack.
     */
    private func parseCloseBracket(): Node {
        let beforeClose = _scanner.position()
        _scanner.next()
        let afterClose = _scanner.position()

        // Get previous `[` or `![`
        // No matching opener, just return a literal.
        let opener: BracketV2 = lastBracket ?? return text(_scanner.getSource(beforeClose, afterClose))

        if (!opener.allowed) {
            // Matching opener but it's not allowed, just return a literal.
            removeLastBracket()
            return text(_scanner.getSource(beforeClose, afterClose))
        }
        var linkOrImage = parseLinkOrImage(opener, beforeClose)
        if (let Some(linkOrImage) <- linkOrImage) {
            return linkOrImage
        }
        _scanner.setPosition(afterClose)

        // Nothing parsed, just parse the bracket as text and continue
        removeLastBracket()
        return text(_scanner.getSource(beforeClose, afterClose))
    }

    private func parseLinkOrImage(opener: BracketV2, beforeClose: SourcePosition): ?Node {
        var linkInfo = parseLinkInfo(opener, beforeClose) ?? return None
        var processorStartPosition = _scanner.position()

        for (linkProcessor in linkProcessors) {
            let result: LinkResultImpl = match (linkProcessor.process(linkInfo, _scanner, context)) {
                case Some(v: LinkResultImpl) => v
                case _ =>
                    // Reset position in case the processor used the scanner, and it didn't work out.
                    _scanner.setPosition(processorStartPosition)
                    continue
            }

            var node = result.getNode()
            var position = result.getPosition()
            var includeMarker = result.isIncludeMarker()

            match (result.getType()) {
                case WRAP =>
                    _scanner.setPosition(position)
                    return wrapBracket(opener, node, includeMarker)
                case REPLACE =>
                    _scanner.setPosition(position)
                    return replaceBracket(opener, node, includeMarker)
            }
        }

        return None
    }

    private func parseLinkInfo(opener: BracketV2, beforeClose: SourcePosition): ?LinkInfo {
        // Check to see if we have a link (or image, with a ! in front). The different types:
        // - Inline:       `[foo](/uri)` or with optional title `[foo](/uri "title")`
        // - Reference links
        //   - Full:      `[foo][bar]` (foo is the text and bar is the label that needs to match a reference)
        //   - Collapsed: `[foo][]`    (foo is both the text and label)
        //   - Shortcut:  `[foo]`      (foo is both the text and label)

        let text = _scanner.getSource(opener.contentPosition, beforeClose).getContent()

        // Starting position is after the closing `]`
        let afterClose = _scanner.position()

        // Maybe an inline link/image
        var destinationTitle = parseInlineDestinationTitle(_scanner)
        if (let Some(destinationTitle) <- destinationTitle) {
            return LinkInfoImpl(opener.markerNode, opener.bracketNode, text, None, destinationTitle.destination,
                destinationTitle.title, afterClose)
        }
        // Not an inline link/image, rewind back to after `]`.
        _scanner.setPosition(afterClose)

        // Maybe a reference link/image like `[foo][bar]`, `[foo][]` or `[foo]`.
        // Note that even `[foo](` could be a valid link if foo is a reference, which is why we try this even if the `(`
        // failed to be parsed as an inline link/image before.

        // See if there's a link label like `[bar]` or `[]`
        let label = parseLinkLabel(_scanner)
        if (label.isNone()) {
            // No label, rewind back
            _scanner.setPosition(afterClose)
        }
        var textIsReference = label?.isEmpty() ?? true
        if (opener.bracketAfter && textIsReference && opener.markerNode == None) {
            // In case of shortcut or collapsed links, the text is used as the reference. But the reference is not allowed to
            // contain an unescaped bracket, so if that's the case we don't need to continue. This is an optimization.
            return None
        }

        return LinkInfoImpl(opener.markerNode, opener.bracketNode, text, label, None, None, afterClose)
    }

    private func wrapBracket(opener: BracketV2, wrapperNode: Node, includeMarker: Bool): Node {
        // Add all nodes between the opening bracket and now (closing bracket) as child nodes of the link
        var n: ?Node = opener.bracketNode.getNext()
        while (let Some(n1) <- n) {
            n = n1.getNext()
            wrapperNode.appendChild(n1)
        }

        if (includeSourceSpans) {
            var startPosition = if (includeMarker && opener.markerPosition.isSome()) {
                opener.markerPosition
            } else {
                opener.bracketPosition
            }
            wrapperNode.setSourceSpans(
                _scanner.getSource(startPosition.getOrThrow(), _scanner.position()).getSourceSpans())
        }

        // Process delimiters such as emphasis inside link/image
        processDelimiters(opener.previousDelimiter)
        mergeChildTextNodes(wrapperNode)
        // We don't need the corresponding text node anymore, we turned it into a link/image node
        if (includeMarker && opener.markerNode.isSome()) {
            opener.markerNode?.unlink()
        }
        opener.bracketNode.unlink()
        removeLastBracket()

        // Links within links are not allowed. We found this link, so there can be no other link around it.
        if (opener.markerNode.isNone()) {
            var bracket = lastBracket
            while (let Some(_bracket) <- bracket) {
                if (_bracket.markerNode.isNone()) {
                    // Disallow link opener. It will still get matched, but will not result in a link.
                    _bracket.allowed = false
                }
                bracket = _bracket.previous
            }
        }

        return wrapperNode
    }

    private func replaceBracket(opener: BracketV2, node: Node, includeMarker: Bool): Node {
        // Remove delimiters (but keep text nodes)
        while (lastDelimiter.isSome() && lastDelimiter != opener.previousDelimiter) {
            removeDelimiterKeepNode(lastDelimiter.getOrThrow())
        }

        if (includeSourceSpans) {
            var startPosition = if (includeMarker && opener.markerPosition.isSome()) {
                opener.markerPosition
            } else {
                opener.bracketPosition
            }
            node.setSourceSpans(_scanner.getSource(startPosition.getOrThrow(), _scanner.position()).getSourceSpans())
        }

        removeLastBracket()

        // Remove nodes that we added since the opener, because we're replacing them
        var n: ?Node = if (includeMarker && opener.markerNode.isSome()) {
            opener.markerNode ?? None
        } else {
            opener.bracketNode
        }
        while (let Some(_n) <- n) {
            var next = _n.getNext()
            _n.unlink()
            n = next
        }
        return node
    }

    private func addBracket(bracket: BracketV2): Unit {
        if (let Some(lastBracket) <- lastBracket) {
            lastBracket.bracketAfter = true
        }
        lastBracket = bracket
    }

    private func removeLastBracket(): Unit {
        lastBracket = lastBracket?.previous ?? None
    }

    /**
     * Try to parse the destination and an optional title for an inline link/image.
     */
    private static func parseInlineDestinationTitle(scanner: Scanner): ?DestinationTitle {
        if (!scanner.next('(')) {
            return None
        }

        scanner.whitespace()
        let dest = parseLinkDestination(scanner) ?? return None

        var title: ?String = None
        let whitespace: Int = scanner.whitespace()
        // title needs a whitespace before
        if (whitespace >= 1) {
            title = parseLinkTitle(scanner)
            scanner.whitespace()
        }
        if (!scanner.next(')')) {
            // Don't have a closing `)`, so it's not a destination and title.
            // Note that something like `[foo](` could still be valid later, `(` will just be text.
            return None
        }
        return DestinationTitle(dest, title)
    }

    /**
     * Attempt to parse link destination, returning the string or null if no match.
     */
    private static func parseLinkDestination(scanner: Scanner): ?String {
        let delimiter: Rune = scanner.peek()
        let start: SourcePosition = scanner.position()
        if (!LinkScannerV2.scanLinkDestination(scanner)) {
            return None
        }

        var dest: String = if (delimiter == r'<') {
            // chop off surrounding <..>:
            let rawDestination = scanner.getSource(start, scanner.position()).getContent()
            rawDestination[1..rawDestination.size - 1]
        } else {
            scanner.getSource(start, scanner.position()).getContent()
        }

        return Escaping.unescapeString(dest)
    }

    /**
     * Attempt to parse link titleStr (sans quotes), returning the string or null if no match.
     */
    private static func parseLinkTitle(scanner: Scanner): ?String {
        let start = scanner.position()
        if (!LinkScannerV2.scanLinkTitle(scanner)) {
            return None
        }

        // chop off ', " or parens
        let rawTitle = scanner.getSource(start, scanner.position()).getContent()
        let title = rawTitle[1..rawTitle.size - 1]
        return Escaping.unescapeString(title)
    }

    /**
     * Attempt to parse a link label, returning number of characters parsed.
     */
    static func parseLinkLabel(scanner: Scanner): ?String {
        if (!scanner.next('[')) {
            return None
        }

        let start = scanner.position()
        if (!LinkScannerV2.scanLinkLabelContent(scanner)) {
            return None
        }
        let end = scanner.position()

        if (!scanner.next(']')) {
            return None
        }

        let content = scanner.getSource(start, end).getContent()
        // spec: A link label can have at most 999 characters inside the square brackets.
        if (content.size > 999) {
            return None
        }

        return content
    }

    private func parseLineBreak(): Node {
        _scanner.next()

        if (trailingSpaces >= 2) {
            return HardLineBreak()
        } else {
            return SoftLineBreak()
        }
    }

    /**
     * Parse the next character as plain text, and possibly more if the following characters are non-special.
     */
    private func parseText(): Node {
        let start = _scanner.position()
        _scanner.next()
        var c: Rune = '\0'
        while (true) {
            c = _scanner.peek()
            if (c == Scanner.END || specialCharacters.get(Int64(UInt32(c)))) {
                break
            }
            _scanner.next()
        }

        let source: SourceLines = _scanner.getSource(start, _scanner.position())
        var content = source.getContent()

        if (c == r'\n') {
            // We parsed until the end of the line. Trim any trailing spaces and remember them (for hard line breaks).
            let end = Characters.skipBackwards(b' ', content, content.size - 1, 0) + 1
            trailingSpaces = content.size - end
            content = content[..end]
        } else if (c == Scanner.END) {
            // For the last line, both tabs and spaces are trimmed for some reason (checked with commonmark.js).
            let end = Characters.skipSpaceTabBackwards(content, content.size - 1, 0) + 1
            content = content[..end]
        }

        let text = Text(content)
        text.setSourceSpans(source.getSourceSpans())
        return text
    }

    /**
     * Scan a sequence of characters with code delimiterChar, and return information about the number of delimiters
     * and whether they are positioned such that they can open and/or close emphasis or strong emphasis.
     *
     * @return information about delimiter run, or {@code null}
     */
    private func scanDelimiters(delimiterProcessor: DelimiterProcessor, delimiterChar: Rune): ?DelimiterDataV2 {
        let before = _scanner.peekPreviousCodePoint()
        let start = _scanner.position()

        // Quick check to see if we have enough delimiters.
        let delimiterCount = _scanner.matchMultiple(delimiterChar)
        if (delimiterCount < delimiterProcessor.getMinLength()) {
            _scanner.setPosition(start)
            return None
        }

        // We do have enough, extract a text node for each delimiter character.
        let delimiters = ArrayList<Text>()
        _scanner.setPosition(start)
        var positionBefore = start
        while (_scanner.next(delimiterChar)) {
            delimiters.add(text(_scanner.getSource(positionBefore, _scanner.position())))
            positionBefore = _scanner.position()
        }
        let delimiterNodeOld = text(_scanner.getSource(start, positionBefore))

        let after = _scanner.peekCodePoint()

        // We could be more lazy here, in most cases we don't need to do every match case.
        let beforeIsPunctuation = before == Scanner.END || Characters.isPunctuationCodePoint(before)
        let beforeIsWhitespace = before == Scanner.END || Characters.isWhitespaceCodePoint(before)
        let afterIsPunctuation = after == Scanner.END || Characters.isPunctuationCodePoint(after)
        let afterIsWhitespace = after == Scanner.END || Characters.isWhitespaceCodePoint(after)

        let leftFlanking = !afterIsWhitespace && (!afterIsPunctuation || beforeIsWhitespace || beforeIsPunctuation)
        let rightFlanking = !beforeIsWhitespace && (!beforeIsPunctuation || afterIsWhitespace || afterIsPunctuation)
        let canOpen: Bool
        let canClose: Bool
        if (delimiterChar == r'_') {
            canOpen = leftFlanking && (!rightFlanking || beforeIsPunctuation)
            canClose = rightFlanking && (!leftFlanking || afterIsPunctuation)
        } else {
            canOpen = leftFlanking && delimiterChar == delimiterProcessor.getOpeningCharacter()
            canClose = rightFlanking && delimiterChar == delimiterProcessor.getClosingCharacter()
        }

        return DelimiterDataV2(delimiterNodeOld, delimiters, canOpen, canClose)
    }

    @Frozen
    private func processDelimiters(stackBottom: ?Delimiter): Unit {
        var openersBottom: HashMap<Rune, ?Delimiter> = HashMap<Rune, ?Delimiter>()

        // find first closer above stackBottom:
        var closer: ?Delimiter = lastDelimiter
        while (closer.isSome() && closer().previous != stackBottom) {
            closer = closer().previous
        }
        // move forward, looking for closers, and handling each
        while (let Some(_closer) <- closer) {
            let delimiterChar: Rune = _closer.delimiterChar

            var delimiterProcessor: ?DelimiterProcessor = delimiterProcessors.get(delimiterChar)
            if (!(_closer.canClose()) || delimiterProcessor.isNone()) {
                closer = _closer.next
                continue
            }

            let openingDelimiterChar: Rune = delimiterProcessor().getOpeningCharacter()

            // Found delimiter closer. Now look back for first matching opener.
            var useDelims: Int64 = 0
            var openerFound: Bool = false
            var potentialOpenerFound: Bool = false
            var opener: ?Delimiter = _closer.previous
            while (opener.isSome() && opener != stackBottom && opener != (openersBottom.get(delimiterChar) ?? None)) {
                if (opener().canOpen() && (opener().delimiterChar == openingDelimiterChar)) {
                    potentialOpenerFound = true
                    // 使用旧版delimiterProcessor处理
                    useDelims = delimiterProcessor().getDelimiterUse(opener(), _closer)
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
                    openersBottom.add(delimiterChar, _closer.previous)
                    if (closer.isSome() && !_closer.canOpen()) {
                        // We can remove a closer that can't be an opener,
                        // once we've seen there's no matching opener:
                        removeDelimiterKeepNode(_closer)
                    }
                }
                closer = _closer.next
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
            if (opener?.length == 0) {
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
        if (let Some(prev) <- delim.previous) {
            prev.next = delim.next
        }
        if (let Some(next) <- delim.next) {
            next.previous = delim.previous
        } else {
            // top of stack
            lastDelimiter = delim.previous
        }
    }

    private func mergeTextNodesBetweenExclusive(fromNode: Node, toNode: Node): Unit {
        // No nodes between them
        if (fromNode == toNode || fromNode.getNext() == toNode) {
            return
        }

        mergeTextNodesInclusive(fromNode.getNext(), toNode.getPrevious())
    }

    @Frozen
    private func mergeChildTextNodes(node: Node): Unit {
        // No children or just one child node, no need for merging
        if (node.getFirstChild().isNone()) {
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
            if (let Some(text: Text) <- node) {
                if (first.isNone()) {
                    first = text
                }
                length += text.getLiteral().size
                last = text
            } else {
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
            var sourceSpans: ?SourceSpans = None
            if (includeSourceSpans) {
                sourceSpans = SourceSpans()
                sourceSpans?.addAll(first().getSourceSpans())
            }
            var node: ?Node = first().getNext()
            let stop: ?Node = last().getNext()
            while (node != stop) {
                if (let Some(v: Text) <- node) {
                    sb.append(v.getLiteral())
                    sourceSpans?.addAll(v.getSourceSpans())
                    var unlink: Node = v
                    node = v.getNext()
                    unlink.unlink()
                }
            }
            let literal: String = sb.toString()
            first?.setLiteral(literal)
            if (let Some(sourceSpans) <- sourceSpans) {
                first?.setSourceSpans(sourceSpans.getSourceSpans())
            }
        }
    }
}

public class InlineParserV2Factory <: InlineParserFactory {
    public override func create(inlineParserContext: InlineParserContext): InlineParser {
        return InlineParserImplV2(inlineParserContext)
    }
}
