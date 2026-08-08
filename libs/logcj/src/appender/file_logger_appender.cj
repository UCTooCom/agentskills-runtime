/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines FileLoggerAppender class.
 */

package logcj.appender

/**
   The specific implementation class of LoggerAppender, which enables the file can be logged.
 */
public class FileLoggerAppender <: LoggerAppender {
    // Defalut log file.
    private let DEFAULT_OUTPUT_FILE_NAME: String = "log4cj_default.log"

    //Log Print Format.
    private var pattern: String = ""

    // Log file name.
    private var fileName: String = ""

    // Log file pointer.
    private var file: File

    // Maximum limit of a single log. The value 0 indicates no limit.
    private var maxSize: Int64 = 0

    // Current log size.
    private var curSize: Int64 = 0

    //Day-based log scrolling flag.
    private var daily: Bool = false

    // Time then a log file is created. This parameter is used together with Daily.
    private var opendate: Int64 = 0

    // Indicates whether to pack logs.
    private var rotate: Bool = false

    private var writeCompleted: Bool = true

    private var retentionDays: Int64 = 7

    private var contentList: LinkedList<LogRecord> = LinkedList<LogRecord>()

    private let lock = Monitor()

    /**
     * Constructor, initialize variable file.
     */
    public init() {
        this.file = File(DEFAULT_OUTPUT_FILE_NAME, OpenMode.Append)
        if (exists(this.file.info.path)) {
            remove(this.file.info.path)
        }
    }

    /**
     * Destructor, close file.
     */
    ~init() {
        if (!file.isClosed()) {
            file.flush()
            file.close()
        }
    }

    /**
     * Initialize file logger appender.
     *
     * @param pattern log format.
     * @param property file appender properties.
     */
    public func initAppender(pattern: String, properties: ArrayList<AppenderProperty>): Unit {
        var file = ""
        let dFormat = "[%D %T %m] [%L] [%I] [%l] (%S) %M"
        var maxSize = 0
        var daily = false
        var rotate = false
        var retentionDays = 7

        if (pattern.size == 0) {
            this.pattern = dFormat
        } else {
            this.pattern = pattern
        }

        //Parse properties.
        var i: Int64 = 0
        while (i < properties.size) {
            var value = properties.get(i).getOrThrow().getValue().trimStart(" \r\n").trimEnd(" \r\n")
            var name = properties.get(i).getOrThrow().getName().toAsciiLower()

            if (name.contains("filename")) {
                file = value.replace("\"", "")
            }
            if (name.contains("maxsize")) {
                maxSize = strToNumBySuffix(value, 1024, 20 * 1024 * 1024)
            }
            if (name.contains("daily") && !value.contains("false")) {
                daily = true
            }
            if (name.contains("rotate") && !value.contains("false")) {
                rotate = true
            }
            if (name.contains("retentiondays")) {
                retentionDays = getNumByString(value, 7)
            }
            i++
        }

        if (file.size == 0) {
            file = "root.log"
        }

        this.fileName = file
        this.rotate = rotate
        this.maxSize = maxSize
        this.daily = daily
        this.retentionDays = retentionDays
    }

    /**
     * Process default file, and assigns values to file-related variables.
     */
    public func start(): Unit {
        var dir = Path(this.fileName).parent
        if (dir.toString() != "" && !exists(dir)) {
            Directory.create(dir, recursive: true)
        }

        this.file = File(this.fileName, OpenMode.Append)
        this.curSize = this.file.info.size
        this.opendate = this.file.info.creationTime.dayOfMonth

        logWriteToFile()
    }

    private func compressRollingFile(): Unit {
        var fileDir = this.file.info.parentDirectory.getOrThrow()
        var paths: HashSet<String> = HashSet<String>()
        for (file in Directory.readFrom(fileDir.path)) {
            var num = file.path.toString().count(".log")
            var fileList: Array<String> = this.fileName.split("/")
            var fileName: String = fileList[fileList.size-1]
            if (file.isRegular() && num >= 2 && file.path.toString().contains(fileName)) {
                var name: String = file.path.fileNameWithoutExtension
                var names: Array<String> = name.split("_")
                var zip = ZipFile(fileDir.path.toString() + "/log_" + fileName + "_" + names.get(1).getOrThrow() + ".zip")
                zip.addFile(file.path.toString())
                if(exists(file.path)){
                    remove(file.path)
                }
            }
        }
    }

