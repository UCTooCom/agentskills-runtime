# f_log API Documentation

## 功能介绍

`f_log` 模块用于提供灵活、高性能的日志系统，实现日志记录、输出、格式化和管理。
模块支持同步和异步日志记录、日志级别管理、日志模板定制、Appender 扩展以及异常处理。
同时提供可视化日志输出（带颜色文本），并支持多种日志输出策略和超时控制。

## 接口

| 接口名 | 功能说明 |
| --- | --- |
| `ExtendLogLevel` | 扩展日志级别接口，增加带颜色的文本表示属性。 |
| `LogFilter` | 日志过滤器接口，用于在日志输出前转换或过滤日志内容。 |
| `LogPart` | 日志模板组成部分接口，定义日志输出组件的生成方法。 |

## 类

| 类名 | 功能说明 |
| --- | --- |
| `AbstractLogger` | 抽象日志器基类，实现日志记录、级别管理、输出和异常打印，支持线程安全锁机制和资源关闭控制。 |
| `AsyncLogger` | 异步日志器，继承 `AbstractLogger`，使用队列异步处理日志写入任务，支持超时策略和异步队列管理。 |
| `LogException` | 日志操作异常类，当日志操作失败时抛出。 |
| `Logger` | 抽象日志记录类，封装日志输出、级别判断和格式化逻辑，支持多种日志级别及异常日志处理。 |
| `LoggerAppenderCreator` | 日志输出器工厂，注册并创建具体 Appender 实例，支持多种类型的日志输出器。 |
| `LoggerAppenderFacade` | 日志输出门面，封装多个 Appender，实现统一日志接口和级别判断。 |
| `LoggerConfig` | 日志配置管理类，读取全局或 Appender 相关配置，支持日志级别、模式及异步策略。 |
| `LoggerFactory` | 日志工厂类，用于创建和管理 `AbstractLogger` 实例，支持按名称或类型获取日志，并可刷新所有日志实例。 |
| `LoggerWrapper` | 日志包装类，实现 `AbstractLogger`，封装 `LoggerAppenderFacade` 并支持动态刷新。 |
| `LogPattern` | 日志格式模板类，解析日志格式字符串并生成日志输出内容。 |
| `NoneLogAppender` | 无操作日志输出器，实现 `AbstractLogger`，不输出任何日志信息，适用于禁用日志或占位。 |
| `ConsoleLoggerAppender` | 控制台日志输出器实现。 |
| `FileLoggerAppender` | 文件日志输出器实现，支持滚动和压缩。 |
| `TcpLoggerAppender` | TCP套接字日志输出器实现。 |
| `UdpLoggerAppender` | UDP套接字日志输出器实现。 |
| `UnixDatagramLoggerAppender` | Unix域数据报套接字日志输出器实现。 |
| `UnixLoggerAppender` | Unix域流式套接字日志输出器实现。 |

## 枚举类型

| 枚举名 | 功能说明 |
| --- | --- |
| `AsyncTimeoutPolicy` | 异步日志超时策略，包括 `AlwaysWaiting`、`Discard` 和 `Abort`。 |
| `LogFileCompressFormat` | 日志文件压缩格式，包括 `NonCompression`、`Deflate` 和 `GZip`。 |

---

## 接口详情

### public interface ExtendLogLevel

**功能：**
提供日志级别的文本表示属性，用于控制台输出显示不同颜色。

**属性：**
*   `prop text: String` — 返回带颜色的日志级别文本。

### public interface LogFilter

**功能：**
定义日志过滤器，用于在日志内容写入前对其进行转换或过滤。可以过滤键值对属性或字符串键值对。

**方法：**
*   `func filter(attr: Attr): ?Attr` — 过滤一个 `Attr` 键值对。返回 `None` 表示丢弃该属性。
*   `func filter(name: String, value: String): ?(String, String)` — 过滤一个字符串键值对。返回 `None` 表示丢弃该属性。

### public interface LogPart

**功能：**
定义日志输出组件接口。所有日志模板组件必须实现 `generate` 方法，用于生成对应部分的日志内容。

**方法：**
*   `func generate(name: String, level: LogLevel, message: ToString, current: DateTime, tid: Int64, writer: LogWriter): Unit` — 输出当前日志组件内容到 `LogWriter`。

---

## 类详情

### public abstract class AbstractLogger <: Logger & Resource

**功能：**
`AbstractLogger` 提供基础日志功能，包括日志级别控制、日志输出、日志记录附加属性、异常打印以及线程安全机制。

**构造方法：**
*   `protected init(name: String, level: LogLevel, pattern: LogPattern, output: OutputStream, tag: String)` — 初始化日志器，设置名称、日志级别、输出模式、输出流和线程安全标签。

