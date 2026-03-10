/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * Attempt to parse backticks, returning either a backtick code span or a literal sequence of backticks.
 */
public class BackticksInlineParser <: InlineContentParser {

    // @Override
    public func tryParse(inlineParserState: InlineParserState): ParsedInline {
        let scanner: Scanner = inlineParserState.scanner()
        let start: SourcePosition = scanner.position()
        let openingTicks: Int = scanner.matchMultiple(r'`')
        let afterOpening: SourcePosition = scanner.position()

        while (scanner.find(r'`') > 0) {
            let beforeClosing: SourcePosition = scanner.position()
            let count: Int = scanner.matchMultiple(r'`')
            if (count == openingTicks) {
                var content: String = scanner.getSource(afterOpening, beforeClosing).getContent()
                content = content.replace('\n', ' ')

                // spec: If the resulting string both begins and ends with a space character, but does not consist
                // entirely of space characters, a single space character is removed from the front and back.
                if (content.size >= 3 && content[0] == b' ' && content[content.size - 1] == b' ' &&
                    Characters.hasNonSpace(content)) {
                    content = content[1..content.size - 1]
                }

                let node: Code = Code(content)
                return ParsedInline.of(node, scanner.position())
            }
        }

        // If we got here, we didn't find a matching closing backtick sequence.
        let source: SourceLines = scanner.getSource(start, afterOpening)
        let text: Text = Text(source.getContent())
        return ParsedInline.of(text, afterOpening)
    }
}

public class BackticksInlineParserFactory <: InlineContentParserFactory {
    // @Override
    public func getTriggerCharacters(): HashSet<Rune> {
        return HashSet(r'`')
    }

    // @Override
    public func create(): InlineContentParser {
        return BackticksInlineParser()
    }
}
