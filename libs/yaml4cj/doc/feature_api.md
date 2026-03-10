## yaml4cj 库

### 介绍

yaml4cj 包使 cangjie 程序能够轻松地编码和解码 YAML 值，可以快速可靠地解析和生成 YAML 数据，参考地址：https://github.com/go-yaml/yaml/tree/v2。

### 1 快速解析 YAML 数据并转换成 JSON 对象或生成 YAML 数据

前置条件：NA 

场景：

1. OHOS， Linux， windows平台下可解析和生成 YAML 数据，支持 YAML1.1和1.2中对锚点，标签，地图合并的支持

约束：目前多文档解组尚不支持，不支持来自 YAML 1.1 的 base-60 浮点数

性能：NA

可靠性：NA

#### 1.1 yaml 格式文件解码成 json 对象 

##### 1.1.1 主要接口

可对 Array&lt;UInt8&gt; 数据进行 YAML 解码，并返回一个解码后的 JsonValue。若解码失败或无有效 YAML 值，则返回 JsonNull。

```cangjie
/*
 * 以默认方式进行解码
 *
 * 参数 data - 传入用于进行 YAML 解码的字节数组
 * 返回值 JsonValue - 返回一个解码后的 JsonValue，若解码失败或无有效 YAML 值，则返回 JsonNull。
 */
public func decode(data: Array<UInt8>): JsonValue

/*
 * 以可选方式进行解码
 *
 * 参数 data - 传入用于进行 YAML 解码的字节数组
 * 参数 strict - 传入是否以严格模式进行解码，true 则为严格模式，false 则为默认模式
 * 返回值 JsonValue -  返回一个解码后的 JsonValue，若解码失败或无有效 YAML 值，则返回 JsonNull。
 */
public func decode(data: Array<UInt8>, strict: Bool): JsonValue
```

##### 1.1.2 示例

test_all.yaml 文件数据

```
#注释
#1-字典  键: 值
username: xiaoming  #冒号后面是空格
password: 123456
info: 配置  #中文---不建议使用，有可能会乱码
#字典嵌套
NAME_PSW:
  name: xiaoming
  password: 123456
#2-列表格式
list:
  - Ruby
  - Perl
  - Python 
#表嵌套
lists:
- 10
- 20
-
 - 100
 - 200
#3-列表中套字典
- 10
- 20
-
 name: tom
 password: 123456

#4-字典套列表
name: TOM
info1:
   - 10
   - 20
   - 30

#5-引号,果是有英文字母或者中文的，不加引号也是字符串
info2: "HELLO word"  #引号可以不加 

#什么加引号:如果有特俗字符\n 不加引号就原字符样式输出    如果显示特殊字符效果:就加双引号
info3: "HELLO\nwoord"

#6-引用 一个数据可以使用很多地方，使用变量
#& 变量名   定义变量
#*变量名   引用变量
name1: &a tom
name2: *a

#8-yamL文件可以有YAML
DATA: conf.yaml

# YAML格式
key: |+
  a
  b
  c
# 实际效果
"key": "a\nb\nc\n"

# YAML格式
key: |-
  a
  b
  c
# 实际效果
"key": "a\nb\nc"

# YAML格式
key: >+
  a
  b
  c
# 实际效果
"key": "a b c\n"

# YAML格式
key: >-
  a
  b
  c
# 实际效果
"key": "a b c"
```

```cangjie
import yaml4cj.yaml.*
import std.os.posix.*
import std.io.*
import std.fs.*

main() {
    var path: String = getcwd()
    let pathname: String = "${path}/test_all.yaml"
    var fs: File = File(pathname, Open(true, true))
    if (fs.canRead()) {
        var res: Array<UInt8> = fs.readToEnd()
        fs.close()
        var jv = decode(res)
        println("---解码后---${jv.toString()}")
    } else {
        println("open fail")
    }
    return 0
}
```
执行结果如下：

```shell
---解码后---{"username":"xiaoming","password":123456,"info":"配置","NAME_PSW":{"name":"xiaoming","password":123456},"list":["Ruby","Perl","Python"],"lists":[10,20,[100,200],10,20,{"name":"tom","password":123456}],"name":"TOM","info1":[10,20,30],"info2":"HELLO word","info3":"HELLO\nwoord","name1":"tom","name2":"tom","DATA":"conf.yaml","key":"a b c"}
```

#### 1.2 json 对象编码成 yaml 数据 

#####  1.2.1 主要接口

可对一个 JsonValue 进行 YAML 编码，并返回编码后的 YAML 格式字节数组数据。若编码失败或无有效 Json 键值，则返回空数组。


