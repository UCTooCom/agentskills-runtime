# fountain实现思想与应用第五弹

##### ——事务

项目链接：https://gitcode.com/Cangjie-SIG/fountain

## AOP

### AOP的主要类型

这是AOP的类图。

![aop](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC05%E5%BC%B9%E2%80%94%E2%80%94AOP&%E4%BA%8B%E5%8A%A1/aop-1762570660004.jpg)

#### Aspects

Aspects是AOP的中枢，宏@Pointcut把被它修饰的函数体包装成嵌套函数，用函数参数构造`Array<Any>`。获得函数参数的类型，再用函数所在类的TypeInfo、函数名和函数参数类型获得InstanceTypeInfo，每次函数调用都会用以上这些信息构造一个新的InvocationFuncInfo实例，这是判定是否织入切面的依据。

#### RouteRule 、TargetAnnotationRouteRule 、ConfigRouteRule

RouteRule是织入规则，典型的就是图中展示的几个RouteRule子类型，各种RouteRule实例可以使用`&` `|` `!`操作符连接起来。

TargetAnnotationRouteRule的初始化参数是注解的全限定名，使用这个规则的切面将被织入符合这个规则的函数。

ConfigRouteRule是从配置项获得规则的抽象父类，ConfigExecutionRouteRule是使用表示成员函数所在类的全限定名、函数名、函数参数、函数返回类型的字符串定义规则，这些规则定义如下：

1.  `*`表示通配符，表示任意零或多个字符，用于包名、类名、函数名、函数返回类型。
2.  `..`表示任意级数的包名
3.  `**`表示任意数量的参数
4.  `<: TypeQualifiedName`，表示函数参数或返回类型是指定类型的子类型
5.  `TypeQualifiedName <:`，表示函数参数或返回类型是指定类型的父类型
6.  `|`分割多个规则

`*..*.save*(**): *|*..*.delete*(**): *`表示任意包名、任意类名、任意返回类型，函数名是save或delete开头的函数。

#### Aspect

这是一个接口，实现了它且注册到IOC的类就是切面。接口声明了分别在函数执行前、执行后、抛出异常后、函数返回前的织入逻辑。这些函数都有空的默认实现。开发者不必全部实现它们，可以选择实现需要的切面函数。具体函数声明如下：

```cj
/**
 * 最先执行，先于around 原函数体 after throwing final，默认什么也不做
 */
func before(funcInfo: InvocationFuncInfo): Unit
/**
 * 在around返回后执行，默认是立即返回result
 */
func after(funcInfo: InvocationFuncInfo, result: Any): Any
/**
 * 在before返回后after之前执行，原函数在around内部某个时机执行，由开发者控制，默认是立即执行原函数体
 */
func around(funcInfo: InvocationFuncInfo, point: (Array<Any>) -> Any): Any
/**
 * 在before、原函数体、around、after任意一个抛出异常时执行，默认返回参数e
 */
func throwing(funcInfo: InvocationFuncInfo, e: Exception): Exception
/**
 * 在before、原函数体、around、after、throwing执行完成后执行，默认什么也不做
 */
func final(funcInfo: InvocationFuncInfo): Unit
/**
 * 开发者可以覆盖这个函数自由定义切面，默认是执行before around 原函数体 after throwing final
 */
func proceed(funcInfo: InvocationFuncInfo, point: (Array<Any>) -> Any): Any
```

#### AspectRoute

AspectRoute是一个注解，被它修饰的且实现了Aspect接口的类才是一个完整的切面。使用RouteRule实例初始化AspectRoute。

### AOP的织入原理。

@Pointcut把它修饰的函数包装成无参嵌套函数`fn`，构造的InvocationFuncInfo和嵌套函数作为实参调用`Aspects.proceed`函数。proceed函数从IOC获得全部Aspect实现的切面列表，遍历切面对象，获得声明切面的AspectRoute，用InvocationFuncInfo调用AspectRoute的matches函数，AspectRoute会调用RouteRule，从RouteRule返回true的表示当前函数符合织入规则。

