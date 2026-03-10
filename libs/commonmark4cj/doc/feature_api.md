## commonMark4cj 库

### 介绍



### 1 Node

前置条件：NA 

场景：markdown解析得到的节点树，不同类型节点为不同的Node子类

约束：NA

可靠性：NA

#### 1.1 通用Node

##### 1.1.1 主要接口

```cangjie
/**
 * 通用节点
 */
public abstract class Node <: ToString & Equatable<Node> {
	
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public open func accept(visitor: Visitor): Unit
	
	/*
     * 获取下一个节点
     * 返回值 ?Node - Option Node 下一个节点
     */
    public func getNext(): ?Node

	/*
     * 获取上一个节点
     * 返回值 ?Node - Option Node 上一个节点
     */
    public func getPrevious(): ?Node
	
	/*
     * 获取第一个孩子节点
     * 返回值 ?Node - Option Node 第一个孩子节点
     */
    public func getFirstChild(): ?Node
    
	/*
     * 获取最后一个孩子节点
     * 返回值 ?Node - Option Node 最后一个孩子节点
     */
    public func getLastChild(): ?Node
	/*
     * 获取父节点
     * 返回值 ?Node - Option Node 父节点
     */
    public open func getParent(): ?Node
	/*
     * 末尾添加子节点
     * 参数 Node - 子节点
     */
    public func appendChild(child: Node): Unit
    /*
     * 开头添加子节点
     * 参数 Node - 子节点
     */
    public func prependChild(child: Node): Unit
    /*
     * 断开连接
     */
    public func unlink(): Unit
    
    /*
     * 后插入一个兄弟节点
     * 参数 Node - 兄弟节点
     */
    public func insertAfter(sibling: Node): Unit
    /*
     * 前插入一个兄弟节点
     * 参数 Node - 兄弟节点
     */
    public func insertBefore(sibling: Node): Unit
	/*
     * toString
     * 返回值 String - toString
     */
    public open func toString(): String
	/*
     * 重写 == 
     * 参数 Node - 比较Node
     * 返回值 Bool - 是否相等
     */
    public operator func ==(other: Node): Bool
	/*
     * 重写 != 
     * 参数 Node - 比较Node
     * 返回值 Bool - 是否相等
     */
    public operator func !=(other: Node): Bool
}

/**
 * 文本节点
 */
public class Text <: Node & Equatable<Text> {
    public init(literal: String): Unit
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
	/*
     * 获取文本
     * 返回值 String - 文本
     */
    public func getLiteral(): String
   	/*
     * 设置文本
     * 参数 String - 文本
     */
    public func setLiteral(literal: String): Unit
	/*
     * 重写 == 
     * 参数 Text - 比较Text
     * 返回值 Bool - 是否相等
     */
    public operator func ==(other: Text): Bool
	/*
     * 重写 != 
     * 参数 Text - 比较Text
     * 返回值 Bool - 是否相等
     */
    public operator func !=(other: Text): Bool
}

/**
 * HtmlInline节点
 */
public class HtmlInline <: Node {
    public init(literal: String): Unit
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
  	/*
     * 获取文本
     * 返回值 String - 文本
     */
    public func getLiteral(): String
   	/*
     * 设置文本
     * 参数 String - 文本
     */
    public func setLiteral(literal: String): Unit
}

/**
 * CustomNode节点
 */
public abstract class CustomNode <: Node {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
}
/**
 * 图片节点
 */
public class Image <: Node {
	/*
     * 初始化
     * 参数 String - 图片地址链接
     * 参数 ?String - 标题
     */
    public init(destination: String, title: ?String)
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
    /*
     * 获取地址链接
     * 返回值 String - 地址链接
     */
    public func getDestination(): String
	/*
     * 设置地址链接
     * 参数 String - 地址链接
     */
    public func setDestination(destination: String): Unit
    /*
     * 获取标题
     * 返回值 ?String - 标题
     */
    public func getTitle(): ?String
	/*
     * 设置标题
     * 参数 String - 标题
     */
    public func setTitle(title: String): Unit
}

/**
 * Code节点
 */
public class Code <: Node {
    public init(literal: String): Unit
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
	/*
     * 获取文本
     * 返回值 String - 文本
     */
    public func getLiteral(): String
   	/*
     * 设置文本
     * 参数 String - 文本
     */
    public func setLiteral(literal: String): Unit
}

/**
 * HardLineBreak节点
 */
public class HardLineBreak <: Node {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
}

/**
 * SoftLineBreak节点
 */
public class SoftLineBreak <: Node {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
}

/**
 * LinkReferenceDefinition节点
 */
public class LinkReferenceDefinition <: Node {
	/*
     * 初始化
     */
    public init()
	/*
     * 添加操作行为
     * 参数 String - 链接引用的标签
     * 参数 String - 目标地址
     * 参数 String - 标题
     */
    public init(label: String, destination: String, title: String)
	/*
     * 获取链接引用的标签
     * 返回值 ?String - 链接引用的标签
     */
    public func getLabel(): ?String
	/*
     * 设置链接引用的标签
     * 参数 String - 链接引用的标签
     */
    public func setLabel(label: String): Unit
    /*
     * 获取目标地址
     * 返回值 String - 目标地址
     */
    public func getDestination(): String
	/*
     * 设置目标地址
     * 参数 String - 目标地址
     */
    public func setDestination(destination: String): Unit
    /*
     * 获取标题
     * 返回值 ?String - 标题
     */
    public func getTitle(): ?String
	/*
     * 设置标题
     * 参数 String - 标题
     */
    public func setTitle(title: String): Unit
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
}

/**
 * Link节点
 */
public class Link <: Node {
    public init(destination: String, title: ?String)
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
    /*
     * 获取目标地址
     * 返回值 String - 目标地址
     */
    public func getDestination(): String
	/*
     * 设置目标地址
     * 参数 String - 目标地址
     */
    public func setDestination(destination: String): Unit
    /*
     * 获取标题
     * 返回值 ?String - 标题
     */
    public func getTitle(): ?String
	/*
     * 设置标题
     * 参数 String - 标题
     */
    public func setTitle(title: String): Unit

}

/**
 * 分隔符接口
 */
public interface Delimited {
    /*
     * 获取开头分隔符
     * 返回值 ?String - 标题
     */
    func getOpeningDelimiter(): ?String
    /*
     * 获取结尾分隔符
     * 返回值 ?String - 标题
     */
    func getClosingDelimiter(): ?String
}

/**
 * StrongEmphasis节点
 */
public class StrongEmphasis <: Node & Delimited {
	/*
     * 初始化
     */
    public init(): Unit
	/*
     * 初始化
     * 参数 String - 分隔符
     */
    public init(delimiter: String): Unit
	/*
     * 设置分隔符
     * 参数 String - 分隔符
     */
    public func setDelimiter(delimiter: String): Unit
    /*
     * 获取开头分隔符
     * 返回值 ?String - 标题
     */
    public func getOpeningDelimiter(): ?String
    /*
     * 获取结尾分隔符
     * 返回值 ?String - 标题
     */
    public func getClosingDelimiter(): ?String
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
}

public class Emphasis <: Node & Delimited {
	/*
     * 初始化
     */
    public init()
	/*
     * 初始化
     * 参数 String - 分隔符
     */
    public init(delimiter: String)
	/*
     * 设置分隔符
     * 参数 String - 分隔符
     */
    public func setDelimiter(delimiter: String): Unit
    /*
     * 获取开头分隔符
     * 返回值 ?String - 标题
     */
    public func getOpeningDelimiter(): ?String
    /*
     * 获取结尾分隔符
     * 返回值 ?String - 标题
     */
    public func getClosingDelimiter(): ?String
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public override func accept(visitor: Visitor): Unit
}
```

