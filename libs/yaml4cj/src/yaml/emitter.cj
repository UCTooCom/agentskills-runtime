/**
 * @file
 * This file is baout emitter.
 */
package yaml4cj.yaml

func emitterFlush(emitter: EmitterT): Bool {
    match (emitter.writeHandler) {
        case None => throw Exception("write handler not set")
        case _ => ()
    }

    if (emitter.bufferPos == 0) {
        return true
    }

    try {
        emitter.writeHandler.getOrThrow()(emitter, emitter.buffer[0..emitter.bufferPos])
    } catch (e: Exception) {
        return emitterSetWriterError(emitter, "write error: ${e}")
    }
    emitter.bufferPos = 0
    true
}

func emitterSetWriterError(emitter: EmitterT, problem: String): Bool {
    emitter.error = ErrorTypeT_WRITER_ERROR
    emitter.problem = problem
    false
}

func put(emitter: EmitterT, value: UInt8): Bool {
    if (emitter.bufferPos + 5 >= emitter.buffer.size && !emitterFlush(emitter)) {
        return false
    }
    emitter.buffer[emitter.bufferPos] = value
    emitter.bufferPos++
    emitter.column++
    true
}

func put(emitter: EmitterT, value: Rune): Bool {
    put(emitter, UInt8(UInt32(value)))
}

func putBreak(emitter: EmitterT): Bool {
    if (emitter.bufferPos + 5 >= emitter.buffer.size && !emitterFlush(emitter)) {
        return false
    }
    match (emitter.lineBreak) {
        case BreakT_LN_BREAK =>
            emitter.buffer[emitter.bufferPos] = 0x0A
            emitter.bufferPos += 1
        case _ => throw Exception("unknown line break setting")
    }
    emitter.column = 0
    emitter.line++
    return true
}

func write(emitter: EmitterT, s: Array<UInt8>, iBox: Box<Int64>): Bool {
    let (i, ok) = write(emitter, s, iBox.value)
    iBox.value = i
    return ok
}

func writeBuffer(emitter: EmitterT, s: Array<UInt8>, sStart: Int64, eStart: Int64, l: Int64) {
    for (i in 0..l) {
        emitter.buffer[i + eStart] = s[i + sStart]
    }
}

func write(emitter: EmitterT, s: Array<UInt8>, i: Int64): (Int64, Bool) {
    if (emitter.bufferPos + 5 >= emitter.buffer.size && !emitterFlush(emitter)) {
        return (i, false)
    }
    let p = emitter.bufferPos
    let w = width(s[i])
    match (w) {
        case 4 => writeBuffer(emitter, s, i, p, 4)
        case 3 => writeBuffer(emitter, s, i, p, 3)
        case 2 => writeBuffer(emitter, s, i, p, 2)
        case 1 => writeBuffer(emitter, s, i, p, 1)
        case _ => throw Exception("unknown character width")
    }
    emitter.column++
    emitter.bufferPos += w
    return (i + w, true)
}

func writeAll(emitter: EmitterT, s: Array<UInt8>): Bool {
    var i = 0
    while (i < s.size) {
        let (c, ok) = write(emitter, s, i)
        i = c
        if (!ok) {
            return false
        }
    }
    return true
}

func writeBreak(emitter: EmitterT, s: Array<UInt8>, i: Int64): (Int64, Bool) {
    var c = i
    if (s[c] == 0x0A) {
        if (!putBreak(emitter)) {
            return (c, false)
        }
        c++
    } else {
        let (w, ok) = write(emitter, s, c)
        c = w
        if (!ok) {
            return (c, false)
        }
        emitter.column = 0
        emitter.line++
    }
    (c, true)
}

type WriteHandlerT = (EmitterT, ArrayList<UInt8>) -> Unit

class AnchorDataT {
    var anchor: Array<UInt8> = []
    var alias: Bool = false
}

class TagDataT {
    var handle: Array<UInt8> = []
    var suffix: Array<UInt8> = []
}

class ScalarDataT {
    var value: Array<UInt8> = []
    var multiline: Bool = false
    var flowPlainAllowed: Bool = false
    var blockPlainAllowed: Bool = false
    var singleQuotedAllowed: Bool = false
    var blockAllowed: Bool = false
    var style: ScalarStyleT = ScalarStyleT_ANY_SCALAR_STYLE
}

class EmitterT {
    var error: ErrorTypeT = ErrorTypeT_NO_ERROR
    var problem: String = ""

    var writeHandler: ?WriteHandlerT = None
    var outputBuffer: ArrayList<UInt8> = ArrayList<UInt8>()

    var buffer: ArrayList<UInt8> = ArrayList<UInt8>()
    var bufferPos: Int64 = 0

    var rawBuffer: ArrayList<UInt8> = ArrayList<UInt8>()
    var rawBufferPos: Int64 = 0

    var encoding: EncodingT = EncodingT_ANY_ENCODING

    var canonical: Bool = false
    var bestIndent: Int64 = 0
    var bestWidth: Int64 = 0
    var unicode: Bool = false
    var lineBreak: BreakT = BreakT_ANY_BREAK

    var state: EmitterStateT = EmitterStateT_EMIT_STREAM_START_STATE
    var states: ArrayList<EmitterStateT> = ArrayList<EmitterStateT>()

    var events: ArrayList<EventT> = ArrayList<EventT>()
    var eventsHead: Int64 = 0

    var indents: ArrayList<Int64> = ArrayList<Int64>()
    var indent: Int64 = 0

    let tagDirectives: ArrayList<TagDirectiveT> = ArrayList<TagDirectiveT>()

    var flowLevel: Int64 = 0

    var rootContext: Bool = false
    var sequenceContext: Bool = false
    var mappingContext: Bool = false
    var simpleKeyContext: Bool = false

    var line: Int64 = 0
    var column: Int64 = 0
    var whitespace: Bool = false
    var indention: Bool = false
    var openEnded: Bool = false

