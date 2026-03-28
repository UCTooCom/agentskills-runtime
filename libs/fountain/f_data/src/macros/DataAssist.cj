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
macro package f_data.macros

import std.ast
import std.ast.*
import std.collection.{HashSet, ArrayList}
import f_data.*
import f_macros.*

/**
 * 支持以下特性，不分大小写
 * ToString：实现ToString接口
 * Props：为非公共的实例成员变量添加公共实例成员属性
 * Hash：实现Hashable
 * Compare: 实现Comparable<T>
 * Equal: 实现Equatable<T>
 * Fields: 实现实例复制
 * @DataAssist只能修饰类，并且要使用fields属性，类的实例成员变量类型T必须是实现了fountain.data.DataFields<T>接口的类型。
 * fountain.data包对基本类型、字符串、Duration、DateTime、实现了DataFields接口的类型和被@DataAssist[fields]修饰的类做泛型实参的数组、集合、Option实现了DataFields的扩展。
 * 只有类的实例成员变量是这些类型才可以被@DataAssist[fields]修饰，否则会报错。
 * 被@DataAssist[fields]修饰的类可以被转换为JsonValue和实例成员复制。
 * 如果@DataAssist[fields]修饰的是泛型类，而泛型形参是实例成员变量的类型，则会编译错误。
 * 因为实例成员变量的类型会作为fountain.data.{ReadonlyField, MutableField}类型的泛型实参，而@DataAssist[fields]展开用它们的实例数组声明了静态成员变量。
 * 现在的编译器不允许泛型形参出现在静态成员变量的声明当中，所以会编译错误。
 */
public macro DataAssist(attr: Tokens, input: Tokens): Tokens {
    assist(attr, input)
}
private func assist(attr: Tokens, input: Tokens): Tokens {
    match (parseDecl(input)) {
        case d: ClassDecl =>
            let set = HashSet<String>()
            for (t in attr) {
                set.add(t.value.toAsciiLower())
            }
            func generate(tag: String, decl: ClassDecl, exclusion: HashSet<String>,
                fn: (ClassDecl, HashSet<String>) -> Unit): Unit {
                if (set.contains(tag)) {
                    fn(decl, exclusion)
                }
            }
            let excludeProp = HashSet<String>()
            let excludeHash = HashSet<String>()
            let excludeEqual = HashSet<String>()
            let excludeCompare = HashSet<String>()
            let excludeToString = HashSet<String>()
            let excludeFields = HashSet<String>()
            func populateExclusion(message: MacroMessage, name: String, set: HashSet<String>): Unit {
                if (message.hasItem(name)) {
                    set.add(message.getString(name))
                }
            }
            for (message in getChildMessages('DataExclude')) {
                populateExclusion(message, 'prop', excludeProp)
                populateExclusion(message, 'hash', excludeHash)
                populateExclusion(message, 'equal', excludeEqual)
                populateExclusion(message, 'compare', excludeCompare)
                populateExclusion(message, 'tostring', excludeToString)
                populateExclusion(message, 'field', excludeFields)
            }
            excludeEqual.add('__hAsh__')
            excludeCompare.add('__hAsh__')
            excludeToString.add('__hAsh__')
            generate('props', d, excludeProp, generateProps)
            generate('hash', d, excludeHash, generateHash)
            generate('equal', d, excludeEqual, generateEqual)
            generate('compare', d, excludeCompare, generateCompare)
            generate('tostring', d, excludeToString, generateToString)
            generate('fields', d, excludeFields, generateToFields)
            d.toTokens()
        case d: MacroExpandDecl => 
            var ind = d
            while(let md: MacroExpandDecl <- ind.macroInputDecl) {
                ind = md
            }
            let tokens = assist(attr, ind.macroInputs)
            ind.macroInputDecl = parseDecl(tokens)
            d.toTokens()
        case _ =>
            diagReport(ERROR, input, 'input must be class decl', '')
            throw IllegalArgumentException("input must be a class decl")
    }
}

