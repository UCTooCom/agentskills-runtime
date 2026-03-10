/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * A set of lines ({@link SourceLine}) from the input source.
 */
public class SourceLines {
    private let lines: ArrayList<SourceLine> = ArrayList()

    public static func empty(): SourceLines {
        return SourceLines()
    }

    public static func of(sourceLine: SourceLine): SourceLines {
        let sourceLines: SourceLines = SourceLines()
        sourceLines.addLine(sourceLine)
        return sourceLines
    }

    public static func of(sourceLines: ArrayList<SourceLine>): SourceLines {
        let result: SourceLines = SourceLines()
        result.lines.add(all: sourceLines)
        return result
    }

    public func addLine(sourceLine: SourceLine): Unit {
        lines.add(sourceLine)
    }

    public func getLines(): ArrayList<SourceLine> {
        return lines
    }

    public func isEmpty(): Bool {
        return lines.isEmpty()
    }

    public func getContent(): String {
        let sb: StringBuilder = StringBuilder()
        for (i in 0..lines.size) {
            if (i != 0) {
                sb.append('\n')
            }
            sb.append(lines[i].getContent())
        }
        return sb.toString()
    }

    @Frozen
    public func getSourceSpans(): ArrayList<SourceSpan> {
        let sourceSpans: ArrayList<SourceSpan> = ArrayList()
        for (line in lines) {
            let sourceSpan = line.getSourceSpan()
            if (let Some(sourceSpan) <- sourceSpan) {
                sourceSpans.add(sourceSpan)
            }
        }
        return sourceSpans
    }
}

/**
 * A line or part of a line from the input source.
 */
public class SourceLine {
    private let content: CharSequence
    private let sourceSpan: ?SourceSpan

    public static func of(content: CharSequence, sourceSpan: ?SourceSpan): SourceLine {
        return SourceLine(content, sourceSpan)
    }

    private SourceLine(content: CharSequence, sourceSpan: ?SourceSpan) {
        this.content = content
        this.sourceSpan = sourceSpan
    }

    public func getContent(): CharSequence {
        return content
    }

    public func getSourceSpan(): ?SourceSpan {
        return sourceSpan
    }

    public func substring(beginIndex: Int, endIndex: Int): SourceLine {
        let newContent: CharSequence = content[beginIndex..endIndex]
        var newSourceSpan: ?SourceSpan = None
        if (let Some(sourceSpan) <- sourceSpan) {
            let length: Int = endIndex - beginIndex
            if (length != 0) {
                let columnIndex: Int = sourceSpan.getColumnIndex() + beginIndex
                let inputIndex: Int = sourceSpan.getInputIndex() + beginIndex
                newSourceSpan = SourceSpan.of(sourceSpan.getLineIndex(), columnIndex, inputIndex, length)
            }
        }
        return SourceLine.of(newContent, newSourceSpan)
    }
}
