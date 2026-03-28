# fountain实现思想与应用第七弹

##### ——日志

项目链接：https://gitcode.com/Cangjie-SIG/fountain

![image-20251113195458091](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC07%E5%BC%B9%E2%80%94%E2%80%94%E6%97%A5%E5%BF%97/image-20251113195458091.png)

### LogPattern

日志格式由LogPattern定义，日志格式由%开头的标记定义日志字段，每个字段都实现接口LogPart，现在支持以下格式：

-   %level——日志级别。
-   %app——当前应用的名称，应用项目使用`fboot build`时会把项目根目录cjpm.toml的name和version节点读取出来，并创建一个新的模块，用项目名称和项目版本号调用`fountain.app.AppVersion`。%app对应的AppLogPart会从AppVersion获取应用名称。
-   %appver——当前应用的版本号。版本来源如前所述。
-   %name——当前日志的名称。日志实例初始化时都会指定名称作为日志实例的唯一标识。
-   %fver——fountain的版本号。
-   %tname——当前线程的名称。
-   %tid——当前线程的ID。
-   %pid——当前进程的ID。
-   除此之外日志模板中的其它内容都初始化为OriginLogPart，日志记录器会原样输出这些文本。

默认的格式为`"[%level-%name] %d{yyyy/MM/dd,HH:mm:ss.SSS}|%m"`。

### Logger

Logger定义了记录日志的各种函数，应用代码可以调用它们记录日志。比如下面这样。

```cj
log.info{'这是一行日志'}
log.info('user.session:{};{}', [userId, token])
//session是一个包含userId和token属性的类实例，这个类被@DataAssist[fields]修饰
log.info('user.session:{userId};{token}', session)
log.error('user.login:{}', e, [userId])
```

### AbstractLogger

定义日志同步逻辑，每一行日志最后以`\0`作为结束标记。核心是以下四个函数。

```cj
    protected func appendException(ex: ?Exception, output: LogWriter): Unit {
        if (let Some(e) <- ex) {
            output.writeException(e)
        }
    }
    private func append(level: LogLevel, message: String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        pattern.generate(name, level, message, now, tid, writer)
        appendException(ex, writer)
        writer.writeString('\0')
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
```

### AsyncLogger

定义了一个以`ArrayBlockingQueue<ArrayList<Array<Byte>>>`模拟的输出流SyncQueueOutputStream，AsyncLogger劫持了具体的日志记录器（比如ConsoleLoggerAppender、FileLoggerAppender）创建的日志输出流，并以SyncQueueOutputStream的实例代替实际日志输出流作为它的父类AbstractLogger的初始化参数。AsyncLogger的实例维持着实际的日志输出流。

调用日志记录器的日志函数时实际都写到了SyncQueueOutputStream，为了避免多线程将不同的日志乱序推入ArrayBlockingQueue，SyncQueueOutputStream内部有一个`ThreadLocal<ArrayList<Array<Byte>>>`，从AbstractLogger写入SyncQueueOutputStream时都会从同步队列获取ArrayList，并把它填充到ThreadLocal，直到写`\0`之前都从ThreadLocal获取这个ArrayList。每一个LogPart转化的字节数组都会推入这个ArrayList。当遇到`\0`这个ArrayList将被推入异步日志队列。SyncQueueOutputStream的核心代码如下：

```cj
	public func write(bytes: Array<Byte>): Unit {
        let buf: ArrayList<Array<Byte>> = if(let Some(buf) <- buffer.get()){
            buf
        }else{
            let buf = pool.remove()
            buffer.set(buf)
            buf
        }
        if(bytes[bytes.size - 1] == b'\0'){//todo 这个做法性能有些低，但是性能高的做法会导致BUG。
            let b = bytes[0 .. bytes.size - 1]
            buf.add(b)
            queue.add(buf)
            buffer.set(None)
        }else{
            buf.add(bytes)
        }
    }
```

AsyncLogger线程从线程安全队列获得`ArrayList<Array<Byte>>`，将ArrayList中的字节数组写到实际的日志输出流。核心的代码如下：