func generateProps(decl: ClassDecl, exclusion: HashSet<String>) {
    let decls = decl.body.decls
    let appended = ArrayList<Decl>()
    func gen(v: VarDecl, macroTokens: Tokens) {
        if (v.isStatic() || v.isPublic()) {
            return
        }
        let name = v.identifier
        if (exclusion.contains(name.value)) {
            return
        }
        let t = v.declType
        let mutable = v.keyword.value == 'var'
        v.identifier = Token(IDENTIFIER, v.identifier.value + '_')
        let (mutToken, setter) = if (mutable) {
            (quote(mut), quote(
                set(value){
                    $(v.identifier) = value
                }
            ))
        } else {
            let empty = quote()
            (empty, empty)
        }
        let propDecl = PropDecl(
                quote(
            public $mutToken prop $name: $(t){
                get(){
                    $(v.identifier)
                }
                $(setter)
            }
        ))
        appended.add(if(macroTokens.size == 0){
            propDecl
        }else{
            let md = MacroExpandDecl(macroTokens)
            var m = md
            while(let x: MacroExpandDecl <- m.macroInputDecl) {
                m = x
            }
            m.macroInputDecl = propDecl
            md
        })
    }
    let vars = ArrayList<Decl>()
    let assigns = ArrayList<ast.Node>()
    for (decl in decls) {
        match (decl) {
            case d: VarDecl where !(d.isStatic() || d.isPublic()) => gen(d, quote())
            case d: PrimaryCtorDecl =>
                let funcParams = d.funcParams
                for (i in 0 .. funcParams.size) {
                    func gen(p: FuncParam, macroTokens: Tokens){
                        let paramTokens = p.toTokens()
                        var c = 0
                        for (j in 0 .. paramTokens.size where paramTokens[j].kind == IDENTIFIER) {
                            c = j
                            break
                        }
                        var end = paramTokens.size
                        if (paramTokens[end - 1].kind == COMMA) {
                            end--
                        }
                        funcParams[i] = FuncParam(paramTokens[c .. end])
                        let member = VarDecl()
                        member.modifiers = p.modifiers
                        member.keyword = p.keyword
                        member.identifier = p.identifier
                        member.colon = p.colon
                        member.declType = p.paramType
                        try{
                            if (p.assign.kind == ASSIGN) {
                                member.assign = p.assign
                                member.expr = p.expr
                            }
                        }catch(_){}
                        vars.add(member)
                        p.modifiers = ArrayList<Modifier>()
                        p.keyword = Token(ILLEGAL)
                        gen(member, macroTokens)
                        assigns.add(parseExpr(quote(this.$(member.identifier) = $(p.identifier))))
                    }
                    let p = funcParams[i]
                    if (let x: MacroExpandParam <- p) {//TODO: x.macroInputDecl x.toTokens()有BUG，无法完成，等待修复
                        let mp = extract(x)
                        if(mp.isMemberParam()){
                            gen(mp, x.toTokens())
                        }
                    } else if (p.isMemberParam()) {
                        gen(p, quote())
                    }
                }
                d.block.nodes.add(all: assigns, at: 0)
            case d: MacroExpandDecl => 
                var md = extract(d)
                if(let x: VarDecl <- md && !(x.isStatic() || x.isPublic())){
                    gen(x, d.toTokens())
                }
            case _ => continue
        }
    }
    decls.add(all: vars, at: 0)
    decls.add(all: appended)
}

func generateHash(d: ClassDecl, exclusion: HashSet<String>) {
    if (d.superTypes.isEmpty()) {
        d.upperBound = `upperbound`[0]
    }
    d.superTypes.add(RefType(quote(Hashable)))
    var hashed = `nl`
    for (d in d.body.decls where d is VarDecl &&
        !(isStatic(d) || exclusion.contains(d.identifier.value) || exclusion.contains('${d.identifier.value}_'))) {
        hashed += quote(hasher.append($(d.identifier))$(`nl`))
    }
    d.body.decls.add(
            all: [VarDecl(quote(
        private var __hAsh__ = 0
    )),
                FuncDecl(
                quote(
        public $(openTokens(d)) func hashCode(): Int64{
            if(__hAsh__ == 0){
                let hasher = HashBuilder()
                $hashed
                __hAsh__ = hasher.build()
            }
            __hAsh__
        }
    ))])
}

func generateEqual(d: ClassDecl, exclusion: HashSet<String>) {
    if (d.superTypes.isEmpty()) {
        d.upperBound = `upperbound`[0]
    }
    let typeName = quote($(d.identifier)$(d.genericParamTokens))
    d.superTypes.add(RefType(quote(Equatable<$typeName>)))
    var eq = quote((!(this is Hashable) || this.hashCode() == other.hashCode())$(`nl`))
    for (d in d.body.decls where d is VarDecl &&
        !(isStatic(d) || exclusion.contains(d.identifier.value) || exclusion.contains('${d.identifier.value}_'))) {
        eq += `and` +quote(f_data_eq(this.$(d.identifier), other.$(d.identifier))) + `nl`
    }
    d.body.decls.add(
            all: [FuncDecl(
                quote(
        public $(openTokens(d)) operator func ==(other: $typeName): Bool {
            refEq(this, other) || ($eq)
        }
    )),
                FuncDecl(
                quote(
        public $(openTokens(d)) operator func !=(other: $typeName): Bool {
            !(this == other)
        }
    ))])
}

func generateCompare(d: ClassDecl, exclusion: HashSet<String>) {
    if (d.superTypes.isEmpty()) {
        d.upperBound = `upperbound`[0]
    }
    let typeName = quote($(d.identifier)$(d.genericParamTokens))
    d.superTypes.add(RefType(quote(Comparable<$typeName>)))
    var cmp = `nl`
    for (d in d.body.decls where d is VarDecl &&
        !(isStatic(d) || exclusion.contains(d.identifier.value) || exclusion.contains('${d.identifier.value}_'))) {
        cmp += quote(f_data_cmp(this.$(d.identifier), other.$(d.identifier))) + `nl` + quote(
            if(result != EQ){
                return result
            }
            $(`nl`)
        )
    }
    d.body.decls.add(
            FuncDecl(
                quote(
        public $(openTokens(d)) func compare(other: $typeName): Ordering {
            var result = Ordering.EQ
            $cmp
            result
        }
    )))
}