```cangjie
/*
 * 对 JsonValue 进行 YAML 编码
 *
 * 参数 input - 传入用于进行 YAML 编码的 JsonValue
 * 返回值 Array<UInt8> - 返回一个编码后的字节数组，若编码失败或无有效 Json 键值，则返回空数组。
 */
public func encode(input: JsonValue): Array<UInt8>
```
#####  1.2.2 示例

test_all.json 文件数据

```
{"username":"xiaoming","password":123456,"info":"配置","NAME_PSW":{"name":"xiaoming","password":123456},"list":["Ruby","Perl","Python"],"lists":[10,20,[100,200],10,20,{"name":"tom","password":123456}],"name":"TOM","info1":[10,20,30],"info2":"HELLO word","info3":"HELLO\nwoord","name1":"tom","name2":"tom","DATA":"conf.yaml","key111":true}
```

```cangjie
import yaml4cj.yaml.*
import std.os.posix.*
import std.io.*
import std.fs.*
import encoding.json.*

main() {
    var path: String = getcwd()
    let pathname: String = "${path}/test_all.json"
    var fs: File = File(pathname, Open(true, true))
    if (fs.canRead()) {
        var res: String = String.fromUtf8(fs.readToEnd())
        fs.close()
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
        var decodeRes: String = decode(encodeRes).toString()
        if(res == decodeRes) {
            println("---success---")
        }

    } else {
        println("open fail")
    }
    return 0
}
```
执行结果如下：

```shell
---success---
```
### 2 内部接口

以下接口为内部接口，用户调用不到

