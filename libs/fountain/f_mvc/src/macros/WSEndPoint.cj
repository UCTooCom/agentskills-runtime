/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
macro package f_mvc.macros

import std.ast.*
import f_macros.*

/**
 * attr的可选项
 * '.....',//URL路径，必须指定且必须是attr开头第一个，必须是字符串类型
 * subProtocols: [....],
 * origins: [....],
 * userFunc: ...//任意正确的的闭包，或者使用本宏的当前作用域内可见的函数标识，函数类型是(HttpRequest) -> HttpHeaders
 * 本宏修饰的类型必须是类。
 * 确保有且只有被@OnWS*开头的注解修饰的函数和被@WSPing修饰的函数才是公共实例成员函数，且函数名在当前类中唯一。
 */
public macro WSEndPoint(attr: Tokens, input: Tokens): Tokens {
    let tokens = generate(attr, input)
    quote(
        @Bean
        $input
        $tokens
    )
}
private func generate(attr: Tokens, input: Tokens): Tokens {
    let path = attr[0]
    let upgradeAttrs = attr[1 .. attr.size]
    let tokens = quote()
    let decl = match(parseDecl(input)){
        case x: ClassDecl => x
        case x: MacroExpandDecl => 
            var y = x
            while(let m: MacroExpandDecl <- y.macroInputDecl) {
                y = m
            }
            if(let d: ClassDecl <- y.macroInputDecl) {
                d
            }else{
                diagReport(ERROR, y.macroInputs, 'illegal decl', '')
                return input
            }
        case _ =>
            diagReport(ERROR, input, 'illegal decl', '')
            return input
    }
    let klass = decl.identifier
    var metaTokens = quote(
        let metaHandles = HashMap<String, (WSFuncMeta<$klass>, Bool) -> Unit>()$(`nl`)
    )
    let typeInfo = quote(let classTypeInfo = ClassTypeInfo.of<$(decl.identifier)>())
    for(d in decl.body.decls where isPublic(d) && !isStatic(d)) {
        if(let f: FuncDecl <- d){
            var paramTokens = quote()
            var paramTypes = quote([)
            var factParams = quote()
            for(p in f.funcParams){
                let default = try{
                    p.expr.toTokens()
                }catch(_){
                    `empty_tokens`
                }
                let named = p.not.kind == TokenKind.NOT
                paramTokens += quote(
                    let $(p.identifier) = match(None<$(p.paramType)>){
                        case _: ?HttpContext => (ctx as $(p.paramType)).getOrThrow()
                        case _: ?HttpRequest => (ctx.request as $(p.paramType)).getOrThrow()
                        case _: ?HttpHeaders => (ctx.request.headers as $(p.paramType)).getOrThrow()
                        case _: ?WebSocket => (ws as $(p.paramType)).getOrThrow()
                        case _: ?Array<Byte> => (payload as $(p.paramType)).getOrThrow()
                        case _ where cf => (WSCloseFrame(payload) as $(p.paramType)).getOrThrow()
                        case _ => (m.extract<$(p.paramType)>(ctx, $(p.identifier.value), converter, pattern, ws, payload) as $(p.paramType)).getOrThrow()
                    }$(`nl`)
                )
                if(factParams.size > 0){
                    factParams += `comma`
                }
                factParams += if(named && default.size > 0) {
                    quote($(p.identifier): $(p.identifier) ?? $(default))
                } else if (named && default.size == 0){
                    quote($(p.identifier): $(p.identifier))
                } else if (!named && default.size > 0) {
                    quote($(p.identifier) ?? $default)
                } else {
                    quote($(p.identifier).getOrThrow())
                }
                if(paramTypes.size > 0){
                    paramTypes += `comma`
                }
                paramTypes += quote(TypeInfo.of<$(p.paramType)>())
            }
            paramTypes += quote(])
            metaTokens += quote(
                metaHandles[$(f.identifier.value)] = {=>
                    let fInfo = classTypeInfo.getInstanceFunction($(f.identifier.value), $paramTypes)
                    let converter = fInfo.findAnnotation<AbstractDateTimeConverter>()
                    {m, cf => 
                        m.setHandle{endpoint, ctx, pattern, ws, payload => 
                            $paramTokens
                            endpoint.$(f.identifier)($factParams)
                        }
                    }
                }()$(`nl`)
            )
        }
    }
    quote(
        private let _ = {=>
            $typeInfo
            $metaTokens
            let meta = MVCStarter.generateAndRegisterWSEndPoint<$klass>($path)
            if(let Some(m) <- meta.openMeta){
                metaHandles[m.name](m, false)
            }
            if(let Some(m) <- meta.closeMeta){
                metaHandles[m.name](m, true)
            }
            if(let Some(m) <- meta.textMeta){
                metaHandles[m.name](m, false)
            }
            if(let Some(m) <- meta.binaryMeta){
                metaHandles[m.name](m, false)
            }
            if(let Some(m) <- meta.pingMeta){
                metaHandles[m.name](m, false)
            }
            if(let Some(m) <- meta.pongMeta){
                metaHandles[m.name](m, false)
            }
            if(let Some(m) <- meta.pingFunc){
                metaHandles[m.name](m, false)
            }
            meta.setHandle{endpoint, converter, ctx, pattern => 
                let ws = meta.upgrade(ctx, $upgradeAttrs)
                meta.exec(endpoint, converter, ctx, pattern, ws)
            }
        }()
    )
}