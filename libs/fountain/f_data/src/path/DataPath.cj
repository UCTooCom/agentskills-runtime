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
package f_data.path

import std.ast.{cangjieLex, Tokens, Token, TokenKind}
import std.collection.{ArrayList, LinkedList, HashSet}
import std.convert.Parsable
import std.reflect.*
import f_base.*
import f_macros.*
import f_data.exception.DataException
public import f_data.*

/**
 * $                根元素
 * @                当前元素
 * .                子元素
 * ..               递归下降，
 * *                当前节点的所有元素
 * []               大于等于1个子元素，可以是数组索引或对象元素名
 * [,]              多个子元素用,分隔
 * [start:end:step] 数组区间，step可省略，step默认是1
 * ?()              过滤表达式
 *
 * min()            数组最小值
 * max()            数组最大值
 * avg()            数组平均值
 * stddev()         数组标准差，未实现
 * length()         数组长度
 *
 * ==               相等
 * !=               不相等
 * <                小于
 * <=               小于等于
 * >                大于
 * >=               大于等于
 * =~               左侧是否匹配右侧的正则
 * in               左侧是否存在于右侧的数组、左侧的字符串是不是右侧对象的key或属性名
 * nin              in的相反运算
 * anyof            左侧与右侧的交集数是否大于零，左侧是单值是认为是只有一个值的集合。
 *                  如果左侧是字符串，右侧是map或对象则判断左侧是否右侧key的子集或是否右侧对象属性的子集
 * subsetof         左侧与右侧的交集数是否等于左侧数
 * nooneof          左侧与右侧的交集数是否等于零
 * size             左侧集合长度或字符串长度或map大小或对象属性数是否等于右侧指定的整数
 *
 * && || !          逻辑与、逻辑或、逻辑非
 * [?(@.age =~ /\d+/)]
 */
abstract sealed class DataPath <: DataPathNode {
    private let nodes = ArrayList<DataPathNode>()