##### 1.1.2 示例

```cangjie
    import commonmark4cj.commonmark.*

    @TestCase
    func linkReferenceDefinitionTest(): Unit {
        var text: LinkReferenceDefinition = LinkReferenceDefinition()
        assertEquals(None, text.getLabel())
        text = LinkReferenceDefinition("foo", "/url", "title")
        assertEquals("foo", text.getLabel())
        assertEquals("/url", text.getDestination())
        assertEquals("title", text.getTitle())

        text.setLabel("bar")
        text.setDestination("/path")
        text.setTitle("titles")

        assertEquals("bar", text.getLabel())
        assertEquals("/path", text.getDestination())
        assertEquals("titles", text.getTitle())
    }
```

#### 1.2 Block系列节点

##### 1.2.1 主要接口

```cangjie
public abstract class Block <: Node {
	/*
     * 获取父节点
     * 返回值 ?Node - Option Node 父节点
     */
    public func getParent(): ?Node
	/*
     * 设置父节点
     * 参数 Node - 父节点
     */
    protected override func setParent(parent: Node): Unit
}

public class BlockQuote <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
}

public class HtmlBlock <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
	/*
     * 获取文本
     * 返回值 String - 文本
     */
    public func getLiteral(): String
   	/*
     * 设置文本
     * 参数 String - 文本
     */
    public func setLiteral(literal: String): Unit
}

public abstract class CustomBlock <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
}

public class ThematicBreak <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
}

public class Document <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
}

public class Paragraph <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
}

public class IndentedCodeBlock <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
	/*
     * 获取文本
     * 返回值 String - 文本
     */
    public func getLiteral(): String
   	/*
     * 设置文本
     * 参数 String - 文本
     */
    public func setLiteral(literal: String): Unit
}

public class FencedCodeBlock <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
	/*
     * 获取围栏字符 默认`
     * 返回值 Rune - 围栏字符
     */
    public func getFenceChar(): Rune
   	/*
     * 设置围栏字符
     * 参数 Rune - 围栏字符
     */
    public func setFenceChar(fenceChar: Rune): Unit
	/*
     * 获取围栏代码块长度 至少3
     * 返回值 Int64 - 围栏代码块长度
     */
    public func getFenceLength(): Int64
   	/*
     * 设置围栏代码块长度
     * 参数 Int64 - 围栏代码块长度
     */
    public func setFenceLength(fenceLength: Int64): Unit
	/*
     * 获取围栏与代码块的缩进量
     * 返回值 Int64 - 围栏与代码块的缩进量
     */
    public func getFenceIndent(): Int64
   	/*
     * 设置围栏与代码块的缩进量
     * 参数 Int64 - 围栏与代码块的缩进量
     */
    public func setFenceIndent(fenceIndent: Int64): Unit
	/*
     * 获取语言标识符
     * 返回值 String - 语言标识符
     */
    public func getInfo(): String
   	/*
     * 设置语言标识符
     * 参数 String - 语言标识符
     */
    public func setInfo(info: String): Unit
	/*
     * 获取文本
     * 返回值 String - 文本
     */
    public func getLiteral(): String
   	/*
     * 设置文本
     * 参数 String - 文本
     */
    public func setLiteral(literal: String): Unit
}

public class ListItem <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
}

public class Heading <: Block {
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
	/*
     * 获取标题级别
     * 返回值 Int64 - 标题级别
     */
    public func getLevel(): Int64
   	/*
     * 设置标题级别
     * 参数 Int64 - 标题级别
     */
    public func setLevel(level: Int64): Unit
}
/**
 * 列表块节点
 */
public abstract class ListBlock <: Block {
	/*
     * 获取表块是不是紧凑的
     * 返回值 Bool - 列表块是不是紧凑的
     */
    public func isTight(): Bool
   	/*
     * 设置列表块是不是紧凑的
     * 参数 Bool - 列表块是不是紧凑的
     */
    public func setTight(tight: Bool)
}
/**
 * 无序列表块节点
 */
public class BulletList <: ListBlock {
   	/*
     * 初始化
     * 参数 Rune - 标记
     */
    public init(bulletMarker: Rune): Unit
  	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
		
	/*
     * 获取标记
     * 返回值 Rune - 标记
     */
    public func getBulletMarker(): Rune
   	/*
     * 设置标记
     * 参数 Rune - 标记
     */
    public func setBulletMarker(bulletMarker: Rune): Unit
}
/**
 * 有序列表块节点
 */
public class OrderedList <: ListBlock {
   	/*
     * 初始化
     * 参数 Int64 - 起始数字
     * 参数 Rune - 分隔符
     */
    public init(startNumber: Int64, delimiter: Rune)
	/*
     * 添加操作行为
     * 参数 Visitor - 具体的操作行为
     */
    public func accept(visitor: Visitor): Unit
	/*
     * 获取起始数字
     * 返回值 Int64 - 起始数字
     */
    public func getStartNumber(): Int64
   	/*
     * 设置起始数字
     * 参数 Int64 - 起始数字
     */
    public func setStartNumber(startNumber: Int64): Unit
	/*
     * 获取分隔符
     * 返回值 Rune - 分隔符
     */
    public func getDelimiter(): Rune
   	/*
     * 设置分隔符
     * 参数 Rune - 分隔符
     */
    public func setDelimiter(delimiter: Rune): Unit
}
```

##### 1.2.2 示例

```cangjie
    import commonmark4cj.commonmark.*
    
    @TestCase
    func documentTest(): Unit {
        var document: Document = Document ()
        var paragraph = Paragraph()
        var blockQuote = BlockQuote()
        var htmlBlock = HtmlBlock()
        var thematicBreak = ThematicBreak()
        var indentedCodeBlock = IndentedCodeBlock()
        var text = Text("text")

        document.appendChild(paragraph)
        document.appendChild(blockQuote)
        document.appendChild(htmlBlock)
        document.appendChild(thematicBreak)
        document.appendChild(indentedCodeBlock)
        document.appendChild(text)
        assertEquals("Document{}", blockQuote.getParent()().toString())
        assertEquals(None, document.getParent())

        htmlBlock.setLiteral("p1")
        assertEquals("p1", htmlBlock.getLiteral())

        assertEquals("HtmlBlock{}", thematicBreak.getPrevious()().toString())

        htmlBlock.insertBefore(Text("foo"))
        assertEquals("Text{literal=foo}", htmlBlock.getPrevious()().toString())

        assertEquals(true, paragraph != htmlBlock)
    }
