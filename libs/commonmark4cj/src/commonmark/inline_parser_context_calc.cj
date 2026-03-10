/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

class InlineParserContextCalc {
    var specialCharacters: BitSet
    var delimiterProcessors: HashMap<Rune, DelimiterProcessor>
    let inlineContentParserFactories: ArrayList<InlineContentParserFactory>
    let linkProcessors: ArrayList<LinkProcessor>
    let linkMarkers: BitSet

    init(context: InlineParserContext) {
        this.inlineContentParserFactories = calculateInlineContentParserFactories(
            context.getCustomInlineContentParserFactories())
        this.delimiterProcessors = calculateDelimiterProcessors(context.getCustomDelimiterProcessors())
        this.linkProcessors = calculateLinkProcessors(context.getCustomLinkProcessors())
        this.linkMarkers = calculateLinkMarkers(context.getCustomLinkMarkers())
        this.specialCharacters = calculateSpecialCharacters(linkMarkers, this.delimiterProcessors.keys(),
            this.inlineContentParserFactories)
    }

    @Frozen
    private static func calculateInlineContentParserFactories(customFactories: ArrayList<InlineContentParserFactory>): ArrayList<InlineContentParserFactory> {
        // Custom parsers can override built-in parsers if they want, so make sure they are tried first
        var list = ArrayList(customFactories)
        list.add(BackslashInlineParserFactory())
        list.add(BackticksInlineParserFactory())
        list.add(EntityInlineParserFactory())
        list.add(AutolinkInlineParserFactory())
        list.add(HtmlInlineParserFactory())
        return list
    }

    @Frozen
    private static func calculateLinkProcessors(linkProcessors: ArrayList<LinkProcessor>): ArrayList<LinkProcessor> {
        // Custom link processors can override the built-in behavior, so make sure they are tried first
        var list = ArrayList(linkProcessors)
        list.add(CoreLinkProcessor())
        return list
    }

    @Frozen
    private static func calculateDelimiterProcessors(delimiterProcessors: ArrayList<DelimiterProcessor>): HashMap<Rune,
        DelimiterProcessor> {
        var map: HashMap<Rune, DelimiterProcessor> = HashMap<Rune, DelimiterProcessor>()
        addDelimiterProcessors([AsteriskDelimiterProcessor(), UnderscoreDelimiterProcessor()], map)
        addDelimiterProcessors(delimiterProcessors, map)
        return map
    }

    @Frozen
    private static func addDelimiterProcessors(
        delimiterProcessors: Collection<DelimiterProcessor>,
        hashMap: HashMap<Rune, DelimiterProcessor>
    ): Unit {
        for (delimiterProcessor in delimiterProcessors) {
            let opening: Rune = delimiterProcessor.getOpeningCharacter()
            let closing: Rune = delimiterProcessor.getClosingCharacter()
            if (opening == closing) {
                let old: Option<DelimiterProcessor> = hashMap.get(opening)
                if (old.isSome() && old().getOpeningCharacter() == old().getClosingCharacter()) {
                    var s: StaggeredDelimiterProcessor
                    if (let Some(v: StaggeredDelimiterProcessor) <- old) {
                        s = v
                    } else {
                        s = StaggeredDelimiterProcessor(opening)
                        s.add(old())
                    }
                    s.add(delimiterProcessor)
                    hashMap.add(opening, s)
                } else {
                    addDelimiterProcessorForChar(opening, delimiterProcessor, hashMap)
                }
            } else {
                addDelimiterProcessorForChar(opening, delimiterProcessor, hashMap)
                addDelimiterProcessorForChar(closing, delimiterProcessor, hashMap)
            }
        }
    }

    @Frozen
    private static func addDelimiterProcessorForChar(
        delimiterChar: Rune,
        toAdd: DelimiterProcessor,
        delimiterProcessors: HashMap<Rune, DelimiterProcessor>
    ): Unit {
        let existing: ?DelimiterProcessor = delimiterProcessors.add(delimiterChar, toAdd)
        if (existing.isSome()) {
            throw IllegalArgumentException("Delimiter processor conflict with delimiter char '${delimiterChar}'")
        }
    }

    @Frozen
    private static func calculateLinkMarkers(linkMarkers: Set<Rune>): BitSet {
        var bitSet = BitSet(8)
        for (c in linkMarkers) {
            bitSet.set(Int64(UInt32(c)))
        }
        bitSet.set(Int64(b'!'))
        return bitSet
    }

    @Frozen
    private static func calculateSpecialCharacters(
        linkMarkers: BitSet,
        delimiterCharacters: Collection<Rune>,
        inlineContentParserFactories: ArrayList<InlineContentParserFactory>
    ): BitSet {
        var bitSet: BitSet = linkMarkers.clone()
        for (c in delimiterCharacters) {
            bitSet.set(Int64(UInt32(c)))
        }
        for (factory in inlineContentParserFactories) {
            for (c in factory.getTriggerCharacters()) {
                bitSet.set(Int64(UInt32(c)))
            }
        }
        bitSet.set(Int64(b'['))
        bitSet.set(Int64(b']'))
        bitSet.set(Int64(b'!'))
        bitSet.set(Int64(b'\n'))
        return bitSet
    }
}
