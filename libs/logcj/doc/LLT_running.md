
# LLT（自测用例）运行说明

## LLT文件所在位置

test/LLT下xxx_test的仓颉文件
```shell
├── doc
├── src
├── test
│   ├── LLT
│   │    ├── xxx_test.cj
│   │    ├── ...
```

## LLT运行先决条件

### 安装python3（版本3.6.9经测试可用，可高于此版本），配置环境变量

### 将项目根目录下的gitee_gate.ctg文件中的LLT=false修改为LLT=true

```cangjie
[coverage]
LLT = true
```

### 下载[测试库](https://gitee.com/HW-PLLab/testJekins/tree/dev)，将测试库中src目录下ci_test 文件夹复制到项目根目录中


## 运行LLT

### 进入项目根目录

```cangjie
cd log-cj
```

### 编译

```cangjie
python3 ci_test/main.py build
```
**出现`cjpm build success!!`，则表示运行成功（xxx为自己机器目录）**

```cangjie
[08-01 15:58:53] INFO - Building with cjpm.....
[08-01 15:58:53] INFO - CMD    : cjpm build
[08-01 15:58:53] INFO - FILE   : /home/helongfei/workspace/log-cj
[08-01 15:59:40] WARNING - warning: unused variable:'i'
[08-01 15:59:40] WARNING -   ==> /home/helongfei/workspace/log-cj/src/utils/util.cj:29:10:
[08-01 15:59:40] WARNING -    | 
[08-01 15:59:40] WARNING - 29 |     for (i in 0..len) {
[08-01 15:59:40] WARNING -    |          ^ unused variable
[08-01 15:59:40] WARNING -    | 
[08-01 15:59:40] WARNING - 
[08-01 15:59:40] WARNING - 1 warning generated, 1 warning printed.
[08-01 15:59:40] WARNING - warning: unused variable:'property'
[08-01 15:59:40] WARNING -   ==> /home/helongfei/workspace/log-cj/src/appender/console_logger_appender.cj:24:47:
[08-01 15:59:40] WARNING -    | 
[08-01 15:59:40] WARNING - 24 |     public func initAppender(pattern: String, property: ArrayList<AppenderProperty>): Unit {
[08-01 15:59:40] WARNING -    |                                               ^^^^^^^^ unused variable
[08-01 15:59:40] WARNING -    | 
[08-01 15:59:40] WARNING - 
[08-01 15:59:40] WARNING - warning: unused variable:'paths'
[08-01 15:59:40] WARNING -    ==> /home/helongfei/workspace/log-cj/src/appender/file_logger_appender.cj:176:13:
[08-01 15:59:40] WARNING -     | 
[08-01 15:59:40] WARNING - 176 |         var paths: HashSet<String> = HashSet<String>()
[08-01 15:59:40] WARNING -     |             ^^^^^ unused variable
[08-01 15:59:40] WARNING -     | 
[08-01 15:59:40] WARNING - 
[08-01 15:59:40] WARNING - warning: unused variable:'fut'
[08-01 15:59:40] WARNING -    ==> /home/helongfei/workspace/log-cj/src/appender/file_logger_appender.cj:137:13:
[08-01 15:59:40] WARNING -     | 
[08-01 15:59:40] WARNING - 137 |         let fut = spawn {
[08-01 15:59:40] WARNING -     |             ^^^ unused variable
[08-01 15:59:40] WARNING -     | 
[08-01 15:59:40] WARNING - 
[08-01 15:59:40] WARNING - 3 warnings generated, 3 warnings printed.
[08-01 15:59:40] WARNING - warning: unused variable:'configList'
[08-01 15:59:40] WARNING -    ==> /home/helongfei/workspace/log-cj/src/logger/logger_manager.cj:339:13:
[08-01 15:59:40] WARNING -     | 
[08-01 15:59:40] WARNING - 339 |         var configList: ArrayList<AppenderConfig> = ArrayList<AppenderConfig>()
[08-01 15:59:40] WARNING -     |             ^^^^^^^^^^ unused variable
[08-01 15:59:40] WARNING -     | 
[08-01 15:59:40] WARNING - 
[08-01 15:59:40] WARNING - 1 warning generated, 1 warning printed.
[08-01 15:59:40] INFO - cjpm build success
```

### 运行

```cangjie
python3 ci_test/main.py test
```
**出现`TestSuiteTask: Total: 4, PASS: 4, FAIL: 0`，则表示运行成功（xxx为自己机器目录）**

