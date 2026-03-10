/**
 * @file
 * This file is about parse.
 */

package yaml4cj.yaml

enum ParserNodeType <: ToString {
    | ParserNodeType_ZERO_NODE
    | ParserNodeType_DOCUMENT_NODE
    | ParserNodeType_MAPPING_NODE
    | ParserNodeType_SEQUENCE_NODE
    | ParserNodeType_SCALAR_NODE
    | ParserNodeType_ALIAS_NODE

    func getCode(): Int64 {
        match (this) {
            case ParserNodeType_ZERO_NODE => 0
            case ParserNodeType_DOCUMENT_NODE => 1
            case ParserNodeType_MAPPING_NODE => 2
            case ParserNodeType_SEQUENCE_NODE => 4
            case ParserNodeType_SCALAR_NODE => 8
            case ParserNodeType_ALIAS_NODE => 16
        }
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        match (this) {
            case ParserNodeType_ZERO_NODE => "ParserNodeType_ZERO_NODE"
            case ParserNodeType_DOCUMENT_NODE => "ParserNodeType_DOCUMENT_NODE"
            case ParserNodeType_MAPPING_NODE => "ParserNodeType_MAPPING_NODE"
            case ParserNodeType_SEQUENCE_NODE => "ParserNodeType_SEQUENCE_NODE"
            case ParserNodeType_SCALAR_NODE => "ParserNodeType_SCALAR_NODE"
            case ParserNodeType_ALIAS_NODE => "ParserNodeType_ALIAS_NODE"
        }
    }

