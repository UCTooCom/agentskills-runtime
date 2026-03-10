/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * Parser for a type of inline content. Registered via a {@link InlineContentParserFactory} and created by its
 * {@link InlineContentParserFactory#create() create} method. The lifetime of this is tied to each inline content
 * snippet that is parsed, as a new instance is created for each.
 */
public interface InlineContentParser {

    /**
     * Try to parse inline content starting from the current position. Note that the character at the current position
     * is one of {@link InlineContentParserFactory#getTriggerCharacters()} of the factory that created this parser.
     * <p>
     * For a given inline content snippet that is being parsed, this method can be called multiple times: each time a
     * trigger character is encountered.
     *
     * @param inlineParserState the current state of the inline parser
     * @return the result of parsing; can indicate that this parser is not interested, or that parsing was successful
     */
    func tryParse(inlineParserState: InlineParserState): ParsedInline
}

/**
 * A factory for extending inline content parsing.
 * <p>
 * See {@link org.commonmark.parser.Parser.Builder#customInlineContentParserFactory} for how to register it.
 */
public interface InlineContentParserFactory {

    /**
     * An inline content parser needs to have a special "trigger" character which activates it. When this character is
     * encountered during inline parsing, {@link InlineContentParser#tryParse} is called with the current parser state.
     * It can also register for more than one trigger character.
     */
    func getTriggerCharacters(): Set<Rune>

    /**
     * Create an {@link InlineContentParser} that will do the parsing. Create is called once per text snippet of inline
     * content inside block structures, and then called each time a trigger character is encountered.
     */
    func create(): InlineContentParser
}

public interface InlineParserState {

    /**
     * Return a scanner for the input for the current position (on the trigger character that the inline parser was
     * added for).
     * <p>
     * Note that this always returns the same instance, if you want to backtrack you need to use
     * {@link Scanner#position()} and {@link Scanner#setPosition(SourcePosition)}.
     */
    func scanner(): Scanner
}
