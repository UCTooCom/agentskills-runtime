/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.strikethrough

let StrikethroughType: NodeType = "Strikethrough"

public abstract class StrikethroughNodeRenderer <: NodeRenderer {
    public override func getNodeTypes(): HashSet<NodeType> {
        return HashSet<NodeType>([StrikethroughType])
    }
}

/**
 * A strikethrough node containing text and other inline nodes nodes as children.
 */
public class Strikethrough <: CustomNode & Delimited {
    private static let DELIMITER: String = "~~"

    public override func getOpeningDelimiter(): ?String {
        return DELIMITER
    }

    public override func getClosingDelimiter(): ?String {
        return DELIMITER
    }

    public override func getNodeType(): NodeType {
        return StrikethroughType
    }
}

class StrikethroughDelimiterProcessor <: DelimiterProcessor {
    public override func getOpeningCharacter(): Rune {
        return r'~'
    }

    public override func getClosingCharacter(): Rune {
        return r'~'
    }

    public override func getMinLength(): Int64 {
        return 2
    }

    public override func getDelimiterUse(opener: DelimiterRun, closer: DelimiterRun): Int64 {
        if (opener.getLength() >= 2 && closer.getLength() >= 2) {
            // Use exactly two delimiters even if we have more, and don't care about internal openers/closers.
            return 2
        } else {
            return 0
        }
    }

    public override func process(opener: Text, closer: Text, _: Int64): Unit {
        // Wrap nodes between delimiters in strikethrough.
        var strikethrough: Node = Strikethrough()

        var tmp: ?Node = opener.getNext()
        while (let Some(v) <- tmp && v != closer) {
            tmp = v.getNext()
            strikethrough.appendChild(v)
        }

        opener.insertAfter(strikethrough)
    }
}

class StrikethroughHtmlNodeRenderer <: StrikethroughNodeRenderer {
    private let context: HtmlNodeRendererContext
    private let html: HtmlWriter

    public init(context: HtmlNodeRendererContext) {
        this.context = context
        this.html = context.getWriter()
    }

    public override func render(node: Node): Unit {
        let attributes: HashMap<String, String> = context.extendAttributes(node, "del", HashMap<String, String>())
        html.tag("del", attributes)
        renderChildren(node)
        html.tag("/del")
    }

    private func renderChildren(parent: Node): Unit {
        var node: ?Node = parent.getFirstChild()
        while (let Some(v) <- node) {
            node = v.getNext()
            context.render(v)
        }
    }
}

class StrikethroughTextContentNodeRenderer <: StrikethroughNodeRenderer {
    private let context: TextContentNodeRendererContext
    private let textContent: TextContentWriter

    public init(context: TextContentNodeRendererContext) {
        this.context = context
        this.textContent = context.getWriter()
    }

    public override func render(node: Node): Unit {
        textContent.write("/")
        renderChildren(node)
        textContent.write("/")
    }

    private func renderChildren(parent: Node): Unit {
        var node: ?Node = parent.getFirstChild()
        while (let Some(v) <- node) {
            node = v.getNext()
            context.render(v)
        }
    }
}

public class StrikethroughExtension <: ParserExtension & HtmlRendererExtension & TextContentRendererExtension {
    private init() {}

    public static func create(): Extension {
        return StrikethroughExtension()
    }

    public override func ext(parserBuilder: ParserBuilder): Unit {
        parserBuilder.customDelimiterProcessor(StrikethroughDelimiterProcessor())
    }

    public override func ext(rendererBuilder: HtmlRendererBuilder): Unit {
        rendererBuilder.nodeRendererFactory({
            context => StrikethroughHtmlNodeRenderer(context)
        })
    }

    public override func ext(rendererBuilder: TextContentRendererBuilder): Unit {
        rendererBuilder.nodeRendererFactory({
            context => StrikethroughTextContentNodeRenderer(context)
        })
    }
}