```

#### 

#### 1.3 Visitor系列节点

##### 1.3.1 主要接口

```cangjie
public interface Visitor {
    func visit(blockQuote: BlockQuote): Unit

    func visit(bulletList: BulletList): Unit

    func visit(code: Code): Unit

    func visit(document: Document): Unit

    func visit(emphasis: Emphasis): Unit

    func visit(fencedCodeBlock: FencedCodeBlock): Unit

    func visit(hardLineBreak: HardLineBreak): Unit

    func visit(heading: Heading): Unit

    func visit(thematicBreak: ThematicBreak): Unit

    func visit(htmlInline: HtmlInline): Unit

    func visit(htmlBlock: HtmlBlock): Unit

    func visit(image: Image): Unit

    func visit(indentedCodeBlock: IndentedCodeBlock): Unit

    func visit(link: Link): Unit

    func visit(listItem: ListItem): Unit

    func visit(orderedList: OrderedList): Unit

    func visit(paragraph: Paragraph): Unit

    func visit(softLineBreak: SoftLineBreak): Unit

    func visit(strongEmphasis: StrongEmphasis): Unit

    func visit(text: Text): Unit

    func visit(linkReferenceDefinition: LinkReferenceDefinition): Unit

    func visit(customBlock: CustomBlock): Unit

    func visit(customNode: CustomNode): Unit
}

public abstract class AbstractVisitor <: Visitor {
	/*
     * 处理渲染BlockQuote节点的行为
     * 参数 BlockQuote - BlockQuote节点
     */
    public open func visit(blockQuote: BlockQuote): Unit
	/*
     * 处理渲染BulletList节点的行为
     * 参数 BulletList - BulletList节点
     */
    public open func visit(bulletList: BulletList): Unit
  	/*
     * 处理渲染Code节点的行为
     * 参数 Code - Code节点
     */
    public open func visit(code: Code): Unit
	/*
     * 处理渲染Document节点的行为
     * 参数 Document - Document节点
     */
    public open func visit(document: Document): Unit
	/*
     * 处理渲染Emphasis节点的行为
     * 参数 Emphasis - Emphasis节点
     */
    public open func visit(emphasis: Emphasis): Unit
	/*
     * 处理渲染FencedCodeBlock节点的行为
     * 参数 FencedCodeBlock - FencedCodeBlock节点
     */
    public open func visit(fencedCodeBlock: FencedCodeBlock): Unit
	/*
     * 处理渲染HardLineBreak节点的行为
     * 参数 HardLineBreak - HardLineBreak节点
     */
    public open func visit(hardLineBreak: HardLineBreak): Unit
  	/*
     * 处理渲染Heading节点的行为
     * 参数 Heading - Heading节点
     */
    public open func visit(heading: Heading): Unit
	/*
     * 处理渲染ThematicBreak节点的行为
     * 参数 ThematicBreak - ThematicBreak节点
     */
    public open func visit(thematicBreak: ThematicBreak): Unit
  	/*
     * 处理渲染HtmlInline节点的行为
     * 参数 HtmlInline - HtmlInline节点
     */
    public open func visit(htmlInline: HtmlInline): Unit
	/*
     * 处理渲染HtmlBlock节点的行为
     * 参数 HtmlBlock - HtmlBlock节点
     */
    public open func visit(htmlBlock: HtmlBlock): Unit
	/*
     * 处理渲染Image节点的行为
     * 参数 Image - Image节点
     */
    public open func visit(image: Image): Unit
	/*
     * 处理渲染IndentedCodeBlock节点的行为
     * 参数 IndentedCodeBlock - IndentedCodeBlock节点
     */
    public open func visit(indentedCodeBlock: IndentedCodeBlock): Unit
	/*
     * 处理渲染Link节点的行为
     * 参数 Link - Link节点
     */
    public open func visit(link: Link): Unit
	/*
     * 处理渲染ListItem节点的行为
     * 参数 ListItem - ListItem节点
     */
    public open func visit(listItem: ListItem): Unit
	/*
     * 处理渲染OrderedList节点的行为
     * 参数 OrderedList - OrderedList节点
     */
    public open func visit(orderedList: OrderedList): Unit
  	/*
     * 处理渲染Paragraph节点的行为
     * 参数 Paragraph - Paragraph节点
     */
    public open func visit(paragraph: Paragraph): Unit
	/*
     * 处理渲染SoftLineBreak节点的行为
     * 参数 SoftLineBreak - SoftLineBreak节点
     */
    public open func visit(softLineBreak: SoftLineBreak): Unit
	/*
     * 处理渲染StrongEmphasis节点的行为
     * 参数 StrongEmphasis - StrongEmphasis节点
     */
    public open func visit(strongEmphasis: StrongEmphasis): Unit
  	/*
     * 处理渲染Text节点的行为
     * 参数 Text - Text节点
     */
    public open func visit(text: Text): Unit
	/*
     * 处理渲染LinkReferenceDefinition节点的行为
     * 参数 LinkReferenceDefinition - LinkReferenceDefinition节点
     */
    public open func visit(linkReferenceDefinition: LinkReferenceDefinition): Unit
	/*
     * 处理渲染CustomBlock节点的行为
     * 参数 CustomBlock - CustomBlock节点
     */
    public open func visit(customBlock: CustomBlock): Unit
	/*
     * 处理渲染CustomNode节点的行为
     * 参数 CustomNode - CustomNode节点
     */
    public open func visit(customNode: CustomNode): Unit
}
```

##### 1.3.2 示例

```cangjie
    import commonmark4cj.commonmark.*

    @TestCase
    func test_Text_accept():Unit {
        var text = Text("aa")
        text.appendChild(Text("bb"))
        text.accept(AbstractVisitorImpl())
        @Assert(text.getLiteral(),"aa")
        let firstChild = text.getFirstChild().getOrThrow()
        @Assert((firstChild as Text).getOrThrow().getLiteral(),"bb")
        let lastChild = text.getLastChild().getOrThrow()
        @Assert((lastChild as Text).getOrThrow().getLiteral(),"cc")
    }
   
    class AbstractVisitorImpl <: AbstractVisitor {
        public func visit(text: Text): Unit {
            text.appendChild(Text("cc"))
        }
    }