    var anchorData: AnchorDataT = AnchorDataT()
    var tagData: TagDataT = TagDataT()
    var scalarData: ScalarDataT = ScalarDataT()

    var document: DocumentT = DocumentT()
}

func emitterSetEmitterError(emitter: EmitterT, problem: String): Bool {
    emitter.error = ErrorTypeT_EMITTER_ERROR
    emitter.problem = problem
    return false
}

func emitterNeedMoreEvents(emitter: EmitterT): Bool {
    if (emitter.eventsHead == emitter.events.size) {
        return true
    }
    let accumulate = match (emitter.events[emitter.eventsHead].typ) {
        case EventTypeT_DOCUMENT_START_EVENT => 1
        case EventTypeT_SEQUENCE_START_EVENT => 2
        case EventTypeT_MAPPING_START_EVENT => 3
        case _ => return false
    }

    if (emitter.events.size - emitter.eventsHead > accumulate) {
        return false
    }

    var level = 0
    for (i in emitter.eventsHead..emitter.events.size) {
        match (emitter.events[i].typ) {
            case EventTypeT_STREAM_START_EVENT | EventTypeT_DOCUMENT_START_EVENT | EventTypeT_SEQUENCE_START_EVENT | EventTypeT_MAPPING_START_EVENT =>level++
            case EventTypeT_STREAM_END_EVENT | EventTypeT_DOCUMENT_END_EVENT | EventTypeT_SEQUENCE_END_EVENT | EventTypeT_MAPPING_END_EVENT =>level--
            case _ => ()
        }
        if (level == 0) {
            return false
        }
    }
    true
}

func emitterAnalyzeEventResolve0(emitter: EmitterT, event: EventT): ?Bool {
    if (!emitterAnalyzeScalar(emitter, event.value)) {
        return false
    }
    None
}

func emitterAnalyzeEventResolve1(): ?Bool {
    None
}

func emitterAnalyzeEventResolve2(): ?Bool {
    None
}

func emitterAnalyzeEvent(emitter: EmitterT, event: EventT): Bool {
    emitter.anchorData.anchor = []
    emitter.tagData.handle = []
    emitter.tagData.suffix = []
    emitter.scalarData.value = []

    let r = match (event.typ) {
        case EventTypeT_SCALAR_EVENT => emitterAnalyzeEventResolve0(emitter, event)
        case EventTypeT_SEQUENCE_START_EVENT => emitterAnalyzeEventResolve1()
        case EventTypeT_MAPPING_START_EVENT => emitterAnalyzeEventResolve2()
        case _ => true
    }
    if (let Some(ok) <- r) {
        ok
    } else {
        true
    }
}

func emitterAnalyzeScalarResolve0(
    value: Array<UInt8>,
    i: Int64,
    followedByWhitespace: Bool,
    precededByWhitespace: Bool,
    flowIndicatorsBox: Box<Bool>,
    blockIndicatorsBox: Box<Bool>
) {
    if (i == 0) {
        match (Rune(UInt32(value[i]))) {
            case '#' | ',' | '[' | ']' | '{' | '}' | '&' | '*' | '!' | '|' | '>' | '\'' | '"' | '%' | '@' | '`' =>
                flowIndicatorsBox.value = true
                blockIndicatorsBox.value = true
            case '?' | ':' =>
                flowIndicatorsBox.value = true
                if (followedByWhitespace) {
                    blockIndicatorsBox.value = true
                }
            case '-' =>
                if (followedByWhitespace) {
                    flowIndicatorsBox.value = true
                    blockIndicatorsBox.value = true
                }
            case _ => ()
        }
    } else {
        match (Rune(UInt32(value[i]))) {
            case ',' | '?' | '[' | ']' | '{' | '}' => flowIndicatorsBox.value = true
            case ':' =>
                flowIndicatorsBox.value = true
                if (followedByWhitespace) {
                    blockIndicatorsBox.value = true
                }
            case '#' =>
                if (precededByWhitespace) {
                    flowIndicatorsBox.value = true
                    blockIndicatorsBox.value = true
                }
            case _ => ()
        }
    }
}

func emitterAnalyzeScalarResolve1(
    emitter: EmitterT,
    value: Array<UInt8>,
    i: Int64,
    specialCharactersBox: Box<Bool>,
    leadingSpaceBox: Box<Bool>,
    trailingSpaceBox: Box<Bool>,
    previousBreakBox: Box<Bool>,
    breakSpaceBox: Box<Bool>,
    previousSpaceBox: Box<Bool>,
    lineBreaksBox: Box<Bool>,
    leadingBreakBox: Box<Bool>,
    trailingBreakBox: Box<Bool>,
    spaceBreakBox: Box<Bool>
) {
    if (!isPrintable(value, i) || !isAscii(value, i) && !emitter.unicode) {
        specialCharactersBox.value = true
    }

    if (isSpace(value, i)) {
        if (i == 0) {
            leadingSpaceBox.value = true
        }
        if (i + width(value[i]) == value.size) {
            trailingSpaceBox.value = true
        }
        if (previousBreakBox.value) {
            breakSpaceBox.value = true
        }
        previousSpaceBox.value = true
        previousBreakBox.value = false
    } else if (isBreak(value, i)) {
        lineBreaksBox.value = true
        if (i == 0) {
            leadingBreakBox.value = true
        }
        if (i + width(value[i]) == value.size) {
            trailingBreakBox.value = true
        }
        if (previousSpaceBox.value) {
            spaceBreakBox.value = true
        }
        previousSpaceBox.value = false
        previousBreakBox.value = true
    } else {
        previousSpaceBox.value = false
        previousBreakBox.value = false
    }
}

