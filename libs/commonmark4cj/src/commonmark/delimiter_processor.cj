/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

public interface DelimiterProcessor {

    /**
     * @return the character that marks the beginning of a delimited node, must not clash with any built-in special
     * characters
     */
    func getOpeningCharacter(): Rune

    /**
     * @return the character that marks the the ending of a delimited node, must not clash with any built-in special
     * characters. Note that for a symmetric delimiter such as "*", this is the same as the opening.
     */
    func getClosingCharacter(): Rune

    /**
     * Minimum number of delimiter characters that are needed to activate this. Must be at least 1.
     */
    func getMinLength(): Int64

    /**
     * Determine how many (if any) of the delimiter characters should be used.
     * <p>
     * This allows implementations to decide how many characters to use based on the properties of the delimiter runs.
     * An implementation can also return 0 when it doesn't want to allow this particular combination of delimiter runs.
     *
     * @param opener the opening delimiter run
     * @param closer the closing delimiter run
     * @return how many delimiters should be used must not be greater than length of either opener or closer
     */
    func getDelimiterUse(opener: DelimiterRun, closer: DelimiterRun): Int64

    /**
     * Process the matched delimiters, e.g. by wrapping the nodes between opener and closer in a new node, or appending
     * a new node after the opener.
     * <p>
     * Note that removal of the delimiter from the delimiter nodes and unlinking them is done by the caller.
     *
     * @param opener the text node that contained the opening delimiter
     * @param closer the text node that contained the closing delimiter
     * @param delimiterUse the number of delimiters that were used
     */
    func process(opener: Text, closer: Text, delimiterUse: Int64): Unit
}

class StaggeredDelimiterProcessor <: DelimiterProcessor {
    private var delim: Rune
    private var minLength: Int64 = 0
    private var processors: LinkedList<DelimiterProcessor> = LinkedList<DelimiterProcessor>()

    init(delim: Rune) {
        this.delim = delim
    }

    public override func getOpeningCharacter(): Rune {
        return delim
    }

    public override func getClosingCharacter(): Rune {
        return delim
    }

    public override func getMinLength(): Int64 {
        return minLength
    }

    func add(dp: DelimiterProcessor): Unit {
        let len: Int64 = dp.getMinLength()
        var added: Bool = false
        var i: Int64 = 0
        for (p in processors) {
            let pLen: Int64 = p.getMinLength()
            if (len > pLen) {
                processors.addBefore(processors.nodeAt(i)(), dp)
                added = true
                break
            } else if (len == pLen) {
                throw IllegalArgumentException(
                    "Cannot add two delimiter processors for char '${delim}' and minimum length ${len}")
            }
            i++
        }

        if (!added) {
            processors.addLast(dp)
            this.minLength = len
        }
    }

    private func findProcessor(len: Int64): DelimiterProcessor {
        for (p in processors) {
            if (p.getMinLength() <= len) {
                return p
            }
        }
        return processors.firstNode().value
    }

    public override func getDelimiterUse(opener: DelimiterRun, closer: DelimiterRun): Int64 {
        return findProcessor(opener.getLength()).getDelimiterUse(opener, closer)
    }

    public override func process(opener: Text, closer: Text, delimiterUse: Int64): Unit {
        findProcessor(delimiterUse).process(opener, closer, delimiterUse)
    }
}