```

### 2 Parse

前置条件：NA 

场景：markdown解析得到的节点树，不同类型节点为不同的Node子类

约束：NA

可靠性：NA

#### 2.1 Parser

##### 2.1.1 主要接口

```cangjie
public class Parser {
	/*
     * 获取ParserBuilder对象
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public static func builder(): ParserBuilder

	/*
     * 解析文本 生成Node
     * 参数 String - 文本
     * 返回值 Node - Node对象
     */
    public func parse(input: String): Node
    
	/*
     * 解析流 生成Node
     * 参数 StringReader<InputStream> - 流
     * 返回值 Node - Node对象
     */
    public func parseReader(input: StringReader<InputStream>): Node
}

public class ParserBuilder {

	/*
     * 构建parse对象
     * 返回值 Parser - Parser对象
     */
    public func build(): Parser

	/*
     * 获取那七个block相关node对象象集合
     * 返回值 HashSet<String> - 那七个block相关Node的对象集合
     */
    public func getEnabledBlockTypes(): HashSet<String>

	/*
     * 作为插件 拓展解析器 参考table
     * 参数 Iterable<T> - 拓展的解析器集合 
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public func extensions<T>(extensions: Iterable<T>): ParserBuilder where T <: Extension

	/*
     * 更新支持解析的Node对象集合
     * 参数 HashSet<String> - 支持解析的Node对象集合
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public func enabledBlockTypes(enabledBlockTypes: HashSet<String>): ParserBuilder

	/*
     * 增加用户新增的解析工厂类
     * 参数 BlockParserFactory - 解析工厂类
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public func customBlockParserFactory(blockParserFactory: BlockParserFactory): ParserBuilder

	/*
     * 增加用户新增的分隔符处理器
     * 参数 DelimiterProcessor - DelimiterProcessor
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public func customDelimiterProcessor(delimiterProcessor: DelimiterProcessor): ParserBuilder
    
	/*
     * 增加用户新增的PostProcessor处理器
     * 参数 PostProcessor - PostProcessor
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public func postProcessor(postProcessor: PostProcessor): ParserBuilder

	/*
     * 实现InlineParser接口 用户自定义行内解析
     * 参数 InlineParserFactory - 用户覆盖的InlineParserFactory子类
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public func inlineParserFactory(inlineParserFactory: InlineParserFactory): ParserBuilder

	/*
     * 获取InlineParserFactory 没有定义就生成默认的InlineParserImpl类
     * 返回值 ParserBuilder - ParserBuilder对象
     */
    public func getInlineParserFactory(): InlineParserFactory
}

public interface ParserExtension <: Extension {
	/*
     * 插件拓展 生成拓展的插件
     * 参数 ParserBuilder - ParserBuilder
     */
    func ext(parserBuilder: ParserBuilder): Unit
}

public interface PostProcessor {
	/*
     * 解析Node
     * 参数 Node - Node
     * 返回值 Node - Node
     */
    func process(node: Node): Node
}

```

##### 2.1.2 示例

```cangjie
    import commonmark4cj.commonmark.*

    @TestCase
    func parse_test():Unit {
        let given: String = "# heading 1\n\nnot a heading"
        var parser: Parser = Parser.builder().build()
        var document: Node = parser.parse(given)
        assertEquals("Heading{}", document.getFirstChild()().toString())
    }
```

#### 2.2 BlockParser

##### 2.2.1 主要接口

```cangjie
public interface BlockParser {
	/*
     * 是否可以包含其他块级元素
     * 返回值 Bool - Bool
     */
    func isContainer(): Bool
	/*
     * 是否可以懒惰的换行
     * 返回值 Bool - Bool
     */
    func canHaveLazyContinuationLines(): Bool
    
	/*
     * 是否可以包含这个Block对象
     * 参数 Block - Block对象
     * 返回值 Bool - Bool
     */
    func canContain(childBlock: Block): Bool

	/*
     * 获取Block对象
     * 返回值 Block - block对象
     */
    func getBlock(): Block

	/*
     * 获取跨行元素对象 如果存在
     * 参数 ParserState - ParserState对象
     * 返回值 Option<BlockContinue> - BlockContinue
     */
    func tryContinue(parserState: ParserState): Option<BlockContinue>
    
	/*
     * 添加一行
     * 参数 CharSequence - CharSequence
     */
    func addLine(line: CharSequence): Unit

	/*
     * 关闭块对象
     */
    func closeBlock(): Unit

	/*
     * 使用InlineParser解析文本
     * 参数 InlineParser - InlineParser对象
     */
    func parseInlines(inlineParser: InlineParser): Unit
}

public abstract class AbstractBlockParser <: BlockParser {
	/*
     * 是否可以包含其他块级元素
     * 返回值 Bool - false
     */
    public open func isContainer(): Bool

	/*
     * 是否可以懒惰的换行
     * 返回值 Bool - false
     */
    public open func canHaveLazyContinuationLines(): Bool

	/*
     * 是否可以包含这个Block对象
     * 参数 Block - Block对象
     * 返回值 Bool - false
     */
    public open func canContain(_: Block): Bool

	/*
     * 添加一行
     * 参数 CharSequence - CharSequence
     */
    public open func addLine(_: CharSequence): Unit

	/*
     * 关闭块对象
     */
    public open func closeBlock(): Unit

	/*
     * 使用InlineParser解析文本
     * 参数 InlineParser - InlineParser对象
     */
    public open func parseInlines(_: InlineParser): Unit
}

public open class BlockContinue {

	/*
     * 清空BlockContinue对象
     * 返回值 InlineParser - Option<BlockContinue>.None
     */
    public static func none(): Option<BlockContinue>

	/*
     * 设置跨行的元素起始下标
     * 参数 Int64 - 起始下标
     * 返回值 BlockContinue - 构建跨行元素实现类
     */
    public static func atIndex(newIndex: Int64): BlockContinue

	/*
     * 设置跨行的元素起始下标
     * 参数 Int64 - 起始下标
     * 返回值 BlockContinue - 构建跨行元素实现类
     */
    public static func atColumn(newColumn: Int64): BlockContinue

	/*
     * 结束跨行
     * 返回值 BlockContinue - 构建跨行元素实现类
     */
    public static func finished(): BlockContinue
}

public interface BlockParserFactory {

	/*
     * 初始化一个特定的 BlockParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart>
}

public abstract class AbstractBlockParserFactory <: BlockParserFactory {}

public abstract class BlockStart {
	/*
     * 生成一个 Option<BlockStart>.None实例
     * 返回值 Option<BlockStart> - Option<BlockStart>.None
     */
    public static func none(): Option<BlockStart>

	/*
     * 生成默认的BlockStart实现类
     * 参数 Array<AbstractBlockParser> - 解析类数组
     * 返回值 BlockStart - BlockStart实现类
     */
    public static func of4Cj(blockParsers: Array<AbstractBlockParser>): BlockStart

	/*
     * 指定下标
     * 参数 Int64 - index
     * 返回值 BlockStart - BlockStart实现类
     */
    public func atIndex(newIndex: Int64): BlockStart

