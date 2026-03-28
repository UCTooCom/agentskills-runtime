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
macro package f_aspect.macros

import std.ast.*
import f_aspect.exception.AspectException
import f_macros.*
import std.reflect.*

public macro Pointcut(input: Tokens): Tokens {
    if (insideParentContext('Pointcut')) {
        return input
    }
    func doPointcut(decl: Decl): Tokens {
        match(decl){
            case x: FuncDecl => pointcut(x)
            case x: ClassDecl => pointcut(x)
            case x: MacroExpandDecl =>
                var m: MacroExpandDecl = x
                while(let md: MacroExpandDecl <- m.macroInputDecl){
                    m = md
                }
                m.macroInputDecl = parseDecl(doPointcut(m.macroInputDecl))
                x.toTokens()
            case x => 
                diagReport(ERROR, input, '${x.identifier.value} must be a func decl or a class decl', '')
                throw AspectException()
        }
    }
    doPointcut(parseDecl(input))
}
func pointcut(decl: FuncDecl): Tokens {
    var tokens = decl.toTokens()
    var funcDecl = quote()
    for (t in tokens) {
        if (t.kind == TokenKind.LCURL) {
            break
        }
        funcDecl += t
    }
    let params = decl.funcParams
    var argVars = quote()
    var args = `lsquare`
    var argTypes = `lsquare`
    for (i in 0..params.size) {
        let param = match(params[i]){
            case x: MacroExpandParam => 
                var mp: MacroExpandParam = x
                while(let m: MacroExpandParam <- mp.macroInputDecl){
                    mp = m
                }
                match(mp.macroInputDecl){
                    case x: FuncParam => x
                    case x: MacroExpandDecl => 
                        var md: MacroExpandDecl = x
                        while(let m: MacroExpandDecl <- md.macroInputDecl){
                            md = m
                        }
                        match(md.macroInputDecl){
                            case x: FuncParam => x
                            case x => FuncParam(x.toTokens())
                        }
                    case x => throw AspectException('unexpected decl ${x.toTokens()} ${ClassTypeInfo.of(x)}')
                }
            case x: FuncParam => x
            case x => throw AspectException('unexpected decl ${x.toTokens()} ${ClassTypeInfo.of(x)}')
        }
        let paramName = param.identifier
        argVars += quote(
            let $paramName = (args[$(i)] as $(param.paramType)).getOrThrow()
        ) + `nl`
        if (i > 0) {
            args += `comma`
            argTypes += `comma`
        }
        args += paramName
        argTypes += quote(TypeInfo.of<$(param.paramType)>())
    }
    args += `rsquare`
    argTypes += `rsquare`
    let funcName = decl.identifier.value
    let funcType = try {
        decl.declType.toTokens()
    } catch (_) {
        `empty_tokens`
    }
    let proceed = if (funcType.size == 0) {
        quote(Aspects.proceed(info, callee))
    } else {
        quote(Aspects.proceed<$funcType>(info, callee))
    }
    tokens = quote(
        $funcDecl {
            func callee(args: Array<Any>){
                $argVars
                $(decl.block.nodes)
            }
            let info = InvocationFuncInfo(TypeInfo.of(this), $funcName, $argTypes, $args)
            $proceed
        }
    )
    tokens
}
private func pointcut(decl: ClassDecl): Tokens {
    let decls = decl.body.decls
    for(i in 0 .. decls.size) {
        let d = decls[i]
        if (let f: FuncDecl <- d && !isStatic(d) && isPublic(d) && d.identifier.value != 'init') {
            decls[i] = parseDecl(pointcut(f))
        } else if (let md: MacroExpandDecl <- d) {
            var m: MacroExpandDecl = md
            while(let md: MacroExpandDecl <- m.macroInputDecl){
                m = md
            }
            if(let f: FuncDecl <- m.macroInputDecl && !isStatic(f) && isPublic(f)){
                m.macroInputDecl = parseDecl(pointcut(f))
            }
        }
    }
    decl.toTokens()
}