嵌套函数包装成`var f: (Array<Any>) -> Any = {args => fn(args)}`。

所有符合规则的切面bean name填入一个`ArrayList<String>`，倒序遍历这个ArrayList，每一个切面都包装成如下的闭包：

```cj
for (i in list.size - 1..=0 : -1) {
    let aspected = f
    f = {args =>
	    funcInfo.setArgs(args)//funcInfo的类型就是InvocationFuncInfo
		BeanFactory.instance.get<Aspect>(list[i]).getOrThrow().proceed(funcInfo, aspected)
	}
}
```

以上这些过程都在Aspects类的`public static func proceed<T>(funcInfo: InvocationFuncInfo, fn: (Array<Any>) -> T): T `函数完成。Aspects.proceed函数会由被@Pointcut展开的代码调用。由于编译器可以完成泛型实参的类型推断，即使原函数没有声明返回类型，原函数体包装的嵌套函数的类型也会被推断出来，进而推断出proceed函数的泛型实参。

当切面层层调用最后返回才从包装函数的返回值从Any类型转换为proceed的泛型实参类型。

### 事务

事务的关键类型就是TransactionAspect，它的声明如下：

```cj
@AspectRoute[FuncAnnotationRouteRule("f_orm.Transactional") | ConfigExecutionRouteRule(ORMConfig.transactionalFuncExecution)]
@BeanMeta
public class TransactionAspect <: Aspect
```

这就是事务切面。所有满足配置项`orm_transactionalFuncExecution`指定的织入规则函数或被Transactional注解修饰的函数都会实现事务控制。另外事务级别、事务传播特性、TransactionAccessMode、TransactionDeferrableMode都可以由这个注解以及相应配置项获得相关信息，还可以控制发生哪些异常时可以提交，哪些异常需要回滚也可以用注解或配置项指定。

相关配置项如下：

```
orm_transactionPropagation    # 事务传播配置
orm_transactionLevel          # 事务级别
orm_transactionAccessMode     # TransactionAccessMode
orm_transactionDeferrableMode # TransactionDeferrableMode
orm_transactionNoRollbackFor  # 可以提交的异常
orm_transactionRollbackFor    # 需要回滚的异常
```
如果同时依赖了不止一个数据库，还可以针对不同的数据库添加事务配置，比如下面就为opengauss添加了事务传播特性：
```
opengauss_orm_transactionPropagation=Requires
```

下面是事务传播特性：

```cj
/*
 * RequiresNew 和 NotSupported 会创建新连接，在这两个特性的作用范围内如果有其它传播特性判定还是以原连接是否创建了事务为依据。
 * 多个指定事务的函数嵌套调用的时候由事务传播枚举决定是创建新的事务还是复用外层函数的事务。
 */
public enum Propagation {
    | Required //外层函数开启了事务就使用这个事务，如果没有事务就创建一个新事务。
    | Supports //外层函数开启了事务就使用这个事务，如果没有事务就不用事务。
    | Mandatory //外层函数开启了事务就使用这个事务，没有事务就抛异常
    | RequiresNew //创建一个新连接，创建新事务。
    | Never //不使用事务，如果外层函数开启了事务就抛出异常。
    | NotSupported //不使用事务，如果外层函数开启了事务就创建一个新的数据库连接执行当前函数的业务。
    | Nested //如果外层函数开启了事务就开启一个新事务，如果没有当前函数也不使用事务。
}
```

事务传播的核心是因为有以下类型：

![事务传播](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC05%E5%BC%B9%E2%80%94%E2%80%94AOP&%E4%BA%8B%E5%8A%A1/%E4%BA%8B%E5%8A%A1%E4%BC%A0%E6%92%AD.jpg)

