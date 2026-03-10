/**
 * @file
 * This file is about yaml api.
 */

package yaml4cj.yaml

func insertToken(parser: ParserT, pos: Int64, token: TokenT) {
    if (parser.tokensHead > 0 && parser.tokens.size == parser.tokens.capacity) {
        if (parser.tokensHead != parser.tokens.size) {
            copy(parser.tokens, parser.tokens, srcStart: parser.tokensHead)
        }
        let b = parser.tokens[0..(parser.tokens.size - parser.tokensHead)]
        parser.tokens = ArrayList<TokenT>(parser.tokens.capacity)
        parser.tokens.add(all: b)
        parser.tokensHead = 0
    }
    parser.tokens.add(token)
    if (pos < 0) {
        return
    }
    copy(
        parser.tokens,
        parser.tokens[(parser.tokensHead + pos)..parser.tokens.size],
        dstStart: parser.tokensHead + pos + 1
    )
    parser.tokens[parser.tokensHead + pos] = token
}

func scalarEventInitialize(
    anchor: Array<UInt8>,
    tag: Array<UInt8>,
    value: Array<UInt8>,
    plain_implicit: Bool,
    quotedImplicit: Bool,
    style: ScalarStyleT
): (EventT, Bool) {
    let event = EventT()

    event.typ = EventTypeT_SCALAR_EVENT
    event.anchor = anchor
    event.tag = tag
    event.value = value
    event.implicit = plain_implicit
    event.quotedImplicit = quotedImplicit
    event.style = style

    (event, true)
}

func mappingStartEventInitialize(
    anchor: Array<UInt8>,
    tag: Array<UInt8>,
    implicit: Bool,
    style: MappingStyleT
): EventT {
    let event = EventT()

    event.typ = EventTypeT_MAPPING_START_EVENT
    event.anchor = anchor
    event.tag = tag
    event.implicit = implicit
    event.style = style

    event
}

func mappingEndEventInitialize(): EventT {
    let event = EventT()

    event.typ = EventTypeT_MAPPING_END_EVENT

    event
}

func sequenceStartEventInitialize(
    anchor: Array<UInt8>,
    tag: Array<UInt8>,
    implicit: Bool,
    style: SequenceStyleT
): (EventT, Bool) {
    let event = EventT()

    event.typ = EventTypeT_SEQUENCE_START_EVENT
    event.anchor = anchor
    event.tag = tag
    event.implicit = implicit
    event.style = style

    (event, true)
}

func sequenceEndEventInitialize(): (EventT, Bool) {
    let event = EventT()

    event.typ = EventTypeT_SEQUENCE_END_EVENT

    (event, true)
}

func parserDelete(): ParserT {
    ParserT()
}