**方法/属性：**
*   `public mut prop level: LogLevel` — 获取或设置日志级别。
*   `protected mut prop output: OutputStream` — 获取或设置日志输出流，同时更新日志写入器。
*   `public open func isClosed(): Bool` — 判断输出流是否已关闭。
*   `public open func close(): Unit` — 关闭日志输出流。
*   `public mut prop closable: Bool` — 设置日志器是否允许关闭输出流。
*   `public func withAttrs(attrs: Array<Attr>): Logger` — 为当前线程的下一次日志记录绑定线程局部属性。
*   `public open func log(record: LogRecord): Unit` — 写入完整的日志记录。
*   `protected func append(level: LogLevel, message: () -> String, ex: Option<Exception>): Unit` — 根据日志级别追加日志的核心方法。
*   `protected func appendException(ex: ?Exception, output: LogWriter): Unit` — 将异常堆栈输出到日志。
*   `protected func doLock<T>(callback: () -> T): T` — 使用互斥锁保证线程安全。

### public abstract class AsyncLogger <: AbstractLogger

**功能：**
`AsyncLogger` 扩展 `AbstractLogger`，通过共享的阻塞队列异步处理日志任务，提高多线程环境下日志写入性能，支持超时策略（等待、丢弃或中止）。

**构造方法：**
*   `public init(name: String, level: LogLevel, pattern: LogPattern, output: OutputStream, queueTag: String)` — 初始化异步日志器，创建或复用队列并设置异步策略。

**方法/属性：**
*   `public open func close(): Unit` — 关闭输出流，并处理异步队列的引用计数。
*   `public open func log(record: LogRecord): Unit` — 写入日志记录，并将任务加入异步队列。
*   `protected func append(fn: () -> Unit): Unit` — 将写入任务提交到异步队列，根据策略处理超时。

### public abstract class Logger <: stdx.log.Logger

**功能：**
`Logger` 类是日志记录的基础抽象，提供多种 `append` 和便捷方法用于输出日志，同时封装日志级别判断逻辑。

**属性：**
*   `public mut prop level: LogLevel` — 当前日志级别。
*   `public prop traceEnabled: Bool` / `debugEnabled: Bool` / `infoEnabled: Bool` / `warnEnabled: Bool` / `errorEnabled: Bool` / `fatalEnabled: Bool` — 判断各日志级别是否启用。

**方法：**
*   `public open func logLevelEnabled(level: LogLevel): Bool` — 判断指定日志级别是否启用。
*   `protected func append(level: LogLevel, message: () -> String, ex: ?Exception): Unit` — 核心日志输出方法，子类实现具体日志写入逻辑。
*   `public func append<T>(level: LogLevel, message: String, args: Array<T>, ex: ?Exception)` — 支持数组、列表、映射和 `@DataAssist` 修饰的对象进行模板格式化日志输出，使用 `TextTemplate` 处理占位符 `{}`。
*   `public func error/warn/info/debug/trace(...)` — 提供不同日志级别的便捷方法，支持多种参数组合，包括字符串、异常、闭包消息、格式化参数等。

### public class LoggerAppenderCreator

**功能：**
管理日志输出器（Appender）的注册与创建。

**静态方法：**
*   `register(kind: String, creator: (String) -> Array<AbstractLogger>): Unit` — 注册一个日志输出器类型，并提供一个创建器函数。
*   `create(name: String): LoggerAppenderFacade` — 根据名称创建 `LoggerAppenderFacade`，该外观对象集合了所有已注册的、为该`name`的`Logger`所配置的非空输出器。

### public class LoggerAppenderFacade <: AsyncLogger

**功能：**
实现日志消息的统一分发，它本身是一个 `AsyncLogger`，内部封装了多个 `AbstractLogger` 输出器。

**构造方法：**
*   `init(name: String, appenders: Array<AbstractLogger>)` — 使用名称和输出器数组初始化外观对象。

**方法/属性：**
*   `logLevelEnabled(level: LogLevel): Bool` — 只要有一个内部Appender启用了该级别，就返回`true`。
*   `log(record: LogRecord): Unit` — 将日志记录异步分发到所有内部Appender。
*   `close(): Unit` — 关闭所有内部Appender。

### public class LoggerConfig

**功能：**
提供从环境变量读取日志相关配置的访问，包括输出器列表、日志级别、格式以及异步策略参数。

**静态方法：**
*   `getAppenders(kind: String): Array<String>` — 获取指定类型的输出器名称列表。
*   `getLevelConf(appender: String): LogLevel` — 获取输出器日志级别配置。
*   `getPatternConf(appender: String): LogPattern` — 获取输出器日志格式配置。
*   `getAsyncBufSize(): Int64` — 获取异步日志缓冲区大小。
*   `getAsyncTimeout(): Duration` — 获取异步日志等待超时时间。
*   `getAsyncTimeoutPolicy(): AsyncTimeoutPolicy` — 获取异步日志超时策略。
*   以及其他获取特定Appender（如File, TCP, UDP, Unix）配置的方法。