    /**
     * The Function is ==
     *
     * @param rhs of ParserNodeType
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(rhs: ParserNodeType): Bool {
        getCode() == rhs.getCode()
    }

    /**
     * The Function is !=
     *
     * @param rhs of ParserNodeType
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(rhs: ParserNodeType): Bool {
        getCode() != rhs.getCode()
    }
}

class Parser {
    var parser: ParserT
    var event: EventT = EventT()
    var doc: ?Node = None
    var doneInit: Bool = false

    init(b: Array<UInt8>) {
        this.parser = ParserT()
        parser.rawBuffer = ArrayList<UInt8>(inputRawBufferSize)
        parser.buffer = ArrayList<UInt8>(inputBufferSize)
        parser.bufferTemp = parser.buffer
        let mb: Array<UInt8> = if (b.size == 0) {
            [10]
        } else {
            b
        }
        parserSetInputString(mb)
    }

    func initiator() {
        if (this.doneInit) {
            return
        }
        expect(EventTypeT_STREAM_START_EVENT)
        this.doneInit = true
    }

    func expect(e: EventTypeT) {
        if (this.event.typ == EventTypeT_NO_EVENT) {
            let (eve, ok) = parserParse(this.parser)
            this.event = eve
            if (!ok) {
                fail()
            }
        }
        if (this.event.typ == EventTypeT_STREAM_END_EVENT) {
            failf("attempted to go past the end of stream; corrupted value?")
        }
        if (this.event.typ != e) {
            this.parser.problem = "expected ${e} event but got ${this.event.typ}"
            fail()
        }
        this.event = EventT()
        this.event.typ = EventTypeT_NO_EVENT
    }

    func parserSetInputString(b: Array<UInt8>) {
        match (this.parser.readHandler) {
            case Some(_) => throw Exception("failed to initialize YAML emitter")
            case _ => ()
        }
        this.parser.readHandler = stringReadHandler
        this.parser.input = b
        this.parser.inputPos = 0
    }

    func parse(): ?Node {
        initiator()
        match (peek()) {
            case EventTypeT_SCALAR_EVENT => scalar()
            case EventTypeT_ALIAS_EVENT => alias()
            case EventTypeT_MAPPING_START_EVENT => mapping()
            case EventTypeT_SEQUENCE_START_EVENT => sequence()
            case EventTypeT_DOCUMENT_START_EVENT => document()
            case EventTypeT_STREAM_END_EVENT => None
            case _ => throw Exception("attempted to parse unknown event: ${event.typ}")
        }
    }

    func fail() {
        var w = ""
        var line: Int64 = 0
        if (this.parser.problemMark.line != 0) {
            line = this.parser.problemMark.line
            if (this.parser.error == ErrorTypeT_SCANNER_ERROR) {
                line++
            }
        } else if (this.parser.contextMark.line != 0) {
            line = this.parser.contextMark.line
        }
        if (line != 0) {
            w = "line ${line}: "
        }
        let m = if (this.parser.problem.size > 0) {
            this.parser.problem
        } else {
            "unknown problem parsing YAML content"
        }
        failf("${w}${m}")
    }

    func peek(): EventTypeT {
        if (this.event.typ != EventTypeT_NO_EVENT) {
            return this.event.typ
        }
        let (eve, ok) = parserParse(this.parser)
        this.event = eve
        if (!ok) {
            fail()
        }
        eve.typ
    }

    func node(kind: ParserNodeType): Node {
        let n = Node()
        n.kind = kind
        n.line = this.event.startMark.line
        n.column = this.event.startMark.column
        n
    }

    func anchor(n: Node, anchor: Array<UInt8>) {
        if (anchor.size > 0) {
            this.doc.getOrThrow().anchors[String.fromUtf8(anchor)] = n
        }
    }

    func scalar(): Node {
        let n = node(ParserNodeType_SCALAR_NODE)
        n.value = String.fromUtf8(this.event.value)
        n.tag = String.fromUtf8(this.event.tag)
        n.implicit = this.event.implicit
        anchor(n, this.event.anchor)
        expect(EventTypeT_SCALAR_EVENT)
        n
    }

    func alias(): Node {
        let n = node(ParserNodeType_ALIAS_NODE)
        n.value = String.fromUtf8(this.event.anchor)
        n.alias = this.doc.getOrThrow().anchors.get(n.value)
        match (n.alias) {
            case None => failf("unknown anchor '${n.value}' referenced")
            case _ => ()
        }
        expect(EventTypeT_ALIAS_EVENT)
        n
    }

    func mapping(): Node {
        let n = node(ParserNodeType_MAPPING_NODE)
        anchor(n, this.event.anchor)
        expect(EventTypeT_MAPPING_START_EVENT)
        while (peek() != EventTypeT_MAPPING_END_EVENT) {
            n.children.add(parse())
            n.children.add(parse())
        }
        expect(EventTypeT_MAPPING_END_EVENT)
        n
    }

    func sequence(): Node {
        let n = node(ParserNodeType_SEQUENCE_NODE)
        anchor(n, this.event.anchor)
        expect(EventTypeT_SEQUENCE_START_EVENT)
        while (peek() != EventTypeT_SEQUENCE_END_EVENT) {
            n.children.add(parse())
        }
        expect(EventTypeT_SEQUENCE_END_EVENT)
        n
    }

    func document(): Node {
        let n = node(ParserNodeType_DOCUMENT_NODE)
        n.anchors = HashMap<String, Node>()
        this.doc = n
        expect(EventTypeT_DOCUMENT_START_EVENT)
        n.children.add(parse())
        expect(EventTypeT_DOCUMENT_END_EVENT)
        n
    }

    func destroy() {
        if (this.event.typ != EventTypeT_NO_EVENT) {
            this.event = eventDelete()
        }
        this.parser = parserDelete()
    }
}

func stringReadHandler(parser: ParserT, buffer: Array<UInt8>): Int64 {
    if (parser.inputPos == parser.input.size) {
        return 0
    }
    let n = copy(buffer, parser.input, srcStart: parser.inputPos)
    parser.inputPos += n
    return n
}

class Node <: ToString & Hashable & Equatable<Node> {
    var kind: ParserNodeType = ParserNodeType_ZERO_NODE
    var line: Int64 = 0
    var column: Int64 = 0
    var tag: String = ""
    var alias: ?Node = None
    var value: String = ""
    var implicit: Bool = false
    var children: ArrayList<?Node> = ArrayList<?Node>()
    var anchors: HashMap<String, Node> = HashMap<String, Node>()

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        """
        {
            kind: ${kind}
            line: ${line}
            column: ${column}
            tag: ${tag}
            alias: ${alias}
            value: ${value}
            implicit: ${implicit}
            children: ${children}
            anchors: ${anchors}
        }
        """
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func hashCode(): Int64 {
        var dfh: DefaultHasher = DefaultHasher()
        dfh.write("name=Node")
        dfh.write("kind=${kind}")
        dfh.write("line=${line}")
        dfh.write("column=${column}")
        dfh.write("tag=${tag}")
        match (alias) {
            case Some(r) => dfh.write("alias=${r.hashCode()}")
            case None => dfh.write("alias=None")
        }
        dfh.write("value=${value}")
        dfh.write("implicit=${implicit}")
        dfh.write("children=${children}")
        dfh.write("anchors=${anchors}")
        return dfh.finish()
    }

    /**
     * The Function is ==
     *
     * @param rhs of Node
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(rhs: Node): Bool {
        hashCode() == rhs.hashCode()
    }

    /**
     * The Function is !=
     *
     * @param rhs of Node
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(rhs: Node): Bool {
        hashCode() != rhs.hashCode()
    }
}

func peekToken(parser: ParserT): ?TokenT {
    if (parser.tokenAvailable || parserFetchMoreTokens(parser)) {
        parser.tokens[parser.tokensHead]
    } else {
        None
    }
}

func skipToken(parser: ParserT) {
    parser.tokenAvailable = false
    parser.tokensParsed++
    parser.streamEndProduced = parser.tokens[parser.tokensHead].typ == TokenTypeT_STREAM_END_TOKEN
    parser.tokensHead++
}

func parserSetParserError(parser: ParserT, problem: String, problemMark: MarkT): Bool {
    parser.error = ErrorTypeT_PARSER_ERROR
    parser.problem = problem
    parser.problemMark = problemMark
    false
}

func parserSetParserErrorContext(
    parser: ParserT,
    context: String,
    contextMark: MarkT,
    problem: String,
    problemMark: MarkT
): Bool {
    parser.error = ErrorTypeT_PARSER_ERROR
    parser.context = context
    parser.contextMark = contextMark
    parser.problem = problem
    parser.problemMark = problemMark
    false
}

func parserParse(parser: ParserT): (EventT, Bool) {
    let event = EventT()
    if (parser.streamEndProduced || parser.error != ErrorTypeT_NO_ERROR || parser.state == ParserStateT_PARSE_END_STATE) {
        return (EventT(), true)
    }
    parserStateMachine(parser, event)
}

func parserStateMachine(parser: ParserT, event: EventT): (EventT, Bool) {
    // println("parser.state=${parser.state} ${event.typ}")
    match (parser.state) {
        case ParserStateT_PARSE_STREAM_START_STATE => parserParseStreamStart(parser, event)
        case ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE => parserParseDocumentStart(parser, event, true)
        case ParserStateT_PARSE_DOCUMENT_START_STATE => parserParseDocumentStart(parser, event, false)
        case ParserStateT_PARSE_DOCUMENT_CONTENT_STATE => parserParseDocumentContent(parser, event)
        case ParserStateT_PARSE_DOCUMENT_END_STATE => parserParseDocumentEnd(parser, event)
        case ParserStateT_PARSE_BLOCK_NODE_STATE => parserParseNode(parser, event, true, false)
        case ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE => parserParseNode(
            parser,
            event,
            true,
            true
        )
        case ParserStateT_PARSE_FLOW_NODE_STATE => parserParseNode(parser, event, false, false)
        case ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE => parserParseBlockSequenceEntry(
            parser,
            event,
            true
        )
        case ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE => parserParseBlockSequenceEntry(
            parser,
            event,
            false
        )
        case ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE => parserParseIndentlessSequenceEntry(
            parser,
            event
        )
        case ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE => parserParseBlockMappingKey(parser, event, true)
        case ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE => parserParseBlockMappingKey(parser, event, false)
        case ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE => parserParseBlockMappingValue(parser, event)
        case ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE => parserParseFlowSequenceEntry(
            parser,
            event,
            true
        )
        case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE => parserParseFlowSequenceEntry(parser, event, false)
        /* case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE =>
            parserParseFlowSequenceEntryMappingKey(
                parser,
                event
            )*/
        /* case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE =>
            parserParseFlowSequenceEntryMappingValue(parser, event)
           case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE =>
            parserParseFlowSequenceEntryMappingEnd(
                parser,
                event
            )*/
        case ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE => parserParseFlowMappingKey(parser, event, true)
        case ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE => parserParseFlowMappingKey(parser, event, false)
        case ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE => parserParseFlowMappingValue(parser, event, false)
        case ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE => parserParseFlowMappingValue(
            parser,
            event,
            true
        )
        case _ => throw Exception("invalid parser state")
    }
}

