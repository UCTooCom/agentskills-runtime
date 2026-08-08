# log-cj 设计文档

## 背景

几乎每个大型应用程序都包含自己的日志记录或跟踪 API。为了方便应用程序灵活配置打印日志，需要开发一款仓颉语言的日志组件——log-cj。

## 功能

- 支持控制台系统输出
- 支持文件系统日志输出
- 支持使用 JSON 进行配置
- 支持日志文件滚动

## 架构

### 代码层次架构
```
├── src
│   ├── appender
│   │   ├── xxx_appender.cj
│   │    ……
│   ├── config
│   │   ├── xxx_config.cj
│   │   ……
│   ├── logger
│   │   ├── logger.cj
│   │   └── logger_manager.cj
│   └── utils
│       ├── log_level.cj
│       ……
```
- appender 目录
  
  包含 appender 接口，和具体实 appender 现类，如控制台实现类：`console_logger_appender.cj` ，文件实现类：`file_logger_appender.cj`

- config 目录
  
  实现解析 xml 配置文件的模型目录，如：`appender_config.cj`

- logger 目录
  
  `logger.cj` : 打印日志接口类，实现不同级别的日志打印功能
  
  `logger_manager.cj`：日志管理类，管理多个 `logger` 实例，加载日志配置等

- utils 目录
  
  工具类，如日志级别定义，日期格式化处理等工具实现

### 日志级别

| 级别    | 描述                           |
| ----- | ---------------------------- |
| ALL   | 所有：所有日志级别，包括定制级别。            |
| TRACE | 跟踪：指明程序运行轨迹，比 DEBUG 级别的粒度更细。 |
| DEBUG | 调试：指明细致的事件信息，对调试应用最有用。       |
| INFO  | 信息：指明描述信息，从粗粒度上描述了应用运行过程。    |
| WARN  | 警告：指明可能潜在的危险状况。              |
| ERROR | 错误：指明错误事件，但应用可能还能继续运行。       |
| OFF   | 关闭：最高级别，不打印日志。               |

### 日志配置

#### 配置文件位置

支持通过 json 文件配置日志信息，配置文件命名为 `logcj.json` ,位置为代码工程的 `src/resources` 目录。

配置示例

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
            "level":"info",
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

#### 配置文件支持属性

支持配置日志的打印目标：

1. 控制台

2. 日志文件

支持日志文件配置属性

1. 日志文件名称

2. 单个日志文件大小

3. 日志清理天数

#### appender 配置参数

| 参数       | 描述                                                                                                                                                                                                                                                                                                                                                      | 默认值                         |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| enabled  | 是否启用此 appender                                                                                                                                                                                                                                                                                                                                          | true                        |
| name     | appender 名称                                                                                                                                                                                                                                                                                                                                             |                             |
| type     | 日志输出目标类型 <br>console： 系统输出；<br>file：文件系统日志输出                                                                                                                                                                                                                                                                                                            |                             |
| pattern  | 日志输出格式<br/>%D (date,eg:2022/11/21)<br/>%T (time,eg: 11:15:11 CST)<br/>%m (millisecond, eg:234)<br/>%L (level：ALL,TRACE,DEBUG,INFO,WARN,ERROR,OFF)<br/>%l (label, tag name)<br/>%S (source,eg:com.test.ClassA)<br/>%M (Message)<br/>输出样例：[2022/11/21 11:15:11 CST 281] [INFO] [com.hello] (examples.TestLoggerExample:77) test message<br/>  | [%T %D %m] [%L][%l] (%S) %M |
| property | 日志大小、清理时间等配置                                                                                                                                                                                                                                                                                                                                            |                             |

#### property 配置参数

| 参数            | 描述                           | 默认值      |
| ------------- | ---------------------------- | -------- |
| filename      | 日志文件名称                       | root.log |
| rotate        | 是否滚动打包日志                     | false    |
| maxsize       | 滚动打包日志时，单个日志大小               | 20M      |
| daily         | 滚动打包日志时是否按每天打包，优先级高于 maxsize | false    |
| retentiondays | 滚动打包日志时，日志保留天数               | 7        |

#### root 配置参数

| 参数           | 描述                                     | 默认值  |
| ------------ | -------------------------------------- | ---- |
| level        | 日志输出的最小级别                              | INFO |
| appender-ref | 关联的 appender，值必须与 appender 的 name 保持一致 |      |

## 日志使用

日志记录器根据不同的文件/包实现不同的命名空间的区分，使用日志组件应尽可能简单。

```python
# 引用组件
import logcj.*   

# Logger_Manager 加载时已经根据日志配置文件做好初始化操作，
# "com.hello" 即为日志记录器的名称，可以是类名或自定义方便识别的字符串
let logger = Logger_Manager.getLogger("com.hello")

# 打印日志
logger.warn("warn")
```