```
enum BreakT <: Hashable & ToString {
    | BreakT_ANY_BREAK
    | BreakT_CR_BREAK
    | BreakT_LN_BREAK
    | BreakT_CRLN_BREAK

    public func hashCode(): Int64
    public operator func ==(b: BreakT): Bool
}

enum EmitterStateT <: Hashable & ToString {
    | EmitterStateT_EMIT_STREAM_START_STATE
    | EmitterStateT_EMIT_FIRST_DOCUMENT_START_STATE
    | EmitterStateT_EMIT_DOCUMENT_START_STATE
    | EmitterStateT_EMIT_DOCUMENT_CONTENT_STATE
    | EmitterStateT_EMIT_DOCUMENT_END_STATE
    | EmitterStateT_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE
    | EmitterStateT_EMIT_FLOW_SEQUENCE_ITEM_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_FIRST_KEY_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_KEY_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_SIMPLE_VALUE_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_VALUE_STATE
    | EmitterStateT_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE
    | EmitterStateT_EMIT_BLOCK_SEQUENCE_ITEM_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_KEY_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_VALUE_STATE
    | EmitterStateT_EMIT_END_STATE

    public func hashCode(): Int64
    public func toString(): String
}

enum EncodingT <: Hashable & ToString {
    | EncodingT_ANY_ENCODING
    | EncodingT_UTF8_ENCODING
    | EncodingT_UTF16LE_ENCODING
    | EncodingT_UTF16BE_ENCODING

    public func hashCode(): Int64
    public operator func ==(b: EncodingT): Bool
}

enum ErrorTypeT {
    | ErrorTypeT_NO_ERROR
    | ErrorTypeT_MEMORY_ERROR
    | ErrorTypeT_READER_ERROR
    | ErrorTypeT_SCANNER_ERROR
    | ErrorTypeT_PARSER_ERROR
    | ErrorTypeT_COMPOSER_ERROR
    | ErrorTypeT_WRITER_ERROR
    | ErrorTypeT_EMITTER_ERROR

    public static func getValues(): Array<ErrorTypeT>
    public operator func ==(b: ErrorTypeT): Bool
    public operator func !=(b: ErrorTypeT): Bool
}

enum ErrorTypeT {
    | ErrorTypeT_NO_ERROR
    | ErrorTypeT_MEMORY_ERROR
    | ErrorTypeT_READER_ERROR
    | ErrorTypeT_SCANNER_ERROR
    | ErrorTypeT_PARSER_ERROR
    | ErrorTypeT_COMPOSER_ERROR
    | ErrorTypeT_WRITER_ERROR
    | ErrorTypeT_EMITTER_ERROR

    public static func getValues(): Array<ErrorTypeT>
    public operator func ==(b: ErrorTypeT): Bool
    public operator func !=(b: ErrorTypeT): Bool
}

class YamlError <: Exception & ToString {
    public init(err: Exception)
    public init(err: String)
    public override func toString(): String
}

public class TypeError <: Exception {
    public init(errors: Array<String>)
}

enum EventTypeT <: Hashable & ToString {
    | EventTypeT_NO_EVENT
    | EventTypeT_STREAM_START_EVENT
    | EventTypeT_STREAM_END_EVENT
    | EventTypeT_DOCUMENT_START_EVENT
    | EventTypeT_DOCUMENT_END_EVENT
    | EventTypeT_ALIAS_EVENT
    | EventTypeT_SCALAR_EVENT
    | EventTypeT_SEQUENCE_START_EVENT
    | EventTypeT_SEQUENCE_END_EVENT
    | EventTypeT_MAPPING_START_EVENT
    | EventTypeT_MAPPING_END_EVENT

    public func hashCode(): Int64
    public operator func ==(b: EventTypeT): Bool
    public operator func !=(b: EventTypeT): Bool
    public func toString(): String
}

enum ParserStateT <: Hashable & ToString {
    | ParserStateT_PARSE_STREAM_START_STATE
    | ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE
    | ParserStateT_PARSE_DOCUMENT_START_STATE
    | ParserStateT_PARSE_DOCUMENT_CONTENT_STATE
    | ParserStateT_PARSE_DOCUMENT_END_STATE
    | ParserStateT_PARSE_BLOCK_NODE_STATE
    | ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE
    | ParserStateT_PARSE_FLOW_NODE_STATE
    | ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE
    | ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE
    | ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE
    | ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE
    | ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE
    | ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE
    | ParserStateT_PARSE_END_STATE

    public func getCode(): Int64
    public operator func ==(b: ParserStateT): Bool
}

enum NullStyleT <: StyleT {
    NullStyleT_NULL_STYLE

    public static func getValues(): Array<StyleT>
    public func getCode(): Int64
}

enum ScalarStyleT <: StyleT {
    | ScalarStyleT_ANY_SCALAR_STYLE
    | ScalarStyleT_PLAIN_SCALAR_STYLE
    | ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE
    | ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE
    | ScalarStyleT_LITERAL_SCALAR_STYLE
    | ScalarStyleT_FOLDED_SCALAR_STYLE
    public static func get(i: StyleT): ScalarStyleT
    public static func getValues(): Array<StyleT>
    public func getCode(): Int64
    public operator func ==(b: StyleT): Bool
    public operator func !=(b: StyleT): Bool
}

enum SequenceStyleT <: StyleT & Hashable {
    | SequenceStyleT_ANY_SEQUENCE_STYLE
    | SequenceStyleT_BLOCK_SEQUENCE_STYLE
    | SequenceStyleT_FLOW_SEQUENCE_STYLE
    public static func get(i: StyleT): SequenceStyleT
    public static func getValues(): Array<StyleT>
    public func getCode(): Int64
    public operator func ==(b: StyleT): Bool
}

enum MappingStyleT <: StyleT {
    | MappingStyleT_ANY_MAPPING_STYLE
    | MappingStyleT_BLOCK_MAPPING_STYLE
    | MappingStyleT_FLOW_MAPPING_STYLE
    public static func get(i: StyleT): MappingStyleT
    public static func getValues(): Array<StyleT>
    public func getCode(): Int64
    public operator func ==(b: StyleT): Bool
}

class TagDirectiveT {
    public init()
    public init(handle: Array<UInt8>, prefix: Array<UInt8>)
}

enum TokenTypeT {
    | TokenTypeT_NO_TOKEN
    | TokenTypeT_STREAM_START_TOKEN
    | TokenTypeT_STREAM_END_TOKEN
    | TokenTypeT_VERSION_DIRECTIVE_TOKEN
    | TokenTypeT_TAG_DIRECTIVE_TOKEN
    | TokenTypeT_DOCUMENT_START_TOKEN
    | TokenTypeT_DOCUMENT_END_TOKEN
    | TokenTypeT_BLOCK_SEQUENCE_START_TOKEN
    | TokenTypeT_BLOCK_MAPPING_START_TOKEN
    | TokenTypeT_BLOCK_END_TOKEN
    | TokenTypeT_FLOW_SEQUENCE_START_TOKEN
    | TokenTypeT_FLOW_SEQUENCE_END_TOKEN
    | TokenTypeT_FLOW_MAPPING_START_TOKEN
    | TokenTypeT_FLOW_MAPPING_END_TOKEN
    | TokenTypeT_BLOCK_ENTRY_TOKEN
    | TokenTypeT_FLOW_ENTRY_TOKEN
    | TokenTypeT_KEY_TOKEN
    | TokenTypeT_VALUE_TOKEN
    | TokenTypeT_ALIAS_TOKEN
    | TokenTypeT_ANCHOR_TOKEN
    | TokenTypeT_TAG_TOKEN
    | TokenTypeT_SCALAR_TOKEN

    public operator func ==(b: TokenTypeT): Bool
    public operator func !=(b: TokenTypeT): Bool
}
```