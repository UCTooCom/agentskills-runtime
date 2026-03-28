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

import std.sync.Mutex
import std.collection.{ArrayList, Map, HashMap}
import std.convert.Parsable
import std.time.DateTime
import f_base.*
import f_data.DataParsable
import f_regex.*

/**
 * 路径匹配工具，可以匹配各种绝对路径，这个工具从一个java版本的实现复制过来，java版本已经在生产环境使用。
 * 只能匹配绝对路径，不以/开头的也当作以/开头处理，多个连续的/合并成一个
 * 支持以下特性
 * 路径字符串相等匹配（a)
 * *通配符多字符模糊匹配单级路径，匹配通配符所在那级路径中的任意数量的字符，字符数大于等于0（b），匹配过程与（d）相同
 * ?通配符单字符模糊匹配单级路径，匹配通配符所在那级路径中的任意一个字符，字符数是且必须是1（c），匹配过程与（d）相同
 * {#regex:}包含的正则表达式单级路径匹配，#regex可以是任意合法变量名也可以是#regex，当此处是变量名时表示本级路径是路径参数，
 * 当此处出现#regex时表示本级路径不作为@PathVariable（d）
 *
 * 单星号的单级路径模糊匹配（e），与（b）的区别是这个单*匹配两个/中间的部分或路径最末尾的一段，
 * （b）的*只是匹配两个/中间的一部分字符或最末尾一段的一部分字符
 *
 * {}包含的占位符单级路径匹配（f），匹配过程与（e）相同
 * {*...}...是占位符变量，单级路径匹配，匹配过程相当于＊＊/{...}（g）
 * 双星号的多级路径模糊匹配（h）
 * 匹配优先级是a>b=c=d>e=f=g>h
 * (b)(c)可以同时出现在同一级路径中
 */
public class PathPattern {
    public init() {}

    private let mutex = Mutex()
    private let patterns = ArrayList<PathNode>()
    private let originPatterns = ArrayList<ArrayList<(String, () -> Any)>>()