**属性：**
*   `public static mut prop filter: LogFilter` — 获取或设置全局的日志过滤器。

### public class LoggerFactory

**功能：**
创建和管理日志实例，支持全局属性映射，并提供刷新功能。这是获取`Logger`实例的入口。

**静态方法：**
*   `getLogger(name: String, attrs: Array<Attr> = []): AbstractLogger` — 根据指定名称和属性数组获取日志实例。
*   `getLogger<O>(attrs: Array<Attr> = []): AbstractLogger` — 使用泛型类型 `O` 的全限定名作为日志实例标识。
*   `getLogger(typeInfo: TypeInfo, attrs: Array<Attr> = []): AbstractLogger` — 使用 `TypeInfo` 的全限定名作为日志实例标识。
*   `refresh(): Unit` — 刷新所有日志实例，使其重新加载配置并更新 `LoggerAppenderFacade`。

### public class LoggerWrapper <: AbstractLogger

**功能：**
`LoggerFactory` 返回的实际类型。它包装了一个 `LoggerAppenderFacade`，提供日志分发和动态刷新功能。

**构造方法：**
*   `init(name: String)` — 使用名称初始化日志包装器，并创建对应的 `LoggerAppenderFacade`。

**方法/属性：**
*   `logLevelEnabled(level: LogLevel): Bool` — 判断指定日志级别是否可用，通过委托给内部 facade 实现。
*   `log(record: LogRecord): Unit` — 将日志记录追加到 facade。
*   `refresh(): Unit` — 刷新日志包装器，创建新的 `LoggerAppenderFacade` 替换旧实例并关闭旧实例。

### public class LogPattern <: LogPart & Hashable & Equatable<LogPattern>

**功能：**
表示日志输出的格式模板。根据模板字符串解析成多个 `LogPart` 组件，支持多种预设的日志内容部分。

**构造方法：**
*   `public init(pattern: String)` — 使用指定日志模板字符串创建 `LogPattern` 对象。

**方法/属性：**
*   `public func generate(name: String, level: LogLevel, message: ToString, current: DateTime, tid: Int64, writer: LogWriter): Unit` — 根据模板生成日志内容并写入 `LogWriter`。
*   **支持的模板占位符**:
    *   `%level`: 日志级别
    *   `%name`: 日志记录器名称
    *   `%app`: 应用名称
    *   `%appver`: 应用版本
    *   `%fver`: fountain框架版本
    *   `%tname`: 线程名称
    *   `%tid`: 线程ID
    *   `%d{...}`: 日期，花括号内为格式
    *   `%m`: 日志消息

---

## 枚举类型详情

### public enum AsyncTimeoutPolicy

**功能：**
定义异步日志操作在队列已满且等待超时的情况下的处理策略。

**枚举值：**
*   `AlwaysWaiting` — 始终等待，直到队列有空间。
*   `Discard` — 超时后丢弃当前日志。
*   `Abort` — 超时后抛出 `LogException`。

---

## 扩展详情

### extend LogLevel <: ExtendLogLevel

**功能：**
为 `stdx.log.LogLevel` 枚举类型添加 `text` 属性，实现 `ExtendLogLevel` 接口，使日志级别在控制台中可视化显示。

**属性实现：**
| 属性名 | 类型 | 功能说明 |
| --- | --- | --- |
| `text` | `String` | 返回带ANSI颜色的日志级别文本，用于控制台显示。不同级别对应不同颜色。 |

---

# 快速上手 

以下是一个结合了日志记录和 MVC 参数绑定的控制器示例：

```cj
package user.controller

import fountain.bean.* 
import fountain.mvc.*
import fountain.mvc.macros.*
import fountain.log.LoggerFactory
import fountain.log.Logger

/**
 * 一个演示日志记录和 MVC 参数绑定的控制器
 */
@Controller
public class GreetingController {

    private static let log = LoggerFactory.getLogger<GreetingController>()

    /**
     * 定义一个 /greet 接口
     * 它接受 'name' 和 'mood' 作为必需的查询参数
     * 示例: /greet?name=fountain&mood=angry
     */
    @GetMapping[path:"/greet", produces:'text/plain;charset=UTF-8']
    @IgnoreSecurity
    public func greet(@RequestParam name: String, @RequestParam mood: String): String {
        
        log.info("开始处理 /greet 请求, name: '{}', mood: '{}'", [name, mood])
        
        let response: String
        
        // 使用区分大小写的比较
        if (mood == "angry") {
            log.warn("为 '{}' 生成一个愤怒的问候。", [name])
            response = "走开, ${name}!"
        } else {
            log.info("为 '{}' 生成一个开心的问候。", [name])
            response = "你好, ${name}! 祝你拥有美好的一天。"
        }
        
        log.debug("问候语已生成，准备返回。")
        return response
    }
}
```
