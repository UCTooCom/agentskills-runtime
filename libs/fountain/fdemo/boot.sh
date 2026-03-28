#!/bin/bash

path=$2
if [[ "$path" == "" ]]; then
    path='./fdemo'
fi
echo "target-dir=$path"
args=${@:3}

exports(){
    # export cjHeapSize=4GB
    # pattern可省略，有默认值
    # %level 记录当前日志级别
    # %name 记录当前日志名称
    # %d 记录当前日志时间，花括号内是时间格式
    # %m 记录当前日志消息文本
    # %tid 记录当前线程ID
    # %pid 记录当前进程ID
#    export loggerAsyncBufsize=2 # 异步日志缓存池的初始化大小，默认是1024
    export logger_appender_console=FDemoConsole # 这是控制台日志记录器的名称，可以任意起名，名称得符合标识符规范
    export logger_appender_FDemoConsole_level=DEBUG
    export logger_appender_FDemoConsole_pattern='[%level-%name]%d{yyyy/MM/dd,HH:mm:ss.SSS}|%tid;%m'
    export logger_appender_file=FDemoFile # 这是文件日志记录器的名称，可以任意起名
    export logger_appender_FDemoFile_level=INFO
    export logger_appender_FDemoFile_pattern='[%level-%name]%d{yyyy/MM/dd,HH:mm:ss.SSS}|%tid;%m'
    export logger_appender_FDemoFile_path=./log/fdemo.log
    export logger_appender_FDemoFile_rotateDuration=DAY
    export controllerPointcut='*..*Controller.*(**): *'
    export mvc_port=8080 # 这一行可以没有，默认就是8080
    export mvc_overallElapsedSwitch=true # 生产环境建议改为false，默认是false
    export mvc_internalServerErrorMessageKind=BEAN
    export mvc_internalServerErrorMessage=NameOf500Handler
    # 如果不使用fountain连接池，也不使用标准库连接池，就不要配置以下orm_*Pool*变量，只配置orm_noPool，只能用代码初始化第三方连接池
    export orm_useThirdPartyPool=true # 使用第三方连接池，不使用fountain.orm的连接池，也不使用标准库的连接池。
    # export opengauss_orm_useThirdPartyPool=flase # 可以为指定的数据库驱动配置是否使用第三方池
    # 此时使用ORM.register(datasource, default: false) # 开发者自己用代码初始化Driver和连接池、调用这个函数注册连接池
    export orm_noPool=true # 默认是false，true表示不用连接池
    # export orm_useStdPool=false # 默认是true，表示使用标准库连接池，false是使用fountain连接池
    export orm_drivers=mockdb,opengauss # 逗号分隔的驱动名称
    # orm_databasePool开头的是fountain.orm.DatabasePool的配置项
    export orm_databasePoolInitSize=1 # 初始连接数
    export orm_databasePoolMinSize=1 # 最小连接数
    export orm_databasePoolMaxSize=1 # 最大连接数
    export orm_databasePoolCheckOnCreation=true # 创建连接时是否检查连接有效性，默认是false
    export orm_databasePoolCheckOnBorrowing=true # 获取连接时是否检查连接有效性，默认是true
    export orm_databasePoolCheckOnReturning=false # 归还连接时是否检查连接有效性，默认是true
    export orm_databasePoolIdleTimeout=0 # 连接闲置时间，默认是0，表示闲置不过期
    export orm_databasePoolConnectionLife=86400 # 连接存活时间，默认是3600，单位是秒
    export orm_databasePoolCheckInterval=300 # 连接有效性检查周期，默认是300，单位是秒
    export orm_databasePoolConnectTimeout=50 # 默认是50，单位是毫秒，从fountain.orm.DatabasePool获取连接的超时时间
    export orm_databasePoolCheckSql='select 1' # 检查连接有效性的SQL，默认是select 1
    # orm_stdPool开头的是std.datasource.sql.PooledDatasource的配置项
    export orm_stdPoolMaxSize=10 # 连接池最大连接数
    export orm_stdPoolMaxIdleSize=10 # 连接池最大空闲连接数
    export orm_stdPoolIdleTimeout=86400 # 连接闲置时间，默认是10分钟
    export orm_stdPoolMaxLifeTime=86400 # 连接存活时间，默认30分钟
    export orm_stdPoolConnectionTimeout=86400 # 连接获取超时时间，默认30分钟
    export orm_stdPoolKeepaliveTime=86400 # 连接保活检查周期，默认1分钟
    # orm_transactionalFuncExecution 和@Transactional注解只要有一个生效就会将事务切面织入到函数
    export orm_transactionalFuncExecution='*..*ServiceImpl.delete*(**): *'
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.remove*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.save*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.add*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.new*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.create*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.update*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.change*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*ServiceImpl.register*(**): *"
    export orm_transactionalFuncExecution="$orm_transactionalFuncExecution|*..*.userSession(**): *"
    export opengauss_orm_connectionUrl=$POSTGRES
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`find ./fdemo/release/* -type d|grep -a -v -P 'f_.+|\.build-logs|fountain|bin|_stAtIc__|charset4cj|boot'|tr '\n' ':'`
    echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
}
run(){
    exports
    fboot run $path --dylibPattern='(boot|user\.util\.(auth|cron)|\.(controller|service\.impl))'
}
perfRecord(){
    exports
    cjprof record -f max -- $CJPM_INSTALL/bin/fboot run $path --dylibPattern='(boot|user\.util\.(auth|cron)|\.(controller|service\.impl))'

}
perfReport(){
    exports
    cjprof report -F 
}
build(){
    export CANGJIE_STDX_PATH=$CANGJIE_STDX_DYNAMIC_PATH
    fboot build $path $args
    echo -e '\a'
}

cleanUpdate(){
    fboot cleanUpdate $path
    echo -e '\a'
}

case "$1" in 
run)
    run
    ;;
perfRecord)
    perfRecord
    ;;
perfReport)
    perfReport
    ;;
cleanUpdate)
    cleanUpdate $2 $3
    ;;
build)
    build 
    ;;
launch)
    launch
    ;;
loop)
    start=$(date +%s.%N)
    for i in $(seq 1 $2); do 
        echo -e "\n================= 第 $i 次循环 =================\n";
#W         curl -XPOST -H'Content-Type:application/json' -H'Accept:application/json' -d'{"username":"asdf","password":"bcbcbcbc"}' http://localhost:8080/api/user/session
        curl -XGET -H'Accept:text/plain' http://localhost:8080/helloworld
	#  sleep 1
#        ./curl.sh
    done
    end=$(date +%s.%N)
    elapsed=$(echo "$end - $start" | bc)
    echo "耗时: $elapsed 秒"
    ;;
ab)
#    apt install apache2-utils 执行前需安装apache2-utils
#    ab -c $2 -n $3 -T "application/json" -H "Accept: application/json" -p post_data.json http://127.0.0.1:8080/helloworld
    ab -c $2 -n $3 -T '' -H 'Accept:text/plain' -H'Content-Type:application/x-www-form-urlencoded' -m GET http://localhost:8080/helloworld
    ;;
esac

exit $?