```cj
    private func append() {
        let buffer = (super.output as SyncQueueOutputStream).getOrThrow()
        if (buffer.size > 0) {
            append {//这个闭包被推入AsyncLogger内部的一个队列
                while(let Some(buf) <- buffer.tryRemove() && let s <- buf.size && s > 0){
                    try{//buf就是ArrayList<Array<Byte>>
                        for(bytes in buf where bytes.size > 0){
                            this.actualOutput.write(bytes)
                        }//actualOutput就是实际的日志输出流
                        this.actualOutput.flush()
                    }finally{//将ArrayList归还SyncQueueOutputStream
                        buffer.returnBuffer(buf)
                    }
                }
            }
        }
    }
```

AsyncLogger内部维持一个队列：`private let queue: ArrayBlockingQueue<() -> Unit>`。AsyncLogger内部线程一直监听并消费这个队列：

```cj
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
```

### LoggerAppenderFacade

本类维持着每一个实际的日志记录器，`private let appenders = Array<AbstractLogger>`。

本类覆盖了AsyncLogger的以下函数。

```cj
protected func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        append {//appender是实际的日志记录器，这个闭包会被AsyncLogger内的线程消费
            for (appender in appenders) {
                appender.append(level, message, now, tid, ex)
            }
        }
    }
```

### `BaseLoggerParams<T> where T <: BaseLoggerParams<T>`

每一个日志记录器都有一个初始化参数类型，它们都是BaseLoggerParams的子类。BaseLoggerParams的register函数调用子类覆盖的以下函数，此函数获得日志配置返回配置参数实例：

```cj
protected static func newParams(appender: String): T 
```

BaseLoggerParams的register函数会把具体的日志记录器初始化过程注册到LoggerAppenderCreator。

```cj
    static func register(loggerName: String, appenderMap: ConcurrentHashMap<T, AbstractLogger>): Unit {
        LoggerAppenderCreator.register(loggerName) {
            name =>...}
    }
```

### LoggerAppenderCreator

```cj
public class LoggerAppenderCreator {
    private static let creators = ConcurrentHashMap<String, (String) -> Array<AbstractLogger>>()
    //BaseLoggerParams的register函数调用的就是这个函数
    public static func register(kind: String, creator: (String) -> Array<AbstractLogger>) {
        creators.add(kind, creator)
    }
    //每次初始化日志实例时都会调用到此处
    public static func create(name: String): LoggerAppenderFacade {
        let loggers = ArrayList<AbstractLogger>()
        for ((_, creator) in creators) {
            for (logger in creator(name) where !(logger is NoneLogAppender)) {
                loggers.add(logger)
            }
        }
        LoggerAppenderFacade(name, loggers.unsafeData())
    }
}

```

### LoggerWrapper与LoggerFactory

LoggerFactory的功能就是用指定的日志实例名称实例化LoggerWrapper。LoggerWrapper的构造函数会调用LoggerAppenderCreator初始化LoggerAppenderFacade。

### ConsoleLoggerAppender

每个日志记录器都用以下类似的方式初始化：

```cj
let _ = ConsoleLoggerAppender.register() //将本实现注册到LoggerAppenderCreator
```

### FileLoggerAppender

内部维持一个RotabableFile实例。RotatableFile实现了OutputStream，每次执行write函数时都会按照配置指定的周期和日志文件大小检查是否需要切分日志文件。判断逻辑如下：

```cj
    private func needRotate(current: DateTime, appended: Int64) {
        let file = this.file
        let fileInfo = file.info
        (fileInfo.creationTime < current || fileInfo.size + appended >= fileSize, file)
    }
```

current参数是将当前时间按照配置的时间周期截取正确的时间单位，如果配置切分单位是DAY则截取代码如下：

```cj
            case DAY =>
                let year = t.year
                let month = t.month
                let day = t.dayOfMonth
                let hour = 0
                let min = 0
                let sec = 0
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
```

### 配置与实例化

```bash
    export logger_appender_console=FDemoConsole
    export logger_appender_FDemoConsole_level=DEBUG
    export logger_appender_FDemoConsole_pattern='[%level-%name]%d{yyyy/MM/dd,HH:mm:ss.SSS}|%tid;%m'
    export logger_appender_file=FDemoFile
    export logger_appender_FDemoFile_level=INFO
    export logger_appender_FDemoFile_pattern='[%level-%name]%d{yyyy/MM/dd,HH:mm:ss.SSS}|%tid;%m'
    export logger_appender_FDemoFile_path=./log/fdemo.log
    export logger_appender_FDemoFile_rotateDuration=DAY
```

下面的代码以`"opengauss"`为名实例化了一个日志实例。

```cj
let logger = LoggerFactory.getLogger("opengauss")
```

