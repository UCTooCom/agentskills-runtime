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
 * 只能修饰类。将@Bean修饰的类注册到BeanFactory。如果不是泛型类型建议使用无属性的@Bean宏。
 * 本宏的属性仅仅用来指定泛型类型的泛型实参，可以使用|分隔指定多组泛型实参。
 */
public macro Bean(attr: Tokens, input: Tokens): Tokens {
    let klass = extractClassDecl(input)
    expandBean(attr, input, klass)
}
/**
 * 只能修饰类。将@Bean修饰的类注册到BeanFactory。如果不是泛型类型建议使用无属性的@Bean宏
 */
public macro Bean(input: Tokens): Tokens {
    let klass = extractClassDecl(input)
    expandBean(quote(), input, klass)
}
private func extractClassDecl(input: Tokens): ClassDecl {
    match(parseDecl(input)){
        case x: ClassDecl => x
        case x: MacroExpandDecl => 
            match(extract(x)){
                case x: ClassDecl => x
                case _ => 
                    diagReport(ERROR, input, '@Bean modify class decl only', '')
                    throw BeanException()
            }
        case _ => 
            diagReport(ERROR, input, '@Bean modify class decl only', '')
            throw BeanException()
    }
}
private func expandBean(attr: Tokens, input: Tokens, klass: ClassDecl): Tokens {
    let identifier = klass.identifier
    let list = ArrayList<Tokens>()
    list.add(quote())
    for(i in 0 .. attr.size){
        let a = attr[i]
        if(a.kind == TokenKind.BITOR){
            list.add(quote())
            continue
        } else {
            let last = list.size - 1
            list[last] = list[last] + a
        }
    }
    if(list.size > 1){
        list.removeIf{g => g.size == 0}
    }
    let messages = getChildMessages('Constructor')
    var tokens = input
    for(g in list){
        let beanType = if(g.size == 0){
            quote($identifier)
        }else{
            quote($identifier<$g>)
        }
        if(messages.isEmpty()){
            tokens += `nl` + topMacroAnonymousClosure(quote(
                BeanFactory.instance.register<$beanType>{$beanType()}
            ))
            continue
        }
        for(msg in messages){
            let constructor = msg.getString('constructor')
            let assigns = msg.getTokens('assigns')
            let actualArgs = msg.getTokens('actualArgs')
            let ctor = if(constructor == 'init'){
                quote({
                    $assigns
                    $beanType($actualArgs)
                })
            }else{
                quote({
                    $assigns
                    $beanType.$(Token(IDENTIFIER, constructor))($actualArgs)
                })
            }
            tokens += `nl` + topMacroAnonymousClosure(quote(
                BeanFactory.instance.register<$beanType>$ctor
            ))
        }
    }
    tokens
}