# fountain实现思想与应用第六弹

##### ——MVC

项目链接：https://gitcode.com/Cangjie-SIG/fountain

![MVC-1760757097624](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC06%E5%BC%B9%E2%80%94%E2%80%94MVC/MVC-1760757097624.jpg)

MVC的核心类型是RequestMeta。

@Controlller宏遍历它修饰的类每一个公共实例成员函数，它展开的代码利用这些函数的函数名和参数TypeInfo调用内部函数获得Mapping注解和参数注解，并利用这些注解从HttpContext获得函数参数将它们转换为参数类型调用相应的函数，它们会作为尾闭包注册到RequestMeta。

每次访问会从自定义的HttpRequestDistributorImpl利用请求路径找到MultiRequestMethodHandler实例，这个实例利用请求方法和Content-Type请求头找到相应的RequestMeta，MultiRequestMethodHandler会检查请求方法、Content-Type，并对不符合的访问返回相应的http状态码。然后调用RequestCondition实例检查表单参数和请求头，最后调用AuthHandler检查当前登录状态和用户访问权限，对于满足所有条件的访问会调用注册到RequestMeta的handle闭包，闭包内部从BeanFactory获得相应的Controller类实例并用这个实例调用controller函数。

@Controller宏会利用各种参数注解解析各种参数。@RequestBody会利用Content-Type从MediaTypes获得注册的MediaType实现，将请求体转换为controller函数参数，@RequestParam会利用它的注解参数或函数参数名从表单获得请求参数，@RequestHeader会利用它的注解参数函数参数名从请求头获得请求参数，@PathVariable会利用它的注解参数或函数参数名从请求路径获得参数。

开发者还可以向MVC注册自定义的AuthHandler实现登录状态和权限检查，并且可以实现ErrorHttpRequestHandler向MVC注册统一的各种错误结果HTTP响应状态码和HTTP响应体。

对于某些不需要检查登录和权限的controller函数可以使用@IgnoreAuth @IgnorePrivilege @IgnoreSecurity忽略检查，@IgnoreAuth会忽略检查登录状态，@IgnorePrivilege会忽略检查权限，@IgnoreSecurity会两个检查都忽略。

MVCStarter.initialize()从配置类获得配置信息完成stdx.net.http.Server初始化。

### 实例化RequestMeta

`@Controller`宏将每个公共实例成员函数的参数类型的TypeInfo、函数名作为`MVCStarter.generateAndRegister`的函数实参，controller类名作为这个函数的泛型实参。此函数最终会到达RequestMeta的generate函数，函数内反射获得InstanceFunctionInfo。以函数参数名为KEY，以ControllerFuncParam子类型和Validator子类型的注解为值构造`HashMap<String, (ControllerFuncParam, Validator)>`。

#### controller函数映射

`@PostMapping` `@GetMapping` `@PutMapping` `@DeleteMapping` 是Controller函数的注解，标注controller URL、请求方法、Content-Type Accept。比如可以有以下注解

```cj
@PostMapping[//请求方法是POST
    path:'/api/user/session',//请求路径
    consumes:'application/json',//对应Content-Type
    produces:'application/json'//对应Accept
]
public func login(request: UserLoginRequest): UserSession{...}
```

#### 忽略登录、权限检查

-   `@IgnoreAuth`——忽略登录检查
-   `@IgnorePrivilege`——忽略权限检查
-   `@IgnoreSecurity`——登录和权限检查都忽略

以上注解都用来修饰controller公共实例函数，注解内的相关数据与前述的HashMap一起初始化为RequestMeta实例。最后`@Controller`宏会利用这些controller函数调用创建闭包作为HTTP请求的处理逻辑。具体的闭包如下：

```cj
meta.setHandle{controller: $klass, ctx: HttpContext, patterns: HttpRequestPathPatterns => 
	let start = MonoTime.now()
	$argExprs//RequestMeta利用ControllerFuncParam的子类型注解将各种类型的参数转换为函数实参
	$anyargs//将函数实参构造为Array<Any>
	var any: ?Any = None<Any>
	var ex = None<Exception>
	try {
		if (meta.checkAuth(ctx, anyArgs)) {//检查登录和权限
			let returned: Any = controller.$(f.identifier)($args)//调用controller函数
			any = returned
			return returned
		}
	} catch(e: Exception) {
		ex = e
	} finally {
		meta.accessLog<$klass>(start, ctx, anyArgs, any, ex)//记录访问日志
	}
}
```

ControllerFuncParam的子类型是controller函数参数的注解，它有以下声明

-   `@RequestParam` ——表单参数。
-   `@PathVariable`——从路径参数获取函数参数，各类Mapping注解的path参数可以指定带参数的路径。`/api/user/{id}`，这就是一个带参数的路径，参数使用花括号包含。
-   `@RequestHeader`——从请求头获取函数参数。
-   `@RequestBody`——将请求体转换为函数实参。此注解实例用请求头Content-Type获得MediaType实例，每一种MediaType对应一种序列化和反序列化逻辑。比如`MediaTypes.tryParse('application/json')`就可以将JSON转换为`@DataAssist[fields]`修饰的类实例，也可以反过来将类的实例转换为JSON。

`@RequestParam`  `@PathVariable`  `@RequestHeader`这三个注解都可以用注解的构造函数参数指定参数名，如果不指定默认使用函数参数名作为表单的参数名。

### 登录与权限检查

登录和权限检查依赖以下三个接口，如果想同时检查登录状态和权限可以只实现AuthHandler接口。如果想分开检查可以分别实现UserSessionHandler和PrivilegeHandler。这些接口的实现注册到IOC才可以生效。如果同时实现了三个接口，会按照从IOC的返回顺序决定哪个生效，如果UserSessionHandler和PrivilegeHandler不都在AuthHandler的前面，则只有AuthHandler生效。

