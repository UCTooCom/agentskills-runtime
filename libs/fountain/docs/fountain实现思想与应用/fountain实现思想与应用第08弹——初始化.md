# fountain实现思想与应用第八弹

##### ——初始化

项目链接：https://gitcode.com/Cangjie-SIG/fountain

本篇介绍使用fountain开发的应用项目如何启动和初始化。

fountain提供了一个子项目fboot，开发者可以借助fboot初始化应用项目。具体是以下两个命令：

1.  `fboot workspace [project_name]`
    -   在当前目录用`project_name`创建新的文件夹，并用它创建一个`workspace`项目。
    -   如果没有指定`project_name`则在当前目录创建`workspace`项目
    -   为新建项目添加fountain的git依赖、stdx二进制依赖、在`[workspace]`下面添加`version="1.0.0"`节点。
        -   为新项目的`compile-option`、`override-compile-option`节点添加`-O2 --dy-std`的参数。
        -   为`[target]`以及`[target.x86-64-unknown-linux-gnu]`等各操作系统和指令集的`[target.*]`节点下面的`compile-option`、`override-compile-option`添加`-O2 --dy-std`参数。
            -   为`[target.x86-64-unknown-linux-gnu]`额外添加`--lto=ful`编译参数。
2.  `fboot module [module_name]`
    -   在当前目录用`module_name`创建新的文件夹，并用它创建一个动态链接库子项目作为`workspace`的模块。
    -   在主项目`[workspace]`的`members`节点添加模块依赖。

为了使用以上命令，可以在`fountain/fboot`执行`cjpm install --root /path/of/fountain/installed`，并把`/path/of/fountain/installed/bin`添加到`PATH`环境变量，把`/path/of/fountain/installed/libs/fboot`添加到`LD_LIBRARY_PATH`。开发者可以参考`fountain/cangjie.sh`和`fountain/fdemo/boot.sh`开发符合项目需要的脚本。

如果项目依赖数据库建议创建一个模块，在模块内创建一个匿名的闭包，在闭包内初始化ORM。比如有以下初始化方式：

```cj
import opengauss.driver.*
import opengauss.slog

private let _ = {=>
    try{
        let logger = LoggerFactory.getLogger("opengauss")
        slog.setDefault(logger)
        let driver = DriverManager.getDriver("opengauss").getOrThrow()
        ORM.register(driver)//ORM会从配置项获得数据库连接URL和其它配置项。
    }catch(e: Exception){
        e.printStackTrace()
        throw e 
    }
}()
```

还有更简单的初始化：

```cj
import opengauss.driver.*//这个导入不能少，否则数据库驱动就不会初始化了
import opengauss.slog

private let _ = {=>
    try{
        let logger = LoggerFactory.getLogger("opengauss")
        slog.setDefault(logger)
        ORM.register('opengauss')//ORM会从配置项获得数据库连接URL和其它配置项。
    }catch(e: Exception){
        e.printStackTrace()
        throw e 
    }
}()
```

在初始化脚本增加环境变量：