func parserParseStreamStart(parser: ParserT, event: EventT): (EventT, Bool) {
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(token) =>
            if (token.typ != TokenTypeT_STREAM_START_TOKEN) {
                return (event, parserSetParserError(
                        parser,
                        "did not find expected <stream-start>",
                        token.startMark
                    ))
            }
            parser.state = ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE
            var eve = EventT()
            eve.typ = EventTypeT_STREAM_START_EVENT
            eve.startMark = token.startMark
            eve.endMark = token.endMark
            eve.encoding = token.encoding
            skipToken(parser)
            (eve, true)
    }
}

func parserParseDocumentStart(parser: ParserT, oevent: EventT, implicit: Bool): (EventT, Bool) {
    var event = oevent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok
            if (!implicit) {
                while (token.typ == TokenTypeT_DOCUMENT_END_TOKEN) {
                    skipToken(parser)
                    token = match (peekToken(parser)) {
                        case None => return (event, false)
                        case Some(t) => t
                    }
                }
            }

            if (implicit && token.typ != TokenTypeT_VERSION_DIRECTIVE_TOKEN && token.typ !=
                TokenTypeT_TAG_DIRECTIVE_TOKEN && token.typ != TokenTypeT_DOCUMENT_START_TOKEN && token.typ !=
                TokenTypeT_STREAM_END_TOKEN) {
                let (_, _, ok) = parserProcessDirectives(parser)
                if (!ok) {
                    return (event, false)
                }
                parser.states.add(ParserStateT_PARSE_DOCUMENT_END_STATE)
                parser.state = ParserStateT_PARSE_BLOCK_NODE_STATE

                event = EventT()
                event.typ = EventTypeT_DOCUMENT_START_EVENT
                event.startMark = token.startMark
                event.endMark = token.endMark
            } else if (token.typ != TokenTypeT_STREAM_END_TOKEN) {
                let startMark = token.startMark
                let (versionDirective, tagDirectives, ok) = parserProcessDirectives(parser)
                if (!ok) {
                    return (event, false)
                }
                token = match (peekToken(parser)) {
                    case None => return (event, false)
                    case Some(t) => t
                }
                if (token.typ != TokenTypeT_DOCUMENT_START_TOKEN) {
                    parserSetParserError(
                        parser,
                        "did not find expected <document start>",
                        token.startMark
                    )
                    return (event, false)
                }
                parser.states.add(ParserStateT_PARSE_DOCUMENT_END_STATE)
                parser.state = ParserStateT_PARSE_DOCUMENT_CONTENT_STATE
                let endMark = token.endMark

                event = EventT()

                event.typ = EventTypeT_DOCUMENT_START_EVENT
                event.startMark = startMark
                event.endMark = endMark
                event.versionDirective = versionDirective
                event.tagDirectives = tagDirectives
                event.implicit = false

                skipToken(parser)
            } else {
                parser.state = ParserStateT_PARSE_END_STATE
                event = EventT()
                event.typ = EventTypeT_STREAM_END_EVENT
                event.startMark = token.startMark
                event.endMark = token.endMark

                skipToken(parser)
            }
            (event, true)
    }
}

