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
package f_regex

public import std.regex.*
import std.collection.ArrayList
import std.convert.Parsable
import f_base.*
import f_exception.UnreachableException
import f_cache.HeapCache
import f_regex.exception.RegexBuilderException

public interface ExtendRegex {
    static prop INTEGER: Regex
    static prop DECIMAL: Regex
    static prop REAL_NUMBER: Regex
    static prop EMAIL: Regex
    static prop DURATION: Regex
    static prop IDENTIFIER: Regex
    static prop BASE64: Regex
    static func wildcard(wildcard: String): Regex
    static func builder(): RegexBuilder
    static func builder(callback: (RegexBuilder) -> Unit): Regex
    func doReplace(input: String, replacement!: String, index!: Int64): String
    func doReplaceAll(input: String, replacement!: String, index!: Int64): String
    func doReplaceAll(input: String, replacement!: (MatchData) -> ?String, index!: Int64): String
}

extend Regex <: ExtendRegex {
    public static prop INTEGER: Regex {
        get() {
            #"^[\+-]?\d+$"#.regex(solid: true)
        }
    }
    public static prop DECIMAL: Regex {
        get() {
            #"^[\+-]?\d+\.\d+$"#.regex(solid: true)
        }
    }
    public static prop REAL_NUMBER: Regex {
        get() {
            #"^[\+-]?\d+(\.\d*)?$"#.regex(solid: true)
        }
    }
    public static prop EMAIL: Regex {
        get() {
            #"^[\w-]+@[\w-]+(\.[\w-]+)+$"#.regex(solid: true)
        }
    }
    public static prop DURATION: Regex {
        get() {
            #"^-?((\d+)(d|h|m|s|ms|us|ns))+$"#.regex(solid: true)
        }
    }
    public static prop IDENTIFIER: Regex {
        get() {
            #"^_*[a-zA-Z]+\w*$"#.regex(solid: true)
        }
    }
    public static prop BASE64: Regex {
        get() {
            '^([+a-zA-Z0-9/]{4})+([+a-zA-Z0-9/]{2}==|[+a-zA-Z0-9/]{3}=)?$'.regex(solid: true)
        }
    }
    public static func wildcard(wildcard: String): Regex {
        '^${wildcard}$'
            .replace('.', '\\.')
            .replace('\\.\\.', '(\\.\\w+)#\\.')
            .replace('\\.*\\.', '\\.\\w+\\.')
            .replace('*', '\\w*')
            .replace('?', '\\w?')
            .replace('(\\.\\w+)#\\.', '(\\.\\w+)*\\.')
            .regex()
    }

    public static func builder(): RegexBuilder {
        RegexBuilder()
    }
    public static func builder(callback: (RegexBuilder) -> Unit): Regex {
        var builder = builder()
        callback(builder)
        builder.build()
    }

    public func doReplace(input: String, replacement!: String = '', index!: Int64 = 0): String {
        let sub = input[index..]
        if (let Some(md) <- this.find(sub, group: true)) {
            let rr = RegexReplacement(replacement)
            let pos = md.matchPosition()
            return '${input[0..index]}${sub[0..pos.start]}${rr.format(md)}${sub[pos.end..]}'
        }
        input
    }
    public func doReplaceAll(input: String, replacement!: String = '', index!: Int64 = 0): String {
        let sub = input[index..]
        let mds = this.findAll(sub, group: true)
        if (mds.size > 0) {
            let rr = RegexReplacement(replacement)
            let builder = StringGenerator()
            builder.append(input[0..index])
            var prevEnd = 0
            for (md in mds) {
                let pos = md.matchPosition()
                builder.append(sub[prevEnd..pos.start])
                builder.append(rr.format(md))
                prevEnd = pos.end
            }
            builder.append(sub[prevEnd..])
            return builder.toString()
        }
        input
    }
    public func doReplaceAll(input: String, replacement!: (MatchData) -> ?String = {md => ''}, index!: Int64 = 0) {
        let sub = input[index..]
        let mds = this.findAll(sub, group: true)
        if (mds.size > 0) {
            let builder = StringGenerator()
            builder.append(input[0..index])
            var prevEnd = 0
            for (md in mds) {
                let pos = md.matchPosition()
                builder.append(sub[prevEnd..pos.start])
                builder.append(replacement(md) ?? md.matchString())
                prevEnd = pos.end
            }
            builder.append(sub[prevEnd..])
            return builder.toString()
        }
        input
    }
}

public struct RegexReplacement {
    private let parts = ArrayList<Any>()
    public init(replacement: String) {
        let part = StringGenerator()
        var placeholder = false
        for (ch in replacement.runes()) {
            match (ch) {
                case r'$' =>
                    if (part.size > 0) {
                        parts.add(part.toString())
                        part.reset()
                    }
                    placeholder = true
                case _ where placeholder && ch >= r'0' && ch <= r'9' => part.append(ch)
                case _ where placeholder =>
                    if (part.size > 0) {
                        let idx = Int64.parse(part.toString())
                        parts.add(idx)
                        part.reset()
                    } else {
                        parts.add("$")
                    }
                    placeholder = false
                case _ => part.append(ch)
            }
        }
        if (replacement.endsWith("$")) {
            parts.add("$")
        } else if (part.size > 0) {
            parts.add(part.toString())
        }
    }
    func format(data: MatchData): String {
        let builder = StringGenerator()
        for (i in 0..parts.size) {
            match (parts[i]) {
                case x: String => builder.append(x)
                case x: Int64 => builder.append(data.matchString(x))
                case _ => throw UnreachableException()
            }
        }
        builder.toString()
    }
}
