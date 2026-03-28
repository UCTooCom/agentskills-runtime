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

import std.collection.concurrent.ConcurrentHashMap
import std.io.OutputStream
import std.sync.Mutex
import std.time.DateTime
import stdx.log.{LogLevel, Attr, LogRecord, LogWriter}
import f_collection.*
import f_log.output.LogWriterImpl

public abstract class AbstractLogger <: Logger & Resource {
    private let locks = ConcurrentHashMap<String, Mutex>()
    protected let name: String
    private var level_: LogLevel
    protected let pattern: LogPattern
    private var output_: OutputStream
    private var writer: LogWriterImpl
    private let tag: String
    protected init(name: String, level: LogLevel, pattern: LogPattern, output: OutputStream, tag: String) {
        this.name = name
        this.level_ = level
        this.pattern = pattern
        this.output_ = output
        this.writer = LogWriterImpl(output)
        this.tag = tag
    }
    protected open func new(name: String): AbstractLogger{
        this
    }
    protected mut prop output: OutputStream {
        get() {
            output_
        }
        set(value) {
            output_ = value
            writer = LogWriterImpl(value)
        }
    }
    public open func isClosed(): Bool {
        match (output) {
            case r: Resource => r.isClosed()
            case _ => false
        }
    }
    public open func close(): Unit {
        match (output) {
            case r: Resource where closable && !isClosed() => r.close()
            case _ => ()
        }
    }

    public mut prop level: LogLevel {
        get() {
            level_
        }
        set(value) {
            level_ = value
        }
    }
    private let attrs = ThreadLocal<Array<Attr>>()
    public func withAttrs(attrs: Array<Attr>): Logger {
        this.attrs.set(attrs)
        this
    }
    public open func log(record: LogRecord): Unit {
        try {
            if (logLevelEnabled(record.level)) {
                doLock {
                    doAppend(record.level, record.message, record.time, Thread.currentThread.id, None<Exception>)
                    func writeAttrs(attrs: Array<Attr>) {
                        if (attrs.isEmpty()) {
                            return
                        }
                        writer.writeString(';')
                        writer.startObject()
                        for (i in 0..attrs.size) {
                            if (i > 0) {
                                writer.writeString(',')
                            }
                            if(let Some(attr) <- LoggerConfig.filter.filter(attrs[i])){
                                writer.writeString('${attr[0]}:')
                                attr[1].writeTo(writer)
                            }
                        }
                        writer.endObject()
                    }
                    writeAttrs(globalAttrMap.get(name) ?? [])
                    writeAttrs(this.attrs.get() ?? [])
                    writeAttrs(record.attrs)
                    writer.writeString('\0')
                }
            }
        } finally {
            attrs.set(None<Array<Attr>>)
        }
    }

    protected func append(level: LogLevel, message: () -> String, ex: Option<Exception>): Unit {
        let now = DateTime.now()//产生日志的时间比记录时间重要，可能记日志的顺序跟时间不一致了，不过不重要。
        let tid = Thread.currentThread.id
        append(level, message, now, tid , ex)
    }
    protected func appendException(ex: ?Exception, output: LogWriter): Unit {
        if (let Some(e) <- ex) {
            output.writeException(e)
        }
    }
    private func append(level: LogLevel, message: String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        doAppend(level, message, now, tid, ex)
        writer.writeString('\0')
    }
    private func doAppend(level: LogLevel, message: String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        pattern.generate(name, level, message, now, tid, writer)
        appendException(ex, writer)
    }
    protected open func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        if (logLevelEnabled(level)) {
            doLock{
                append(level, message(), now, tid, ex)
            }
        }
    }
    protected func doLock<T>(callback: () -> T): T {
        let lock = locks.computeIfAbsent(tag){Mutex()}
        synchronized(lock) {
            callback()
        }
    }
    private var closable_ = false
    public open mut prop closable: Bool {
        get() {
            closable_
        }
        set(value){
            closable_ = value
        }
    }
}
