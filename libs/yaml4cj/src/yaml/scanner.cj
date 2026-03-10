/**
 * @file
 * This file is about scanner.
 */

package yaml4cj.yaml

func parserFetchMoreTokens(parser: ParserT): Bool {
    while (true) {
        if (parser.tokensHead != parser.tokens.size) {
            let headTokIdx = parser.simpleKeysByTok.get(parser.tokensParsed)
            match (headTokIdx) {
                case None => break
                case Some(idx) =>
                    let (valid, ok) = simpleKeyIsValid(parser, parser.simpleKeys[idx])
                    if (!ok) {
                        return false
                    }
                    if (!valid) {
                        break
                    }
            }
        }

        if (!parserFetchNextToken(parser)) {
            return false
        }
    }
    parser.tokenAvailable = true
    true
}

func simpleKeyIsValid(parser: ParserT, simpleKey: SimpleKeyT): (Bool, Bool) {
    if (!simpleKey.possible) {
        return (false, true)
    }

    if (simpleKey.mark.line < parser.mark.line || simpleKey.mark.index + 1024 < parser.mark.index) {
        if (simpleKey.required) {
            return (false, parserSetScannerError(
                    parser,
                    "while scanning a simple key",
                    simpleKey.mark,
                    "could not find expected ':'"
                ))
        }
        simpleKey.possible = false
        return (false, true)
    }
    (true, true)
}

func parserSetScannerError(parser: ParserT, context: String, contextMark: MarkT, problem: String): Bool {
    parser.error = ErrorTypeT_SCANNER_ERROR
    parser.context = context
    parser.contextMark = contextMark
    parser.problem = problem
    parser.problemMark = parser.mark
    false
}

func parserSetScannerTagError(
    parser: ParserT,
    directive: Bool,
    contextMark: MarkT,
    problem: String
): Bool {
    let context = if (directive) {
        "while parsing a %TAG directive"
    } else {
        "while parsing a tag"
    }
    parserSetScannerError(parser, context, contextMark, problem)
}

func parserFetchNextTokenResolve0(parser: ParserT): ?Bool {
    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return false
        }
    }

    if (!parser.streamStartProduced) {
        return parserFetchStreamStart(parser)
    }

    if (!parserScanToNextToken(parser)) {
        return false
    }

    if (!parserUnrollIndent(parser, parser.mark.column)) {
        return false
    }

    if (parser.unread < 4) {
        if (!parserUpdateBuffer(parser, 4)) {
            return false
        }
    }

    if (isZ(parser.buffer, parser.bufferPos)) {
        return parserFetchStreamEnd(parser)
    }

    if (parser.mark.column == 0 && parser.buffer[parser.bufferPos] == 0x25) {
        return parserFetchDirective(parser)
    }
    None
}

func parserFetchNextTokenResolve1(parser: ParserT): ?Bool {
    let buf = parser.buffer
    let pos = parser.bufferPos

    if (parser.mark.column == 0 && buf[pos] == 0x2D && buf[pos + 1] == 0x2D && buf[pos + 2] == 0x2D && isBlankz(
        buf,
        pos + 3
    )) {
        return parserFetchDocumentIndicator(parser, TokenTypeT_DOCUMENT_START_TOKEN)
    }

    if (parser.mark.column == 0 && buf[pos] == 0x2E && buf[pos + 1] == 0x2E && buf[pos + 2] == 0x2E && isBlankz(
        buf,
        pos + 3
    )) {
        return parserFetchDocumentIndicator(parser, TokenTypeT_DOCUMENT_END_TOKEN)
    }

    if (buf[pos] == 0x5B) {
        return parserFetchFlowCollectionStart(parser, TokenTypeT_FLOW_SEQUENCE_START_TOKEN)
    }
    None
}

func parserFetchNextTokenResolve2(parser: ParserT): ?Bool {
    if (parser.buffer[parser.bufferPos] == 0x7B) {
        return parserFetchFlowCollectionStart(parser, TokenTypeT_FLOW_MAPPING_START_TOKEN)
    }

    if (parser.buffer[parser.bufferPos] == 0x5D) {
        return parserFetchFlowCollectionEnd(
            parser,
            TokenTypeT_FLOW_SEQUENCE_END_TOKEN
        )
    }

    if (parser.buffer[parser.bufferPos] == 0x7D) {
        return parserFetchFlowCollectionEnd(
            parser,
            TokenTypeT_FLOW_MAPPING_END_TOKEN
        )
    }

    if (parser.buffer[parser.bufferPos] == 0x2C) {
        return parserFetchFlowEntry(parser)
    }

    if (parser.buffer[parser.bufferPos] == 0x2D && isBlankz(parser.buffer, parser.bufferPos + 1)) {
        return parserFetchBlockEntry(parser)
    }

    if (parser.buffer[parser.bufferPos] == 0x3F && (parser.flowLevel > 0 || isBlankz(
        parser.buffer,
        parser.bufferPos + 1
    ))) {
        return parserFetchKey(parser)
    }

    if (parser.buffer[parser.bufferPos] == 0x3A && (parser.flowLevel > 0 || isBlankz(
        parser.buffer,
        parser.bufferPos + 1
    ))) {
        return parserFetchValue(parser)
    }
    None
}

func parserFetchNextTokenResolve3(parser: ParserT): ?Bool {
    if (parser.buffer[parser.bufferPos] == 0x2A) {
        return parserFetchAnchor(parser, TokenTypeT_ALIAS_TOKEN)
    }

    if (parser.buffer[parser.bufferPos] == 0x26) {
        return parserFetchAnchor(parser, TokenTypeT_ANCHOR_TOKEN)
    }

    if (parser.buffer[parser.bufferPos] == 0x21) {
        return parserFetchTag(parser)
    }

    if (parser.buffer[parser.bufferPos] == 0x7C && parser.flowLevel == 0) {
        return parserFetchBlockScalar(parser, true)
    }

    if (parser.buffer[parser.bufferPos] == 0x3E && parser.flowLevel == 0) {
        return parserFetchBlockScalar(parser, false)
    }

    if (parser.buffer[parser.bufferPos] == 0x27) {
        return parserFetchFlowScalar(parser, true)
    }

    if (parser.buffer[parser.bufferPos] == 0x22) {
        return parserFetchFlowScalar(parser, false)
    }

    let bc = Rune(UInt32(parser.buffer[parser.bufferPos]))
    if (!(isBlankz(parser.buffer, parser.bufferPos) || bc == r'-' || bc == r'?' || bc == r':' || bc == r',' || bc == r'[' ||
        bc == r']' || bc == r'{' || bc == r'}' || bc == r'#' || bc == r'&' || bc == r'*' || bc == r'!' || bc == r'|' || bc == r'>' ||
        bc == r'\'' || bc == r'"' || bc == r'%' || bc == r'@' || bc == r'`') || (bc == r'-' &&
        !isBlank(parser.buffer, parser.bufferPos + 1)) || (parser.flowLevel == 0 && (bc == r'?' || bc == r':') &&
        !isBlankz(parser.buffer, parser.bufferPos + 1))) {
        return parserFetchPlainScalar(parser)
    }
    None
}

func parserFetchNextToken(parser: ParserT): Bool {
    if (let Some(ok) <- parserFetchNextTokenResolve0(parser)) {
        return ok
    }

    if (let Some(ok) <- parserFetchNextTokenResolve1(parser)) {
        return ok
    }

    if (let Some(ok) <- parserFetchNextTokenResolve2(parser)) {
        return ok
    }

    if (let Some(ok) <- parserFetchNextTokenResolve3(parser)) {
        return ok
    }

    return parserSetScannerError(
        parser,
        "while scanning for the next token",
        parser.mark,
        "found character that cannot start any token"
    )
}