	/*
     * 指定下标
     * 参数 Int64 - column
     * 返回值 BlockStart - BlockStart实现类
     */
    public func atColumn(newColumn: Int64): BlockStart

	/*
     * 是否可替换当前解析类
     * 返回值 BlockStart - BlockStart实现类
     */
    public func replaceActiveBlockParser(): BlockStart
}

public interface MatchedBlockParser {
	/*
     * 获取匹配到的解析类
     * 返回值 AbstractBlockParser - 解析类
     */
    func getMatchedBlockParser(): AbstractBlockParser

	/*
     * 获取段落文本 如果匹配的是段落Node
     * 返回值 ?String - 段落文本
     */
    func getParagraphContent(): ?String
}


public interface ParserState {
	/*
     * 获取当前行内容
     * 返回值 CharSequence - 内容
     */
    func getLine(): CharSequence
    
	/*
     * 获取下标
     * 返回值 Int64 - 下标
     */
    func getIndex(): Int64

	/*
     * 获取下一个没有空格的下标
     * 返回值 Int64 - 下标
     */
    func getNextNonSpaceIndex(): Int64

	/*
     * 获取下标
     * 返回值 Int64 - 下标
     */
    func getColumn(): Int64

	/*
     * 获取缩进级别
     * 返回值 Int64 - 缩进级别
     */
    func getIndent(): Int64

	/*
     * 是否是空行
     * 返回值 Bool - 是否是空行
     */
    func isBlank(): Bool

	/*
     * 获取最底层的块块解析对象
     * 返回值 AbstractBlockParser - 最底层的块块解析对象
     */
    func getActiveBlockParser(): AbstractBlockParser
}

public class BlockQuoteParserFactory <: BlockParserFactory {
	/*
     * 初始化一个特定的 BlockParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart>
}

public class FencedCodeBlockParserFactory <: BlockParserFactory {
	/*
     * 初始化一个特定的 FencedCodeBlockParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart>
}

public class HeadingParserFactory <: BlockParserFactory {
	/*
     * 初始化一个特定的 HeadingParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    public func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart>
}

public class HtmlBlockParserFactory <: BlockParserFactory {
	/*
     * 初始化一个特定的 HtmlBlockParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    public func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart> 
}

public class IndentedCodeBlockParserFactory <: BlockParserFactory {
	/*
     * 初始化一个特定的 IndentedCodeBlockParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart>
}

public class LinkReferenceDefinitionParser {
	/*
     * 解析当前的文本行
     * 参数 CharSequence - 文本
     */
    public func parse(line: CharSequence): Unit

    /*
     * 获取State对象
     * 返回值 State - State对象
     */
    public func getState(): State
}

public enum State {
    | START_DEFINITION

    | LABEL

    | DESTINATION

    | START_TITLE

    | TITLE

    | PARAGRAPH
}

public class ListBlockParserFactory <: BlockParserFactory {
	/*
     * 初始化一个特定的 ListBlockParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    public func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): Option<BlockStart> 
}

public class ThematicBreakParserFactory <: BlockParserFactory {
	/*
     * 初始化一个特定的 ThematicBreakParser 实例来解析当前的文本行
     * 参数 ParserState - ParserState 对象
     * 参数 MatchedBlockParser - MatchedBlockParser 对象
     * 返回值 Option<BlockStart> - BlockStart
     */
    public func tryStart(state: ParserState, _: MatchedBlockParser): Option<BlockStart>
}
```

##### 2.2.2 示例

```cangjie
import commonmark4cj.commonmark.*

main(): Int64 {
    let parser: Parser = Parser.builder().customBlockParserFactory(DashBlockParserFactory()).build()

    let document: Node = parser.parse("hey\n\n---\n")

    println(document.getFirstChild().getOrThrow().toString())
    println((document.getFirstChild().getOrThrow().getFirstChild().getOrThrow() as Text).getOrThrow().getLiteral())
    println(document.getLastChild().getOrThrow().toString())

    return 0
}

class DashBlockParserFactory <: AbstractBlockParserFactory {

    public override func tryStart(state: ParserState, matchedBlockParser: MatchedBlockParser): ?BlockStart {
        if (state.getLine() == ("---")) {
            return BlockStart.of4Cj(DashBlockParser())
        }
        return BlockStart.none()
    }
}

class DashBlock <: CustomBlock {
    public func getNodeType(): NodeType {
        "DashBlock"
    }
}

class DashBlockParser <: AbstractBlockParser {

    private var dash: DashBlock = DashBlock()

    public override func getBlock(): Block {
        return dash
    }

    public override func tryContinue(parserState: ParserState): ?BlockContinue {
        return BlockContinue.none()
    }
}
```

#### 2.3 InlineParser

##### 2.3.1 主要接口

```cangjie
public interface InlineParser {
	/*
     * 解析行内元素
     * 参数 String - 文本
     * 返回值 Node - 与生成的Node互为父子节点
     */
    func parse(input: String, node: Node): Unit
}

public interface InlineParserContext {
	/*
     * 获取用户自定义的分割符处理器
     * 返回值 ArrayList<DelimiterProcessor> - ArrayList<DelimiterProcessor>
     */
    func getCustomDelimiterProcessors(): ArrayList<DelimiterProcessor>
    
	/*
     * 根据名字获取对应的链接引用
     * 参数 String - 名字
     * 返回值 ?LinkReferenceDefinition - ?LinkReferenceDefinition
     */
    func getLinkReferenceDefinition(label: String): ?LinkReferenceDefinition
}

public interface InlineParserFactory {
	/*
     * 构建InlineParser行内解析器实例
     * 参数 InlineParserContext - InlineParserContext
     * 返回值 InlineParser - InlineParser对象
     */
    func create(inlineParserContext: InlineParserContext): InlineParser
}

public interface DelimiterProcessor {
	/*
     * 获取开始分隔符
     * 返回值 Rune - 开始分隔符
     */
    func getOpeningCharacter(): Rune

	/*
     * 获取结束分隔符
     * 返回值 Rune - 结束分隔符
     */
    func getClosingCharacter(): Rune

	/*
     * 获取最小长度 为1
     * 返回值 Int64
     */
    func getMinLength(): Int64

	/*
     * 获取多少分隔符可以被使用
     * 参数 DelimiterRun - 开始 DelimiterRun(连续分隔符序列)
     * 参数 DelimiterRun - 结束DelimiterRun(连续分隔符序列)
     * 返回值 Int64 - 个数
     */
    func getDelimiterUse(opener: DelimiterRun, closer: DelimiterRun): Int64

	/*
     * 处理行内元素
     * 参数 Text - 开始文本
     * 参数 Text - 结束文本
     * 参数 Int64 - 可以用的分隔符数量 决定是Emphasis还是StrongEmphasis 的 Node
     */
    func process(opener: Text, closer: Text, delimiterUse: Int64): Unit
}

