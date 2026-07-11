/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq4cj.client.util

public class URLSupport {
    public static func parseQuery(query: String): HashMap<String, ?String> {
        let map = HashMap<String, ?String>()

        let array = query.split("&", removeEmpty: true)
        for (param in array) {
            let p = param.indexOf("=")
            if (let Some(p) <- p) {
                let name = param[0..p]
                let value = param[(p + 1)..param.size]
                map.add(name, value)
            } else {
                map.add(param, None)
            }
        }
        return map
    }

    /**
     * 解析url携带的参数和对应的值，以HashMap返回
     */
    public static func parseQuery(url: URL): HashMap<String, ?String> {
        let map = HashMap<String, ?String>()
        if (let Some(query) <- url.query) {
            return parseQuery(query)
        }
        return map
    }

    public static func createRemainingURI(originalURL: URL, params: HashMap<String, ?String>): URL {
        return createURIWithQuery(originalURL, createQueryString(params))
    }

    public static func createURIWithQuery(url: URL, query: ?String): URL {
        var uri = url.toString()
        var questionMark = 0
        if (let Some(questionIndex) <- uri.lastIndexOf("?")) {
            questionMark = questionIndex
            if (let Some(rightBracket) <- uri.lastIndexOf(")")) {
                if (rightBracket > questionMark) {
                    questionMark = -1
                }
            }
        }
        if (questionMark > 0) {
            uri = uri[0..questionMark]
            if (let Some(query) <- query) {
                uri = uri + "?" + query
            }
            return URL.parse(uri)
        }
        return url
    }

    public static func createQueryString(options: HashMap<String, ?String>): ?String {
        if (options.size == 0) {
            return None
        }
        let rc = StringBuilder()
        var first = true
        for ((k, v) in options) {
            if (first) {
                first = false
            } else {
                rc.append("&")
            }
            if (let Some(value) <- v) {
                rc.append("${k}=${value}")
            } else {
                rc.append("${k}=")
            }
        }
        return rc.toString()
    }

    public static func parseComposite(url: URL): CompositeData {
        var componentString: String
        var params: ?String = url.rawQuery

        var rc = CompositeData()
        let ssp = url.opaque.trimAscii()
        if (ssp.count("(") != ssp.count(")")) {
            throw UrlSyntaxException(url.toString(), "Not a matching number of '(' and ')' parenthesis")
        }

        var p: Int64 = 0
        var initialParen = ssp.indexOf("(")
        if (let Some(initialParen) <- initialParen) {
            if (initialParen == 0) {
                p = indexOfParenthesisMatch(ssp, initialParen)
                componentString = ssp[initialParen + 1..p]
            } else {
                componentString = ssp
            }
        } else {
            componentString = ssp
        }

        rc.components = splitComponents(componentString)

        if (let Some(parameters) <- params) {
            var query = parameters
            if (let Some(p) <- parameters.indexOf("?")) {
                query = parameters[p + 1..parameters.size]
            }
            rc.parameters = parseQuery(query)
        }
        return rc
    }

    /**
     * 找到对应括号的位置
     */
    public static func indexOfParenthesisMatch(str: String, first: Int64): Int64 {
        if (first < 0 || first > str.size) {
            throw IllegalArgumentException("Invalid position for first parenthesis: ${first}")
        }
        let charArray = str.toRuneArray()
        if (charArray[0] != r'(') {
            throw IllegalArgumentException("char at indicated position is not a parenthesis")
        }

        var depth = 1
        var index = -1
        for (i in first + 1..charArray.size) {
            if (charArray[i] == r'(') {
                depth++
            }
            if (charArray[i] == r')') {
                depth--
                if (depth == 0) {
                    index = i
                    break
                }
            }
        }

        if (depth > 0) {
            throw UrlSyntaxException(str, "URI did not contain a matching parenthesis.")
        }

        return index
    }

    private static func splitComponents(str: String): Array<String> {
        let l: LinkedList<String> = LinkedList<String>()

        var last = 0
        var depth = 0
        var chars: Array<Rune> = str.toRuneArray()
        for (i in 0..chars.size) {
            match (chars[i]) {
                case '(' => depth++
                case ')' => depth--
                case ',' =>
                    if (depth == 0) {
                        let s = str[last..i]
                        l.addLast(s)
                        last = i + 1
                    }
                case _ => continue
            }
        }

        var s = str[last..str.size]
        if (s.size != 0) {
            l.addLast(s)
        }

        return l.toArray()
    }

    public static func checkURLsEquals(var1: LinkedList<URL>, var2: LinkedList<URL>): Bool {
        if (var1.size != var2.size) {
            return false
        }
        let array1 = var1.toArray()
        let array2 = var2.toArray()
        sort<URL>(
            array1,
            by: {
                e1: URL, e2: URL => URLCompareTo(e1, e2)
            }
        )
        sort<URL>(
            array2,
            by: {
                e1: URL, e2: URL => URLCompareTo(e1, e2)
            }
        )
        for (i in 0..array1.size) {
            if (!checkURLEquals(array1[i], array2[i])) {
                return false
            }
        }
        return true
    }

    private static func URLCompareTo(a: URL, b: URL): Ordering {
        if (a.toString() > b.toString()) {
            return Ordering.LT
        } else if (a.toString() == b.toString()) {
            return Ordering.EQ
        } else {
            return Ordering.GT
        }
    }

    public static func checkURLEquals(var1: ?URL, var2: ?URL): Bool {
        if (let Some(var1) <- var1) {
            if (let Some(var2) <- var2) {
                if (!checkURLEquals(var1, var2)) {
                    return false
                }
            } else {
                return false
            }
        } else {
            if (var2.isSome()) {
                return false
            }
        }

        return true
    }

    public static func checkURLEquals(var1: URL, var2: URL): Bool {
        if (var1.scheme != var2.scheme) {
            return false
        }
        if (var1.hostName != var2.hostName) {
            return false
        }
        if (var1.port != var2.port) {
            return false
        }
        return true
    }

    public static func addExtraQuery(url: URL, extraQuery: ?String): URL {
        var newQuery: ?String = None
        if (let Some(oldQuery) <- url.query) {
            if (let Some(extraQuery) <- extraQuery) {
                newQuery = oldQuery + "&" + extraQuery
            }
        } else {
            if (let Some(extraQuery) <- extraQuery) {
                newQuery = extraQuery
            }
        }
        return url.replace(query: newQuery)
    }
}
