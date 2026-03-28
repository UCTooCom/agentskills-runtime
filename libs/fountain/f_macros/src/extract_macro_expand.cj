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
package f_macros

import std.collection.Set

public func extract(decl: MacroExpandDecl): Decl {
    var d: Decl = decl
    while (let m: MacroExpandDecl <- d) {
        d = m.macroInputDecl
    }
    d
}

public func extract(decl: MacroExpandDecl, macroName: String): ?(MacroExpandDecl, Decl) {
    var d: Decl = decl
    var result = None<(MacroExpandDecl, Decl)>
    while (let m: MacroExpandDecl <- d) {
        if (m.fullIdentifier.value == macroName) {
            result = (m, d)
        }
        d = m.macroInputDecl
    }
    if (let Some((m, _)) <- result) {
        result = (m, d)
    }
    result
}

public func extractIfOneOf(decl: MacroExpandDecl, macroNames: Set<String>): ?(MacroExpandDecl, Decl) {
    var d: Decl = decl
    var result = None<(MacroExpandDecl, Decl)>
    while (let m: MacroExpandDecl <- d) {
        if (result.isNone() && macroNames.contains(m.fullIdentifier.value)) {
            result = (m, d)
        }
        d = m.macroInputDecl
    }
    if (let Some((m, _)) <- result) {
        result = (m, d)
    }
    result
}

public func extract(expr: MacroExpandExpr): Expr {
    var e: Expr = expr
    while (let m: MacroExpandExpr <- e) {
        e = parseExpr(m.macroInputs)
    }
    e
}

public func extract(expr: MacroExpandExpr, macroName: String): ?(MacroExpandExpr, Expr) {
    var e: Expr = expr
    var result = None<(MacroExpandExpr, Expr)>
    while (let m: MacroExpandExpr <- e) {
        if (m.identifier.value == macroName) {
            result = (m, e)
        }
        e = parseExpr(m.macroInputs)
    }
    if (let Some((m, _)) <- result) {
        result = (m, e)
    }
    result
}

public func extractIfOneOf(expr: MacroExpandExpr, macroNames: Set<String>): ?(MacroExpandExpr, Expr) {
    var e: Expr = expr
    var result = None<(MacroExpandExpr, Expr)>
    while (let m: MacroExpandExpr <- e) {
        if (result.isNone() && macroNames.contains(m.identifier.value)) {
            result = (m, e)
        }
        e = parseExpr(m.macroInputs)
    }
    if (let Some((m, _)) <- result) {
        result = (m, e)
    }
    result
}

public func extract(param: MacroExpandParam): FuncParam {
    var p: FuncParam = param
    while (let m: MacroExpandParam <- p && let pin: FuncParam <- m.macroInputDecl) {
        p = pin
    }
    p
}

public func extract(param: MacroExpandParam, macroName: String): ?(MacroExpandParam, FuncParam) {
    var p: FuncParam = param
    var result = None<(MacroExpandParam, FuncParam)>
    while (let m: MacroExpandParam <- param && let pin: FuncParam <- m.macroInputDecl) {
        if (m.fullIdentifier.value == macroName) {
            result = (m, pin)
        }
        p = pin
    }
    if (let Some((m, _)) <- result) {
        result = (m, p)
    }
    result
}

public func extractIfOneOf(param: MacroExpandParam, macroNames: Set<String>): ?(MacroExpandParam, FuncParam) {
    var p: FuncParam = param
    var result = None<(MacroExpandParam, FuncParam)>
    while (let m: MacroExpandParam <- param && let pin: FuncParam <- m.macroInputDecl) {
        if (result.isNone() && macroNames.contains(m.fullIdentifier.value)) {
            result = (m, pin)
        }
        p = pin
    }
    if (let Some((m, _)) <- result) {
        result = (m, p)
    }
    result
}
public func replaceMacroInputDecl(macroTokens: Tokens, decl: MacroExpandDecl): MacroExpandDecl {
    var d = decl
    while(let md: MacroExpandDecl <- d.macroInputDecl) {
        d = md
    }
    let mt = 
    if(let AT <- macroTokens[0].kind){
        macroTokens
    }else{
        `at` + macroTokens
    }
    let tokens = quote(
        $mt
        $(d.macroInputs)
    )
    d.macroInputDecl = parseDecl(tokens)
    //经过测试macroInputDecl macroInput互不影响，两个都要修改
    decl
}
public func replaceMacroInputDecl(macroDecl: MacroExpandDecl, decl: Decl): MacroExpandDecl {
    var d = macroDecl
    while(let md: MacroExpandDecl <- d.macroInputDecl) {
        d = md
    }
    d.macroInputDecl = decl
    macroDecl
}