public abstract class EmphasisDelimiterProcessor <: DelimiterProcessor {
	/*
     * 获取开始分隔符
     * 返回值 Rune - 开始分隔符
     */
    public override func getOpeningCharacter(): Rune

	/*
     * 获取结束分隔符
     * 返回值 Rune - 结束分隔符
     */
    public override func getClosingCharacter(): Rune

	/*
     * 获取最小长度 为1
     * 返回值 Int64 - 最小长度 为1
     */
    public override func getMinLength(): Int64

	/*
     * 获取多少分隔符可以被使用
     * 参数 DelimiterRun - 开始 DelimiterRun(连续分隔符序列)
     * 参数 DelimiterRun - 结束DelimiterRun(连续分隔符序列)
     * 返回值 Int64 - 个数
     */
    public override func getDelimiterUse(opener: DelimiterRun, closer: DelimiterRun): Int64 

	/*
     * 处理行内元素
     * 参数 Text - 开始文本
     * 参数 Text - 结束文本
     * 参数 Int64 - 可以用的分隔符数量 决定是Emphasis还是StrongEmphasis 的 Node 
     */
    public override func process(opener: Text, closer: Text, delimiterUse: Int64): Unit
}

public interface DelimiterRun {
	/*
     * 是否可以开启一个新的分隔符
     * 返回值 Bool - 是否可以打开
     */
    func canOpen(): Bool

	/*
     * 是否可以关闭分隔符
     * 返回值 Bool - 是否可以关闭
     */
    func canClose(): Bool

	/*
     * 序列长度
     * 返回值 Bool - 是否可以关闭
     */
    func getLength(): Int64
    
	/*
     * 序列原始长度
     * 返回值 Bool - 是否可以关闭
     */
    func getOriginalLength(): Int64
}
```

##### 2.3.2 示例

```cangjie
    import commonmark4cj.commonmark.*

    @TestCase
    public func inlineParser(): Unit {
        let parser: Parser = Parser.builder().inlineParserFactory(fakeInlineParserFactory()).build()
        let input: String = "**bold** **bold** ~~strikethrough~~"

        assertEquals(parser.parse(input).getFirstChild()().getFirstChild()().toString(), "ThematicBreak{}")
    }
class fakeInlineParser <: InlineParser {
    public override func parse(input: String, node: Node): Unit {
        node.appendChild(ThematicBreak())
    }
}

class fakeInlineParserFactory <: InlineParserFactory {

    public override func create(inlineParserContext: InlineParserContext): InlineParser {
        return fakeInlineParser()
    }
}
```

#### 2.4 Strikethrough

##### 2.4.1 主要接口

```cangjie
public abstract class StrikethroughNodeRenderer <: NodeRenderer {
	/*
     * 获取删除线类型
     * 返回值 HashSet<String> - 删除线类型
     */
    public override func getNodeTypes(): HashSet<String>
}

public class Strikethrough <: CustomNode & Delimited {
	/*
     * 获取起始分隔符
     * 返回值 ?String> - 起始分隔符
     */
	public override func getOpeningDelimiter(): ?String

	/*
     * 获取结束分隔符
     * 返回值 ?String> - 结束分隔符
     */
    public override func getClosingDelimiter(): ?String
}

public class StrikethroughExtension <: ParserExtension & HtmlRendererExtension & TextContentRendererExtension {

	/*
     * 拓展插件
     * 返回值 Extension - Extension
     */
    public static func create(): Extension
    
	/*
     * 插件拓展 
     * 参数 ParserBuilder - ParserBuilder
     */
    public override func ext(parserBuilder: ParserBuilder): Unit
	/*
     * 插件拓展 
     * 参数 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public override func ext(rendererBuilder: HtmlRendererBuilder): Unit
    
	/*
     * 插件拓展 
     * 参数 TextContentRendererBuilder - TextContentRendererBuilder
     */
    public override func ext(rendererBuilder: TextContentRendererBuilder): Unit
}
```

##### 2.4.2 示例

```cangjie
import commonmark4cj.commonmark.*

@TestCase
public class StrikethroughTest {
    private static let EXTENSIONS: Iterable<Extension> = ArrayList<Extension>(StrikethroughExtension.create())
    private static let PARSER: Parser = Parser.builder().extensions(EXTENSIONS).build()
    private static let HTML_RENDERER: HtmlRenderer = HtmlRenderer.builder().extensions(EXTENSIONS).build()
    private static let CONTENT_RENDERER: TextContentRenderer  = TextContentRenderer.builder()
            .extensions(EXTENSIONS).build()

    @TestCase
    public func oneTildeIsNotEnough(): Unit {
        assertRendering("~foo~", "<p>~foo~</p>\n")
    }

    func render(source: String): String {
        return HTML_RENDERER.render(PARSER.parse(source))
    }

    func assertRendering(source: String, expectedResult: String): Unit {
        let renderedContent: String = render(source)
        let expected: String = showTabs(expectedResult + "\n\n" + source)
        let actual: String = showTabs(renderedContent + "\n\n" + source)
        assertEquals(expected, actual)
    }

    func showTabs(s: String): String {
        return s.replace("\t", "\u{2192}")
    }
}
```

#### 2.5 Table

##### 2.5.1 主要接口

```cangjie
public abstract class TableNodeRenderer <: NodeRenderer {
	/*
     * 获取表格类型
     * 返回值 HashSet<String> - 表格类型
     */
    public override func getNodeTypes(): HashSet<String>

	/*
     * 渲染
     * 参数 Node - Node
     */
    public override func render(node: Node): Unit
}

public class TableBlock <: CustomBlock {}

public class TableBody <: CustomNode {}

public class TableCell <: CustomNode {

	/*
     * 是不是表头
     * 返回值 Bool - Bool
     */
    public func isHeader(): Bool

	/*
     * 设置该行是表头
     * 参数 Bool - Bool
     */
    public func setHeader(header: Bool): Unit

	/*
     * 获取对齐方式
     * 返回值 ?Alignment - 对齐方式
     */
    public func getAlignment(): ?Alignment

	/*
     * 设置对齐方式
     * 参数 Alignment - 对齐方式
     */
    public func setAlignment(alignment: Alignment): Unit
}

public enum Alignment {
    | LEFT
    | CENTER
    | RIGHT
}

public class TableHead <: CustomNode {}

public class TableRow <: CustomNode {}

public class TablesExtension <: ParserExtension & HtmlRendererExtension & TextContentRendererExtension {
	/*
     * 拓展插件
     * 返回值 Extension - Extension
     */
    public static func create(): Extension
	/*
     * 拓展插件
     * 参数 ParserBuilder - ParserBuilder
     */
    public func ext(parserBuilder: ParserBuilder): Unit
	/*
     * 拓展插件
     * 参数 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public func ext(rendererBuilder: HtmlRendererBuilder): Unit
	/*
     * 拓展插件
     * 参数 TextContentRendererBuilder - TextContentRendererBuilder
     */
    public func ext(rendererBuilder: TextContentRendererBuilder): Unit
}
```

##### 2.5.2 示例

```cangjie

