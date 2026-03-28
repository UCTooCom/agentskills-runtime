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
import std.collection.HashMap
import f_macros.*
import f_orm.exception.ORMException
import f_regex.*
import f_util.CaseFormat

/**
 * 必须跟@ORMField配合使用
 * 使用宏@ORMField 注解public mut prop或public var指定当前属性或成员变量是不是主键以及映射的列名，所有的仓颉mut prop必须是驼峰命名法。
 * @ORMField[true LowerUnderScore dataType] 表示当前属性映射主键，属性名转为LowerUnderScore就是列名，列的类型是dataType。
 * @ORMField[true "column_name" dataType] 表示当前属性映射主键，不论属性名是什么列名一定是"column_name"。
 * 第一部分可以是true或false，true表示当前属性映射主键，false表示映射的不是主键。
 * dataType必须是枚举orm.dialect.DataType的值。
 * 每一部分都是可选的。
 * 没有使用@ORMField注解的按照映射的不是主键，且按照列名是LowerUnderScore处理。
 *
 * 宏的属性格式：
 *   dirty 指定这个属性的表示被此宏修饰的类的属性发生变化时会向ORM标记修改历史，可以调用executor.updateDirty<T>()更新修改过的属性，
 *         本属性没有值只有属性名。
 *         只有被@ORMField修饰的成员变量才对dirty生效。
 *   table: 是一个字符串或标识符，表示列名转换的格式，
 *          可以是LowerUnderScore、UpperUnderScore、Pascal，会把Pascal风格的类名转换成指定风格的名称，并把转换结果作为表名，也可以是表名本身。
 *   classPrefix: 是一个字符串或标识符，把类名开头匹配的子串裁掉
 *   classSuffix: 是一个字符串或标识符，把类名结尾匹配的子串裁掉
 *   tablePrefix: 是一个字符串或标识符，在转换后的表名前面加上这个前缀
 *   tableSuffix: 是一个字符串或标识符，在转换后的表名后面加上这个后缀
 *   上面的冒号也是宏属性的一部分。
 *   如果宏属性只有一个，且不是dirty，就把它当作tableName处理。
 *   如果没有宏属性或只有一个dirty属性，则把类名按照Pascal风格转成LowerUnderScore。
 * 如果要把fountain.data.macros.DataAssist跟@QueryMappersGenerator一起使用，需要满足以下条件：
 * 1. 不要对被修饰类使用DataAssist宏的props属性，@QueryMappersGenerator会为被修饰类添加属性
 * 2. 如果要复制实例成员或者把类的实例转换为JsonValue，@QueryMappersGenerator要先于@DataAssist展开，
 *    即@DataAssist要在@QueryMappersGenerator前面。
 * 3. 如果没有2. 这种需求，则二者顺序没有要求，但是1. 还需要满足。
 */
