# 配置文件（logcj.json）说明（此说明适用于主分支master）

#### 三方调用位置以及文件名说明

位置: 默认resources目录下<br/>
文件名：默认logcj.json<br/>
**注意** <br/>
如果想更改默认位置，请搜索logger_manager.cj文件，自行更改如下代码，重新编译测试
```
public let Logger_Manager = LoggerManager("./src/resources/logcj.json")
```

#### 文件结构如下

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

##### appenders（附加器）说明

根据 type 定义不同类型的 appender 注册到 appenderFactory，激活使用

1. **enabled: 是否启用**

- true（启用）
- false （不启用）

2. **name: 名字**

- 可以和 type 保持一致（也可以自定义名字）

3. **type: 类型**

- console（stdout、stderr 系统输出）
- file（文件系统日志输出）

4. **pattern: 输出日志的格式**

- %D (date,eg:2022/11/21)
- %T (ime,eg: 11:15:11 CST)
- %m (millisecond, eg:234)
- %L (level,ALL,TRACE,DEBUG,INFO,WARN,ERROR,OFF)
- %l (label, tag name)
- %S (source,eg:com.test.ClassA)
- %M (Message)
- 输出样例：[2022/11/21 11:15:11 CST 281] [ALL] [com.hello] () test message

5. **property（name 属性名字）以下均为 file appender 独有属性**

6. **filename: 文件名**

- 自定义（eg: root.log）

7. **rotate: 是否打包日志**

- true（打包）
- false(不打包)

8. **maxsize: 单个日志文件最大 size**

- 自定义（数字，默认单位为字节）

9. **daily: 是否按天打包**

- true（按天打包）
- false（不按天打包）

##### loggers（自定义记录器）说明，默认继承 root logger，可以不定义，可以定义多个

1. **name: 名字**

- 自定义

2. **level: 输出的日志最小级别**

- 比如填写info，表示的是输出info级别及以上的日志

3. **appender-refs: 关联的 appender**

- ref值必须与 appender 的 name 保持一致

##### root（根记录器）说明

1. **name: 名字**

- 自定义

2. **level: 输出的日志最小级别**

- 比如填写info，表示的是输出info级别及以上的日志

3. **appender-refs: 关联的 appender**

- ref值必须与 appender 的 name 保持一致
