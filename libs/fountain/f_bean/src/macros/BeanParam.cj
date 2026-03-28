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

public macro BeanParam(attr: Tokens, input: Tokens): Tokens {
    func setItem(attr: Tokens, param: FuncParam): Unit {
        setItem('name', param.identifier.value)
        let first = attr[0]
        let tokens = match ((first.kind, first.value)) {
            case (STRING_LITERAL, _) => attr
            case (IDENTIFIER, 'StringCond') 
            where attr.size == 6 && attr[1].kind == DOT && attr[2].kind == IDENTIFIER && 
                match(attr[2].value){
                    case 'Exactly' | 'prefix' | 'Suffix' | 'wildcard' | 'Regexp' => true
                    case _ => 
                        diagReport(ERROR, input, '${attr} must be a String or constructor of fountain.bean.StringCond', '')
                        return
                } && 
                attr[3].kind == LPAREN && attr[4].kind == STRING_LITERAL && attr[5].kind == RPAREN => attr
            case (IDENTIFIER, 'StringCond') 
            where attr.size == 3 && attr[1].kind == DOT && 
                attr[2].kind == IDENTIFIER && attr[2].value == 'IgnoreCond' => attr
            case (IDENTIFIER, 'IgnoreCond') => quote(StringCond.$attr)
            case (IDENTIFIER, _) where attr.size == 3 && match(attr[0].value){
                case 'Exactly' | 'prefix' | 'Suffix' | 'wildcard' | 'Regexp' => true
                case _ => 
                    diagReport(ERROR, input, '${attr} must be a String or constructor of fountain.bean.StringCond', '')
                    return
            } && attr[1].kind == LPAREN && attr[2].kind == STRING_LITERAL && attr[3].kind == RPAREN => quote(StringCond.$attr)
            case _ => 
                diagReport(ERROR, input, '${attr} must be a String or constructor of fountain.bean.StringCond', '')
                return
        }
        setItem('cond', tokens)
    }
    assertParentContext('Constructor')
    match (parseDecl(attr)) {
        case x: FuncParam => setItem(attr, x)
        case x: MacroExpandParam =>
            var d: Decl = x
            while (let mp: MacroExpandParam <- d) {
                d = mp.macroInputDecl
            }
            if (let p: FuncParam <- d) {
                setItem(attr, p)
            } else {
                diagReport(ERROR, input, '${input} must be a FuncParam or a MacroExpandParam', '')
            }
        case _ => diagReport(ERROR, input, '${input} must be a FuncParam or a MacroExpandParam', '')
    }
    input
}
