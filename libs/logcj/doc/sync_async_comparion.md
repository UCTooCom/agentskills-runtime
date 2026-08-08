# 日志文件同步、异步写入对比

#### 使用异步的目的

仓颉语言实现日志打印功能，类似 log4j 三方件。鉴于多线程运行原因，考虑使用异步写入文件。

#### 代码实现差别

##### 同步
正常写入

```
 public func logWrite(rec: LogRecord): Unit { xxx }
```

##### 异步

spawn创建线程，本身支持异步操作。<br>
getResult(ns:Int64)阻塞等待线程执行结束，并返回执行结果，如果该线程已经结束，则直接返回执行结果。<br/>

```
public func logWrite(rec: LogRecord): Unit {
 let fut = spawn{ xxx }
 fut.getResult(100**6)
}

```

#### 速度对比
##### 写入50行日志时间对比
###### 同步
```
[Execute Result]
time taken: 1s3ms408us22ns
```

###### 异步
```
[Execute Result]
time taken: 1s3ms567us275ns
```

##### 写入200行日志时间对比
###### 同步
```
[Execute Result]
time taken: 1s10ms818us238ns
```

###### 异步
```
[Execute Result]
time taken: 1s12ms344us222nss
```

##### 写入500行日志时间对比
###### 同步
```
[Execute Result]
time taken: 1s10ms839us532ns
```

###### 异步
```
[Execute Result]
time taken: 1s21ms64us628ns
```

#### 总结说明
同步、异步随着日志行数的增加，秒（s）的单位整体差距不大，毫秒（ms）上略有差距，而微秒（us）和纳秒（ns）的差距可以忽略不计<br>
异步因为增加了线程，存在了一定的超时时间（ms），所以略微慢一点。