let defaultTagDirectives: Array<TagDirectiveT> = [
    TagDirectiveT([0x21], [0x21]),
    TagDirectiveT(
        [0x21, 0x21],
        [0x74, 0x61, 0x67, 0x3A, 0x79, 0x61, 0x6D, 0x6C, 0x2E, 0x6F, 0x72, 0x67, 0x2C, 0x32, 0x30, 0x30, 0x32, 0x3A]
    )
]

func parserProcessDirectives(parser: ParserT): (?VersionDirectiveT, ArrayList<TagDirectiveT>, Bool) {
    var versionDirective: ?VersionDirectiveT = None
    let tagDirectives = ArrayList<TagDirectiveT>()
    match (peekToken(parser)) {
        case None => (None, ArrayList<TagDirectiveT>(), false)
        case Some(tok) =>
            var token = tok
            while (token.typ == TokenTypeT_VERSION_DIRECTIVE_TOKEN || token.typ == TokenTypeT_TAG_DIRECTIVE_TOKEN) {
                if (token.typ == TokenTypeT_VERSION_DIRECTIVE_TOKEN) {
                    match (versionDirective) {
                        case None => ()
                        case _ =>
                            parserSetParserError(
                                parser,
                                "found duplicate %YAML directive",
                                token.startMark
                            )
                            return (None, ArrayList<TagDirectiveT>(), false)
                    }
                    if (token.major != 1 || token.minor != 1) {
                        parserSetParserError(
                            parser,
                            "found incompatible YAML document",
                            token.startMark
                        )
                        return (None, ArrayList<TagDirectiveT>(), false)
                    }
                    let nVersionDirective = VersionDirectiveT()
                    nVersionDirective.major = token.major
                    nVersionDirective.minor = token.minor
                    versionDirective = nVersionDirective
                } else if (token.typ == TokenTypeT_TAG_DIRECTIVE_TOKEN) {
                    let value = TagDirectiveT()

                    value.handle = token.value
                    value.prefix = token.prefix

                    if (!parserAppendTagDirective(parser, value, false, token.startMark)) {
                        return (None, ArrayList<TagDirectiveT>(), false)
                    }
                    tagDirectives.add(value)
                }
                skipToken(parser)
                token = match (peekToken(parser)) {
                    case None => return (None, ArrayList<TagDirectiveT>(), false)
                    case Some(t) => t
                }
            }

            for (v in defaultTagDirectives) {
                if (!parserAppendTagDirective(parser, v, true, token.startMark)) {
                    return (None, ArrayList<TagDirectiveT>(), false)
                }
            }
            (versionDirective, tagDirectives, true)
    }
}

func parserAppendTagDirective(
    parser: ParserT,
    value: TagDirectiveT,
    allowDuplicates: Bool,
    mark: MarkT
): Bool {
    let valueHandle = String.fromUtf8(value.handle)
    for (v in parser.tagDirectives) {
        if (valueHandle == String.fromUtf8(v.handle)) {
            if (allowDuplicates) {
                return true
            }
            return parserSetParserError(parser, "found duplicate %TAG directive", mark)
        }
    }

    let valueCopy = TagDirectiveT()
    valueCopy.handle = Array<UInt8>(value.handle.size, repeat: 0)
    valueCopy.prefix = Array<UInt8>(value.prefix.size, repeat: 0)
    copy(valueCopy.handle, value.handle)
    copy(valueCopy.prefix, value.prefix)
    parser.tagDirectives.add(valueCopy)
    true
}

func parserParseDocumentContent(parser: ParserT, event: EventT): (EventT, Bool) {
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok
            if (token.typ == TokenTypeT_VERSION_DIRECTIVE_TOKEN || token.typ == TokenTypeT_TAG_DIRECTIVE_TOKEN ||
                token.typ == TokenTypeT_DOCUMENT_START_TOKEN || token.typ == TokenTypeT_DOCUMENT_END_TOKEN ||
                token.typ == TokenTypeT_STREAM_END_TOKEN) {
                parser.state = parser.states[parser.states.size - 1]
                parser.states = parser.states[0..(parser.states.size - 1)]
                return parserProcessEmptyScalar(token.startMark)
            }
            parserParseNode(parser, event, true, false)
    }
}

