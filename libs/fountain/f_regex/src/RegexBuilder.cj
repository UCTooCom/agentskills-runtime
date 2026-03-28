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

import f_base.*
import f_regex.exception.RegexBuilderException
/**
 * Regex.builder.start.digit.oneOrMore.end == ^\d+$
 * Regex.builder{b=>
 * b.start(b.digit_.oneOrMore.greedy).end == ^(\d++)$
 * }
 * _结尾的属性会创建新的RegexBuilder，在新的RegexBuilder添加正则命令，同名没有_结尾的属性不会创建新的RegexBuilder
 * oneOf 就是[Array<ToString>]，区别是oneOf会在新的RegexBuilder添加[...]
 * notOneOf 就是[Bool,Array<ToString>]，区别就是notOneOf会在新的RegexBuilder添加[^...]
 * group(...) 就是(...)，区别是group会在新的RegexBuilder添加(...)
 */
public class RegexBuilder <: ToString & Equatable<RegexBuilder> {
    private var pattern = StringGenerator()

    public operator func ==(other: RegexBuilder) {
        refEq(this, other) || pattern.toString() == other.pattern.toString()
    }

    public func build(flags!: Array<RegexFlag> = [], solid!: Bool = false): Regex {
        return toString().regex(flags: flags, solid: solid)
    }

