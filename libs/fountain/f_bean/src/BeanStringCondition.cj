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
package f_bean

/**
 * 字符串满足指定条件返回true
 */
public enum StringCond <: Equatable<StringCond> & Equatable<String> & ToString {
    /**
     * 忽略本条件
     */
    | IgnoreCond
    /**
     * 传入on的字符串等于指定字符串
     */
    | Exactly(String)
    /**
     * 传入on的字符串以指定字符串开头
     */
    | Prefix(String)
    /**
     * 传入on的字符串以指定字符串结尾
     */
    | Suffix(String)
    /**
     * 传入on的字符串符合通配规则
     */
    | Wildcard(String)
    /**
     * 传入on的字符串符合指定正则表达式
     */
    | Regexp(String)
    /**
     * 构造器参数是传入on的字符串的子串
     */
    | Contains(String)
    /**
     * 传on的字符串是构造器参数的子串
     */
    | In(String)

    public func toString() {
        match (this) {
            case IgnoreCond => 'IgnoreCond'
            case Exactly(n) => 'Exactly(${n})'
            case Prefix(n) => 'Prefix(${n})'
            case Suffix(n) => 'Suffix(${n})'
            case Wildcard(n) => 'Wildcard(${n})'
            case Regexp(n) => 'Regexp(${n})'
            case Contains(n) => 'Contains(${n})'
            case In(n) => 'In(${n})'
        }
    }

    public func on(s: String): Bool {
        match (this) {
            case IgnoreCond => true
            case Exactly(v) => s == v
            case Prefix(v) => s.startsWith(v)
            case Suffix(v) => s.endsWith(v)
            case Wildcard(v) => Regex.wildcard(v).matches(s)
            case Regexp(v) => v.regex().matches(s)
            case Contains(v) => s.contains(v)
            case In(v) => v.contains(s)
        }
    }
    public prop ignored: Bool {
        get() {
            match (this) {
                case IgnoreCond => true
                case _ => false
            }
        }
    }
    public operator func ==(right: StringCond) {
        match ((this, right)) {
            case (IgnoreCond, IgnoreCond) => true
            case (Exactly(a), Exactly(b)) => a == b
            case (Prefix(a), Prefix(b)) => a == b
            case (Suffix(a), Suffix(b)) => a == b
            case (Wildcard(a), Wildcard(b)) => a == b
            case (Regexp(a), Regexp(b)) => a == b
            case (Contains(a), Contains(b)) => a == b
            case (In(a), In(b)) => a == b
            case _ => false
        }
    }
    public operator func ==(right: String) {
        this == Exactly(right)
    }
}