    private func parts(path: String, withExtName: Bool): Array<String> {
        return trimExt(path, withExtName).split("/")
    }
    private func trimExt(path: String, withExtName: Bool): String {
        var p = path
        if (!withExtName) {
            let idx = path.lastIndexOf(".") ?? -1
            if (idx > 0 && idx > (path.lastIndexOf("/") ?? -1) && idx > (path.lastIndexOf("}") ?? -1)) {
                p = path[0..idx]
            }
        }
        return p
    }
    private func countWithoutDoubleStar(path: String, withExtName: Bool): Int64 {
        return parts(#"/\*\*"#.regex(solid: true).replaceAll(path, String.empty), withExtName).size
    }
    private func getPathNode(len: Int64): PathNode {
        func populateNode(node: PathNode) {
            synchronized(mutex) {
                while (patterns.size < len) {
                    patterns.add(NonePathNode.INSTANCE)
                }
                if (patterns.size == len) {
                    patterns.add(node)
                } else {
                    patterns[len] = node
                }
                for (i in 1..=len) {
                    if (i < originPatterns.size) {
                        for ((pattern, supplier) in originPatterns[i]) {
                            let parts = this.parts(pattern, true)
                            compile(false, node, parts, supplier)
                        }
                    }
                }
            }
            node
        }
        match (patterns.get(len)) {
            case Some(n) where (n is NonePathNode) =>
                let node = PathNode()
                populateNode(node)
            case Some(node) => node
            case _ =>
                let node = PathNode()
                populateNode(node)
        }
    }

    public func compile(pattern: String): PathPattern {
        return compile(pattern, ())
    }
    private func trimRedundantSlash(path: String) {
        var p = path.replace("//", "/")
        if (p.endsWith("/")) {
            p = p[0..p.size - 1]
        }
        if (!p.startsWith("/")) {
            p = "/${p}"
        }
        p
    }
    private func pretreat(pattern: String) {
        var p = pattern
        p = #"/\{\*(?=[a-zA-Z][A-Za-z0-9_]*\})"#.regex(solid: true).replaceAll(p, "/**/{")
        p = #"/\*{3,}"#.regex(solid: true).replaceAll(p, "/**")
        p = #"(/\*{2}){2,}"#.regex(solid: true).replaceAll(p, "/**")
        p = p.replace("//", "/")
        p = trimRedundantSlash(p)
        p
    }
    //pattern是定义的路径，data是路径对应的数据，比如这个路径对应的执行函数、是否匹配当前请求方法等
    public func compile<T>(pattern: String, data: T): PathPattern {
        doCompile<T>(true, pattern) {data}
        this
    }
    private func doCompile<T>(anyway: Bool, pattern: String, supplier: () -> Any): T {
        let parts = parts(pattern, true)
        synchronized(mutex) {
            if (pattern.contains("**")) {
                let count = countWithoutDoubleStar(pattern, true)
                while (patterns.size < count + 1) {
                    patterns.add(NonePathNode.INSTANCE)
                }
                while (originPatterns.size < count + 1) {
                    originPatterns.add(ArrayList<(String, () -> Any)>())
                }
                originPatterns[count].add((pattern, supplier))
                for (i in count..patterns.size) {
                    var node = patterns[i]
                    if (node is NonePathNode) {
                        node = PathNode()
                        patterns[i] = node
                    }
                    compile(anyway, node, parts, supplier)
                }
            }
            let prev = getPathNode(parts.size)
            return (compile(anyway, prev, parts, supplier) as T).getOrThrow()
        }
    }
    public func compileIfAbsent<T>(pattern: String, supplier: () -> T): T {
        let p = pretreat(pattern)
        doCompile<T>(false, p) {supplier()}
    }

    private func compile(anyway: Bool, prev: PathNode, parts: Array<String>, supplier: () -> Any): Any {
        var prev_ = prev
        for (i in 0..parts.size) {
            let part = parts[i]
            prev_ = appendSubPathNode(prev_, part)
        }
        prev_.end = true
        prev_.setDataIfNone(anyway, supplier)
    }
    private func appendSubPathNode(prev: PathNode, name: String): PathNode {
        return prev.appendSubPathNode(name).getOrThrow()
    }
    public func extractVariableInPath(path: String, name: String): Option<String> {
        return extractVariableInPath(path, name, false)
    }
    public func extractVariableInPath(path: String, name: String, withExtName: Bool): Option<String> {
        return extractVariablesInPath(path, withExtName).get(name)
    }
    public func extractVariablesInPath(path: String): Map<String, String> {
        return extractVariablesInPath(path, false)
    }
    public func extractVariablesInPath(path: String, withExtName: Bool): Map<String, String> {
        let parts = this.parts(path, withExtName)
        let variables = get<Map<Int64, Any>>(parts, Mode.EXTRACTION)
        let result = HashMap<String, String>()
        match (variables) {
            case Some(map) =>
                for ((index, node) in map) {
                    match (node) {
                        case name: String => result.add(name, parts[index])
                        case node: ComplexPathNode => result.add(all: node.extract(parts[index]))
                        case _ => () //unreachable
                    }
                }
                result

            case _ => result
        }
    }
    public func extractTimeVariableInPath(path: String, name: String, format: String): Option<DateTime> {
        return extractTimeVariableInPath(path, name, false, format)
    }
    public func extractTimeVariableInPath(path: String, name: String, withExtName: Bool, format: String): Option<DateTime> {
        let value = extractVariableInPath(path, name, withExtName)
        match (value) {
            case Some(v) => DateTime.parse(v, format)
            case _ => None<DateTime>
        }
    }
    public func extractParsableVariableInPath<T>(path: String, name: String): Option<T> where T <: Parsable<T> {
        return extractParsableVariableInPath<T>(path, name, false)
    }
    public func extractParsableVariableInPath<T>(path: String, name: String, withExtName: Bool): Option<T> where T <: Parsable<T> {
        let value = extractVariableInPath(path, name, withExtName)
        match (value) {
            case Some(v) => T.tryParse(v)
            case _ => None<T>
        }
    }
    public func extractDataParsableVariableInPath<T>(path: String, name: String): Option<T> where T <: DataParsable<T> {
        return extractDataParsableVariableInPath<T>(path, name, false)
    }
    public func extractDataParsableVariableInPath<T>(path: String, name: String, withExtName: Bool): Option<T> where T <: DataParsable<T> {
        let value = extractVariableInPath(path, name, withExtName)
        match (value) {
            case Some(v) => T.tryParse(v)
            case _ => None<T>
        }
    }

    private func get<T>(parts: Array<String>, mode: Mode): Option<T> {
        return get<T>(parts, mode, parts.size)
    }

    /**
     * 想不到更漂亮的做法。
     * 如果觉的这段代码很丑，可以参考学习一下航天飞机模式。
     *
     * @param parts
     * @param mode
     * @param <T>
     * @return
     */
    private func get<T>(parts: Array<String>, mode: Mode, len: Int64): Option<T> {
        var node: PathNode = getPathNode(len)
        var prevDoubleStar: PathNode = NonePathNode.INSTANCE
        var prevComplex: PathNode = NonePathNode.INSTANCE
        var prevRegexPlaceholder: PathNode = NonePathNode.INSTANCE
        var prevPlaceholder: PathNode = NonePathNode.INSTANCE
        var endNode: PathNode = NonePathNode.INSTANCE
        let variables: Map<Int64, Any> = if (let EXTRACTION <- mode) {
            HashMap<Int64, Any>()
        } else {
            EmptyMap<Int64, Any>.INSTANCE()
        }
        var i = 0
        while (i < parts.size) {
            let part = parts[i]
            var tmp: Option<PathNode> = node.getSub(part)
            if (let Some(n) <- tmp) {
                node = n
                prevComplex = NonePathNode.INSTANCE
                prevRegexPlaceholder = NonePathNode.INSTANCE
                prevPlaceholder = NonePathNode.INSTANCE
                i++
                continue
            }

            tmp = node.getRegexPlaceholderNode(part, prevRegexPlaceholder)
            if (let Some(n) <- tmp) {
                node = n
                prevComplex = NonePathNode.INSTANCE
                prevRegexPlaceholder = NonePathNode.INSTANCE
                prevDoubleStar = NonePathNode.INSTANCE
                prevPlaceholder = NonePathNode.INSTANCE
                if (mode.extraction()) {
                    variables.add(i, node.name)
                }
                i++
                continue
            }
            tmp = node.getPlaceholderNode(prevPlaceholder)
            if (let Some(n) <- tmp) {
                node = n
                prevPlaceholder = NonePathNode.INSTANCE
                prevDoubleStar = NonePathNode.INSTANCE
                prevComplex = NonePathNode.INSTANCE
                prevRegexPlaceholder = NonePathNode.INSTANCE
                if (mode.extraction()) {
                    variables.add(i, node.name)
                }
                i++
                continue
            }
            tmp = node.getRegexNode(part)
            if (let Some(n) <- tmp) {
                node = n
                prevComplex = NonePathNode.INSTANCE
                prevRegexPlaceholder = NonePathNode.INSTANCE
                prevPlaceholder = NonePathNode.INSTANCE
                i++
                continue
            }

            tmp = node.getComplexNode(part, prevComplex)
            if (let Some(n) <- tmp) {
                node = n
                prevPlaceholder = NonePathNode.INSTANCE
                prevComplex = NonePathNode.INSTANCE
                prevRegexPlaceholder = NonePathNode.INSTANCE
                if (mode.extraction()) {
                    variables.add(i, node)
                }
                i++
                continue
            }

            tmp = node.getStarNode()
            if (let Some(n) <- tmp) {
                node = n
                prevComplex = NonePathNode.INSTANCE
                prevRegexPlaceholder = NonePathNode.INSTANCE
                prevPlaceholder = NonePathNode.INSTANCE
                i++
                continue
            }
            tmp = node.getDoubleStarNode()
            if (let Some(n) <- tmp) {
                node = n
                prevDoubleStar = node
                prevPlaceholder = NonePathNode.INSTANCE
                prevComplex = NonePathNode.INSTANCE
                prevRegexPlaceholder = NonePathNode.INSTANCE
                i++
                continue
            }
            let end = node.end
            if (end) {
                endNode = node
            }
            match (node.prev) {
                case Some(n) where n is PlaceholderPathNode =>
                    if (mode.extraction()) {
                        variables.remove(i)
                    }
                    i -= 2
                    prevPlaceholder = n
                    if (let Some(ppn) <- prevPlaceholder.prev) {
                        node = ppn
                    } else {
                        node = NonePathNode.INSTANCE
                    }
                    prevDoubleStar = NonePathNode.INSTANCE
                    prevComplex = NonePathNode.INSTANCE
                    prevRegexPlaceholder = NonePathNode.INSTANCE
                case Some(n) where n is PlaceholderRegexPathNode =>
                    if (mode.extraction()) {
                        variables.remove(i)
                    }
                    i -= 2
                    prevRegexPlaceholder = n
                    if (let Some(prpn) <- prevRegexPlaceholder.prev) {
                        node = prpn
                    } else {
                        node = NonePathNode.INSTANCE
                    }
                    prevComplex = NonePathNode.INSTANCE
                    prevDoubleStar = NonePathNode.INSTANCE
                    prevPlaceholder = NonePathNode.INSTANCE
                case Some(n) where n is ComplexPathNode =>
                    if (mode.extraction()) {
                        variables.remove(i)
                    }
                    i -= 2
                    prevComplex = n
                    if (let Some(pcn) <- prevComplex.prev) {
                        node = pcn
                    } else {
                        node = NonePathNode.INSTANCE
                    }
                    prevRegexPlaceholder = NonePathNode.INSTANCE
                    prevDoubleStar = NonePathNode.INSTANCE
                    prevPlaceholder = NonePathNode.INSTANCE
                case _ where !(prevDoubleStar is NonePathNode || prevDoubleStar == node) =>
                    node = prevDoubleStar
                    prevPlaceholder = NonePathNode.INSTANCE
                    prevComplex = NonePathNode.INSTANCE
                    prevRegexPlaceholder = NonePathNode.INSTANCE
                    i++
                    continue
                case _ where node is DoubleStarPathNode =>
                    prevDoubleStar = node
                    prevPlaceholder = NonePathNode.INSTANCE
                    prevComplex = NonePathNode.INSTANCE
                    prevRegexPlaceholder = NonePathNode.INSTANCE
                    i++
                    continue
                case _ where end && mode.prefix() =>
                    node = endNode
                    break
                case _ => return None<T>
            }
            i++
        }
        if (mode.extraction()) {
            return variables as T
        } else {
            return node as T
        }
    }

    /**
     * 不包含路径中的扩展名
     * @param path
     * @return
     */
    public func matches(path: String): Bool {
        return matches(path, false)
    }
    public func matches(path: String, withExtName: Bool): Bool {
        let node = get(path, Mode.MATCHING, withExtName)
        return matches(node)
    }
    public func matchesPrefix(path: String): Bool {
        let node = get(path, Mode.PREFIX, false)
        return matches(node)
    }
    private func matches(node: PathNode): Bool {
        !(node is NonePathNode) && node.end
    }
    private func matches(node: Option<PathNode>): Bool {
        matches(node ?? NonePathNode.INSTANCE)
    }

    /**
     * 不包含路径中的扩展名
     * @param path
     * @param <T>
     * @return
     */
    public func data<T>(path: String): Option<T> {
        return data<T>(path, false)
    }
    public func data<T>(path: String, withExtName: Bool): Option<T> {
        get(path, Mode.MATCHING, withExtName).data<T>()
    }

    public func dataByPrefix<T>(path: String): Option<T> {
        dataByPrefix<T>(path, false)
    }
    public func dataByPrefix<T>(path: String, withExtName: Bool): Option<T> {
        get(path, Mode.PREFIX, withExtName).data<T>()
    }

    private func get(path: String, mode: Mode, withExtName: Bool): PathNode {
        let p = trimRedundantSlash(path)
        let parts = this.parts(p, withExtName)
        match (mode) {
            case PREFIX =>
                var node = None<PathNode>
                var len = parts.size
                do {
                    node = get<PathNode>(parts, mode, len)
                    len--
                } while (len > 0 && !matches(node))
                node
            case _ => get<PathNode>(parts, mode)
        } ?? NonePathNode.INSTANCE
    }
}

extend<T> Option<T> where T <: PathNode {
    func matches(value: String): Bool {
        match (this) {
            case Some(n) => n.matches(value)
            case _ => false
        }
    }
}

open class PathNode <: Equatable<PathNode> {
    protected var name: String
    let prev: Option<PathNode>
    private let subs = HashMap<String, PathNode>()
    private let complexPathNodes = HashMap<String, ComplexPathNode>()
    private let regexPlaceholderPathNodes = HashMap<String, PlaceholderRegexPathNode>()
    private let placeholderPathNodes = HashMap<String, PlaceholderPathNode>()
    private let regexPathNodes = HashMap<String, RegexPathNode>()
    private var starNode: Option<PathNode>
    private var doubleStarNode: Option<PathNode>
    private var end_: Bool
    private var data_: Option<Any>

