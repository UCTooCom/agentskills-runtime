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

public macro Constructor(input: Tokens): Tokens {
    assertParentContext('Bean')
    let beanCond = HashMap<String, Tokens>()
    let valueCond = HashMap<String, Tokens>()
    for(msg in getChildMessages('BeanParam')){
        beanCond[msg.getString('name')] = msg.getTokens('cond')
    }
    for(msg in getChildMessages('Value')){
        valueCond[msg.getString('name')] = msg.getTokens('cond')
    }
    constructor(parseDecl(input), beanCond, valueCond)
    input
}
private func constructor(decl: Decl, beanCond: HashMap<String, Tokens>, valueCond: HashMap<String, Tokens>): Unit {
    match(decl){
        case x: FuncDecl where x.isPublic() && x.identifier.value == 'init' =>
            argTokens(x.funcParams, beanCond, valueCond)
            setItem('constructor', 'init')
        case x: FuncDecl where x.isPublic() && x.isStatic() && isGenericFunc(x) =>
            argTokens(x.funcParams, beanCond, valueCond)
            setItem('constructor', x.identifier.value)
        case x: PrimaryCtorDecl where x.isPublic() =>
            argTokens(x.funcParams, beanCond, valueCond)
            setItem('constructor', 'init')
        case x: MacroExpandDecl =>
            var d: Decl = x
            while(let md: MacroExpandDecl <- d){
                d = md.macroInputDecl
            }
            constructor(d, beanCond, valueCond)
        case _ => 
            let tokens = decl.toTokens()
            diagReport(ERROR, tokens, '${decl.identifier.value} must be a public constructor or public static func without generic parameter', '')
    }
}
private func isGenericFunc(decl: FuncDecl){
    try{
        decl.genericParam.parameters.size == 0
    }catch(_){
        false
    }
}
private func argTokens(params: ArrayList<FuncParam>, beanCond: HashMap<String, Tokens>, valueCond: HashMap<String, Tokens>): Unit {
    var assigns = quote()
    var actualArgs = quote()
    for(param in params){
        if(assigns.size > 0){
            assigns += `nl`
            actualArgs += `comma`
        }
        actualArgs += if(param.not.kind == ILLEGAL){
            quote($(param.identifier))
        }else{
            quote($(param.identifier): $(param.identifier))
        }
        let paramTypeTokens = param.paramType.toTokens()
        assigns += quote(let $(param.identifier) = ) + 
        if(let Some(cond) <- beanCond.get(param.identifier.value)){
            match(paramTypeTokens[0].value){
                case 'ArrayList' | 'List' => quote(lookupList<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>($cond))
                case 'Array' => quote(lookupList<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>($cond).toArray())
                case 'HashSet' | 'Set' => quote(lookupSet<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>($cond))
                case 'Option' => quote(lookupOption<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>($cond))
                case '?' => quote(lookupOption<$(paramTypeTokens[1 .. ])>($cond))
                case 'HashMap' | 'Map' => quote(lookupMap<$(paramTypeTokens[4 .. paramTypeTokens.size - 1])>($cond))
                case _ => quote(lookup<$(param.paramType)>($cond))
            }
        }else if (let Some(cond) <- valueCond.get(param.identifier.value)) {
            cond
        } else{
            match(paramTypeTokens[0].value){
                case 'ArrayList' | 'List' => quote(lookupList<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>())
                case 'Array' => quote(lookupList<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>().toArray())
                case 'HashSet' | 'Set' => quote(lookupSet<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>())
                case 'Option' => quote(if(let Some(x) <- lookupOption<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>($(param.identifier.value))){
                    x
                }else{
                    lookupOption<$(paramTypeTokens[2 .. paramTypeTokens.size - 1])>()
                })
                case '?' => quote(if(let Some(x) <- lookupOption<$(paramTypeTokens[1 .. ])>($(param.identifier.value))){
                    x
                }else{
                    lookupOption<$(paramTypeTokens[1 .. ])>()
                })
                case 'HashMap' | 'Map' => quote(lookupMap<$(paramTypeTokens[4 .. paramTypeTokens.size - 1])>())
                case _ => quote(if(let Some(x) <- lookupOption<$(param.paramType)>($(param.identifier.value))){
                    x
                }else{
                    lookup<$(param.paramType)>()
                }) 
            }
        }
    }
    setItem('assigns', assigns)
    setItem('actualArgs', actualArgs)
}