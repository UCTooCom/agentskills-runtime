/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_util

import std.collection.{ArrayList, TreeMap, HashMap, Map}
import std.collection.concurrent.ConcurrentHashMap
import std.convert.Parsable
import std.math.RoundingMode
import std.math.numeric.Decimal
import std.reflect.TypeInfo
import std.sync.Mutex
import std.time.DateTime
import f_base.*
import f_collection.*
import f_data.*
import f_exception.UnreachableException
import f_regex.*
import f_time.*
import f_util.exception.TextTemplateException
/**
 * 简单文本模板
 * 本类依赖ThreadLocalStringBuilder，如果使用本类的方法也使用了ThreadLocalStringBuilder请不要在那个方法内构造字符串时调用本类方法。
 * 如果本类对象的返回值是构造的一个字符串的一部分，请先调用本类，然后在使用本类的方法内使用ThreadLocalStringBuilder获取StringBuilder对象。
 * 占位符方式的文本模板，prefix和suffix之间的文本是提供数据的对象属性或map的key，
 * 占位符用“regex:”开头的表示这是一个正则表达式，包含正则表达式的模板只接收map作为数据来源，用map中找到的第一个匹配这个正则表达式的key所对应的值替换这个正则表达式占位符；正则表达式用`包含
 * 占位符内包含“time:`FORMAT`”表示，FORMAT在实际使用时换成日期格式化模板；占位符名在time:前面用空格分隔，或者在`FORMAT`后面后空格分隔
 * <p>
 * 占位符内包含“number:`##.##,HALF_UP`”表示，`##.##,HALF_UP`
 * 在实际使用时换成数字格式化模板；占位符名在number:前面用空格分隔，
 * 或者在`##.##,HALF_UP`后面用空格分隔，格式模板的#数量表示数字位数，.表示小数点位置；HALF_UP是默认舍入规则，可选
 * 数字格式可以o O x X e E + (等任意一个符号开头，这几个标记不能同时出现
 * o O表示转化成8进制，x X 表示转化成16进制，转化前会自动把小数精度改为0
 * e E 表示转化为科学计数法
 * + 表示对于正数需要前置+，(表示对于负数需要去掉-，并用()包含数字串
 * <p>
 * 占位符可以是用.分割的字符串，.分割的占位符接收数组、list、po、map作参数；
 * a.0.b.c，表示参数的a属性是一个数组或list，它的索引0有一个属性b（如果是map就是key）,属性b有一个属性c，属性c的值是用来格式化的内容
 * 由于在number: regex: time:等模式中`有特殊意义
 */
public class TextTemplate {
    private static let templates = ConcurrentHashMap<String, TextTemplate>()
    private static let mutex = Mutex()
    private static const TIME_FORMAT_PREFIX = "time:"
    private static const NUMBER_FORMAT_PREFIX = "number:"

    private let compiled = ArrayList<Value2String>()
    private TextTemplate(private let template: String) {}