func parserProcessEmptyScalar(mark: MarkT): (EventT, Bool) {
    let event = EventT()
    event.typ = EventTypeT_SCALAR_EVENT
    event.startMark = mark
    event.endMark = mark
    event.value = []
    event.implicit = true
    event.style = ScalarStyleT_PLAIN_SCALAR_STYLE
    (event, true)
}

func parserParseNodeReslove0(
    parser: ParserT,
    event: EventT,
    tag: ArrayList<UInt8>,
    tagHandle: Array<UInt8>,
    tagSuffixBox: Box<Array<UInt8>>,
    startMark: MarkT,
    tagMark: MarkT
): (?EventT, Bool) {
    if (tagHandle.size == 0) {
        tag.clear()
        tag.add(all: tagSuffixBox.value)
        tagSuffixBox.value = []
    } else {
        let tagHandleStr = String.fromUtf8(tagHandle)
        for (v in parser.tagDirectives) {
            if (tagHandleStr == String.fromUtf8(v.handle)) {
                tag.clear()
                tag.add(all: v.prefix)
                tag.add(all: tagSuffixBox.value)
                break
            }
        }
        if (tag.size == 0) {
            parserSetParserErrorContext(
                parser,
                "while parsing a node",
                startMark,
                "found undefined tag handle",
                tagMark
            )
            return (event, false)
        }
    }
    (None, false)
}

func parserParseNode(parser: ParserT, oEvent: EventT, block: Bool, indentlessSequence: Bool): (EventT, Bool) {
    var event = oEvent
    if (let Some(tok) <- peekToken(parser)) {
        var token = tok
        if (token.typ == TokenTypeT_ALIAS_TOKEN) {
            parser.state = parser.states[parser.states.size - 1]
            parser.states = parser.states[0..(parser.states.size - 1)]
            event = EventT()

            event.typ = EventTypeT_ALIAS_EVENT
            event.startMark = token.startMark
            event.endMark = token.endMark
            event.anchor = token.value

            skipToken(parser)
            return (event, true)
        }

        var startMark = token.startMark
        var endMark = token.startMark

        var tagToken = false
        var tagHandle: Array<UInt8> = []
        var tagSuffix: Array<UInt8> = []
        var anchor: Array<UInt8> = []
        var tagMark = MarkT()

        if (token.typ == TokenTypeT_ANCHOR_TOKEN) {
            anchor = token.value
            startMark = token.startMark
            endMark = token.endMark
            skipToken(parser)
            if (let Some(tok) <- peekToken(parser)) {
                token = tok
            } else {
                return (event, false)
            }
        }
        if (token.typ == TokenTypeT_TAG_TOKEN) {
            tagToken = true
            tagHandle = token.value
            tagSuffix = token.suffix
            tagMark = token.startMark
            endMark = token.endMark
            skipToken(parser)
            if (let Some(tok) <- peekToken(parser)) {
                token = tok
            } else {
                return (event, false)
            }
        } else if (token.typ == TokenTypeT_TAG_TOKEN) {
            tagToken = true
            tagHandle = token.value
            tagSuffix = token.suffix
            startMark = token.startMark
            tagMark = token.startMark
            endMark = token.endMark
            skipToken(parser)
            if (let Some(tok) <- peekToken(parser)) {
                token = tok
            } else {
                return (event, false)
            }
            if (token.typ == TokenTypeT_ANCHOR_TOKEN) {
                anchor = token.value
                endMark = token.endMark
                skipToken(parser)
                if (let Some(tok) <- peekToken(parser)) {
                    token = tok
                } else {
                    return (event, false)
                }
            }
        }
        let tag = ArrayList<UInt8>()
        if (tagToken) {
            let tagSuffixBox = Box<Array<UInt8>>(tagSuffix)
            if (let (Some(e), ok) <- parserParseNodeReslove0(
                parser,
                event,
                tag,
                tagHandle,
                tagSuffixBox,
                startMark,
                tagMark
            )) {
                return (e, ok)
            }
            tagSuffix = tagSuffixBox.value
        }

        let implicit = tag.size == 0
        if (indentlessSequence && token.typ == TokenTypeT_BLOCK_ENTRY_TOKEN) {
            endMark = token.endMark
            parser.state = ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE
            event = EventT()

            event.typ = EventTypeT_SEQUENCE_START_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.anchor = anchor
            event.tag = tag.toArray()
            event.implicit = implicit
            event.style = SequenceStyleT_BLOCK_SEQUENCE_STYLE

            return (event, true)
        }

        if (token.typ == TokenTypeT_SCALAR_TOKEN) {
            var plain_implicit = false
            var quotedImplicit = false
            endMark = token.endMark
            if ((tag.size == 0 && token.style == ScalarStyleT_PLAIN_SCALAR_STYLE) || (tag.size == 1 && tag[0] == 0x21)) {
                plain_implicit = true
            } else if (tag.size == 0) {
                quotedImplicit = true
            }
            parser.state = parser.states[parser.states.size - 1]
            parser.states = parser.states[0..(parser.states.size - 1)]

            event = EventT()

            event.typ = EventTypeT_SCALAR_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.anchor = anchor
            event.tag = tag.toArray()
            event.value = token.value
            event.implicit = plain_implicit
            event.quotedImplicit = quotedImplicit
            event.style = token.style

            skipToken(parser)
            return (event, true)
        }

        if (token.typ == TokenTypeT_FLOW_SEQUENCE_START_TOKEN) {
            endMark = token.endMark
            parser.state = ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE
            event = EventT()

            event.typ = EventTypeT_SEQUENCE_START_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.anchor = anchor
            event.tag = tag.toArray()
            event.implicit = implicit
            event.style = SequenceStyleT_FLOW_SEQUENCE_STYLE

            return (event, true)
        }

        if (token.typ == TokenTypeT_FLOW_MAPPING_START_TOKEN) {
            endMark = token.endMark
            parser.state = ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE
            event = EventT()

            event.typ = EventTypeT_MAPPING_START_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.anchor = anchor
            event.tag = tag.toArray()
            event.implicit = implicit
            event.style = MappingStyleT_FLOW_MAPPING_STYLE

            return (event, true)
        }

        if (block && token.typ == TokenTypeT_BLOCK_SEQUENCE_START_TOKEN) {
            endMark = token.endMark
            parser.state = ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE
            event = EventT()

            event.typ = EventTypeT_SEQUENCE_START_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.anchor = anchor
            event.tag = tag.toArray()
            event.implicit = implicit
            event.style = SequenceStyleT_BLOCK_SEQUENCE_STYLE

            return (event, true)
        }

        if (block && token.typ == TokenTypeT_BLOCK_MAPPING_START_TOKEN) {
            endMark = token.endMark
            parser.state = ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE
            event = EventT()

            event.typ = EventTypeT_MAPPING_START_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.anchor = anchor
            event.tag = tag.toArray()
            event.implicit = implicit
            event.style = MappingStyleT_BLOCK_MAPPING_STYLE

            return (event, true)
        }

        if (anchor.size > 0 || tag.size > 0) {
            parser.state = parser.states[parser.states.size - 1]
            parser.states = parser.states[0..(parser.states.size - 1)]

            event = EventT()

            event.typ = EventTypeT_SCALAR_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.anchor = anchor
            event.tag = tag.toArray()
            event.implicit = implicit
            event.quotedImplicit = false
            event.style = ScalarStyleT_PLAIN_SCALAR_STYLE

            return (event, true)
        }

        var context = "while parsing a flow node"
        if (block) {
            context = "while parsing a block node"
        }
        parserSetParserErrorContext(
            parser,
            context,
            startMark,
            "did not find expected node content",
            token.startMark
        )
    }
    return (event, false)
}