func parserFetchStreamStart(parser: ParserT): Bool {
    parser.indent = -1

    parser.simpleKeys.add(SimpleKeyT())

    parser.simpleKeysByTok = HashMap<Int64, Int64>()

    parser.simpleKeyAllowed = true

    parser.streamStartProduced = true

    let token = TokenT()
    token.typ = TokenTypeT_STREAM_START_TOKEN
    token.startMark = parser.mark
    token.endMark = parser.mark
    token.encoding = parser.encoding

    insertToken(parser, -1, token)
    return true
}

func parserFetchPlainScalar(parser: ParserT): Bool {
    if (!parserSaveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    let (token, ok) = parserScanPlainScalar(parser)
    if (!ok) {
        return false
    }
    insertToken(parser, -1, token)
    return true
}

func parserScanToNextTokenResolve(parser: ParserT): ?Bool {
    while (parser.buffer[parser.bufferPos] == 0x20 || ((parser.flowLevel > 0 || !parser.simpleKeyAllowed) &&
            parser.buffer[parser.bufferPos] == 0x09)) {
        skip(parser)
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return false
            }
        }
    }

    if (parser.buffer[parser.bufferPos] == 0x23) {
        while (!isBreakz(parser.buffer, parser.bufferPos)) {
            skip(parser)
            if (parser.unread < 1) {
                if (!parserUpdateBuffer(parser, 1)) {
                    return false
                }
            }
        }
    }
    None
}

func parserScanToNextTokenLoop(parser: ParserT): ?(Bool, Bool) {
    if (parser.unread < 1 && !parserUpdateBuffer(parser, 1)) {
        return (false, false)
    }
    if (parser.mark.column == 0) {
        if (isBom(parser.buffer)) {
            skip(parser)
        }
    }

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (false, false)
        }
    }

    if (let Some(ok) <- parserScanToNextTokenResolve(parser)) {
        return (ok, false)
    }

    if (isBreak(parser.buffer, parser.bufferPos)) {
        if (parser.unread < 2) {
            if (!parserUpdateBuffer(parser, 2)) {
                return (false, false)
            }
        }
        skipLine(parser)

        if (parser.flowLevel == 0) {
            parser.simpleKeyAllowed = true
        }
        return None
    } else {
        return (false, true)
    }
}

func parserScanToNextToken(parser: ParserT): Bool {
    while (true) {
        if (let Some((ok, isBreak)) <- parserScanToNextTokenLoop(parser)) {
            if (isBreak) {
                break
            }
            return ok
        }
    }

    return true
}

func skip(parser: ParserT) {
    parser.mark.index++
    parser.mark.column++
    parser.unread--
    parser.bufferPos += width(parser.buffer[parser.bufferPos])
}

func skipLine(parser: ParserT) {
    if (isCRLF(parser.buffer, parser.bufferPos)) {
        parser.mark.index += 2
        parser.mark.column = 0
        parser.mark.line++
        parser.unread -= 2
        parser.bufferPos += 2
    } else if (isBreak(parser.buffer, parser.bufferPos)) {
        parser.mark.index++
        parser.mark.column = 0
        parser.mark.line++
        parser.unread--
        parser.bufferPos += width(parser.buffer[parser.bufferPos])
    }
}

func read(parser: ParserT): Array<UInt8> {
    let w = width(parser.buffer[parser.bufferPos])
    if (w == 0) {
        throw Exception("invalid character sequence")
    }
    var s: Array<UInt8>
    if (w == 1) {
        s = [parser.buffer[parser.bufferPos]]
        parser.bufferPos++
    } else {
        s = (parser.buffer[parser.bufferPos..(parser.bufferPos + w)]).toArray()
        parser.bufferPos += w
    }
    parser.mark.index++
    parser.mark.column++
    parser.unread--
    s
}

func readLine(parser: ParserT): Array<UInt8> {
    let buf = parser.buffer
    let pos = parser.bufferPos
    var s: Array<UInt8>
    if (buf[pos] == 0xD && buf[pos + 1] == 0xA) {
        s = [0xA]
        parser.bufferPos += 2
        parser.mark.index++
        parser.unread--
    } else if (buf[pos] == 0xD || buf[pos] == 0xA) {
        s = [0xA]
        parser.bufferPos += 1
    } else if (buf[pos] == 0xC2 && buf[pos + 1] == 0x85) {
        s = [0xA]
        parser.bufferPos += 2
    } else if (buf[pos] == 0xE2 && buf[pos + 1] == 0x80 && (buf[pos + 2] == 0xA8 || buf[pos + 2] == 0xA9)) {
        s = (buf[parser.bufferPos..(pos + 3)]).toArray()
        parser.bufferPos += 3
    } else {
        return []
    }
    parser.mark.index++
    parser.mark.column = 0
    parser.mark.line++
    parser.unread--
    s
}

func parserUnrollIndent(parser: ParserT, column: Int64): Bool {
    if (parser.flowLevel > 0) {
        return true
    }
    while (parser.indent > column) {
        let token = TokenT()

        token.typ = TokenTypeT_BLOCK_END_TOKEN
        token.startMark = parser.mark
        token.endMark = parser.mark

        insertToken(parser, -1, token)

        parser.indent = parser.indents[parser.indents.size - 1]
        parser.indents = parser.indents[0..(parser.indents.size - 1)]
    }
    true
}

func parserFetchStreamEnd(parser: ParserT): Bool {
    if (parser.mark.column != 0) {
        parser.mark.column = 0
        parser.mark.line++
    }

    if (!parserUnrollIndent(parser, -1)) {
        return false
    }

    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    let token = TokenT()

    token.typ = TokenTypeT_STREAM_END_TOKEN
    token.startMark = parser.mark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

func parserRemoveSimpleKey(parser: ParserT): Bool {
    let i = parser.simpleKeys.size - 1
    if (parser.simpleKeys[i].possible) {
        if (parser.simpleKeys[i].required) {
            return parserSetScannerError(
                parser,
                "while scanning a simple key",
                parser.simpleKeys[i].mark,
                "could not find expected ':'"
            )
        }

        parser.simpleKeys[i].possible = false
        parser.simpleKeysByTok.remove(parser.simpleKeys[i].tokenNumber)
    }
    true
}

func parserFetchDirective(parser: ParserT): Bool {
    // Reset the indentation level.
    if (!parserUnrollIndent(parser, -1)) {
        return false
    }

    // Reset simple keys.
    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    // Create the YAML-DIRECTIVE or TAG-DIRECTIVE token.
    let (token, ok) = parserScanDirective(parser)
    if (!ok) {
        return false
    }

    // Append the token to the queue.
    insertToken(parser, -1, token)
    return true
}

func parserScanDirective(parser: ParserT): (TokenT, Bool) {
    let token = TokenT()

    let startMark = parser.mark
    skip(parser)

    let (name, nok) = parserScanDirectiveName(parser, startMark)
    if (!nok) {
        return (token, false)
    }

    if ("YAML" == String.fromUtf8(name)) {
        let (major, minor, ok) = parserScanVersionDirectiveValue(parser, startMark)
        if (!ok) {
            return (token, false)
        }
        token.typ = TokenTypeT_VERSION_DIRECTIVE_TOKEN
        token.startMark = startMark
        token.endMark = parser.mark
        token.major = major
        token.minor = minor
    } else if ("TAG" == String.fromUtf8(name)) {
        let (handle, prefix, ok) = parserScanTagDirectiveValue(parser, startMark)
        if (!ok) {
            return (token, false)
        }
        token.typ = TokenTypeT_TAG_DIRECTIVE_TOKEN
        token.startMark = startMark
        token.endMark = parser.mark
        token.value = handle
        token.prefix = prefix
    } else {
        parserSetScannerError(
            parser,
            "while scanning a directive",
            startMark,
            "found unknown directive name"
        )
        return (token, false)
    }

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (token, false)
        }
    }

    while (isBlank(parser.buffer, parser.bufferPos)) {
        skip(parser)
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return (token, false)
            }
        }
    }

    if (parser.buffer[parser.bufferPos] == 0x23) {
        while (!isBreakz(parser.buffer, parser.bufferPos)) {
            skip(parser)
            if (parser.unread < 1) {
                if (!parserUpdateBuffer(parser, 1)) {
                    return (token, false)
                }
            }
        }
    }

    if (!isBreakz(parser.buffer, parser.bufferPos)) {
        parserSetScannerError(
            parser,
            "while scanning a directive",
            startMark,
            "did not find expected comment or line break"
        )
        return (token, false)
    }

    if (isBreak(parser.buffer, parser.bufferPos)) {
        if (parser.unread < 2) {
            if (!parserUpdateBuffer(parser, 2)) {
                return (token, false)
            }
        }
        skipLine(parser)
    }

    (token, true)
}

