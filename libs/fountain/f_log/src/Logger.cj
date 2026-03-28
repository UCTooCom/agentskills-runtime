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
package f_log

import std.collection.{ArrayList, HashMap, TreeMap}
import std.collection.concurrent.ConcurrentHashMap
import stdx.log.LogLevel
import stdx.log.Logger as StdLogger
import f_base.*
import f_collection.LinkedHashMap
import f_data.*
import f_util.TextTemplate

/**
 * 函数logLevelEnabled和各种日志级别的Enabled属性，不必在应用代码中显式调用，本日志框架记录日志前已做过判断
 */
public abstract class Logger <: StdLogger {
    public mut prop level: LogLevel
    public open func logLevelEnabled(level: LogLevel): Bool {
        enabled(level)
    }

    protected func append(level: LogLevel, message: () -> String, ex: ?Exception): Unit
    protected func append(level: LogLevel, message: () -> String): Unit {
        append(level, message, None<Exception>)
    }
    protected func append(level: LogLevel, message: String): Unit {
        append(level, message, None<Exception>)
    }

    public func append(level: LogLevel, message: String, ex: Option<Exception>): Unit {
        append(level, {=> message}, ex)
    }
    public func append<T>(level: LogLevel, message: String, args: Array<T>, ex: ?Exception): Unit where T <: ToString {
        append(
            level,
            {
                => TextTemplate.compile(message, prefix: "{", suffix: "}").format<T>(args)
            },
            ex
        )
    }
    public func append<T>(level: LogLevel, message: String, args: T, ex: ?Exception): Unit where T <: Object & ObjectData<T> {
        append(
            level,
            {=> 
                let filter = LoggerConfig.filter
                if(let _: DummyLogFilter <- filter){
                    return TextTemplate.compile(message, prefix: "{", suffix: "}").format<T>(args)
                }
                let map = HashMap<String, String>()
                for(field in DataObject<T>(args).fields()){
                    let name = field.name
                    let data = field.get(args).toString()
                    if(let Some((n, v)) <- filter.filter(name, data)){
                        map.add(n, v)
                    }
                }
                TextTemplate.compile(message, prefix: "{", suffix: "}").format<String>(map)
            },
            ex
        )
    }
    public func append<T>(level: LogLevel, message: String, args: ArrayList<T>, ex: ?Exception): Unit where T <: ToString {
        append<T>(level, message, args.unsafeData(), ex)
    }
    
    public func append<T>(level: LogLevel, message: String, args: HashMap<String, T>, ex: ?Exception): Unit where T <: ToString {
        append(
            level,
            {=> 
                let filter = LoggerConfig.filter
                if(let _: DummyLogFilter <- filter){
                    return TextTemplate.compile(message, prefix: "{", suffix: "}").format<T>(args)
                }
                let map = HashMap<String, String>()
                for ((n, v) in args) {
                    if(let Some((n, v)) <- filter.filter(n, v.toString())){
                        map[n] = v
                    }
                }
                TextTemplate.compile(message, prefix: "{", suffix: "}").format<String>(map)
            },
            ex
        )
    }
    public func append<T>(level: LogLevel, message: String, args: ConcurrentHashMap<String, T>, ex: ?Exception): Unit where T <: ToString {
        append(
            level,
            {=> 
                let filter = LoggerConfig.filter
                if(let _: DummyLogFilter <- filter){
                    return TextTemplate.compile(message, prefix: "{", suffix: "}").format<T>(args)
                }
                let map = HashMap<String, String>()
                for((n, v) in args){
                    if(let Some((n, v)) <- filter.filter(n, v.toString())){
                        map[n] = v
                    }
                }
                TextTemplate.compile(message, prefix: "{", suffix: "}").format<String>(map)
            },
            ex
        )
    }
    public func append<T>(level: LogLevel, message: String, args: TreeMap<String, T>, ex: ?Exception): Unit where T <: ToString {
        append(
            level,
            {=> 
                let filter = LoggerConfig.filter
                if(let _: DummyLogFilter <- filter){
                    return TextTemplate.compile(message, prefix: "{", suffix: "}").format<T>(args)
                }
                let map = HashMap<String, String>()
                for((n, v) in args){
                    if(let Some((n, v)) <- filter.filter(n, v.toString())){
                        map[n] = v
                    }
                }
                TextTemplate.compile(message, prefix: "{", suffix: "}").format<String>(map)
            },
            ex
        )
    }
    public func append<T>(level: LogLevel, message: String, args: LinkedHashMap<String, T>, ex: ?Exception): Unit where T <: ToString {
        append(
            level,
            {=> 
                let filter = LoggerConfig.filter
                if(let _: DummyLogFilter <- filter){
                    return TextTemplate.compile(message, prefix: "{", suffix: "}").format<T>(args)
                }
                let map = HashMap<String, String>()
                for((n, v) in args){
                    if(let Some((n, v)) <- filter.filter(n, v.toString())){
                        map[n] = v
                    }
                }
                TextTemplate.compile(message, prefix: "{", suffix: "}").format<String>(map)
            },
            ex
        )
    }
    
