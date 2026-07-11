/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */

package hyperion.logadapter


/**
 * 打印日志的Handler
 *
 * @author yangfuping
 */
public interface SimpleLoggerHandler {
    func publish(logRecord: SimpleLogRecord): Unit
}

/**
 * 打印日志到输出流的Handler
 *
 * @author yangfuping
 */
public interface StreamLoggerHandler <: SimpleLoggerHandler {
    /**
     * 更新OutputStream
     */
    func updateStream(outputStream: OutputStream): Unit
}

/**
 * 使用输出流打印日志，内部会启动一个线程打印日志
 *
 * @author yangfuping
 */
public open class SimpleStreamLoggerHandler <: StreamLoggerHandler {
    private let pendingLogRecords = ArrayBlockingQueue<SimpleLogRecord>(8192)

    private let running = AtomicBool(true)

    private let logFormatter: SimpleLogFormatter

    private var outputStream: OutputStream

    private var writer: AtomicReference<StringWriter<OutputStream>>

    private let publishThread = AtomicOptionReference<LoggerPublisherThread>()

    private let pollLogRecordTimeout = Duration.second * 3

    private let updateStreamLock = Mutex()

    public init(logFormatter: SimpleLogFormatter, outputStream: OutputStream) {
        this.logFormatter = logFormatter
        this.outputStream = outputStream
        let stringWriter = StringWriter<OutputStream>(outputStream)
        this.writer = AtomicReference<StringWriter<OutputStream>>(stringWriter)
    }

    private func initialize() {
        if (publishThread.load().isNone()) {
            let thread = LoggerPublisherThread(this)
            if (publishThread.compareAndSwap(None, thread)) {
                // 启动打印日志的线程
                spawn {
                    Thread.currentThread.name = "Logger-Publisher"
                    thread.run()
                }
            }
        }
    }

    public open func publish(logRecord: SimpleLogRecord): Unit {
        if (publishThread.load().isNone()) {
            initialize()
        }

        if (pendingLogRecords.tryAdd(logRecord)) {
            return
        }

        pendingLogRecords.add(logRecord)
    }

    public func updateStream(outputStream: OutputStream): Unit {
        if (checkStreamEquals(this.outputStream, outputStream)) {
            return
        }

        synchronized(updateStreamLock) {
            if (checkStreamEquals(this.outputStream, outputStream)) {
                return
            }

            this.outputStream = outputStream
            let stringWriter = StringWriter<OutputStream>(outputStream)
            writer.store(stringWriter)
        }
    }

    /**
     * 判断新设置的OutputStream是否和当前OutputStream相同
     */
    private func checkStreamEquals(oldStream: OutputStream, newStream: OutputStream): Bool {
        if (let Some(oldStream) <- (oldStream as Object)) {
            if (let Some(newStream) <- (newStream as Object)) {
                if (refEq(oldStream, newStream)) {
                    return true
                }
            }
        }

        return false
    }

    protected open func log() {
        while (running.load()) {
            if (let Some(logRecord) <- pendingLogRecords.remove(pollLogRecordTimeout)) {
                let message = logFormatter.format(logRecord)
                try {
                    let localWriter = writer.load()
                    localWriter.write(message)
                    localWriter.flush()
                } catch (ex: Exception) {
                    // 不能写到日志的流中， 打印到stdErr
                    ex.printStackTrace()
                }
            }
        }
    }
}

/**
 * 打印日志的线程
 *
 * @author yangfuping
 */
class LoggerPublisherThread {
    private let handler: SimpleStreamLoggerHandler

    public init(handler: SimpleStreamLoggerHandler) {
        this.handler = handler
    }

    public func run() {
        handler.log()
    }
}
