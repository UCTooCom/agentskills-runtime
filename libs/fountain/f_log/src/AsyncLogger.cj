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

import std.collection.ArrayList
import std.collection.concurrent.{ArrayBlockingQueue, ConcurrentHashMap}
import std.env
import std.io.OutputStream
import std.sync.AtomicInt64
import std.time.DateTime
import stdx.log.{LogLevel, LogRecord}
import f_base.Console
import f_collection.*
import f_io.DummyOutputStream
import f_log.exception.LogException

private struct SyncQueueStream{
    let queue: ArrayBlockingQueue<() -> Unit>
    let output: OutputStream
    let refCount = AtomicInt64(0)
    init(output: OutputStream){
        let bufSize = LoggerConfig.getAsyncBufSize()
        queue = ArrayBlockingQueue<() -> Unit>(bufSize)
        this.output = match(output){
            case x: DummyOutputStream => output
            case _ => 
                SyncQueueOutputStream(bufSize * 10)
        }
        remove(queue)
    }
    private static func remove(queue: ArrayBlockingQueue<() -> Unit>): Unit {
        spawn {
            while (true) {
                try {
                    queue.remove()()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}
public abstract class AsyncLogger <: AbstractLogger {
    private static let queueMap = ConcurrentHashMap<String, SyncQueueStream>()
    private let timeout: Duration
    private let policy: AsyncTimeoutPolicy
    private let queue: ArrayBlockingQueue<() -> Unit>
    protected var actualOutput: OutputStream
    private let queueTag: String
    public init(
        name: String,
        level: LogLevel,
        pattern: LogPattern,
        output: OutputStream,
        queueTag: String
    ) {
        super(name, level, pattern, confirmDummy(output, queueTag), queueTag)
        this.queueTag = queueTag
        this.actualOutput = output
        timeout = LoggerConfig.getAsyncTimeout()
        policy = LoggerConfig.getAsyncTimeoutPolicy()
        let qstream = queueStream(output, queueTag)
        this.queue = qstream.queue
        env.atExit{doClose(output, true, queueTag)}
    }
    public open func isClosed(): Bool {
        if(let r: Resource <- actualOutput){
            r.isClosed()
        }else{
            false
        }
    }
    private static func doClose(output: OutputStream, closable: Bool, tag: String): Unit {
        if(let Some(q) <- queueMap.get(tag) && q.refCount.fetchSub(1) == 1){
            func wait(q: ArrayBlockingQueue<() -> Unit>){
                while(q.size > 0){
                    sleep(Duration.Zero)// 循环次数可能很多，避免当前线程长时间占用CPU
                }
            }
            wait(q.queue)
            sleep(Duration.microsecond * 100)// 等待写线程能够把最后一个字节数组写出
        }
        if(closable && let r: Resource <- output &&!r.isClosed()){
            r.close()
        }
        queueMap.remove(tag)
    }
    public open func close(): Unit {
        doClose(actualOutput, closable, queueTag)
    }
    private static func confirmDummy(output: OutputStream, tag: String): OutputStream {
        queueStream(output, tag).output
    }
    private static func queueStream(output: OutputStream, tag: String){
        let q = queueMap.computeIfAbsent(tag){
            SyncQueueStream(output)
        }
        q.refCount.fetchAdd(1)
        q
    }
    private func append() {
        let buffer = (super.output as SyncQueueOutputStream).getOrThrow()
        if (buffer.size > 0) {
            append {
                buffer.writeTo(actualOutput)
            }
        }
    }
    public open func log(record: LogRecord): Unit {
        super.log(record)
        append()
    }
    protected func append(fn: () -> Unit): Unit {
        while (!queue.add(fn, timeout)) {
            match (policy) {
                case AlwaysWaiting => continue
                case Discard => return // 忽略
                case Abort => throw LogException("to add for current logger is timeout ${timeout}")
            }
        }
    }
    protected open func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        super.append(level, message, now, tid, ex)
        append()
    }
}
public struct SyncQueueOutputStream <: OutputStream {
    private static let pool: ArrayBlockingQueue<ArrayList<Array<Byte>>>
    static init() {
        let size = LoggerConfig.getAsyncBufSize()
        pool = ArrayBlockingQueue<ArrayList<Array<Byte>>>(size)
        for(i in 0 .. size){
            pool.add(ArrayList<Array<Byte>>())
        }
    }
    private let queue: ArrayBlockingQueue<ArrayList<Array<Byte>>>
    private let buffer = ThreadLocal<ArrayList<Array<Byte>>>()
    init(bufSize: Int64){
        queue = ArrayBlockingQueue<ArrayList<Array<Byte>>>(bufSize)
    }
    public func write(bytes: Array<Byte>): Unit {
        let buf = if(let Some(buf) <- buffer.get()){
            buf
        }else if (let Some(buf) <- pool.remove(Duration.millisecond * 5)) {
            buffer.set(buf)
            buf
        } else {
            Console.writeln('AsyncLogger.SyncQueueOutputStream.EmptyPool')
            return
        }
        // if(bytes[bytes.size - 1] == b'\0'){//todo 这个做法性能有些低，但是性能高的做法会导致BUG。
        //     let b = bytes[0 .. bytes.size - 1]
        //     buf.add(b)
        //     queue.add(buf)
        //     buffer.set(None)
        // }else{
        //     buf.add(bytes)
        // }
        if(bytes[0] == b'\0'){
            queue.add(buf)
            buffer.set(None)
        }else{
            buf.add(bytes)
        }
    }
    prop size: Int64 {
        get(){
            queue.size
        }
    }
    func writeTo(output: OutputStream): Unit {
        while (let Some(buf) <- queue.peek()){
            try{
                if(buf.size > 0){
                    for(bytes in buf where bytes.size > 0) {
                        output.write(bytes)
                    }
                }
            } finally {
                output.flush()
                returnBuffer(queue.remove())
            }
        }
    }
    private func returnBuffer(buf: ArrayList<Array<Byte>>){
        buf.clear()
        pool.add(buf)
    }
}