func parserParseDocumentEnd(parser: ParserT, oEvent: EventT): (EventT, Bool) {
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok

            let startMark = token.startMark
            var endMark = token.startMark

            var implicit = true
            if (token.typ == TokenTypeT_DOCUMENT_END_TOKEN) {
                endMark = token.endMark
                skipToken(parser)
                implicit = false
            }
            parser.tagDirectives.clear()

            parser.state = ParserStateT_PARSE_DOCUMENT_START_STATE
            event = EventT()

            event.typ = EventTypeT_DOCUMENT_END_EVENT
            event.startMark = startMark
            event.endMark = endMark
            event.implicit = implicit

            (event, true)
    }
}

func parserParseBlockSequenceEntry(parser: ParserT, oEvent: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        let token = peekToken(parser)
        parser.marks.add(token.getOrThrow().startMark)
        skipToken(parser)
    }

    var event = oEvent
    match (peekToken(parser)) {
        case None => return (event, false)
        case Some(tok) =>
            var token = tok
            if (token.typ == TokenTypeT_BLOCK_ENTRY_TOKEN) {
                let mark = token.endMark
                skipToken(parser)
                match (peekToken(parser)) {
                    case None => return (event, false)
                    case Some(tok0) => token = tok0
                }
                if (token.typ != TokenTypeT_BLOCK_ENTRY_TOKEN && token.typ != TokenTypeT_BLOCK_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE)
                    return parserParseNode(parser, event, true, false)
                } else {
                    parser.state = ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE
                    return parserProcessEmptyScalar(mark)
                }
            }
            if (token.typ == TokenTypeT_BLOCK_END_TOKEN) {
                parser.state = parser.states[parser.states.size - 1]
                parser.states = parser.states[0..(parser.states.size - 1)]
                parser.marks = parser.marks[0..(parser.marks.size - 1)]

                event = EventT()

                event.typ = EventTypeT_SEQUENCE_END_EVENT
                event.startMark = token.startMark
                event.endMark = token.endMark

                skipToken(parser)
                return (event, true)
            }

            let contextMark = parser.marks[parser.marks.size - 1]
            parser.marks = parser.marks[0..(parser.marks.size - 1)]
            return (event, parserSetParserErrorContext(
                    parser,
                    "while parsing a block collection",
                    contextMark,
                    "did not find expected '-' indicator",
                    token.startMark
                ))
    }
}

