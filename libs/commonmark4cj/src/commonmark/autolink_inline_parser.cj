/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * Attempt to parse an autolink (URL or email in pointy brackets).
 */
public class AutolinkInlineParser <: InlineContentParser {
    private static let URI: Regex = Regex(#"^[a-zA-Z][a-zA-Z0-9.+-]{1,31}:[^<>\x00-\x20]*$"#)

    private static let EMAIL: Regex = Regex(
        #"^([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$"#
    )

    // @Override
    public func tryParse(inlineParserState: InlineParserState): ParsedInline {
        let scanner: Scanner = inlineParserState.scanner()
        scanner.next()
        let textStart: SourcePosition = scanner.position()
        if (scanner.find(r'>') > 0) {
            let textSource: SourceLines = scanner.getSource(textStart, scanner.position())
            let content: String = textSource.getContent()
            scanner.next()

            var destination: ?String = None
            if (URI.matches(content)) {
                destination = content
            } else if (EMAIL.matches(content)) {
                destination = "mailto:" + content
            }

            if (let Some(destination) <- destination) {
                let link: Link = Link(destination, None)
                let text: Text = Text(content)
                text.setSourceSpans(textSource.getSourceSpans())
                link.appendChild(text)
                return ParsedInline.of(link, scanner.position())
            }
        }
        return ParsedInline.none()
    }
}

public class AutolinkInlineParserFactory <: InlineContentParserFactory {
    // @Override
    public func getTriggerCharacters(): HashSet<Rune> {
        return HashSet(r'<')
    }

    // @Override
    public func create(): InlineContentParser {
        return AutolinkInlineParser()
    }
}