func parserScanDirectiveName(parser: ParserT, startMark: MarkT): (Array<UInt8>, Bool) {
    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return ([], false)
        }
    }
    var s = ArrayList<UInt8>()
    while (isAlpha(parser.buffer, parser.bufferPos)) {
        s.add(all: read(parser))
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return ([], false)
            }
        }
    }
    if (s.size == 0) {
        parserSetScannerError(
            parser,
            "while scanning a directive",
            startMark,
            "could not find expected directive name"
        )
        return ([], false)
    }
    if (!isBlankz(parser.buffer, parser.bufferPos)) {
        parserSetScannerError(
            parser,
            "while scanning a directive",
            startMark,
            "found unexpected non-alphabetical character"
        )
        return ([], false)
    }
    (s.toArray(), true)
}

func parserScanVersionDirectiveValue(parser: ParserT, startMark: MarkT): (Int8, Int8, Bool) {
    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (0, 0, false)
        }
    }
    while (isBlank(parser.buffer, parser.bufferPos)) {
        skip(parser)
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return (0, 0, false)
            }
        }
    }

    let (major, mok) = parserScanVersionDirectiveNumber(parser, startMark)
    if (!mok) {
        return (major, 0, false)
    }

    if (parser.buffer[parser.bufferPos] != 0x2E) {
        return (major, 0, parserSetScannerError(
                parser,
                "while scanning a %YAML directive",
                startMark,
                "did not find expected digit or '.' character"
            ))
    }

    skip(parser)

    let (minor, nok) = parserScanVersionDirectiveNumber(parser, startMark)
    if (!nok) {
        return (major, minor, false)
    }
    (major, minor, true)
}

let maxNumberLength: Int8 = 2

func parserScanVersionDirectiveNumber(parser: ParserT, startMark: MarkT): (Int8, Bool) {
    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (0, false)
        }
    }
    var value: Int8 = 0
    var length: Int8 = 0
    while (isDigit(parser.buffer, parser.bufferPos)) {
        length++
        if (length > maxNumberLength) {
            return (0, parserSetScannerError(
                    parser,
                    "while scanning a %YAML directive",
                    startMark,
                    "found extremely long version number"
                ))
        }
        value = value * 10 + Int8(asDigit(parser.buffer, parser.bufferPos))
        skip(parser)
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return (0, false)
            }
        }
    }
    (value, true)
}

func parserScanTagDirectiveValue(parser: ParserT, startMark: MarkT): (Array<UInt8>, Array<UInt8>, Bool) {
    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return ([], [], false)
        }
    }

    while (isBlank(parser.buffer, parser.bufferPos)) {
        skip(parser)
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return ([], [], false)
            }
        }
    }

    let (handle_value, hok) = parserScanTagHandle(parser, true, startMark)
    if (!hok) {
        return ([], [], false)
    }

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return ([], [], false)
        }
    }
    if (!isBlank(parser.buffer, parser.bufferPos)) {
        parserSetScannerError(
            parser,
            "while scanning a %TAG directive",
            startMark,
            "did not find expected whitespace"
        )
        return ([], [], false)
    }

    while (isBlank(parser.buffer, parser.bufferPos)) {
        skip(parser)
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return ([], [], false)
            }
        }
    }

    let (prefix_value, pok) = parserScanTagURI(parser, true, None, startMark)
    if (!pok) {
        return ([], [], false)
    }

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return ([], [], false)
        }
    }
    if (!isBlankz(parser.buffer, parser.bufferPos)) {
        parserSetScannerError(
            parser,
            "while scanning a %TAG directive",
            startMark,
            "did not find expected whitespace or line break"
        )
        return ([], [], false)
    }
    (handle_value, prefix_value, true)
}

func parserScanTagHandle(parser: ParserT, directive: Bool, startMark: MarkT): (Array<UInt8>, Bool) {
    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return ([], false)
        }
    }
    if (parser.buffer[parser.bufferPos] != 0x21) {
        parserSetScannerTagError(
            parser,
            directive,
            startMark,
            "did not find expected '!'"
        )
        return ([], false)
    }
    let s = ArrayList<UInt8>()
    s.add(all: read(parser))

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return ([], false)
        }
    }
    while (isAlpha(parser.buffer, parser.bufferPos)) {
        s.add(all: read(parser))
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return ([], false)
            }
        }
    }

    if (parser.buffer[parser.bufferPos] == 0x21) {
        s.add(all: read(parser))
    } else {
        // It's either the '!' tag or not really a tag handle.  If it's a %TAG
        // directive, it's an error.  If it's a tag token, it must be a part of URI.
        if (directive && b'!' == s[0]) {
            parserSetScannerTagError(
                parser,
                directive,
                startMark,
                "did not find expected '!'"
            )
            return ([], false)
        }
    }
    (s.toArray(), true)
}

func checkBufferChar(buffer: ArrayList<UInt8>, bufferPos: Int64): Bool {
    let bc = Rune(UInt32(buffer[bufferPos]))
    bc == r';' || bc == r'/' || bc == r'?' || bc == r':' || bc == r'@' || bc == r'&' || bc == r'=' || bc == r'+' || bc == r'$' ||
        bc == r',' || bc == r'.' || bc == r'!' || bc == r'~' || bc == r'*' || bc == r'\'' || bc == r'(' || bc == r')' || bc ==
        r'[' || bc == r']' || bc == r'%'
}

func parserScanTagURI(parser: ParserT, directive: Bool, head: ?Array<UInt8>, startMark: MarkT): (Array<UInt8>, Bool) {
    let s = ArrayList<UInt8>()
    var hasTag = false
    match (head) {
        case Some(h) =>
            if (h.size > 0) {
                hasTag = true
            }
            if (h.size > 1) {
                s.add(all: h[1..h.size])
            }
        case _ => ()
    }

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return ([], false)
        }
    }

    while (isAlpha(parser.buffer, parser.bufferPos) || checkBufferChar(parser.buffer, parser.bufferPos)) {
        if (parser.buffer[parser.bufferPos] == 0x25) {
            if (!parserScanURIEscapes(parser, directive, startMark, s)) {
                return ([], false)
            }
        } else {
            s.add(all: read(parser))
        }
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return ([], false)
            }
        }
        hasTag = true
    }

    if (!hasTag) {
        parserSetScannerTagError(
            parser,
            directive,
            startMark,
            "did not find expected tag URI"
        )
        return ([], false)
    }
    (s.toArray(), true)
}