import commonmark4cj.commonmark.*

@Test
public class TableTT {
    @TestCase
    func mustHaveHeaderAndSeparator(): Unit {
        let tt: TablesTest = TablesTest()
        @PowerAssert(tt.assertRendering("Abc|Def", "<p>Abc|Def</p>\n") == true)
        @PowerAssert(tt.assertRendering("Abc | Def", "<p>Abc | Def</p>\n") == true)
    }
}

public abstract class RenderingTestCase {
    protected func render(source: String): String

    public func assertRendering(source: String, expectedResult: String): Bool {
        let renderedContent: String = render(source)
        // include source for better assertion errors
        let expected: String = showTabs(expectedResult + "\n\n" + source)
        let actual: String = showTabs(renderedContent + "\n\n" + source)
        return expected.toString() == actual.toString()
    }

    private static func showTabs(s: String): String {
        // Tabs are shown as "rightwards arrow" for easier comparison
        return s.replace("\t", "\u{2192}")
    }
}

public class TablesTest <: RenderingTestCase {
    private static let EXTENSIONS: Array<Extension> = Array<Extension>([TablesExtension.create()])
    private static let PARSER: Parser = Parser.builder().extensions(EXTENSIONS).build()
    private static let RENDERER: HtmlRenderer = HtmlRenderer.builder().extensions(EXTENSIONS).build()

    protected override func render(source: String): String {
        return RENDERER.render(PARSER.parse(source))
    }
}
```

### 3 Render

前置条件：NA 

场景：

约束：NA

可靠性：NA

#### 3.1 TextRender

##### 3.1.1 主要接口

```cangjie
public class TextContentRenderer <: Renderer {
	/*
     * 构建TextContentRendererBuilder对象
     * 返回值 TextContentRendererBuilder - TextContentRendererBuilder
     */
    public static func builder(): TextContentRendererBuilder

	/*
     * 渲染node 追加到StringBuilder中
     * 参数 Node - Ndoe
     * 参数 StringBuilder - StringBuilder文本
     */
    public override func render(node: Node, output: StringBuilder): Unit

	/*
     * 渲染node
     * 参数 Node - Ndoe
     * 返回值 String - 渲染完成的文本
     */
    public override func render(node: Node): String
}

public class TextContentRendererBuilder {
	/*
     * 构建 TextContentRenderer 对象
     * 返回值 TextContentRenderer - TextContentRenderer
     */
    public func build(): TextContentRenderer

	/*
     * 是否忽略换行符 true是忽略
     * 参数 Bool - 是否忽略换行符
     * 返回值 TextContentRendererBuilder - TextContentRendererBuilder
     */
    public func setStripNewlines(stripNewlines: Bool): TextContentRendererBuilder

	/*
     * 新增一个 TextContentNodeRendererFactory实例对象
     * 参数 TextContentNodeRendererFactory - TextContentNodeRendererFactory
     * 返回值 TextContentRendererBuilder - TextContentRendererBuilder
     */
    public func nodeRendererFactory(nodeRendererFactory: TextContentNodeRendererFactory): TextContentRendererBuilder

	/*
     * 拓展新的render 例如 TablesExtension
     * 参数 Iterable<Extension> - 拓展列表
     * 返回值 TextContentRendererBuilder - TextContentRendererBuilder
     */
    public func extensions(extensions: Iterable<Extension>): TextContentRendererBuilder
}

public interface TextContentRendererExtension <: Extension {

	/*
     * 拓展新的render 例如 TablesExtension
     * 参数 TextContentRendererBuilder - TextContentRendererBuilder
     */
    func ext(rendererBuilder: TextContentRendererBuilder): Unit
}

public interface TextContentNodeRendererContext {
	/*
     * 是否忽略换行符 true是忽略
     * 返回值 Bool - 是否忽略换行符
     */
    func stripNewlines(): Bool

	/*
     * 获取TextContentWriter
     * 返回值 TextContentWriter - 是否忽TextContentWriter略换行符
     */
    func getWriter(): TextContentWriter

	/*
     * 渲染render
     * 参数 Node - Node
     */
    func render(node: Node): Unit
}

public type TextContentNodeRendererFactory = (context: TextContentNodeRendererContext) -> NodeRenderer

public class TextContentWriter {
	/*
     * 构建TextContentWriter对象
     * 参数 StringBuilder - 初始文本
     */
    public TextContentWriter(out: StringBuilder)
    
	/*
     * 写入空格 " "
     */
    public func whitespace(): Unit

	/*
     * 写入冒号 ":"
     */
    public func colon(): Unit

	/*
     * 写入 "\n"
     */
    public func line(): Unit

	/*
     * 去除文本的 [\r\n\s]格式 
     * 参数 ?String - 文本
     */
    public func writeStripped(s: ?String): Unit

	/*
     * 写入文本
     * 参数 ?String - 文本
     */
    public func write(s: ?String): Unit

	/*
     * 写入文本
     * 参数 Rune - 文本
     */
    public func write(c: Rune): Unit
}
```

##### 3.1.2 示例

```cangjie
    import commonmark4cj.commonmark.*

    @TestCase
    func render_test():Unit {
        var source: String = ""
        var rendered: String = ""
        source = "foo bar"
        rendered = defaultRenderer().render(parse(source))
        assertEquals("foo bar", rendered)
        rendered = strippedRenderer().render(parse(source))
        assertEquals("foo bar", rendered)

        source = "foo foo\n\nbar\nbar"
        rendered = defaultRenderer().render(parse(source))
        assertEquals("foo foo\nbar\nbar", rendered)
        rendered = strippedRenderer().render(parse(source))
        assertEquals("foo foo bar bar", rendered)
    }

    func defaultRenderer(): TextContentRenderer {
        return TextContentRenderer.builder().build()
    }

    func strippedRenderer(): TextContentRenderer {
        return TextContentRenderer.builder().setStripNewlines(true).build()
    }
```

#### 3.2 HtmlRender

##### 3.2.1 主要接口

```cangjie
public class HtmlRenderer <: Renderer {
	/*
     * 构建HtmlRendererBuilder对象
     * 返回值 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public static func builder(): HtmlRendererBuilder

	/*
     * 渲染node 追加到StringBuilder中
     * 参数 Node - Ndoe
     * 参数 StringBuilder - StringBuilder文本
     */
    public override func render(node: Node, output: StringBuilder): Unit

	/*
     * 渲染node
     * 参数 Node - Ndoe
     * 返回值 String - 渲染完成的文本
     */
    public override func render(node: Node): String
}

public class HtmlRendererBuilder {
	/*
     * 构建 HtmlRenderer 对象
     * 返回值 HtmlRenderer - HtmlRenderer
     */
    public func build(): HtmlRenderer
	
