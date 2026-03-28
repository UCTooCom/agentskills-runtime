# fountain实现思想与应用第四弹

##### ——orm

项目链接：https://gitcode.com/Cangjie-SIG/fountain

这是ORM的类图

![ORM](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC04%E5%BC%B9%E2%80%94%E2%80%94ORM/ORM.jpg)

ORM的核心是SqlExecutor，所有增删改查、填充SQL参数都是这个类的API，而且各种高阶API也是它的扩展，数据库访问的接口也通过@DAO宏扩展到SqlExecutor。

SqlArgs是SqlExecutor是SQL参数集合按照调用添加参数的函数顺序添加到SqlArgs实例，每一个参数都被包装成SqlArg实例，访问数据库时遍历SqlArgs将参数添加到Statement。

类图中的RootDAO依赖的`Condition`结尾的类是SQL条件函数，MeetCondition执行每一个符合的条件、ChooseCondition执行第一个符合的条件，LoopCondition遍历Iterable实例。比如说可以有这样的SQL构造代码：

```cj
let page = executor.FROM<UserPO>()
.WHERE{'''
${meet(username.size > 0, ' username like '){
'%${username}%'
}}
${meet(password.size > 0, ' and "password" like '){
'%${password}%'
}}'''
}.page<UserPO>(10, page: 1)
```

SqlHead依赖的Clause类是SQL API的辅助工具，可以帮助开发者构造SQL。比如可以有以下API调用：

```cj
executor.FROM<MapperClass>().page<MapperClass>(10/*每页记录数*/, page: 1/*查询的页数*/)
executor.FROM<MapperClass>().WHERE{'id ${IN(list)}'}.page<MapperClass>(10)
```

分页查询时按照不同数据库的方言构造相应的分页查询SQL，构造的SQL会作为计数和分页查询的SQL子查询，避免有些查询SQL包含不能跟分页子句同时出现的SQL子句。比如postgres的计数SQL不能跟排序子句同时出现。

类图下面的QueryMappers和QueryMapper及它的子类是映射类型。每个映射类的成员被包装为QueryMapper实例，而QueryMappers是QueryMapper的集合。这些类型都是ORM内部类型，开发者不需要自己实例化它们，仅仅需要使用`@QueryMappersGenerator`修饰映射类。

```cj
@QueryMappersGenerator[user_info]//映射的表名
public class UserPO {
    @ORMField[true 'id']//如果是主键列，使用true表示，id是列名
    private var id: Int64 = 0
    @ORMField['username']//列名
    private var username: String = ''
    @ORMField['password']
    private var password: String = ''
    @ORMField['save_time']
    private var saveTime: ?DateTime = None<DateTime>
}
```

下面是一个完整的ORM例子。

首先初始化ORM。

```cj
import std.env
import opengauss.driver.*
import opengauss.slog
import fountain.data.*
import fountain.data.macros.*
import fountain.log.LoggerFactory
import fountain.orm.*
//具体可以参考项目里的fdemo/boot/src/boot.cj
private let _ = {=>
    let logger = LoggerFactory.getLogger("opengauss")
    slog.setDefault(logger)//初始化一个日志实例，给opengauss驱动指定日志实例
    let driver = DriverManager.getDriver("opengauss").getOrThrow()//实例化opengauss 驱动
    let url = env.getVariable('POSTGRES') ?? ''//获得opengauss url
    ORM.register(driver, url, [])//将驱动和url注册到ORM
    //register有一个default!: Bool = true参数，表示当前驱动是不是默认驱动，
    //如果多次调用ORM.register，而且都使用default默认值，则最后一次调用的驱动是默认驱动
}()//opengauss有列索引和参数索引从0开始，跟仓颉团队沟通过，回复也是应该从0开始，
//不过文档没有明确提到，有些驱动实现从1开始。
//我已经提了ISSUE希望文档能够有明确的说明。
```

然后声明一个Service类的实现。

```cj
import fountain.orm.*

import user.service.UserService
import user.dao.UserDAO

@Bean
public class UserServiceImpl <: UserService & RootService {
    public func register(username: String, password: String): Int64 {
        println('username: ${username}, password: ${password}')
        executor().register(username, password)//register是UserDAO的函数，UserDAO是SqlExecutor的扩展。
        //executor()是RootService接口的函数，它有默认实现，
        //功能是使用默认驱动从fountain.orm.ORM获得fountain.orm.SqlExecutor实例，SqlExecutor内部维持着数据库连接。
        //这个实例保存在ThreadLocal，同一线程重复调用executor()返回的是同一个SqlExecutor。
        //另外还有executor(driverName)，使用指定驱动名创建SqlExecutor。
    }
}
```

最后声明一个DAO。

```cj
import fountain.orm.*
import fountain.orm.macros.*

@DAO//这个宏会将UserDAO扩展到SqlExecutor
public interface UserDAO <: RootDAO {
    func register(username: String, password: String): Int64 {
        //executor是RootDAO的属性，SqlExecutor也实现了RootDAO，executor在SqlExecutor的实现就是返回自身。
        executor.setSql('''
            insert into user_info(
                        username,
                        password)
                 values(${arg(username)}, 
                        ${arg(password)}) 
            returning id'''
        ).insert//sqlSql也是返回SqlExecutor自身，insert返回插入的ID。
    }
}
```