    public func toString() {
        template
    }
    public static func compile(template: String, placeholder!: String = "#") {
        compile(template, prefix: placeholder, suffix: placeholder)
    }
    public static func compile(template: String, prefix!: String = #"${"#, suffix!: String = "}") {
        templates.computeIfAbsent(template){
            let instance = TextTemplate(template)
            instance.doCompile(template, prefix, suffix)
            instance
        }
    }
    private func doCompile(template: String, prefix: String, suffix: String) {
        let prefixLength = prefix.size
        let suffixLength = suffix.size
        let templateLength = template.size
        var start = 0
        var end = template.indexOf(prefix) ?? -1
        var tmp = template.indexOf(suffix, end + prefixLength) ?? -1
        var placeholderIndex = 0

        while (true) {
            if (end > 0 && tmp > 0 && end < templateLength && tmp < templateLength) {
                compiled.add(OriginValue2String(template[start..end]))
            } else if (end < 0 || tmp < 0 || end >= templateLength || tmp >= templateLength) {
                compiled.add(OriginValue2String(template[start..templateLength]))
                break
            }
            start = end + prefixLength
            end = tmp
            func confirmPlaceholderEnd(tag: String) {
                match (template.indexOf(tag, start) ?? -1) {
                    case x where x > 0 && x < end =>
                        var endIdx = (template.indexOf("`", x) ?? -1) + 1 //跳过第一个`
                        do {
                            endIdx = template.indexOf("`", endIdx + 1) ?? -1
                        } while (endIdx > 0 && endIdx < template.size && template[endIdx - 1] == b'\\')
                        if (endIdx < 0 || endIdx >= template.size) {
                            throw TextTemplateException("text template is not completed")
                        }
                        template.indexOf(suffix, endIdx + 1) ?? -1
                    case _ => None<Int64>
                }
            }
            for (tag in [TIME_FORMAT_PREFIX, NUMBER_FORMAT_PREFIX]) {
                if (let Some(x) <- confirmPlaceholderEnd(tag)) {
                    end = x
                    break
                }
            }
            addPlaceholder(template, start, end, placeholderIndex)
            placeholderIndex++
            start = end + suffixLength
            end = template.indexOf(prefix, start) ?? -1
            tmp = template.indexOf(suffix, end + prefixLength) ?? -1
        }
    }

    /**
     * 执行compile(...)时，找到一个占位符，就添加一个占位符对象，模板里非占位符的部分也是一个占位符对象
     * @param template 文本模板
     * @param start 占位符开始位置
     * @param end 占位符结束位置
     * @param placeholderIndex 第N个占位符，从0开始计数
     */
    private func addPlaceholder(template: String, start: Int64, end: Int64, placeholderIndex: Int64) {
        var placeholder = template[start..end].trimAscii()
        let getter = ValueGetter(placeholderIndex, placeholder)
        if (placeholder.isEmpty()) {
            compiled.add(Value2PlainString(getter))
            return
        }
        var timePrefix = TIME_FORMAT_PREFIX
        var timeIdx = placeholder.indexOf(timePrefix) ?? -1
        let converter = if (timeIdx < 0) {
            let numberIdx = placeholder.indexOf(NUMBER_FORMAT_PREFIX) ?? -1
            if (numberIdx >= 0) {
                var formatStart = numberIdx + NUMBER_FORMAT_PREFIX.size
                formatStart = (placeholder.indexOf("`", formatStart) ?? -1) + 1
                var formatEnd = placeholder.indexOf("`", formatStart) ?? -1
                while (formatEnd > 0 && formatEnd < placeholder.size && template[formatEnd - 1] == b'\\') {
                    formatEnd = template.indexOf("`", formatEnd + 1) ?? -1
                }
                let format = if (formatEnd > 0 && formatEnd < placeholder.size) {
                    placeholder[formatStart..formatEnd].trimAscii()
                } else {
                    throw IllegalArgumentException("time format must be followed 'time:' and included in ``")
                }
                placeholder = placeholder[if (numberIdx == 0) {
                        formatEnd + 1..placeholder.size
                    } else {
                        0..numberIdx
                    }].trimAscii()
                Value2NumberString(getter, format)
            } else {
                Value2PlainString(getter)
            }
        } else {
            var formatStart = timeIdx + timePrefix.size
            formatStart = (placeholder.indexOf("`", formatStart) ?? -1) + 1
            var formatEnd = placeholder.indexOf("`", formatStart) ?? -1
            while (formatEnd > 0 && formatEnd < placeholder.size && template[formatEnd - 1] == b'\\') {
                formatEnd = template.indexOf("`", formatEnd + 1) ?? -1
            }
            let format = if (formatEnd > 0 && formatEnd < placeholder.size) {
                placeholder[formatStart..formatEnd].trimAscii().regex().replaceAll("`", "\\`")
            } else {
                throw IllegalArgumentException("time format must be followed 'time:' and included in ``")
            }
            placeholder = if (timeIdx == 0) {
                placeholder[formatEnd + 1..]
            } else { //timeIdx>0
                placeholder[0..timeIdx]
            }.trimAscii()
            Value2TimeString(getter, format)
        }
        compiled.add(converter)
    }
    private func format<K, V, O>(data: O, noneConverter: ?String): String where K <: TextTemplateKey<K>, V <: ToString,
        O <: TextTemplateObject<K, V, O> {
        let builder = StringGenerator()
        for (i in 0..compiled.size) {
            builder.append(compiled[i].format<K, V, O>(data, noneConverter))
        }
        builder.toString()
    }
    public func format<T>(data: Array<T>, noneConverter!: ?String = None<String>): String where T <: ToString {
        format<Int64, T, Array<T>>(data, noneConverter)
    }
    public func format<T>(data: ArrayList<T>, noneConverter!: ?String = None<String>): String where T <: ToString {
        format<Int64, T, ArrayList<T>>(data, noneConverter)
    }
    public func format<V>(data: ConcurrentHashMap<String, V>, noneConverter!: ?String = None<String>): String where V <: ToString {
        format<String, V, ConcurrentHashMap<String, V>>(data, noneConverter)
    }
    public func format<V>(data: HashMap<String, V>, noneConverter!: ?String = None<String>): String where V <: ToString {
        format<String, V, HashMap<String, V>>(data, noneConverter)
    }
    public func format<V>(data: TreeMap<String, V>, noneConverter!: ?String = None<String>): String where V <: ToString {
        format<String, V, TreeMap<String, V>>(data, noneConverter)
    }
    public func format<V>(data: LinkedHashMap<String, V>, noneConverter!: ?String = None<String>): String where V <: ToString {
        format<String, V, LinkedHashMap<String, V>>(data, noneConverter)
    }
    public func format<T>(data: T, noneConverter!: ?String = None<String>): String where T <: Object & ObjectData<T> {
        format<String, ToString, ObjectTextTemplateArgs<T>>(ObjectTextTemplateArgs<T>(data), noneConverter)
    }
}