func emitterAnalyzeScalar(emitter: EmitterT, value: Array<UInt8>): Bool {
    var blockIndicators = false
    var flowIndicators = false
    var lineBreaks = false
    var specialCharacters = false

    var leadingSpace = false
    var leadingBreak = false
    var trailingSpace = false
    var trailingBreak = false
    var breakSpace = false
    var spaceBreak = false

    var precededByWhitespace = false
    var followedByWhitespace = false
    var previousSpace = false
    var previousBreak = false

    emitter.scalarData.value = value

    if (value.size == 0) {
        emitter.scalarData.multiline = false
        emitter.scalarData.flowPlainAllowed = false
        emitter.scalarData.blockPlainAllowed = true
        emitter.scalarData.singleQuotedAllowed = true
        emitter.scalarData.blockAllowed = false
        return true
    }

    if (value.size >= 3 &&
        ((value[0] == 0x2D && value[1] == 0x2D && value[2] == 0x2D) ||
        (value[0] == 0x2E && value[1] == 0x2E && value[2] == 0x2E))) {
        blockIndicators = true
        flowIndicators = true
    }

    precededByWhitespace = true
    var i = 0
    var w = 0
    let flowIndicatorsBox = Box<Bool>(flowIndicators)
    let blockIndicatorsBox = Box<Bool>(blockIndicators)
    let specialCharactersBox = Box<Bool>(specialCharacters)
    let leadingSpaceBox = Box<Bool>(leadingSpace)
    let trailingSpaceBox = Box<Bool>(trailingSpace)
    let previousBreakBox = Box<Bool>(previousBreak)
    let previousSpaceBox = Box<Bool>(previousSpace)
    let breakSpaceBox = Box<Bool>(breakSpace)
    let lineBreaksBox = Box<Bool>(lineBreaks)
    let leadingBreakBox = Box<Bool>(leadingBreak)
    let trailingBreakBox = Box<Bool>(trailingBreak)
    let spaceBreakBox = Box<Bool>(spaceBreak)
    while (i < value.size) {
        w = width(value[i])
        followedByWhitespace = i + w >= value.size || isBlank(value, i + w)

        emitterAnalyzeScalarResolve0(
            value,
            i,
            followedByWhitespace,
            precededByWhitespace,
            flowIndicatorsBox,
            blockIndicatorsBox
        )
        flowIndicators = flowIndicatorsBox.value
        blockIndicators = blockIndicatorsBox.value

        emitterAnalyzeScalarResolve1(
            emitter,
            value,
            i,
            specialCharactersBox,
            leadingSpaceBox,
            trailingSpaceBox,
            previousBreakBox,
            breakSpaceBox,
            previousSpaceBox,
            lineBreaksBox,
            leadingBreakBox,
            trailingBreakBox,
            spaceBreakBox
        )
        specialCharacters = specialCharactersBox.value
        leadingSpace = leadingSpaceBox.value
        trailingSpace = trailingSpaceBox.value
        previousBreak = previousBreakBox.value
        breakSpace = breakSpaceBox.value
        previousSpace = previousSpaceBox.value
        lineBreaks = lineBreaksBox.value
        leadingBreak = leadingBreakBox.value
        trailingBreak = trailingBreakBox.value
        spaceBreak = spaceBreakBox.value

        precededByWhitespace = isBlankz(value, i)

        i += w
    }

    emitter.scalarData.multiline = lineBreaks
    emitter.scalarData.flowPlainAllowed = true
    emitter.scalarData.blockPlainAllowed = true
    emitter.scalarData.singleQuotedAllowed = true
    emitter.scalarData.blockAllowed = true

    if (leadingSpace || leadingBreak || trailingSpace || trailingBreak) {
        emitter.scalarData.flowPlainAllowed = false
        emitter.scalarData.blockPlainAllowed = false
    }
    if (trailingSpace) {
        emitter.scalarData.blockAllowed = false
    }
    if (breakSpace) {
        emitter.scalarData.flowPlainAllowed = false
        emitter.scalarData.blockPlainAllowed = false
        emitter.scalarData.singleQuotedAllowed = false
    }
    if (spaceBreak || specialCharacters) {
        emitter.scalarData.flowPlainAllowed = false
        emitter.scalarData.blockPlainAllowed = false
        emitter.scalarData.singleQuotedAllowed = false
        emitter.scalarData.blockAllowed = false
    }
    if (lineBreaks) {
        emitter.scalarData.flowPlainAllowed = false
        emitter.scalarData.blockPlainAllowed = false
    }
    if (flowIndicators) {
        emitter.scalarData.flowPlainAllowed = false
    }
    if (blockIndicators) {
        emitter.scalarData.blockPlainAllowed = false
    }
    true
}

func emitterStateMachine(emitter: EmitterT, event: EventT): (EventT, Bool) {
    match (emitter.state) {
        case EmitterStateT_EMIT_STREAM_START_STATE => emitterEmitStreamStart(emitter, event)
        case EmitterStateT_EMIT_FIRST_DOCUMENT_START_STATE => emitterEmitDocumentStart(emitter, event, true)
        case EmitterStateT_EMIT_DOCUMENT_START_STATE => emitterEmitDocumentStart(emitter, event, false)
        case EmitterStateT_EMIT_DOCUMENT_CONTENT_STATE => emitterEmitDocumentContent(emitter, event)
        case EmitterStateT_EMIT_DOCUMENT_END_STATE => emitterEmitDocumentEnd(emitter, event)
        case EmitterStateT_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE => emitterEmitFlowSequenceItem(emitter, event, true)
        case EmitterStateT_EMIT_FLOW_SEQUENCE_ITEM_STATE => emitterEmitFlowSequenceItem(emitter, event, false)
        case EmitterStateT_EMIT_FLOW_MAPPING_FIRST_KEY_STATE => emitterEmitFlowMappingKey(emitter, event, true)
        case EmitterStateT_EMIT_FLOW_MAPPING_KEY_STATE => emitterEmitFlowMappingKey(emitter, event, false)

        case EmitterStateT_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE => emitterEmitBlockSequenceItem(emitter, event, true)
        case EmitterStateT_EMIT_BLOCK_SEQUENCE_ITEM_STATE => emitterEmitBlockSequenceItem(emitter, event, false)
        case EmitterStateT_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE => emitterEmitBlockMappingKey(emitter, event, true)
        case EmitterStateT_EMIT_BLOCK_MAPPING_KEY_STATE => emitterEmitBlockMappingKey(emitter, event, false)
        case EmitterStateT_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE => emitterEmitBlockMappingValue(emitter, event, true)
        case _ => (event, emitterSetEmitterError(emitter, "unsupport state: ${emitter.state} and type: ${event.typ}"))
    }
}