```cangjie
helongfei@test-zhangxiaoyang:~/workspace/log-cj$ python3 ci_test/main.py test
[08-01 15:57:26] INFO - The CJC compiler has been configured.
[08-01 15:57:26] INFO - start clear
[08-01 15:57:26] INFO - end clear
[08-01 15:57:26] INFO - CMD    : cjc --import-path /home/helongfei/workspace/log-cj/build/charset/.. --import-path /home/helongfei/workspace/log-cj/ci_lib/zip4cj/..  -L /home/helongfei/workspace/log-cj/build/charset -L /home/helongfei/workspace/log-cj/ci_lib/zip4cj  -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese  config_test.cj
[08-01 15:57:26] INFO - FILE   : config_test.cj
[08-01 15:57:30] INFO - CMD    : ./main
[08-01 15:57:30] INFO - FILE   : config_test.cj
[08-01 15:57:30] INFO - 测试开始
[08-01 15:57:30] INFO - testLoggerConfig = true
[08-01 15:57:30] INFO - testLoggerConfigWithAttrs = true
[08-01 15:57:30] INFO - testLoggerConfigWithInitParams = true
[08-01 15:57:30] INFO - testAppenderConfig = true
[08-01 15:57:30] INFO - testAppenderConfigWithAttrs = true
[08-01 15:57:30] INFO - testAppenderConfigWithInitParams = true
[08-01 15:57:30] INFO - testAppenderProperty = true
[08-01 15:57:30] INFO - testAppenderPropertyWithAttrs = true
[08-01 15:57:30] INFO - testAppenderPropertyWithInitParams = true
[08-01 15:57:30] INFO - testAppenderRef = true
[08-01 15:57:30] INFO - testLoggerConfiguartion = true
[08-01 15:57:30] INFO - testLoggerConfiguartionWithInitParams = true
[08-01 15:57:30] INFO - testRootLoggerConfig = true
[08-01 15:57:30] INFO - testRootLoggerConfigWithAttrs = true
[08-01 15:57:30] INFO - testRootLoggerConfigWithInitParams = true
[08-01 15:57:30] INFO - 测试结束
[08-01 15:57:30] INFO - return : 0
[08-01 15:57:30] INFO -  >>=============================================<<当前进度11.11% 
[08-01 15:57:30] INFO - 
[08-01 15:57:30] INFO - CMD    : cjc --import-path /home/helongfei/workspace/log-cj/build/charset/.. --import-path /home/helongfei/workspace/log-cj/ci_lib/zip4cj/..  -L /home/helongfei/workspace/log-cj/build/charset -L /home/helongfei/workspace/log-cj/ci_lib/zip4cj  -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese  appender_test.cj
[08-01 15:57:30] INFO - FILE   : appender_test.cj
[08-01 15:57:34] WARNING - warning: unused variable:'i'
[08-01 15:57:34] WARNING -    ==> appender_test.cj:199:10:
[08-01 15:57:34] WARNING -     | 
[08-01 15:57:34] WARNING - 199 |     for (i in 0..2) {
[08-01 15:57:34] WARNING -     |          ^ unused variable
[08-01 15:57:34] WARNING -     | 
[08-01 15:57:34] WARNING - 
[08-01 15:57:34] WARNING - warning: unused variable:'i'
[08-01 15:57:34] WARNING -    ==> appender_test.cj:179:10:
[08-01 15:57:34] WARNING -     | 
[08-01 15:57:34] WARNING - 179 |     for (i in 0..10) {
[08-01 15:57:34] WARNING -     |          ^ unused variable
[08-01 15:57:34] WARNING -     | 
[08-01 15:57:34] WARNING - 
[08-01 15:57:34] WARNING - warning: unused variable:'res'
[08-01 15:57:34] WARNING -    ==> appender_test.cj:147:9:
[08-01 15:57:34] WARNING -     | 
[08-01 15:57:34] WARNING - 147 |     var res = getQueryResult("", logRecord, "root.log")
[08-01 15:57:34] WARNING -     |         ^^^ unused variable
[08-01 15:57:34] WARNING -     | 
[08-01 15:57:34] WARNING - 
[08-01 15:57:34] WARNING - 3 warnings generated, 3 warnings printed.
[08-01 15:57:34] INFO - CMD    : ./main
[08-01 15:57:34] INFO - FILE   : appender_test.cj
[08-01 15:57:43] INFO - 测试开始
[08-01 15:57:43] INFO - [15:57:34 CST 2023/08/01 019] [ALL][com.test] (source) message
[08-01 15:57:43] INFO - testConsoleLoggerAppenderWithDefaultPattern = true
[08-01 15:57:43] INFO - [15:57:34 CST 2023/08/01] [ALL] (source) message]
[08-01 15:57:43] INFO - testConsoleLoggerAppenderWithOtherPattern = true
[08-01 15:57:43] INFO - testFileLoggerAppenderWithDefaultPattern = true
[08-01 15:57:43] INFO - testFileLoggerAppenderWithOtherPattern = true
[08-01 15:57:43] INFO - write file occur exception: The file not opened, can not be written.
[08-01 15:57:43] INFO - testFileLoggerAppenderWithErrorRolling = true
[08-01 15:57:43] INFO - testFileLoggerAppenderWithRightRolling = false
[08-01 15:57:43] INFO - AppenderType is empty, please RegistryType at first
[08-01 15:57:43] INFO - testAppenderFactoryNoType = false
[08-01 15:57:43] INFO - testAppenderFactorWithConsoleType = false
[08-01 15:57:43] INFO - testAppenderFactorWithInitParams = true
[08-01 15:57:43] INFO - testAppenderFactorNoNew = true
[08-01 15:57:43] INFO - testAppenderReference = true
[08-01 15:57:43] INFO - testAppenderReferenceWithInitParams = true
[08-01 15:57:43] INFO - testAppenderReferenceWithSetter = true
[08-01 15:57:43] INFO - testLevelEnabled = true
[08-01 15:57:43] INFO - testLevelEnabled01 = true
[08-01 15:57:43] INFO - testInfoNotEnabled = true
[08-01 15:57:43] INFO - testErrorEnabled = true
[08-01 15:57:43] INFO - testWarnEnabled = true
[08-01 15:57:43] INFO - testTraceEnabled = true
[08-01 15:57:43] INFO - testFatalEnabled = true
[08-01 15:57:43] INFO - testDebugEnabled = true
[08-01 15:57:43] INFO - 测试结束
[08-01 15:57:43] INFO - return : 0
[08-01 15:57:43] INFO -  >>=============================================<<当前进度22.22% 
[08-01 15:57:43] INFO - 
[08-01 15:57:43] INFO - CMD    : cjc --import-path /home/helongfei/workspace/log-cj/build/charset/.. --import-path /home/helongfei/workspace/log-cj/ci_lib/zip4cj/..  -L /home/helongfei/workspace/log-cj/build/charset -L /home/helongfei/workspace/log-cj/ci_lib/zip4cj  -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese  util_test.cj
[08-01 15:57:43] INFO - FILE   : util_test.cj
[08-01 15:57:43] INFO - CMD    : ./main
[08-01 15:57:43] INFO - FILE   : util_test.cj
[08-01 15:57:43] INFO - 测试开始
[08-01 15:57:43] INFO - testGetNumByString = true
[08-01 15:57:43] INFO - testStrToNumBySuffix = true
[08-01 15:57:43] INFO - testFlushLeft = true
[08-01 15:57:43] INFO - testFormatLogRecord = true
[08-01 15:57:43] INFO - testLogRecord = true
[08-01 15:57:43] INFO - testLogLevel = true
[08-01 15:57:43] INFO - testGetLevelByString = true
[08-01 15:57:43] INFO - testTimeSlice = true
[08-01 15:57:43] INFO - testLogLevelOperator = false
[08-01 15:57:43] INFO - 测试结束
[08-01 15:57:43] INFO - return : 0
[08-01 15:57:43] INFO -  >>=============================================<<当前进度33.33% 
[08-01 15:57:43] INFO - 
[08-01 15:57:43] INFO - CMD    : cjc --import-path /home/helongfei/workspace/log-cj/build/charset/.. --import-path /home/helongfei/workspace/log-cj/ci_lib/zip4cj/..  -L /home/helongfei/workspace/log-cj/build/charset -L /home/helongfei/workspace/log-cj/ci_lib/zip4cj  -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese  logger_test.cj
[08-01 15:57:43] INFO - FILE   : logger_test.cj
[08-01 15:57:46] INFO - CMD    : ./main
[08-01 15:57:46] INFO - FILE   : logger_test.cj
[08-01 15:57:46] INFO - enter default...
[08-01 15:57:46] INFO - 测试开始
[08-01 15:57:46] INFO - enter default...
[08-01 15:57:46] INFO - testLoadDefaultConfig = false
[08-01 15:57:46] INFO - testGetLogger = true
[08-01 15:57:46] INFO - testInitLogggerManager = false
[08-01 15:57:46] INFO - testPrintInfoLog = false
[08-01 15:57:46] INFO - testPrintErrorLog = true
[08-01 15:57:46] INFO - testPrintWarnLog = true
[08-01 15:57:46] INFO - testPrintOffLog = true
[08-01 15:57:46] INFO - testPrintTraceLog = true
[08-01 15:57:46] INFO - testPrintDebugLog = true
[08-01 15:57:46] INFO - testPrintAllLog = true
[08-01 15:57:46] INFO - testGetAppenderFactory = false
[08-01 15:57:46] INFO - enter default...
[08-01 15:57:46] INFO - testInitLogggerManagerWithEmptyPath = false
[08-01 15:57:46] INFO - testPrintFatalLog = true
[08-01 15:57:46] INFO - 测试结束
[08-01 15:57:46] INFO - return : 0
[08-01 15:57:46] INFO -  >>=============================================<<当前进度44.44% 
[08-01 15:57:46] INFO - 
[08-01 15:57:46] INFO - 
[08-01 15:57:46] INFO - 
[08-01 15:57:46] INFO -   TestSuiteTask: Total: 4, PASS: 4, FAIL: 0, Ratio  : 100.0%
```

## 以下步骤本版本（0.39.4）暂不支持
## 生成覆盖率报告（前提：LLT运行完成）

### 进入项目根目录，执行如下命令(xxx为自己机器目录)
**-root 在root目录或者在其递归子目录能找到gcda文件**<br/>
**-e 排除不需要计算覆盖率的文件**<br/>
**-o 输出目录**<br/>

```cangjie
cjcov --root=./ -e "xxx/log-cj/ci_test/ xxx/log-cj/doc/ xxx/log-cj/src/main.cj" --html-details -o html_output
```

## 查看覆盖率报告

在项目根目录下的html_output目录下打开index.html，即可查看全部文件的覆盖率以及整体覆盖率