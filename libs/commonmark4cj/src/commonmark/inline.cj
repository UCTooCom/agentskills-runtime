/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

public abstract class EmphasisDelimiterProcessor <: DelimiterProcessor {
    private let delimiterChar: Rune

    protected init(delimiterChar: Rune) {
        this.delimiterChar = delimiterChar
    }

    public override func getOpeningCharacter(): Rune {
        return delimiterChar
    }

    public override func getClosingCharacter(): Rune {
        return delimiterChar
    }

    public override func getMinLength(): Int64 {
        return 1
    }

    public override func getDelimiterUse(opener: DelimiterRun, closer: DelimiterRun): Int64 {
        // "multiple of 3" rule for internal delimiter runs
        if ((opener.canClose() || closer.canOpen()) && closer.getOriginalLength() % 3 != 0 &&
            (opener.getOriginalLength() + closer.getOriginalLength()) % 3 == 0) {
            return 0
        }
        // calculate actual number of delimiters used from this closer
        if (opener.getLength() >= 2 && closer.getLength() >= 2) {
            return 2
        } else {
            return 1
        }
    }

    public override func process(opener: Text, closer: Text, delimiterUse: Int64): Unit {
        let singleDelimiter: String = String(getOpeningCharacter())
        let emphasis: Node = if (delimiterUse == 1) {
            Emphasis(singleDelimiter)
        } else {
            StrongEmphasis(singleDelimiter + singleDelimiter)
        }
        var tmp: ?Node = opener.getNext()
        while (let Some(v) <- tmp && v != closer) {
            tmp = v.getNext()
            emphasis.appendChild(v)
        }

        opener.insertAfter(emphasis)
    }
}

public class UnderscoreDelimiterProcessor <: EmphasisDelimiterProcessor {
    public init() {
        super(r'_')
    }
}

public class AsteriskDelimiterProcessor <: EmphasisDelimiterProcessor {
    public init() {
        super(r'*')
    }
}