func emitterEmitStreamStart(emitter: EmitterT, event: EventT): (EventT, Bool) {
    if (event.typ != EventTypeT_STREAM_START_EVENT) {
        return (event, emitterSetEmitterError(emitter, "expected STREAM-START"))
    }
    if (emitter.encoding == EncodingT_ANY_ENCODING) {
        emitter.encoding = event.encoding
        if (emitter.encoding == EncodingT_ANY_ENCODING) {
            emitter.encoding = EncodingT_UTF8_ENCODING
        }
    }
    if (emitter.bestIndent < 2 || emitter.bestIndent > 9) {
        emitter.bestIndent = 2
    }
    if (emitter.bestWidth >= 0 && emitter.bestWidth <= emitter.bestIndent * 2) {
        emitter.bestWidth = 80
    }
    if (emitter.bestWidth < 0) {
        emitter.bestWidth = (1 << 31) - 1
    }
    if (emitter.lineBreak == BreakT_ANY_BREAK) {
        emitter.lineBreak = BreakT_LN_BREAK
    }

    emitter.indent = -1
    emitter.line = 0
    emitter.column = 0
    emitter.whitespace = true
    emitter.indention = true
    emitter.state = EmitterStateT_EMIT_FIRST_DOCUMENT_START_STATE
    (event, true)
}

func emitterEmitDocumentStart(emitter: EmitterT, event: EventT, first: Bool): (EventT, Bool) {
    if (event.typ == EventTypeT_DOCUMENT_START_EVENT) {
        var implicit = event.implicit
        if (!first || emitter.canonical) {
            implicit = false
        }

        if (!implicit &&
            (!emitterWriteIndent(emitter) || (!emitterWriteIndicator(
            emitter,
            [0x2D, 0x2D, 0x2D],
            true,
            false,
            false
        )) || (emitter.canonical && !emitterWriteIndent(emitter)))) {
            return (event, false)
        }

        emitter.state = EmitterStateT_EMIT_DOCUMENT_CONTENT_STATE
        return (event, true)
    }

    if (event.typ == EventTypeT_STREAM_END_EVENT) {
        if ((emitter.openEnded &&
            (!emitterWriteIndicator(emitter, [0x2E, 0x2E, 0x2E], true, false, false) || !emitterWriteIndent(emitter))) ||
            !emitterFlush(emitter)) {
            return (event, false)
        }
        emitter.state = EmitterStateT_EMIT_END_STATE
        return (event, true)
    }

    return (event, emitterSetEmitterError(emitter, "expected DOCUMENT-START or STREAM-END"))
}

func emitterIncreaseIndent(emitter: EmitterT, flow: Bool, indentless: Bool): Bool {
    emitter.indents.add(emitter.indent)
    if (emitter.indent < 0) {
        if (flow) {
            emitter.indent = emitter.bestIndent
        } else {
            emitter.indent = 0
        }
    } else if (!indentless) {
        emitter.indent += emitter.bestIndent
    }
    true
}

func emitterWriteIndicator(
    emitter: EmitterT,
    indicator: Array<UInt8>,
    needWhitespace: Bool,
    isWhitespace: Bool,
    isIndention: Bool
): Bool {
    if (needWhitespace && !emitter.whitespace) {
        if (!put(emitter, 0x20)) {
            return false
        }
    }
    if (!writeAll(emitter, indicator)) {
        return false
    }
    emitter.whitespace = isWhitespace
    emitter.indention = (emitter.indention && isIndention)
    emitter.openEnded = false
    true
}

func emitterWriteIndent(emitter: EmitterT): Bool {
    let indent = if (emitter.indent < 0) {
        0
    } else {
        emitter.indent
    }
    if (!emitter.indention || emitter.column > indent || (emitter.column == indent && !emitter.whitespace)) {
        if (!putBreak(emitter)) {
            return false
        }
    }
    while (emitter.column < indent) {
        if (!put(emitter, 0x20)) {
            return false
        }
    }
    emitter.whitespace = true
    emitter.indention = true
    true
}

func emitterEmitNode(
    emitter: EmitterT,
    event: EventT,
    root: Bool,
    sequence: Bool,
    mapping: Bool,
    simpleKey: Bool
): (EventT, Bool) {
    emitter.rootContext = root
    emitter.sequenceContext = sequence
    emitter.mappingContext = mapping
    emitter.simpleKeyContext = simpleKey

    match (event.typ) {
        // case EventTypeT_ALIAS_EVENT => emitterEmitAlias(emitter, event)
        case EventTypeT_SCALAR_EVENT => emitterEmitScalar(emitter, event)
        case EventTypeT_SEQUENCE_START_EVENT => emitterEmitSequenceStart(emitter, event)
        case EventTypeT_MAPPING_START_EVENT => emitterEmitMappingStart(emitter, event)
        case _ =>
            (event, emitterSetEmitterError(
                    emitter,
                    "expected SCALAR, SEQUENCE-START, or MAPPING-START, but got ${event.typ}"
                ))
    }
}

