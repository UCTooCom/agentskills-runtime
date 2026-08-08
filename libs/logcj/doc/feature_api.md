# LogCJ

## 1.介绍
仓颉语言实现日志打印功能，类似 log4j 三方件

- 1.前置条件：json文件路径和名称为 ./src/resources/logcj.xml 未配置该文件时会使用默认设置

- 2.场景：
     * 支持使用JSON进行配置
     * 支持配置stdout、stderr等系统输出，支持文件系统日志输出
     * 支持配置单个日志大小，是否打包等属性
 
- 3.性能：支持版本几何性能持平

- 4.可靠性：NA

## 2.接口

### 2.1 LoggerAppender接口

主要方法

```cangjie
/**
 * 初始化appender
 *
 * 参数 pattern - 日志输出格式
 * 参数 property - appender属性集合
 */
func initAppender(pattern: String, property: ArrayList<AppenderProperty>): Unit

/**
 * 写日志之前
 */
func start(): Unit

/**
 * 写日志
 *
 * 参数 rec - 日志记录
 */
func logWrite(rec: LogRecord): Unit

/**
 * 写日志之后
 * 
 * 清除关于LogWrite的任何残留内容
 * 删除LogWrite，关闭后不应调用LogWrite
 */
func close(): Unit
```

### 2.2 ConsoleLoggerAppender

- 向控制台打印日志
- LoggerAppender接口实现类

主要方法
```cangjie
/**
 * 初始化appender
 *
 * 参数 pattern - 日志输出格式
 * 参数 property - appender属性集合
 */
public func initAppender(pattern: String, property: ArrayList<AppenderProperty>): Unit

/**
 * 写日志之前 空实现
 */
public func start(): Unit

/**
 * 格式化打印日志到控制台
 *
 * 参数 rec - 日志记录
 */
public func logWrite(rec: LogRecord): Unit

/**
 * 写日志之后 空实现
 */
public func close(): Unit
```

### 2.3 FileLoggerAppender

- 向文件中打印日志
- LoggerAppender接口实现类

主要方法
```cangjie
/**
 * 构造方法
 */
public init()

/**
 * 初始化日志配置文件中相关Appender的属性
 *
 * 参数 pattern - 日志输出格式
 * 参数 property - appender属性集合
 */
public func initAppender(pattern: String, property: ArrayList<AppenderProperty>): Unit

/**
 * 处理日志文件，打开文件，定义日志文件的文件名，操作日期等
 */
public func start(): Unit

/**
 * 写日志
 *   ·采用仓颉spawn...getResult..模式处理多线程
 *   ·判断文件是否关闭，如果关闭，则执行start方法，重新打开文件
 *   ·进行日志文件切分的情况
 *     比较日志文件的maxsize和当前文件的大小，当前文件大小大于maxsize，则进行切分
 *     判断文件按天归类，并且文件的操作日期和当前日期不相符，则进行切分
 *   ·格式化日志记录，写入文件
 *   ·重新计算当前日志的大小
 *
 * 参数 rec - 日志记录
 */
public func logWrite(rec: LogRecord): Unit

/**
 * 对日志文件进行刷新和关闭
 */
public func close(): Unit
```

### 2.4 LoggerAppenderFactory

- 根据名称或类型注册LoggerAppender
- 获取LoggerAppender的具体实现对象

主要方法

