/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * Parse a backslash-escaped special character, adding either the escaped  character, a hard line break
 * (if the backslash is followed by a newline), or a literal backslash to the block's children.
 */
public class BackslashInlineParser <: InlineContentParser {
    private static let ESCAPABLE: Regex = Regex('^' + Escaping.ESCAPABLE)

    // @Override
    public func tryParse(inlineParserState: InlineParserState): ParsedInline {
        let scanner: Scanner = inlineParserState.scanner()
        // Backslash
        scanner.next()

        let next = scanner.peek()
        if (next == r'\n') {
            scanner.next()
            return ParsedInline.of(HardLineBreak(), scanner.position())
        } else if (next != r'\0' && ESCAPABLE.matches(next.toString())) {
            scanner.next()
            return ParsedInline.of(Text(next.toString()), scanner.position())
        } else {
            return ParsedInline.of(Text("\\"), scanner.position())
        }
    }
}

public class BackslashInlineParserFactory <: InlineContentParserFactory {
    // @Override
    public func getTriggerCharacters(): HashSet<Rune> {
        return HashSet(r'\\')
    }

    // @Override
    public func create(): InlineContentParser {
        return BackslashInlineParser()
    }
}