func generateToString(d: ClassDecl, exclusion: HashSet<String>) {
    if (d.superTypes.isEmpty()) {
        d.upperBound = `upperbound`[0]
    }
    d.superTypes.add(RefType(quote(ToString)))
    var str = quote(
        result.append<$(d.identifier)$(d.genericParamTokens)>()
    )
    for (d in d.body.decls where d is VarDecl &&
        !(isStatic(d) || exclusion.contains(d.identifier.value) || exclusion.contains('${d.identifier.value}_'))) {
        str += `nl` + quote(result.append($(d.identifier.value), $(d.identifier)))
    }
    d.body.decls.add(
            FuncDecl(
                quote(
        public $(openTokens(d)) func toString(): String {
            var result = DataToString()
            $str
            result.toString()
        }
    )))
}

func generateToFields(d: ClassDecl, exclusion: HashSet<String>) {
    let klassDecl = (d as ClassDecl).getOrThrow {
        DataException("current decl ${d.identifier.value} must be a class decl")
    }
    let klassIdentifier = quote($(klassDecl.identifier)$(d.genericParamTokens))
    if (klassDecl.superTypes.isEmpty()) {
        klassDecl.upperBound = `upperbound`[0]
    }
    let superTypes = klassDecl.superTypes
    superTypes.add(RefType(quote(ObjectData<$(klassIdentifier)>)))
    let body = klassDecl.body.decls
    let fields = ArrayList<Expr>()
    for (d in body where (!isStatic(d) && isPublic(d) && !exclusion.contains(d.identifier.value)) || (d is MacroExpandDecl)) {
        func appendExpr(d: Decl, dt: Tokens, isVar: Bool){
            var declType = dt
            if (declType[0].kind == QUEST) {
                declType = declType[1..]
            } else if (declType[0].kind == IDENTIFIER && declType[0].value == 'Option') {
                declType = declType[2..declType.size - 1]
            }
            let tokens = if (isVar) {
                quote(MutableField)
            } else {
                quote(ReadonlyField)
            } + quote(.new<$(klassIdentifier), $(declType)>($(d.identifier.value), {o => o.$(d.identifier)})) + if (isVar) {
                quote({o, v => o.$(d.identifier) = v})
            } else {
                `empty_tokens`
            }
            let expr = parseExpr(tokens)
            fields.add(expr)
        }
        func appendExpr(dt: Tokens, isVar: Bool){
            appendExpr(d, dt, isVar)
        }
        match (d) {
            case x: VarDecl => appendExpr(quote($(x.declType)), x.isVar())
            case x: PropDecl => appendExpr(quote($(x.declType)), x.isMut())
            case x: PrimaryCtorDecl =>
                for (p in x.funcParams where p.isMemberParam() && isPublic(p)) {
                    appendExpr(p.paramType.toTokens(), isVar(p))
                }
                continue
            case x: MacroExpandDecl => 
                match (extract(x)) {
                    case x: VarDecl where !isStatic(x) && isPublic(x) => appendExpr(x, quote($(x.declType)), x.isVar())
                    case x: PropDecl where !isStatic(x) && isPublic(x) => appendExpr(x, quote($(x.declType)), x.isMut())
                    case x: PrimaryCtorDecl where isPublic(d) =>
                        for (p in x.funcParams) {
                            match(p){
                                case x: MacroExpandParam => 
                                    var m: Decl = x
                                    while(let d: MacroExpandParam <- m){
                                        m = d.macroInputDecl
                                    }
                                    if(let x: FuncParam <- m && x.isMemberParam() && isPublic(x)){
                                        appendExpr(x, quote($(x.paramType)), isVar(x))
                                    }
                                case x: FuncParam where x.isMemberParam() && isPublic(p) => appendExpr(x, quote($(x.paramType)), isVar(x))
                                case _ => continue
                            }
                            appendExpr(p.paramType.toTokens(), isVar(p))
                        }
                        continue
                    case _ => continue
                }
            case _ => continue
        }
    }
    let openModi = openTokens(klassDecl)
    var fieldTokens = `lsquare`
    for (f in fields) {
        if (fieldTokens.size > 1) {
            fieldTokens += `comma`
        }
        fieldTokens += f.toTokens()
    }
    fieldTokens += `rsquare`
    body.add(
        all: [
            FuncDecl(
                quote(
        public static func dataFields(): ObjectFields {
            ObjectFields.getObjectFields<$klassIdentifier>{
                ($fieldTokens, {=>$klassIdentifier()})
            }
        }
    )),
            FuncDecl(
                quote(
        public $openModi func toData(): Data {
            DataObject<$klassIdentifier>(this)
        }
    )),
            FuncDecl(
                quote(
        public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
            f_data_tryFromData<$klassIdentifier>(data, flag)
        }
    ))
        ]
    )
}

private func openTokens(klassDecl: ClassDecl): Tokens {
    if (klassDecl.isAbstract() || klassDecl.isOpen()) {
        `open`
    } else {
        `empty_tokens`
    }
}