    public func toString(): String {
        return pattern.toString()
    }
    public prop start: RegexBuilder {
        get() {
            pattern.append(r'^')
            return this
        }
    }
    public prop end: RegexBuilder {
        get() {
            pattern.append(r'$')
            return this
        }
    }
    public prop any: RegexBuilder {
        get() {
            pattern.append(r'.')
            return this
        }
    }
    public prop digit: RegexBuilder {
        get() {
            pattern.append(#"\d"#)
            return this
        }
    }
    public prop notDigit: RegexBuilder {
        get() {
            pattern.append(#"\D"#)
            return this
        }
    }
    public prop whitespace: RegexBuilder {
        get() {
            pattern.append(#" "#)
            return this
        }
    }
    public prop notWhitespace: RegexBuilder {
        get() {
            pattern.append(#"[^ ]"#)
            return this
        }
    }
    public prop blank: RegexBuilder {
        get() {
            pattern.append(#"\s"#)
            return this
        }
    }
    public prop notBlank: RegexBuilder {
        get() {
            pattern.append(#"\S"#)
            return this
        }
    }
    public prop wordChar: RegexBuilder {
        get() {
            pattern.append(#"\w"#)
            return this
        }
    }
    public prop notWordChar: RegexBuilder {
        get() {
            pattern.append(#"\W"#)
            return this
        }
    }
    public prop alphaDigit: RegexBuilder {
        get() {
            pattern.append(#"[0-9a-zA-Z]"#)
            return this
        }
    }
    public prop notAlphaDigit: RegexBuilder {
        get() {
            pattern.append(#"[^0-9a-zA-Z]"#)
            return this
        }
    }
    public prop alpha: RegexBuilder {
        get() {
            pattern.append(#"[a-zA-Z]"#)
            return this
        }
    }
    public prop notAlpha: RegexBuilder {
        get() {
            pattern.append(#"[^a-zA-Z]"#)
            return this
        }
    }
    public prop lowerAlpha: RegexBuilder {
        get() {
            pattern.append(#"[a-z]"#)
            return this
        }
    }
    public prop notLowerAlpha: RegexBuilder {
        get() {
            pattern.append(#"[^a-z]"#)
            return this
        }
    }
    public prop upperAlpha: RegexBuilder {
        get() {
            pattern.append(#"[A-Z]"#)
            return this
        }
    }
    public prop notUpperAlpha: RegexBuilder {
        get() {
            pattern.append(#"[^A-Z]"#)
            return this
        }
    }
    public prop lowerAlphaDigit: RegexBuilder {
        get() {
            pattern.append(#"[0-9a-z]"#)
            return this
        }
    }
    public prop notLowerAlphaDigit: RegexBuilder {
        get() {
            pattern.append(#"[^0-9a-z]"#)
            return this
        }
    }
    public prop upperAlphaDigit: RegexBuilder {
        get() {
            pattern.append(#"[0-9A-Z]"#)
            return this
        }
    }
    public prop notUpperAlphaDigit: RegexBuilder {
        get() {
            pattern.append(#"[^0-9A-Z]"#)
            return this
        }
    }
    public prop boundary: RegexBuilder {
        get() {
            pattern.append(#"\b"#)
            return this
        }
    }
    public prop decimal: RegexBuilder {
        get() {
            pattern.append(#"\d+(\.\d+)?"#)
            return this
        }
    }

    public prop version: RegexBuilder {
        get() {
            pattern.append(#"\d+(\.\d+)+"#)
            return this
        }
    }
    public func text(part: ToString): RegexBuilder {
        pattern.append(part)
        return this
    }
    private func group_(notCapture: Bool, part: ToString): RegexBuilder {
        if (notCapture) {
            return lparan.notCapture.text(part).rparan
        }
        return lparan.text(part).rparan
    }
    public operator func ()(notCapture: Bool, part: ToString): RegexBuilder {
        return group_(notCapture, part)
    }
    public func group(notCapture: Bool, part: ToString): RegexBuilder {
        return RegexBuilder().group_(notCapture, part)
    }
    public operator func ()(part: ToString): RegexBuilder {
        return group_(false, part)
    }
    public func group(part: ToString): RegexBuilder {
        return RegexBuilder().group_(false, part)
    }
    private func group_(dir: SearchDirection, part: ToString): RegexBuilder {
        match (dir) {
            case LOOK_AHEAD => lparan.lookAhead.text(part).rparan
            case LOOK_BEHIND => lparan.lookBehind.text(part).rparan
        }
    }
    public operator func ()(dir: SearchDirection, part: ToString): RegexBuilder {
        group_(dir, part)
    }
    public func group(dir: SearchDirection, part: ToString): RegexBuilder {
        RegexBuilder().group_(dir, part)
    }
    public prop lparan: RegexBuilder {
        get() {
            pattern.append("(")
            return this
        }
    }
    public prop rparan: RegexBuilder {
        get() {
            pattern.append(")")
            return this
        }
    }
    public prop notCapture: RegexBuilder {
        get() {
            pattern.append("?:")
            return this
        }
    }
    public prop lookAhead: RegexBuilder {
        get() {
            pattern.append("?=")
            return this
        }
    }
    public prop notLookAhead: RegexBuilder {
        get() {
            pattern.append('?!')
            this
        }
    }
    public prop lookBehind: RegexBuilder {
        get() {
            pattern.append("?<=")
            return this
        }
    }
    public prop notLookBehind: RegexBuilder {
        get() {
            pattern.append('?<!')
            this
        }
    }

    private func mORn(cmd: Rune): RegexBuilder {
        pattern.append(cmd)
        return this
    }
    public prop zeroOrOne: RegexBuilder {
        get() {
            return mORn(r'?')
        }
    }
    public prop zeroOrMore: RegexBuilder {
        get() {
            return mORn(r'*')
        }
    }
    public prop oneOrMore: RegexBuilder {
        get() {
            return mORn(r'+')
        }
    }

    public prop greedy: RegexBuilder {
        get() {
            let p = pattern.toString()
            if (p.isEmpty()) {
                throw RegexBuilderException("greedy mode must not be following with empty regex")
            }
            let c = p[p.size - 1]
            if (c == b'+' || c == b'*') {
                pattern.append(r'+')
            } else {
                throw RegexBuilderException(
                    "greedy mode must be following with + or *, but the current pattern is ${pattern}")
            }
            return this
        }
    }
    public prop notGreedy: RegexBuilder {
        get() {
            let p = pattern.toString()
            if (p.isEmpty()) {
                throw RegexBuilderException("not greedy mode must not be following with empty regex")
            }
            let c = p[p.size - 1]
            if (c == b'+' || c == b'*') {
                pattern.append(r'?')
            } else {
                throw RegexBuilderException(
                    "greedy mode must be following with + or *, but the current pattern is ${pattern}")
            }
            return this
        }
    }
    public func startRange(min: Int64): RegexBuilder {
        range(min, -1)
    }
    public func endRange(max: Int64): RegexBuilder {
        range(-1, max)
    }
    public func range(min: Int64, max: Int64): RegexBuilder {
        if ((min < 0 && max < 0) || (min > 0 && max > 0 && min < max)) {
            throw RegexBuilderException(
                "min must less or equals to max and both are larger than 0, or one of min and max should be larger than 0 and the other must be ignored")
        }
        pattern.append("{")
        if (min >= 0) {
            pattern.append(min)
        }
        pattern.append(",")
        if (max >= 0) {
            pattern.append(max)
        }
        pattern.append("}")
        return this
    }
    public operator func [](notIn: Bool, parts: Iterable<ToString>): RegexBuilder {
        pattern.append(r'[')
        if (notIn) {
            pattern.append(r'^')
        }
        for (p in parts) {
            pattern.append(p)
        }
        pattern.append(r']')
        return this
    }
    public operator func [](parts: Iterable<ToString>): RegexBuilder {
        return this[false, parts]
    }
    public func oneOf<T>(parts: Iterable<T>): RegexBuilder where T <: ToString {
        return RegexBuilder()[false, parts.iterator().map {p => (p as ToString).getOrThrow()}]
    }
    public func notOneOf<T>(parts: Iterable<T>): RegexBuilder where T <: ToString {
        return RegexBuilder()[true, parts.iterator().map {p => (p as ToString).getOrThrow()}]
    }
    public prop lsquare: RegexBuilder {
        get() {
            pattern.append("[")
            return this
        }
    }
    public prop rsquare: RegexBuilder {
        get() {
            pattern.append("]")
            return this
        }
    }
    public prop notIn: RegexBuilder {
        get() {
            pattern.append("^")
            return this
        }
    }
    public operator func |(part: ToString): RegexBuilder {
        return or.append(part)
    }
    public prop or: RegexBuilder {
        get() {
            pattern.append(r'|')
            return this
        }
    }
    public prop headBlanks: RegexBuilder {
        get() {
            return start.blank.oneOrMore
        }
    }
    public prop tailBlanks: RegexBuilder {
        get() {
            return blank.oneOrMore.end
        }
    }
    public prop headOrTailBlanks: RegexBuilder {
        get() {
            return headBlanks.or.tailBlanks
        }
    }
    private func append(part: ToString): RegexBuilder {
        pattern.append(part.toString())
        return this
    }
}
