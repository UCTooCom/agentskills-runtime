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

import std.collection.HashSet
import std.collection.concurrent.ConcurrentHashMap
import f_base.StringGenerator
import f_cache.HeapCache
import f_collection.*

public interface RegexFromString {
    func regex(flags!: Array<RegexFlag>, solid!: Bool): Regex
}

private let CACHE = HeapCache<Regex>(maxLife: Duration.day, maxSize: 10000)
private let SOLID = ConcurrentHashMap<String, Regex>()

extend String <: RegexFromString {
    public func regex(flags!: Array<RegexFlag> = [], solid!: Bool = false): Regex {
        func flagstr(flag: RegexFlag): String {
            match (flag) {
                case IgnoreCase => 'i'
                case MultiLine => 'm'
                case Unicode => 'u'
            }
        }
        func flagsstr() {
            let set = HashSet<String>()
            for (f in flags) {
                set.add(flagstr(f))
            }
            let fb = StringGenerator()
            for (f in set) {
                fb.append(f)
            }
            fb.toString()
        }
        let key = "/${this}/${flagsstr()}"
        if (solid) {
            SOLID.computeIfAbsent(key){
                if(let Some(x) <- CACHE.get(key)) {
                    x
                }else{
                    Regex(this, flags)
                }
            }
        } else {
            CACHE.getOrCompute(key) {
                SOLID.get(key) ?? Regex(this, flags)
            }
        }
    }
}