```cangjie
/**
  * 构造函数
  */
public init()

/**
 * 构造函数
 *
 * 参数 appender - LoggerAppender集合
 * 参数 appenderType  - LoggerAppender类型集合
 * 参数 typeLock  - 
 *
 * 返回值 LoggerAppenderFactory
 */
public init(
    appender: HashMap<String, LoggerAppender>,
    appenderType: HashMap<String, LoggerAppender>,
    typeLock: ReentrantMutex
)

/**
 * 清空工厂类中相关Appender属性，获得新的工厂类对象
 *
 * 返回值 LoggerAppenderFactory 工厂类对象
 */
public func new(): LoggerAppenderFactory

/**
 * 根据LoggerAppender的类型和类型名称注册Appender到工厂类的appenderType属性
 *
 * 参数 typename - LoggerAppender类型名称
 * 参数 typeClz  - LoggerAppender类型
 *
 * 返回值 LoggerAppenderFactory 工厂类对象
 */
public func registryType(typeName: String, typeClz: LoggerAppender): LoggerAppenderFactory

/**
 * 根据LoggerAppender的类型名称获取特定类型的LoggerAppender
 *
 * 参数 typename - LoggerAppender类型名称
 *
 * 返回值 LoggerAppender LoggerAppender类型对象
 */
public func getAppenderByType(typeName: String): LoggerAppender

/**
 * 根据LoggerAppender的名称获取特定类型的LoggerAppender
 *
 * 参数 typename - LoggerAppender名称
 *
 * 返回值 LoggerAppender
 */
public func getAppenderByName(name: String): LoggerAppender

/**
 * 根据LoggerAppender相关属性注册Appender到工厂类的剩余属性（写文件之前的准备工作）
 *
 * 参数 name       - LoggerAppender名称
 * 参数 typename   - LoggerAppender类型名称
 * 参数 pattern    - 日志输出格式
 * 参数 properties - Appender属性合集
 *
 * 返回值 LoggerAppenderFactory
 */
public func registerLoggerAppender(
    name: String,
    typename: String,
    pattern: String,
    properties: ArrayList<AppenderProperty>
): LoggerAppenderFactory
```
### 2.5 LoggerAppenderReference

- LoggerAppender参考模型类

主要方法

```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 构造函数
 *
 * 参数 level - 日志等级
 * 参数 appender - LoggerAppender集合
 */
public init(level: LogLevel, appenderList: ArrayList<LoggerAppender>)

/**
 * 获取LoggerAppender集合
 *
 * 返回值 ArrayList<LoggerAppender> LoggerAppender集合
 */
public func getAppenderList(): ArrayList<LoggerAppender>

/**
 * 设置LoggerAppender集合
 *
 * 参数 appenderList - LoggerAppender集合
 */
public func setAppenderList(appenderList: ArrayList<LoggerAppender>): Unit

/**
 * 获取日志等级
 *
 * 返回值 LogLevel 日志等级
 */
public func getLevel(): LogLevel

/**
 * 设置日志等级
 *
 * 参数 level - 日志等级
 */
public func setLevel(level: LogLevel): Unit

/**
 * 判断日志配置中Debug级别是否生效
 *
 */
public func isDebugEnabled(): Bool

/**
 * 判断日志配置中Info级别是否生效
 *
 */
public func isInfoEnabled(): Bool

/**
 * 判断日志配置中Error级别是否生效
 *
 */
public func isErrorEnabled(): Bool

/**
 * 判断日志配置中Warn级别是否生效
 *
 */
public func isWarnEnabled(): Bool

/**
 * 判断日志配置中Trace级别是否生效
 *
 */
public func isTraceEnabled(): Bool

/**
 * 判断日志配置中Fatal级别是否生效
 *
 */
public func isFatalEnabled(): Bool

/**
 * 判断日志配置中某个级别日志是否生效
 *
 * 参数 level - 日志级别
 *
 */
public func isEnabled(level: LogLevel): Bool
```

### 2.6 LoggerManager

- 解析日志配置文件得到配置项
- 解析默认配置
- 注册`ConsoleLoggerAppender`，`FileLoggerAppender`

主要方法

```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 初始化LoggerManager，通过内置路径得到日志配置项
 * 并且注册ConsoleLoggerAppender，FileLoggerAppender
 *
 *
 * 参数 xmlPath - 配置文件路径
 */
public init(xmlPath: String)

/**
 * 获取LoggerAppenderFactory
 *
 * 返回值 LoggerAppenderFactory 工厂类对象
 */
public func getLoggerAppenderFactory(): LoggerAppenderFactory

/**
 * 获取rootLogger的LoggerAppenderReference
 *
 * 返回值 LoggerAppenderReference rootLogger的LoggerAppenderReference
 */
public func getRootLogger(): LoggerAppenderReference

/**
 * 获取所有Logger的名称集合集合
 *
 * 返回值 ArrayList<String> LoggerName集合
 */
public func getLoggerNameArr(): ArrayList<String> 

/**
 * 获取所有Logger的LoggerAppenderReference集合
 *
 * 返回值 ArrayList<LoggerAppenderReference> LoggerAppenderReference集合
 */
public func getLoggerAttrArr(): ArrayList<LoggerAppenderReference>

/**
 * 根据Logger名称获取特定Logger
 *
 * 返回值 Logger Logger对象
 */
public func getLogger(name: String): Logger

/**
 * 初始化过程中如果日志配置文件路径不正确或者内容为空，则加载默认配置
 *
 *
 * 返回值 LoggerConfiguration 配置信息
 */
public func loadDefaultConfiguration(): LoggerConfiguration
```