/**
 * 得到数据
 */
class ValueGetter {
    private let index: Int64
    ValueGetter(index: Int64, private let key: String) {
        this.index = if (key.isEmpty()) {
            index
        } else if (let Some(x) <- Int64.tryParse(key)) {
            x
        } else {
            -1
        }
    }
    init(indexText: String) {
        this(Int64.parse(indexText), indexText)
    }

    func get<K, V, O>(data: O): ToString where K <: TextTemplateKey<K>, V <: ToString, O <: TextTemplateObject<K, V, O> {
        match (index) {
            case x: K where index >= 0 => data[x]
            case _ => match (key) {
                case x: K where !(key.isEmpty() && (TypeInfo
                    .of(data)
                    .qualifiedName
                    .startsWith("f_util.ObjectTextTemplateArgs"))) => data[x]
                case _ => throw TextTemplateException(
                    "data type ${TypeInfo.of(data)} is without field ${key} or the field is not a ${TypeInfo.of<K>()}")
            }
        }
    }
    func placeholder(): String {
        if (index >= 0 && key.isEmpty()) {
            index.toString()
        } else {
            key
        }
    }
}

/**
 * 数据格式化接口，所有的占位符对象都实现这个接口
 */
abstract sealed class Value2String {
    protected func format<K, V, O>(data: O, noneConverter: ?String): String where K <: TextTemplateKey<K>, V <: ToString,
        O <: TextTemplateObject<K, V, O> {
        match (this) {
            case x: OriginValue2String => x.doFormat()
            case x: Value2PlainString => x.doFormat<K, V, O>(data, noneConverter)
            case x: Value2TimeString => x.doFormat<K, V, O>(data, noneConverter)
            case x: Value2NumberString => x.doFormat<K, V, O>(data, noneConverter)
            case _ => throw UnreachableException()
        }
    }
}

/**
 * 原始文本占位符，模板里面是什么内容就输出什么内容
 */
class OriginValue2String <: Value2String {
    OriginValue2String(private let text: String) {}

    protected func doFormat() {
        text
    }
}

