macro package ystyle::cordis_plugin.macros

import std.ast.*
// 重导出运行时符号：宏展开生成的代码直接引用，使用者仅导入宏包即可编译
public import ystyle::cordis_plugin.PluginRuntime
public import ystyle::cordis_plugin.PluginContext
public import ystyle::cordis_plugin.ServiceProxy

/**
 * @inject 属性宏：标记插件类中依赖外部服务的字段
 *
 * 用法：
 * ```cangjie
 * @Plugin[]
 * public class MyPlugin {
 *     @Inject["db"]
 *     public var db: ServiceProxy   // 声明依赖 db 服务，宏注入 ServiceProxy(ctx, "db")
 * }
 * ```
 *
 * @Inject 通过 setItem 把 (服务 key, 字段名) 上报给外层 @plugin 宏，
 * 自身展开后保持原字段声明不变（由 @plugin 生成的构造函数注入值）。
 */
public macro Inject(attr: Tokens, input: Tokens): Tokens {
    assertParentContext("Plugin")
    // 解析 @Inject["service-key"] 属性
    let serviceKey = parseAttrString(attr, "inject")
    // 解析字段声明
    let varDecl = parseDecl(input)
    if (!(varDecl is VarDecl)) {
        throw Exception("@Inject is only allowed on var fields")
    }
    let fieldName = (varDecl as VarDecl).getOrThrow().identifier.value
    // 上报给外层 @plugin 宏
    setItem("injectKey", serviceKey)
    setItem("injectField", fieldName)
    // 保持原字段声明不变
    return input
}

/**
 * @provide 属性宏：标记插件类中对外提供服务的 public 方法
 *
 * 用法：
 * ```cangjie
 * @plugin
 * public class MyPlugin {
 *     @provide["echo"]
 *     public func echo(args: Array<JsonValue>): JsonValue {
 *         // 业务逻辑
 *     }
 * }
 * ```
 *
 * @provide 通过 setItem 把 (服务 key, 方法名) 上报给外层 @plugin 宏，
 * 自身展开后保持原方法声明不变。
 */
public macro Provide(attr: Tokens, input: Tokens): Tokens {
    assertParentContext("Plugin")
    // 解析 @provide["service-key"] 属性
    let serviceKey = parseAttrString(attr, "provide")
    // 解析方法声明
    let funcDecl = FuncDecl(input)
    let methodName = funcDecl.identifier.value
    // 上报给外层 @plugin 宏
    setItem("serviceKey", serviceKey)
    setItem("methodName", methodName)
    // 保持原方法不变
    return input
}

/**
 * @plugin 属性宏：把类标记为 Cordis 插件，自动生成 main + 运行时启动
 *
 * 展开逻辑：
 * 1. 收集类内所有 @provide 方法（getChildMessages("Provide")）
 * 2. 收集类内所有 @inject 字段（getChildMessages("Inject")）
 * 3. 给类添加构造函数 init(__ctx: PluginContext)，为每个 @inject 字段注入 ServiceProxy
 * 4. 生成 main：PluginRuntime.run(类名, [inject keys...], [provide keys...], { ctx =>
 *        let __plugin = 类名(ctx)
 *        ctx.registerHandler(key, { method, args => __plugin.方法(args) })
 *    })
 */