### 2.7 Logger类

- 打印不同级别的日志信息到Console，File

主要方法

```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 获取Logger名称
 *
 * 返回值 String Logger名称
 */
public func getName(): String

/**
 * 根据传入的level和msg打印日志信息
 *
 * 参数 level - 日志级别 
 * 参数 msg - 日志记录消息
 *
 */
public func log(level: LogLevel, msg: String): Unit

/**
* 打印off级别日志
*
* 参数 msg - 日志记录消息
* 
*/
public func off(msg: String): Unit

/**
* 打印fatal级别日志
*
* 参数 msg - 日志记录消息
*
*/
public func fatal(msg: String): Unit

/**
* 打印error级别日志
*
* 参数 msg - 日志记录消息
* 
*/
public func error(msg: String): Unit

/**
* 打印warn级别日志
*
* 参数 msg - 日志记录消息
* 
*/
public func warn(msg: String): Unit

/**
* 打印info级别日志
*
* 参数 msg - 日志记录消息
* 
*/
public func info(msg: String): Unit

/**
* 打印debug级别日志
*
* 参数 msg - 日志记录消息
* 
*/
public func debug(msg: String): Unit

/**
* 打印trace级别日志
*
* 参数 msg - 日志记录消息
*/
public func trace(msg: String): Unit

/**
* 打印all级别日志
*
* 参数 msg - 日志记录消息
* 
*/
public func all(msg: String): Unit
```

### 2.8 AppenderConfig

主要接口
```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 构造函数
 *
 * 参数 enabled - Appender是否可以使用
 * 参数 name - Appender名称
 * 参数 appenderType - Appender类型 file or console
 * 参数 pattern - 输出格式 主要用于标准化输出时间的显示样式
 * 参数 properties - Appender属性列表
 */
public init(
    enabled: String,
    name: String,
    appenderType: String,
    pattern: String,
    properties: ArrayList<AppenderProperty>
)

/**
 * 获取Enabled属性
 *
 * 返回值 String Enabled值
 */
public func getEnabled(): String

/**
 * 设置Enabled属性
 *
 * 参数 enabled - Appender是否可以使用
 */
public func setEnabled(enabled: String): Unit

/**
 * 获取name
 *
 * 返回值 String Appender名称
 */
public func getName(): String

/**
 * 设置name
 *
 * 参数 name - Appender名称
 */
public func setName(name: String): Unit

/**
 * 获取appenderType
 *
 * 返回值 String Appender类型 file or console
 */
public func getAppenderType(): String

/**
 * 设置appenderType
 *
 * 参数appenderType Appender类型 file or console
 */
public func setAppenderType(appenderType: String): Unit

/**
 * 获取pattern
 *
 * 返回值 String 输出格式
 */
public func getPattern(): String

/**
 * 设置pattern
 *
 * 参数 pattern - 输出格式
 */
public func setPattern(pattern: String): Unit

/**
 * 获取properties
 *
 * 返回值 ArrayList<AppenderProperty> Appender属性列表
 */
public func getProperties(): ArrayList<AppenderProperty>

/**
 * 设置 properties
 *
 * 参数 properties - Appender属性列表
 */
public func setProperties(properties: ArrayList<AppenderProperty>): Unit
```
### 2.9 AppenderProperty

主要接口
```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 设置属性
 *
 * 参数 name - 属性名称
 * 参数 value - 属性值
 */
public init(name: String, value: String)

/**
 * 获取属性名称
 *
 * 返回值 String 属性名称
 */
public func getName(): String

/**
 * 设置属性名称
 *
 * 参数 name - 属性名称
 */
public func setName(name: String): Unit

/**
 * 获取属性值
 *
 * 返回值 String 属性值
 */
public func getValue(): String 

/**
 * 设置属性值
 *
 * 参数 value - 属性值
 */
public func setValue(value: String): Unit
```

