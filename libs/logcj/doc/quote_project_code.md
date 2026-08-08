# 项目源码引用

#### 引用

##### 拷贝被调用项目源码

拷贝被调用项目源码至调用项目目录下，保持和调用项目的src目录同级

调用项目代码结构如下

```shell
├── src
├── log-cj（被调用项目）
│    ├── src
│    │    ├── appender
│    │    │    ├── xxx.cj
│    │    ├── config
│    │    │    ├── xxx.cj
│    │    ├── logger
│    │    │    ├── xxx.cj
│    │    ├── utils
│    │    │    ├── xxx.cj
│    ├── module.json
├── main.cj
├── module.json
```
**注意**：记得修改被调用项目（log-cj)module.json文件中的output_type为static

##### 更改调用项目的module.json文件

更改requires字段的值，此字段是map类型，类似如下，如果原来此字段存在值，则续添，反之，则复制以下代码框中"log4cj":"{}"的内容即可
```
	"requires": {
		"logcj":{
			"organization":"cangjie",
			"version":"1.0.0",
			"path":"./log-cj"
		}
	}
```
**注意**："logcj"，"organization"和"version"和被调用项目（log-cj)module.json文件中的name,organization,version保持一致

##### 修改依赖关系

修改命令：cjpm update<br/>
手动执行cjpm update的原因：update用来将module.json里的内容更新到module-resolve.json,当module-resolve.json不存在是，将会生成该文件<br/>
module-resolve.json里存放的是项目中模块之间的依赖关系

##### 如何调用引入的项目源码

在需要引入的仓颉（.cj）文件中，引入log4j相关依赖，写法如下
```
import logcj.appender.*
import logcj.config.*
import logcj.logger.*
import logcj.utils.*

let logger = Logger_Manager.getLogger("com.test")

func xxx(){ 
    logger.warn("test waring")
}
```

##### 运行
运行完程序，查看项目中对应的.log文件（和src目录同级）中有没有你写入的内容


