    init() {
        this(String.empty, None<PathNode>, None<PathNode>, None<PathNode>, false, None<Any>)
    }
    init(name: String, prev: PathNode) {
        this(name, prev, None<PathNode>, None<PathNode>, false, None<Any>)
    }
    init(name: String, prev: PathNode, starNode: PathNode, doubleStarNode: PathNode) {
        this(name, prev, starNode, doubleStarNode, false, None<Any>)
    }
    init(name: String, prev: PathNode, starNode: PathNode, doubleStarNode: PathNode, end: Bool) {
        this(name, prev, starNode, doubleStarNode, end, None<Any>)
    }
    init(name: String, prev: PathNode, starNode: PathNode, doubleStarNode: PathNode, data: Any) {
        this(name, prev, starNode, doubleStarNode, true, data)
    }
    init(name: String, prev: PathNode, end: Bool) {
        this(name, prev, None<PathNode>, None<PathNode>, end, None<Any>)
    }
    init(name: String, prev: PathNode, data: Any) {
        this(name, prev, None<PathNode>, None<PathNode>, true, data)
    }
    private init(
        name: String,
        prev: Option<PathNode>,
        starNode: Option<PathNode>,
        doubleStarNode: Option<PathNode>,
        end: Bool,
        data: Option<Any>
    ) {
        this.name = name
        this.prev = prev
        this.starNode = starNode
        this.doubleStarNode = doubleStarNode
        this.end_ = end
        this.data_ = data
    }