### 2.10 AppenderRef

主要接口
```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 构造函数
 *
 * 参数 ref - appender-ref的属性值
 */
public init(ref: String)

/**
 * 获取appender-ref的属性值
 *
 * 返回值 String appender-ref的属性值
 */
public func getRef(): String
```

### 2.11 LoggerConfig

主要接口
```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 构造函数
 *
 * 参数 name - Logger名称
 * 参数 level - 日志等级
 * 参数 appenderRefList - appender-ref属性集合
 */
public init(name: String, level: String, appenderRefList: ArrayList<AppenderRef>)

/**
 * 获取name
 *
 * 返回值 String Logger名称
 */
public func getName(): String

/**
 * 设置name
 *
 * 参数 name - Logger名称
 */
public func setName(name: String): Unit

/**
 * 获取level
 *
 * 返回值 String 日志等级
 */
public func getLevel(): String

/**
 * 设置level
 *
 * 参数 level - 日志等级
 */
public func setLevel(level: String): Unit

/**
 * 获取appenderRefList
 *
 * 返回值 String appender-ref属性集合
 */
public func getAppenderRefList(): ArrayList<AppenderRef>

/**
 * 设置appenderRefList
 *
 * 参数 appenderRefList - appender-ref属性集合
 */
public func setAppenderRefList(appenderRefList: ArrayList<AppenderRef>): Unit
```

### 2.12 LoggerConfiguration

主要接口
```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 构造函数
 *
 * 参数 appenders - appender配置集合
 * 参数 root - root配置
 * 参数 logger - logger配置集合
 */
public init(appenders: ArrayList<AppenderConfig>, root: RootLoggerConfig, logger: ArrayList<LoggerConfig>)

/**
 * 获取appenders
 *
 * 返回值 ArrayList<AppenderConfig> appender配置集合
 */
public func getAppenders(): ArrayList<AppenderConfig>

/**
 * 获取root
 *
 * 返回值 RootLoggerConfig root配置
 */
public func getRoot(): RootLoggerConfig

/**
 * 获取logger
 *
 * 返回值 ArrayList<LoggerConfig> logger配置集合
 */
public func getLogger(): ArrayList<LoggerConfig>
```

### 2.13 RootLoggerConfig

主要接口
```cangjie
/**
 * 构造函数
 */
public init()

/**
 * 构造函数
 *
 * 参数 level - 日志等级
 * 参数 appenderRefList - appender-ref属性集合
 */
public init(level: String, appenderRefList: ArrayList<AppenderRef>)

/**
 * 获取logger
 *
 * 返回值 String  日志等级
 */
public func getLevel(): String

/**
 * 设置level
 *
 * 参数 level - 日志等级
 */
public func setLevel(level: String): Unit

/**
 * 获取appenderRefList
 *
 * 返回值 String appender-ref属性集合
 */
public func getAppenderRefList(): ArrayList<AppenderRef>

/**
 * 设置appenderRefList
 *
 * 参数 appenderRefList - appender-ref属性集合
 */
public func setAppenderRefList(appenderRefList: ArrayList<AppenderRef>): Unit
```

### 2.14 LogLevel

主要接口
```cangjie
ALL // 所有等级log
TRACE // Track级别日志
DEBUG // Debug级别日志
INFO // Notification级别日志
WARN // Warning级别日志
ERROR // Error级别日志
FATAL // Fatal级别日志
OFF // 禁用log

/**
 * 获取日志等级
 *
 * 返回值 Int64 
 *     ALL-1 TRACE-2 DEBUG-3 INFO-4 WARN-5 ERROR-6 FATAL-7 OFF-8
 */
public func level(): Int64

/**
 * 获取日志等级名称
 *
 * 返回值 String
 *     ALL-"ALL" TRACE-"TRACE" DEBUG-"DEBUG" INFO-"INFO" WARN-"WARN" ERROR-"ERROR" FATAL-"FATAL" OFF-"OFF"
 */
public func levelName(): String

/**
 * 重载>=运算符
 *
 * 参数 target - 日志等级对象
 * 返回值 Bool 配置等级是否大于或等于target等级 
 *     true 大于等  false 小于
 */
public operator func >=(target: LogLevel): Bool

/**
 * 根据名称获取日志等级对象
 *
 * 参数 lable - 日志等级名称
 * 返回值 LogLevel  日志等级对象
 */
public static func getLevelByString(lable: String): LogLevel
```