func emitterEmitScalar(emitter: EmitterT, event: EventT): (EventT, Bool) {
    if (!emitterSelectScalarStyle(emitter, event)) {
        return (event, false)
    }

    if (!emitterIncreaseIndent(emitter, true, false)) {
        return (event, false)
    }
    if (!emitterProcessScalar(emitter)) {
        return (event, false)
    }
    emitter.indent = emitter.indents[emitter.indents.size - 1]
    emitter.indents = emitter.indents[0..(emitter.indents.size - 1)]
    emitter.state = emitter.states[emitter.states.size - 1]
    emitter.states = emitter.states[0..(emitter.states.size - 1)]
    (event, true)
}

func emitterSelectScalarStyleResolve0(
    emitter: EmitterT,
    oStyle: ScalarStyleT,
    event: EventT,
    noTag: Bool
): ScalarStyleT {
    var style = oStyle
    if (emitter.flowLevel > 0 && !emitter.scalarData.flowPlainAllowed || emitter.flowLevel == 0 &&
        !emitter.scalarData.blockPlainAllowed) {
        style = ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE
    }
    if (emitter.scalarData.value.size == 0 && (emitter.flowLevel > 0 || emitter.simpleKeyContext)) {
        style = ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE
    }
    if (noTag && !event.implicit) {
        style = ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE
    }
    style
}

func emitterSelectScalarStyleResolve1(emitter: EmitterT, oStyle: ScalarStyleT): ScalarStyleT {
    var style = oStyle
    if (style == ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE) {
        if (!emitter.scalarData.singleQuotedAllowed) {
            style = ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE
        }
    }
    if (style == ScalarStyleT_LITERAL_SCALAR_STYLE || style == ScalarStyleT_FOLDED_SCALAR_STYLE) {
        if (!emitter.scalarData.blockAllowed || emitter.flowLevel > 0 || emitter.simpleKeyContext) {
            style = ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE
        }
    }
    style
}

func emitterSelectScalarStyle(emitter: EmitterT, event: EventT): Bool {
    let noTag = emitter.tagData.handle.size == 0 && emitter.tagData.suffix.size == 0
    if (noTag && !event.implicit && !event.quotedImplicit) {
        return emitterSetEmitterError(emitter, "neither tag nor implicit flags are specified")
    }

    var style = event.scalarStyle()
    if (style == ScalarStyleT_ANY_SCALAR_STYLE) {
        style = ScalarStyleT_PLAIN_SCALAR_STYLE
    }
    if (emitter.canonical) {
        style = ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE
    }
    if (emitter.simpleKeyContext && emitter.scalarData.multiline) {
        style = ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE
    }

    if (style == ScalarStyleT_PLAIN_SCALAR_STYLE) {
        style = emitterSelectScalarStyleResolve0(emitter, style, event, noTag)
    }

    style = emitterSelectScalarStyleResolve1(emitter, style)

    if (noTag && !event.quotedImplicit && style != ScalarStyleT_PLAIN_SCALAR_STYLE) {
        emitter.tagData.handle = [0x21]
    }
    emitter.scalarData.style = style
    return true
}

func emitterProcessScalar(emitter: EmitterT): Bool {
    match (emitter.scalarData.style) {
        case ScalarStyleT_PLAIN_SCALAR_STYLE =>
            emitterWritePlainScalar(
                emitter,
                emitter.scalarData.value,
                !emitter.simpleKeyContext
            )

        case ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE =>
            emitterWriteSingleQuotedScalar(
                emitter,
                emitter.scalarData.value,
                !emitter.simpleKeyContext
            )

        case ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE =>
            emitterWriteDoubleQuotedScalar(
                emitter,
                emitter.scalarData.value,
                !emitter.simpleKeyContext
            )

        case ScalarStyleT_LITERAL_SCALAR_STYLE => emitterWriteLiteralScalar(emitter, emitter.scalarData.value)

        case _ => throw Exception("unknown scalar style")
    }
}

func emitterWritePlainScalarResolve0(
    emitter: EmitterT,
    value: Array<UInt8>,
    allowBreaks: Bool,
    iBox: Box<Int64>,
    spacesBox: Box<Bool>
): Bool {
    if (allowBreaks && !spacesBox.value && emitter.column > emitter.bestWidth && !isSpace(value, iBox.value + 1)) {
        if (!emitterWriteIndent(emitter)) {
            return false
        }
        iBox.value += width(value[iBox.value])
    } else {
        let (c, ok) = write(emitter, value, iBox.value)
        iBox.value = c
        if (!ok) {
            return false
        }
    }
    spacesBox.value = true
    return true
}

func emitterWritePlainScalarResolve2(
    emitter: EmitterT,
    value: Array<UInt8>,
    iBox: Box<Int64>,
    spacesBox: Box<Bool>,
    breaksBox: Box<Bool>
): Bool {
    if (breaksBox.value) {
        if (!emitterWriteIndent(emitter)) {
            return false
        }
    }
    let (c, ok) = write(emitter, value, iBox.value)
    iBox.value = c
    if (!ok) {
        return false
    }
    emitter.indention = false
    spacesBox.value = false
    breaksBox.value = false
    return true
}

func emitterWritePlainScalarLoop(
    emitter: EmitterT,
    value: Array<UInt8>,
    allowBreaks: Bool,
    spacesBox: Box<Bool>,
    breaksBox: Box<Bool>,
    iBox: Box<Int64>
) {
    if (isSpace(value, iBox.value)) {
        emitterWritePlainScalarResolve0(emitter, value, allowBreaks, iBox, spacesBox)
    } else {
        emitterWritePlainScalarResolve2(emitter, value, iBox, spacesBox, breaksBox)
    }
}

