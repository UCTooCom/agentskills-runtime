/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * Matcher interface for {@code Rune} values.
 * <p>
 * Note that because this matches on {@code Rune} values only (as opposed to {@code Int} code points),
 * this only operates on the level of code units and doesn't support supplementary characters
 * (see {@link Character#isSupplementaryCodePoint(Int)}).
 */
public interface CharMatcher {
    func matches(c: Rune): Bool
}

/**
 * Char matcher that can match ASCII characters efficiently.
 */
public class AsciiMatcher <: CharMatcher {
    private let set: BitSet

    AsciiMatcher(builder: AsciiMatcherBuilder) {
        this.set = builder.set
    }

    // @Override
    public func matches(c: Rune): Bool {
        return set.get(Int64(UInt32(c)))
    }

    public func newBuilder(): AsciiMatcherBuilder {
        return AsciiMatcherBuilder(set.clone())
    }

    public static func builder(): AsciiMatcherBuilder {
        return AsciiMatcherBuilder(BitSet(16))
    }

    public static func builder(matcher: AsciiMatcher): AsciiMatcherBuilder {
        return AsciiMatcherBuilder(matcher.set.clone())
    }
}

public class AsciiMatcherBuilder {
    let set: BitSet

    AsciiMatcherBuilder(set: BitSet) {
        this.set = set
    }

    public func c(ch: Byte): AsciiMatcherBuilder {
        c(Int64(ch))
    }
    public func c(ch: Rune): AsciiMatcherBuilder {
        c(Int64(UInt32(ch)))
    }
    public func c(ch: Int64): AsciiMatcherBuilder {
        if (ch > 127) {
            throw IllegalArgumentException("Can only match ASCII characters")
        }
        set.set(ch)
        return this
    }

    public func anyOf(s: String): AsciiMatcherBuilder {
        for (i in 0..s.size) {
            c(s[i])
        }
        return this
    }

    public func anyOf(characters: Set<Byte>): AsciiMatcherBuilder {
        for (ch in characters) {
            c(ch)
        }
        return this
    }

    public func range(from: Byte, toInclusive: Byte): AsciiMatcherBuilder {
        for (ch in from..=toInclusive) {
            c(ch)
        }
        return this
    }

    public func build(): AsciiMatcher {
        return AsciiMatcher(this)
    }
}