func parserScanURIEscapes(parser: ParserT, directive: Bool, startMark: MarkT, s: ArrayList<UInt8>): Bool {
    var w = 1024
    while (w > 0) {
        if (parser.unread < 3) {
            if (!parserUpdateBuffer(parser, 3)) {
                return false
            }
        }

        if (!(parser.buffer[parser.bufferPos] == 0x25 && isHex(parser.buffer, parser.bufferPos + 1) && isHex(
            parser.buffer, parser.bufferPos + 2))) {
            return parserSetScannerTagError(
                parser,
                directive,
                startMark,
                "did not find URI escaped octet"
            )
        }

        let octet = UInt8((asHex(parser.buffer, parser.bufferPos + 1) << 4) + asHex(
                parser.buffer,
                parser.bufferPos + 2
            ))

        if (w == 1024) {
            w = width(octet)
            if (w == 0) {
                return parserSetScannerTagError(
                    parser,
                    directive,
                    startMark,
                    "found an incorrect leading UTF-8 octet"
                )
            }
        } else {
            if ((octet & 0xC0) != 0x80) {
                return parserSetScannerTagError(
                    parser,
                    directive,
                    startMark,
                    "found an incorrect trailing UTF-8 octet"
                )
            }
        }

        s.add(octet)
        skip(parser)
        skip(parser)
        skip(parser)
        w--
    }
    true
}

func parserFetchDocumentIndicator(parser: ParserT, typ: TokenTypeT): Bool {
    if (!parserUnrollIndent(parser, -1)) {
        return false
    }

    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    let startMark = parser.mark

    skip(parser)
    skip(parser)
    skip(parser)

    let token = TokenT()
    token.typ = typ
    token.startMark = startMark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

func parserFetchFlowCollectionStart(parser: ParserT, typ: TokenTypeT): Bool {
    if (!parserSaveSimpleKey(parser)) {
        return false
    }

    if (!parserIncreaseFlowLevel(parser)) {
        return false
    }

    parser.simpleKeyAllowed = true

    let startMark = parser.mark
    skip(parser)

    let token = TokenT()
    token.typ = typ
    token.startMark = startMark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

func parserSaveSimpleKey(parser: ParserT): Bool {
    let required = parser.flowLevel == 0 && parser.indent == parser.mark.column

    if (parser.simpleKeyAllowed) {
        let simpleKey = SimpleKeyT()

        simpleKey.possible = true
        simpleKey.required = required
        simpleKey.tokenNumber = parser.tokensParsed + (parser.tokens.size - parser.tokensHead)
        simpleKey.mark = parser.mark.clone()

        if (!parserRemoveSimpleKey(parser)) {
            return false
        }
        parser.simpleKeys[parser.simpleKeys.size - 1] = simpleKey
        parser.simpleKeysByTok[simpleKey.tokenNumber] = parser.simpleKeys.size - 1
    }
    true
}

let max_flowLevel = 10000

func parserIncreaseFlowLevel(parser: ParserT): Bool {
    let simpleKey = SimpleKeyT()
    simpleKey.possible = false
    simpleKey.required = false
    simpleKey.tokenNumber = parser.tokensParsed + (parser.tokens.size - parser.tokensHead)
    simpleKey.mark = parser.mark
    parser.simpleKeys.add(simpleKey)

    parser.flowLevel++
    if (parser.flowLevel > max_flowLevel) {
        return parserSetScannerError(
            parser,
            "while increasing flow level",
            parser.simpleKeys[parser.simpleKeys.size - 1].mark,
            "exceeded max depth of ${max_flowLevel}"
        )
    }

    true
}

func parserFetchFlowCollectionEnd(parser: ParserT, typ: TokenTypeT): Bool {
    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    if (!parserDecreaseFlowLevel(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    let startMark = parser.mark
    skip(parser)

    let token = TokenT()
    token.typ = typ
    token.startMark = startMark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

func parserDecreaseFlowLevel(parser: ParserT): Bool {
    if (parser.flowLevel > 0) {
        parser.flowLevel--
        let last = parser.simpleKeys.size - 1
        parser.simpleKeysByTok.remove(parser.simpleKeys[last].tokenNumber)
        parser.simpleKeys = parser.simpleKeys[0..last]
    }
    true
}

func parserFetchFlowEntry(parser: ParserT): Bool {
    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = true

    let startMark = parser.mark
    skip(parser)
    let token = TokenT()
    token.typ = TokenTypeT_FLOW_ENTRY_TOKEN
    token.startMark = startMark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

func parserFetchBlockEntry(parser: ParserT): Bool {
    if (parser.flowLevel == 0) {
        if (!parser.simpleKeyAllowed) {
            return parserSetScannerError(
                parser,
                "",
                parser.mark,
                "block sequence entries are not allowed in this context"
            )
        }
        if (!parserRollIndent(parser, parser.mark.column, -1, TokenTypeT_BLOCK_SEQUENCE_START_TOKEN, parser.mark)) {
            return false
        }
    }

    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = true

    let startMark = parser.mark
    skip(parser)
    let token = TokenT()
    token.typ = TokenTypeT_BLOCK_ENTRY_TOKEN
    token.startMark = startMark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

let max_indents = 10000

func parserRollIndent(
    parser: ParserT,
    column: Int64,
    number: Int64,
    typ: TokenTypeT,
    mark: MarkT
): Bool {
    if (parser.flowLevel > 0) {
        return true
    }
    if (parser.indent < column) {
        parser.indents.add(parser.indent)
        parser.indent = column
        if (parser.indents.size > max_indents) {
            return parserSetScannerError(
                parser,
                "while increasing indent level",
                parser.simpleKeys[parser.simpleKeys.size - 1].mark,
                "exceeded max depth of ${max_indents}"
            )
        }

        let token = TokenT()
        token.typ = typ
        token.startMark = mark
        token.endMark = mark
        let num = if (number > -1) {
            number - parser.tokensParsed
        } else {
            number
        }
        insertToken(parser, num, token)
    }
    true
}

func parserFetchKey(parser: ParserT): Bool {
    if (parser.flowLevel == 0) {
        if (!parser.simpleKeyAllowed) {
            return parserSetScannerError(
                parser,
                "",
                parser.mark,
                "mapping keys are not allowed in this context"
            )
        }
        if (!parserRollIndent(parser, parser.mark.column, -1, TokenTypeT_BLOCK_MAPPING_START_TOKEN, parser.mark)) {
            return false
        }
    }

    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = parser.flowLevel == 0

    let startMark = parser.mark
    skip(parser)
    let token = TokenT()
    token.typ = TokenTypeT_KEY_TOKEN
    token.startMark = startMark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

func parserFetchValue(parser: ParserT): Bool {
    let simpleKey = parser.simpleKeys[parser.simpleKeys.size - 1]
    let (valid, ok) = simpleKeyIsValid(parser, simpleKey)
    if (!ok) {
        return false
    } else if (valid) {
        let token = TokenT()
        token.typ = TokenTypeT_KEY_TOKEN
        token.startMark = simpleKey.mark
        token.endMark = simpleKey.mark
        insertToken(parser, simpleKey.tokenNumber - parser.tokensParsed, token)

        if (!parserRollIndent(
            parser,
            simpleKey.mark.column,
            simpleKey.tokenNumber,
            TokenTypeT_BLOCK_MAPPING_START_TOKEN,
            simpleKey.mark
        )) {
            return false
        }

        simpleKey.possible = false
        parser.simpleKeysByTok.remove(simpleKey.tokenNumber)

        parser.simpleKeyAllowed = false
    } else {
        if (parser.flowLevel == 0) {
            if (!parser.simpleKeyAllowed) {
                return parserSetScannerError(
                    parser,
                    "",
                    parser.mark,
                    "mapping values are not allowed in this context"
                )
            }

            if (!parserRollIndent(
                parser,
                parser.mark.column,
                -1,
                TokenTypeT_BLOCK_MAPPING_START_TOKEN,
                parser.mark
            )) {
                return false
            }
        }

        parser.simpleKeyAllowed = parser.flowLevel == 0
    }

    let startMark = parser.mark
    skip(parser)
    let token = TokenT()
    token.typ = TokenTypeT_VALUE_TOKEN
    token.startMark = startMark
    token.endMark = parser.mark

    insertToken(parser, -1, token)
    true
}

func parserScanAnchor(parser: ParserT, typ: TokenTypeT): (TokenT, Bool) {
    let startMark = parser.mark
    skip(parser)

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (TokenT(), false)
        }
    }

    let s = ArrayList<UInt8>()

    while (isAlpha(parser.buffer, parser.bufferPos)) {
        s.add(all: read(parser))
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return (TokenT(), false)
            }
        }
    }

    let endMark = parser.mark

    let bc = Rune(UInt32(parser.buffer[parser.bufferPos]))
    if (s.size == 0 ||
        !(isBlankz(parser.buffer, parser.bufferPos) || bc == r'?' || bc == r':' || bc == r',' || bc == r']' || bc == r'}' ||
        bc == r'%' || bc == r'@' || bc == r'`')) {
        let context = if (typ == TokenTypeT_ANCHOR_TOKEN) {
            "while scanning an anchor"
        } else {
            "while scanning an alias"
        }
        parserSetScannerError(
            parser,
            context,
            startMark,
            "did not find expected alphabetic or numeric character"
        )
        return (TokenT(), false)
    }

    let token = TokenT()
    token.typ = typ
    token.startMark = startMark
    token.endMark = endMark
    token.value = s.toArray()

    (token, true)
}

func parserFetchAnchor(parser: ParserT, typ: TokenTypeT): Bool {
    if (!parserSaveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    var (token, ok) = parserScanAnchor(parser, typ)
    if (!ok) {
        return false
    }
    insertToken(parser, -1, token)
    true
}

func parserScanTag(parser: ParserT): (TokenT, Bool) {
    let startMark = parser.mark

    if (parser.unread < 2) {
        if (!parserUpdateBuffer(parser, 2)) {
            return (TokenT(), false)
        }
    }

    var han: Array<UInt8> = []
    var suf: Array<UInt8> = []

    if (parser.buffer[parser.bufferPos + 1] == 0x3C) {
        skip(parser)
        skip(parser)

        let (suffix, ok) = parserScanTagURI(parser, false, None, startMark)
        suf = suffix
        if (!ok) {
            return (TokenT(), false)
        }

        if (parser.buffer[parser.bufferPos] != 0x3E) {
            parserSetScannerError(
                parser,
                "while scanning a tag",
                startMark,
                "did not find the expected '>'"
            )
            return (TokenT(), false)
        }

        skip(parser)
    } else {
        let (handle, ok) = parserScanTagHandle(parser, false, startMark)
        han = handle
        if (!ok) {
            return (TokenT(), false)
        }
        if (handle[0] == 0x21 && handle.size > 1 && handle[handle.size - 1] == 0x21) {
            let (suffix, sok) = parserScanTagURI(parser, false, None, startMark)
            suf = suffix
            if (!sok) {
                return (TokenT(), false)
            }
        } else {
            let (suffix, sok) = parserScanTagURI(parser, false, handle, startMark)
            suf = suffix
            if (!sok) {
                return (TokenT(), false)
            }

            han = [0x21]

            if (suf.size == 0) {
                let (nhandle, nsuffix) = (suf, han)
                han = nhandle
                suf = nsuffix
            }
        }
    }

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (TokenT(), false)
        }
    }
    if (!isBlankz(parser.buffer, parser.bufferPos)) {
        parserSetScannerError(
            parser,
            "while scanning a tag",
            startMark,
            "did not find expected whitespace or line break"
        )
        return (TokenT(), false)
    }

    let token = TokenT()
    token.typ = TokenTypeT_TAG_TOKEN
    token.startMark = startMark
    token.endMark = parser.mark
    token.value = han
    token.suffix = suf

    (token, true)
}

func parserFetchTag(parser: ParserT): Bool {
    if (!parserSaveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    let (token, ok) = parserScanTag(parser)
    if (!ok) {
        return false
    }

    insertToken(parser, -1, token)
    true
}

func parserScanBlockScalarResloveAddOrSub(
    parser: ParserT,
    startMark: MarkT,
    incrementBox: Box<Int64>,
    chompingBox: Box<Int64>
): (?TokenT, Bool) {
    chompingBox.value = if (parser.buffer[parser.bufferPos] == 0x2B) {
        1
    } else {
        -1
    }
    skip(parser)

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (TokenT(), false)
        }
    }
    if (isDigit(parser.buffer, parser.bufferPos)) {
        if (parser.buffer[parser.bufferPos] == 0x30) {
            parserSetScannerError(
                parser,
                "while scanning a block scalar",
                startMark,
                "found an indentation indicator equal to 0"
            )
            return (TokenT(), false)
        }

        incrementBox.value = asDigit(parser.buffer, parser.bufferPos)
        skip(parser)
    }
    (None, false)
}

func parserScanBlockScalarResolveDigit(
    parser: ParserT,
    startMark: MarkT,
    incrementBox: Box<Int64>,
    chompingBox: Box<Int64>
): (?TokenT, Bool) {
    if (parser.buffer[parser.bufferPos] == 0x30) {
        parserSetScannerError(
            parser,
            "while scanning a block scalar",
            startMark,
            "found an indentation indicator equal to 0"
        )
        return (TokenT(), false)
    }
    incrementBox.value = asDigit(parser.buffer, parser.bufferPos)
    skip(parser)

    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (TokenT(), false)
        }
    }
    if (parser.buffer[parser.bufferPos] == 0x2B || parser.buffer[parser.bufferPos] == 0x2D) {
        chompingBox.value = if (parser.buffer[parser.bufferPos] == 0x2B) {
            1
        } else {
            -1
        }
        skip(parser)
    }
    (None, false)
}