func parserParseIndentlessSequenceEntry(parser: ParserT, oEvent: EventT): (EventT, Bool) {
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok

            if (token.typ == TokenTypeT_BLOCK_ENTRY_TOKEN) {
                let mark = token.endMark
                skipToken(parser)
                match (peekToken(parser)) {
                    case None => return (event, false)
                    case Some(tok0) => token = tok0
                }
                if (token.typ != TokenTypeT_BLOCK_ENTRY_TOKEN && token.typ != TokenTypeT_KEY_TOKEN && token.typ !=
                    TokenTypeT_VALUE_TOKEN && token.typ != TokenTypeT_BLOCK_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE)
                    return parserParseNode(parser, event, true, false)
                }
                parser.state = ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE
                return parserProcessEmptyScalar(mark)
            }
            parser.state = parser.states[parser.states.size - 1]
            parser.states = parser.states[0..(parser.states.size - 1)]

            event = EventT()

            event.typ = EventTypeT_SEQUENCE_END_EVENT
            event.startMark = token.startMark
            event.endMark = token.startMark

            return (event, true)
    }
}

func parserParseBlockMappingKey(parser: ParserT, oEvent: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        let token = peekToken(parser)
        parser.marks.add(token.getOrThrow().startMark)
        skipToken(parser)
    }
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok
            if (token.typ == TokenTypeT_KEY_TOKEN) {
                let mark = token.endMark
                skipToken(parser)
                match (peekToken(parser)) {
                    case None => return (event, false)
                    case Some(tok0) => token = tok0
                }
                if (token.typ != TokenTypeT_KEY_TOKEN && token.typ != TokenTypeT_VALUE_TOKEN && token.typ !=
                    TokenTypeT_BLOCK_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE)
                    return parserParseNode(parser, event, true, true)
                } else {
                    parser.state = ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE
                    return parserProcessEmptyScalar(mark)
                }
            } else if (token.typ == TokenTypeT_BLOCK_END_TOKEN) {
                parser.state = parser.states[parser.states.size - 1]
                parser.states = parser.states[0..(parser.states.size - 1)]
                parser.marks = parser.marks[0..(parser.marks.size - 1)]
                event = EventT()

                event.typ = EventTypeT_MAPPING_END_EVENT
                event.startMark = token.startMark
                event.endMark = token.endMark

                skipToken(parser)
                return (event, true)
            }
            let contextMark = parser.marks[parser.marks.size - 1]
            parser.marks = parser.marks[0..(parser.marks.size - 1)]
            (event, parserSetParserErrorContext(
                    parser,
                    "while parsing a block mapping",
                    contextMark,
                    "did not find expected key",
                    token.startMark
                ))
    }
}

func parserParseBlockMappingValue(parser: ParserT, oEvent: EventT): (EventT, Bool) {
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok

            if (token.typ == TokenTypeT_VALUE_TOKEN) {
                let mark = token.endMark
                skipToken(parser)
                match (peekToken(parser)) {
                    case None => return (event, false)
                    case Some(tok0) => token = tok0
                }
                if (token.typ != TokenTypeT_KEY_TOKEN && token.typ != TokenTypeT_VALUE_TOKEN && token.typ !=
                    TokenTypeT_BLOCK_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE)
                    return parserParseNode(parser, event, true, true)
                }
                parser.state = ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE
                return parserProcessEmptyScalar(mark)
            }
            parser.state = ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE
            return parserProcessEmptyScalar(token.startMark)
    }
}

func parserParseFlowSequenceEntry(parser: ParserT, oEvent: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        let token = peekToken(parser)
        parser.marks.add(token.getOrThrow().startMark)
        skipToken(parser)
    }

    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok

            if (token.typ != TokenTypeT_FLOW_SEQUENCE_END_TOKEN) {
                if (!first) {
                    if (token.typ == TokenTypeT_FLOW_ENTRY_TOKEN) {
                        skipToken(parser)
                        match (peekToken(parser)) {
                            case None => return (event, false)
                            case Some(tok0) => token = tok0
                        }
                    } else {
                        let contextMark = parser.marks[parser.marks.size - 1]
                        parser.marks = parser.marks[0..(parser.marks.size - 1)]
                        return (event, parserSetParserErrorContext(
                                parser,
                                "while parsing a flow sequence",
                                contextMark,
                                "did not find expected ',' or ']'",
                                token.startMark
                            ))
                    }
                }

                if (token.typ == TokenTypeT_KEY_TOKEN) {
                    parser.state = ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE
                    event = EventT()

                    event.typ = EventTypeT_MAPPING_START_EVENT
                    event.startMark = token.startMark
                    event.endMark = token.endMark
                    event.implicit = true
                    event.style = MappingStyleT_FLOW_MAPPING_STYLE

                    skipToken(parser)
                    return (event, true)
                } else if (token.typ != TokenTypeT_FLOW_SEQUENCE_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE)
                    return parserParseNode(parser, event, false, false)
                }
            }

            parser.state = parser.states[parser.states.size - 1]
            parser.states = parser.states[0..(parser.states.size - 1)]
            parser.marks = parser.marks[0..(parser.marks.size - 1)]

            event = EventT()

            event.typ = EventTypeT_SEQUENCE_END_EVENT
            event.startMark = token.startMark
            event.endMark = token.endMark

            skipToken(parser)
            (event, true)
    }
}

