/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

/**
 * Core of commonmark (implementation of CommonMark for parsing markdown and rendering to HTML)
 */
package commonmark4cj.commonmark

internal import std.collection.{ArrayList, HashMap, HashSet, Map, EquatableCollection, Set, LinkedList, map, collectString, collectHashSet}
internal import std.convert.*
internal import std.io.{StringReader, InputStream, IOException}
internal import std.regex.{Regex, RegexFlag, MatchData, Position, Matcher}
internal import std.unicode.*

extend<T> Option<T> {
    operator func ()(): T {
        this.getOrThrow()
    }
}

extend<T> Option<T> where T <: Equatable<T> {
    operator func ==(other: T): Bool {
        match (this) {
            case Some(v) => v == other
            case _ => false
        }
    }
    operator func !=(other: T): Bool {
        match (this) {
            case Some(v) => v != other
            case _ => true
        }
    }
}

let NULL_CHAR: Rune = '\u{0}'
let EMPTY_STRING: String = ""
let EMPTY_MAP: HashMap<String, String> = HashMap()
let STRINGBUILDER_CAPACITY: Int64 = 256

type CharSequence = String