func parserScanBlockScalarReslove0(parser: ParserT, startMark: MarkT): (?TokenT, Bool) {
    if (parser.unread < 1) {
        if (!parserUpdateBuffer(parser, 1)) {
            return (TokenT(), false)
        }
    }
    while (isBlank(parser.buffer, parser.bufferPos)) {
        skip(parser)
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return (TokenT(), false)
            }
        }
    }
    if (parser.buffer[parser.bufferPos] == 0x23) {
        while (!isBreakz(parser.buffer, parser.bufferPos)) {
            skip(parser)
            if (parser.unread < 1) {
                if (!parserUpdateBuffer(parser, 1)) {
                    return (TokenT(), false)
                }
            }
        }
    }

    if (!isBreakz(parser.buffer, parser.bufferPos)) {
        parserSetScannerError(
            parser,
            "while scanning a block scalar",
            startMark,
            "did not find expected comment or line break"
        )
        return (TokenT(), false)
    }

    if (isBreak(parser.buffer, parser.bufferPos)) {
        if (parser.unread < 2) {
            if (!parserUpdateBuffer(parser, 2)) {
                return (TokenT(), false)
            }
        }
        skipLine(parser)
    }
    (None, false)
}

func parserScanBlockScalarReslove1(
    parser: ParserT,
    literal: Bool,
    chomping: Int64,
    indentBox: Box<Int64>,
    s: ArrayList<UInt8>,
    trailingBreaksBox: Box<Array<UInt8>>,
    startMark: MarkT,
    endMarkBox: Box<MarkT>
): (?TokenT, Bool) {
    var leadingBreak: ArrayList<UInt8> = ArrayList<UInt8>()
    var leadingBlank = false
    var trailingBlank = false

    while (parser.mark.column == indentBox.value && !isZ(parser.buffer, parser.bufferPos)) {
        trailingBlank = isBlank(parser.buffer, parser.bufferPos)

        if (!literal && !leadingBlank && !trailingBlank && leadingBreak.size > 0 && leadingBreak[0] == 0xA) {
            if (trailingBreaksBox.value.size == 0) {
                s.add(0x20)
            }
        } else {
            s.add(all: leadingBreak)
        }
        leadingBreak.clear()
        s.add(all: trailingBreaksBox.value)
        trailingBreaksBox.value = []

        leadingBlank = isBlank(parser.buffer, parser.bufferPos)

        while (!isBreakz(parser.buffer, parser.bufferPos)) {
            s.add(all: read(parser))
            if (parser.unread < 1) {
                if (!parserUpdateBuffer(parser, 1)) {
                    return (TokenT(), false)
                }
            }
        }

        if (parser.unread < 2) {
            if (!parserUpdateBuffer(parser, 2)) {
                return (TokenT(), false)
            }
        }

        leadingBreak.add(all: readLine(parser))

        let (nTrailingBreaks, nEndMark, nTok) = parserScanBlockScalarBreaks(
            parser,
            indentBox,
            startMark
        )
        trailingBreaksBox.value = nTrailingBreaks
        endMarkBox.value = nEndMark
        if (!nTok) {
            return (TokenT(), false)
        }
    }

    if (chomping != -1) {
        s.add(all: leadingBreak)
    }
    if (chomping == 1) {
        s.add(all: trailingBreaksBox.value)
    }
    (None, false)
}