### 2.15 LogRecord

主要接口
```cangjie
/**
 * 构造函数
 */
public init(createdTime: Time)

/**
 * 构造函数
 *
 * 参数 tagName tag名称
 * 参数 level 日志等级
 * 参数 createdTime 创建时间
 * 参数 source source信息
 * 参数 message message信息
 */
public init(tagName: String, level: LogLevel, createdTime: Time, source: String, message: String)

/**
 * 获取tagName
 *
 * 返回值 String tag名称
 */
public func getTagName(): String

/**
 * 获取level
 *
 * 返回值 LogLevel 日志等级对象
 */
public func getLevel(): LogLevel

/**
 * 获取source
 *
 * 返回值 String source信息
 */
public func getSource(): String

/**
 * 获取message
 *
 * 返回值 String message信息
 */
public func getMessage(): String

/**
 * 获取createdTime
 *
 * 返回值 Time 创建时间
 */
public func getCreatedTime(): Time
```

### 2.16 PatternConverter

主要接口
```cangjie
/**
 * 格式化日志记录
 *
 * 参数 pattern 格式
 * 参数 logRecord 日志记录对象
 *
 * 返回值 String 格式化后的字符串
 */
func formatLogRecord(pattern: String, logRecord: LogRecord): String
```

### 2.17 func getDefaultPatternConvert()
```cangjie
/**
 * 获取默认格式化模型
 *
 * 返回值 PatternConverter 默认格式化模型对象
 */
public func getDefaultPatternConvert(): PatternConverter
```

### 2.18 DefaultPatternConverter

主要接口
```cangjie
/**
 * 格式化日志记录
 *
 * 参数 pattern 格式
 * 参数 logRecord 日志记录对象
 *
 * 返回值 String 格式化后的字符串
 */
public func formatLogRecord(pattern: String, logRecord: LogRecord): String
```

### 2.19 TimeSlice

主要接口
```cangjie
/**
 * 获取时间戳
 *
 * 参数 time 时间对象
 */
public func getTimeSlice(time: Time): Unit

/**
 * 获取短格式时间
 *
 * 返回值 String 短格式时间字符串-hh:mm
 */
public func getShortTime(): String

/**
 * 获取长格式时间
 *
 * 返回值 String 长格式时间字符串-hh:mm:ss:
 */
public func getLongTime(): String

/**
 * 获取短格式日期
 *
 * 返回值 String 短格式日期字符串-yy/MM/dd 
 */
public func getShortDate(): String

/**
 * 获取长格式日期
 *
 * 返回值 String 长格式日期字符串-yyyy/MM/dd 
 */
public func getLongDate(): String
```

### 2.20 util.cj文件

主要接口
```cangjie
/**
 * 将字符串向右对齐，并在剩余的位中补充指定的字符
 *
 * 参数 str 要转换的字符串
 * 参数 limit limit num.
 * 参数 placeholder 占位符
 * 
 * 返回值 return the processed result.
 */
public func flushLeft(str: String, limit: Int64, placeholder: String): String

/**
 * 解析带有K/M/G后缀的数字 基于 (1000) 或者 2^10 (1024) 
 *
 * 参数 str 要转换的字符串
 * 参数 mult 基数值(1000) 或者 2^10 (1024)
 * 参数 defaultValue 默认值
 *
 * 返回值 Int64 解析后数据
 */
public func strToNumBySuffix(str: String, mult: Int64, defaultValue: Int64): Int64

/**
 * 将数字字符串转换为int64
 *
 * 参数 str 要转换的字符串
 * 参数 defaultValue 转换异常时返回默认值
 *
 * 返回值 Int64 转换后的值
 */
public func getNumByString(str: String, defaultValue: Int64): Int64
```
## 3.日志级别

### 3.1等级关系

- ALL < TRACE < DEBUG < INFO < WARN < ERROR < FATAL < OFF

### 3.2日志输出说明