public macro Plugin(_: Tokens, input: Tokens): Tokens {
    let classDecl = ClassDecl(input)
    let className = classDecl.identifier.value
    let classNameToken = Token(TokenKind.IDENTIFIER, className)

    // 收集 @provide 子宏消息
    let provides = getChildMessages("Provide")
    // 收集 @inject 子宏消息
    let injects = getChildMessages("Inject")

    // 构造 provide 服务 key 数组：[ "key1", "key2" ]
    var keyTokens = Tokens()
    keyTokens = keyTokens + Token(TokenKind.LSQUARE)
    var first = true
    for (msg in provides) {
        if (!first) {
            keyTokens = keyTokens + Token(TokenKind.COMMA)
        }
        first = false
        let key = msg.getString("serviceKey")
        keyTokens = keyTokens + Token(TokenKind.STRING_LITERAL, key)
    }
    keyTokens = keyTokens + Token(TokenKind.RSQUARE)

    // 构造 inject 依赖 key 数组：[ "db", "cache" ]
    var injectTokens = Tokens()
    injectTokens = injectTokens + Token(TokenKind.LSQUARE)
    var firstInject = true
    for (msg in injects) {
        if (!firstInject) {
            injectTokens = injectTokens + Token(TokenKind.COMMA)
        }
        firstInject = false
        let key = msg.getString("injectKey")
        injectTokens = injectTokens + Token(TokenKind.STRING_LITERAL, key)
    }
    injectTokens = injectTokens + Token(TokenKind.RSQUARE)

    // 生成构造函数体：为每个 @inject 字段注入 ServiceProxy
    var initBody = Tokens()
    var firstInit = true
    for (msg in injects) {
        if (!firstInit) {
            initBody = initBody + Token(TokenKind.NL)
        }
        firstInit = false
        let field = msg.getString("injectField")
        let key = msg.getString("injectKey")
        let fieldToken = Token(TokenKind.IDENTIFIER, field)
        initBody = initBody + quote(
            this.$(fieldToken) = __ctx.proxy($(key))
        )
    }
    // 构造函数（有 @inject 字段才生成）
    if (injects.size > 0) {
        let initDecl = parseDecl(quote(
            public init(__ctx: PluginContext) {
                $(initBody)
            }
        ))
        classDecl.body.decls.add(initDecl)
    }

    // 构造 handler 内的注册语句列表（拼接为 Tokens）
    var registrations = Tokens()
    var firstReg = true
    for (msg in provides) {
        if (!firstReg) {
            registrations = registrations + Token(TokenKind.NL)
        }
        firstReg = false
        let serviceKey = msg.getString("serviceKey")
        let methodName = msg.getString("methodName")
        let methodToken = Token(TokenKind.IDENTIFIER, methodName)
        registrations = registrations + quote(
            ctx.registerHandler($(serviceKey), { _, args => __plugin.$(methodToken)(args) })
        )
    }

    // 生成 main 函数（作为独立进程入口）
    // className 作为字符串字面量传入 PluginRuntime.run
    let nameLiteral = Token(TokenKind.STRING_LITERAL, className)
    // 有 @inject 字段时构造函数需要 ctx（init(__ctx: PluginContext)），否则无参构造
    let mainTokens = if (injects.size > 0) {
        quote(
            main(): Int64 {
                PluginRuntime.run($(nameLiteral), $(injectTokens), $(keyTokens), { ctx =>
                    let __plugin = $(classNameToken)(ctx)
                    $(registrations)
                })
                return 0
            }
        )
    } else {
        quote(
            main(): Int64 {
                PluginRuntime.run($(nameLiteral), [], $(keyTokens), { ctx =>
                    let __plugin = $(classNameToken)()
                    $(registrations)
                })
                return 0
            }
        )
    }

    // 将 main 追加到类声明之后（顶层函数）
    let classTokens = classDecl.toTokens()
    return classTokens + mainTokens
}

/**
 * 解析属性参数中的字符串：@provide["key"]
 */
func parseAttrString(attr: Tokens, macroName: String): String {
    let s = attr.toString()
    let trimmed = s.trimStart().trimEnd()
    // 去掉可能的 [] 和引号
    var content = trimmed
    if (content.startsWith("[")) {
        content = content[1..]
    }
    if (content.endsWith("]")) {
        content = content[0..(content.size - 1)]
    }
    content = content.trimStart().trimEnd()
    if (content.startsWith("\"")) {
        content = content[1..]
    }
    if (content.endsWith("\"")) {
        content = content[0..(content.size - 1)]
    }
    if (content.isEmpty()) {
        throw Exception("@${macroName} requires a string key, e.g. @${macroName}[\"service-key\"]")
    }
    content
}