/* func parserParseFlowSequenceEntryMappingKey(parser: ParserT, oEvent: EventT): (EventT, Bool) {
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok
            if (token.typ != TokenTypeT_VALUE_TOKEN && token.typ != TokenTypeT_FLOW_ENTRY_TOKEN && token.typ !=
                TokenTypeT_FLOW_SEQUENCE_END_TOKEN) {
                parser.states.add(ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE)
                return parserParseNode(parser, event, false, false)
            }
            let mark = token.endMark
            skipToken(parser)
            parser.state = ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE
            return parserProcessEmptyScalar(mark)
    }
   }*/

/* func parserParseFlowSequenceEntryMappingValue(parser: ParserT, oEvent: EventT): (EventT, Bool) {
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok
            if (token.typ == TokenTypeT_VALUE_TOKEN) {
                skipToken(parser)
                let t = match (peekToken(parser)) {
                    case None => return (event, false)
                    case Some(tok0) => tok0
                }
                if (t.typ != TokenTypeT_FLOW_ENTRY_TOKEN && t.typ != TokenTypeT_FLOW_SEQUENCE_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE)
                    return parserParseNode(parser, event, false, false)
                }
            }
            parser.state = ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE
            return parserProcessEmptyScalar(token.startMark)
    }
   }

   func parserParseFlowSequenceEntryMappingEnd(parser: ParserT, oEvent: EventT): (EventT, Bool) {
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok
            parser.state = ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE
            event = EventT()
            event.typ = EventTypeT_MAPPING_END_EVENT
            event.startMark = token.startMark
            event.endMark = token.startMark
            return (event, true)
    }
   }*/
func parserParseFlowMappingKey(parser: ParserT, oEvent: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        let token = peekToken(parser)
        parser.marks.add(token.getOrThrow().startMark)
        skipToken(parser)
    }

    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok

            if (token.typ != TokenTypeT_FLOW_MAPPING_END_TOKEN) {
                if (!first) {
                    if (token.typ == TokenTypeT_FLOW_ENTRY_TOKEN) {
                        skipToken(parser)
                        match (peekToken(parser)) {
                            case None => return (event, false)
                            case Some(tok0) => token = tok0
                        }
                    } else {
                        let contextMark = parser.marks[parser.marks.size - 1]
                        parser.marks = parser.marks[0..(parser.marks.size - 1)]
                        return (event, parserSetParserErrorContext(
                                parser,
                                "while parsing a flow mapping",
                                contextMark,
                                "did not find expected ',' or '}'",
                                token.startMark
                            ))
                    }
                }

                if (token.typ == TokenTypeT_KEY_TOKEN) {
                    skipToken(parser)
                    match (peekToken(parser)) {
                        case None => return (event, false)
                        case Some(tok0) => token = tok0
                    }
                    if (token.typ != TokenTypeT_VALUE_TOKEN && token.typ != TokenTypeT_FLOW_ENTRY_TOKEN && token.typ !=
                        TokenTypeT_FLOW_MAPPING_END_TOKEN) {
                        parser.states.add(ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE)
                        return parserParseNode(parser, event, false, false)
                    } else {
                        parser.state = ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE
                        return parserProcessEmptyScalar(token.startMark)
                    }
                } else if (token.typ != TokenTypeT_FLOW_MAPPING_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE)
                    return parserParseNode(parser, event, false, false)
                }
            }

            parser.state = parser.states[parser.states.size - 1]
            parser.states = parser.states[0..(parser.states.size - 1)]
            parser.marks = parser.marks[0..(parser.marks.size - 1)]
            event = EventT()

            event.typ = EventTypeT_MAPPING_END_EVENT
            event.startMark = token.startMark
            event.endMark = token.endMark

            skipToken(parser)
            (event, true)
    }
}

func parserParseFlowMappingValue(parser: ParserT, oEvent: EventT, empty: Bool): (EventT, Bool) {
    var event = oEvent
    match (peekToken(parser)) {
        case None => (event, false)
        case Some(tok) =>
            var token = tok
            if (empty) {
                parser.state = ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE
                return parserProcessEmptyScalar(token.startMark)
            }
            if (token.typ == TokenTypeT_VALUE_TOKEN) {
                skipToken(parser)
                match (peekToken(parser)) {
                    case None => return (event, false)
                    case Some(tok0) => token = tok0
                }
                if (token.typ != TokenTypeT_FLOW_ENTRY_TOKEN && token.typ != TokenTypeT_FLOW_MAPPING_END_TOKEN) {
                    parser.states.add(ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE)
                    return parserParseNode(parser, event, false, false)
                }
            }
            parser.state = ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE
            return parserProcessEmptyScalar(token.startMark)
    }
}
