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
package f_log.output

import std.convert.Parsable
import std.collection.concurrent.ArrayBlockingQueue
import std.env
import std.fs.{File, Directory, OpenMode, exists, rename, removeIfExists}
import std.io.{SeekPosition, OutputStream}
import std.sync.{Timer, Mutex, AtomicOptionReference}
import std.time.DateTime
import stdx.compress.zlib.{WrapType, CompressLevel, CompressOutputStream}
import f_base.*
import f_io.*// 必须导入这个包mmap才生效
import f_time.TimeUnit

internal import f_log.exception.LogException

public class RotatableFileParams <: Hashable & Equatable<RotatableFileParams> {
    public var path = "${env.getWorkingDirectory()}/logs/${env.getCommand()}.log"
    public var fileSize = Int64.Max
    public var timeunit = TimeUnit.DAY
    public var compress = LogFileCompressFormat.NonCompression

    public operator func ==(that: RotatableFileParams): Bool {
        this.path == that.path && this.fileSize == that.fileSize && 
        this.timeunit.toString() == that.timeunit.toString() && this.compress == that.compress
    }
    private var h = 0
    public func hashCode(): Int64 {
        if (h == 0){
            h = HashBuilder().append(path).append(fileSize).append(timeunit.toString()).append(compress).build()
        }
        h
    }
}

protected class RotatableFile <: OutputStream & Resource {
    private let queue = ArrayBlockingQueue<() -> Unit>(1)
    private var rotateTimer = ZERO_TIMER
    private let fileSize: Int64
    private let timeunit: TimeUnit
    private let compress: LogFileCompressFormat
    private let directory: String
    private let file = AtomicOptionReference<File>()