class Value2PlainString <: Value2String {
    Value2PlainString(private let getter: ValueGetter) {}
    protected func doFormat<K, V, O>(data: O, noneConverter: ?String): String where K <: TextTemplateKey<K>,
        V <: ToString, O <: TextTemplateObject<K, V, O> {
        getter.get<K, V, O>(data).toString()
    }
}

class Value2TimeString <: Value2String {
    Value2TimeString(private let getter: ValueGetter, private let formatter: String) {}
    protected func doFormat<K, V, O>(data: O, noneConverter: ?String): String where K <: TextTemplateKey<K>,
        V <: ToString, O <: TextTemplateObject<K, V, O> {
        func extractNoneConverter() {
            match (noneConverter) {
                case Some(x) => x
                case _ => throw TextTemplateException(
                    "type ${TypeInfo.of(data)} whose field ${getter.placeholder()} is not a DateTime or does not exist")
            }
        }
        let value = getter.get<K, V, O>(data)
        match (value) {
            case x: DateTime => x.format(formatter)
            case x: ?DateTime => match (x) {
                case Some(x) => x.format(formatter)
                case _ => extractNoneConverter()
            }
            case _ => extractNoneConverter()
        }
    }
}

class Value2NumberString <: Value2String {
    private let integer: Int64
    private var radix = 10
    private var prefix = ""
    private var engineering = false
    private var prefixPlus = false
    private var enclosedInParentheses = false
    private var upperCase = false
    private var scale = 0i32
    private var mode = RoundingMode.HalfUp

    Value2NumberString(private let getter: ValueGetter, private let formatter: String) {
        if (!#"^[oOxXeE\\+\\(]?(#+(\\.#+)?|(#*\\.#+))(,[a-zA-Z_]+)?$"#.regex(solid: false).matches(formatter)) {
            throw TextTemplateException(
                "number placeholder must be # in number format like O### x### e###.## ##.##,HALF_UP or ###,HALF_UP or .###,HALF_UP")
        }
        var hasSymbol = 0
        if (formatter.startsWith("o") || formatter.startsWith("O")) {
            radix = 8
            prefix = formatter[0..1]
            hasSymbol = 1
        } else if (formatter.startsWith("x") || formatter.startsWith("X")) {
            radix = 16
            prefix = "0" + formatter[0..1]
            if (prefix[0] == b'X') {
                upperCase = true
            }
            hasSymbol = 1
        } else if (formatter.startsWith("e") || formatter.startsWith("E")) {
            engineering = true
            if (formatter[0] == b'E') {
                upperCase = true
            }
            hasSymbol = 1
        } else if (formatter.startsWith("+")) {
            prefixPlus = true
            hasSymbol = 1
        } else if (formatter.startsWith("(")) {
            enclosedInParentheses = true
            hasSymbol = 1
        }
        var dotIdx = formatter.indexOf(".") ?? -1
        var commaIdx = formatter.lastIndexOf(",") ?? -1
        if (dotIdx < 0) {
            scale = 0
            if (commaIdx < 0) {
                integer = formatter.size - hasSymbol
                mode = RoundingMode.HalfUp
            } else { //commaIdx>0
                integer = commaIdx - hasSymbol
                mode = parseRoundingMode(formatter[commaIdx + 1..].toAsciiUpper())
            }
        } else if (dotIdx == 0) {
            integer = 0
            if (commaIdx < 0) {
                scale = Int32(formatter.size - 1) //去掉小数点
                mode = RoundingMode.HalfUp
            } else { //commaIdx>0
                scale = Int32(commaIdx - 1) //去掉小数点
                mode = parseRoundingMode(formatter[commaIdx + 1..])
            }
        } else { //dotIdx>0
            integer = dotIdx - hasSymbol
            if (commaIdx < 0) {
                scale = Int32(formatter.size - dotIdx - 1)
                mode = RoundingMode.HalfUp
            } else if (commaIdx > 0) {
                scale = Int32(commaIdx - dotIdx - 1)
                mode = parseRoundingMode(formatter[commaIdx + 1..])
            }
        }
    }
    private static func parseRoundingMode(mode: String): RoundingMode {
        match (mode.toAsciiUpper()) {
            case "UP" => Up
            case "DOWN" => Down
            case "CEILING" => Ceiling
            case "FLOOR" => Floor
            case "HALF_UP" | 'HALFUP' => HalfUp
            case "HALF_EVEN" | 'HALFEVEN' => HalfEven
            case _ => throw TextTemplateException("${mode} is not a RoundingMode")
        }
    }
    protected func doFormat<K, V, O>(data: O, noneConverter: ?String): String where K <: TextTemplateKey<K>,
        V <: ToString, O <: TextTemplateObject<K, V, O> {
        let value = getter.get<K, V, O>(data).toString()
        if (value.isEmpty()) {
            noneConverter
        }
        var number = Decimal.parse(value)
        var symbol = number.compare(Decimal.zero)
        if (radix == 10) {
            number = number.reScale(scale, roundingMode: mode)
            var string: String
            if (engineering) {
                string = number.toSciString()
            } else {
                string = number.toString()
                if (scale > 0) {
                    var dotIdx = string.indexOf(".") ?? -1
                    if (integer == 0) {
                        string = "0${string[dotIdx..]}"
                    } else if (dotIdx < integer) {
                        string = "${0 * (integer - dotIdx)}${string}"
                    }
                } else {
                    var l = string.size
                    if (l < integer) {
                        string = "${0 * (integer - l)}${string}"
                    }
                }
            }
            if (upperCase) {
                string = string.toAsciiUpper()
            }
            if (symbol > EQ && prefixPlus) {
                return "+" + string
            } else if (symbol < EQ && enclosedInParentheses) {
                return "(${string[1..]})"
            }
            return string
        } else {
            let string = BigInt(true, number.reScale(0, roundingMode: mode).toBigInt().toBytes()).toString(radix: radix)
            let l = string.size
            if (l < integer) {
                return "${prefix}${0 * (integer - 1)}${string}"
            }
            return prefix + string
        }
    }
}

