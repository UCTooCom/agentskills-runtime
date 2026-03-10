/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * A source span references a snippet of text from the source input.
 * <p>
 * It has a starting position (line and column index) and a length of how many characters it spans.
 * <p>
 * For example, this CommonMark source text:
 * <pre><code>
 * &gt; foo
 * </code></pre>
 * The {@link BlockQuote} node would have this source span: line 0, column 0, length 5.
 * <p>
 * The {@link Paragraph} node inside it would have: line 0, column 2, length 3.
 * <p>
 * If a block has multiple lines, it will have a source span for each line.
 * <p>
 * Note that the column index and length are measured in Java characters (UTF-16 code units). If you're outputting them
 * to be consumed by another programming language, e.g. one that uses UTF-8 strings, you will need to translate them,
 * otherwise characters such as emojis will result in incorrect positions.
 */
public class SourceSpan <: Equatable<SourceSpan> & ToString {
    private let lineIndex: Int
    private let columnIndex: Int
    private let inputIndex: Int
    private let length: Int

    public static func of(line: Int, col: Int, input: Int, length: Int): SourceSpan {
        return SourceSpan(line, col, input, length)
    }

    /**
     * @deprecated Use {{@link #of(Int, Int, Int, Int)}} instead to also specify input index. Using the deprecated one
     * will set {@link #inputIndex} to 0.
     */
    // @Deprecated
    public static func of(lineIndex: Int, columnIndex: Int, length: Int): SourceSpan {
        return of(lineIndex, columnIndex, 0, length)
    }

    private SourceSpan(lineIndex: Int, columnIndex: Int, inputIndex: Int, length: Int) {
        if (lineIndex < 0) {
            throw IllegalArgumentException("lineIndex ${lineIndex} must be >= 0")
        }
        if (columnIndex < 0) {
            throw IllegalArgumentException("columnIndex ${columnIndex} must be >= 0")
        }
        if (inputIndex < 0) {
            throw IllegalArgumentException("inputIndex ${inputIndex} must be >= 0")
        }
        if (length < 0) {
            throw IllegalArgumentException("length ${length} must be >= 0")
        }
        this.lineIndex = lineIndex
        this.columnIndex = columnIndex
        this.inputIndex = inputIndex
        this.length = length
    }

    /**
     * @return 0-based line index, e.g. 0 for first line, 1 for the second line, etc
     */
    public func getLineIndex(): Int {
        return lineIndex
    }

    /**
     * @return 0-based index of column (character on line) in source, e.g. 0 for the first character of a line, 1 for
     * the second character, etc
     */
    public func getColumnIndex(): Int {
        return columnIndex
    }

    /**
     * @return 0-based index in whole input
     */
    public func getInputIndex(): Int {
        return inputIndex
    }

    /**
     * @return length of the span in characters
     */
    public func getLength(): Int {
        return length
    }

    public func subSpan(beginIndex: Int): SourceSpan {
        return subSpan(beginIndex, length)
    }

    public func subSpan(beginIndex: Int, endIndex: Int): SourceSpan {
        if (beginIndex < 0) {
            throw IndexOutOfBoundsException("beginIndex ${beginIndex} + must be >= 0")
        }
        if (beginIndex > length) {
            throw IndexOutOfBoundsException("beginIndex ${beginIndex} must be <= length ${length}")
        }
        if (endIndex < 0) {
            throw IndexOutOfBoundsException("endIndex ${endIndex} + must be >= 0")
        }
        if (endIndex > length) {
            throw IndexOutOfBoundsException("endIndex ${endIndex} must be <= length ${length}")
        }
        if (beginIndex > endIndex) {
            throw IndexOutOfBoundsException("beginIndex ${beginIndex} must be <= endIndex ${endIndex}")
        }
        if (beginIndex == 0 && endIndex == length) {
            return this
        }
        return SourceSpan(lineIndex, columnIndex + beginIndex, inputIndex + beginIndex, endIndex - beginIndex)
    }

    public operator func ==(that: SourceSpan): Bool {
        if (refEq(this, that)) {
            return true
        }
        return lineIndex == that.lineIndex && columnIndex == that.columnIndex && inputIndex == that.inputIndex &&
            length == that.length
    }
    public operator func !=(that: SourceSpan): Bool {
        !(this == that)
    }

    // @Override
    // public func hashCode() : Int  {
    //     return Objects.hash(lineIndex, columnIndex, inputIndex, length)
    // }

    public func toString(): String {
        return "SourceSpan{line=${lineIndex}, column=${columnIndex}, input=${inputIndex}, length=${length}}"
    }
}

/**
 * A list of source spans that can be added to. Takes care of merging adjacent source spans.
 */
public class SourceSpans {
    private var sourceSpans: ?ArrayList<SourceSpan> = None

    public static func empty(): SourceSpans {
        return SourceSpans()
    }

    public func getSourceSpans(): ArrayList<SourceSpan> {
        return sourceSpans ?? ArrayList()
    }

    public func addAllFrom(nodes: Collection<Node>): Unit {
        for (node in nodes) {
            addAll(node.getSourceSpans())
        }
    }

    public func addAll(other: ArrayList<SourceSpan>): Unit {
        if (other.isEmpty()) {
            return
        }

        let sourceSpans = sourceSpans ?? ArrayList()

        if (sourceSpans.isEmpty()) {
            sourceSpans.add(all: other)
        } else {
            let lastIndex: Int = sourceSpans.size - 1
            let a: SourceSpan = sourceSpans[lastIndex]
            let b: SourceSpan = other[0]
            if (a.getInputIndex() + a.getLength() == b.getInputIndex()) {
                sourceSpans[lastIndex] = SourceSpan.of(a.getLineIndex(), a.getColumnIndex(), a.getInputIndex(),
                    a.getLength() + b.getLength())
                sourceSpans.add(all: other[1..])
            } else {
                sourceSpans.add(all: other)
            }
        }
    }
}

/**
 * SourcePosition within a {@link Scanner}. This is intentionally kept opaque so as not to expose the internal structure of
 * the Scanner.
 */
public class SourcePosition {
    public SourcePosition(public let lineIndex: Int, public let index: Int) {}
}

extend SourcePosition <:ToString{
    public func toString(): String {
        return "{lineIndex=${lineIndex}, index=${index}}"
    }
}