	/*
     * 更改 softbreak 默认 "\n"
     * 参数 String - softbreak
     * 返回值 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public func softbreak(softbreak: String): HtmlRendererBuilder

	/*
     * 是否需要转义 默认 false
     * 参数 Bool - 是否需要转义
     * 返回值 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public func escapeHtml(escapeHtml: Bool): HtmlRendererBuilder

	/*
     * 是否URL编码 默认 false
     * 参数 Bool - 是否URL编码
     * 返回值 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public func percentEncodeUrls(percentEncodeUrls: Bool): HtmlRendererBuilder

	/*
     * 新增属性工厂类
     * 参数 AttributeProviderFactory - AttributeProviderFactory
     * 返回值 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public func attributeProviderFactory(attributeProviderFactory: AttributeProviderFactory): HtmlRendererBuilder

	/*
     * 新增属性渲染工厂类
     * 参数 HtmlNodeRendererFactory - HtmlNodeRendererFactory
     * 返回值 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public func nodeRendererFactory(nodeRendererFactory: HtmlNodeRendererFactory): HtmlRendererBuilder

	/*
     * 拓展新的render 例如 TablesExtension
     * 参数 Iterable<Extension> - 拓展列表
     * 返回值 HtmlRendererBuilder - HtmlRendererBuilder
     */
    public func extensions(extensions: Iterable<Extension>): HtmlRendererBuilder
}

public interface HtmlRendererExtension <: Extension {
	/*
     * 拓展新的render 例如 TablesExtension
     * 参数 HtmlRendererBuilder - HtmlRendererBuilder
     */
    func ext(rendererBuilder: HtmlRendererBuilder): Unit
}

public class HtmlWriter {
	/*
     * 初始化
     * 参数 StringBuilder - 初始文本
     */
    public init(out: StringBuilder)

	/*
     * 新增文本
     * 参数 String - 文本
     */
    public func raw(s: String): Unit

	/*
     * 新增转义后的文本
     * 参数 String - 文本
     */
    public func text(text: String): Unit

	/*
     * 新增标签
     * 参数 String - 文本
     */
    public func tag(name: String): Unit

	/*
     * 新增标签
     * 参数 String - 文本
     * 参数 Map<String, String> - 属性map
     */
    public func tag(name: String, attrs: Map<String, String>): Unit

	/*
     * 新增标签
     * 参数 String - 文本
     * 参数 Map<String, String> - 属性map
     * 参数 Bool - 是否需要闭合 " /"
     */
    public func tag(name: String, attrs: ?Map<String, String>, voidElement: Bool): Unit

	/*
     * 新增 "\n"
     */
    public func line(): Unit
}

public interface AttributeProvider {
	/*
     * 设置标签属性
     * 参数 Node - Node
     * 参数 String - 标签
     * 参数 Map<String, String> - 属性map
     */
    func setAttributes(node: Node, tagName: String, attributes: Map<String, String>): Unit
}

public interface AttributeProviderContext {}

public type AttributeProviderFactory = (context: AttributeProviderContext) -> AttributeProvider

public interface HtmlNodeRendererContext {

	/*
     * URL编码
     * 参数 String - url
     * 返回值 String - 编码后的url
     */
    func encodeUrl(url: String): String

	/*
     * 拓展自定义的tag属性
     * 参数 Node - 被应用的Node
     * 参数 String - 标签
     * 参数 Map<String, String> - 属性map
     * 返回值 Map<String, String> - 拓展后的属性map
     */
    func extendAttributes(node: Node, tagName: String, attributes: Map<String, String>): Map<String, String>

	/*
     * 获取HtmlWriter
     * 返回值 HtmlWriter - HtmlWriter
     */
    func getWriter(): HtmlWriter

	/*
     * 获取HtmlWriter 默认 "\n"
     * 返回值 HtmlWriter - HtmlWriter
     */
    func getSoftbreak(): String

	/*
     * 渲染Node
     * 参数 Node - Node
     */
    func render(node: Node): Unit

	/*
     * 是否需要转义 默认false
     * 返回值 Bool - Bool
     */
    func shouldEscapeHtml(): Bool
}

public type HtmlNodeRendererFactory = (context: HtmlNodeRendererContext) -> NodeRenderer
```

##### 3.2.2 示例

```cangjie
    import commonmark4cj.commonmark.*

    @TestCase
    func render_test():Unit {
        let rendered: String = htmlAllowingRenderer().render(
            parse("paragraph with <span id='foo' class=\"bar\">inline &amp; html</span>"))
        assertEquals("<p>paragraph with <span id='foo' class=\"bar\">inline &amp; html</span></p>\n", rendered)
    }

    private func htmlAllowingRenderer(): HtmlRenderer {
        return HtmlRenderer.builder().escapeHtml(false).build()
    }
```

### 4 util

前置条件：NA 

场景：

约束：NA

可靠性：NA

#### 4.1 util
# asdasd   
##### 4.1.1 主要接口

```
public class Escaping {
	/*
     * html转义
     * 参数 String - String
     * 返回值 String - 转义后的String
     */
    public static func escapeHtml(input: String): String

	/*
     * 返回转义前的原始文本
     * 参数 String - String
     * 返回值 String -String
     */
    public static func unescapeString(s: String): String

	/*
     * 百分比编码
     * 参数 String - String
     * 返回值 String - 编码后的String
     */
    public static func percentEncodeUrl(s: String): String
}

public interface Replacer {
	/*
     * 替换
     * 参数 String - String
     * 参数 StringBuilder - String
     */
    func replace(input: String, sb: StringBuilder): Unit
}

public class Html5Entities {
	/*
     * 获取特殊字符的map
     * 返回值 HashMap<String, String> - 特殊字符的map
     */
    public static func readEntities(): HashMap<String, String>
}
```

##### 4.2.2 示例

```cangjie
    import commonmark4cj.commonmark.*

    @TestCase
    func escaping_test(): Unit {
        let escapeString6: String = Escaping.escapeHtml("< start")
        @PowerAssert(escapeString6 == "&lt; start")
        let escapeString7: String = Escaping.escapeHtml("end >")
        @PowerAssert(escapeString7 == "end &gt;")
        let escapeString8: String = Escaping.escapeHtml("< both >")
        @PowerAssert(escapeString8 == "&lt; both &gt;")
        let escapeString9: String = Escaping.escapeHtml("< middle & too >")
        @PowerAssert(escapeString9 == "&lt; middle &amp; too &gt;")

        let text = "Example string with special characters: !@#$%^&*()_+|~- and encoded characters: &amp;#x123; &amp;#123; and &amp;test;"
        let unescapeString: String = Escaping.unescapeString(text)
        let t = "Example string with special characters: !@#$%^&*()_+|~- and encoded characters: &#x123; &#123; and &test;"
        @PowerAssert(unescapeString == t)
    }
```
