/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

package commonmark4cj.table

class TableBlockParser <: AbstractBlockParser {
    private var block: TableBlock = TableBlock()
    private var bodyLines: ArrayList<String> = ArrayList<String>()
    private let columns: ArrayList<?Alignment>
    private let headerCells: ArrayList<String>

    var lineState: Int = 0 // 行状态 0:head 0:column 2:body

    init(columns: ArrayList<?Alignment>, headerCells: ArrayList<String>) {
        this.columns = columns
        this.headerCells = headerCells
    }

    public func canHaveLazyContinuationLines(): Bool {
        return true
    }

    public func getBlock(): TableBlock {
        return block
    }

    public func tryContinue(state: ParserState): ?BlockContinue {
        if (state.getLine().contains("|")) {
            return BlockContinue.atIndex(state.getIndex())
        } else {
            return BlockContinue.none()
        }
    }

    public func addLine(line: String): Unit {
        if (lineState != 2) {
            lineState++
        } else {
            bodyLines.add(line)
        }
    }

    public func parseInlines(inlineParser: InlineParser): Unit {
        var headerColumns: Int64 = headerCells.size
        var head: Node = TableHead()
        block.appendChild(head)

        var headerRow: TableRow = TableRow()
        head.appendChild(headerRow)
        for (i in 0..headerColumns) {
            let cell: String = headerCells.get(i).getOrThrow()
            var tableCell: TableCell = parseCell(cell, i, inlineParser)
            tableCell.setHeader(true)
            headerRow.appendChild(tableCell)
        }

        var body: ?Node = None
        for (rowLine in bodyLines) {
            var cells: ArrayList<String> = split(rowLine)
            var row: TableRow = TableRow()

            // Body can not have more columns than head
            for (i in 0..headerColumns) {
                var cell: String = ""
                if (i < cells.size) {
                    cell = cells.get(i).getOrThrow()
                }
                var tableCell: TableCell = parseCell(cell, i, inlineParser)
                row.appendChild(tableCell)
            }

            if (body.isNone()) {
                // It's valid to have a table without body. In that case, don't add an empty TableBody node.
                body = TableBody()
                block.appendChild(body())
            }
            body().appendChild(row)
        }
    }

    private func parseCell(cell: String, column: Int64, inlineParser: InlineParser): TableCell {
        var tableCell: TableCell = TableCell()

        if (column < columns.size) {
            if (columns.get(column).getOrThrow().isSome()) {
                tableCell.setAlignment(columns.get(column).getOrThrow().getOrThrow())
            }
        }

        inlineParser.parse(cell.trimAscii(), tableCell)

        return tableCell
    }

    static func split(input: String): ArrayList<String> {
        var line: String = input.trimAscii()
        if (line.size > 0 && line[0] == b'|') {
            line = line[1..]
        }
        var cells: ArrayList<String> = ArrayList<String>()
        var sb: StringBuilder = StringBuilder()
        var i: Int64 = 0
        let arr = line
        while (i < arr.size) {
            let c = arr[i]
            match (c) {
                case '\\' =>
                    if (i + 1 < arr.size && arr[i + 1] == b'|') {
                        // Pipe is special for table parsing. An escaped pipe doesn't result in a new cell, but is
                        // passed down to inline parsing as an unescaped pipe. Note that that applies even for the `\|`
                        // in an input like `\\|` - in other words, table parsing doesn't support escaping backslashes.
                        sb.append('|')
                        i++
                    } else {
                        // Preserve backslash before other characters or at end of line.
                        sb.append('\\')
                    }
                case '|' =>
                    cells.add(sb.toString())
                    sb.reset()
                case _ =>
                    let (char, charSize) = Rune.fromUtf8(unsafe { line.rawData() }, i)
                    sb.append(char)
                    i += charSize
                    continue
            }
            i++
        }
        if (sb.size > 0) {
            cells.add(sb.toString())
        }
        return cells
    }

    // Examples of valid separators:
    //
    // |-
    // -|
    // |-|
    // -|-
    // |-|-|
    // --- | ---
    public static func parseSeparator(s: String): ?ArrayList<?Alignment> {
        var columns: ArrayList<?Alignment> = ArrayList<?Alignment>()
        var pipes: Int64 = 0
        var valid: Bool = false
        var i: Int64 = 0
        while (i < s.size) {
            let c = s[i]
            match (c) {
                case '|' =>
                    i++
                    pipes++
                    if (pipes > 1) {
                        // More than one adjacent pipe not allowed
                        return None
                    }
                    // Need at lest one pipe, even for a one column table
                    valid = true
                case '-' | ':' =>
                    if (pipes == 0 && !columns.isEmpty()) {
                        // Need a pipe after the first column (first column doesn't need to start with one)
                        return None
                    }
                    var left: Bool = false
                    var right: Bool = false
                    if (c == b':') {
                        left = true
                        i++
                    }
                    var haveDash: Bool = false
                    while (i < s.size && s[i] == b'-') {
                        i++
                        haveDash = true
                    }
                    if (!haveDash) {
                        // Need at least one dash
                        return None
                    }
                    if (i < s.size && s[i] == b':') {
                        right = true
                        i++
                    }
                    columns.add(getAlignment(left, right))
                    // Next, need another pipe
                    pipes = 0
                case ' ' | '\t' =>
                    // White space is allowed between pipes and columns
                    i++
                case _ =>
                    // Any other character is invalid
                    return None
            }
        }
        if (!valid) {
            return None
        }
        return columns
    }

    private static func getAlignment(left: Bool, right: Bool): ?Alignment {
        if (left && right) {
            return Alignment.CENTER
        } else if (left) {
            return Alignment.LEFT
        } else if (right) {
            return Alignment.RIGHT
        } else {
            return None
        }
    }
}

class tableBlockFactory <: AbstractBlockParserFactory {
    public func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): ?BlockStart {
        let line: String = state.getLine()
        let nextLine = state.getNextLine()
        let preLine = matchedBlockParser.getParagraphContent() ?? ""

        if (line.contains("|")) {
            if (nextLine.contains("|")) {
                let headLine: String = line[state.getIndex()..]
                let columnLine: String = nextLine[state.getIndex()..] // 考虑到列表中 每行前有固定缩进
                if (let Some(blockStart) <- col(headLine, columnLine, state, 0)) {
                    return blockStart
                }
            }
            if (!preLine.contains("\n") && preLine.contains("|")) {
                let headLine: String = preLine
                let columnLine: String = line[state.getIndex()..]
                return col(headLine, columnLine, state, 1)?.replaceActiveBlockParser()
            }
        }
        return BlockStart.none()
    }
    private func col(headLine: String, columnLine: String, state: ParserState, currentLineState: Int): ?BlockStart {
        let columns: ArrayList<?Alignment> = TableBlockParser.parseSeparator(columnLine) ?? return BlockStart.none()
        if (columns.size > 0) {
            let headerCells: ArrayList<String> = TableBlockParser.split(headLine)
            if (columns.size >= headerCells.size) {
                let parser = TableBlockParser(columns, headerCells)
                parser.lineState = currentLineState
                return BlockStart.of4Cj(parser).atIndex(state.getIndex())
            }
        }
        return BlockStart.none()
    }
}