func parserScanBlockScalarReslove2(
    parser: ParserT,
    startMark: MarkT,
    increment: Box<Int64>,
    chomping: Box<Int64>
): ?(TokenT, Bool) {
    if (parser.buffer[parser.bufferPos] == 0x2B || parser.buffer[parser.bufferPos] == 0x2D) {
        if (let (Some(t), ok) <- parserScanBlockScalarResloveAddOrSub(
            parser,
            startMark,
            increment,
            chomping
        )) {
            return (t, ok)
        }
    } else if (isDigit(parser.buffer, parser.bufferPos)) {
        if (let (Some(t), ok) <- parserScanBlockScalarResolveDigit(
            parser,
            startMark,
            increment,
            chomping
        )) {
            return (t, ok)
        }
    }
    if (let (Some(t), ok) <- parserScanBlockScalarReslove0(parser, startMark)) {
        return (t, ok)
    }
    return None
}

func parserScanBlockScalarResloveIndent(parser: ParserT, increment: Box<Int64>): Int64 {
    if (increment.value > 0) {
        if (parser.indent >= 0) {
            parser.indent + increment.value
        } else {
            increment.value
        }
    } else {
        0
    }
}

func parserScanBlockScalar(parser: ParserT, literal: Bool): (TokenT, Bool) {
    let startMark = parser.mark
    skip(parser)

    // Scan the additional block scalar indicators.
    if (parser.unread < 1 && !parserUpdateBuffer(parser, 1)) {
        return (TokenT(), false)
    }

    let increment = Box<Int64>(0)
    let chomping = Box<Int64>(0)

    if (let Some((t, ok)) <- parserScanBlockScalarReslove2(parser, startMark, increment, chomping)) {
        return (t, ok)
    }

    var endMark = parser.mark

    var indent = Box<Int64>(parserScanBlockScalarResloveIndent(parser, increment))

    let (ntrailingBreaks, nendMark, tok) = parserScanBlockScalarBreaks(
        parser,
        indent,
        startMark
    )
    var trailingBreaks = ntrailingBreaks
    endMark = nendMark
    if (!tok || (parser.unread < 1 && !parserUpdateBuffer(parser, 1))) {
        return (TokenT(), false)
    }
    let s = ArrayList<UInt8>()
    let trailingBreaksBox = Box<Array<UInt8>>(trailingBreaks)
    let endMarkBox = Box<MarkT>(endMark)
    if (let (Some(t), ok) <- parserScanBlockScalarReslove1(
        parser,
        literal,
        chomping.value,
        indent,
        s,
        trailingBreaksBox,
        startMark,
        endMarkBox
    )) {
        return (t, ok)
    }
    trailingBreaks = trailingBreaksBox.value
    endMark = endMarkBox.value

    let token = TokenT()
    token.typ = TokenTypeT_SCALAR_TOKEN
    token.startMark = startMark
    token.endMark = endMark
    token.value = s.toArray()
    token.style = ScalarStyleT_LITERAL_SCALAR_STYLE
    if (!literal) {
        token.style = ScalarStyleT_FOLDED_SCALAR_STYLE
    }
    (token, true)
}