    /**
     * Close file.
     */
    public func close(): Unit {
        let fut: Future<Unit> = spawn {
            while (true) {
                if (writeCompleted) {
                    if (!this.file.isClosed()) {
                        this.file.flush()
                        this.file.close()
                    }
                    return
                }
                sleep(5 * Duration.millisecond)
            }
        }
        
        fut.get()
        return
    }

    /**
     * Write log to file. 可以使用异步，但必须要有个写完的返回值，
     *
     * @param rec log recording.
     */
    public func logWrite(rec: LogRecord): Unit {
        lock.lock()
        contentList.addLast(rec)
        lock.notifyAll()
        lock.unlock()
    }

    private func logWriteToFile(): Unit {
        let fut: Future<Unit> = spawn {
            while (true) {
                lock.lock()
                if (let Some(rec) <- (contentList.removeFirst())) {
                    writeCompleted = false
                    if (this.file.isClosed()) {
                        this.file = File(this.fileName, OpenMode.Append)
                        this.curSize = this.file.info.size
                        this.opendate = this.file.info.creationTime.dayOfMonth
                    }
                
                    // Formatting logging.
                    var mess = getDefaultPatternConvert().formatLogRecord(this.pattern, rec).replace("\"", "").toArray()
                    
                    try {
                        this.file.write(mess)
                    } catch (e: FSException) {
                        println("write file occur exception: ${e.message}")
                        return
                    }
                    let n = mess.size

                    // Update the size.
                    this.curSize += n

                    let now = DateTime.now()
                    if ((this.maxSize > 0 && this.curSize >= this.maxSize) || (this.daily && now.dayOfMonth != this.opendate)) {
                        // lock.unlock()    
                        writeCompleted = true
                        rollingFile()
                        // lock.lock()
                    }

                    compressRollingFile()
                    lock.unlock()
                } else {
                    writeCompleted = true
                    lock.wait()
                }
            }
        }
    }

    // If this is called in a threaded context, it must be synchronized.
    private func rollingFile(): Unit {
        if (!this.rotate) {
            return
        }

        lock.lock()

        // Close current file.
        close()

        var fname = ""

        // If daily in the configuration is true (archived by day), the opening date is not the same as the current day.
        if (this.daily && DateTime.now().dayOfMonth != this.opendate) {
            // Get yesterday's time, format to day.
            let yesterday = DateTime.now().addDays(-1).toString(DateTimeFormat.of("YYYYMMddhhmmss-SS"))
            fname = this.fileName + "_" + yesterday + ".log"
        } else {
            fname = this.fileName + "_" + DateTime.now().toString(DateTimeFormat.of("YYYYMMddhhmmss-SS")) + ".log"
        }
        try {
            //An error message is returned when the current file is named fname.
            rename(this.fileName, to: fname, overwrite: false)
            //Open a new file.
            this.file = File(this.fileName, OpenMode.Append)
        } catch (e: IllegalArgumentException | FSException) {
            lock.unlock()
            println("rolling file occur exception: ${e.message}")
            return
        }

        // Set the daily open date to the current date.
        this.opendate = DateTime.now().dayOfMonth
        this.curSize = 0

        //Indicates whether to start the thread to run.
        deleterollingFile()
        lock.unlock()
    }

    /**
     * Delete log files whose storage duration exceeds the retention period.
     */
    private func deleterollingFile(): Unit {
        try {
            let fileDir = this.file.info.parentDirectory.getOrThrow()
            for (file in Directory.readFrom(fileDir.path)) {
                if (file.path.toString().contains(".log") && file.lastModificationTime.addDays(this.retentionDays) <
                    DateTime.now()) {
                    remove(file.path)
                }
            }
        } catch (e: NoneValueException) {
            println("logfile Directory is none")
            return
        } catch (e: FSException) {
            println("delete log file has occur an exception")
        }
    }
}