#### 3.2.1File

- 文件输出受配置文件中root和logger节点的level影响
- 举例说明：例如配置level为info，文件则输出info，warn，error，off级别的日志

#### 3.2.2Console

- 控制台输出和文件输出保持一致

### 3.3配置文件说明

```
{
    "appenders": [
        {
            "enabled": "true",
            "name": "console",
            "type": "console",
            "pattern": "[%D %T %m] [%L] [%l] (%S) %M"
        },
        {
            "enabled": "true",
            "name": "file",
            "type": "file",
            "pattern": "[%D %T %m] [%L] [%l] (%S) %M",
            "properties": [
                {
                    "name": "filename",
                    "value": "root.log"
                },
                {
                    "name": "rotate",
                    "value": "true"
                },
                {
                    "name": "maxsize",
                    "value": "20M"
                },
                {
                    "name": "daily",
                    "value": "false"
                }
            ]
        }
    ],
    "loggers":[
        {
            "name":"Demo",
            "level":"warn",
            "appender-refs": [
                {
                    "ref": "console"
                },
                {
                    "ref": "file"
                }
            ]
        }
    ],
    "root": {
        "level": "info",
        "appender-refs": [
            {
                "ref": "console"
            },
            {
                "ref": "file"
            }
        ]
    }
}
```
## 4.使用示例
### 4.1示例代码

```cangjie
import logcj.appender.*
import logcj.config.*
import logcj.logger.*
import logcj.utils.*

main(): Int64 {
    // Create a logger.
    let logger = LoggerManager.createManager("./logcj.json").getLogger("aaa")

    // Print logs.
    logger.all("1")
    logger.trace("2")
    logger.debug("3")
    logger.info("4")
    logger.warn("5")
    logger.error("6")
    logger.off("7")

    // Create another logger.
    let logger1 = LoggerManager.createManager("./logcj.json").getLogger("Demo")
    logger1.all("1")
    logger1.trace("2")
    logger1.debug("3")
    logger1.info("4")
    logger1.warn("5")
    logger1.error("6")
    logger1.off("789")

    return 0
}
```
### 4.2运行结果

#### 4.2.1控制台输出

```cangjie
[2024/07/19 11:43:23 CST 928] [INFO] [1] [root] <> 4
[2024/07/19 11:43:23 CST 928] [WARN] [1] [root] <> 5
[2024/07/19 11:43:23 CST 928] [ERROR] [1] [root] <> 6
[2024/07/19 11:43:23 CST 928] [OFF] [1] [root] <> 7
[2024/07/19 11:43:23 CST 928] [INFO] [1] [root] <> 4
[2024/07/19 11:43:23 CST 928] [WARN] [1] [root] <> 5
[2024/07/19 11:43:23 CST 928] [WARN] [1] [Demo] <> 5
[2024/07/19 11:43:23 CST 928] [ERROR] [1] [root] <> 6
[2024/07/19 11:43:23 CST 929] [ERROR] [1] [Demo] <> 6
[2024/07/19 11:43:23 CST 929] [OFF] [1] [root] <> 789
[2024/07/19 11:43:23 CST 929] [OFF] [1] [Demo] <> 789
```

#### 4.2.2日志文件输出

```cangjie
[2024/07/19 11:43:23 CST 928] [INFO] [1] [root] <> 4
[2024/07/19 11:43:23 CST 928] [WARN] [1] [root] <> 5
[2024/07/19 11:43:23 CST 928] [ERROR] [1] [root] <> 6
[2024/07/19 11:43:23 CST 928] [OFF] [1] [root] <> 7
[2024/07/19 11:43:23 CST 928] [INFO] [1] [root] <> 4
[2024/07/19 11:43:23 CST 928] [WARN] [1] [root] <> 5
[2024/07/19 11:43:23 CST 928] [WARN] [1] [Demo] <> 5
[2024/07/19 11:43:23 CST 928] [ERROR] [1] [root] <> 6
[2024/07/19 11:43:23 CST 929] [ERROR] [1] [Demo] <> 6
[2024/07/19 11:43:23 CST 929] [OFF] [1] [root] <> 789
[2024/07/19 11:43:23 CST 929] [OFF] [1] [Demo] <> 789
```