func emitterWritePlainScalar(emitter: EmitterT, value: Array<UInt8>, allowBreaks: Bool): Bool {
    if (!emitter.whitespace && !put(emitter, 0x20)) {
        return false
    }

    var spacesBox = Box<Bool>(false)
    var breaksBox = Box<Bool>(false)
    var iBox = Box<Int64>(0)
    while (iBox.value < value.size) {
        emitterWritePlainScalarLoop(emitter, value, allowBreaks, spacesBox, breaksBox, iBox)
    }

    emitter.whitespace = false
    emitter.indention = false
    if (emitter.rootContext) {
        emitter.openEnded = true
    }

    true
}

func emitterWriteSingleQuotedScalarReslove0(
    emitter: EmitterT,
    value: Array<UInt8>,
    allowBreaks: Bool,
    iBox: Box<Int64>,
    spacesBox: Box<Bool>
): Bool {
    if (allowBreaks && !spacesBox.value && emitter.column > emitter.bestWidth && iBox.value > 0 && iBox.value < value.
    size - 1 && !isSpace(value, iBox.value + 1)) {
        if (!emitterWriteIndent(emitter)) {
            return false
        }
        iBox.value += width(value[iBox.value])
    } else {
        let (c, ok) = write(emitter, value, iBox.value)
        iBox.value = c
        if (!ok) {
            return false
        }
    }
    spacesBox.value = true
    return true
}

func emitterWriteSingleQuotedScalarReslove2(
    emitter: EmitterT,
    value: Array<UInt8>,
    iBox: Box<Int64>,
    spacesBox: Box<Bool>,
    breaksBox: Box<Bool>
): Bool {
    if (breaksBox.value) {
        if (!emitterWriteIndent(emitter)) {
            return false
        }
    }
    if (value[iBox.value] == 0x27) {
        if (!put(emitter, 0x27)) {
            return false
        }
    }
    let (c, ok) = write(emitter, value, iBox.value)
    iBox.value = c
    if (!ok) {
        return false
    }
    emitter.indention = false
    spacesBox.value = false
    breaksBox.value = false
    return true
}

func emitterWriteSingleQuotedScalarLoop(
    emitter: EmitterT,
    value: Array<UInt8>,
    allowBreaks: Bool,
    spacesBox: Box<Bool>,
    breaksBox: Box<Bool>,
    iBox: Box<Int64>
) {
    if (isSpace(value, iBox.value)) {
        emitterWriteSingleQuotedScalarReslove0(emitter, value, allowBreaks, iBox, spacesBox)
    } else {
        emitterWriteSingleQuotedScalarReslove2(emitter, value, iBox, spacesBox, breaksBox)
    }
}

func emitterWriteSingleQuotedScalar(emitter: EmitterT, value: Array<UInt8>, allowBreaks: Bool): Bool {
    if (!emitterWriteIndicator(emitter, [0x27], true, false, false)) {
        return false
    }

    var spacesBox = Box<Bool>(false)
    var breaksBox = Box<Bool>(false)
    let iBox = Box<Int64>(0)
    while (iBox.value < value.size) {
        emitterWriteSingleQuotedScalarLoop(emitter, value, allowBreaks, spacesBox, breaksBox, iBox)
    }
    if (!emitterWriteIndicator(emitter, [0x27], false, false, false)) {
        return false
    }
    emitter.whitespace = false
    emitter.indention = false
    true
}

func emitterWriteDoubleQuotedScalarResolve(emitter: EmitterT, v: UInt32): Bool {
    match (v) {
        case 0x00 => put(emitter, r'0')
        case 0x07 => put(emitter, r'a')
        case 0x08 => put(emitter, r'b')
        case 0x09 => put(emitter, r't')
        case 0x0A => put(emitter, r'n')
        case 0x0b => put(emitter, r'v')
        case 0x0c => put(emitter, r'f')
        case 0x0d => put(emitter, r'r')
        case 0x1b => put(emitter, r'e')
        case 0x22 => put(emitter, r'"')
        case 0x5c => put(emitter, r'\\')
        case 0x85 => put(emitter, r'N')
        case 0xA0 => put(emitter, r'_')
        case 0x2028 => put(emitter, r'L')
        case 0x2029 => put(emitter, r'P')
        case _ =>
            var o = false
            let w = if (v <= 0xFF) {
                o = put(emitter, r'x')
                2
            } else if (v <= 0xFFFF) {
                o = put(emitter, r'u')
                4
            } else {
                o = put(emitter, r'U')
                8
            }
            var k = (w - 1) * 4
            while (o && k >= 0) {
                let digit = UInt8((v >> UInt32(k)) & 0x0F)
                if (digit < 10) {
                    o = put(emitter, digit + 0x30)
                } else {
                    o = put(emitter, digit + 0x41 - 10)
                }
                k -= 4
            }
            o
    }
}

func emitterWriteDoubleQuotedScalarLoop(
    emitter: EmitterT,
    value: Array<UInt8>,
    allowBreaks: Bool,
    i: Box<Int64>,
    spaces: Box<Bool>
): ?(Bool, Bool) {
    if (containsChinese(value)) {
        if (!write(emitter, value, i)) {
            return (false, false)
        }
        spaces.value = false
    } else if (!isPrintable(value, i.value) || (!emitter.unicode && !isAscii(value, i.value)) || isBom(
        value
    ) || isBreak(
        value,
        i.value
    ) || value[i.value] == 0x22 || value[i.value] == 0x5C) {
        var octet = UInt32(value[i.value])

        let (nw, nv): (Int64, UInt32) = if ((octet & 0x80) == 0x00) {
            (1, UInt32(octet & 0x7F))
        } else if ((octet & 0xE0) == 0xC0) {
            (2, UInt32(octet & 0x1F))
        } else if ((octet & 0xF0) == 0xE0) {
            (3, UInt32(octet & 0x0F))
        } else if ((octet & 0xF8) == 0xF0) {
            (4, UInt32(octet & 0x07))
        } else {
            (0, 0)
        }
        var w = nw
        var v = nv
        for (k in 1..w) {
            octet = UInt32(value[i.value + k])
            v = (v << 6) + (octet & 0x3F)
        }
        i.value += w

        if (!put(emitter, r'\\') || !emitterWriteDoubleQuotedScalarResolve(emitter, v)) {
            return (false, false)
        }
        spaces.value = false
    } else if (isSpace(value, i.value)) {
        if (allowBreaks && !spaces.value && emitter.column > emitter.bestWidth && i.value > 0 && i.value < value.size - 1) {
            if (!emitterWriteIndent(emitter) || (isSpace(value, i.value + 1) && !put(emitter, r'\\'))) {
                return (false, false)
            }
            i.value += width(value[i.value])
        } else if (!write(emitter, value, i)) {
            return (false, false)
        }
        spaces.value = true
    } else {
        if (!write(emitter, value, i)) {
            return (false, false)
        }
        spaces.value = false
    }
    return None
}