func parserFetchBlockScalar(parser: ParserT, literal: Bool): Bool {
    if (!parserRemoveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = true

    let (token, ok) = parserScanBlockScalar(parser, literal)
    if (!ok) {
        return false
    }
    insertToken(parser, -1, token)
    true
}

// 返回breaks、indent、endMark
func parserScanBlockScalarBreaks(
    parser: ParserT,
    indent: Box<Int64>,
    startMark: MarkT
): (Array<UInt8>, MarkT, Bool) {
    var breaks: ArrayList<UInt8> = ArrayList<UInt8>()
    var endMark = parser.mark

    var max_indent = 0
    while (true) {
        if (parser.unread < 1) {
            if (!parserUpdateBuffer(parser, 1)) {
                return (breaks.toArray(), endMark, false)
            }
        }
        while ((indent.value == 0 || parser.mark.column < indent.value) && isSpace(parser.buffer, parser.bufferPos)) {
            skip(parser)
            if (parser.unread < 1) {
                if (!parserUpdateBuffer(parser, 1)) {
                    return (breaks.toArray(), endMark, false)
                }
            }
        }
        if (parser.mark.column > max_indent) {
            max_indent = parser.mark.column
        }

        if ((indent.value == 0 || parser.mark.column < indent.value) && isTab(parser.buffer, parser.bufferPos)) {
            return (breaks.toArray(), endMark, parserSetScannerError(
                    parser,
                    "while scanning a block scalar",
                    startMark,
                    "found a tab character where an indentation space is expected"
                ))
        }

        if (!isBreak(parser.buffer, parser.bufferPos)) {
            break
        }

        if (parser.unread < 2 && !parserUpdateBuffer(parser, 2)) {
            return (breaks.toArray(), endMark, false)
        }

        breaks.add(all: readLine(parser))
        endMark = parser.mark
    }

    if (indent.value == 0) {
        indent.value = max_indent
        if (indent.value < parser.indent + 1) {
            indent.value = parser.indent + 1
        }
        if (indent.value < 1) {
            indent.value = 1
        }
    }
    (breaks.toArray(), endMark, true)
}

func parserFetchFlowScalar(parser: ParserT, single: Bool): Bool {
    if (!parserSaveSimpleKey(parser)) {
        return false
    }

    parser.simpleKeyAllowed = false

    let (token, ok) = parserScanFlowScalar(parser, single)
    if (!ok) {
        return false
    }
    insertToken(parser, -1, token)
    return true
}

func parserScanFlowScalarResolveNonBlankz(
    parser: ParserT,
    single: Bool,
    s: ArrayList<UInt8>,
    token: TokenT,
    startMark: MarkT,
    leadingBlanksBox: Box<Bool>
): (?TokenT, Bool) {
    while (!isBlankz(parser.buffer, parser.bufferPos)) {
        if (single && parser.buffer[parser.bufferPos] == 0x27 && parser.buffer[parser.bufferPos + 1] == 0x27) {
            s.add(0x27)
            skip(parser)
            skip(parser)
        } else if (single && parser.buffer[parser.bufferPos] == 0x27) {
            break
        } else if (!single && parser.buffer[parser.bufferPos] == 0x22) {
            break
        } else if (!single && parser.buffer[parser.bufferPos] == 0x5C && isBreak(
            parser.buffer,
            parser.bufferPos + 1
        )) {
            if (parser.unread < 3 && !parserUpdateBuffer(parser, 3)) {
                return (token, false)
            }

            skip(parser)
            skipLine(parser)
            leadingBlanksBox.value = true
            break
        } else if (!single && parser.buffer[parser.bufferPos] == 0x5C) {
            var codeLength = 0

            match (Rune(UInt32(parser.buffer[parser.bufferPos + 1]))) {
                case '0' => s.add(0)
                case 'a' => s.add(0x07)
                case 'b' => s.add(0x08)
                case 't' | '\t' => s.add(0x09)
                case 'n' => s.add(0x0A)
                case 'v' => s.add(0x0B)
                case 'f' => s.add(0x0C)
                case 'r' => s.add(0x0D)
                case 'e' => s.add(0x1B)
                case ' ' => s.add(0x20)
                case '"' => s.add(0x22)
                case '\'' => s.add(0x27)
                case '\\' => s.add(0x5C)
                case 'N' =>
                    s.add(0xC2)
                    s.add(0x85)
                case '_' =>
                    s.add(0xC2)
                    s.add(0xA0)
                case 'L' =>
                    s.add(0xE2)
                    s.add(0x80)
                    s.add(0xA8)
                case 'P' =>
                    s.add(0xE2)
                    s.add(0x80)
                    s.add(0xA9)
                case 'x' => codeLength = 2
                case 'u' => codeLength = 4
                case 'U' => codeLength = 8
                case _ =>
                    parserSetScannerError(
                        parser,
                        "while parsing a quoted scalar",
                        startMark,
                        "found unknown escape character"
                    )
                    return (token, false)
            }

            skip(parser)
            skip(parser)
            if (codeLength > 0) {
                var value: Int32 = 0

                if (parser.unread < codeLength && !parserUpdateBuffer(parser, codeLength)) {
                    return (token, false)
                }

                for (k in 0..codeLength) {
                    if (!isHex(parser.buffer, parser.bufferPos + k)) {
                        parserSetScannerError(
                            parser,
                            "while parsing a quoted scalar",
                            startMark,
                            "did not find expected hexdecimal number"
                        )
                        return (token, false)
                    }
                    value = (value << 4) + Int32(asHex(parser.buffer, parser.bufferPos + k))
                }

                if ((value >= 0xD800 && value <= 0xDFFF) || value > 0x10FFFF) {
                    parserSetScannerError(
                        parser,
                        "while parsing a quoted scalar",
                        startMark,
                        "found invalid Unicode character escape code"
                    )
                    return (token, false)
                }

                if (value <= 0x7F) {
                    s.add(UInt8(value))
                } else if (value <= 0x7FF) {
                    s.add(UInt8(0xC0 + (value >> 6)))
                    s.add(UInt8(0x80 + (value & 0x3F)))
                } else if (value <= 0xFFFF) {
                    s.add(UInt8(0xE0 + (value >> 12)))
                    s.add(UInt8(0x80 + ((value >> 6) & 0x3F)))
                    s.add(UInt8(0x80 + (value & 0x3F)))
                } else {
                    s.add(UInt8(0xF0 + (value >> 18)))
                    s.add(UInt8(0x80 + ((value >> 12) & 0x3F)))
                    s.add(UInt8(0x80 + ((value >> 6) & 0x3F)))
                    s.add(UInt8(0x80 + (value & 0x3F)))
                }

                for (_ in 0..codeLength) {
                    skip(parser)
                }
            }
        } else {
            s.add(all: read(parser))
        }
        if (parser.unread < 2 && !parserUpdateBuffer(parser, 2)) {
            return (token, false)
        }
    }
    (None, false)
}

func parserScanFlowScalarResolveBlankOrBreak(
    parser: ParserT,
    leadingBreak: ArrayList<UInt8>,
    trailingBreaks: ArrayList<UInt8>,
    whitespaces: ArrayList<UInt8>,
    token: TokenT,
    leadingBlanksBox: Box<Bool>
): (?TokenT, Bool) {
    while (isBlank(parser.buffer, parser.bufferPos) || isBreak(parser.buffer, parser.bufferPos)) {
        if (isBlank(parser.buffer, parser.bufferPos)) {
            if (!leadingBlanksBox.value) {
                whitespaces.add(all: read(parser))
            } else {
                skip(parser)
            }
        } else {
            if (parser.unread < 2 && !parserUpdateBuffer(parser, 2)) {
                return (token, false)
            }

            if (!leadingBlanksBox.value) {
                whitespaces.clear()
                leadingBreak.add(all: readLine(parser))
                leadingBlanksBox.value = true
            } else {
                trailingBreaks.add(all: readLine(parser))
            }
        }
        if (parser.unread < 1 && !parserUpdateBuffer(parser, 1)) {
            return (token, false)
        }
    }
    (None, false)
}

func parserScanFlowScalarResolveLeadingBlanks(
    leadingBlanks: Bool,
    s: ArrayList<UInt8>,
    leadingBreak: ArrayList<UInt8>,
    trailingBreaks: ArrayList<UInt8>,
    whitespaces: ArrayList<UInt8>
) {
    if (leadingBlanks) {
        if (leadingBreak.size > 0 && leadingBreak[0] == 0x0A) {
            if (trailingBreaks.size == 0) {
                s.add(0x20)
            } else {
                s.add(all: trailingBreaks)
            }
        } else {
            s.add(all: leadingBreak)
            s.add(all: trailingBreaks)
        }
        trailingBreaks.clear()
        leadingBreak.clear()
    } else {
        s.add(all: whitespaces)
        whitespaces.clear()
    }
}

func parserScanFlowScalarResolvePreConditions(
    parser: ParserT,
    token: TokenT,
    startMark: MarkT
): (?TokenT, Bool) {
    if (parser.unread < 4 && !parserUpdateBuffer(parser, 4)) {
        return (token, false)
    }

    if (parser.mark.column == 0 && ((parser.buffer[parser.bufferPos + 0] == 0x2D &&
        parser.buffer[parser.bufferPos + 1] == 0x2D && parser.buffer[parser.bufferPos + 2] == 0x2D) || (parser.buffer[parser.
            bufferPos + 0] == 0x2E && parser.buffer[parser.bufferPos + 1] == 0x2E &&
        parser.buffer[parser.bufferPos + 2] == 0x2E)) && isBlankz(parser.buffer, parser.bufferPos + 3)) {
        parserSetScannerError(
            parser,
            "while scanning a quoted scalar",
            startMark,
            "found unexpected document indicator"
        )
        return (token, false)
    }

    if (isZ(parser.buffer, parser.bufferPos)) {
        parserSetScannerError(
            parser,
            "while scanning a quoted scalar",
            startMark,
            "found unexpected end of stream"
        )
        return (token, false)
    }
    (None, false)
}

func parserScanFlowScalarLoop(
    parser: ParserT,
    single: Bool,
    token: TokenT,
    startMark: MarkT,
    s: ArrayList<UInt8>,
    leadingBreak: ArrayList<UInt8>,
    trailingBreaks: ArrayList<UInt8>,
    whitespaces: ArrayList<UInt8>
): ?(TokenT, Bool, Bool) {
    if (let (Some(t), ok) <- parserScanFlowScalarResolvePreConditions(parser, token, startMark)) {
        return (t, ok, false)
    }

    var leadingBlanks = false
    let leadingBlanksBox = Box<Bool>(leadingBlanks)
    if (let (Some(t), ok) <- parserScanFlowScalarResolveNonBlankz(
        parser,
        single,
        s,
        token,
        startMark,
        leadingBlanksBox
    )) {
        return (t, ok, false)
    }
    leadingBlanks = leadingBlanksBox.value

    if (parser.unread < 1 && !parserUpdateBuffer(parser, 1)) {
        return (token, false, false)
    }

    if (single) {
        if (parser.buffer[parser.bufferPos] == 0x27) {
            return (token, false, true)
        }
    } else {
        if (parser.buffer[parser.bufferPos] == 0x22) {
            return (token, false, true)
        }
    }

    if (let (Some(t), ok) <- parserScanFlowScalarResolveBlankOrBreak(
        parser,
        leadingBreak,
        trailingBreaks,
        whitespaces,
        token,
        leadingBlanksBox
    )) {
        return (t, ok, false)
    }
    leadingBlanks = leadingBlanksBox.value

    parserScanFlowScalarResolveLeadingBlanks(
        leadingBlanks,
        s,
        leadingBreak,
        trailingBreaks,
        whitespaces
    )
    return None
}

func parserScanFlowScalar(parser: ParserT, single: Bool): (TokenT, Bool) {
    let startMark = parser.mark
    skip(parser)

    let token = TokenT()
    let s = ArrayList<UInt8>()
    let leadingBreak = ArrayList<UInt8>()
    let trailingBreaks = ArrayList<UInt8>()
    let whitespaces = ArrayList<UInt8>()
    while (true) {
        if (let Some((t, ok, isBreak)) <- parserScanFlowScalarLoop(
            parser,
            single,
            token,
            startMark,
            s,
            leadingBreak,
            trailingBreaks,
            whitespaces
        )) {
            if (isBreak) {
                break
            }
            return (t, ok)
        }
    }

    skip(parser)

    token.typ = TokenTypeT_SCALAR_TOKEN
    token.startMark = startMark
    token.endMark = parser.mark
    token.value = s.toArray()
    token.style = ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE

    (token, true)
}

func parserScanPlainScalarResolve0(
    parser: ParserT,
    s: ArrayList<UInt8>,
    leadingBreak: ArrayList<UInt8>,
    trailingBreaks: ArrayList<UInt8>,
    whitespaces: ArrayList<UInt8>,
    leadingBlanksBox: Box<Bool>,
    token: TokenT,
    endMarkBox: Box<MarkT>
): (?TokenT, Bool) {
    while (!isBlankz(parser.buffer, parser.bufferPos)) {
        if ((parser.buffer[parser.bufferPos] == 0x3A && isBlankz(parser.buffer, parser.bufferPos + 1)) || (parser.
            flowLevel > 0 && (parser.buffer[parser.bufferPos] == 0x2C || parser.buffer[parser.bufferPos] == 0x3F ||
            parser.buffer[parser.bufferPos] == 0x5B || parser.buffer[parser.bufferPos] == 0x5D ||
            parser.buffer[parser.bufferPos] == 0x7B || parser.buffer[parser.bufferPos] == 0x7D))) {
            break
        }

        if (leadingBlanksBox.value || whitespaces.size > 0) {
            if (leadingBlanksBox.value) {
                if (leadingBreak[0] == 0x0A) {
                    if (trailingBreaks.size == 0) {
                        s.add(0x20)
                    } else {
                        s.add(all: trailingBreaks)
                    }
                } else {
                    s.add(all: leadingBreak)
                    s.add(all: trailingBreaks)
                }
                trailingBreaks.clear()
                leadingBreak.clear()
                leadingBlanksBox.value = false
            } else {
                s.add(all: whitespaces)
                whitespaces.clear()
            }
        }

        s.add(all: read(parser))

        endMarkBox.value = parser.mark

        if (parser.unread < 2 && !parserUpdateBuffer(parser, 2)) {
            return (token, false)
        }
    }
    (None, false)
}

func parserScanPlainScalarResolve0(
    parser: ParserT,
    indent: Int64,
    startMark: MarkT,
    token: TokenT,
    leadingBlanksBox: Box<Bool>,
    leadingBreak: ArrayList<UInt8>,
    trailingBreaks: ArrayList<UInt8>,
    whitespaces: ArrayList<UInt8>
): (?TokenT, Bool) {
    while (isBlank(parser.buffer, parser.bufferPos) || isBreak(parser.buffer, parser.bufferPos)) {
        if (isBlank(parser.buffer, parser.bufferPos)) {
            if (leadingBlanksBox.value && parser.mark.column < indent && isTab(parser.buffer, parser.bufferPos)) {
                parserSetScannerError(
                    parser,
                    "while scanning a plain scalar",
                    startMark,
                    "found a tab character that violates indentation"
                )
                return (token, false)
            }

            if (!leadingBlanksBox.value) {
                whitespaces.add(all: read(parser))
            } else {
                skip(parser)
            }
        } else {
            if (parser.unread < 2 && !parserUpdateBuffer(parser, 2)) {
                return (token, false)
            }

            if (!leadingBlanksBox.value) {
                whitespaces.clear()
                leadingBreak.add(all: readLine(parser))
                leadingBlanksBox.value = true
            } else {
                trailingBreaks.add(all: readLine(parser))
            }
        }
        if (parser.unread < 1 && !parserUpdateBuffer(parser, 1)) {
            return (token, false)
        }
    }
    (None, false)
}

func parserScanPlainScalarLoop(
    parser: ParserT,
    token: TokenT,
    indent: Int64,
    startMark: MarkT,
    s: ArrayList<UInt8>,
    leadingBreak: ArrayList<UInt8>,
    trailingBreaks: ArrayList<UInt8>,
    whitespaces: ArrayList<UInt8>,
    leadingBlanks: Box<Bool>,
    endMark: Box<MarkT>
): ?(TokenT, Bool, Bool) {
    if (parser.unread < 4 && !parserUpdateBuffer(parser, 4)) {
        return (token, false, false)
    }
    if (parser.mark.column == 0 && ((parser.buffer[parser.bufferPos + 0] == 0x2D &&
        parser.buffer[parser.bufferPos + 1] == 0x2D && parser.buffer[parser.bufferPos + 2] == 0x2D) || (parser.buffer[parser.
            bufferPos + 0] == 0x2E && parser.buffer[parser.bufferPos + 1] == 0x2E &&
        parser.buffer[parser.bufferPos + 2] == 0x2E)) && isBlankz(parser.buffer, parser.bufferPos + 3)) {
        return (token, false, true)
    }

    if (parser.buffer[parser.bufferPos] == 0x23) {
        return (token, false, true)
    }

    if (let (Some(t), ok) <- parserScanPlainScalarResolve0(
        parser,
        s,
        leadingBreak,
        trailingBreaks,
        whitespaces,
        leadingBlanks,
        token,
        endMark
    )) {
        return (t, ok, false)
    }

    if (!(isBlank(parser.buffer, parser.bufferPos) || isBreak(parser.buffer, parser.bufferPos))) {
        return (token, false, true)
    }

    if (parser.unread < 1 && !parserUpdateBuffer(parser, 1)) {
        return (token, false, false)
    }

    if (let (Some(t), ok) <- parserScanPlainScalarResolve0(
        parser,
        indent,
        startMark,
        token,
        leadingBlanks,
        leadingBreak,
        trailingBreaks,
        whitespaces
    )) {
        return (t, ok, false)
    }

    if (parser.flowLevel == 0 && parser.mark.column < indent) {
        return (token, false, true)
    }
    return None
}

func parserScanPlainScalar(parser: ParserT): (TokenT, Bool) {
    let token = TokenT()
    let s = ArrayList<UInt8>()
    let leadingBreak = ArrayList<UInt8>()
    let trailingBreaks = ArrayList<UInt8>()
    let whitespaces = ArrayList<UInt8>()
    var leadingBlanks = Box<Bool>(false)
    var indent = parser.indent + 1

    let startMark = parser.mark
    var endMark = Box<MarkT>(parser.mark)

    while (true) {
        if (let Some((t, ok, isBreak)) <- parserScanPlainScalarLoop(
            parser,
            token,
            indent,
            startMark,
            s,
            leadingBreak,
            trailingBreaks,
            whitespaces,
            leadingBlanks,
            endMark
        )) {
            if (isBreak) {
                break
            }
            return (t, ok)
        }
    }

    token.typ = TokenTypeT_SCALAR_TOKEN
    token.startMark = startMark
    token.endMark = endMark.value
    token.value = s.toArray()
    token.style = ScalarStyleT_PLAIN_SCALAR_STYLE

    if (leadingBlanks.value) {
        parser.simpleKeyAllowed = true
    }
    (token, true)
}