每次调用受事务控制的函数，不论当前函数是否需要创建事务都会用外层函数的TransactionWrap创建一个新的TransactionWrap，TransactionWrap包装着真实的事务实例，如果当前函数需要创建新的事务就用新建的事务，如果不需要创建新事务会使用DummyTransaction顶替。

TransactionWrap的实例是SqlExecution的成员，发生一次事务函数的调用就包一层新的TransactionWrap的皮，事务函数返回时就脱一层。

### WeavedBean

AOP模块提供了宏@WeavedBean，weave函数会为每个公共实例成员函数完成织入，相当于@Bean+@Pointcut同时修饰一个类。

```cj
public macro WeavedBean(input: Tokens): Tokens {
    let tokens = quote(
        @Bean
        $(weave(input))
    )
    tokens
}
public macro WeavedBean(attr: Tokens, input: Tokens): Tokens {
    quote(
        @Bean[$attr]
        $(weave(input))
    )
}
```



### 事务宏

使用@TransactionalService修饰需要事务控制的类，宏展开时为它修饰的类添加@Bean宏修饰，为这个类的公共实例成员函数添加@Pointcut宏修饰。

@TransactionalService做了跟@WeavedBean一样的事，因为前者是后者的别名。

### 事务钩子

实现接口TransactionHook并注册到IOC的实例都是事务钩子。

```cj
public interface TransactionHook {
    func beforeTx(): Unit {}//事务开启前
    func beforeCommit(readOnly: Bool): Unit {}//事务提交前
    func afterCommit(): Unit {}//事务提交后
    func afterThrowing(e: Exception): Unit {}//抛出异常后
    func beforeRollback(e: Exception): Unit {}//回滚前
    func afterRollback(e: Exception): Unit {}//回滚后
    func afterComplete(status: TransactionStatus): Unit {}//函数返回前
    /**
     * 用于决定钩子的执行顺序
     */
    prop order: Int64 {
        get() {
            Int64.Max
        }
    }
}
```



### 事务例子

定义环境变量：

```bash
export orm_transactionalFuncExecution='*..*.delete*(**): *|*..*.remove*(**): *|*..*.save*(**): *|*..*.add*(**): *|*..*.new*(**): *|*..*.create*(**): *|*..*.insert*(**): *|*..*.update*(**): *|*..*.change*(**): *'
```

定义类

```cj
@TransactionalService//如果不需要事务控制可以用@Bean修饰
public class UserServiceImpl <: UserService {
    public func register(username: String, password: String): Int64 {
        println('username: ${username}, password: ${password}')
        executor().register(username, password)
    }
    @Transactional//仅做演示，此函数只有查询，不需要事务控制，如果事务生效，控制台会输出日志
    public func userSession(username: String, password: String): ?(Int64, String, Bool) {
        UserEntity(username, password).makeSession(executor().findUserId)
    }
}
//只要使用宏@TransactionalService修饰的类事务控制都会生效
```

定义一个事务钩子：

```cj
import fountain.bean.*
import fountain.bean.macros.*
import fountain.log.*
import fountain.orm.*

@Bean
public class TransactionHookImpl <: TransactionHook {
    private let log = LoggerFactory.getLogger('TransactionHook')
    public func beforeTx(): Unit {
        log.info('beforeTx')
    }
    public func beforeCommit(readOnly: Bool): Unit {
        log.info('beforeCommit')
    }
    public func afterCommit(): Unit {
        log.info('afterCommit')
    }
    public func afterThrowing(e: Exception): Unit {
        log.info('afterThrowing')
    }
    public func beforeRollback(e: Exception): Unit {
        log.info('beforeRollback')
    }
    public func afterRollback(e: Exception): Unit {
        log.info('afterRollback')
    }
    public func afterComplete(status: TransactionStatus): Unit {
        log.info('afterComplete')
    }
}
```

如果事务控制生效了执行到希望开启事务的函数时会记录这些日志。