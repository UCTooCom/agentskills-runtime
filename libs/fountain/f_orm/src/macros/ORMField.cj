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
macro package f_orm.macros

import std.ast.*
import f_macros.*
import f_orm.exception.*
import f_util.CaseFormat

/**
 * 必须跟@QueryMappersGenerator配合使用
 * 使用宏@ORMField 注解public mut prop或public var指定当前属性或成员变量是不是主键以及映射的列名，所有的仓颉mut prop必须是驼峰命名法。
 * @ORMField[true LowerUnderScore dataType] 表示当前属性映射主键，属性名转为LowerUnderScore就是列名，列的类型是dataType。
 * @ORMField[true "column_name" dataType] 表示当前属性映射主键，不论属性名是什么列名一定是"column_name"。
 * 第一部分可以是true或false，true表示当前属性映射主键，false表示映射的不是主键。
 * dataType必须是枚举orm.DataType的值。
 * 每一部分都是可选的，且顺序任意，不是true false也不是LowerUnderScore UpperUnderScore Pascal Camel的一律认为是DataType。
 * 没有使用@ORMField注解的公共实例成员变量或公共实例成员属性被认为映射的不是主键，且按照列名是LowerUnderScore处理。
 */
public macro ORMField(attrs: Tokens, input: Tokens): Tokens {
    assertParentContext("QueryMappersGenerator") //无法用反射处理QueryMapper的闭包参数的泛型，也就不能用反射创建Q
    expandORMField(attrs, input)
}
private func expandORMField(attrs: Tokens, input: Tokens): Tokens {
    var tokens = input
    let decl = parseDecl(input)
    let name = match(decl) {
        case varDecl: VarDecl => 
            if (varDecl.keyword.kind == VAR && !varDecl.isStatic()) {
                let name = varDecl.identifier
                let varName = Token(IDENTIFIER, "_${name.value}_")
                let varType = if (varDecl.colon.kind != ILLEGAL) {
                    `colon` + varDecl.declType.toTokens()
                } else {
                    `empty_tokens`
                }
                let assign = if (varDecl.assign.kind != ILLEGAL) {
                    `assign` + varDecl.expr.toTokens()
                } else {
                    `empty_tokens`
                }
                tokens = quote(
                    private var $varName $varType $assign
                    public mut prop $name $varType {
                        get(){
                            this.$varName
                        }
                        set(value){
                            this.$varName = value
                        }
                    }
                )
                name
            } else {
                throw ORMException(
                    "member of current type which is named as ${decl.identifier.value} must be modified by `public var` or `public mut prop` which is annotated by ORMField")
            }
        case propDecl: PropDecl => 
            if (propDecl.isPublic() && propDecl.isMut() && !propDecl.isStatic()) {
                propDecl.identifier
            } else {
                throw ORMException(
                    "member of current type which is named as ${decl.identifier.value} must be modified by `public var` or `public mut prop` which is annotated by ORMField")
            }
        case d: MacroExpandDecl => 
            let tokens = expandORMField(attrs, extract(d).toTokens())
            let (varDecl, next) = parseDeclFragment(tokens, startFrom: 0)
            return quote(
                $(replaceMacroInputDecl(d, varDecl))
                $(tokens[next .. ])
            )
        case _ => 
            diagReport(ERROR, input, 'illegal decl', '')
            throw ORMException(
                "member of current type must be modified by `public var` or `public mut prop` which is annotated by ORMField")

    }
    setItem("field", name.value)
    for (attr in attrs) {
        match ((attr.kind, attr.value)) {
            case (BOOL_LITERAL, x) => setItem("id", x == "true")
            case (STRING_LITERAL, x) => setItem("column", x)
            case (SINGLE_QUOTED_STRING_LITERAL, x) => setItem("column", x)
            case (IDENTIFIER, x) => match (x) {
                case "LowerUnderScore" => setItem("column",
                    CaseFormat.Camel.convert(name.value, to: CaseFormat.LowerUnderScore))
                case "UpperUnderScore" => setItem("column",
                    CaseFormat.Camel.convert(name.value, to: CaseFormat.UpperUnderScore))
                case "Pascal" => setItem("column", CaseFormat.Camel.convert(name.value, to: CaseFormat.Pascal))
                case "Camel" => setItem("column", name.value)
                case x => setItem("dataType", x)
            }
            case _ => throw ORMException("unsupported TokenKind in attrs of @ORMFIeld")
        }
    }
    tokens
}