    func getSub(name: String): Option<PathNode> {
        return subs.get(name)
    }
    func getComplexNode(value: String, current: Option<PathNode>): Option<PathNode> {
        if (complexPathNodes.isEmpty()) {
            return None<PathNode>
        }
        let iterator = complexPathNodes.values().iterator()
        var node = None<PathNode>
        if (current.isNone() || !(current.getOrThrow() is ComplexPathNode)) {
            for (n in iterator) {
                node = n
                if (node.matches(value)) {
                    return node
                }
            }
        } else {
            while (current != node && let Some(n) <- iterator.next()) {
                node = n
            }
            for (n in iterator) {
                node = n
                if (node.matches(value)) {
                    return node
                }
            }
        }
        return None<PathNode>
    }
    func getRegexPlaceholderNode(value: String, current: Option<PathNode>): Option<PathNode> {
        if (regexPlaceholderPathNodes.isEmpty()) {
            return None<PathNode>
        }
        let iterator = regexPlaceholderPathNodes.values().iterator()
        var node: PathNode = NonePathNode.INSTANCE
        let cur = current ?? node
        if (!(cur is PlaceholderRegexPathNode)) {
            for (n in iterator) {
                node = n
                if (node.matches(value)) {
                    return node
                }
            }
        } else {
            while (let Some(n) <- iterator.next() && cur != node) {
                node = n
            }
            for (n in iterator) {
                node = n
                if (node.matches(value)) {
                    return node
                }
            }
        }
        return None<PathNode>
    }
    func getPlaceholderNode(current: Option<PathNode>): Option<PathNode> {
        if (placeholderPathNodes.isEmpty()) {
            return None<PathNode>
        }
        let iterator = placeholderPathNodes.values().iterator()
        if (current.isNone() || !(current.getOrThrow() is PlaceholderPathNode)) {
            return iterator.next().getOrThrow()
        }
        for (n in iterator) {
            if (n == current) {
                match (iterator.next()) {
                    case Some(x) => return x
                    case _ => continue
                }
            }
        }
        return None<PathNode>
    }
    func getRegexNode(name: String): Option<PathNode> {
        for (n in regexPathNodes.values()) {
            if (n.matches(name)) {
                return n
            }
        }
        return None<PathNode>
    }
    func getStarNode(): Option<PathNode> {
        return starNode
    }
    func getDoubleStarNode(): Option<PathNode> {
        return doubleStarNode
    }
    func appendSub(name: String): Option<PathNode> {
        match (subs.get(name)) {
            case Some(x) => x
            case _ =>
                let node = SubPathNode(name, this)
                subs.addIfAbsent(name, node)
                node
        }
    }
    func appendRegexNode(name: String, protogenesis: Bool): Option<PathNode> {
        match (regexPathNodes.get(name)) {
            case Some(x) => x
            case _ =>
                let node = RegexPathNode(name, protogenesis, this)
                regexPathNodes.addIfAbsent(name, node)
                node
        }
    }
    func createPlaceholderRegexNodeIfAbsent(name: String, reg: String, protogenesis: Bool): Option<PathNode> {
        match (regexPlaceholderPathNodes.get(name)) {
            case Some(x) => x
            case _ =>
                let node = PlaceholderRegexPathNode(name, reg, protogenesis, this)
                regexPlaceholderPathNodes.addIfAbsent(name, node)
                node
        }
    }
    func createStarNodeIfAbsent(): Option<PathNode> {
        if (starNode.isNone()) {
            starNode = StarPathNode(this)
        }
        return starNode
    }
    func createDoubleStarNodeIfAbsent(): Option<PathNode> {
        if (doubleStarNode.isNone()) {
            doubleStarNode = DoubleStarPathNode(this)
        }
        return doubleStarNode
    }
    func createPlaceholderNodeIfAbsent(name: String): Option<PathNode> {
        match (placeholderPathNodes.get(name)) {
            case Some(x) => x
            case _ =>
                let node = PlaceholderPathNode(name, this)
                placeholderPathNodes.addIfAbsent(name, node)
                node
        }
    }
    func createComplexPathNode(name: String): Option<PathNode> {
        match (complexPathNodes.get(name)) {
            case Some(x) => x
            case _ =>
                let node = ComplexPathNode(name, this)
                complexPathNodes.addIfAbsent(name, node)
                node
        }
    }
    func appendSubPathNode(name: String): Option<PathNode> {
        match (name) {
            case "*" => this.createStarNodeIfAbsent()
            case "**" => this.createDoubleStarNodeIfAbsent()
            case _ =>
                if (#"^\{#regex:.+\}$"#.regex(solid: true).matches(name)) {
                    let idx = (name.indexOf(":") ?? -1) + 1
                    let n = name[idx..name.size - 1]
                    this.appendRegexNode(n, true)
                } else if (#"^\{[a-zA-Z_]+\w*:.+\}$"#.regex(solid: true).matches(name)) {
                    let idx = name.indexOf(":") ?? -1
                    let reg = name[idx + 1..name.size - 1]
                    let n = name[1..idx]
                    this.createPlaceholderRegexNodeIfAbsent(n, reg, true)
                } else if (#"^\{[a-zA-Z_]+\w*\}$"#.regex(solid: true).matches(name)) {
                    return this.createPlaceholderNodeIfAbsent(name[1..name.size - 1])
                } else if (#'^(.*?)\{(.+?)\}(.*?)$'#.regex(solid: true).matches(name)) {
                    return this.createComplexPathNode(name)
                } else if (name.contains("*") || name.contains("?")) {
                    return this.appendRegexNode(name, false)
                } else {
                    return this.appendSub(name)
                }
        }
    }
    mut prop end: Bool {
        get() {
            end_
        }
        set(value) {
            end_ = value
        }
    }
    func data(data: Any): Unit {
        this.data_ = data
    }
    func setDataIfNone(anyway: Bool, supplier: () -> Any): Any {
        if (anyway || this.data_.isNone()) {
            this.data_ = supplier()
        }
        this.data_.getOrThrow()
    }
    func data<T>(): Option<T> {
        match (data_) {
            case Some(x) => x as T
            case _ => None<T>
        }
    }
    protected open operator func ==(o: Any): Bool {
        match (o) {
            case x: PathNode => refEq(this, x) || name == x.name
            case x: String => name == x
            case opt: Option<PathNode> => match (opt) {
                case Some(x) => refEq(this, x) || name == x.name
                case _ => false
            }
            case opt: Option<String> => match (opt) {
                case Some(x) => name == x
                case _ => false
            }
            case _ => false
        }
    }
    public operator func ==(node: PathNode): Bool {
        refEq(this, node) || name == node.name
    }
    public operator func !=(node: PathNode): Bool {
        name != node.name
    }
    protected open func matches(value: String): Bool {
        return this == value
    }
}

class NonePathNode <: PathNode {
    static let INSTANCE: PathNode = NonePathNode()
    private init() {}
    protected operator func ==(o: Any): Bool {
        match (o) {
            case x: Object => refEq(this, x)
            case _ => false
        } || o is NonePathNode || (o as Option<NonePathNode>).isSome()
    }
}
//实路径节点
class SubPathNode <: PathNode {
    init(name: String, prev: PathNode) {
        super(name, prev)
    }
}
//匹配路径节点是*
class StarPathNode <: PathNode {
    init(prev: PathNode) {
        super("*", prev)
    }
    protected operator func ==(o: Any): Bool {
        match (o) {
            case x: Object => refEq(this, x)
            case _ => false
        } || o is PathNode || o is String || (o as Option<DoubleStarPathNode>).isSome() ||
            (o as Option<StarPathNode>).isSome() || (o as Option<RegexPathNode>).isSome() ||
            (o as Option<PlaceholderPathNode>).isSome() || (o as Option<ComplexPathNode>).isSome() ||
            (o as Option<PlaceholderRegexPathNode>).isSome() || (o as Option<SubPathNode>).isSome() ||
            (o as Option<String>).isSome()
    }
}
//匹配路径节点是**
class DoubleStarPathNode <: PathNode {
    public init(prev: PathNode) {
        super("**", prev)
    }
    protected operator func ==(o: Any) {
        match (o) {
            case x: Object => refEq(this, x)
            case _ => false
        } || o is PathNode || o is String || (o as Option<DoubleStarPathNode>).isSome() ||
            (o as Option<StarPathNode>).isSome() || (o as Option<RegexPathNode>).isSome() ||
            (o as Option<PlaceholderPathNode>).isSome() || (o as Option<ComplexPathNode>).isSome() ||
            (o as Option<PlaceholderRegexPathNode>).isSome() || (o as Option<SubPathNode>).isSome() ||
            (o as Option<String>).isSome()
    }
}

open class RegexPathNode <: PathNode {
    private var reg: Regex
    init(name: String, protogenesis: Bool, prev: PathNode) {
        super(name, prev)
        if (protogenesis) {
            var prefix = String.empty
            var suffix = String.empty
            if (!name.startsWith("^")) {
                prefix = "^"
            } else if (!name.endsWith("$")) {
                suffix = "$"
            }
            this.reg = "${prefix}(${name})${suffix}".regex()
        } else {
            let reg = StringGenerator()
            reg.append("^(")
            for (c in name.runes()) {
                match (c) {
                    case r'?' => reg.append(r'.')
                    case r'*' => reg.append(".*")
                    case c => reg.append(c)
                }
            }
            reg.append(")$")
            this.reg = reg.toString().regex()
        }
    }
    protected func matches(name: String) {
        return reg.matches(name)
    }
}

class PlaceholderRegexPathNode <: RegexPathNode {
    init(name: String, reg: String, protogenesis: Bool, prev: PathNode) {
        super(reg, protogenesis, prev)
        super.name = name
    }
}

class PlaceholderPathNode <: PathNode {
    init(name: String, prev: PathNode) {
        super(name, prev)
    }
    protected operator func ==(o: Any): Bool {
        match (o) {
            case x: Object => refEq(this, x)
            case _ => false
        } || o is PlaceholderPathNode || o is String || (o as Option<PlaceholderPathNode>).isSome() ||
            (o as Option<String>).isSome()
    }
    protected func matches(name: String) {
        return this == name
    }
}

class ComplexPathNode <: PathNode {
    private let parts = ArrayList<String>()
    private let reg = #'(.*?)\{(.+?)\}(.*?)'#.regex(solid: true)
    init(name: String, prev: PathNode) {
        super(name, prev)
        for (md in reg.lazyFindAll(name, group: true)) {
            parts.add(md.matchString(1))
            parts.add(md.matchString(2))
        }
    }

