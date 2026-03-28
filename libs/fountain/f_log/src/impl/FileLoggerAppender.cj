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
package f_log.impl

class FileLoggerAppender <: AsyncLogger {
    private static const LOGGER_NAME = 'file'
    public init(
        name!: String,
        pattern!: LogPattern,
        level!: LogLevel = LogLevel.INFO,
        file!: OutputStream
    ) {
        super(name, level, pattern, file, '${LOGGER_NAME}:///${toPath(file)}')
    }
    protected func new(name: String): AbstractLogger {
        FileLoggerAppender(name: name, pattern: super.pattern, level: super.level, file: super.actualOutput)
    }
    @When[os == "Linux"]
    private static func toPath(file: OutputStream) {
        match(file){
            case x: RotatableFile => x.path
            case x: RotatableMMapFile => x.path
            case _ => ''
        }
    }
    @When[os != "Linux"]
    private static func toPath(file: OutputStream) {
        match(file){
            case x: RotatableFile => x.path
            case _ => ''
        }
    }
    private static let appenderMap = ConcurrentHashMap<FileLoggerParams, AbstractLogger>()
    public static func register(): Unit {
        FileLoggerParams.register(LOGGER_NAME, appenderMap)
    }
}
public class FileLoggerParams <: BaseLoggerParams<FileLoggerParams> {
    public FileLoggerParams(
        level: LogLevel,
        pattern: LogPattern,
        protected let url: String,
        protected let params: RotatableFileParams,
        protected let mmap: Bool
    ){
        super(level, pattern)
        h = HashBuilder().append(level).append(pattern).append(url).append(params).append(mmap).build()
    }
    public operator func ==(that: FileLoggerParams): Bool {
        this.h == that.h && this.level == that.level && this.pattern == that.pattern && 
        this.url == that.url && this.params == that.params && this.mmap == that.mmap
    }
    protected static func newParams(appender: String): FileLoggerParams {
        let params = RotatableFileParams()
        let url = if (let Some(url) <- LoggerConfig.getString(appender, 'url')) {
            url
        } else {
            ''
        }
        if (let p <- LoggerConfig.getLogFilePath(appender) && !p.isEmpty()) {
            params.path = p
        }
        if (let d <- LoggerConfig.getLogFileRotateDuration(appender) && 
            let Some(u) <- TimeUnit.tryParse(d)) {
            params.timeunit = u
        }
        if (let s <- LoggerConfig.getLogFileRotateSize(appender) && !s.isEmpty()) {
            params.fileSize = RotatableFile.computeBytes(s)
        }
        if (let c <- LoggerConfig.getLogFileCompressFormat(appender) && !c.isEmpty()) {
            params.compress = RotatableFile.compressFormat(c)
        }
        let mmap = LoggerConfig.getLogFileMMap(appender)
        FileLoggerParams(LoggerConfig.getLevelConf(appender), LoggerConfig.getPatternConf(appender),
            url, params, mmap)
    }
    protected func newAppender(name: String): AbstractLogger {
        let rf = if (url.isEmpty()) {
            RotatableFile(params)
        } else {
            RotatableFile(url, params)
        }
        @When[os == "Linux"]
        let output: OutputStream = if(mmap){
            rf.mmap()
        }else{
            rf
        }
        @When[os != "Linux"]
        let output: OutputStream = rf
        FileLoggerAppender(
            name: name,
            level: level,
            pattern: pattern,
            file: output
        )
    }
}
let _ = FileLoggerAppender.register()
