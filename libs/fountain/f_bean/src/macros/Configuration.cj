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
macro package f_bean.macros

/**
 * 将@Configuration修饰的类里被@Constructor修饰的函数作为bean初始化函数。被@Configuration修饰的类不会注册到BeanFactory.
 */
public macro Configuration(input: Tokens): Tokens {
    let klass = ClassDecl(input)
    let identifier = klass.identifier
    var staticTokens = quote()
    var instanceTokens = quote()
    for (d in klass.body.decls) {
        func expandFuncTokens(f: FuncDecl, fnIdentifier: Tokens, fnPrefix: Tokens): Tokens {
            let fname = f.identifier.value
            quote(
                BeanFactory.instance.$fnIdentifier<$identifier>($fname){$fnPrefix.$(f.identifier)()}$(`nl`)
            ) + `nl`
        }
        match (d) {
            case med: MacroExpandDecl =>
                var md: Decl = med
                var isBeanInit = false
                while (let d: MacroExpandDecl <- md) {
                    isBeanInit ||= d.fullIdentifier.value == 'BeanInit'
                    md = d.macroInputDecl
                    match (md) {
                        case f: FuncDecl where isBeanInit && isStatic(f) && isPublic(f) && f.funcParams.isEmpty() =>
                            staticTokens += expandFuncTokens(f, quote(registerByStaticFunction), quote($identifier))
                        case f: FuncDecl where isBeanInit && !isStatic(f) && isPublic(f) && f.funcParams.isEmpty() =>
                            instanceTokens += expandFuncTokens(f, quote(registerByInstanceFunction), quote(configuration))
                        case f: MacroExpandDecl => continue
                        case _ => break
                    }
                    break
                }
            case _ => ()
        }
    }
    topMacroAnonymousClosure(quote(
        $staticTokens
        let configuration = $(identifier)()
        $instanceTokens
    ))
}