public macro QueryMappersGenerator(input: Tokens): Tokens {
    expandQueryMappers(quote(), input)
}
public macro QueryMappersGenerator(attr: Tokens, input: Tokens): Tokens {
    expandQueryMappers(attr, input)
}
private func expandQueryMappers(attr: Tokens, input: Tokens): Tokens {
    let decl = match(parseDecl(input)){
        case d: ClassDecl => d
        case d: MacroExpandDecl => 
            var decl = extract(d)
            let tokens = expandQueryMappers(attr, decl.toTokens())
            decl = parseDecl(tokens)
            decl = replaceMacroInputDecl(d, decl)
            return decl.toTokens()
        case _ => 
            diagReport(ERROR, input, 'QueryMappersGenerator supports a class', '')
            throw ORMException("QueryMappersGenerator supports a class") 
    }
    let name = quote($(decl.identifier))
    let body = decl.body.decls
    let props = extractMutProps(body)
    let map = HashMap<String, (Bool, String, Token)>()
    for (m in getChildMessages("ORMField")) {
        let name = m.getString("field")
        let id = if (m.hasItem("id")) {
            m.getBool("id")
        } else {
            false
        }
        let column = if (m.hasItem("column")) {
            m.getString("column")
        } else {
            ""
        }
        let dataType = if (m.hasItem("dataType")) {
            m.getString("dataType")
        } else {
            ""
        }
        map[name] = (id, column, Token(IDENTIFIER, dataType))
    }
    let mapperMetaFn = {
        n: String => if (let Some(m) <- map.get(n)) {
            m
        } else {
            (false, CaseFormat.Camel.convert(n, to: CaseFormat.LowerUnderScore), Token(IDENTIFIER, ""))
        }
    }
    var dirty = false
    for(token in attr where token.kind == IDENTIFIER && token.value.toAsciiLower() == 'dirty'){
        dirty = true
        break
    }
    var mappers = quote([$(generateMappers(name, props, dirty, mapperMetaFn)))
    let varMappers = generateMappers(name, extractVars(body), mapperMetaFn)//这里不能去掉，对于级联映射会用到
    if (varMappers.size > 0) {
        mappers += `comma` + varMappers
    }
    mappers += `rsquare`
    let queryMappersName = Token(IDENTIFIER, "_qUEry__mAppErs_")
    let superTypes = decl.superTypes
    var mapperTokens = quote(
        let creator = {=> $name()}
        let mappers = $mappers$(`nl`)
    )
    for (st in superTypes) {
        mapperTokens += quote(
            if (let Some(x) <- QueryMappers<$st>.create<$name>(creator, mappers)) {
                return x
            }$(`nl`)
        )
    }
    if (superTypes.isEmpty()) {
        decl.upperBound = `upperbound`[0]
    }
    decl.superTypes.add(RefType(quote(QueryMappersInit<$name>)))
    let tableName = transformTableName(attr, decl)
    body.add(parseDecl(
            quote(
        private static let $queryMappersName = {=>
            $mapperTokens
            QueryMappers<$name> (
                creator: creator,
                mappers: mappers
            )
        }()
    )))
    body.add(parseDecl(
            quote(
        public static func tableName(): String {
            $tableName
        }
    )))
    body.add(parseDecl(
            quote(
        public static func isSimpleData(): Bool {
            false
        }
    )))
    body.add(parseDecl(
            quote(
        public static func queryMappers(): QueryMappers<$name>{
            $queryMappersName
        }
    )))
    decl.toTokens()
}

func generateMappers(name: Tokens, props: ArrayList<PropDecl>, dirty: Bool, mapperMetaFn: (String) -> (Bool, String, Token)): Tokens {
    var tokens = quote()
    for (i in 0..props.size) {
        if (i > 0) {
            tokens += `comma`
        }
        let decl = props[i]
        let propName = decl.identifier
        let dts = decl.declType.toTokens()
        if(dirty && (dts.size == 1 || (dts.size == 2 && dts[0].kind == QUEST) || (dts.size == 4 && dts[0].value == 'Option'))){
            let expr = parseExpr(quote(DirtyTag.setDirtyField<$name>($(decl.identifier.value))))
            try{
                decl.setter.block.nodes.add(expr)
            }catch(_){}
        }
        let meta = mapperMetaFn(propName.value)
        tokens += generateMappers(name, propName, dts, meta)
    }
    tokens
}

func generateMappers(name: Tokens, vars: ArrayList<VarDecl>, mapperMetaFn: (String) -> (Bool, String, Token)): Tokens {
    var tokens = quote()
    for (i in 0..vars.size) {
        if (i > 0) {
            tokens += `comma`
        }
        let decl = vars[i]
        let varName = decl.identifier
        let dts = quote($(decl.declType))
        let meta = mapperMetaFn(varName.value)
        tokens += generateMappers(name, varName, dts, meta)
    }
    tokens
}

func generateMappers(name: Tokens, fieldName: Token, dts: Tokens, meta: (Bool, String, Token)): Tokens {
    var dataType = quote()
    var nullable = false
    for (j in 0..dts.size) {
        let dt = dts[j]
        if (j == 0 && dt.value == "?") {
            nullable = true
            dataType += dts[j + 1]
        } else if (j == 0 && dt.value == "Option") {
            nullable = true
            dataType += dts[j + 2]
        } else {
            dataType += dt
            continue
        }
        break
    }
    let dataTypeStr = dataType.toString().replace(' ', '')
    let dataTypeToken = Token(IDENTIFIER, '${dataType[0].value}DataType')
    let fieldNameStr = Token(STRING_LITERAL, fieldName.value)
    let columnName = Token(STRING_LITERAL, meta[1])
    let columnType = meta[2]
    if (meta[0]) {
        quote(
                IdQueryMapper<$dataType, $name>(
                    dataType: $(dataTypeToken)($nullable, $columnName, $fieldNameStr),
                    putter: {o, v => o.$fieldName = ORMConverter.convert<$dataType>(v)}
                )
            )
    } else if (dataType[0].value == "ArrayList") {
        var listGeneric = quote()
        for (j in 2..dataType.size - 1) {
            let dt = dataType[j]
            if (j == 2 && dt.value == "?") {
                nullable = true
                listGeneric += quote(Option<)
            } else if (j == 2 && dt.value == "Option") {
                nullable = true
                listGeneric += dt
            } else {
                listGeneric += dt
            }
        }
        if (nullable) {
            listGeneric += `gt`
        }
        if (nullable && columnType.value.isEmpty()) {
            quote(
                    if (TypeInfo.of<$(listGeneric[2])>().isSubtypeOf(TypeInfo.of<InputStream>()) || $(listGeneric[2]).isSimpleData()) {
                        GroupedSingleQueryMapper<$(listGeneric[2]), $name>(
                            name: $columnName,
                            groupedGetter: {o => o.$fieldName}
                        )
                    } else {
                        NullableGroupedQueryMapper<$(listGeneric[2]), $name>(
                            ignoreNone: false,
                            grouped: $(listGeneric[2]).queryMappers(),
                            groupedGetter: {o => o.$fieldName}
                        )
                    }
                )
        } else if (nullable) {
            quote(
                    if (TypeInfo.of<$(listGeneric[2])>().isSubtypeOf(TypeInfo.of<InputStream>()) || $(listGeneric[2]).isSimpleData()) {
                        GroupedSingleQueryMapper<$(listGeneric[2]), $name>(
                            name: $columnName,
                            groupedGetter: {o => o.$fieldName}
                        )
                    } else {
                        NullableGroupedQueryMapper<$(listGeneric[2]), $name>(
                            ignoreNone: false,
                            grouped: $(listGeneric[2]).queryMappers(),
                            groupedGetter: {o => o.$fieldName}
                        )
                    }
                )
        } else if (columnType.value == "") {
            quote(
                    if (TypeInfo.of<$(listGeneric)>().isSubtypeOf(TypeInfo.of<InputStream>()) || $(listGeneric).isSimpleData()) {
                        GroupedSingleQueryMapper<$listGeneric, $name>(
                            name: $columnName,
                            groupedGetter: {o => o.$fieldName}
                        )
                    } else {
                        GroupedQueryMapper<$listGeneric, $name>(
                            name: $columnName,
                            grouped: $(listGeneric).queryMappers(),
                            groupedGetter: {o => o.$fieldName}
                        )
                    }
                )
        } else {
            quote(
                    if (TypeInfo.of<$(listGeneric)>().isSubtypeOf(TypeInfo.of<InputStream>()) || $(listGeneric).isSimpleData()) {
                        GroupedSingleQueryMapper<$listGeneric, $name>(
                            name: $columnName,
                            groupedGetter: {o => o.$fieldName}
                        )
                    } else {
                        GroupedQueryMapper<$listGeneric, $name>(
                            name: $columnName,
                            grouped: $(listGeneric).queryMappers(),
                            groupedGetter: {o => o.$fieldName}
                        )
                    }
                )
        }
    } else if (nullable && columnType.value == "") {
        quote(
                if(TypeInfo.of<$(dataType)>().isSubtypeOf(TypeInfo.of<InputStream>())){
                    FieldQueryMapper<$dataType, $name> (
                        dataType: InputStreamDataType($nullable, $columnName, $fieldNameStr),
                        putter: {o, v => o.$fieldName = v}
                    )
                }else if ($(dataType).isSimpleData()) {
                    FieldQueryMapper<$dataType, $name> (
                        dataType: $(dataTypeToken)($nullable, $columnName, $fieldNameStr),
                        putter: {o, v => o.$fieldName = v}
                    )
                } else {
                    NullableNestQueryMapper<$dataType, $name> (
                        nested: $(dataType).queryMappers(),
                        nestGetter: {o => o.$fieldName},
                        nestPutter: {o, v => o.$fieldName = v}
                    )
                }
            )
    } else if (nullable) {
        quote(
                if(TypeInfo.of<$(dataType)>().isSubtypeOf(TypeInfo.of<InputStream>())){
                    FieldQueryMapper<$dataType, $name> (
                        dataType: InputStreamDataType($nullable, $columnName, $fieldNameStr),
                        putter: {o, v => o.$fieldName = v}
                    )
                }else if ($(dataType).isSimpleData()) {
                    FieldQueryMapper<$dataType, $name> (
                        dataType: $(dataTypeToken)($nullable, $columnName, $fieldNameStr),
                        putter: {o, v => o.$fieldName = v}
                    )
                } else {
                    NullableNestQueryMapper<$dataType, $name> (
                        nested: $(dataType).queryMappers(),
                        nestGetter: {o => o.$fieldName},
                        nestPutter: {o, v => o.$fieldName = v}
                    )
                }
            )
    } else if (columnType.value == "") {
        quote(
                if(TypeInfo.of<$(dataType)>().isSubtypeOf(TypeInfo.of<InputStream>())){
                    QueryMapper<$name> (
                        dataType: InputStreamDataType($nullable, $columnName, $fieldNameStr),
                        putter: {o, v =>
                            o.$fieldName =
                            match(v){
                                case x: Option<$dataType> => x.getOrThrow{ORMException("current value for " + $fieldNameStr + " must not be None")}
                                case x: $dataType =>  x
                                case _ => throw ORMException("current value must be type of " + $(dataTypeStr))
                            }
                    })
                }else if ($(dataType).isSimpleData()) {
                    QueryMapper<$name> (
                        dataType: $(dataTypeToken)($nullable, $columnName, $fieldNameStr),
                        putter: {o, v =>
                            o.$fieldName =
                            match(v){
                                case x: Option<$dataType> => x.getOrThrow{ORMException("current value for " + $fieldNameStr + " must not be None")}
                                case x: $dataType =>  x
                                case _ => throw ORMException("current value must be type of " + $(dataTypeStr))
                            }
                    })
                } else {
                    NestQueryMapper<$dataType, $name> (
                        nested: $(dataType).queryMappers(),
                        nestPutter: {o, v => o.$fieldName = v}
                    )
                }
            )
    } else {
        quote(
                if(TypeInfo.of<$(dataType)>().isSubtypeOf(TypeInfo.of<InputStream>())){
                    QueryMapper<$name> (
                        dataType: InputStreamDataType($nullable, $columnName, $fieldNameStr),
                        putter: {o, v =>
                            o.$fieldName =
                            match(v){
                                case x: Option<$dataType> => x.getOrThrow{ORMException("current value for " + $fieldNameStr + " must not be None")}
                                case x: $dataType =>  x
                                case _ => throw ORMException("current value must be type of " + $(dataTypeStr))
                            }
                    })
                }else if ($(dataType).isSimpleData()) {
                    QueryMapper<$name> (
                        dataType: $(dataTypeToken)($nullable, $columnName, $fieldNameStr),
                        putter: {o, v =>
                            o.$fieldName =
                            match(v){
                                case x: Option<$dataType> => x.getOrThrow{ORMException("current value for " + $fieldNameStr + " must not be None")}
                                case x: $dataType =>  x
                                case _ => throw ORMException("current value must be type of " + $(dataTypeStr))
                            }
                    })
                } else {
                    NestQueryMapper<$dataType, $name> (
                        nested: $(dataType).queryMappers(),
                        nestPutter: {o, v => o.$fieldName = v}
                    )
                }
            )
    }
}
private func transformTableName(attrs: Tokens, decl: Decl): String {
    var className = decl.identifier.value
    if(attrs.size == 0 || (attrs.size == 1 && attrs[0].kind == IDENTIFIER && attrs[0].value.toAsciiLower() == 'dirty')){
        return CaseFormat.Pascal.convert(className, to: CaseFormat.LowerUnderScore)
    }
    var tableToken = Token(STRING_LITERAL, "")
    var classPrefix = ''
    var classSuffix = ''
    var tablePrefix = ''
    var tableSuffix = ''
    if(attrs.size == 1){
        tableToken = attrs[0]
    } else {
        var i = 0
        while(i < attrs.size){
            let attr = attrs[i]
            match((attr.kind, attr.value)){
                case (IDENTIFIER, 'table') => 
                    tableToken = attrs[i + 2]
                    i += 2
                case (_, 'classPrefix') => 
                    classPrefix = attrs[i + 2].value
                    i += 2
                case (_, 'classSuffix') => 
                    classSuffix = attrs[i + 2].value
                    i += 2
                case (_, 'tablePrefix') => 
                    tablePrefix = attrs[i + 2].value
                    i += 2
                case (_, 'tableSuffix') => 
                    tableSuffix = attrs[i + 2].value
                    i += 2
                case (COMMA, _) | (SEMI, _) | (IDENTIFIER, 'dirty') => ()
                case _ =>
                    diagReport(WARNING, attrs, '${attr.value} is illegal attr for @QueryMappersGenerator, which is modifying ${decl.identifier.value}', '')
            }
            i++
        }
    }

    className = className.removePrefix(classPrefix).removeSuffix(classSuffix)
    let tableName =
    match((tableToken.kind, tableToken.value)){
        case (STRING_LITERAL, x) => x
        case (SINGLE_QUOTED_STRING_LITERAL, x) => x
        case (IDENTIFIER, 'LowerUnderScore') => CaseFormat.Pascal.convert(className, to: CaseFormat.LowerUnderScore)
        case (IDENTIFIER, 'UpperUnderScore') => CaseFormat.Pascal.convert(className, to: CaseFormat.UpperUnderScore)
        case (IDENTIFIER, 'Pascal') => className
        case (_, x) => x
    }
    '${tablePrefix}${tableName}${tableSuffix}'
}