public interface TextTemplateKey<K> where K <: TextTemplateKey<K> {}

extend Int64 <: TextTemplateKey<Int64> {}

extend String <: TextTemplateKey<String> {}

public interface TextTemplateObject<K, V, O> where K <: TextTemplateKey<K>, V <: ToString,
    O <: TextTemplateObject<K, V, O> {
    operator func [](key: K): V
}

extend<T> Array<T> <: TextTemplateObject<Int64, T, Array<T>> where T <: ToString {}

extend<T> ArrayList<T> <: TextTemplateObject<Int64, T, ArrayList<T>> where T <: ToString {}

extend<K, V> HashMap<K, V> <: TextTemplateObject<K, V, HashMap<K, V>> where K <: Hashable & Equatable<K> & TextTemplateKey<K>,
    V <: ToString {}

extend<K, V> ConcurrentHashMap<K, V> <: TextTemplateObject<K, V, ConcurrentHashMap<K, V>> where K <: Hashable & Equatable<K> & TextTemplateKey<K>,
    V <: ToString {}

extend<K, V> TreeMap<K, V> <: TextTemplateObject<K, V, TreeMap<K, V>> where K <: Comparable<K> & TextTemplateKey<K>,
    V <: ToString {}

extend<K, V> LinkedHashMap<K, V> <: TextTemplateObject<K, V, LinkedHashMap<K, V>> where K <: Equatable<K> & TextTemplateKey<K>,
    V <: ToString {}

public class ObjectTextTemplateArgs<T> <: TextTemplateObject<String, ToString, ObjectTextTemplateArgs<T>> where T <: Object & ObjectData<T> {
    public ObjectTextTemplateArgs(private let arg: T) {}
    public operator func [](key: String): ToString {
        T
            .dataFields()
            .readableField(key)
            .getOrThrow {TextTemplateException("type ${TypeInfo.of<T>()} is without field ${key}")}
            .get(arg)
            .toString()
    }
}