func emitterWriteDoubleQuotedScalar(emitter: EmitterT, value: Array<UInt8>, allowBreaks: Bool): Bool {
    if (!emitterWriteIndicator(emitter, [0x22], true, false, false)) {
        return false
    }

    var spaces = Box<Bool>(false)
    var i = Box<Int64>(0)
    while (i.value < value.size) {
        if (let Some((ok, isBreak)) <- emitterWriteDoubleQuotedScalarLoop(
            emitter,
            value,
            allowBreaks,
            i,
            spaces
        )) {
            if (isBreak) {
                break
            }
            return ok
        }
    }
    if (!emitterWriteIndicator(emitter, [0x22], false, false, false)) {
        return false
    }
    emitter.whitespace = false
    emitter.indention = false
    true
}

func emitterWriteBlockScalarHints(emitter: EmitterT, value: Array<UInt8>): Bool {
    if (isSpace(value, 0) || isBreak(value, 0)) {
        let indentHint = [0x30 + UInt8(emitter.bestIndent)]
        if (!emitterWriteIndicator(emitter, indentHint, false, false, false)) {
            return false
        }
    }

    emitter.openEnded = false

    let chompHint: Array<UInt8> = if (value.size == 0) {
        [0x2D]
    } else {
        var i = value.size - 1
        while ((value[i] & 0xC0) == 0x80) {
            i--
        }
        if (!isBreak(value, i)) {
            [0x2D]
        } else if (i == 0) {
            emitter.openEnded = true
            [0x2B]
        } else {
            i--
            while ((value[i] & 0xC0) == 0x80) {
                i--
            }
            if (isBreak(value, i)) {
                emitter.openEnded = true
                [0x2B]
            } else {
                [0x00]
            }
        }
    }
    if (chompHint[0] != 0) {
        if (!emitterWriteIndicator(emitter, chompHint, false, false, false)) {
            return false
        }
    }
    true
}

func emitterWriteLiteralScalar(emitter: EmitterT, value: Array<UInt8>): Bool {
    if (!emitterWriteIndicator(emitter, [0x7C], true, false, false)) {
        return false
    }
    if (!emitterWriteBlockScalarHints(emitter, value)) {
        return false
    }
    if (!putBreak(emitter)) {
        return false
    }
    emitter.indention = true
    emitter.whitespace = true
    var breaks = true
    var i = 0
    while (i < value.size) {
        if (isBreak(value, i)) {
            let (c, ok) = writeBreak(emitter, value, i)
            i = c
            if (!ok) {
                return false
            }
            emitter.indention = true
            breaks = true
        } else {
            if (breaks) {
                if (!emitterWriteIndent(emitter)) {
                    return false
                }
            }
            let (c, ok) = write(emitter, value, i)
            i = c
            if (!ok) {
                return false
            }
            emitter.indention = false
            breaks = false
        }
    }

    true
}

func emitterCheckEmptySequence(emitter: EmitterT): Bool {
    if (emitter.events.size - emitter.eventsHead < 2) {
        return false
    }
    emitter.events[emitter.eventsHead].typ == EventTypeT_SEQUENCE_START_EVENT && emitter.events[emitter.eventsHead + 1].
    typ == EventTypeT_SEQUENCE_END_EVENT
}

func emitterEmitSequenceStart(emitter: EmitterT, event: EventT): (EventT, Bool) {
    if (emitter.flowLevel > 0 || emitter.canonical || event.sequenceStyle() == SequenceStyleT_FLOW_SEQUENCE_STYLE ||
        emitterCheckEmptySequence(emitter)) {
        emitter.state = EmitterStateT_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE
    } else {
        emitter.state = EmitterStateT_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE
    }
    (event, true)
}

func emitterCheckEmptyMapping(emitter: EmitterT): Bool {
    if (emitter.events.size - emitter.eventsHead < 2) {
        return false
    }
    emitter.events[emitter.eventsHead].typ == EventTypeT_MAPPING_START_EVENT && emitter.events[emitter.eventsHead + 1].
    typ == EventTypeT_MAPPING_END_EVENT
}

func emitterEmitMappingStart(emitter: EmitterT, event: EventT): (EventT, Bool) {
    if (emitter.flowLevel > 0 || emitter.canonical || event.mappingStyle() == MappingStyleT_FLOW_MAPPING_STYLE ||
        emitterCheckEmptyMapping(emitter)) {
        emitter.state = EmitterStateT_EMIT_FLOW_MAPPING_FIRST_KEY_STATE
    } else {
        emitter.state = EmitterStateT_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE
    }
    (event, true)
}

func emitterEmitDocumentContent(emitter: EmitterT, event: EventT): (EventT, Bool) {
    emitter.states.add(EmitterStateT_EMIT_DOCUMENT_END_STATE)
    return emitterEmitNode(emitter, event, true, false, false, false)
}