    public func fatal<T>(message: String, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, None<Exception>)
    }
    
    public func fatal<T>(message: String, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, None<Exception>)
    }
    public func fatal<T>(message: String, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, None<Exception>)
    }
    public func fatal<T>(message: String, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, None<Exception>)
    }
    public func fatal<T>(message: String, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, None<Exception>)
    }
    public func fatal<T>(message: String, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, None<Exception>)
    }
    public func fatal<T>(message: String, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.FATAL, message, args, None<Exception>)
    }

    public func fatal<T>(message: String, ex: Exception, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, ex)
    }
    public func fatal<T>(message: String, ex: Exception, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, ex)
    }
    public func fatal<T>(message: String, ex: Exception, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, ex)
    }
    public func fatal<T>(message: String, ex: Exception, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, ex)
    }
    public func fatal<T>(message: String, ex: Exception, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, ex)
    }
    public func fatal<T>(message: String, ex: Exception, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.FATAL, message, args, ex)
    }
    public func fatal<T>(message: String, ex: Exception, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.FATAL, message, args, ex)
    }

    public func error<T>(message: String, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, None<Exception>)
    }
    public func error<T>(message: String, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, None<Exception>)
    }
    public func error<T>(message: String, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, None<Exception>)
    }
    public func error<T>(message: String, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, None<Exception>)
    }
    public func error<T>(message: String, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, None<Exception>)
    }
    public func error<T>(message: String, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, None<Exception>)
    }
    public func error<T>(message: String, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.ERROR, message, args, None<Exception>)
    }

    public func error<T>(message: String, ex: Exception, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, ex)
    }
    public func error<T>(message: String, ex: Exception, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, ex)
    }
    public func error<T>(message: String, ex: Exception, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, ex)
    }
    public func error<T>(message: String, ex: Exception, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, ex)
    }
    public func error<T>(message: String, ex: Exception, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, ex)
    }
    public func error<T>(message: String, ex: Exception, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.ERROR, message, args, ex)
    }
    public func error<T>(message: String, ex: Exception, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.ERROR, message, args, ex)
    }

    public func warn<T>(message: String, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, None<Exception>)
    }
    public func warn<T>(message: String, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, None<Exception>)
    }
    public func warn<T>(message: String, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, None<Exception>)
    }
    public func warn<T>(message: String, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, None<Exception>)
    }
    public func warn<T>(message: String, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, None<Exception>)
    }
    public func warn<T>(message: String, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, None<Exception>)
    }
    public func warn<T>(message: String, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.WARN, message, args, None<Exception>)
    }

    public func warn<T>(message: String, ex: Exception, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, ex)
    }
    public func warn<T>(message: String, ex: Exception, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, ex)
    }
    public func warn<T>(message: String, ex: Exception, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, ex)
    }
    public func warn<T>(message: String, ex: Exception, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, ex)
    }
    public func warn<T>(message: String, ex: Exception, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, ex)
    }
    public func warn<T>(message: String, ex: Exception, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.WARN, message, args, ex)
    }
    public func warn<T>(message: String, ex: Exception, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.WARN, message, args, ex)
    }

    public func info<T>(message: String, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, None<Exception>)
    }
    public func info<T>(message: String, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, None<Exception>)
    }
    public func info<T>(message: String, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, None<Exception>)
    }
    public func info<T>(message: String, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, None<Exception>)
    }
    public func info<T>(message: String, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, None<Exception>)
    }
    public func info<T>(message: String, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, None<Exception>)
    }
    public func info<T>(message: String, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.INFO, message, args, None<Exception>)
    }

    public func info<T>(message: String, ex: Exception, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, ex)
    }
    public func info<T>(message: String, ex: Exception, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, ex)
    }
    public func info<T>(message: String, ex: Exception, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, ex)
    }
    public func info<T>(message: String, ex: Exception, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, ex)
    }
    public func info<T>(message: String, ex: Exception, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, ex)
    }
    public func info<T>(message: String, ex: Exception, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.INFO, message, args, ex)
    }
    public func info<T>(message: String, ex: Exception, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.INFO, message, args, ex)
    }

    public func debug<T>(message: String, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, None<Exception>)
    }
    public func debug<T>(message: String, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, None<Exception>)
    }
    public func debug<T>(message: String, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, None<Exception>)
    }
    public func debug<T>(message: String, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, None<Exception>)
    }
    public func debug<T>(message: String, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, None<Exception>)
    }
    public func debug<T>(message: String, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, None<Exception>)
    }
    public func debug<T>(message: String, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.DEBUG, message, args, None<Exception>)
    }

    public func debug<T>(message: String, ex: Exception, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, ex)
    }
    public func debug<T>(message: String, ex: Exception, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, ex)
    }
    public func debug<T>(message: String, ex: Exception, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, ex)
    }
    public func debug<T>(message: String, ex: Exception, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, ex)
    }
    public func debug<T>(message: String, ex: Exception, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, ex)
    }
    public func debug<T>(message: String, ex: Exception, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.DEBUG, message, args, ex)
    }
    public func debug<T>(message: String, ex: Exception, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.DEBUG, message, args, ex)
    }

    public func trace<T>(message: String, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, None<Exception>)
    }
    public func trace<T>(message: String, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, None<Exception>)
    }
    public func trace<T>(message: String, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, None<Exception>)
    }
    public func trace<T>(message: String, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, None<Exception>)
    }
    public func trace<T>(message: String, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, None<Exception>)
    }
    public func trace<T>(message: String, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, None<Exception>)
    }
    public func trace<T>(message: String, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.TRACE, message, args, None<Exception>)
    }

    public func trace<T>(message: String, ex: Exception, args: Array<T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, ex)
    }
    public func trace<T>(message: String, ex: Exception, args: ArrayList<T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, ex)
    }
    public func trace<T>(message: String, ex: Exception, args: HashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, ex)
    }
    public func trace<T>(message: String, ex: Exception, args: LinkedHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, ex)
    }
    public func trace<T>(message: String, ex: Exception, args: ConcurrentHashMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, ex)
    }
    public func trace<T>(message: String, ex: Exception, args: TreeMap<String, T>): Unit where T <: ToString {
        append<T>(LogLevel.TRACE, message, args, ex)
    }
    public func trace<T>(message: String, ex: Exception, args: T): Unit where T <: Object & ObjectData<T> {
        append<T>(LogLevel.TRACE, message, args, ex)
    }

    public func fatal(message: String, ex: Exception): Unit {
        append(LogLevel.FATAL, message, ex)
    }
    public func error(message: String, ex: Exception): Unit {
        append(LogLevel.ERROR, message, ex)
    }
    public func warn(message: String, ex: Exception): Unit {
        append(LogLevel.WARN, message, ex)
    }
    public func info(message: String, ex: Exception): Unit {
        append(LogLevel.INFO, message, ex)
    }
    public func debug(message: String, ex: Exception): Unit {
        append(LogLevel.DEBUG, message, ex)
    }
    public func trace(message: String, ex: Exception): Unit {
        append(LogLevel.TRACE, message, ex)
    }
    public func fatal(ex: Exception, message: () -> String): Unit {
        append(LogLevel.FATAL, message, ex)
    }
    public func error(ex: Exception, message: () -> String): Unit {
        append(LogLevel.ERROR, message, ex)
    }
    public func warn(ex: Exception, message: () -> String): Unit {
        append(LogLevel.WARN, message, ex)
    }
    public func info(ex: Exception, message: () -> String): Unit {
        append(LogLevel.INFO, message, ex)
    }
    public func debug(ex: Exception, message: () -> String): Unit {
        append(LogLevel.DEBUG, message, ex)
    }
    public func trace(ex: Exception, message: () -> String): Unit {
        append(LogLevel.TRACE, message, ex)
    }

    public func fatal(ex: Exception): Unit {
        append(LogLevel.FATAL, String.empty, ex)
    }
    public func error(ex: Exception): Unit {
        append(LogLevel.ERROR, String.empty, ex)
    }
    public func warn(ex: Exception): Unit {
        append(LogLevel.WARN, String.empty, ex)
    }
    public func info(ex: Exception): Unit {
        append(LogLevel.INFO, String.empty, ex)
    }
    public func debug(ex: Exception): Unit {
        append(LogLevel.DEBUG, String.empty, ex)
    }
    public func trace(ex: Exception): Unit {
        append(LogLevel.TRACE, String.empty, ex)
    }

    public func fatal(message: String): Unit {
        append(LogLevel.FATAL, message)
    }
    public func error(message: String): Unit {
        append(LogLevel.ERROR, message)
    }
    public func warn(message: String): Unit {
        append(LogLevel.WARN, message)
    }
    public func info(message: String): Unit {
        append(LogLevel.INFO, message)
    }
    public func debug(message: String): Unit {
        append(LogLevel.DEBUG, message)
    }
    public func trace(message: String): Unit {
        append(LogLevel.TRACE, message)
    }

    public func fatal(message: () -> String, ex: Exception): Unit {
        append(LogLevel.FATAL, message, ex)
    }
    public func error(message: () -> String, ex: Exception): Unit {
        append(LogLevel.ERROR, message, ex)
    }
    public func warn(message: () -> String, ex: Exception): Unit {
        append(LogLevel.WARN, message, ex)
    }
    public func info(message: () -> String, ex: Exception): Unit {
        append(LogLevel.INFO, message, ex)
    }
    public func debug(message: () -> String, ex: Exception): Unit {
        append(LogLevel.DEBUG, message, ex)
    }
    public func trace(message: () -> String, ex: Exception): Unit {
        append(LogLevel.TRACE, message, ex)
    }

    public func fatal(message: () -> String): Unit {
        append(LogLevel.FATAL, message)
    }
    public func error(message: () -> String): Unit {
        append(LogLevel.ERROR, message)
    }
    public func warn(message: () -> String): Unit {
        append(LogLevel.WARN, message)
    }
    public func info(message: () -> String): Unit {
        append(LogLevel.INFO, message)
    }
    public func debug(message: () -> String): Unit {
        append(LogLevel.DEBUG, message)
    }
    public func trace(message: () -> String): Unit {
        append(LogLevel.TRACE, message)
    }

    public prop traceEnabled: Bool {
        get() {
            logLevelEnabled(LogLevel.TRACE)
        }
    }
    public prop debugEnabled: Bool {
        get() {
            logLevelEnabled(LogLevel.DEBUG)
        }
    }
    public prop infoEnabled: Bool {
        get() {
            logLevelEnabled(LogLevel.INFO)
        }
    }
    public prop warnEnabled: Bool {
        get() {
            logLevelEnabled(LogLevel.WARN)
        }
    }
    public prop errorEnabled: Bool {
        get() {
            logLevelEnabled(LogLevel.ERROR)
        }
    }
    public prop fatalEnabled: Bool {
        get() {
            logLevelEnabled(LogLevel.FATAL)
        }
    }
}
