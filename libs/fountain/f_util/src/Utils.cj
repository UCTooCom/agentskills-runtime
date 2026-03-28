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

import std.regex.Regex
import std.convert.Parsable
import f_regex.RegexFromString

/**
 * compute parameter such as 123KB 24M etc。 to a UInt64,
 */
public func computeBytes(size: String): Option<Int64> {
    let sizeRegex = #"^(\d+)([kmgtpezyKMGTPEZY]?)[bB]?$"#.regex(solid: true)
    let matched = sizeRegex.find(size, group: true).getOrThrow()
    let num = Int64.parse(matched.matchString(1))
    if (matched.groupCount() >= 2) {
        let unit = matched.matchString(2)
        return computeBytes(num, unit)
    }
    return num
}

public func computeBytes(n: Int64, unit: String): Option<Int64> {
    let uniteq = unit.toAsciiLower()
    if (uniteq == "b") {
        n
    } else if (uniteq == "k" || uniteq == "kb") {
        n * 1024
    } else if (uniteq == "m" || uniteq == "mb") {
        n * 1024 * 1024
    } else if (uniteq == "g" || uniteq == "gb") {
        n * 1024 * 1024 * 1024
    } else if (uniteq == "t" || uniteq == "tb") {
        n * 1024 * 1024 * 1024 * 1024
    } else if (uniteq == "p" || uniteq == "pb") {
        n * 1024 * 1024 * 1024 * 1024 * 1024
    } else if (uniteq == "e" || uniteq == "eb") {
        n * 1024 * 1024 * 1024 * 1024 * 1024 * 1024
    } else if (uniteq == "z" || uniteq == "zb") {
        n * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024
    } else if (uniteq == "y" || uniteq == "yb") {
        n * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024
    }
    throw IllegalArgumentException("not supported byte unit: ${unit}")
}
