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
package f_config

import std.collection.{HashMap, Map, HashSet}
import std.collection.concurrent.ConcurrentHashMap
import std.env
import std.time.DateTime
public import f_data.DataParsable
public import std.convert.Parsable

/**
 * 不依赖配置文件，所有配置都来自环境变量和命令行参数，命令行参数会覆盖同名环境变量。
 * 本工具不会修改环境变量和命令行参数命名风格，仓颉运行时环境变量都是驼峰命名法，建议用于应用配置的环境变量和命令行参数也采用此风格。
 * 命令行参数需要遵守以下规则
 *   1. --argName=argValue
 *   2. --argName
 *      * 相当于--argName=true
 *   3. -argName argVal
 *   4. -argName
 *      * 相当于-argName true
 */
public class Config {
    private static let prefix = 'fountain'
    private static let ARGS = ConcurrentHashMap<String, String>()
    private static let REFRESHER = ConcurrentHashMap<String, () -> Unit>()
    static init() {
        for ((k, v) in env.getVariables()) {
            ARGS[k] = v
        }
        let args = env.getCommandLine()[1..]
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            if (arg.startsWith('--')) {
                let (key, val) = 
                if (let Some(idx) <- arg.indexOf('=')) {
                    let key = arg[2..idx].trimAscii()
                    let val = arg[idx + 1..].trimAscii()
                    (key, val)
                } else {
                    let key = arg[2..].trimAscii()
                    (key, 'true')
                }
                ARGS[key] = val
            } else if (arg.startsWith('-')) {
                let key = arg[1..].trimAscii()
                let val = if (i + 1 < args.size) {
                    let val = args[i + 1].trimAscii()
                    if (val.startsWith('-')) {
                        'true'
                    } else {
                        i++
                        val
                    }
                } else {
                    'true'
                }
                ARGS[key] = val
            }
            i++
        }
    }
    private init() {}

    public static func refresher(prefix: String, fn: () -> Unit) {
        REFRESHER['${prefix}_'] = fn
    }
    /**
     * ifAbsent是true，只有当前配置项不存在时才添加，否则用新的配置覆盖旧的
     */
    public static func set<T>(tuples: Array<(String, T)>, ifAbsent!: Bool = false): Unit where T <: ToString {
        let set = HashSet<String>()
        for (tpl in tuples) {
            let name = tpl[0]
            if (!ifAbsent) {
                ARGS[name] = tpl[1].toString()
            } else if(ARGS.addIfAbsent(name, tpl[1].toString()).isSome()) {
                continue
            }
            if (let Some(x) <- name.indexOf('_')) {
                set.add(name[0..x])
            } else {
                set.add(name)
            }
        }
        for ((prefix, fn) in REFRESHER) {
            for (k in set where k.startsWith(prefix) || k.startsWith('${Config.prefix}_${prefix}')) {
                fn()
                break
            }
        }

    }
    public static func getAll(prefix: String): Map<String, String> {
        let map = HashMap<String, String>()
        for ((k, v) in ARGS where k.startsWith('${prefix}_') || k.startsWith('${Config.prefix}_${prefix}_')) {
            map[k] = v
        }
        map
    }
    public static func getString(key: String): ?String {
        if (let Some(v) <- ARGS.get(key)) {
            v
        } else {
            ARGS.get("${prefix}_${key}")
        }
    }

    public static func getValue<T>(key: String, parser: (String) -> ?T): ?T {
        if (let Some(x) <- getString(key)) {
            parser(x)
        } else {
            None<T>
        }
    }
    public static func getValue<T>(key: String): ?T where T <: Parsable<T> {
        getValue<T>(key) {s => T.tryParse(s)}
    }
    public static func getStringArray(key: String, delim!: String = ','): Array<String> {
        if (let Some(x) <- getString(key)) {
            let arr = x.split(delim, removeEmpty: true)
            Array<String>(arr.size) {i => arr[i].trimAscii()}
        } else {
            []
        }
    }
    public static func getValues<T>(key: String, delim!: String = ',', parser!: (String) -> T): Array<T> {
        let arr = getStringArray(key, delim: delim)
        Array<T>(arr.size) {i => parser(arr[i])}
    }
    public static func getValues<T>(key: String, delim!: String = ','): Array<T> where T <: Parsable<T> {
        getValues<T>(key, delim: delim) {s => T.parse(s)}
    }
    private static func parseDateTime(s: String, format: String) {
        if (format.isEmpty()) {
            DateTime.parse(s)
        } else {
            DateTime.parse(s, format)
        }
    }
    public static func getDateTime(key: String, format!: String = ''): ?DateTime {
        getValue<DateTime>(key) {s => parseDateTime(s, format)}
    }
    public static func getDateTimes(key: String, format!: String = '', delim!: String = ','): Array<DateTime> {
        getValues<DateTime>(key, delim: delim) {s => parseDateTime(s, format)}
    }
    public static func getData<T>(key: String): ?T where T <: DataParsable<T> {
        getValue<T>(key) {s => T.tryParse(s)}
    }
    public static func getDatas<T>(key: String, delim!: String = ','): Array<T> where T <: DataParsable<T> {
        getValues<T>(key, delim: delim) {s => T.parse(s)}
    }
    public static func getDuration(key: String): ?Duration {
        getData<Duration>(key)
    }
    public static func getDurations(key: String, delim!: String = ','): Array<Duration> {
        getDatas<Duration>(key, delim: delim)
    }
    public static func bufferSize(bufferKey: String, default: Int64, debugging: Bool) {
        if (let Some(x) <- Config.getValue<Int>(bufferKey)) {
            if (x > 0 && debugging) {
                return x
            } else if (x <= 0) {
                return default
            } else if (((x - 1) & x) == 0) {
                return x
            }
            var s = 1
            while (s < x) {
                s <<= 1
            }
            if (s >= default) {
                s
            } else {
                default
            }
        } else {
            default
        }
    }
}