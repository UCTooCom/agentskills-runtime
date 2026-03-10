/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * Attempts to parse an HTML entity or numeric character reference.
 */
public class EntityInlineParser <: InlineContentParser {
    private static let hex: AsciiMatcher = AsciiMatcher
        .builder()
        .range(b'0', b'9')
        .range(b'A', b'F')
        .range(b'a', b'f')
        .build()
    private static let dec: AsciiMatcher = AsciiMatcher.builder().range(b'0', b'9').build()
    private static let entityStart: AsciiMatcher = AsciiMatcher.builder().range(b'A', b'Z').range(b'a', b'z').build()
    private static let entityContinue: AsciiMatcher = entityStart.newBuilder().range(b'0', b'9').build()

    // @Override
    public func tryParse(inlineParserState: InlineParserState): ParsedInline {
        let scanner: Scanner = inlineParserState.scanner()
        let start: SourcePosition = scanner.position()
        // Skip `&`
        scanner.next()

        let c = scanner.peek()
        if (c == r'#') {
            // Numeric
            scanner.next()
            if (scanner.next('x') || scanner.next('X')) {
                let digits: Int = scanner.matches(hex)
                if (1 <= digits && digits <= 6 && scanner.next(';')) {
                    return entity(scanner, start)
                }
            } else {
                let digits: Int = scanner.matches(dec)
                if (1 <= digits && digits <= 7 && scanner.next(';')) {
                    return entity(scanner, start)
                }
            }
        } else if (entityStart.matches(c)) {
            scanner.matches(entityContinue)
            if (scanner.next(';')) {
                return entity(scanner, start)
            }
        }

        return ParsedInline.none()
    }

    private func entity(scanner: Scanner, start: SourcePosition): ParsedInline {
        let text: String = scanner.getSource(start, scanner.position()).getContent()
        return ParsedInline.of(Text(Html5Entities.entityToString(text)), scanner.position())
    }
}

public class EntityInlineParserFactory <: InlineContentParserFactory {

    // @Override
    public func getTriggerCharacters(): HashSet<Rune> {
        return HashSet(r'&')
    }

    // @Override
    public func create(): InlineContentParser {
        return EntityInlineParser()
    }
}