    public init(url: String, params: RotatableFileParams) {
        let fileInfo = url["file://".size..]
        var idx = fileInfo.indexOf("?") ?? fileInfo.size
        let path = fileInfo[0..idx]
        let (directory, file) = createDirIfNeed(path)
        this.directory = directory
        this.file.store(file)
        if (idx < fileInfo.size) {
            idx = fileInfo.indexOf("rotateSize=") ?? -1
            if (idx > 0) {
                let end = fileInfo.indexOf("&", idx) ?? fileInfo.size
                fileSize = Int64.parse(fileInfo[idx + "rotateSize=".size..end])
            } else {
                fileSize = params.fileSize
            }
            idx = fileInfo.indexOf("rotateDuration=") ?? -1
            if (idx > 0) {
                let end = fileInfo.indexOf("&", idx) ?? fileInfo.size
                let duration = fileInfo[idx + "rotateDuration=".size..end]
                timeunit = TimeUnit.tryParse(duration).getOrThrow {LogException("rotateDuration=${duration}")}
            } else {
                timeunit = params.timeunit
            }
            idx = fileInfo.indexOf("compressFormat=") ?? fileInfo.size
            if (idx > 0) {
                let end = fileInfo.indexOf("&", idx) ?? fileInfo.size
                let format = fileInfo[idx + "compressFormat=".size..end]
                compress = compressFormat(format)
            } else {
                compress = params.compress
            }
        } else {
            fileSize = params.fileSize
            timeunit = params.timeunit
            compress = params.compress
        }
        rotateTimer = createRotateTimer()
    }
    public init(params: RotatableFileParams) {
        this.timeunit = params.timeunit
        this.fileSize = params.fileSize
        this.compress = params.compress
        let (directory, file) = createDirIfNeed(params.path)
        this.directory = directory
        this.file.store(file)
        rotateTimer = createRotateTimer()
    }
    public func isClosed(): Bool {
        file.load()?.isClosed() ?? true
    }
    @When[os != "Linux"]
    public func close(): Unit {
        file.load()?.close()
    }
    @When[os == "Linux"]
    public func close(): Unit {
        if(let Some(mm) <- this.mmapf){
            mm.setLength()
            mm.close()
        }else{
            file.load()?.close()
        }
    }
    @When[os == "Linux"]
    private var mmapf = None<RotatableMMapFile>
    @When[os == "Linux"]
    protected func mmap() {
        let file = this.file.load().getOrThrow()
        let len = file.length
        let mm = file.mmap(0, fileSize)
        mm.writeOffset = len
        let rmmf = RotatableMMapFile(this, mm)
        this.mmapf = rmmf
        rmmf
    }
    protected prop path: String {
        get() {
            (this.file.load()?.info.path.toString()).getOrThrow()
        }
    }
    private func createRotateTimer() {
        spawn {
            while (let fn <- queue.remove()) {
                fn()
            }
        }
        let timer = Timer.after(timeunit.since(datetime: timeunit.trim(DateTime.now()))) {
            rotateFileIfNeed(0)
            this.timeunit.since(datetime: timeunit.trim(DateTime.now()))
        }
        env.atExit {timer.cancel()}
        timer
    }
    private static func createDirIfNeed(path: String) {
        let directory = path[0..(path.lastIndexOf("/") ?? path.size)]
        if (!exists(directory)) {
            Directory.create(directory, recursive: true)
        }
        (directory, File(path, Append))
    }
    public static func compressFormat(format: String): LogFileCompressFormat {
        match (format) {
            case "None" => LogFileCompressFormat.NonCompression
            case "Deflate(BestSpeed)" | "DeflateFormat(BestSpeed)" => LogFileCompressFormat.Deflate(BestSpeed)
            case "Deflate(DefaultCompression)" | "Deflate(Default)" | "Deflate" | "DeflateFormat"
                | "DeflateFormat(DefaultCompression)" | "DeflateFormat(Default)" => LogFileCompressFormat.Deflate(
                DefaultCompression)
            case "Deflate(BestCompression)" | "DeflateFormat(BestCompression)" => LogFileCompressFormat.Deflate(
                BestCompression)

            case "GZip(BestSpeed)" | "GZipFormat(BestSpeed)" => LogFileCompressFormat.GZip(BestSpeed)
            case "GZip(DefaultCompression)" | "GZip(Default)" | "GZip" | "GZipFormat" | "GZipFormat(DefaultCompression)"
                | "GZipFormat(Default)" => LogFileCompressFormat.GZip(DefaultCompression)
            case "GZip(BestCompression)" | "GZipFormat(BestCompression)" => LogFileCompressFormat.GZip(BestCompression)
            case _ => throw IllegalArgumentException(
                "unsupported compress config ${format}. " +
                    " The supported compressing configs are None, Deflate(BestSpeed), DeflateFormat(BestSpeed)," +
                    " Deflate(DefaultCompression), DeflateFormat(Default)," +
                    " DeflateFormat(DefaultCompression), DeflateFormat(Default), Deflate, DeflateFormat," +
                    " Deflate(BestCompression), DeflateFormat(BestCompression)," +
                    " GZip(BestSpeed), GZipFormat(BestSpeed)," +
                    " GZip(DefaultCompression), GZipFormat(Default), GZip, GZipFormat," +
                    " GZipFormat(DefaultCompression), GZipFormat(Default)" +
                    " GZip(BestCompression), GZipFormat(BestCompression).")
        }
    }
    public static func computeBytes(bytes: String): Int64 {
        let b = bytes.trimAscii()
        var unit = b'b'
        var ne = bytes.size
        var bu = bytes[ne - 1]
        if (bu == b'b' || bu == b'B') {
            ne--
            bu = bytes[ne - 1]
            if ((bu >= b'a' && bu <= b'z') || (bu >= b'A' && bu <= b'Z')) {
                ne--
                unit = bu
            }
        } else if ((bu >= b'a' && bu <= b'z') || (bu >= b'A' && bu <= b'Z')) {
            ne--
            unit = bu
        }
        Int64.tryParse(bytes[0..ne]).getOrThrow {
                throw IllegalArgumentException(
                    "${b} is illegal bytes description, bytes description supports an integer number follows with r'k' 'kbr' 'mr' 'mbr' 'gr' 'gbr' 'tr' 'tbr' 'er' 'eb' or their upper cases")
            } * 1024 ** match (unit) {
            case b'b' | b'B' => 0
            case b'k' | b'K' => 1
            case b'm' | b'M' => 2
            case b'g' | b'G' => 3
            case b't' | b'T' => 4
            case b'p' | b'P' => 5
            case b'e' | b'E' => 6
            case b'z' | b'Z' | b'y' | b'Y' => throw IllegalArgumentException("${b} is overflow for Int64")
            case _ => throw IllegalArgumentException("${unit} is illegal byte unit")
        }
    }