    protected func matches(value: String): Bool {
        reg.matches(value)
    }

    func extract(value: String): Map<String, String> {
        let datas = HashMap<String, String>()
        var start = 0
        for (i in 0..parts.size : 2) {
            let p = parts[i]
            if (start == 0) {
                start = if(let Some(idx) <- value.indexOf(p)){
                    idx + p.size
                } else {
                    datas.clear()
                    return datas
                }
            } 
            let end = if (i + 2 < parts.size) {
                if(let Some(idx) <- value.indexOf(parts[i + 2], start)){
                    idx
                }else{
                    datas.clear()
                    return datas
                }
            } else {
                value.size
            }
            datas[parts[i + 1]] = value[start..end]
            start = end + parts[i + 2].size
        }
        return datas
    }
}

enum Mode {
    | MATCHING
    | EXTRACTION
    | PREFIX

    private operator func ==(mode: Mode) {
        match ((this, mode)) {
            case (MATCHING, MATCHING) | (EXTRACTION, EXTRACTION) | (PREFIX, PREFIX) => true
            case _ => false
        }
    }
    func matching(): Bool {
        return this == MATCHING
    }
    func extraction(): Bool {
        return this == EXTRACTION
    }
    func prefix(): Bool {
        return this == PREFIX
    }
}
