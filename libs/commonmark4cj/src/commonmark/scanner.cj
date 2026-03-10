/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

public class Scanner {

    /**
     * Character representing the end of input source (or outside of the text in case of the "previous" methods).
     * <p>
     * Note that we can use NULL to represent this because CommonMark does not allow those in the input (we replace them
     * in the beginning of parsing).
     */
    public static let END: Rune = r'\0'

    // Lines without newlines at the end. The scanner will yield `\n` between lines because they're significant for
    // parsing and the let output. There is no `\n` after the last line.
    public let lines: ArrayList<SourceLine>
    // Which line we're at.
    public var lineIndex: Int
    // The index within the line. let index : If == length(), we pretend that there's a `\n` and only advance after we yield
    // that.
    public var index: Int
    private var index_rune: Rune = END // 当前index的Rune
    private var index_next = (-1, -1) // (lineIndex, index) 下一个index的坐标(计算了Rune长度) 用于判断是否已进行peek

    // Current line or "" if at the end of the lines (using "" instead of None saves a None check)
    var line: SourceLine = SourceLine.of("", None)
    private var lineLength: Int = 0

    Scanner(lines: ArrayList<SourceLine>, lineIndex: Int, index: Int) {
        this.lines = lines
        this.lineIndex = lineIndex
        this.index = index
        if (!lines.isEmpty()) {
            checkPosition(lineIndex, index)
            setLine(lines[lineIndex])
        }
    }

    public static func of(lines: SourceLines): Scanner {
        return Scanner(lines.getLines(), 0, 0)
    }

    public func peek(): Rune {
        if (index < lineLength) {
            if (index_next[0] > lineIndex || (index_next[0] == lineIndex && index_next[1] > index)) {
                return index_rune
            } else {
                let (r, len) = Rune.fromUtf8(unsafe { line.getContent().rawData() }, index)
                index_rune = r
                index_next = (lineIndex, index + len)
                return index_rune
            }
        } else {
            if (lineIndex < lines.size - 1) {
                return r'\n'
            } else {
                // Don't return newline for end of last line
                return END
            }
        }
    }

    public func peekCodePoint(): Rune {
        peek()
    }

    public func peekPreviousCodePoint(): Rune {
        if (index > 0) {
            let (r, _) = Rune.getPreviousFromUtf8(unsafe { line.getContent().rawData() }, index)
            return r
        } else {
            if (lineIndex > 0) {
                return r'\n'
            } else {
                return END
            }
        }
    }

    public func hasNext(): Bool {
        if (index < lineLength) {
            return true
        } else {
            // No newline at end of last line
            return lineIndex < lines.size - 1
        }
    }

    public func next(): Unit {
        match (index + 1) {
            case v where v < lineLength =>
                // 行内
                peek()
                index = index_next[1]
            case v where v == lineLength =>
                index++ // 行末
            case v where v > lineLength =>
                // 跨行
                lineIndex++
                if (lineIndex < lines.size) {
                    setLine(lines[lineIndex])
                } else {
                    setLine(SourceLine.of("", None))
                }
                index = 0
            case _ => ()
        }
    }

    /**
     * Check if the specified Rune is next and advance the position.
     *
     * @param c the Rune to check (including newline characters)
     * @return true if matched and position was advanced, false otherwise
     */
    public func next(c: Rune): Bool {
        if (peek() == c) {
            next()
            return true
        } else {
            return false
        }
    }

    /**
     * Check if we have the specified content on the line and advanced the position. Note that if you want to match
     * newline characters, use {@link #next(Rune)}.
     *
     * @param content the text content to match on a single line (excluding newline characters)
     * @return true if matched and position was advanced, false otherwise
     */
    public func next(content: String): Bool {
        if (index < lineLength && index + content.size <= lineLength) {
            // Can't use startsWith because it's not available on CharSequence
            for (i in 0..content.size) {
                if (line.getContent()[index + i] != content[i]) {
                    return false
                }
            }
            index += content.size
            return true
        } else {
            return false
        }
    }

    public func matchMultiple(c: Rune): Int {
        var count: Int = 0
        while (peek() == c) {
            count++
            next()
        }
        return count
    }

    public func matches(matcher: CharMatcher): Int {
        var count: Int = 0
        while (matcher.matches(peek())) {
            count++
            next()
        }
        return count
    }

    public func whitespace(): Int {
        var count: Int = 0
        while (true) {
            match (peek()) {
                case ' ' | '\t' | '\n' | '\u{000B}' | '\f' | '\r' =>
                    count++
                    next()
                case _ => return count
            }
        }
        return count
    }

    public func find(c: Rune): Int {
        var count: Int = 0
        while (true) {
            let cur = peek()
            if (cur == Scanner.END) {
                return -1
            } else if (cur == c) {
                return count
            }
            count++
            next()
        }
        return count
    }

    public func find(matcher: CharMatcher): Int {
        var count: Int = 0
        while (true) {
            let c = peek()
            if (c == END) {
                return -1
            } else if (matcher.matches(c)) {
                return count
            }
            count++
            next()
        }
        return count
    }

    // Don't expose the Int index, because it would be good if we could switch input to a Collection<String> of lines later
    // instead of one contiguous String.
    public func position(): SourcePosition {
        return SourcePosition(lineIndex, index)
    }

    public func setPosition(position: SourcePosition): Unit {
        checkPosition(position.lineIndex, position.index)
        this.lineIndex = position.lineIndex
        this.index = position.index
        setLine(lines[this.lineIndex])
        index_next = (-1, -1) // reset index_next
    }

    // For cases where the caller appends the result to a StringBuilder, we could offer another method to avoid some
    // unnecessary copying.
    public func getSource(begin: SourcePosition, end: SourcePosition): SourceLines {
        if (begin.lineIndex == end.lineIndex) {
            // Shortcut for common case of text from a single line
            let line: SourceLine = lines[begin.lineIndex]
            let newContent: CharSequence = line.getContent()[begin.index..end.index]
            let sourceSpan = line.getSourceSpan()
            let newSourceSpan: ?SourceSpan = sourceSpan?.subSpan(begin.index, end.index)
            return SourceLines.of(SourceLine.of(newContent, newSourceSpan))
        } else {
            let sourceLines: SourceLines = SourceLines.empty()

            let firstLine: SourceLine = lines[begin.lineIndex]
            sourceLines.addLine(firstLine.substring(begin.index, firstLine.getContent().size))

            // Lines between begin and end (we are appending the full line)
            for (line in begin.lineIndex + 1..end.lineIndex) {
                sourceLines.addLine(lines[line])
            }

            let lastLine: SourceLine = lines[end.lineIndex]
            sourceLines.addLine(lastLine.substring(0, end.index))
            return sourceLines
        }
    }

    private func setLine(line: SourceLine): Unit {
        this.line = line
        this.lineLength = line.getContent().size
    }

    private func checkPosition(lineIndex: Int, index: Int): Unit {
        if (lineIndex < 0 || lineIndex >= lines.size) {
            throw IllegalArgumentException("Line index ${lineIndex} out of range, number of lines: ${lines.size}")
        }
        let line: SourceLine = lines[lineIndex]
        if (index < 0 || index > line.getContent().size) {
            throw IllegalArgumentException("Index ${index} out of range, line length: ${line.getContent().size}")
        }
    }
}