func emitterEmitDocumentEnd(emitter: EmitterT, event: EventT): (EventT, Bool) {
    if (event.typ != EventTypeT_DOCUMENT_END_EVENT) {
        return (event, emitterSetEmitterError(emitter, "expected DOCUMENT-END"))
    }
    if (!emitterWriteIndent(emitter)) {
        return (event, false)
    }
    if (!event.implicit) {
        if (!emitterWriteIndicator(emitter, [0x2E, 0x2E, 0x2E], true, false, false)) {
            return (event, false)
        }
        if (!emitterWriteIndent(emitter)) {
            return (event, false)
        }
    }
    if (!emitterFlush(emitter)) {
        return (event, false)
    }
    emitter.state = EmitterStateT_EMIT_DOCUMENT_START_STATE
    emitter.tagDirectives.clear()
    (event, true)
}

func emitterEmitFlowSequenceItem(emitter: EmitterT, event: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        if (!emitterWriteIndicator(emitter, [0x5B], true, true, false)) {
            return (event, false)
        }
        if (!emitterIncreaseIndent(emitter, true, false)) {
            return (event, false)
        }
        emitter.flowLevel++
    }

    if (event.typ == EventTypeT_SEQUENCE_END_EVENT) {
        emitter.flowLevel--
        emitter.indent = emitter.indents[emitter.indents.size - 1]
        emitter.indents = emitter.indents[0..(emitter.indents.size - 1)]
        if (emitter.canonical && !first) {
            if (!emitterWriteIndicator(emitter, [0x2C], false, false, false)) {
                return (event, false)
            }
            if (!emitterWriteIndent(emitter)) {
                return (event, false)
            }
        }
        if (!emitterWriteIndicator(emitter, [0x5D], false, false, false)) {
            return (event, false)
        }
        emitter.state = emitter.states[emitter.states.size - 1]
        emitter.states = emitter.states[0..(emitter.states.size - 1)]

        return (event, true)
    }
    return (event, false)
}

func emitterCheckSimpleKey(emitter: EmitterT): Bool {
    var length = 0
    match (emitter.events[emitter.eventsHead].typ) {
        case EventTypeT_ALIAS_EVENT => length += emitter.anchorData.anchor.size
        case EventTypeT_SCALAR_EVENT =>
            if (emitter.scalarData.multiline) {
                return false
            }
            length += emitter.anchorData.anchor.size + emitter.tagData.handle.size + emitter.tagData.suffix.size +
                emitter.scalarData.value.size
        case _ => return false
    }
    return length <= 128
}

func emitterEmitFlowMappingKey(emitter: EmitterT, event: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        if (!emitterWriteIndicator(emitter, [0x7B], true, true, false)) {
            return (event, false)
        }
        if (!emitterIncreaseIndent(emitter, true, false)) {
            return (event, false)
        }
        emitter.flowLevel++
    }

    if (event.typ == EventTypeT_MAPPING_END_EVENT) {
        emitter.flowLevel--
        emitter.indent = emitter.indents[emitter.indents.size - 1]
        emitter.indents = emitter.indents[0..(emitter.indents.size - 1)]
        if (emitter.canonical && !first) {
            if (!emitterWriteIndicator(emitter, [0x2C], false, false, false)) {
                return (event, false)
            }
            if (!emitterWriteIndent(emitter)) {
                return (event, false)
            }
        }
        if (!emitterWriteIndicator(emitter, [0x7D], false, false, false)) {
            return (event, false)
        }
        emitter.state = emitter.states[emitter.states.size - 1]
        emitter.states = emitter.states[0..(emitter.states.size - 1)]
        return (event, true)
    }
    return (event, false)
}

func emitterEmitBlockSequenceItem(emitter: EmitterT, event: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        if (!emitterIncreaseIndent(emitter, false, emitter.mappingContext && !emitter.indention)) {
            return (event, false)
        }
    }
    if (event.typ == EventTypeT_SEQUENCE_END_EVENT) {
        emitter.indent = emitter.indents[emitter.indents.size - 1]
        emitter.indents = emitter.indents[0..(emitter.indents.size - 1)]
        emitter.state = emitter.states[emitter.states.size - 1]
        emitter.states = emitter.states[0..(emitter.states.size - 1)]
        return (event, true)
    }
    if (!emitterWriteIndent(emitter)) {
        return (event, false)
    }
    if (!emitterWriteIndicator(emitter, [0x2D], true, false, true)) {
        return (event, false)
    }
    emitter.states.add(EmitterStateT_EMIT_BLOCK_SEQUENCE_ITEM_STATE)
    return emitterEmitNode(emitter, event, false, true, false, false)
}

func emitterEmitBlockMappingKey(emitter: EmitterT, event: EventT, first: Bool): (EventT, Bool) {
    if (first) {
        if (!emitterIncreaseIndent(emitter, false, false)) {
            return (event, false)
        }
    }
    if (event.typ == EventTypeT_MAPPING_END_EVENT) {
        emitter.indent = emitter.indents[emitter.indents.size - 1]
        emitter.indents = emitter.indents[0..(emitter.indents.size - 1)]
        emitter.state = emitter.states[emitter.states.size - 1]
        emitter.states = emitter.states[0..(emitter.states.size - 1)]
        return (event, true)
    }
    if (!emitterWriteIndent(emitter)) {
        return (event, false)
    }
    if (emitterCheckSimpleKey(emitter)) {
        emitter.states.add(EmitterStateT_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE)
        return emitterEmitNode(emitter, event, false, false, true, true)
    }
    return (event, false)
}

func emitterEmitBlockMappingValue(emitter: EmitterT, event: EventT, simple: Bool): (EventT, Bool) {
    if (simple) {
        if (!emitterWriteIndicator(emitter, [0x3A], false, false, false)) {
            return (event, false)
        }
    } 

    emitter.states.add(EmitterStateT_EMIT_BLOCK_MAPPING_KEY_STATE)
    return emitterEmitNode(emitter, event, false, false, true, false)
}