```cj
/**
 * 这个接口的实现类用fountain.bean.macros.@Bean修饰可以实现登录状态与权限检查。
 * 如果应用项目，登录状态和权限都需要检查，务必在一个类中实现，一次调用就都检查了。
 */
public interface AuthHandler {
    /**
     * 检查当前用户登录状态及权限
     * @param ctx 当前请求上下文
     * @param args 处理当前请求的函数参数
     * @return 当前用户登录状态及权限的检查结果
     */
    func check(param: AuthParam): AuthStatus
}
/**
 * ctx: 当前请求上下文
 * path: 当前请求的controller映射路径，不是请求的路径，是controller函数定义的路径
 * args: 当前请求的参数
 * ignoreAuth: 是否忽略登录检查
 * ignorePrivilege: 是否忽略权限检查
 */
public struct AuthParam {
    public AuthParam(
        public let ctx: HttpContext,
        public let path: String,
        public let args: ArrayList<Any>,
        public let ignoreAuth: Bool,
        public let ignorePrivilege: Bool
    ){}
}
/**
 * 登录检查
 */
public interface UserSessionHandler <: AuthHandler {}
/**
 * 权限检查
 */
public interface PrivilegeHandler <: AuthHandler {}
```

AuthStatus是检查结果，声明如下：

```cj
/**
 * 枚举的Any类型实际只能处理String ToString InputStream Array<Byte> f_data.ToData这几种类型，
 * 如果是其它类型将会忽略，转而使用HttpStatus的reasonPhrase作为响应体。
 * OK：当前用户登录状态有效且权限正确。
 * SessionNotFound：未找到当前用户的登录状态，可能是用户未登录，也可能是登录状态已过期。
 * InvalidSession：找到了当前用户的登录状态，但是本次访问传递的登录信息无效。
 * SessionError：检查当前用户登录状态时发生错误，可能是服务器内部错误。
 * PrivilegeError：检查当前用户权限时发生错误，可能是服务器内部错误。
 * NoPrivilege：当前用户没有权限访问该资源。
 * 没有HttpStatus参数的构造器表示响应状态码是200
 */
public enum AuthStatus {
    | OK
    | SessionNotFound(HttpStatus, Any)
    | SessionNotFound(Any)
    | InvalidSession(HttpStatus, Any)
    | InvalidSession(Any)
    | SessionError(HttpStatus, Any)
    | SessionError(Any)
    | PrivilegeError(HttpStatus, Any)
    | PrivilegeError(Any)
    | NoPrivilege(HttpStatus, Any)
    | NoPrivilege(Any)

    public prop isOK: Bool {
        get(){
            match(this){
                case OK => true
                case _ => false
            }
        }
    }
}
```

### 异常处理逻辑

默认情况，发生异常时http status是500，响应体是Internal Server Error。如果想做额外处理可以实现以下接口。

```cj
public interface ErrorHttpRequestHandler {
    func handle(ctx: HttpContext, e: ?Exception): (HttpStatus, Any)
}
```

ctx是本次HTTP访问的stdx.net.http.HttpContext，e是本次发生的异常。返回的Any可以是字节数组、字符串、ToString、InputStream，还有被`@DataAssist[fields]`修饰的类实例。前面几种类型会直接作为ctx.responseBuilder.body函数的实参，如果返回的是`@DataAssist[fields]`修饰的类则按照Accept将实例转换为字节数组作为响应体，如果没有指定Accept，将实例转换的Data再转换为字符串作为响应体。

### 声明一个Controller

```cj
import fountain.mvc.*
import fountain.mvc.macros.*//此包重导出了IOC的@Bean宏

@Controller//重新用@Bean修饰了这个类
public class HellowordController {
    @GetMapping[path:"/helloworld", produces:'text/plain']
    @IgnoreSecurity
    public func helloworld(): String {
        return "helloworld"
    }
}
```

### 错误处理器
```cj
import stdx.net.http.HttpContext
import fountain.bean.*
import fountain.bean.macros.*
import fountain.data.*
import fountain.data.macros.*
import fountain.mvc.{ErrorHttpRequestHandler, HttpStatus}

@Bean
@BeanMeta[name:'NameOf500Handler']
public class Http500Handler <: ErrorHttpRequestHandler {
    public func handle(_: HttpContext, _: ?Exception): (HttpStatus, Any) {
        (HttpStatus.OK, BaseResponse.error('error'))
    }
}
@DataAssist[fields]
public open class BaseResponse {
    public var code: UInt16 = 0
    public var msg: String = "ok"

    public init() {}
    public init(code: UInt16, msg: String) {
        super()
        this.code = code
        this.msg = msg
    }

    public static func success(): BaseResponse {
        BaseResponse(0, "ok")
    }

    public static func success(msg: String): BaseResponse {
        BaseResponse(0, msg)
    }

    public static func error(msg: String): BaseResponse {
        BaseResponse(1, msg)
    }
}
```
### MVC初始化

```bash
    export mvc_port=8080 # 这一行可以没有，默认就是8080                                                                         
    export mvc_internalServerErrorMessageKind=BEAN # 错误处理类型
    export mvc_internalServerErrorMessage=NameOf500Handler # 错误处理BEAN名称，如果没有这两行配置前面的错误处理器将不会生效
```

### controller切面

有些时候可能需要为controller织入切面，此时就需要用宏@WeavedController，除了完成@Controller宏的功能，还用@Pointcut重新修饰了controller类声明。