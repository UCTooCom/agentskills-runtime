<div align="center">
<h1>log-cj</h1>
</div>

<p align="center">
<img alt="" src="https://img.shields.io/badge/release-v1.0.3-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/build-pass-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/cjc-v1.1.3-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/cjcov-89.8%25-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/project-open-brightgreen" style="display: inline-block;" />
</p>

## 介绍

仓颉语言实现日志打印功能

### 特性

- 💡 支持控制台日志输出和文件日志输出

- 🚀 支持使用Json进行自定义配置


## 软件架构

参见[log-cj 设计文档](./doc/log-cj_design.md)

### 源码目录

```shell
├── doc
├── src
│   ├── appender
│   │   ├── console_logger_appender.cj
│   │   ├── file_logger_appender.cj
│   │   ├── logger_appender.cj
│   │   ├── logger_appender_factory.cj
│   │   └── logger_appender_reference.cj
│   ├── config
│   │   ├── appender_config.cj
│   │   ├── appender_property.cj
│   │   ├── appender_ref.cj
│   │   ├── logger_config.cj
│   │   ├── logger_configuration.cj
│   │   └── root_logger_config.cj
│   ├── logger
│   │   ├── logger.cj
│   │   └── logger_manager.cj
│   └── utils
│       ├── log_level.cj
│       ├── log_record.cj
│       ├── pattern_converter.cj
│       ├── time_slice.cj
│       └── util.cj
├── resources
│   └── logcj.json
├── test
│   ├── LLT
│   └── HLT
```

- `doc` 库的设计文档、提案、库的使用文档等
- `src` 库源码目录
- `resources` 资源文件模板目录
- `test` 测试用例目录

### 接口说明

主要类和函数接口说明详见 [feature_api](./doc/feature_api.md)


## 使用说明

### 编译构建
```shell
cjpm update
cjpm build
```

### 执行用例

#### 1. 用例编译
```shell
# 编译
cjc  --import-path xxx/log-cj/target/release -L xxx/log-cj/zip4cj/crypto4cj/lib/ -l crypto   -L xxxx/log-cj/target/release/logcj -L xxx/log-cj/target/release/charset -L xxx/log-cj/target/release/zip4cj -L xxx/log-cj/target/release/crypto4cj -l crypto4cj.sha1cj -l crypto4cj.symmetrycj -l charset.unicode -l crypto4cj.sha384cj -l zip4cj.util -l crypto4cj.rc4cj -l zip4cj -l crypto4cj.sha256cj -l charset.singlebyte -l logcj.config -l charset.simplechinese -l crypto4cj.md5cj -l logcj.utils -l crypto4cj.dsacj -l zip4cj.io -l crypto4cj.sha512cj -l charset.exception -l zip4cj.progress -l charset.traditionchinese -l crypto4cj.eccj -l crypto4cj.dhcj -l zip4cj.headers -l charset.korean -l logcj.logger -l logcj.appender -l charset.japanese -l zip4cj.io.outputstream -l zip4cj.crypto -l zip4cj.io.inputstream -l crypto4cj.sha224cj -l crypto4cj.rsacj -l zip4cj.model -l charset.encoding -l crypto4cj.rc2cj -l charset -l crypto4cj.digestcj -l crypto4cj.hmaccj -l crypto4cj.utils -l crypto4cj.aescj -l zip4cj.util.internals -l logcj -l zip4cj.crypto.engine -l crypto4cj.pbkdf2cj -l crypto4cj.bignumcj -l zip4cj.crypto.PBKDF2 -l zip4cj.tasks -l zip4cj.model.enums -l crypto4cj -l zip4cj.exception  xxx/xxx/用例文件名.cj 
```

注意，用例编译生成文件默认保存在当前目录，生成的可执行文件默认为 main

#### 2. 库文件复制
- 把编译好的文件复制到 main 文件同级目录下，target/release/zip4cj、target/release/crypto4cj、target/release/charset、target/release/logcj 文件夹下的 cjo 和 so 文件
- 把 zip4cj/crypto4cj/lib/ 下的 libcrypto.so 文件也复制到 main 文件同级目录下

#### 3. 执行用例
```shell
./main
```


### 功能示例

示例代码：

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

配置文件：

```json
{"appenders": [
        {
            "enabled": "true",
            "name": "console",
            "type": "console",
            "pattern": "[%D %T %m] [%L] [%I] [%l] <%S> %M"
        },
        {
            "enabled": "true",
            "name": "file",
            "type": "file",
            "pattern": "[%D %T %m] [%L] [%I] [%l] <%S> %M",
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

执行结果如下：

```shell
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


## 开源协议

本项目基于 [Apache License 2.0](./LICENSE) ，请自由的享受和参与开源。

## 参与贡献

欢迎给我们提交PR，欢迎给我们提交Issue，欢迎参与任何形式的贡献