    init() {}
    public static func solid(path: String): DataPath {
        SolidDataPath.compile(path)
    }
    public static func cache(path: String): DataPath {
        CacheDataPath.compile(path)
    }
    func doCompile(path: String, solid: Bool): DataPath {
        if (!(path.startsWith('$.') || path.startsWith('$['))) {
            throw DataException('data path must be starts with \"$.\" or \"$[\", but it is ${path}')
        }
        doCompile(cangjieLex(path, true), solid)
    }
    private func extractSubPathInSquares(path: Tokens, index: Int64): (Tokens, Int64) {
        var parens = 0
        var end = -1
        for (i in index..path.size) {
            let t = path[i]
            match (t.kind) {
                case LSQUARE => parens++
                case RSQUARE =>
                    parens--
                    if (parens == 0) {
                        end = i
                        break
                    }
                case _ => continue
            }
        }
        if (end < 0) {
            throw DataException('squares are not match after ${index} in data path ${path}')
        }
        (path[index + 1..end], end)
    }
    private func compileSubInSquares(sub: Tokens) {
        match (sub[0].kind) {
            case STRING_LITERAL | SINGLE_QUOTED_STRING_LITERAL | IDENTIFIER => SubPathNode(sub[0].value)
            case _ => throw DataException('sub expression in squares can only be string literal or identifier')
        }
    }
    private func compileIndexInSquares(sub: Tokens) {
        let idx = Int64.parse(sub[0].value)
        if (idx < 0) {
            throw DataException('sub expression as an index must greater than or equals to zero')
        }
        IndexPathNode(idx)
    }
    private func compileSubsInSquares(sub: Tokens) {
        let names = ArrayList<String>()
        for (t in sub) {
            let n = match (t.kind) {
                case STRING_LITERAL | SINGLE_QUOTED_STRING_LITERAL | IDENTIFIER => t.value
                case COMMA => continue
                case _ => throw DataException(
                    'sub expression in squares as multi-names can only be string literal, identifier and comma, but current are ${sub}')
            }
            names.add(n)
        }
        MultiSubPathNode(names.unsafeData())
    }
    private func compileIndexesInSquares(sub: Tokens): DataPathNode {
        let list = ArrayList<Int64>()
        var range = 0
        var comma = 0
        for (i in 0..sub.size) {
            let t = sub[i]
            match (t.kind) {
                case INT64 =>
                    let idx = Int64.parse(t.value)
                    if (idx < 0) {
                        throw DataException('sub expression as an index must greater than or equals to zero')
                    }
                    list.add(idx)
                case COLON =>
                    range++
                    if (range > 2) {
                        throw DataException(
                            'sub expression in squares as a int range must be int1:int2:int3 or int1:int2')
                    } else if (comma > 0) {
                        throw DataException('sub expression in squares cannot be with comma and colon at the same time')
                    }
                case COMMA =>
                    comma++
                    if (range > 0) {
                        throw DataException('sub expression in squares cannot be with comma and colon at the same time')
                    }
                case _ => throw DataException(
                    'sub expression in squares must be all strings or int64 or int1:int2:int3 or int1:int2')
            }
        }
        match (range) {
            case 0 => MultiIndexPathNode(list.toArray())
            case 1 =>
                if (list[0] >= list[1]) {
                    throw DataException('sub expression as an int range, range start must be greater than end')
                }
                RangePathNode(list[0]..list[1])
            case 2 =>
                if (list[0] >= list[1] || list[2] <= 0) {
                    throw DataException(
                        'sub expression as an int range, range start must be greater than end and step must be greater than zero')
                }
                RangePathNode(list[0]..list[1] : list[2])
            case _ => throw UnreachableException()
        }
    }
    private func parseFilterTokens(sub: Tokens, solid: Bool): Tokens {
        var tokens = quote()
        var i = 0
        while (i < sub.size) {
            let t = sub[i]
            match (t.kind) {
                case LPAREN =>
                    var parens = 0
                    var end = -1
                    for (e in i..sub.size) {
                        match (sub[e].kind) {
                            case LPAREN => parens++
                            case RPAREN =>
                                parens--
                                if (parens == 0) {
                                    end = e
                                    break
                                }
                            case _ => continue
                        }
                    }
                    if (end <= i) {
                        throw DataException('illegal filter expression for data path, ${sub}')
                    }
                    tokens += `lparen` + parseFilterTokens(sub[i..end], solid) + `rparen`
                case AT => for (e in i..sub.size) {
                    let t = sub[e]
                    match (t.kind) {
                        case EQUAL where sub[e + 1].kind == STRING_LITERAL || sub[e + 1].kind == SINGLE_QUOTED_STRING_LITERAL =>
                            tokens += quote(EqFilter<String>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case EQUAL where sub[e + 1].kind == INT64 =>
                            tokens += quote(EqFilter<Int64>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case EQUAL where sub[e + 1].kind == FLOAT64 =>
                            tokens += quote(EqFilter<Float64>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case EQUAL where sub[e + 1].kind == BOOL_LITERAL =>
                            tokens += quote(EqFilter<Bool>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case NOTEQ where sub[e + 1].kind == STRING_LITERAL || sub[e + 1].kind == SINGLE_QUOTED_STRING_LITERAL =>
                            tokens += quote(NotEqFilter<String>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case NOTEQ where sub[e + 1].kind == INT64 =>
                            tokens += quote(NotEqFilter<Int64>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case NOTEQ where sub[e + 1].kind == FLOAT64 =>
                            tokens += quote(NotEqFilter<Float64>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case NOTEQ where sub[e + 1].kind == BOOL_LITERAL =>
                            tokens += quote(NotEqFilter<Bool>($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case LT where sub[e + 1].kind == STRING_LITERAL || sub[e + 1].kind ==SINGLE_QUOTED_STRING_LITERAL =>
                            tokens += quote(CmpFilter<String>($(sub[i .. e].toString()), $(sub[e + 1].value), 'LT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case LT where sub[e + 1].kind == INT64 =>
                            tokens += quote(CmpFilter<Int64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'LT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case LT where sub[e + 1].kind == FLOAT64 =>
                            tokens += quote(CmpFilter<Float64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'LT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case GT where sub[e + 1].kind == STRING_LITERAL || sub[e + 1].kind == SINGLE_QUOTED_STRING_LITERAL =>
                            tokens += quote(CmpFilter<String>($(sub[i .. e].toString()), $(sub[e + 1].value), 'GT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case GT where sub[e + 1].kind == INT64 =>
                            tokens += quote(CmpFilter<Int64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'GT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case GT where sub[e + 1].kind == FLOAT64 =>
                            tokens += quote(CmpFilter<Float64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'GT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case LE where sub[e + 1].kind == STRING_LITERAL || sub[e + 1].kind == SINGLE_QUOTED_STRING_LITERAL =>
                            tokens += quote(CmpFilter<String>($(sub[i .. e].toString()), $(sub[e + 1].value), 'LT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case LE where sub[e + 1].kind == INT64 =>
                            tokens += quote(CmpFilter<Int64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'LT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case LE where sub[e + 1].kind == FLOAT64 =>
                            tokens += quote(CmpFilter<Float64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'LT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case GE where sub[e + 1].kind == STRING_LITERAL || sub[e + 1].kind == SINGLE_QUOTED_STRING_LITERAL =>
                            tokens += quote(CmpFilter<String>($(sub[i .. e].toString()), $(sub[e + 1].value), 'GT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case GE where sub[e + 1].kind == INT64 =>
                            tokens += quote(CmpFilter<Int64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'GT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case GE where sub[e + 1].kind == FLOAT64 =>
                            tokens += quote(CmpFilter<Float64>($(sub[i .. e].toString()), $(sub[e + 1].value), 'GT', 'false', $(solid.toString())))
                            i = e + 1
                            break
                        case ASSIGN where sub[e + 1].kind == BITNOT && sub[e + 2].kind == DIV =>
                            let rs = e + 2
                            var re = rs + 1
                            for (e in re..sub.size where sub[e].kind == DIV) {
                                re = e
                                break
                            }
                            if (rs + 1 == re || sub[re].kind != DIV) {
                                throw DataException('illegal regex in data path filter ${sub}')
                            }
                            if (sub[re + 1].kind == IDENTIFIER && sub[re + 1].value == 'i') {
                                re++
                            }
                            tokens += quote(RegexFilter($(sub[i .. e].toString()), $(sub[rs ..= re].toString()), $(solid.toString())))
                            i = re
                            break
                        case IN where sub[e + 1].kind == LSQUARE =>
                            let (t, e) = parseSetOp(sub, i, e, quote(InFilter), solid)
                            tokens += t
                            i = e
                        case IDENTIFIER where t.value == 'nin' && sub[e + 1].kind == LSQUARE =>
                            let (t, e) = parseSetOp(sub, i, e, quote(NinFilter), solid)
                            tokens += t
                            i = e
                        case IDENTIFIER where t.value == 'anyof' && sub[e + 1].kind == LSQUARE =>
                            let (t, e) = parseSetOp(sub, i, e, quote(AnyOfFilter), solid)
                            tokens += t
                            i = e
                        case IDENTIFIER where t.value == 'subsetof' && sub[e + 1].kind == LSQUARE =>
                            let (t, e) = parseSetOp(sub, i, e, quote(SubSetOfFilter), solid)
                            tokens += t
                            i = e
                        case IDENTIFIER where t.value == 'nooneof' && sub[e + 1].kind == LSQUARE =>
                            let (t, e) = parseSetOp(sub, i, e, quote(NoOneOfFilter), solid)
                            tokens += t
                            i = e
                        case IDENTIFIER where t.value == 'size' && sub[e + 1].kind == INT64 =>
                            tokens += quote(SizeFilter($(sub[i .. e].toString()), $(sub[e + 1].value), $(solid.toString())))
                            i = e + 1
                            break
                        case _ => throw DataException('filter in data path ${sub} is illegal')
                    }
                }
                case BITAND where i > 0 => tokens += `bitand`
                case BITOR where i > 0 => tokens += `bitor`
                case _ => throw DataException('filter in data path ${sub} is illegal')
            }
            i++
        }
        tokens
    }
    private func parseSetOp(sub: Tokens, i: Int64, e: Int64, filter: Tokens, solid: Bool): (Tokens, Int64) {
        let arrs = e + 1
        var arre = arrs + 1
        for (e in arre..sub.size where sub[e].kind == RSQUARE) {
            arre = e
            break
        }
        if (arrs + 1 == arre || sub[arre].kind == RSQUARE) {
            throw DataException('illegal array in data path filter ${sub} for in expression')
        }
        let tokens = match (sub[arrs + 1].kind) {
            case STRING_LITERAL | SINGLE_QUOTED_STRING_LITERAL => quote($(filter)<String>($(sub[i .. e].toString()), $(sub[arrs ..= arre].toString()), $(solid.toString())))
            case INT64 => quote($(filter)<Int64>($(sub[i .. e].toString()), $(sub[arrs ..= arre].toString()), $(solid.toString())))
            case FLOAT64 => quote($(filter)<Float64>($(sub[i .. e].toString()), $(sub[arrs ..= arre].toString()), $(solid.toString())))
            case _ => throw DataException('illegal array element type in data path filter ${sub} for in expression')
        }
        (tokens, arre)
    }
    private func compileFilter(sub: Tokens, solid: Bool) {
        let tokens = parseFilterTokens(sub, solid)
        let expr = parseExpr(tokens)
        DataFilterPathNode(compileFilter(expr))
    }
    private func compileFilter(expr: Expr): DataFilter {
        //EqFilter<> NotEqFilter<> CmpFilter<> RegexFilter 
        //InFilter<> NinFilter<> AnyOfFilter<> SubSetOfFilter<> NoOneOfFilter<>
        //SizeFilter
        //CallExpr ParenExpr BinaryExpr UnaryExpr
        func arg(args: Tokens, index: Int64) {
            args[index].value
        }
        match (expr) {
            case x: CallExpr =>
                let tokens = x.toTokens()
                let filter = tokens[0].value
                let generic = tokens[2].value
                let args = tokens[if (filter == 'RegexFilter' || filter == 'SizeFilter') {
                        2
                    } else {
                        5
                    }..tokens.size - 1]
                match ((filter, generic)) {
                    case ('EqFilter', 'String') => EqFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('EqFilter', 'Int64') => EqFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('EqFilter', 'Float64') => EqFilter<Float64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('EqFilter', 'Bool') => EqFilter<Bool>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NotEqFilter', 'String') => NotEqFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NotEqFilter', 'Int64') => NotEqFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NotEqFilter', 'Float64') => NotEqFilter<Float64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NotEqFilter', 'Bool') => NotEqFilter<Bool>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('CmpFilter', 'String') => CmpFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2),
                        arg(args, 3), arg(args, 4))
                    case ('CmpFilter', 'Int64') => CmpFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2),
                        arg(args, 3), arg(args, 4))
                    case ('CmpFilter', 'Float64') => CmpFilter<Float64>(arg(args, 0), arg(args, 1), arg(args, 2),
                        arg(args, 3), arg(args, 4))
                    case ('RegexFilter', _) => RegexFilter(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('InFilter', 'String') => InFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('InFilter', 'Int64') => InFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('InFilter', 'Float64') => InFilter<Float64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NinFilter', 'String') => NinFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NinFilter', 'Int64') => NinFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NinFilter', 'Float64') => NinFilter<Float64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('AnyOfFilter', 'String') => AnyOfFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('AnyOfFilter', 'Int64') => AnyOfFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('AnyOfFilter', 'Float64') => AnyOfFilter<Float64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('SubSetOfFilter', 'String') => SubSetOfFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('SubSetOfFilter', 'Int64') => SubSetOfFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('SubSetOfFilter', 'Float64') => SubSetOfFilter<Float64>(arg(args, 0), arg(args, 1),
                        arg(args, 2))
                    case ('NoOneOfFilter', 'String') => NoOneOfFilter<String>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NoOneOfFilter', 'Int64') => NoOneOfFilter<Int64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('NoOneOfFilter', 'Float64') => NoOneOfFilter<Float64>(arg(args, 0), arg(args, 1), arg(args, 2))
                    case ('SizeFilter', _) => SizeFilter(arg(args, 0), arg(args, 1), arg(args, 2))
                    case _ => throw DataException('unreachable ${tokens}')
                }
            case x: ParenExpr => compileFilter(x.parenthesizedExpr)
            case x: UnaryExpr where x.op.kind == NOT => !compileFilter(x.expr)
            case x: BinaryExpr where x.op.kind == BITAND => compileFilter(x.leftExpr) & compileFilter(x.rightExpr)
            case x: BinaryExpr where x.op.kind == BITOR => compileFilter(x.leftExpr) | compileFilter(x.rightExpr)
            case _ => throw DataException('unreachable ${expr.toTokens()}')
        }
    }
    private func compileInSquares(sub: Tokens, solid: Bool) {
        if (sub.size == 1 && (sub[0].kind == STRING_LITERAL || sub[0].kind == SINGLE_QUOTED_STRING_LITERAL)) {
            compileSubInSquares(sub)
        } else if (sub.size == 1 && sub[0].kind == INT64) {
            compileIndexInSquares(sub)
        } else if (sub.size > 1 && (sub[0].kind == STRING_LITERAL || sub[0].kind == SINGLE_QUOTED_STRING_LITERAL)) {
            compileSubsInSquares(sub)
        } else if (sub.size > 1 && sub[0].kind == INT64) {
            compileIndexesInSquares(sub)
        } else if (sub.size > 1 && sub[0].kind == QUEST && sub[1].kind == LPAREN && sub[sub.size - 1].kind == RPAREN) {
            compileFilter(sub[2..sub.size - 1], solid)
        } else {
            throw DataException('sub path ${sub} is illegal')
        }
    }
    private func doCompile(path: Tokens, solid: Bool): DataPath {
        var i = 0
        while (i < path.size) {
            let node = if (i == 0 && path[i].kind == DOLLAR) {
                RootPathNode.instance
            } else if (path[i].kind == DOT && path[i + 1].kind == IDENTIFIER) {
                i++
                SubPathNode(path[i].value)
            } else if (path[i].kind == DOT && path[i + 1].kind == MUL) {
                i++
                AnySubPathNode.instance
            } else if (path[i].kind == DOT && path[i + 1].kind == DOT) {
                RecursiveDescentPathNode.instance
            } else if (path[i].kind == DOT && path[i + 1].kind == LSQUARE && path[i - 1].kind == DOT) {
                let (sub, index) = extractSubPathInSquares(path, i + 1)
                i = index
                compileInSquares(sub, solid)
            } else if (path[i].kind == LSQUARE && (path[i - 1].kind == IDENTIFIER || path[i - 1].kind == DOLLAR ||
                path[i - 1].kind == AT || path[i - 1].kind == RSQUARE)) {
                let (subPath, index) = extractSubPathInSquares(path, i)
                i = index
                compileInSquares(sub, solid)
            } else if (i == 0 && path[i].kind == AT) {
                CurrentPathNode.instance
            } else if (path[i].kind == DOT && path[i + 1].kind == IDENTIFIER && path[i + 2].kind == LPAREN &&
                path[i + 3].kind == RPAREN) {
                let node: DataPathNode = match (path[i + 1].value) {
                    case 'min' => MinPathNode.instance
                    case 'max' => MaxPathNode.instance
                    case 'avg' => AvgPathNode.instance
                    case 'length' => LengthPathNode.instance
                    case _ => throw DataException(
                        'data path is illegal at index ${i}, path: ${path}, unsupported function call')
                }
                i += 3
                node
            } else {
                throw DataException('data path is illegal at index ${i}, path: ${path}')
            }
            nodes.add(node)
            i++
        }
        this
    }
    public func get(data: Data): Iterator<Data> {
        var itr: Iterator<Data> = nodes[0].get(data)
        for (i in 1..nodes.size) {
            itr = itr.flatMap<Data> {d => nodes[i].get(d)}
        }
        itr
    }
}