```bash
#    如果不使用fountain连接池，也不使用标准库连接池，就不要配置以下orm变量，只能用代码初始化第三方连接池
#    export orm_noPool=true # 默认是false，true表示不用连接池，值是true时忽略所有连接池配置
#    export orm_useStdPool=false # 默认是true，true表示使用std.datasource.sql.PooledDatasource，否则使用fountain.orm.DatasourcePool
    # 使用orm池会忽略标准库池的配置，反之亦然
    export orm_drivers=opengauss # 逗号分隔的驱动名称
    # orm_datasourcePool*是fountain.orm.DatasourcePool的初始化参数
    export orm_databasePoolInitSize=10 # 池的初始连接数
    export orm_databasePoolMinSize=10 # 池的最小连接数
    export orm_databasePoolMaxSize=10 # 池的最大连接数
    export orm_databasePoolCheckOnCreation=true # 默认false，true表示创建连接时检查连接
    export orm_databasePoolCheckOnBorrowing=true # 默认true，true表示在获取连接时检查连接
    export orm_databasePoolCheckOnReturning=false # 默认true，true表示在返回连接时检查连接
    export orm_databasePoolConnectionLife=86400 # 默认是3600，单位是秒，连接存活时间
    export orm_databasePoolCheckInterval=300 # 默认是300，单位是秒，连接有效性检查周期
    export orm_databasePoolCheckSql='select 1' # 默认是select 1，检查连接有效性的SQL
    # orm_stdPool*是std.datasource.sql.PooledDatasource的初始化参数
    export orm_stdPoolMaxSize=1 # 最大连接数
    export orm_stdPoolMaxIdleSize=1 # 最大空闲连接数
    export orm_stdPoolIdleTimeout=86400 # 连接闲置时间
    export orm_stdPoolMaxLifeTime=86400 # 连接存活时间
    export orm_stdPoolConnectionTimeout=86400 # 从池中获取连接的超时时间
    export orm_stdPoolKeepaliveTime=86400 # 检查连接有效性的周期
    # 以上是数据库连接池的初始化参数
    # orm_transactionalFuncExecution 和@Transactional注解只要有一个生效就会将事务切面织入到函数
    export orm_transactionalFuncExecution='*..*.delete*(**): *|*..*.remove*(**): *|*..*.save*(**): *|*..*.add*(**): *|*..*.new*(**): *|*..*.create*(**): *|*..*.insert*(**): *|*..*.update*(**): *|*..*.change*(**): *|*..*.register*(**): *'
    export opengauss_orm_connectionUrl=$POSTGRES # 数据库驱动的初始化URL
    if [[ "$path" == "" ]]; then
        path='./fdemo'
    fi
    export LD_LIBRARY_PATH=$path/release/boot:$path/release/opengauss:$path/release/user:$LD_LIBRARY_PATH
    
    # pattern可省略，有默认值
    # %level 记录当前日志级别
    # %name 记录当前日志名称
    # %d 记录当前日志时间，花括号内是时间格式
    # %m 记录当前日志消息文本
    # 日志配置项的名字跟日志实例的名字不同，这些名字仅在用配置初始化时有用
    export logger_appender_console=FDemoConsole # 为控制台日志配置项起个名字，可以用,指定多个控制台日志配置
    export logger_appender_FDemoConsole_level=DEBUG # 为这个控制台配置指定日志级别
    # 控制台日志的格式
    export logger_appender_FDemoConsole_pattern='[%level-%name]%d{yyyy/MM/dd,HH:mm:ss.SSS}|%tid;%m' 
    export logger_appender_file=FDemoFile # 为文件日志的配置项起个名字。
    export logger_appender_FDemoFile_level=INFO
    export logger_appender_FDemoFile_pattern='[%level-%name]%d{yyyy/MM/dd,HH:mm:ss.SSS}|%tid;%m'
    export logger_appender_FDemoFile_path=./log/fdemo.log # 日志文件的路径和文件名
    export logger_appender_FDemoFile_rotateDuration=DAY # 日志文件的切分周期
    # 以上是日志初始化参数
    export mvc_port=8080 # 这一行可以没有，默认就是8080
    export mvc_overallElapsedSwitch=true # 是否记录从路径查询handler开始到完全写出响应体的耗时
    export mvc_internalServerErrorMessageKind=BEAN # 应用项目处理HTTP请求时如果发生异常，处理异常的类型，这个配置表示ErrorMessage是一个IOC bean name
    export mvc_internalServerErrorMessage=NameOf500Handler 
```

接下来可以按照业务划分不同的模块，模块内可以按照`controller`、`service`、`service.impl`、`dao`、`util`等创建包名，比如以下名为user的模块：

![image-20251115112321416](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC08%E5%BC%B9%E2%80%94%E2%80%94%E5%88%9D%E5%A7%8B%E5%8C%96/image-20251115112321416.png)

为了方便开发者编译和启动项目可以使用以下命令：

-   `fboot build`——将当前工作目录作为待编译的项目目录。编译时会创建一个`project_name_stAtIc__`模块，读出`[workspace]`的version节点的值，并把`project_name/banner.txt`一起写入这个模块，把模块添加到`members=[...]`。编译结束，不论成功失败都会删除这个临时模块。
-   `fboot run --dylibPattern='(boot|user\.util\.auth|\.(controller|service\.impl))'`——启动应用项目。递归遍历将当前目录内的全部动态链接库，`--dylibPattern`是应用启动时需要主动加载的动态链接库，启动时会使用`PackageInfo.load(path)`动态加载这些动态链接库。
    -   启动前需要把编译结果的动态链接库路径加入`LD_LIBRARY_PATH`。
-   `fboot cleanUpdate`——执行`cjpm clean`清除当前目录的编译结果、删除当前目录下的`cjpm.lock`并重新执行`cjpm update`。
-   `fboot count`——计数当前目录下的仓颉代码模块数、包数、文件数、行数。

能做到以上功能，是因为fboot是以下代码：

```cj
import fountain.App
main(args: Array<String>){
   App(args).boot()
}
```

fboot的每个子命令都是`fountain.App`的一个函数：

```cj
    public func boot(): Int64 {
        match (args[0]) {
            case 'run' => run()
            case 'shutdown' => shutdown()
            case 'restart' => restart()
            case 'module' => initModule()
            case 'workspace' => initWorkspace()
            case 'cleanUpdate' => cleanUpdate()
            case 'build' => build()
            case 'test' => test()
            case 'count' => count()
            case 'version' => version()
            case 'help' => help()
            case _ => throw BootException(
                    'first command arg must be run|shutdow|restart|module|workspace|cleanUpdate|build|count|version, but current args are ${args}')
        }
    }
```