    private static func genTime(timeunit: TimeUnit, current: DateTime): String {
        match (timeunit) {
            case DAY => current.addDays(-1).format("yyyyMMdd")
            case HOUR => current.addHours(-1).format("yyyyMMddHH")
            case WEEK => current.addWeeks(-1).format("yyyyMMddWW")
            case MINUTE => current.addMinutes(-1).format("yyyyMMddHHmm")
            case MONTH => current.addMonths(-1).format("yyyyMM")
            case YEAR => current.addYears(-1).format("yyyy")
            case SECOND => current.addSeconds(-1).format("yyyyMMddHHMMss")
            case _ => current.addNanoseconds(-1).format("yyyyMMddHHmmssSSS")
        }
    }
    private let fileLock = Mutex()
    func rotateFileIfNeed(appended: Int64) {
        synchronized(fileLock) { //此处不能使用双重检查锁，否则可能导致一个线程试图向另一个线程已经重命名的文件导致写失败
            let current = timeunit.trim(DateTime.now())
            let (need, file) = needRotate(current, appended)
            if (need) {
                let originPath = file.info.path.toString()
                try {
                    let time = genTime(timeunit, current)
                    let path = "${originPath}.${time}"
                    try {
                        this.close()
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    try {
                        rename(originPath, to: path, overwrite: false)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    compressAndDeleteOld(path)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                if (!exists(originPath)) {
                    this.file.store(File(originPath, Append))
                    @When[os == "Linux"]
                    let _ = if(let Some(mm) <- this.mmapf){
                        mm.mmap = this.file.load().getOrThrow().mmap(0, this.fileSize)
                        mm.mmap.writeOffset = 0
                    }
                }
            }
        }
    }
    private func needRotate(current: DateTime, appended: Int64) {
        let file = this.file.load().getOrThrow()
        let fileInfo = file.info
        (fileInfo.creationTime < current || fileInfo.size + appended >= fileSize, file)
    }
    private func closeFile(file: ?File): Unit {
        if (let Some(f) <- file) {
            if (f.isClosed()) {
                return
            }
            try {
                f.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    private func doCompress(path: String, ext: String, wrap: WrapType, level: CompressLevel) {
        var f = None<File>
        var compressedFile = None<File>
        try {
            f = File(path, OpenMode.Read)
            let fsize = f?.length ?? 0
            if (fsize == 0) {
                return
            }
            compressedFile = File("${path}${ext}", OpenMode.Write)
            let compressedOutput = CompressOutputStream(
                compressedFile.getOrThrow(),
                wrap: wrap,
                compressLevel: level
            )
            try {
                f?.seek(Begin(0))
                var buf = Array<Byte>(if (fsize >= 1024 ** 2) {
                    1024 ** 2
                } else {
                    fsize
                }, repeat: 0)
                var readLen = 0
                do {
                    readLen = f?.read(buf) ?? 0
                    if (readLen > 0) {
                        compressedOutput.write(buf[0..readLen])
                    }
                } while (readLen == buf.size)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                try {
                    compressedOutput.close()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            closeFile(f)
            closeFile(compressedFile)
            removeIfExists(path)
        }
    }
    private func compressAndDeleteOld(path: String) {
        queue.add(
            {
                => match (compress) {
                    case Deflate(level) => doCompress(path, ".lz", DeflateFormat, level)
                    case GZip(level) => doCompress(path, ".gz", GzipFormat, level)
                    case NonCompression => return
                }
            })
    }
    public func write(buffer: Array<Byte>): Unit {
        rotateFileIfNeed(buffer.size)
        file.load()?.write(buffer)
    }
    public func flush(): Unit {
        file.load()?.flush()
    }
}

public enum LogFileCompressFormat <: ToString & Hashable & Equatable<LogFileCompressFormat> {
    | NonCompression
    | Deflate(CompressLevel)
    | GZip(CompressLevel)

    private func eq(x: CompressLevel, y: CompressLevel): Bool {
        match((x, y)){
            case (BestCompression, BestCompression) => true
            case (BestSpeed, BestSpeed) => true
            case (DefaultCompression, DefaultCompression) => true
            case _ => false
        }
    }
    public operator func ==(that: LogFileCompressFormat): Bool {
        match((this, that)){
            case (NonCompression, NonCompression) => true
            case (Deflate(x), Deflate(y)) => eq(x, y)
            case (GZip(x), GZip(y)) => eq(x, y)
            case _ => false
        }
    }
    private func compressLevelString(level: CompressLevel){
        match(level){
            case BestCompression => "BestCompression"
            case BestSpeed => "BestSpeed"
            case DefaultCompression => "DefaultCompression"
        }
    }
    public func toString(): String {
        match(this){
            case NonCompression => "NonCompression"
            case Deflate(x) => 'Deflate(${compressLevelString(x)})'
            case GZip(x) => 'GZip(${compressLevelString(x)})'
        }
    }
    public func hashCode(): Int64 {
        toString().hashCode()
    }
}
