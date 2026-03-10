/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.table

let TableBlockType: NodeType = "TableBlock"
let TableBodyType: NodeType = "TableBody"
let TableCellType: NodeType = "TableCell"
let TableHeadType: NodeType = "TableHead"
let TableRowType: NodeType = "TableRow"

public abstract class TableNodeRenderer <: NodeRenderer {
    public override func getNodeTypes(): HashSet<NodeType> {
        return HashSet<NodeType>([TableBlockType, TableHeadType, TableBodyType, TableRowType, TableCellType])
    }

    public override func render(node: Node): Unit {
        if (node is TableBlock) {
            renderBlock((node as TableBlock)())
        } else if (node is TableHead) {
            renderHead((node as TableHead)())
        } else if (node is TableBody) {
            renderBody((node as TableBody)())
        } else if (node is TableRow) {
            renderRow((node as TableRow)())
        } else if (node is TableCell) {
            renderCell((node as TableCell)())
        }
    }

    protected func renderBlock(node: TableBlock): Unit

    protected func renderHead(node: TableHead): Unit

    protected func renderBody(node: TableBody): Unit

    protected func renderRow(node: TableRow): Unit

    protected func renderCell(node: TableCell): Unit
}

public class TableBlock <: CustomBlock {
    public override func getNodeType(): NodeType {
        return TableBlockType
    }
}

public class TableBody <: CustomNode {
    public override func getNodeType(): NodeType {
        return TableBodyType
    }
}

public class TableCell <: CustomNode {
    private var header: Bool = false
    private var alignment: ?Alignment = None

    /**
     * @return whether the cell is a header or not
     */
    public func isHeader(): Bool {
        return header
    }

    public func setHeader(header: Bool): Unit {
        this.header = header
    }

    /**
     * @return the cell alignment
     */
    public func getAlignment(): ?Alignment {
        return alignment
    }

    public func setAlignment(alignment: Alignment): Unit {
        this.alignment = alignment
    }
    public override func getNodeType(): NodeType {
        return TableCellType
    }
}

/**
 * How the cell is aligned horizontally.
 */
public enum Alignment {
    | LEFT
    | CENTER
    | RIGHT
}

public class TableHead <: CustomNode {
    public override func getNodeType(): NodeType {
        return TableHeadType
    }
}

public class TableRow <: CustomNode {
    public override func getNodeType(): NodeType {
        return TableRowType
    }
}

public class TablesExtension <: ParserExtension & HtmlRendererExtension & TextContentRendererExtension {
    private init() {
    }

    public static func create(): Extension {
        return TablesExtension()
    }

    public func ext(parserBuilder: ParserBuilder): Unit {
        parserBuilder.customBlockParserFactory(tableBlockFactory())
    }

    public func ext(rendererBuilder: HtmlRendererBuilder): Unit {
        rendererBuilder.nodeRendererFactory({
            context => TableHtmlNodeRenderer(context)
        })
    }

    public func ext(rendererBuilder: TextContentRendererBuilder): Unit {
        rendererBuilder.nodeRendererFactory({
            context => TableTextContentNodeRenderer(context)
        })
    }
}

class TableHtmlNodeRenderer <: TableNodeRenderer {
    private let context: HtmlNodeRendererContext
    private let htmlWriter: HtmlWriter

    public init(context: HtmlNodeRendererContext) {
        this.htmlWriter = context.getWriter()
        this.context = context
    }

    protected func renderBlock(tableBlock: TableBlock): Unit {
        htmlWriter.line()
        htmlWriter.tag("table", getAttributes(tableBlock, "table"))
        renderChildren(tableBlock)
        htmlWriter.tag("/table")
        htmlWriter.line()
    }

    protected func renderHead(tableHead: TableHead): Unit {
        htmlWriter.line()
        htmlWriter.tag("thead", getAttributes(tableHead, "thead"))
        renderChildren(tableHead)
        htmlWriter.tag("/thead")
        htmlWriter.line()
    }

    protected func renderBody(tableBody: TableBody): Unit {
        htmlWriter.line()
        htmlWriter.tag("tbody", getAttributes(tableBody, "tbody"))
        renderChildren(tableBody)
        htmlWriter.tag("/tbody")
        htmlWriter.line()
    }

    protected func renderRow(tableRow: TableRow): Unit {
        htmlWriter.line()
        htmlWriter.tag("tr", getAttributes(tableRow, "tr"))
        renderChildren(tableRow)
        htmlWriter.tag("/tr")
        htmlWriter.line()
    }

    protected func renderCell(tableCell: TableCell): Unit {
        var tagName: String = "td"
        if (tableCell.isHeader()) {
            tagName = "th"
        }
        htmlWriter.line()
        htmlWriter.tag(tagName, getCellAttributes(tableCell, tagName))
        renderChildren(tableCell)
        htmlWriter.tag("/" + tagName)
        htmlWriter.line()
    }

    private func getAttributes(node: Node, tagName: String): HashMap<String, String> {
        return context.extendAttributes(node, tagName, HashMap<String, String>())
    }

    private func getCellAttributes(tableCell: TableCell, tagName: String): HashMap<String, String> {
        if (tableCell.getAlignment().isSome()) {
            let singletonMap: HashMap<String, String> = HashMap<String, String>(
                [("align", getAlignValue(tableCell.getAlignment()()))])
            return context.extendAttributes(tableCell, tagName, singletonMap);
        } else {
            return context.extendAttributes(tableCell, tagName, HashMap<String, String>())
        }
    }

    private static func getAlignValue(alignment: Alignment): String {
        match (alignment) {
            case LEFT => return "left"
            case CENTER => return "center"
            case RIGHT => return "right"
        }
    }

    private func renderChildren(parent: Node): Unit {
        var node: ?Node = parent.getFirstChild()
        while (let Some(v) <- node) {
            var next: ?Node = v.getNext()
            context.render(node())
            node = next
        }
    }
}

class TableTextContentNodeRenderer <: TableNodeRenderer {
    private let context: TextContentNodeRendererContext
    private let textContentWriter: TextContentWriter

    public init(context: TextContentNodeRendererContext) {
        this.textContentWriter = context.getWriter()
        this.context = context
    }

    protected func renderBlock(tableBlock: TableBlock): Unit {
        renderChildren(tableBlock)
        if (tableBlock.getNext().isSome()) {
            textContentWriter.write("\n")
        }
    }

    protected func renderHead(tableHead: TableHead): Unit {
        renderChildren(tableHead)
    }

    protected func renderBody(tableBody: TableBody): Unit {
        renderChildren(tableBody)
    }

    protected func renderRow(tableRow: TableRow): Unit {
        textContentWriter.line()
        renderChildren(tableRow)
        textContentWriter.line()
    }

    protected func renderCell(tableCell: TableCell): Unit {
        renderChildren(tableCell)
        textContentWriter.write("|")
        textContentWriter.whitespace()
    }

    private func renderLastCell(tableCell: TableCell): Unit {
        renderChildren(tableCell)
    }

    private func renderChildren(parent: Node): Unit {
        var node: ?Node = parent.getFirstChild()
        while (node.isSome()) {
            var next: ?Node = node().getNext()

            // For last cell in row, we dont render the delimiter.
            if (node() is TableCell && next.isNone()) {
                renderLastCell((node() as TableCell).getOrThrow())
            } else {
                context.render((node()))
            }

            node = next
        }
    }
}
